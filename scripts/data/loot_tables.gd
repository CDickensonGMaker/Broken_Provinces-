## loot_tables.gd - Centralized loot pool definitions and generation
## NOTE: This script is an autoload - access via LootTables singleton, not class_name
extends Node

## Rarity tiers for loot pools
enum LootTier {
	JUNK,      # Common trash, low value
	COMMON,    # Basic gear and supplies
	UNCOMMON,  # Better quality items
	RARE,      # Good finds
	EPIC,      # Exceptional items
	LEGENDARY  # Best items in the game
}

## Loot pools by category - only includes items that exist in the data folders
var weapon_pools: Dictionary = {
	LootTier.COMMON: ["dagger"],
	LootTier.UNCOMMON: ["longsword", "hunting_bow"],
	LootTier.RARE: ["battleaxe", "crossbow"],
	LootTier.EPIC: ["musket"],
	LootTier.LEGENDARY: ["flamebrand"]
}

var armor_pools: Dictionary = {
	LootTier.COMMON: ["leather_armor"],
	LootTier.UNCOMMON: ["chainmail", "wooden_shield"],
	LootTier.RARE: ["ring_of_protection", "ring_of_strength"],
	LootTier.EPIC: ["amulet_of_vitality", "amulet_of_wisdom"],
}

## Basic weapon pool - village blacksmith items only (no exotic/rare weapons)
var basic_weapon_pools: Dictionary = {
	LootTier.COMMON: ["dagger"],
	LootTier.UNCOMMON: ["longsword", "hunting_bow"],
}

## Basic armor pool - village blacksmith items only (no exotic/rare armor)
var basic_armor_pools: Dictionary = {
	LootTier.COMMON: ["leather_armor"],
	LootTier.UNCOMMON: ["chainmail", "wooden_shield"],
}

## Jewelry pool (rings and amulets) - for magic shops
var jewelry_pools: Dictionary = {
	LootTier.COMMON: ["iron_ring", "copper_amulet"],
	LootTier.UNCOMMON: ["silver_ring", "silver_amulet", "bone_ring", "wolf_fang_necklace"],
	LootTier.RARE: ["gold_ring", "gold_amulet", "ring_of_protection", "ring_of_strength", "serpent_ring", "spider_silk_pendant"],
	LootTier.EPIC: ["amulet_of_vitality", "amulet_of_wisdom", "flame_heart_ring", "frost_crystal_pendant", "signet_ring", "scholars_medallion"],
}

## Magic consumables pool (mana potions, etc.)
var magic_consumable_pools: Dictionary = {
	LootTier.UNCOMMON: ["mana_potion"],
}

var consumable_pools: Dictionary = {
	LootTier.COMMON: ["health_potion", "bread", "cheese", "ale"],
	LootTier.UNCOMMON: ["stamina_potion", "cooked_meat"],
	LootTier.RARE: ["antidote"],
}

## Food and cooking ingredients pool - sold by innkeepers
var food_pools: Dictionary = {
	LootTier.JUNK: ["water"],
	LootTier.COMMON: ["raw_meat", "bread", "cheese", "flour", "potato", "carrot"],
	LootTier.UNCOMMON: ["ale", "cooked_meat"],
}

var material_pools: Dictionary = {
	LootTier.JUNK: ["stone_block", "coal"],
	LootTier.COMMON: ["iron_ore", "leather", "wood_plank", "empty_vial"],
	LootTier.UNCOMMON: ["iron_ingot", "leather_strip", "red_herb", "silver_ore", "healing_herb"],
	LootTier.RARE: ["steel_ingot", "silver_ingot", "gem_amethyst", "gem_ruby"],
	LootTier.EPIC: ["gold_ore", "gold_ingot", "gem_emerald", "gem_sapphire"],
	LootTier.LEGENDARY: ["gem_diamond"],
}

var ammo_pools: Dictionary = {
	LootTier.COMMON: ["arrows", "bolts", "lead_balls"],
}

