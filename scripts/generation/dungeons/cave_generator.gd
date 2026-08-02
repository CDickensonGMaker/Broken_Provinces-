class_name CaveGenerator
extends RefCounted
## Procedural cave generator that outputs grid Dictionary compatible with DungeonBuilder
## Uses random walk with branching to create organic cave layouts

## Cave generation parameters
const DEFAULT_LENGTH: int = 8  # Main path length
const DEFAULT_BRANCHES: int = 2  # Number of side branches
const BRANCH_LENGTH_MIN: int = 2
const BRANCH_LENGTH_MAX: int = 5
const CHAMBER_CHANCE: float = 0.15  # Chance for dead end to become chamber


## Direction vectors for movement
const DIR_NORTH: Vector2i = Vector2i(0, -1)
const DIR_SOUTH: Vector2i = Vector2i(0, 1)
const DIR_EAST: Vector2i = Vector2i(1, 0)
const DIR_WEST: Vector2i = Vector2i(-1, 0)

const DIRECTIONS: Array[Vector2i] = [DIR_NORTH, DIR_SOUTH, DIR_EAST, DIR_WEST]


## Generate a random cave layout and return grid Dictionary
## Parameters:
##   main_length: Length of main path from entrance to exit
##   branch_count: Number of side branches to create
##   seed_value: Random seed for reproducibility (-1 for random)
## Returns: Dictionary[Vector2i, int] mapping positions to RoomType
static func generate(
	main_length: int = DEFAULT_LENGTH,
	branch_count: int = DEFAULT_BRANCHES,
	seed_value: int = -1
) -> Dictionary:
	if seed_value >= 0:
		seed(seed_value)
	else:
		randomize()

	var grid: Dictionary = {}
	var visited: Array[Vector2i] = []

	# Start at origin with entrance
	var current_pos: Vector2i = Vector2i.ZERO
	grid[current_pos] = DungeonGridData.RoomType.CAVE_ENTRANCE
	visited.append(current_pos)

	var last_direction: Vector2i = DIR_SOUTH  # Entrance opens to south
	var branch_points: Array[Dictionary] = []  # Positions where branches can start

	# Generate main path
	for i: int in range(main_length):
		var next_dir: Vector2i = _pick_next_direction(last_direction, visited, current_pos)
		if next_dir == Vector2i.ZERO:
			break  # Dead end, can't continue

		var next_pos: Vector2i = current_pos + next_dir

		# Determine room type based on direction change
		var room_type: int = _get_room_type_for_directions(
			_opposite_direction(last_direction),
			next_dir
		)

		# Potentially mark this as a branch point
		if i > 1 and i < main_length - 1 and randf() < 0.4:
			branch_points.append({
				"pos": next_pos,
				"entry_dir": _opposite_direction(next_dir)
			})

		grid[next_pos] = room_type
		visited.append(next_pos)
		last_direction = next_dir
		current_pos = next_pos

	# Place exit at end of main path
	if grid.has(current_pos):
		# Replace last room with exit
		grid[current_pos] = DungeonGridData.RoomType.CAVE_EXIT

	# Generate branches
	var branches_created: int = 0
	branch_points.shuffle()

	for bp: Dictionary in branch_points:
		if branches_created >= branch_count:
			break

		var branch_length: int = randi_range(BRANCH_LENGTH_MIN, BRANCH_LENGTH_MAX)
		var branched: bool = _create_branch(
			grid,
			visited,
			bp["pos"],
			bp["entry_dir"],
			branch_length
		)

		if branched:
			branches_created += 1

	# Fix room types to ensure proper connections
	_fix_room_connections(grid)

	return grid


## Generate a simple linear cave (no branches)
static func generate_linear(length: int = 6, seed_value: int = -1) -> Dictionary:
	return generate(length, 0, seed_value)


## Generate a complex cave with many branches
static func generate_complex(seed_value: int = -1) -> Dictionary:
	return generate(12, 4, seed_value)


## Pick next direction avoiding visited cells and preferring forward movement
static func _pick_next_direction(
	last_dir: Vector2i,
	visited: Array[Vector2i],
	current: Vector2i
) -> Vector2i:
	var options: Array[Vector2i] = []

	for dir: Vector2i in DIRECTIONS:
		var next_pos: Vector2i = current + dir
		if next_pos not in visited:
			options.append(dir)

	if options.is_empty():
		return Vector2i.ZERO

	# Prefer continuing in same direction
	if last_dir in options and randf() < 0.6:
		return last_dir

	# Otherwise pick random valid direction
	return options[randi() % options.size()]


## Get opposite direction vector
static func _opposite_direction(dir: Vector2i) -> Vector2i:
	return -dir


