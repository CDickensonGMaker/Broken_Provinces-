@tool
## dungeon_editor_plugin.gd - Dungeon Editor Plugin entry point
extends EditorPlugin


var dock: Control


func _enter_tree() -> void:
	# Load and instantiate the dock
	var dock_script: Script = preload("res://addons/dungeon_editor/dungeon_editor_dock.gd")
	dock = dock_script.new()
	dock.name = "DungeonEditor"

	# Add dock to bottom panel
	add_control_to_bottom_panel(dock, "Dungeon Editor")


func _exit_tree() -> void:
	if dock:
		remove_control_from_bottom_panel(dock)
		dock.queue_free()
		dock = null


func _get_plugin_name() -> String:
	return "Dungeon Editor"
