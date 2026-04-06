## puzzle_room_controller.gd - Manages puzzle state and validates sequences
## Tracks registered puzzle elements, validates player input sequences,
## and emits completion/failure signals for room-level effects
class_name PuzzleRoomController
extends Node3D

signal puzzle_completed
signal puzzle_failed
signal puzzle_reset
signal sequence_progress(current: int, total: int)

## Puzzle identification
@export_group("Puzzle Info")
@export var puzzle_id: String = ""
@export var puzzle_name: String = "Puzzle Room"
@export var puzzle_description: String = ""

## Sequence puzzle configuration
@export_group("Sequence Settings")
## Expected pillar indices in order (e.g., [0, 2, 1, 3])
@export var required_sequence: Array[int] = []
## If true, wrong input resets the puzzle automatically
@export var auto_reset_on_failure: bool = true
## Delay before auto-reset after failure
@export var reset_delay: float = 1.0

## Completion settings
@export_group("Completion")
## Flag to set in FlagManager when completed
@export var completion_flag: String = ""
## XP awarded on completion
@export var completion_xp: int = 100

## Registered puzzle elements: element_id -> PuzzleElement
var _elements: Dictionary = {}
## Current sequence of touched pillar indices
var _current_sequence: Array[int] = []
## Has the puzzle been completed?
var _is_completed: bool = false
## Is the puzzle locked (during reset animation, etc.)?
var _is_locked: bool = false


func _ready() -> void:
	add_to_group("puzzle_controllers")


## Register a puzzle element with this controller
func register_puzzle_element(element: PuzzleElement) -> void:
	# Auto-generate ID if empty
	if element.element_id.is_empty():
		element.element_id = str(element.get_instance_id())

	_elements[element.element_id] = element
	element.activated.connect(_on_element_activated)


## Get an element by its ID
func get_element_by_id(element_id: String) -> PuzzleElement:
	return _elements.get(element_id)


## Get all registered elements
func get_all_elements() -> Array:
	return _elements.values()


## Called when a pillar is touched - validates sequence
func on_pillar_touched(pillar: PuzzlePillar) -> void:
	if _is_completed or _is_locked:
		return

	# Not a sequence pillar, just activate it
	if pillar.sequence_index < 0:
		pillar.activate()
		return

	# Add to current sequence
	_current_sequence.append(pillar.sequence_index)

	# Check if sequence is correct so far
	if not _is_sequence_valid():
		_on_sequence_failed(pillar)
		return

	# Valid so far - activate the pillar
	pillar.activate()

	# Emit progress signal
	sequence_progress.emit(_current_sequence.size(), required_sequence.size())

	# Check if sequence is complete
	if _current_sequence.size() == required_sequence.size():
		_on_puzzle_completed()


## Check if current sequence matches required sequence so far
func _is_sequence_valid() -> bool:
	for i in range(_current_sequence.size()):
		if i >= required_sequence.size():
			return false
		if _current_sequence[i] != required_sequence[i]:
			return false
	return true


## Called when sequence input is wrong
func _on_sequence_failed(pillar: PuzzlePillar) -> void:
	pillar.show_error()
	puzzle_failed.emit()

	if auto_reset_on_failure:
		_is_locked = true
		await get_tree().create_timer(reset_delay).timeout
		reset_puzzle()
		_is_locked = false


## Called when puzzle is completed successfully
func _on_puzzle_completed() -> void:
	_is_completed = true

	# Set completion flag
	if not completion_flag.is_empty():
		var flag_manager: Node = get_node_or_null("/root/FlagManager")
		if flag_manager and flag_manager.has_method("set_flag"):
			flag_manager.set_flag(completion_flag, true)

	# Award XP
	if completion_xp > 0 and GameManager and GameManager.player_data:
		var xp_with_multiplier: int = int(completion_xp * GameManager.player_data.get_xp_multiplier())
		GameManager.player_data.add_ip(xp_with_multiplier)
		_show_notification("Puzzle completed! (+%d XP)" % xp_with_multiplier)

	# Notify QuestManager for puzzle objectives
	if not puzzle_id.is_empty() and QuestManager:
		QuestManager.on_puzzle_solved(puzzle_id)

	puzzle_completed.emit()


## Called when any element activates
func _on_element_activated(_element: PuzzleElement) -> void:
	# Override for custom behavior
	pass


## Reset the puzzle to initial state
func reset_puzzle() -> void:
	_current_sequence.clear()

	for element in _elements.values():
		if is_instance_valid(element):
			element.reset()

	puzzle_reset.emit()


## Check if puzzle is completed
func is_completed() -> bool:
	return _is_completed


## Get completion progress (0.0 to 1.0)
func get_progress() -> float:
	if required_sequence.is_empty():
		return 1.0 if _is_completed else 0.0
	return float(_current_sequence.size()) / float(required_sequence.size())


## Get current sequence length
func get_current_sequence_length() -> int:
	return _current_sequence.size()


## Get required sequence length
func get_required_sequence_length() -> int:
	return required_sequence.size()


## Show notification to player
func _show_notification(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Get save data for the puzzle
func get_save_data() -> Dictionary:
	var element_states: Dictionary = {}
	for element_id in _elements:
		var element: PuzzleElement = _elements[element_id]
		if is_instance_valid(element):
			element_states[element_id] = element.get_save_data()

	return {
		"puzzle_id": puzzle_id,
		"is_completed": _is_completed,
		"current_sequence": _current_sequence,
		"element_states": element_states
	}


## Load save data for the puzzle
func load_save_data(data: Dictionary) -> void:
	if data.has("is_completed"):
		_is_completed = data.is_completed

	if data.has("current_sequence"):
		_current_sequence.clear()
		for idx in data.current_sequence:
			_current_sequence.append(idx)

	if data.has("element_states"):
		for element_id in data.element_states:
			var element: PuzzleElement = _elements.get(element_id)
			if element and is_instance_valid(element):
				element.load_save_data(data.element_states[element_id])


## Static factory for creating a puzzle room controller
static func create_controller(
	parent: Node,
	p_puzzle_id: String,
	p_puzzle_name: String,
	p_sequence: Array[int] = [],
	p_completion_flag: String = ""
) -> PuzzleRoomController:
	var controller := PuzzleRoomController.new()
	controller.name = "PuzzleController"
	controller.puzzle_id = p_puzzle_id
	controller.puzzle_name = p_puzzle_name
	controller.required_sequence = p_sequence
	controller.completion_flag = p_completion_flag

	parent.add_child(controller)
	return controller
