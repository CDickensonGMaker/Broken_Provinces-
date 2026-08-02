## flag_manager.gd - Centralized flag management for quests, dialogue, and game state
## Autoload singleton for managing persistent flags
extends Node

## Signals
signal flag_changed(flag_name: String, value: bool)
signal devotee_status_changed(deity: String, is_devotee: bool)
signal guild_rank_changed(guild: String, rank: String)

# =============================================================================
# FLAG CONSTANTS
# =============================================================================

## Devotee flags - set when player commits to a specific deity
const FLAG_CHRONOS_DEVOTEE := "chronos_devotee"
const FLAG_GAELA_DEVOTEE := "gaela_devotee"
const FLAG_MORTHANE_DEVOTEE := "morthane_devotee"

## All devotee flags for iteration
const DEVOTEE_FLAGS: Array[String] = [
	FLAG_CHRONOS_DEVOTEE,
	FLAG_GAELA_DEVOTEE,
	FLAG_MORTHANE_DEVOTEE
]

## Guild rank flags - set when player achieves a rank in a guild
## Format: {guild_id}_rank_{rank_name}
## Adventurer's Guild ranks (6 ranks: Initiate -> Journeyman -> Adventurer -> Veteran -> Elite -> Champion)
const FLAG_ADVENTURERS_INITIATE := "adventurers_guild_rank_initiate"
const FLAG_ADVENTURERS_JOURNEYMAN := "adventurers_guild_rank_journeyman"
const FLAG_ADVENTURERS_ADVENTURER := "adventurers_guild_rank_adventurer"
const FLAG_ADVENTURERS_VETERAN := "adventurers_guild_rank_veteran"
const FLAG_ADVENTURERS_ELITE := "adventurers_guild_rank_elite"
const FLAG_ADVENTURERS_CHAMPION := "adventurers_guild_rank_champion"

## Thieves Guild ranks (6 ranks: Pickpocket -> Cutpurse -> Burglar -> Shadowfoot -> Master Thief -> Guildmaster's Shadow)
const FLAG_THIEVES_PICKPOCKET := "thieves_guild_rank_pickpocket"
const FLAG_THIEVES_CUTPURSE := "thieves_guild_rank_cutpurse"
const FLAG_THIEVES_BURGLAR := "thieves_guild_rank_burglar"
const FLAG_THIEVES_SHADOWFOOT := "thieves_guild_rank_shadowfoot"
const FLAG_THIEVES_MASTER_THIEF := "thieves_guild_rank_master_thief"
const FLAG_THIEVES_GUILDMASTERS_SHADOW := "thieves_guild_rank_guildmasters_shadow"

## Iron Company (Mercenary Guild) ranks
const FLAG_IRON_RECRUIT := "iron_company_rank_recruit"
const FLAG_IRON_SOLDIER := "iron_company_rank_soldier"
const FLAG_IRON_SERGEANT := "iron_company_rank_sergeant"
const FLAG_IRON_LIEUTENANT := "iron_company_rank_lieutenant"
const FLAG_IRON_CAPTAIN := "iron_company_rank_captain"

## Arcane Circle (Mage Guild) ranks
const FLAG_ARCANE_NOVICE := "arcane_circle_rank_novice"
const FLAG_ARCANE_APPRENTICE := "arcane_circle_rank_apprentice"
const FLAG_ARCANE_JOURNEYMAN := "arcane_circle_rank_journeyman"
const FLAG_ARCANE_MAGUS := "arcane_circle_rank_magus"
const FLAG_ARCANE_ARCHMAGE := "arcane_circle_rank_archmage"

## Keepers ranks
const FLAG_KEEPERS_INITIATE := "keepers_rank_initiate"
const FLAG_KEEPERS_SEEKER := "keepers_rank_seeker"
const FLAG_KEEPERS_WARDEN := "keepers_rank_warden"
const FLAG_KEEPERS_KEEPER := "keepers_rank_keeper"

