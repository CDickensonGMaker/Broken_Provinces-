## dungeon_loot_config.gd - Dungeon room spawn configuration and loot tables
## Defines enemy counts, chest counts, and loot tiers for each room type
class_name DungeonLootConfig
extends RefCounted


## Room spawn configuration dictionary
## Maps RoomType -> spawn configuration
const DUNGEON_LOOT_CONFIG: Dictionary = {
	# START room - safe zone, no enemies
	DungeonGridData.RoomType.START: {
		"enemy_min": 0, "enemy_max": 0,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},

	# Corridors - occasional wandering enemy, no chests
	DungeonGridData.RoomType.CORRIDOR_NS: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.CORRIDOR_EW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},

	# Hallways (narrow) - occasional wandering enemy, no chests
	DungeonGridData.RoomType.HALLWAY_NS: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.HALLWAY_EW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},

	# Turns - occasional wandering enemy, no chests
	DungeonGridData.RoomType.TURN_NE: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.TURN_NW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.TURN_SE: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.TURN_SW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},

	# T-junctions - small groups, occasional chest
	DungeonGridData.RoomType.T_NORTH: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.T_SOUTH: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.T_EAST: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.T_WEST: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},

	# Cross - 4-way intersection, moderate enemies
	DungeonGridData.RoomType.CROSS: {
		"enemy_min": 2, "enemy_max": 3,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},

	# Dead ends - small encounter with guaranteed chest
	DungeonGridData.RoomType.DEAD_END_N: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.DEAD_END_S: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.DEAD_END_E: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},
	DungeonGridData.RoomType.DEAD_END_W: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},

	# Small room - moderate encounter
	DungeonGridData.RoomType.ROOM_SMALL: {
		"enemy_min": 2, "enemy_max": 3,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},

	# Medium room - larger encounter
	DungeonGridData.RoomType.ROOM_MEDIUM: {
		"enemy_min": 3, "enemy_max": 5,
		"chest_min": 1, "chest_max": 2,
		"loot_tier": LootTables.LootTier.RARE,
		"is_boss": false
	},

	# Large room - significant encounter
	DungeonGridData.RoomType.ROOM_LARGE: {
		"enemy_min": 4, "enemy_max": 6,
		"chest_min": 2, "chest_max": 3,
		"loot_tier": LootTables.LootTier.RARE,
		"is_boss": false
	},

	# Boss room - boss + adds + legendary loot
	DungeonGridData.RoomType.ROOM_BOSS: {
		"enemy_min": 3, "enemy_max": 5,  # 1 boss + 2-4 adds
		"chest_min": 5, "chest_max": 10,
		"loot_tier": LootTables.LootTier.LEGENDARY,
		"is_boss": true
	},

	## Cave room configurations
	# Cave entrance - safe zone, player spawn point
	DungeonGridData.RoomType.CAVE_ENTRANCE: {
		"enemy_min": 0, "enemy_max": 0,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	# Cave exit - treasure room at end of cave
	DungeonGridData.RoomType.CAVE_EXIT: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 2,
		"loot_tier": LootTables.LootTier.RARE,
		"is_boss": false
	},
	# Cave corridors - occasional wandering creatures
	DungeonGridData.RoomType.CAVE_CORRIDOR_NS: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.CAVE_CORRIDOR_EW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	# Cave corners - occasional creatures
	DungeonGridData.RoomType.CAVE_CORNER_NE: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.CAVE_CORNER_NW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.CAVE_CORNER_SE: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	DungeonGridData.RoomType.CAVE_CORNER_SW: {
		"enemy_min": 0, "enemy_max": 1,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.JUNK,
		"is_boss": false
	},
	# Cave T-junction - patrol point, small groups
	DungeonGridData.RoomType.CAVE_T_JUNCTION: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	# Cave crossroads - major intersection, moderate group
	DungeonGridData.RoomType.CAVE_CROSSROADS: {
		"enemy_min": 2, "enemy_max": 3,
		"chest_min": 0, "chest_max": 1,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	},
	# Cave dead end - creature nest with guaranteed loot
	DungeonGridData.RoomType.CAVE_DEAD_END: {
		"enemy_min": 1, "enemy_max": 2,
		"chest_min": 1, "chest_max": 1,
		"loot_tier": LootTables.LootTier.UNCOMMON,
		"is_boss": false
	},
	# Cave chamber - large area, major encounter
	DungeonGridData.RoomType.CAVE_CHAMBER: {
		"enemy_min": 3, "enemy_max": 5,
		"chest_min": 1, "chest_max": 2,
		"loot_tier": LootTables.LootTier.RARE,
		"is_boss": false
	},
}


