## companion_command_ui.gd - UI element showing companion command mode and available commands
## Displays when command mode is active with available command options
## Shows visual feedback when a command is issued
class_name CompanionCommandUI
extends Control

## Command input keys (primary)
const KEY_FOLLOW := KEY_1
const KEY_WAIT := KEY_2
const KEY_ATTACK := KEY_3
const KEY_DEFEND := KEY_4

## Alternative function keys
const KEY_F_FOLLOW := KEY_F1
const KEY_F_WAIT := KEY_F2
const KEY_F_ATTACK := KEY_F3
const KEY_F_DEFEND := KEY_F4

## Visual constants
const PANEL_WIDTH := 280
const PANEL_HEIGHT := 90
const COMMAND_FEEDBACK_DURATION := 1.0
const FADE_SPEED := 4.0

## Colors
const COL_ACTIVE := Color(0.9, 0.85, 0.7, 1.0)
const COL_INACTIVE := Color(0.5, 0.45, 0.4, 0.8)
const COL_HIGHLIGHT := Color(1.0, 0.9, 0.5, 1.0)
const COL_FOLLOW := Color(0.5, 0.9, 0.5, 1.0)
const COL_WAIT := Color(0.9, 0.9, 0.5, 1.0)
const COL_ATTACK := Color(0.9, 0.5, 0.5, 1.0)
const COL_DEFEND := Color(0.5, 0.7, 0.9, 1.0)

## UI elements
var panel: PanelContainer
var title_label: Label
var commands_container: HBoxContainer
var command_labels: Dictionary = {}  # "follow" -> Label
var feedback_label: Label

## State
var is_command_mode_active: bool = false
var feedback_timer: float = 0.0
var current_alpha: float = 0.0
var target_alpha: float = 0.0

## Cached reference to CompanionManager
var _companion_manager: Node = null


func _ready() -> void:
	name = "CompanionCommandUI"

	# Build UI
	_create_ui()

	# Connect to CompanionManager
	_connect_companion_manager()

	# Initially hidden
	modulate.a = 0.0


func _process(delta: float) -> void:
	# Update feedback timer
	if feedback_timer > 0:
		feedback_timer -= delta
		if feedback_timer <= 0:
			feedback_label.visible = false

	# Smooth fade in/out
	if current_alpha != target_alpha:
		if current_alpha < target_alpha:
			current_alpha = minf(current_alpha + delta * FADE_SPEED, target_alpha)
		else:
			current_alpha = maxf(current_alpha - delta * FADE_SPEED, target_alpha)
		modulate.a = current_alpha


func _input(event: InputEvent) -> void:
	# Only process when command mode is active
	if not is_command_mode_active:
		return

	# Skip if typing in a text field or menu is open
	if _is_typing_or_menu_open():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey

		match key_event.keycode:
			KEY_FOLLOW, KEY_F_FOLLOW:
				_issue_command("follow")
				get_viewport().set_input_as_handled()
			KEY_WAIT, KEY_F_WAIT:
				_issue_command("wait")
				get_viewport().set_input_as_handled()
			KEY_ATTACK, KEY_F_ATTACK:
				_issue_command("attack")
				get_viewport().set_input_as_handled()
			KEY_DEFEND, KEY_F_DEFEND:
				_issue_command("defend")
				get_viewport().set_input_as_handled()


func _create_ui() -> void:
	custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)

	# Main panel
	panel = PanelContainer.new()
	panel.name = "CommandPanel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0

	# Panel style - dark with golden border
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.6, 0.5, 0.3, 0.9)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	# Vertical layout
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Title row
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	vbox.add_child(title_row)

	title_label = Label.new()
	title_label.text = "COMPANION COMMANDS"
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", COL_ACTIVE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	# Commands container
	commands_container = HBoxContainer.new()
	commands_container.add_theme_constant_override("separation", 12)
	commands_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(commands_container)

	# Create command options
	_create_command_option("follow", "[1] Follow", COL_FOLLOW)
	_create_command_option("wait", "[2] Wait", COL_WAIT)
	_create_command_option("attack", "[3] Attack", COL_ATTACK)
	_create_command_option("defend", "[4] Defend", COL_DEFEND)

	# Feedback label (shown briefly when command issued)
	feedback_label = Label.new()
	feedback_label.name = "FeedbackLabel"
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", COL_HIGHLIGHT)
	feedback_label.visible = false
	vbox.add_child(feedback_label)


func _create_command_option(cmd_id: String, text: String, color: Color) -> void:
	var label := Label.new()
	label.name = "Cmd_%s" % cmd_id
	label.text = text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", color)
	commands_container.add_child(label)
	command_labels[cmd_id] = label


