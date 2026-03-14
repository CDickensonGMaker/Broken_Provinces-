## dungeon_builder.gd - Procedural dungeon generation using BFS expansion
##
## Generates a connected dungeon layout from a pool of room templates.
## Uses breadth-first expansion from the start room, then forces boss placement.
class_name DungeonBuilder
extends RefCounted

## Generation result
enum GenerateResult { SUCCESS, NO_START_ROOM, NO_BOSS_ROOM, NOT_CONNECTED, FAILED }

## The spatial grid tracking placed rooms
var grid: DungeonGrid = DungeonGrid.new()

## Graph of room connections: instance_id -> Array[int] of connected instance_ids
var dungeon_graph: Dictionary = {}

## All placed rooms in BFS order
var placed_rooms: Array[PlacedRoom] = []

## Random number generator (seeded for reproducibility)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Room registry (pool of available RoomData templates)
var _room_registry: Array[RoomData] = []

## Fallback dead-end room (1x1, single entrance)
var _dead_end_room: RoomData = null

## Generation seed for debugging
var _seed: int = 0

## BFS frontier: Array of {room: PlacedRoom, exit_index: int}
var _frontier: Array[Dictionary] = []

## Locked door data: {from_room_id: int, to_room_id: int, key_room_id: int}
var locked_doors: Array[Dictionary] = []

## Room flagged to spawn the key item
var key_spawn_room: PlacedRoom = null

## Critical path room IDs (rooms on the path from start to boss)
var _critical_path: Array[int] = []


## Initialize with a room registry
func setup(room_registry: Array[RoomData], dead_end: RoomData = null) -> void:
	_room_registry = room_registry
	_dead_end_room = dead_end if dead_end else _create_default_dead_end()


## Generate a dungeon
## Returns GenerateResult indicating success or failure reason
func generate(seed_value: int, max_rooms: int = DungeonConstants.MAX_ROOMS_DEFAULT) -> int:
	_seed = seed_value
	rng.seed = seed_value

	# Clear previous state
	grid.clear()
	dungeon_graph.clear()
	placed_rooms.clear()
	_frontier.clear()

	print("DungeonBuilder: Generating dungeon with seed %d, max_rooms %d" % [seed_value, max_rooms])

	# Step 1: Place start room
	var start_data: RoomData = _find_room_with_tag(RoomData.RoomTag.START)
	if start_data == null:
		push_error("DungeonBuilder: No start room in registry")
		return GenerateResult.NO_START_ROOM

	var start_room: PlacedRoom = _place_start_room(start_data)
	if start_room == null:
		push_error("DungeonBuilder: Failed to place start room")
		return GenerateResult.FAILED

	# Add start room exits to frontier
	_add_to_frontier(start_room)

	# Step 2: BFS expansion loop
	var rooms_placed := 1
	while not _frontier.is_empty() and rooms_placed < max_rooms:
		# Get next frontier entry
		var entry: Dictionary = _frontier.pop_front()
		var from_room: PlacedRoom = entry["room"]
		var exit_index: int = entry["exit_index"]

		# Skip if this exit is already connected
		if from_room.is_exit_connected(exit_index):
			continue

		# Try to place a room at this exit
		var new_room: PlacedRoom = _try_place_room_at_exit(from_room, exit_index)
		if new_room:
			rooms_placed += 1
			_add_to_frontier(new_room)
		else:
			# Use dead-end fallback
			var dead_end: PlacedRoom = _try_place_dead_end(from_room, exit_index)
			if dead_end:
				rooms_placed += 1

	# Step 3: Force boss room if not already placed
	var boss_placed: bool = grid.get_boss_room() != null
	if not boss_placed:
		boss_placed = _force_place_boss_room()
		if not boss_placed:
			push_error("DungeonBuilder: Failed to place boss room")
			return GenerateResult.NO_BOSS_ROOM

	# Step 4: Seal all remaining open exits with dead-ends
	_seal_remaining_exits()

	# Step 5: Validate connectivity
	if not validate_all_connected():
		push_error("DungeonBuilder: Dungeon is not fully connected")
		return GenerateResult.NOT_CONNECTED

	print("DungeonBuilder: Generation complete - %d rooms placed" % grid.get_room_count())
	return GenerateResult.SUCCESS


