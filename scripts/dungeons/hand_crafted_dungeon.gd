## hand_crafted_dungeon.gd - Base script for hand-crafted dungeon scenes
## Attach this to dungeon scenes created by the Dungeon Assembler
extends Node3D

const ZONE_ID := "hand_crafted_dungeon"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

@export var spawn_id: String = "default"
## Dungeon faction determines which enemy types spawn
@export_enum("undead", "goblin", "bandit", "cultist", "beast") var dungeon_faction: String = "undead"
## Zone danger level (1-10) affects enemy scaling
@export_range(1, 10) var zone_danger: int = 3
## Whether to auto-spawn enemies and chests based on room types
@export var auto_spawn_content: bool = true

var _player_spawned: bool = false
var _content_spawned: bool = false
var _hud: CanvasLayer


func _ready() -> void:
	print("[HandCraftedDungeon] _ready() called")
	print("[HandCraftedDungeon] Children: %s" % str(get_children().map(func(c): return c.name)))

	var rooms_node: Node3D = get_node_or_null("Rooms") as Node3D
	if rooms_node:
		print("[HandCraftedDungeon] Rooms node found with %d children" % rooms_node.get_child_count())
		for room: Node in rooms_node.get_children():
			print("[HandCraftedDungeon]   - Room: %s at %s" % [room.name, str((room as Node3D).position) if room is Node3D else "N/A"])
	else:
		print("[HandCraftedDungeon] ERROR: No 'Rooms' node found!")

	# Initialize game state if needed (for standalone testing)
	_initialize_game_state()
	# Ensure dungeon has proper lighting
	_ensure_lighting()
	# Setup HUD for interaction prompts and player UI
	_setup_hud()
	# Setup exit portal in START room
	_setup_exit_portal()
	# Block unused doorways so player can't fall out
	_setup_door_blockers()

	# DEFERRED: Run spawn after scene is fully ready
	# This ensures we override SceneManager's fallback position if needed
	call_deferred("_spawn_player")

	# Spawn enemies and chests in rooms
	if auto_spawn_content:
		call_deferred("_setup_all_room_spawns")


func _spawn_player() -> void:
	# Get target spawn_id from SceneManager (set by ZoneDoor transition) or use local export
	var target_spawn_id: String = spawn_id
	if SceneManager and not SceneManager.spawn_point_id.is_empty():
		target_spawn_id = SceneManager.spawn_point_id
		print("[HandCraftedDungeon] Using SceneManager.spawn_point_id: %s" % target_spawn_id)

	print("[HandCraftedDungeon] _spawn_player() called, target_spawn_id=%s" % target_spawn_id)
	if _player_spawned:
		print("[HandCraftedDungeon] Player already spawned, skipping")
		return

	var spawn_point: Marker3D = _find_spawn_point(target_spawn_id)
	print("[HandCraftedDungeon] _find_spawn_point('%s') returned: %s" % [target_spawn_id, spawn_point])
	if not spawn_point:
		# Try finding any spawn point
		spawn_point = _find_any_spawn_point()
		print("[HandCraftedDungeon] _find_any_spawn_point() returned: %s" % spawn_point)

	if not spawn_point:
		push_error("[HandCraftedDungeon] No spawn point found!")
		print("[HandCraftedDungeon] ERROR: No spawn point found anywhere!")
		return

	var spawn_pos: Vector3 = spawn_point.global_position
	print("[HandCraftedDungeon] Spawning player at %s" % str(spawn_pos))

	# Try to find existing player
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		player.global_position = spawn_pos + Vector3(0, 0.5, 0)
		_player_spawned = true
		print("[HandCraftedDungeon] Player teleported to spawn point")
	else:
		# Player doesn't exist yet - instantiate it
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos + Vector3(0, 0.5, 0)
			_player_spawned = true
			print("[HandCraftedDungeon] Player instantiated at spawn point")


func _find_spawn_point(target_spawn_id: String) -> Marker3D:
	# Search for spawn point with matching spawn_id in all rooms
	var rooms: Node3D = get_node_or_null("Rooms")
	if not rooms:
		return null

	for room: Node in rooms.get_children():
		var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
		if spawn_points:
			for marker: Node in spawn_points.get_children():
				if marker is Marker3D:
					var marker_spawn_id: String = marker.get_meta("spawn_id", "")
					if marker_spawn_id == target_spawn_id:
						return marker

	return null


func _find_any_spawn_point() -> Marker3D:
	# Find the first spawn point in the starter_room or first room
	var rooms: Node3D = get_node_or_null("Rooms")
	if not rooms:
		return null

	# Try start room first - check for rooms named "start_X_Y" (from DungeonBuilder)
	for room: Node in rooms.get_children():
		if room.name.begins_with("start_"):
			var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
			if spawn_points and spawn_points.get_child_count() > 0:
				var first_spawn: Node = spawn_points.get_child(0)
				if first_spawn is Marker3D:
					return first_spawn

	# Fall back to first room with spawn points
	for room: Node in rooms.get_children():
		var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var first_spawn: Node = spawn_points.get_child(0)
			if first_spawn is Marker3D:
				return first_spawn

	return null


