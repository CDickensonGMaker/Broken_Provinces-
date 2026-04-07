## cave_instance_test.gd - Procedural cave generated when entering from cave_door_test
## Generates a random cave layout and has an exit back to the exterior
extends Node3D

const CaveGeneratorScript = preload("res://scripts/dungeons/cave_generator.gd")
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const EXTERIOR_SCENE := "res://scenes/dev/cave_door_test.tscn"

@export_range(4, 16) var cave_length: int = 8
@export_range(0, 6) var cave_branches: int = 2
@export_enum("cave", "beast") var cave_faction: String = "cave"
@export_range(1, 10) var zone_danger: int = 3
@export var auto_spawn_content: bool = true

var _dungeon_root: Node3D = null
var _player_spawned: bool = false
var _hud: CanvasLayer
var _current_seed: int = -1


func _ready() -> void:
	_initialize_game_state()
	_setup_hud()
	_generate_cave()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			print("[CaveInstance] F5 pressed - regenerating cave...")
			_regenerate_cave()
		elif event.keycode == KEY_F6:
			print("[CaveInstance] F6 pressed - regenerating with new seed...")
			_current_seed = -1
			_regenerate_cave()


func _regenerate_cave() -> void:
	if _dungeon_root:
		_dungeon_root.queue_free()
		_dungeon_root = null

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = Vector3(0, 5, 0)

	await get_tree().process_frame
	_generate_cave()


func _generate_cave() -> void:
	print("[CaveInstance] Generating cave (length=%d, branches=%d)" % [cave_length, cave_branches])

	var grid: Dictionary = CaveGeneratorScript.generate(cave_length, cave_branches, _current_seed)
	if _current_seed == -1:
		_current_seed = randi()

	print("[CaveInstance] Generated grid with %d rooms" % grid.size())
	for pos: Vector2i in grid.keys():
		var room_type: int = grid[pos]
		var type_name: String = DungeonGridData.get_room_type_name(room_type)
		print("[CaveInstance]   %s: %s" % [str(pos), type_name])

	var result: DungeonBuilder.BuildResult = DungeonBuilder.build(grid, self, false)

	if not result.success:
		push_error("[CaveInstance] Failed to build cave!")
		for error: String in result.errors:
			push_error("[CaveInstance]   %s" % error)
		return

	_dungeon_root = result.dungeon_root
	print("[CaveInstance] Cave built with %d rooms" % result.rooms.size())

	_ensure_lighting()
	_setup_exit_door()
	_spawn_player_at_entrance()

	if auto_spawn_content:
		call_deferred("_setup_room_spawns")


func _spawn_player_at_entrance() -> void:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[CaveInstance] No Rooms node found!")
		return

	var spawn_pos: Vector3 = Vector3(8, 0.5, 8)
	var spawn_id: String = SceneManager.spawn_point_id
	var found_spawn: bool = false

	# Try to find spawn point in CAVE_ENTRANCE room first
	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			var spawn_points_node: Node3D = room.get_node_or_null("SpawnPoints")
			if spawn_points_node and spawn_points_node.get_child_count() > 0:
				var marker: Node = spawn_points_node.get_child(0)
				if marker is Marker3D:
					# Add marker to spawn_points group so SceneManager can find it
					marker.add_to_group("spawn_points")
					marker.set_meta("spawn_id", "default")
					spawn_pos = marker.global_position
					found_spawn = true
					print("[CaveInstance] Found spawn in CAVE_ENTRANCE room, added to spawn_points group")
					break
			else:
				spawn_pos = room.global_position + Vector3(8, 0.5, 8)
				found_spawn = true
				print("[CaveInstance] Using CAVE_ENTRANCE room center as spawn")
				break

	# Fallback: find any spawn point if entrance wasn't found
	if not found_spawn:
		var fallback_marker: Marker3D = _find_any_spawn_point()
		if fallback_marker:
			# Add fallback marker to spawn_points group so SceneManager can find it
			fallback_marker.add_to_group("spawn_points")
			fallback_marker.set_meta("spawn_id", "default")
			spawn_pos = fallback_marker.global_position
			found_spawn = true
			print("[CaveInstance] Using fallback spawn point from another room, added to spawn_points group")
		else:
			# Last resort: use first room's center
			if rooms_node.get_child_count() > 0:
				var first_room: Node3D = rooms_node.get_child(0) as Node3D
				if first_room:
					spawn_pos = first_room.global_position + Vector3(8, 0.5, 8)
					print("[CaveInstance] WARNING: Using first room center as last-resort spawn")

	# Always add Y offset to ensure player spawns above floor collision
	var final_spawn_pos: Vector3 = spawn_pos + Vector3(0, 0.5, 0)

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = final_spawn_pos
		print("[CaveInstance] Teleported player to %s (spawn_id: %s)" % [str(final_spawn_pos), spawn_id])
	else:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = final_spawn_pos
			print("[CaveInstance] Spawned player at %s" % str(final_spawn_pos))

	_player_spawned = true


