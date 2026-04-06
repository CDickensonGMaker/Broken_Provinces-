## dungeon_builder.gd - Builds dungeons from validated grid layouts
## Instantiates room scenes at grid positions and handles connections
class_name DungeonBuilder
extends RefCounted


## Room size constant (16x16 meter rooms)
const ROOM_SIZE: float = 16.0


## Maps room types to their scene paths
const ROOM_SCENES: Dictionary = {
	DungeonGridData.RoomType.START: "res://scenes/dungeons/rooms/room_start.tscn",
	DungeonGridData.RoomType.CORRIDOR_NS: "res://scenes/dungeons/rooms/corridor_ns.tscn",
	DungeonGridData.RoomType.CORRIDOR_EW: "res://scenes/dungeons/rooms/corridor_ew.tscn",
	DungeonGridData.RoomType.TURN_NE: "res://scenes/dungeons/rooms/turn_ne.tscn",
	DungeonGridData.RoomType.TURN_NW: "res://scenes/dungeons/rooms/turn_nw.tscn",
	DungeonGridData.RoomType.TURN_SE: "res://scenes/dungeons/rooms/turn_se.tscn",
	DungeonGridData.RoomType.TURN_SW: "res://scenes/dungeons/rooms/turn_sw.tscn",
	DungeonGridData.RoomType.T_NORTH: "res://scenes/dungeons/rooms/t_north.tscn",
	DungeonGridData.RoomType.T_SOUTH: "res://scenes/dungeons/rooms/t_south.tscn",
	DungeonGridData.RoomType.T_EAST: "res://scenes/dungeons/rooms/t_east.tscn",
	DungeonGridData.RoomType.T_WEST: "res://scenes/dungeons/rooms/t_west.tscn",
	DungeonGridData.RoomType.CROSS: "res://scenes/dungeons/rooms/cross.tscn",
	DungeonGridData.RoomType.ROOM_SMALL: "res://scenes/dungeons/rooms/room_small.tscn",
	DungeonGridData.RoomType.ROOM_MEDIUM: "res://scenes/dungeons/rooms/room_medium.tscn",
	DungeonGridData.RoomType.ROOM_LARGE: "res://scenes/dungeons/rooms/room_large.tscn",
	DungeonGridData.RoomType.ROOM_BOSS: "res://scenes/dungeons/rooms/room_boss.tscn",
	DungeonGridData.RoomType.DEAD_END_N: "res://scenes/dungeons/rooms/dead_end_n.tscn",
	DungeonGridData.RoomType.DEAD_END_S: "res://scenes/dungeons/rooms/dead_end_s.tscn",
	DungeonGridData.RoomType.DEAD_END_E: "res://scenes/dungeons/rooms/dead_end_e.tscn",
	DungeonGridData.RoomType.DEAD_END_W: "res://scenes/dungeons/rooms/dead_end_w.tscn",
	DungeonGridData.RoomType.HALLWAY_NS: "res://scenes/dungeons/rooms/hallway_ns.tscn",
	DungeonGridData.RoomType.HALLWAY_EW: "res://scenes/dungeons/rooms/hallway_ew.tscn",
	## Cave room scenes - using new mine kit pieces
	DungeonGridData.RoomType.CAVE_ENTRANCE: "res://scenes/rooms/caves/mine_entrance.tscn",
	DungeonGridData.RoomType.CAVE_EXIT: "res://scenes/rooms/caves/mine_dead_end_medium.tscn",
	DungeonGridData.RoomType.CAVE_CORRIDOR_NS: "res://scenes/rooms/caves/mine_corridor_ns_standard.tscn",
	DungeonGridData.RoomType.CAVE_CORRIDOR_EW: "res://scenes/rooms/caves/mine_corridor_ew_narrow.tscn",
	DungeonGridData.RoomType.CAVE_CORNER_NE: "res://scenes/rooms/caves/mine_corner_se.tscn",
	DungeonGridData.RoomType.CAVE_CORNER_NW: "res://scenes/rooms/caves/mine_corner_nw.tscn",
	DungeonGridData.RoomType.CAVE_CORNER_SE: "res://scenes/rooms/caves/mine_corner_se.tscn",
	DungeonGridData.RoomType.CAVE_CORNER_SW: "res://scenes/rooms/caves/mine_corner_nw.tscn",
	DungeonGridData.RoomType.CAVE_T_JUNCTION: "res://scenes/rooms/caves/mine_corner_se.tscn",
	DungeonGridData.RoomType.CAVE_CROSSROADS: "res://scenes/rooms/caves/mine_chamber_small.tscn",
	DungeonGridData.RoomType.CAVE_DEAD_END: "res://scenes/rooms/caves/mine_dead_end_small.tscn",
	DungeonGridData.RoomType.CAVE_CHAMBER: "res://scenes/rooms/caves/mine_chamber_medium.tscn"
}


