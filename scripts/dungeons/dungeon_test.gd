## dungeon_test.gd - Test node for dungeon data layer
##
## Run this node to verify the data layer compiles and works correctly.
## Tests RoomData creation, PlacedRoom placement, and grid operations.
extends Node

func _ready() -> void:
	print("=== Dungeon Data Layer Test ===")
	_test_utils()
	_test_room_data()
	_test_placed_room()
	_test_grid()
	print("=== All Tests Complete ===")


func _test_utils() -> void:
	print("\n--- Testing DungeonUtils ---")

	# Test grid_to_world
	var world_pos: Vector3 = DungeonUtils.grid_to_world(Vector2i(0, 0))
	print("grid_to_world(0,0) = %s (expected: center of cell)" % str(world_pos))

	world_pos = DungeonUtils.grid_to_world(Vector2i(2, 3))
	print("grid_to_world(2,3) = %s" % str(world_pos))

	# Test world_to_grid
	var grid_pos: Vector2i = DungeonUtils.world_to_grid(Vector3(20.0, 0.0, 28.0))
	print("world_to_grid(20,0,28) = %s (expected: (2,3))" % str(grid_pos))

	# Test direction rotation
	print("rotate_dir(NORTH, 90) = %s (expected: EAST)" % DungeonUtils.dir_to_string(DungeonUtils.rotate_dir(DungeonUtils.DIR_NORTH, 90)))
	print("rotate_dir(EAST, 180) = %s (expected: WEST)" % DungeonUtils.dir_to_string(DungeonUtils.rotate_dir(DungeonUtils.DIR_EAST, 180)))

	# Test cell rotation
	var cell: Vector2i = DungeonUtils.rotate_cell(Vector2i(0, 0), Vector2i(2, 2), 90)
	print("rotate_cell((0,0), fp(2,2), 90) = %s" % str(cell))

	# Test footprint cells
	var cells: Array[Vector2i] = DungeonUtils.get_footprint_cells(Vector2i(5, 5), Vector2i(2, 3), 0)
	print("get_footprint_cells((5,5), (2,3), 0) = %d cells" % cells.size())


func _test_room_data() -> void:
	print("\n--- Testing RoomData ---")

	# Create a test room
	var room := RoomData.new()
	room.room_id = "test_corridor"
	room.display_name = "Test Corridor"
	room.footprint = Vector2i(1, 3)
	room.entrances = [Vector2i(0, 0), Vector2i(0, 2)]
	room.entrance_dirs = [RoomData.Dir.SOUTH, RoomData.Dir.NORTH]
	room.tags = [RoomData.RoomTag.CORRIDOR]
	room.valid_rotations = [0, 90, 180, 270]

	print("Created RoomData: %s" % room.room_id)
	print("  Footprint: %s" % str(room.footprint))
	print("  Entrances: %d" % room.get_entrance_count())
	print("  Is corridor: %s" % str(room.has_tag(RoomData.RoomTag.CORRIDOR)))
	print("  Is start: %s" % str(room.is_start()))
	print("  Is dead-end: %s" % str(room.is_dead_end()))

	# Create a start room
	var start_room := RoomData.new()
	start_room.room_id = "test_start"
	start_room.footprint = Vector2i(2, 2)
	start_room.entrances = [Vector2i(1, 0), Vector2i(0, 1)]
	start_room.entrance_dirs = [RoomData.Dir.SOUTH, RoomData.Dir.WEST]
	start_room.tags = [RoomData.RoomTag.START]

	print("Created start room: is_start=%s" % str(start_room.is_start()))

	# Create a boss room
	var boss_room := RoomData.new()
	boss_room.room_id = "test_boss"
	boss_room.footprint = Vector2i(3, 3)
	boss_room.entrances = [Vector2i(1, 0)]
	boss_room.entrance_dirs = [RoomData.Dir.SOUTH]
	boss_room.tags = [RoomData.RoomTag.BOSS]
	boss_room.min_depth = 5

	print("Created boss room: is_boss=%s, min_depth=%d" % [str(boss_room.is_boss()), boss_room.min_depth])