## Initialize game state for standalone testing (if not already initialized)
func _initialize_game_state() -> void:
	# Check if already initialized with items
	if GameManager.player_data and GameManager.player_data.character_name != "":
		if InventoryManager.inventory.size() > 0:
			print("[HandCraftedDungeon] Game state already initialized with %d items" % InventoryManager.inventory.size())
			return
		# Character exists but no items - just give items without resetting
		print("[HandCraftedDungeon] Character exists but inventory empty - giving items")
		_give_test_items()
		return

	# Full initialization - no character exists
	print("[HandCraftedDungeon] Initializing game state for standalone testing...")

	# Reset game state
	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()

	# Create test character
	var char_data := CharacterData.new()
	char_data.race = Enums.Race.HUMAN
	char_data.character_name = "Dungeon Tester"
	char_data.initialize_race_bonuses()
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana
	GameManager.player_data = char_data

	_give_test_items()
	print("[HandCraftedDungeon] Test character created with basic gear")


func _give_test_items() -> void:
	var sword_added: bool = InventoryManager.add_item("iron_sword", 1)
	var armor_added: bool = InventoryManager.add_item("leather_armor", 1)
	var potions_added: bool = InventoryManager.add_item("health_potion", 5)
	var torch_added: bool = InventoryManager.add_item("torch", 3)
	InventoryManager.add_gold(500)

	print("[HandCraftedDungeon] Test gear added - sword:%s armor:%s potions:%s torch:%s" % [sword_added, armor_added, potions_added, torch_added])
	print("[HandCraftedDungeon] Inventory count: %d items" % InventoryManager.inventory.size())


## Setup HUD for interaction prompts and player UI
func _setup_hud() -> void:
	# Check if HUD already exists
	var existing_hud := get_tree().get_first_node_in_group("hud")
	if existing_hud:
		print("[HandCraftedDungeon] HUD already exists")
		return

	# Load and add HUD
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)
		print("[HandCraftedDungeon] HUD added to scene")
	else:
		push_warning("[HandCraftedDungeon] Failed to load HUD scene")


func _ensure_lighting() -> void:
	# Check if dungeon already has lighting
	var has_light: bool = false
	for child: Node in get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			has_light = true
			break

	if not has_light:
		_add_default_dungeon_lighting()


func _add_default_dungeon_lighting() -> void:
	# Add directional light for basic visibility
	var light := DirectionalLight3D.new()
	light.name = "DungeonLight"
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 0.8  # Reduced for moodier atmosphere
	light.shadow_enabled = false
	add_child(light)

	# Add ambient lighting via WorldEnvironment with fog
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.015, 0.01)  # Very dark dungeon background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.12, 0.1)  # Dim ambient - moody
	env.ambient_light_energy = 0.6

	# Add volumetric fog for dark atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03  # Light fog density
	env.volumetric_fog_albedo = Color(0.1, 0.08, 0.06)  # Dark brownish fog
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)  # No emission
	env.volumetric_fog_emission_energy = 0.0
	env.volumetric_fog_anisotropy = 0.3  # Slight forward scattering
	env.volumetric_fog_length = 32.0  # Fog render distance
	env.volumetric_fog_detail_spread = 0.5
	env.volumetric_fog_gi_inject = 0.0  # No GI contribution

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	print("[HandCraftedDungeon] Added default dungeon lighting with fog")


## Setup exit portal in the START room for returning to overworld
func _setup_exit_portal() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		return

	# Find the start room
	for room in rooms_node.get_children():
		if not room is Node3D:
			continue

		var room_type: int = room.get_meta("room_type", 0)
		if room_type == DungeonGridData.RoomType.START:
			_place_exit_portal(room)
			break


## Place the exit portal in the start room
func _place_exit_portal(start_room: Node3D) -> void:
	# Room is 16x16, center is at (8, 0, 8)
	# Player spawns at center (8, 0.5, 8)
	# Place exit portal behind player spawn (south wall area, Z ~13)
	# Use LOCAL position since portal is added as child of start_room
	var portal_local_pos: Vector3 = Vector3(8.0, 0.5, 13.0)

	var portal: ZoneDoor = ZoneDoor.spawn_portal(
		start_room,
		portal_local_pos,
		SceneManager.RETURN_TO_WILDERNESS,  # Returns to overworld
		"default",
		"Exit Portal"
	)

	if portal:
		portal.return_to_previous = true  # Return to previous scene (test area)
		# Make portal face north (toward player spawn)
		portal.rotation_degrees.y = 180.0
		print("[HandCraftedDungeon] Exit portal placed at local %s (room: %s)" % [str(portal_local_pos), start_room.name])


