## takeover_manager.gd - Manages UI takeovers (dialogue, menus, cutscenes)
## Provides a stack-based system for UI layers that take over player input
## NOTE: This is an autoload singleton - access via TakeoverManager global
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a takeover is pushed onto the stack
signal takeover_started(takeover_type: String, takeover_node: Node)

## Emitted when a takeover is popped from the stack
signal takeover_ended(takeover_type: String)

## Emitted when the takeover stack becomes empty (gameplay resumes)
signal all_takeovers_cleared

## Emitted when the active takeover changes (top of stack changes)
signal active_takeover_changed(takeover_type: String, takeover_node: Node)


# =============================================================================
# CONSTANTS
# =============================================================================

## Known takeover types for type safety and documentation
const TYPE_DIALOGUE := "dialogue"        ## Scripted NPC dialogue (DialogueManager)
const TYPE_CONVERSATION := "conversation" ## Topic-based NPC conversation (ConversationSystem)
const TYPE_MENU := "menu"                ## Full-screen menus (pause, game menu)
const TYPE_POPUP := "popup"              ## Modal popups (confirmation, loot)
const TYPE_CUTSCENE := "cutscene"        ## Cutscene sequences
const TYPE_SHOP := "shop"                ## Shop/trade interfaces
const TYPE_CRAFTING := "crafting"        ## Crafting interfaces
const TYPE_CUSTOM := "custom"            ## Custom takeovers


# =============================================================================
# TAKEOVER DATA
# =============================================================================

## Represents a single takeover on the stack
class TakeoverData:
	var type: String              ## Takeover type (see TYPE_* constants)
	var node: Node                ## The node handling this takeover (can be null)
	var pauses_game: bool         ## Whether this takeover pauses the game tree
	var captures_mouse: bool      ## Whether this takeover shows the mouse cursor
	var blocks_input: bool        ## Whether this takeover blocks input to lower layers
	var priority: int             ## Higher priority takeovers can interrupt lower ones
	var metadata: Dictionary      ## Additional data for this takeover

	func _init(
		p_type: String,
		p_node: Node = null,
		p_pauses_game: bool = true,
		p_captures_mouse: bool = true,
		p_blocks_input: bool = true,
		p_priority: int = 0,
		p_metadata: Dictionary = {}
	) -> void:
		type = p_type
		node = p_node
		pauses_game = p_pauses_game
		captures_mouse = p_captures_mouse
		blocks_input = p_blocks_input
		priority = p_priority
		metadata = p_metadata


# =============================================================================
# STATE
# =============================================================================

## Stack of active takeovers (bottom = oldest, top = current)
var _takeover_stack: Array[TakeoverData] = []

## Whether the takeover system is active (has at least one takeover)
var is_active: bool:
	get:
		return not _takeover_stack.is_empty()

## The current (topmost) takeover
var current_takeover: TakeoverData:
	get:
		if _takeover_stack.is_empty():
			return null
		return _takeover_stack[_takeover_stack.size() - 1]

## Quick access to current takeover type
var current_type: String:
	get:
		var current := current_takeover
		return current.type if current else ""

## Quick access to current takeover node
var current_node: Node:
	get:
		var current := current_takeover
		return current.node if current else null


# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# =============================================================================
# PUBLIC API - STACK MANAGEMENT
# =============================================================================

## Push a new takeover onto the stack
## Returns the TakeoverData for the pushed takeover
func push_takeover(
	type: String,
	node: Node = null,
	pauses_game: bool = true,
	captures_mouse: bool = true,
	blocks_input: bool = true,
	priority: int = 0,
	metadata: Dictionary = {}
) -> TakeoverData:
	var takeover := TakeoverData.new(
		type, node, pauses_game, captures_mouse, blocks_input, priority, metadata
	)

	# Check if we need to sort by priority
	var insert_index: int = _takeover_stack.size()
	for i in range(_takeover_stack.size() - 1, -1, -1):
		if _takeover_stack[i].priority <= priority:
			insert_index = i + 1
			break
		else:
			insert_index = i

	_takeover_stack.insert(insert_index, takeover)

	# Apply takeover state
	_apply_takeover_state()

	# Emit signals
	takeover_started.emit(type, node)
	if current_takeover == takeover:
		active_takeover_changed.emit(type, node)

	return takeover


