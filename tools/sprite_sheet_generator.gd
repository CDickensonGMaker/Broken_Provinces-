@tool
## sprite_sheet_generator.gd - Renders 3D models to 2D sprite sheets
## Run from Editor: Open this scene, configure, click "Generate" button
extends Node3D

## Configuration
@export_file("*.obj", "*.glb", "*.gltf") var model_path: String = ""
@export var output_path: String = "res://assets/weapons/musket/musket_fps_sheet.png"
@export var frame_size: Vector2i = Vector2i(256, 256)
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var background_color: Color = Color(0, 0, 0, 0)  # Transparent

## Animation settings for attack swing
@export_group("Animation")
@export var start_rotation: Vector3 = Vector3(-15, 20, 10)  # Idle pose (degrees)
@export var end_rotation: Vector3 = Vector3(45, -30, -20)   # End of swing
@export var start_position: Vector3 = Vector3(0.3, -0.2, -0.5)  # Offset from camera
@export var end_position: Vector3 = Vector3(0.1, 0.1, -0.4)     # Forward thrust

## Camera settings
@export_group("Camera")
@export var camera_fov: float = 50.0
@export var camera_distance: float = 1.0

## Lighting
@export_group("Lighting")
@export var light_energy: float = 1.5
@export var ambient_light: Color = Color(0.3, 0.3, 0.35)

## Runtime
var viewport: SubViewport
var camera: Camera3D
var model_instance: Node3D
var light: DirectionalLight3D

@export var generate_now: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			generate_sprite_sheet()
		generate_now = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		# Can also run in-game for testing
		pass


func generate_sprite_sheet() -> void:
	print("[SpriteGen] Starting sprite sheet generation...")
	print("[SpriteGen] Model: %s" % model_path)
	print("[SpriteGen] Output: %s" % output_path)

	if model_path.is_empty():
		push_error("[SpriteGen] No model path specified!")
		return

	# Setup rendering environment
	_setup_viewport()
	_setup_camera()
	_setup_lighting()

	# Load the model
	if not _load_model():
		push_error("[SpriteGen] Failed to load model!")
		_cleanup()
		return

	# Create the sprite sheet image
	var total_frames := grid_columns * grid_rows
	var sheet_width := frame_size.x * grid_columns
	var sheet_height := frame_size.y * grid_rows
	var sprite_sheet := Image.create(sheet_width, sheet_height, false, Image.FORMAT_RGBA8)
	sprite_sheet.fill(background_color)

	print("[SpriteGen] Rendering %d frames at %dx%d each..." % [total_frames, frame_size.x, frame_size.y])

	# Render each frame
	for frame_idx in range(total_frames):
		var progress := float(frame_idx) / float(total_frames - 1) if total_frames > 1 else 0.0

		# Interpolate model transform for animation
		_set_model_pose(progress)

		# Wait for viewport to render
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		# Capture the frame
		var frame_image := viewport.get_texture().get_image()

		# Calculate position in sprite sheet
		var col := frame_idx % grid_columns
		var row := frame_idx / grid_columns
		var dest_pos := Vector2i(col * frame_size.x, row * frame_size.y)

		# Copy frame to sprite sheet
		sprite_sheet.blit_rect(frame_image, Rect2i(Vector2i.ZERO, frame_size), dest_pos)

		print("[SpriteGen] Frame %d/%d rendered" % [frame_idx + 1, total_frames])

	# Save the sprite sheet
	var save_path := output_path
	if save_path.begins_with("res://"):
		save_path = ProjectSettings.globalize_path(save_path)

	var err := sprite_sheet.save_png(save_path)
	if err == OK:
		print("[SpriteGen] Sprite sheet saved to: %s" % output_path)
	else:
		push_error("[SpriteGen] Failed to save sprite sheet! Error: %d" % err)

	_cleanup()
	print("[SpriteGen] Done!")


func _setup_viewport() -> void:
	viewport = SubViewport.new()
	viewport.size = frame_size
	viewport.transparent_bg = (background_color.a < 1.0)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.fov = camera_fov
	camera.position = Vector3(0, 0, camera_distance)
	camera.look_at(Vector3.ZERO)
	viewport.add_child(camera)


func _setup_lighting() -> void:
	# Main directional light
	light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = light_energy
	light.shadow_enabled = false
	viewport.add_child(light)

	# Set ambient light via environment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background_color
	env.ambient_light_color = ambient_light
	env.ambient_light_energy = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)


func _load_model() -> bool:
	# Try loading as mesh resource first
	var mesh_resource = load(model_path)

	if mesh_resource is Mesh:
		model_instance = MeshInstance3D.new()
		(model_instance as MeshInstance3D).mesh = mesh_resource
	elif mesh_resource is PackedScene:
		model_instance = mesh_resource.instantiate()
	else:
		# Try importing OBJ directly
		var obj_mesh := _load_obj_mesh(model_path)
		if obj_mesh:
			model_instance = MeshInstance3D.new()
			(model_instance as MeshInstance3D).mesh = obj_mesh
		else:
			return false

	if model_instance:
		viewport.add_child(model_instance)
		# Initial pose
		model_instance.position = start_position
		model_instance.rotation_degrees = start_rotation
		return true

	return false


func _load_obj_mesh(path: String) -> Mesh:
	# Godot can import OBJ files if they're in the project
	# The path should already be a res:// path after copying
	var mesh = load(path)
	if mesh is Mesh:
		return mesh
	elif mesh is ArrayMesh:
		return mesh
	return null


func _set_model_pose(progress: float) -> void:
	if not model_instance:
		return

	# Smooth easing for more natural animation
	var eased := _ease_out_quad(progress)

	# Interpolate rotation and position
	model_instance.rotation_degrees = start_rotation.lerp(end_rotation, eased)
	model_instance.position = start_position.lerp(end_position, eased)


func _ease_out_quad(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _cleanup() -> void:
	if viewport:
		viewport.queue_free()
		viewport = null
	model_instance = null
	camera = null
	light = null
