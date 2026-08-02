@tool
class_name QuestAuthoringDock
extends Control
## Quest Authoring - a form over the real quest schema.
##
## This writes `res://data/quests/**.json`: 236 files deep, read by QuestManager
## on every boot, checked by `tools/validate.ps1` on every commit. It is the
## replacement for the Scripted Event Editor, which wrote `data/events/` - a
## directory that does not exist, in a format no script in the project reads.
##
## THE POINT OF THIS TOOL is the right-hand column. Every id typed into the form
## is resolved against the live registries as it is typed: NPCs out of
## `data/npcs/` and `data/npc_schedules.json`, items out of the four item
## directories, enemies, factions, and the quest ids already on disk. A red row
## is a phantom - a name that reads as real and resolves to nothing - and it is
## the thing the validator will fail the commit on. Seeing it here is the
## difference between a five-second fix and a headless run.
##
## It is deliberately not a graph editor. Caleb authors with markers and
## metadata; this is the same shape - a list of objectives, each a handful of
## named fields, with the OR-group and the world-condition spelled out in words.

const QUEST_DIR := "res://data/quests"

## QuestManager.HANDLED_OBJECTIVE_TYPES, which is the single source of truth.
## Loaded off the script at startup so this list cannot drift from that one.
var objective_types: Array[String] = []

## Quest sources QuestManager._parse_quest actually recognises. Anything else
## falls through to STORY, silently, which is how "npc" ended up in the data.
const QUEST_SOURCES: Array[String] = ["story", "npc_bounty", "board_bounty", "world_object"]

const TURN_IN_TYPES: Array[String] = ["npc_specific", "any_npc", "auto", "board"]

## Keys inside a choice_consequences branch that QuestManager executes. Anything
## else in that dictionary is documentation and never fires.
const CONSEQUENCE_KEYS: Array[String] = [
	"flags_to_set", "world_flags_to_set", "reputation_changes",
	"unlock_follower", "spawn_enemy", "items_given"
]

const COL_OK := Color(0.55, 0.82, 0.55)
const COL_BAD := Color(0.95, 0.45, 0.38)
const COL_DIM := Color(0.6, 0.6, 0.6)

# --- live registries --------------------------------------------------------
var known_npcs: Dictionary = {}
var known_items: Dictionary = {}
var known_enemies: Dictionary = {}
var known_factions: Dictionary = {}
var known_quests: Dictionary = {}   # quest_id -> path

# --- UI ---------------------------------------------------------------------
var quest_list: ItemList
var id_edit: LineEdit
var title_edit: LineEdit
var description_edit: TextEdit
var main_quest_check: CheckBox
var source_option: OptionButton
var giver_edit: LineEdit
var giver_region_edit: LineEdit
var turn_in_type_option: OptionButton
var turn_in_target_edit: LineEdit
var turn_in_zone_edit: LineEdit
var prerequisites_edit: LineEdit
var next_quest_edit: LineEdit
var notes_edit: TextEdit

var gold_spin: SpinBox
var xp_spin: SpinBox
var reward_items_edit: LineEdit
var reward_rep_edit: LineEdit

var objectives_list: ItemList
var obj_id_edit: LineEdit
var obj_desc_edit: LineEdit
var obj_type_option: OptionButton
var obj_target_edit: LineEdit
var obj_count_spin: SpinBox
var obj_optional_check: CheckBox
var obj_group_edit: LineEdit
var obj_condition_edit: LineEdit
var obj_consequence_edit: TextEdit

var check_panel: RichTextLabel
var status_label: Label

# --- state ------------------------------------------------------------------
var current_path: String = ""
var quest: Dictionary = {}
var selected_objective: int = -1
var _suppress_field_sync: bool = false


func _ready() -> void:
	_load_objective_types()
	_load_registries()
	_build_ui()
	_new_quest()
	_refresh_quest_list()


## The vocabulary of objective types is QuestManager's, read off its script, so
## a type added there appears here the same day and a type removed vanishes.
func _load_objective_types() -> void:
	objective_types.clear()
	var qm: Script = load("res://scripts/systems/quests/quest_manager.gd")
	if qm:
		for t: String in qm.HANDLED_OBJECTIVE_TYPES:
			objective_types.append(t)
	if objective_types.is_empty():
		push_warning("[QuestAuthoring] Could not read HANDLED_OBJECTIVE_TYPES off QuestManager")


## ============================================================================
## THE REGISTRIES - what "this id is real" means
## ============================================================================

