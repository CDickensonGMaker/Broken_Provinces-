## guild_rank_manager.gd - Manages guild rank progression with combined reputation AND quest requirements
## Autoload singleton that tracks guild ranks across all guilds
extends Node

## Signals
signal rank_promoted(guild_id: String, old_rank: String, new_rank: String, rank_level: int)
signal rank_check_failed(guild_id: String, reason: String)  # For debug/UI feedback

# =============================================================================
# GUILD CONFIGURATION
# =============================================================================

## Guild IDs - matches faction_manager IDs
const GUILD_ADVENTURERS := "adventurers_guild"
const GUILD_THIEVES := "thieves_guild"
const GUILD_IRON_COMPANY := "iron_company"
const GUILD_ARCANE_CIRCLE := "arcane_circle"
const GUILD_KEEPERS := "the_keepers"

## Rank data structure: Array of { name, display_name, rep_required, quests_required, flag }
## quests_required: Number of guild quests player must have completed for this guild
## rep_required: Minimum reputation needed with the guild faction

## Adventurer's Guild Ranks
## Initiate -> Journeyman -> Adventurer -> Veteran -> Elite -> Champion
const ADVENTURERS_RANKS: Array[Dictionary] = [
	{ "name": "initiate", "display_name": "Initiate", "rep_required": 0, "quests_required": 0, "flag": "adventurers_guild_rank_initiate" },
	{ "name": "journeyman", "display_name": "Journeyman", "rep_required": 25, "quests_required": 3, "flag": "adventurers_guild_rank_journeyman" },
	{ "name": "adventurer", "display_name": "Adventurer", "rep_required": 50, "quests_required": 6, "flag": "adventurers_guild_rank_adventurer" },
	{ "name": "veteran", "display_name": "Veteran", "rep_required": 75, "quests_required": 9, "flag": "adventurers_guild_rank_veteran" },
	{ "name": "elite", "display_name": "Elite", "rep_required": 100, "quests_required": 12, "flag": "adventurers_guild_rank_elite" },
	{ "name": "champion", "display_name": "Champion", "rep_required": 100, "quests_required": 14, "flag": "adventurers_guild_rank_champion" }
]

## Thieves Guild Ranks
## Pickpocket -> Cutpurse -> Burglar -> Shadowfoot -> Master Thief -> Guildmaster's Shadow
const THIEVES_RANKS: Array[Dictionary] = [
	{ "name": "pickpocket", "display_name": "Pickpocket", "rep_required": 0, "quests_required": 0, "flag": "thieves_guild_rank_pickpocket" },
	{ "name": "cutpurse", "display_name": "Cutpurse", "rep_required": 25, "quests_required": 3, "flag": "thieves_guild_rank_cutpurse" },
	{ "name": "burglar", "display_name": "Burglar", "rep_required": 50, "quests_required": 6, "flag": "thieves_guild_rank_burglar" },
	{ "name": "shadowfoot", "display_name": "Shadowfoot", "rep_required": 75, "quests_required": 9, "flag": "thieves_guild_rank_shadowfoot" },
	{ "name": "master_thief", "display_name": "Master Thief", "rep_required": 100, "quests_required": 12, "flag": "thieves_guild_rank_master_thief" },
	{ "name": "guildmasters_shadow", "display_name": "Guildmaster's Shadow", "rep_required": 100, "quests_required": 14, "flag": "thieves_guild_rank_guildmasters_shadow" }
]

## Iron Company Ranks (reputation only - no quest requirement)
## Recruit -> Soldier -> Sergeant -> Lieutenant -> Captain
const IRON_COMPANY_RANKS: Array[Dictionary] = [
	{ "name": "recruit", "display_name": "Recruit", "rep_required": 0, "quests_required": 0, "flag": "iron_company_rank_recruit" },
	{ "name": "soldier", "display_name": "Soldier", "rep_required": 25, "quests_required": 0, "flag": "iron_company_rank_soldier" },
	{ "name": "sergeant", "display_name": "Sergeant", "rep_required": 50, "quests_required": 0, "flag": "iron_company_rank_sergeant" },
	{ "name": "lieutenant", "display_name": "Lieutenant", "rep_required": 75, "quests_required": 0, "flag": "iron_company_rank_lieutenant" },
	{ "name": "captain", "display_name": "Captain", "rep_required": 100, "quests_required": 0, "flag": "iron_company_rank_captain" }
]

