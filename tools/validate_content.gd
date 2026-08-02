extends SceneTree
## Content wiring validator.
##
## Usage: godot --headless --path . --script res://tools/validate_content.gd
##
## Checks that content data references resolve:
##   - quest giver / turn-in / talk-objective NPC ids resolve to a spawnable NPC
##   - quest reward item ids resolve to data/items/
##   - encounter table entries resolve to a real enemy .tres
##   - enemy .tres sprite/icon/attack/death paths exist on disk
##   - dialogue action type strings are parseable by DialogueLoader
##
## Writes docs/audits/validation_report.md and exits non-zero on any error.

const REPORT_PATH := "res://docs/audits/validation_report.md"

const QUEST_DIR := "res://data/quests"
## Quest rewards name weapons, armour and spells by the same id space as items,
## and InventoryManager resolves all four, so all four count as "an item exists".
const ITEM_DIRS: Array[String] = [
	"res://data/items",
	"res://data/weapons",
	"res://data/armor",
	"res://data/spells",
]
const ENEMY_DIR := "res://data/enemies"
const NPC_DIR := "res://data/npcs"
const DIALOGUE_DIRS: Array[String] = ["res://data/dialogue", "res://data/dialogues"]
const SCRIPT_DIRS: Array[String] = ["res://scripts"]
const SCENE_DIRS: Array[String] = ["res://scenes"]

const ENCOUNTER_MANAGER_PATH := "res://scripts/autoload/encounter_manager.gd"
const DIALOGUE_LOADER_PATH := "res://scripts/dialogue/dialogue_loader.gd"
const QUEST_MANAGER_PATH := "res://scripts/autoload/quest_manager.gd"

## Keys that are notes to the reader by convention, allowed anywhere a
## vocabulary is otherwise closed. Everything else must be dispatched.
const ANNOTATION_KEYS: Array[String] = ["notes", "description", "note", "comment"]

## NPC ids produced at runtime by format strings or marker-name defaults that no
## static scan can see. Referencing quests are reported as warnings, not errors.
const DYNAMIC_ID_PREFIXES: Array[String] = ["kd_", "kazan_dun_"]

## Quest "npc" ids that are world objects, not people: boards, shrines and
## triggers the player interacts with. They are spawned by their own classes
## (BountyBoard, etc.), so an NPC scan can never see them and must not fail.
## Add an id here only when a real interactable of that kind exists in-world.
const INTERACTABLE_IDS: Array[String] = [
	"bounty_board",
	"guild_contract_board",
	"temporal_echo_trigger",
]

## Ids that exist in quest text as narrative placeholders and are deliberately
## never spawned - a rumour's subject, an off-screen authority. They are
## reported as warnings so the list stays visible instead of silently rotting.
## Every entry needs a row in docs/audits/wave_b_dispositions.md naming the
## question that blocks it. Nothing goes on this list to make a number move.
const LORE_ONLY_IDS: Array[String] = [
	# The missing king. The bible's first [OPEN] question is whether this game
	# reaches his cave at all, so he must not be standing in a room.
	"king_aldric",
	# Act II, inside the capital's politics. The society is unnamed and touches
	# the elf-claimant plot, which is Act II's main side quest.
	"secret_society_contact",
	"capital_informant",
	# The bible leaves the elven lands' position [OPEN], and what the king did
	# for the elves [OPEN]. Both of these characters exist to answer those.
	"elven_elder_witness",
	"elven_guide",
	# East Hollow's grid cell points at the *destroyed* hamlet scene. The
	# diplomacy quest predates the destruction; which of the two is canon is a
	# world-design call.
	"village_elder_east_hollow",
	# southern_outpost has no scene at all.
	"garrison_commander",
]

## Consequence keys QuestManager actually executes; anything else in a
## choice_consequences entry is a note to the reader and never fires.
const CONSEQUENCE_KEYS: Array[String] = [
	"flags_to_set",
	"world_flags_to_set",
	"reputation_changes",
	"unlock_follower",
	"spawn_enemy",
	"items_given",
]

const FACTION_DIR := "res://data/factions"

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

var npc_ids: Dictionary = {}
var item_ids: Dictionary = {}
var enemy_ids: Dictionary = {}
var faction_ids: Dictionary = {}
var invoked_choices: Dictionary = {}


func _initialize() -> void:
	_collect_item_ids()
	_collect_enemy_ids()
	_collect_npc_ids()
	_collect_faction_ids()
	_collect_invoked_choices()

	_load_schedules()

	_check_quests()
	_check_encounter_tables()
	_check_enemy_sprites()
	_check_dialogue_actions()
	_check_schedules()
	_check_quest_npc_daytime_reachability()

	var failed: bool = _write_report()
	quit(1 if failed else 0)


# --- id collection -----------------------------------------------------------

func _collect_item_ids() -> void:
	for dir: String in ITEM_DIRS:
		for path: String in _walk(dir, ".tres"):
			var id: String = _read_field(path, "id")
			if not id.is_empty():
				item_ids[id] = path


