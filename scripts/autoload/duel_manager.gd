## duel_manager.gd - Manages NPC duels (non-lethal combat)
## Used for: Adventurers Quest 13, Mercenary Quest 13, Mage Quest 13, Thieves Quest 8
## Features: Non-lethal combat, yield detection, arena boundaries, quest integration
extends Node

## Duel state enum
enum DuelState {
	INACTIVE,      ## No duel in progress
	ACTIVE,        ## Duel is ongoing
	PLAYER_WON,    ## Player won (opponent yielded)
	PLAYER_LOST,   ## Player yielded or was defeated
	DRAW           ## Both combatants yielded simultaneously (rare)
}

## Duel result for callbacks
enum DuelResult {
	PLAYER_VICTORY,
	PLAYER_DEFEAT,
	DRAW,
	CANCELLED
}

## Signals for quest integration and UI
signal duel_started(opponent: Node, duel_id: String)
signal duel_ended(result: int, opponent: Node, duel_id: String)  ## result is DuelResult enum value
signal opponent_yielded(opponent: Node, duel_id: String)
signal player_yielded(duel_id: String)
signal duel_hp_changed(entity: Node, current_hp: int, max_hp: int, hp_percent: float)

## Current duel state
var current_state: DuelState = DuelState.INACTIVE
var duel_id: String = ""  ## Unique ID for quest tracking

## Combatants
var player: Node = null
var opponent: Node = null

## Duel configuration
var yield_threshold: float = 0.2  ## HP percentage at which opponent yields (20% default)
var player_yield_threshold: float = 0.1  ## HP percentage at which player auto-yields (10%)
var duel_center: Vector3 = Vector3.ZERO
var duel_radius: float = 15.0  ## Boundary radius from duel center

## Arena boundary (created at runtime)
var arena_barrier: StaticBody3D = null
var barrier_height: float = 10.0

## Original HP values (for restoration after duel)
var _opponent_original_hp: int = 0
var _opponent_original_max_hp: int = 0
var _player_original_hp: int = 0

## Track if we're intercepting damage
var _is_intercepting_damage: bool = false


func _ready() -> void:
	# Connect to scene manager to clean up on scene change
	if SceneManager:
		SceneManager.scene_load_started.connect(_on_scene_load_started)


## Called when a scene change begins - clean up duel state
func _on_scene_load_started(_scene_path: String) -> void:
	if current_state == DuelState.ACTIVE:
		# Force end duel as cancelled
		_end_duel(DuelResult.CANCELLED)
	_clear_state()


## Clear all state
func _clear_state() -> void:
	current_state = DuelState.INACTIVE
	duel_id = ""
	player = null
	opponent = null
	_opponent_original_hp = 0
	_opponent_original_max_hp = 0
	_player_original_hp = 0
	_is_intercepting_damage = false

	if arena_barrier and is_instance_valid(arena_barrier):
		arena_barrier.queue_free()
	arena_barrier = null


## Start a duel between the player and an NPC
## Returns true if duel started successfully
func start_duel(
	opponent_node: Node,
	p_duel_id: String = "",
	p_yield_threshold: float = 0.2,
	p_duel_center: Vector3 = Vector3.ZERO,
	p_duel_radius: float = 15.0,
	create_barrier: bool = true
) -> bool:
	if current_state == DuelState.ACTIVE:
		push_warning("[DuelManager] Cannot start duel - already in a duel")
		return false

	if not is_instance_valid(opponent_node):
		push_error("[DuelManager] Invalid opponent node")
		return false

	# Get player reference
	player = get_tree().get_first_node_in_group("player")
	if not player:
		push_error("[DuelManager] Cannot find player")
		return false

	opponent = opponent_node
	duel_id = p_duel_id if not p_duel_id.is_empty() else "duel_%d" % Time.get_ticks_msec()
	yield_threshold = p_yield_threshold

	# Determine duel center (midpoint between combatants if not specified)
	if p_duel_center == Vector3.ZERO:
		if opponent is Node3D and player is Node3D:
			duel_center = (opponent.global_position + player.global_position) / 2.0
		else:
			duel_center = Vector3.ZERO
	else:
		duel_center = p_duel_center

	duel_radius = p_duel_radius

	# Store original HP values
	_store_original_hp()

	# Create arena barrier if requested
	if create_barrier:
		_create_duel_barrier()

	# Mark opponent as in duel (for AI behavior)
	if opponent.has_method("set_in_duel"):
		opponent.set_in_duel(true)
	opponent.set_meta("in_duel", true)

	# Enter active state
	current_state = DuelState.ACTIVE
	_is_intercepting_damage = true

	# Emit signal
	duel_started.emit(opponent, duel_id)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var opponent_name: String = _get_opponent_name()
		hud.show_notification("DUEL STARTED: %s" % opponent_name)

	print("[DuelManager] Duel started with %s (ID: %s)" % [_get_opponent_name(), duel_id])
	return true


