## unit_viewer.gd - 3D Unit Viewer/Editor for debugging sprite rotation issues
## Camera setup MUST match ActorZoo and Battle Scene for orientation consistency
extends Node3D

## Camera configuration - CRITICAL: These MUST match ActorZoo exactly
const CAMERA_FOV := 60.0
const CAMERA_NEAR := 0.1
const CAMERA_FAR := 100.0
const CAMERA_SPEED := 10.0
const ZOOM_SPEED := 2.0
const ZOOM_MIN := 2.0
const ZOOM_MAX := 30.0
const ORBIT_SENSITIVITY := 0.003

## Walk mode settings - CRITICAL: These MUST match ActorZoo exactly
const WALK_SPEED := 8.0
const WALK_SPRINT_MULT := 2.5
const WALK_MOUSE_SENS := 0.002
const PLAYER_EYE_HEIGHT := 1.5  # Same as player.tscn camera pivot

## Patch file path
const PATCH_FILE := "user://unit_orientation_patches.json"

## Node references
var camera: Camera3D
var ground_plane: MeshInstance3D
var unit_container: Node3D
var ui: CanvasLayer
var debug_panel: PanelContainer
var unit_select: OptionButton

## Current unit
var current_unit: Node3D = null
var current_billboard: BillboardSprite = null
var current_actor_data: Dictionary = {}

## Camera state - CRITICAL: Same as ActorZoo
var camera_target: Vector3 = Vector3.ZERO
var camera_distance: float = 8.0
var camera_orbit_angle: float = 0.0  # Yaw (horizontal rotation)
var camera_pitch: float = -0.3  # Looking slightly down
var is_orbiting: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

## Walk mode state - CRITICAL: Same as ActorZoo
var walk_mode: bool = false
var walk_position: Vector3 = Vector3(0, PLAYER_EYE_HEIGHT, 5)
var walk_yaw: float = 0.0
var walk_pitch: float = 0.0

## Orientation editing state
var sprite_orientation_offset: float = 0.0  # Degrees offset for sprite facing
var formation_facing_angle: float = 0.0  # Simulated formation facing angle
var modified_orientations: Dictionary = {}  # actor_id -> offset

## Debug visualization
var camera_direction_arrow: MeshInstance3D
var sprite_facing_arrow: MeshInstance3D
var formation_facing_arrow: MeshInstance3D
var compass_ring: MeshInstance3D
var los_cone: MeshInstance3D

## LOS (Line of Sight) cone settings
const LOS_CONE_ANGLE := 90.0  # Field of view angle in degrees
const LOS_CONE_RANGE := 4.0   # How far the cone extends
const LOS_CONE_SEGMENTS := 16 # Number of segments for cone smoothness
var los_cone_visible: bool = true

## Colors for debug visualization
const COLOR_CAMERA := Color(0.2, 0.6, 1.0)  # Blue for camera
const COLOR_SPRITE := Color(1.0, 0.8, 0.2)  # Yellow for sprite facing
const COLOR_FORMATION := Color(0.2, 1.0, 0.4)  # Green for formation
const COLOR_MISMATCH := Color(1.0, 0.2, 0.2)  # Red for mismatch
const COLOR_LOS_CONE := Color(1.0, 0.5, 0.0, 0.3)  # Orange, semi-transparent


func _ready() -> void:
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_load_patches()
	_create_camera()
	_create_ground()
	_create_unit_container()
	_create_debug_arrows()
	_create_los_cone()
	_create_ui()
	_update_camera_position()

	# Load first unit if available
	_populate_unit_list()


func _process(delta: float) -> void:
	if walk_mode:
		_handle_walk_input(delta)
	else:
		_handle_camera_input(delta)

	# Update debug visualization
	_update_debug_arrows()
	_update_los_cone()
	_update_debug_panel()


