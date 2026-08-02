## quest_manager.gd - Manages quest states and objectives
extends Node

signal quest_started(quest_id: String)
signal quest_updated(quest_id: String, objective_id: String)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)
signal quest_betrayed(quest_id: String)  # Player kept quest items or made selfish choice
signal objective_completed(quest_id: String, objective_id: String)
signal objective_time_expired(quest_id: String, objective_id: String)  # Timed objective ran out of time
signal timed_objective_started(quest_id: String, objective_id: String, time_limit: int)  # Timer started
signal timed_objective_tick(quest_id: String, objective_id: String, time_remaining: float)  # Timer update
signal tracked_quest_changed(quest_id: String)
signal choice_consequence_applied(quest_id: String, choice_id: String)  # Choice consequences executed
signal follower_recruited(follower_id: String, quest_id: String)  # Follower recruited via quest
signal soulstone_delivered(soulstone_id: String, npc_id: String, quest_id: String)  # Soulstone turned in
signal puzzle_solved(puzzle_id: String, quest_id: String)  # Puzzle completed
signal moral_choice_recorded(quest_id: String, choice_id: String)  # Player committed to a branch

## THE OBJECTIVE VOCABULARY.
##
## Every objective `type` a driver in this file can settle. `update_progress`
## matches on the type string alone, so an unlisted type is not rejected - it
## simply sits there forever because nothing ever calls update_progress with it.
## That is how ten types reached a milestone build with four Thieves Guild
## quests and two Mage capstones structurally uncompletable, blocking both rank
## ladders, without a single error line.
##
## This list is the single source of truth for the type vocabulary. It is read
## by tools/check_quest_engine.gd, which drives each type end to end and fails
## if one cannot be settled, and by tools/validate_content.gd, which fails on
## any type in data/quests/ that appears in neither this list nor
## DEFERRED_OBJECTIVE_TYPES.
##
## Add a type here only when a driver for it exists.
const HANDLED_OBJECTIVE_TYPES: Array[String] = [
	"kill",               # on_enemy_killed
	"collect",            # on_item_collected + inventory poll on start
	"has_item",           # refresh_has_item_objectives (poll, not a count)
	"talk",               # on_npc_talked
	"reach",              # on_location_reached
	"explore",            # on_location_explored
	"interact",           # on_interact, incl. QuestInteractable
	"choice",             # apply_choice_consequence
	"craft",              # update_progress("craft", ...) from the crafting UI
	"escort",             # on_escort_arrived / on_escort_died
	"duel_win",           # DuelManager
	"deliver_soulstone",  # on_soulstone_delivered
	"solve_puzzle",       # on_puzzle_solved, off PuzzleRoomController's flags
	"recruit_follower",   # on_follower_recruited
	"wave_defense",       # on_wave_defense_progress / _complete
	"wave_defense_complete",
]

## Types that ship in data/quests/ with no driver, deliberately, because
## implementing one would mean inventing a design decision Caleb has not made.
## Each needs a row in docs/audits/wave_b_dispositions.md naming the question.
## Nothing goes on this list to make a check quiet.
##
## Empty, and it must stay empty until a type genuinely has to wait on a
## design call. `variable` lived here for mage_repeatable_research; that quest
## now asks for a real reagent through the "has_item" driver, so the excuse has
## no subject left and check_quest_engine fails on a deferral nothing uses.
const DEFERRED_OBJECTIVE_TYPES: Dictionary = {}

## Quest data structure
class Quest:
	var id: String
	var title: String
	var description: String
	var state: Enums.QuestState = Enums.QuestState.UNAVAILABLE
	var completion_state: Enums.QuestCompletionState = Enums.QuestCompletionState.NONE  # Detailed outcome
	var is_main_quest: bool = false  # Main story quests get gold markers, side quests get teal
	var objectives: Array[Objective] = []
	var rewards: Dictionary = {}  # {gold, xp, items: [{id, quantity}], faction_reputation: {faction_id: amount}, follower: "follower_id", soulstone: "soulstone_id", unlock_area: "flag_name"}
	var prerequisites: Array[String] = []  # Quest IDs that must be completed
	var flag_prerequisites: Array[String] = []  # Flags that must be set (e.g., "chronos_devotee", "adventurers_guild_rank_veteran")
	var forbidden_flags: Array[String] = []  # Flags that must NOT be set (e.g., other devotee flags)

	# Quest source and giver tracking
	var quest_source: Enums.QuestSource = Enums.QuestSource.STORY
	var giver_npc_id: String = ""  # NPC who gave this quest
	var giver_npc_type: String = ""  # Type of NPC (e.g., "guard", "merchant")
	var giver_region: String = ""  # Region where quest was given

	# Turn-in configuration (NEW - unified turn-in system)
	var turn_in_type: Enums.TurnInType = Enums.TurnInType.NPC_SPECIFIC
	var turn_in_target: String = ""  # NPC ID, NPC type, or object ID depending on turn_in_type
	var turn_in_region: String = ""  # Region where turn-in is accepted
	var turn_in_zone: String = ""  # Zone ID for compass navigation

	# Quest chains and triggers
	var next_quest: String = ""  # Auto-start this quest on completion
	var trigger_item: String = ""  # Item that triggers this quest when picked up

	# Starter items given when quest begins
	var starter_items: Array[Dictionary] = []  # [{id: String, quantity: int}]

	# Spawn-on-accept: Spawn objects when quest is accepted
	# Format: [{"type": "chest"|"camp", "location": "zone_id", "coords": [x, y, z], "contains": ["item_id"], "loot_tier": "common"}]
	var spawn_on_accept: Array[Dictionary] = []

	# Quest item tracking for temptation system
	var quest_items: Array[String] = []  # Item IDs that are quest-bound (fail quest if sold/equipped)

	# Faction the quest belongs to (for reputation on complete/fail)
	var faction: String = ""

	## Flags raised in FlagManager the moment this quest completes.
	##
	## ONE property, TWO authored spellings. The story chains and the Mage
	## ladder write `on_complete_flags`; the Thieves ladder writes `flags_set`,
	## sitting beside the turn-in fields, which is the same claim in different
	## words. _parse_quest unions both keys into this list rather than carrying
	## two properties that would have to be raised in two places forever.
	##
	## These do not collide with the rank flags GuildRankManager writes: the
	## quests spell them `thieves_rank_burglar`, the ladder spells its own
	## `thieves_guild_rank_burglar`, and no name appears in both schemes.
	var on_complete_flags: Array[String] = []

	## Guild rank LEVEL the player must already hold before this quest is
	## offered, read against `faction` as the guild id.
	## GuildRankManager.get_guild_rank_level() answers -1 for a non-member and
	## 0+ for a member, so 0 here means "must have joined" and -1 - the default
	## for a quest that authored no rank_required at all - gates nothing.
	var rank_required: int = -1

	# Bounty cooldown system
	var cooldown_days: int = 0  # Days before this bounty can be taken again (0 = no cooldown)
	var possible_zones: Array[String] = []  # Random zone selection for objectives (empty = use fixed target_zone)

	# Dungeon generation (for procedural dungeon quests)
	var dungeon_type: String = ""  # Type of dungeon to generate (e.g., "crypt", "cave")
	var dungeon_seed: int = 0  # Seed for reproducible generation (0 = random from quest_id hash)
	var dungeon_room_set: String = ""  # Room set to use (empty = default)
	var dungeon_size: String = "MEDIUM"  # Size preset: SMALL, MEDIUM, LARGE, HUGE

	# Choice consequence system - maps choice_id to consequence data.
	# Supported keys, all optional:
	#   flags_to_set: ["flag"]                 dialogue flags to raise
	#   reputation_changes: {faction_id: int}  faction must exist in data/factions
	#   unlock_follower: "follower_id"         raises the follower_unlocked flag
	#   spawn_enemy: "enemy_id@location_id"    location half optional
	#   items_given: ["item_id"]               one of each, handed over on the spot
	# Any other key is documentation only and is never executed.
	var choice_consequences: Dictionary = {}

	# OR-objective groups. Objectives carrying the same `group` id are
	# alternatives: settling any one of them settles the group. This dictionary
	# is optional decoration for those groups - a group works without an entry
	# here, and an entry without members does nothing.
	#   group_id: {description: String, required: int}
	# `required` is how many members must complete before the group is settled;
	# it defaults to 1, which is the OR case.
	var objective_groups: Dictionary = {}

class Objective:
	var id: String
	var description: String
	var type: String  # one of QuestManager.HANDLED_OBJECTIVE_TYPES
	var target: String  # Enemy ID, item ID, NPC ID, location ID, soulstone ID, puzzle flag, follower ID, wave_spawner_id
	var target_zone: String = ""  # Zone where target is located (for cross-zone markers)
	var required_count: int = 1
	var current_count: int = 0
	var is_completed: bool = false
	var is_optional: bool = false
	var completion_method: String = ""  # How this objective was completed (for multi-path quests)
	var time_limit: int = 0  # Time limit in seconds (0 = no limit)
	var fail_quest_on_timeout: bool = true  # If true, failing this timed objective fails the entire quest

	## OR-group membership. Empty means this objective stands alone. Objectives
	## sharing a group id are alternative ways to settle the same problem.
	var group: String = ""

	## True when a sibling in this objective's group settled it instead. The
	## player never did this one and the journal should not claim he did, but
	## the quest no longer waits on it.
	var is_settled: bool = false

	## An authored skill check standing between the player and this objective,
	## `{"skill": "deception", "dc": 14}`. Rolled by whatever settles the
	## objective - QuestInteractable does it today. Empty means no roll.
	## Quests carried these in decorative `skill_checks` blocks that
	## QuestManager never read; this is the field that is actually consulted.
	var skill_check: Dictionary = {}

	## World-state condition that pre-completes this objective the moment the
	## quest is offered - the "you already did this" case. Shape is documented
	## on WorldState.evaluate_condition().
	var world_condition: Dictionary = {}

	## The quest no longer waits on this objective, whether the player did it
	## or a sibling settled the group.
	func is_satisfied() -> bool:
		return is_completed or is_settled

	## Dungeon spawn configuration (for spawning quest-specific content in dungeons)
	## Format: {dungeon_id, room_type, spawn_type, entity_id, guaranteed_count}
	var dungeon_spawn: Dictionary = {}
	# dungeon_spawn fields:
	#   - dungeon_id: String - which dungeon to spawn in
	#   - room_type: String - "any", "boss", "entrance", "treasure"
	#   - spawn_type: String - "npc", "enemy", "item", "chest"
	#   - entity_id: String - ID of the NPC, enemy, or item to spawn
	#   - guaranteed_count: int - minimum number to spawn (for enemies)


## Active quests
var quests: Dictionary = {}  # quest_id -> Quest

## Quest database (loaded from data files)
var quest_database: Dictionary = {}

## quest_id -> the .json it was parsed from, and quest_id -> that file's raw
## parsed contents. Filled by the recursive walk in _load_quests_from_directory,
## because the walk is the only thing that knows where a quest actually lives.
## get_quest_data() used to guess at "res://data/quests/<id>.json" and silently
## degrade for every quest in a subdirectory - see the note on it.
var quest_json_paths: Dictionary = {}
var quest_raw_json: Dictionary = {}

## quest_id -> the branch the player committed to. Saved.
var moral_choices: Dictionary = {}

## How far a branch tagged "good" or "evil" moves the morality score. One tier
## boundary is 40 points wide, so 10 means four consistent choices in the same
## direction move a person a whole tier - a run of decisions, not one.
const MORAL_CHOICE_ALIGNMENT_SHIFT: int = 10

## Currently tracked quest (shown on compass)
var tracked_quest_id: String = ""

## Objective locations cache: quest_id -> {objective_id -> {hex: Vector2i, zone_id: String, world_pos: Vector3}}
## Caches resolved locations for quest objectives for efficient navigation
var objective_locations: Dictionary = {}

## Bounty cooldowns: quest_id -> game_day when bounty becomes available again
## This persists between saves and prevents bounty spam
var bounty_cooldowns: Dictionary = {}

## Default cooldown for bounties (5 in-game days)
const DEFAULT_BOUNTY_COOLDOWN_DAYS := 5

## Timed objectives tracking
## Key: "quest_id:objective_id", Value: remaining time in seconds (float)
var _timed_objectives: Dictionary = {}

## Paused timed objectives (for cutscenes, menus, etc.)
var _paused_timers: Dictionary = {}  # Same key format as _timed_objectives

func _ready() -> void:
	_load_quest_database()
	# Defer signal connection to ensure other managers are ready
	call_deferred("_connect_signals")