## Store original HP values for restoration
func _store_original_hp() -> void:
	# Store opponent HP
	if opponent:
		if "current_hp" in opponent:
			_opponent_original_hp = opponent.current_hp
		if "max_hp" in opponent:
			_opponent_original_max_hp = opponent.max_hp

	# Store player HP
	if GameManager and GameManager.player_data:
		_player_original_hp = GameManager.player_data.current_hp


## Get opponent's display name
func _get_opponent_name() -> String:
	if not is_instance_valid(opponent):
		return "Unknown"

	if "display_name" in opponent:
		return str(opponent.display_name)
	if opponent.has_method("get_display_name"):
		return opponent.get_display_name()
	if opponent.has_method("get_enemy_data"):
		var data = opponent.get_enemy_data()
		if data and "display_name" in data:
			return data.display_name
	return opponent.name


## Create invisible barrier around duel area
func _create_duel_barrier() -> void:
	if arena_barrier and is_instance_valid(arena_barrier):
		arena_barrier.queue_free()

	arena_barrier = StaticBody3D.new()
	arena_barrier.name = "DuelBarrier"
	arena_barrier.global_position = duel_center
	arena_barrier.collision_layer = 1
	arena_barrier.collision_mask = 0

	# Create 4 walls forming a square boundary
	var barrier_thickness: float = 1.0

	# North wall
	_add_barrier_wall(arena_barrier,
		Vector3(0, barrier_height / 2, -duel_radius),
		Vector3(duel_radius * 2, barrier_height, barrier_thickness))

	# South wall
	_add_barrier_wall(arena_barrier,
		Vector3(0, barrier_height / 2, duel_radius),
		Vector3(duel_radius * 2, barrier_height, barrier_thickness))

	# East wall
	_add_barrier_wall(arena_barrier,
		Vector3(duel_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, duel_radius * 2))

	# West wall
	_add_barrier_wall(arena_barrier,
		Vector3(-duel_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, duel_radius * 2))

	# Add to scene tree
	get_tree().current_scene.add_child(arena_barrier)


## Add a wall segment to the barrier
func _add_barrier_wall(parent: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)


## Check if duel is currently active
func is_duel_active() -> bool:
	return current_state == DuelState.ACTIVE


## Process damage during a duel - call this from damage handlers
## Returns the clamped damage amount (prevents lethal damage)
func process_duel_damage(target: Node, damage: int, damage_type: Enums.DamageType, attacker: Node) -> int:
	if current_state != DuelState.ACTIVE:
		return damage  # Not in duel, return original damage

	if not _is_intercepting_damage:
		return damage

	# Check if target is one of the combatants
	var is_player_hit: bool = target == player or target.is_in_group("player")
	var is_opponent_hit: bool = target == opponent

	if not is_player_hit and not is_opponent_hit:
		return damage  # Not a duel combatant, return original damage

	# Get target's current and max HP
	var current_hp: int = 0
	var max_hp: int = 1

	if is_player_hit:
		if GameManager and GameManager.player_data:
			current_hp = GameManager.player_data.current_hp
			max_hp = GameManager.player_data.max_hp
	else:
		if "current_hp" in target:
			current_hp = target.current_hp
		if "max_hp" in target:
			max_hp = target.max_hp

	# Calculate HP after damage
	var hp_after_damage: int = current_hp - damage
	var hp_percent_after: float = float(hp_after_damage) / float(max_hp)

	# Determine yield threshold for this target
	var threshold: float = player_yield_threshold if is_player_hit else yield_threshold

	# Check if this would cause yielding
	if hp_percent_after <= threshold:
		# Clamp damage to leave target at 1 HP (non-lethal)
		var clamped_damage: int = maxi(0, current_hp - 1)

		# Trigger yield
		if is_player_hit:
			_on_player_yields()
		else:
			_on_opponent_yields()

		return clamped_damage

	# Emit HP changed signal
	var hp_percent: float = float(current_hp - damage) / float(max_hp)
	duel_hp_changed.emit(target, current_hp - damage, max_hp, hp_percent)

	return damage


## Called when opponent yields (HP below threshold)
func _on_opponent_yields() -> void:
	if current_state != DuelState.ACTIVE:
		return

	print("[DuelManager] Opponent %s yields!" % _get_opponent_name())

	# Emit yield signal
	opponent_yielded.emit(opponent, duel_id)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("%s YIELDS!" % _get_opponent_name().to_upper())

	# End duel with player victory
	_end_duel(DuelResult.PLAYER_VICTORY)


