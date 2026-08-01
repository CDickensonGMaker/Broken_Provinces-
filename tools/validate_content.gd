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
const LORE_ONLY_IDS: Array[String] = []

var errors: Array[Dictionary] = []
var warnings: Array[Dictionary] = []

var npc_ids: Dictionary = {}
var item_ids: Dictionary = {}
var enemy_ids: Dictionary = {}


func _initialize() -> void:
	_collect_item_ids()
	_collect_enemy_ids()
	_collect_npc_ids()

	_check_quests()
	_check_encounter_tables()
	_check_enemy_sprites()
	_check_dialogue_actions()

	var failed: bool = _write_report()
	quit(1 if failed else 0)


# --- id collection -----------------------------------------------------------

func _collect_item_ids() -> void:
	for dir: String in ITEM_DIRS:
		for path: String in _walk(dir, ".tres"):
			var id: String = _read_field(path, "id")
			if not id.is_empty():
				item_ids[id] = path


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


## Extracts the npc id argument from QuestGiver spawn factory calls. Both
## factories take the id as argument index 3; spawn_quest_giver derives one from
## the display name when the id is left blank.
func _collect_spawn_call_ids(text: String, source: String) -> void:
	for fn: String in ["spawn_quest_giver", "spawn_from_registry"]:
		var search_from: int = 0
		while true:
			var idx: int = text.find(fn + "(", search_from)
			if idx == -1:
				break
			var open_paren: int = idx + fn.length()
			var args: Array[String] = _split_call_args(text, open_paren)
			search_from = idx + fn.length()
			if args.size() < 4:
				continue
			var id_arg: String = _literal_of(args[3])
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

func _check_quests() -> void:
	for path: String in _walk(QUEST_DIR, ".json"):
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
			match obj_type:
				"talk":
					_expect_npc(target, path, where)
				"kill":
					_expect_enemy(target, path, where)
				"collect":
					_expect_item(target, path, where, true)

		var rewards: Dictionary = quest.get("rewards", {})
		var reward_items: Array = rewards.get("items", [])
		for entry: Variant in reward_items:
			if entry is String:
				_expect_item(entry, path, "rewards.items", false)


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
	var known: Dictionary = {}
	var loader_text: String = _read_text(DIALOGUE_LOADER_PATH)
	var known_re := RegEx.new()
	known_re.compile("\"([a-z_]+)\"\\s*:\\s*return DialogueData\\.ActionType\\.")
	for m: RegExMatch in known_re.search_all(loader_text):
		known[m.get_string(1)] = true

	if known.is_empty():
		_fail("DIALOGUE", DIALOGUE_LOADER_PATH, "", "could not parse the action type table")
		return

	for dir: String in DIALOGUE_DIRS:
		for path: String in _walk(dir, ".json"):
			var data: Dictionary = _read_json(path)
			if data.is_empty():
				continue
			for action_type: String in _harvest_action_types(data):
				if not known.has(action_type.to_lower()):
					_fail("DIALOGUE", path, action_type,
							"action type has no handler in DialogueLoader (parses to NONE)")


## Walks arbitrarily nested dialogue JSON collecting every "type" string that
## sits inside an "actions" array.
func _harvest_action_types(value: Variant, in_actions: bool = false) -> Array[String]:
	var found: Array[String] = []
	if value is Array:
		for entry: Variant in (value as Array):
			found.append_array(_harvest_action_types(entry, in_actions))
	elif value is Dictionary:
		var dict: Dictionary = value
		if in_actions and dict.has("type") and dict["type"] is String:
			found.append(dict["type"])
		for key: Variant in dict.keys():
			found.append_array(_harvest_action_types(dict[key], String(key) == "actions"))
	return found


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

func _walk(root: String, suffix: String) -> Array[String]:
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
			if entry.begins_with("."):
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
