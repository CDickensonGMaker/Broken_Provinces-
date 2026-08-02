## dungeon_validator.gd - Validates dungeon grid layouts before building
## Checks that all room connections have matching doors
class_name DungeonValidator
extends RefCounted


## Validation result structure
class ValidationResult extends RefCounted:
	var is_valid: bool = true
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func add_error(msg: String) -> void:
		is_valid = false
		errors.append(msg)

	func add_warning(msg: String) -> void:
		warnings.append(msg)

	func get_summary() -> String:
		var summary: String = ""
		if is_valid:
			summary = "Validation PASSED"
		else:
			summary = "Validation FAILED"

		if errors.size() > 0:
			summary += "\nErrors (%d):\n" % errors.size()
			for error: String in errors:
				summary += "  - %s\n" % error

		if warnings.size() > 0:
			summary += "\nWarnings (%d):\n" % warnings.size()
			for warning: String in warnings:
				summary += "  - %s\n" % warning

		return summary


## Check if two adjacent rooms have matching doors
## Returns true if doors match (both have doors or both don't have doors)
static func doors_match(
	room_a_type: DungeonGridData.RoomType,
	room_a_pos: Vector2i,
	room_b_type: DungeonGridData.RoomType,
	room_b_pos: Vector2i
) -> bool:
	# Determine the direction from room_a to room_b
	var offset: Vector2i = room_b_pos - room_a_pos
	var dir_a_to_b: DungeonGridData.Direction = _offset_to_direction(offset)
	if dir_a_to_b == -1:
		# Rooms are not adjacent
		return true

	var dir_b_to_a: DungeonGridData.Direction = DungeonGridData.get_opposite_direction(dir_a_to_b)

	var a_has_door: bool = DungeonGridData.has_door(room_a_type, dir_a_to_b)
	var b_has_door: bool = DungeonGridData.has_door(room_b_type, dir_b_to_a)

	# Both must have doors, or both must not have doors
	return a_has_door == b_has_door


## Validate an entire dungeon grid
## grid: Dictionary mapping Vector2i -> DungeonGridData.RoomType
static func validate(grid: Dictionary) -> ValidationResult:
	var result := ValidationResult.new()

	if grid.is_empty():
		result.add_error("Grid is empty - no rooms defined")
		return result

	# Check each room's connections
	for pos: Vector2i in grid.keys():
		var room_type: DungeonGridData.RoomType = grid[pos]

		if room_type == DungeonGridData.RoomType.EMPTY:
			continue

		# Check all four directions
		for dir: DungeonGridData.Direction in [
			DungeonGridData.Direction.NORTH,
			DungeonGridData.Direction.SOUTH,
			DungeonGridData.Direction.EAST,
			DungeonGridData.Direction.WEST
		]:
			var neighbor_pos: Vector2i = pos + DungeonGridData.get_direction_offset(dir)
			var has_door: bool = DungeonGridData.has_door(room_type, dir)

			if grid.has(neighbor_pos):
				var neighbor_type: DungeonGridData.RoomType = grid[neighbor_pos]

				if neighbor_type == DungeonGridData.RoomType.EMPTY:
					# Empty neighbor - door should lead nowhere (warning, not error)
					if has_door:
						result.add_warning(
							"Room at %s has %s door but neighbor at %s is empty" %
							[str(pos), DungeonGridData.get_direction_name(dir), str(neighbor_pos)]
						)
				else:
					# Non-empty neighbor - check door matching
					var opposite_dir: DungeonGridData.Direction = DungeonGridData.get_opposite_direction(dir)
					var neighbor_has_door: bool = DungeonGridData.has_door(neighbor_type, opposite_dir)

					if has_door != neighbor_has_door:
						result.add_error(
							"Door mismatch: Room at %s (%s) has %s door=%s, " % [
								str(pos),
								DungeonGridData.get_room_type_name(room_type),
								DungeonGridData.get_direction_name(dir),
								str(has_door)
							] +
							"but neighbor at %s (%s) has %s door=%s" % [
								str(neighbor_pos),
								DungeonGridData.get_room_type_name(neighbor_type),
								DungeonGridData.get_direction_name(opposite_dir),
								str(neighbor_has_door)
							]
						)
			else:
				# No neighbor in grid - door leads to void
				if has_door:
					result.add_warning(
						"Room at %s has %s door but no neighbor exists at %s" %
						[str(pos), DungeonGridData.get_direction_name(dir), str(neighbor_pos)]
					)

	# Check for start room
	var has_start: bool = false
	for pos: Vector2i in grid.keys():
		if grid[pos] == DungeonGridData.RoomType.START:
			has_start = true
			break

	if not has_start:
		result.add_warning("No START room found in dungeon")

	# Check for connectivity (all rooms reachable from first non-empty room)
	var first_room_pos: Vector2i = Vector2i.ZERO
	for pos: Vector2i in grid.keys():
		if grid[pos] != DungeonGridData.RoomType.EMPTY:
			first_room_pos = pos
			break

	var reachable: Dictionary = _find_reachable_rooms(grid, first_room_pos)
	var total_rooms: int = 0
	for pos: Vector2i in grid.keys():
		if grid[pos] != DungeonGridData.RoomType.EMPTY:
			total_rooms += 1
			if not reachable.has(pos):
				result.add_error(
					"Room at %s is not reachable from the main dungeon" % str(pos)
				)

	return result


## Find all rooms reachable from a starting position via connected doors
static func _find_reachable_rooms(grid: Dictionary, start_pos: Vector2i) -> Dictionary:
	var reachable: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]

	while queue.size() > 0:
		var current: Vector2i = queue.pop_front()

		if reachable.has(current):
			continue

		if not grid.has(current):
			continue

		var room_type: DungeonGridData.RoomType = grid[current]
		if room_type == DungeonGridData.RoomType.EMPTY:
			continue

		reachable[current] = true

		# Check each direction for connected rooms
		for dir: DungeonGridData.Direction in [
			DungeonGridData.Direction.NORTH,
			DungeonGridData.Direction.SOUTH,
			DungeonGridData.Direction.EAST,
			DungeonGridData.Direction.WEST
		]:
			if not DungeonGridData.has_door(room_type, dir):
				continue

			var neighbor_pos: Vector2i = current + DungeonGridData.get_direction_offset(dir)

			if not grid.has(neighbor_pos):
				continue

			var neighbor_type: DungeonGridData.RoomType = grid[neighbor_pos]
			if neighbor_type == DungeonGridData.RoomType.EMPTY:
				continue

			var opposite_dir: DungeonGridData.Direction = DungeonGridData.get_opposite_direction(dir)
			if DungeonGridData.has_door(neighbor_type, opposite_dir):
				# Connected via matching doors
				queue.append(neighbor_pos)

	return reachable


## Convert an offset to a direction (-1 if not adjacent)
static func _offset_to_direction(offset: Vector2i) -> int:
	if offset == Vector2i(0, -1):
		return DungeonGridData.Direction.NORTH
	elif offset == Vector2i(0, 1):
		return DungeonGridData.Direction.SOUTH
	elif offset == Vector2i(1, 0):
		return DungeonGridData.Direction.EAST
	elif offset == Vector2i(-1, 0):
		return DungeonGridData.Direction.WEST
	return -1


## Quick validation check - returns true if valid, false if any errors
static func is_valid(grid: Dictionary) -> bool:
	var result: ValidationResult = validate(grid)
	return result.is_valid