## Called when player yields (HP below threshold)
func _on_player_yields() -> void:
	if current_state != DuelState.ACTIVE:
		return

	print("[DuelManager] Player yields!")

	# Emit yield signal
	player_yielded.emit(duel_id)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("YOU YIELD!")

	# End duel with player defeat
	_end_duel(DuelResult.PLAYER_DEFEAT)


## Manually trigger player yield (e.g., from a "Yield" button)
func player_surrender() -> void:
	if current_state != DuelState.ACTIVE:
		return

	_on_player_yields()


## End the duel
func _end_duel(result: DuelResult) -> void:
	if current_state == DuelState.INACTIVE:
		return

	_is_intercepting_damage = false

	# Update state based on result
	match result:
		DuelResult.PLAYER_VICTORY:
			current_state = DuelState.PLAYER_WON
		DuelResult.PLAYER_DEFEAT:
			current_state = DuelState.PLAYER_LOST
		DuelResult.DRAW:
			current_state = DuelState.DRAW
		DuelResult.CANCELLED:
			current_state = DuelState.INACTIVE

	# Remove duel marker from opponent
	if is_instance_valid(opponent):
		if opponent.has_method("set_in_duel"):
			opponent.set_in_duel(false)
		opponent.remove_meta("in_duel")

		# Stop opponent from attacking
		if opponent.has_method("_change_state"):
			# Make opponent go idle
			opponent._change_state(0)  # AIState.IDLE

	# Remove barrier
	if arena_barrier and is_instance_valid(arena_barrier):
		arena_barrier.queue_free()
		arena_barrier = null

	# Emit end signal
	duel_ended.emit(result, opponent, duel_id)

	# Update quest progress if applicable
	_update_quest_progress(result)

	# Show result notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		match result:
			DuelResult.PLAYER_VICTORY:
				hud.show_notification("DUEL WON!")
			DuelResult.PLAYER_DEFEAT:
				hud.show_notification("DUEL LOST!")
			DuelResult.DRAW:
				hud.show_notification("DUEL - DRAW!")

	print("[DuelManager] Duel ended: %s (ID: %s)" % [DuelResult.keys()[result], duel_id])


## Update quest progress based on duel result
func _update_quest_progress(result: DuelResult) -> void:
	if duel_id.is_empty():
		return

	if not QuestManager:
		return

	# For player victories, update "duel_win" type objectives
	if result == DuelResult.PLAYER_VICTORY:
		QuestManager.update_progress("duel_win", duel_id, 1)

		# Also try with opponent ID if available
		if is_instance_valid(opponent):
			var opponent_id: String = ""
			if "npc_id" in opponent:
				opponent_id = opponent.npc_id
			elif opponent.has_method("get_enemy_data"):
				var data = opponent.get_enemy_data()
				if data and "id" in data:
					opponent_id = data.id

			if not opponent_id.is_empty():
				QuestManager.update_progress("duel_win", opponent_id, 1)


## Cancel the current duel (e.g., if interrupted)
func cancel_duel() -> void:
	if current_state == DuelState.ACTIVE:
		_end_duel(DuelResult.CANCELLED)
	_clear_state()


## Force end duel with a specific result (for scripted events)
func force_end_duel(result: DuelResult) -> void:
	if current_state == DuelState.ACTIVE:
		_end_duel(result)


## Get the current duel state
func get_duel_state() -> DuelState:
	return current_state


## Get current duel result as string
func get_duel_result_string() -> String:
	match current_state:
		DuelState.PLAYER_WON:
			return "victory"
		DuelState.PLAYER_LOST:
			return "defeat"
		DuelState.DRAW:
			return "draw"
		_:
			return "none"


## Check if entity is in the current duel
func is_in_duel(entity: Node) -> bool:
	if current_state != DuelState.ACTIVE:
		return false
	return entity == player or entity == opponent


## Restore opponent HP after duel (optional - for rematches)
func restore_opponent_hp() -> void:
	if is_instance_valid(opponent) and _opponent_original_hp > 0:
		if "current_hp" in opponent:
			opponent.current_hp = _opponent_original_hp
		if "max_hp" in opponent and _opponent_original_max_hp > 0:
			opponent.max_hp = _opponent_original_max_hp


## Get save data for persistence
func get_save_data() -> Dictionary:
	return {
		"last_duel_id": duel_id,
		"last_duel_result": get_duel_result_string()
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	# Duels don't persist across saves - just store history
	pass
