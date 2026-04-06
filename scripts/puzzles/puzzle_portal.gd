## puzzle_portal.gd - Teleport player to destination or trigger trap effect
## Visual portal with particle/shader effects
class_name PuzzlePortal
extends PuzzleElement

signal portal_entered(portal: PuzzlePortal, entity: Node3D)
signal portal_teleported(portal: PuzzlePortal, destination: Vector3)

## Destination configuration
@export_group("Destination")
## Scene to load (leave empty for same-scene teleport)
@export_file("*.tscn") var destination_scene: String = ""
## Position to teleport to within the scene
@export var destination_position: Vector3 = Vector3.ZERO
## Spawn point ID in destination scene (for doors/spawn system)
@export var destination_spawn_id: String = "default"

## Trap configuration
@export_group("Trap")
## If true, this portal is a trap (damage, status effect, etc.)
@export var is_trap: bool = false
## Damage dealt on trap activation
@export var trap_damage: int = 20
## Status effect to apply (empty = none)
@export var trap_status_effect: String = ""

## Visual configuration
@export_group("Visual")
@export var portal_radius: float = 1.0
@export var portal_height: float = 2.5
@export var portal_color: Color = Color(0.3, 0.6, 1.0, 0.8)
@export var trap_color: Color = Color(1.0, 0.2, 0.2, 0.8)

## Audio
@export_group("Audio")
@export var ambient_sound: String = "portal_hum"
@export var teleport_sound: String = "portal_teleport"
@export var trap_sound: String = "trap_trigger"

## Internal references
var _portal_area: Area3D
var _particles: GPUParticles3D
var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _audio_player: AudioStreamPlayer3D
var _cooldown_timer: float = 0.0
const COOLDOWN_DURATION: float = 1.0


func _ready() -> void:
	super._ready()
	_setup_visual()
	_setup_portal_area()
	_setup_particles()
	_setup_audio()


func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta


func _setup_visual() -> void:
	## Create portal ring/frame
	_mesh = MeshInstance3D.new()
	_mesh.name = "PortalMesh"

	var torus := TorusMesh.new()
	torus.inner_radius = portal_radius * 0.9
	torus.outer_radius = portal_radius
	torus.rings = 16
	torus.ring_segments = 32
	_mesh.mesh = torus
	_mesh.position = Vector3(0, portal_height / 2.0, 0)
	_mesh.rotation_degrees.x = 90

	_material = StandardMaterial3D.new()
	_material.albedo_color = trap_color if is_trap else portal_color
	_material.emission_enabled = true
	_material.emission = trap_color if is_trap else portal_color
	_material.emission_energy_multiplier = 2.0
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _material

	add_child(_mesh)

	## Create inner portal plane (the "surface" you walk through)
	var inner_mesh := MeshInstance3D.new()
	inner_mesh.name = "PortalSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(portal_radius * 1.8, portal_height * 0.9)
	inner_mesh.mesh = plane
	inner_mesh.position = Vector3(0, portal_height / 2.0, 0)
	inner_mesh.rotation_degrees.x = 90

	var inner_material := StandardMaterial3D.new()
	inner_material.albedo_color = Color(0, 0, 0, 0.6)
	inner_material.emission_enabled = true
	inner_material.emission = (trap_color if is_trap else portal_color) * 0.5
	inner_material.emission_energy_multiplier = 1.0
	inner_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	inner_mesh.material_override = inner_material

	add_child(inner_mesh)


