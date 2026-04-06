@tool
## create_room_templates.gd - EditorScript to generate starter room scene templates
## Run this from the editor to create all the basic room .tscn files
##
## Usage: Open this script in the editor and run it via Script > Run
extends EditorScript


const ROOM_SIZE: float = 16.0
const WALL_HEIGHT: float = 4.0
const WALL_THICKNESS: float = 0.5
const DOOR_WIDTH: float = 3.0
const DOOR_HEIGHT: float = 3.0
const OUTPUT_PATH: String = "res://scenes/dungeons/rooms/"


## Room templates to generate
const TEMPLATES: Array = [
	# Basic rooms
	{"name": "room_start", "doors": ["n", "s", "e", "w"], "color": Color(0.3, 0.5, 0.3)},

	# Corridors
	{"name": "corridor_ns", "doors": ["n", "s"], "color": Color(0.4, 0.4, 0.4)},
	{"name": "corridor_ew", "doors": ["e", "w"], "color": Color(0.4, 0.4, 0.4)},

	# L-turns
	{"name": "turn_ne", "doors": ["n", "e"], "color": Color(0.45, 0.4, 0.35)},
	{"name": "turn_nw", "doors": ["n", "w"], "color": Color(0.45, 0.4, 0.35)},
	{"name": "turn_se", "doors": ["s", "e"], "color": Color(0.45, 0.4, 0.35)},
	{"name": "turn_sw", "doors": ["s", "w"], "color": Color(0.45, 0.4, 0.35)},

	# T-junctions
	{"name": "t_north", "doors": ["n", "e", "w"], "color": Color(0.5, 0.45, 0.4)},
	{"name": "t_south", "doors": ["s", "e", "w"], "color": Color(0.5, 0.45, 0.4)},
	{"name": "t_east", "doors": ["n", "s", "e"], "color": Color(0.5, 0.45, 0.4)},
	{"name": "t_west", "doors": ["n", "s", "w"], "color": Color(0.5, 0.45, 0.4)},

	# Crossroads
	{"name": "cross", "doors": ["n", "s", "e", "w"], "color": Color(0.55, 0.5, 0.45)},

	# Rooms (all have 4 doors for flexibility)
	{"name": "room_small", "doors": ["n", "s", "e", "w"], "color": Color(0.35, 0.35, 0.45)},
	{"name": "room_medium", "doors": ["n", "s", "e", "w"], "color": Color(0.35, 0.4, 0.45)},
	{"name": "room_large", "doors": ["n", "s", "e", "w"], "color": Color(0.4, 0.4, 0.5)},
	{"name": "room_boss", "doors": ["n", "s", "e", "w"], "color": Color(0.5, 0.3, 0.3)},

	# Dead ends
	{"name": "dead_end_n", "doors": ["n"], "color": Color(0.35, 0.3, 0.3)},
	{"name": "dead_end_s", "doors": ["s"], "color": Color(0.35, 0.3, 0.3)},
	{"name": "dead_end_e", "doors": ["e"], "color": Color(0.35, 0.3, 0.3)},
	{"name": "dead_end_w", "doors": ["w"], "color": Color(0.35, 0.3, 0.3)}
]


func _run() -> void:
	print("[CreateRoomTemplates] Starting room template generation...")

	# Ensure output directory exists
	var dir := DirAccess.open("res://")
	if not dir:
		push_error("[CreateRoomTemplates] Cannot access res://")
		return

	if not dir.dir_exists("scenes/dungeons"):
		dir.make_dir_recursive("scenes/dungeons/rooms")
	elif not dir.dir_exists("scenes/dungeons/rooms"):
		dir.make_dir("scenes/dungeons/rooms")

	var created_count: int = 0
	var skipped_count: int = 0

	for template: Dictionary in TEMPLATES:
		var room_name: String = template["name"]
		var doors: Array = template["doors"]
		var color: Color = template.get("color", Color(0.4, 0.4, 0.4))

		var scene_path: String = OUTPUT_PATH + room_name + ".tscn"

		# Check if scene already exists
		if ResourceLoader.exists(scene_path):
			print("[CreateRoomTemplates] Skipping existing: %s" % room_name)
			skipped_count += 1
			continue

		# Create the room scene
		var room_scene: PackedScene = _create_room_scene(room_name, doors, color)
		if room_scene:
			var error: int = ResourceSaver.save(room_scene, scene_path)
			if error == OK:
				print("[CreateRoomTemplates] Created: %s" % scene_path)
				created_count += 1
			else:
				push_error("[CreateRoomTemplates] Failed to save: %s (error %d)" % [scene_path, error])
		else:
			push_error("[CreateRoomTemplates] Failed to create scene: %s" % room_name)

	print("[CreateRoomTemplates] Done! Created: %d, Skipped: %d" % [created_count, skipped_count])


