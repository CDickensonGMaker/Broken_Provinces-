## cave_interior_test.gd - Simple cave interior for door testing
## Player enters from cave_door_test.tscn and can exit back
extends Node3D

const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

var _hud: CanvasLayer
var _player_spawned: bool = false


func _ready() -> void:
	_initialize_game_state()
	_setup_hud()
	_spawn_player()
	_setup_doors()
	_setup_enemies()
	_setup_chests()
	_setup_cave_environment()


func _spawn_player() -> void:
	var spawn_pos: Vector3 = Vector3(0, 0.5, -6)  # Default spawn near entrance
	var spawn_id: String = "from_exterior"

	# Check if coming from specific spawn
	if SceneManager.spawn_point_id != "":
		spawn_id = SceneManager.spawn_point_id

	# Find matching spawn point
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if spawn_points:
		for marker: Node in spawn_points.get_children():
			if marker is Marker3D:
				var marker_spawn_id: String = marker.get_meta("spawn_id", "")
				if marker_spawn_id == spawn_id:
					spawn_pos = marker.global_position
					break

	# Get or create player
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = spawn_pos
		print("[CaveInterior] Teleported player to %s (spawn_id: %s)" % [str(spawn_pos), spawn_id])
	else:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos
			print("[CaveInterior] Spawned player at %s" % str(spawn_pos))

	_player_spawned = true


func _setup_doors() -> void:
	var door_positions: Node3D = get_node_or_null("DoorPositions")
	if not door_positions:
		return

	for marker: Node in door_positions.get_children():
		if not marker is Marker3D:
			continue

		var target_scene: String = marker.get_meta("target_scene", "")
		var spawn_id: String = marker.get_meta("spawn_id", "default")
		var door_label: String = marker.get_meta("door_label", "Door")
		var show_frame: bool = marker.get_meta("show_frame", false)

		if target_scene.is_empty():
			continue

		var door: ZoneDoor = ZoneDoor.spawn_door(
			self,
			marker.global_position,
			target_scene,
			spawn_id,
			door_label,
			show_frame
		)

		if door:
			door.rotation = marker.rotation
			print("[CaveInterior] Spawned door '%s' -> %s" % [door_label, target_scene])


func _setup_enemies() -> void:
	var enemy_spawns: Node3D = get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		return

	for marker: Node in enemy_spawns.get_children():
		if not marker is Marker3D:
			continue

		var enemy_data_path: String = marker.get_meta("enemy_data", "")
		var sprite_path: String = marker.get_meta("sprite_path", "")
		var h_frames: int = marker.get_meta("h_frames", 4)
		var v_frames: int = marker.get_meta("v_frames", 1)

		if enemy_data_path.is_empty() or sprite_path.is_empty():
			continue

		var sprite_texture: Texture2D = load(sprite_path)
		if not sprite_texture:
			push_warning("[CaveInterior] Failed to load sprite: %s" % sprite_path)
			continue

		var enemy: Node3D = EnemyBase.spawn_billboard_enemy(
			self,
			marker.global_position,
			enemy_data_path,
			sprite_texture,
			h_frames,
			v_frames,
			3  # Zone danger
		)

		if enemy:
			enemy.add_to_group("enemies")
			print("[CaveInterior] Spawned enemy at %s" % str(marker.global_position))


func _setup_chests() -> void:
	var chest_positions: Node3D = get_node_or_null("ChestPositions")
	if not chest_positions:
		return

	for marker: Node in chest_positions.get_children():
		if not marker is Marker3D:
			continue

		var chest_id: String = marker.get_meta("chest_id", "")
		var chest_name: String = marker.get_meta("chest_name", "Chest")
		var is_locked: bool = marker.get_meta("is_locked", false)
		var lock_dc: int = marker.get_meta("lock_difficulty", 10)
		var loot_tier_name: String = marker.get_meta("loot_tier", "common")

		var loot_tier: LootTables.LootTier = LootTables.LootTier.COMMON
		match loot_tier_name.to_lower():
			"junk": loot_tier = LootTables.LootTier.JUNK
			"common": loot_tier = LootTables.LootTier.COMMON
			"uncommon": loot_tier = LootTables.LootTier.UNCOMMON
			"rare": loot_tier = LootTables.LootTier.RARE
			"epic": loot_tier = LootTables.LootTier.EPIC
			"legendary": loot_tier = LootTables.LootTier.LEGENDARY

		var chest: Chest = Chest.spawn_chest(
			self,
			marker.global_position,
			chest_name,
			is_locked,
			lock_dc,
			false,
			chest_id
		)

		if chest:
			chest.setup_with_loot(loot_tier, 0)
			print("[CaveInterior] Spawned chest '%s' at %s" % [chest_name, str(marker.global_position)])


func _setup_cave_environment() -> void:
	# Add dark cave environment
	var world_env: WorldEnvironment = get_node_or_null("Lighting/WorldEnvironment")
	if not world_env:
		world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		$Lighting.add_child(world_env)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.03)  # Very dark

	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.12, 0.1)  # Dim warm ambient
	env.ambient_light_energy = 1.0  # Brighter ambient for visibility

	# Subtle fog for atmosphere
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.1, 0.08, 0.06)
	env.volumetric_fog_emission = Color(0.0, 0.0, 0.0)
	env.volumetric_fog_length = 30.0

	world_env.environment = env
	print("[CaveInterior] Cave environment setup complete")


func _initialize_game_state() -> void:
	if GameManager.player_data and GameManager.player_data.character_name != "":
		return

	print("[CaveInterior] Initializing game state...")
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