## Alternative mine piece scenes for variety (randomly selected when building caves)
const MINE_PIECE_VARIANTS: Dictionary = {
	DungeonGridData.RoomType.CAVE_CORRIDOR_NS: [
		"res://scenes/rooms/caves/mine_corridor_ns_standard.tscn",
		"res://scenes/rooms/caves/mine_corridor_ns_long.tscn",
		"res://scenes/rooms/caves/mine_ramp_down.tscn",
		"res://scenes/rooms/caves/mine_ramp_long.tscn"
	],
	DungeonGridData.RoomType.CAVE_DEAD_END: [
		"res://scenes/rooms/caves/mine_dead_end_small.tscn",
		"res://scenes/rooms/caves/mine_dead_end_medium.tscn"
	],
	DungeonGridData.RoomType.CAVE_CHAMBER: [
		"res://scenes/rooms/caves/mine_chamber_small.tscn",
		"res://scenes/rooms/caves/mine_chamber_medium.tscn",
		"res://scenes/rooms/caves/mine_hall_large.tscn"
	]
}


## Build result structure
class BuildResult extends RefCounted:
	var success: bool = false
	var dungeon_root: Node3D = null
	var rooms: Array[Node3D] = []
	var errors: Array[String] = []

	func add_error(msg: String) -> void:
		success = false
		errors.append(msg)


## Build a dungeon from a grid layout
## grid: Dictionary mapping Vector2i -> DungeonGridData.RoomType
## parent: Node to add the dungeon to (optional, creates orphan node if null)
## validate_first: Whether to validate the grid before building
static func build(
	grid: Dictionary,
	parent: Node = null,
	validate_first: bool = true
) -> BuildResult:
	var result := BuildResult.new()

	# Validate first if requested
	if validate_first:
		var validation: DungeonValidator.ValidationResult = DungeonValidator.validate(grid)
		if not validation.is_valid:
			for error: String in validation.errors:
				result.add_error("Validation: " + error)
			return result

	# Create dungeon root node
	var dungeon_root := Node3D.new()
	dungeon_root.name = "Dungeon"

	# Create rooms container
	var rooms_container := Node3D.new()
	rooms_container.name = "Rooms"
	dungeon_root.add_child(rooms_container)
	rooms_container.owner = dungeon_root  # Required for PackedScene.pack()

	# Cache loaded scenes
	var scene_cache: Dictionary = {}

	# Build each room
	for pos: Vector2i in grid.keys():
		var room_type: DungeonGridData.RoomType = grid[pos]

		if room_type == DungeonGridData.RoomType.EMPTY:
			continue

		# Get scene path (check variants first for variety)
		var scene_path: String = ""
		if MINE_PIECE_VARIANTS.has(room_type):
			var variants: Array = MINE_PIECE_VARIANTS[room_type]
			scene_path = variants[randi() % variants.size()]
		else:
			scene_path = ROOM_SCENES.get(room_type, "")

		if scene_path.is_empty():
			result.add_error("No scene defined for room type: %s" % DungeonGridData.get_room_type_name(room_type))
			continue

		# Load scene (from cache or fresh)
		var scene: PackedScene
		if scene_cache.has(scene_path):
			scene = scene_cache[scene_path]
		else:
			if not ResourceLoader.exists(scene_path):
				result.add_error("Scene not found: %s" % scene_path)
				continue
			scene = load(scene_path) as PackedScene
			if not scene:
				result.add_error("Failed to load scene: %s" % scene_path)
				continue
			scene_cache[scene_path] = scene

		# Instantiate room
		var room_instance: Node3D = scene.instantiate() as Node3D
		if not room_instance:
			result.add_error("Failed to instantiate scene: %s" % scene_path)
			continue

		# Set room name and position
		var type_name: String = DungeonGridData.get_room_type_name(room_type)
		room_instance.name = "%s_%d_%d" % [type_name, pos.x, pos.y]
		room_instance.position = Vector3(pos.x * ROOM_SIZE, 0.0, pos.y * ROOM_SIZE)

		# Store grid position as metadata
		room_instance.set_meta("grid_pos", pos)
		room_instance.set_meta("room_type", room_type)

		rooms_container.add_child(room_instance)
		room_instance.owner = dungeon_root  # Required for PackedScene.pack()
		# NOTE: Do NOT call _set_owner_recursive on instanced scenes!
		# The instance's internal children keep their own owner structure.
		# Setting owner on them causes duplicate empty nodes in the export.
		result.rooms.append(room_instance)

		# Block any doors that don't connect to another room
		_add_door_blockers(room_instance, pos, room_type, grid, dungeon_root)

	# Add dungeon to parent if provided
	if parent:
		parent.add_child(dungeon_root)

	result.success = true
	result.dungeon_root = dungeon_root
	return result