var scroll_pools: Dictionary = {
	LootTier.UNCOMMON: ["scroll_healing_light", "scroll_armor"],
	LootTier.RARE: ["scroll_magic_missile", "scroll_blind"],
	LootTier.EPIC: ["scroll_lightning_bolt", "scroll_soul_drain", "scroll_dispel_magic", "scroll_fireball", "scroll_haste", "scroll_slow", "scroll_ice_storm", "scroll_fire_gate"],
	LootTier.LEGENDARY: ["scroll_cone_of_cold", "scroll_iron_guard", "scroll_chain_lightning"],
}

## Book pools - bestiary volumes and lore books found in dungeons/loot
var book_pools: Dictionary = {
	LootTier.COMMON: ["bestiary_vol_1_vermin", "bestiary_vol_2_predators"],
	LootTier.UNCOMMON: ["bestiary_vol_3_arachnids", "bestiary_vol_4_goblins", "bestiary_vol_5_bandits", "lore_factions", "lore_gods"],
	LootTier.RARE: ["bestiary_vol_6_undead", "bestiary_vol_7_cultists", "lore_enemies", "lore_dwarves"],
	LootTier.EPIC: ["bestiary_vol_8_monsters", "bestiary_vol_9_tengers", "lore_elves", "lore_underworld"],
	LootTier.LEGENDARY: ["bestiary_vol_10_legendary"],
}

var tool_pools: Dictionary = {
	LootTier.COMMON: ["lockpick"],
}

## Soulstone pool - empty soulstones for soul capture enchanting
## Soulstones drop from magical enemies (undead, mages, demons) based on tier
var soulstone_pools: Dictionary = {
	LootTier.UNCOMMON: ["soulstone_petty_empty"],
	LootTier.RARE: ["soulstone_lesser_empty"],
	LootTier.EPIC: ["soulstone_common_empty"],
	LootTier.LEGENDARY: ["soulstone_greater_empty"],
}

## Shop type definitions - what pools each shop type draws from
const SHOP_TYPE_POOLS: Dictionary = {
	"general": ["consumable", "material", "ammo", "tool"],
	"blacksmith": ["weapon", "armor", "material"],
	"basic_blacksmith": ["basic_weapon", "basic_armor", "material"],  # Village smith - no exotic items
	"alchemist": ["consumable", "scroll"],
	"weapon": ["weapon", "ammo"],
	"armor": ["armor"],
	"magic": ["scroll", "magic_consumable", "jewelry", "soulstone"],  # scrolls, mana potions, rings/amulets, soulstones
	"innkeeper": ["food", "consumable"],  # food ingredients, drinks, basic consumables
}

## Number of items to generate per shop tier
const SHOP_ITEM_COUNTS: Dictionary = {
	LootTier.JUNK: 4,
	LootTier.COMMON: 6,
	LootTier.UNCOMMON: 8,
	LootTier.RARE: 10,
	LootTier.EPIC: 12,
	LootTier.LEGENDARY: 15,
}

## Enemy difficulty to loot tier mapping
const DIFFICULTY_TO_TIER: Dictionary = {
	1: LootTier.JUNK,
	2: LootTier.COMMON,
	3: LootTier.COMMON,
	4: LootTier.UNCOMMON,
	5: LootTier.UNCOMMON,
	6: LootTier.RARE,
	7: LootTier.RARE,
	8: LootTier.EPIC,
	9: LootTier.EPIC,
	10: LootTier.LEGENDARY,
}

## Chance for enemy to drop loot at all (by tier)
const DROP_CHANCE_BY_TIER: Dictionary = {
	LootTier.JUNK: 0.3,
	LootTier.COMMON: 0.4,
	LootTier.UNCOMMON: 0.5,
	LootTier.RARE: 0.6,
	LootTier.EPIC: 0.75,
	LootTier.LEGENDARY: 0.9,
}

