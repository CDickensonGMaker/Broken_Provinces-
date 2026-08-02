## options_menu.gd - The options screen, as its own popup.
##
## There was no options scene. Options were hand-built inline inside
## pause_menu.gd and reachable only from a running game, and they covered three
## things: a dice-roll toggle, UI scale, and three volume sliders. No
## resolution, no fullscreen, no vsync, no key rebinding existed anywhere in
## the project, and neither the title screen nor the main menu had a way in -
## so the window opened at its 1280x960 override and a player had no way to
## change it.
##
## This is that screen, on BasePopupUI like every other popup, opened from both
## the main menu and the pause menu. Everything it changes is applied at once
## and written to user://settings.cfg by GameSettings, so it survives a restart
## without a save file.
class_name OptionsMenu
extends BasePopupUI

const REBIND_PROMPT := "Press a key..."

var _dice_checkbox: CheckBox = null
var _fullscreen_checkbox: CheckBox = null
var _vsync_checkbox: CheckBox = null
var _resolution_button: OptionButton = null
var _ui_scale_slider: HSlider = null
var _ui_scale_label: Label = null
var _volume_sliders: Dictionary = {}   # bus key -> HSlider
var _volume_labels: Dictionary = {}    # bus key -> Label
var _rebind_buttons: Dictionary = {}   # action -> Button

## The action currently waiting for a key press, or "" when not rebinding.
var _awaiting_action: String = ""


func _configure() -> void:
	popup_tier = Tier.FULLSCREEN
	pauses_game = true
	closes_on_click_outside = false


func _build_popup(content: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "OPTIONS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COL_GOLD)
	title.add_theme_font_size_override("font_size", 24)
	content.add_child(title)

	var scroll := _make_scroll()
	content.add_child(scroll)

	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 8)
	scroll.add_child(page)

	_build_display_section(page)
	page.add_child(_make_separator())
	_build_interface_section(page)
	page.add_child(_make_separator())
	_build_audio_section(page)
	page.add_child(_make_separator())
	_build_gameplay_section(page)
	page.add_child(_make_separator())
	_build_controls_section(page)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)

	var defaults_btn := Button.new()
	defaults_btn.text = "Restore Defaults"
	_style_button(defaults_btn)
	defaults_btn.pressed.connect(_on_restore_defaults)
	footer.add_child(defaults_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	_style_button(back_btn)
	back_btn.pressed.connect(close)
	footer.add_child(back_btn)


func _post_build() -> void:
	_refresh()


# =============================================================================
# SECTIONS
# =============================================================================

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COL_GOLD)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _field_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 130
	label.add_theme_color_override("font_color", COL_TEXT)
	return label

func _build_display_section(page: VBoxContainer) -> void:
	page.add_child(_section_title("DISPLAY"))

	_fullscreen_checkbox = CheckBox.new()
	_fullscreen_checkbox.text = "Fullscreen"
	_fullscreen_checkbox.add_theme_color_override("font_color", COL_TEXT)
	_fullscreen_checkbox.toggled.connect(_on_display_changed)
	page.add_child(_fullscreen_checkbox)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 10)
	page.add_child(res_row)
	res_row.add_child(_field_label("Window Size"))

	_resolution_button = OptionButton.new()
	for factor: int in GameSettings.RESOLUTION_SCALES:
		_resolution_button.add_item(GameSettings.resolution_label(factor))
	_resolution_button.item_selected.connect(_on_resolution_selected)
	res_row.add_child(_resolution_button)

	var res_note := Label.new()
	res_note.text = "Every size is a whole multiple of the 640x480 design\nresolution, so the picture stays pixel-exact."
	res_note.add_theme_color_override("font_color", COL_DIM)
	res_note.add_theme_font_size_override("font_size", 11)
	page.add_child(res_note)

	_vsync_checkbox = CheckBox.new()
	_vsync_checkbox.text = "V-Sync"
	_vsync_checkbox.add_theme_color_override("font_color", COL_TEXT)
	_vsync_checkbox.toggled.connect(_on_display_changed)
	page.add_child(_vsync_checkbox)


func _build_interface_section(page: VBoxContainer) -> void:
	page.add_child(_section_title("INTERFACE"))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	row.add_child(_field_label("UI Scale"))

	_ui_scale_slider = HSlider.new()
	_ui_scale_slider.min_value = 0.5
	_ui_scale_slider.max_value = 1.5
	_ui_scale_slider.step = 0.02
	_ui_scale_slider.custom_minimum_size = Vector2(200, 20)
	_ui_scale_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	row.add_child(_ui_scale_slider)

	_ui_scale_label = Label.new()
	_ui_scale_label.custom_minimum_size.x = 50
	_ui_scale_label.add_theme_color_override("font_color", COL_GOLD)
	row.add_child(_ui_scale_label)


func _build_audio_section(page: VBoxContainer) -> void:
	page.add_child(_section_title("AUDIO"))
	for entry: Array in [
		["master_volume", "Master"], ["music_volume", "Music"],
		["sfx_volume", "SFX"], ["ambient_volume", "Ambient"],
	]:
		_add_volume_row(page, String(entry[0]), String(entry[1]))