func _collect_faction_ids() -> void:
	for path: String in _walk(FACTION_DIR, ".tres"):
		faction_ids[path.get_file().get_basename()] = path


## Harvests every "quest_id:choice_id" an apply_choice_consequence action names,
## from dialogue JSON and from any script that calls QuestManager directly.
func _collect_invoked_choices() -> void:
	var json_re := RegEx.new()
	json_re.compile("\"apply_choice_consequence\"[^}]*?\"param(?:_string)?\"\\s*:\\s*\"([^\"]+)\"")
	for dir: String in DIALOGUE_DIRS:
		for path: String in _walk(dir, ".json"):
			var text: String = _read_text(path)
			for m: RegExMatch in json_re.search_all(text):
				invoked_choices[m.get_string(1)] = path

	var call_re := RegEx.new()
	call_re.compile("apply_choice_consequence\\(\\s*\"([^\"]+)\"\\s*,\\s*\"([^\"]+)\"")
	# World objects carry their branch as one "quest_id:choice_id" string and
	# split it at runtime - QuestInteractable.choice_consequence. A branch a
	# lever fires is every bit as reachable as one a dialogue choice fires.
	var field_re := RegEx.new()
	field_re.compile("choice_consequence\\s*(?::\\s*String)?\\s*=\\s*\"([^\"]+)\"")
	for dir: String in SCRIPT_DIRS:
		for path: String in _walk(dir, ".gd"):
			var text: String = _read_text(path)
			for m: RegExMatch in call_re.search_all(text):
				invoked_choices["%s:%s" % [m.get_string(1), m.get_string(2)]] = path
			for m: RegExMatch in field_re.search_all(text):
				invoked_choices[m.get_string(1)] = path


func _collect_enemy_ids() -> void:
	for path: String in _walk(ENEMY_DIR, ".tres"):
		var id: String = _read_field(path, "id")
		if not id.is_empty():
			enemy_ids[id] = path


func _collect_npc_ids() -> void:
	for path: String in _walk(NPC_DIR, ".tres"):
		var id: String = _read_field(path, "npc_id")
		if not id.is_empty():
			npc_ids[id] = path

	var scene_re := RegEx.new()
	scene_re.compile("(?m)^(?:metadata/)?npc_id\\s*=\\s*\"([^\"]+)\"")
	for dir: String in SCENE_DIRS:
		for path: String in _walk(dir, ".tscn"):
			var text: String = _read_text(path)
			for m: RegExMatch in scene_re.search_all(text):
				_register_npc_id(m.get_string(1), path)

	var assign_re := RegEx.new()
	assign_re.compile("npc_id\\s*(?::\\s*String)?\\s*=\\s*\"([^\"]+)\"")
	for dir: String in SCRIPT_DIRS:
		for path: String in _walk(dir, ".gd"):
			var text: String = _read_text(path)
			for m: RegExMatch in assign_re.search_all(text):
				_register_npc_id(m.get_string(1), path)
			_collect_spawn_call_ids(text, path)


func _register_npc_id(id: String, source: String) -> void:
	if id.is_empty() or id.contains("%"):
		return
	npc_ids[id] = source


## Which argument of each NPC spawn factory carries the id. The QuestGiver
## family takes it at index 3; HostageNPC takes it at index 2.
const SPAWN_FACTORY_ID_ARG: Dictionary = {
	"spawn_quest_giver": 3,
	"spawn_from_registry": 3,
	"spawn_townsfolk": 3,
	"spawn_hostage": 2,
}


## Extracts the npc id argument from NPC spawn factory calls.
## spawn_quest_giver derives one from the display name when the id is blank.
func _collect_spawn_call_ids(text: String, source: String) -> void:
	for fn: String in SPAWN_FACTORY_ID_ARG:
		var id_index: int = SPAWN_FACTORY_ID_ARG[fn]
		var search_from: int = 0
		while true:
			var idx: int = text.find(fn + "(", search_from)
			if idx == -1:
				break
			var open_paren: int = idx + fn.length()
			var args: Array[String] = _split_call_args(text, open_paren)
			search_from = idx + fn.length()
			if args.size() <= id_index:
				continue
			var id_arg: String = _literal_of(args[id_index])
			if id_arg.is_empty() and fn == "spawn_quest_giver":
				id_arg = _literal_of(args[2]).to_lower().replace(" ", "_")
			_register_npc_id(id_arg, source)


