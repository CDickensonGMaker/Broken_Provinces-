## puzzle_lever.gd - Pull lever to trigger connected elements
## Toggle behavior with animation support for pull up/down states
class_name PuzzleLever
extends PuzzleElement

signal lever_pulled(lever: PuzzleLever, is_up: bool)

## Visual configuration
@export_group("Visual")
@export var lever_height: float = 1.2
@export var lever_base_radius: float = 0.15
@export var lever_handle_length: float = 0.6
@export var color_inactive: Color = Color(0.5, 0.4, 0.35)
@export var color_active: Color = Color(0.8, 0.7, 0.5)

## Audio
@export_group("Audio")
@export var pull_sound: String = "lever_pull"

## Animation
@export_group("Animation")
## Optional AnimationPlayer for custom lever animation
@export var animation_player_path: NodePath = ""
@export var pull_up_anim: String = "pull_up"
@export var pull_down_anim: String = "pull_down"
@export var animation_duration: float = 0.3

## Internal state
var _is_up: bool = false
var _mesh_base: MeshInstance3D
var _mesh_handle: MeshInstance3D
var _material: StandardMaterial3D
var _collision_shape: CollisionShape3D
var _interaction_area: Area3D
var _animation_player: AnimationPlayer
var _is_animating: bool = false


func _ready() -> void:
	super._ready()
	_setup_collision()
	_setup_visual()
	_setup_interaction_area()
	_setup_animation()


func _setup_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(lever_base_radius * 2, lever_height, lever_base_radius * 2)
	_collision_shape.shape = box
	_collision_shape.position = Vector3(0, lever_height / 2.0, 0)
	add_child(_collision_shape)

	collision_layer = 1
	collision_mask = 0


func _setup_visual() -> void:
	## Create material
	_material = StandardMaterial3D.new()
	_material.albedo_color = color_inactive
	_material.roughness = 0.8

	## Base cylinder
	_mesh_base = MeshInstance3D.new()
	_mesh_base.name = "LeverBase"
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = lever_base_radius
	base_mesh.bottom_radius = lever_base_radius * 1.2
	base_mesh.height = lever_height * 0.4
	_mesh_base.mesh = base_mesh
	_mesh_base.position = Vector3(0, lever_height * 0.2, 0)
	_mesh_base.material_override = _material
	add_child(_mesh_base)

	## Handle (the part that moves)
	_mesh_handle = MeshInstance3D.new()
	_mesh_handle.name = "LeverHandle"
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = lever_base_radius * 0.5
	handle_mesh.bottom_radius = lever_base_radius * 0.5
	handle_mesh.height = lever_handle_length
	_mesh_handle.mesh = handle_mesh
	_mesh_handle.position = Vector3(0, lever_height * 0.4 + lever_handle_length * 0.3, 0)
	_mesh_handle.material_override = _material.duplicate()
	## Start tilted back (down position)
	_mesh_handle.rotation_degrees.x = 30
	add_child(_mesh_handle)


func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 256  # Layer 9 for interactables
	_interaction_area.collision_mask = 0
	add_child(_interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(lever_base_radius * 3, lever_height + 0.5, lever_base_radius * 3)
	area_shape.shape = box
	area_shape.position = Vector3(0, lever_height / 2.0, 0)
	_interaction_area.add_child(area_shape)


func _setup_animation() -> void:
	## Try to get external animation player
	if not animation_player_path.is_empty():
		_animation_player = get_node_or_null(animation_player_path) as AnimationPlayer


## Override interact - toggle lever position
func interact(_interactor: Node) -> void:
	if _is_animating:
		return

	if one_shot and is_activated:
		return

	_toggle_lever()


## Toggle lever state with animation
func _toggle_lever() -> void:
	_is_animating = true
	_is_up = not _is_up

	## Play sound
	if AudioManager and pull_sound != "":
		AudioManager.play_sfx(pull_sound)

	## Emit signal
	lever_pulled.emit(self, _is_up)

	## Animate using external player or built-in tween
	if _animation_player:
		var anim_name: String = pull_up_anim if _is_up else pull_down_anim
		if _animation_player.has_animation(anim_name):
			_animation_player.play(anim_name)
			await _animation_player.animation_finished
	else:
		## Built-in tween animation
		var tween := create_tween()
		var target_rotation: float = -30 if _is_up else 30
		tween.tween_property(_mesh_handle, "rotation_degrees:x", target_rotation, animation_duration)
		await tween.finished

	_is_animating = false

	## Activate or deactivate based on state
	if _is_up:
		activate()
	else:
		deactivate()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if _is_animating:
		return ""  # Don't show prompt during animation
	if _is_up:
		return "Pull " + element_name + " Down"
	return "Pull " + element_name + " Up"


## Called when activated
func _on_activated() -> void:
	if _material:
		_material.albedo_color = color_active
	if _mesh_handle and _mesh_handle.material_override:
		(_mesh_handle.material_override as StandardMaterial3D).albedo_color = color_active


## Called when deactivated
func _on_deactivated() -> void:
	if _material:
		_material.albedo_color = color_inactive
	if _mesh_handle and _mesh_handle.material_override:
		(_mesh_handle.material_override as StandardMaterial3D).albedo_color = color_inactive


## Reset to initial state
func _on_reset() -> void:
	_is_up = false
	if _mesh_handle:
		_mesh_handle.rotation_degrees.x = 30
	if _material:
		_material.albedo_color = color_inactive
	if _mesh_handle and _mesh_handle.material_override:
		(_mesh_handle.material_override as StandardMaterial3D).albedo_color = color_inactive


## Override save data
func get_save_data() -> Dictionary:
	var data: Dictionary = super.get_save_data()
	data["is_up"] = _is_up
	return data


## Override load data
func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("is_up"):
		_is_up = data.is_up
		if _mesh_handle:
			_mesh_handle.rotation_degrees.x = -30 if _is_up else 30


## Static factory for spawning levers
static func spawn_lever(
	parent: Node,
	pos: Vector3,
	p_element_id: String = "",
	p_element_name: String = "Lever",
	p_one_shot: bool = false
) -> PuzzleLever:
	var lever := PuzzleLever.new()
	lever.position = pos
	lever.element_id = p_element_id
	lever.element_name = p_element_name
	lever.one_shot = p_one_shot

	parent.add_child(lever)
	return lever