## Map of guild ID to rank flags (ordered from lowest to highest)
const GUILD_RANK_FLAGS: Dictionary = {
	"adventurers_guild": [
		FLAG_ADVENTURERS_INITIATE,
		FLAG_ADVENTURERS_JOURNEYMAN,
		FLAG_ADVENTURERS_ADVENTURER,
		FLAG_ADVENTURERS_VETERAN,
		FLAG_ADVENTURERS_ELITE,
		FLAG_ADVENTURERS_CHAMPION
	],
	"thieves_guild": [
		FLAG_THIEVES_PICKPOCKET,
		FLAG_THIEVES_CUTPURSE,
		FLAG_THIEVES_BURGLAR,
		FLAG_THIEVES_SHADOWFOOT,
		FLAG_THIEVES_MASTER_THIEF,
		FLAG_THIEVES_GUILDMASTERS_SHADOW
	],
	"iron_company": [
		FLAG_IRON_RECRUIT,
		FLAG_IRON_SOLDIER,
		FLAG_IRON_SERGEANT,
		FLAG_IRON_LIEUTENANT,
		FLAG_IRON_CAPTAIN
	],
	"arcane_circle": [
		FLAG_ARCANE_NOVICE,
		FLAG_ARCANE_APPRENTICE,
		FLAG_ARCANE_JOURNEYMAN,
		FLAG_ARCANE_MAGUS,
		FLAG_ARCANE_ARCHMAGE
	],
	"the_keepers": [
		FLAG_KEEPERS_INITIATE,
		FLAG_KEEPERS_SEEKER,
		FLAG_KEEPERS_WARDEN,
		FLAG_KEEPERS_KEEPER
	]
}

## Map of deity name to devotee flag
const DEITY_FLAGS: Dictionary = {
	"chronos": FLAG_CHRONOS_DEVOTEE,
	"gaela": FLAG_GAELA_DEVOTEE,
	"morthane": FLAG_MORTHANE_DEVOTEE
}

## Map of deity name to church sub-faction ID
const DEITY_FACTIONS: Dictionary = {
	"chronos": "church_of_chronos",
	"gaela": "church_of_gaela",
	"morthane": "church_of_morthane"
}

# =============================================================================
# FLAG STORAGE
# =============================================================================

## All flags (flag_name -> value)
## Values can be bool, int, String, etc.
var flags: Dictionary = {}

## Context variables for placeholder substitution in flag names
## Example: {"merchant_id": "blacksmith_01"} allows flags like "{merchant_id}:befriend"
var context_variables: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer autoload connections to ensure they're all loaded
	call_deferred("_connect_to_autoloads")


## Connect to other autoloads after they're all initialized
func _connect_to_autoloads() -> void:
	# Connect to FactionManager for rank-based flag updates
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	if faction_mgr:
		if faction_mgr.has_signal("rank_changed") and not faction_mgr.rank_changed.is_connected(_on_faction_rank_changed):
			faction_mgr.rank_changed.connect(_on_faction_rank_changed)
		if faction_mgr.has_signal("joined_faction") and not faction_mgr.joined_faction.is_connected(_on_joined_faction):
			faction_mgr.joined_faction.connect(_on_joined_faction)
		# The apostasy term ends when its daily penalty does, and nowhere else.
		if faction_mgr.has_signal("ongoing_effect_cleared") \
				and not faction_mgr.ongoing_effect_cleared.is_connected(_on_ongoing_effect_cleared):
			faction_mgr.ongoing_effect_cleared.connect(_on_ongoing_effect_cleared)

	# Taking the bond is watched here rather than written into each priest's
	# dialogue, so all three doors - the ritual, `become_devotee()` and a raw
	# `set_flag` from data - charge the same price.
	if not devotee_status_changed.is_connected(_on_devotee_status_changed):
		devotee_status_changed.connect(_on_devotee_status_changed)


## A devotee term expiring reopens the other two temples.
func _on_ongoing_effect_cleared(effect_id: String) -> void:
	if not effect_id.begins_with("forsworn_"):
		return
	expire_forsworn(effect_id.trim_prefix("forsworn_"))


## Serving one god costs standing with the other two. The three churches are
## `neutrals` of each other, so no cascade does this - it has to be said here.
func _on_devotee_status_changed(deity: String, is_devotee: bool) -> void:
	if not is_devotee:
		return

	for other: String in DEITY_FACTIONS:
		if other == deity:
			continue
		FactionManager.modify_reputation(
			DEITY_FACTIONS[other], DEVOTION_RIVAL_CHURCH_COST,
			"gave their devotion to %s" % deity.capitalize()
		)