## Price markup for shops (buy price multiplier)
const SHOP_BUY_MARKUP: float = 1.5
## Price markdown for selling to shops
const SHOP_SELL_MARKDOWN: float = 0.4

func _ready() -> void:
	pass


# ============================================================================
# CORE LOOT RETRIEVAL FUNCTIONS
# ============================================================================

## Get random item from a specific tier in a pool
## Returns empty string if tier not found or pool empty
func get_random_from_tier(pool: Dictionary, tier: LootTier) -> String:
	if pool.has(tier) and pool[tier].size() > 0:
		return pool[tier][randi() % pool[tier].size()]
	return ""


## Get random item from tier or below (with fallback to lower tiers)
## Useful when you want to guarantee an item even if higher tiers are empty
func get_random_up_to_tier(pool: Dictionary, max_tier: LootTier) -> String:
	var available: Array[String] = []
	for tier in range(max_tier + 1):
		if pool.has(tier):
			available.append_array(pool[tier])
	if available.size() > 0:
		return available[randi() % available.size()]
	return ""


## Get all items from a pool up to and including a tier
func get_all_up_to_tier(pool: Dictionary, max_tier: LootTier) -> Array[String]:
	var result: Array[String] = []
	for tier in range(max_tier + 1):
		if pool.has(tier):
			for item_id in pool[tier]:
				if item_id not in result:
					result.append(item_id)
	return result


## Get the pool dictionary for a category name
func get_pool_by_name(pool_name: String) -> Dictionary:
	match pool_name:
		"weapon": return weapon_pools
		"armor": return armor_pools
		"basic_weapon": return basic_weapon_pools
		"basic_armor": return basic_armor_pools
		"jewelry": return jewelry_pools
		"consumable": return consumable_pools
		"magic_consumable": return magic_consumable_pools
		"material": return material_pools
		"ammo": return ammo_pools
		"scroll": return scroll_pools
		"tool": return tool_pools
		"food": return food_pools
		"soulstone": return soulstone_pools
		"book": return book_pools
	return {}


# ============================================================================
# LOOT TIER ROLLING
# ============================================================================

## Roll for a loot tier with luck modifier
## base_tier: The expected tier for this drop
## luck_modifier: Positive values increase chance of higher tier, negative decreases
## Returns the actual tier to use
func roll_loot_tier(base_tier: LootTier, luck_modifier: int = 0) -> LootTier:
	# Base chance to upgrade tier: 15% per tier above base
	# Luck modifier adds/subtracts 5% per point
	var upgrade_chance: float = 0.15 + (luck_modifier * 0.05)
	upgrade_chance = clampf(upgrade_chance, 0.0, 0.5)  # Cap at 50%

	var result_tier: int = base_tier

	# Try to upgrade (can upgrade multiple times with good luck)
	while result_tier < LootTier.LEGENDARY and randf() < upgrade_chance:
		result_tier += 1
		upgrade_chance *= 0.5  # Diminishing returns for each tier up

	# Chance to downgrade if luck is negative
	if luck_modifier < 0:
		var downgrade_chance: float = abs(luck_modifier) * 0.1
		while result_tier > LootTier.JUNK and randf() < downgrade_chance:
			result_tier -= 1
			downgrade_chance *= 0.5

	return result_tier as LootTier


