## puzzle_pressure_plate.gd - Step on plate to activate, step off to deactivate
## Uses Area3D for detecting player presence
class_name PuzzlePressurePlate
extends PuzzleElement

signal plate_pressed(plate: PuzzlePressurePlate)
signal plate_released(plate: PuzzlePressurePlate)

## Visual configuration
@export_group("Visual")
@export var plate_size: Vector2 = Vector2(1.5, 1.5)
@export var plate_height: float = 0.1
@export var pressed_offset: float = 0.05
@export var color_inactive: Color = Color(0.4, 0.4, 0.45)
@export var color_active: Color = Color(0.6, 0.8, 0.5)

## Audio
@export_group("Audio")
@export var press_sound: String = "plate_press"
@export var release_sound: String = "plate_release"

## Behavior
@export_group("Behavior")
## If true, plate stays activated once pressed (ignores release)
@export var stay_pressed: bool = false
## Minimum weight required (player is always heavy enough, used for objects)
@export var weight_threshold: float = 1.0

## Internal references
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _collision_shape: CollisionShape3D
var _detection_area: Area3D
var _entities_on_plate: Array[Node] = []
var _original_y: float = 0.0


func _ready() -> void:
	super._ready()
	_original_y = position.y
	_setup_collision()
	_setup_visual()
	_setup_detection_area()


func _setup_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(plate_size.x, plate_height, plate_size.y)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0, plate_height / 2.0, 0)
	add_child(_collision_shape)

	collision_layer = 1
	collision_mask = 0


func _setup_visual() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "PlateMesh"

	var box := BoxMesh.new()
	box.size = Vector3(plate_size.x, plate_height, plate_size.y)
	_mesh.mesh = box
	_mesh.position = Vector3(0, plate_height / 2.0, 0)

	_material = StandardMaterial3D.new()
	_material.albedo_color = color_inactive
	_material.roughness = 0.6
	_mesh.material_override = _material

	add_child(_mesh)


func _setup_detection_area() -> void:
	_detection_area = Area3D.new()
	_detection_area.name = "DetectionArea"
	_detection_area.collision_layer = 0
	_detection_area.collision_mask = 2 + 4  # Player (2) and NPC (4) layers
	add_child(_detection_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	## Detection box is slightly larger and taller than the plate
	box.size = Vector3(plate_size.x * 0.9, 1.0, plate_size.y * 0.9)
	area_shape.shape = box
	area_shape.position = Vector3(0, 0.5 + plate_height, 0)
	_detection_area.add_child(area_shape)

	_detection_area.body_entered.connect(_on_body_entered)
	_detection_area.body_exited.connect(_on_body_exited)


## Called when a body enters the detection area
func _on_body_entered(body: Node3D) -> void:
	## Check if this is a valid entity (player or weighted object)
	if not _is_valid_weight(body):
		return

	if body not in _entities_on_plate:
		_entities_on_plate.append(body)

	## First entity activates the plate
	if _entities_on_plate.size() == 1:
		_press_plate()


## Called when a body exits the detection area
func _on_body_exited(body: Node3D) -> void:
	_entities_on_plate.erase(body)

	## Last entity leaves - release the plate (unless stay_pressed is true)
	if _entities_on_plate.is_empty() and is_activated:
		if not stay_pressed and not one_shot:
			_release_plate()


## Check if body has enough weight to trigger the plate
func _is_valid_weight(body: Node3D) -> bool:
	## Player always triggers
	if body.is_in_group("player"):
		return true

	## Check for weight property on other objects
	var weight: float = body.get("weight") if "weight" in body else 0.0
	return weight >= weight_threshold


## Press the plate down
func _press_plate() -> void:
	plate_pressed.emit(self)

	## Play sound
	if AudioManager and press_sound != "":
		AudioManager.play_sfx(press_sound)

	## Animate pressing down
	var tween := create_tween()
	tween.tween_property(self, "position:y", _original_y - pressed_offset, 0.1)

	activate()


## Release the plate
func _release_plate() -> void:
	plate_released.emit(self)

	## Play sound
	if AudioManager and release_sound != "":
		AudioManager.play_sfx(release_sound)

	## Animate raising up
	var tween := create_tween()
	tween.tween_property(self, "position:y", _original_y, 0.1)

	deactivate()


## Called when activated
func _on_activated() -> void:
	if _material:
		_material.albedo_color = color_active


## Called when deactivated
func _on_deactivated() -> void:
	if _material:
		_material.albedo_color = color_inactive


## Reset to initial state
func _on_reset() -> void:
	_entities_on_plate.clear()
	position.y = _original_y
	if _material:
		_material.albedo_color = color_inactive


## Interaction is not typically used for pressure plates (auto-trigger)
func interact(_interactor: Node) -> void:
	pass  # Pressure plates are passive


## Get display name for interaction prompt (not typically shown)
func get_interaction_prompt() -> String:
	return ""  # No interaction prompt for pressure plates


## Override save data
func get_save_data() -> Dictionary:
	var data: Dictionary = super.get_save_data()
	data["original_y"] = _original_y
	return data


## Override load data
func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("original_y"):
		_original_y = data.original_y
	## Restore visual state
	if is_activated:
		position.y = _original_y - pressed_offset
	else:
		position.y = _original_y


## Static factory for spawning pressure plates
static func spawn_pressure_plate(
	parent: Node,
	pos: Vector3,
	p_element_id: String = "",
	p_plate_size: Vector2 = Vector2(1.5, 1.5),
	p_stay_pressed: bool = false
) -> PuzzlePressurePlate:
	var plate := PuzzlePressurePlate.new()
	plate.position = pos
	plate.element_id = p_element_id
	plate.element_name = "Pressure Plate"
	plate.plate_size = p_plate_size
	plate.stay_pressed = p_stay_pressed

	parent.add_child(plate)
	return plate
