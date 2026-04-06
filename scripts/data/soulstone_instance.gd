## soulstone_instance.gd - Per-soulstone instance data resource
## Represents a single soulstone's current state
class_name SoulstoneInstance
extends Resource

## Unique identifier for this soulstone (matches SoulstoneEconomy registry)
@export var soulstone_id: String = ""

## Tier level (1-5, matches SoulstoneTier enum)
@export_range(1, 5) var tier: int = 1

## Display name shown to player
@export var display_name: String = ""

## Current soul charge level
@export var soul_charge: float = 0.0

## Maximum charge capacity
@export var max_charge: float = 100.0

## Whether this soulstone is a quest target
@export var is_quest_target: bool = false

## Quest ID if this is a quest target
@export var quest_id: String = ""

## Whether this soulstone is filled with a soul
@export var is_filled: bool = false

## Location where this soulstone was found
@export var origin_location: String = ""


## Get the tier name
func get_tier_name() -> String:
	return SoulstoneData.get_tier_name(tier)


## Get the enchant power multiplier for this tier
func get_enchant_power() -> float:
	return SoulstoneData.get_tier_power(tier)


## Get the fill threshold for this tier
func get_fill_threshold() -> int:
	return SoulstoneData.get_tier_threshold(tier)


## Check if the soulstone is fully charged
func is_fully_charged() -> bool:
	return soul_charge >= max_charge


## Get charge percentage (0.0 - 1.0)
func get_charge_percent() -> float:
	if max_charge <= 0.0:
		return 0.0
	return clampf(soul_charge / max_charge, 0.0, 1.0)


## Add soul energy to this soulstone
## Returns true if soulstone became filled
func add_soul_energy(energy: float) -> bool:
	if is_filled:
		return false

	soul_charge += energy
	if soul_charge >= max_charge:
		soul_charge = max_charge
		is_filled = true
		return true
	return false


## Consume the soul (for enchanting)
## Returns true if successful
func consume_soul() -> bool:
	if not is_filled:
		return false

	is_filled = false
	soul_charge = 0.0
	return true


## Get display name with status
func get_status_display_name() -> String:
	var tier_name: String = get_tier_name()
	if is_filled:
		return "%s Soulstone (Filled)" % tier_name
	elif soul_charge > 0.0:
		return "%s Soulstone (%d%%)" % [tier_name, int(get_charge_percent() * 100.0)]
	else:
		return "%s Soulstone (Empty)" % tier_name


## Create display name from tier
func generate_display_name() -> void:
	display_name = "%s Soulstone" % get_tier_name()


## Convert to dictionary for saving
func to_dict() -> Dictionary:
	return {
		"soulstone_id": soulstone_id,
		"tier": tier,
		"display_name": display_name,
		"soul_charge": soul_charge,
		"max_charge": max_charge,
		"is_quest_target": is_quest_target,
		"quest_id": quest_id,
		"is_filled": is_filled,
		"origin_location": origin_location
	}


## Load from dictionary
func from_dict(data: Dictionary) -> void:
	soulstone_id = data.get("soulstone_id", "")
	tier = data.get("tier", 1)
	display_name = data.get("display_name", "")
	soul_charge = data.get("soul_charge", 0.0)
	max_charge = data.get("max_charge", 100.0)
	is_quest_target = data.get("is_quest_target", false)
	quest_id = data.get("quest_id", "")
	is_filled = data.get("is_filled", false)
	origin_location = data.get("origin_location", "")


## Create a new soulstone instance from economy data
static func create_from_economy(economy_data: Dictionary, p_soulstone_id: String) -> SoulstoneInstance:
	var instance := SoulstoneInstance.new()
	instance.soulstone_id = p_soulstone_id
	instance.tier = economy_data.get("tier", 1)
	instance.is_quest_target = economy_data.get("is_quest_target", false)
	instance.quest_id = economy_data.get("quest_id", "")
	instance.origin_location = economy_data.get("owner_id", "")

	# Set max charge based on tier
	instance.max_charge = float(SoulstoneData.get_tier_threshold(instance.tier))

	# Generate display name
	instance.generate_display_name()

	return instance


## Duplicate this soulstone instance
func duplicate_instance() -> SoulstoneInstance:
	var copy := SoulstoneInstance.new()
	copy.soulstone_id = soulstone_id
	copy.tier = tier
	copy.display_name = display_name
	copy.soul_charge = soul_charge
	copy.max_charge = max_charge
	copy.is_quest_target = is_quest_target
	copy.quest_id = quest_id
	copy.is_filled = is_filled
	copy.origin_location = origin_location
	return copy