## Handle faction rank changes - update guild rank flags
func _on_faction_rank_changed(faction_id: String, _old_rank: String, new_rank: String) -> void:
	_update_guild_rank_flag(faction_id, new_rank)


## Handle faction join - set initial rank flag
func _on_joined_faction(faction_id: String, rank_name: String) -> void:
	_update_guild_rank_flag(faction_id, rank_name)


## Update guild rank flags when rank changes
func _update_guild_rank_flag(faction_id: String, rank_name: String) -> void:
	if not GUILD_RANK_FLAGS.has(faction_id):
		return

	var rank_flags: Array = GUILD_RANK_FLAGS[faction_id]
	var rank_lower := rank_name.to_lower().replace(" ", "_").replace("'", "")

	# Find and set the appropriate rank flag
	for flag: String in rank_flags:
		# Check if this flag matches the rank name
		if flag.ends_with("_" + rank_lower) or flag.contains("_" + rank_lower + "_"):
			set_flag(flag)
			guild_rank_changed.emit(faction_id, rank_name)
			break


# =============================================================================
# CORE FLAG OPERATIONS
# =============================================================================

## Substitute context variables in a string
## Replaces {variable_name} patterns with values from context_variables
func _substitute_context_variables(text: String) -> String:
	var result := text
	for key in context_variables:
		var placeholder := "{%s}" % key
		if result.contains(placeholder):
			result = result.replace(placeholder, str(context_variables[key]))
	return result


## Set a flag (supports context variable substitution)
func set_flag(flag_name: String, value: Variant = true) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	var old_value: Variant = flags.get(resolved_name, null)
	flags[resolved_name] = value

	if old_value != value:
		flag_changed.emit(resolved_name, value == true)

		# Check for devotee flag changes
		if resolved_name in DEVOTEE_FLAGS:
			var deity := _get_deity_from_flag(resolved_name)
			if not deity.is_empty():
				devotee_status_changed.emit(deity, value == true)


## Clear a flag (supports context variable substitution)
func clear_flag(flag_name: String) -> void:
	var resolved_name := _substitute_context_variables(flag_name)
	if flags.has(resolved_name):
		flags.erase(resolved_name)
		flag_changed.emit(resolved_name, false)

		# Check for devotee flag changes
		if resolved_name in DEVOTEE_FLAGS:
			var deity := _get_deity_from_flag(resolved_name)
			if not deity.is_empty():
				devotee_status_changed.emit(deity, false)


## Check if a flag is set (supports context variable substitution)
func has_flag(flag_name: String) -> bool:
	var resolved_name := _substitute_context_variables(flag_name)
	return flags.has(resolved_name) and flags[resolved_name] == true


## Get a flag value (supports context variable substitution)
func get_flag(flag_name: String, default: Variant = null) -> Variant:
	var resolved_name := _substitute_context_variables(flag_name)
	return flags.get(resolved_name, default)


## Get deity name from devotee flag
func _get_deity_from_flag(flag_name: String) -> String:
	for deity: String in DEITY_FLAGS:
		if DEITY_FLAGS[deity] == flag_name:
			return deity
	return ""


# =============================================================================
# DEVOTEE FLAG HELPERS
# =============================================================================

## Check if player is a devotee of a specific deity
## deity: "chronos", "gaela", or "morthane"
func is_devotee_of(deity: String) -> bool:
	var deity_lower := deity.to_lower()
	if DEITY_FLAGS.has(deity_lower):
		return has_flag(DEITY_FLAGS[deity_lower])
	return false


## Get which deity the player is devoted to (or empty string if none)
func get_devoted_deity() -> String:
	for deity: String in DEITY_FLAGS:
		if has_flag(DEITY_FLAGS[deity]):
			return deity
	return ""


## Set player as a devotee of a deity (clears other devotee flags)
## deity: "chronos", "gaela", or "morthane"
func become_devotee(deity: String) -> bool:
	var deity_lower := deity.to_lower()
	if not DEITY_FLAGS.has(deity_lower):
		push_warning("[FlagManager] Unknown deity: %s" % deity)
		return false

	# Clear any existing devotee flags
	for d: String in DEITY_FLAGS:
		if has_flag(DEITY_FLAGS[d]):
			clear_flag(DEITY_FLAGS[d])

	# Set the new devotee flag
	set_flag(DEITY_FLAGS[deity_lower])

	return true


