## secret_wall.gd - False wall that disappears when detected by the player
## Secret walls require the player's hidden detection bonus to beat the DC
## Once revealed, the wall fades away revealing a hidden passage or room
class_name SecretWall
extends StaticBody3D

## Self-reference for static method instantiation
const _Self = preload("res://scripts/world/interactables/secret_wall.gd")

signal wall_revealed(wall: SecretWall)

## Detection configuration
@export var detection_dc: int = 15
@export var detection_radius: float = 6.0
@export var wall_name: String = "Secret Passage"

## Wall dimensions
@export var wall_size: Vector3 = Vector3(3.0, 3.0, 0.5)

## Wall appearance
@export var wall_texture: Texture2D = null
@export var wall_color: Color = Color(0.35, 0.32, 0.28)  # Fallback color if no texture
@export var uv_scale: Vector3 = Vector3(2, 1, 2)  # UV tiling scale

## Hidden state
var is_revealed: bool = false
var has_checked: bool = false
var check_at_bonus: int = -1

## Node references
var wall_mesh: MeshInstance3D
var wall_collision: CollisionShape3D
var detection_area: Area3D

## Reveal VFX
var reveal_text: Label3D
var dust_particles: GPUParticles3D


func _ready() -> void:
	# Create the wall geometry and collision
	_create_wall_mesh()
	_create_wall_collision()
	_create_detection_area()

	add_to_group("secret_walls")


func _create_wall_mesh() -> void:
	## Create the visible wall mesh
	wall_mesh = MeshInstance3D.new()
	wall_mesh.name = "WallMesh"

	var box_mesh := BoxMesh.new()
	box_mesh.size = wall_size
	wall_mesh.mesh = box_mesh

	# Create material - use texture if provided, otherwise fallback color
	var mat := StandardMaterial3D.new()
	if wall_texture:
		mat.albedo_texture = wall_texture
		mat.uv1_scale = uv_scale
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 style
	else:
		mat.albedo_color = wall_color
	mat.roughness = 0.9
	wall_mesh.material_override = mat

	# Center the mesh
	wall_mesh.position = Vector3(0, wall_size.y / 2.0, 0)
	add_child(wall_mesh)


func _create_wall_collision() -> void:
	## Create collision shape for the wall
	wall_collision = CollisionShape3D.new()
	wall_collision.name = "WallCollision"

	var box_shape := BoxShape3D.new()
	box_shape.size = wall_size
	wall_collision.shape = box_shape

	# Center the collision
	wall_collision.position = Vector3(0, wall_size.y / 2.0, 0)
	add_child(wall_collision)


func _create_detection_area() -> void:
	## Create Area3D sphere for player detection
	detection_area = Area3D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0  # Don't block anything
	detection_area.collision_mask = 2   # Player layer (layer 2)
	add_child(detection_area)

	var sphere_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = detection_radius
	sphere_shape.shape = sphere
	sphere_shape.name = "DetectionShape"
	# Center detection at wall center height
	sphere_shape.position = Vector3(0, wall_size.y / 2.0, 0)
	detection_area.add_child(sphere_shape)

	# Connect signals
	detection_area.body_entered.connect(_on_body_entered_detection)


func _on_body_entered_detection(body: Node3D) -> void:
	## Player entered detection range - attempt detection
	if is_revealed:
		return

	if body.is_in_group("player"):
		_attempt_detection()


func _attempt_detection() -> void:
	## Try to detect the secret wall using player's hidden detection bonus
	if not GameManager.player_data:
		return

	var player_bonus: int = GameManager.player_data.get_hidden_detection_bonus()

	# Allow re-check if skill improved by 3+ points
	if has_checked and (player_bonus < check_at_bonus + 3):
		return

	has_checked = true
	check_at_bonus = player_bonus

	# Make the passive check
	var result: Dictionary = DiceManager.passive_check("Secret Detection", player_bonus, detection_dc)

	if result.success:
		_reveal_wall()


func _reveal_wall() -> void:
	## Make the wall disappear to reveal the passage
	if is_revealed:
		return

	is_revealed = true

	# Play reveal VFX
	_play_reveal_effect()

	# Play gold sparkly text notification
	_show_gold_reveal_text()

	# Play sound
	AudioManager.play_sfx("secret_revealed")

	# Emit signal
	wall_revealed.emit(self)


func _play_reveal_effect() -> void:
	## Dust/debris particles + wall fade-out

	# Create dust particles (stone dust falling)
	dust_particles = GPUParticles3D.new()
	dust_particles.name = "DustParticles"
	dust_particles.amount = 50
	dust_particles.one_shot = true
	dust_particles.explosiveness = 0.6
	dust_particles.lifetime = 2.0
	dust_particles.position = Vector3(0, wall_size.y / 2.0, 0)
	add_child(dust_particles)

	# Create particle material
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	particle_material.emission_box_extents = Vector3(wall_size.x / 2.0, wall_size.y / 2.0, 0.2)
	particle_material.direction = Vector3(0, -1, 0)
	particle_material.spread = 30.0
	particle_material.initial_velocity_min = 0.5
	particle_material.initial_velocity_max = 2.0
	particle_material.gravity = Vector3(0, -5, 0)
	particle_material.scale_min = 0.03
	particle_material.scale_max = 0.08
	particle_material.color = Color(0.6, 0.55, 0.45, 0.8)  # Stone dust color
	dust_particles.process_material = particle_material

	# Create particle mesh (small quad)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	dust_particles.draw_pass_1 = quad

	# Start particles
	dust_particles.emitting = true

	# Disable collision so player can walk through (deferred to avoid physics callback error)
	if wall_collision:
		wall_collision.set_deferred("disabled", true)

	# Fade out mesh
	if wall_mesh:
		var mat: StandardMaterial3D = wall_mesh.material_override
		if mat:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

		# Create tween for fade-out
		var tween := create_tween()
		tween.tween_method(_set_wall_transparency, 1.0, 0.0, 1.2)
		tween.tween_callback(_on_reveal_complete)