## Block unused doorways in rooms based on which neighbors exist
func _setup_door_blockers() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		return

	# Build grid of room positions
	var grid: Dictionary = {}
	for room: Node in rooms_node.get_children():
		if room is Node3D and room.has_meta("grid_pos"):
			var pos: Vector2i = room.get_meta("grid_pos") as Vector2i
			grid[pos] = room.get_meta("room_type", 0)

	# For each room, check if doors need blockers
	for room: Node in rooms_node.get_children():
		if not room is Node3D or not room.has_meta("grid_pos"):
			continue
		var pos: Vector2i = room.get_meta("grid_pos") as Vector2i
		var room_type: int = room.get_meta("room_type", 0) as int
		_add_door_blockers_for_room(room as Node3D, pos, room_type, grid)


func _add_door_blockers_for_room(room: Node3D, pos: Vector2i, room_type: int, grid: Dictionary) -> void:
	var doors: Array = DungeonGridData.get_doors(room_type as DungeonGridData.RoomType)

	for door_dir in doors:
		var offset: Vector2i = DungeonGridData.get_direction_offset(door_dir)
		var neighbor_pos: Vector2i = pos + offset

		var needs_blocker: bool = true
		if grid.has(neighbor_pos):
			var neighbor_type: int = grid[neighbor_pos]
			if neighbor_type != DungeonGridData.RoomType.EMPTY:
				var opposite: DungeonGridData.Direction = DungeonGridData.get_opposite_direction(door_dir)
				if DungeonGridData.has_door(neighbor_type as DungeonGridData.RoomType, opposite):
					needs_blocker = false

		if needs_blocker:
			_create_door_blocker(room, door_dir)


func _create_door_blocker(room: Node3D, dir: DungeonGridData.Direction) -> void:
	var blocker := CSGBox3D.new()
	blocker.size = Vector3(4.0, 4.0, 0.5)
	blocker.use_collision = true

	match dir:
		DungeonGridData.Direction.NORTH:
			blocker.position = Vector3(8, 2, 0.25)
		DungeonGridData.Direction.SOUTH:
			blocker.position = Vector3(8, 2, 15.75)
		DungeonGridData.Direction.EAST:
			blocker.position = Vector3(15.75, 2, 8)
			blocker.size = Vector3(0.5, 4.0, 4.0)
		DungeonGridData.Direction.WEST:
			blocker.position = Vector3(0.25, 2, 8)
			blocker.size = Vector3(0.5, 4.0, 4.0)

	# Use stone wall texture to match dungeon walls
	var mat := StandardMaterial3D.new()
	var wall_texture: Texture2D = load("res://assets/textures/environment/walls/stonewall.png")
	if wall_texture:
		mat.albedo_texture = wall_texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST  # PS1 pixelated look
		mat.uv1_scale = Vector3(2.0, 2.0, 1.0)  # Tile texture appropriately
	else:
		mat.albedo_color = Color(0.2, 0.18, 0.15)  # Fallback color
	blocker.material = mat

	room.add_child(blocker)
	print("[HandCraftedDungeon] Added door blocker at %s direction %d" % [room.name, dir])


## Setup spawns for all rooms based on room type
func _setup_all_room_spawns() -> void:
	if _content_spawned:
		return
	_content_spawned = true

	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		print("[HandCraftedDungeon] No Rooms node found, skipping spawn setup")
		return

	print("[HandCraftedDungeon] Setting up room spawns for %d rooms (faction: %s, danger: %d)" % [
		rooms_node.get_child_count(),
		dungeon_faction,
		zone_danger
	])

	for room in rooms_node.get_children():
		if not room is Node3D:
			continue

		var room_type_int: int = room.get_meta("room_type", 0)
		var room_type: DungeonGridData.RoomType = room_type_int as DungeonGridData.RoomType

		# Skip START room (safe zone)
		if room_type == DungeonGridData.RoomType.START:
			print("[HandCraftedDungeon]   - %s: START room (no spawns)" % room.name)
			continue

		# Skip EMPTY rooms
		if room_type == DungeonGridData.RoomType.EMPTY:
			continue

		# Spawn content based on room type
		DungeonSpawner.spawn_room_content(room, room_type, dungeon_faction, zone_danger)

		var config: Dictionary = DungeonLootConfig.get_room_config(room_type)
		print("[HandCraftedDungeon]   - %s: type=%d, enemies=%d-%d, chests=%d-%d" % [
			room.name,
			room_type,
			config.get("enemy_min", 0),
			config.get("enemy_max", 0),
			config.get("chest_min", 0),
			config.get("chest_max", 0)
		])

	print("[HandCraftedDungeon] Room spawn setup complete")