## Boss chest templates for boss rooms
## Each template defines a type of treasure chest with specific loot
const BOSS_CHEST_TEMPLATES: Array = [
	# Gold chests (always present)
	{
		"name": "Gold Hoard",
		"gold_min": 2000,
		"gold_max": 5000,
		"lock_dc": 0,
		"tier": LootTables.LootTier.LEGENDARY
	},
	{
		"name": "Treasure Pile",
		"gold_min": 1500,
		"gold_max": 3000,
		"lock_dc": 0,
		"tier": LootTables.LootTier.EPIC
	},
	# Equipment chests
	{
		"name": "Weapon Rack",
		"item_pool": "weapon",
		"lock_dc": 15,
		"tier": LootTables.LootTier.EPIC
	},
	{
		"name": "Armor Cache",
		"item_pool": "armor",
		"lock_dc": 15,
		"tier": LootTables.LootTier.EPIC
	},
	# Spell chest
	{
		"name": "Arcane Tome Chest",
		"item_pool": "scroll",
		"lock_dc": 20,
		"tier": LootTables.LootTier.LEGENDARY
	},
	# Mixed legendary
	{
		"name": "Ancient Treasure",
		"item_pool": "mixed",
		"lock_dc": 25,
		"tier": LootTables.LootTier.LEGENDARY
	},
]


## Enemy pools by faction for dungeon spawning
const DUNGEON_ENEMY_POOLS: Dictionary = {
	"undead": [
		"res://data/enemies/skeleton_warrior.tres",
		"res://data/enemies/skeleton_shade.tres",
		"res://data/enemies/drowned_dead.tres",
		"res://data/enemies/flaming_skull.tres",
	],
	"goblin": [
		"res://data/enemies/goblin_soldier.tres",
		"res://data/enemies/goblin_archer.tres",
		"res://data/enemies/goblin_mage.tres",
	],
	"bandit": [
		"res://data/enemies/human_bandit.tres",
		"res://data/enemies/bandit_captain.tres",
	],
	"cultist": [
		"res://data/enemies/cultist.tres",
		"res://data/enemies/cult_leader.tres",
	],
	"beast": [
		"res://data/enemies/giant_rat.tres",
		"res://data/enemies/bat.tres",
		"res://data/enemies/giant_spider.tres",
		"res://data/enemies/wolf.tres",
	],
	"cave": [
		"res://data/enemies/bat.tres",
		"res://data/enemies/giant_spider.tres",
		"res://data/enemies/giant_rat.tres",
	],
}


## Boss enemies by faction
const DUNGEON_BOSS_POOL: Dictionary = {
	"undead": "res://data/enemies/dark_general.tres",
	"goblin": "res://data/enemies/goblin_warboss.tres",
	"bandit": "res://data/enemies/bandit_boss.tres",
	"cultist": "res://data/enemies/cult_leader.tres",
	"beast": "res://data/enemies/troll.tres",
	"cave": "res://data/enemies/giant_spider.tres",
}