## Returns the top-level comma-separated arguments of a call whose opening
## parenthesis sits at open_paren. Empty if the call is unbalanced.
func _split_call_args(text: String, open_paren: int) -> Array[String]:
	var args: Array[String] = []
	var depth: int = 0
	var in_string: bool = false
	var current: String = ""
	var i: int = open_paren
	while i < text.length():
		var c: String = text[i]
		if in_string:
			if c == "\\":
				current += c
				i += 1
				if i < text.length():
					current += text[i]
				i += 1
				continue
			if c == "\"":
				in_string = false
			current += c
		elif c == "\"":
			in_string = true
			current += c
		elif c == "#":
			# Skip a line comment; its commas are not argument separators.
			while i < text.length() and text[i] != "\n":
				i += 1
			continue
		elif c == "(" or c == "[" or c == "{":
			depth += 1
			if depth > 1:
				current += c
		elif c == ")" or c == "]" or c == "}":
			depth -= 1
			if depth == 0:
				args.append(current)
				return args
			current += c
		elif c == "," and depth == 1:
			args.append(current)
			current = ""
		else:
			current += c
		i += 1
	return []


## Returns the contents of a quoted string literal argument, or "" if the
## argument is a variable, null, or an expression.
func _literal_of(arg: String) -> String:
	var trimmed: String = arg.strip_edges()
	# Strip trailing line comments so a commented argument does not confuse us.
	var comment: int = trimmed.find("#")
	if comment != -1:
		trimmed = trimmed.substr(0, comment).strip_edges()
	if trimmed.length() >= 2 and trimmed.begins_with("\"") and trimmed.ends_with("\""):
		return trimmed.substr(1, trimmed.length() - 2)
	return ""


# --- checks ------------------------------------------------------------------

## Quest staging directories (a leading underscore, e.g. data/quests/_future/)
## are not shipped content: QuestManager skips them too. They are counted in the
## report so the staging area stays visible instead of silently rotting, but
## they do not gate.
var staging_quest_count: int = 0


## The objective-type and reward-key vocabularies, read out of quest_manager.gd
## itself so this check cannot rot when either one grows. Populated once.
var handled_objective_types: Dictionary = {}
var deferred_objective_types: Dictionary = {}
var reward_keys: Dictionary = {}


## Reads the vocabularies out of the engine's own source.
##
## Tasks 46-50 were five instances of one thing: content names a key or a type
## the code does not dispatch, and nothing says so. The validator already read
## every one of these files; it checked that ids RESOLVE, never that keys are
## DISPATCHED. Both lists are parsed from source rather than copied here,
## because a copied vocabulary is the same trap one level up.
func _collect_engine_vocabularies() -> void:
	var text: String = _read_text(QUEST_MANAGER_PATH)
	if text.is_empty():
		_fail("QUEST_VOCAB", QUEST_MANAGER_PATH, "", "quest manager not readable")
		return

	handled_objective_types = _parse_const_strings(text, "HANDLED_OBJECTIVE_TYPES")
	deferred_objective_types = _parse_const_strings(text, "DEFERRED_OBJECTIVE_TYPES")

	# complete_quest() reads its rewards as quest.rewards.has("<key>").
	var reward_re := RegEx.new()
	reward_re.compile("quest\\.rewards\\.has\\(\"([a-z_]+)\"\\)")
	for m: RegExMatch in reward_re.search_all(text):
		reward_keys[m.get_string(1)] = true

	if handled_objective_types.is_empty():
		_fail("QUEST_VOCAB", QUEST_MANAGER_PATH, "HANDLED_OBJECTIVE_TYPES",
				"could not parse the objective type vocabulary")
	if reward_keys.is_empty():
		_fail("QUEST_VOCAB", QUEST_MANAGER_PATH, "rewards",
				"could not parse the reward key vocabulary from complete_quest()")


## Collects the quoted strings inside a named const block, whether it is
## declared as an Array (values) or a Dictionary (keys).
func _parse_const_strings(text: String, const_name: String) -> Dictionary:
	var found: Dictionary = {}
	var start: int = text.find("const %s" % const_name)
	if start == -1:
		return found

	# The first bracket after the name belongs to the TYPE HINT
	# (`: Array[String] =`), so anchor on the assignment instead.
	var assign: int = text.find("=", start)
	if assign == -1:
		return found
	var open_bracket: int = assign
	while open_bracket < text.length() and text[open_bracket] != "[" and text[open_bracket] != "{":
		open_bracket += 1
	if open_bracket >= text.length():
		return found

	var closer: String = "]" if text[open_bracket] == "[" else "}"
	var end: int = text.find(closer, open_bracket)
	if end == -1:
		return found

	var body: String = text.substr(open_bracket, end - open_bracket)
	var re := RegEx.new()
	re.compile("\"([a-z_]+)\"")
	for m: RegExMatch in re.search_all(body):
		found[m.get_string(1)] = true
	return found


