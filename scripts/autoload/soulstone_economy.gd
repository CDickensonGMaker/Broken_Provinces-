## soulstone_economy.gd - Global soulstone tracker and economy system
## Manages the 100 soulstones that exist in the world
## NOTE: This is an autoload singleton - do NOT add class_name as it conflicts with the autoload name
extends Node

const TOTAL_SOULSTONES: int = 100

signal soulstone_claimed(soulstone_id: String, owner_type: int, owner_id: String)
signal soulstone_released(soulstone_id: String)
signal soulstone_created(soulstone_id: String, tier: int)
signal quest_target_set(soulstone_id: String, quest_id: String)
signal quest_target_cleared(soulstone_id: String)

## Owner types for soulstone tracking
enum OwnerType {
	UNCLAIMED = 0,
	PLAYER = 1,
	NPC = 2,
	WORLD = 3,
	SHOP = 4,
	QUEST_REWARD = 5,
	DUNGEON = 6
}

## Soulstone tier values (matches SoulstoneData)
enum SoulstoneTier {
	PETTY = 1,
	LESSER = 2,
	COMMON = 3,
	GREATER = 4,
	GRAND = 5
}

## Registry: soulstone_id -> {tier: int, owner_type: OwnerType, owner_id: String, is_quest_target: bool, quest_id: String}
var soulstone_registry: Dictionary = {}

## Quest targets: quest_id -> soulstone_id
var quest_targets: Dictionary = {}

## Distribution tracking: category -> count
var distribution_counts: Dictionary = {
	"quest_rewards": 0,
	"dungeon_loot": 0,
	"npc_possession": 0,
	"shop_inventory": 0,
	"world_spawns": 0
}

## Initial distribution plan (how many of each category)
const DISTRIBUTION_PLAN: Dictionary = {
	"quest_rewards": 25,
	"dungeon_loot": 30,
	"npc_possession": 20,
	"shop_inventory": 15,
	"world_spawns": 10
}

## Daily penalty ID for quest soulstone debt
const SOULSTONE_DEBT_PENALTY_ID: String = "soulstone_quest_debt"

## Faction ID for soulstone debt (Church of Three - souls are spiritual matters)
const SOULSTONE_DEBT_FACTION: String = "church_of_three"

## Daily reputation loss for holding quest-targeted soulstones
const SOULSTONE_DEBT_DAILY_PENALTY: int = -3

func _ready() -> void:
	_initialize_world_soulstones()

	# Connect to day change for debt tracking
	if GameManager:
		GameManager.day_changed.connect(_on_day_changed)


## Initialize the world's 100 soulstones with predefined distribution
func _initialize_world_soulstones() -> void:
	# Only initialize if registry is empty (not loaded from save)
	if not soulstone_registry.is_empty():
		return

	var soulstone_index: int = 0

	# Generate soulstones for each category
	soulstone_index = _generate_category_soulstones("quest_rewards", DISTRIBUTION_PLAN["quest_rewards"], soulstone_index)
	soulstone_index = _generate_category_soulstones("dungeon_loot", DISTRIBUTION_PLAN["dungeon_loot"], soulstone_index)
	soulstone_index = _generate_category_soulstones("npc_possession", DISTRIBUTION_PLAN["npc_possession"], soulstone_index)
	soulstone_index = _generate_category_soulstones("shop_inventory", DISTRIBUTION_PLAN["shop_inventory"], soulstone_index)
	soulstone_index = _generate_category_soulstones("world_spawns", DISTRIBUTION_PLAN["world_spawns"], soulstone_index)


## Generate soulstones for a specific category
func _generate_category_soulstones(category: String, count: int, start_index: int) -> int:
	var owner_type: OwnerType = _category_to_owner_type(category)

	for i in range(count):
		var soulstone_id: String = "soulstone_%03d" % (start_index + i)
		var tier: int = _generate_tier_for_index(start_index + i)

		soulstone_registry[soulstone_id] = {
			"tier": tier,
			"owner_type": owner_type,
			"owner_id": _get_spawn_location_for_category(category, start_index + i),
			"is_quest_target": false,
			"quest_id": "",
			"category": category
		}

		distribution_counts[category] += 1

	return start_index + count


## Convert category name to owner type
func _category_to_owner_type(category: String) -> OwnerType:
	match category:
		"quest_rewards":
			return OwnerType.QUEST_REWARD
		"dungeon_loot":
			return OwnerType.DUNGEON
		"npc_possession":
			return OwnerType.NPC
		"shop_inventory":
			return OwnerType.SHOP
		"world_spawns":
			return OwnerType.WORLD
		_:
			return OwnerType.UNCLAIMED


