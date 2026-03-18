## zone_door.gd - Interactable door that transitions between scenes/zones
## Uses SceneManager for fade transitions and spawn point handling
class_name ZoneDoor
extends StaticBody3D

## Door visual styles
enum DoorStyle { WOODEN, PORTAL }

## Configuration
@export var target_scene: String = ""  # Path to scene to load (e.g., "res://scenes/levels/inn_interior.tscn")
@export var spawn_point_id: String = "default"  # Where to spawn in target scene
@export var door_name: String = "Door"
@export var is_locked: bool = false
@export var lock_difficulty: int = 0  # 0 = no skill check, 1-10 = lockpicking skill required
@export var show_frame: bool = true  # Whether to show door frame geometry
@export var return_to_previous: bool = false  # If true, returns to previous scene instead of target_scene
@export var door_style: DoorStyle = DoorStyle.WOODEN  # Visual style of the door

## Visual components
var mesh_root: Node3D
var door_frame_mesh: MeshInstance3D
var door_mesh: MeshInstance3D
var interaction_area: Area3D
var portal_mesh: MeshInstance3D
var portal_glow: OmniLight3D

## Materials
var frame_material: StandardMaterial3D
var door_material: StandardMaterial3D
var portal_material: ShaderMaterial

## Animation
var _time: float = 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("doors")

	# Setup collision for blocking player movement
	collision_layer = 1  # World layer
	collision_mask = 0

	# Only create visuals/areas if not already present (supports scene instancing)
	if not get_node_or_null("MeshRoot"):
		_create_door_mesh()
	else:
		mesh_root = get_node_or_null("MeshRoot")
		door_mesh = get_node_or_null("MeshRoot/DoorMesh")

	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	_register_compass_poi()

## Create visual representation of the door
func _create_door_mesh() -> void:
	mesh_root = Node3D.new()
	mesh_root.name = "MeshRoot"
	add_child(mesh_root)

	if door_style == DoorStyle.PORTAL:
		_create_portal_mesh()
	else:
		_create_wooden_door_mesh()


## Create traditional wooden door
func _create_wooden_door_mesh() -> void:
	# Frame material (stone/wood)
	frame_material = StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.3, 0.25, 0.2)
	frame_material.roughness = 0.9

	# Door material (darker wood)
	door_material = StandardMaterial3D.new()
	door_material.albedo_color = Color(0.25, 0.18, 0.12)
	door_material.roughness = 0.8

	# Door frame (left post, right post, top beam)
	if show_frame:
		var left_post := MeshInstance3D.new()
		left_post.name = "LeftPost"
		var left_box := BoxMesh.new()
		left_box.size = Vector3(0.2, 3.0, 0.3)
		left_post.mesh = left_box
		left_post.material_override = frame_material
		left_post.position = Vector3(-0.9, 1.5, 0)
		mesh_root.add_child(left_post)

		var right_post := MeshInstance3D.new()
		right_post.name = "RightPost"
		var right_box := BoxMesh.new()
		right_box.size = Vector3(0.2, 3.0, 0.3)
		right_post.mesh = right_box
		right_post.material_override = frame_material
		right_post.position = Vector3(0.9, 1.5, 0)
		mesh_root.add_child(right_post)

		var top_beam := MeshInstance3D.new()
		top_beam.name = "TopBeam"
		var top_box := BoxMesh.new()
		top_box.size = Vector3(2.0, 0.2, 0.3)
		top_beam.mesh = top_box
		top_beam.material_override = frame_material
		top_beam.position = Vector3(0, 3.1, 0)
		mesh_root.add_child(top_beam)

	# The actual door
	door_mesh = MeshInstance3D.new()
	door_mesh.name = "DoorMesh"
	var door_box := BoxMesh.new()
	door_box.size = Vector3(1.6, 2.8, 0.1)
	door_mesh.mesh = door_box
	door_mesh.material_override = door_material
	door_mesh.position = Vector3(0, 1.4, 0)
	mesh_root.add_child(door_mesh)

	# Update door color if locked
	if is_locked:
		door_material.albedo_color = Color(0.35, 0.2, 0.15)  # Slightly reddish