func _add_volume_row(page: VBoxContainer, key: String, label_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	page.add_child(row)
	row.add_child(_field_label(label_text))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(160, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_volume_changed.bind(key))
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 50
	value_label.add_theme_color_override("font_color", COL_GOLD)
	row.add_child(value_label)

	_volume_sliders[key] = slider
	_volume_labels[key] = value_label


func _build_gameplay_section(page: VBoxContainer) -> void:
	page.add_child(_section_title("GAMEPLAY"))

	_dice_checkbox = CheckBox.new()
	_dice_checkbox.text = "Show Dice Rolls"
	_dice_checkbox.add_theme_color_override("font_color", COL_TEXT)
	_dice_checkbox.toggled.connect(_on_dice_toggled)
	page.add_child(_dice_checkbox)

	var desc := Label.new()
	desc.text = "Display roll breakdowns for skill checks and combat."
	desc.add_theme_color_override("font_color", COL_DIM)
	desc.add_theme_font_size_override("font_size", 11)
	page.add_child(desc)


func _build_controls_section(page: VBoxContainer) -> void:
	page.add_child(_section_title("CONTROLS"))

	for action: String in GameSettings.REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		page.add_child(row)
		row.add_child(_field_label(GameSettings.display_name_for_action(action)))

		var btn := Button.new()
		btn.custom_minimum_size.x = 130
		_style_button(btn)
		btn.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(btn)
		_rebind_buttons[action] = btn


# =============================================================================
# REFRESH
# =============================================================================

func _refresh() -> void:
	_fullscreen_checkbox.set_pressed_no_signal(GameSettings.is_fullscreen())
	_vsync_checkbox.set_pressed_no_signal(
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	)
	_resolution_button.disabled = GameSettings.is_fullscreen()
	var factor: int = GameSettings.current_resolution_scale()
	_resolution_button.select(maxi(0, GameSettings.RESOLUTION_SCALES.find(factor)))

	var scale: float = get_tree().root.content_scale_factor
	_ui_scale_slider.set_value_no_signal(scale)
	_ui_scale_label.text = "%d%%" % int(round(scale * 100.0))

	var audio: Dictionary = AudioManager.get_settings()
	for key: String in _volume_sliders.keys():
		var value: float = float(audio.get(key, 1.0))
		(_volume_sliders[key] as HSlider).set_value_no_signal(value)
		(_volume_labels[key] as Label).text = "%d%%" % int(round(value * 100.0))

	_dice_checkbox.set_pressed_no_signal(DiceManager.show_dice_rolls)
	_refresh_bindings()


func _refresh_bindings() -> void:
	for action: String in _rebind_buttons.keys():
		var btn: Button = _rebind_buttons[action]
		if action == _awaiting_action:
			btn.text = REBIND_PROMPT
		else:
			btn.text = GameSettings.binding_label(action)


# =============================================================================
# HANDLERS
# =============================================================================

func _on_display_changed(_pressed: bool) -> void:
	GameSettings.apply_display(
		_fullscreen_checkbox.button_pressed,
		GameSettings.RESOLUTION_SCALES[_resolution_button.selected],
		_vsync_checkbox.button_pressed
	)
	_resolution_button.disabled = _fullscreen_checkbox.button_pressed
	_persist()


func _on_resolution_selected(_index: int) -> void:
	_on_display_changed(false)


func _on_ui_scale_changed(value: float) -> void:
	get_tree().root.content_scale_factor = value
	_ui_scale_label.text = "%d%%" % int(round(value * 100.0))
	_persist()


func _on_volume_changed(value: float, key: String) -> void:
	match key:
		"master_volume": AudioManager.set_master_volume(value)
		"music_volume": AudioManager.set_music_volume(value)
		"sfx_volume": AudioManager.set_sfx_volume(value)
		"ambient_volume": AudioManager.set_ambient_volume(value)
	(_volume_labels[key] as Label).text = "%d%%" % int(round(value * 100.0))
	_persist()


func _on_dice_toggled(pressed: bool) -> void:
	DiceManager.show_dice_rolls = pressed
	_persist()


func _on_rebind_pressed(action: String) -> void:
	_awaiting_action = action
	_refresh_bindings()


func _on_restore_defaults() -> void:
	InputMap.load_from_project_settings()
	GameSettings.apply_display(false, 2, true)
	get_tree().root.content_scale_factor = GameSettings.DEFAULT_UI_SCALE
	AudioManager.load_settings({})
	DiceManager.show_dice_rolls = true
	_persist()
	_refresh()


func _persist() -> void:
	GameSettings.save_all(get_tree())


# =============================================================================
# INPUT
# =============================================================================

## While waiting for a rebind, this popup swallows the whole event stream -
## otherwise pressing Escape to cancel would close the menu and pressing a
## movement key would move the player behind it.
func _input(event: InputEvent) -> void:
	if visible and not _awaiting_action.is_empty():
		if not (event is InputEventKey or event is InputEventMouseButton):
			return
		if not event.is_pressed() or event.is_echo():
			return
		get_viewport().set_input_as_handled()

		var cancelled: bool = event is InputEventKey \
			and (event as InputEventKey).physical_keycode == KEY_ESCAPE
		if not cancelled:
			GameSettings.rebind_action(_awaiting_action, event)
			_persist()
		_awaiting_action = ""
		_refresh_bindings()
		return

	super._input(event)


func close() -> void:
	_awaiting_action = ""
	_persist()
	super.close()