## Generate tier based on index (distribution curve)
## Lower indices = more common lower tiers
func _generate_tier_for_index(index: int) -> int:
	# Distribution: 40% Petty, 25% Lesser, 20% Common, 10% Greater, 5% Grand
	if index < 40:
		return SoulstoneTier.PETTY
	elif index < 65:
		return SoulstoneTier.LESSER
	elif index < 85:
		return SoulstoneTier.COMMON
	elif index < 95:
		return SoulstoneTier.GREATER
	else:
		return SoulstoneTier.GRAND


## Get spawn location ID for a category and index
## These IDs should match location_ids in WorldGrid, NPC IDs, dungeon IDs, etc.
func _get_spawn_location_for_category(category: String, index: int) -> String:
	match category:
		"quest_rewards":
			return _get_quest_reward_location(index)
		"dungeon_loot":
			return _get_dungeon_location(index)
		"npc_possession":
			return _get_npc_location(index)
		"shop_inventory":
			return _get_shop_location(index)
		"world_spawns":
			return _get_world_location(index)
		_:
			return ""


## Get specific quest reward locations
func _get_quest_reward_location(index: int) -> String:
	# Maps to quest IDs that reward soulstones
	var quest_ids: Array[String] = [
		"mages_guild_initiation",
		"recover_lost_soulstone_01",
		"recover_lost_soulstone_02",
		"recover_lost_soulstone_03",
		"dungeon_clear_willow_dale",
		"dungeon_clear_kazer_dun_01",
		"dungeon_clear_kazer_dun_02",
		"dungeon_clear_kazer_dun_03",
		"dungeon_clear_kazer_dun_04",
		"dungeon_clear_kazer_dun_05",
		"merchant_favor_dalhurst",
		"merchant_favor_thornfield",
		"merchant_favor_millbrook",
		"priest_blessing_01",
		"priest_blessing_02",
		"bandit_leader_loot",
		"goblin_chief_loot",
		"undead_boss_01",
		"undead_boss_02",
		"dragon_cult_01",
		"dragon_cult_02",
		"dragon_cult_03",
		"sea_monster_hunt",
		"elven_city_quest",
		"main_quest_finale"
	]
	var local_index: int = index % quest_ids.size()
	return quest_ids[local_index]


## Get specific dungeon loot locations
func _get_dungeon_location(index: int) -> String:
	var dungeon_ids: Array[String] = [
		"willow_dale_01", "willow_dale_02", "willow_dale_03",
		"bandit_hideout_01", "bandit_hideout_02",
		"kazer_dun_01", "kazer_dun_02", "kazer_dun_03", "kazer_dun_04", "kazer_dun_05",
		"kazer_dun_06", "kazer_dun_07", "kazer_dun_08", "kazer_dun_09", "kazer_dun_10",
		"crypt_01", "crypt_02", "crypt_03",
		"cave_01", "cave_02", "cave_03", "cave_04",
		"ruins_01", "ruins_02", "ruins_03",
		"goblin_warren_01", "goblin_warren_02",
		"undead_tomb_01", "undead_tomb_02", "undead_tomb_03"
	]
	var local_index: int = (index - DISTRIBUTION_PLAN["quest_rewards"]) % dungeon_ids.size()
	return dungeon_ids[local_index]


## Get specific NPC possession locations
func _get_npc_location(index: int) -> String:
	var npc_ids: Array[String] = [
		"mage_elder_moor",
		"mage_dalhurst",
		"mage_thornfield",
		"wizard_wandering_01",
		"wizard_wandering_02",
		"necromancer_01",
		"necromancer_02",
		"enchanter_01",
		"enchanter_02",
		"enchanter_03",
		"cultist_leader_01",
		"cultist_leader_02",
		"bandit_mage_01",
		"bandit_mage_02",
		"noble_collector_01",
		"noble_collector_02",
		"dwarf_runesmith_01",
		"dwarf_runesmith_02",
		"elf_mage_01",
		"elf_mage_02"
	]
	var local_index: int = (index - DISTRIBUTION_PLAN["quest_rewards"] - DISTRIBUTION_PLAN["dungeon_loot"]) % npc_ids.size()
	return npc_ids[local_index]


## Get specific shop locations
func _get_shop_location(index: int) -> String:
	var shop_ids: Array[String] = [
		"shop_elder_moor_magic",
		"shop_dalhurst_magic",
		"shop_thornfield_magic",
		"shop_millbrook_magic",
		"shop_kazer_dun_magic",
		"shop_elder_moor_general",
		"shop_dalhurst_general",
		"shop_thornfield_general",
		"shop_millbrook_general",
		"shop_wandering_merchant_01",
		"shop_wandering_merchant_02",
		"shop_wandering_merchant_03",
		"shop_black_market_01",
		"shop_black_market_02",
		"shop_elven_city"
	]
	var base_index: int = DISTRIBUTION_PLAN["quest_rewards"] + DISTRIBUTION_PLAN["dungeon_loot"] + DISTRIBUTION_PLAN["npc_possession"]
	var local_index: int = (index - base_index) % shop_ids.size()
	return shop_ids[local_index]


