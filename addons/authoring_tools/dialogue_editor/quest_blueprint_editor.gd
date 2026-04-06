@tool
class_name QuestBlueprintEditor
extends Control
## Quest Blueprint Editor - Ultra-simple "idea capture" for quests
## Jot down WHO/WHAT/WHERE/WHEN, then ask Claude to generate full quest JSON

const BLUEPRINT_DIR := "res://data/blueprints/quests/"
const NPC_BLUEPRINT_DIR := "res://data/blueprints/npcs/"
const UNSAVED_COLOR := Color(1.0, 0.8, 0.3)
const SAVED_COLOR := Color(0.5, 0.8, 0.5)

# UI References
var blueprint_dropdown: OptionButton
var new_button: Button
var delete_button: Button
var save_button: Button

var quest_name_edit: LineEdit
var giver_dropdown: OptionButton
var new_npc_button: Button
var who_edit: TextEdit
var what_edit: TextEdit
var where_edit: TextEdit
var when_edit: TextEdit
var rewards_edit: LineEdit

var status_label: Label
var title_label: Label

# State
var current_blueprint_path: String = ""
var unsaved_changes: bool = false
var blueprint_files: Array[String] = []
var npc_list: Array[Dictionary] = []  # {id, name, path}


func _ready() -> void:
	_build_ui()
	_load_blueprint_list()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.ctrl_pressed:
			if not current_blueprint_path.is_empty() or not quest_name_edit.text.is_empty():
				_on_save_pressed()
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Toolbar
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)

	# Scroll container for all content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	# Quest Name
	var name_row := HBoxContainer.new()
	content.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Quest Name:"
	name_label.custom_minimum_size.x = 100
	name_row.add_child(name_label)
	quest_name_edit = LineEdit.new()
	quest_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	quest_name_edit.placeholder_text = "Stolen Tools"
	quest_name_edit.text_changed.connect(_on_field_changed)
	name_row.add_child(quest_name_edit)

	# Quest Giver row
	var giver_row := HBoxContainer.new()
	giver_row.add_theme_constant_override("separation", 8)
	content.add_child(giver_row)
	var giver_label := Label.new()
	giver_label.text = "Quest Giver:"
	giver_label.custom_minimum_size.x = 100
	giver_row.add_child(giver_label)
	giver_dropdown = OptionButton.new()
	giver_dropdown.custom_minimum_size.x = 200
	giver_dropdown.size_flags_horizontal = SIZE_EXPAND_FILL
	giver_dropdown.item_selected.connect(_on_giver_selected)
	giver_row.add_child(giver_dropdown)
	new_npc_button = Button.new()
	new_npc_button.text = "+ New NPC"
	new_npc_button.pressed.connect(_on_new_npc_pressed)
	giver_row.add_child(new_npc_button)

	# WHO section
	content.add_child(_create_section_header("WHO:"))
	who_edit = _create_text_area("Grimjaw the blacksmith gives it\nBandits have the tools\nTheir leader Scar took them personally")
	content.add_child(who_edit)

	# WHAT section
	content.add_child(_create_section_header("WHAT:"))
	what_edit = _create_text_area("Get back the stolen blacksmith tools\nCan kill bandits or intimidate leader\nTools are in a chest in the hideout")
	content.add_child(what_edit)

	# WHERE section
	content.add_child(_create_section_header("WHERE:"))
	where_edit = _create_text_area("Starts in Thornfield smithy\nGo to Bandit Hideout (north of Elder Moor)\nReturn to Thornfield")
	content.add_child(where_edit)

	# WHEN section
	content.add_child(_create_section_header("WHEN:"))
	when_edit = _create_text_area("Available after reaching Thornfield\nNo time limit\nBandits raided last week (story context)")
	content.add_child(when_edit)

	# REWARDS section
	var rewards_row := HBoxContainer.new()
	content.add_child(rewards_row)
	var rewards_label := Label.new()
	rewards_label.text = "REWARDS:"
	rewards_label.custom_minimum_size.x = 100
	rewards_row.add_child(rewards_label)
	rewards_edit = LineEdit.new()
	rewards_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	rewards_edit.placeholder_text = "50 gold, free repairs, XP"
	rewards_edit.text_changed.connect(_on_field_changed)
	rewards_row.add_child(rewards_edit)

	# Status bar
	status_label = Label.new()
	status_label.text = "Ready - jot down your quest ideas, then ask Claude to generate the JSON"
	main_vbox.add_child(status_label)


func _create_toolbar() -> HBoxContainer:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	title_label = Label.new()
	title_label.text = "Quest Ideas"
	title_label.add_theme_font_size_override("font_size", 18)
	toolbar.add_child(title_label)

	toolbar.add_child(_create_spacer())

	blueprint_dropdown = OptionButton.new()
	blueprint_dropdown.custom_minimum_size.x = 200
	blueprint_dropdown.item_selected.connect(_on_blueprint_selected)
	toolbar.add_child(blueprint_dropdown)

	new_button = Button.new()
	new_button.text = "New"
	new_button.pressed.connect(_on_new_pressed)
	toolbar.add_child(new_button)

	delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_on_delete_pressed)
	toolbar.add_child(delete_button)

	save_button = Button.new()
	save_button.text = "Save (Ctrl+S)"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)

	return toolbar


