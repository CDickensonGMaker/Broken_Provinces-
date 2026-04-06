@tool
class_name Editor3DViewport
extends Control
## Reusable 3D viewport with camera controls for level editors
## Supports: Orbit camera, pan, zoom, element placement

signal element_clicked(position: Vector3)
signal element_placed(position: Vector3)
signal element_selected(node: Node3D)
signal camera_moved(position: Vector3)
signal mouse_moved_on_ground(position: Vector3)

## Viewport and camera
var sub_viewport: SubViewport
var camera: Camera3D
var world: World3D
var environment: WorldEnvironment

## Camera settings
var camera_distance: float = 50.0
var camera_pitch: float = -45.0  # Degrees
var camera_yaw: float = 0.0  # Degrees
var camera_target: Vector3 = Vector3.ZERO
var min_distance: float = 5.0
var max_distance: float = 200.0

## Input state
var is_orbiting: bool = false
var is_panning: bool = false
var last_mouse_pos: Vector2 = Vector2.ZERO

## Ground plane for raycasting
var ground_plane: StaticBody3D
var ground_mesh: MeshInstance3D

## Content container (for placed elements)
var content_root: Node3D

## Ghost preview
var ghost_preview: Node3D = null
var ghost_material: StandardMaterial3D
var ghost_material_valid: StandardMaterial3D
var ghost_material_invalid: StandardMaterial3D
var ghost_is_valid: bool = true

## Footprint preview (shows building XZ bounds on ground)
var footprint_preview: MeshInstance3D = null
var footprint_material_valid: StandardMaterial3D
var footprint_material_invalid: StandardMaterial3D


func _ready() -> void:
	# Ensure this control catches mouse events for element placement
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_viewport()
	_setup_camera()
	_setup_environment()
	_setup_ground()
	_setup_content_root()
	_setup_ghost_material()


func _setup_viewport() -> void:
	# Create container first
	var viewport_container := SubViewportContainer.new()
	viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	# Pass mouse events to parent (Editor3DViewport) for handling
	viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(viewport_container)

	# Create viewport as child of container
	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(800, 600)
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub_viewport.handle_input_locally = true
	sub_viewport.gui_disable_input = false
	viewport_container.add_child(sub_viewport)


func _setup_camera() -> void:
	camera = Camera3D.new()
	camera.name = "EditorCamera"
	camera.current = true
	camera.fov = 60.0
	camera.near = 0.1
	camera.far = 500.0
	sub_viewport.add_child(camera)
	_update_camera_position()


func _setup_environment() -> void:
	environment = WorldEnvironment.new()
	environment.name = "Environment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.25, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.65, 0.7)
	env.ambient_light_energy = 0.6

	environment.environment = env
	sub_viewport.add_child(environment)

	# Directional light
	var sun := DirectionalLight3D.new()
	sun.name = "EditorSun"
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sub_viewport.add_child(sun)


func _setup_ground() -> void:
	ground_plane = StaticBody3D.new()
	ground_plane.name = "GroundPlane"
	ground_plane.collision_layer = 1
	ground_plane.collision_mask = 0

	# Collision shape
	var col := CollisionShape3D.new()
	var plane_shape := WorldBoundaryShape3D.new()
	plane_shape.plane = Plane(Vector3.UP, 0)
	col.shape = plane_shape
	ground_plane.add_child(col)

	# Visual mesh
	ground_mesh = MeshInstance3D.new()
	ground_mesh.name = "GroundMesh"
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(200, 200)
	ground_mesh.mesh = plane_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.32, 0.28)
	mat.roughness = 0.9
	ground_mesh.material_override = mat
	ground_plane.add_child(ground_mesh)

	# Grid overlay
	_create_grid_overlay()

	sub_viewport.add_child(ground_plane)


func _create_grid_overlay(half_size: float = 50.0) -> void:
	var grid := ImmediateMesh.new()
	var grid_instance := MeshInstance3D.new()
	grid_instance.name = "GridOverlay"

	# Create grid lines
	grid.clear_surfaces()
	grid.surface_begin(Mesh.PRIMITIVE_LINES)

	var grid_size: float = half_size
	var grid_step: float = 2.0
	var grid_color := Color(0.4, 0.42, 0.38, 0.5)

	# X lines
	var z: float = -grid_size
	while z <= grid_size:
		grid.surface_set_color(grid_color)
		grid.surface_add_vertex(Vector3(-grid_size, 0.01, z))
		grid.surface_add_vertex(Vector3(grid_size, 0.01, z))
		z += grid_step

	# Z lines
	var x: float = -grid_size
	while x <= grid_size:
		grid.surface_set_color(grid_color)
		grid.surface_add_vertex(Vector3(x, 0.01, -grid_size))
		grid.surface_add_vertex(Vector3(x, 0.01, grid_size))
		x += grid_step

	grid.surface_end()
	grid_instance.mesh = grid

	var grid_mat := StandardMaterial3D.new()
	grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_mat.vertex_color_use_as_albedo = true
	grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid_instance.material_override = grid_mat

	ground_plane.add_child(grid_instance)