func _create_room_scene(room_name: String, doors: Array, floor_color: Color) -> PackedScene:
	# Create root node
	var root := Node3D.new()
	root.name = room_name.to_pascal_case()

	# Create geometry container
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	root.add_child(geometry)
	geometry.owner = root

	# Create floor
	var floor_mesh := _create_floor(floor_color)
	floor_mesh.name = "Floor"
	geometry.add_child(floor_mesh)
	floor_mesh.owner = root

	# Create ceiling
	var ceiling_mesh := _create_ceiling()
	ceiling_mesh.name = "Ceiling"
	geometry.add_child(ceiling_mesh)
	ceiling_mesh.owner = root

	# Create walls with door openings
	var walls := _create_walls(doors)
	walls.name = "Walls"
	geometry.add_child(walls)
	walls.owner = root
	for child: Node in walls.get_children():
		child.owner = root

	# Create SpawnPoints container
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	root.add_child(spawn_points)
	spawn_points.owner = root

	# Add default spawn point at center
	var spawn_marker := Marker3D.new()
	spawn_marker.name = "SpawnPoint"
	spawn_marker.position = Vector3(ROOM_SIZE / 2.0, 0.5, ROOM_SIZE / 2.0)
	spawn_marker.set_meta("spawn_id", "default")
	spawn_points.add_child(spawn_marker)
	spawn_marker.owner = root

	# Create EnemySpawns container
	var enemy_spawns := Node3D.new()
	enemy_spawns.name = "EnemySpawns"
	root.add_child(enemy_spawns)
	enemy_spawns.owner = root

	# Create ChestPositions container
	var chest_positions := Node3D.new()
	chest_positions.name = "ChestPositions"
	root.add_child(chest_positions)
	chest_positions.owner = root

	# Create collision for floor and walls
	var collision := _create_collision(doors)
	collision.name = "Collision"
	root.add_child(collision)
	collision.owner = root
	for child: Node in collision.get_children():
		child.owner = root

	# Pack into scene
	var packed_scene := PackedScene.new()
	var error: int = packed_scene.pack(root)
	if error != OK:
		push_error("[CreateRoomTemplates] Failed to pack scene: %s" % room_name)
		return null

	# Clean up
	root.queue_free()

	return packed_scene


func _create_floor(color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(ROOM_SIZE, ROOM_SIZE)
	mesh_instance.mesh = plane_mesh

	# Position floor at room center
	mesh_instance.position = Vector3(ROOM_SIZE / 2.0, 0.0, ROOM_SIZE / 2.0)

	# Create material
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material

	return mesh_instance


func _create_ceiling() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()

	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(ROOM_SIZE, ROOM_SIZE)
	mesh_instance.mesh = plane_mesh

	# Position ceiling at room center, flipped
	mesh_instance.position = Vector3(ROOM_SIZE / 2.0, WALL_HEIGHT, ROOM_SIZE / 2.0)
	mesh_instance.rotation_degrees.x = 180

	# Create dark material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.15, 0.15)
	material.roughness = 1.0
	mesh_instance.material_override = material

	return mesh_instance


func _create_walls(doors: Array) -> Node3D:
	var walls_container := Node3D.new()

	# Wall material
	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_color = Color(0.35, 0.32, 0.3)
	wall_material.roughness = 0.85

	# Create each wall
	# North wall (at Z = 0)
	if "n" in doors:
		_add_wall_with_door(walls_container, wall_material, "North", Vector3.FORWARD)
	else:
		_add_solid_wall(walls_container, wall_material, "North", Vector3.FORWARD)

	# South wall (at Z = ROOM_SIZE)
	if "s" in doors:
		_add_wall_with_door(walls_container, wall_material, "South", Vector3.BACK)
	else:
		_add_solid_wall(walls_container, wall_material, "South", Vector3.BACK)

	# East wall (at X = ROOM_SIZE)
	if "e" in doors:
		_add_wall_with_door(walls_container, wall_material, "East", Vector3.RIGHT)
	else:
		_add_solid_wall(walls_container, wall_material, "East", Vector3.RIGHT)

	# West wall (at X = 0)
	if "w" in doors:
		_add_wall_with_door(walls_container, wall_material, "West", Vector3.LEFT)
	else:
		_add_solid_wall(walls_container, wall_material, "West", Vector3.LEFT)

	return walls_container


func _add_solid_wall(parent: Node3D, material: Material, wall_name: String, direction: Vector3) -> void:
	var wall := MeshInstance3D.new()
	wall.name = "Wall" + wall_name

	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS)
	wall.mesh = box_mesh
	wall.material_override = material

	# Position based on direction
	match direction:
		Vector3.FORWARD:  # North
			wall.position = Vector3(ROOM_SIZE / 2.0, WALL_HEIGHT / 2.0, WALL_THICKNESS / 2.0)
		Vector3.BACK:  # South
			wall.position = Vector3(ROOM_SIZE / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE - WALL_THICKNESS / 2.0)
		Vector3.RIGHT:  # East
			wall.position = Vector3(ROOM_SIZE - WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE / 2.0)
			wall.rotation_degrees.y = 90
		Vector3.LEFT:  # West
			wall.position = Vector3(WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE / 2.0)
			wall.rotation_degrees.y = 90

	parent.add_child(wall)


