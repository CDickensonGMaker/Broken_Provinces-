## game_settings.gd - Player preferences, stored outside the save file.
##
## Until 8/2 there was no such thing. The only options in the game were built
## inline in the pause menu and reachable only mid-run, and the only ones that
## survived a restart were the three volumes - which rode in the *save file*,
## via SaveData.audio_settings. So a player who set the volume on the title
## screen lost it, and there was no resolution, fullscreen, vsync or key
## rebinding anywhere in the project at all.
##
## Preferences are not save-game state. They live in `user://settings.cfg` and
## are applied at boot by GameManager, before any menu exists.
##
## AudioManager.get_settings() / load_settings() remain the audio vocabulary;
## this stores what they return rather than defining a second one.
class_name GameSettings
extends RefCounted

const SETTINGS_PATH := "user://settings.cfg"

## The project's design resolution. Everything offered is a multiple of it, so
## the "viewport" stretch mode stays pixel-exact at every size.
const BASE_RESOLUTION := Vector2i(640, 480)

## Window sizes offered in the options menu, as multiples of BASE_RESOLUTION.
const RESOLUTION_SCALES: Array[int] = [1, 2, 3, 4]

## GameManager's long-standing default.
const DEFAULT_UI_SCALE := 0.68

## Input actions a player may rebind, in the order the menu lists them.
## Only actions the game actually reads - batch 4 removed block, lock_on and
## toggle_camera_mode rather than shipping keys that did nothing, and this list
## must never grow back past what the input code handles.
##
## `block` and `lock_on` are back because PlayerController implements them now.
const REBINDABLE_ACTIONS: Array[String] = [
	"move_forward", "move_backward", "move_left", "move_right",
	"jump", "sprint", "crouch", "dodge",
	"light_attack", "heavy_attack", "block", "lock_on", "interact",
	"menu", "pause",
]

## Actions the code reads that `project.godot` does not declare, with the key
## each defaults to. Registered at boot rather than written into the project
## file - the same shape SaveManager uses for quick_save/quick_load.
const RUNTIME_ACTION_DEFAULTS: Dictionary = {
	"block": KEY_Q,
	"lock_on": KEY_V,
}


## Register any action in RUNTIME_ACTION_DEFAULTS the InputMap does not have.
## Idempotent, and it never touches an action that already exists - so a
## player's rebind, loaded a moment later, wins.
static func ensure_runtime_actions() -> void:
	for action: String in RUNTIME_ACTION_DEFAULTS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var event := InputEventKey.new()
		event.physical_keycode = RUNTIME_ACTION_DEFAULTS[action]
		InputMap.action_add_event(action, event)


static func display_name_for_action(action: String) -> String:
	match action:
		"move_forward": return "Move Forward"
		"move_backward": return "Move Back"
		"move_left": return "Strafe Left"
		"move_right": return "Strafe Right"
		"jump": return "Jump"
		"sprint": return "Sprint"
		"crouch": return "Crouch"
		"dodge": return "Dodge"
		"light_attack": return "Attack"
		"heavy_attack": return "Heavy Attack"
		"block": return "Block"
		"lock_on": return "Lock On"
		"interact": return "Interact"
		"menu": return "Menu"
		"pause": return "Pause"
		_: return action.capitalize()


## Human-readable label for an action's first bound event.
static func binding_label(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))
		if event is InputEventMouseButton:
			match (event as InputEventMouseButton).button_index:
				MOUSE_BUTTON_LEFT: return "Mouse Left"
				MOUSE_BUTTON_RIGHT: return "Mouse Right"
				MOUSE_BUTTON_MIDDLE: return "Mouse Middle"
				_: return "Mouse %d" % (event as InputEventMouseButton).button_index
	return "-"