## Create swirling dark portal effect
func _create_portal_mesh() -> void:
	# Stone archway frame
	if show_frame:
		frame_material = StandardMaterial3D.new()
		frame_material.albedo_color = Color(0.2, 0.2, 0.22)  # Dark stone
		frame_material.roughness = 0.95

		# Left pillar
		var left_pillar := MeshInstance3D.new()
		left_pillar.name = "LeftPillar"
		var left_cyl := CylinderMesh.new()
		left_cyl.top_radius = 0.25
		left_cyl.bottom_radius = 0.3
		left_cyl.height = 3.2
		left_pillar.mesh = left_cyl
		left_pillar.material_override = frame_material
		left_pillar.position = Vector3(-1.1, 1.6, 0)
		mesh_root.add_child(left_pillar)

		# Right pillar
		var right_pillar := MeshInstance3D.new()
		right_pillar.name = "RightPillar"
		var right_cyl := CylinderMesh.new()
		right_cyl.top_radius = 0.25
		right_cyl.bottom_radius = 0.3
		right_cyl.height = 3.2
		right_pillar.mesh = right_cyl
		right_pillar.material_override = frame_material
		right_pillar.position = Vector3(1.1, 1.6, 0)
		mesh_root.add_child(right_pillar)

		# Arch top (torus segment)
		var arch := MeshInstance3D.new()
		arch.name = "Arch"
		var arch_torus := TorusMesh.new()
		arch_torus.inner_radius = 0.8
		arch_torus.outer_radius = 1.1
		arch.mesh = arch_torus
		arch.material_override = frame_material
		arch.position = Vector3(0, 3.2, 0)
		arch.rotation_degrees = Vector3(90, 0, 0)
		arch.scale = Vector3(1.0, 0.3, 1.0)  # Flatten it
		mesh_root.add_child(arch)

	# Portal effect - dark sphere with swirl shader
	portal_mesh = MeshInstance3D.new()
	portal_mesh.name = "PortalMesh"
	var portal_sphere := SphereMesh.new()
	portal_sphere.radius = 1.0
	portal_sphere.height = 2.8
	portal_mesh.mesh = portal_sphere
	portal_mesh.position = Vector3(0, 1.5, 0)
	portal_mesh.scale = Vector3(0.9, 1.0, 0.15)  # Flatten into oval

	# Create swirling void shader
	portal_material = ShaderMaterial.new()
	portal_material.shader = _create_portal_shader()
	portal_mesh.material_override = portal_material
	mesh_root.add_child(portal_mesh)

	# Eerie glow
	portal_glow = OmniLight3D.new()
	portal_glow.name = "PortalGlow"
	portal_glow.light_color = Color(0.2, 0.1, 0.3)  # Dark purple
	portal_glow.light_energy = 0.5
	portal_glow.omni_range = 4.0
	portal_glow.position = Vector3(0, 1.5, 0.5)
	mesh_root.add_child(portal_glow)

	# Enable processing for animation
	set_process(true)