## Validate that all rooms are reachable from start via BFS
func validate_all_connected() -> bool:
	var start: PlacedRoom = grid.get_start_room()
	if start == null:
		return false

	var visited: Dictionary = {}
	var queue: Array[int] = [start.instance_id]
	visited[start.instance_id] = true

	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		var neighbors: Array[int] = []
		neighbors.assign(dungeon_graph.get(current_id, []))
		for neighbor_id: int in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)

	return visited.size() == placed_rooms.size()


## Validate that boss room is reachable from start
func validate_boss_reachable() -> bool:
	var start: PlacedRoom = grid.get_start_room()
	var boss: PlacedRoom = grid.get_boss_room()

	if start == null or boss == null:
		return false

	var visited: Dictionary = {}
	var queue: Array[int] = [start.instance_id]
	visited[start.instance_id] = true

	while not queue.is_empty():
		var current_id: int = queue.pop_front()
		if current_id == boss.instance_id:
			return true

		var neighbors: Array[int] = []
		neighbors.assign(dungeon_graph.get(current_id, []))
		for neighbor_id: int in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				queue.append(neighbor_id)

	return false


## Place hidden rooms behind false walls
## Called after main generation, before sealing
func place_hidden_rooms() -> int:
	var hidden_data: RoomData = _find_room_with_tag(RoomData.RoomTag.HIDDEN)
	if hidden_data == null:
		# No hidden room template available
		return 0

	var placed := 0
	var eligible_rooms: Array[PlacedRoom] = []

	# Find rooms deep enough for hidden rooms
	for room: PlacedRoom in placed_rooms:
		if room.depth >= DungeonConstants.MIN_HIDDEN_ROOM_DEPTH:
			if room.get_unconnected_exit_count() > 0:
				eligible_rooms.append(room)

	rng.shuffle(eligible_rooms)

	# Try to place hidden rooms
	for room: PlacedRoom in eligible_rooms:
		if rng.randf() > DungeonConstants.HIDDEN_ROOM_CHANCE:
			continue

		var unconnected: Array[int] = room.get_unconnected_exits()
		if unconnected.is_empty():
			continue

		var exit_index: int = unconnected[0]
		var hidden_room: PlacedRoom = _try_place_hidden_room(room, exit_index, hidden_data)
		if hidden_room:
			placed += 1

	print("DungeonBuilder: Placed %d hidden rooms" % placed)
	return placed


## Place locked doors on non-critical paths
## Returns true if a locked door was placed
func place_locked_doors() -> bool:
	# First, compute critical path from start to boss
	_compute_critical_path()

	if _critical_path.is_empty():
		return false

	# Find non-critical edges
	var non_critical_edges: Array[Dictionary] = []

	for room: PlacedRoom in placed_rooms:
		if room.instance_id in _critical_path:
			continue

		var neighbors: Array = dungeon_graph.get(room.instance_id, [])
		for neighbor_id: int in neighbors:
			if neighbor_id in _critical_path:
				# This edge connects to critical path - candidate for locked door
				non_critical_edges.append({
					"from": room.instance_id,
					"to": neighbor_id
				})

	if non_critical_edges.is_empty():
		return false

	# Pick a random edge to lock
	var edge: Dictionary = non_critical_edges[rng.randi() % non_critical_edges.size()]

	# Find a room on the critical path (before the locked door) to spawn the key
	var key_room_id: int = -1
	for room_id: int in _critical_path:
		if room_id == edge["to"]:
			break
		key_room_id = room_id

	if key_room_id == -1:
		key_room_id = _critical_path[0]

	locked_doors.append({
		"from_room_id": edge["from"],
		"to_room_id": edge["to"],
		"key_room_id": key_room_id
	})

	key_spawn_room = grid.get_room_by_id(key_room_id)

	print("DungeonBuilder: Locked door placed (key in room %d)" % key_room_id)
	return true


