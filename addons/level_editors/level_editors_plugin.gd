@tool
extends EditorPlugin
## Unified Level Editors Plugin - Provides dropdown access to all level editing tools

var menu_button: MenuButton
var popup_menu: PopupMenu

# Editor windows
var world_forge_window: Window
var town_editor_window: Window
var dungeon_editor_window: Window

# Authoring tool windows
var npc_composer_window: Window
var npc_blueprint_editor_window: Window
var quest_blueprint_editor_window: Window
var event_editor_window: Window

# Editor docks
var world_forge_dock: Control
var town_editor_dock: Control
var dungeon_editor_dock: Control

# Authoring tool docks
var npc_composer_dock: Control
var npc_blueprint_editor_dock: Control
var quest_blueprint_editor_dock: Control
var event_editor_dock: Control

# Preloads
const WorldForgeDock = preload("res://addons/world_forge/world_forge_dock.gd")
const TownEditorDock = preload("res://addons/level_editors/town_editor/town_editor_dock.gd")
const DungeonEditorDock = preload("res://addons/dungeon_editor/dungeon_editor_dock.gd")

# Authoring tool preloads
const NPCComposerDock = preload("res://addons/authoring_tools/npc_composer/npc_composer_dock.gd")
const NPCBlueprintEditorDock = preload("res://addons/authoring_tools/dialogue_editor/npc_blueprint_editor.gd")
const QuestBlueprintEditorDock = preload("res://addons/authoring_tools/dialogue_editor/quest_blueprint_editor.gd")
const ScriptedEventEditorDock = preload("res://addons/authoring_tools/event_editor/scripted_event_editor_dock.gd")

# Menu IDs
enum MenuID {
	WORLD_FORGE = 0,
	TOWN_EDITOR = 1,
	DUNGEON_EDITOR = 2,
	SEPARATOR = 99,
	NPC_COMPOSER = 4,
	NPC_BLUEPRINT_EDITOR = 5,
	QUEST_BLUEPRINT_EDITOR = 6,
	EVENT_EDITOR = 7,
	CLOSE_ALL = 10
}


func _enter_tree() -> void:
	# Create the dropdown menu button
	menu_button = MenuButton.new()
	menu_button.text = "Level Editors"
	menu_button.tooltip_text = "Open World Forge, Town Editor, Dungeon Editor, or Authoring Tools"
	menu_button.flat = false

	popup_menu = menu_button.get_popup()
	popup_menu.add_icon_item(null, "World Forge", MenuID.WORLD_FORGE)
	popup_menu.add_icon_item(null, "Town Editor", MenuID.TOWN_EDITOR)
	popup_menu.add_icon_item(null, "Dungeon Editor", MenuID.DUNGEON_EDITOR)
	popup_menu.add_separator()
	popup_menu.add_icon_item(null, "NPC Composer", MenuID.NPC_COMPOSER)
	popup_menu.add_icon_item(null, "NPC Ideas (Blueprint)", MenuID.NPC_BLUEPRINT_EDITOR)
	popup_menu.add_icon_item(null, "Quest Ideas (Blueprint)", MenuID.QUEST_BLUEPRINT_EDITOR)
	popup_menu.add_icon_item(null, "Scripted Event Editor", MenuID.EVENT_EDITOR)
	popup_menu.add_separator()
	popup_menu.add_item("Close All", MenuID.CLOSE_ALL)

	popup_menu.id_pressed.connect(_on_menu_item_pressed)

	# Add to toolbar
	add_control_to_container(CONTAINER_TOOLBAR, menu_button)

	# Initialize editor windows (but don't show them)
	_create_world_forge_window()
	_create_town_editor_window()
	_create_dungeon_editor_window()

	# Initialize authoring tool windows
	_create_npc_composer_window()
	_create_npc_blueprint_editor_window()
	_create_quest_blueprint_editor_window()
	_create_event_editor_window()


func _exit_tree() -> void:
	if menu_button:
		remove_control_from_container(CONTAINER_TOOLBAR, menu_button)
		menu_button.queue_free()
		menu_button = null

	if world_forge_window:
		world_forge_window.queue_free()
		world_forge_window = null

	if town_editor_window:
		town_editor_window.queue_free()
		town_editor_window = null

	if dungeon_editor_window:
		dungeon_editor_window.queue_free()
		dungeon_editor_window = null

	# Clean up authoring tool windows
	if npc_composer_window:
		npc_composer_window.queue_free()
		npc_composer_window = null

	if npc_blueprint_editor_window:
		npc_blueprint_editor_window.queue_free()
		npc_blueprint_editor_window = null

	if quest_blueprint_editor_window:
		quest_blueprint_editor_window.queue_free()
		quest_blueprint_editor_window = null

	if event_editor_window:
		event_editor_window.queue_free()
		event_editor_window = null

	world_forge_dock = null
	town_editor_dock = null
	dungeon_editor_dock = null

	npc_composer_dock = null
	npc_blueprint_editor_dock = null
	quest_blueprint_editor_dock = null
	event_editor_dock = null