func _connect_companion_manager() -> void:
	_companion_manager = get_node_or_null("/root/CompanionManager")
	if not _companion_manager:
		return

	# Listen for commanded signal to update highlight
	if _companion_manager.has_signal("all_companions_commanded"):
		if not _companion_manager.all_companions_commanded.is_connected(_on_command_issued):
			_companion_manager.all_companions_commanded.connect(_on_command_issued)


## Issue a command via CompanionManager
func _issue_command(command: String) -> void:
	if not _companion_manager:
		_companion_manager = get_node_or_null("/root/CompanionManager")

	if _companion_manager and _companion_manager.has_method("command_all"):
		match command:
			"follow":
				_companion_manager.command_all(CompanionNPC.CompanionCommand.FOLLOW)
			"wait":
				_companion_manager.command_all(CompanionNPC.CompanionCommand.WAIT)
			"attack":
				_companion_manager.command_all(CompanionNPC.CompanionCommand.ATTACK_TARGET)
			"defend":
				_companion_manager.command_all(CompanionNPC.CompanionCommand.DEFEND_POSITION)

	# Show visual feedback
	_show_command_feedback(command)


## Show feedback when command is issued
func _show_command_feedback(command: String) -> void:
	var feedback_text: String = ""
	var feedback_color: Color = COL_HIGHLIGHT

	match command:
		"follow":
			feedback_text = "Companions: FOLLOW"
			feedback_color = COL_FOLLOW
		"wait":
			feedback_text = "Companions: WAIT"
			feedback_color = COL_WAIT
		"attack":
			feedback_text = "Companions: ATTACK"
			feedback_color = COL_ATTACK
		"defend":
			feedback_text = "Companions: DEFEND"
			feedback_color = COL_DEFEND

	feedback_label.text = feedback_text
	feedback_label.add_theme_color_override("font_color", feedback_color)
	feedback_label.visible = true
	feedback_timer = COMMAND_FEEDBACK_DURATION

	# Highlight the corresponding command label briefly
	_highlight_command(command)


## Highlight a command label
func _highlight_command(command: String) -> void:
	# Reset all labels to normal
	for cmd_id: String in command_labels:
		var label: Label = command_labels[cmd_id]
		label.add_theme_font_size_override("font_size", 10)

	# Make the selected one larger
	if command_labels.has(command):
		var label: Label = command_labels[command]
		label.add_theme_font_size_override("font_size", 12)

		# Schedule reset
		get_tree().create_timer(0.3).timeout.connect(func():
			if is_instance_valid(label):
				label.add_theme_font_size_override("font_size", 10)
		)


## Called when CompanionManager reports a command was issued
func _on_command_issued(command: CompanionNPC.CompanionCommand) -> void:
	# Map command enum to display string
	var display_cmd: String = "follow"
	match command:
		CompanionNPC.CompanionCommand.FOLLOW:
			display_cmd = "follow"
		CompanionNPC.CompanionCommand.WAIT:
			display_cmd = "wait"
		CompanionNPC.CompanionCommand.ATTACK_TARGET:
			display_cmd = "attack"
		CompanionNPC.CompanionCommand.DEFEND_POSITION:
			display_cmd = "defend"

	_show_command_feedback(display_cmd)


## Show the command UI
func show_command_mode() -> void:
	is_command_mode_active = true
	target_alpha = 1.0


## Hide the command UI
func hide_command_mode() -> void:
	is_command_mode_active = false
	target_alpha = 0.0


## Toggle command mode
func toggle_command_mode() -> void:
	if is_command_mode_active:
		hide_command_mode()
	else:
		show_command_mode()


## Check if command mode is active
func is_active() -> bool:
	return is_command_mode_active


## Check if player is typing or a menu is open
func _is_typing_or_menu_open() -> bool:
	# Check for active menus
	var game_menu := get_tree().get_first_node_in_group("game_menu")
	if game_menu and game_menu is Control and (game_menu as Control).visible:
		return true

	# Check for dialogue
	var dialogue_manager := get_node_or_null("/root/DialogueManager")
	if dialogue_manager and "is_dialogue_active" in dialogue_manager:
		if dialogue_manager.is_dialogue_active:
			return true

	# Check for conversation system
	var conversation := get_node_or_null("/root/ConversationSystem")
	if conversation and "is_active" in conversation:
		if conversation.is_active:
			return true

	return false


## Set whether this UI should be enabled (companions exist)
func set_enabled(enabled: bool) -> void:
	if enabled:
		show_command_mode()
	else:
		hide_command_mode()
