## dungeon_populator.gd - Instantiates room scenes and seals exits
##
## Phase 1: Instantiate room scenes at world positions
## Phase 2: Seal all unconnected exits with wall caps or false walls
## Phase 3: Populate with entities (enemies, loot, NPCs, boss)
class_name DungeonPopulator
extends RefCounted

## Wall cap scene for sealing normal exits
const WALL_CAP_SCENE := "res://scenes/dungeons/wall_cap.tscn"
const FALSE_WALL_SCENE := "res://scenes/dungeons/false_wall.tscn"

## Spawn point metadata keys
const SPAWN_TYPE_ENEMY := "enemy"
const SPAWN_TYPE_LOOT := "loot"
const SPAWN_TYPE_NPC_QUEST := "npc_quest"
const SPAWN_TYPE_BOSS := "boss"
const SPAWN_TYPE_KEY_ITEM := "key_item"

## Enemy-free zone (hops from start)
const ENEMY_FREE_HOPS := 2

## Container nodes in the dungeon scene
var rooms_container: Node3D = null
var caps_container: Node3D = null
var entities_container: Node3D = null

## Reference to the builder
var _builder: DungeonBuilder = null

## Preloaded scenes
var _wall_cap_packed: PackedScene = null
var _false_wall_packed: PackedScene = null

## Track claimed positions for spawn safety
var _claimed_positions: Array[Vector3] = []
const CLAIM_CLEARANCE := 1.5

## Rooms within ENEMY_FREE_HOPS of start (no enemies allowed)
var _safe_room_ids: Array[int] = []

## Rooms containing quest NPCs (no enemies allowed)
var _quest_npc_room_ids: Array[int] = []

## Population statistics
var _stats: Dictionary = {
	"enemies": 0,
	"loot": 0,
	"npcs": 0,
	"boss": 0,
	"key_items": 0
}


## Initialize the populator with a builder and parent containers
func setup(builder: DungeonBuilder, p_rooms_container: Node3D, p_caps_container: Node3D, p_entities_container: Node3D = null) -> void:
	_builder = builder
	rooms_container = p_rooms_container
	caps_container = p_caps_container
	entities_container = p_entities_container if p_entities_container else p_rooms_container

	# Preload seal scenes
	if ResourceLoader.exists(WALL_CAP_SCENE):
		_wall_cap_packed = load(WALL_CAP_SCENE)
	else:
		push_warning("DungeonPopulator: Wall cap scene not found at %s" % WALL_CAP_SCENE)

	if ResourceLoader.exists(FALSE_WALL_SCENE):
		_false_wall_packed = load(FALSE_WALL_SCENE)
	else:
		push_warning("DungeonPopulator: False wall scene not found at %s" % FALSE_WALL_SCENE)

	# Compute safe rooms (near start)
	_compute_safe_rooms()


## Instantiate all room scenes
func instantiate_rooms() -> int:
	if _builder == null or rooms_container == null:
		push_error("DungeonPopulator: Not properly initialized")
		return 0

	var count := 0
	for room: PlacedRoom in _builder.placed_rooms:
		if _instantiate_room(room):
			count += 1

	print("DungeonPopulator: Instantiated %d room scenes" % count)
	return count


## Seal all unconnected exits with wall caps
## Returns the number of exits sealed
func seal_exits() -> int:
	if _builder == null or caps_container == null:
		push_error("DungeonPopulator: Not properly initialized")
		return 0

	var sealed := 0
	var open_exits := 0

	for room: PlacedRoom in _builder.placed_rooms:
		var unconnected: Array[int] = room.get_unconnected_exits()
		for exit_index: int in unconnected:
			if _seal_exit(room, exit_index):
				sealed += 1
			else:
				open_exits += 1

	if open_exits > 0:
		push_warning("DungeonPopulator: %d exits could not be sealed" % open_exits)
	else:
		print("DungeonPopulator: All exits sealed (%d caps placed)" % sealed)

	return sealed


## Check that no exits remain open (assertion for validation)
func validate_all_sealed() -> bool:
	if _builder == null:
		return false

	for room: PlacedRoom in _builder.placed_rooms:
		var unconnected: Array[int] = room.get_unconnected_exits()
		if not unconnected.is_empty():
			push_error("DungeonPopulator: Room %s has %d unconnected exits" % [
				room.room_data.room_id, unconnected.size()
			])
			return false

	return true