func _create_world_forge_window() -> void:
	world_forge_window = Window.new()
	world_forge_window.title = "World Forge"
	world_forge_window.size = Vector2i(1000, 750)
	world_forge_window.min_size = Vector2i(700, 550)
	world_forge_window.visible = false
	world_forge_window.wrap_controls = true
	world_forge_window.transient = true
	world_forge_window.exclusive = false
	world_forge_window.close_requested.connect(_on_world_forge_close)

	world_forge_dock = WorldForgeDock.new()
	world_forge_dock.name = "WorldForgeDock"
	world_forge_window.add_child(world_forge_dock)
	world_forge_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(world_forge_window)


func _create_town_editor_window() -> void:
	town_editor_window = Window.new()
	town_editor_window.title = "Town Editor"
	town_editor_window.size = Vector2i(1300, 850)
	town_editor_window.min_size = Vector2i(900, 650)
	town_editor_window.visible = false
	town_editor_window.wrap_controls = true
	town_editor_window.transient = true
	town_editor_window.exclusive = false
	town_editor_window.close_requested.connect(_on_town_editor_close)

	town_editor_dock = TownEditorDock.new()
	town_editor_dock.name = "TownEditorDock"
	town_editor_window.add_child(town_editor_dock)
	town_editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(town_editor_window)


func _create_dungeon_editor_window() -> void:
	dungeon_editor_window = Window.new()
	dungeon_editor_window.title = "Dungeon Editor"
	dungeon_editor_window.size = Vector2i(1400, 900)
	dungeon_editor_window.min_size = Vector2i(1000, 700)
	dungeon_editor_window.visible = false
	dungeon_editor_window.wrap_controls = true
	dungeon_editor_window.transient = true
	dungeon_editor_window.exclusive = false
	dungeon_editor_window.close_requested.connect(_on_dungeon_editor_close)

	dungeon_editor_dock = DungeonEditorDock.new()
	dungeon_editor_dock.name = "DungeonEditorDock"
	dungeon_editor_window.add_child(dungeon_editor_dock)
	dungeon_editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(dungeon_editor_window)


func _on_menu_item_pressed(id: int) -> void:
	match id:
		MenuID.WORLD_FORGE:
			_show_window(world_forge_window)
		MenuID.TOWN_EDITOR:
			_show_window(town_editor_window)
		MenuID.DUNGEON_EDITOR:
			_show_window(dungeon_editor_window)
		MenuID.NPC_COMPOSER:
			_show_window(npc_composer_window)
		MenuID.NPC_BLUEPRINT_EDITOR:
			_show_window(npc_blueprint_editor_window)
		MenuID.QUEST_BLUEPRINT_EDITOR:
			_show_window(quest_blueprint_editor_window)
		MenuID.EVENT_EDITOR:
			_show_window(event_editor_window)
		MenuID.CLOSE_ALL:
			_close_all_windows()


func _show_window(window: Window) -> void:
	if not window:
		return
	window.visible = true
	_center_window(window)
	window.grab_focus()


func _center_window(window: Window) -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_size: Vector2i = window.size
	window.position = Vector2i(
		(screen_size.x - window_size.x) / 2,
		(screen_size.y - window_size.y) / 2
	)


func _close_all_windows() -> void:
	if world_forge_window:
		world_forge_window.visible = false
	if town_editor_window:
		town_editor_window.visible = false
	if dungeon_editor_window:
		dungeon_editor_window.visible = false
	if npc_composer_window:
		npc_composer_window.visible = false
	if npc_blueprint_editor_window:
		npc_blueprint_editor_window.visible = false
	if quest_blueprint_editor_window:
		quest_blueprint_editor_window.visible = false
	if event_editor_window:
		event_editor_window.visible = false


func _on_world_forge_close() -> void:
	world_forge_window.visible = false


func _on_town_editor_close() -> void:
	town_editor_window.visible = false


func _on_dungeon_editor_close() -> void:
	dungeon_editor_window.visible = false


## Authoring Tool Window Creation

