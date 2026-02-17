## generate_musket_sprite.gd - Auto-generates musket FPS sprite sheet when run
## Run this scene to generate the sprite sheet
extends Node3D

const OUTPUT_PATH = "res://assets/weapons/musket/musket_fps_sheet.png"
const MODEL_PATH = "res://assets/weapons/musket/ps1_musket_fp.obj"
const FRAME_SIZE = Vector2i(256, 256)
const GRID_SIZE = Vector2i(4, 4)  # 4x4 = 16 frames

## Debug: set to true to see what's happening without auto-closing
@export var debug_mode: bool = true
@export var current_test_frame: int = 0

var viewport: SubViewport
var camera: Camera3D
var model: Node3D
var frames_captured: int = 0
var total_frames: int = 16
var sprite_sheet: Image
var is_generating: bool = false
var generation_started: bool = false
var debug_preview: TextureRect


func _ready() -> void:
	print("=== MUSKET SPRITE SHEET GENERATOR ===")
	print("Output: %s" % OUTPUT_PATH)
	print("Debug mode: %s" % debug_mode)

	# Create sprite sheet image
	var sheet_width := FRAME_SIZE.x * GRID_SIZE.x
	var sheet_height := FRAME_SIZE.y * GRID_SIZE.y
	sprite_sheet = Image.create(sheet_width, sheet_height, false, Image.FORMAT_RGBA8)
	sprite_sheet.fill(Color(0, 0, 0, 0))  # Transparent background

	# Setup viewport for rendering
	_setup_viewport()

	# Load model
	if not _load_model():
		print("ERROR: Failed to load model from %s" % MODEL_PATH)
		print("Trying to create a test cube instead...")
		_create_test_cube()

	if debug_mode:
		_setup_debug_ui()
		print("DEBUG MODE: Press SPACE to generate, arrow keys to preview frames")
	else:
		print("Starting generation...")
		is_generating = true


func _setup_viewport() -> void:
	viewport = SubViewport.new()
	viewport.size = FRAME_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

	# Camera setup - first person perspective looking slightly down at hands
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 70.0  # Wide FOV for first-person
	camera.position = Vector3(0, 0.3, 0.8)  # Above and behind, looking down at weapon
	camera.look_at(Vector3(0, -0.1, -0.5))  # Look forward and slightly down
	viewport.add_child(camera)

	# Main light from front-right-top
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 45, 0)
	light.light_energy = 1.5
	viewport.add_child(light)

	# Fill light from left
	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(20, -60, 0)
	fill_light.light_energy = 0.6
	viewport.add_child(fill_light)

	# Environment with visible background for debugging
	var env := Environment.new()
	if debug_mode:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.2, 0.2, 0.3, 1.0)  # Visible dark blue
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0, 0, 0, 0)  # Transparent
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.55)
	env.ambient_light_energy = 1.0

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)


func _load_model() -> bool:
	print("Attempting to load: %s" % MODEL_PATH)

	var mesh_res = load(MODEL_PATH)
	print("Load result: %s" % (mesh_res.get_class() if mesh_res else "NULL"))

	if mesh_res == null:
		print("Model is NULL - file may not be imported yet")
		return false

	if mesh_res is Mesh or mesh_res is ArrayMesh:
		model = MeshInstance3D.new()
		(model as MeshInstance3D).mesh = mesh_res
		print("Loaded as Mesh")
	elif mesh_res is PackedScene:
		model = mesh_res.instantiate()
		print("Loaded as PackedScene")
	else:
		print("Unknown resource type: %s" % mesh_res.get_class())
		return false

	# Scale up the model for first-person view
	# Original model is about 0.8 units long, scale to fill frame nicely
	model.scale = Vector3(1.8, 1.8, 1.8)

	# Create a simple material so it's visible
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.35, 0.3)  # Brown/wood color
	mat.metallic = 0.3
	mat.roughness = 0.7

	if model is MeshInstance3D:
		(model as MeshInstance3D).material_override = mat

	viewport.add_child(model)
	print("Model added to viewport with scale: %s" % model.scale)
	return true


func _create_test_cube() -> void:
	# Fallback: create a visible test cube
	print("Creating test cube for debugging...")
	model = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.2, 0.1)  # Musket-like proportions
	(model as MeshInstance3D).mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.4, 0.2)
	(model as MeshInstance3D).material_override = mat

	viewport.add_child(model)
	print("Test cube created")


func _setup_debug_ui() -> void:
	# Create a CanvasLayer to show the viewport preview
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(50, 50)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var label := Label.new()
	label.text = "Viewport Preview (Press SPACE to generate)"
	vbox.add_child(label)

	debug_preview = TextureRect.new()
	debug_preview.custom_minimum_size = Vector2(256, 256)
	debug_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	debug_preview.texture = viewport.get_texture()
	vbox.add_child(debug_preview)

	var frame_label := Label.new()
	frame_label.name = "FrameLabel"
	frame_label.text = "Frame: 0 (Use LEFT/RIGHT to preview)"
	vbox.add_child(frame_label)