## Pop the current (topmost) takeover from the stack
## Returns the popped TakeoverData or null if stack was empty
func pop_takeover() -> TakeoverData:
	if _takeover_stack.is_empty():
		push_warning("[TakeoverManager] Attempted to pop from empty stack")
		return null

	var popped: TakeoverData = _takeover_stack.pop_back()
	var popped_type: String = popped.type

	# Apply new state
	_apply_takeover_state()

	# Emit signals
	takeover_ended.emit(popped_type)

	if _takeover_stack.is_empty():
		all_takeovers_cleared.emit()
	else:
		var new_current: TakeoverData = current_takeover
		active_takeover_changed.emit(new_current.type, new_current.node)

	return popped


## Pop a specific takeover by type (removes first match from top)
## Returns the popped TakeoverData or null if not found
func pop_takeover_by_type(type: String) -> TakeoverData:
	for i in range(_takeover_stack.size() - 1, -1, -1):
		if _takeover_stack[i].type == type:
			var popped: TakeoverData = _takeover_stack[i]
			_takeover_stack.remove_at(i)

			# Apply new state
			_apply_takeover_state()

			# Emit signals
			takeover_ended.emit(type)

			if _takeover_stack.is_empty():
				all_takeovers_cleared.emit()
			elif i == _takeover_stack.size():  # Was the top
				var new_current: TakeoverData = current_takeover
				active_takeover_changed.emit(new_current.type, new_current.node)

			return popped

	push_warning("[TakeoverManager] Takeover type not found: %s" % type)
	return null


## Pop a specific takeover by node reference
## Returns the popped TakeoverData or null if not found
func pop_takeover_by_node(node: Node) -> TakeoverData:
	for i in range(_takeover_stack.size() - 1, -1, -1):
		if _takeover_stack[i].node == node:
			var popped: TakeoverData = _takeover_stack[i]
			_takeover_stack.remove_at(i)

			# Apply new state
			_apply_takeover_state()

			# Emit signals
			takeover_ended.emit(popped.type)

			if _takeover_stack.is_empty():
				all_takeovers_cleared.emit()
			elif i == _takeover_stack.size():  # Was the top
				var new_current: TakeoverData = current_takeover
				active_takeover_changed.emit(new_current.type, new_current.node)

			return popped

	push_warning("[TakeoverManager] Takeover node not found")
	return null


## Clear all takeovers from the stack
func clear_all_takeovers() -> void:
	if _takeover_stack.is_empty():
		return

	var types: Array[String] = []
	for takeover in _takeover_stack:
		types.append(takeover.type)

	_takeover_stack.clear()

	# Apply cleared state
	_apply_takeover_state()

	# Emit signals for each cleared takeover
	for type in types:
		takeover_ended.emit(type)

	all_takeovers_cleared.emit()


# =============================================================================
# PUBLIC API - QUERIES
# =============================================================================

## Check if any takeover is active
func has_takeover() -> bool:
	return not _takeover_stack.is_empty()


## Check if a specific takeover type is active (anywhere in stack)
func has_takeover_type(type: String) -> bool:
	for takeover in _takeover_stack:
		if takeover.type == type:
			return true
	return false


## Check if the current (topmost) takeover is of a specific type
func is_current_type(type: String) -> bool:
	return current_type == type


## Get the stack depth
func get_stack_depth() -> int:
	return _takeover_stack.size()


## Get takeover data by type (returns first match from top)
func get_takeover_by_type(type: String) -> TakeoverData:
	for i in range(_takeover_stack.size() - 1, -1, -1):
		if _takeover_stack[i].type == type:
			return _takeover_stack[i]
	return null