func _connect_signals() -> void:
	# Connect to CombatManager for kill tracking (backup for spell kills)
	if CombatManager and CombatManager.has_signal("entity_killed"):
		CombatManager.entity_killed.connect(_on_entity_killed)

	# Connect to InventoryManager for trigger_item quests
	if InventoryManager and InventoryManager.has_signal("item_added"):
		InventoryManager.item_added.connect(_on_item_added)

	# Connect to InventoryManager for temptation tracking (selling quest items)
	if InventoryManager and InventoryManager.has_signal("item_sold"):
		InventoryManager.item_sold.connect(_on_item_sold)

	# Connect to InventoryManager for temptation tracking (equipping quest items)
	if InventoryManager and InventoryManager.has_signal("equipment_changed"):
		InventoryManager.equipment_changed.connect(_on_equipment_changed)

	# Connect to PlayerGPS so "explore" objectives settle on discovery
	if PlayerGPS:
		if PlayerGPS.has_signal("location_discovered"):
			PlayerGPS.location_discovered.connect(_on_location_discovered)
		if PlayerGPS.has_signal("cell_revealed"):
			PlayerGPS.cell_revealed.connect(_on_cell_revealed)

	# Connect to own signals for timed objective management
	objective_completed.connect(_on_objective_completed_for_timer)


func _on_location_discovered(location_id: String, _location_name: String) -> void:
	on_location_explored(location_id)


func _on_cell_revealed(coords: Vector2i) -> void:
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
	if cell and not cell.location_id.is_empty():
		on_location_explored(cell.location_id)


func _process(delta: float) -> void:
	_update_timed_objectives(delta)


# =============================================================================
# TIMED OBJECTIVES SYSTEM
# =============================================================================

## Update all active timed objectives
func _update_timed_objectives(delta: float) -> void:
	if _timed_objectives.is_empty():
		return

	# Don't tick timers when game is paused or in menu
	if get_tree().paused:
		return

	var expired_keys: Array[String] = []

	for key: String in _timed_objectives:
		var remaining: float = _timed_objectives[key]
		remaining -= delta

		if remaining <= 0.0:
			expired_keys.append(key)
		else:
			_timed_objectives[key] = remaining
			# Emit tick signal for UI updates
			var parts: PackedStringArray = key.split(":")
			if parts.size() == 2:
				timed_objective_tick.emit(parts[0], parts[1], remaining)

	# Handle expired timers
	for key: String in expired_keys:
		_timed_objectives.erase(key)
		var parts: PackedStringArray = key.split(":")
		if parts.size() == 2:
			_on_timed_objective_expired(parts[0], parts[1])