func _load_registries() -> void:
	known_npcs.clear()
	known_items.clear()
	known_enemies.clear()
	known_factions.clear()
	known_quests.clear()

	# NPCs: the resources, plus everyone the living world has a day for.
	for path: String in _files_under("res://data/npcs", ".tres"):
		var id: String = _read_tres_string(path, "npc_id")
		if id.is_empty():
			id = path.get_file().get_basename()
		known_npcs[id] = path
	if FileAccess.file_exists("res://data/npc_schedules.json"):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npc_schedules.json"))
		if parsed is Dictionary:
			var npcs: Dictionary = (parsed as Dictionary).get("npcs", {})
			for npc_id: String in npcs:
				if not known_npcs.has(npc_id):
					known_npcs[npc_id] = "res://data/npc_schedules.json"

	for dir_path: String in ["res://data/items", "res://data/weapons", "res://data/armor", "res://data/spells"]:
		for path: String in _files_under(dir_path, ".tres"):
			known_items[path.get_file().get_basename()] = path

	for path: String in _files_under("res://data/enemies", ".tres"):
		known_enemies[path.get_file().get_basename()] = path

	for path: String in _files_under("res://data/factions", ".tres"):
		known_factions[path.get_file().get_basename()] = path

	for path: String in _files_under(QUEST_DIR, ".json"):
		var text: String = FileAccess.get_file_as_string(path)
		var q: Variant = JSON.parse_string(text)
		if q is Dictionary:
			var qid: String = String((q as Dictionary).get("id", ""))
			if not qid.is_empty():
				known_quests[qid] = path


func _files_under(root: String, suffix: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_files_under(full, suffix))
		elif name.ends_with(suffix):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _read_tres_string(path: String, key: String) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	for line: String in text.split("\n"):
		if line.begins_with(key + " = "):
			return line.substr((key + " = ").length()).strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


## ============================================================================
## UI
## ============================================================================

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 4)
	add_child(root)

	root.add_child(_build_toolbar())

	var split := HSplitContainer.new()
	split.size_flags_vertical = SIZE_EXPAND_FILL
	root.add_child(split)

	split.add_child(_build_left_panel())

	var right_split := HSplitContainer.new()
	right_split.size_flags_horizontal = SIZE_EXPAND_FILL
	split.add_child(right_split)

	right_split.add_child(_build_form_panel())
	right_split.add_child(_build_check_panel())

	status_label = Label.new()
	status_label.text = "Ready"
	root.add_child(status_label)


