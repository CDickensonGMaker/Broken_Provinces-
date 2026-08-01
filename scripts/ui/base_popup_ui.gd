## base_popup_ui.gd - The chrome every popup used to hand-build for itself.
##
## A popup subclass says what tier it is, then fills the VBox it is handed.
## Overlay, click-outside, panel, border, padding, escape key, pause handling
## and the ui_closed signal all live here, once.
##
## Subclasses override, in this order:
##   _configure()            - set popup_tier and the flags below (no nodes yet)
##   _build_popup(body)      - add widgets to body
##   _post_build()           - first refresh, now that the widgets exist
class_name BasePopupUI
extends Control

signal ui_closed

## Three shapes of popup, per ADR-003.
##   FULLSCREEN - a whole menu: shop, crafting, journal. 60/80/-60/-40 margins.
##   DIALOGUE   - a talking box across the bottom third of the screen.
##   COMPACT    - a small centred card: confirmations, single choices.
enum Tier { FULLSCREEN, DIALOGUE, COMPACT }

# Palette, re-exported so subclasses can keep saying COL_GOLD
const COL_BG := UITheme.COL_BG
const COL_PANEL := UITheme.COL_PANEL
const COL_BORDER := UITheme.COL_BORDER
const COL_TEXT := UITheme.COL_TEXT
const COL_DIM := UITheme.COL_DIM
const COL_GOLD := UITheme.COL_GOLD
const COL_SELECT := UITheme.COL_SELECT
const COL_GREEN := UITheme.COL_GREEN
const COL_RED := UITheme.COL_RED
const COL_YELLOW := UITheme.COL_YELLOW
const COL_BLUE := UITheme.COL_BLUE

## Which shape of chrome to build. Set it in _configure().
var popup_tier: Tier = Tier.FULLSCREEN
## Popups that are built on demand and shown at once set this true in _configure().
var starts_visible: bool = false
## A click on the dark area outside the panel closes the popup.
var closes_on_click_outside: bool = true
## The popup itself pauses the game and frees the mouse. Popups whose opener
## already does that (crafting stations, the bounty board) leave this false.
var pauses_game: bool = false
## Escape / pause / menu closes the popup.
var closes_on_cancel: bool = true

## The panel the chrome built. Subclasses may restyle it.
var panel: PanelContainer = null
## The VBox handed to _build_popup(). Subclasses put their widgets here.
var body: VBoxContainer = null


func _ready() -> void:
	_configure()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = starts_visible
	_build_chrome()
	_build_popup(body)
	_post_build()


## Override to set popup_tier and the behaviour flags. Runs before any node exists.
func _configure() -> void:
	pass


## Override to fill the popup. `content` is the padded VBox inside the panel.
func _build_popup(_content: VBoxContainer) -> void:
	pass


## Override for the first data refresh, after the widgets exist.
func _post_build() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not visible or not closes_on_cancel:
		return

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("menu"):
		close()
		get_viewport().set_input_as_handled()


func _build_chrome() -> void:
	if closes_on_click_outside:
		var click_outside := Button.new()
		click_outside.name = "ClickOutside"
		click_outside.set_anchors_preset(Control.PRESET_FULL_RECT)
		click_outside.flat = true
		click_outside.focus_mode = Control.FOCUS_NONE
		click_outside.mouse_filter = Control.MOUSE_FILTER_STOP
		click_outside.process_mode = Node.PROCESS_MODE_ALWAYS
		click_outside.pressed.connect(close)
		add_child(click_outside)

	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = UITheme.COL_OVERLAY
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", UITheme.make_panel_style())
	_apply_tier_geometry(panel)
	add_child(panel)

	body = VBoxContainer.new()
	body.name = "Body"
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = UITheme.CONTENT_PADDING
	body.offset_top = UITheme.CONTENT_PADDING
	body.offset_right = -UITheme.CONTENT_PADDING
	body.offset_bottom = -UITheme.CONTENT_PADDING
	body.add_theme_constant_override("separation", UITheme.CONTENT_SEPARATION)
	panel.add_child(body)


func _apply_tier_geometry(target: PanelContainer) -> void:
	match popup_tier:
		Tier.DIALOGUE:
			# Bottom third of the screen, edge to edge bar a margin
			target.anchor_left = 0.0
			target.anchor_right = 1.0
			target.anchor_top = 0.62
			target.anchor_bottom = 1.0
			target.offset_left = 60
			target.offset_right = -60
			target.offset_top = 0
			target.offset_bottom = -40
		Tier.COMPACT:
			# Small card, centred, sized to its contents
			target.set_anchors_preset(Control.PRESET_CENTER)
			target.grow_horizontal = Control.GROW_DIRECTION_BOTH
			target.grow_vertical = Control.GROW_DIRECTION_BOTH
			target.custom_minimum_size = Vector2(480, 280)
		_:
			target.set_anchors_preset(Control.PRESET_FULL_RECT)
			target.offset_left = UITheme.FULLSCREEN_MARGIN.position.x
			target.offset_top = UITheme.FULLSCREEN_MARGIN.position.y
			target.offset_right = UITheme.FULLSCREEN_MARGIN.size.x
			target.offset_bottom = UITheme.FULLSCREEN_MARGIN.size.y


## Show the popup and, if it owns the pause, take it. Subclasses keep their own
## open() with whatever arguments they need and call this first.
func show_popup() -> void:
	if visible:
		return
	visible = true
	if pauses_game:
		_enter_menu_state()


func close() -> void:
	if not visible:
		return
	visible = false
	if pauses_game:
		_exit_menu_state()
	ui_closed.emit()


func _enter_menu_state() -> void:
	if GameManager:
		GameManager.enter_menu()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _exit_menu_state() -> void:
	if GameManager:
		GameManager.exit_menu()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ---- shared widget factories, forwarded so subclasses need no import ----

func _make_separator() -> HSeparator:
	return UITheme.make_separator()


func _style_button(btn: Button) -> void:
	UITheme.style_button(btn)


func _make_scroll() -> ScrollContainer:
	return UITheme.make_scroll()