func _unhandled_input(event: InputEvent) -> void:
	# Handle keyboard shortcuts
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event as InputEventKey
		match key.keycode:
			KEY_P:
				_toggle_walk_mode()
			KEY_HOME:
				_reset_camera()
			KEY_LEFT:
				_adjust_sprite_orientation(-5.0 if not key.shift_pressed else -15.0)
			KEY_RIGHT:
				_adjust_sprite_orientation(5.0 if not key.shift_pressed else 15.0)
			KEY_UP:
				_adjust_formation_facing(5.0 if not key.shift_pressed else 15.0)
			KEY_DOWN:
				_adjust_formation_facing(-5.0 if not key.shift_pressed else -15.0)
			KEY_R:
				_reset_orientations()
			KEY_L:
				_toggle_los_cone()
			KEY_S:
				if key.ctrl_pressed:
					_save_patches()
					get_viewport().set_input_as_handled()

	# Handle mouse for orbiting / walk mode
	if walk_mode:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			walk_yaw -= motion.relative.x * WALK_MOUSE_SENS
			walk_pitch -= motion.relative.y * WALK_MOUSE_SENS
			walk_pitch = clampf(walk_pitch, -PI/2 + 0.1, PI/2 - 0.1)
			_update_walk_camera()

		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				is_orbiting = mb.pressed
				last_mouse_pos = mb.position
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				camera_distance = maxf(camera_distance - ZOOM_SPEED, ZOOM_MIN)
				_update_camera_position()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				camera_distance = minf(camera_distance + ZOOM_SPEED, ZOOM_MAX)
				_update_camera_position()

		if event is InputEventMouseMotion and is_orbiting:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			camera_orbit_angle -= motion.relative.x * ORBIT_SENSITIVITY
			camera_pitch = clampf(camera_pitch - motion.relative.y * ORBIT_SENSITIVITY, -1.4, -0.1)
			_update_camera_position()


## ============================================================================
## SETUP - Camera matches ActorZoo exactly
## ============================================================================

func _create_camera() -> void:
	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.near = CAMERA_NEAR
	camera.far = CAMERA_FAR
	add_child(camera)


func _create_ground() -> void:
	ground_plane = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)

	# Grid pattern for orientation reference
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	plane.material = mat

	ground_plane.mesh = plane
	add_child(ground_plane)

	# Add grid lines
	_create_grid_lines()


func _create_grid_lines() -> void:
	var grid := Node3D.new()
	grid.name = "Grid"
	add_child(grid)

	var line_mat := StandardMaterial3D.new()
	line_mat.albedo_color = Color(0.4, 0.4, 0.45)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Create grid lines
	for i in range(-10, 11):
		# X axis lines
		var line_x := MeshInstance3D.new()
		var box_x := BoxMesh.new()
		box_x.size = Vector3(20.0, 0.02, 0.02)
		box_x.material = line_mat
		line_x.mesh = box_x
		line_x.position = Vector3(0, 0.01, i)
		grid.add_child(line_x)

		# Z axis lines
		var line_z := MeshInstance3D.new()
		var box_z := BoxMesh.new()
		box_z.size = Vector3(0.02, 0.02, 20.0)
		box_z.material = line_mat
		line_z.mesh = box_z
		line_z.position = Vector3(i, 0.01, 0)
		grid.add_child(line_z)

	# Cardinal direction markers
	_create_cardinal_markers(grid)


func _create_cardinal_markers(parent: Node3D) -> void:
	var directions: Array[Dictionary] = [
		{"name": "N", "pos": Vector3(0, 0.1, -8), "color": Color.RED},
		{"name": "S", "pos": Vector3(0, 0.1, 8), "color": Color.GREEN},
		{"name": "E", "pos": Vector3(8, 0.1, 0), "color": Color.BLUE},
		{"name": "W", "pos": Vector3(-8, 0.1, 0), "color": Color.YELLOW}
	]

	for dir: Dictionary in directions:
		var label := Label3D.new()
		label.text = dir["name"]
		label.font_size = 64
		label.pixel_size = 0.02
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = dir["pos"]
		label.modulate = dir["color"]
		parent.add_child(label)


func _create_unit_container() -> void:
	unit_container = Node3D.new()
	unit_container.name = "UnitContainer"
	add_child(unit_container)


## ============================================================================
## DEBUG VISUALIZATION
## ============================================================================

func _create_debug_arrows() -> void:
	# Camera direction arrow (blue)
	camera_direction_arrow = _create_arrow(COLOR_CAMERA, "CameraDirection")
	add_child(camera_direction_arrow)

	# Sprite facing arrow (yellow)
	sprite_facing_arrow = _create_arrow(COLOR_SPRITE, "SpriteFacing")
	add_child(sprite_facing_arrow)

	# Formation facing arrow (green)
	formation_facing_arrow = _create_arrow(COLOR_FORMATION, "FormationFacing")
	add_child(formation_facing_arrow)

	# Compass ring at ground level
	_create_compass_ring()


func _create_arrow(color: Color, arrow_name: String) -> MeshInstance3D:
	var arrow := MeshInstance3D.new()
	arrow.name = arrow_name

	# Arrow shaft
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.05
	shaft.bottom_radius = 0.05
	shaft.height = 2.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft.material = mat

	arrow.mesh = shaft

	# Arrow head (cone)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.15
	cone.height = 0.4
	cone.material = mat
	head.mesh = cone
	head.position = Vector3(0, 1.2, 0)
	arrow.add_child(head)

	return arrow


