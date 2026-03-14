## dungeon_manager.gd - Autoload for dungeon generation and management
##
## Coordinates dungeon generation with the cell streaming system.
## Manages the active dungeon and provides generation hooks.
extends Node

## Emitted when dungeon generation starts
signal generation_started(seed_value: int)

## Emitted when dungeon generation completes successfully
signal done_generating(dungeon_id: String, room_count: int)

## Emitted when dungeon generation fails
signal generation_failed(reason: String)

## Current dungeon builder
var _builder: DungeonBuilder = null

## Room registry (loaded room templates)
var _room_registry: Array[RoomData] = []

## Active dungeon ID
var _active_dungeon_id: String = ""

## Generation config
@export var default_max_rooms: int = 20
@export var stress_test_mode: bool = false
@export var debug_draw_enabled: bool = false

## Current populator
var _populator: DungeonPopulator = null

## Debug visualization node
var _debug_draw_node: Node3D = null

## Color palette for debug visualization
const DEBUG_COLORS: Dictionary = {
	"start": Color.GREEN,
	"boss": Color.RED,
	"corridor": Color.GRAY,
	"treasure": Color.GOLD,
	"hidden": Color.PURPLE,
	"dead_end": Color.DARK_GRAY,
	"default": Color.BLUE,
	"critical_path": Color.ORANGE
}


func _ready() -> void:
	_load_default_room_registry()

	if stress_test_mode:
		call_deferred("run_stress_test", 100)


## Generate a new dungeon with the given seed
func generate(dungeon_id: String, seed_value: int, max_rooms: int = -1) -> bool:
	if max_rooms < 0:
		max_rooms = default_max_rooms

	# Pause cell streaming if available
	if has_node("/root/CellStreamer"):
		var streamer: Node = get_node("/root/CellStreamer")
		if streamer.has_method("pause_streaming"):
			streamer.pause_streaming()

	emit_signal("generation_started", seed_value)

	# Create builder and generate
	_builder = DungeonBuilder.new()
	_builder.setup(_room_registry)

	var result: int = _builder.generate(seed_value, max_rooms)

	if result == DungeonBuilder.GenerateResult.SUCCESS:
		_active_dungeon_id = dungeon_id
		print("DungeonManager: Dungeon '%s' generated successfully (%d rooms)" % [
			dungeon_id, _builder.grid.get_room_count()
		])

		# Resume cell streaming if available
		if has_node("/root/CellStreamer"):
			var streamer: Node = get_node("/root/CellStreamer")
			if streamer.has_method("resume_streaming"):
				streamer.resume_streaming()

		emit_signal("done_generating", dungeon_id, _builder.grid.get_room_count())
		return true
	else:
		var reason: String = _result_to_string(result)
		push_error("DungeonManager: Generation failed - %s" % reason)
		emit_signal("generation_failed", reason)
		return false


## Get the current dungeon builder (for accessing grid, rooms, etc.)
func get_builder() -> DungeonBuilder:
	return _builder


## Get all placed rooms in the current dungeon
func get_placed_rooms() -> Array[PlacedRoom]:
	if _builder:
		return _builder.placed_rooms
	return []


## Get the dungeon grid
func get_grid() -> DungeonGrid:
	if _builder:
		return _builder.grid
	return null


## Print the current dungeon as 2D map
func print_dungeon() -> void:
	if _builder:
		_builder.print_grid_2d()
	else:
		print("DungeonManager: No dungeon generated")


## Run stress test with multiple seeds
func run_stress_test(count: int = 100, verbose: bool = false) -> Dictionary:
	print("=== Dungeon Stress Test: %d iterations ===" % count)

	var results: Dictionary = {
		"total": count,
		"passed": 0,
		"failed": 0,
		"failed_seeds": [],
		"failure_reasons": {},
		"avg_rooms": 0.0,
		"min_rooms": 9999,
		"max_rooms": 0,
		"avg_depth": 0.0
	}

	var total_rooms := 0
	var total_depth := 0

	for i in range(count):
		var seed_val: int = i * 12345 + 1
		var test_result: Dictionary = _run_single_test(seed_val, verbose)

		if test_result["success"]:
			results["passed"] += 1
			total_rooms += test_result["room_count"]
			total_depth += test_result["max_depth"]
			results["min_rooms"] = mini(results["min_rooms"], test_result["room_count"])
			results["max_rooms"] = maxi(results["max_rooms"], test_result["room_count"])
		else:
			results["failed"] += 1
			results["failed_seeds"].append(seed_val)
			var reason: String = test_result["reason"]
			results["failure_reasons"][reason] = results["failure_reasons"].get(reason, 0) + 1

		# Clear between tests
		_builder = null

	# Calculate averages
	if results["passed"] > 0:
		results["avg_rooms"] = float(total_rooms) / results["passed"]
		results["avg_depth"] = float(total_depth) / results["passed"]
	if results["min_rooms"] == 9999:
		results["min_rooms"] = 0

	# Print summary
	print("=== Stress Test Results ===")
	print("Passed: %d / %d (%.1f%%)" % [results["passed"], count, (results["passed"] * 100.0 / count)])
	print("Failed: %d" % results["failed"])
	if results["passed"] > 0:
		print("Room count: min=%d, max=%d, avg=%.1f" % [results["min_rooms"], results["max_rooms"], results["avg_rooms"]])
		print("Avg depth: %.1f" % results["avg_depth"])
	if not results["failed_seeds"].is_empty():
		print("Failed seeds: %s" % str(results["failed_seeds"]))
		print("Failure reasons: %s" % str(results["failure_reasons"]))

	return results