func _build_toolbar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)

	var new_btn := Button.new()
	new_btn.text = "New quest"
	new_btn.pressed.connect(_on_new_pressed)
	bar.add_child(new_btn)

	var save_btn := Button.new()
	save_btn.text = "Save quest"
	save_btn.tooltip_text = "Write this quest into data/quests/. It is live the next time the game boots."
	save_btn.pressed.connect(_on_save_pressed)
	bar.add_child(save_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Rescan registries"
	reload_btn.tooltip_text = "Re-read NPCs, items, enemies, factions and quests off disk. Press this after adding an NPC in the Town Editor or the NPC Composer."
	reload_btn.pressed.connect(_on_rescan_pressed)
	bar.add_child(reload_btn)

	bar.add_child(VSeparator.new())

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	bar.add_child(spacer)

	return bar


func _build_left_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 220

	var label := Label.new()
	label.text = "Quests on disk"
	panel.add_child(label)

	quest_list = ItemList.new()
	quest_list.size_flags_vertical = SIZE_EXPAND_FILL
	quest_list.item_selected.connect(_on_quest_list_selected)
	panel.add_child(quest_list)

	return panel


func _build_form_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var form := VBoxContainer.new()
	form.size_flags_horizontal = SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation", 6)
	scroll.add_child(form)

	form.add_child(_section("The quest"))
	id_edit = _line(form, "Id", "millbrook_bandits", "Lower case with underscores. It is the file name and the id every other quest, dialogue and flag refers to.")
	title_edit = _line(form, "Title", "Trouble in Millbrook", "What the journal calls it. Never hand-write this title into a conversation line - use {quest_title}.")

	form.add_child(_make_label("Description"))
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 70
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	description_edit.text_changed.connect(_on_any_field_changed)
	form.add_child(description_edit)

	var flags_row := HBoxContainer.new()
	form.add_child(flags_row)
	main_quest_check = CheckBox.new()
	main_quest_check.text = "Main quest"
	main_quest_check.toggled.connect(func(_p: bool) -> void: _on_any_field_changed())
	flags_row.add_child(main_quest_check)
	flags_row.add_child(_make_label("  Source:"))
	source_option = OptionButton.new()
	for s: String in QUEST_SOURCES:
		source_option.add_item(s)
	source_option.tooltip_text = "Only these four are recognised. Anything else - 'npc', for instance - falls through to story without a word."
	source_option.item_selected.connect(func(_i: int) -> void: _on_any_field_changed())
	flags_row.add_child(source_option)

	form.add_child(_section("Who gives it, who takes it back"))
	giver_edit = _line(form, "Giver npc_id", "millbrook_elder", "Must be an NPC that exists AND is spawned in the giver region.")
	giver_region_edit = _line(form, "Giver region", "millbrook", "")
	var tit_row := HBoxContainer.new()
	form.add_child(tit_row)
	tit_row.add_child(_fixed_label("Turn in to"))
	turn_in_type_option = OptionButton.new()
	for t: String in TURN_IN_TYPES:
		turn_in_type_option.add_item(t)
	turn_in_type_option.item_selected.connect(func(_i: int) -> void: _on_any_field_changed())
	tit_row.add_child(turn_in_type_option)
	turn_in_target_edit = _line(form, "Turn-in npc_id", "millbrook_elder", "Required when the type is npc_specific. This NPC must be spawned in the turn-in zone.")
	turn_in_zone_edit = _line(form, "Turn-in zone", "millbrook", "")

	form.add_child(_section("Objectives"))
	var obj_help := Label.new()
	obj_help.text = "Objectives sharing a group id are different answers to the same problem - any one of them settles the group, and the journal marks the rest 'settled another way'. A world condition that already holds completes the objective the moment the quest is offered."
	obj_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	obj_help.add_theme_font_size_override("font_size", 10)
	obj_help.add_theme_color_override("font_color", COL_DIM)
	form.add_child(obj_help)

	objectives_list = ItemList.new()
	objectives_list.custom_minimum_size.y = 110
	objectives_list.item_selected.connect(_on_objective_selected)
	form.add_child(objectives_list)

	var obj_buttons := HBoxContainer.new()
	form.add_child(obj_buttons)
	var add_obj := Button.new()
	add_obj.text = "Add objective"
	add_obj.pressed.connect(_on_add_objective)
	obj_buttons.add_child(add_obj)
	var del_obj := Button.new()
	del_obj.text = "Remove"
	del_obj.pressed.connect(_on_remove_objective)
	obj_buttons.add_child(del_obj)
	var up_obj := Button.new()
	up_obj.text = "Up"
	up_obj.pressed.connect(_on_move_objective.bind(-1))
	obj_buttons.add_child(up_obj)
	var down_obj := Button.new()
	down_obj.text = "Down"
	down_obj.pressed.connect(_on_move_objective.bind(1))
	obj_buttons.add_child(down_obj)

	obj_id_edit = _line(form, "Objective id", "kill_leader", "Unique inside this quest. A choice objective's id IS the choice id its consequences are filed under.")
	obj_desc_edit = _line(form, "Reads as", "Kill Chief Corla Vane", "")

	var type_row := HBoxContainer.new()
	form.add_child(type_row)
	type_row.add_child(_fixed_label("Type"))
	obj_type_option = OptionButton.new()
	for t: String in objective_types:
		obj_type_option.add_item(t)
	obj_type_option.tooltip_text = "QuestManager's handled types, read off its own script. A type not on this list has no driver and will never complete."
	obj_type_option.item_selected.connect(func(_i: int) -> void: _sync_objective_from_fields())
	type_row.add_child(obj_type_option)
	type_row.add_child(_make_label(" Count"))
	obj_count_spin = SpinBox.new()
	obj_count_spin.min_value = 1
	obj_count_spin.max_value = 999
	obj_count_spin.value = 1
	obj_count_spin.value_changed.connect(func(_v: float) -> void: _sync_objective_from_fields())
	type_row.add_child(obj_count_spin)
	obj_optional_check = CheckBox.new()
	obj_optional_check.text = "optional"
	obj_optional_check.toggled.connect(func(_p: bool) -> void: _sync_objective_from_fields())
	type_row.add_child(obj_optional_check)

	obj_target_edit = _line(form, "Target", "bandit_boss", "An enemy id for kill, an npc_id for talk, an item id for collect, a location for reach. Checked against the registries on the right.", true)
	obj_group_edit = _line(form, "OR group", "settle_the_camp", "Leave empty for an objective that stands alone. Objectives sharing this id are alternatives; settling one settles them all.", true)
	obj_condition_edit = _line(form, "World condition", '{"flag": "bandit_camp_cleared"}', "JSON. If it already holds when the quest is offered, this objective completes immediately - the 'you already did this, here is your money' moment. An empty condition is always false, so a typo can never hand out a free quest.", true)

	form.add_child(_make_label("Choice consequences for this objective"))
	obj_consequence_edit = TextEdit.new()
	obj_consequence_edit.custom_minimum_size.y = 90
	obj_consequence_edit.placeholder_text = '{\n  "flags_to_set": ["millbrook_camp_razed"],\n  "world_flags_to_set": ["bandit_camp_cleared"],\n  "reputation_changes": {"millbrook": 30}\n}'
	obj_consequence_edit.text_changed.connect(_sync_objective_from_fields)
	form.add_child(obj_consequence_edit)

	form.add_child(_section("Rewards"))
	var rew_row := HBoxContainer.new()
	form.add_child(rew_row)
	rew_row.add_child(_fixed_label("Gold"))
	gold_spin = SpinBox.new()
	gold_spin.max_value = 100000
	gold_spin.value_changed.connect(func(_v: float) -> void: _on_any_field_changed())
	rew_row.add_child(gold_spin)
	rew_row.add_child(_make_label(" XP"))
	xp_spin = SpinBox.new()
	xp_spin.max_value = 100000
	xp_spin.value_changed.connect(func(_v: float) -> void: _on_any_field_changed())
	rew_row.add_child(xp_spin)

	reward_items_edit = _line(form, "Item rewards", "healing_potion x2, iron_sword", "Comma separated. 'id xN' for a quantity.")
	reward_rep_edit = _line(form, "Reputation", "millbrook 25, bandits -40", "Comma separated 'faction amount'.")

	form.add_child(_section("Wiring"))
	prerequisites_edit = _line(form, "Prerequisites", "millbrook_intro", "Comma separated quest ids that must be complete first.")
	next_quest_edit = _line(form, "Next quest", "", "Auto-starts when this one completes.")

	form.add_child(_make_label("Notes (never shown to the player)"))
	notes_edit = TextEdit.new()
	notes_edit.custom_minimum_size.y = 50
	notes_edit.text_changed.connect(_on_any_field_changed)
	form.add_child(notes_edit)

	return scroll


func _build_check_panel() -> Control:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 300

	var header := Label.new()
	header.text = "Does it resolve?"
	header.add_theme_font_size_override("font_size", 14)
	panel.add_child(header)

	var sub := Label.new()
	sub.text = "Every id in the form, against what is actually on disk. A red row is what the validator will fail the commit on."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", COL_DIM)
	panel.add_child(sub)

	check_panel = RichTextLabel.new()
	check_panel.bbcode_enabled = true
	check_panel.size_flags_vertical = SIZE_EXPAND_FILL
	panel.add_child(check_panel)

	return panel


func _section(text: String) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_child(HSeparator.new())
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	vbox.add_child(label)
	return vbox


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _fixed_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 110
	return label


func _line(parent: Control, label_text: String, placeholder: String, tooltip: String, objective_field: bool = false) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)
	row.add_child(_fixed_label(label_text))
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.tooltip_text = tooltip
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	if objective_field:
		edit.text_changed.connect(func(_t: String) -> void: _sync_objective_from_fields())
	else:
		edit.text_changed.connect(func(_t: String) -> void: _on_any_field_changed())
	row.add_child(edit)
	return edit