func _check_quests() -> void:
	_collect_engine_vocabularies()
	staging_quest_count = _walk(QUEST_DIR, ".json").size() - _walk(QUEST_DIR, ".json", true).size()

	for path: String in _walk(QUEST_DIR, ".json", true):
		var quest: Dictionary = _read_json(path)
		if quest.is_empty():
			continue

		var giver: String = quest.get("giver_npc_id", "")
		_expect_npc(giver, path, "giver_npc_id")

		var turn_in_type: String = quest.get("turn_in_type", "")
		if turn_in_type == "npc_specific":
			_expect_npc(quest.get("turn_in_target", ""), path, "turn_in_target")

		var objectives: Array = quest.get("objectives", [])
		for obj: Variant in objectives:
			if not (obj is Dictionary):
				continue
			var objective: Dictionary = obj
			var obj_type: String = objective.get("type", "")
			var target: String = objective.get("target", "")
			var where: String = "objective[%s].target" % objective.get("id", "?")

			# An objective whose type no driver handles sits at 0/1 forever and
			# never throws. Ten of these shipped, and four Thieves Guild quests
			# and two Mage capstones could not be completed at all.
			if obj_type.is_empty():
				_fail("QUEST_OBJECTIVE", path, objective.get("id", "?"), "objective has no type")
			elif not handled_objective_types.has(obj_type):
				if deferred_objective_types.has(obj_type):
					_warn("QUEST_OBJECTIVE", path, obj_type,
							"%s is deferred in QuestManager.DEFERRED_OBJECTIVE_TYPES - the quest cannot be completed until it is implemented" % where)
				else:
					_fail("QUEST_OBJECTIVE", path, obj_type,
							"%s uses an objective type QuestManager dispatches nowhere, so it can never be completed" % where)

			match obj_type:
				"talk":
					_expect_npc(target, path, where)
				"kill":
					_expect_enemy(target, path, where)
				"collect":
					_expect_item(target, path, where, true)

		var rewards: Dictionary = quest.get("rewards", {})

		# complete_quest reads nine keys. Three quests spelled faction_reputation
		# as `reputation` or `reputation_changes` and were never granted it.
		for reward_key: Variant in rewards.keys():
			var key_name: String = String(reward_key)
			if reward_keys.has(key_name) or ANNOTATION_KEYS.has(key_name):
				continue
			_fail("QUEST_REWARD", path, key_name,
					"rewards.%s is not read by complete_quest(), so the reward is silently never granted" % key_name)

		var reward_items: Array = rewards.get("items", [])
		for entry: Variant in reward_items:
			if entry is String:
				_expect_item(entry, path, "rewards.items", false)

		var reward_rep: Dictionary = rewards.get("faction_reputation", {})
		for faction_id: Variant in reward_rep.keys():
			_expect_faction(String(faction_id), path, "rewards.faction_reputation")

		_check_choice_consequences(quest, path)


## Quest branches only fire when a dialogue action calls
## apply_choice_consequence "quest_id:choice_id". A branch nothing calls is
## authored data the player can never reach, so it is reported as a warning.
func _check_choice_consequences(quest: Dictionary, path: String) -> void:
	var consequences: Dictionary = quest.get("choice_consequences", {})
	if consequences.is_empty():
		return
	var quest_id: String = quest.get("id", "")

	for choice_id: Variant in consequences.keys():
		var key: String = "%s:%s" % [quest_id, choice_id]
		if not invoked_choices.has(key):
			_warn("QUEST_CHOICE", path, String(choice_id),
					"no dialogue action calls apply_choice_consequence \"%s\", so the branch is unreachable" % key)

		var entry: Variant = consequences[choice_id]
		if not (entry is Dictionary):
			_fail("QUEST_CHOICE", path, String(choice_id), "consequence is not an object")
			continue
		var consequence: Dictionary = entry

		for consequence_key: Variant in consequence.keys():
			var key_name: String = String(consequence_key)
			if CONSEQUENCE_KEYS.has(key_name):
				continue
			if ANNOTATION_KEYS.has(key_name):
				# A note to the reader is fine; a key that looks like an effect
				# and is not, is not.
				continue
			_fail("QUEST_CHOICE", path, String(choice_id),
					"consequence key \"%s\" is executed by nothing - either it is an effect QuestManager does not run, or it should be named notes/description" % key_name)

		var rep: Dictionary = consequence.get("reputation_changes", {})
		for faction_id: Variant in rep.keys():
			_expect_faction(String(faction_id), path,
					"choice[%s].reputation_changes" % choice_id)

		var spawn_enemy: String = consequence.get("spawn_enemy", "")
		if not spawn_enemy.is_empty():
			_expect_enemy(spawn_enemy.split("@")[0], path, "choice[%s].spawn_enemy" % choice_id)

		var items_given: Array = consequence.get("items_given", [])
		for item_id: Variant in items_given:
			if item_id is String:
				_expect_item(String(item_id), path, "choice[%s].items_given" % choice_id, true)