func _create_compass_ring() -> void:
	compass_ring = MeshInstance3D.new()
	compass_ring.name = "CompassRing"

	var torus := TorusMesh.new()
	torus.inner_radius = 2.8
	torus.outer_radius = 3.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.5, 0.5, 0.5)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	torus.material = mat

	compass_ring.mesh = torus
	compass_ring.position = Vector3(0, 0.05, 0)
	compass_ring.rotation_degrees.x = 90  # Lay flat
	add_child(compass_ring)

	# Add degree markers
	var marker_parent := Node3D.new()
	marker_parent.name = "DegreeMarkers"
	compass_ring.add_child(marker_parent)

	for deg in range(0, 360, 45):
		var rad: float = deg_to_rad(deg)
		var pos := Vector3(sin(rad) * 3.2, 0.2, -cos(rad) * 3.2)

		var label := Label3D.new()
		label.text = str(deg) + " deg"
		label.font_size = 32
		label.pixel_size = 0.01
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = pos
		label.modulate = Color(0.7, 0.7, 0.7)
		add_child(label)


## Create the LOS cone mesh (wedge shape representing field of view)
func _create_los_cone() -> void:
	los_cone = MeshInstance3D.new()
	los_cone.name = "LOSCone"

	# Create a wedge/cone mesh using ImmediateMesh for custom geometry
	var mesh := _generate_los_cone_mesh()
	los_cone.mesh = mesh

	# Material for the cone - semi-transparent
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOR_LOS_CONE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from both sides
	mat.no_depth_test = false
	los_cone.material_override = mat

	# Position slightly above ground
	los_cone.position = Vector3(0, 0.1, 0)
	los_cone.visible = los_cone_visible

	add_child(los_cone)


## Generate the LOS cone mesh geometry (flat wedge on ground plane)
func _generate_los_cone_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()

	# Half angle of the cone
	var half_angle: float = deg_to_rad(LOS_CONE_ANGLE / 2.0)

	# Center point (at unit position)
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)

	# Create vertices around the arc
	for i in range(LOS_CONE_SEGMENTS + 1):
		var t: float = float(i) / float(LOS_CONE_SEGMENTS)
		var angle: float = -half_angle + (t * LOS_CONE_ANGLE * deg_to_rad(1.0) * (180.0 / LOS_CONE_ANGLE) * 2.0 * half_angle / deg_to_rad(LOS_CONE_ANGLE))
		# Simplified: angle from -half_angle to +half_angle
		angle = -half_angle + t * 2.0 * half_angle

		# Forward is -Z in Godot, so cone points in -Z direction
		var x: float = sin(angle) * LOS_CONE_RANGE
		var z: float = -cos(angle) * LOS_CONE_RANGE  # Negative Z is forward

		vertices.append(Vector3(x, 0, z))
		normals.append(Vector3.UP)

	# Create triangles (fan from center)
	for i in range(LOS_CONE_SEGMENTS):
		indices.append(0)           # Center
		indices.append(i + 1)       # Current arc point
		indices.append(i + 2)       # Next arc point

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## Update the LOS cone rotation to match sprite facing direction
func _update_los_cone() -> void:
	if not los_cone:
		return

	los_cone.visible = los_cone_visible

	if not los_cone_visible:
		return

	# Calculate the sprite's effective facing angle (base + offset)
	var sprite_angle: float = sprite_orientation_offset
	if current_billboard:
		var facing: Vector3 = current_billboard.facing_direction
		sprite_angle += rad_to_deg(atan2(facing.x, facing.z))

	# Rotate the cone to match sprite facing
	# The cone mesh is built pointing in -Z direction, so we rotate around Y
	los_cone.rotation_degrees.y = -sprite_angle


## Toggle LOS cone visibility
func _toggle_los_cone() -> void:
	los_cone_visible = not los_cone_visible
	if los_cone:
		los_cone.visible = los_cone_visible
	print("[UnitViewer] LOS cone: %s" % ("ON" if los_cone_visible else "OFF"))