## ============================================================================
## FORM <-> QUEST
## ============================================================================

func _new_quest() -> void:
	current_path = ""
	quest = {
		"id": "",
		"title": "",
		"description": "",
		"is_main_quest": false,
		"quest_source": "story",
		"giver_npc_id": "",
		"giver_region": "",
		"turn_in_type": "npc_specific",
		"turn_in_target": "",
		"turn_in_zone": "",
		"objectives": [],
		"objective_groups": {},
		"rewards": {"gold": 0, "xp": 0},
		"choice_consequences": {},
		"prerequisites": [],
		"next_quest": "",
		"notes": "",
	}
	selected_objective = -1
	_quest_to_form()
	_run_checks()


func _quest_to_form() -> void:
	_suppress_field_sync = true

	id_edit.text = String(quest.get("id", ""))
	title_edit.text = String(quest.get("title", ""))
	description_edit.text = String(quest.get("description", ""))
	main_quest_check.button_pressed = bool(quest.get("is_main_quest", false))
	source_option.selected = maxi(0, QUEST_SOURCES.find(String(quest.get("quest_source", "story"))))
	giver_edit.text = String(quest.get("giver_npc_id", ""))
	giver_region_edit.text = String(quest.get("giver_region", ""))
	turn_in_type_option.selected = maxi(0, TURN_IN_TYPES.find(String(quest.get("turn_in_type", "npc_specific"))))
	turn_in_target_edit.text = String(quest.get("turn_in_target", ""))
	turn_in_zone_edit.text = String(quest.get("turn_in_zone", ""))
	next_quest_edit.text = String(quest.get("next_quest", ""))
	notes_edit.text = String(quest.get("notes", ""))
	prerequisites_edit.text = ", ".join(_as_string_array(quest.get("prerequisites", [])))

	var rewards: Dictionary = quest.get("rewards", {})
	gold_spin.value = int(rewards.get("gold", 0))
	xp_spin.value = int(rewards.get("xp", 0))

	var item_parts: Array[String] = []
	for entry: Variant in rewards.get("items", []) as Array:
		if entry is Dictionary:
			var qty: int = int((entry as Dictionary).get("quantity", 1))
			var iid: String = String((entry as Dictionary).get("id", ""))
			item_parts.append(iid if qty <= 1 else "%s x%d" % [iid, qty])
	reward_items_edit.text = ", ".join(item_parts)

	var rep_parts: Array[String] = []
	var rep: Dictionary = rewards.get("faction_reputation", {})
	for faction: String in rep:
		rep_parts.append("%s %d" % [faction, int(rep[faction])])
	reward_rep_edit.text = ", ".join(rep_parts)

	_suppress_field_sync = false
	_refresh_objectives_list()
	_objective_to_fields()