func _check_encounter_tables() -> void:
	var text: String = _read_text(ENCOUNTER_MANAGER_PATH)
	if text.is_empty():
		_fail("ENCOUNTER", ENCOUNTER_MANAGER_PATH, "", "encounter manager not readable")
		return

	var config_ids: Dictionary = {}
	var config_re := RegEx.new()
	config_re.compile("\"data_path\"\\s*:\\s*\"([^\"]+)\"")
	for m: RegExMatch in config_re.search_all(text):
		var data_path: String = m.get_string(1)
		if not FileAccess.file_exists(data_path):
			_fail("ENCOUNTER", ENCOUNTER_MANAGER_PATH, data_path,
					"ENEMY_SPAWN_CONFIG data_path does not exist")

	var key_re := RegEx.new()
	key_re.compile("(?m)^\\t\\\"([a-z_]+)\\\"\\s*:\\s*\\{")
	for m: RegExMatch in key_re.search_all(text):
		config_ids[m.get_string(1)] = true

	var entry_re := RegEx.new()
	entry_re.compile("\\{\"enemy_type\":\\s*\"([^\"]+)\",\\s*\"weight\":\\s*(\\d+)")
	var table_re := RegEx.new()
	table_re.compile("(?m)^\\t\\\"([a-z_]+)\\\"\\s*:\\s*\\[")

	var tables: Array[RegExMatch] = table_re.search_all(text)
	for i: int in tables.size():
		var table_name: String = tables[i].get_string(1)
		var start: int = tables[i].get_end()
		var end: int = text.length() if i + 1 >= tables.size() else tables[i + 1].get_start()
		var body: String = text.substr(start, end - start)
		for entry: RegExMatch in entry_re.search_all(body):
			var enemy_type: String = entry.get_string(1)
			var weight: int = int(entry.get_string(2))
			if config_ids.has(enemy_type):
				continue
			# EncounterManager falls back to deriving a config from the enemy's
			# own resource, which needs both the file and a usable sprite.
			var data_path: String = "%s/%s.tres" % [ENEMY_DIR, enemy_type]
			if not FileAccess.file_exists(data_path):
				_fail("ENCOUNTER", ENCOUNTER_MANAGER_PATH, enemy_type,
						"biome table '%s' references an enemy with no .tres and no spawn config (weight %d)"
						% [table_name, weight])
			elif _read_field(data_path, "sprite_path").is_empty():
				_fail("ENCOUNTER", ENCOUNTER_MANAGER_PATH, enemy_type,
						"biome table '%s' entry has no sprite_path, so it cannot be spawned (weight %d)"
						% [table_name, weight])


func _check_enemy_sprites() -> void:
	var fields: Array[String] = [
		"icon_path", "sprite_path", "attack_sprite_path", "death_sprite_path", "scene_path",
	]
	for path: String in _walk(ENEMY_DIR, ".tres"):
		for field: String in fields:
			var value: String = _read_field(path, field)
			if value.is_empty():
				continue
			if not FileAccess.file_exists(value):
				_fail("ENEMY_SPRITE", path, value, "%s does not exist on disk" % field)


func _check_dialogue_actions() -> void:
	var loader_text: String = _read_text(DIALOGUE_LOADER_PATH)

	# Both vocabularies are read straight out of the loader's own match
	# statements, so the check cannot rot when a case is added.
	var known_actions: Dictionary = _parse_cases(loader_text, "ActionType")
	var known_conditions: Dictionary = _parse_cases(loader_text, "ConditionType")

	if known_actions.is_empty():
		_fail("DIALOGUE", DIALOGUE_LOADER_PATH, "", "could not parse the action type table")
		return
	if known_conditions.is_empty():
		_fail("DIALOGUE", DIALOGUE_LOADER_PATH, "", "could not parse the condition type table")
		return

	for dir: String in DIALOGUE_DIRS:
		for path: String in _walk(dir, ".json"):
			var data: Dictionary = _read_json(path)
			if data.is_empty():
				continue
			for action_type: String in _harvest_types(data, "actions"):
				if not known_actions.has(action_type.to_lower()):
					_fail("DIALOGUE", path, action_type,
							"action type has no case in DialogueLoader, so it does nothing")
			# Worse than the action case: an unparsed condition used to coerce
			# to NONE, and a NONE condition PASSES. 67 gated choices in this
			# directory were ungated that way. It fails closed now, which makes
			# an unknown type hide a choice instead - either way, an error.
			for condition_type: String in _harvest_types(data, "conditions"):
				if not known_conditions.has(condition_type.to_lower()):
					_fail("DIALOGUE", path, condition_type,
							"condition type has no case in DialogueLoader, so the condition can never pass")


## Harvests the loader's `"name": return DialogueData.<enum>.` match cases.
func _parse_cases(loader_text: String, enum_name: String) -> Dictionary:
	var found: Dictionary = {}
	var re := RegEx.new()
	re.compile("(?m)^\\s*\"([a-z_]*)\"\\s*:\\s*return DialogueData\\.%s\\." % enum_name)
	for m: RegExMatch in re.search_all(loader_text):
		found[m.get_string(1)] = true
	return found


## Walks arbitrarily nested dialogue JSON collecting every "type" string that
## sits inside an array under the given key.
func _harvest_types(value: Variant, under: String, inside: bool = false) -> Array[String]:
	var found: Array[String] = []
	if value is Array:
		for entry: Variant in (value as Array):
			found.append_array(_harvest_types(entry, under, inside))
	elif value is Dictionary:
		var dict: Dictionary = value
		if inside and dict.has("type") and dict["type"] is String:
			found.append(dict["type"])
		for key: Variant in dict.keys():
			found.append_array(_harvest_types(dict[key], under, String(key) == under))
	return found