## Called when a timed objective runs out of time
func _on_timed_objective_expired(quest_id: String, objective_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	# Find the objective
	var target_obj: Objective = null
	for obj in quest.objectives:
		if obj.id == objective_id:
			target_obj = obj
			break

	if not target_obj or target_obj.is_completed:
		return

	# Emit the expired signal
	objective_time_expired.emit(quest_id, objective_id)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Time expired: %s" % target_obj.description)

	# Fail quest or just mark objective as failed based on configuration
	if target_obj.fail_quest_on_timeout:
		fail_quest(quest_id, "timeout")
	else:
		# Just mark the objective as failed (optional objectives can timeout without failing quest)
		target_obj.is_completed = true
		target_obj.completion_method = "timeout_failed"
		quest_updated.emit(quest_id, objective_id)
		_check_quest_completion(quest_id)


## Start a timer for a timed objective
func start_objective_timer(quest_id: String, objective_id: String, time_seconds: int) -> void:
	if time_seconds <= 0:
		return

	var key: String = "%s:%s" % [quest_id, objective_id]
	_timed_objectives[key] = float(time_seconds)
	timed_objective_started.emit(quest_id, objective_id, time_seconds)


## Stop/cancel a timer for a timed objective (e.g., when objective completes)
func stop_objective_timer(quest_id: String, objective_id: String) -> void:
	var key: String = "%s:%s" % [quest_id, objective_id]
	_timed_objectives.erase(key)
	_paused_timers.erase(key)


## Pause a specific timer (useful for cutscenes)
func pause_objective_timer(quest_id: String, objective_id: String) -> void:
	var key: String = "%s:%s" % [quest_id, objective_id]
	if _timed_objectives.has(key):
		_paused_timers[key] = _timed_objectives[key]
		_timed_objectives.erase(key)


## Resume a paused timer
func resume_objective_timer(quest_id: String, objective_id: String) -> void:
	var key: String = "%s:%s" % [quest_id, objective_id]
	if _paused_timers.has(key):
		_timed_objectives[key] = _paused_timers[key]
		_paused_timers.erase(key)


## Pause all active timers
func pause_all_timers() -> void:
	for key: String in _timed_objectives:
		_paused_timers[key] = _timed_objectives[key]
	_timed_objectives.clear()


## Resume all paused timers
func resume_all_timers() -> void:
	for key: String in _paused_timers:
		_timed_objectives[key] = _paused_timers[key]
	_paused_timers.clear()


## Extend a timer by additional seconds
func extend_objective_timer(quest_id: String, objective_id: String, extra_seconds: float) -> void:
	var key: String = "%s:%s" % [quest_id, objective_id]
	if _timed_objectives.has(key):
		_timed_objectives[key] += extra_seconds
	elif _paused_timers.has(key):
		_paused_timers[key] += extra_seconds


## Get remaining time for a timed objective (returns 0 if not timed or expired)
func get_objective_time_remaining(quest_id: String, objective_id: String) -> float:
	var key: String = "%s:%s" % [quest_id, objective_id]
	if _timed_objectives.has(key):
		return _timed_objectives[key]
	if _paused_timers.has(key):
		return _paused_timers[key]
	return 0.0


## Check if an objective timer is active
func is_objective_timer_active(quest_id: String, objective_id: String) -> bool:
	var key: String = "%s:%s" % [quest_id, objective_id]
	return _timed_objectives.has(key) or _paused_timers.has(key)


## Get the currently active timed objective for display (returns dict with quest_id, objective_id, time_remaining, description)
## Returns empty dict if no timed objectives are active
func get_active_timed_objective() -> Dictionary:
	if _timed_objectives.is_empty():
		return {}

	# Return the first active timed objective (prioritize tracked quest)
	var tracked_key: String = ""
	if not tracked_quest_id.is_empty():
		for key: String in _timed_objectives:
			if key.begins_with(tracked_quest_id + ":"):
				tracked_key = key
				break

	var key_to_use: String = tracked_key if not tracked_key.is_empty() else _timed_objectives.keys()[0]
	var parts: PackedStringArray = key_to_use.split(":")

	if parts.size() != 2:
		return {}

	var quest_id: String = parts[0]
	var objective_id: String = parts[1]

	if not quests.has(quest_id):
		return {}

	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		if obj.id == objective_id:
			return {
				"quest_id": quest_id,
				"objective_id": objective_id,
				"time_remaining": _timed_objectives[key_to_use],
				"description": obj.description,
				"quest_title": quest.title
			}

	return {}


## Start timers for timed objectives when a quest begins
## Only starts timer for the first incomplete timed objective
func _start_timed_objectives_for_quest(quest: Quest) -> void:
	for obj in quest.objectives:
		if obj.is_completed:
			continue
		if obj.time_limit > 0:
			start_objective_timer(quest.id, obj.id, obj.time_limit)
			# Only start timer for first timed objective
			break


## Called when any objective completes - stop its timer and potentially start next timed objective
func _on_objective_completed_for_timer(quest_id: String, objective_id: String) -> void:
	# Stop the timer for the completed objective
	stop_objective_timer(quest_id, objective_id)

	# Check if there's a next timed objective in the quest that should start
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	# Find next incomplete timed objective and start its timer
	for obj in quest.objectives:
		if obj.is_completed:
			continue
		if obj.time_limit > 0 and not is_objective_timer_active(quest_id, obj.id):
			start_objective_timer(quest_id, obj.id, obj.time_limit)
			break


## Clear all timers for a quest (called when quest completes or fails)
func _clear_quest_timers(quest_id: String) -> void:
	var keys_to_remove: Array[String] = []
	for key: String in _timed_objectives:
		if key.begins_with(quest_id + ":"):
			keys_to_remove.append(key)
	for key: String in keys_to_remove:
		_timed_objectives.erase(key)

	keys_to_remove.clear()
	for key: String in _paused_timers:
		if key.begins_with(quest_id + ":"):
			keys_to_remove.append(key)
	for key: String in keys_to_remove:
		_paused_timers.erase(key)


## Handle entity killed event from CombatManager.
##
## EnemyBase reports its own death in `_on_death()`, whatever killed it. This
## handler exists for killable things that do not - counting an EnemyBase here
## as well would advance a kill objective twice for one corpse.
func _on_entity_killed(entity: Node, _killer: Node) -> void:
	if entity is EnemyBase:
		return
	if entity.has_method("get_enemy_data"):
		var enemy_data = entity.get_enemy_data()
		if enemy_data and enemy_data.id:
			on_enemy_killed(enemy_data.id)


## Handle item added to inventory - check for quest trigger items
func _on_item_added(item_id: String, _quantity: int) -> void:
	# Check if any quest is triggered by picking up this item
	for quest_id in quest_database:
		var template: Quest = quest_database[quest_id]
		if template.trigger_item == item_id:
			# Don't trigger if quest is already active or completed
			if quests.has(quest_id):
				continue

			# Start the quest
			if start_quest(quest_id):
				# Show notification
				var hud := get_tree().get_first_node_in_group("hud")
				if hud and hud.has_method("show_notification"):
					var quest: Quest = quests.get(quest_id)
					if quest:
						hud.show_notification("Quest Started: " + quest.title)


## Handle item sold - check for temptation (selling quest items)
func _on_item_sold(item_id: String, _quantity: int, _quality: Enums.ItemQuality) -> void:
	# Check all active quests for this item as a quest item
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		# Check if this item is a quest item for this quest
		if item_id in quest.quest_items:
			fail_quest(quest_id, "temptation")
			return


## Handle equipment changed - check for temptation (equipping quest items)
func _on_equipment_changed(slot: String, _old_item: Dictionary, new_item: Dictionary) -> void:
	if new_item.is_empty():
		return  # Unequipping doesn't count

	var item_id: String = new_item.get("item_id", "")
	if item_id.is_empty():
		return

	# Check all active quests for this item as a quest item
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		# Check if this item is a quest item for this quest
		if item_id in quest.quest_items:
			fail_quest(quest_id, "temptation")
			return


func _load_quest_database() -> void:
	var quest_dir := "res://data/quests/"
	if not DirAccess.dir_exists_absolute(quest_dir):
		return

	_load_quests_from_directory(quest_dir)


## Recursively load quests from a directory and its subdirectories
func _load_quests_from_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		var full_path: String = dir_path + file_name

		# A leading underscore marks a staging directory (data/quests/_future/).
		# Loading staging into the live database is how two stale forks came to
		# overwrite the shipped aberdeens_blessing and missing_miner with their
		# broken giver ids: the walk reached _future/ last and it won.
		if dir.current_is_dir() and not file_name.begins_with(".") and not file_name.begins_with("_"):
			# Recursively load from subdirectory
			_load_quests_from_directory(full_path + "/")
		elif file_name.ends_with(".json"):
			var file := FileAccess.open(full_path, FileAccess.READ)
			if file:
				var json: Variant = JSON.parse_string(file.get_as_text())
				if json is Dictionary:
					var json_dict: Dictionary = json as Dictionary
					# Skip disabled quests (preserved for later re-enabling)
					if json_dict.get("disabled", false):
						file_name = dir.get_next()
						continue
					var quest := _parse_quest(json_dict)
					if not quest.id.is_empty():
						quest_database[quest.id] = quest
						quest_json_paths[quest.id] = full_path
						quest_raw_json[quest.id] = json_dict

		file_name = dir.get_next()
	dir.list_dir_end()

func _parse_quest(data: Dictionary) -> Quest:
	var quest := Quest.new()
	quest.id = data.get("id", "")
	quest.title = data.get("title", "Unknown Quest")
	quest.description = data.get("description", "")
	quest.is_main_quest = data.get("is_main_quest", false)  # Main story = gold, side = teal
	quest.rewards = data.get("rewards", {})

	# Quest source (defaults to STORY for JSON quests)
	var source_str: String = data.get("quest_source", "story")
	quest.quest_source = _parse_quest_source(source_str)

	# Quest giver info
	quest.giver_npc_id = data.get("giver_npc_id", "")
	quest.giver_npc_type = data.get("giver_npc_type", "")
	quest.giver_region = data.get("giver_region", "")

	# Turn-in configuration (NEW)
	var turnin_type_str: String = data.get("turn_in_type", "npc_specific")
	quest.turn_in_type = _parse_turn_in_type(turnin_type_str)
	quest.turn_in_target = data.get("turn_in_target", data.get("turn_in_npc_id", quest.giver_npc_id))  # Fallback to giver
	quest.turn_in_region = data.get("turn_in_region", quest.giver_region)  # Fallback to giver region
	quest.turn_in_zone = data.get("turn_in_zone", "")

	# Quest chains and triggers (handle null values from JSON)
	var next_q: Variant = data.get("next_quest", "")
	quest.next_quest = next_q if next_q != null else ""
	var trigger: Variant = data.get("trigger_item", "")
	quest.trigger_item = trigger if trigger != null else ""

	# Prerequisites (quest IDs that must be completed)
	var prereqs: Array = data.get("prerequisites", [])
	for prereq in prereqs:
		quest.prerequisites.append(str(prereq))

	# Flag prerequisites (flags that must be set for quest to be available)
	var flag_prereqs: Array = data.get("flag_prerequisites", [])
	for flag_prereq: Variant in flag_prereqs:
		if flag_prereq is String:
			quest.flag_prerequisites.append(flag_prereq as String)

	# Forbidden flags (flags that must NOT be set for quest to be available)
	var forbidden: Array = data.get("forbidden_flags", [])
	for flag_forbidden: Variant in forbidden:
		if flag_forbidden is String:
			quest.forbidden_flags.append(flag_forbidden as String)

	# Objectives
	for obj_data in data.get("objectives", []):
		var obj := Objective.new()
		obj.id = obj_data.get("id", "")
		obj.description = obj_data.get("description", "")
		obj.type = obj_data.get("type", "")
		obj.target = obj_data.get("target", "")
		obj.target_zone = obj_data.get("target_zone", "")
		obj.required_count = obj_data.get("required_count", 1)
		obj.is_optional = obj_data.get("is_optional", false)
		# Timed objective support
		obj.time_limit = obj_data.get("time_limit", 0)
		obj.fail_quest_on_timeout = obj_data.get("fail_quest_on_timeout", true)
		# Dungeon spawn configuration for quest-specific content
		obj.dungeon_spawn = obj_data.get("dungeon_spawn", {})
		# OR-group membership and world-state pre-completion
		obj.group = obj_data.get("group", "")
		var obj_condition: Variant = obj_data.get("world_condition", {})
		if obj_condition is Dictionary:
			obj.world_condition = (obj_condition as Dictionary).duplicate(true)
		var obj_skill_check: Variant = obj_data.get("skill_check", {})
		if obj_skill_check is Dictionary:
			obj.skill_check = (obj_skill_check as Dictionary).duplicate(true)
		quest.objectives.append(obj)

	# Optional descriptions for the OR groups the objectives declared
	var groups_data: Variant = data.get("objective_groups", {})
	if groups_data is Dictionary:
		quest.objective_groups = (groups_data as Dictionary).duplicate(true)

	# Starter items (given to player when quest starts)
	var starter_items_data: Array = data.get("starter_items", [])
	for item_data: Variant in starter_items_data:
		if item_data is Dictionary:
			var item_dict: Dictionary = item_data as Dictionary
			quest.starter_items.append({
				"id": item_dict.get("id", ""),
				"quantity": item_dict.get("quantity", 1)
			})

	# Spawn-on-accept (spawn chests, camps, etc. when quest starts)
	var spawn_data: Array = data.get("spawn_on_accept", [])
	for spawn: Variant in spawn_data:
		if spawn is Dictionary:
			quest.spawn_on_accept.append(spawn as Dictionary)

	# Quest items (items that are quest-bound for temptation tracking)
	var quest_items_data: Array = data.get("quest_items", [])
	for item_id: Variant in quest_items_data:
		if item_id is String:
			quest.quest_items.append(item_id as String)

	# Faction for this quest
	quest.faction = data.get("faction", "")

	# Flags raised on completion. Two authored spellings, one meaning, one list.
	for completion_key: String in ["on_complete_flags", "flags_set"]:
		var completion_flags: Variant = data.get(completion_key, [])
		if not (completion_flags is Array):
			continue
		for flag: Variant in completion_flags as Array:
			if flag is String and not quest.on_complete_flags.has(flag):
				quest.on_complete_flags.append(flag as String)

	# Guild rank gate. JSON hands every number over as a float and assigning a
	# float to an int property throws, which would abort the rest of this parse.
	quest.rank_required = int(data.get("rank_required", -1))

	# Bounty cooldown (days before quest can be taken again)
	quest.cooldown_days = data.get("cooldown_days", 0)

	# Possible zones for random selection (for bounties)
	var possible_zones_data: Array = data.get("possible_zones", [])
	for zone_id: Variant in possible_zones_data:
		if zone_id is String:
			quest.possible_zones.append(zone_id as String)

	# Dungeon generation settings
	quest.dungeon_type = data.get("dungeon_type", "")
	quest.dungeon_seed = data.get("dungeon_seed", 0)
	quest.dungeon_room_set = data.get("dungeon_room_set", "")
	quest.dungeon_size = data.get("dungeon_size", "MEDIUM")

	# Choice consequence system
	var choice_consequences_data: Variant = data.get("choice_consequences", {})
	if choice_consequences_data is Dictionary:
		quest.choice_consequences = (choice_consequences_data as Dictionary).duplicate(true)

	return quest


## Parse quest source string to enum
func _parse_quest_source(source: String) -> Enums.QuestSource:
	match source.to_lower():
		"story": return Enums.QuestSource.STORY
		"npc_bounty": return Enums.QuestSource.NPC_BOUNTY
		"board_bounty": return Enums.QuestSource.BOARD_BOUNTY
		"world_object": return Enums.QuestSource.WORLD_OBJECT
		_: return Enums.QuestSource.STORY


## Parse turn-in type string to enum
func _parse_turn_in_type(turn_in: String) -> Enums.TurnInType:
	match turn_in.to_lower():
		"npc_specific": return Enums.TurnInType.NPC_SPECIFIC
		"npc_type_in_region": return Enums.TurnInType.NPC_TYPE_IN_REGION
		"world_object": return Enums.TurnInType.WORLD_OBJECT
		"auto_complete": return Enums.TurnInType.AUTO_COMPLETE
		_: return Enums.TurnInType.NPC_SPECIFIC

## Does the player hold the guild rank this quest is written for?
##
## The two gate sets - is_quest_available() and start_quest() - are duplicated
## by hand in this file, and every gate that lives in only one of them is a
## quest the board refuses to show and the engine hands over anyway. This one
## is a function so both can ask the same question.
func meets_rank_requirement(template: Quest) -> bool:
	if template.rank_required < 0:
		return true  # no rank_required authored, nothing to gate on
	if template.faction.is_empty():
		push_warning("[QuestManager] %s sets rank_required with no faction to read it against" % template.id)
		return true
	if not GuildRankManager:
		return true
	return GuildRankManager.get_guild_rank_level(template.faction) >= template.rank_required


## Start a quest
func start_quest(quest_id: String) -> bool:
	if not quest_database.has(quest_id):
		push_warning("Quest not found: " + quest_id)
		return false

	if quests.has(quest_id):
		return false  # Already active or completed

	# Check if bounty is on cooldown
	if is_bounty_on_cooldown(quest_id):
		return false

	# Check prerequisites
	var template: Quest = quest_database[quest_id]
	for prereq in template.prerequisites:
		if not quests.has(prereq) or quests[prereq].state != Enums.QuestState.COMPLETED:
			return false

	# Check flag prerequisites via FlagManager
	if FlagManager:
		if not FlagManager.check_flag_prerequisites(template.flag_prerequisites):
			return false
		if not FlagManager.check_forbidden_flags(template.forbidden_flags):
			return false

	# Check the guild rank the quest is written for
	if not meets_rank_requirement(template):
		return false

	# Create active quest from template
	var quest := Quest.new()
	quest.id = template.id
	quest.title = template.title
	quest.description = template.description
	quest.is_main_quest = template.is_main_quest
	quest.state = Enums.QuestState.ACTIVE
	quest.rewards = template.rewards.duplicate()
	quest.prerequisites = template.prerequisites.duplicate()
	quest.flag_prerequisites = template.flag_prerequisites.duplicate()
	quest.forbidden_flags = template.forbidden_flags.duplicate()

	# Copy quest source and giver info
	quest.quest_source = template.quest_source
	quest.giver_npc_id = template.giver_npc_id
	quest.giver_npc_type = template.giver_npc_type
	quest.giver_region = template.giver_region

	# Copy turn-in configuration (NEW)
	quest.turn_in_type = template.turn_in_type
	quest.turn_in_target = template.turn_in_target
	quest.turn_in_region = template.turn_in_region
	quest.turn_in_zone = template.turn_in_zone

	# Copy quest chains and triggers
	quest.next_quest = template.next_quest
	quest.trigger_item = template.trigger_item

	# Copy cooldown settings
	quest.cooldown_days = template.cooldown_days
	for zone: String in template.possible_zones:
		quest.possible_zones.append(zone)

	# Copy dungeon settings
	quest.dungeon_type = template.dungeon_type
	quest.dungeon_seed = template.dungeon_seed if template.dungeon_seed != 0 else quest_id.hash()
	quest.dungeon_room_set = template.dungeon_room_set
	quest.dungeon_size = template.dungeon_size

	# Select random zone if possible_zones is set
	var selected_zone: String = ""
	if template.possible_zones.size() > 0:
		selected_zone = template.possible_zones[randi() % template.possible_zones.size()]

	for obj in template.objectives:
		var new_obj := Objective.new()
		new_obj.id = obj.id
		new_obj.description = obj.description
		new_obj.type = obj.type
		new_obj.target = obj.target
		# Use selected random zone if possible_zones was set, otherwise use objective's target_zone
		if not selected_zone.is_empty():
			new_obj.target_zone = selected_zone
		else:
			new_obj.target_zone = obj.target_zone
		new_obj.required_count = obj.required_count
		new_obj.is_optional = obj.is_optional
		# Timed objective support
		new_obj.time_limit = obj.time_limit
		new_obj.fail_quest_on_timeout = obj.fail_quest_on_timeout
		new_obj.dungeon_spawn = obj.dungeon_spawn.duplicate(true)
		new_obj.group = obj.group
		new_obj.world_condition = obj.world_condition.duplicate(true)
		new_obj.skill_check = obj.skill_check.duplicate(true)
		quest.objectives.append(new_obj)

	# Copy the authored branch consequences so choices can fire while active
	quest.choice_consequences = template.choice_consequences.duplicate(true)
	quest.objective_groups = template.objective_groups.duplicate(true)
	for starter: Dictionary in template.starter_items:
		quest.starter_items.append(starter.duplicate())

	# Copy spawn_on_accept, quest_items, and faction
	for spawn: Dictionary in template.spawn_on_accept:
		quest.spawn_on_accept.append(spawn.duplicate())
	for item_id: String in template.quest_items:
		quest.quest_items.append(item_id)
	quest.faction = template.faction
	quest.on_complete_flags = template.on_complete_flags.duplicate()
	quest.rank_required = template.rank_required

	quests[quest_id] = quest
	quest_started.emit(quest_id)

	# Execute spawn_on_accept spawns (chests, camps, etc.)
	if template.spawn_on_accept.size() > 0:
		_execute_spawn_on_accept(quest)

	# Give starter items to player
	if template.starter_items.size() > 0:
		_give_starter_items(template.starter_items, quest.title)

	# Auto-track newly started quests (or if no quest is currently tracked)
	if tracked_quest_id.is_empty():
		set_tracked_quest(quest_id)

	# Check existing inventory for "collect" objectives (pre-collection support)
	_check_existing_inventory_for_quest(quest)

	# Settle anything the world says the player already did, then let any
	# OR groups those settlements belong to close behind them.
	_apply_world_pre_completion(quest)
	_settle_objective_groups(quest)
	_check_quest_completion(quest_id)

	# Cache objective locations for navigation
	_cache_objective_locations(quest_id)

	# Start timers for timed objectives (only for first incomplete objective)
	_start_timed_objectives_for_quest(quest)

	return true


## Give starter items to player when quest begins
func _give_starter_items(items: Array[Dictionary], quest_title: String) -> void:
	if not InventoryManager:
		push_warning("[QuestManager] InventoryManager not available for starter items")
		return

	for item_entry: Dictionary in items:
		var item_id: String = item_entry.get("id", "")
		var quantity: int = item_entry.get("quantity", 1)

		if item_id.is_empty():
			continue

		# Try to add the item to inventory
		var success: bool = InventoryManager.add_item(item_id, quantity)
		if success:
			# Show notification to player
			var item_name: String = InventoryManager.get_item_name(item_id)
			if item_name.is_empty():
				item_name = item_id
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Received: %s x%d" % [item_name, quantity])
		else:
			push_warning("[QuestManager] Failed to give starter item: %s" % item_id)


# =============================================================================
# SPAWN ON ACCEPT (Quest Chests and Camps)
# =============================================================================

## Active quest spawns: quest_id -> Array[Node] (spawned objects to cleanup on quest fail/abandon)
##
## TRANSIENT, deliberately. These are live node references, and every one of
## them is freed by the scene change a load performs, so writing them into a
## save would restore a dictionary of dangling ids that _cleanup_quest_spawns
## could do nothing with. The real gap this exposes is a different one and is
## recorded rather than invented around: a quest chest or hostage spawned by
## spawn_on_accept is not respawned after a load at all.
var _quest_spawns: Dictionary = {}

## Execute spawn_on_accept entries when quest starts
func _execute_spawn_on_accept(quest: Quest) -> void:
	if quest.spawn_on_accept.is_empty():
		return

	var spawned_nodes: Array[Node] = []

	for spawn: Dictionary in quest.spawn_on_accept:
		var spawn_type: String = spawn.get("type", "")

		match spawn_type:
			"chest":
				var node: Node = _spawn_quest_chest(spawn, quest.id)
				if node:
					spawned_nodes.append(node)
			"hostage":
				var node: Node = _spawn_quest_hostage(spawn, quest.id)
				if node:
					spawned_nodes.append(node)
			"camp":
				# Future: spawn bandit camp instance
				pass
			_:
				push_warning("[QuestManager] Unknown spawn type: %s" % spawn_type)

	if spawned_nodes.size() > 0:
		_quest_spawns[quest.id] = spawned_nodes


## Spawn a quest-specific chest at the designated location
func _spawn_quest_chest(spawn_data: Dictionary, quest_id: String) -> Node:
	var location: String = spawn_data.get("location", "")
	var coords_arr: Array = spawn_data.get("coords", [])
	var contains: Array = spawn_data.get("contains", [])
	var loot_tier_str: String = spawn_data.get("loot_tier", "common")

	# Calculate world position
	var world_pos: Vector3 = Vector3.ZERO

	if coords_arr.size() >= 3:
		# Direct world coordinates
		world_pos = Vector3(coords_arr[0], coords_arr[1], coords_arr[2])
	elif not location.is_empty():
		# Get position from location ID
		var loc_coords: Vector2i = WorldGrid.get_location_coords(location)
		if loc_coords != Vector2i.ZERO or location == "elder_moor":
			world_pos = WorldGrid.cell_to_world(loc_coords)
			# Add some random offset within the cell
			world_pos += Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))

	if world_pos == Vector3.ZERO:
		push_warning("[QuestManager] Could not determine position for quest chest in quest: %s" % quest_id)
		return null

	# Spawn the chest using our QuestChest class
	var chest_scene_path: String = "res://scripts/world/interactables/quest_chest.gd"
	var chest: Node3D = null

	# Use regular Chest class with quest tagging
	chest = Chest.spawn_chest(
		get_tree().current_scene,
		world_pos,
		"Quest Chest",
		false,  # Not locked by default
		0,
		false,  # Not persistent (disappears when emptied or quest fails)
		"quest_chest_%s" % quest_id
	)

	if not chest:
		push_warning("[QuestManager] Failed to spawn quest chest for quest: %s" % quest_id)
		return null

	# Add quest-specific contents
	for item_id: Variant in contains:
		if item_id is String:
			chest.add_item(item_id as String, 1, Enums.ItemQuality.AVERAGE)

	# Add random loot based on tier
	var tier: LootTables.LootTier = _parse_loot_tier(loot_tier_str)
	chest.setup_with_loot(tier)

	# Tag the chest with quest_id for cleanup
	chest.set_meta("quest_id", quest_id)
	chest.add_to_group("quest_spawns")

	return chest