## Get specific world spawn locations
func _get_world_location(index: int) -> String:
	var world_locations: Array[String] = [
		"shrine_01",
		"shrine_02",
		"shrine_03",
		"ancient_altar_01",
		"ancient_altar_02",
		"hidden_cache_01",
		"hidden_cache_02",
		"hidden_cache_03",
		"shipwreck_01",
		"ruins_surface_01"
	]
	var base_index: int = DISTRIBUTION_PLAN["quest_rewards"] + DISTRIBUTION_PLAN["dungeon_loot"] + DISTRIBUTION_PLAN["npc_possession"] + DISTRIBUTION_PLAN["shop_inventory"]
	var local_index: int = (index - base_index) % world_locations.size()
	return world_locations[local_index]


# =============================================================================
# PUBLIC API
# =============================================================================

## Register a new soulstone (used when creating soulstones dynamically)
## Returns false if at TOTAL_SOULSTONES limit
func register_soulstone(soulstone_id: String, tier: int, owner_type: OwnerType, owner_id: String = "") -> bool:
	if soulstone_registry.size() >= TOTAL_SOULSTONES:
		push_warning("[SoulstoneEconomy] Cannot register soulstone - at %d limit" % TOTAL_SOULSTONES)
		return false

	if soulstone_registry.has(soulstone_id):
		push_warning("[SoulstoneEconomy] Soulstone %s already registered" % soulstone_id)
		return false

	soulstone_registry[soulstone_id] = {
		"tier": tier,
		"owner_type": owner_type,
		"owner_id": owner_id,
		"is_quest_target": false,
		"quest_id": "",
		"category": "dynamic"
	}

	soulstone_created.emit(soulstone_id, tier)
	return true


## Claim a soulstone (change ownership)
func claim_soulstone(soulstone_id: String, owner_type: OwnerType, owner_id: String) -> bool:
	if not soulstone_registry.has(soulstone_id):
		push_warning("[SoulstoneEconomy] Unknown soulstone: %s" % soulstone_id)
		return false

	var data: Dictionary = soulstone_registry[soulstone_id]
	data["owner_type"] = owner_type
	data["owner_id"] = owner_id

	soulstone_claimed.emit(soulstone_id, owner_type, owner_id)

	# Check for quest debt when player claims a quest-targeted soulstone
	if owner_type == OwnerType.PLAYER and data.get("is_quest_target", false):
		_update_quest_debt()

	return true


## Release a soulstone (mark as unclaimed)
func release_soulstone(soulstone_id: String) -> void:
	if not soulstone_registry.has(soulstone_id):
		return

	var data: Dictionary = soulstone_registry[soulstone_id]
	var was_player_owned: bool = data["owner_type"] == OwnerType.PLAYER

	data["owner_type"] = OwnerType.UNCLAIMED
	data["owner_id"] = ""

	soulstone_released.emit(soulstone_id)

	# Update debt tracking if player released a quest target
	if was_player_owned and data.get("is_quest_target", false):
		_update_quest_debt()


## Check if a soulstone is a quest target
func is_quest_target(soulstone_id: String) -> bool:
	if not soulstone_registry.has(soulstone_id):
		return false
	return soulstone_registry[soulstone_id].get("is_quest_target", false)


## Set a soulstone as a quest target
func set_quest_target(soulstone_id: String, quest_id: String) -> void:
	if not soulstone_registry.has(soulstone_id):
		push_warning("[SoulstoneEconomy] Cannot set quest target - unknown soulstone: %s" % soulstone_id)
		return

	var data: Dictionary = soulstone_registry[soulstone_id]
	data["is_quest_target"] = true
	data["quest_id"] = quest_id

	quest_targets[quest_id] = soulstone_id

	quest_target_set.emit(soulstone_id, quest_id)

	# Update debt if player already owns this soulstone
	if data["owner_type"] == OwnerType.PLAYER:
		_update_quest_debt()


## Clear quest target status from a soulstone
func clear_quest_target(soulstone_id: String) -> void:
	if not soulstone_registry.has(soulstone_id):
		return

	var data: Dictionary = soulstone_registry[soulstone_id]
	var quest_id: String = data.get("quest_id", "")

	data["is_quest_target"] = false
	data["quest_id"] = ""

	if quest_targets.has(quest_id):
		quest_targets.erase(quest_id)

	quest_target_cleared.emit(soulstone_id)

	# Update debt tracking
	_update_quest_debt()