## Build and return just the dungeon node (convenience method)
static func build_dungeon(grid: Dictionary, validate_first: bool = true) -> Node3D:
	var result: BuildResult = build(grid, null, validate_first)
	if result.success:
		return result.dungeon_root
	else:
		for error: String in result.errors:
			push_error("[DungeonBuilder] %s" % error)
		return null


## Recursively set owner on all child nodes (required for PackedScene.pack())
static func _set_owner_recursive(node: Node, owner_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = owner_node
		_set_owner_recursive(child, owner_node)


## Add wall blockers for any doors that don't connect to another room
static func _add_door_blockers(
	room_instance: Node3D,
	pos: Vector2i,
	room_type: DungeonGridData.RoomType,
	grid: Dictionary,
	owner_node: Node
) -> void:
	var room_doors: Array = DungeonGridData.get_doors(room_type)
	if room_doors.is_empty():
		return

	# Load wall material for blockers
	var wall_material: StandardMaterial3D = null
	var wall_texture: Texture2D = load("res://assets/textures/environment/dungeon/stonewall.png")
	if wall_texture:
		wall_material = StandardMaterial3D.new()
		wall_material.albedo_texture = wall_texture
		wall_material.uv1_scale = Vector3(1, 1, 1)
		wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Check each door direction
	for door_dir: DungeonGridData.Direction in room_doors:
		var offset: Vector2i = DungeonGridData.get_direction_offset(door_dir)
		var neighbor_pos: Vector2i = pos + offset

		# Check if there's a room in this direction with a matching door
		var needs_blocker: bool = true
		if grid.has(neighbor_pos):
			var neighbor_type: DungeonGridData.RoomType = grid[neighbor_pos]
			if neighbor_type != DungeonGridData.RoomType.EMPTY:
				var opposite_dir: DungeonGridData.Direction = DungeonGridData.get_opposite_direction(door_dir)
				if DungeonGridData.has_door(neighbor_type, opposite_dir):
					needs_blocker = false

		if needs_blocker:
			var blocker: CSGBox3D = _create_door_blocker(door_dir, wall_material, room_type)
			room_instance.add_child(blocker)
			blocker.owner = owner_node


## Create a CSGBox3D to block a door opening
## room_type is used to determine door width (hallways are narrower)
static func _create_door_blocker(direction: DungeonGridData.Direction, material: StandardMaterial3D, room_type: DungeonGridData.RoomType = DungeonGridData.RoomType.CORRIDOR_NS) -> CSGBox3D:
	var blocker := CSGBox3D.new()
	blocker.use_collision = true

	# Determine door width based on room type
	# Hallways have 5 unit wide doors, corridors have 4 unit wide doors
	var door_width: float = 4.0
	if room_type == DungeonGridData.RoomType.HALLWAY_NS or room_type == DungeonGridData.RoomType.HALLWAY_EW:
		door_width = 5.0

	# Door opening centered at 8, wall is 4 units tall
	match direction:
		DungeonGridData.Direction.NORTH:
			blocker.name = "DoorBlockerNorth"
			blocker.size = Vector3(door_width, 4, 0.5)
			blocker.position = Vector3(8, 2, 0.25)
		DungeonGridData.Direction.SOUTH:
			blocker.name = "DoorBlockerSouth"
			blocker.size = Vector3(door_width, 4, 0.5)
			blocker.position = Vector3(8, 2, 15.75)
		DungeonGridData.Direction.EAST:
			blocker.name = "DoorBlockerEast"
			blocker.size = Vector3(0.5, 4, door_width)
			blocker.position = Vector3(15.75, 2, 8)
		DungeonGridData.Direction.WEST:
			blocker.name = "DoorBlockerWest"
			blocker.size = Vector3(0.5, 4, door_width)
			blocker.position = Vector3(0.25, 2, 8)

	if material:
		blocker.material = material

	return blocker


## Convert grid position to world position
static func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * ROOM_SIZE, 0.0, grid_pos.y * ROOM_SIZE)