## Spawn a quest-specific hostage at the designated location
func _spawn_quest_hostage(spawn_data: Dictionary, quest_id: String) -> Node:
	var location: String = spawn_data.get("location", "")
	var coords_arr: Array = spawn_data.get("coords", [])
	var hostage_id: String = spawn_data.get("hostage_id", "hostage")
	var hostage_name: String = spawn_data.get("name", "Hostage")
	var objective_id: String = spawn_data.get("objective_id", "")

	# Calculate world position
	var world_pos: Vector3 = Vector3.ZERO

	if coords_arr.size() >= 3:
		# Direct world coordinates
		world_pos = Vector3(coords_arr[0], coords_arr[1], coords_arr[2])
	elif not location.is_empty():
		# Get position from location ID
		var loc_coords: Vector2i = WorldGrid.get_location_coords(location)
		if loc_coords != Vector2i.ZERO or location == "elder_moor":
			world_pos = WorldGrid.cell_to_world(loc_coords)
			# Add some random offset within the cell (but closer to center)
			world_pos += Vector3(randf_range(-15, 15), 0, randf_range(-15, 15))

	if world_pos == Vector3.ZERO:
		push_warning("[QuestManager] Could not determine position for hostage in quest: %s" % quest_id)
		return null

	# Spawn the hostage using HostageNPC
	var hostage: Node = HostageNPC.spawn_hostage(
		get_tree().current_scene,
		world_pos,
		hostage_id,
		hostage_name,
		quest_id,
		objective_id
	)

	if not hostage:
		push_warning("[QuestManager] Failed to spawn hostage for quest: %s" % quest_id)
		return null

	# Tag the hostage with quest_id for cleanup
	hostage.set_meta("quest_id", quest_id)
	hostage.add_to_group("quest_spawns")

	return hostage


## Parse loot tier string to enum
func _parse_loot_tier(tier_str: String) -> LootTables.LootTier:
	match tier_str.to_lower():
		"junk": return LootTables.LootTier.JUNK
		"common": return LootTables.LootTier.COMMON
		"uncommon": return LootTables.LootTier.UNCOMMON
		"rare": return LootTables.LootTier.RARE
		"epic": return LootTables.LootTier.EPIC
		"legendary": return LootTables.LootTier.LEGENDARY
		_: return LootTables.LootTier.COMMON


## Cleanup spawned objects when quest fails or is abandoned
func _cleanup_quest_spawns(quest_id: String) -> void:
	if not _quest_spawns.has(quest_id):
		return

	var spawns: Array = _quest_spawns[quest_id]
	for node: Variant in spawns:
		if node is Node and is_instance_valid(node):
			(node as Node).queue_free()

	_quest_spawns.erase(quest_id)


# =============================================================================
# OBJECTIVE LOCATION CACHING (for navigation/compass)
# =============================================================================