func _show_gold_reveal_text() -> void:
	## Create a floating gold text that says "Secret Passage Found!" with sparkle effect
	reveal_text = Label3D.new()
	reveal_text.name = "RevealText"
	reveal_text.text = "Secret Passage Found!"
	reveal_text.font_size = 48
	reveal_text.pixel_size = 0.008
	reveal_text.position = Vector3(0, wall_size.y + 0.5, 0)  # Above wall
	reveal_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	reveal_text.modulate = Color(1.0, 0.85, 0.2, 1.0)  # Gold color
	reveal_text.outline_size = 8
	reveal_text.outline_modulate = Color(0.8, 0.5, 0.0, 1.0)  # Darker gold outline
	add_child(reveal_text)

	# Create sparkle particles around the text
	var sparkle := GPUParticles3D.new()
	sparkle.name = "TextSparkles"
	sparkle.amount = 20
	sparkle.lifetime = 1.5
	sparkle.one_shot = false
	sparkle.explosiveness = 0.0
	sparkle.position = Vector3(0, wall_size.y + 0.5, 0)
	add_child(sparkle)

	# Sparkle particle material
	var sparkle_mat := ParticleProcessMaterial.new()
	sparkle_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sparkle_mat.emission_box_extents = Vector3(1.0, 0.2, 0.1)
	sparkle_mat.direction = Vector3(0, 0.5, 0)
	sparkle_mat.spread = 180.0
	sparkle_mat.initial_velocity_min = 0.3
	sparkle_mat.initial_velocity_max = 0.8
	sparkle_mat.gravity = Vector3(0, -0.5, 0)
	sparkle_mat.scale_min = 0.02
	sparkle_mat.scale_max = 0.05
	sparkle_mat.color = Color(1.0, 0.9, 0.3, 1.0)  # Bright gold sparkles
	sparkle.process_material = sparkle_mat

	# Small quad mesh for sparkles
	var sparkle_mesh := QuadMesh.new()
	sparkle_mesh.size = Vector2(0.08, 0.08)
	sparkle.draw_pass_1 = sparkle_mesh

	sparkle.emitting = true

	# Animate text: float up and fade out after 3 seconds
	var tween := create_tween()
	tween.set_parallel(true)

	# Float up
	tween.tween_property(reveal_text, "position:y", wall_size.y + 1.5, 3.0).set_ease(Tween.EASE_OUT)

	# Pulse scale for sparkle effect
	tween.tween_property(reveal_text, "pixel_size", 0.01, 0.5).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(reveal_text, "pixel_size", 0.008, 0.5).set_ease(Tween.EASE_IN)

	# Fade out after 2 seconds
	tween.tween_property(reveal_text, "modulate:a", 0.0, 1.0).set_delay(2.0)
	tween.tween_property(sparkle, "emitting", false, 0.0).set_delay(2.5)

	# Cleanup after animation
	tween.chain().tween_callback(func():
		if is_instance_valid(reveal_text):
			reveal_text.queue_free()
			reveal_text = null
		if is_instance_valid(sparkle):
			sparkle.queue_free()
	)


func _set_wall_transparency(alpha: float) -> void:
	## Set transparency on wall mesh material
	if not wall_mesh:
		return

	var mat: StandardMaterial3D = wall_mesh.material_override
	if mat:
		mat.albedo_color.a = alpha


func _on_reveal_complete() -> void:
	## Called when reveal animation finishes
	# Hide mesh completely
	if wall_mesh:
		wall_mesh.visible = false

	# Disable detection area (no longer needed)
	if detection_area:
		detection_area.queue_free()
		detection_area = null

	# Clean up particles after they finish
	if dust_particles:
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(dust_particles):
			dust_particles.queue_free()
			dust_particles = null


## Static factory method for spawning secret walls
static func spawn_secret_wall(
	parent: Node,
	pos: Vector3,
	p_wall_name: String = "Secret Passage",
	p_detection_dc: int = 15,
	p_wall_size: Vector3 = Vector3(3.0, 3.0, 0.5),
	p_rotation_y: float = 0.0,
	p_texture: Texture2D = null,
	p_uv_scale: Vector3 = Vector3(2, 1, 2)
) -> SecretWall:
	var instance := _Self.new()
	instance.position = pos
	instance.wall_name = p_wall_name
	instance.detection_dc = p_detection_dc
	instance.wall_size = p_wall_size
	instance.rotation.y = deg_to_rad(p_rotation_y)
	instance.wall_texture = p_texture
	instance.uv_scale = p_uv_scale

	parent.add_child(instance)

	return instance


## Parse detection DC from string metadata
static func parse_dc(dc_string: String) -> int:
	if dc_string.is_valid_int():
		return dc_string.to_int()
	return 15  # Default DC