func _form_to_quest() -> void:
	quest["id"] = id_edit.text.strip_edges()
	quest["title"] = title_edit.text.strip_edges()
	quest["description"] = description_edit.text
	quest["is_main_quest"] = main_quest_check.button_pressed
	quest["quest_source"] = QUEST_SOURCES[source_option.selected] if source_option.selected >= 0 else "story"
	quest["giver_npc_id"] = giver_edit.text.strip_edges()
	quest["giver_region"] = giver_region_edit.text.strip_edges()
	quest["turn_in_type"] = TURN_IN_TYPES[turn_in_type_option.selected] if turn_in_type_option.selected >= 0 else "npc_specific"
	quest["turn_in_target"] = turn_in_target_edit.text.strip_edges()
	quest["turn_in_zone"] = turn_in_zone_edit.text.strip_edges()
	quest["next_quest"] = next_quest_edit.text.strip_edges()
	quest["notes"] = notes_edit.text
	quest["prerequisites"] = _split_list(prerequisites_edit.text)

	var rewards: Dictionary = {"gold": int(gold_spin.value), "xp": int(xp_spin.value)}
	var items: Array = []
	for part: String in _split_list(reward_items_edit.text):
		var bits: PackedStringArray = part.split(" x")
		if bits.size() == 2:
			items.append({"id": bits[0].strip_edges(), "quantity": int(bits[1])})
		else:
			items.append({"id": part, "quantity": 1})
	if not items.is_empty():
		rewards["items"] = items

	var rep: Dictionary = {}
	for part: String in _split_list(reward_rep_edit.text):
		var bits: PackedStringArray = part.rsplit(" ", true, 1)
		if bits.size() == 2:
			rep[bits[0].strip_edges()] = int(bits[1])
	if not rep.is_empty():
		rewards["faction_reputation"] = rep

	quest["rewards"] = rewards

	# objective_groups is decoration; keep one entry per group that exists so the
	# journal has a line to print, and drop entries for groups nobody is in.
	var groups: Dictionary = quest.get("objective_groups", {})
	var live: Dictionary = {}
	for obj: Variant in quest.get("objectives", []) as Array:
		var gid: String = String((obj as Dictionary).get("group", ""))
		if gid.is_empty():
			continue
		live[gid] = groups.get(gid, {"description": "Settle it, however you like", "required": 1})
	quest["objective_groups"] = live


func _on_any_field_changed() -> void:
	if _suppress_field_sync:
		return
	_form_to_quest()
	_run_checks()


## ============================================================================
## OBJECTIVES
## ============================================================================

func _objectives() -> Array:
	return quest.get("objectives", []) as Array


func _refresh_objectives_list() -> void:
	objectives_list.clear()
	for obj: Variant in _objectives():
		var o: Dictionary = obj
		var group: String = String(o.get("group", ""))
		var label: String = "%s  [%s]  %s" % [
			o.get("id", "?"), o.get("type", "?"), o.get("target", "")
		]
		if not group.is_empty():
			label += "   (or: %s)" % group
		if o.has("world_condition"):
			label += "   (pre-completes)"
		objectives_list.add_item(label)
	if selected_objective >= 0 and selected_objective < objectives_list.item_count:
		objectives_list.select(selected_objective)


