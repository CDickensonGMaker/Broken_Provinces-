## puzzle_crystal.gd - Collectable crystal for puzzle objectives
## One-shot collectable that adds to inventory or triggers quest progress
class_name PuzzleCrystal
extends PuzzleElement

signal crystal_collected(crystal: PuzzleCrystal, collector: Node3D)

## Crystal configuration
@export_group("Crystal")
## Item ID to add to inventory (empty = no inventory item)
@export var item_id: String = ""
## Quantity to add
@export var item_quantity: int = 1
## Quest objective target (for direct quest progress)
@export var quest_objective_target: String = ""

## Visual configuration
@export_group("Visual")
@export var crystal_size: float = 0.3
@export var crystal_color: Color = Color(0.5, 0.3, 1.0)
@export var glow_intensity: float = 2.0
@export var rotation_speed: float = 30.0
@export var bob_amplitude: float = 0.1
@export var bob_speed: float = 2.0

## Audio
@export_group("Audio")
@export var collect_sound: String = "crystal_collect"
@export var ambient_sound: String = "crystal_hum"

## Internal references
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _particles: GPUParticles3D
var _collision_shape: CollisionShape3D
var _interaction_area: Area3D
var _audio_player: AudioStreamPlayer3D
var _original_y: float = 0.0
var _time: float = 0.0
var _is_collected: bool = false


func _ready() -> void:
	## Force one_shot for crystals
	one_shot = true

	super._ready()
	_original_y = position.y
	_setup_collision()
	_setup_visual()
	_setup_particles()
	_setup_interaction_area()
	_setup_audio()


func _process(delta: float) -> void:
	if _is_collected:
		return

	## Rotation animation
	if _mesh:
		_mesh.rotation_degrees.y += rotation_speed * delta

	## Bobbing animation
	_time += delta
	var bob_offset: float = sin(_time * bob_speed) * bob_amplitude
	position.y = _original_y + bob_offset


func _setup_collision() -> void:
	_collision_shape = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = crystal_size * 1.5
	_collision_shape.shape = sphere
	_collision_shape.position = Vector3(0, crystal_size, 0)
	add_child(_collision_shape)

	collision_layer = 1
	collision_mask = 0


func _setup_visual() -> void:
	_mesh = MeshInstance3D.new()
	_mesh.name = "CrystalMesh"

	## Create a diamond-like prism shape
	var prism := PrismMesh.new()
	prism.size = Vector3(crystal_size, crystal_size * 2, crystal_size)
	_mesh.mesh = prism
	_mesh.position = Vector3(0, crystal_size, 0)

	_material = StandardMaterial3D.new()
	_material.albedo_color = crystal_color
	_material.roughness = 0.1
	_material.metallic = 0.3
	_material.emission_enabled = true
	_material.emission = crystal_color
	_material.emission_energy_multiplier = glow_intensity
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color.a = 0.9
	_mesh.material_override = _material

	add_child(_mesh)


func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "CrystalParticles"
	_particles.emitting = true
	_particles.amount = 20
	_particles.lifetime = 1.5
	_particles.position = Vector3(0, crystal_size, 0)

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = crystal_size * 0.5
	material.gravity = Vector3(0, 1, 0)
	material.initial_velocity_min = 0.2
	material.initial_velocity_max = 0.5
	material.scale_min = 0.03
	material.scale_max = 0.08
	material.color = crystal_color
	_particles.process_material = material

	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	_particles.draw_pass_1 = quad

	add_child(_particles)


func _setup_interaction_area() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionArea"
	_interaction_area.collision_layer = 256  # Layer 9 for interactables
	_interaction_area.collision_mask = 0
	add_child(_interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = crystal_size * 2
	area_shape.shape = sphere
	area_shape.position = Vector3(0, crystal_size, 0)
	_interaction_area.add_child(area_shape)


func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)


## Override interact - collect the crystal
func interact(interactor: Node) -> void:
	if _is_collected or is_activated:
		return

	_collect_crystal(interactor)


## Collect the crystal
func _collect_crystal(collector: Node) -> void:
	_is_collected = true

	## Play collect sound
	if AudioManager and collect_sound != "":
		AudioManager.play_sfx(collect_sound)

	## Add to inventory
	if not item_id.is_empty() and InventoryManager:
		InventoryManager.add_item(item_id, item_quantity)

	## Update quest objective
	if not quest_objective_target.is_empty() and QuestManager:
		QuestManager.on_item_collected(quest_objective_target, 1)

	## Emit signal
	crystal_collected.emit(self, collector as Node3D)

	## Play collection animation
	await _play_collect_animation()

	## Activate (triggers connected elements)
	activate()


## Collection animation - shrink and fade
func _play_collect_animation() -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	## Scale down
	tween.tween_property(_mesh, "scale", Vector3.ZERO, 0.3)

	## Fade particles
	if _particles:
		_particles.emitting = false

	## Increase glow briefly
	if _material:
		tween.tween_property(_material, "emission_energy_multiplier", glow_intensity * 3, 0.1)
		tween.chain().tween_property(_material, "emission_energy_multiplier", 0.0, 0.2)

	await tween.finished

	## Hide after animation
	visible = false


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if _is_collected or is_activated:
		return ""
	return "Collect " + element_name


## Called when activated
func _on_activated() -> void:
	_is_collected = true
	visible = false


## Called when deactivated (shouldn't happen for crystals)
func _on_deactivated() -> void:
	pass


## Reset to initial state
func _on_reset() -> void:
	_is_collected = false
	visible = true
	position.y = _original_y
	if _mesh:
		_mesh.scale = Vector3.ONE
	if _particles:
		_particles.emitting = true
	if _material:
		_material.emission_energy_multiplier = glow_intensity


## Override save data
func get_save_data() -> Dictionary:
	var data: Dictionary = super.get_save_data()
	data["is_collected"] = _is_collected
	return data


## Override load data
func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	if data.has("is_collected"):
		_is_collected = data.is_collected
		if _is_collected:
			visible = false
			if _particles:
				_particles.emitting = false


## Static factory for spawning crystals
static func spawn_crystal(
	parent: Node,
	pos: Vector3,
	p_element_id: String = "",
	p_item_id: String = "",
	p_crystal_color: Color = Color(0.5, 0.3, 1.0)
) -> PuzzleCrystal:
	var crystal := PuzzleCrystal.new()
	crystal.position = pos
	crystal.element_id = p_element_id
	crystal.element_name = "Crystal"
	crystal.item_id = p_item_id
	crystal.crystal_color = p_crystal_color

	parent.add_child(crystal)
	return crystal