func _test_placed_room() -> void:
	print("\n--- Testing PlacedRoom ---")

	# Create RoomData
	var room_data := RoomData.new()
	room_data.room_id = "test_room"
	room_data.footprint = Vector2i(2, 2)
	room_data.entrances = [Vector2i(0, 0), Vector2i(1, 1)]
	room_data.entrance_dirs = [RoomData.Dir.SOUTH, RoomData.Dir.NORTH]

	# Create PlacedRoom
	var placed: PlacedRoom = PlacedRoom.create(room_data, Vector2i(5, 5), 0, 2)
	print("Created PlacedRoom: %s" % str(placed))

	# Test world position
	var world_pos: Vector3 = placed.get_world_position()
	print("World position: %s" % str(world_pos))

	# Test occupied cells
	var cells: Array[Vector2i] = placed.get_occupied_cells()
	print("Occupied cells: %d" % cells.size())
	for cell: Vector2i in cells:
		print("  - %s" % str(cell))

	# Test entrances
	var entrances: Array[Vector2i] = placed.get_world_entrances()
	var dirs: Array[int] = placed.get_world_entrance_dirs()
	print("World entrances:")
	for i in range(entrances.size()):
		print("  - %s facing %s" % [str(entrances[i]), DungeonUtils.dir_to_string(dirs[i])])

	# Test exit connection
	placed.connect_exit(0)
	print("After connecting exit 0:")
	print("  Unconnected: %d" % placed.get_unconnected_exit_count())
	print("  Exit 0 connected: %s" % str(placed.is_exit_connected(0)))
	print("  Exit 1 connected: %s" % str(placed.is_exit_connected(1)))


func _test_grid() -> void:
	print("\n--- Testing DungeonGrid ---")

	var grid := DungeonGrid.new()

	# Create some room data
	var start_data := RoomData.new()
	start_data.room_id = "start"
	start_data.footprint = Vector2i(2, 2)
	start_data.entrances = [Vector2i(1, 1)]
	start_data.entrance_dirs = [RoomData.Dir.SOUTH]
	start_data.tags = [RoomData.RoomTag.START]

	var corridor_data := RoomData.new()
	corridor_data.room_id = "corridor"
	corridor_data.footprint = Vector2i(1, 3)
	corridor_data.entrances = [Vector2i(0, 0), Vector2i(0, 2)]
	corridor_data.entrance_dirs = [RoomData.Dir.NORTH, RoomData.Dir.SOUTH]
	corridor_data.tags = [RoomData.RoomTag.CORRIDOR]

	var boss_data := RoomData.new()
	boss_data.room_id = "boss"
	boss_data.footprint = Vector2i(3, 3)
	boss_data.entrances = [Vector2i(1, 0)]
	boss_data.entrance_dirs = [RoomData.Dir.NORTH]
	boss_data.tags = [RoomData.RoomTag.BOSS]

	# Place rooms
	var start_room: PlacedRoom = PlacedRoom.create(start_data, Vector2i(0, 0), 0, 0)
	var placed_start: bool = grid.place(start_room)
	print("Placed start room: %s" % str(placed_start))

	var corridor_room: PlacedRoom = PlacedRoom.create(corridor_data, Vector2i(2, 0), 0, 1)
	var placed_corridor: bool = grid.place(corridor_room)
	print("Placed corridor: %s" % str(placed_corridor))

	var boss_room: PlacedRoom = PlacedRoom.create(boss_data, Vector2i(3, 0), 0, 2)
	var placed_boss: bool = grid.place(boss_room)
	print("Placed boss room: %s" % str(placed_boss))

	# Test overlap detection
	var overlap_room: PlacedRoom = PlacedRoom.create(corridor_data, Vector2i(1, 0), 0, 1)
	var placed_overlap: bool = grid.place(overlap_room)
	print("Attempt to place overlapping room: %s (expected: false)" % str(placed_overlap))

	# Grid info
	print("\nGrid stats:")
	print("  Total rooms: %d" % grid.get_room_count())
	print("  Max depth: %d" % grid.get_max_depth())
	print("  Bounds: %s" % str(grid.get_bounds()))

	# Find special rooms
	var found_start: PlacedRoom = grid.get_start_room()
	var found_boss: PlacedRoom = grid.get_boss_room()
	print("  Start room: %s" % (str(found_start) if found_start else "NOT FOUND"))
	print("  Boss room: %s" % (str(found_boss) if found_boss else "NOT FOUND"))

	# Print debug grid
	print("\nDebug grid view:")
	grid.print_debug()

	# Test world positions
	print("\nWorld positions:")
	for room: PlacedRoom in grid.get_all_placed():
		print("  %s at %s -> world %s" % [
			room.room_data.room_id,
			str(room.cell),
			str(room.get_world_position())
		])