# --- schedules ---------------------------------------------------------------

const SCHEDULE_ARCHETYPE_DIR := "res://data/schedules/archetypes"
const SCHEDULE_RECORDS := "res://data/npc_schedules.json"
const SCHEDULE_ACTIONS: Array[String] = ["sleep", "travel", "work", "eat", "socialise", "idle"]

## The hours a player can reasonably expect a town to be doing business. The
## no-soft-lock rule is written against this band; night is flavour.
const SCHEDULE_DAY_FIRST := 9
const SCHEDULE_DAY_LAST := 17

## Half-extents per streaming cell, in world units, from WorldGrid's LOCATIONS
## `scene_size` where it declares one and 100x100 where it does not. Stations
## outside these were placed somewhere the cell does not reach.
##
## Dalhurst's declared 160x172 is narrower than Dalhurst's own content - the
## Seabreeze Armory stands at local x=86 against a declared half-width of 80 -
## so the bound carries a 20% tolerance and the discrepancy is a level-design
## row in wave_b_dispositions.md rather than something this validator invents a
## fix for.
const SCHEDULE_BOUNDS_TOLERANCE := 1.2

var schedule_archetypes: Dictionary = {}
var schedule_records: Dictionary = {}
var schedule_cell_bounds: Dictionary = {}


func _load_schedules() -> void:
	for path: String in _walk(SCHEDULE_ARCHETYPE_DIR, ".json"):
		var data: Dictionary = _read_json(path)
		if data.is_empty():
			continue
		schedule_archetypes[data.get("id", path.get_file().get_basename())] = data

	var doc: Dictionary = _read_json(SCHEDULE_RECORDS)
	var npcs: Variant = doc.get("npcs", {})
	if npcs is Dictionary:
		schedule_records = npcs

	# Cell half-extents, read off WorldGrid rather than restated here.
	var grid_text: String = _read_text("res://scripts/data/world_grid.gd")
	var re := RegEx.new()
	# (?s) so `.` crosses newlines: a LOCATIONS entry puts scene_size on the
	# line after the coordinates, and without it every town read as 100x100.
	re.compile('(?s)\\{"id":\\s*"([a-z_]+)".*?"x":\\s*(-?\\d+),\\s*"y":\\s*(-?\\d+),.*?(?:"scene_size":\\s*\\[(\\d+),\\s*(\\d+)\\],)?\\s*"description"')
	for m: RegExMatch in re.search_all(grid_text):
		var width: float = float(m.get_string(4)) if not m.get_string(4).is_empty() else 100.0
		var depth: float = float(m.get_string(5)) if not m.get_string(5).is_empty() else 100.0
		schedule_cell_bounds[Vector2i(int(m.get_string(2)), int(m.get_string(3)))] = Vector2(width, depth)


## Rule 1: every archetype a record names resolves.
## Rule 2: every archetype's day covers 24 hours exactly once with real actions.
## Rule 3: every scheduled npc_id is an NPC something actually spawns.
## Rule 4: every station sits inside the bounds of the cell it claims.
func _check_schedules() -> void:
	if schedule_records.is_empty():
		_warn("SCHEDULE", SCHEDULE_RECORDS, "npc_schedules", "no schedule records were loaded")
		return

	for id: String in schedule_archetypes.keys():
		var blocks: Array = (schedule_archetypes[id] as Dictionary).get("blocks", [])
		var covered: Array[int] = []
		covered.resize(24)
		for block: Variant in blocks:
			if not block is Dictionary:
				continue
			var b: Dictionary = block
			var action: String = b.get("action", "")
			if not SCHEDULE_ACTIONS.has(action):
				_fail("SCHEDULE_ARCHETYPE", SCHEDULE_ARCHETYPE_DIR, id,
						"block names action '%s', which no scheduler action matches" % action)
			var from: int = int(b.get("from", 0))
			var to: int = int(b.get("to", 0))
			for h: int in range(24):
				var inside: bool = (from <= h and h < to) if from < to else (h >= from or h < to)
				if inside:
					covered[h] += 1
		for h: int in range(24):
			if covered[h] != 1:
				_fail("SCHEDULE_ARCHETYPE", SCHEDULE_ARCHETYPE_DIR, id,
						"hour %02d is covered %d times - a gap silently becomes idle-at-work" % [h, covered[h]])

	for npc_id: String in schedule_records.keys():
		var rec: Dictionary = schedule_records[npc_id]

		var archetype: String = rec.get("archetype", "")
		if not schedule_archetypes.has(archetype):
			_fail("SCHEDULE_NPC", SCHEDULE_RECORDS, npc_id,
					"names archetype '%s', which has no file in %s" % [archetype, SCHEDULE_ARCHETYPE_DIR])

		# "Every scheduled npc_id spawns somewhere" is NOT checked here. This
		# validator reads source text, and twenty of the ids in the table are
		# spawned in ways no regex can see - Merchant.spawn_merchant assigns
		# merchant_id after construction, the Dalhurst guards are built with
		# "guard_dalhurst_%d". Asserting it from here reports twenty NPCs the
		# player can walk up to as dead data. The rule lives in
		# tools/check_living_world.tscn instead, which boots the five towns and
		# counts the nodes.

		var stations: Dictionary = rec.get("stations", {})
		if not stations.has("work"):
			_fail("SCHEDULE_NPC", SCHEDULE_RECORDS, npc_id,
					"has no work station, so there is nothing to fall back to")

		for key: String in stations.keys():
			var station: Dictionary = stations[key]
			var cell_arr: Array = station.get("cell", [])
			if cell_arr.size() < 2:
				_fail("SCHEDULE_STATION", SCHEDULE_RECORDS, npc_id,
						"station '%s' names no cell" % key)
				continue
			var cell := Vector2i(int(cell_arr[0]), int(cell_arr[1]))
			if not schedule_cell_bounds.has(cell):
				_warn("SCHEDULE_STATION", SCHEDULE_RECORDS, npc_id,
						"station '%s' sits in cell %s, which WorldGrid does not name" % [key, cell])
				continue

			var pos: Array = station.get("pos", [])
			if pos.size() < 3:
				_fail("SCHEDULE_STATION", SCHEDULE_RECORDS, npc_id,
						"station '%s' has no position" % key)
				continue

			var half: Vector2 = (schedule_cell_bounds[cell] as Vector2) * 0.5 * SCHEDULE_BOUNDS_TOLERANCE
			var local_x: float = float(pos[0]) - float(cell.x) * 100.0
			var local_z: float = float(pos[2]) - float(cell.y) * 100.0
			if absf(local_x) > half.x or absf(local_z) > half.y:
				_fail("SCHEDULE_STATION", SCHEDULE_RECORDS, npc_id,
						"station '%s' stands at (%.0f, %.0f) inside cell %s, which reaches only (%.0f, %.0f)"
						% [key, local_x, local_z, cell, half.x, half.y])


