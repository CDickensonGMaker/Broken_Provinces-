@tool
class_name ScriptedEventEditorDock
extends Control
## Scripted Event Editor - Timeline-based editor for in-game cutscenes and events
## Creates JSON event files that can be triggered in-game

const EVENT_DIR := "res://data/events/"

const ACTION_TYPES: Dictionary = {
	"dialogue": "Show Dialogue",
	"move_npc": "Move NPC",
	"spawn_npc": "Spawn NPC",
	"despawn_npc": "Despawn NPC",
	"camera_pan": "Camera Pan",
	"camera_shake": "Camera Shake",
	"play_sound": "Play Sound",
	"play_music": "Play Music",
	"fade_in": "Fade In",
	"fade_out": "Fade Out",
	"wait": "Wait",
	"set_flag": "Set Flag",
	"clear_flag": "Clear Flag",
	"give_item": "Give Item",
	"take_item": "Take Item",
	"give_gold": "Give Gold",
	"give_xp": "Give XP",
	"start_quest": "Start Quest",
	"complete_quest": "Complete Quest",
	"teleport_player": "Teleport Player",
	"set_time": "Set Time of Day",
	"spawn_enemy": "Spawn Enemy",
	"custom": "Custom Script"
}

# UI References
var split_container: HSplitContainer
var left_panel: VBoxContainer
var center_panel: VBoxContainer
var right_panel: VBoxContainer

# Left panel - Event list
var event_list: ItemList
var new_event_button: Button
var delete_event_button: Button

# Center panel - Timeline
var timeline_header: HBoxContainer
var event_name_edit: LineEdit
var event_description_edit: TextEdit
var trigger_type_option: OptionButton
var trigger_value_edit: LineEdit
var auto_play_check: CheckBox
var once_only_check: CheckBox
var timeline_list: ItemList
var new_action_button: Button
var delete_action_button: Button
var move_up_button: Button
var move_down_button: Button

# Right panel - Action editor
var action_editor_scroll: ScrollContainer
var action_editor: VBoxContainer
var action_type_option: OptionButton
var action_params_container: VBoxContainer
var action_delay_spin: SpinBox

# Dynamic action parameter editors
var param_edits: Dictionary = {}

# Status
var status_label: Label

# State
var current_event_path: String = ""
var current_event_data: Dictionary = {}
var current_action_index: int = -1
var unsaved_changes: bool = false


func _ready() -> void:
	# Ensure event directory exists
	_ensure_event_dir()
	_build_ui()
	_load_event_list()


func _ensure_event_dir() -> void:
	var dir := DirAccess.open("res://data/")
	if dir and not dir.dir_exists("events"):
		dir.make_dir("events")


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)

	# Toolbar
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)

	# Split container
	split_container = HSplitContainer.new()
	split_container.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(split_container)

	# Left panel - Event list
	left_panel = _create_left_panel()
	split_container.add_child(left_panel)

	# Center panel - Timeline
	center_panel = _create_center_panel()
	split_container.add_child(center_panel)

	# Right panel - Action editor
	right_panel = _create_right_panel()
	split_container.add_child(right_panel)

	# Status bar
	status_label = Label.new()
	status_label.text = "Ready"
	main_vbox.add_child(status_label)

	split_container.split_offset = 180


func _create_toolbar() -> HBoxContainer:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Scripted Event Editor"
	title.add_theme_font_size_override("font_size", 18)
	toolbar.add_child(title)

	toolbar.add_child(_create_spacer())

	var save_button := Button.new()
	save_button.text = "Save Event"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)

	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_on_reload_pressed)
	toolbar.add_child(reload_button)

	var preview_button := Button.new()
	preview_button.text = "Preview"
	preview_button.pressed.connect(_on_preview_pressed)
	toolbar.add_child(preview_button)

	return toolbar