func _update_debug_arrows() -> void:
	if not camera:
		return

	# Camera direction arrow - points where camera is looking
	var camera_forward: Vector3
	if walk_mode:
		camera_forward = Vector3(sin(walk_yaw), 0, cos(walk_yaw)).normalized()
	else:
		camera_forward = Vector3(sin(camera_orbit_angle), 0, cos(camera_orbit_angle)).normalized()

	var camera_angle_deg: float = rad_to_deg(atan2(camera_forward.x, camera_forward.z))
	camera_direction_arrow.position = Vector3(0, 0.5, 0)
	camera_direction_arrow.rotation_degrees.x = 90  # Lay horizontal
	camera_direction_arrow.rotation_degrees.y = -camera_angle_deg

	# Sprite facing arrow
	var sprite_angle: float = sprite_orientation_offset
	if current_billboard:
		var facing: Vector3 = current_billboard.facing_direction
		sprite_angle += rad_to_deg(atan2(facing.x, facing.z))

	sprite_facing_arrow.position = Vector3(0, 1.0, 0)
	sprite_facing_arrow.rotation_degrees.x = 90
	sprite_facing_arrow.rotation_degrees.y = -sprite_angle

	# Formation facing arrow
	formation_facing_arrow.position = Vector3(0, 1.5, 0)
	formation_facing_arrow.rotation_degrees.x = 90
	formation_facing_arrow.rotation_degrees.y = -formation_facing_angle

	# Check for mismatch and highlight
	var sprite_to_formation_diff: float = absf(wrapf(sprite_angle - formation_facing_angle, -180, 180))
	if sprite_to_formation_diff > 10.0:  # More than 10 degree mismatch
		var mismatch_mat := StandardMaterial3D.new()
		mismatch_mat.albedo_color = COLOR_MISMATCH
		mismatch_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sprite_facing_arrow.material_override = mismatch_mat
	else:
		sprite_facing_arrow.material_override = null


## ============================================================================
## UI
## ============================================================================

func _create_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	add_child(ui)

	# Main layout
	var main_container := HBoxContainer.new()
	main_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(main_container)

	# Left spacer (viewport area)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_container.add_child(spacer)

	# Right panel - Debug info and controls
	_create_debug_panel(main_container)

	# Top bar for unit selection
	_create_top_bar()