## Roll item quality based on tier (higher tier = better quality chance)
func roll_quality_for_tier(tier: LootTier) -> Enums.ItemQuality:
	var roll := randf()

	match tier:
		LootTier.JUNK:
			# Junk: 60% poor, 30% below average, 10% average
			if roll < 0.60:
				return Enums.ItemQuality.POOR
			elif roll < 0.90:
				return Enums.ItemQuality.BELOW_AVERAGE
			else:
				return Enums.ItemQuality.AVERAGE

		LootTier.COMMON:
			# Common: 20% poor, 50% below average, 25% average, 5% above average
			if roll < 0.20:
				return Enums.ItemQuality.POOR
			elif roll < 0.70:
				return Enums.ItemQuality.BELOW_AVERAGE
			elif roll < 0.95:
				return Enums.ItemQuality.AVERAGE
			else:
				return Enums.ItemQuality.ABOVE_AVERAGE

		LootTier.UNCOMMON:
			# Uncommon: 10% poor, 30% below average, 40% average, 18% above average, 2% perfect
			if roll < 0.10:
				return Enums.ItemQuality.POOR
			elif roll < 0.40:
				return Enums.ItemQuality.BELOW_AVERAGE
			elif roll < 0.80:
				return Enums.ItemQuality.AVERAGE
			elif roll < 0.98:
				return Enums.ItemQuality.ABOVE_AVERAGE
			else:
				return Enums.ItemQuality.PERFECT

		LootTier.RARE:
			# Rare: 5% below average, 35% average, 45% above average, 15% perfect
			if roll < 0.05:
				return Enums.ItemQuality.BELOW_AVERAGE
			elif roll < 0.40:
				return Enums.ItemQuality.AVERAGE
			elif roll < 0.85:
				return Enums.ItemQuality.ABOVE_AVERAGE
			else:
				return Enums.ItemQuality.PERFECT

		LootTier.EPIC:
			# Epic: 20% average, 50% above average, 30% perfect
			if roll < 0.20:
				return Enums.ItemQuality.AVERAGE
			elif roll < 0.70:
				return Enums.ItemQuality.ABOVE_AVERAGE
			else:
				return Enums.ItemQuality.PERFECT

		LootTier.LEGENDARY:
			# Legendary: 10% above average, 90% perfect
			if roll < 0.10:
				return Enums.ItemQuality.ABOVE_AVERAGE
			else:
				return Enums.ItemQuality.PERFECT

	return Enums.ItemQuality.AVERAGE


# ============================================================================
# SHOP INVENTORY GENERATION
# ============================================================================

## Generate shop inventory based on shop tier and type
## Returns array of {item_id, item_type, price, quantity, quality}
func generate_shop_inventory(shop_tier: LootTier, shop_type: String = "general") -> Array[Dictionary]:
	var inventory: Array[Dictionary] = []

	# Get pools for this shop type
	var pool_names: Array = SHOP_TYPE_POOLS.get(shop_type, ["consumable"])

	# Determine how many items to generate
	var item_count: int = SHOP_ITEM_COUNTS.get(shop_tier, 6)

	# Build a combined available items list
	var available_items: Array[Dictionary] = []
	for pool_name in pool_names:
		var pool: Dictionary = get_pool_by_name(pool_name)
		var items: Array[String] = get_all_up_to_tier(pool, shop_tier)

		# Check which items actually exist in the databases
		for item_id in items:
			var exists_in_db := _item_exists_in_database(item_id)
			if exists_in_db:
				available_items.append({
					"item_id": item_id,
					"pool_name": pool_name
				})

	if available_items.is_empty():
		return inventory

	# Shuffle for randomization
	available_items.shuffle()

	# Pick items for the shop
	var items_added: Array[String] = []
	var attempts := 0
	var max_attempts := item_count * 3  # Prevent infinite loop

	while inventory.size() < item_count and attempts < max_attempts:
		attempts += 1

		# Pick a random item from available
		var pick: Dictionary = available_items[randi() % available_items.size()]
		var item_id: String = pick.get("item_id", "")
		if item_id.is_empty():
			continue

		# Avoid too many duplicates (allow some for consumables)
		var already_count := items_added.count(item_id)
		if already_count >= 2:
			continue

		# Determine quality based on shop tier
		var quality: Enums.ItemQuality = roll_quality_for_tier(shop_tier)

		# Get base price
		var base_price: int = get_base_price(item_id)

		# Apply quality multiplier and shop markup
		var quality_mult: float = _get_quality_price_multiplier(quality)
		var final_price: int = int(base_price * quality_mult * SHOP_BUY_MARKUP)

		# Determine quantity (consumables get more, equipment is 1)
		var quantity: int = 1
		var item_type: String = _get_item_type(item_id)
		if item_type in ["consumable", "material", "ammo"]:
			quantity = randi_range(1, 5 + shop_tier)

		inventory.append({
			"item_id": item_id,
			"item_type": item_type,
			"price": final_price,
			"quantity": quantity,
			"quality": quality
		})
		items_added.append(item_id)

	return inventory


