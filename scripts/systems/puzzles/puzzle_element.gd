## puzzle_element.gd - Base class for interactive puzzle elements
## Provides activation/deactivation system with chaining support
## Puzzle elements can trigger other elements via target_element_ids
class_name PuzzleElement
extends StaticBody3D

signal activated(element: PuzzleElement)
signal deactivated(element: PuzzleElement)

## Unique identifier for this element within the puzzle room
@export var element_id: String = ""
## Display name for interaction prompts
@export var element_name: String = "Puzzle Element"
## IDs of elements to trigger when this element activates
@export var target_element_ids: Array[String] = []
## Delay before triggering connected elements
@export var activation_delay: float = 0.0
## If true, element can only be activated once
@export var one_shot: bool = false

## Current activation state
var is_activated: bool = false
## Reference to parent room controller (auto-detected)
var _room_controller: Node = null


func _ready() -> void:
	add_to_group("puzzle_elements")
	add_to_group("interactable")
	_find_room_controller()


## Traverse up the scene tree to find a PuzzleRoomController
func _find_room_controller() -> void:
	var parent: Node = get_parent()
	while parent:
		if parent.has_method("register_puzzle_element"):
			_room_controller = parent
			_room_controller.register_puzzle_element(self)
			break
		parent = parent.get_parent()


## Called by player interaction system - override in subclasses
func interact(_interactor: Node) -> void:
	pass


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_activated:
		return element_name + " (Active)"
	return "Activate " + element_name


## Activate this element
func activate() -> void:
	if one_shot and is_activated:
		return

	is_activated = true
	_on_activated()
	activated.emit(self)

	if activation_delay > 0:
		await get_tree().create_timer(activation_delay).timeout

	_trigger_connected_elements()


## Deactivate this element (ignored for one_shot elements)
func deactivate() -> void:
	if one_shot:
		return

	is_activated = false
	_on_deactivated()
	deactivated.emit(self)


## Called when element is activated - override for visual/audio feedback
func _on_activated() -> void:
	pass


## Called when element is deactivated - override for visual/audio feedback
func _on_deactivated() -> void:
	pass


## Trigger all connected elements via room controller
func _trigger_connected_elements() -> void:
	if not _room_controller:
		return

	for target_id in target_element_ids:
		var target: PuzzleElement = _room_controller.get_element_by_id(target_id)
		if target and target.has_method("activate"):
			target.activate()


## Reset element to initial state
func reset() -> void:
	is_activated = false
	_on_reset()


## Called when element is reset - override for custom reset behavior
func _on_reset() -> void:
	pass


## Get save data for this element
func get_save_data() -> Dictionary:
	return {
		"element_id": element_id,
		"is_activated": is_activated
	}


## Load save data for this element
func load_save_data(data: Dictionary) -> void:
	if data.has("is_activated"):
		is_activated = data.is_activated
		if is_activated:
			_on_activated()
		else:
			_on_deactivated()