## Create the portal swirl shader
func _create_portal_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float time : hint_range(0.0, 1000.0) = 0.0;
uniform vec4 color_inner : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_outer : source_color = vec4(0.15, 0.05, 0.2, 1.0);
uniform vec4 color_swirl : source_color = vec4(0.3, 0.1, 0.4, 1.0);

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv) * 2.0;

	// Swirl effect
	float angle = atan(uv.y, uv.x);
	float swirl = sin(angle * 3.0 + time * 2.0 + dist * 5.0) * 0.5 + 0.5;
	float swirl2 = sin(angle * 5.0 - time * 1.5 + dist * 3.0) * 0.5 + 0.5;

	// Radial gradient - dark center
	float center_dark = smoothstep(0.0, 0.6, dist);

	// Combine colors
	vec3 col = mix(color_inner.rgb, color_outer.rgb, center_dark);
	col = mix(col, color_swirl.rgb, swirl * swirl2 * 0.4 * center_dark);

	// Pulsing edge
	float edge_pulse = sin(time * 3.0) * 0.1 + 0.9;
	float edge = smoothstep(0.9, 1.0, dist * edge_pulse);

	// Alpha - solid center, fading edge
	float alpha = 1.0 - smoothstep(0.8, 1.0, dist);

	ALBEDO = col;
	ALPHA = alpha;
	EMISSION = col * 0.3;
}
"""
	return shader


## Update portal animation
func _process(delta: float) -> void:
	if door_style != DoorStyle.PORTAL:
		return

	_time += delta
	if portal_material:
		portal_material.set_shader_parameter("time", _time)

	# Pulse the glow
	if portal_glow:
		portal_glow.light_energy = 0.4 + sin(_time * 2.0) * 0.15

## Create interaction area for player detection
func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 3.0, 1.5)
	area_shape.shape = box
	area_shape.position = Vector3(0, 1.5, 0)
	interaction_area.add_child(area_shape)

	# Also add collision for blocking movement (thinner)
	var door_collision := CollisionShape3D.new()
	door_collision.name = "DoorCollision"
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(2.0, 3.0, 0.2)
	door_collision.shape = col_box
	door_collision.position = Vector3(0, 1.5, 0)
	add_child(door_collision)

## Called by player interaction system
func interact(_interactor: Node) -> void:
	if is_locked:
		_handle_locked_door(_interactor)
		return

	# Play door sound
	AudioManager.play_sfx("door_open")

	# Return to previous scene (for inn exits, etc.)
	if return_to_previous:
		SceneManager.return_to_previous_scene()
		return

	if target_scene.is_empty():
		return

	# Special case: Return to wilderness (for dungeon exits that lead back to open world)
	if target_scene == SceneManager.RETURN_TO_WILDERNESS:
		SceneManager.return_to_wilderness()
		return

	# Special case: Return to previous scene (for interiors like inns)
	if target_scene == "RETURN_TO_PREVIOUS":
		SceneManager.return_to_previous_scene()
		return

	# Transition to target scene
	# Note: spawn_point_id is passed to ProceduralDungeon as the dungeon_id
	SceneManager.change_scene(target_scene, spawn_point_id)

## Handle locked door interaction
func _handle_locked_door(_interactor: Node) -> void:
	# Show locked notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		if lock_difficulty > 0:
			hud.show_notification("Locked (Lockpicking %d required)" % lock_difficulty)
		else:
			hud.show_notification("This door is locked")

	# Play locked sound
	AudioManager.play_sfx("door_locked")

	# TODO: Future - check player lockpicking skill and open lockpicking minigame
	# if lock_difficulty > 0:
	#     var player_skill := GameManager.player_data.get_skill(Enums.Skill.LOCKPICKING)
	#     if player_skill >= lock_difficulty:
	#         # Open lockpicking UI
	#         pass

## Unlock the door (called by keys, lockpicking success, etc.)
func unlock() -> void:
	is_locked = false
	if door_material:
		door_material.albedo_color = Color(0.25, 0.18, 0.12)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(door_name + " unlocked")

	AudioManager.play_sfx("door_unlock")

## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if is_locked:
		if lock_difficulty > 0:
			return "Locked - " + door_name + " (Lockpicking %d)" % lock_difficulty
		return "Locked - " + door_name
	return "Enter " + door_name

## Register this door as a compass POI
## Uses instance ID for guaranteed uniqueness across scenes
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	# Use instance_id for guaranteed uniqueness - prevents ghost markers across scenes
	set_meta("poi_id", "door_%d" % get_instance_id())
	set_meta("poi_name", door_name)
	set_meta("poi_color", Color(0.8, 0.7, 0.4))  # Warm yellow for doors


## Static factory method for spawning doors
static func spawn_door(parent: Node, pos: Vector3, target: String, spawn_id: String = "default", door_name_param: String = "Door", show_frame_param: bool = true, style: DoorStyle = DoorStyle.WOODEN) -> ZoneDoor:
	var door := ZoneDoor.new()
	door.position = pos
	door.target_scene = target
	door.spawn_point_id = spawn_id
	door.door_name = door_name_param
	door.show_frame = show_frame_param
	door.door_style = style
	parent.add_child(door)
	return door


## Static factory for portal-style doors (convenience method)
static func spawn_portal(parent: Node, pos: Vector3, target: String, spawn_id: String = "default", door_name_param: String = "Enter", show_frame_param: bool = true) -> ZoneDoor:
	return spawn_door(parent, pos, target, spawn_id, door_name_param, show_frame_param, DoorStyle.PORTAL)
