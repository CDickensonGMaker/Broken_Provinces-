## dungeon_grid.gd - Grid wrapper for managing placed rooms during generation
##
## Tracks which cells are occupied and provides lookup methods.
## This is the spatial index for the dungeon generation process.
class_name DungeonGrid
extends RefCounted

## Cell occupancy: Vector2i -> PlacedRoom
## A cell maps to the room that occupies it (rooms can span multiple cells)
var _cell_to_room: Dictionary = {}

## All placed rooms in order of placement
var _placed_rooms: Array[PlacedRoom] = []

## Reserved cells that cannot be used (e.g., for corridors or buffer zones)
var _reserved_cells: Dictionary = {}  # Vector2i -> bool

## Next instance ID to assign
var _next_instance_id: int = 0


## Clear the grid for reuse
func clear() -> void:
	_cell_to_room.clear()
	_placed_rooms.clear()
	_reserved_cells.clear()
	_next_instance_id = 0


## Place a room in the grid
## Returns true if successful, false if any cell is already occupied
func place(room: PlacedRoom) -> bool:
	if room == null or room.room_data == null:
		push_error("DungeonGrid: Cannot place null room")
		return false

	var cells: Array[Vector2i] = room.get_occupied_cells()

	# Check all cells are free
	for cell: Vector2i in cells:
		if is_occupied(cell) or is_reserved(cell):
			return false

	# Place in all cells
	for cell: Vector2i in cells:
		_cell_to_room[cell] = room

	# Assign instance ID and add to list
	room.instance_id = _next_instance_id
	_next_instance_id += 1
	_placed_rooms.append(room)

	return true


## Check if a cell is occupied by any room
func is_occupied(cell: Vector2i) -> bool:
	return cell in _cell_to_room


## Check if a cell is reserved
func is_reserved(cell: Vector2i) -> bool:
	return cell in _reserved_cells


## Check if a cell is available (not occupied and not reserved)
func is_available(cell: Vector2i) -> bool:
	return not is_occupied(cell) and not is_reserved(cell)


## Get the room at a specific cell (or null if empty)
func get_room(cell: Vector2i) -> PlacedRoom:
	return _cell_to_room.get(cell, null)


## Reserve a cell to prevent placement (but don't mark as occupied)
func reserve_cell(cell: Vector2i) -> void:
	_reserved_cells[cell] = true


## Reserve multiple cells
func reserve_cells(cells: Array[Vector2i]) -> void:
	for cell: Vector2i in cells:
		reserve_cell(cell)


## Unreserve a cell
func unreserve_cell(cell: Vector2i) -> void:
	_reserved_cells.erase(cell)


## Check if a footprint can be placed at a position
func can_place(anchor: Vector2i, footprint: Vector2i, rotation_deg: int) -> bool:
	var cells: Array[Vector2i] = DungeonUtils.get_footprint_cells(anchor, footprint, rotation_deg)
	for cell: Vector2i in cells:
		if not is_available(cell):
			return false
	return true


## Get all placed rooms
func get_all_placed() -> Array[PlacedRoom]:
	return _placed_rooms.duplicate()


## Get the number of placed rooms
func get_room_count() -> int:
	return _placed_rooms.size()


## Get a room by its instance ID
func get_room_by_id(instance_id: int) -> PlacedRoom:
	for room: PlacedRoom in _placed_rooms:
		if room.instance_id == instance_id:
			return room
	return null


## Get all rooms with a specific tag
func get_rooms_by_tag(tag: RoomData.RoomTag) -> Array[PlacedRoom]:
	var result: Array[PlacedRoom] = []
	for room: PlacedRoom in _placed_rooms:
		if room.room_data and room.room_data.has_tag(tag):
			result.append(room)
	return result


## Get the start room (should be exactly one)
func get_start_room() -> PlacedRoom:
	var starts: Array[PlacedRoom] = get_rooms_by_tag(RoomData.RoomTag.START)
	if starts.is_empty():
		return null
	return starts[0]


## Get the boss room (should be exactly one)
func get_boss_room() -> PlacedRoom:
	var bosses: Array[PlacedRoom] = get_rooms_by_tag(RoomData.RoomTag.BOSS)
	if bosses.is_empty():
		return null
	return bosses[0]


## Get count of rooms of a specific RoomData type
func count_rooms_of_type(room_data: RoomData) -> int:
	var count := 0
	for room: PlacedRoom in _placed_rooms:
		if room.room_data == room_data:
			count += 1
	return count


## Find all rooms at a given depth
func get_rooms_at_depth(depth: int) -> Array[PlacedRoom]:
	var result: Array[PlacedRoom] = []
	for room: PlacedRoom in _placed_rooms:
		if room.depth == depth:
			result.append(room)
	return result


## Get the maximum depth of any placed room
func get_max_depth() -> int:
	var max_d := 0
	for room: PlacedRoom in _placed_rooms:
		max_d = maxi(max_d, room.depth)
	return max_d


## Get the bounds of the placed dungeon (min and max cells)
func get_bounds() -> Rect2i:
	if _placed_rooms.is_empty():
		return Rect2i(0, 0, 0, 0)

	var min_x := 999999
	var min_y := 999999
	var max_x := -999999
	var max_y := -999999

	for cell: Vector2i in _cell_to_room.keys():
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Print the grid as ASCII art for debugging
func print_debug() -> void:
	if _placed_rooms.is_empty():
		print("DungeonGrid: (empty)")
		return

	var bounds: Rect2i = get_bounds()
	print("DungeonGrid: %d rooms, bounds %s" % [_placed_rooms.size(), str(bounds)])

	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		var line := ""
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cell := Vector2i(x, y)
			if is_occupied(cell):
				var room: PlacedRoom = get_room(cell)
				if room.room_data.is_start():
					line += "S"
				elif room.room_data.is_boss():
					line += "B"
				elif room.room_data.is_hidden():
					line += "H"
				elif room.room_data.has_tag(RoomData.RoomTag.CORRIDOR):
					line += "C"
				elif room.room_data.has_tag(RoomData.RoomTag.TREASURE):
					line += "T"
				else:
					line += "R"
			elif is_reserved(cell):
				line += "x"
			else:
				line += "."
		print(line)