func _setup_content_root() -> void:
	content_root = Node3D.new()
	content_root.name = "Content"
	sub_viewport.add_child(content_root)


func _setup_ghost_material() -> void:
	# Default ghost material (blue - for backward compatibility)
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.3, 0.7, 1.0, 0.5)
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Valid placement ghost (green)
	ghost_material_valid = StandardMaterial3D.new()
	ghost_material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_valid.albedo_color = Color(0.3, 0.85, 0.4, 0.5)
	ghost_material_valid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Invalid placement ghost (red)
	ghost_material_invalid = StandardMaterial3D.new()
	ghost_material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material_invalid.albedo_color = Color(0.85, 0.3, 0.3, 0.5)
	ghost_material_invalid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Footprint materials
	footprint_material_valid = StandardMaterial3D.new()
	footprint_material_valid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_material_valid.albedo_color = Color(0.2, 0.8, 0.3, 0.35)
	footprint_material_valid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint_material_valid.cull_mode = BaseMaterial3D.CULL_DISABLED

	footprint_material_invalid = StandardMaterial3D.new()
	footprint_material_invalid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	footprint_material_invalid.albedo_color = Color(0.8, 0.2, 0.2, 0.35)
	footprint_material_invalid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	footprint_material_invalid.cull_mode = BaseMaterial3D.CULL_DISABLED


func _update_camera_position() -> void:
	if not camera:
		return

	var pitch_rad := deg_to_rad(camera_pitch)
	var yaw_rad := deg_to_rad(camera_yaw)

	var offset := Vector3(
		sin(yaw_rad) * cos(pitch_rad),
		-sin(pitch_rad),
		cos(yaw_rad) * cos(pitch_rad)
	) * camera_distance

	camera.global_position = camera_target + offset
	camera.look_at(camera_target)
	camera_moved.emit(camera.global_position)


func _gui_input(event: InputEvent) -> void:
	# Workaround for Godot SubViewport input issues - manually push mouse events
	if sub_viewport and event is InputEventMouse:
		sub_viewport.push_input(event.duplicate())

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				if event.shift_pressed:
					is_panning = true
				else:
					is_orbiting = true
				last_mouse_pos = event.position
			else:
				is_orbiting = false
				is_panning = false

		MOUSE_BUTTON_LEFT:
			if event.pressed and not event.is_echo():
				var world_pos := _raycast_to_ground(event.position)
				if world_pos != null:
					element_clicked.emit(world_pos)
					if ghost_preview:
						element_placed.emit(world_pos)

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				is_orbiting = true
				last_mouse_pos = event.position
			else:
				is_orbiting = false

		MOUSE_BUTTON_WHEEL_UP:
			camera_distance = maxf(min_distance, camera_distance - camera_distance * 0.1)
			_update_camera_position()

		MOUSE_BUTTON_WHEEL_DOWN:
			camera_distance = minf(max_distance, camera_distance + camera_distance * 0.1)
			_update_camera_position()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var delta := event.position - last_mouse_pos
	last_mouse_pos = event.position

	if is_orbiting:
		camera_yaw -= delta.x * 0.5
		camera_pitch = clampf(camera_pitch - delta.y * 0.5, -89.0, -10.0)
		_update_camera_position()

	elif is_panning:
		var pan_speed := camera_distance * 0.002
		var right := camera.global_transform.basis.x
		var forward := camera.global_transform.basis.z
		forward.y = 0
		forward = forward.normalized()
		camera_target -= right * delta.x * pan_speed
		camera_target += forward * delta.y * pan_speed
		_update_camera_position()

	# Update ghost preview position and emit mouse position
	var world_pos := _raycast_to_ground(event.position)
	if world_pos != null:
		if ghost_preview:
			ghost_preview.global_position = world_pos
		# Always emit mouse position for pick-up movement
		mouse_moved_on_ground.emit(world_pos)


func _raycast_to_ground(screen_pos: Vector2) -> Variant:
	if not camera or not sub_viewport:
		return null

	# screen_pos from _gui_input is local to this control
	# The SubViewport is 800x600 but stretched to fill this control
	var viewport_size := Vector2(sub_viewport.size)  # 800x600
	var control_size := size

	# Avoid division by zero
	if control_size.x <= 0 or control_size.y <= 0:
		return null

	# Scale screen position to viewport coordinates
	var local_pos := Vector2(
		screen_pos.x / control_size.x * viewport_size.x,
		screen_pos.y / control_size.y * viewport_size.y
	)

	var from := camera.project_ray_origin(local_pos)
	var dir := camera.project_ray_normal(local_pos)

	# Raycast to ground plane (Y = 0)
	var plane := Plane(Vector3.UP, 0)
	var intersection := plane.intersects_ray(from, dir)

	return intersection