## Arcane Circle Ranks (reputation only - no quest requirement)
## Novice -> Apprentice -> Journeyman -> Magus -> Archmage
const ARCANE_CIRCLE_RANKS: Array[Dictionary] = [
	{ "name": "novice", "display_name": "Novice", "rep_required": 0, "quests_required": 0, "flag": "arcane_circle_rank_novice" },
	{ "name": "apprentice", "display_name": "Apprentice", "rep_required": 25, "quests_required": 0, "flag": "arcane_circle_rank_apprentice" },
	{ "name": "journeyman", "display_name": "Journeyman", "rep_required": 50, "quests_required": 0, "flag": "arcane_circle_rank_journeyman" },
	{ "name": "magus", "display_name": "Magus", "rep_required": 75, "quests_required": 0, "flag": "arcane_circle_rank_magus" },
	{ "name": "archmage", "display_name": "Archmage", "rep_required": 100, "quests_required": 0, "flag": "arcane_circle_rank_archmage" }
]

## Keepers Ranks (reputation only - secret organization)
## Initiate -> Seeker -> Warden -> Keeper
const KEEPERS_RANKS: Array[Dictionary] = [
	{ "name": "initiate", "display_name": "Initiate", "rep_required": 0, "quests_required": 0, "flag": "keepers_rank_initiate" },
	{ "name": "seeker", "display_name": "Seeker", "rep_required": 25, "quests_required": 0, "flag": "keepers_rank_seeker" },
	{ "name": "warden", "display_name": "Warden", "rep_required": 50, "quests_required": 0, "flag": "keepers_rank_warden" },
	{ "name": "keeper", "display_name": "Keeper", "rep_required": 75, "quests_required": 0, "flag": "keepers_rank_keeper" }
]

## Map guild_id to rank definitions
const GUILD_RANKS: Dictionary = {
	"adventurers_guild": ADVENTURERS_RANKS,
	"thieves_guild": THIEVES_RANKS,
	"iron_company": IRON_COMPANY_RANKS,
	"arcane_circle": ARCANE_CIRCLE_RANKS,
	"the_keepers": KEEPERS_RANKS
}

## Map guild_id to display names
const GUILD_DISPLAY_NAMES: Dictionary = {
	"adventurers_guild": "Adventurer's Guild",
	"thieves_guild": "Thieves Guild",
	"iron_company": "Iron Company",
	"arcane_circle": "Arcane Circle",
	"the_keepers": "The Keepers"
}

# =============================================================================
# STATE TRACKING
# =============================================================================

## Completed guild quests counter per guild (guild_id -> count)
## Tracks how many guild-affiliated quests player has completed
var guild_quest_counts: Dictionary = {}

## Current rank level per guild (guild_id -> int, 0-indexed)
var guild_rank_levels: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initialize quest counts for all guilds
	for guild_id: String in GUILD_RANKS:
		guild_quest_counts[guild_id] = 0
		guild_rank_levels[guild_id] = -1  # -1 = not a member

	# Defer autoload connections to ensure they're all loaded
	call_deferred("_connect_to_autoloads")


## Connect to other autoloads after they're all initialized
func _connect_to_autoloads() -> void:
	# Connect to quest completion signal
	var quest_mgr: Node = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_mgr.has_signal("quest_completed"):
		if not quest_mgr.quest_completed.is_connected(_on_quest_completed):
			quest_mgr.quest_completed.connect(_on_quest_completed)

	# Connect to faction changes for reputation-based promotion checks
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	if faction_mgr:
		if faction_mgr.has_signal("reputation_changed") and not faction_mgr.reputation_changed.is_connected(_on_reputation_changed):
			faction_mgr.reputation_changed.connect(_on_reputation_changed)
		if faction_mgr.has_signal("joined_faction") and not faction_mgr.joined_faction.is_connected(_on_joined_faction):
			faction_mgr.joined_faction.connect(_on_joined_faction)
		if faction_mgr.has_signal("left_faction") and not faction_mgr.left_faction.is_connected(_on_left_faction):
			faction_mgr.left_faction.connect(_on_left_faction)


