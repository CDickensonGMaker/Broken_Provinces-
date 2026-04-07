## cave_spawner.gd - Cave-specific spawning utilities
## Static utility class for spawning enemies, chests, and props in cave areas
class_name CaveSpawner
extends RefCounted


## Enemy pools by faction for cave spawning
const CAVE_ENEMY_POOLS: Dictionary = {
	"natural": [
		"res://data/enemies/bat.tres",
		"res://data/enemies/giant_spider.tres",
		"res://data/enemies/giant_rat.tres",
	],
	"goblin": [
		"res://data/enemies/goblin_soldier.tres",
		"res://data/enemies/goblin_archer.tres",
	],
	"undead": [
		"res://data/enemies/skeleton_warrior.tres",
		"res://data/enemies/drowned_dead.tres",
	],
	"bandit": [
		"res://data/enemies/human_bandit.tres",
	],
	"beast": [
		"res://data/enemies/wolf.tres",
		"res://data/enemies/giant_rat.tres",
		"res://data/enemies/bat.tres",
	],
}


## Boss/elite enemies by faction for treasure rooms
const CAVE_BOSS_POOL: Dictionary = {
	"natural": "res://data/enemies/giant_spider.tres",
	"goblin": "res://data/enemies/goblin_mage.tres",
	"undead": "res://data/enemies/skeleton_shade.tres",
	"bandit": "res://data/enemies/bandit_captain.tres",
	"beast": "res://data/enemies/wolf.tres",
}


## Prop types that can spawn in caves
const PROP_TYPES: Dictionary = {
	"crate": "res://assets/models/props/crate.glb",
	"barrel": "res://assets/models/props/barrel.glb",
	"bones": "res://assets/models/props/bone_pile.glb",
	"mining_cart": "res://assets/models/props/mining_cart.glb",
	"stalactite": "res://assets/models/props/stalactite.glb",
	"mushroom": "res://assets/models/props/cave_mushroom.glb",
}


## CaveAreaType enum values (mirror of CaveManager.CaveAreaType)
const CAVE_AREA_TYPE_ENTRANCE: int = 0
const CAVE_AREA_TYPE_PASSAGE: int = 1
const CAVE_AREA_TYPE_JUNCTION: int = 2
const CAVE_AREA_TYPE_CHAMBER: int = 3
const CAVE_AREA_TYPE_TREASURE_ROOM: int = 4
const CAVE_AREA_TYPE_EXIT: int = 5


## Cave-appropriate props by area type
const AREA_PROP_POOLS: Dictionary = {
	0: ["crate", "barrel"],  # ENTRANCE
	1: ["bones", "stalactite"],  # PASSAGE
	2: ["bones", "stalactite", "mushroom"],  # JUNCTION
	3: ["bones", "stalactite", "mushroom", "crate", "barrel"],  # CHAMBER
	4: ["crate", "barrel", "bones"],  # TREASURE_ROOM
	5: ["crate", "stalactite"],  # EXIT
}


## Loot tier by area type (use int keys matching CaveAreaType)
const AREA_LOOT_TIERS: Dictionary = {
	0: LootTables.LootTier.JUNK,  # ENTRANCE
	1: LootTables.LootTier.COMMON,  # PASSAGE
	2: LootTables.LootTier.COMMON,  # JUNCTION
	3: LootTables.LootTier.UNCOMMON,  # CHAMBER
	4: LootTables.LootTier.RARE,  # TREASURE_ROOM
	5: LootTables.LootTier.COMMON,  # EXIT
}


## Spawn height for enemies
const SPAWN_HEIGHT: float = 0.1


## Helper to get CaveManager from tree (for static functions)
static func _get_cave_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("CaveManager")
	return null


## Spawn all content for a cave area
## Returns dictionary with "enemies", "chests", "props" arrays
static func spawn_area_content(
	area: RefCounted,
	parent: Node3D,
	faction: String,
	danger: int
) -> Dictionary:
	var result: Dictionary = {
		"enemies": [],
		"chests": [],
		"props": []
	}

	if not area or not parent:
		return result

	var config: Dictionary = area.spawn_config

	# Spawn enemies (respecting global cap)
	var enemy_max: int = config.get("enemy_max", 0)
	var cave_mgr: Node = _get_cave_manager()
	var can_spawn: bool = true
	if cave_mgr and cave_mgr.has_method("can_spawn_enemy"):
		can_spawn = cave_mgr.can_spawn_enemy()
	if enemy_max > 0 and can_spawn:
		var enemies: Array[Node3D] = spawn_enemies(parent, area, enemy_max, faction, danger)
		result.enemies = enemies

	# Spawn chest based on chance
	var chest_chance: float = config.get("chest_chance", 0.0)
	if chest_chance > 0.0 and randf() < chest_chance:
		var tier: LootTables.LootTier = AREA_LOOT_TIERS.get(area.area_type, LootTables.LootTier.COMMON)
		var chest: Node = spawn_chest(parent, area.center + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2)), tier)
		if chest:
			result.chests.append(chest)

	# Spawn props based on density
	var prop_density: float = config.get("prop_density", 0.0)
	if prop_density > 0.0:
		var props: Array = spawn_props(parent, area, prop_density)
		result.props = props

	return result


