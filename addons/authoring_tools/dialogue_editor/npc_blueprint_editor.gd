@tool
class_name NPCBlueprintEditor
extends Control
## NPC Blueprint Editor - Ultra-simple "idea capture" for NPCs
## Jot down WHO/WHAT/WHERE, then ask Claude to generate full dialogue JSON

const BLUEPRINT_DIR := "res://data/blueprints/npcs/"
const QUEST_BLUEPRINT_DIR := "res://data/blueprints/quests/"
const UNSAVED_COLOR := Color(1.0, 0.8, 0.3)
const SAVED_COLOR := Color(0.5, 0.8, 0.5)

# Dropdown options
const NPC_TYPES: Array[String] = [
	"Civilian", "Guard", "Merchant", "Blacksmith", "Innkeeper", "Priest",
	"Quest Giver", "Noble", "Wizard", "Barmaid", "Cook", "Farmer",
	"Miner", "Sailor", "Hunter", "Scholar", "Beggar", "Thief"
]
const RACES: Array[String] = ["Human", "Elf", "Dwarf", "Halfling"]
const GENDERS: Array[String] = ["Male", "Female", "Other"]

# UI References
var blueprint_dropdown: OptionButton
var new_button: Button
var delete_button: Button
var save_button: Button

var npc_name_edit: LineEdit
var type_dropdown: OptionButton
var race_dropdown: OptionButton
var gender_dropdown: OptionButton
var who_edit: TextEdit
var what_edit: TextEdit
var where_edit: TextEdit

# Quest linking UI
var quests_container: VBoxContainer
var quest_checkboxes: Dictionary = {}  # quest_id -> CheckBox
var link_quest_button: Button

var status_label: Label
var title_label: Label

# State
var current_blueprint_path: String = ""
var unsaved_changes: bool = false
var blueprint_files: Array[String] = []
var linked_quests: Array[String] = []  # Quest IDs this NPC gives


func _ready() -> void:
	_build_ui()
	_load_blueprint_list()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.ctrl_pressed:
			if not current_blueprint_path.is_empty() or not npc_name_edit.text.is_empty():
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

	# NPC Name
	var name_row := HBoxContainer.new()
	content.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.custom_minimum_size.x = 100
	name_row.add_child(name_label)
	npc_name_edit = LineEdit.new()
	npc_name_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	npc_name_edit.placeholder_text = "Grimjaw Ironhand"
	npc_name_edit.text_changed.connect(_on_field_changed)
	name_row.add_child(npc_name_edit)

	# Type / Race / Gender row
	var attributes_row := HBoxContainer.new()
	attributes_row.add_theme_constant_override("separation", 16)
	content.add_child(attributes_row)

	# Type dropdown
	var type_container := HBoxContainer.new()
	attributes_row.add_child(type_container)
	var type_label := Label.new()
	type_label.text = "Type:"
	type_container.add_child(type_label)
	type_dropdown = OptionButton.new()
	type_dropdown.custom_minimum_size.x = 120
	for npc_type: String in NPC_TYPES:
		type_dropdown.add_item(npc_type)
	type_dropdown.item_selected.connect(_on_dropdown_changed)
	type_container.add_child(type_dropdown)

	# Race dropdown
	var race_container := HBoxContainer.new()
	attributes_row.add_child(race_container)
	var race_label := Label.new()
	race_label.text = "Race:"
	race_container.add_child(race_label)
	race_dropdown = OptionButton.new()
	race_dropdown.custom_minimum_size.x = 100
	for race: String in RACES:
		race_dropdown.add_item(race)
	race_dropdown.item_selected.connect(_on_dropdown_changed)
	race_container.add_child(race_dropdown)

	# Gender dropdown
	var gender_container := HBoxContainer.new()
	attributes_row.add_child(gender_container)
	var gender_label := Label.new()
	gender_label.text = "Gender:"
	gender_container.add_child(gender_label)
	gender_dropdown = OptionButton.new()
	gender_dropdown.custom_minimum_size.x = 90
	for gender: String in GENDERS:
		gender_dropdown.add_item(gender)
	gender_dropdown.item_selected.connect(_on_dropdown_changed)
	gender_container.add_child(gender_dropdown)

	# WHO section
	content.add_child(_create_section_header("WHO:"))
	who_edit = _create_text_area("Dwarf blacksmith, been here 40 years\nGruff but secretly kind\nLost his wife to plague, throws himself into work")
	content.add_child(who_edit)

	# WHAT section (knows/does)
	content.add_child(_create_section_header("WHAT (knows/does):"))
	what_edit = _create_text_area("Sells weapons and armor\nCan repair gear\nKnows rumors about old dwarf mines\nComplains about bandits attacking trade routes")
	content.add_child(what_edit)

	# WHERE section
	content.add_child(_create_section_header("WHERE:"))
	where_edit = _create_text_area("Thornfield smithy\nNever leaves his forge")
	content.add_child(where_edit)

	# QUESTS GIVEN section
	content.add_child(_create_section_header("QUESTS GIVEN:"))
	quests_container = VBoxContainer.new()
	quests_container.add_theme_constant_override("separation", 4)
	content.add_child(quests_container)

	link_quest_button = Button.new()
	link_quest_button.text = "+ Link Quest..."
	link_quest_button.pressed.connect(_on_link_quest_pressed)
	content.add_child(link_quest_button)

	# Status bar
	status_label = Label.new()
	status_label.text = "Ready - jot down your NPC ideas, then ask Claude to generate the dialogue"
	main_vbox.add_child(status_label)