## Determine room type based on entry and exit directions
static func _get_room_type_for_directions(entry_dir: Vector2i, exit_dir: Vector2i) -> int:
	# Straight corridors
	if (entry_dir == DIR_NORTH and exit_dir == DIR_SOUTH) or \
	   (entry_dir == DIR_SOUTH and exit_dir == DIR_NORTH):
		return DungeonGridData.RoomType.CAVE_CORRIDOR_NS

	if (entry_dir == DIR_EAST and exit_dir == DIR_WEST) or \
	   (entry_dir == DIR_WEST and exit_dir == DIR_EAST):
		return DungeonGridData.RoomType.CAVE_CORRIDOR_EW

	# Corners (entry from direction, exit to direction)
	# NE corner: entry from south or west, exit to north or east
	if (entry_dir == DIR_SOUTH and exit_dir == DIR_EAST) or \
	   (entry_dir == DIR_WEST and exit_dir == DIR_NORTH):
		return DungeonGridData.RoomType.CAVE_CORNER_NE

	if (entry_dir == DIR_SOUTH and exit_dir == DIR_WEST) or \
	   (entry_dir == DIR_EAST and exit_dir == DIR_NORTH):
		return DungeonGridData.RoomType.CAVE_CORNER_NW

	if (entry_dir == DIR_NORTH and exit_dir == DIR_EAST) or \
	   (entry_dir == DIR_WEST and exit_dir == DIR_SOUTH):
		return DungeonGridData.RoomType.CAVE_CORNER_SE

	if (entry_dir == DIR_NORTH and exit_dir == DIR_WEST) or \
	   (entry_dir == DIR_EAST and exit_dir == DIR_SOUTH):
		return DungeonGridData.RoomType.CAVE_CORNER_SW

	# Default to corridor
	return DungeonGridData.RoomType.CAVE_CORRIDOR_NS


## Create a branch from a position
static func _create_branch(
	grid: Dictionary,
	visited: Array[Vector2i],
	start_pos: Vector2i,
	entry_dir: Vector2i,
	length: int
) -> bool:
	# Find a direction that's not the entry direction and not visited
	var branch_dirs: Array[Vector2i] = []
	for dir: Vector2i in DIRECTIONS:
		if dir == entry_dir:
			continue
		var next_pos: Vector2i = start_pos + dir
		if next_pos not in visited:
			branch_dirs.append(dir)

	if branch_dirs.is_empty():
		return false

	# Pick random branch direction
	var branch_dir: Vector2i = branch_dirs[randi() % branch_dirs.size()]

	# Upgrade start position to T-junction or crossroads
	var current_room: int = grid.get(start_pos, -1)
	if current_room != -1:
		grid[start_pos] = _upgrade_to_junction(current_room, branch_dir)

	# Create branch path
	var current_pos: Vector2i = start_pos + branch_dir
	var last_dir: Vector2i = branch_dir

	for i: int in range(length):
		if current_pos in visited:
			break

		visited.append(current_pos)

		if i == length - 1:
			# End of branch - place dead end or chamber
			if randf() < CHAMBER_CHANCE:
				grid[current_pos] = DungeonGridData.RoomType.CAVE_CHAMBER
			else:
				grid[current_pos] = DungeonGridData.RoomType.CAVE_DEAD_END
		else:
			var next_dir: Vector2i = _pick_next_direction(last_dir, visited, current_pos)
			if next_dir == Vector2i.ZERO:
				# Can't continue, end here
				grid[current_pos] = DungeonGridData.RoomType.CAVE_DEAD_END
				break

			var room_type: int = _get_room_type_for_directions(
				_opposite_direction(last_dir),
				next_dir
			)
			grid[current_pos] = room_type

			last_dir = next_dir
			current_pos = current_pos + next_dir

	return true


## Upgrade a room to include an additional door direction
static func _upgrade_to_junction(current_type: int, new_dir: Vector2i) -> int:
	var current_doors: Array = DungeonGridData.get_doors(current_type).duplicate()

	# Add new direction
	var dir_enum: int = _vec_to_direction_enum(new_dir)
	if dir_enum not in current_doors:
		current_doors.append(dir_enum)

	# Find appropriate junction type
	if current_doors.size() >= 4:
		return DungeonGridData.RoomType.CAVE_CROSSROADS
	elif current_doors.size() == 3:
		return DungeonGridData.RoomType.CAVE_T_JUNCTION

	return current_type


