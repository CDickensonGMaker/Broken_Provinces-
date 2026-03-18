## dungeon_spawner.gd - Helper utilities for spawning enemies and chests in dungeons
## Used by HandCraftedDungeon to populate rooms based on room type
class_name DungeonSpawner
extends RefCounted


## Room size in world units (matches DungeonGridData.ROOM_SIZE)
const ROOM_SIZE: float = 16.0

## Spawn area bounds (relative to room center)
## Leaves margin near walls for player movement
const SPAWN_MARGIN: float = 3.0
const SPAWN_AREA_MIN: float = SPAWN_MARGIN
const SPAWN_AREA_MAX: float = ROOM_SIZE - SPAWN_MARGIN

## Vertical spawn height for enemies (slightly above floor for CharacterBody3D)
const SPAWN_HEIGHT: float = 0.1
## Chest spawn height (on the floor)
const CHEST_SPAWN_HEIGHT: float = 0.0


## Spawn all content for a room based on its type
## room: The room Node3D (position is world position)
## room_type: The DungeonGridData.RoomType enum value
## faction: The enemy faction to use (e.g., "undead", "goblin", "bandit")
## zone_danger: Danger level (1-10) for enemy scaling
static func spawn_room_content(room: Node3D, room_type: DungeonGridData.RoomType, faction: String = "undead", zone_danger: int = 3) -> void:
	var config: Dictionary = DungeonLootConfig.get_room_config(room_type)
	if config.is_empty():
		return

	# Spawn enemies
	var enemy_count: int = randi_range(config.enemy_min, config.enemy_max)
	if config.is_boss:
		_spawn_boss_room_enemies(room, faction, zone_danger)
	elif enemy_count > 0:
		_spawn_regular_enemies(room, enemy_count, faction, zone_danger)

	# Spawn chests
	var chest_count: int = randi_range(config.chest_min, config.chest_max)
	if config.is_boss:
		_spawn_boss_room_chests(room, chest_count)
	elif chest_count > 0:
		_spawn_regular_chests(room, chest_count, config.loot_tier)


## Spawn regular enemies in a room
static func _spawn_regular_enemies(room: Node3D, count: int, faction: String, zone_danger: int) -> void:
	print("[DungeonSpawner] _spawn_regular_enemies: room=%s, count=%d, faction=%s" % [room.name, count, faction])
	var spawn_positions: Array[Vector3] = _generate_spread_positions(room, count)

	for i in range(count):
		var enemy_data_path: String = DungeonLootConfig.get_random_enemy(faction)
		if enemy_data_path.is_empty():
			continue

		# Load EnemyData to get sprite info directly from resource
		var enemy_data: EnemyData = load(enemy_data_path) as EnemyData
		if not enemy_data:
			push_warning("[DungeonSpawner] Failed to load enemy data: %s" % enemy_data_path)
			continue

		# Get sprite path from EnemyData, fallback to hardcoded config
		var sprite_path: String = enemy_data.sprite_path
		if sprite_path.is_empty():
			var sprite_data: Dictionary = DungeonLootConfig.get_sprite_data(enemy_data_path)
			sprite_path = sprite_data.get("sprite_path", "")
		if sprite_path.is_empty():
			push_warning("[DungeonSpawner] No sprite path for enemy: %s" % enemy_data_path)
			continue

		var sprite_texture: Texture2D = load(sprite_path) as Texture2D
		if not sprite_texture:
			push_warning("[DungeonSpawner] Failed to load sprite: %s" % sprite_path)
			continue

		# Get h_frames/v_frames from EnemyData, fallback to 4x1
		var h_frames: int = enemy_data.sprite_hframes if enemy_data.sprite_hframes > 0 else 4
		var v_frames: int = enemy_data.sprite_vframes if enemy_data.sprite_vframes > 0 else 1

		var spawn_pos: Vector3 = spawn_positions[i] if i < spawn_positions.size() else _get_random_spawn_position(room)

		print("[DungeonSpawner]   Spawning %s at %s with sprite %s (%dx%d)" % [enemy_data.display_name, spawn_pos, sprite_path, h_frames, v_frames])

		var enemy: Node3D = EnemyBase.spawn_billboard_enemy(
			room,
			spawn_pos,
			enemy_data_path,
			sprite_texture,
			h_frames,
			v_frames,
			zone_danger
		)

		if enemy:
			enemy.add_to_group("enemies")
			enemy.add_to_group("dungeon_enemies")
			print("[DungeonSpawner]   -> Enemy spawned successfully: %s" % enemy.name)
		else:
			print("[DungeonSpawner]   -> ERROR: Enemy spawn returned null!")