## Replace an action's binding with a single event. Returns false for an event
## shape the game cannot bind (a mouse motion, a modifier on its own).
static func rebind_action(action: String, event: InputEvent) -> bool:
	if not InputMap.has_action(action):
		return false
	if not (event is InputEventKey or event is InputEventMouseButton):
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_NONE and key.keycode == KEY_NONE:
			return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	return true


# =============================================================================
# APPLY
# =============================================================================

## Window, vsync and UI scale. Depends on no autoload, so GameManager - which
## is the FIRST autoload and therefore cannot see AudioManager or DiceManager
## in its own _ready() - can call this straight away.
static func apply_window_settings(tree: SceneTree) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)

	apply_display(
		cfg.get_value("display", "fullscreen", false),
		int(cfg.get_value("display", "resolution_scale", 2)),
		cfg.get_value("display", "vsync", true)
	)

	var ui_scale: float = float(cfg.get_value("interface", "ui_scale", DEFAULT_UI_SCALE))
	if tree and tree.root:
		tree.root.content_scale_factor = ui_scale


## Everything else, including the parts that need other autoloads. Call this
## deferred from the first autoload, or directly from anything later.
## Safe with no file present - every value falls back to the project default.
static func apply_all(tree: SceneTree) -> void:
	apply_window_settings(tree)
	ensure_runtime_actions()

	var cfg := ConfigFile.new()
	var loaded: bool = cfg.load(SETTINGS_PATH) == OK

	# Gameplay
	DiceManager.show_dice_rolls = bool(cfg.get_value("gameplay", "show_dice_rolls", true))

	# Audio - AudioManager already owns this vocabulary.
	if loaded and cfg.has_section("audio"):
		var audio: Dictionary = {}
		for key: String in cfg.get_section_keys("audio"):
			audio[key] = cfg.get_value("audio", key)
		AudioManager.load_settings(audio)

	# Keybinds
	if loaded and cfg.has_section("keybinds"):
		for action: String in cfg.get_section_keys("keybinds"):
			if not REBINDABLE_ACTIONS.has(action):
				continue
			var event: Variant = cfg.get_value("keybinds", action)
			if event is InputEvent:
				rebind_action(action, event as InputEvent)


static func apply_display(fullscreen: bool, resolution_scale: int, vsync: bool) -> void:
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	)
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var factor: int = clampi(resolution_scale, RESOLUTION_SCALES[0], RESOLUTION_SCALES[-1])
	DisplayServer.window_set_size(BASE_RESOLUTION * factor)


# =============================================================================
# SAVE
# =============================================================================

static func save_all(tree: SceneTree) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep anything we do not manage

	cfg.set_value("display", "fullscreen", is_fullscreen())
	cfg.set_value("display", "resolution_scale", current_resolution_scale())
	cfg.set_value("display", "vsync",
		DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED)

	if tree and tree.root:
		cfg.set_value("interface", "ui_scale", tree.root.content_scale_factor)

	cfg.set_value("gameplay", "show_dice_rolls", DiceManager.show_dice_rolls)

	var audio: Dictionary = AudioManager.get_settings()
	for key: String in audio.keys():
		cfg.set_value("audio", key, audio[key])

	for action: String in REBINDABLE_ACTIONS:
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		if not events.is_empty():
			cfg.set_value("keybinds", action, events[0])

	cfg.save(SETTINGS_PATH)


static func is_fullscreen() -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## Which entry of RESOLUTION_SCALES the window is nearest to.
static func current_resolution_scale() -> int:
	var width: int = DisplayServer.window_get_size().x
	var best: int = RESOLUTION_SCALES[0]
	var best_delta: int = 1 << 30
	for factor: int in RESOLUTION_SCALES:
		var delta: int = absi(BASE_RESOLUTION.x * factor - width)
		if delta < best_delta:
			best_delta = delta
			best = factor
	return best


static func resolution_label(factor: int) -> String:
	var size: Vector2i = BASE_RESOLUTION * factor
	return "%d x %d" % [size.x, size.y]