## Rule 5, the schedule-era version of the giver/receiver law: no quest may be
## soft-locked by an NPC being in bed. Every giver, turn-in and talk target with
## a schedule must be present and awake through the whole day band.
func _check_quest_npc_daytime_reachability() -> void:
	if schedule_records.is_empty():
		return

	var quest_npcs: Dictionary = {}
	for path: String in _walk(QUEST_DIR, ".json", true):
		var quest: Dictionary = _read_json(path)
		if quest.is_empty():
			continue
		for id: Variant in [quest.get("giver_npc_id", ""), quest.get("turn_in_target", "")]:
			if not String(id).is_empty():
				quest_npcs[String(id)] = path
		for obj: Variant in quest.get("objectives", []) as Array:
			if not obj is Dictionary:
				continue
			if (obj as Dictionary).get("type", "") == "talk":
				var target: String = (obj as Dictionary).get("target", "")
				if not target.is_empty():
					quest_npcs[target] = path

	for npc_id: String in quest_npcs.keys():
		if not schedule_records.has(npc_id):
			continue
		var rec: Dictionary = schedule_records[npc_id]
		var blocks: Array = (schedule_archetypes.get(rec.get("archetype", ""), {}) as Dictionary).get("blocks", [])
		var stations: Dictionary = rec.get("stations", {})

		for hour: int in range(SCHEDULE_DAY_FIRST, SCHEDULE_DAY_LAST + 1):
			var action: String = "idle"
			var station_key: String = "work"
			for block: Variant in blocks:
				if not block is Dictionary:
					continue
				var b: Dictionary = block
				var from: int = int(b.get("from", 0))
				var to: int = int(b.get("to", 0))
				var inside: bool = (from <= hour and hour < to) if from < to else (hour >= from or hour < to)
				if inside:
					action = b.get("action", "idle")
					station_key = b.get("station", "work")
					break

			if action == "sleep":
				_fail("SCHEDULE_QUEST", quest_npcs[npc_id], npc_id,
						"is asleep at %02d:00, inside the hours a player expects to find them" % hour)
				break

			var station: Dictionary = stations.get(station_key, stations.get("work", {}))
			if station.get("interior", false):
				_fail("SCHEDULE_QUEST", quest_npcs[npc_id], npc_id,
						"is behind an unmodelled door at %02d:00, so the quest cannot be started or turned in" % hour)
				break


# --- expectations ------------------------------------------------------------

func _expect_npc(id: String, path: String, where: String) -> void:
	if id.is_empty() or npc_ids.has(id):
		return
	if INTERACTABLE_IDS.has(id):
		return
	if LORE_ONLY_IDS.has(id):
		_warn("QUEST_NPC", path, id, "%s is a lore-only reference with no spawned NPC" % where)
		return
	for prefix: String in DYNAMIC_ID_PREFIXES:
		if id.begins_with(prefix):
			_warn("QUEST_NPC", path, id, "%s may be a runtime-generated id (unverifiable statically)" % where)
			return
	_fail("QUEST_NPC", path, id, "%s references an NPC that is never spawned" % where)


