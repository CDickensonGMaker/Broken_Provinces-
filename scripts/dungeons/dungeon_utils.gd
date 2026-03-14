## dungeon_utils.gd - Static helper functions for dungeon generation
##
## Contains pure utility functions for coordinate conversion, rotation math,
## and footprint calculations. No state, all static methods.
class_name DungeonUtils
extends RefCounted

## Grid cell size in world units (width, height, depth)
const CELL_SIZE := Vector3(8.0, 4.0, 8.0)

## Direction constants matching RoomData.Dir
const DIR_NORTH := 0
const DIR_EAST := 1
const DIR_SOUTH := 2
const DIR_WEST := 3

## Direction offsets in grid space
## North = -Y (up on screen), East = +X, South = +Y, West = -X
const DIR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),  # NORTH
	Vector2i(1, 0),   # EAST
	Vector2i(0, 1),   # SOUTH
	Vector2i(-1, 0)   # WEST
]


## Convert a grid cell coordinate to world position
## Returns the center of the cell at floor level
static func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(
		cell.x * CELL_SIZE.x + CELL_SIZE.x * 0.5,
		0.0,
		cell.y * CELL_SIZE.z + CELL_SIZE.z * 0.5
	)


## Convert world position to grid cell coordinate
static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		floori(world_pos.x / CELL_SIZE.x),
		floori(world_pos.z / CELL_SIZE.z)
	)


## Get the grid offset for a direction
static func dir_to_offset(dir: int) -> Vector2i:
	if dir < 0 or dir > 3:
		push_error("DungeonUtils: Invalid direction %d" % dir)
		return Vector2i.ZERO
	return DIR_OFFSETS[dir]


## Get the opposite direction
static func opposite_dir(dir: int) -> int:
	return (dir + 2) % 4


## Rotate a direction by a given angle (in degrees, must be 0/90/180/270)
static func rotate_dir(dir: int, rotation_deg: int) -> int:
	var steps: int = (rotation_deg / 90) % 4
	return (dir + steps) % 4


## Rotate a cell position within a footprint
## Used to transform local entrance positions when room is rotated
static func rotate_cell(local_cell: Vector2i, footprint: Vector2i, rotation_deg: int) -> Vector2i:
	var steps: int = (rotation_deg / 90) % 4
	var result: Vector2i = local_cell

	for _i in range(steps):
		# 90-degree clockwise rotation within footprint bounds
		# (x, y) -> (footprint.y - 1 - y, x)
		var new_x: int = footprint.y - 1 - result.y
		var new_y: int = result.x
		result = Vector2i(new_x, new_y)
		# After rotation, footprint dimensions swap
		footprint = Vector2i(footprint.y, footprint.x)

	return result


## Get the rotated footprint dimensions
static func rotate_footprint(footprint: Vector2i, rotation_deg: int) -> Vector2i:
	var steps: int = (rotation_deg / 90) % 4
	if steps % 2 == 1:
		return Vector2i(footprint.y, footprint.x)
	return footprint


## Get all grid cells occupied by a room with given anchor, footprint, and rotation
static func get_footprint_cells(anchor: Vector2i, footprint: Vector2i, rotation_deg: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var rotated_fp: Vector2i = rotate_footprint(footprint, rotation_deg)

	for x in range(rotated_fp.x):
		for y in range(rotated_fp.y):
			result.append(anchor + Vector2i(x, y))

	return result


## Check if two rooms would overlap
static func rooms_overlap(
	anchor_a: Vector2i, footprint_a: Vector2i, rotation_a: int,
	anchor_b: Vector2i, footprint_b: Vector2i, rotation_b: int
) -> bool:
	var cells_a: Array[Vector2i] = get_footprint_cells(anchor_a, footprint_a, rotation_a)
	var cells_b: Array[Vector2i] = get_footprint_cells(anchor_b, footprint_b, rotation_b)

	for cell_a: Vector2i in cells_a:
		if cell_a in cells_b:
			return true
	return false


## Get the cell that is adjacent to a given cell in a direction
static func get_adjacent_cell(cell: Vector2i, dir: int) -> Vector2i:
	return cell + dir_to_offset(dir)


## Get all four adjacent cells
static func get_all_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dir in range(4):
		result.append(cell + DIR_OFFSETS[dir])
	return result


## Calculate rotation needed to align an entrance to connect to an adjacent room
## Returns the rotation in degrees that would make entrance_dir point toward target_dir
static func calc_rotation_for_connection(entrance_dir: int, target_dir: int) -> int:
	# We need entrance to face opposite of target (to connect)
	var needed_dir: int = opposite_dir(target_dir)
	var diff: int = (needed_dir - entrance_dir + 4) % 4
	return diff * 90


## Get direction from one cell to another (must be adjacent)
static func get_direction_between(from_cell: Vector2i, to_cell: Vector2i) -> int:
	var diff: Vector2i = to_cell - from_cell
	for dir in range(4):
		if DIR_OFFSETS[dir] == diff:
			return dir
	push_error("DungeonUtils: Cells are not adjacent: %s -> %s" % [str(from_cell), str(to_cell)])
	return -1


## Convert rotation degrees to a human-readable string
static func rotation_to_string(rotation_deg: int) -> String:
	match rotation_deg:
		0: return "0deg"
		90: return "90deg"
		180: return "180deg"
		270: return "270deg"
		_: return "%ddeg" % rotation_deg


## Convert direction to human-readable string
static func dir_to_string(dir: int) -> String:
	match dir:
		DIR_NORTH: return "N"
		DIR_EAST: return "E"
		DIR_SOUTH: return "S"
		DIR_WEST: return "W"
		_: return "?"