func _run_single_test(seed_val: int, verbose: bool) -> Dictionary:
	var result: Dictionary = {
		"success": false,
		"reason": "",
		"room_count": 0,
		"max_depth": 0
	}

	# Generate
	_builder = DungeonBuilder.new()
	_builder.setup(_room_registry)
	var gen_result: int = _builder.generate(seed_val, default_max_rooms)

	if gen_result != DungeonBuilder.GenerateResult.SUCCESS:
		result["reason"] = _result_to_string(gen_result)
		return result

	# Validate connectivity
	if not _builder.validate_all_connected():
		result["reason"] = "Connectivity check failed"
		return result

	# Validate boss reachable
	if not _builder.validate_boss_reachable():
		result["reason"] = "Boss unreachable"
		return result

	# Check for boss room
	if _builder.grid.get_boss_room() == null:
		result["reason"] = "No boss room"
		return result

	# Success
	result["success"] = true
	result["room_count"] = _builder.grid.get_room_count()
	result["max_depth"] = _builder.grid.get_max_depth()

	if verbose:
		print("Seed %d: %d rooms, depth %d" % [seed_val, result["room_count"], result["max_depth"]])

	return result


## Register a room template
func register_room(room_data: RoomData) -> void:
	if room_data and room_data not in _room_registry:
		_room_registry.append(room_data)


## Clear the room registry
func clear_room_registry() -> void:
	_room_registry.clear()


## Load room registry from directory
func load_room_registry(directory: String) -> int:
	var dir := DirAccess.open(directory)
	if dir == null:
		push_error("DungeonManager: Cannot open directory %s" % directory)
		return 0

	var count := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path := directory.path_join(file_name)
			var res: Resource = load(path)
			if res is RoomData:
				register_room(res as RoomData)
				count += 1
		file_name = dir.get_next()

	dir.list_dir_end()
	print("DungeonManager: Loaded %d room templates from %s" % [count, directory])
	return count


