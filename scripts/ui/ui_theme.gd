## ui_theme.gd - The one place the menus agree on what the game looks like.
## Palette and widget factories per ADR-003. Nothing here touches game state,
## so any UI can call it at any time, paused or not.
class_name UITheme
extends RefCounted

# Gothic palette (ADR-003)
const COL_BG := Color(0.08, 0.08, 0.1)
const COL_PANEL := Color(0.12, 0.12, 0.15)
const COL_BORDER := Color(0.3, 0.25, 0.2)
const COL_TEXT := Color(0.9, 0.85, 0.75)
const COL_DIM := Color(0.5, 0.5, 0.5)
const COL_GOLD := Color(0.8, 0.6, 0.2)
const COL_SELECT := Color(0.25, 0.2, 0.15)
const COL_GREEN := Color(0.3, 0.8, 0.3)
const COL_RED := Color(0.8, 0.3, 0.3)
const COL_YELLOW := Color(1.0, 0.8, 0.3)
const COL_BLUE := Color(0.4, 0.6, 0.9)

## Dark wash drawn behind every popup
const COL_OVERLAY := Color(0, 0, 0, 0.75)

## Panel margins for a full-screen menu (ADR-003)
const FULLSCREEN_MARGIN := Rect2(60, 80, -60, -40)
## Inner padding every content VBox uses
const CONTENT_PADDING := 10.0
## Vertical gap between rows in a content VBox
const CONTENT_SEPARATION := 8


## Standard dark panel with a sharp two-pixel border
static func make_panel_style(bg: Color = COL_BG, border: Color = COL_BORDER) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(0)
	return style


## PS1 aesthetic: sharp corners, no rounding, three states
static func style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = COL_PANEL
	normal.border_color = COL_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(0)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = COL_SELECT
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.15, 0.15, 0.2)
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.1, 0.1, 0.12)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", COL_TEXT)
	btn.add_theme_color_override("font_hover_color", COL_GOLD)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)
	btn.add_theme_color_override("font_disabled_color", COL_DIM)


static func make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var line := StyleBoxLine.new()
	line.color = COL_BORDER
	line.thickness = 1
	sep.add_theme_stylebox_override("separator", line)
	return sep


static func make_title(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COL_GOLD)
	label.add_theme_font_size_override("font_size", size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


## Vertical scroll area that grows to fill whatever box it is put in
static func make_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	return scroll


## Name on the left, value on the right, both clipped to the row
static func make_list_row(text: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 24

	var name_label := Label.new()
	name_label.text = text
	name_label.add_theme_color_override("font_color", COL_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value
	value_label.add_theme_color_override("font_color", COL_GOLD)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	return row