## Handle quest completion - check if this was a guild quest
func _on_quest_completed(quest_id: String) -> void:
	var quest = QuestManager.quests.get(quest_id)
	if not quest:
		# Quest was removed (bounty), check database
		quest = QuestManager.quest_database.get(quest_id)
		if not quest:
			return

	# Check if quest has faction reputation reward - indicates guild quest
	if not quest.rewards.has("faction_reputation"):
		return

	var rep_rewards: Dictionary = quest.rewards["faction_reputation"]

	# Increment quest count for each guild that got reputation from this quest
	for faction_id: Variant in rep_rewards:
		var faction_str: String = faction_id as String
		if faction_str in GUILD_RANKS:
			var old_count: int = guild_quest_counts.get(faction_str, 0)
			guild_quest_counts[faction_str] = old_count + 1
			# Check for promotion after quest completion
			check_rank_promotion(faction_str)


## Handle reputation changes
func _on_reputation_changed(faction_id: String, _old_rep: int, _new_rep: int) -> void:
	if faction_id in GUILD_RANKS:
		check_rank_promotion(faction_id)


## Handle joining a faction - set initial rank
func _on_joined_faction(faction_id: String, _rank_name: String) -> void:
	if faction_id in GUILD_RANKS:
		# Set to rank 0 when joining
		var old_rank_level: int = guild_rank_levels.get(faction_id, -1)
		guild_rank_levels[faction_id] = 0

		# Set the initial rank flag
		var ranks: Array[Dictionary] = _get_ranks_for_guild(faction_id)
		if ranks.size() > 0:
			var first_rank: Dictionary = ranks[0]
			_set_rank_flag(faction_id, first_rank)
			_show_rank_notification(faction_id, first_rank["display_name"], true)

			if old_rank_level < 0:
				rank_promoted.emit(faction_id, "", first_rank["display_name"], 0)


## Handle leaving a faction - clear rank
func _on_left_faction(faction_id: String) -> void:
	if faction_id in GUILD_RANKS:
		guild_rank_levels[faction_id] = -1
		# Clear all rank flags for this guild
		_clear_all_rank_flags(faction_id)


# =============================================================================
# PUBLIC API
# =============================================================================

## Get the current rank name for a guild
## Returns empty string if not a member
func get_guild_rank(guild_id: String) -> String:
	if not guild_id in GUILD_RANKS:
		return ""

	var rank_level: int = guild_rank_levels.get(guild_id, -1)
	if rank_level < 0:
		return ""

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	if rank_level >= 0 and rank_level < ranks.size():
		return ranks[rank_level]["display_name"]

	return ""


## Get the current rank level (0-indexed, -1 if not a member)
func get_guild_rank_level(guild_id: String) -> int:
	return guild_rank_levels.get(guild_id, -1)


## Get number of completed guild quests
func get_guild_quest_count(guild_id: String) -> int:
	return guild_quest_counts.get(guild_id, 0)


## Check if player has achieved a specific rank or higher
## rank_name is the internal name (e.g., "veteran", not "Veteran")
func has_rank(guild_id: String, rank_name: String) -> bool:
	if not guild_id in GUILD_RANKS:
		return false

	var current_level: int = guild_rank_levels.get(guild_id, -1)
	if current_level < 0:
		return false

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	for i: int in range(ranks.size()):
		if ranks[i]["name"] == rank_name:
			return current_level >= i

	return false


## Check for rank promotion and apply if requirements met
## Called after quest completion or reputation change
func check_rank_promotion(guild_id: String) -> void:
	if not guild_id in GUILD_RANKS:
		return

	# Must be a member of the faction
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	if not faction_mgr or not faction_mgr.has_method("is_member") or not faction_mgr.is_member(guild_id):
		return

	var current_level: int = guild_rank_levels.get(guild_id, -1)
	if current_level < 0:
		# Initialize at rank 0 if they're a member but not tracked yet
		guild_rank_levels[guild_id] = 0
		current_level = 0

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	var current_rep: int = 0
	if faction_mgr.has_method("get_reputation"):
		current_rep = faction_mgr.get_reputation(guild_id)
	var quest_count: int = guild_quest_counts.get(guild_id, 0)

	# Find highest achievable rank
	var new_level: int = current_level
	for i: int in range(current_level + 1, ranks.size()):
		var rank: Dictionary = ranks[i]
		var rep_req: int = rank.get("rep_required", 0)
		var quest_req: int = rank.get("quests_required", 0)

		if current_rep >= rep_req and quest_count >= quest_req:
			new_level = i
		else:
			break  # Can't skip ranks, stop at first unmet requirement

	# Apply promotion if rank changed
	if new_level > current_level:
		var old_rank_name: String = ""
		if current_level >= 0 and current_level < ranks.size():
			old_rank_name = ranks[current_level]["display_name"]

		var new_rank: Dictionary = ranks[new_level]
		guild_rank_levels[guild_id] = new_level

		# Set the rank flag
		_set_rank_flag(guild_id, new_rank)

		# Show notification
		_show_rank_notification(guild_id, new_rank["display_name"], false)

		# Emit signal
		rank_promoted.emit(guild_id, old_rank_name, new_rank["display_name"], new_level)