func _create_npc_composer_window() -> void:
	npc_composer_window = Window.new()
	npc_composer_window.title = "NPC Composer"
	npc_composer_window.size = Vector2i(1200, 800)
	npc_composer_window.min_size = Vector2i(900, 600)
	npc_composer_window.visible = false
	npc_composer_window.wrap_controls = true
	npc_composer_window.transient = true
	npc_composer_window.exclusive = false
	npc_composer_window.close_requested.connect(_on_npc_composer_close)

	npc_composer_dock = NPCComposerDock.new()
	npc_composer_dock.name = "NPCComposerDock"
	npc_composer_window.add_child(npc_composer_dock)
	npc_composer_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(npc_composer_window)


func _create_npc_blueprint_editor_window() -> void:
	npc_blueprint_editor_window = Window.new()
	npc_blueprint_editor_window.title = "NPC Ideas (Blueprint)"
	npc_blueprint_editor_window.size = Vector2i(800, 700)
	npc_blueprint_editor_window.min_size = Vector2i(600, 500)
	npc_blueprint_editor_window.visible = false
	npc_blueprint_editor_window.wrap_controls = true
	npc_blueprint_editor_window.transient = true
	npc_blueprint_editor_window.exclusive = false
	npc_blueprint_editor_window.close_requested.connect(_on_npc_blueprint_editor_close)

	npc_blueprint_editor_dock = NPCBlueprintEditorDock.new()
	npc_blueprint_editor_dock.name = "NPCBlueprintEditorDock"
	npc_blueprint_editor_window.add_child(npc_blueprint_editor_dock)
	npc_blueprint_editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(npc_blueprint_editor_window)


func _create_quest_blueprint_editor_window() -> void:
	quest_blueprint_editor_window = Window.new()
	quest_blueprint_editor_window.title = "Quest Ideas (Blueprint)"
	quest_blueprint_editor_window.size = Vector2i(800, 800)
	quest_blueprint_editor_window.min_size = Vector2i(600, 600)
	quest_blueprint_editor_window.visible = false
	quest_blueprint_editor_window.wrap_controls = true
	quest_blueprint_editor_window.transient = true
	quest_blueprint_editor_window.exclusive = false
	quest_blueprint_editor_window.close_requested.connect(_on_quest_blueprint_editor_close)

	quest_blueprint_editor_dock = QuestBlueprintEditorDock.new()
	quest_blueprint_editor_dock.name = "QuestBlueprintEditorDock"
	quest_blueprint_editor_window.add_child(quest_blueprint_editor_dock)
	quest_blueprint_editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(quest_blueprint_editor_window)


func _create_event_editor_window() -> void:
	event_editor_window = Window.new()
	event_editor_window.title = "Scripted Event Editor"
	event_editor_window.size = Vector2i(1500, 950)
	event_editor_window.min_size = Vector2i(1100, 750)
	event_editor_window.visible = false
	event_editor_window.wrap_controls = true
	event_editor_window.transient = true
	event_editor_window.exclusive = false
	event_editor_window.close_requested.connect(_on_event_editor_close)

	event_editor_dock = ScriptedEventEditorDock.new()
	event_editor_dock.name = "ScriptedEventEditorDock"
	event_editor_window.add_child(event_editor_dock)
	event_editor_dock.set_anchors_preset(Control.PRESET_FULL_RECT)

	EditorInterface.get_base_control().add_child(event_editor_window)


func _on_npc_composer_close() -> void:
	npc_composer_window.visible = false


func _on_npc_blueprint_editor_close() -> void:
	npc_blueprint_editor_window.visible = false


func _on_quest_blueprint_editor_close() -> void:
	quest_blueprint_editor_window.visible = false


func _on_event_editor_close() -> void:
	event_editor_window.visible = false


## Public API for external access

## Open Town Editor with a scene
func open_town_editor(scene_path: String = "") -> void:
	_show_window(town_editor_window)
	if town_editor_dock and not scene_path.is_empty() and town_editor_dock.has_method("load_scene"):
		town_editor_dock.load_scene(scene_path)


## Open Town Editor for a new town
func create_new_town(poi_data: Dictionary) -> void:
	_show_window(town_editor_window)
	if town_editor_dock and town_editor_dock.has_method("create_new_town"):
		town_editor_dock.create_new_town(poi_data)


## Open World Forge
func open_world_forge() -> void:
	_show_window(world_forge_window)


## Get the World Forge dock for external access
func get_world_forge_dock() -> Control:
	return world_forge_dock


## Open Dungeon Editor
func open_dungeon_editor() -> void:
	_show_window(dungeon_editor_window)


## Get the Dungeon Editor dock for external access
func get_dungeon_editor_dock() -> Control:
	return dungeon_editor_dock


func _get_plugin_name() -> String:
	return "Level Editors"