## Cache objective locations when quest starts
## Resolves targets to hex coordinates for efficient navigation
func _cache_objective_locations(quest_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	var locations: Dictionary = {}

	for obj in quest.objectives:
		var location: Dictionary = _resolve_objective_location(obj)
		if not location.is_empty():
			locations[obj.id] = location

	# Also cache turn-in location if applicable
	if quest.turn_in_type != Enums.TurnInType.AUTO_COMPLETE:
		var turnin_location: Dictionary = _resolve_turnin_location(quest)
		if not turnin_location.is_empty():
			locations["_turnin"] = turnin_location

	objective_locations[quest_id] = locations


## Resolve the location of an objective target
func _resolve_objective_location(obj: Objective) -> Dictionary:
	match obj.type:
		"kill":
			return _resolve_enemy_location(obj.target)
		"collect":
			return _resolve_item_location(obj.target)
		"talk":
			# First try to find NPC locally
			var npc_loc: Dictionary = _resolve_npc_location(obj.target)
			if not npc_loc.is_empty():
				return npc_loc
			# If NPC not found and target_zone is specified, use zone location
			if obj.target_zone != "":
				return _resolve_zone_location(obj.target_zone)
			return {}
		"reach", "explore":
			return _resolve_zone_location(obj.target)
		"interact":
			return _resolve_object_location(obj.target)
		"escort":
			# Escort destination - resolve the destination zone
			if obj.target_zone != "":
				return _resolve_zone_location(obj.target_zone)
			return {}
	return {}


## Resolve enemy spawn location
## Note: Enemy locations are found dynamically in scenes, not from a registry
func _resolve_enemy_location(_enemy_type: String) -> Dictionary:
	# Enemy spawn locations are determined at runtime. The live compass resolves
	# them itself in hud_navigation._find_objective_in_current_zone().
	return {}


## Resolve item location (from world drops or containers)
func _resolve_item_location(item_id: String) -> Dictionary:
	# Items are typically found dynamically, so we check known drop sources
	# For now, return empty - items are usually collected from enemies or chests
	return {}


## Resolve NPC location
## Note: NPC locations are found dynamically in scenes, not from a registry
func _resolve_npc_location(_npc_id: String) -> Dictionary:
	# NPC locations are determined at runtime. The live compass resolves them
	# itself in hud_navigation._find_objective_in_current_zone().
	return {}


## Resolve zone/location ID to coordinates
func _resolve_zone_location(zone_id: String) -> Dictionary:
	# Check WorldGrid for location IDs
	var coords: Vector2i = WorldGrid.get_location_coords(zone_id)
	if coords != Vector2i.ZERO or zone_id == "elder_moor":
		return {
			"hex": coords,
			"zone_id": zone_id,
			"world_pos": WorldGrid.cell_to_world(coords)
		}

	return {}


## Resolve interactable object location
func _resolve_object_location(object_id: String) -> Dictionary:
	# Check for known object types
	# Bounty boards, doors, special interactables

	# For now, check WorldData for any registered location
	return _resolve_zone_location(object_id)


## Resolve turn-in location for a quest
func _resolve_turnin_location(quest: Quest) -> Dictionary:
	match quest.turn_in_type:
		Enums.TurnInType.NPC_SPECIFIC:
			return _resolve_npc_location(quest.turn_in_target)

		Enums.TurnInType.NPC_TYPE_IN_REGION:
			# Find any NPC of this type in the region
			var region: String = quest.turn_in_region if not quest.turn_in_region.is_empty() else quest.giver_region
			# Check if there's a zone hint
			if not quest.turn_in_zone.is_empty():
				return _resolve_zone_location(quest.turn_in_zone)
			# Otherwise return the region center (approximate)
			return {}

		Enums.TurnInType.WORLD_OBJECT:
			return _resolve_object_location(quest.turn_in_target)

		Enums.TurnInType.AUTO_COMPLETE:
			return {}  # No turn-in location needed

	return {}




## Get cached hex coordinates for an objective
## Returns Vector2i.ZERO if not cached or not found
func get_objective_hex(quest_id: String, objective_id: String) -> Vector2i:
	if not objective_locations.has(quest_id):
		return Vector2i.ZERO

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return Vector2i.ZERO

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("hex", Vector2i.ZERO)


## Get cached zone ID for an objective
func get_objective_zone(quest_id: String, objective_id: String) -> String:
	if not objective_locations.has(quest_id):
		return ""

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return ""

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("zone_id", "")


## Get cached world position for an objective
func get_objective_world_pos(quest_id: String, objective_id: String) -> Vector3:
	if not objective_locations.has(quest_id):
		return Vector3.ZERO

	var quest_locs: Dictionary = objective_locations[quest_id]
	if not quest_locs.has(objective_id):
		return Vector3.ZERO

	var loc: Dictionary = quest_locs[objective_id]
	return loc.get("world_pos", Vector3.ZERO)


## Get turn-in hex for a quest
func get_turnin_hex(quest_id: String) -> Vector2i:
	return get_objective_hex(quest_id, "_turnin")


## Get turn-in zone for a quest
func get_turnin_zone(quest_id: String) -> String:
	return get_objective_zone(quest_id, "_turnin")


## Clear cached locations for a quest (called when quest completes/fails)
func _clear_objective_locations(quest_id: String) -> void:
	objective_locations.erase(quest_id)


## Refresh cached locations (call if world state changes)
func refresh_objective_locations(quest_id: String) -> void:
	_clear_objective_locations(quest_id)
	_cache_objective_locations(quest_id)


## Settle "has_item" objectives against what the player is carrying right now.
##
## "collect" counts pickups; "has_item" asks a question about the pack. The
## difference matters for a quest that wants a Greater Soulstone the player may
## have owned for twenty hours before the noble ever asked - counting pickups
## would never see it. Polled when the quest is offered and again on every
## pickup, which are the only two moments the answer can change from no to yes.
func refresh_has_item_objectives(quest: Quest) -> void:
	var settled: bool = false

	for obj: Objective in quest.objectives:
		if obj.type != "has_item" or obj.is_satisfied():
			continue
		var held: int = InventoryManager.get_item_count(obj.target)
		if held < obj.required_count:
			continue
		obj.current_count = obj.required_count
		obj.is_completed = true
		obj.completion_method = "carried"
		settled = true
		quest_updated.emit(quest.id, obj.id)
		objective_completed.emit(quest.id, obj.id)

	if settled:
		_settle_objective_groups(quest)
		_check_quest_completion(quest.id)


## Check existing inventory for "collect" objectives when quest starts
## This allows pre-collected items to count toward quest progress
func _check_existing_inventory_for_quest(quest: Quest) -> void:
	refresh_has_item_objectives(quest)

	for obj in quest.objectives:
		if obj.type == "collect" and not obj.is_completed:
			# Check if player already has items in inventory
			var current_count: int = InventoryManager.get_item_count(obj.target)
			if current_count > 0:
				var to_add: int = min(current_count, obj.required_count - obj.current_count)
				if to_add > 0:
					obj.current_count += to_add
					quest_updated.emit(quest.id, obj.id)

					if obj.current_count >= obj.required_count:
						obj.is_completed = true
						objective_completed.emit(quest.id, obj.id)

## Update quest progress for a specific type
func update_progress(objective_type: String, target: String, amount: int = 1) -> void:
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			if obj.type == objective_type and obj.target == target:
				# For "talk" objectives, check if all prior required objectives are complete
				# This prevents "return to NPC" objectives from completing immediately
				if objective_type == "talk" and not are_prior_objectives_complete(quest, obj):
					continue

				obj.current_count += amount
				quest_updated.emit(quest_id, obj.id)

				if obj.current_count >= obj.required_count:
					obj.is_completed = true
					objective_completed.emit(quest_id, obj.id)

		# Check if quest is complete
		_check_quest_completion(quest_id)


## Check if all objectives before a given objective are complete
## Used to prevent "return to NPC" talk objectives from completing too early
## Made public so ConversationSystem can access it for talk objective dialogue
func are_prior_objectives_complete(quest: Quest, target_obj: Objective) -> bool:
	for obj in quest.objectives:
		# If we've reached the target objective, all prior objectives are complete
		if obj.id == target_obj.id:
			return true
		# Skip optional objectives
		if obj.is_optional:
			continue
		# If any prior required objective is incomplete, return false
		if not obj.is_satisfied():
			return false
	return true

## Track enemy kill
func on_enemy_killed(enemy_id: String) -> void:
	# Direct match (e.g., "goblin_soldier")
	update_progress("kill", enemy_id, 1)

	# Also check for category match (e.g., "goblin" matches "goblin_soldier")
	var parts := enemy_id.split("_")
	if parts.size() > 1:
		var category := parts[0]  # "goblin" from "goblin_soldier"
		update_progress("kill", category, 1)

	# Always update generic "enemies" target (matches any enemy)
	update_progress("kill", "enemies", 1)

## Track item collection
func on_item_collected(item_id: String, count: int = 1) -> void:
	update_progress("collect", item_id, count)

	# A pickup is the one moment a "has_item" question can change answer.
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state == Enums.QuestState.ACTIVE:
			refresh_has_item_objectives(quest)

## Track NPC interaction
func on_npc_talked(npc_id: String) -> void:
	update_progress("talk", npc_id, 1)

## Track location reached
func on_location_reached(location_id: String) -> void:
	update_progress("reach", location_id, 1)
	# Standing somewhere is also having explored it
	on_location_explored(location_id)


## Settle "explore" objectives for a place the player has now seen.
## Exploring is a yes/no fact, not a count, and the same arrival can arrive
## twice (cell reveal plus location reach), so a match completes the objective
## outright instead of incrementing it.
func on_location_explored(location_id: String) -> void:
	if location_id.is_empty():
		return

	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		var settled: bool = false
		for obj: Objective in quest.objectives:
			if obj.is_completed or obj.type != "explore" or obj.target != location_id:
				continue
			obj.current_count = obj.required_count
			obj.is_completed = true
			settled = true
			quest_updated.emit(quest_id, obj.id)
			objective_completed.emit(quest_id, obj.id)

		if settled:
			_check_quest_completion(quest_id)

## The skill check standing in front of an active objective that names this
## target, or {} if there is none. Whatever settles the objective asks first.
func get_objective_skill_check(objective_type: String, target: String) -> Dictionary:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue
		for obj: Objective in quest.objectives:
			if obj.is_satisfied() or obj.skill_check.is_empty():
				continue
			if obj.type == objective_type and obj.target == target:
				return obj.skill_check
	return {}


## Track object interaction
func on_interact(object_id: String) -> void:
	update_progress("interact", object_id, 1)


## Track soulstone delivery to NPC
## soulstone_id: The soulstone item ID being delivered
## npc_id: The NPC receiving the soulstone
func on_soulstone_delivered(soulstone_id: String, npc_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			# deliver_soulstone objectives match on soulstone_id (target) and optionally npc_id (target_zone)
			if obj.type == "deliver_soulstone" and obj.target == soulstone_id:
				# If target_zone is set, it specifies the required NPC
				if not obj.target_zone.is_empty() and obj.target_zone != npc_id:
					continue

				obj.current_count += 1
				quest_updated.emit(quest_id, obj.id)

				if obj.current_count >= obj.required_count:
					obj.is_completed = true
					obj.completion_method = "delivered_to:" + npc_id
					objective_completed.emit(quest_id, obj.id)
					soulstone_delivered.emit(soulstone_id, npc_id, quest_id)

		_check_quest_completion(quest_id)


## Track puzzle completion (flag-based)
## puzzle_id: The puzzle identifier (matches flag name when puzzle is solved)
func on_puzzle_solved(puzzle_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			if obj.type == "solve_puzzle" and obj.target == puzzle_id:
				obj.current_count = obj.required_count
				obj.is_completed = true
				obj.completion_method = "puzzle_solved"
				quest_updated.emit(quest_id, obj.id)
				objective_completed.emit(quest_id, obj.id)
				puzzle_solved.emit(puzzle_id, quest_id)

		_check_quest_completion(quest_id)


## Track follower recruitment
## follower_id: The NPC ID of the follower being recruited
func on_follower_recruited(follower_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			if obj.type == "recruit_follower" and obj.target == follower_id:
				obj.current_count = obj.required_count
				obj.is_completed = true
				obj.completion_method = "recruited"
				quest_updated.emit(quest_id, obj.id)
				objective_completed.emit(quest_id, obj.id)
				follower_recruited.emit(follower_id, quest_id)

		_check_quest_completion(quest_id)


## Track wave defense progress
## wave_spawner_id: The ID of the WaveSpawner node's wave_defense_id
## Called by WaveSpawner when a wave is completed
func on_wave_defense_progress(wave_spawner_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			if obj.type == "wave_defense" and obj.target == wave_spawner_id:
				obj.current_count += 1
				quest_updated.emit(quest_id, obj.id)

				if obj.current_count >= obj.required_count:
					obj.is_completed = true
					obj.completion_method = "waves_cleared"
					objective_completed.emit(quest_id, obj.id)

		_check_quest_completion(quest_id)


## Track wave defense completion (all waves cleared)
## wave_spawner_id: The ID of the WaveSpawner node's wave_defense_id
## Called by WaveSpawner when all waves are completed
func on_wave_defense_complete(wave_spawner_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			# Match both "wave_defense" and "wave_defense_complete" objective types
			if (obj.type == "wave_defense" or obj.type == "wave_defense_complete") and obj.target == wave_spawner_id:
				obj.current_count = obj.required_count  # Force complete
				obj.is_completed = true
				obj.completion_method = "all_waves_cleared"
				quest_updated.emit(quest_id, obj.id)
				objective_completed.emit(quest_id, obj.id)

		_check_quest_completion(quest_id)


## Track escort arrival at destination
## escort_id: The escort NPC's escort_id
## destination_id: The destination location ID reached
func on_escort_arrived(escort_id: String, destination_id: String) -> void:
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			# Match escort objective type with matching escort_id or destination
			if obj.type == "escort":
				# Match by escort_id (target field) or by destination
				if obj.target == escort_id or obj.target == destination_id:
					obj.current_count = obj.required_count
					obj.is_completed = true
					obj.completion_method = "escort_arrived"
					quest_updated.emit(quest_id, obj.id)
					objective_completed.emit(quest_id, obj.id)

		_check_quest_completion(quest_id)


## Track escort NPC death (fails the quest)
## escort_id: The escort NPC's escort_id
## quest_id: Optional quest_id to fail (if known)
func on_escort_died(escort_id: String, failed_quest_id: String = "") -> void:
	# If quest_id is provided, fail that specific quest
	if not failed_quest_id.is_empty() and quests.has(failed_quest_id):
		fail_quest(failed_quest_id, "escort_died")
		return

	# Otherwise, search for quests with escort objectives matching this escort_id
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.is_completed:
				continue
			# Check if this is an escort objective for the dead escort
			if obj.type == "escort" and obj.target == escort_id:
				# Fail the quest
				fail_quest(quest_id, "escort_died")
				break


## Check if quest objectives are all complete
## AUTO_COMPLETE quests will complete automatically, others require turn-in
## Settle any objective whose world-state condition already holds when the
## quest is offered. This is the "you already did this" moment: the player
## cleared the camp weeks ago, so the man asking him to clear it is thanking
## him instead of sending him.
func _apply_world_pre_completion(quest: Quest) -> void:
	var world_state: Node = get_node_or_null("/root/WorldState")
	if world_state == null:
		return

	for obj: Objective in quest.objectives:
		if obj.is_completed or obj.world_condition.is_empty():
			continue
		if not world_state.evaluate_condition(obj.world_condition):
			continue

		obj.current_count = obj.required_count
		obj.is_completed = true
		obj.completion_method = "already_done"
		quest_updated.emit(quest.id, obj.id)
		objective_completed.emit(quest.id, obj.id)


## Close OR groups. Objectives sharing a `group` id are alternative answers to
## the same problem - kill the leader, or intimidate him, or buy him off. Once
## enough members are complete (one, unless the group asks for more) the rest
## stop being work the quest is waiting on. They are marked settled rather than
## completed so the journal can say the player chose a different road instead
## of claiming he walked all three.
## Returns true if anything changed.
func _settle_objective_groups(quest: Quest) -> bool:
	var completed_per_group: Dictionary = {}
	var has_groups: bool = false

	for obj: Objective in quest.objectives:
		if obj.group.is_empty():
			continue
		has_groups = true
		if obj.is_completed:
			completed_per_group[obj.group] = int(completed_per_group.get(obj.group, 0)) + 1

	if not has_groups:
		return false

	var changed: bool = false
	for obj: Objective in quest.objectives:
		if obj.group.is_empty() or obj.is_completed or obj.is_settled:
			continue

		var required: int = 1
		var group_info: Variant = quest.objective_groups.get(obj.group, null)
		if group_info is Dictionary:
			required = maxi(1, int((group_info as Dictionary).get("required", 1)))

		if int(completed_per_group.get(obj.group, 0)) >= required:
			obj.is_settled = true
			changed = true
			quest_updated.emit(quest.id, obj.id)

	return changed


func _check_quest_completion(quest_id: String) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	# Close any OR group whose alternatives are now moot. This must happen
	# before the auto-complete gate below, and for every quest, not only the
	# auto-completing ones - a hand-turned-in quest still needs its groups shut.
	_settle_objective_groups(quest)

	# Only auto-complete if turn_in_type is AUTO_COMPLETE
	if quest.turn_in_type != Enums.TurnInType.AUTO_COMPLETE:
		return

	# Check if all required objectives are complete
	if are_objectives_complete(quest_id):
		complete_quest(quest_id)

## Check if all required objectives are complete (for NPCs to check turn-in status)
func are_objectives_complete(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		if not obj.is_optional and not obj.is_satisfied():
			return false
	return true

## Complete a quest and give rewards
## completion_type: Optional completion state (defaults to COMPLETED)
func complete_quest(quest_id: String, completion_type: Enums.QuestCompletionState = Enums.QuestCompletionState.COMPLETED) -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	quest.state = Enums.QuestState.COMPLETED
	quest.completion_state = completion_type

	# Give rewards
	if quest.rewards.has("gold"):
		InventoryManager.add_gold(quest.rewards["gold"])

	if quest.rewards.has("xp"):
		GameManager.player_data.add_ip(quest.rewards["xp"])

	if quest.rewards.has("items"):
		for item: Dictionary in normalize_reward_items(quest.rewards["items"]):
			InventoryManager.add_item(item["id"], item["quantity"])

	# Apply faction reputation rewards
	if quest.rewards.has("faction_reputation"):
		var rep_changes: Dictionary = quest.rewards["faction_reputation"]
		for faction_id: Variant in rep_changes:
			var amount: int = int(rep_changes[faction_id])
			if FactionManager:
				FactionManager.modify_reputation(faction_id as String, amount, "completed quest: %s" % quest.title)

	# NEW: Follower reward - recruit an NPC as follower
	if quest.rewards.has("follower"):
		var follower_id: String = quest.rewards["follower"]
		if not follower_id.is_empty():
			_grant_follower_reward(follower_id, quest_id)

	# NEW: Soulstone reward - grant a specific soulstone
	if quest.rewards.has("soulstone"):
		var soulstone_id: String = quest.rewards["soulstone"]
		if not soulstone_id.is_empty():
			InventoryManager.add_item(soulstone_id, 1)

	# NEW: Title reward - an honorific somebody hands you, not a rank you climb
	if quest.rewards.has("title"):
		var title: String = str(quest.rewards["title"])
		if not title.is_empty():
			GuildRankManager.grant_title(title)

	# NEW: Unlock area reward - set flag to unlock an area
	if quest.rewards.has("unlock_area"):
		var unlock_flag: String = quest.rewards["unlock_area"]
		if not unlock_flag.is_empty():
			DialogueManager.set_flag(unlock_flag)

	# NEW: Discover lore reward - unlock a lore entry in the Codex
	if quest.rewards.has("discover_lore"):
		var lore_reward: Variant = quest.rewards["discover_lore"]
		if lore_reward is String and not lore_reward.is_empty():
			if CodexManager:
				CodexManager.discover_lore(lore_reward)
		elif lore_reward is Array:
			for lore_id: String in lore_reward:
				if CodexManager and not lore_id.is_empty():
					CodexManager.discover_lore(lore_id)

	# NEW: Discover bestiary reward - unlock a bestiary entry in the Codex
	if quest.rewards.has("discover_bestiary"):
		var bestiary_reward: Variant = quest.rewards["discover_bestiary"]
		if bestiary_reward is String and not bestiary_reward.is_empty():
			if CodexManager:
				CodexManager.discover_bestiary_entry(bestiary_reward)
		elif bestiary_reward is Array:
			for creature_id: String in bestiary_reward:
				if CodexManager and not creature_id.is_empty():
					CodexManager.discover_bestiary_entry(creature_id)

	# Flags the quest promised to raise on completion, authored as
	# `on_complete_flags` or `flags_set`. Raised before the signal so anything
	# listening for the completion already sees the world it describes.
	if FlagManager:
		for completion_flag: String in quest.on_complete_flags:
			if not completion_flag.is_empty():
				FlagManager.set_flag(completion_flag)

	quest_completed.emit(quest_id)

	# Clear any active timers for this quest
	_clear_quest_timers(quest_id)

	# Set bounty cooldown if applicable
	if quest.cooldown_days > 0:
		_set_bounty_cooldown(quest_id, quest.cooldown_days)

	# Clear cached objective locations
	_clear_objective_locations(quest_id)

	# Cleanup any quest spawns (chests collected, etc.)
	_cleanup_quest_spawns(quest_id)

	# Remove from active quests so it can be taken again after cooldown
	if quest.cooldown_days > 0:
		quests.erase(quest_id)

	# Handle quest chain - auto-start next quest if specified
	var next_quest_id: String = quest.next_quest
	if not next_quest_id.is_empty():
		# Defer to avoid issues with signal handling
		call_deferred("_start_chain_quest", next_quest_id)

	# If this was the tracked quest, switch to next quest in chain or another active quest
	if tracked_quest_id == quest_id:
		if not next_quest_id.is_empty() and quest_database.has(next_quest_id):
			# Will be tracked when chain quest starts
			pass
		else:
			var active := get_active_quests()
			if active.size() > 0:
				set_tracked_quest(active[0].id)
			else:
				set_tracked_quest("")


## Start a quest from a chain (deferred call)
func _start_chain_quest(quest_id: String) -> void:
	if start_quest(quest_id):
		# Auto-track the chain quest
		set_tracked_quest(quest_id)

## Fail a quest
## reason: optional string indicating why (e.g., "temptation" for selling/equipping quest item)
func fail_quest(quest_id: String, reason: String = "") -> void:
	if not quests.has(quest_id):
		return

	var quest: Quest = quests[quest_id]
	if quest.state != Enums.QuestState.ACTIVE:
		return

	# Determine if this is a betrayal or regular failure
	if reason == "temptation" or reason == "betrayal":
		quest.state = Enums.QuestState.BETRAYED
		quest.completion_state = Enums.QuestCompletionState.BETRAYED
	else:
		quest.state = Enums.QuestState.FAILED
		quest.completion_state = Enums.QuestCompletionState.FAILED

	# Apply negative faction reputation for failing
	if not quest.faction.is_empty() and FactionManager:
		var rep_loss: int = -20  # Default reputation loss
		if reason == "temptation":
			rep_loss = -25  # Extra penalty for betrayal
		FactionManager.modify_reputation(quest.faction, rep_loss, "failed quest: %s" % quest.title)

		# Set betrayal flag if failed via temptation
		if reason == "temptation":
			FlagManager.set_flag("betrayed_%s" % quest.faction, true)

	# Clear any active timers for this quest
	_clear_quest_timers(quest_id)

	# Clear cached objective locations
	_clear_objective_locations(quest_id)

	# Cleanup quest spawns (chests, etc.)
	_cleanup_quest_spawns(quest_id)

	# Emit appropriate signal based on completion state
	if quest.completion_state == Enums.QuestCompletionState.BETRAYED:
		quest_betrayed.emit(quest_id)
	else:
		quest_failed.emit(quest_id)

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		if reason == "temptation" or reason == "betrayal":
			hud.show_notification("Quest Failed: You kept or sold a quest item!")
		else:
			hud.show_notification("Quest Failed: %s" % quest.title)

## Grant follower reward (placeholder until FollowerManager is implemented)
func _grant_follower_reward(follower_id: String, quest_id: String) -> void:
	# Set flag indicating follower is available
	DialogueManager.set_flag("follower_available:" + follower_id)
	follower_recruited.emit(follower_id, quest_id)


# =============================================================================
# CHOICE CONSEQUENCE SYSTEM
# =============================================================================

## Execute a choice consequence by choice_id for a quest
## Called from dialogue system when player makes a quest-related choice
func apply_choice_consequence(quest_id: String, choice_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]

	if not quest.choice_consequences.has(choice_id):
		# Four thieves-guild quests author their branches under `moral_choice`
		# instead, in a vocabulary of its own. Reach those the same way.
		return _apply_moral_choice(quest, choice_id)

	var consequence: Dictionary = quest.choice_consequences[choice_id]
	_execute_choice_consequence(quest_id, choice_id, consequence)
	_complete_choice_objectives(quest, choice_id)
	record_moral_choice(quest_id, choice_id)
	return true


## Apply a branch authored under a quest's `moral_choice.consequences` block.
##
## `moral_choice` is a second, hand-rolled consequence vocabulary that four
## thieves-guild quests use and NOTHING has ever read - `thieves_02`,
## `thieves_04`, `thieves_05` and `thieves_10` describe forgiving a debt,
## warning a man he is being framed, exposing a slaver, and handing the Guild
## its own legitimacy, and every one of those choices did precisely nothing.
## Two sibling quests were migrated to `choice_consequences` and these four were
## missed.
##
## Rather than rewrite the author's intent into the other vocabulary, this
## executes it. Every field it declares is honoured:
##
## | moral_choice field | what it does |
## |---|---|
## | `faction_rep` | `{faction_id: delta}` - reputation, the same call the engine vocabulary makes |
## | `flag_set` | one flag name, set on FlagManager |
## | `gold_bonus` / `gold_cost` | paid to / taken from the player |
## | `xp_bonus` | improvement points |
## | `moral_alignment` | "good" / "evil" - moves the morality score |
## | `quest_failure` | the branch loses the quest instead of completing it |
## | `alternative_reward` | `{gold, xp}` paid instead of the quest's own reward |
## | `future_impact` | prose for the reader; deliberately does nothing |
func _apply_moral_choice(quest: Quest, choice_id: String) -> bool:
	var raw: Dictionary = get_quest_data(quest.id)
	var moral: Dictionary = raw.get("moral_choice", {})
	if moral.is_empty():
		return false
	var consequences: Dictionary = moral.get("consequences", {})
	if not consequences.has(choice_id):
		return false

	var branch: Dictionary = consequences[choice_id]

	var faction_rep: Dictionary = branch.get("faction_rep", {})
	for faction_id: String in faction_rep:
		FactionManager.modify_reputation(faction_id, int(faction_rep[faction_id]))

	var flag_set: String = str(branch.get("flag_set", ""))
	if not flag_set.is_empty():
		FlagManager.set_flag(flag_set, true)

	var gold_bonus: int = int(branch.get("gold_bonus", 0))
	if gold_bonus > 0:
		InventoryManager.add_gold(gold_bonus)

	var gold_cost: int = int(branch.get("gold_cost", 0))
	if gold_cost > 0:
		InventoryManager.remove_gold(gold_cost)

	var alternative: Dictionary = branch.get("alternative_reward", {})
	if not alternative.is_empty():
		var alt_gold: int = int(alternative.get("gold", 0))
		if alt_gold > 0:
			InventoryManager.add_gold(alt_gold)
		var alt_xp: int = int(alternative.get("xp", 0))
		if alt_xp > 0 and GameManager.player_data:
			GameManager.player_data.add_ip(alt_xp)

	var xp_bonus: int = int(branch.get("xp_bonus", 0))
	if xp_bonus > 0 and GameManager.player_data:
		GameManager.player_data.add_ip(xp_bonus)

	var alignment: String = str(branch.get("moral_alignment", ""))
	if alignment == "good":
		MoralityManager.modify_morality(MORAL_CHOICE_ALIGNMENT_SHIFT, "%s: %s" % [quest.id, choice_id])
	elif alignment == "evil":
		MoralityManager.modify_morality(-MORAL_CHOICE_ALIGNMENT_SHIFT, "%s: %s" % [quest.id, choice_id])

	record_moral_choice(quest.id, choice_id)
	_complete_choice_objectives(quest, choice_id)

	if bool(branch.get("quest_failure", false)):
		fail_quest(quest.id)

	return true


## Remember which way the player went, so later content can ask.
##
## The choice itself is the point - a player who forgave Garrett's debt should
## be a different person to the Guild ever after, and that is not expressible as
## a reputation number alone.
func record_moral_choice(quest_id: String, choice_id: String) -> void:
	if quest_id.is_empty() or choice_id.is_empty():
		return
	moral_choices[quest_id] = choice_id
	# Readable from dialogue and conversation pools without a new condition type.
	FlagManager.set_flag("choice:%s:%s" % [quest_id, choice_id], true)
	moral_choice_recorded.emit(quest_id, choice_id)


## Which branch the player took on a quest, or "" if they never chose.
func get_moral_choice(quest_id: String) -> String:
	return str(moral_choices.get(quest_id, ""))


func has_moral_choice(quest_id: String, choice_id: String) -> bool:
	return get_moral_choice(quest_id) == choice_id


## Settle a quest's "choice" objectives once the player has committed to a path
func _complete_choice_objectives(quest: Quest, choice_id: String) -> void:
	var settled: bool = false

	for obj: Objective in quest.objectives:
		if obj.type != "choice" or obj.is_completed:
			continue
		# A lone choice objective is the quest's decision point whatever the
		# branch is called. Choice objectives inside an OR group are rival
		# answers, so only the one the player actually picked may complete -
		# the rest are settled as roads not taken.
		if not obj.group.is_empty() and obj.id != choice_id:
			continue
		obj.current_count = obj.required_count
		obj.is_completed = true
		obj.completion_method = choice_id
		settled = true
		objective_completed.emit(quest.id, obj.id)

	if settled:
		_check_quest_completion(quest.id)


## Internal function to execute a choice consequence
func _execute_choice_consequence(quest_id: String, choice_id: String, consequence: Dictionary) -> void:
	# Set flags
	var flags_to_set: Array = consequence.get("flags_to_set", [])
	for flag: Variant in flags_to_set:
		if flag is String and DialogueManager:
			DialogueManager.set_flag(flag as String)

	# Record durable world facts - what the world remembers, not the player's paperwork
	var world_flags: Variant = consequence.get("world_flags_to_set", [])
	if world_flags is Array:
		for flag: Variant in (world_flags as Array):
			if flag is String and WorldState:
				WorldState.set_flag(flag as String, true)
	elif world_flags is Dictionary:
		for flag: Variant in (world_flags as Dictionary).keys():
			if flag is String and WorldState:
				WorldState.set_flag(flag as String, (world_flags as Dictionary)[flag])

	# Apply reputation changes
	var rep_changes: Dictionary = consequence.get("reputation_changes", {})
	for faction_id: Variant in rep_changes:
		var amount: int = int(rep_changes[faction_id])
		if FactionManager:
			FactionManager.modify_reputation(faction_id as String, amount, "quest choice: %s" % choice_id)

	# Unlock follower
	var unlock_follower: String = consequence.get("unlock_follower", "")
	if not unlock_follower.is_empty():
		_grant_follower_reward(unlock_follower, quest_id)

	# Spawn enemy (format: "enemy_id@location_id" or just "enemy_id" for current location)
	var spawn_enemy: String = consequence.get("spawn_enemy", "")
	if not spawn_enemy.is_empty():
		_spawn_consequence_enemy(spawn_enemy)

	# Hand over items the branch promises
	var items_given: Array = consequence.get("items_given", [])
	for item_id: Variant in items_given:
		if item_id is String and InventoryManager:
			InventoryManager.add_item(item_id as String, 1)

	choice_consequence_applied.emit(quest_id, choice_id)


## Spawn an enemy as a consequence of a choice
## Format: "enemy_id" or "enemy_id@location_id"
func _spawn_consequence_enemy(spawn_data: String) -> void:
	var parts: PackedStringArray = spawn_data.split("@")
	var enemy_id: String = parts[0]
	var location_id: String = parts[1] if parts.size() > 1 else ""

	# Store as a world fact for level scripts to check and spawn. This used to
	# go to SaveManager.world_flags, which nothing anywhere read; WorldState is
	# the store a level script, a world_condition or a dialogue condition can
	# actually see. No level script reads it yet - that is content work.
	WorldState.set_flag("spawn_enemy:" + enemy_id, true)
	if not location_id.is_empty():
		WorldState.set_flag("spawn_enemy_location:" + enemy_id, location_id)


## Get active quests
func get_active_quests() -> Array[Quest]:
	var active: Array[Quest] = []
	for quest_id in quests:
		if quests[quest_id].state == Enums.QuestState.ACTIVE:
			active.append(quests[quest_id])
	return active

## Get completed quests
func get_completed_quests() -> Array[Quest]:
	var completed: Array[Quest] = []
	for quest_id in quests:
		if quests[quest_id].state == Enums.QuestState.COMPLETED:
			completed.append(quests[quest_id])
	return completed

## Get quest by ID
func get_quest(quest_id: String) -> Quest:
	return quests.get(quest_id)

## Check if quest is currently active
func is_quest_active(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	return quests[quest_id].state == Enums.QuestState.ACTIVE

## Check if quest is completed
func is_quest_completed(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	return quests[quest_id].state == Enums.QuestState.COMPLETED

## Set the tracked quest (shown on compass)
func set_tracked_quest(quest_id: String) -> void:
	if quest_id == tracked_quest_id:
		return

	# Verify quest exists and is active
	if not quest_id.is_empty() and (not quests.has(quest_id) or quests[quest_id].state != Enums.QuestState.ACTIVE):
		return

	tracked_quest_id = quest_id
	tracked_quest_changed.emit(quest_id)


## Get the currently tracked quest
func get_tracked_quest() -> Quest:
	if tracked_quest_id.is_empty():
		return null
	return quests.get(tracked_quest_id)


## Get the tracked quest ID
func get_tracked_quest_id() -> String:
	return tracked_quest_id


## Get all active kill objective targets (enemy IDs to mark on compass/minimap)
## Returns Array of dictionaries: [{target: String, quest_id: String, is_main: bool, remaining: int}]
func get_active_kill_targets() -> Array[Dictionary]:
	var targets: Array[Dictionary] = []
	for quest_id: String in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			if obj.type == "kill" and not obj.is_completed:
				targets.append({
					"target": obj.target,
					"quest_id": quest_id,
					"is_main": quest.is_main_quest,
					"remaining": obj.required_count - obj.current_count
				})
	return targets


## Check if an enemy ID matches any active kill objective target
## Returns Dictionary with match info or empty if no match
func is_enemy_quest_target(enemy_id: String) -> Dictionary:
	var kill_targets: Array[Dictionary] = get_active_kill_targets()
	for target_info: Dictionary in kill_targets:
		var target: String = target_info["target"]
		# Match exact ID or prefix (e.g., "cultist" matches "cultist_mage")
		if enemy_id == target or enemy_id.begins_with(target + "_") or target == enemy_id.split("_")[0]:
			return target_info
	return {}


## Check if a bounty is currently on cooldown
func is_bounty_on_cooldown(quest_id: String) -> bool:
	if not bounty_cooldowns.has(quest_id):
		return false
	var current_day: int = _get_current_game_day()
	var available_day: int = bounty_cooldowns[quest_id]
	return current_day < available_day


## Get the day when a bounty becomes available again
func get_bounty_available_day(quest_id: String) -> int:
	return bounty_cooldowns.get(quest_id, 0)


## Set cooldown for a bounty after completion
func _set_bounty_cooldown(quest_id: String, cooldown_days: int) -> void:
	var current_day: int = _get_current_game_day()
	var available_day: int = current_day + cooldown_days
	bounty_cooldowns[quest_id] = available_day


## Get current in-game day from GameManager
func _get_current_game_day() -> int:
	if GameManager:
		return GameManager.current_day
	return 0


## Get all available bounties (not on cooldown, not active)
func get_available_bounties() -> Array[String]:
	var available: Array[String] = []
	for quest_id: String in quest_database:
		var template: Quest = quest_database[quest_id]
		# Check if it's a bounty (has cooldown set)
		if template.cooldown_days > 0:
			# Not already active and not on cooldown
			if not quests.has(quest_id) and not is_bounty_on_cooldown(quest_id):
				available.append(quest_id)
	return available


## Get current progress for a specific objective
func get_objective_progress(quest_id: String, objective_id: String) -> int:
	if not quests.has(quest_id):
		return 0
	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		if obj.id == objective_id:
			return obj.current_count
	return 0


## Check if quest is available
func is_quest_available(quest_id: String) -> bool:
	if not quest_database.has(quest_id):
		return false
	if quests.has(quest_id):
		return false  # Already started

	var template: Quest = quest_database[quest_id]

	# Check quest prerequisites (other quests that must be completed)
	for prereq in template.prerequisites:
		if not quests.has(prereq) or quests[prereq].state != Enums.QuestState.COMPLETED:
			return false

	# Check flag prerequisites via FlagManager
	if FlagManager:
		if not FlagManager.check_flag_prerequisites(template.flag_prerequisites):
			return false
		if not FlagManager.check_forbidden_flags(template.forbidden_flags):
			return false

	# Check the guild rank the quest is written for
	if not meets_rank_requirement(template):
		return false

	return true

## Get available quests (for quest givers)
func get_available_quests() -> Array[String]:
	var available: Array[String] = []
	for quest_id in quest_database:
		if is_quest_available(quest_id):
			available.append(quest_id)
	return available


## Check if NPC has any active quest where they are the turn-in target
func has_active_quest_for_npc(npc_id: String) -> bool:
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		if quest.state == Enums.QuestState.ACTIVE:
			if quest.turn_in_type == Enums.TurnInType.NPC_SPECIFIC and quest.turn_in_target == npc_id:
				return true
	return false


## Check if NPC has any available quest they can give
func has_available_quest_from_npc(npc_id: String) -> bool:
	for quest_id in quest_database:
		if is_quest_available(quest_id):
			var template: Quest = quest_database[quest_id]
			if template.giver_npc_id == npc_id:
				return true
	return false


## Get a quest that's ready to complete with this NPC (objectives done, NPC is turn-in target)
func get_completable_quest_for_npc(npc_id: String) -> Quest:
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		if quest.state != Enums.QuestState.ACTIVE:
			continue
		if quest.turn_in_type != Enums.TurnInType.NPC_SPECIFIC:
			continue
		if quest.turn_in_target != npc_id:
			continue
		if not are_objectives_complete(quest_id):
			continue
		return quest
	return null


## Get raw quest data dictionary from JSON (for quest offers)
## Read an `items` reward block in either shape the content is written in.
##
## Two spellings exist in `data/quests/`, and only one of them was ever read:
##
##     "items": ["farmers_blessing_charm"]                 # 114 quests
##     "items": [{"id": "rope", "quantity": 2}]            # 13 quests
##
## The reward code indexed every entry with `item["id"]`, which throws on a
## String and - in GDScript - aborts the whole function. So for those 114
## quests `complete_quest` stopped at the item reward and never reached the
## faction reputation below it, nor the follower, soulstone, title, area
## unlock, lore or quest chaining after that. The quest still reported itself
## COMPLETED, because the state is set before the rewards are paid.
##
## Returns a list of `{"id": String, "quantity": int}`, skipping entries that
## name nothing. Static so the three reward-preview call sites can share it.
static func normalize_reward_items(items: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not items is Array:
		return result

	for entry: Variant in items as Array:
		if entry is String:
			var id: String = entry as String
			if not id.is_empty():
				result.append({"id": id, "quantity": 1})
		elif entry is Dictionary:
			var dict: Dictionary = entry as Dictionary
			var entry_id: String = str(dict.get("id", ""))
			if not entry_id.is_empty():
				result.append({"id": entry_id, "quantity": int(dict.get("quantity", 1))})

	return result


## The full authored contents of a quest's .json - every key, not just the ones
## the Quest object models.
##
## This used to guess the file's location: "res://data/quests/<id>.json", flat,
## no subdirectories. Every quest under bounties/, chains/, guild/**,
## kazan_dun/ and temple/ - which is most of them - failed that existence test
## and fell through to a four-key stand-in built from the Quest object, losing
## objectives, prerequisites, giver and turn-in ids, choice_consequences and
## moral_choice. It never errored; callers just got a quest with no objectives
## and carried on.
##
## The walk that loads the database already knows where every file is, so it
## records both the path and the parsed contents and this function serves them.
func get_quest_data(quest_id: String) -> Dictionary:
	if quest_raw_json.has(quest_id):
		var raw: Dictionary = quest_raw_json[quest_id]
		return raw

	# A quest that was never in the database at all (a runtime bounty, say).
	if quest_database.has(quest_id):
		var quest: Quest = quest_database[quest_id]
		return {
			"id": quest.id,
			"title": quest.title,
			"description": quest.description,
			"rewards": quest.rewards
		}
	return {}


## Where a quest's .json lives on disk, or "" for quests that came from nowhere.
func get_quest_json_path(quest_id: String) -> String:
	return str(quest_json_paths.get(quest_id, ""))


## Set the quest giver NPC for a quest (used for dynamic quests like bounties)
func set_quest_giver(quest_id: String, npc_id: String) -> void:
	if quests.has(quest_id):
		quests[quest_id].giver_npc_id = npc_id


## Set the quest giver NPC type and region (for group turn-ins)
func set_quest_giver_info(quest_id: String, npc_id: String, npc_type: String, region: String) -> void:
	if quests.has(quest_id):
		quests[quest_id].giver_npc_id = npc_id
		quests[quest_id].giver_npc_type = npc_type
		quests[quest_id].giver_region = region


## Set turn-in configuration for a quest (for dynamic quests like bounties)
func set_turn_in_info(quest_id: String, turn_in_type: Enums.TurnInType, target: String, region: String = "", zone: String = "") -> void:
	if quests.has(quest_id):
		quests[quest_id].turn_in_type = turn_in_type
		quests[quest_id].turn_in_target = target
		quests[quest_id].turn_in_region = region
		quests[quest_id].turn_in_zone = zone


## Get the quest giver NPC ID for a quest
func get_quest_giver(quest_id: String) -> String:
	if quests.has(quest_id):
		return quests[quest_id].giver_npc_id
	return ""


# =============================================================================
# CENTRAL TURN-IN SYSTEM
# =============================================================================

## Check if an entity can accept turn-in for a specific quest
## Entity must have npc_id/object_id and npc_type/region_id properties as needed
func can_accept_turnin(entity: Node, quest_id: String) -> bool:
	var entity_npc_id: String = entity.get("npc_id") if "npc_id" in entity else ""
	var entity_npc_type: String = entity.get("npc_type") if "npc_type" in entity else ""
	var entity_region: String = entity.get("region_id") if "region_id" in entity else ""

	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]

	# Quest must be active
	if quest.state != Enums.QuestState.ACTIVE:
		return false

	# Primary objectives must be complete
	if not _are_primary_objectives_complete(quest_id):
		return false

	# Check based on turn-in type
	match quest.turn_in_type:
		Enums.TurnInType.NPC_SPECIFIC:
			# Entity must match exact NPC ID
			var matches: bool = entity_npc_id == quest.turn_in_target
			return matches

		Enums.TurnInType.NPC_TYPE_IN_REGION:
			# Entity must match NPC type and be in correct region
			# Also check giver_region if turn_in_region is empty (fallback)
			var required_region: String = quest.turn_in_region if not quest.turn_in_region.is_empty() else quest.giver_region
			var type_matches: bool = entity_npc_type == quest.turn_in_target
			var region_matches: bool = required_region.is_empty() or entity_region == required_region
			var matches: bool = type_matches and region_matches
			return matches

		Enums.TurnInType.WORLD_OBJECT:
			# Entity must match object ID
			var entity_object_id: String = entity.get("object_id") if "object_id" in entity else ""
			var matches: bool = entity_object_id == quest.turn_in_target
			return matches

		Enums.TurnInType.AUTO_COMPLETE:
			# Auto-complete quests don't need entity turn-in
			return false

	return false


## Attempt to turn in a quest to an entity
## Returns {success: bool, rewards: Dictionary, message: String}
func try_turnin(entity: Node, quest_id: String) -> Dictionary:
	if not can_accept_turnin(entity, quest_id):
		return {
			"success": false,
			"rewards": {},
			"message": "Cannot turn in this quest here."
		}

	var quest: Quest = quests[quest_id]

	# Complete the quest and give rewards
	complete_quest(quest_id)

	return {
		"success": true,
		"rewards": quest.rewards.duplicate(),
		"message": "Quest completed: " + quest.title
	}


## Get all quests that an entity can accept turn-in for
func get_turnin_quests_for_entity(entity: Node) -> Array[String]:
	var turnin_quests: Array[String] = []

	for quest_id in quests:
		if can_accept_turnin(entity, quest_id):
			turnin_quests.append(quest_id)

	return turnin_quests


## Get quests completable by an NPC of a specific type in a specific region
## Used for "any guard in this region can accept turn-in" feature
func get_completable_quests_for_npc_type(npc_type: String, region: String) -> Array[String]:
	var completable: Array[String] = []
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		# Quest must be active
		if quest.state != Enums.QuestState.ACTIVE:
			continue
		# Quest must have matching NPC type and region (or be in same region with matching type)
		if quest.giver_npc_type == npc_type and quest.giver_region == region:
			# Check if PRIMARY objectives are complete (ignore "talk" return objectives)
			# This allows guards to accept turn-in even if the "return_to_giver" talk objective
			# was meant for a different NPC
			if _are_primary_objectives_complete(quest_id):
				completable.append(quest_id)
	return completable


## Check if primary objectives (kill, collect, destroy, reach, interact) are complete
## Ignores "talk" objectives which are for specific NPC turn-ins
func _are_primary_objectives_complete(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false

	var quest: Quest = quests[quest_id]
	for obj in quest.objectives:
		# Skip optional objectives
		if obj.is_optional:
			continue
		# Skip "talk" objectives - these are for specific NPC turn-ins, not guards
		if obj.type == "talk":
			continue
		# If any non-talk required objective is incomplete, return false
		if not obj.is_satisfied():
			return false
	return true


# =============================================================================
# DUNGEON GENERATION INTEGRATION
# =============================================================================

## Generate a dungeon for a quest (called when player enters dungeon area)
## Returns true if dungeon generation started successfully
## Note: Uses SimpleDungeons addon for procedural generation
func generate_quest_dungeon(quest_id: String) -> bool:
	if not quests.has(quest_id):
		push_warning("[QuestManager] Quest not found for dungeon generation: %s" % quest_id)
		return false

	var quest: Quest = quests[quest_id]

	# No dungeon configured for this quest
	if quest.dungeon_type.is_empty() and quest.dungeon_room_set.is_empty():
		push_warning("[QuestManager] Quest has no dungeon configuration: %s" % quest_id)
		return false

	# Quest dungeons use hand-crafted levels or SimpleDungeons via DungeonManager
	# This stub exists for future procedural quest dungeon integration
	push_warning("[QuestManager] Procedural quest dungeon generation not yet integrated")
	return false


## Check if a quest has a dungeon that needs to be generated
func quest_has_dungeon(quest_id: String) -> bool:
	if not quests.has(quest_id):
		return false
	var quest: Quest = quests[quest_id]
	return not quest.dungeon_type.is_empty() or not quest.dungeon_room_set.is_empty()


## Get dungeon info for a quest (for UI display)
func get_quest_dungeon_info(quest_id: String) -> Dictionary:
	if not quests.has(quest_id):
		return {}
	var quest: Quest = quests[quest_id]
	return {
		"type": quest.dungeon_type,
		"seed": quest.dungeon_seed,
		"room_set": quest.dungeon_room_set,
		"size": quest.dungeon_size
	}


## Get all dungeon spawn requirements for active quests targeting a specific dungeon
## Returns array of spawn configs: [{quest_id, objective_id, spawn_type, entity_id, room_type, count}]
func get_dungeon_spawn_requirements(dungeon_id: String) -> Array[Dictionary]:
	var spawns: Array[Dictionary] = []

	for quest_id in quests:
		var quest: Quest = quests[quest_id]

		# Only active quests
		if quest.state != Enums.QuestState.ACTIVE:
			continue

		for obj in quest.objectives:
			# Skip completed objectives
			if obj.is_completed:
				continue

			# Check if this objective has dungeon spawn config
			if obj.dungeon_spawn.is_empty():
				continue

			var spawn_dungeon_id: String = obj.dungeon_spawn.get("dungeon_id", "")

			# Match dungeon ID (or empty means "any dungeon this quest generates")
			if not spawn_dungeon_id.is_empty() and spawn_dungeon_id != dungeon_id:
				continue

			spawns.append({
				"quest_id": quest_id,
				"objective_id": obj.id,
				"spawn_type": obj.dungeon_spawn.get("spawn_type", "enemy"),
				"entity_id": obj.dungeon_spawn.get("entity_id", obj.target),
				"room_type": obj.dungeon_spawn.get("room_type", "any"),
				"guaranteed_count": obj.dungeon_spawn.get("guaranteed_count", obj.required_count),
			})

	return spawns


## Get all enemy types that should be guaranteed in a dungeon for active quests
func get_quest_guaranteed_enemies(dungeon_id: String) -> Dictionary:
	# Returns: {enemy_id: minimum_count}
	var enemies: Dictionary = {}

	var spawns: Array[Dictionary] = get_dungeon_spawn_requirements(dungeon_id)
	for spawn in spawns:
		if spawn.spawn_type == "enemy":
			var enemy_id: String = spawn.entity_id
			var count: int = spawn.guaranteed_count
			if enemies.has(enemy_id):
				enemies[enemy_id] = maxi(enemies[enemy_id], count)
			else:
				enemies[enemy_id] = count

	return enemies


## Serialize for saving
func to_dict() -> Dictionary:
	var data := {
		"tracked_quest_id": tracked_quest_id,
		"quests": {},
		"bounty_cooldowns": bounty_cooldowns.duplicate(),
		"timed_objectives": _timed_objectives.duplicate(),
		"paused_timers": _paused_timers.duplicate(),
		"moral_choices": moral_choices.duplicate()
	}
	for quest_id in quests:
		var quest: Quest = quests[quest_id]
		var quest_data := {
			"state": quest.state,
			"completion_state": quest.completion_state,  # NEW: Detailed completion outcome
			# Quest source and giver
			"quest_source": quest.quest_source,
			"giver_npc_id": quest.giver_npc_id,
			"giver_npc_type": quest.giver_npc_type,
			"giver_region": quest.giver_region,
			# Turn-in configuration
			"turn_in_type": quest.turn_in_type,
			"turn_in_target": quest.turn_in_target,
			"turn_in_region": quest.turn_in_region,
			"turn_in_zone": quest.turn_in_zone,
			# Quest chains
			"next_quest": quest.next_quest,
			# Dungeon settings
			"dungeon_type": quest.dungeon_type,
			"dungeon_seed": quest.dungeon_seed,
			"dungeon_room_set": quest.dungeon_room_set,
			"dungeon_size": quest.dungeon_size,
			# Choice consequences (if any were defined)
			"choice_consequences": quest.choice_consequences.duplicate(true),
			"objectives": []
		}
		for obj in quest.objectives:
			quest_data.objectives.append({
				"id": obj.id,
				"current_count": obj.current_count,
				"is_completed": obj.is_completed,
				"completion_method": obj.completion_method,  # NEW: How objective was completed
				"is_settled": obj.is_settled  # A sibling in this objective's OR group answered it
			})
		data.quests[quest_id] = quest_data
	return data

## Deserialize from save
func from_dict(data: Dictionary) -> void:
	quests.clear()

	# Restore bounty cooldowns
	bounty_cooldowns = data.get("bounty_cooldowns", {}).duplicate()

	# Handle both old format (quest_id -> data) and new format ({tracked_quest_id, quests})
	var quests_data: Dictionary = data.get("quests", data)  # Fallback to old format
	tracked_quest_id = data.get("tracked_quest_id", "")
	moral_choices = data.get("moral_choices", {})

	for quest_id in quests_data:
		# Skip non-quest keys from new format
		if quest_id in ["tracked_quest_id", "quests", "moral_choices", "bounty_cooldowns", "timed_objectives", "paused_timers"]:
			continue

		if not quest_database.has(quest_id):
			continue

		var template: Quest = quest_database[quest_id]
		var quest := Quest.new()
		quest.id = template.id
		quest.title = template.title
		quest.description = template.description
		quest.is_main_quest = template.is_main_quest
		quest.trigger_item = template.trigger_item
		quest.faction = template.faction
		quest.on_complete_flags = template.on_complete_flags.duplicate()
		quest.rank_required = template.rank_required
		quest.cooldown_days = template.cooldown_days
		quest.objective_groups = template.objective_groups.duplicate(true)
		for zone: String in template.possible_zones:
			quest.possible_zones.append(zone)
		for spawn: Dictionary in template.spawn_on_accept:
			quest.spawn_on_accept.append(spawn.duplicate(true))
		for starter: Dictionary in template.starter_items:
			quest.starter_items.append(starter.duplicate())
		for quest_item_id: String in template.quest_items:
			quest.quest_items.append(quest_item_id)
		quest.state = quests_data[quest_id].get("state", Enums.QuestState.ACTIVE)
		quest.completion_state = quests_data[quest_id].get("completion_state", Enums.QuestCompletionState.NONE)
		quest.rewards = template.rewards.duplicate()
		quest.prerequisites = template.prerequisites.duplicate()
		quest.flag_prerequisites = template.flag_prerequisites.duplicate()
		quest.forbidden_flags = template.forbidden_flags.duplicate()
		quest.choice_consequences = template.choice_consequences.duplicate(true)
		# Restore quest source and giver info from save or fall back to template
		quest.quest_source = quests_data[quest_id].get("quest_source", template.quest_source)
		quest.giver_npc_id = quests_data[quest_id].get("giver_npc_id", template.giver_npc_id)
		quest.giver_npc_type = quests_data[quest_id].get("giver_npc_type", template.giver_npc_type)
		quest.giver_region = quests_data[quest_id].get("giver_region", template.giver_region)

		# Restore turn-in configuration
		quest.turn_in_type = quests_data[quest_id].get("turn_in_type", template.turn_in_type)
		quest.turn_in_target = quests_data[quest_id].get("turn_in_target", template.turn_in_target)
		quest.turn_in_region = quests_data[quest_id].get("turn_in_region", template.turn_in_region)
		quest.turn_in_zone = quests_data[quest_id].get("turn_in_zone", template.turn_in_zone)

		# Restore quest chain info (handle null values)
		var saved_next: Variant = quests_data[quest_id].get("next_quest", template.next_quest)
		quest.next_quest = saved_next if saved_next != null else ""

		# Restore dungeon settings
		quest.dungeon_type = quests_data[quest_id].get("dungeon_type", template.dungeon_type)
		quest.dungeon_seed = quests_data[quest_id].get("dungeon_seed", template.dungeon_seed)
		quest.dungeon_room_set = quests_data[quest_id].get("dungeon_room_set", template.dungeon_room_set)
		quest.dungeon_size = quests_data[quest_id].get("dungeon_size", template.dungeon_size)

		var saved_objectives: Array = quests_data[quest_id].get("objectives", [])
		for i in range(template.objectives.size()):
			var obj := Objective.new()
			var t_obj: Objective = template.objectives[i]
			obj.id = t_obj.id
			obj.description = t_obj.description
			obj.type = t_obj.type
			obj.target = t_obj.target
			obj.target_zone = t_obj.target_zone
			obj.required_count = t_obj.required_count
			obj.is_optional = t_obj.is_optional
			# Timed objective settings from template
			obj.time_limit = t_obj.time_limit
			obj.fail_quest_on_timeout = t_obj.fail_quest_on_timeout
			obj.dungeon_spawn = t_obj.dungeon_spawn.duplicate(true)
			obj.group = t_obj.group
			obj.world_condition = t_obj.world_condition.duplicate(true)
			obj.skill_check = t_obj.skill_check.duplicate(true)

			# Restore progress
			for saved in saved_objectives:
				if saved.id == obj.id:
					obj.current_count = saved.get("current_count", 0)
					obj.is_completed = saved.get("is_completed", false)
					obj.completion_method = saved.get("completion_method", "")
					obj.is_settled = saved.get("is_settled", false)
					break

			quest.objectives.append(obj)

		quests[quest_id] = quest

	# Validate tracked quest still exists and is active
	if not tracked_quest_id.is_empty():
		if not quests.has(tracked_quest_id) or quests[tracked_quest_id].state != Enums.QuestState.ACTIVE:
			# Track first active quest instead
			var active := get_active_quests()
			tracked_quest_id = active[0].id if active.size() > 0 else ""

	# Restore timed objectives (timers that were running when saved)
	_timed_objectives.clear()
	_paused_timers.clear()
	var saved_timers: Dictionary = data.get("timed_objectives", {})
	for key: String in saved_timers:
		var time_remaining: float = saved_timers[key]
		if time_remaining > 0:
			_timed_objectives[key] = time_remaining
	# A timer paused for a cutscene or a menu must come back paused, not lost
	# and not running.
	var saved_paused: Dictionary = data.get("paused_timers", {})
	for key: String in saved_paused:
		var paused_remaining: float = saved_paused[key]
		if paused_remaining > 0:
			_paused_timers[key] = paused_remaining


## Reset quest state for a new game (called from death screen "New Game")
func reset_for_new_game() -> void:
	# Clear all active quests
	quests.clear()
	tracked_quest_id = ""

	# Clear objective location cache
	objective_locations.clear()
