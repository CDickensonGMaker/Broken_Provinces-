## timed_objective_ui.gd - UI element showing countdown timer for timed objectives
## Displays MM:SS countdown with color changes and flashing effect
class_name TimedObjectiveUI
extends Control

## Colors (PS1 gothic aesthetic)
const COL_TIME_SAFE: Color = Color(0.3, 0.8, 0.3)  # Green - plenty of time
const COL_TIME_WARNING: Color = Color(0.9, 0.8, 0.2)  # Yellow - getting low
const COL_TIME_DANGER: Color = Color(0.9, 0.2, 0.2)  # Red - critical
const COL_TIME_CRITICAL: Color = Color(1.0, 0.1, 0.1)  # Bright red - flashing
const COL_DESCRIPTION: Color = Color(0.8, 0.75, 0.65)  # Light tan for description
const COL_PANEL_BG: Color = Color(0.05, 0.03, 0.08, 0.9)  # Dark purple-black
const COL_PANEL_BORDER: Color = Color(0.5, 0.25, 0.15)  # Bronze border

## Time thresholds (in seconds)
const THRESHOLD_WARNING := 60.0  # Yellow when under 1 minute
const THRESHOLD_DANGER := 30.0  # Red when under 30 seconds
const THRESHOLD_CRITICAL := 10.0  # Flash when under 10 seconds

## Node references (created in _ready)
var panel: PanelContainer
var vbox: VBoxContainer
var timer_label: Label
var description_label: Label
var quest_title_label: Label

## Flash state for critical time
var _flash_timer: float = 0.0
var _flash_visible: bool = true
const FLASH_SPEED := 4.0  # Flashes per second

## Current timer data
var _current_quest_id: String = ""
var _current_objective_id: String = ""
var _time_remaining: float = 0.0


func _ready() -> void:
	_create_ui()
	visible = false  # Hidden by default
	_connect_quest_manager_signals()


func _process(delta: float) -> void:
	if not visible:
		return

	# Handle flashing effect for critical time
	if _time_remaining <= THRESHOLD_CRITICAL and _time_remaining > 0:
		_flash_timer += delta * FLASH_SPEED * 2.0 * PI
		var flash_alpha: float = 0.5 + 0.5 * sin(_flash_timer)
		timer_label.modulate.a = flash_alpha
	else:
		timer_label.modulate.a = 1.0


## Create the UI elements programmatically (matches PS1 aesthetic)
func _create_ui() -> void:
	# Main panel with dark background
	panel = PanelContainer.new()
	panel.name = "TimerPanel"

	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL_BG
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = COL_PANEL_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	# Vertical container for labels
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Quest title (small, above timer)
	quest_title_label = Label.new()
	quest_title_label.name = "QuestTitleLabel"
	quest_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quest_title_label.add_theme_color_override("font_color", COL_DESCRIPTION)
	quest_title_label.add_theme_font_size_override("font_size", 12)
	quest_title_label.text = ""
	vbox.add_child(quest_title_label)

	# Timer display (large, prominent)
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_color_override("font_color", COL_TIME_SAFE)
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.text = "00:00"
	vbox.add_child(timer_label)

	# Objective description (smaller, below timer)
	description_label = Label.new()
	description_label.name = "DescriptionLabel"
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.add_theme_color_override("font_color", COL_DESCRIPTION)
	description_label.add_theme_font_size_override("font_size", 14)
	description_label.text = ""
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.x = 200
	vbox.add_child(description_label)


## Connect to QuestManager signals
func _connect_quest_manager_signals() -> void:
	if not QuestManager:
		push_warning("[TimedObjectiveUI] QuestManager not available")
		return

	if QuestManager.has_signal("timed_objective_started"):
		if not QuestManager.timed_objective_started.is_connected(_on_timed_objective_started):
			QuestManager.timed_objective_started.connect(_on_timed_objective_started)

	if QuestManager.has_signal("timed_objective_tick"):
		if not QuestManager.timed_objective_tick.is_connected(_on_timed_objective_tick):
			QuestManager.timed_objective_tick.connect(_on_timed_objective_tick)

	if QuestManager.has_signal("objective_time_expired"):
		if not QuestManager.objective_time_expired.is_connected(_on_objective_time_expired):
			QuestManager.objective_time_expired.connect(_on_objective_time_expired)

	if QuestManager.has_signal("objective_completed"):
		if not QuestManager.objective_completed.is_connected(_on_objective_completed):
			QuestManager.objective_completed.connect(_on_objective_completed)

	if QuestManager.has_signal("quest_completed"):
		if not QuestManager.quest_completed.is_connected(_on_quest_ended):
			QuestManager.quest_completed.connect(_on_quest_ended)

	if QuestManager.has_signal("quest_failed"):
		if not QuestManager.quest_failed.is_connected(_on_quest_ended):
			QuestManager.quest_failed.connect(_on_quest_ended)


## Format seconds into MM:SS string
func _format_time(seconds: float) -> String:
	var mins: int = int(seconds) / 60
	var secs: int = int(seconds) % 60
	return "%02d:%02d" % [mins, secs]


