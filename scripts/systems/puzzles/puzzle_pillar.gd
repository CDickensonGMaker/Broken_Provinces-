## puzzle_pillar.gd - Activatable/destroyable pillar element for sequence puzzles
## Emits glow when touched, can be part of ordered sequence puzzles
## Visual feedback via emission color and optional particles
class_name PuzzlePillar
extends PuzzleElement

signal pillar_touched(pillar: PuzzlePillar)

## Emission colors for different states
@export_group("Visual")
@export var glow_color_inactive: Color = Color(0.3, 0.3, 0.4)
@export var glow_color_active: Color = Color(0.2, 0.8, 1.0)
@export var glow_color_error: Color = Color(1.0, 0.2, 0.2)
@export var pillar_height: float = 2.0
@export var pillar_radius: float = 0.3

## Audio
@export_group("Audio")
@export var activation_sound: String = "puzzle_activate"
@export var error_sound: String = "puzzle_error"

## Sequence puzzle support
@export_group("Sequence")
## Index in the puzzle sequence (-1 = not part of a sequence)
@export var sequence_index: int = -1

## Internal references
var _mesh: MeshInstance3D
var _glow_material: StandardMaterial3D
var _audio_player: AudioStreamPlayer3D
var _collision_shape: CollisionShape3D
var _interaction_area: Area3D


func _ready() -> void:
	super._ready()
	_setup_collision()
	_setup_visual()
	_setup_audio()
	_setup_interaction_area()


func _setup_collision() -> void:
	## Create collision shape for physics
	_collision_shape = CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = pillar_radius
	cylinder.height = pillar_height
	_collision_shape.shape = cylinder
	_collision_shape.position = Vector3(0, pillar_height / 2.0, 0)
	add_child(_collision_shape)

	collision_layer = 1  # World layer
	collision_mask = 0


func _setup_visual() -> void:
	## Check for existing mesh or create one
	_mesh = get_node_or_null("MeshInstance3D")

	if not _mesh:
		_mesh = MeshInstance3D.new()
		_mesh.name = "MeshInstance3D"

		var cylinder := CylinderMesh.new()
		cylinder.top_radius = pillar_radius
		cylinder.bottom_radius = pillar_radius * 1.1  # Slightly wider base
		cylinder.height = pillar_height
		_mesh.mesh = cylinder
		_mesh.position = Vector3(0, pillar_height / 2.0, 0)
		add_child(_mesh)

	## Create or duplicate glow material
	if _mesh.material_override:
		_glow_material = _mesh.material_override.duplicate()
	else:
		_glow_material = StandardMaterial3D.new()
		_glow_material.albedo_color = Color(0.4, 0.4, 0.5)
		_glow_material.roughness = 0.7

	_mesh.material_override = _glow_material
	_set_glow_color(glow_color_inactive)


func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)


func _setup_interaction_area() -> void:
	## Create Area3D for player interaction detection
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 256  # Layer 9 for interactables
	_interaction_area.collision_mask = 0
	add_child(_interaction_area)

	var area_shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = pillar_radius + 0.3
	cylinder.height = pillar_height + 0.2
	area_shape.shape = cylinder
	area_shape.position = Vector3(0, pillar_height / 2.0, 0)
	_interaction_area.add_child(area_shape)


## Set the emission color for glow effect
func _set_glow_color(color: Color) -> void:
	if _glow_material:
		_glow_material.emission = color
		_glow_material.emission_enabled = true
		_glow_material.emission_energy_multiplier = 1.5


## Override interact - let room controller decide if valid for sequences
func interact(interactor: Node) -> void:
	pillar_touched.emit(self)

	# Let room controller validate sequence if present
	if _room_controller and _room_controller.has_method("on_pillar_touched"):
		_room_controller.on_pillar_touched(self)
	else:
		# No controller, just activate
		activate()


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_activated:
		return element_name + " (Glowing)"
	return "Touch " + element_name


## Called when activated - show active glow and play sound
func _on_activated() -> void:
	_set_glow_color(glow_color_active)

	if AudioManager and activation_sound != "":
		AudioManager.play_sfx(activation_sound)

	# Trigger particles if available
	var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
	if particles:
		particles.emitting = true


## Called when deactivated - return to inactive glow
func _on_deactivated() -> void:
	_set_glow_color(glow_color_inactive)

	var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
	if particles:
		particles.emitting = false


## Show error state (wrong sequence)
func show_error() -> void:
	_set_glow_color(glow_color_error)

	if AudioManager and error_sound != "":
		AudioManager.play_sfx(error_sound)

	# Flash back to inactive after delay
	await get_tree().create_timer(0.5).timeout
	if not is_activated:
		_set_glow_color(glow_color_inactive)


## Reset to initial state
func _on_reset() -> void:
	_set_glow_color(glow_color_inactive)

	var particles: GPUParticles3D = get_node_or_null("GPUParticles3D")
	if particles:
		particles.emitting = false


## Static factory for spawning pillars
static func spawn_pillar(
	parent: Node,
	pos: Vector3,
	p_element_id: String = "",
	p_sequence_index: int = -1,
	p_height: float = 2.0
) -> PuzzlePillar:
	var pillar := PuzzlePillar.new()
	pillar.position = pos
	pillar.element_id = p_element_id
	pillar.element_name = "Crystal Pillar"
	pillar.sequence_index = p_sequence_index
	pillar.pillar_height = p_height

	parent.add_child(pillar)
	return pillar