## Spawn boss room enemies (1 boss + adds)
static func _spawn_boss_room_enemies(room: Node3D, faction: String, zone_danger: int) -> void:
	# Spawn boss at center
	var boss_data_path: String = DungeonLootConfig.get_boss_enemy(faction)
	if boss_data_path.is_empty():
		boss_data_path = DungeonLootConfig.get_random_enemy(faction)

	if not boss_data_path.is_empty():
		# Load EnemyData to get sprite info directly from resource
		var boss_data: EnemyData = load(boss_data_path) as EnemyData
		if not boss_data:
			push_warning("[DungeonSpawner] Failed to load boss data: %s" % boss_data_path)
		else:
			# Get sprite path from EnemyData, fallback to hardcoded config
			var sprite_path: String = boss_data.sprite_path
			if sprite_path.is_empty():
				var sprite_data: Dictionary = DungeonLootConfig.get_sprite_data(boss_data_path)
				sprite_path = sprite_data.get("sprite_path", "")

			if sprite_path.is_empty():
				push_warning("[DungeonSpawner] No sprite path for boss: %s" % boss_data_path)
			else:
				var sprite_texture: Texture2D = load(sprite_path) as Texture2D
				if sprite_texture:
					# Get h_frames/v_frames from EnemyData, fallback to 4x1
					var h_frames: int = boss_data.sprite_hframes if boss_data.sprite_hframes > 0 else 4
					var v_frames: int = boss_data.sprite_vframes if boss_data.sprite_vframes > 0 else 1

					# LOCAL position - center of room
					var boss_pos: Vector3 = Vector3(ROOM_SIZE / 2.0, SPAWN_HEIGHT, ROOM_SIZE / 2.0)

					var boss: Node3D = EnemyBase.spawn_billboard_enemy(
						room,
						boss_pos,
						boss_data_path,
						sprite_texture,
						h_frames,
						v_frames,
						zone_danger + 2  # Boss is tougher
					)

					if boss:
						boss.add_to_group("enemies")
						boss.add_to_group("dungeon_enemies")
						boss.add_to_group("boss_enemy")
				else:
					push_warning("[DungeonSpawner] Failed to load boss sprite: %s" % sprite_path)

	# Spawn 2-4 adds around the boss
	var add_count: int = randi_range(2, 4)
	_spawn_regular_enemies(room, add_count, faction, zone_danger)


## Spawn regular chests in a room
static func _spawn_regular_chests(room: Node3D, count: int, loot_tier: LootTables.LootTier) -> void:
	var positions: Array[Vector3] = _generate_corner_positions(room, count)

	for i in range(count):
		var pos: Vector3 = positions[i] if i < positions.size() else _get_corner_spawn_position(room)

		# Determine if chest should be locked
		var is_locked: bool = randf() < 0.3  # 30% chance
		var lock_dc: int = 10 + (int(loot_tier) * 2)  # Higher tier = harder lock

		var chest: Chest = Chest.spawn_chest(
			room,
			pos,
			"Dungeon Chest",
			is_locked,
			lock_dc,
			false,  # Not persistent
			""  # No ID needed
		)

		if chest:
			chest.setup_with_loot(loot_tier, 0)
			chest.add_to_group("dungeon_chests")


## Spawn boss room chests with special templates
static func _spawn_boss_room_chests(room: Node3D, count: int) -> void:
	var positions: Array[Vector3] = _generate_boss_chest_positions(room, count)
	var templates: Array[Dictionary] = []
	for t: Dictionary in DungeonLootConfig.BOSS_CHEST_TEMPLATES:
		templates.append(t)
	templates.shuffle()

	for i in range(count):
		var pos: Vector3 = positions[i] if i < positions.size() else _get_corner_spawn_position(room)
		var template: Dictionary = templates[i % templates.size()]

		var chest: Chest = Chest.spawn_chest(
			room,
			pos,
			template.get("name", "Boss Chest"),
			template.get("lock_dc", 0) > 0,
			template.get("lock_dc", 0),
			false,
			""
		)

		if not chest:
			continue

		chest.add_to_group("dungeon_chests")
		chest.add_to_group("boss_chests")

		# Fill chest based on template type
		if template.has("gold_min"):
			# Gold chest
			var gold_amount: int = randi_range(template.gold_min, template.gold_max)
			chest.add_item("_gold", gold_amount, Enums.ItemQuality.AVERAGE)
			# Also add some items
			chest.setup_with_loot(template.get("tier", LootTables.LootTier.LEGENDARY), 2)
		elif template.has("item_pool"):
			# Item pool chest
			var tier: LootTables.LootTier = template.get("tier", LootTables.LootTier.EPIC)
			_fill_chest_from_pool(chest, template.item_pool, tier)
		else:
			# Default legendary loot
			chest.setup_with_loot(LootTables.LootTier.LEGENDARY, 2)


