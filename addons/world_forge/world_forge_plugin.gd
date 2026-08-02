@tool
extends EditorPlugin
## World Forge - Visual world map editor for Broken Provinces

var dock: Control
var window: Window
var toolbar_button: Button


func _enter_tree() -> void:
	# Force WorldGrid to reload fresh data on editor startup
	var world_grid_script = load("res://scripts/core/world_grid.gd")
	if world_grid_script and world_grid_script.has_method("force_reload"):
		world_grid_script.force_reload()
		print("[WorldForge] Cleared WorldGrid cache - will load fresh from JSON")

	# One World Forge, not two.
	#
	# `level_editors` builds its own World Forge window off the same dock script.
	# With both plugins enabled - which is what project.godot has always said -
	# the editor held two docks over two separate MapStates writing one file, and
	# whichever was typed into last won the next save. This plugin now stands
	# down when the umbrella is present, and its toolbar button is the umbrella's.
	if EditorInterface.is_plugin_enabled("level_editors"):
		print("[WorldForge] Level Editors is enabled and already hosts World Forge - standing down to avoid two editors over one file.")
		return

	# Create the dock instance
	dock = preload("res://addons/world_forge/world_forge_dock.gd").new()
	dock.name = "WorldForge"
	dock.host_plugin = self

	# Create popup window
	window = Window.new()
	window.title = "World Forge"
	window.size = Vector2i(900, 700)
	window.min_size = Vector2i(600, 500)
	window.visible = false
	window.wrap_controls = true
	window.transient = true
	window.exclusive = false
	window.unresizable = false
	window.close_requested.connect(_on_window_close_requested)

	# Add dock content to window
	window.add_child(dock)
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Add window to editor
	EditorInterface.get_base_control().add_child(window)

	# Add toolbar button
	toolbar_button = Button.new()
	toolbar_button.text = "World Forge"
	toolbar_button.tooltip_text = "Open World Forge Map Editor"
	toolbar_button.toggle_mode = true
	toolbar_button.toggled.connect(_on_toolbar_button_toggled)
	add_control_to_container(CONTAINER_TOOLBAR, toolbar_button)

	print("[WorldForge] Plugin enabled - Click 'World Forge' button in toolbar to open")


func _exit_tree() -> void:
	# Remove toolbar button
	if toolbar_button:
		remove_control_from_container(CONTAINER_TOOLBAR, toolbar_button)
		toolbar_button.queue_free()
		toolbar_button = null

	# Remove window
	if window:
		window.queue_free()
		window = null

	dock = null

	print("[WorldForge] Plugin disabled")


func _on_toolbar_button_toggled(pressed: bool) -> void:
	if window:
		window.visible = pressed
		if pressed:
			# Center window on screen
			var screen_size := DisplayServer.screen_get_size()
			var window_size := window.size
			window.position = Vector2i(
				(screen_size.x - window_size.x) / 2,
				(screen_size.y - window_size.y) / 2
			)
			window.grab_focus()


func _on_window_close_requested() -> void:
	window.visible = false
	if toolbar_button:
		toolbar_button.button_pressed = false


func _get_plugin_name() -> String:
	return "World Forge"


func _get_plugin_icon() -> Texture2D:
	return null