## Get information about the next rank
## Returns: { name, display_name, rep_required, quests_required, rep_current, quests_current, rep_needed, quests_needed }
## Returns empty dict if at max rank or not a member
func get_next_rank_info(guild_id: String) -> Dictionary:
	if not guild_id in GUILD_RANKS:
		return {}

	var current_level: int = guild_rank_levels.get(guild_id, -1)
	if current_level < 0:
		return {}

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	var next_level: int = current_level + 1

	if next_level >= ranks.size():
		return {}  # Already at max rank

	var next_rank: Dictionary = ranks[next_level]
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	var current_rep: int = 0
	if faction_mgr and faction_mgr.has_method("get_reputation"):
		current_rep = faction_mgr.get_reputation(guild_id)
	var current_quests: int = guild_quest_counts.get(guild_id, 0)

	var rep_req: int = next_rank.get("rep_required", 0)
	var quest_req: int = next_rank.get("quests_required", 0)

	return {
		"name": next_rank["name"],
		"display_name": next_rank["display_name"],
		"rep_required": rep_req,
		"quests_required": quest_req,
		"rep_current": current_rep,
		"quests_current": current_quests,
		"rep_needed": maxi(0, rep_req - current_rep),
		"quests_needed": maxi(0, quest_req - current_quests)
	}


## Get all rank information for a guild
## Returns array of rank dictionaries with progress info
func get_all_ranks_info(guild_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not guild_id in GUILD_RANKS:
		return result

	var current_level: int = guild_rank_levels.get(guild_id, -1)
	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	var current_rep: int = 0
	if faction_mgr and faction_mgr.has_method("get_reputation"):
		current_rep = faction_mgr.get_reputation(guild_id)
	var current_quests: int = guild_quest_counts.get(guild_id, 0)

	for i: int in range(ranks.size()):
		var rank: Dictionary = ranks[i]
		var rep_req: int = rank.get("rep_required", 0)
		var quest_req: int = rank.get("quests_required", 0)

		result.append({
			"level": i,
			"name": rank["name"],
			"display_name": rank["display_name"],
			"rep_required": rep_req,
			"quests_required": quest_req,
			"is_achieved": i <= current_level,
			"is_current": i == current_level,
			"rep_met": current_rep >= rep_req,
			"quests_met": current_quests >= quest_req
		})

	return result


## Get list of all guilds the player can potentially join
func get_all_guilds() -> Array[String]:
	var result: Array[String] = []
	for guild_id: String in GUILD_RANKS:
		result.append(guild_id)
	return result


## Get display name for a guild
func get_guild_display_name(guild_id: String) -> String:
	return GUILD_DISPLAY_NAMES.get(guild_id, guild_id)


## Get the display name for a specific rank level in a guild
## Returns empty string if guild or level is invalid
func get_rank_name_by_level(guild_id: String, level: int) -> String:
	if not guild_id in GUILD_RANKS:
		return ""

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	if level >= 0 and level < ranks.size():
		return ranks[level]["display_name"]

	return ""


## Check if player is a member of a guild
func is_guild_member(guild_id: String) -> bool:
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	if faction_mgr and faction_mgr.has_method("is_member"):
		return faction_mgr.is_member(guild_id)
	return false


## Manually add guild quest completion (for quests that don't use standard system)
func add_guild_quest_completion(guild_id: String, count: int = 1) -> void:
	if guild_id in GUILD_RANKS:
		var old_count: int = guild_quest_counts.get(guild_id, 0)
		guild_quest_counts[guild_id] = old_count + count
		check_rank_promotion(guild_id)


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

## Get rank definitions for a guild (type-safe wrapper)
func _get_ranks_for_guild(guild_id: String) -> Array[Dictionary]:
	if not GUILD_RANKS.has(guild_id):
		return []

	# Return as typed array
	var result: Array[Dictionary] = []
	var ranks: Variant = GUILD_RANKS.get(guild_id)
	if ranks is Array:
		for rank: Variant in ranks:
			if rank is Dictionary:
				result.append(rank as Dictionary)
	return result


## Set the rank flag in FlagManager
func _set_rank_flag(guild_id: String, rank: Dictionary) -> void:
	var flag_mgr: Node = get_node_or_null("/root/FlagManager")
	if not flag_mgr:
		return

	var flag: String = rank.get("flag", "")
	if flag.is_empty():
		return

	if flag_mgr.has_method("set_flag"):
		flag_mgr.set_flag(flag)


## Clear all rank flags for a guild
func _clear_all_rank_flags(guild_id: String) -> void:
	var flag_mgr: Node = get_node_or_null("/root/FlagManager")
	if not flag_mgr:
		return

	var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
	for rank: Dictionary in ranks:
		var flag: String = rank.get("flag", "")
		if not flag.is_empty() and flag_mgr.has_method("clear_flag"):
			flag_mgr.clear_flag(flag)


## Show rank promotion notification
func _show_rank_notification(guild_id: String, rank_name: String, is_join: bool) -> void:
	var guild_name: String = GUILD_DISPLAY_NAMES.get(guild_id, guild_id)

	var message: String
	if is_join:
		message = "You have joined the %s as %s!" % [guild_name, rank_name]
	else:
		message = "You have been promoted to %s in the %s!" % [rank_name, guild_name]

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)
	else:
		print("[GuildRankManager] %s" % message)