func _input(event: InputEvent) -> void:
	if not debug_mode:
		return

	if event.is_action_pressed("ui_accept"):  # Space/Enter
		print("Starting generation...")
		is_generating = true
		debug_mode = false  # Disable debug during generation

	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_LEFT:
			current_test_frame = max(0, current_test_frame - 1)
			_preview_frame(current_test_frame)
		elif key.keycode == KEY_RIGHT:
			current_test_frame = min(total_frames - 1, current_test_frame + 1)
			_preview_frame(current_test_frame)


func _preview_frame(frame_idx: int) -> void:
	var progress := float(frame_idx) / float(total_frames - 1) if total_frames > 1 else 0.0
	_set_pose(progress)

	var label := get_node_or_null("CanvasLayer/PanelContainer/VBoxContainer/FrameLabel")
	if label:
		label.text = "Frame: %d / %d" % [frame_idx, total_frames - 1]


func _process(_delta: float) -> void:
	# In debug mode, update preview continuously
	if debug_mode and debug_preview:
		debug_preview.texture = viewport.get_texture()

	if not is_generating:
		return

	if not generation_started:
		generation_started = true
		_run_generation()


func _run_generation() -> void:
	print("Capturing %d frames..." % total_frames)

	for frame_idx in range(total_frames):
		var progress := float(frame_idx) / float(total_frames - 1) if total_frames > 1 else 0.0
		_set_pose(progress)

		# Wait for render
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw

		# Capture frame
		var frame_image := viewport.get_texture().get_image()

		# Position in grid
		var col := frame_idx % GRID_SIZE.x
		var row := frame_idx / GRID_SIZE.x
		var dest := Vector2i(col * FRAME_SIZE.x, row * FRAME_SIZE.y)

		sprite_sheet.blit_rect(frame_image, Rect2i(Vector2i.ZERO, FRAME_SIZE), dest)
		print("Frame %d/%d captured" % [frame_idx + 1, total_frames])

	_save_and_quit()


func _set_pose(progress: float) -> void:
	if not model:
		return

	# Animation for musket: idle -> aim -> fire -> return
	# Model's barrel is along X axis, need to rotate 90° around Y to point forward (-Z)
	# Then tilt for first-person holding angle

	# BASE ROTATION: 90° Y to point barrel into screen, plus holding angle
	# Stock should be lower-right (toward player's shoulder), barrel upper-left going away

	var t := progress

	# Key poses - all rotations are ADDED to the base 90° Y rotation
	# X = pitch (negative = barrel points down), Y = yaw, Z = roll (tilt)

	# Idle: relaxed hold, barrel angled down-right, stock at hip
	var idle_rot := Vector3(-15, 90, 20)      # Barrel down, rotated to show side
	var idle_pos := Vector3(0.2, -0.15, 0)    # Offset right and down

	# Aim: bring up to eye level, barrel straight ahead
	var aim_rot := Vector3(-5, 90, 5)         # Nearly level, slight tilt
	var aim_pos := Vector3(0.05, 0, 0)        # Centered

	# Fire: recoil kicks barrel up and back
	var fire_rot := Vector3(10, 90, 0)        # Barrel kicked up from recoil
	var fire_pos := Vector3(0.1, 0.05, 0.15)  # Pushed back toward player

	# Return to idle
	var return_rot := idle_rot
	var return_pos := idle_pos

	# 4-phase animation
	if t < 0.3:
		# Idle to aim (raising the musket)
		var phase_t := t / 0.3
		model.rotation_degrees = idle_rot.lerp(aim_rot, _ease_out(phase_t))
		model.position = idle_pos.lerp(aim_pos, _ease_out(phase_t))
	elif t < 0.5:
		# Hold aim (steady before firing)
		model.rotation_degrees = aim_rot
		model.position = aim_pos
	elif t < 0.65:
		# Fire recoil (sharp kick)
		var phase_t := (t - 0.5) / 0.15
		model.rotation_degrees = aim_rot.lerp(fire_rot, _ease_out(phase_t))
		model.position = aim_pos.lerp(fire_pos, _ease_out(phase_t))
	else:
		# Return to idle (recover from recoil)
		var phase_t := (t - 0.65) / 0.35
		model.rotation_degrees = fire_rot.lerp(return_rot, _ease_in_out(phase_t))
		model.position = fire_pos.lerp(return_pos, _ease_in_out(phase_t))


func _ease_out(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _ease_in_out(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return 1.0 - pow(-2.0 * t + 2.0, 2) / 2.0


func _save_and_quit() -> void:
	is_generating = false

	var global_path := ProjectSettings.globalize_path(OUTPUT_PATH)
	var err := sprite_sheet.save_png(global_path)

	if err == OK:
		print("=== SUCCESS ===")
		print("Sprite sheet saved to: %s" % OUTPUT_PATH)
	else:
		print("=== ERROR ===")
		print("Failed to save! Error: %d" % err)

	print("Closing in 3 seconds...")
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