func _create_left_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 180
	panel.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Events"
	header.add_theme_font_size_override("font_size", 14)
	panel.add_child(header)

	event_list = ItemList.new()
	event_list.size_flags_vertical = SIZE_EXPAND_FILL
	event_list.item_selected.connect(_on_event_selected)
	panel.add_child(event_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	panel.add_child(buttons)

	new_event_button = Button.new()
	new_event_button.text = "New"
	new_event_button.size_flags_horizontal = SIZE_EXPAND_FILL
	new_event_button.pressed.connect(_on_new_event_pressed)
	buttons.add_child(new_event_button)

	delete_event_button = Button.new()
	delete_event_button.text = "Delete"
	delete_event_button.size_flags_horizontal = SIZE_EXPAND_FILL
	delete_event_button.pressed.connect(_on_delete_event_pressed)
	buttons.add_child(delete_event_button)

	return panel


func _create_center_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4)

	# Event properties
	var props := VBoxContainer.new()
	props.add_theme_constant_override("separation", 4)
	panel.add_child(props)

	props.add_child(_create_section_header("Event Properties"))
	event_name_edit = _add_line_edit_field(props, "Event ID:")

	var desc_label := Label.new()
	desc_label.text = "Description:"
	props.add_child(desc_label)
	event_description_edit = TextEdit.new()
	event_description_edit.custom_minimum_size.y = 50
	event_description_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	props.add_child(event_description_edit)

	# Trigger settings
	var trigger_row := HBoxContainer.new()
	props.add_child(trigger_row)
	var trigger_label := Label.new()
	trigger_label.text = "Trigger:"
	trigger_label.custom_minimum_size.x = 80
	trigger_row.add_child(trigger_label)
	trigger_type_option = OptionButton.new()
	trigger_type_option.add_item("manual")
	trigger_type_option.add_item("on_enter_zone")
	trigger_type_option.add_item("on_interact")
	trigger_type_option.add_item("on_quest_complete")
	trigger_type_option.add_item("on_flag_set")
	trigger_type_option.add_item("on_time")
	trigger_row.add_child(trigger_type_option)

	trigger_value_edit = LineEdit.new()
	trigger_value_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	trigger_value_edit.placeholder_text = "Trigger value (zone_id, quest_id, etc.)"
	trigger_row.add_child(trigger_value_edit)

	# Options row
	var options_row := HBoxContainer.new()
	props.add_child(options_row)
	auto_play_check = CheckBox.new()
	auto_play_check.text = "Auto-play"
	options_row.add_child(auto_play_check)
	once_only_check = CheckBox.new()
	once_only_check.text = "Once only"
	once_only_check.button_pressed = true
	options_row.add_child(once_only_check)

	# Timeline section
	panel.add_child(_create_section_header("Timeline"))

	timeline_list = ItemList.new()
	timeline_list.size_flags_vertical = SIZE_EXPAND_FILL
	timeline_list.item_selected.connect(_on_action_selected)
	panel.add_child(timeline_list)

	# Timeline buttons
	var timeline_buttons := HBoxContainer.new()
	timeline_buttons.add_theme_constant_override("separation", 4)
	panel.add_child(timeline_buttons)

	new_action_button = Button.new()
	new_action_button.text = "Add Action"
	new_action_button.pressed.connect(_on_new_action_pressed)
	timeline_buttons.add_child(new_action_button)

	delete_action_button = Button.new()
	delete_action_button.text = "Delete"
	delete_action_button.pressed.connect(_on_delete_action_pressed)
	timeline_buttons.add_child(delete_action_button)

	move_up_button = Button.new()
	move_up_button.text = "Up"
	move_up_button.pressed.connect(_on_move_up_pressed)
	timeline_buttons.add_child(move_up_button)

	move_down_button = Button.new()
	move_down_button.text = "Down"
	move_down_button.pressed.connect(_on_move_down_pressed)
	timeline_buttons.add_child(move_down_button)

	return panel