## Populate the dungeon with entities in BFS order
func populate() -> Dictionary:
	if _builder == null:
		push_error("DungeonPopulator: Not properly initialized")
		return _stats

	clear_claimed_positions()
	_stats = {"enemies": 0, "loot": 0, "npcs": 0, "boss": 0, "key_items": 0}

	# First pass: identify quest NPC rooms (no enemies)
	_find_quest_npc_rooms()

	# BFS-order traversal of rooms
	var visited: Dictionary = {}
	var start: PlacedRoom = _builder.grid.get_start_room()
	if start == null:
		return _stats

	var queue: Array[PlacedRoom] = [start]
	visited[start.instance_id] = true

	while not queue.is_empty():
		var room: PlacedRoom = queue.pop_front()
		_populate_room(room)

		# Add neighbors to queue
		var neighbors: Array[int] = []
		neighbors.assign(_builder.dungeon_graph.get(room.instance_id, []))
		for neighbor_id: int in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				var neighbor: PlacedRoom = _builder.grid.get_room_by_id(neighbor_id)
				if neighbor:
					queue.append(neighbor)

	print("DungeonPopulator: Population complete - %s" % str(_stats))
	return _stats


## Get population statistics
func get_stats() -> Dictionary:
	return _stats.duplicate()


## Get all room scene instances
func get_room_instances() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for room: PlacedRoom in _builder.placed_rooms:
		if room.scene_instance:
			result.append(room.scene_instance)
	return result


## Check if a position is available for spawning (not claimed)
func is_position_available(pos: Vector3) -> bool:
	for claimed: Vector3 in _claimed_positions:
		if pos.distance_to(claimed) < CLAIM_CLEARANCE:
			return false
	return true


## Claim a position for spawning
func claim_position(pos: Vector3) -> void:
	_claimed_positions.append(pos)


## Clear all claimed positions
func clear_claimed_positions() -> void:
	_claimed_positions.clear()


# ============================================================================
# PRIVATE METHODS
# ============================================================================

func _instantiate_room(room: PlacedRoom) -> bool:
	if room.room_data == null or room.room_data.scene == null:
		# No scene - this is okay for template rooms without visuals
		return false

	var instance: Node3D = room.room_data.scene.instantiate()
	if instance == null:
		push_error("DungeonPopulator: Failed to instantiate scene for %s" % room.room_data.room_id)
		return false

	# Position and rotate
	instance.position = room.get_world_position()
	instance.rotation_degrees.y = room.rotation_deg

	# Add to container
	rooms_container.add_child(instance)
	room.scene_instance = instance

	# Set metadata for later reference
	instance.set_meta("placed_room", room)
	instance.set_meta("room_id", room.room_data.room_id)
	instance.set_meta("depth", room.depth)
	instance.set_meta("is_hidden", room.is_hidden)

	return true


func _seal_exit(room: PlacedRoom, exit_index: int) -> bool:
	# Get exit position and direction
	var exits: Array[Vector2i] = room.get_world_entrances()
	var dirs: Array[int] = room.get_world_entrance_dirs()

	if exit_index >= exits.size():
		return false

	var exit_cell: Vector2i = exits[exit_index]
	var exit_dir: int = dirs[exit_index]

	# Calculate world position for the cap
	# The cap should be at the edge of the room, facing outward
	var cell_world: Vector3 = DungeonUtils.grid_to_world(exit_cell)
	var dir_offset: Vector2i = DungeonUtils.dir_to_offset(exit_dir)
	var cap_pos: Vector3 = cell_world + Vector3(
		dir_offset.x * DungeonUtils.CELL_SIZE.x * 0.5,
		0.0,
		dir_offset.y * DungeonUtils.CELL_SIZE.z * 0.5
	)

	# Choose wall cap or false wall based on room type
	var packed: PackedScene = _wall_cap_packed
	if room.is_hidden and _false_wall_packed:
		packed = _false_wall_packed

	if packed == null:
		# Create placeholder mesh if no scene available
		return _create_placeholder_cap(cap_pos, exit_dir, room.is_hidden)

	var cap: Node3D = packed.instantiate()
	if cap == null:
		return false

	cap.position = cap_pos
	cap.rotation_degrees.y = _dir_to_rotation(exit_dir)
	caps_container.add_child(cap)

	# Set metadata
	cap.set_meta("seals_room", room.instance_id)
	cap.set_meta("exit_index", exit_index)
	cap.set_meta("is_false_wall", room.is_hidden)

	return true