## Sprite data for enemies (pulled from zoo_registry patterns)
## Maps enemy_data path to sprite info for spawning
const ENEMY_SPRITE_DATA: Dictionary = {
	"res://data/enemies/skeleton_warrior.tres": {
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_walking.png",
		"h_frames": 8, "v_frames": 1
	},
	"res://data/enemies/skeleton_shade.tres": {
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_shade_walking.png",
		"h_frames": 4, "v_frames": 1
	},
	"res://data/enemies/drowned_dead.tres": {
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_walking.png",
		"h_frames": 8, "v_frames": 1
	},
	"res://data/enemies/flaming_skull.tres": {
		"sprite_path": "res://assets/sprites/enemies/undead/flaming_skull.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/goblin_soldier.tres": {
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_sword.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/goblin_archer.tres": {
		"sprite_path": "res://assets/sprites/goblin_archer_Fixed.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/goblin_mage.tres": {
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_fireball.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/goblin_warboss.tres": {
		"sprite_path": "res://assets/sprites/enemies/goblins/goblin_warboss_walking.png",
		"h_frames": 4, "v_frames": 1
	},
	"res://data/enemies/human_bandit.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/bandit_captain.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/bandit_boss.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/cultist.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/cult_leader.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/giant_rat.tres": {
		"sprite_path": "res://assets/sprites/enemies/beasts/giant_rat.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/bat.tres": {
		"sprite_path": "res://assets/sprites/enemies/beasts/bat_dark.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/giant_spider.tres": {
		"sprite_path": "res://assets/sprites/enemies/beasts/giant_spider.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/wolf.tres": {
		"sprite_path": "res://assets/sprites/enemies/beasts/wolf.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/troll.tres": {
		"sprite_path": "res://assets/sprites/enemies/humanoid/troll.png",
		"h_frames": 1, "v_frames": 1
	},
	"res://data/enemies/dark_general.tres": {
		"sprite_path": "res://assets/sprites/enemies/undead/skeleton_shade_walking.png",
		"h_frames": 4, "v_frames": 1
	},
}


## Quality distribution for boss loot by tier
const BOSS_QUALITY_DISTRIBUTION: Dictionary = {
	LootTables.LootTier.EPIC: {
		Enums.ItemQuality.AVERAGE: 0.20,
		Enums.ItemQuality.ABOVE_AVERAGE: 0.50,
		Enums.ItemQuality.PERFECT: 0.30
	},
	LootTables.LootTier.LEGENDARY: {
		Enums.ItemQuality.ABOVE_AVERAGE: 0.10,
		Enums.ItemQuality.PERFECT: 0.90
	}
}


## Get spawn config for a room type
static func get_room_config(room_type: DungeonGridData.RoomType) -> Dictionary:
	return DUNGEON_LOOT_CONFIG.get(room_type, {
		"enemy_min": 0, "enemy_max": 0,
		"chest_min": 0, "chest_max": 0,
		"loot_tier": LootTables.LootTier.COMMON,
		"is_boss": false
	})


## Get a random enemy from a faction pool
static func get_random_enemy(faction: String) -> String:
	var pool: Array = DUNGEON_ENEMY_POOLS.get(faction, [])
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


## Get boss enemy for a faction
static func get_boss_enemy(faction: String) -> String:
	return DUNGEON_BOSS_POOL.get(faction, "")


## Get sprite data for an enemy data path
static func get_sprite_data(enemy_data_path: String) -> Dictionary:
	return ENEMY_SPRITE_DATA.get(enemy_data_path, {
		"sprite_path": "res://assets/sprites/enemies/humanoid/human_bandit_alt.png",
		"h_frames": 1, "v_frames": 1
	})


## Roll quality for boss loot based on tier
static func roll_boss_quality(tier: LootTables.LootTier) -> Enums.ItemQuality:
	var dist: Dictionary = BOSS_QUALITY_DISTRIBUTION.get(tier, {})
	if dist.is_empty():
		return Enums.ItemQuality.AVERAGE

	var roll: float = randf()
	var cumulative: float = 0.0

	for quality in dist.keys():
		cumulative += dist[quality]
		if roll < cumulative:
			return quality

	return Enums.ItemQuality.PERFECT