func _create_top_bar() -> void:
	var top_bar := PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.add_child(top_bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	top_bar.add_child(hbox)

	# Title
	var title := Label.new()
	title.text = "Unit Viewer/Editor - Sprite Orientation Debug"
	hbox.add_child(title)

	# Separator
	var sep := VSeparator.new()
	hbox.add_child(sep)

	# Unit selector
	var lbl := Label.new()
	lbl.text = "Unit:"
	hbox.add_child(lbl)

	unit_select = OptionButton.new()
	unit_select.custom_minimum_size.x = 200
	unit_select.item_selected.connect(_on_unit_selected)
	hbox.add_child(unit_select)

	# Walk mode button
	var walk_btn := Button.new()
	walk_btn.text = "Walk Mode (P)"
	walk_btn.toggle_mode = true
	walk_btn.toggled.connect(func(pressed: bool) -> void:
		if pressed != walk_mode:
			_toggle_walk_mode()
	)
	hbox.add_child(walk_btn)

	# LOS Cone toggle button
	var los_btn := Button.new()
	los_btn.name = "LOSButton"
	los_btn.text = "LOS Cone (L)"
	los_btn.toggle_mode = true
	los_btn.button_pressed = los_cone_visible
	los_btn.toggled.connect(func(pressed: bool) -> void:
		if pressed != los_cone_visible:
			_toggle_los_cone()
			los_btn.button_pressed = los_cone_visible
	)
	hbox.add_child(los_btn)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "Reset (R)"
	reset_btn.pressed.connect(_reset_orientations)
	hbox.add_child(reset_btn)

	# Save button
	var save_btn := Button.new()
	save_btn.text = "Save (Ctrl+S)"
	save_btn.pressed.connect(_save_patches)
	hbox.add_child(save_btn)


func _create_debug_panel(parent: Control) -> void:
	debug_panel = PanelContainer.new()
	debug_panel.custom_minimum_size.x = 320
	parent.add_child(debug_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	debug_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "Content"
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Camera Info Section
	_add_section_header(vbox, "=== Camera Direction ===")

	var camera_info := VBoxContainer.new()
	camera_info.name = "CameraInfo"
	vbox.add_child(camera_info)

	_add_info_label(camera_info, "LblCameraAngle", "Angle: 0 deg")
	_add_info_label(camera_info, "LblCameraDir", "Direction: (0, 0, 1)")
	_add_info_label(camera_info, "LblCameraMode", "Mode: Orbit")

	# Sprite Facing Section
	var sep1 := HSeparator.new()
	vbox.add_child(sep1)
	_add_section_header(vbox, "=== Sprite Facing ===")

	var sprite_info := VBoxContainer.new()
	sprite_info.name = "SpriteInfo"
	vbox.add_child(sprite_info)

	_add_info_label(sprite_info, "LblSpriteAngle", "Base Angle: 0 deg")
	_add_info_label(sprite_info, "LblSpriteOffset", "Offset: 0 deg")
	_add_info_label(sprite_info, "LblSpriteFinal", "Final: 0 deg")
	_add_info_label(sprite_info, "LblSpriteDir", "Direction: (0, 0, 1)")

	# Formation Section
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)
	_add_section_header(vbox, "=== Formation Facing ===")

	var formation_info := VBoxContainer.new()
	formation_info.name = "FormationInfo"
	vbox.add_child(formation_info)

	_add_info_label(formation_info, "LblFormationAngle", "Angle: 0 deg")
	_add_info_label(formation_info, "LblFormationDir", "Direction: (0, 0, 1)")

	# Mismatch Section
	var sep3 := HSeparator.new()
	vbox.add_child(sep3)
	_add_section_header(vbox, "=== Mismatch Analysis ===")

	var mismatch_info := VBoxContainer.new()
	mismatch_info.name = "MismatchInfo"
	vbox.add_child(mismatch_info)

	_add_info_label(mismatch_info, "LblCamToSprite", "Camera vs Sprite: 0 deg")
	_add_info_label(mismatch_info, "LblSpriteToForm", "Sprite vs Formation: 0 deg")
	_add_info_label(mismatch_info, "LblMismatchStatus", "Status: OK")

	# LOS Cone Section
	var sep_los := HSeparator.new()
	vbox.add_child(sep_los)
	_add_section_header(vbox, "=== LOS Cone ===")

	var los_info := VBoxContainer.new()
	los_info.name = "LOSInfo"
	vbox.add_child(los_info)

	_add_info_label(los_info, "LblLOSVisible", "Visible: ON")
	_add_info_label(los_info, "LblLOSAngle", "FOV Angle: 90 deg")
	_add_info_label(los_info, "LblLOSRange", "Range: 4.0 units")
	_add_info_label(los_info, "LblLOSDirection", "Direction: 0 deg")

	# Controls Section
	var sep4 := HSeparator.new()
	vbox.add_child(sep4)
	_add_section_header(vbox, "=== Edit Controls ===")

	var controls := VBoxContainer.new()
	controls.name = "Controls"
	vbox.add_child(controls)

	# Sprite orientation offset slider
	_add_slider_control(controls, "Sprite Orientation Offset:", "SliderSpriteOffset", -180, 180, 0)

	# Formation facing angle slider
	_add_slider_control(controls, "Formation Facing:", "SliderFormation", 0, 360, 0)

	# Keyboard hints
	var sep5 := HSeparator.new()
	vbox.add_child(sep5)
	_add_section_header(vbox, "=== Keyboard Shortcuts ===")

	var hints := VBoxContainer.new()
	vbox.add_child(hints)

	var hint_texts: Array[String] = [
		"Right-click + drag: Orbit camera",
		"Scroll wheel: Zoom",
		"WASD: Pan camera / Walk (in walk mode)",
		"P: Toggle walk mode",
		"L: Toggle LOS cone",
		"Left/Right arrows: Adjust sprite offset",
		"Up/Down arrows: Adjust formation facing",
		"Shift + arrows: Larger increments",
		"R: Reset orientations",
		"Ctrl+S: Save patches",
		"Home: Reset camera"
	]

	for hint: String in hint_texts:
		var lbl := Label.new()
		lbl.text = hint
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		hints.add_child(lbl)

	# Legend
	var sep6 := HSeparator.new()
	vbox.add_child(sep6)
	_add_section_header(vbox, "=== Arrow Legend ===")

	var legend := VBoxContainer.new()
	vbox.add_child(legend)

	_add_legend_item(legend, "Blue arrow: Camera direction", COLOR_CAMERA)
	_add_legend_item(legend, "Yellow arrow: Sprite facing", COLOR_SPRITE)
	_add_legend_item(legend, "Green arrow: Formation facing", COLOR_FORMATION)
	_add_legend_item(legend, "Red arrow: Mismatch detected", COLOR_MISMATCH)
	_add_legend_item(legend, "Orange cone: LOS (Line of Sight)", Color(1.0, 0.5, 0.0))


func _add_section_header(parent: Control, text: String) -> void:
	var header := Label.new()
	header.text = text
	header.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	parent.add_child(header)


func _add_info_label(parent: Control, lbl_name: String, text: String) -> void:
	var lbl := Label.new()
	lbl.name = lbl_name
	lbl.text = text
	parent.add_child(lbl)


func _add_slider_control(parent: Control, label_text: String, slider_name: String, min_val: float, max_val: float, default: float) -> void:
	var container := VBoxContainer.new()
	parent.add_child(container)

	var lbl := Label.new()
	lbl.text = label_text
	container.add_child(lbl)

	var hbox := HBoxContainer.new()
	container.add_child(hbox)

	var slider := HSlider.new()
	slider.name = slider_name
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = default
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_slider_changed.bind(slider_name))
	hbox.add_child(slider)

	var value_label := Label.new()
	value_label.name = slider_name + "Value"
	value_label.text = "%.1f" % default
	value_label.custom_minimum_size.x = 60
	hbox.add_child(value_label)