func _create_placeholder_cap(pos: Vector3, dir: int, is_hidden: bool) -> bool:
	# Create a simple CSG box as placeholder
	var cap := CSGBox3D.new()
	cap.size = Vector3(DungeonUtils.CELL_SIZE.x, DungeonUtils.CELL_SIZE.y, 0.2)
	cap.position = pos

	# Rotate based on direction
	cap.rotation_degrees.y = _dir_to_rotation(dir)

	# Visual indicator
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.DARK_SLATE_GRAY if not is_hidden else Color.DARK_RED
	cap.material = material

	caps_container.add_child(cap)
	return true


func _dir_to_rotation(dir: int) -> float:
	# Convert direction to Y rotation in degrees
	match dir:
		DungeonUtils.DIR_NORTH: return 0.0
		DungeonUtils.DIR_EAST: return 90.0
		DungeonUtils.DIR_SOUTH: return 180.0
		DungeonUtils.DIR_WEST: return 270.0
		_: return 0.0


func _compute_safe_rooms() -> void:
	_safe_room_ids.clear()

	if _builder == null:
		return

	var start: PlacedRoom = _builder.grid.get_start_room()
	if start == null:
		return

	# BFS to find rooms within ENEMY_FREE_HOPS of start
	var visited: Dictionary = {}
	var queue: Array[Dictionary] = [{"room": start, "hops": 0}]
	visited[start.instance_id] = true
	_safe_room_ids.append(start.instance_id)

	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var room: PlacedRoom = entry["room"]
		var hops: int = entry["hops"]

		if hops >= ENEMY_FREE_HOPS:
			continue

		var neighbors: Array[int] = []
		neighbors.assign(_builder.dungeon_graph.get(room.instance_id, []))
		for neighbor_id: int in neighbors:
			if not visited.has(neighbor_id):
				visited[neighbor_id] = true
				_safe_room_ids.append(neighbor_id)
				var neighbor: PlacedRoom = _builder.grid.get_room_by_id(neighbor_id)
				if neighbor:
					queue.append({"room": neighbor, "hops": hops + 1})


func _find_quest_npc_rooms() -> void:
	_quest_npc_room_ids.clear()

	for room: PlacedRoom in _builder.placed_rooms:
		if room.scene_instance == null:
			continue

		var spawn_points: Node = room.scene_instance.get_node_or_null("SpawnPoints")
		if spawn_points == null:
			continue

		for child: Node in spawn_points.get_children():
			if child is Marker3D:
				var spawn_type: String = child.get_meta("spawn_type", "")
				if spawn_type == SPAWN_TYPE_NPC_QUEST:
					if room.instance_id not in _quest_npc_room_ids:
						_quest_npc_room_ids.append(room.instance_id)
					break


func _populate_room(room: PlacedRoom) -> void:
	if room.scene_instance == null:
		return

	var spawn_points: Node = room.scene_instance.get_node_or_null("SpawnPoints")
	if spawn_points == null:
		return

	var is_boss_room: bool = room.room_data.is_boss()
	var is_safe_room: bool = room.instance_id in _safe_room_ids
	var has_quest_npc: bool = room.instance_id in _quest_npc_room_ids
	var is_key_room: bool = _builder.key_spawn_room != null and _builder.key_spawn_room.instance_id == room.instance_id

	for child: Node in spawn_points.get_children():
		if not child is Marker3D:
			continue

		var marker: Marker3D = child as Marker3D
		var spawn_type: String = marker.get_meta("spawn_type", "")
		var world_pos: Vector3 = marker.global_position

		# Check position availability
		if not is_position_available(world_pos):
			continue

		match spawn_type:
			SPAWN_TYPE_ENEMY:
				# Enemies forbidden in start room, safe rooms, and quest NPC rooms
				if is_safe_room or has_quest_npc:
					continue
				if _spawn_enemy(marker, room):
					_stats["enemies"] += 1
					claim_position(world_pos)

			SPAWN_TYPE_LOOT:
				if _spawn_loot(marker, room):
					_stats["loot"] += 1
					claim_position(world_pos)

			SPAWN_TYPE_NPC_QUEST:
				if _spawn_quest_npc(marker, room):
					_stats["npcs"] += 1
					claim_position(world_pos)

			SPAWN_TYPE_BOSS:
				# Boss spawn only in boss room
				if is_boss_room:
					if _spawn_boss(marker, room):
						_stats["boss"] += 1
						claim_position(world_pos)
				else:
					push_warning("DungeonPopulator: Boss spawn point in non-boss room %s" % room.room_data.room_id)

			SPAWN_TYPE_KEY_ITEM:
				# Key item only in designated room
				if is_key_room:
					if _spawn_key_item(marker, room):
						_stats["key_items"] += 1
						claim_position(world_pos)


