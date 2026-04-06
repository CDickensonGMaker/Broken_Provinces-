## crystal_portal.gd - Trapped portal visual for Crystal Hearts puzzle
## Displays a trapped figure inside until the puzzle is solved
class_name CrystalPortal
extends Node3D

signal portal_opened

@export var trapped_sprite_path: String = ""
@export var portal_active: bool = false
@export var glow_color_closed: Color = Color(0.4, 0.2, 0.6)  # Purple
@export var glow_color_open: Color = Color(0.2, 0.8, 1.0)    # Cyan

var _portal_mesh: MeshInstance3D
var _trapped_sprite: Sprite3D
var _particles: GPUParticles3D
var _tween: Tween
var _portal_light: OmniLight3D


func _ready() -> void:
	_setup_portal_mesh()
	_setup_trapped_sprite()
	_setup_particles()
	_setup_lighting()
	_update_portal_state()


func _setup_portal_mesh() -> void:
	_portal_mesh = get_node_or_null("PortalMesh")
	if not _portal_mesh:
		# Create portal mesh if not present
		_portal_mesh = MeshInstance3D.new()
		_portal_mesh.name = "PortalMesh"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 2.0
		cylinder.bottom_radius = 2.0
		cylinder.height = 0.5
		_portal_mesh.mesh = cylinder
		_portal_mesh.position = Vector3(0, 0.25, 0)
		add_child(_portal_mesh)

	# Apply glowing material
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = glow_color_closed
	mat.emission_energy_multiplier = 2.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(glow_color_closed, 0.5)
	_portal_mesh.material_override = mat


func _setup_trapped_sprite() -> void:
	_trapped_sprite = get_node_or_null("TrappedSprite")
	if not _trapped_sprite:
		_trapped_sprite = Sprite3D.new()
		_trapped_sprite.name = "TrappedSprite"

		# Try to load specified sprite, or use a default wizard/mage sprite
		var sprite_path: String = trapped_sprite_path
		if sprite_path.is_empty():
			sprite_path = "res://assets/sprites/npcs/civilians/wizard_mage.png"

		if ResourceLoader.exists(sprite_path):
			_trapped_sprite.texture = load(sprite_path)
		else:
			push_warning("[CrystalPortal] Trapped sprite not found: %s" % sprite_path)

		_trapped_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_trapped_sprite.position = Vector3(0, 1.5, 0)
		_trapped_sprite.pixel_size = 0.0256
		_trapped_sprite.modulate = Color(0.6, 0.4, 0.8, 0.8)  # Ethereal purple tint
		add_child(_trapped_sprite)


func _setup_particles() -> void:
	_particles = get_node_or_null("GPUParticles3D")
	if not _particles:
		_particles = GPUParticles3D.new()
		_particles.name = "GPUParticles3D"
		_particles.amount = 50
		_particles.emitting = true
		_particles.lifetime = 3.0
		_particles.position = Vector3(0, 1.0, 0)

		# Setup particle material
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		mat.emission_ring_axis = Vector3(0, 1, 0)
		mat.emission_ring_height = 0.5
		mat.emission_ring_radius = 2.0
		mat.emission_ring_inner_radius = 1.5
		mat.gravity = Vector3(0, 0.5, 0)  # Float upward
		mat.initial_velocity_min = 0.2
		mat.initial_velocity_max = 0.5
		mat.direction = Vector3(0, 1, 0)
		mat.spread = 30.0
		mat.scale_min = 0.05
		mat.scale_max = 0.15
		mat.color = glow_color_closed
		_particles.process_material = mat

		# Simple quad mesh for particles
		var quad := QuadMesh.new()
		quad.size = Vector2(0.1, 0.1)
		_particles.draw_pass_1 = quad

		add_child(_particles)


func _setup_lighting() -> void:
	_portal_light = OmniLight3D.new()
	_portal_light.name = "PortalLight"
	_portal_light.light_color = glow_color_closed
	_portal_light.light_energy = 1.5
	_portal_light.omni_range = 6.0
	_portal_light.position = Vector3(0, 1.5, 0)
	add_child(_portal_light)


func _update_portal_state() -> void:
	var target_color: Color = glow_color_open if portal_active else glow_color_closed

	if _portal_mesh and _portal_mesh.material_override:
		var mat: StandardMaterial3D = _portal_mesh.material_override
		mat.emission = target_color

	if _portal_light:
		_portal_light.light_color = target_color

	if _trapped_sprite:
		_trapped_sprite.visible = not portal_active

	if _particles and _particles.process_material:
		var particle_mat: ParticleProcessMaterial = _particles.process_material
		particle_mat.color = target_color


func open_portal() -> void:
	if portal_active:
		return
	portal_active = true

	# Animate the opening
	if _tween:
		_tween.kill()
	_tween = create_tween()

	# Fade trapped sprite
	if _trapped_sprite:
		_tween.tween_property(_trapped_sprite, "modulate:a", 0.0, 1.0)

	# Change portal color
	if _portal_mesh and _portal_mesh.material_override:
		var mat: StandardMaterial3D = _portal_mesh.material_override
		_tween.parallel().tween_property(mat, "emission", glow_color_open, 1.0)
		_tween.parallel().tween_property(mat, "albedo_color", Color(glow_color_open, 0.7), 1.0)

	# Change light color
	if _portal_light:
		_tween.parallel().tween_property(_portal_light, "light_color", glow_color_open, 1.0)

	# Increase particle intensity
	if _particles:
		_tween.parallel().tween_property(_particles, "amount", 100, 1.0)

	_tween.tween_callback(func():
		if _trapped_sprite:
			_trapped_sprite.visible = false
		portal_opened.emit()

		# Update particle color after tween
		if _particles and _particles.process_material:
			var particle_mat: ParticleProcessMaterial = _particles.process_material
			particle_mat.color = glow_color_open
	)

	# Play portal opening sound
	if AudioManager:
		AudioManager.play_sfx("portal_open")


## Close the portal (for resetting)
func close_portal() -> void:
	if not portal_active:
		return
	portal_active = false

	if _tween:
		_tween.kill()
	_tween = create_tween()

	# Fade trapped sprite back in
	if _trapped_sprite:
		_trapped_sprite.visible = true
		_trapped_sprite.modulate.a = 0.0
		_tween.tween_property(_trapped_sprite, "modulate:a", 0.8, 1.0)

	# Change portal color back
	if _portal_mesh and _portal_mesh.material_override:
		var mat: StandardMaterial3D = _portal_mesh.material_override
		_tween.parallel().tween_property(mat, "emission", glow_color_closed, 1.0)
		_tween.parallel().tween_property(mat, "albedo_color", Color(glow_color_closed, 0.5), 1.0)

	# Change light color back
	if _portal_light:
		_tween.parallel().tween_property(_portal_light, "light_color", glow_color_closed, 1.0)

	# Decrease particle intensity
	if _particles:
		_tween.parallel().tween_property(_particles, "amount", 50, 1.0)

	_tween.tween_callback(func():
		if _particles and _particles.process_material:
			var particle_mat: ParticleProcessMaterial = _particles.process_material
			particle_mat.color = glow_color_closed
	)


## Get save data
func get_save_data() -> Dictionary:
	return {
		"portal_active": portal_active
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	if data.has("portal_active"):
		portal_active = data.portal_active
		_update_portal_state()
