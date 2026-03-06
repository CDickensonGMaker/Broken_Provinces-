@tool
extends EditorPlugin
## World Forge - Visual world map editor for Broken Provinces

var dock: Control


func _enter_tree() -> void:
	# Create the dock instance
	dock = preload("res://addons/world_forge/world_forge_dock.gd").new()
	dock.name = "WorldForge"

	# Add the dock to the editor
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

	print("[WorldForge] Plugin enabled")


func _exit_tree() -> void:
	# Remove the dock
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

	print("[WorldForge] Plugin disabled")


func _get_plugin_name() -> String:
	return "World Forge"


func _get_plugin_icon() -> Texture2D:
	return null