func _expect_item(id: String, path: String, where: String, as_warning: bool) -> void:
	if id.is_empty() or item_ids.has(id):
		return
	if as_warning:
		_warn("QUEST_ITEM", path, id, "%s references an unknown item id" % where)
	else:
		_fail("QUEST_ITEM", path, id, "%s references an unknown item id" % where)


func _expect_faction(id: String, path: String, where: String) -> void:
	if id.is_empty() or faction_ids.has(id):
		return
	_warn("QUEST_FACTION", path, id,
			"%s names a faction with no resource in data/factions, so the change is dropped" % where)


func _expect_enemy(id: String, path: String, where: String) -> void:
	if id.is_empty() or enemy_ids.has(id):
		return
	_warn("QUEST_ENEMY", path, id, "%s references an unknown enemy id" % where)


func _fail(category: String, path: String, subject: String, message: String) -> void:
	errors.append({"category": category, "path": path, "subject": subject, "message": message})


func _warn(category: String, path: String, subject: String, message: String) -> void:
	warnings.append({"category": category, "path": path, "subject": subject, "message": message})


# --- reporting ---------------------------------------------------------------

func _write_report() -> bool:
	var lines: Array[String] = []
	lines.append("# Content Validation Report")
	lines.append("")
	lines.append("Generated by `tools/validate_content.gd`.")
	lines.append("")
	lines.append("| Set | Count |")
	lines.append("|---|---|")
	lines.append("| NPC ids discovered | %d |" % npc_ids.size())
	lines.append("| Item ids discovered | %d |" % item_ids.size())
	lines.append("| Enemy ids discovered | %d |" % enemy_ids.size())
	lines.append("| Interactable ids whitelisted | %d |" % INTERACTABLE_IDS.size())
	lines.append("| Lore-only ids whitelisted | %d |" % LORE_ONLY_IDS.size())
	lines.append("| Staging quests not gated (`_future/`) | %d |" % staging_quest_count)
	lines.append("| Schedule archetypes | %d |" % schedule_archetypes.size())
	lines.append("| NPCs with a schedule record | %d |" % schedule_records.size())
	lines.append("| Errors | %d |" % errors.size())
	lines.append("| Warnings | %d |" % warnings.size())
	lines.append("")

	lines.append_array(_section("Errors", errors))
	lines.append_array(_section("Warnings", warnings))

	var report: String = "\n".join(lines) + "\n"
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(report)
		file.close()

	print(report)
	print("Errors: %d  Warnings: %d" % [errors.size(), warnings.size()])
	return not errors.is_empty()


func _section(title: String, entries: Array[Dictionary]) -> Array[String]:
	var lines: Array[String] = []
	lines.append("## %s" % title)
	lines.append("")
	if entries.is_empty():
		lines.append("None.")
		lines.append("")
		return lines

	var by_category: Dictionary = {}
	for entry: Dictionary in entries:
		var category: String = entry["category"]
		if not by_category.has(category):
			by_category[category] = []
		by_category[category].append(entry)

	var categories: Array = by_category.keys()
	categories.sort()
	for category: String in categories:
		lines.append("### %s" % category)
		lines.append("")
		lines.append("| Subject | File | Detail |")
		lines.append("|---|---|---|")
		for entry: Dictionary in by_category[category]:
			lines.append("| `%s` | `%s` | %s |" % [entry["subject"], entry["path"], entry["message"]])
		lines.append("")
	return lines


# --- io helpers --------------------------------------------------------------

func _walk(root: String, suffix: String, skip_staging: bool = false) -> Array[String]:
	var found: Array[String] = []
	var pending: Array[String] = [root]
	while not pending.is_empty():
		var dir_path: String = pending.pop_back()
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue
		dir.list_dir_begin()
		var entry: String = dir.get_next()
		while not entry.is_empty():
			if entry.begins_with(".") or (skip_staging and entry.begins_with("_") and dir.current_is_dir()):
				entry = dir.get_next()
				continue
			var full: String = dir_path.path_join(entry)
			if dir.current_is_dir():
				pending.append(full)
			elif entry.ends_with(suffix):
				found.append(full)
			entry = dir.get_next()
		dir.list_dir_end()
	found.sort()
	return found


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _read_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read_text(path))
	if parsed is Dictionary:
		return parsed
	return {}


## Reads a `field = "value"` assignment from the main [resource] block of a .tres,
## ignoring identically-named fields on embedded sub_resources.
func _read_field(path: String, field: String) -> String:
	var text: String = _read_text(path)
	var body_start: int = text.rfind("[resource]")
	if body_start != -1:
		text = text.substr(body_start)
	var re := RegEx.new()
	re.compile("(?m)^%s\\s*=\\s*\"([^\"]*)\"" % field)
	var m: RegExMatch = re.search(text)
	return "" if not m else m.get_string(1)