func _add_legend_item(parent: Control, text: String, color: Color) -> void:
	var hbox := HBoxContainer.new()
	parent.add_child(hbox)

	var color_box := ColorRect.new()
	color_box.color = color
	color_box.custom_minimum_size = Vector2(16, 16)
	hbox.add_child(color_box)

	var lbl := Label.new()
	lbl.text = "  " + text
	hbox.add_child(lbl)


func _update_debug_panel() -> void:
	var content: VBoxContainer = debug_panel.find_child("Content", true, false) as VBoxContainer
	if not content:
		return

	# Get camera direction
	var camera_forward: Vector3
	var camera_angle_deg: float
	if walk_mode:
		camera_forward = Vector3(sin(walk_yaw), 0, cos(walk_yaw)).normalized()
		camera_angle_deg = rad_to_deg(walk_yaw)
	else:
		camera_forward = Vector3(sin(camera_orbit_angle), 0, cos(camera_orbit_angle)).normalized()
		camera_angle_deg = rad_to_deg(camera_orbit_angle)

	# Camera info
	var cam_info: VBoxContainer = content.find_child("CameraInfo", true, false) as VBoxContainer
	if cam_info:
		_set_label_text(cam_info, "LblCameraAngle", "Angle: %.1f deg" % camera_angle_deg)
		_set_label_text(cam_info, "LblCameraDir", "Direction: (%.2f, 0, %.2f)" % [camera_forward.x, camera_forward.z])
		_set_label_text(cam_info, "LblCameraMode", "Mode: %s" % ("Walk" if walk_mode else "Orbit"))

	# Sprite info
	var sprite_base_angle: float = 0.0
	var sprite_final_angle: float = sprite_orientation_offset
	var sprite_dir := Vector3.FORWARD

	if current_billboard:
		sprite_dir = current_billboard.facing_direction
		sprite_base_angle = rad_to_deg(atan2(sprite_dir.x, sprite_dir.z))
		sprite_final_angle = sprite_base_angle + sprite_orientation_offset

	var sprite_info: VBoxContainer = content.find_child("SpriteInfo", true, false) as VBoxContainer
	if sprite_info:
		_set_label_text(sprite_info, "LblSpriteAngle", "Base Angle: %.1f deg" % sprite_base_angle)
		_set_label_text(sprite_info, "LblSpriteOffset", "Offset: %.1f deg" % sprite_orientation_offset)
		_set_label_text(sprite_info, "LblSpriteFinal", "Final: %.1f deg" % sprite_final_angle)
		_set_label_text(sprite_info, "LblSpriteDir", "Direction: (%.2f, 0, %.2f)" % [sprite_dir.x, sprite_dir.z])

	# Formation info
	var formation_dir := Vector3(sin(deg_to_rad(formation_facing_angle)), 0, cos(deg_to_rad(formation_facing_angle)))
	var form_info: VBoxContainer = content.find_child("FormationInfo", true, false) as VBoxContainer
	if form_info:
		_set_label_text(form_info, "LblFormationAngle", "Angle: %.1f deg" % formation_facing_angle)
		_set_label_text(form_info, "LblFormationDir", "Direction: (%.2f, 0, %.2f)" % [formation_dir.x, formation_dir.z])

	# Mismatch analysis
	var cam_to_sprite: float = wrapf(camera_angle_deg - sprite_final_angle, -180, 180)
	var sprite_to_form: float = wrapf(sprite_final_angle - formation_facing_angle, -180, 180)
	var has_mismatch: bool = absf(sprite_to_form) > 10.0

	var mismatch_info: VBoxContainer = content.find_child("MismatchInfo", true, false) as VBoxContainer
	if mismatch_info:
		_set_label_text(mismatch_info, "LblCamToSprite", "Camera vs Sprite: %.1f deg" % cam_to_sprite)
		_set_label_text(mismatch_info, "LblSpriteToForm", "Sprite vs Formation: %.1f deg" % sprite_to_form)

		var status_label: Label = mismatch_info.find_child("LblMismatchStatus", true, false) as Label
		if status_label:
			if has_mismatch:
				status_label.text = "Status: MISMATCH DETECTED"
				status_label.add_theme_color_override("font_color", COLOR_MISMATCH)
			else:
				status_label.text = "Status: OK (aligned)"
				status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))

	# LOS Cone info
	var los_info: VBoxContainer = content.find_child("LOSInfo", true, false) as VBoxContainer
	if los_info:
		_set_label_text(los_info, "LblLOSVisible", "Visible: %s" % ("ON" if los_cone_visible else "OFF"))
		_set_label_text(los_info, "LblLOSAngle", "FOV Angle: %.0f deg" % LOS_CONE_ANGLE)
		_set_label_text(los_info, "LblLOSRange", "Range: %.1f units" % LOS_CONE_RANGE)
		_set_label_text(los_info, "LblLOSDirection", "Direction: %.1f deg" % sprite_final_angle)