## Print the grid as a 2D symbol map
func print_grid_2d() -> void:
	if placed_rooms.is_empty():
		print("(empty dungeon)")
		return

	var bounds: Rect2i = grid.get_bounds()
	print("Dungeon Grid (%d rooms, seed=%d):" % [placed_rooms.size(), _seed])

	for y in range(bounds.position.y, bounds.position.y + bounds.size.y):
		var line := ""
		for x in range(bounds.position.x, bounds.position.x + bounds.size.x):
			var cell := Vector2i(x, y)
			var room: PlacedRoom = grid.get_room(cell)
			if room == null:
				line += "."
			elif room.room_data.is_start():
				line += "S"
			elif room.room_data.is_boss():
				line += "B"
			elif room.is_hidden:
				line += "H"
			elif room.room_data.has_tag(RoomData.RoomTag.CORRIDOR):
				line += "C"
			elif room.room_data.has_tag(RoomData.RoomTag.DEAD_END):
				line += "D"
			elif room.room_data.has_tag(RoomData.RoomTag.TREASURE):
				line += "T"
			else:
				line += "R"
		print(line)


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _place_start_room(start_data: RoomData) -> PlacedRoom:
	var room: PlacedRoom = PlacedRoom.create(start_data, Vector2i(0, 0), 0, 0)
	if grid.place(room):
		placed_rooms.append(room)
		dungeon_graph[room.instance_id] = []
		return room
	return null


func _add_to_frontier(room: PlacedRoom) -> void:
	for i in range(room.room_data.get_entrance_count()):
		if not room.is_exit_connected(i):
			_frontier.append({"room": room, "exit_index": i})


func _try_place_room_at_exit(from_room: PlacedRoom, exit_index: int) -> PlacedRoom:
	# Get exit position and direction in world space
	var exits: Array[Vector2i] = from_room.get_world_entrances()
	var exit_dirs: Array[int] = from_room.get_world_entrance_dirs()

	if exit_index >= exits.size():
		return null

	var exit_cell: Vector2i = exits[exit_index]
	var exit_dir: int = exit_dirs[exit_index]
	var target_cell: Vector2i = DungeonUtils.get_adjacent_cell(exit_cell, exit_dir)
	var needed_dir: int = DungeonUtils.opposite_dir(exit_dir)

	# Filter valid room candidates
	var candidates: Array[RoomData] = _get_valid_candidates(from_room.depth + 1)
	rng.shuffle(candidates)

	# Try each candidate with each valid rotation
	for room_data: RoomData in candidates:
		var rotations: Array = room_data.valid_rotations.duplicate()
		rng.shuffle(rotations)

		for rotation: int in rotations:
			var anchor: Vector2i = _calc_anchor_for_entrance(room_data, rotation, target_cell, needed_dir)
			if anchor == Vector2i(-99999, -99999):
				continue

			if grid.can_place(anchor, room_data.footprint, rotation):
				var new_room: PlacedRoom = PlacedRoom.create(room_data, anchor, rotation, from_room.depth + 1)
				if grid.place(new_room):
					# Connect the rooms
					_connect_rooms(from_room, exit_index, new_room, needed_dir)
					placed_rooms.append(new_room)
					dungeon_graph[new_room.instance_id] = []
					return new_room

	return null


func _try_place_dead_end(from_room: PlacedRoom, exit_index: int) -> PlacedRoom:
	if _dead_end_room == null:
		return null

	var exits: Array[Vector2i] = from_room.get_world_entrances()
	var exit_dirs: Array[int] = from_room.get_world_entrance_dirs()

	if exit_index >= exits.size():
		return null

	var exit_cell: Vector2i = exits[exit_index]
	var exit_dir: int = exit_dirs[exit_index]
	var target_cell: Vector2i = DungeonUtils.get_adjacent_cell(exit_cell, exit_dir)
	var needed_dir: int = DungeonUtils.opposite_dir(exit_dir)

	# Calculate rotation for dead-end
	var base_dir: int = _dead_end_room.entrance_dirs[0] if _dead_end_room.entrance_dirs.size() > 0 else 0
	var rotation: int = DungeonUtils.calc_rotation_for_connection(base_dir, exit_dir)

	if grid.can_place(target_cell, _dead_end_room.footprint, rotation):
		var dead_end: PlacedRoom = PlacedRoom.create(_dead_end_room, target_cell, rotation, from_room.depth + 1)
		if grid.place(dead_end):
			_connect_rooms(from_room, exit_index, dead_end, needed_dir)
			placed_rooms.append(dead_end)
			dungeon_graph[dead_end.instance_id] = []
			return dead_end

	return null