## Convert world position to grid position
static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ROOM_SIZE)),
		int(floor(world_pos.z / ROOM_SIZE))
	)


## Get the center world position of a room at grid position
static func get_room_center(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * ROOM_SIZE + ROOM_SIZE / 2.0,
		0.0,
		grid_pos.y * ROOM_SIZE + ROOM_SIZE / 2.0
	)


## Create a simple test dungeon grid for debugging
static func create_test_grid() -> Dictionary:
	var grid: Dictionary = {}

	# Start room at origin
	grid[Vector2i(0, 0)] = DungeonGridData.RoomType.START

	# Corridors extending from start
	grid[Vector2i(0, -1)] = DungeonGridData.RoomType.CORRIDOR_NS  # North
	grid[Vector2i(0, 1)] = DungeonGridData.RoomType.CORRIDOR_NS   # South
	grid[Vector2i(1, 0)] = DungeonGridData.RoomType.CORRIDOR_EW   # East
	grid[Vector2i(-1, 0)] = DungeonGridData.RoomType.CORRIDOR_EW  # West

	# Rooms at corridor ends
	grid[Vector2i(0, -2)] = DungeonGridData.RoomType.DEAD_END_S   # North end
	grid[Vector2i(0, 2)] = DungeonGridData.RoomType.ROOM_SMALL    # South room
	grid[Vector2i(2, 0)] = DungeonGridData.RoomType.ROOM_BOSS     # East boss room
	grid[Vector2i(-2, 0)] = DungeonGridData.RoomType.DEAD_END_E   # West end

	# Connect south room to boss room via turn
	grid[Vector2i(1, 2)] = DungeonGridData.RoomType.CORRIDOR_EW
	grid[Vector2i(2, 2)] = DungeonGridData.RoomType.TURN_NW

	# Make south room have doors
	grid[Vector2i(0, 2)] = DungeonGridData.RoomType.CROSS

	# Connect boss room south
	grid[Vector2i(2, 1)] = DungeonGridData.RoomType.CORRIDOR_NS

	return grid


## Save a grid to a JSON file
static func save_grid_to_json(grid: Dictionary, path: String) -> bool:
	var data: Dictionary = {}

	for pos: Vector2i in grid.keys():
		var room_type: DungeonGridData.RoomType = grid[pos]
		var key: String = "%d,%d" % [pos.x, pos.y]
		data[key] = DungeonGridData.get_room_type_name(room_type)

	var json_string: String = JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[DungeonBuilder] Failed to open file for writing: %s" % path)
		return false

	file.store_string(json_string)
	file.close()
	return true


## Load a grid from a JSON file
static func load_grid_from_json(path: String) -> Dictionary:
	var grid: Dictionary = {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[DungeonBuilder] Failed to open file for reading: %s" % path)
		return grid

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: int = json.parse(json_string)
	if error != OK:
		push_error("[DungeonBuilder] Failed to parse JSON: %s" % json.get_error_message())
		return grid

	var data: Dictionary = json.get_data()

	for key: String in data.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		var type_name: String = data[key]
		var room_type: DungeonGridData.RoomType = DungeonGridData.get_room_type_from_name(type_name)
		grid[pos] = room_type

	return grid