func _set_label_text(parent: Control, label_name: String, text: String) -> void:
	var label: Label = parent.find_child(label_name, true, false) as Label
	if label:
		label.text = text


func _on_slider_changed(value: float, slider_name: String) -> void:
	# Update value display
	var content: VBoxContainer = debug_panel.find_child("Content", true, false) as VBoxContainer
	if content:
		var value_label: Label = content.find_child(slider_name + "Value", true, false) as Label
		if value_label:
			value_label.text = "%.1f" % value

	match slider_name:
		"SliderSpriteOffset":
			sprite_orientation_offset = value
			_mark_modified()
		"SliderFormation":
			formation_facing_angle = value


func _populate_unit_list() -> void:
	unit_select.clear()

	# Get all actors from zoo registry
	var actors: Array[Dictionary] = ZooRegistry.get_all_actors()

	for actor: Dictionary in actors:
		var actor_id: String = actor.get("id", "")
		var actor_name: String = actor.get("name", "Unknown")
		unit_select.add_item("%s (%s)" % [actor_name, actor_id])
		unit_select.set_item_metadata(unit_select.item_count - 1, actor)

	# Select first unit if available
	if unit_select.item_count > 0:
		unit_select.select(0)
		_on_unit_selected(0)


func _on_unit_selected(index: int) -> void:
	if index < 0 or index >= unit_select.item_count:
		return

	var actor: Dictionary = unit_select.get_item_metadata(index) as Dictionary
	_spawn_unit(actor)


func _spawn_unit(actor: Dictionary) -> void:
	# Clear existing unit
	if current_unit:
		current_unit.queue_free()
		current_unit = null
		current_billboard = null

	current_actor_data = actor

	var sprite_path: String = actor.get("sprite_path", "")
	if sprite_path.is_empty() or not ResourceLoader.exists(sprite_path):
		_spawn_placeholder()
		return

	var texture: Texture2D = load(sprite_path)
	if not texture:
		_spawn_placeholder()
		return

	# Create billboard sprite
	current_unit = Node3D.new()
	current_unit.name = "Unit_" + actor.get("id", "unknown")
	unit_container.add_child(current_unit)

	current_billboard = BillboardSprite.new()
	current_billboard.sprite_sheet = texture
	current_billboard.h_frames = actor.get("h_frames", 1)
	current_billboard.v_frames = actor.get("v_frames", 1)
	current_billboard.pixel_size = actor.get("pixel_size", 0.03)
	current_billboard.offset_y = actor.get("offset_y", 0.0)
	current_billboard.idle_frames = actor.get("idle_frames", current_billboard.h_frames)
	current_billboard.walk_frames = actor.get("walk_frames", current_billboard.h_frames)
	current_billboard.idle_fps = actor.get("idle_fps", 3.0)
	current_billboard.walk_fps = actor.get("walk_fps", 6.0)

	current_unit.add_child(current_billboard)

	# Load any saved orientation offset for this unit
	var actor_id: String = actor.get("id", "")
	if modified_orientations.has(actor_id):
		sprite_orientation_offset = modified_orientations[actor_id]
	else:
		sprite_orientation_offset = 0.0

	# Update UI slider
	_update_slider_value("SliderSpriteOffset", sprite_orientation_offset)


func _spawn_placeholder() -> void:
	current_unit = Node3D.new()
	current_unit.name = "Placeholder"
	unit_container.add_child(current_unit)

	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 2.0, 0.1)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.2, 0.2)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat

	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0, 1.0, 0)
	current_unit.add_child(mesh_instance)

	current_billboard = null