func _on_add_objective() -> void:
	var obj: Dictionary = {
		"id": "objective_%d" % (_objectives().size() + 1),
		"description": "",
		"type": objective_types[0] if not objective_types.is_empty() else "kill",
		"target": "",
		"required_count": 1,
	}
	_objectives().append(obj)
	selected_objective = _objectives().size() - 1
	_refresh_objectives_list()
	_objective_to_fields()
	_run_checks()


func _on_remove_objective() -> void:
	if selected_objective < 0 or selected_objective >= _objectives().size():
		return
	var removed: Dictionary = _objectives()[selected_objective]
	_objectives().remove_at(selected_objective)
	var consequences: Dictionary = quest.get("choice_consequences", {})
	consequences.erase(String(removed.get("id", "")))
	selected_objective = mini(selected_objective, _objectives().size() - 1)
	_form_to_quest()
	_refresh_objectives_list()
	_objective_to_fields()
	_run_checks()


func _on_move_objective(delta: int) -> void:
	var target: int = selected_objective + delta
	if selected_objective < 0 or target < 0 or target >= _objectives().size():
		return
	var objs: Array = _objectives()
	var moved: Variant = objs[selected_objective]
	objs[selected_objective] = objs[target]
	objs[target] = moved
	selected_objective = target
	_refresh_objectives_list()


func _on_objective_selected(index: int) -> void:
	selected_objective = index
	_objective_to_fields()


func _objective_to_fields() -> void:
	_suppress_field_sync = true
	if selected_objective < 0 or selected_objective >= _objectives().size():
		obj_id_edit.text = ""
		obj_desc_edit.text = ""
		obj_target_edit.text = ""
		obj_group_edit.text = ""
		obj_condition_edit.text = ""
		obj_consequence_edit.text = ""
		obj_count_spin.value = 1
		obj_optional_check.button_pressed = false
		_suppress_field_sync = false
		return

	var obj: Dictionary = _objectives()[selected_objective]
	obj_id_edit.text = String(obj.get("id", ""))
	obj_desc_edit.text = String(obj.get("description", ""))
	obj_type_option.selected = maxi(0, objective_types.find(String(obj.get("type", ""))))
	obj_target_edit.text = String(obj.get("target", ""))
	obj_count_spin.value = int(obj.get("required_count", 1))
	obj_optional_check.button_pressed = bool(obj.get("is_optional", false))
	obj_group_edit.text = String(obj.get("group", ""))
	obj_condition_edit.text = JSON.stringify(obj.get("world_condition", {})) if obj.has("world_condition") else ""

	var consequences: Dictionary = quest.get("choice_consequences", {})
	var branch: Variant = consequences.get(String(obj.get("id", "")), null)
	obj_consequence_edit.text = JSON.stringify(branch, "  ") if branch is Dictionary else ""

	_suppress_field_sync = false


func _sync_objective_from_fields() -> void:
	if _suppress_field_sync:
		return
	if selected_objective < 0 or selected_objective >= _objectives().size():
		return

	var obj: Dictionary = _objectives()[selected_objective]
	var old_id: String = String(obj.get("id", ""))
	var new_id: String = obj_id_edit.text.strip_edges()

	obj["id"] = new_id
	obj["description"] = obj_desc_edit.text
	obj["type"] = objective_types[obj_type_option.selected] if obj_type_option.selected >= 0 else obj.get("type", "kill")
	obj["target"] = obj_target_edit.text.strip_edges()
	obj["required_count"] = int(obj_count_spin.value)
	if obj_optional_check.button_pressed:
		obj["is_optional"] = true
	else:
		obj.erase("is_optional")

	var group: String = obj_group_edit.text.strip_edges()
	if group.is_empty():
		obj.erase("group")
	else:
		obj["group"] = group

	var cond_text: String = obj_condition_edit.text.strip_edges()
	if cond_text.is_empty():
		obj.erase("world_condition")
	else:
		var parsed: Variant = JSON.parse_string(cond_text)
		if parsed is Dictionary:
			obj["world_condition"] = parsed

	# The consequence branch is filed under the objective's id, so a rename has
	# to carry it. Getting this wrong orphans the branch and the choice does
	# nothing - which is exactly what four thieves-guild quests did for months.
	var consequences: Dictionary = quest.get("choice_consequences", {})
	if old_id != new_id and consequences.has(old_id):
		consequences[new_id] = consequences[old_id]
		consequences.erase(old_id)

	var cons_text: String = obj_consequence_edit.text.strip_edges()
	if cons_text.is_empty():
		consequences.erase(new_id)
	else:
		var parsed_cons: Variant = JSON.parse_string(cons_text)
		if parsed_cons is Dictionary:
			consequences[new_id] = parsed_cons
	quest["choice_consequences"] = consequences

	_form_to_quest()
	_refresh_objectives_list()
	_run_checks()