func _setup_portal_area() -> void:
	_portal_area = Area3D.new()
	_portal_area.name = "PortalArea"
	_portal_area.collision_layer = 0
	_portal_area.collision_mask = 2  # Player layer
	add_child(_portal_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(portal_radius * 0.5, portal_height, 0.5)
	area_shape.shape = box
	area_shape.position = Vector3(0, portal_height / 2.0, 0)
	_portal_area.add_child(area_shape)

	_portal_area.body_entered.connect(_on_body_entered)


func _setup_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "PortalParticles"
	_particles.emitting = true
	_particles.amount = 50
	_particles.lifetime = 2.0
	_particles.position = Vector3(0, portal_height / 2.0, 0)

	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3(0, 0, 1)
	material.emission_ring_height = portal_height * 0.8
	material.emission_ring_radius = portal_radius * 0.8
	material.emission_ring_inner_radius = portal_radius * 0.5
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 0.5
	material.initial_velocity_max = 1.5
	material.direction = Vector3(0, 0, 1)
	material.spread = 20.0
	material.scale_min = 0.05
	material.scale_max = 0.15
	material.color = trap_color if is_trap else portal_color
	_particles.process_material = material

	## Simple quad mesh for particles
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	_particles.draw_pass_1 = quad

	add_child(_particles)


func _setup_audio() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "AudioPlayer"
	add_child(_audio_player)


## Called when player enters portal
func _on_body_entered(body: Node3D) -> void:
	if _cooldown_timer > 0:
		return

	if not body.is_in_group("player"):
		return

	_cooldown_timer = COOLDOWN_DURATION
	portal_entered.emit(self, body)

	if is_trap:
		_trigger_trap(body)
	else:
		_teleport_player(body)


## Trigger trap effect
func _trigger_trap(player: Node3D) -> void:
	## Play trap sound
	if AudioManager and trap_sound != "":
		AudioManager.play_sfx(trap_sound)

	## Deal damage
	if trap_damage > 0 and player.has_method("take_damage"):
		player.take_damage(trap_damage)
	elif trap_damage > 0 and GameManager and GameManager.player_data:
		GameManager.player_data.take_damage(trap_damage)

	## Apply status effect
	if trap_status_effect != "" and player.has_method("apply_status"):
		player.apply_status(trap_status_effect)

	## Flash portal red
	_flash_portal(trap_color)

	## Activate connected elements (trap chain)
	activate()


## Teleport player to destination
func _teleport_player(player: Node3D) -> void:
	## Play teleport sound
	if AudioManager and teleport_sound != "":
		AudioManager.play_sfx(teleport_sound)

	## Flash portal
	_flash_portal(portal_color)

	if destination_scene.is_empty():
		## Same-scene teleport
		if destination_position != Vector3.ZERO:
			player.global_position = destination_position
			portal_teleported.emit(self, destination_position)
	else:
		## Cross-scene teleport via SceneManager
		if SceneManager:
			SceneManager.goto_scene(destination_scene, destination_spawn_id)
		portal_teleported.emit(self, destination_position)

	activate()


## Visual flash effect
func _flash_portal(color: Color) -> void:
	if not _material:
		return

	var original_energy: float = _material.emission_energy_multiplier
	var tween := create_tween()
	tween.tween_property(_material, "emission_energy_multiplier", 5.0, 0.1)
	tween.tween_property(_material, "emission_energy_multiplier", original_energy, 0.3)


## Override interact - allow manual activation
func interact(interactor: Node) -> void:
	if _cooldown_timer > 0:
		return

	if interactor.is_in_group("player"):
		_on_body_entered(interactor as Node3D)


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_trap:
		return "Enter " + element_name + " (Unstable)"
	return "Enter " + element_name


## Called when activated
func _on_activated() -> void:
	## Increase particle emission
	if _particles:
		_particles.amount = 100


## Called when deactivated
func _on_deactivated() -> void:
	if _particles:
		_particles.amount = 50


## Reset to initial state
func _on_reset() -> void:
	_cooldown_timer = 0.0
	if _particles:
		_particles.amount = 50


## Static factory for spawning portals
static func spawn_portal(
	parent: Node,
	pos: Vector3,
	p_element_id: String = "",
	p_destination_scene: String = "",
	p_destination_position: Vector3 = Vector3.ZERO,
	p_is_trap: bool = false
) -> PuzzlePortal:
	var portal := PuzzlePortal.new()
	portal.position = pos
	portal.element_id = p_element_id
	portal.element_name = "Portal"
	portal.destination_scene = p_destination_scene
	portal.destination_position = p_destination_position
	portal.is_trap = p_is_trap

	parent.add_child(portal)
	return portal