func _add_wall_with_door(parent: Node3D, material: Material, wall_name: String, direction: Vector3) -> void:
	# Create three segments: left, above door, right
	var door_center: float = ROOM_SIZE / 2.0
	var segment_width: float = (ROOM_SIZE - DOOR_WIDTH) / 2.0
	var above_door_height: float = WALL_HEIGHT - DOOR_HEIGHT

	# Left segment
	var left := MeshInstance3D.new()
	left.name = "Wall" + wall_name + "Left"
	var left_mesh := BoxMesh.new()
	left_mesh.size = Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS)
	left.mesh = left_mesh
	left.material_override = material

	# Right segment
	var right := MeshInstance3D.new()
	right.name = "Wall" + wall_name + "Right"
	var right_mesh := BoxMesh.new()
	right_mesh.size = Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS)
	right.mesh = right_mesh
	right.material_override = material

	# Above door segment
	var above := MeshInstance3D.new()
	above.name = "Wall" + wall_name + "Above"
	var above_mesh := BoxMesh.new()
	above_mesh.size = Vector3(DOOR_WIDTH, above_door_height, WALL_THICKNESS)
	above.mesh = above_mesh
	above.material_override = material

	# Position based on direction
	match direction:
		Vector3.FORWARD:  # North
			var z_pos: float = WALL_THICKNESS / 2.0
			left.position = Vector3(segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
			right.position = Vector3(ROOM_SIZE - segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
			above.position = Vector3(door_center, DOOR_HEIGHT + above_door_height / 2.0, z_pos)

		Vector3.BACK:  # South
			var z_pos: float = ROOM_SIZE - WALL_THICKNESS / 2.0
			left.position = Vector3(segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
			right.position = Vector3(ROOM_SIZE - segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
			above.position = Vector3(door_center, DOOR_HEIGHT + above_door_height / 2.0, z_pos)

		Vector3.RIGHT:  # East
			var x_pos: float = ROOM_SIZE - WALL_THICKNESS / 2.0
			left.position = Vector3(x_pos, WALL_HEIGHT / 2.0, segment_width / 2.0)
			left.rotation_degrees.y = 90
			right.position = Vector3(x_pos, WALL_HEIGHT / 2.0, ROOM_SIZE - segment_width / 2.0)
			right.rotation_degrees.y = 90
			above.position = Vector3(x_pos, DOOR_HEIGHT + above_door_height / 2.0, door_center)
			above.rotation_degrees.y = 90

		Vector3.LEFT:  # West
			var x_pos: float = WALL_THICKNESS / 2.0
			left.position = Vector3(x_pos, WALL_HEIGHT / 2.0, segment_width / 2.0)
			left.rotation_degrees.y = 90
			right.position = Vector3(x_pos, WALL_HEIGHT / 2.0, ROOM_SIZE - segment_width / 2.0)
			right.rotation_degrees.y = 90
			above.position = Vector3(x_pos, DOOR_HEIGHT + above_door_height / 2.0, door_center)
			above.rotation_degrees.y = 90

	parent.add_child(left)
	parent.add_child(right)
	parent.add_child(above)


func _create_collision(doors: Array) -> StaticBody3D:
	var static_body := StaticBody3D.new()

	# Floor collision
	var floor_shape := CollisionShape3D.new()
	floor_shape.name = "FloorCollision"
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(ROOM_SIZE, 0.1, ROOM_SIZE)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(ROOM_SIZE / 2.0, -0.05, ROOM_SIZE / 2.0)
	static_body.add_child(floor_shape)

	# Wall collisions (simplified - full walls for now)
	# In a real implementation, you'd want door-aware collision shapes
	_add_wall_collision(static_body, "North", Vector3.FORWARD, "n" in doors)
	_add_wall_collision(static_body, "South", Vector3.BACK, "s" in doors)
	_add_wall_collision(static_body, "East", Vector3.RIGHT, "e" in doors)
	_add_wall_collision(static_body, "West", Vector3.LEFT, "w" in doors)

	return static_body


func _add_wall_collision(parent: StaticBody3D, wall_name: String, direction: Vector3, has_door: bool) -> void:
	if has_door:
		# Add collision segments around door
		var segment_width: float = (ROOM_SIZE - DOOR_WIDTH) / 2.0
		var above_door_height: float = WALL_HEIGHT - DOOR_HEIGHT

		# Left segment
		var left_shape := CollisionShape3D.new()
		left_shape.name = wall_name + "LeftCollision"
		var left_box := BoxShape3D.new()
		left_box.size = Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS)
		left_shape.shape = left_box

		# Right segment
		var right_shape := CollisionShape3D.new()
		right_shape.name = wall_name + "RightCollision"
		var right_box := BoxShape3D.new()
		right_box.size = Vector3(segment_width, WALL_HEIGHT, WALL_THICKNESS)
		right_shape.shape = right_box

		# Above door
		var above_shape := CollisionShape3D.new()
		above_shape.name = wall_name + "AboveCollision"
		var above_box := BoxShape3D.new()
		above_box.size = Vector3(DOOR_WIDTH, above_door_height, WALL_THICKNESS)
		above_shape.shape = above_box

		match direction:
			Vector3.FORWARD:
				var z_pos: float = WALL_THICKNESS / 2.0
				left_shape.position = Vector3(segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
				right_shape.position = Vector3(ROOM_SIZE - segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
				above_shape.position = Vector3(ROOM_SIZE / 2.0, DOOR_HEIGHT + above_door_height / 2.0, z_pos)
			Vector3.BACK:
				var z_pos: float = ROOM_SIZE - WALL_THICKNESS / 2.0
				left_shape.position = Vector3(segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
				right_shape.position = Vector3(ROOM_SIZE - segment_width / 2.0, WALL_HEIGHT / 2.0, z_pos)
				above_shape.position = Vector3(ROOM_SIZE / 2.0, DOOR_HEIGHT + above_door_height / 2.0, z_pos)
			Vector3.RIGHT:
				var x_pos: float = ROOM_SIZE - WALL_THICKNESS / 2.0
				left_shape.position = Vector3(x_pos, WALL_HEIGHT / 2.0, segment_width / 2.0)
				left_shape.rotation_degrees.y = 90
				right_shape.position = Vector3(x_pos, WALL_HEIGHT / 2.0, ROOM_SIZE - segment_width / 2.0)
				right_shape.rotation_degrees.y = 90
				above_shape.position = Vector3(x_pos, DOOR_HEIGHT + above_door_height / 2.0, ROOM_SIZE / 2.0)
				above_shape.rotation_degrees.y = 90
			Vector3.LEFT:
				var x_pos: float = WALL_THICKNESS / 2.0
				left_shape.position = Vector3(x_pos, WALL_HEIGHT / 2.0, segment_width / 2.0)
				left_shape.rotation_degrees.y = 90
				right_shape.position = Vector3(x_pos, WALL_HEIGHT / 2.0, ROOM_SIZE - segment_width / 2.0)
				right_shape.rotation_degrees.y = 90
				above_shape.position = Vector3(x_pos, DOOR_HEIGHT + above_door_height / 2.0, ROOM_SIZE / 2.0)
				above_shape.rotation_degrees.y = 90

		parent.add_child(left_shape)
		parent.add_child(right_shape)
		parent.add_child(above_shape)
	else:
		# Full wall collision
		var wall_shape := CollisionShape3D.new()
		wall_shape.name = wall_name + "Collision"
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(ROOM_SIZE, WALL_HEIGHT, WALL_THICKNESS)
		wall_shape.shape = wall_box

		match direction:
			Vector3.FORWARD:
				wall_shape.position = Vector3(ROOM_SIZE / 2.0, WALL_HEIGHT / 2.0, WALL_THICKNESS / 2.0)
			Vector3.BACK:
				wall_shape.position = Vector3(ROOM_SIZE / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE - WALL_THICKNESS / 2.0)
			Vector3.RIGHT:
				wall_shape.position = Vector3(ROOM_SIZE - WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE / 2.0)
				wall_shape.rotation_degrees.y = 90
			Vector3.LEFT:
				wall_shape.position = Vector3(WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, ROOM_SIZE / 2.0)
				wall_shape.rotation_degrees.y = 90

		parent.add_child(wall_shape)