func _create_toolbar() -> HBoxContainer:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	title_label = Label.new()
	title_label.text = "NPC Ideas"
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
# QUEST LINKING
# =============================================================================

func _refresh_quest_list() -> void:
	# Clear existing checkboxes
	for child in quests_container.get_children():
		child.queue_free()
	quest_checkboxes.clear()

	# Scan quest blueprints directory
	var quest_blueprints := _get_all_quest_blueprints()

	if quest_blueprints.is_empty():
		var no_quests_label := Label.new()
		no_quests_label.text = "(No quest blueprints found)"
		no_quests_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		quests_container.add_child(no_quests_label)
		return

	# Get current NPC ID for auto-detection
	var current_npc_id: String = npc_name_edit.text.strip_edges().to_lower().replace(" ", "_")

	for quest_info: Dictionary in quest_blueprints:
		var quest_id: String = quest_info.get("id", "")
		var quest_row := HBoxContainer.new()
		quest_row.add_theme_constant_override("separation", 8)

		# Check if quest is linked: either in our list OR quest has us as giver
		var is_linked: bool = quest_id in linked_quests
		var quest_giver: String = quest_info.get("giver_npc", "")
		if not is_linked and quest_giver == current_npc_id:
			# Quest has us as giver but we didn't have it in our list - add it
			is_linked = true
			if quest_id not in linked_quests:
				linked_quests.append(quest_id)

		var checkbox := CheckBox.new()
		checkbox.text = quest_info.get("name", quest_id.replace("_", " ").capitalize())
		checkbox.button_pressed = is_linked
		checkbox.toggled.connect(_on_quest_checkbox_toggled.bind(quest_id))
		quest_row.add_child(checkbox)
		quest_checkboxes[quest_id] = checkbox

		var view_button := Button.new()
		view_button.text = "View"
		view_button.pressed.connect(_on_view_quest_pressed.bind(quest_id))
		quest_row.add_child(view_button)

		quests_container.add_child(quest_row)


func _get_all_quest_blueprints() -> Array[Dictionary]:
	var quests: Array[Dictionary] = []
	var dir := DirAccess.open(QUEST_BLUEPRINT_DIR)
	if not dir:
		return quests

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			var path: String = QUEST_BLUEPRINT_DIR + file_name
			var file := FileAccess.open(path, FileAccess.READ)
			if file:
				var json := JSON.new()
				if json.parse(file.get_as_text()) == OK:
					var data: Dictionary = json.data
					var quest_id: String = file_name.get_basename()
					quests.append({
						"id": quest_id,
						"name": data.get("name", quest_id.replace("_", " ").capitalize()),
						"path": path,
						"giver_npc": data.get("giver_npc", "")
					})
				file.close()
		file_name = dir.get_next()
	dir.list_dir_end()
	return quests


func _on_quest_checkbox_toggled(pressed: bool, quest_id: String) -> void:
	if pressed:
		if quest_id not in linked_quests:
			linked_quests.append(quest_id)
	else:
		linked_quests.erase(quest_id)
	_on_field_changed()


func _on_view_quest_pressed(quest_id: String) -> void:
	# Find the quest editor tab and load this quest
	var parent_tab := get_parent()
	if parent_tab and parent_tab.has_method("_switch_to_quest_editor"):
		parent_tab._switch_to_quest_editor(quest_id)
	else:
		_set_status("Cannot open quest editor from here")