## ============================================================================
## THE CHECKS - the grounding culture, in tool form
## ============================================================================

func _run_checks() -> void:
	if check_panel == null:
		return
	var lines: Array[String] = []
	var problems: int = 0

	var quest_id: String = String(quest.get("id", ""))
	if quest_id.is_empty():
		lines.append(_bad("id", "a quest with no id cannot be saved"))
		problems += 1
	elif known_quests.has(quest_id) and known_quests[quest_id] != current_path:
		lines.append(_bad("id  %s" % quest_id, "already used by %s" % String(known_quests[quest_id]).get_file()))
		problems += 1
	else:
		lines.append(_ok("id  %s" % quest_id))

	if String(quest.get("title", "")).is_empty():
		lines.append(_bad("title", "empty"))
		problems += 1

	lines.append("")
	lines.append("[b]People[/b]")
	problems += _check_id(lines, "giver", String(quest.get("giver_npc_id", "")), known_npcs, true)
	if String(quest.get("turn_in_type", "")) == "npc_specific":
		problems += _check_id(lines, "turn-in", String(quest.get("turn_in_target", "")), known_npcs, true)

	lines.append("")
	lines.append("[b]Objectives[/b]")
	var objectives: Array = _objectives()
	if objectives.is_empty():
		lines.append(_bad("objectives", "a quest with none can never complete"))
		problems += 1

	var seen_ids: Dictionary = {}
	var groups: Dictionary = {}
	for obj: Variant in objectives:
		var o: Dictionary = obj
		var oid: String = String(o.get("id", ""))
		var otype: String = String(o.get("type", ""))
		var target: String = String(o.get("target", ""))

		if oid.is_empty():
			lines.append(_bad("objective", "no id"))
			problems += 1
		elif seen_ids.has(oid):
			lines.append(_bad(oid, "two objectives share this id"))
			problems += 1
		seen_ids[oid] = true

		if not objective_types.has(otype):
			lines.append(_bad("%s type %s" % [oid, otype], "no driver - it can never complete"))
			problems += 1

		match otype:
			"kill":
				problems += _check_id(lines, oid, target, known_enemies, false, "enemy")
			"talk":
				problems += _check_id(lines, oid, target, known_npcs, false, "npc")
			"collect", "has_item":
				problems += _check_id(lines, oid, target, known_items, false, "item")
			"choice":
				if not quest.get("choice_consequences", {}).has(oid):
					lines.append(_warn(oid, "a choice with no consequence branch does nothing but tick"))
			_:
				if target.is_empty() and otype not in ["choice"]:
					lines.append(_warn(oid, "no target"))

		var gid: String = String(o.get("group", ""))
		if not gid.is_empty():
			groups[gid] = int(groups.get(gid, 0)) + 1

	for gid: String in groups:
		if groups[gid] < 2:
			lines.append(_warn("group %s" % gid, "only one objective is in it - an OR group of one is just an objective"))
		else:
			lines.append(_ok("group %s  (%d ways)" % [gid, groups[gid]]))

	lines.append("")
	lines.append("[b]Rewards and wiring[/b]")
	var rewards: Dictionary = quest.get("rewards", {})
	for entry: Variant in rewards.get("items", []) as Array:
		problems += _check_id(lines, "reward", String((entry as Dictionary).get("id", "")), known_items, false, "item")
	for faction: String in rewards.get("faction_reputation", {}) as Dictionary:
		problems += _check_id(lines, "rep", faction, known_factions, false, "faction")
	for prereq: String in _as_string_array(quest.get("prerequisites", [])):
		problems += _check_id(lines, "prereq", prereq, known_quests, false, "quest")
	var next_quest: String = String(quest.get("next_quest", ""))
	if not next_quest.is_empty():
		problems += _check_id(lines, "next", next_quest, known_quests, false, "quest")

	# Consequence branches: keys that fire, and keys that are only prose.
	var consequences: Dictionary = quest.get("choice_consequences", {})
	if not consequences.is_empty():
		lines.append("")
		lines.append("[b]Consequences[/b]")
		for choice_id: String in consequences:
			if not seen_ids.has(choice_id):
				lines.append(_warn(choice_id, "no objective has this id, so this branch can never be applied"))
			var branch: Dictionary = consequences[choice_id]
			for key: String in branch:
				if not CONSEQUENCE_KEYS.has(key):
					lines.append(_warn("%s.%s" % [choice_id, key], "not a key QuestManager executes - documentation only"))
			for faction2: String in branch.get("reputation_changes", {}) as Dictionary:
				problems += _check_id(lines, "%s rep" % choice_id, faction2, known_factions, false, "faction")
			for item_id: String in _as_string_array(branch.get("items_given", [])):
				problems += _check_id(lines, "%s gives" % choice_id, item_id, known_items, false, "item")

	lines.append("")
	if problems == 0:
		lines.append("[color=#8fbf8f][b]Everything resolves.[/b] Save it, then run tools/validate.ps1 - it checks the things only a booted game can, like whether the giver is actually spawned in that region and awake at nine in the morning.[/color]")
	else:
		lines.append("[color=#f07060][b]%d thing(s) do not resolve.[/b] Each is a name the player could be sent after that leads nowhere.[/color]" % problems)

	check_panel.text = "\n".join(lines)