## Find any spawn point from any room as a fallback
func _find_any_spawn_point() -> Marker3D:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		return null

	# Try entrance room first (prioritize it even in fallback)
	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			var sp: Node3D = room.get_node_or_null("SpawnPoints")
			if sp and sp.get_child_count() > 0:
				var marker: Node = sp.get_child(0)
				if marker is Marker3D:
					return marker

	# Fallback: any room with SpawnPoints
	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var sp: Node3D = room.get_node_or_null("SpawnPoints")
		if sp and sp.get_child_count() > 0:
			var marker: Node = sp.get_child(0)
			if marker is Marker3D:
				return marker

	return null


func _setup_exit_door() -> void:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		return

	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			_place_exit_door(room as Node3D)
			break


func _place_exit_door(entrance_room: Node3D) -> void:
	# Place exit door near entrance
	var door_local_pos: Vector3 = Vector3(8.0, 0.5, 2.0)

	var door: ZoneDoor = ZoneDoor.spawn_door(
		entrance_room,
		door_local_pos,
		EXTERIOR_SCENE,
		"from_cave",  # Spawn point ID in exterior scene
		"Exit Cave",
		false  # No door frame (cave mouth)
	)

	if door:
		door.rotation_degrees.y = 0.0
		print("[CaveInstance] Exit door placed -> %s" % EXTERIOR_SCENE)
	else:
		push_error("[CaveInstance] Failed to spawn exit door")


func _setup_room_spawns() -> void:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		return

	print("[CaveInstance] Setting up room spawns (faction: %s, danger: %d)" % [cave_faction, zone_danger])

	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue

		var room_type_int: int = room.get_meta("room_type", 0)
		var room_type: DungeonGridData.RoomType = room_type_int as DungeonGridData.RoomType

		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			continue

		DungeonSpawner.spawn_room_content(room, room_type, cave_faction, zone_danger)


func _initialize_game_state() -> void:
	if GameManager.player_data and GameManager.player_data.character_name != "":
		return

	print("[CaveInstance] Initializing game state...")
	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()

	var char_data := CharacterData.new()
	char_data.race = Enums.Race.HUMAN
	char_data.character_name = "Cave Explorer"
	char_data.initialize_race_bonuses()
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana
	GameManager.player_data = char_data

	InventoryManager.add_item("iron_sword", 1)
	InventoryManager.add_item("leather_armor", 1)
	InventoryManager.add_item("health_potion", 5)
	InventoryManager.add_item("torch", 10)
	InventoryManager.add_gold(500)


func _setup_hud() -> void:
	var existing_hud := get_tree().get_first_node_in_group("hud")
	if existing_hud:
		return

	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)


func _ensure_lighting() -> void:
	for child: Node in get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			return
	_add_cave_lighting()


func _add_cave_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.name = "CaveLight"
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 0.585
	light.shadow_enabled = false
	add_child(light)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.1, 0.08)
	env.ambient_light_energy = 0.975

	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.08, 0.06, 0.05)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.2
	env.volumetric_fog_length = 40.0

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	print("[CaveInstance] Added cave lighting and fog")