func _spawn_enemy(marker: Marker3D, room: PlacedRoom) -> bool:
	# Get enemy data from marker metadata
	var enemy_id: String = marker.get_meta("enemy_id", "")
	var enemy_data_path: String = marker.get_meta("enemy_data", "")

	if enemy_id.is_empty() and enemy_data_path.is_empty():
		push_warning("DungeonPopulator: Enemy spawn point missing enemy_id/enemy_data metadata")
		return false

	# TODO: Actually spawn enemy using EnemyBase.spawn_billboard_enemy
	# For now, create placeholder
	var placeholder := _create_spawn_placeholder(marker.global_position, Color.RED, "Enemy")
	if placeholder:
		entities_container.add_child(placeholder)
		return true

	return false


func _spawn_loot(marker: Marker3D, room: PlacedRoom) -> bool:
	var loot_table: String = marker.get_meta("loot_table", "common")
	var is_chest: bool = marker.get_meta("is_chest", false)

	# TODO: Actually spawn chest or loot pile
	# For now, create placeholder
	var placeholder := _create_spawn_placeholder(marker.global_position, Color.GOLD, "Loot")
	if placeholder:
		entities_container.add_child(placeholder)
		return true

	return false


func _spawn_quest_npc(marker: Marker3D, room: PlacedRoom) -> bool:
	var npc_id: String = marker.get_meta("npc_id", "")

	if npc_id.is_empty():
		push_warning("DungeonPopulator: NPC spawn point missing npc_id metadata")
		return false

	# TODO: Actually spawn NPC
	# For now, create placeholder
	var placeholder := _create_spawn_placeholder(marker.global_position, Color.CYAN, "NPC")
	if placeholder:
		entities_container.add_child(placeholder)
		return true

	return false


func _spawn_boss(marker: Marker3D, room: PlacedRoom) -> bool:
	var boss_id: String = marker.get_meta("boss_id", "")
	var boss_data_path: String = marker.get_meta("boss_data", "")

	if boss_id.is_empty() and boss_data_path.is_empty():
		push_warning("DungeonPopulator: Boss spawn point missing boss_id/boss_data metadata")
		return false

	# TODO: Actually spawn boss
	# For now, create placeholder
	var placeholder := _create_spawn_placeholder(marker.global_position, Color.PURPLE, "BOSS")
	if placeholder:
		placeholder.scale = Vector3(2, 2, 2)
		entities_container.add_child(placeholder)
		return true

	return false


func _spawn_key_item(marker: Marker3D, room: PlacedRoom) -> bool:
	var key_id: String = marker.get_meta("key_id", "dungeon_key")

	# TODO: Actually spawn key item
	# For now, create placeholder
	var placeholder := _create_spawn_placeholder(marker.global_position, Color.YELLOW, "KEY")
	if placeholder:
		entities_container.add_child(placeholder)
		return true

	return false


func _create_spawn_placeholder(pos: Vector3, color: Color, label: String) -> Node3D:
	var placeholder := CSGSphere3D.new()
	placeholder.radius = 0.3
	placeholder.position = pos + Vector3(0, 0.5, 0)

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	placeholder.material = material

	placeholder.name = "Placeholder_%s" % label
	return placeholder