## Spawn enemies in an area
## Returns array of spawned enemy nodes
static func spawn_enemies(
	parent: Node3D,
	area: RefCounted,
	max_count: int,
	faction: String,
	danger: int
) -> Array[Node3D]:
	var enemies: Array[Node3D] = []

	# Determine actual count (1 to max, capped by global limit)
	var count: int = randi_range(1, max_count)

	# Generate spawn positions spread within the area
	var positions: Array[Vector3] = _generate_area_positions(area, count)

	var cave_mgr: Node = _get_cave_manager()
	for i in range(count):
		# Check global cap
		var can_spawn: bool = true
		if cave_mgr and cave_mgr.has_method("can_spawn_enemy"):
			can_spawn = cave_mgr.can_spawn_enemy()
		if not can_spawn:
			break

		var enemy_data_path: String = _get_random_enemy(faction)
		if enemy_data_path.is_empty():
			continue

		# Load enemy data for sprite info
		var enemy_data: EnemyData = load(enemy_data_path) as EnemyData
		if not enemy_data:
			push_warning("[CaveSpawner] Failed to load enemy data: %s" % enemy_data_path)
			continue

		var sprite_path: String = enemy_data.sprite_path
		if sprite_path.is_empty():
			sprite_path = _get_fallback_sprite(faction)
		if sprite_path.is_empty():
			continue

		var sprite_texture: Texture2D = load(sprite_path) as Texture2D
		if not sprite_texture:
			push_warning("[CaveSpawner] Failed to load sprite: %s" % sprite_path)
			continue

		var h_frames: int = enemy_data.sprite_hframes if enemy_data.sprite_hframes > 0 else 1
		var v_frames: int = enemy_data.sprite_vframes if enemy_data.sprite_vframes > 0 else 1
		var spawn_pos: Vector3 = positions[i] if i < positions.size() else area.center

		var enemy: Node3D = EnemyBase.spawn_billboard_enemy(
			parent,
			spawn_pos,
			enemy_data_path,
			sprite_texture,
			h_frames,
			v_frames,
			danger
		)

		if enemy:
			enemy.add_to_group("enemies")
			enemy.add_to_group("cave_enemies")
			enemies.append(enemy)

			# Register with CaveManager (use safe access)
			if cave_mgr and cave_mgr.has_method("register_enemy"):
				cave_mgr.register_enemy(enemy, area.area_id)

			print("[CaveSpawner] Spawned %s at %s in area %s" % [enemy_data.display_name, spawn_pos, area.area_id])

	return enemies


## Spawn a chest at a position
static func spawn_chest(parent: Node3D, pos: Vector3, tier: LootTables.LootTier) -> Node:
	# Determine if locked based on tier
	var is_locked: bool = tier >= LootTables.LootTier.UNCOMMON and randf() < 0.3
	var lock_dc: int = 10 + (int(tier) * 3)

	var chest: Chest = Chest.spawn_chest(
		parent,
		pos,
		"Cave Chest",
		is_locked,
		lock_dc,
		false,  # Not persistent
		""
	)

	if chest:
		chest.setup_with_loot(tier, 0)
		chest.add_to_group("cave_chests")
		print("[CaveSpawner] Spawned chest at %s with tier %d" % [pos, tier])

	return chest


## Spawn props in an area based on density
static func spawn_props(parent: Node3D, area: RefCounted, density: float) -> Array[Node3D]:
	var props: Array[Node3D] = []

	# Get prop pool for this area type
	var prop_pool: Array = AREA_PROP_POOLS.get(area.area_type, ["stalactite"])
	if prop_pool.is_empty():
		return props

	# Calculate prop count based on density and area size
	var base_count: int = int(area.radius * density)
	var prop_count: int = randi_range(maxi(1, base_count - 2), base_count + 2)

	# Generate positions within the area
	var positions: Array[Vector3] = _generate_area_positions(area, prop_count)

	for i in range(prop_count):
		var prop_type: String = prop_pool[randi() % prop_pool.size()]
		var prop_path: String = PROP_TYPES.get(prop_type, "")

		if prop_path.is_empty() or not ResourceLoader.exists(prop_path):
			continue

		var pos: Vector3 = positions[i] if i < positions.size() else area.center

		var prop: Node3D = _spawn_prop(parent, pos, prop_path, prop_type)
		if prop:
			props.append(prop)

	return props