# =============================================================================
# APOSTASY
# =============================================================================
# Every refusal in the game calls the bond "a sacred bond that cannot be
# undone", and all three priests have a `devotee_regret` node warning that the
# choice is permanent. Ruled 8/2: there IS a road back, and it costs. The
# priests were not lying - they were telling the player what it would take, and
# nobody had ever paid it.

## The flag that closes every other devotion chain while the price is being
## paid. Named on the three `*_05_devotion_choice` quests' `forbidden_flags`.
const FLAG_FORSWORN := "forsworn"

## What renouncing costs the church you are leaving.
const APOSTASY_REPUTATION_COST: int = -50

## How long the daily penalty runs, and therefore how long the other two
## temples stay shut.
const APOSTASY_PENALTY_DAYS: int = 7

## What taking the bond costs the OTHER two churches. Serving one god has never
## cost standing with the others - the three churches are `neutrals` of each
## other, so the cascade moves nothing either way. Ruled 8/2: it costs, and it
## costs less than apostasy, because choosing somebody is not the same as
## leaving them.
const DEVOTION_RIVAL_CHURCH_COST: int = -15


## Renounce the bond. Clears the devotee flag, empties the church's regard,
## and starts the forsworn term - during which no other devotion may be taken.
##
## Returns false if the player is not that god's devotee, so a dialogue branch
## that somehow fires twice cannot charge twice.
func renounce_devotion(deity: String) -> bool:
	var deity_lower := deity.to_lower()
	if not DEITY_FLAGS.has(deity_lower):
		push_warning("[FlagManager] Unknown deity: %s" % deity)
		return false
	if not has_flag(DEITY_FLAGS[deity_lower]):
		return false

	clear_flag(DEITY_FLAGS[deity_lower])
	set_flag(FLAG_FORSWORN)
	set_flag("forsworn_%s" % deity_lower)

	var church: String = DEITY_FACTIONS.get(deity_lower, "")
	if not church.is_empty():
		FactionManager.modify_reputation(
			church, APOSTASY_REPUTATION_COST, "renounced the bond"
		)
		# A daily penalty that ends on its own. `expire_forsworn` is what the
		# ticker calls when the term is served, which is also what reopens the
		# other two temples - so the sentence and the lockout cannot drift apart.
		FactionManager.add_ongoing_effect("forsworn_%s" % deity_lower, {
			"type": "reputation",
			"faction": church,
			"amount": -2,
			"reason_display": "Forsworn",
			"source": "apostasy",
			"days": APOSTASY_PENALTY_DAYS,
		})

	return true


## Is the player serving out an apostasy term?
func is_forsworn() -> bool:
	return has_flag(FLAG_FORSWORN)


## The term is served. Called by FactionManager when the daily penalty expires;
## the other two temples open on this line and nowhere else.
func expire_forsworn(deity: String) -> void:
	clear_flag("forsworn_%s" % deity.to_lower())

	for other: String in DEITY_FLAGS:
		if has_flag("forsworn_%s" % other):
			return

	clear_flag(FLAG_FORSWORN)


## Check if player has chosen any devotee path
func has_devotee_path() -> bool:
	for deity: String in DEITY_FLAGS:
		if has_flag(DEITY_FLAGS[deity]):
			return true
	return false


## Get the church sub-faction ID for the player's devoted deity
func get_devoted_church_faction() -> String:
	var deity := get_devoted_deity()
	if deity.is_empty():
		return ""
	return DEITY_FACTIONS.get(deity, "")


# =============================================================================
# GUILD RANK FLAG HELPERS
# =============================================================================

## Check if player has achieved a specific guild rank (or higher)
## guild_id: The faction ID (e.g., "adventurers_guild", "thieves_guild")
## rank_flag: The rank flag constant (e.g., FLAG_ADVENTURERS_VETERAN)
func has_guild_rank(guild_id: String, rank_flag: String) -> bool:
	if not GUILD_RANK_FLAGS.has(guild_id):
		return false

	var rank_flags: Array = GUILD_RANK_FLAGS[guild_id]
	var target_index: int = rank_flags.find(rank_flag)

	if target_index < 0:
		return false

	# Check if player has this rank or any higher rank
	for i: int in range(target_index, rank_flags.size()):
		if has_flag(rank_flags[i]):
			return true

	return false


