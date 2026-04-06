## cave_test.gd - Test scene for random cave generation
## Press F5 to regenerate cave layout
extends Node3D

const CaveGeneratorScript = preload("res://scripts/dungeons/cave_generator.gd")
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

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
			print("[CaveTest] F5 pressed - regenerating cave...")
			_regenerate_cave()
		elif event.keycode == KEY_F6:
			print("[CaveTest] F6 pressed - regenerating with new seed...")
			_current_seed = -1
			_regenerate_cave()


func _regenerate_cave() -> void:
	# Remove old dungeon
	if _dungeon_root:
		_dungeon_root.queue_free()
		_dungeon_root = null

	# Teleport player back to origin temporarily
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = Vector3(0, 5, 0)

	# Generate new cave after a frame to let old one clean up
	await get_tree().process_frame
	_generate_cave()


func _generate_cave() -> void:
	print("[CaveTest] Generating cave (length=%d, branches=%d)" % [cave_length, cave_branches])

	# Generate cave grid
	var grid: Dictionary = CaveGeneratorScript.generate(cave_length, cave_branches, _current_seed)
	if _current_seed == -1:
		_current_seed = randi()  # Store the seed for potential regeneration

	print("[CaveTest] Generated grid with %d rooms" % grid.size())
	for pos: Vector2i in grid.keys():
		var room_type: int = grid[pos]
		var type_name: String = DungeonGridData.get_room_type_name(room_type)
		print("[CaveTest]   %s: %s" % [str(pos), type_name])

	# Build dungeon from grid
	var result: DungeonBuilder.BuildResult = DungeonBuilder.build(grid, self, false)

	if not result.success:
		push_error("[CaveTest] Failed to build cave!")
		for error: String in result.errors:
			push_error("[CaveTest]   %s" % error)
		return

	_dungeon_root = result.dungeon_root
	print("[CaveTest] Cave built with %d rooms" % result.rooms.size())

	# Ensure lighting
	_ensure_lighting()

	# Setup exit portal in entrance room
	_setup_exit_portal()

	# Spawn player at entrance
	_spawn_player_at_entrance()

	# Spawn enemies and loot
	if auto_spawn_content:
		call_deferred("_setup_room_spawns")


func _spawn_player_at_entrance() -> void:
	# Find the entrance room
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[CaveTest] No Rooms node found!")
		return

	var spawn_pos: Vector3 = Vector3(8, 0.5, 8)  # Default center of first room

	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			# Found entrance, look for spawn point
			var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
			if spawn_points and spawn_points.get_child_count() > 0:
				var marker: Node = spawn_points.get_child(0)
				if marker is Marker3D:
					spawn_pos = marker.global_position
					break
			else:
				# No spawn point marker, use room center
				spawn_pos = room.global_position + Vector3(8, 0.5, 8)
				break

	# Get or create player
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = spawn_pos
		print("[CaveTest] Teleported player to %s" % str(spawn_pos))
	else:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos
			print("[CaveTest] Spawned player at %s" % str(spawn_pos))

	_player_spawned = true


func _setup_exit_portal() -> void:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		return

	# Find the entrance room and place exit portal there (same as dungeons)
	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue
		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			_place_exit_portal(room as Node3D)
			break


func _place_exit_portal(entrance_room: Node3D) -> void:
	# Room is 16x16, player spawns at (8, 0.5, 4) per the scene
	# Place exit portal near north wall (entrance side) so player can leave
	var portal_local_pos: Vector3 = Vector3(8.0, 0.5, 2.0)

	# For test scene: use empty target so we can intercept and handle locally
	var portal: ZoneDoor = ZoneDoor.spawn_portal(
		entrance_room,
		portal_local_pos,
		"",  # Empty target - we'll handle interaction
		"default",
		"Exit Cave (Regenerate)"
	)

	if portal:
		# Portal faces south (toward player spawn area)
		portal.rotation_degrees.y = 0.0
		# Connect to interaction to handle locally (regenerate cave for testing)
		portal.player_interacted.connect(_on_exit_portal_used)
		print("[CaveTest] Exit portal placed at local %s (room: %s)" % [str(portal_local_pos), entrance_room.name])
	else:
		push_error("[CaveTest] Failed to spawn exit portal in room: %s" % entrance_room.name)


func _on_exit_portal_used() -> void:
	print("[CaveTest] Exit portal used - regenerating cave with new seed...")
	_current_seed = -1  # New random seed
	_regenerate_cave()


func _setup_room_spawns() -> void:
	var rooms_node: Node3D = _dungeon_root.get_node_or_null("Rooms")
	if not rooms_node:
		return

	print("[CaveTest] Setting up room spawns (faction: %s, danger: %d)" % [cave_faction, zone_danger])

	for room: Node in rooms_node.get_children():
		if not room is Node3D:
			continue

		var room_type_int: int = room.get_meta("room_type", 0)
		var room_type: DungeonGridData.RoomType = room_type_int as DungeonGridData.RoomType

		# Skip entrance (safe zone)
		if room_type == DungeonGridData.RoomType.CAVE_ENTRANCE:
			continue

		# Spawn content
		DungeonSpawner.spawn_room_content(room, room_type, cave_faction, zone_danger)


func _initialize_game_state() -> void:
	if GameManager.player_data and GameManager.player_data.character_name != "":
		if InventoryManager.inventory.size() > 0:
			return
		_give_test_items()
		return

	print("[CaveTest] Initializing game state...")
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

	_give_test_items()


func _give_test_items() -> void:
	InventoryManager.add_item("iron_sword", 1)
	InventoryManager.add_item("leather_armor", 1)
	InventoryManager.add_item("health_potion", 5)
	InventoryManager.add_item("torch", 5)
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
	# Check if we already have lighting
	for child: Node in get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			return

	_add_cave_lighting()


func _add_cave_lighting() -> void:
	# Dim directional light
	var light := DirectionalLight3D.new()
	light.name = "CaveLight"
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 0.45  # Increased 50%
	light.shadow_enabled = false
	add_child(light)

	# Cave atmosphere
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)  # Very dark
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.1, 0.08)  # Dim warm ambient
	env.ambient_light_energy = 0.75  # Increased 50%

	# Cave fog
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

	print("[CaveTest] Added cave lighting and fog")