## Spawn a single prop at a position
static func _spawn_prop(parent: Node3D, pos: Vector3, model_path: String, prop_type: String) -> Node3D:
	# Try to load the model
	var scene: PackedScene = load(model_path) as PackedScene
	if not scene:
		# Create a simple placeholder
		return _create_placeholder_prop(parent, pos, prop_type)

	var prop: Node3D = scene.instantiate() as Node3D
	if not prop:
		return null

	prop.position = pos
	prop.add_to_group("cave_props")

	# Random rotation for variety
	prop.rotation.y = randf_range(0, TAU)

	# Random scale variation
	var scale_var: float = randf_range(0.8, 1.2)
	prop.scale = Vector3(scale_var, scale_var, scale_var)

	parent.add_child(prop)
	return prop


## Create a placeholder prop if model doesn't exist
static func _create_placeholder_prop(parent: Node3D, pos: Vector3, prop_type: String) -> Node3D:
	var prop := Node3D.new()
	prop.name = "Prop_" + prop_type

	var mesh_instance := MeshInstance3D.new()

	# Different shapes for different prop types
	match prop_type:
		"crate", "barrel":
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.5, 0.5)
			mesh_instance.mesh = box
		"bones":
			var capsule := CapsuleMesh.new()
			capsule.radius = 0.1
			capsule.height = 0.4
			mesh_instance.mesh = capsule
		"stalactite":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.05
			cone.bottom_radius = 0.2
			cone.height = 0.8
			mesh_instance.mesh = cone
		"mushroom":
			var sphere := SphereMesh.new()
			sphere.radius = 0.15
			mesh_instance.mesh = sphere
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.3, 0.3, 0.3)
			mesh_instance.mesh = box

	# Create a simple material
	var material := StandardMaterial3D.new()
	match prop_type:
		"crate", "barrel":
			material.albedo_color = Color(0.4, 0.3, 0.2)
		"bones":
			material.albedo_color = Color(0.9, 0.85, 0.8)
		"stalactite":
			material.albedo_color = Color(0.5, 0.5, 0.55)
		"mushroom":
			material.albedo_color = Color(0.6, 0.4, 0.3)
		_:
			material.albedo_color = Color(0.5, 0.5, 0.5)

	mesh_instance.material_override = material
	prop.add_child(mesh_instance)

	prop.position = pos
	prop.rotation.y = randf_range(0, TAU)
	prop.add_to_group("cave_props")

	parent.add_child(prop)
	return prop


## Spawn enemies at specific marker positions
static func spawn_enemies_at_markers(parent: Node3D, faction: String, danger: int) -> Array[Node3D]:
	var enemies: Array[Node3D] = []

	# Find all EnemySpawn markers in the scene
	var markers: Array = _find_spawn_markers(parent, "EnemySpawn_")

	var cave_mgr: Node = _get_cave_manager()
	for marker in markers:
		var can_spawn: bool = true
		if cave_mgr and cave_mgr.has_method("can_spawn_enemy"):
			can_spawn = cave_mgr.can_spawn_enemy()
		if not can_spawn:
			break

		if not marker is Node3D:
			continue

		var marker_node: Node3D = marker as Node3D

		# Get enemy data from marker metadata
		var enemy_data_path: String = marker_node.get_meta("enemy_data", "")
		if enemy_data_path.is_empty():
			enemy_data_path = _get_random_enemy(faction)

		if enemy_data_path.is_empty():
			continue

		var enemy_data: EnemyData = load(enemy_data_path) as EnemyData
		if not enemy_data:
			continue

		# Get sprite info
		var sprite_path: String = marker_node.get_meta("sprite_path", enemy_data.sprite_path)
		if sprite_path.is_empty():
			sprite_path = _get_fallback_sprite(faction)
		if sprite_path.is_empty():
			continue

		var sprite_texture: Texture2D = load(sprite_path) as Texture2D
		if not sprite_texture:
			continue

		var h_frames: int = marker_node.get_meta("h_frames", enemy_data.sprite_hframes)
		var v_frames: int = marker_node.get_meta("v_frames", enemy_data.sprite_vframes)
		if h_frames <= 0:
			h_frames = 1
		if v_frames <= 0:
			v_frames = 1

		var enemy: Node3D = EnemyBase.spawn_billboard_enemy(
			parent,
			marker_node.global_position,
			enemy_data_path,
			sprite_texture,
			h_frames,
			v_frames,
			danger
		)

		if enemy:
			enemy.add_to_group("enemies")
			enemy.add_to_group("cave_enemies")
			enemies.append(enemy)

			# Try to find area this marker belongs to
			var area_id: String = _find_area_for_position(marker_node.global_position)
			if not area_id.is_empty() and cave_mgr and cave_mgr.has_method("register_enemy"):
				cave_mgr.register_enemy(enemy, area_id)

	return enemies