func _on_link_quest_pressed() -> void:
	_refresh_quest_list()
	_set_status("Quest list refreshed - check boxes to link quests")


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
		_refresh_quest_list()
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
	_refresh_quest_list()


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

	npc_name_edit.text = data.get("name", "")

	# Load dropdown values
	var npc_type: String = data.get("type", "Civilian")
	var type_idx: int = NPC_TYPES.find(npc_type.capitalize())
	type_dropdown.select(type_idx if type_idx >= 0 else 0)

	var race: String = data.get("race", "Human")
	var race_idx: int = RACES.find(race.capitalize())
	race_dropdown.select(race_idx if race_idx >= 0 else 0)

	var gender: String = data.get("gender", "Male")
	var gender_idx: int = GENDERS.find(gender.capitalize())
	gender_dropdown.select(gender_idx if gender_idx >= 0 else 0)

	who_edit.text = data.get("who", "")
	what_edit.text = data.get("what", "")
	where_edit.text = data.get("where", "")

	# Load linked quests - handle both old string format and new array format
	var quests_data: Variant = data.get("quests", [])
	linked_quests.clear()
	if quests_data is Array:
		for quest_id: Variant in quests_data:
			if quest_id is String:
				linked_quests.append(quest_id)
	elif quests_data is String and not quests_data.is_empty():
		# Old format: comma-separated string - convert to array
		var parts: PackedStringArray = quests_data.split(",")
		for part: String in parts:
			var trimmed: String = part.strip_edges().to_lower().replace(" ", "_")
			if not trimmed.is_empty():
				linked_quests.append(trimmed)

	current_blueprint_path = path
	unsaved_changes = false
	_update_unsaved_indicator()
	_refresh_quest_list()
	_set_status("Loaded: " + path.get_file())


func _on_new_pressed() -> void:
	_clear_form()
	current_blueprint_path = ""
	blueprint_dropdown.select(0)
	_set_status("New blueprint - fill in your NPC ideas")


func _clear_form() -> void:
	npc_name_edit.text = ""
	type_dropdown.select(0)
	race_dropdown.select(0)
	gender_dropdown.select(0)
	who_edit.text = ""
	what_edit.text = ""
	where_edit.text = ""
	linked_quests.clear()
	current_blueprint_path = ""
	unsaved_changes = false
	_update_unsaved_indicator()
	_refresh_quest_list()


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
	var npc_name: String = npc_name_edit.text.strip_edges()
	if npc_name.is_empty():
		_set_status("Enter an NPC name first")
		return

	# Generate filename from NPC name
	var new_file_name: String = npc_name.to_lower().replace(" ", "_") + ".json"
	var new_path: String = BLUEPRINT_DIR + new_file_name

	# If we had a previous path and name changed, delete old file
	if not current_blueprint_path.is_empty():
		var old_file_name: String = current_blueprint_path.get_file()
		if new_file_name != old_file_name:
			var del_err := DirAccess.remove_absolute(current_blueprint_path)
			if del_err == OK:
				_set_status("Renamed: " + old_file_name + " -> " + new_file_name)
			# Continue with save even if delete failed

	var data: Dictionary = {
		"name": npc_name,
		"type": NPC_TYPES[type_dropdown.selected].to_lower().replace(" ", "_"),
		"race": RACES[race_dropdown.selected].to_lower(),
		"gender": GENDERS[gender_dropdown.selected].to_lower(),
		"who": who_edit.text,
		"what": what_edit.text,
		"where": where_edit.text,
		"quests": linked_quests.duplicate()
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

	# Update any quest that lists this NPC as giver
	_sync_quests_with_npc(npc_name.to_lower().replace(" ", "_"))

	_set_status("Saved: " + new_file_name, SAVED_COLOR)


func _sync_quests_with_npc(npc_id: String) -> void:
	# Update quest blueprints to reflect this NPC's linked quests
	for quest_id: String in linked_quests:
		var quest_path: String = QUEST_BLUEPRINT_DIR + quest_id + ".json"
		var file := FileAccess.open(quest_path, FileAccess.READ)
		if file:
			var json := JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var quest_data: Dictionary = json.data
				file.close()

				# Update giver_npc field
				quest_data["giver_npc"] = npc_id

				var write_file := FileAccess.open(quest_path, FileAccess.WRITE)
				if write_file:
					write_file.store_string(JSON.stringify(quest_data, "  "))
					write_file.close()


func _on_field_changed(_value: Variant = null) -> void:
	unsaved_changes = true
	_update_unsaved_indicator()


func _on_dropdown_changed(_index: int) -> void:
	unsaved_changes = true
	_update_unsaved_indicator()


func _set_status(msg: String, color: Color = Color.WHITE) -> void:
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)


func _update_unsaved_indicator() -> void:
	if not title_label:
		return

	var base_title: String = "NPC Ideas"
	if not current_blueprint_path.is_empty():
		base_title = "NPC Ideas - " + current_blueprint_path.get_file().get_basename()

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