## Get the player's current rank flag for a guild (or empty string if not a member)
func get_guild_rank_flag(guild_id: String) -> String:
	if not GUILD_RANK_FLAGS.has(guild_id):
		return ""

	var rank_flags: Array = GUILD_RANK_FLAGS[guild_id]

	# Return the highest achieved rank flag
	for i: int in range(rank_flags.size() - 1, -1, -1):
		if has_flag(rank_flags[i]):
			return rank_flags[i]

	return ""


## Get the rank index for a guild (0 = lowest rank, -1 = not a member)
func get_guild_rank_index(guild_id: String) -> int:
	if not GUILD_RANK_FLAGS.has(guild_id):
		return -1

	var rank_flags: Array = GUILD_RANK_FLAGS[guild_id]

	# Return the highest achieved rank index
	for i: int in range(rank_flags.size() - 1, -1, -1):
		if has_flag(rank_flags[i]):
			return i

	return -1


# =============================================================================
# QUEST PREREQUISITE HELPERS
# =============================================================================

## Check if all required flags are set
## Returns true if all flags in the array are set
func check_flag_prerequisites(required_flags: Array) -> bool:
	for flag_name: Variant in required_flags:
		if flag_name is String:
			if not has_flag(flag_name as String):
				return false
	return true


## Check if any of the forbidden flags are set
## Returns true if NONE of the forbidden flags are set (i.e., prerequisites pass)
func check_forbidden_flags(forbidden_flags: Array) -> bool:
	for flag_name: Variant in forbidden_flags:
		if flag_name is String:
			if has_flag(flag_name as String):
				return false
	return true


## Get list of missing prerequisite flags
func get_missing_prerequisites(required_flags: Array) -> Array[String]:
	var missing: Array[String] = []
	for flag_name: Variant in required_flags:
		if flag_name is String:
			if not has_flag(flag_name as String):
				missing.append(flag_name as String)
	return missing


# =============================================================================
# CONTEXT VARIABLE MANAGEMENT
# =============================================================================

## Set a context variable for placeholder substitution
func set_context_variable(key: String, value: Variant) -> void:
	context_variables[key] = value


## Clear a context variable
func clear_context_variable(key: String) -> void:
	context_variables.erase(key)


## Clear all context variables
func clear_all_context_variables() -> void:
	context_variables.clear()


## Get current context variables
func get_context_variables() -> Dictionary:
	return context_variables.duplicate()


# =============================================================================
# PENDING FLAG OPERATIONS (for shops, boats, etc.)
# =============================================================================

## Check and clear a pending shop flag (returns shop ID or empty string)
func pop_pending_shop() -> String:
	var shop_id := ""
	for key: String in flags.keys():
		if key.begins_with("_pending_shop:"):
			shop_id = key.substr(len("_pending_shop:"))
			flags.erase(key)
			break
	return shop_id


## Check and clear a pending boat voyage flag (returns route ID or empty string)
func pop_pending_boat_voyage() -> String:
	var route_id := ""
	for key: String in flags.keys():
		if key.begins_with("_pending_boat_voyage:"):
			route_id = key.substr(len("_pending_boat_voyage:"))
			flags.erase(key)
			break
	return route_id


# =============================================================================
# SAVE/LOAD INTEGRATION
# =============================================================================

## Serialize flags for saving.
##
## context_variables belongs here as much as flags do: it is the substitution
## context behind every `{merchant_id}:befriend` flag name, so a save that
## carries the flags and drops the context restores names that no longer
## resolve to anything.
func to_dict() -> Dictionary:
	return {
		"flags": flags.duplicate(),
		"context_variables": context_variables.duplicate()
	}


## Deserialize flags from save
func from_dict(data: Dictionary) -> void:
	flags = data.get("flags", {}).duplicate()
	context_variables = data.get("context_variables", {}).duplicate()


## Reset state for new game
func reset_for_new_game() -> void:
	flags.clear()
	context_variables.clear()


# =============================================================================
# DEBUG HELPERS
# =============================================================================

## Get all set flags (for debugging)
func get_all_flags() -> Dictionary:
	return flags.duplicate()


## Print all flags to console (for debugging)
func debug_print_flags() -> void:
	Log.d("[FlagManager] Current flags:")
	for flag_name: String in flags:
		Log.d("  %s = %s" % [flag_name, flags[flag_name]])