## Get soulstone data
func get_soulstone_data(soulstone_id: String) -> Dictionary:
	if not soulstone_registry.has(soulstone_id):
		return {}
	return soulstone_registry[soulstone_id].duplicate()


## Get all soulstones owned by the player
func get_player_soulstones() -> Array[String]:
	var result: Array[String] = []
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data["owner_type"] == OwnerType.PLAYER:
			result.append(soulstone_id)
	return result


## Get total claimed soulstones
func get_total_claimed() -> int:
	var count: int = 0
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data["owner_type"] != OwnerType.UNCLAIMED:
			count += 1
	return count


## Get remaining unclaimed soulstones
func get_remaining_unclaimed() -> int:
	return TOTAL_SOULSTONES - get_total_claimed()


## Check if we can create a new soulstone (against 100 limit)
func can_create_soulstone() -> bool:
	return soulstone_registry.size() < TOTAL_SOULSTONES


## Get soulstones by owner type
func get_soulstones_by_owner(owner_type: OwnerType) -> Array[String]:
	var result: Array[String] = []
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data["owner_type"] == owner_type:
			result.append(soulstone_id)
	return result


## Get soulstones by tier
func get_soulstones_by_tier(tier: int) -> Array[String]:
	var result: Array[String] = []
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data["tier"] == tier:
			result.append(soulstone_id)
	return result


## Get soulstones at a specific location
func get_soulstones_at_location(location_id: String) -> Array[String]:
	var result: Array[String] = []
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data.get("owner_id", "") == location_id:
			result.append(soulstone_id)
	return result


## Get tier name from tier value
func get_tier_name(tier: int) -> String:
	match tier:
		SoulstoneTier.PETTY:
			return "Petty"
		SoulstoneTier.LESSER:
			return "Lesser"
		SoulstoneTier.COMMON:
			return "Common"
		SoulstoneTier.GREATER:
			return "Greater"
		SoulstoneTier.GRAND:
			return "Grand"
		_:
			return "Unknown"


## Get soulstone for a quest
func get_quest_soulstone(quest_id: String) -> String:
	return quest_targets.get(quest_id, "")


## Get player's quest-targeted soulstones (soulstones player holds that are quest targets)
func get_player_quest_soulstones() -> Array[String]:
	var result: Array[String] = []
	for soulstone_id: String in soulstone_registry:
		var data: Dictionary = soulstone_registry[soulstone_id]
		if data["owner_type"] == OwnerType.PLAYER and data.get("is_quest_target", false):
			result.append(soulstone_id)
	return result


# =============================================================================
# QUEST DEBT SYSTEM
# =============================================================================

## Update quest debt daily penalty based on player-held quest soulstones
func _update_quest_debt() -> void:
	if not FactionManager:
		return

	var quest_soulstones: Array[String] = get_player_quest_soulstones()

	if quest_soulstones.is_empty():
		# Clear penalty if player has no quest soulstones
		FactionManager.clear_daily_penalty(SOULSTONE_DEBT_FACTION, SOULSTONE_DEBT_PENALTY_ID)
	else:
		# Add/update penalty based on number of held quest soulstones
		var total_penalty: int = SOULSTONE_DEBT_DAILY_PENALTY * quest_soulstones.size()
		var reason: String = "Holding %d quest soulstone(s)" % quest_soulstones.size()
		FactionManager.add_daily_penalty(SOULSTONE_DEBT_FACTION, SOULSTONE_DEBT_PENALTY_ID, total_penalty, reason)


## Handle day change - check debt status
func _on_day_changed(_new_day: int) -> void:
	# Debt is automatically processed by FactionManager's _process_daily_penalties
	# We just need to ensure our penalty is up to date
	_update_quest_debt()


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Get save data
func get_save_data() -> Dictionary:
	return {
		"soulstone_registry": soulstone_registry.duplicate(true),
		"quest_targets": quest_targets.duplicate(),
		"distribution_counts": distribution_counts.duplicate()
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	soulstone_registry = data.get("soulstone_registry", {}).duplicate(true)
	quest_targets = data.get("quest_targets", {}).duplicate()
	distribution_counts = data.get("distribution_counts", DISTRIBUTION_PLAN.duplicate())

	# Re-apply quest debt after loading
	_update_quest_debt()


## Reset for new game
func reset() -> void:
	soulstone_registry.clear()
	quest_targets.clear()
	distribution_counts = DISTRIBUTION_PLAN.duplicate()

	# Clear any existing debt penalty
	if FactionManager:
		FactionManager.clear_daily_penalty(SOULSTONE_DEBT_FACTION, SOULSTONE_DEBT_PENALTY_ID)

	# Re-initialize world soulstones
	_initialize_world_soulstones()