func _create_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	return label


func _create_text_area(placeholder: String) -> TextEdit:
	var edit := TextEdit.new()
	edit.custom_minimum_size.y = 100
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	edit.placeholder_text = placeholder
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.text_changed.connect(_on_field_changed)
	return edit


func _create_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


# =============================================================================
# NPC GIVER MANAGEMENT
# =============================================================================

func _refresh_npc_list() -> void:
	giver_dropdown.clear()
	npc_list.clear()

	giver_dropdown.add_item("-- Select NPC --")

	var dir := DirAccess.open(NPC_BLUEPRINT_DIR)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var path: String = NPC_BLUEPRINT_DIR + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data: Dictionary = json.data
					var npc_id: String = file_name.get_basename()
					var npc_name: String = data.get("name", npc_id.replace("_", " ").capitalize())
					npc_list.append({
						"id": npc_id,
						"name": npc_name,
						"path": path
					})
					giver_dropdown.add_item(npc_name)
				file.close()
		file_name = dir.get_next()
	dir.list_dir_end()


func _on_giver_selected(index: int) -> void:
	if index == 0:
		# No NPC selected
		_on_field_changed()
		return

	var npc_index: int = index - 1
	if npc_index < 0 or npc_index >= npc_list.size():
		return

	var npc_info: Dictionary = npc_list[npc_index]
	var npc_name: String = npc_info.get("name", "")

	# Auto-fill WHO field first line if empty
	if who_edit.text.is_empty() or who_edit.text.begins_with("("):
		who_edit.text = npc_name + " gives this quest\n"

	_on_field_changed()


func _on_new_npc_pressed() -> void:
	# Find the NPC editor tab and switch to it
	var parent_tab := get_parent()
	if parent_tab and parent_tab.has_method("_switch_to_npc_editor"):
		parent_tab._switch_to_npc_editor()
	else:
		_set_status("Cannot open NPC editor from here")


func _get_selected_npc_id() -> String:
	var index: int = giver_dropdown.selected
	if index <= 0 or index - 1 >= npc_list.size():
		return ""
	return npc_list[index - 1].get("id", "")


func _select_npc_by_id(npc_id: String) -> void:
	if npc_id.is_empty():
		giver_dropdown.select(0)
		return

	for i: int in range(npc_list.size()):
		if npc_list[i].get("id", "") == npc_id:
			giver_dropdown.select(i + 1)
			return

	# NPC not found, select none
	giver_dropdown.select(0)


# =============================================================================
# BLUEPRINT MANAGEMENT
# =============================================================================

func _load_blueprint_list() -> void:
	blueprint_dropdown.clear()
	blueprint_files.clear()

	blueprint_dropdown.add_item("-- Select Blueprint --")

	var dir := DirAccess.open(BLUEPRINT_DIR)
	if not dir:
		# Directory may not have any files yet
		_set_status("Blueprint folder ready")
		_refresh_npc_list()
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var display_name: String = file_name.get_basename().replace("_", " ").capitalize()
			blueprint_dropdown.add_item(display_name)
			blueprint_files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	_set_status("Loaded %d blueprints" % blueprint_files.size())
	_refresh_npc_list()


func _on_blueprint_selected(index: int) -> void:
	if index == 0:
		_clear_form()
		return

	var file_index: int = index - 1
	if file_index < 0 or file_index >= blueprint_files.size():
		return

	var path: String = BLUEPRINT_DIR + blueprint_files[file_index]
	_load_blueprint(path)