# =============================================================================
# SAVE/LOAD
# =============================================================================

## Serialize state for saving
func to_dict() -> Dictionary:
	return {
		"quest_counts": guild_quest_counts.duplicate(),
		"rank_levels": guild_rank_levels.duplicate()
	}


## Deserialize state from save
func from_dict(data: Dictionary) -> void:
	guild_quest_counts = data.get("quest_counts", {}).duplicate()
	guild_rank_levels = data.get("rank_levels", {}).duplicate()

	# Ensure all guilds have entries
	for guild_id: String in GUILD_RANKS:
		if not guild_quest_counts.has(guild_id):
			guild_quest_counts[guild_id] = 0
		if not guild_rank_levels.has(guild_id):
			guild_rank_levels[guild_id] = -1

	# Re-apply rank flags based on loaded state
	_restore_rank_flags()


## Restore rank flags from loaded state
func _restore_rank_flags() -> void:
	if not FlagManager:
		return

	for guild_id: String in guild_rank_levels:
		var rank_level: int = guild_rank_levels[guild_id]
		if rank_level < 0:
			continue

		var ranks: Array[Dictionary] = _get_ranks_for_guild(guild_id)
		if rank_level >= 0 and rank_level < ranks.size():
			var rank: Dictionary = ranks[rank_level]
			_set_rank_flag(guild_id, rank)


## Reset state for new game
func reset_for_new_game() -> void:
	for guild_id: String in GUILD_RANKS:
		guild_quest_counts[guild_id] = 0
		guild_rank_levels[guild_id] = -1

	# Clear all guild rank flags
	for guild_id: String in GUILD_RANKS:
		_clear_all_rank_flags(guild_id)


# =============================================================================
# DEBUG
# =============================================================================

## Print current guild status
func debug_print_status() -> void:
	print("[GuildRankManager] Current Guild Status:")
	var faction_mgr: Node = get_node_or_null("/root/FactionManager")
	for guild_id: String in GUILD_RANKS:
		var rank_level: int = guild_rank_levels.get(guild_id, -1)
		var quest_count: int = guild_quest_counts.get(guild_id, 0)
		var rank_name: String = get_guild_rank(guild_id)
		var is_member: bool = is_guild_member(guild_id)
		var rep: int = 0
		if faction_mgr and faction_mgr.has_method("get_reputation"):
			rep = faction_mgr.get_reputation(guild_id)

		print("  %s: Member=%s, Rank=%s (level %d), Rep=%d, Quests=%d" % [
			guild_id, is_member, rank_name if not rank_name.is_empty() else "N/A",
			rank_level, rep, quest_count
		])