## Fill a chest from a specific item pool
static func _fill_chest_from_pool(chest: Chest, pool_name: String, tier: LootTables.LootTier) -> void:
	var pool: Dictionary = LootTables.get_pool_by_name(pool_name)
	if pool.is_empty():
		# Fallback to mixed loot
		chest.setup_with_loot(tier, 2)
		return

	# Add 2-4 items from the pool
	var item_count: int = randi_range(2, 4)
	for i in range(item_count):
		var item_id: String = LootTables.get_random_up_to_tier(pool, tier)
		if not item_id.is_empty():
			var quality: Enums.ItemQuality = DungeonLootConfig.roll_boss_quality(tier)
			chest.add_item(item_id, 1, quality)

	# Add some gold
	var gold_amount: int = randi_range(200, 500) * (int(tier) + 1)
	chest.add_item("_gold", gold_amount, Enums.ItemQuality.AVERAGE)


## Generate spread positions for enemies within a room
## NOTE: Returns LOCAL positions relative to the room node, NOT global positions
## This is important because spawn_billboard_enemy sets enemy.position (local) before add_child
static func _generate_spread_positions(room: Node3D, count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	# Use local coordinates (relative to room origin at 0,0,0)
	# The room's transform will handle the global positioning

	# Use a simple grid pattern with jitter
	var grid_size: int = ceili(sqrt(count))
	var cell_size: float = (SPAWN_AREA_MAX - SPAWN_AREA_MIN) / maxf(float(grid_size), 1.0)

	for i in range(count):
		var grid_x: int = i % grid_size
		var grid_y: int = i / grid_size

		var base_x: float = SPAWN_AREA_MIN + (grid_x + 0.5) * cell_size
		var base_z: float = SPAWN_AREA_MIN + (grid_y + 0.5) * cell_size

		# Add jitter
		var jitter_x: float = randf_range(-cell_size * 0.3, cell_size * 0.3)
		var jitter_z: float = randf_range(-cell_size * 0.3, cell_size * 0.3)

		# LOCAL position within the room (room origin is at local 0,0,0)
		var pos: Vector3 = Vector3(
			clampf(base_x + jitter_x, SPAWN_AREA_MIN, SPAWN_AREA_MAX),
			SPAWN_HEIGHT,
			clampf(base_z + jitter_z, SPAWN_AREA_MIN, SPAWN_AREA_MAX)
		)
		positions.append(pos)

	return positions


## Generate corner positions for chests
## NOTE: Returns LOCAL positions relative to the room node
static func _generate_corner_positions(room: Node3D, count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Corner positions (near walls) - LOCAL coordinates - for chests
	var corners: Array[Vector3] = [
		Vector3(SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, SPAWN_MARGIN),
		Vector3(ROOM_SIZE - SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, SPAWN_MARGIN),
		Vector3(SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, ROOM_SIZE - SPAWN_MARGIN),
		Vector3(ROOM_SIZE - SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, ROOM_SIZE - SPAWN_MARGIN),
	]

	corners.shuffle()

	for i in range(mini(count, corners.size())):
		positions.append(corners[i])  # Already local, no need to add room_origin

	return positions


## Generate positions for boss room chests (spread around perimeter)
## NOTE: Returns LOCAL positions relative to the room node
static func _generate_boss_chest_positions(room: Node3D, count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Distribute around perimeter - LOCAL coordinates - for chests
	for i in range(count):
		var angle: float = (float(i) / float(count)) * TAU
		var radius: float = (ROOM_SIZE / 2.0) - SPAWN_MARGIN

		var pos: Vector3 = Vector3(
			(ROOM_SIZE / 2.0) + cos(angle) * radius,
			CHEST_SPAWN_HEIGHT,
			(ROOM_SIZE / 2.0) + sin(angle) * radius
		)
		positions.append(pos)

	return positions


## Get a random spawn position within the room
## NOTE: Returns LOCAL position relative to the room node
static func _get_random_spawn_position(room: Node3D) -> Vector3:
	return Vector3(
		randf_range(SPAWN_AREA_MIN, SPAWN_AREA_MAX),
		SPAWN_HEIGHT,
		randf_range(SPAWN_AREA_MIN, SPAWN_AREA_MAX)
	)


## Get a random corner spawn position (for chests)
## NOTE: Returns LOCAL position relative to the room node
static func _get_corner_spawn_position(room: Node3D) -> Vector3:
	var corners: Array[Vector3] = [
		Vector3(SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, SPAWN_MARGIN),
		Vector3(ROOM_SIZE - SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, SPAWN_MARGIN),
		Vector3(SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, ROOM_SIZE - SPAWN_MARGIN),
		Vector3(ROOM_SIZE - SPAWN_MARGIN, CHEST_SPAWN_HEIGHT, ROOM_SIZE - SPAWN_MARGIN),
	]
	return corners[randi() % corners.size()]