func _load_default_room_registry() -> void:
	# Create basic room templates for testing
	_room_registry.clear()

	# Start room (2x2)
	var start := RoomData.new()
	start.room_id = "start_room"
	start.display_name = "Entrance Hall"
	start.footprint = Vector2i(2, 2)
	start.entrances = [Vector2i(1, 0)]
	start.entrance_dirs = [RoomData.Dir.SOUTH]
	start.tags = [RoomData.RoomTag.START]
	_room_registry.append(start)

	# Corridor (1x3)
	var corridor := RoomData.new()
	corridor.room_id = "corridor_1x3"
	corridor.display_name = "Corridor"
	corridor.footprint = Vector2i(1, 3)
	corridor.entrances = [Vector2i(0, 0), Vector2i(0, 2)]
	corridor.entrance_dirs = [RoomData.Dir.NORTH, RoomData.Dir.SOUTH]
	corridor.tags = [RoomData.RoomTag.CORRIDOR]
	_room_registry.append(corridor)

	# Cross junction (3x3)
	var cross := RoomData.new()
	cross.room_id = "cross_junction"
	cross.display_name = "Junction"
	cross.footprint = Vector2i(3, 3)
	cross.entrances = [Vector2i(1, 0), Vector2i(2, 1), Vector2i(1, 2), Vector2i(0, 1)]
	cross.entrance_dirs = [RoomData.Dir.NORTH, RoomData.Dir.EAST, RoomData.Dir.SOUTH, RoomData.Dir.WEST]
	_room_registry.append(cross)

	# T-junction (2x2)
	var t_junction := RoomData.new()
	t_junction.room_id = "t_junction"
	t_junction.display_name = "T-Junction"
	t_junction.footprint = Vector2i(2, 2)
	t_junction.entrances = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	t_junction.entrance_dirs = [RoomData.Dir.NORTH, RoomData.Dir.EAST, RoomData.Dir.SOUTH]
	_room_registry.append(t_junction)

	# Standard room (2x2)
	var standard := RoomData.new()
	standard.room_id = "room_2x2"
	standard.display_name = "Chamber"
	standard.footprint = Vector2i(2, 2)
	standard.entrances = [Vector2i(0, 0), Vector2i(1, 1)]
	standard.entrance_dirs = [RoomData.Dir.WEST, RoomData.Dir.EAST]
	_room_registry.append(standard)

	# Treasure room (2x2)
	var treasure := RoomData.new()
	treasure.room_id = "treasure_room"
	treasure.display_name = "Treasure Chamber"
	treasure.footprint = Vector2i(2, 2)
	treasure.entrances = [Vector2i(0, 0)]
	treasure.entrance_dirs = [RoomData.Dir.SOUTH]
	treasure.tags = [RoomData.RoomTag.TREASURE, RoomData.RoomTag.DEAD_END]
	treasure.min_depth = 2
	treasure.max_count = DungeonConstants.MAX_TREASURE_ROOMS
	_room_registry.append(treasure)

	# Boss room (3x3)
	var boss := RoomData.new()
	boss.room_id = "boss_room"
	boss.display_name = "Boss Arena"
	boss.footprint = Vector2i(3, 3)
	boss.entrances = [Vector2i(1, 0)]
	boss.entrance_dirs = [RoomData.Dir.SOUTH]
	boss.tags = [RoomData.RoomTag.BOSS]
	boss.min_depth = DungeonConstants.MIN_BOSS_DEPTH
	boss.max_count = 1
	_room_registry.append(boss)

	# Dead end (1x1)
	var dead_end := RoomData.new()
	dead_end.room_id = "dead_end"
	dead_end.display_name = "Dead End"
	dead_end.footprint = Vector2i(1, 1)
	dead_end.entrances = [Vector2i(0, 0)]
	dead_end.entrance_dirs = [RoomData.Dir.SOUTH]
	dead_end.tags = [RoomData.RoomTag.DEAD_END]
	_room_registry.append(dead_end)

	# Hidden room (2x2)
	var hidden := RoomData.new()
	hidden.room_id = "hidden_room"
	hidden.display_name = "Secret Chamber"
	hidden.footprint = Vector2i(2, 2)
	hidden.entrances = [Vector2i(0, 0)]
	hidden.entrance_dirs = [RoomData.Dir.SOUTH]
	hidden.tags = [RoomData.RoomTag.HIDDEN, RoomData.RoomTag.TREASURE]
	hidden.min_depth = DungeonConstants.MIN_HIDDEN_ROOM_DEPTH
	hidden.max_count = 2
	_room_registry.append(hidden)

	print("DungeonManager: Loaded %d default room templates" % _room_registry.size())


func _result_to_string(result: int) -> String:
	match result:
		DungeonBuilder.GenerateResult.SUCCESS: return "Success"
		DungeonBuilder.GenerateResult.NO_START_ROOM: return "No start room in registry"
		DungeonBuilder.GenerateResult.NO_BOSS_ROOM: return "Failed to place boss room"
		DungeonBuilder.GenerateResult.NOT_CONNECTED: return "Dungeon not fully connected"
		DungeonBuilder.GenerateResult.FAILED: return "Generation failed"
		_: return "Unknown error"


# ============================================================================
# DEBUG VISUALIZATION
# ============================================================================

## Draw debug visualization of the dungeon grid
func draw_debug_grid(parent: Node3D = null) -> void:
	if _builder == null:
		push_warning("DungeonManager: No dungeon to visualize")
		return

	# Clear previous debug draw
	clear_debug_draw()

	# Create container
	_debug_draw_node = Node3D.new()
	_debug_draw_node.name = "DungeonDebugDraw"

	if parent:
		parent.add_child(_debug_draw_node)
	else:
		add_child(_debug_draw_node)

	# Draw each room as a colored box
	for room: PlacedRoom in _builder.placed_rooms:
		_draw_room_debug(room)

	print("DungeonManager: Debug grid drawn (%d rooms)" % _builder.placed_rooms.size())


## Draw debug visualization of the dungeon graph (connections)
func draw_dungeon_graph(parent: Node3D = null) -> void:
	if _builder == null:
		push_warning("DungeonManager: No dungeon to visualize")
		return

	if _debug_draw_node == null:
		draw_debug_grid(parent)

	# Draw connections as lines
	var drawn_pairs: Dictionary = {}

	for room: PlacedRoom in _builder.placed_rooms:
		var neighbors: Array[int] = []
		neighbors.assign(_builder.dungeon_graph.get(room.instance_id, []))
		for neighbor_id: int in neighbors:
			# Avoid drawing the same connection twice
			var pair_key: String = "%d-%d" % [mini(room.instance_id, neighbor_id), maxi(room.instance_id, neighbor_id)]
			if drawn_pairs.has(pair_key):
				continue
			drawn_pairs[pair_key] = true

			var neighbor: PlacedRoom = _builder.grid.get_room_by_id(neighbor_id)
			if neighbor:
				_draw_connection_debug(room, neighbor)

	print("DungeonManager: Debug graph drawn (%d connections)" % drawn_pairs.size())