## Convert Vector2i direction to Direction enum
static func _vec_to_direction_enum(vec: Vector2i) -> int:
	if vec == DIR_NORTH:
		return DungeonGridData.Direction.NORTH
	elif vec == DIR_SOUTH:
		return DungeonGridData.Direction.SOUTH
	elif vec == DIR_EAST:
		return DungeonGridData.Direction.EAST
	elif vec == DIR_WEST:
		return DungeonGridData.Direction.WEST
	return -1


## Fix room connections to ensure doors match up
static func _fix_room_connections(grid: Dictionary) -> void:
	for pos: Vector2i in grid.keys():
		var room_type: int = grid[pos]

		# Skip special rooms that have all doors or are endpoints
		if room_type == DungeonGridData.RoomType.CAVE_CHAMBER or \
		   room_type == DungeonGridData.RoomType.CAVE_CROSSROADS or \
		   room_type == DungeonGridData.RoomType.CAVE_ENTRANCE or \
		   room_type == DungeonGridData.RoomType.CAVE_EXIT:
			continue

		# Calculate what doors this room needs
		var needed_doors: Array = []

		for dir: Vector2i in DIRECTIONS:
			var neighbor_pos: Vector2i = pos + dir
			if grid.has(neighbor_pos):
				var dir_enum: int = _vec_to_direction_enum(dir)
				needed_doors.append(dir_enum)

		# Find correct room type for these doors
		if needed_doors.size() == 0:
			grid.erase(pos)  # Orphan room
		elif needed_doors.size() == 1:
			grid[pos] = DungeonGridData.RoomType.CAVE_DEAD_END
		elif needed_doors.size() == 2:
			# Corridor or corner
			grid[pos] = _find_cave_connector(needed_doors)
		elif needed_doors.size() == 3:
			grid[pos] = DungeonGridData.RoomType.CAVE_T_JUNCTION
		else:
			grid[pos] = DungeonGridData.RoomType.CAVE_CROSSROADS


## Find the right cave connector type for given doors
static func _find_cave_connector(doors: Array) -> int:
	doors.sort()

	# Check for corridors (opposite directions)
	if DungeonGridData.Direction.NORTH in doors and \
	   DungeonGridData.Direction.SOUTH in doors:
		return DungeonGridData.RoomType.CAVE_CORRIDOR_NS

	if DungeonGridData.Direction.EAST in doors and \
	   DungeonGridData.Direction.WEST in doors:
		return DungeonGridData.RoomType.CAVE_CORRIDOR_EW

	# Corners
	if DungeonGridData.Direction.NORTH in doors:
		if DungeonGridData.Direction.EAST in doors:
			return DungeonGridData.RoomType.CAVE_CORNER_NE
		elif DungeonGridData.Direction.WEST in doors:
			return DungeonGridData.RoomType.CAVE_CORNER_NW

	if DungeonGridData.Direction.SOUTH in doors:
		if DungeonGridData.Direction.EAST in doors:
			return DungeonGridData.RoomType.CAVE_CORNER_SE
		elif DungeonGridData.Direction.WEST in doors:
			return DungeonGridData.RoomType.CAVE_CORNER_SW

	# Fallback
	return DungeonGridData.RoomType.CAVE_CORRIDOR_NS


## Build a complete mine dungeon and return the Node3D root
## This is a convenience method that generates the grid and builds it in one step
## Parameters:
##   parent: Node to add the dungeon to (optional)
##   main_length: Length of main path
##   branch_count: Number of side branches
##   seed_value: Random seed (-1 for random)
## Returns: Node3D root of the dungeon, or null on failure
static func build_mine_dungeon(
	parent: Node = null,
	main_length: int = DEFAULT_LENGTH,
	branch_count: int = DEFAULT_BRANCHES,
	seed_value: int = -1
) -> Node3D:
	# Generate the cave grid
	var grid: Dictionary = generate(main_length, branch_count, seed_value)
	if grid.is_empty():
		push_error("[CaveGenerator] Failed to generate cave grid")
		return null

	# Build the dungeon using the builder
	var result: DungeonBuilder.BuildResult = DungeonBuilder.build(grid, parent, false)
	if not result.success:
		for error: String in result.errors:
			push_error("[CaveGenerator] Build error: %s" % error)
		return null

	# Rename to Mine instead of Dungeon
	if result.dungeon_root:
		result.dungeon_root.name = "MineDungeon"

	return result.dungeon_root


## Generate and build a simple linear mine (no branches)
static func build_linear_mine(parent: Node = null, length: int = 6, seed_value: int = -1) -> Node3D:
	return build_mine_dungeon(parent, length, 0, seed_value)


## Generate and build a complex mine with many branches
static func build_complex_mine(parent: Node = null, seed_value: int = -1) -> Node3D:
	return build_mine_dungeon(parent, 12, 4, seed_value)