func _force_place_boss_room() -> bool:
	var boss_data: RoomData = _find_room_with_tag(RoomData.RoomTag.BOSS)
	if boss_data == null:
		return false

	# Find deepest rooms with unconnected exits
	var max_depth: int = grid.get_max_depth()
	var candidates: Array[Dictionary] = []

	for room: PlacedRoom in placed_rooms:
		if room.depth >= max_depth - 1:
			for exit_i: int in room.get_unconnected_exits():
				candidates.append({"room": room, "exit_index": exit_i})

	rng.shuffle(candidates)

	# Try to place boss room at each candidate
	for entry: Dictionary in candidates:
		var from_room: PlacedRoom = entry["room"]
		var exit_index: int = entry["exit_index"]

		var exits: Array[Vector2i] = from_room.get_world_entrances()
		var exit_dirs: Array[int] = from_room.get_world_entrance_dirs()

		if exit_index >= exits.size():
			continue

		var exit_dir: int = exit_dirs[exit_index]
		var target_cell: Vector2i = DungeonUtils.get_adjacent_cell(exits[exit_index], exit_dir)
		var needed_dir: int = DungeonUtils.opposite_dir(exit_dir)

		for rotation: int in boss_data.valid_rotations:
			var anchor: Vector2i = _calc_anchor_for_entrance(boss_data, rotation, target_cell, needed_dir)
			if anchor == Vector2i(-99999, -99999):
				continue

			if grid.can_place(anchor, boss_data.footprint, rotation):
				var boss_room: PlacedRoom = PlacedRoom.create(boss_data, anchor, rotation, from_room.depth + 1)
				if grid.place(boss_room):
					_connect_rooms(from_room, exit_index, boss_room, needed_dir)
					placed_rooms.append(boss_room)
					dungeon_graph[boss_room.instance_id] = []
					return true

	return false


func _seal_remaining_exits() -> void:
	for room: PlacedRoom in placed_rooms:
		for exit_i: int in room.get_unconnected_exits():
			_try_place_dead_end(room, exit_i)


func _connect_rooms(room_a: PlacedRoom, exit_a: int, room_b: PlacedRoom, entrance_dir_b: int) -> void:
	# Mark exits as connected
	room_a.connect_exit(exit_a)

	# Find matching entrance in room_b
	var b_exits: Array[Vector2i] = room_b.get_world_entrances()
	var b_dirs: Array[int] = room_b.get_world_entrance_dirs()

	for i in range(b_dirs.size()):
		if b_dirs[i] == entrance_dir_b:
			room_b.connect_exit(i)
			break

	# Update graph
	if not dungeon_graph.has(room_a.instance_id):
		dungeon_graph[room_a.instance_id] = []
	if not dungeon_graph.has(room_b.instance_id):
		dungeon_graph[room_b.instance_id] = []

	dungeon_graph[room_a.instance_id].append(room_b.instance_id)
	dungeon_graph[room_b.instance_id].append(room_a.instance_id)


func _get_valid_candidates(depth: int) -> Array[RoomData]:
	var result: Array[RoomData] = []

	for room_data: RoomData in _room_registry:
		# Skip special rooms
		if room_data.is_start() or room_data.is_boss():
			continue

		# Check depth constraint
		if depth < room_data.min_depth:
			continue

		# Check max count constraint
		if room_data.max_count > 0:
			var current: int = grid.count_rooms_of_type(room_data)
			if current >= room_data.max_count:
				continue

		result.append(room_data)

	return result