## Get color based on time remaining
func _get_time_color(seconds: float) -> Color:
	if seconds <= THRESHOLD_CRITICAL:
		return COL_TIME_CRITICAL
	elif seconds <= THRESHOLD_DANGER:
		return COL_TIME_DANGER
	elif seconds <= THRESHOLD_WARNING:
		return COL_TIME_WARNING
	else:
		return COL_TIME_SAFE


## Update the timer display
func _update_display(time_remaining: float, description: String = "", quest_title: String = "") -> void:
	_time_remaining = time_remaining

	# Update timer text
	timer_label.text = _format_time(time_remaining)

	# Update timer color based on urgency
	var color: Color = _get_time_color(time_remaining)
	timer_label.add_theme_color_override("font_color", color)

	# Update description if provided
	if not description.is_empty():
		description_label.text = description
		description_label.visible = true
	else:
		description_label.visible = false

	# Update quest title if provided
	if not quest_title.is_empty():
		quest_title_label.text = quest_title
		quest_title_label.visible = true
	else:
		quest_title_label.visible = false

	# Reset flash timer when entering critical phase
	if time_remaining <= THRESHOLD_CRITICAL and _time_remaining > THRESHOLD_CRITICAL:
		_flash_timer = 0.0


## Signal handlers
func _on_timed_objective_started(quest_id: String, objective_id: String, time_limit: int) -> void:
	_current_quest_id = quest_id
	_current_objective_id = objective_id
	_flash_timer = 0.0

	# Get objective and quest info from QuestManager
	var timed_info: Dictionary = QuestManager.get_active_timed_objective()
	var description: String = timed_info.get("description", "")
	var quest_title: String = timed_info.get("quest_title", "")

	_update_display(float(time_limit), description, quest_title)
	visible = true

	# Play start sound (optional)
	if AudioManager:
		AudioManager.play_ui_confirm()


func _on_timed_objective_tick(quest_id: String, objective_id: String, time_remaining: float) -> void:
	# Only update if this is our current objective
	if quest_id != _current_quest_id or objective_id != _current_objective_id:
		# Check if we should switch to tracking this objective
		if not _current_quest_id.is_empty():
			return
		_current_quest_id = quest_id
		_current_objective_id = objective_id

	# Get current info (description might have changed)
	var timed_info: Dictionary = QuestManager.get_active_timed_objective()
	var description: String = timed_info.get("description", "")
	var quest_title: String = timed_info.get("quest_title", "")

	_update_display(time_remaining, description, quest_title)

	if not visible:
		visible = true

	# Play warning sounds at key thresholds
	if AudioManager:
		if time_remaining <= THRESHOLD_CRITICAL and _time_remaining > THRESHOLD_CRITICAL:
			# Just crossed into critical - play urgent sound
			AudioManager.play_ui_cancel()  # Use cancel sound for urgent warning
		elif time_remaining <= THRESHOLD_DANGER and _time_remaining > THRESHOLD_DANGER:
			# Just crossed into danger - play warning sound
			AudioManager.play_ui_select()  # Use select sound for warning

	_time_remaining = time_remaining


func _on_objective_time_expired(quest_id: String, objective_id: String) -> void:
	if quest_id == _current_quest_id and objective_id == _current_objective_id:
		# Play failure sound
		if AudioManager:
			AudioManager.play_ui_cancel()

		# Show expired state briefly before hiding
		timer_label.text = "TIME UP!"
		timer_label.add_theme_color_override("font_color", COL_TIME_CRITICAL)
		timer_label.modulate.a = 1.0

		# Hide after delay
		get_tree().create_timer(2.0).timeout.connect(_on_hide_after_expired)


func _on_objective_completed(quest_id: String, objective_id: String) -> void:
	if quest_id == _current_quest_id and objective_id == _current_objective_id:
		# Check if there's another timed objective
		var next_timed: Dictionary = QuestManager.get_active_timed_objective()
		if next_timed.is_empty():
			_hide_timer()
		else:
			# Switch to next timed objective
			_current_quest_id = next_timed.get("quest_id", "")
			_current_objective_id = next_timed.get("objective_id", "")
			_update_display(
				next_timed.get("time_remaining", 0.0),
				next_timed.get("description", ""),
				next_timed.get("quest_title", "")
			)


func _on_quest_ended(quest_id: String) -> void:
	if quest_id == _current_quest_id:
		_hide_timer()


func _on_hide_after_expired() -> void:
	_hide_timer()


## Hide the timer and reset state
func _hide_timer() -> void:
	visible = false
	_current_quest_id = ""
	_current_objective_id = ""
	_time_remaining = 0.0
	_flash_timer = 0.0
	timer_label.modulate.a = 1.0


## Show the timer UI (for manual control)
func show_timer() -> void:
	var timed_info: Dictionary = QuestManager.get_active_timed_objective()
	if not timed_info.is_empty():
		_current_quest_id = timed_info.get("quest_id", "")
		_current_objective_id = timed_info.get("objective_id", "")
		_update_display(
			timed_info.get("time_remaining", 0.0),
			timed_info.get("description", ""),
			timed_info.get("quest_title", "")
		)
		visible = true


## Hide the timer UI (for manual control)
func hide_timer() -> void:
	_hide_timer()