## Clear debug visualization
func clear_debug_draw() -> void:
	if _debug_draw_node and is_instance_valid(_debug_draw_node):
		_debug_draw_node.queue_free()
		_debug_draw_node = null


func _draw_room_debug(room: PlacedRoom) -> void:
	var color: Color = _get_room_color(room)

	# Get room center in world space
	var cells: Array[Vector2i] = room.get_occupied_cells()
	var center: Vector3 = Vector3.ZERO
	for cell: Vector2i in cells:
		center += DungeonUtils.grid_to_world(cell)
	center /= cells.size()

	# Calculate room bounds
	var rotated_fp: Vector2i = DungeonUtils.rotate_footprint(room.room_data.footprint, room.rotation_deg)
	var size: Vector3 = Vector3(
		rotated_fp.x * DungeonUtils.CELL_SIZE.x * 0.9,
		DungeonUtils.CELL_SIZE.y * 0.5,
		rotated_fp.y * DungeonUtils.CELL_SIZE.z * 0.9
	)

	# Create box mesh
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh

	# Create material
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.5
	mesh_instance.material_override = material

	mesh_instance.position = center + Vector3(0, size.y * 0.5 + 0.1, 0)
	mesh_instance.name = "Room_%d_%s" % [room.instance_id, room.room_data.room_id]

	_debug_draw_node.add_child(mesh_instance)

	# Add label
	var label := Label3D.new()
	label.text = "%d\n%s" % [room.depth, room.room_data.room_id]
	label.position = center + Vector3(0, size.y + 0.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.outline_size = 4
	_debug_draw_node.add_child(label)


func _draw_connection_debug(room_a: PlacedRoom, room_b: PlacedRoom) -> void:
	var pos_a: Vector3 = room_a.get_world_position() + Vector3(0, 1, 0)
	var pos_b: Vector3 = room_b.get_world_position() + Vector3(0, 1, 0)

	# Check if on critical path
	var is_critical: bool = _builder.is_on_critical_path(room_a.instance_id) and _builder.is_on_critical_path(room_b.instance_id)
	var color: Color = DEBUG_COLORS["critical_path"] if is_critical else Color.WHITE

	# Create line using ImmediateMesh
	var mesh_instance := MeshInstance3D.new()
	var immediate_mesh := ImmediateMesh.new()

	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate_mesh.surface_set_color(color)
	immediate_mesh.surface_add_vertex(pos_a)
	immediate_mesh.surface_add_vertex(pos_b)
	immediate_mesh.surface_end()

	mesh_instance.mesh = immediate_mesh
	mesh_instance.name = "Connection_%d_%d" % [room_a.instance_id, room_b.instance_id]

	_debug_draw_node.add_child(mesh_instance)


func _get_room_color(room: PlacedRoom) -> Color:
	if room.room_data.is_start():
		return DEBUG_COLORS["start"]
	elif room.room_data.is_boss():
		return DEBUG_COLORS["boss"]
	elif room.is_hidden:
		return DEBUG_COLORS["hidden"]
	elif room.room_data.has_tag(RoomData.RoomTag.CORRIDOR):
		return DEBUG_COLORS["corridor"]
	elif room.room_data.has_tag(RoomData.RoomTag.TREASURE):
		return DEBUG_COLORS["treasure"]
	elif room.room_data.has_tag(RoomData.RoomTag.DEAD_END):
		return DEBUG_COLORS["dead_end"]
	else:
		return DEBUG_COLORS["default"]


# ============================================================================
# FULL GENERATION PIPELINE
# ============================================================================

## Run full generation pipeline with population
func generate_and_populate(
	dungeon_id: String,
	seed_value: int,
	rooms_container: Node3D,
	caps_container: Node3D,
	entities_container: Node3D = null,
	max_rooms: int = -1
) -> bool:
	# Step 1: Generate layout
	if not generate(dungeon_id, seed_value, max_rooms):
		return false

	# Step 2: Place hidden rooms
	_builder.place_hidden_rooms()

	# Step 3: Place locked doors
	_builder.place_locked_doors()

	# Step 4: Create populator
	_populator = DungeonPopulator.new()
	_populator.setup(_builder, rooms_container, caps_container, entities_container)

	# Step 5: Instantiate rooms
	_populator.instantiate_rooms()

	# Step 6: Seal exits
	_populator.seal_exits()

	# Step 7: Populate entities
	_populator.populate()

	# Step 8: Draw debug if enabled
	if debug_draw_enabled:
		draw_debug_grid()
		draw_dungeon_graph()

	return true


## Get the current populator
func get_populator() -> DungeonPopulator:
	return _populator