## Get the sell price for an item (what player gets when selling)
func get_sell_price(item_id: String, quality: Enums.ItemQuality = Enums.ItemQuality.AVERAGE) -> int:
	var base_price: int = get_base_price(item_id)
	var quality_mult: float = _get_quality_price_multiplier(quality)
	return int(base_price * quality_mult * SHOP_SELL_MARKDOWN)


# ============================================================================
# ENEMY LOOT GENERATION
# ============================================================================

## Generate enemy loot drop based on enemy difficulty
## difficulty: 1-10 scale
## Returns array of {item_id, quantity, quality}
func generate_enemy_loot(difficulty: int) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []

	# Clamp difficulty
	difficulty = clampi(difficulty, 1, 10)

	# Get base tier for this difficulty
	var base_tier: LootTier = DIFFICULTY_TO_TIER.get(difficulty, LootTier.COMMON)

	# Check if enemy drops anything at all
	var drop_chance: float = DROP_CHANCE_BY_TIER.get(base_tier, 0.4)
	if randf() > drop_chance:
		return loot  # No drop

	# Roll for actual tier (might upgrade)
	var actual_tier: LootTier = roll_loot_tier(base_tier, 0)

	# Determine number of drops (1-3 based on difficulty)
	var num_drops: int = 1
	if difficulty >= 5:
		num_drops = randi_range(1, 2)
	if difficulty >= 8:
		num_drops = randi_range(1, 3)

	# Generate drops
	for i in range(num_drops):
		var drop: Dictionary = _generate_single_drop(actual_tier)
		if not drop.is_empty():
			loot.append(drop)

	# Chance for bonus gold drop
	if randf() < 0.5:
		var gold_amount: int = randi_range(5, 10 + difficulty * 5) * (actual_tier + 1)
		loot.append({
			"item_id": "_gold",
			"quantity": gold_amount,
			"quality": Enums.ItemQuality.AVERAGE
		})

	return loot


## Generate a single loot drop
func _generate_single_drop(tier: LootTier) -> Dictionary:
	# Weighted pool selection
	# Consumables most common, then materials, then equipment
	# Books and soulstones have small chances at higher tiers
	var roll := randf()
	var pool: Dictionary
	var pool_name: String

	if roll < 0.40:
		pool = consumable_pools
		pool_name = "consumable"
	elif roll < 0.60:
		pool = material_pools
		pool_name = "material"
	elif roll < 0.73:
		pool = ammo_pools
		pool_name = "ammo"
	elif roll < 0.83:
		pool = armor_pools
		pool_name = "armor"
	elif roll < 0.92:
		pool = weapon_pools
		pool_name = "weapon"
	elif roll < 0.97:
		# 5% chance for book drop
		pool = book_pools
		pool_name = "book"
	elif tier >= LootTier.UNCOMMON:
		# 3% chance for soulstone drop at UNCOMMON+ tier
		pool = soulstone_pools
		pool_name = "soulstone"
	else:
		pool = weapon_pools
		pool_name = "weapon"

	# Get item from pool
	var item_id: String = get_random_up_to_tier(pool, tier)
	if item_id.is_empty():
		# Fallback to consumables
		item_id = get_random_up_to_tier(consumable_pools, tier)

	if item_id.is_empty():
		return {}

	# Determine quality
	var quality: Enums.ItemQuality = roll_quality_for_tier(tier)

	# Determine quantity
	var quantity: int = 1
	if pool_name in ["consumable", "material", "ammo"]:
		quantity = randi_range(1, 3)

	return {
		"item_id": item_id,
		"quantity": quantity,
		"quality": quality
	}