func _create_right_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 350
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4)

	panel.add_child(_create_section_header("Action Editor"))

	action_editor_scroll = ScrollContainer.new()
	action_editor_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	action_editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(action_editor_scroll)

	action_editor = VBoxContainer.new()
	action_editor.size_flags_horizontal = SIZE_EXPAND_FILL
	action_editor.add_theme_constant_override("separation", 6)
	action_editor_scroll.add_child(action_editor)

	# Action type
	var type_row := HBoxContainer.new()
	action_editor.add_child(type_row)
	var type_label := Label.new()
	type_label.text = "Type:"
	type_label.custom_minimum_size.x = 80
	type_row.add_child(type_label)
	action_type_option = OptionButton.new()
	action_type_option.size_flags_horizontal = SIZE_EXPAND_FILL
	for key: String in ACTION_TYPES:
		action_type_option.add_item(ACTION_TYPES[key])
		action_type_option.set_item_metadata(action_type_option.item_count - 1, key)
	action_type_option.item_selected.connect(_on_action_type_changed)
	type_row.add_child(action_type_option)

	# Delay
	var delay_row := HBoxContainer.new()
	action_editor.add_child(delay_row)
	var delay_label := Label.new()
	delay_label.text = "Delay (s):"
	delay_label.custom_minimum_size.x = 80
	delay_row.add_child(delay_label)
	action_delay_spin = SpinBox.new()
	action_delay_spin.min_value = 0.0
	action_delay_spin.max_value = 60.0
	action_delay_spin.step = 0.1
	action_delay_spin.value = 0.0
	delay_row.add_child(action_delay_spin)

	# Dynamic parameters container
	action_params_container = VBoxContainer.new()
	action_params_container.add_theme_constant_override("separation", 4)
	action_editor.add_child(action_params_container)

	# Apply button
	var apply_button := Button.new()
	apply_button.text = "Apply Action Changes"
	apply_button.pressed.connect(_apply_action_changes)
	action_editor.add_child(apply_button)

	return panel


func _create_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	return label