## Set the ghost preview model
func set_ghost_preview(model: Node3D) -> void:
	clear_ghost_preview()
	if model:
		ghost_preview = model.duplicate() as Node3D
		if not ghost_preview:
			push_error("[Editor3DViewport] Failed to duplicate model as Node3D")
			return
		ghost_preview.name = "GhostPreview"
		ghost_is_valid = true  # Reset validity when setting new preview
		_apply_ghost_material(ghost_preview)
		if sub_viewport:
			sub_viewport.add_child(ghost_preview)


## Clear ghost preview
func clear_ghost_preview() -> void:
	if ghost_preview and is_instance_valid(ghost_preview):
		ghost_preview.queue_free()
	ghost_preview = null
	clear_footprint_preview()


## Update ghost validity state (changes color to green/red)
func set_ghost_validity(is_valid: bool) -> void:
	if ghost_is_valid == is_valid:
		return  # No change needed

	ghost_is_valid = is_valid
	if ghost_preview and is_instance_valid(ghost_preview):
		var mat := ghost_material_valid if is_valid else ghost_material_invalid
		_apply_ghost_material_with(ghost_preview, mat)

	# Update footprint color too
	if footprint_preview and is_instance_valid(footprint_preview):
		footprint_preview.material_override = footprint_material_valid if is_valid else footprint_material_invalid


## Apply ghost material to all meshes in node
func _apply_ghost_material(node: Node) -> void:
	# Use validity-based material
	var mat := ghost_material_valid if ghost_is_valid else ghost_material_invalid
	_apply_ghost_material_with(node, mat)


## Apply a specific material to all meshes in node
func _apply_ghost_material_with(node: Node, mat: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	if node is CSGShape3D:
		node.material = mat
	for child in node.get_children():
		_apply_ghost_material_with(child, mat)


## Show/update footprint preview (building XZ bounds on ground)
func set_footprint_preview(width: float, depth: float, position: Vector3) -> void:
	if not footprint_preview:
		footprint_preview = MeshInstance3D.new()
		footprint_preview.name = "FootprintPreview"
		var plane_mesh := PlaneMesh.new()
		footprint_preview.mesh = plane_mesh
		footprint_preview.material_override = footprint_material_valid if ghost_is_valid else footprint_material_invalid
		if sub_viewport:
			sub_viewport.add_child(footprint_preview)

	# Update size and position
	if footprint_preview.mesh is PlaneMesh:
		(footprint_preview.mesh as PlaneMesh).size = Vector2(width, depth)
	footprint_preview.global_position = Vector3(position.x, 0.02, position.z)  # Slightly above ground
	footprint_preview.material_override = footprint_material_valid if ghost_is_valid else footprint_material_invalid


## Clear footprint preview
func clear_footprint_preview() -> void:
	if footprint_preview and is_instance_valid(footprint_preview):
		footprint_preview.queue_free()
	footprint_preview = null


## Add content to the viewport
func add_content(node: Node3D) -> void:
	content_root.add_child(node)


## Clear all content immediately
func clear_content() -> void:
	if not content_root:
		print("[Editor3DViewport] clear_content: content_root is null!")
		return

	# IMPORTANT: Make a copy of the children array first!
	# Calling free() modifies the array during iteration, which can skip elements
	var children: Array[Node] = content_root.get_children()
	var freed_count: int = 0
	print("[Editor3DViewport] clear_content: %d children to clear" % children.size())

	for child in children:
		if is_instance_valid(child):
			child.free()
			freed_count += 1

	print("[Editor3DViewport] clear_content: freed %d nodes, remaining: %d" % [
		freed_count,
		content_root.get_child_count()
	])


## Get all content nodes
func get_content() -> Array[Node]:
	return content_root.get_children()


## Focus camera on position
func focus_on(pos: Vector3) -> void:
	camera_target = pos
	_update_camera_position()


## Reset camera to default view
func reset_camera() -> void:
	camera_target = Vector3.ZERO
	camera_distance = 50.0
	camera_pitch = -45.0
	camera_yaw = 0.0
	_update_camera_position()


## Set ground size
func set_ground_size(size_val: float) -> void:
	if ground_mesh and ground_mesh.mesh is PlaneMesh:
		(ground_mesh.mesh as PlaneMesh).size = Vector2(size_val, size_val)


## Resize grid overlay to match ground size
func resize_grid(size_val: float) -> void:
	if not ground_plane:
		return

	# Remove old grid
	var old_grid: Node = ground_plane.get_node_or_null("GridOverlay")
	if old_grid:
		old_grid.queue_free()

	# Create new grid matching the new size (half_size for +/- extents)
	call_deferred("_create_grid_overlay", size_val / 2.0)