## Spawn chests at specific marker positions
static func spawn_chests_at_markers(parent: Node3D) -> Array[Node]:
	var chests: Array[Node] = []

	var markers: Array = _find_spawn_markers(parent, "ChestPos_")

	for marker in markers:
		if not marker is Node3D:
			continue

		var marker_node: Node3D = marker as Node3D

		# Get chest config from metadata
		var tier_str: String = marker_node.get_meta("loot_tier", "common")
		var tier: LootTables.LootTier = _string_to_loot_tier(tier_str)
		var is_locked: bool = marker_node.get_meta("is_locked", false)
		var lock_dc: int = marker_node.get_meta("lock_difficulty", 10)
		var chest_name: String = marker_node.get_meta("chest_name", "Cave Chest")

		var chest: Chest = Chest.spawn_chest(
			parent,
			marker_node.global_position,
			chest_name,
			is_locked,
			lock_dc,
			false,
			""
		)

		if chest:
			chest.setup_with_loot(tier, 0)
			chest.add_to_group("cave_chests")
			chests.append(chest)

	return chests


## Generate positions spread within an area
static func _generate_area_positions(area: RefCounted, count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	for i in range(count):
		# Generate random position within area radius
		var angle: float = randf_range(0, TAU)
		var dist: float = randf_range(0, area.radius * 0.8)  # Keep slightly inside radius

		var pos: Vector3 = Vector3(
			area.center.x + cos(angle) * dist,
			SPAWN_HEIGHT,
			area.center.z + sin(angle) * dist
		)
		positions.append(pos)

	return positions


## Get a random enemy from a faction pool
static func _get_random_enemy(faction: String) -> String:
	var pool: Array = CAVE_ENEMY_POOLS.get(faction, CAVE_ENEMY_POOLS.get("natural", []))
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


## Get a boss/elite enemy for a faction
static func _get_boss_enemy(faction: String) -> String:
	return CAVE_BOSS_POOL.get(faction, CAVE_BOSS_POOL.get("natural", ""))


## Get fallback sprite path for a faction
static func _get_fallback_sprite(faction: String) -> String:
	match faction:
		"natural", "beast":
			return "res://assets/sprites/enemies/beasts/giant_rat.png"
		"goblin":
			return "res://assets/sprites/enemies/goblins/goblin_sword.png"
		"undead":
			return "res://assets/sprites/enemies/undead/skeleton_walking.png"
		_:
			return "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"


## Find spawn markers recursively
static func _find_spawn_markers(node: Node, prefix: String) -> Array[Node]:
	var markers: Array[Node] = []

	if node.name.begins_with(prefix):
		markers.append(node)

	for child in node.get_children():
		markers.append_array(_find_spawn_markers(child, prefix))

	return markers


## Find which area contains a position
static func _find_area_for_position(pos: Vector3) -> String:
	var cave_mgr: Node = _get_cave_manager()
	if not cave_mgr or not "area_data" in cave_mgr:
		return ""

	var area_data: Dictionary = cave_mgr.area_data
	for area_id: String in area_data:
		var area: RefCounted = area_data[area_id]
		if area and area.has_method("contains_point") and area.contains_point(pos):
			return area_id
	return ""


## Convert string to loot tier
static func _string_to_loot_tier(tier_str: String) -> LootTables.LootTier:
	match tier_str.to_lower():
		"junk": return LootTables.LootTier.JUNK
		"common": return LootTables.LootTier.COMMON
		"uncommon": return LootTables.LootTier.UNCOMMON
		"rare": return LootTables.LootTier.RARE
		"epic": return LootTables.LootTier.EPIC
		"legendary": return LootTables.LootTier.LEGENDARY
	return LootTables.LootTier.COMMON
