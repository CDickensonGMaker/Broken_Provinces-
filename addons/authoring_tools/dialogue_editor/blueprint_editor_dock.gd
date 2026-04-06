@tool
class_name BlueprintEditorDock
extends Control
## Combined NPC and Quest Blueprint Editor dock
## Provides tabbed interface and cross-linking between NPC and Quest editors

var tab_container: TabContainer
var npc_editor: NPCBlueprintEditor
var quest_editor: QuestBlueprintEditor


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	set_anchors_preset(PRESET_FULL_RECT)

	tab_container = TabContainer.new()
	tab_container.set_anchors_preset(PRESET_FULL_RECT)
	tab_container.tabs_visible = true
	add_child(tab_container)

	# NPC Blueprint Editor tab
	npc_editor = NPCBlueprintEditor.new()
	npc_editor.name = "NPC Blueprints"
	tab_container.add_child(npc_editor)

	# Quest Blueprint Editor tab
	quest_editor = QuestBlueprintEditor.new()
	quest_editor.name = "Quest Blueprints"
	tab_container.add_child(quest_editor)


# =============================================================================
# CROSS-LINKING API - Called by child editors
# =============================================================================

func _switch_to_npc_editor() -> void:
	if tab_container and npc_editor:
		tab_container.current_tab = 0
		npc_editor._on_new_pressed()


func _switch_to_quest_editor(quest_id: String = "") -> void:
	if tab_container and quest_editor:
		tab_container.current_tab = 1
		if not quest_id.is_empty():
			quest_editor.load_quest_by_id(quest_id)