## Check if game tree is paused due to takeovers
func is_game_paused() -> bool:
	for takeover in _takeover_stack:
		if takeover.pauses_game:
			return true
	return false


## Check if input should be blocked for gameplay
func is_input_blocked() -> bool:
	for takeover in _takeover_stack:
		if takeover.blocks_input:
			return true
	return false


# =============================================================================
# PUBLIC API - CONVENIENCE METHODS
# =============================================================================

## Start a dialogue takeover (convenience wrapper)
func start_dialogue(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_DIALOGUE, node, true, true, true, 10, metadata)


## End the current dialogue takeover
func end_dialogue() -> TakeoverData:
	return pop_takeover_by_type(TYPE_DIALOGUE)


## Start a conversation takeover (convenience wrapper)
func start_conversation(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_CONVERSATION, node, true, true, true, 10, metadata)


## End the current conversation takeover
func end_conversation() -> TakeoverData:
	return pop_takeover_by_type(TYPE_CONVERSATION)


## Start a menu takeover (convenience wrapper)
func start_menu(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_MENU, node, true, true, true, 20, metadata)


## End the current menu takeover
func end_menu() -> TakeoverData:
	return pop_takeover_by_type(TYPE_MENU)


## Start a popup takeover (convenience wrapper)
func start_popup(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_POPUP, node, true, true, true, 30, metadata)


## End the current popup takeover
func end_popup() -> TakeoverData:
	return pop_takeover_by_type(TYPE_POPUP)


## Start a cutscene takeover (convenience wrapper)
func start_cutscene(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_CUTSCENE, node, true, false, true, 50, metadata)


## End the current cutscene takeover
func end_cutscene() -> TakeoverData:
	return pop_takeover_by_type(TYPE_CUTSCENE)


## Start a shop takeover (convenience wrapper)
func start_shop(node: Node = null, metadata: Dictionary = {}) -> TakeoverData:
	return push_takeover(TYPE_SHOP, node, true, true, true, 15, metadata)


## End the current shop takeover
func end_shop() -> TakeoverData:
	return pop_takeover_by_type(TYPE_SHOP)


# =============================================================================
# INTERNAL - STATE MANAGEMENT
# =============================================================================

## Apply the combined state of all active takeovers
func _apply_takeover_state() -> void:
	if _takeover_stack.is_empty():
		# No takeovers - restore normal gameplay state
		get_tree().paused = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		# Update GameManager flags
		if GameManager:
			GameManager.is_in_dialogue = false
			GameManager.is_in_menu = false
	else:
		# Apply combined state from all takeovers
		var should_pause: bool = false
		var should_show_mouse: bool = false

		for takeover in _takeover_stack:
			if takeover.pauses_game:
				should_pause = true
			if takeover.captures_mouse:
				should_show_mouse = true

		get_tree().paused = should_pause

		if should_show_mouse:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

		# Update GameManager flags based on current takeover
		if GameManager:
			var current := current_takeover
			if current:
				GameManager.is_in_dialogue = (current.type == TYPE_DIALOGUE or current.type == TYPE_CONVERSATION)
				GameManager.is_in_menu = (current.type == TYPE_MENU or current.type == TYPE_POPUP or current.type == TYPE_SHOP)


# =============================================================================
# INPUT ROUTING
# =============================================================================

## Route an input event to the active takeover
## Returns true if the input was handled
func route_input(event: InputEvent) -> bool:
	if _takeover_stack.is_empty():
		return false

	var current := current_takeover
	if not current:
		return false

	# If the takeover has a node with _takeover_input, call it
	if current.node and current.node.has_method("_takeover_input"):
		return current.node._takeover_input(event)

	return false


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Serialize state for saving (usually just clear on load)
func to_dict() -> Dictionary:
	# Don't save takeover state - UI should be closed on save/load
	return {}


## Deserialize state from save
func from_dict(_data: Dictionary) -> void:
	# Clear any active takeovers when loading
	clear_all_takeovers()


## Reset for new game
func reset_for_new_game() -> void:
	clear_all_takeovers()