## Generate loot for a chest/container based on tier
func generate_chest_loot(chest_tier: LootTier, luck_modifier: int = 0) -> Array[Dictionary]:
	var loot: Array[Dictionary] = []

	# Chests always drop something
	var actual_tier: LootTier = roll_loot_tier(chest_tier, luck_modifier)

	# Chests have 2-4 items
	var num_items: int = randi_range(2, 4)

	for i in range(num_items):
		var drop: Dictionary = _generate_single_drop(actual_tier)
		if not drop.is_empty():
			loot.append(drop)

	# Chests always have gold
	var gold_amount: int = randi_range(20, 50) * (actual_tier + 1)
	loot.append({
		"item_id": "_gold",
		"quantity": gold_amount,
		"quality": Enums.ItemQuality.AVERAGE
	})

	return loot


# ============================================================================
# PRICE LOOKUP
# ============================================================================

## Get base price for an item (looks up in InventoryManager databases)
func get_base_price(item_id: String) -> int:
	# Check weapon database
	if InventoryManager.weapon_database.has(item_id):
		return (InventoryManager.weapon_database[item_id] as WeaponData).base_value

	# Check armor database
	if InventoryManager.armor_database.has(item_id):
		return (InventoryManager.armor_database[item_id] as ArmorData).base_value

	# Check item database
	if InventoryManager.item_database.has(item_id):
		return (InventoryManager.item_database[item_id] as ItemData).base_value

	# Default fallback
	return 10


## Get item type category string
func _get_item_type(item_id: String) -> String:
	if InventoryManager.weapon_database.has(item_id):
		return "weapon"
	if InventoryManager.armor_database.has(item_id):
		return "armor"
	if InventoryManager.item_database.has(item_id):
		var item: ItemData = InventoryManager.item_database[item_id]
		match item.item_type:
			ItemData.ItemType.CONSUMABLE:
				return "consumable"
			ItemData.ItemType.MATERIAL:
				return "material"
			ItemData.ItemType.AMMUNITION:
				return "ammo"
			ItemData.ItemType.SCROLL:
				return "scroll"
			_:
				return "misc"
	return "misc"


## Get price multiplier for quality
func _get_quality_price_multiplier(quality: Enums.ItemQuality) -> float:
	match quality:
		Enums.ItemQuality.POOR:
			return 0.25
		Enums.ItemQuality.BELOW_AVERAGE:
			return 0.5
		Enums.ItemQuality.AVERAGE:
			return 1.0
		Enums.ItemQuality.ABOVE_AVERAGE:
			return 2.0
		Enums.ItemQuality.PERFECT:
			return 4.0
	return 1.0


# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Get tier name as string (for debugging/UI)
func get_tier_name(tier: LootTier) -> String:
	match tier:
		LootTier.JUNK: return "Junk"
		LootTier.COMMON: return "Common"
		LootTier.UNCOMMON: return "Uncommon"
		LootTier.RARE: return "Rare"
		LootTier.EPIC: return "Epic"
		LootTier.LEGENDARY: return "Legendary"
	return "Unknown"


## Get tier color for UI display
func get_tier_color(tier: LootTier) -> Color:
	match tier:
		LootTier.JUNK: return Color(0.5, 0.5, 0.5)      # Gray
		LootTier.COMMON: return Color(1.0, 1.0, 1.0)    # White
		LootTier.UNCOMMON: return Color(0.0, 0.8, 0.0)  # Green
		LootTier.RARE: return Color(0.0, 0.5, 1.0)      # Blue
		LootTier.EPIC: return Color(0.6, 0.0, 0.8)      # Purple
		LootTier.LEGENDARY: return Color(1.0, 0.6, 0.0) # Orange
	return Color.WHITE


## Check if an item exists in any pool
func item_exists_in_pools(item_id: String) -> bool:
	for pool in [weapon_pools, armor_pools, jewelry_pools, consumable_pools, magic_consumable_pools, material_pools, ammo_pools, scroll_pools, tool_pools, book_pools]:
		for tier in pool.keys():
			if item_id in pool[tier]:
				return true
	return false