func _add_line_edit_field(parent: Control, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	row.add_child(label)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(edit)

	return edit


func _create_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


# =============================================================================
# EVENT LIST MANAGEMENT
# =============================================================================

func _load_event_list() -> void:
	event_list.clear()

	var dir := DirAccess.open(EVENT_DIR)
	if not dir:
		_set_status("Event directory not found - create one to get started")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while not file_name.is_empty():
		if file_name.ends_with(".json"):
			event_list.add_item(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()

	_set_status("Loaded %d events" % event_list.item_count)


func _on_event_selected(index: int) -> void:
	var event_name: String = event_list.get_item_text(index)
	var path: String = EVENT_DIR + event_name + ".json"
	_load_event(path)


func _load_event(path: String) -> void:
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

	current_event_path = path
	current_event_data = json.data
	current_action_index = -1

	# Populate fields
	event_name_edit.text = current_event_data.get("id", "")
	event_description_edit.text = current_event_data.get("description", "")

	var trigger_type: String = current_event_data.get("trigger_type", "manual")
	for i: int in range(trigger_type_option.item_count):
		if trigger_type_option.get_item_text(i) == trigger_type:
			trigger_type_option.select(i)
			break

	trigger_value_edit.text = current_event_data.get("trigger_value", "")
	auto_play_check.button_pressed = current_event_data.get("auto_play", false)
	once_only_check.button_pressed = current_event_data.get("once_only", true)

	_refresh_timeline()
	_clear_action_editor()

	unsaved_changes = false
	_set_status("Loaded: " + event_name_edit.text)


# =============================================================================
# TIMELINE MANAGEMENT
# =============================================================================

func _refresh_timeline() -> void:
	timeline_list.clear()

	var actions: Array = current_event_data.get("actions", [])
	for i: int in range(actions.size()):
		var action: Dictionary = actions[i]
		var action_type: String = action.get("type", "wait")
		var delay: float = action.get("delay", 0.0)
		var display_name: String = ACTION_TYPES.get(action_type, action_type)

		var display: String = "%d. %s" % [i + 1, display_name]
		if delay > 0:
			display += " (%.1fs)" % delay

		# Add brief param info
		match action_type:
			"dialogue":
				var text: String = action.get("text", "")
				if text.length() > 20:
					text = text.substr(0, 20) + "..."
				display += ": \"%s\"" % text
			"move_npc", "spawn_npc", "despawn_npc":
				display += ": %s" % action.get("npc_id", "?")
			"play_sound", "play_music":
				display += ": %s" % action.get("sound", action.get("music", "?"))
			"wait":
				display += ": %.1fs" % action.get("duration", 1.0)
			"set_flag", "clear_flag":
				display += ": %s" % action.get("flag", "?")

		timeline_list.add_item(display)


func _on_action_selected(index: int) -> void:
	current_action_index = index
	_load_action_to_editor(index)


func _load_action_to_editor(index: int) -> void:
	var actions: Array = current_event_data.get("actions", [])
	if index < 0 or index >= actions.size():
		_clear_action_editor()
		return

	var action: Dictionary = actions[index]
	var action_type: String = action.get("type", "wait")

	# Find and select action type
	for i: int in range(action_type_option.item_count):
		if action_type_option.get_item_metadata(i) == action_type:
			action_type_option.select(i)
			break

	action_delay_spin.value = action.get("delay", 0.0)

	# Build parameter UI for this action type
	_build_action_params(action_type, action)


func _clear_action_editor() -> void:
	action_type_option.select(0)
	action_delay_spin.value = 0.0
	_clear_action_params()
	current_action_index = -1


func _clear_action_params() -> void:
	for child in action_params_container.get_children():
		child.queue_free()
	param_edits.clear()


func _on_action_type_changed(_index: int) -> void:
	var action_type: String = action_type_option.get_selected_metadata()
	_build_action_params(action_type, {})


func _build_action_params(action_type: String, existing_data: Dictionary) -> void:
	_clear_action_params()

	match action_type:
		"dialogue":
			_add_param_line_edit("speaker", "Speaker:", existing_data.get("speaker", ""))
			_add_param_text_edit("text", "Text:", existing_data.get("text", ""))

		"move_npc":
			_add_param_line_edit("npc_id", "NPC ID:", existing_data.get("npc_id", ""))
			_add_param_vector3("target_pos", "Target Position:", existing_data.get("target_pos", {"x": 0, "y": 0, "z": 0}))
			_add_param_spin("speed", "Speed:", existing_data.get("speed", 3.0), 0.1, 20.0)

		"spawn_npc":
			_add_param_line_edit("npc_id", "NPC ID:", existing_data.get("npc_id", ""))
			_add_param_line_edit("npc_type", "NPC Type:", existing_data.get("npc_type", "civilian"))
			_add_param_vector3("position", "Position:", existing_data.get("position", {"x": 0, "y": 0, "z": 0}))

		"despawn_npc":
			_add_param_line_edit("npc_id", "NPC ID:", existing_data.get("npc_id", ""))

		"camera_pan":
			_add_param_vector3("target", "Target Position:", existing_data.get("target", {"x": 0, "y": 0, "z": 0}))
			_add_param_spin("duration", "Duration (s):", existing_data.get("duration", 2.0), 0.1, 30.0)

		"camera_shake":
			_add_param_spin("intensity", "Intensity:", existing_data.get("intensity", 1.0), 0.1, 10.0)
			_add_param_spin("duration", "Duration (s):", existing_data.get("duration", 0.5), 0.1, 10.0)

		"play_sound":
			_add_param_line_edit("sound", "Sound Path:", existing_data.get("sound", ""))
			_add_param_spin("volume", "Volume (dB):", existing_data.get("volume", 0.0), -40.0, 20.0)

		"play_music":
			_add_param_line_edit("music", "Music Path:", existing_data.get("music", ""))
			_add_param_spin("fade_time", "Fade Time (s):", existing_data.get("fade_time", 1.0), 0.0, 10.0)

		"fade_in", "fade_out":
			_add_param_spin("duration", "Duration (s):", existing_data.get("duration", 1.0), 0.1, 10.0)
			_add_param_color("color", "Color:", existing_data.get("color", {"r": 0, "g": 0, "b": 0}))

		"wait":
			_add_param_spin("duration", "Duration (s):", existing_data.get("duration", 1.0), 0.1, 60.0)

		"set_flag", "clear_flag":
			_add_param_line_edit("flag", "Flag Name:", existing_data.get("flag", ""))

		"give_item", "take_item":
			_add_param_line_edit("item_id", "Item ID:", existing_data.get("item_id", ""))
			_add_param_spin("quantity", "Quantity:", existing_data.get("quantity", 1), 1, 99)

		"give_gold":
			_add_param_spin("amount", "Amount:", existing_data.get("amount", 100), 1, 10000)

		"give_xp":
			_add_param_spin("amount", "Amount:", existing_data.get("amount", 100), 1, 10000)

		"start_quest", "complete_quest":
			_add_param_line_edit("quest_id", "Quest ID:", existing_data.get("quest_id", ""))

		"teleport_player":
			_add_param_line_edit("zone_id", "Zone ID:", existing_data.get("zone_id", ""))
			_add_param_line_edit("spawn_id", "Spawn ID:", existing_data.get("spawn_id", "default"))

		"set_time":
			_add_param_line_edit("time", "Time of Day:", existing_data.get("time", "noon"))

		"spawn_enemy":
			_add_param_line_edit("enemy_id", "Enemy ID:", existing_data.get("enemy_id", ""))
			_add_param_vector3("position", "Position:", existing_data.get("position", {"x": 0, "y": 0, "z": 0}))

		"custom":
			_add_param_line_edit("method", "Method Name:", existing_data.get("method", ""))
			_add_param_line_edit("args", "Arguments (JSON):", existing_data.get("args", "{}"))


func _add_param_line_edit(key: String, label: String, value: String) -> void:
	var row := HBoxContainer.new()
	action_params_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 100
	row.add_child(lbl)

	var edit := LineEdit.new()
	edit.text = value
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(edit)

	param_edits[key] = edit


func _add_param_text_edit(key: String, label: String, value: String) -> void:
	var lbl := Label.new()
	lbl.text = label
	action_params_container.add_child(lbl)

	var edit := TextEdit.new()
	edit.text = value
	edit.custom_minimum_size.y = 60
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	action_params_container.add_child(edit)

	param_edits[key] = edit


func _add_param_spin(key: String, label: String, value: float, min_val: float, max_val: float) -> void:
	var row := HBoxContainer.new()
	action_params_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 100
	row.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.step = 0.1 if max_val <= 100 else 1
	spin.value = value
	row.add_child(spin)

	param_edits[key] = spin


func _add_param_vector3(key: String, label: String, value: Dictionary) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	action_params_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 80
	row.add_child(lbl)

	var x_spin := SpinBox.new()
	x_spin.min_value = -1000
	x_spin.max_value = 1000
	x_spin.step = 0.5
	x_spin.value = value.get("x", 0)
	x_spin.prefix = "X:"
	x_spin.custom_minimum_size.x = 70
	row.add_child(x_spin)

	var y_spin := SpinBox.new()
	y_spin.min_value = -100
	y_spin.max_value = 100
	y_spin.step = 0.1
	y_spin.value = value.get("y", 0)
	y_spin.prefix = "Y:"
	y_spin.custom_minimum_size.x = 70
	row.add_child(y_spin)

	var z_spin := SpinBox.new()
	z_spin.min_value = -1000
	z_spin.max_value = 1000
	z_spin.step = 0.5
	z_spin.value = value.get("z", 0)
	z_spin.prefix = "Z:"
	z_spin.custom_minimum_size.x = 70
	row.add_child(z_spin)

	param_edits[key] = {"x": x_spin, "y": y_spin, "z": z_spin}


func _add_param_color(key: String, label: String, value: Dictionary) -> void:
	var row := HBoxContainer.new()
	action_params_container.add_child(row)

	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 100
	row.add_child(lbl)

	var picker := ColorPickerButton.new()
	picker.color = Color(value.get("r", 0), value.get("g", 0), value.get("b", 0))
	row.add_child(picker)

	param_edits[key] = picker


func _apply_action_changes() -> void:
	if current_action_index < 0:
		_set_status("No action selected")
		return

	var actions: Array = current_event_data.get("actions", [])
	if current_action_index >= actions.size():
		return

	var action: Dictionary = {}
	action["type"] = action_type_option.get_selected_metadata()
	action["delay"] = action_delay_spin.value

	# Collect parameters
	for key: String in param_edits:
		var editor: Variant = param_edits[key]
		if editor is LineEdit:
			action[key] = editor.text
		elif editor is TextEdit:
			action[key] = editor.text
		elif editor is SpinBox:
			action[key] = editor.value
		elif editor is ColorPickerButton:
			action[key] = {"r": editor.color.r, "g": editor.color.g, "b": editor.color.b}
		elif editor is Dictionary:
			# Vector3
			action[key] = {
				"x": editor["x"].value,
				"y": editor["y"].value,
				"z": editor["z"].value
			}

	actions[current_action_index] = action
	unsaved_changes = true
	_refresh_timeline()
	_set_status("Applied action changes")


func _on_new_action_pressed() -> void:
	if current_event_data.is_empty():
		_set_status("Load or create an event first")
		return

	var actions: Array = current_event_data.get("actions", [])
	var new_action: Dictionary = {
		"type": "wait",
		"delay": 0.0,
		"duration": 1.0
	}

	actions.append(new_action)
	current_event_data["actions"] = actions
	unsaved_changes = true

	_refresh_timeline()
	current_action_index = actions.size() - 1
	_load_action_to_editor(current_action_index)
	_set_status("Added new action")


func _on_delete_action_pressed() -> void:
	if current_action_index < 0:
		return

	var actions: Array = current_event_data.get("actions", [])
	if current_action_index >= actions.size():
		return

	actions.remove_at(current_action_index)
	current_event_data["actions"] = actions
	unsaved_changes = true

	current_action_index = -1
	_clear_action_editor()
	_refresh_timeline()
	_set_status("Deleted action")


func _on_move_up_pressed() -> void:
	if current_action_index <= 0:
		return

	var actions: Array = current_event_data.get("actions", [])
	var action: Dictionary = actions[current_action_index]
	actions.remove_at(current_action_index)
	actions.insert(current_action_index - 1, action)
	current_event_data["actions"] = actions
	unsaved_changes = true

	current_action_index -= 1
	_refresh_timeline()
	timeline_list.select(current_action_index)


func _on_move_down_pressed() -> void:
	var actions: Array = current_event_data.get("actions", [])
	if current_action_index < 0 or current_action_index >= actions.size() - 1:
		return

	var action: Dictionary = actions[current_action_index]
	actions.remove_at(current_action_index)
	actions.insert(current_action_index + 1, action)
	current_event_data["actions"] = actions
	unsaved_changes = true

	current_action_index += 1
	_refresh_timeline()
	timeline_list.select(current_action_index)


# =============================================================================
# SAVE AND LOAD
# =============================================================================

func _on_save_pressed() -> void:
	if current_event_path.is_empty():
		_set_status("No event loaded")
		return

	# Update event data from fields
	current_event_data["id"] = event_name_edit.text
	current_event_data["description"] = event_description_edit.text
	current_event_data["trigger_type"] = trigger_type_option.get_item_text(trigger_type_option.selected)
	current_event_data["trigger_value"] = trigger_value_edit.text
	current_event_data["auto_play"] = auto_play_check.button_pressed
	current_event_data["once_only"] = once_only_check.button_pressed

	var json_string: String = JSON.stringify(current_event_data, "\t")
	var file := FileAccess.open(current_event_path, FileAccess.WRITE)
	if not file:
		_set_status("Failed to save file")
		return

	file.store_string(json_string)
	file.close()

	unsaved_changes = false
	_set_status("Saved: " + event_name_edit.text)


func _on_reload_pressed() -> void:
	if not current_event_path.is_empty():
		_load_event(current_event_path)
	else:
		_load_event_list()


func _on_preview_pressed() -> void:
	_set_status("Preview not available in editor - test in-game")


func _on_new_event_pressed() -> void:
	var new_id: String = "new_event_%d" % Time.get_unix_time_from_system()
	var new_event: Dictionary = {
		"id": new_id,
		"description": "New scripted event",
		"trigger_type": "manual",
		"trigger_value": "",
		"auto_play": false,
		"once_only": true,
		"actions": []
	}

	var path: String = EVENT_DIR + new_id + ".json"
	var json_string: String = JSON.stringify(new_event, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_set_status("Failed to create event file")
		return

	file.store_string(json_string)
	file.close()

	_load_event_list()
	_load_event(path)
	_set_status("Created new event")


func _on_delete_event_pressed() -> void:
	if current_event_path.is_empty():
		return

	var dir := DirAccess.open(EVENT_DIR)
	if dir:
		var file_name: String = current_event_path.get_file()
		dir.remove(file_name)
		_set_status("Deleted: " + file_name)

		current_event_path = ""
		current_event_data = {}
		_load_event_list()


func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
