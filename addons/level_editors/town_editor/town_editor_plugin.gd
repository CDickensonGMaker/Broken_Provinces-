@tool
extends EditorPlugin
## Town Editor Plugin - Visual editor for town/settlement scenes

var toolbar_button: Button
var editor_window: Window
var editor_dock: Control

const TownEditorDock = preload("res://addons/level_editors/town_editor/town_editor_dock.gd")


func _enter_tree() -> void:
	# Create toolbar button
	toolbar_button = Button.new()
	toolbar_button.text = "Town Editor"
	toolbar_button.tooltip_text = "Open Town Editor for placing buildings and NPCs"
	toolbar_button.toggle_mode = true
	toolbar_button.toggled.connect(_on_toolbar_toggled)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)

	# Create popup window
	editor_window = Window.new()
	editor_window.title = "Town Editor"
	editor_window.size = Vector2i(1200, 800)
	editor_window.min_size = Vector2i(800, 600)
	editor_window.visible = false
	editor_window.wrap_controls = true
	editor_window.transient = true
	editor_window.exclusive = false
	editor_window.close_requested.connect(_on_window_close)

	# Create dock content
	editor_dock = TownEditorDock.new()
	editor_dock.name = "TownEditorDock"
	editor_window.add_child(editor_dock)
	editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add window to editor
	EditorInterface.get_base_control().add_child(editor_window)

	print("[TownEditor] Plugin enabled")


func _exit_tree() -> void:
	if toolbar_button:
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)
		toolbar_button.queue_free()
		toolbar_button = null

	if editor_window:
		editor_window.queue_free()
		editor_window = null

	editor_dock = null
	print("[TownEditor] Plugin disabled")


func _on_toolbar_toggled(pressed: bool) -> void:
	if editor_window:
		editor_window.visible = pressed
		if pressed:
			_center_window()
			editor_window.grab_focus()


func _on_window_close() -> void:
	editor_window.visible = false
	if toolbar_button:
		toolbar_button.button_pressed = false


func _center_window() -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_size: Vector2i = editor_window.size
	editor_window.position = Vector2i(
		(screen_size.x - window_size.x) / 2,
		(screen_size.y - window_size.y) / 2
	)


## Open editor with a specific scene path (called from World Forge)
func open_with_scene(scene_path: String) -> void:
	if toolbar_button:
		toolbar_button.button_pressed = true
	if editor_dock and editor_dock.has_method("load_scene"):
		editor_dock.load_scene(scene_path)


## Open editor to create new town at POI
func create_new_town(poi_data: Dictionary) -> void:
	if toolbar_button:
		toolbar_button.button_pressed = true
	if editor_dock and editor_dock.has_method("create_new_town"):
		editor_dock.create_new_town(poi_data)


func _get_plugin_name() -> String:
	return "Town Editor"