func _check_id(lines: Array[String], label: String, id: String, registry: Dictionary, required: bool, kind: String = "npc") -> int:
	if id.is_empty():
		if required:
			lines.append(_bad(label, "empty"))
			return 1
		return 0
	if registry.has(id):
		lines.append(_ok("%s  %s" % [label, id]))
		return 0
	lines.append(_bad("%s  %s" % [label, id], "no %s with that id" % kind))
	return 1


func _ok(text: String) -> String:
	return "[color=#8fbf8f]OK[/color]   %s" % text


func _bad(text: String, why: String) -> String:
	return "[color=#f07060]NO[/color]   %s  -  %s" % [text, why]


func _warn(text: String, why: String) -> String:
	return "[color=#d8b878]?[/color]    %s  -  %s" % [text, why]


## ============================================================================
## FILES
## ============================================================================

func _refresh_quest_list() -> void:
	quest_list.clear()
	var ids: Array[String] = []
	for qid: String in known_quests:
		ids.append(qid)
	ids.sort()
	for qid: String in ids:
		var idx: int = quest_list.add_item(qid)
		quest_list.set_item_metadata(idx, known_quests[qid])


func _on_quest_list_selected(index: int) -> void:
	var path: String = String(quest_list.get_item_metadata(index))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		_set_status("Could not parse %s" % path)
		return
	quest = parsed
	current_path = path
	selected_objective = -1
	_quest_to_form()
	_run_checks()
	_set_status("Opened %s" % path)


func _on_new_pressed() -> void:
	_new_quest()
	_set_status("New quest")


func _on_rescan_pressed() -> void:
	_load_registries()
	_refresh_quest_list()
	_run_checks()
	_set_status("Registries: %d npcs, %d items, %d enemies, %d factions, %d quests" % [
		known_npcs.size(), known_items.size(), known_enemies.size(),
		known_factions.size(), known_quests.size()
	])


func _on_save_pressed() -> void:
	_form_to_quest()
	var quest_id: String = String(quest.get("id", ""))
	if quest_id.is_empty():
		_set_status("Give the quest an id first")
		return

	var path: String = current_path
	if path.is_empty():
		path = QUEST_DIR.path_join(quest_id + ".json")

	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_set_status("ERROR: could not write %s" % path)
		return
	file.store_string(JSON.stringify(_pruned(quest), "\t") + "\n")
	file.close()

	current_path = path
	known_quests[quest_id] = path
	_refresh_quest_list()
	_run_checks()
	_set_status("Saved %s  -  run tools/validate.ps1 before committing" % path)


## Empty containers and empty strings are noise in a hand-read file, and an
## empty `choice_consequences` reads like a promise nobody kept.
func _pruned(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: String in source:
		var value: Variant = source[key]
		if value is String and (value as String).is_empty():
			continue
		if value is Array and (value as Array).is_empty():
			continue
		if value is Dictionary and (value as Dictionary).is_empty():
			continue
		out[key] = value
	return out


func _split_list(text: String) -> Array:
	var out: Array = []
	for part: String in text.split(",", false):
		var trimmed: String = part.strip_edges()
		if not trimmed.is_empty():
			out.append(trimmed)
	return out


func _as_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			out.append(String(entry))
	return out


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
	print("[QuestAuthoring] %s" % text)