func _update_slider_value(slider_name: String, value: float) -> void:
	var content: VBoxContainer = debug_panel.find_child("Content", true, false) as VBoxContainer
	if content:
		var slider: HSlider = content.find_child(slider_name, true, false) as HSlider
		if slider:
			slider.set_value_no_signal(value)
		var value_label: Label = content.find_child(slider_name + "Value", true, false) as Label
		if value_label:
			value_label.text = "%.1f" % value


## ============================================================================
## CAMERA - Matches ActorZoo exactly
## ============================================================================

func _handle_camera_input(delta: float) -> void:
	if Input.is_key_pressed(KEY_CTRL):
		return  # Don't move camera during Ctrl+S

	var move := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		move.z -= 1
	if Input.is_key_pressed(KEY_S):
		move.z += 1
	if Input.is_key_pressed(KEY_A):
		move.x -= 1
	if Input.is_key_pressed(KEY_D):
		move.x += 1

	if move.length_squared() > 0:
		move = move.normalized()
		move = move.rotated(Vector3.UP, camera_orbit_angle)
		camera_target += move * CAMERA_SPEED * delta
		_update_camera_position()


func _update_camera_position() -> void:
	var offset := Vector3(
		sin(camera_orbit_angle) * cos(camera_pitch) * camera_distance,
		-sin(camera_pitch) * camera_distance,
		cos(camera_orbit_angle) * cos(camera_pitch) * camera_distance
	)

	camera.position = camera_target + offset
	camera.look_at(camera_target)


func _reset_camera() -> void:
	camera_distance = 8.0
	camera_orbit_angle = 0.0
	camera_pitch = -0.3
	camera_target = Vector3.ZERO
	_update_camera_position()


func _toggle_walk_mode() -> void:
	walk_mode = not walk_mode

	if walk_mode:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		walk_position = Vector3(camera_target.x, PLAYER_EYE_HEIGHT, camera_target.z + 5)
		walk_yaw = 0.0
		walk_pitch = 0.0
		_update_walk_camera()
		print("[UnitViewer] Walk mode ON - WASD to move, mouse to look, P to exit")
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera_target = Vector3(walk_position.x, 0, walk_position.z)
		_update_camera_position()
		print("[UnitViewer] Walk mode OFF - Orbit camera restored")


func _handle_walk_input(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	var speed: float = WALK_SPEED
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= WALK_SPRINT_MULT

	var input_dir := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1

	if input_dir.length_squared() > 0:
		input_dir = input_dir.normalized()
		input_dir = input_dir.rotated(Vector3.UP, walk_yaw)
		walk_position += input_dir * speed * delta
		walk_position.y = PLAYER_EYE_HEIGHT
		_update_walk_camera()


func _update_walk_camera() -> void:
	camera.position = walk_position
	camera.rotation = Vector3(walk_pitch, walk_yaw, 0)


## ============================================================================
## ORIENTATION EDITING
## ============================================================================

func _adjust_sprite_orientation(amount: float) -> void:
	sprite_orientation_offset += amount
	sprite_orientation_offset = wrapf(sprite_orientation_offset, -180, 180)
	_update_slider_value("SliderSpriteOffset", sprite_orientation_offset)
	_mark_modified()


func _adjust_formation_facing(amount: float) -> void:
	formation_facing_angle += amount
	formation_facing_angle = wrapf(formation_facing_angle, 0, 360)
	_update_slider_value("SliderFormation", formation_facing_angle)


func _reset_orientations() -> void:
	sprite_orientation_offset = 0.0
	formation_facing_angle = 0.0
	_update_slider_value("SliderSpriteOffset", 0.0)
	_update_slider_value("SliderFormation", 0.0)


func _mark_modified() -> void:
	if current_actor_data.is_empty():
		return

	var actor_id: String = current_actor_data.get("id", "")
	if not actor_id.is_empty():
		modified_orientations[actor_id] = sprite_orientation_offset


## ============================================================================
## PERSISTENCE
## ============================================================================

func _load_patches() -> void:
	if not FileAccess.file_exists(PATCH_FILE):
		return

	var file := FileAccess.open(PATCH_FILE, FileAccess.READ)
	if not file:
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_warning("[UnitViewer] Failed to parse patches: %s" % json.get_error_message())
		return

	modified_orientations = json.data as Dictionary
	print("[UnitViewer] Loaded %d orientation patches from %s" % [modified_orientations.size(), PATCH_FILE])


func _save_patches() -> void:
	var file := FileAccess.open(PATCH_FILE, FileAccess.WRITE)
	if not file:
		push_error("[UnitViewer] Failed to save patches")
		return

	file.store_string(JSON.stringify(modified_orientations, "\t"))
	file.close()

	print("[UnitViewer] Saved %d orientation patches to %s" % [modified_orientations.size(), PATCH_FILE])
