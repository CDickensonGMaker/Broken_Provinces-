## wave_counter_ui.gd - UI element showing wave defense progress
## Shows current wave, enemies remaining, and countdown timer between waves
class_name WaveCounterUI
extends Control

## Colors (PS1 gothic aesthetic)
const COL_WAVE_TITLE: Color = Color(0.9, 0.75, 0.5)  # Gold for wave number
const COL_ENEMIES: Color = Color(0.8, 0.2, 0.2)  # Red for enemy count
const COL_COUNTDOWN: Color = Color(0.6, 0.8, 1.0)  # Blue for countdown
const COL_COMPLETE: Color = Color(0.2, 0.8, 0.3)  # Green for completion
const COL_PANEL_BG: Color = Color(0.05, 0.03, 0.08, 0.85)  # Dark purple-black
const COL_PANEL_BORDER: Color = Color(0.4, 0.25, 0.15)  # Bronze border

## Node references (created in _ready)
var panel: PanelContainer
var vbox: VBoxContainer
var wave_label: Label
var enemies_label: Label
var countdown_label: Label
var status_label: Label

## Connected wave spawner
var wave_spawner: WaveSpawner = null


func _ready() -> void:
	_create_ui()
	visible = false  # Hidden by default


func _process(_delta: float) -> void:
	if not visible or not wave_spawner:
		return

	_update_display()


## Create the UI elements programmatically (matches PS1 aesthetic)
func _create_ui() -> void:
	# Main panel with dark background
	panel = PanelContainer.new()
	panel.name = "WavePanel"

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
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)

	# Vertical container for labels
	vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Wave title (WAVE X / Y)
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.add_theme_color_override("font_color", COL_WAVE_TITLE)
	wave_label.add_theme_font_size_override("font_size", 20)
	wave_label.text = "WAVE 1 / 5"
	vbox.add_child(wave_label)

	# Enemies remaining
	enemies_label = Label.new()
	enemies_label.name = "EnemiesLabel"
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemies_label.add_theme_color_override("font_color", COL_ENEMIES)
	enemies_label.add_theme_font_size_override("font_size", 16)
	enemies_label.text = "Enemies: 8"
	vbox.add_child(enemies_label)

	# Countdown timer (shown between waves)
	countdown_label = Label.new()
	countdown_label.name = "CountdownLabel"
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.add_theme_color_override("font_color", COL_COUNTDOWN)
	countdown_label.add_theme_font_size_override("font_size", 18)
	countdown_label.text = "Next wave: 10"
	countdown_label.visible = false
	vbox.add_child(countdown_label)

	# Status label (WAVE COMPLETE, DEFENSE COMPLETE, etc.)
	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", COL_COMPLETE)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.text = ""
	status_label.visible = false
	vbox.add_child(status_label)


## Connect to a wave spawner and start displaying
func connect_to_spawner(spawner: WaveSpawner) -> void:
	if wave_spawner:
		_disconnect_spawner_signals()

	wave_spawner = spawner

	if wave_spawner:
		_connect_spawner_signals()
		visible = true
		_update_display()


## Disconnect from current spawner
func disconnect_spawner() -> void:
	if wave_spawner:
		_disconnect_spawner_signals()
	wave_spawner = null
	visible = false


## Connect signals from wave spawner
func _connect_spawner_signals() -> void:
	if not wave_spawner:
		return

	if wave_spawner.has_signal("wave_started"):
		if not wave_spawner.wave_started.is_connected(_on_wave_started):
			wave_spawner.wave_started.connect(_on_wave_started)

	if wave_spawner.has_signal("wave_completed"):
		if not wave_spawner.wave_completed.is_connected(_on_wave_completed):
			wave_spawner.wave_completed.connect(_on_wave_completed)

	if wave_spawner.has_signal("all_waves_completed"):
		if not wave_spawner.all_waves_completed.is_connected(_on_all_waves_completed):
			wave_spawner.all_waves_completed.connect(_on_all_waves_completed)

	if wave_spawner.has_signal("countdown_tick"):
		if not wave_spawner.countdown_tick.is_connected(_on_countdown_tick):
			wave_spawner.countdown_tick.connect(_on_countdown_tick)


## Disconnect signals from wave spawner
func _disconnect_spawner_signals() -> void:
	if not wave_spawner:
		return

	if wave_spawner.has_signal("wave_started"):
		if wave_spawner.wave_started.is_connected(_on_wave_started):
			wave_spawner.wave_started.disconnect(_on_wave_started)

	if wave_spawner.has_signal("wave_completed"):
		if wave_spawner.wave_completed.is_connected(_on_wave_completed):
			wave_spawner.wave_completed.disconnect(_on_wave_completed)

	if wave_spawner.has_signal("all_waves_completed"):
		if wave_spawner.all_waves_completed.is_connected(_on_all_waves_completed):
			wave_spawner.all_waves_completed.disconnect(_on_all_waves_completed)

	if wave_spawner.has_signal("countdown_tick"):
		if wave_spawner.countdown_tick.is_connected(_on_countdown_tick):
			wave_spawner.countdown_tick.disconnect(_on_countdown_tick)


## Update display based on current spawner state
func _update_display() -> void:
	if not wave_spawner:
		return

	var current_wave: int = wave_spawner.get_current_wave()
	var total_waves: int = wave_spawner.get_total_waves()
	var enemies: int = wave_spawner.get_enemies_remaining()

	# Update wave label
	if current_wave > 0:
		wave_label.text = "WAVE %d / %d" % [current_wave, total_waves]
	else:
		wave_label.text = "WAVE DEFENSE"

	# Update enemies label (hide during countdown)
	if wave_spawner.is_in_countdown():
		enemies_label.visible = false
	else:
		enemies_label.visible = true
		enemies_label.text = "Enemies: %d" % enemies


## Signal handlers
func _on_wave_started(wave_num: int) -> void:
	countdown_label.visible = false
	status_label.visible = false
	enemies_label.visible = true

	# Flash effect for new wave
	_flash_wave_start()


func _on_wave_completed(wave_num: int) -> void:
	status_label.text = "WAVE COMPLETE"
	status_label.add_theme_color_override("font_color", COL_COMPLETE)
	status_label.visible = true
	enemies_label.visible = false


func _on_all_waves_completed() -> void:
	countdown_label.visible = false
	enemies_label.visible = false
	status_label.text = "DEFENSE COMPLETE!"
	status_label.add_theme_color_override("font_color", COL_COMPLETE)
	status_label.visible = true

	# Hide after delay
	get_tree().create_timer(5.0).timeout.connect(_on_hide_after_complete)


func _on_countdown_tick(seconds: int) -> void:
	countdown_label.text = "Next wave: %d" % seconds
	countdown_label.visible = true
	status_label.visible = seconds > 3  # Hide status near end of countdown


func _on_hide_after_complete() -> void:
	# Fade out and hide
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
		disconnect_spawner()
	)


## Visual flash when new wave starts
func _flash_wave_start() -> void:
	var original_color: Color = COL_WAVE_TITLE
	wave_label.add_theme_color_override("font_color", Color.WHITE)

	var tween := create_tween()
	tween.tween_property(wave_label, "theme_override_colors/font_color", original_color, 0.5)


## Show the wave counter
func show_counter() -> void:
	visible = true
	modulate.a = 1.0


## Hide the wave counter
func hide_counter() -> void:
	visible = false