## Get the tier of an item (returns -1 if not found)
func get_item_tier(item_id: String) -> int:
	for pool in [weapon_pools, armor_pools, jewelry_pools, consumable_pools, magic_consumable_pools, material_pools, ammo_pools, scroll_pools, tool_pools, book_pools]:
		for tier in pool.keys():
			if item_id in pool[tier]:
				return tier
	return -1


## Add an item to a pool (for runtime modifications like mods)
func add_item_to_pool(pool_name: String, tier: LootTier, item_id: String) -> bool:
	var pool: Dictionary = get_pool_by_name(pool_name)
	if pool.is_empty():
		return false

	if not pool.has(tier):
		pool[tier] = []

	if item_id not in pool[tier]:
		pool[tier].append(item_id)
		return true

	return false


## Check if an item exists in any of the InventoryManager databases
func _item_exists_in_database(item_id: String) -> bool:
	if InventoryManager.weapon_database.has(item_id):
		return true
	if InventoryManager.armor_database.has(item_id):
		return true
	if InventoryManager.item_database.has(item_id):
		return true
	return false


# ============================================================================
# ENEMY FACTION SOULSTONE DROPS
# ============================================================================

## Factions that can drop soulstones (magical creatures)
const SOULSTONE_DROP_FACTIONS: Array[int] = [
	Enums.Faction.UNDEAD,    # Undead always have trapped souls
	Enums.Faction.DEMON,     # Demons carry soul energy
	Enums.Faction.CULTIST,   # Mages/cultists use soulstones in rituals
]

## Base drop chance for soulstones by faction
const SOULSTONE_BASE_CHANCE: Dictionary = {
	Enums.Faction.UNDEAD: 0.15,   # 15% base chance - common for undead
	Enums.Faction.DEMON: 0.20,    # 20% base chance - demons are rich in soul energy
	Enums.Faction.CULTIST: 0.10,  # 10% base chance - mages sometimes carry them
}

## Check if a faction can drop soulstones
func faction_drops_soulstones(faction: Enums.Faction) -> bool:
	return int(faction) in SOULSTONE_DROP_FACTIONS


## Generate soulstone drop for an enemy based on faction and difficulty tier
## Returns Dictionary with {item_id: String, quantity: int} or empty if no drop
func roll_soulstone_drop(faction: Enums.Faction, tier: LootTier) -> Dictionary:
	# Check if this faction drops soulstones
	if not faction_drops_soulstones(faction):
		return {}

	# Get base drop chance for faction
	var base_chance: float = SOULSTONE_BASE_CHANCE.get(int(faction), 0.0)
	if base_chance <= 0.0:
		return {}

	# Tier increases drop chance: +5% per tier above COMMON
	var tier_bonus: float = maxf(0.0, (int(tier) - int(LootTier.COMMON))) * 0.05
	var final_chance: float = base_chance + tier_bonus

	# Roll for drop
	if randf() >= final_chance:
		return {}

	# Determine soulstone type based on tier
	# Higher tier enemies drop better soulstones
	var soulstone_id: String = ""
	match tier:
		LootTier.JUNK, LootTier.COMMON:
			# Low tier: small chance for petty soulstone
			if randf() < 0.3:
				soulstone_id = "soulstone_petty_empty"
		LootTier.UNCOMMON:
			soulstone_id = "soulstone_petty_empty"
		LootTier.RARE:
			soulstone_id = "soulstone_lesser_empty"
		LootTier.EPIC:
			soulstone_id = "soulstone_common_empty"
		LootTier.LEGENDARY:
			soulstone_id = "soulstone_greater_empty"

	if soulstone_id.is_empty():
		return {}

	# Verify item exists in database
	if not _item_exists_in_database(soulstone_id):
		return {}

	return {
		"item_id": soulstone_id,
		"quantity": 1
	}