func _load_blueprint(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("Failed to open: " + path)
		return

	var json_text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		_set_status("JSON parse error: " + json.get_error_message())
		return

	var data: Dictionary = json.data

	quest_name_edit.text = data.get("name", "")
	who_edit.text = data.get("who", "")
	what_edit.text = data.get("what", "")
	where_edit.text = data.get("where", "")
	when_edit.text = data.get("when", "")
	rewards_edit.text = data.get("rewards", "")

	# Load giver NPC
	var giver_npc: String = data.get("giver_npc", "")
	_select_npc_by_id(giver_npc)

	current_blueprint_path = path
	unsaved_changes = false
	_update_unsaved_indicator()
	_set_status("Loaded: " + path.get_file())


func _on_new_pressed() -> void:
	_clear_form()
	current_blueprint_path = ""
	blueprint_dropdown.select(0)
	_refresh_npc_list()
	_set_status("New blueprint - fill in your quest ideas")


func _clear_form() -> void:
	quest_name_edit.text = ""
	giver_dropdown.select(0)
	who_edit.text = ""
	what_edit.text = ""
	where_edit.text = ""
	when_edit.text = ""
	rewards_edit.text = ""
	current_blueprint_path = ""
	unsaved_changes = false
	_update_unsaved_indicator()


func _on_delete_pressed() -> void:
	if current_blueprint_path.is_empty():
		_set_status("No blueprint selected to delete")
		return

	var err := DirAccess.remove_absolute(current_blueprint_path)
	if err != OK:
		_set_status("Failed to delete file")
		return

	_set_status("Deleted: " + current_blueprint_path.get_file())
	_clear_form()
	_load_blueprint_list()


func _on_save_pressed() -> void:
	var quest_name: String = quest_name_edit.text.strip_edges()
	if quest_name.is_empty():
		_set_status("Enter a quest name first")
		return

	# Generate filename from quest name
	var new_file_name: String = quest_name.to_lower().replace(" ", "_") + ".json"
	var new_path: String = BLUEPRINT_DIR + new_file_name

	# If we had a previous path and name changed, delete old file
	if not current_blueprint_path.is_empty():
		var old_file_name: String = current_blueprint_path.get_file()
		if new_file_name != old_file_name:
			var del_err := DirAccess.remove_absolute(current_blueprint_path)
			if del_err == OK:
				_set_status("Renamed: " + old_file_name + " -> " + new_file_name)
			# Continue with save even if delete failed

	var giver_npc_id: String = _get_selected_npc_id()

	var data: Dictionary = {
		"name": quest_name,
		"giver_npc": giver_npc_id,
		"who": who_edit.text,
		"what": what_edit.text,
		"where": where_edit.text,
		"when": when_edit.text,
		"rewards": rewards_edit.text
	}

	var json_string: String = JSON.stringify(data, "  ")
	var file := FileAccess.open(new_path, FileAccess.WRITE)
	if not file:
		_set_status("Failed to save file")
		return

	file.store_string(json_string)
	file.close()

	current_blueprint_path = new_path
	unsaved_changes = false
	_update_unsaved_indicator()
	_load_blueprint_list()

	# Select the saved blueprint in dropdown
	for i: int in range(blueprint_files.size()):
		if blueprint_files[i] == new_file_name:
			blueprint_dropdown.select(i + 1)
			break

	# Update NPC's quest list if giver was selected
	if not giver_npc_id.is_empty():
		_sync_npc_with_quest(giver_npc_id, quest_name.to_lower().replace(" ", "_"))

	_set_status("Saved: " + new_file_name, SAVED_COLOR)


func _sync_npc_with_quest(npc_id: String, quest_id: String) -> void:
	# Update the NPC's quests list to include this quest
	var npc_path: String = NPC_BLUEPRINT_DIR + npc_id + ".json"
	var file := FileAccess.open(npc_path, FileAccess.READ)
	if not file:
		return

	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		return

	var npc_data: Dictionary = json.data
	file.close()

	# Get or create quests array
	var quests: Array[String] = []
	var quests_data: Variant = npc_data.get("quests", [])
	if quests_data is Array:
		for q: Variant in quests_data:
			if q is String:
				quests.append(q)
	elif quests_data is String and not quests_data.is_empty():
		# Old format - convert
		var parts: PackedStringArray = quests_data.split(",")
		for part: String in parts:
			var trimmed: String = part.strip_edges().to_lower().replace(" ", "_")
			if not trimmed.is_empty():
				quests.append(trimmed)

	# Add this quest if not already present
	if quest_id not in quests:
		quests.append(quest_id)
		npc_data["quests"] = quests

		var write_file := FileAccess.open(npc_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(JSON.stringify(npc_data, "  "))
			write_file.close()


func _on_field_changed(_value: Variant = null) -> void:
	unsaved_changes = true
	_update_unsaved_indicator()


func _set_status(msg: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)


func _update_unsaved_indicator() -> void:
	if not title_label:
		return

	var base_title: String = "Quest Ideas"
	if not current_blueprint_path.is_empty():
		base_title = "Quest Ideas - " + current_blueprint_path.get_file().get_basename()

	if unsaved_changes:
		title_label.text = base_title + " *"
		title_label.add_theme_color_override("font_color", UNSAVED_COLOR)
		if save_button:
			save_button.add_theme_color_override("font_color", UNSAVED_COLOR)
	else:
		title_label.text = base_title
		title_label.remove_theme_color_override("font_color")
		if save_button:
			save_button.remove_theme_color_override("font_color")


# =============================================================================
# PUBLIC API - Called by parent editor to load specific quest
# =============================================================================

func load_quest_by_id(quest_id: String) -> void:
	var path: String = BLUEPRINT_DIR + quest_id + ".json"
	if FileAccess.file_exists(path):
		_load_blueprint(path)
		# Update dropdown selection
		for i: int in range(blueprint_files.size()):
			if blueprint_files[i] == quest_id + ".json":
				blueprint_dropdown.select(i + 1)
				break
	else:
		_set_status("Quest not found: " + quest_id)