func _find_room_with_tag(tag: RoomData.RoomTag) -> RoomData:
	for room_data: RoomData in _room_registry:
		if room_data.has_tag(tag):
			return room_data
	return null


func _calc_anchor_for_entrance(room_data: RoomData, rotation: int, target_cell: Vector2i, needed_dir: int) -> Vector2i:
	# Find an entrance that faces needed_dir after rotation
	for i in range(room_data.entrances.size()):
		var local_dir: int = room_data.entrance_dirs[i]
		var rotated_dir: int = DungeonUtils.rotate_dir(local_dir, rotation)

		if rotated_dir == needed_dir:
			# This entrance works - calculate anchor
			var local_entrance: Vector2i = room_data.entrances[i]
			var rotated_entrance: Vector2i = DungeonUtils.rotate_cell(local_entrance, room_data.footprint, rotation)
			return target_cell - rotated_entrance

	return Vector2i(-99999, -99999)  # No valid entrance found


func _create_default_dead_end() -> RoomData:
	var room := RoomData.new()
	room.room_id = "dead_end_default"
	room.display_name = "Dead End"
	room.footprint = Vector2i(1, 1)
	room.entrances = [Vector2i(0, 0)]
	room.entrance_dirs = [RoomData.Dir.SOUTH]
	room.tags = [RoomData.RoomTag.DEAD_END]
	room.valid_rotations = [0, 90, 180, 270]
	return room


func _try_place_hidden_room(from_room: PlacedRoom, exit_index: int, hidden_data: RoomData) -> PlacedRoom:
	var exits: Array[Vector2i] = from_room.get_world_entrances()
	var exit_dirs: Array[int] = from_room.get_world_entrance_dirs()

	if exit_index >= exits.size():
		return null

	var exit_cell: Vector2i = exits[exit_index]
	var exit_dir: int = exit_dirs[exit_index]
	var target_cell: Vector2i = DungeonUtils.get_adjacent_cell(exit_cell, exit_dir)
	var needed_dir: int = DungeonUtils.opposite_dir(exit_dir)

	# Try each valid rotation
	for rotation: int in hidden_data.valid_rotations:
		var anchor: Vector2i = _calc_anchor_for_entrance(hidden_data, rotation, target_cell, needed_dir)
		if anchor == Vector2i(-99999, -99999):
			continue

		if grid.can_place(anchor, hidden_data.footprint, rotation):
			var hidden_room: PlacedRoom = PlacedRoom.create(hidden_data, anchor, rotation, from_room.depth + 1)
			hidden_room.is_hidden = true

			if grid.place(hidden_room):
				_connect_rooms(from_room, exit_index, hidden_room, needed_dir)
				placed_rooms.append(hidden_room)
				dungeon_graph[hidden_room.instance_id] = []
				return hidden_room

	return null


func _compute_critical_path() -> void:
	_critical_path.clear()

	var start: PlacedRoom = grid.get_start_room()
	var boss: PlacedRoom = grid.get_boss_room()

	if start == null or boss == null:
		return

	# BFS to find shortest path from start to boss
	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[int] = [start.instance_id]
	visited[start.instance_id] = true
	parent[start.instance_id] = -1

	while not queue.is_empty():
		var current_id: int = queue.pop_front()

		if current_id == boss.instance_id:
			# Found boss - reconstruct path
			var path_id: int = boss.instance_id
			while path_id != -1:
				_critical_path.push_front(path_id)
				path_id = parent.get(path_id, -1)
			return

		var neighbors: Array[int] = []
		neighbors.assign(dungeon_graph.get(current_id, []))
		for neighbor_id: int in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				parent[neighbor_id] = current_id
				queue.append(neighbor_id)


## Get the critical path room IDs
func get_critical_path() -> Array[int]:
	return _critical_path.duplicate()


## Check if a room is on the critical path
func is_on_critical_path(room_id: int) -> bool:
	return room_id in _critical_path
