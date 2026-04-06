@tool
extends Control
class_name TownEditorDock
## Main UI for the Town Editor - PS1 style medieval settlement builder

signal town_saved(path: String)

const Editor3DViewport = preload("res://addons/level_editors/shared/editor_3d_viewport.gd")
const ModelBrowser = preload("res://addons/level_editors/shared/model_browser.gd")
const LevelEditorData = preload("res://addons/level_editors/shared/editor_data.gd")

## Path to custom building models - GLB/FBX files named by building ID (e.g., cottage.glb)
const BUILDING_MODELS_PATH := "res://assets/models/buildings/"
const PROP_MODELS_PATH := "res://assets/models/props/"


## Try to find a model file with various naming conventions and formats
func _find_model_path(base_path: String, item_id: String) -> String:
	# Handle special naming conventions for certain buildings
	# Maps building_id from JSON -> actual model filename(s)
	var special_names: Dictionary = {
		# Shops - use shop.glb
		"inn": ["shop"],
		"general_store": ["shop"],
		"magic_shop": ["shop"],
		"tavern": ["shop"],
		# Houses - direct matches exist for most
		"shack": ["hovel"],
		# Temples
		"temple": ["temple_harvest", "chapel"],
		"cathedral": ["temple_harvest", "chapel"],
		"church": ["chapel", "temple_harvest"],
		# Military/Industrial
		"tower": ["guard_tower", "watch_tower"],
		"barracks": ["warehouse"],
		"armorer": ["blacksmith"],
		"barn": ["farm"],
		"palace": ["castle_keep", "manor"],
		# Guilds
		"guild_hall": ["guild_adventure", "adventure_guildglb"],
		"guild_adventure": ["adventure_guildglb", "guild_adventure"],
		"guild_mage": ["MAGE_guildglb", "mage_guild", "guild_mage"],
		"guild_mercenary": ["Mercenary_guild", "mercenary_guild", "guild_mercenary"],
		"guild_thieves": ["thieves_guild", "guild_thieves"],
		# Walls
		"wall_large_tower_U": ["wall_large_tower_Uglb", "wall_large_tower_U"],
	}

	# Try patterns in order of preference
	var ids_to_try: Array[String] = [item_id]
	if special_names.has(item_id):
		for alt_name: String in special_names[item_id]:
			ids_to_try.append(alt_name)

	for try_id: String in ids_to_try:
		var patterns: Array[String] = [
			base_path + try_id + ".glb",
			base_path + try_id + ".fbx",
			base_path + try_id + "_001.glb",
			base_path + try_id + "_001.fbx",
			base_path + "kenney_" + try_id + ".glb",
			base_path + "kenney_" + try_id + ".fbx",
		]
		for path: String in patterns:
			if ResourceLoader.exists(path):
				return path
	return ""

## UI Components
var viewport_3d: Editor3DViewport
var palette_tabs: TabContainer
var inspector_panel: VBoxContainer
var model_browser: ModelBrowser
var status_label: Label

## Building palette
var building_list: ItemList
var npc_list: ItemList
var prop_list: ItemList
var functional_list: ItemList

## Named NPCs palette (from data/npcs/)
var named_npc_list: ItemList
var named_npc_filter: OptionButton
var named_npc_data: Array[Dictionary] = []  # {path, npc_id, display_name, archetype, sprite_path}

## Inspector fields
var name_edit: LineEdit
var position_x: SpinBox
var position_y: SpinBox
var position_z: SpinBox
var rotation_y: SpinBox
var scale_uniform: SpinBox
var delete_btn: Button
var shop_type_option: OptionButton
var shop_type_row: HBoxContainer

## NPC inspector fields
var npc_section: VBoxContainer
var npc_id_edit: LineEdit
var is_female_check: CheckBox
var region_id_edit: LineEdit

## Quest assignment section (for quest_giver NPCs)
var quest_section: VBoxContainer
var quest_list: ItemList
var available_quests: Array[Dictionary] = []  # {id, title, giver_npc_id}

## Merchant-specific inspector fields
var merchant_section: VBoxContainer
var shop_tier_option: OptionButton
var buy_multiplier_spin: SpinBox
var sell_multiplier_spin: SpinBox
var use_conversation_check: CheckBox

## Settlement type bar
var settlement_type_option: OptionButton
var grid_size_label: Label
var district_controls: HBoxContainer

## World locations dropdown
var locations_dropdown: OptionButton

## Manipulation mode buttons
var mode_select_btn: Button
var mode_move_btn: Button
var mode_rotate_btn: Button

## State
var current_scene_path: String = ""
var level_data: LevelEditorData.LevelData
var placed_elements: Dictionary = {}  # id -> Node3D
var selected_element_id: String = ""
var current_brush: Dictionary = {}  # {type, data}
var brush_rotation: float = 0.0  # Y-axis rotation to apply when placing
var is_placing: bool = false
var show_labels: bool = true
var manipulation_mode: String = "select"  # select, move, rotate

## Manipulation state
var is_manipulating: bool = false
var manipulation_start_pos: Vector3 = Vector3.ZERO
var manipulation_start_rot: float = 0.0

## Pick-up state (element follows cursor until placed)
var picked_up_element_id: String = ""

## Snapping state
var snap_enabled: bool = true
var snap_size_custom: float = 4.0  # Custom snap size (uses level_data.snap_size if not overridden)
var edge_snap_enabled: bool = true
var edge_snap_threshold: float = 2.0  # Units within which edge snapping activates
var overlap_check_enabled: bool = true  # Check for building overlaps

## UI for snap controls
var snap_toggle: CheckBox
var snap_size_spin: SpinBox
var edge_snap_toggle: CheckBox
var overlap_check_toggle: CheckBox


## ============================================================================
## PALETTE DEFINITIONS - Buildings filtered by settlement tier
## ============================================================================

## Building tier requirements: 1=hamlet, 2=village, 3=town, 4=city, 5=capital
const BUILDINGS: Array[Dictionary] = [
	# Residential
	{"id": "hovel", "name": "Hovel", "width": 4, "height": 2.5, "depth": 4, "style": "wood", "tier": 1},
	{"id": "cottage", "name": "Cottage", "width": 5, "height": 3, "depth": 5, "style": "stone", "tier": 1},
	{"id": "house_small", "name": "Small House", "width": 6, "height": 3.5, "depth": 5, "style": "timber", "tier": 1},
	{"id": "house_small_cluster", "name": "Small House Cluster", "width": 12, "height": 4, "depth": 10, "style": "timber", "tier": 1},
	{"id": "house_medium", "name": "Medium House", "width": 8, "height": 4, "depth": 6, "style": "timber", "tier": 2},
	{"id": "house_medium_cluster", "name": "Medium House Cluster", "width": 16, "height": 5, "depth": 12, "style": "timber", "tier": 2},
	{"id": "house_large", "name": "Large House", "width": 10, "height": 5, "depth": 8, "style": "timber", "tier": 3},
	{"id": "house_large_cluster", "name": "Large House Cluster", "width": 20, "height": 6, "depth": 16, "style": "timber", "tier": 3},
	{"id": "manor", "name": "Manor House", "width": 14, "height": 6, "depth": 12, "style": "stone", "tier": 4},
	{"id": "manor_cluster", "name": "Manor Cluster", "width": 28, "height": 7, "depth": 24, "style": "stone", "tier": 4},
	{"id": "modular_house_blocks", "name": "Modular House Blocks", "width": 10, "height": 4, "depth": 10, "style": "timber", "tier": 2},
	# Commercial
	{"id": "market_stall", "name": "Market Stall", "width": 4, "height": 3, "depth": 3, "style": "stall", "tier": 1, "is_shop": true},
	{"id": "market_stall_threeinarow", "name": "Market Stalls (3)", "width": 12, "height": 3, "depth": 3, "style": "stall", "tier": 1, "is_shop": true},
	{"id": "shop", "name": "Shop", "width": 7, "height": 4, "depth": 6, "style": "timber", "tier": 2, "is_shop": true},
	{"id": "inn", "name": "Inn/Tavern", "width": 12, "height": 5, "depth": 10, "style": "timber", "tier": 2, "is_shop": true},
	{"id": "blacksmith", "name": "Blacksmith", "width": 10, "height": 4, "depth": 8, "style": "forge", "tier": 2, "is_shop": true},
	{"id": "stable", "name": "Stable", "width": 12, "height": 4, "depth": 8, "style": "barn", "tier": 2},
	{"id": "warehouse", "name": "Warehouse", "width": 14, "height": 5, "depth": 10, "style": "stone", "tier": 4},
	{"id": "warehouse_cluster", "name": "Warehouse Cluster", "width": 28, "height": 6, "depth": 20, "style": "stone", "tier": 4},
	{"id": "farm", "name": "Farm", "width": 16, "height": 4, "depth": 12, "style": "barn", "tier": 1},
	{"id": "bank", "name": "Bank", "width": 10, "height": 5, "depth": 8, "style": "stone", "tier": 4, "is_shop": true},
	# Religious/Civic - Three Gods Temples
	{"id": "chapel", "name": "Chapel", "width": 8, "height": 8, "depth": 12, "style": "church", "tier": 2},
	{"id": "temple", "name": "Temple", "width": 12, "height": 10, "depth": 16, "style": "church", "tier": 3},
	{"id": "temple_harvest", "name": "Temple of Harvest", "width": 14, "height": 12, "depth": 18, "style": "church", "tier": 3},
	{"id": "temple_time", "name": "Temple of Time", "width": 14, "height": 12, "depth": 18, "style": "church", "tier": 3},
	{"id": "temple_death", "name": "Temple of Death", "width": 14, "height": 12, "depth": 18, "style": "church", "tier": 3},
	# Guild Halls
	{"id": "guild_hall", "name": "Guild Hall", "width": 14, "height": 6, "depth": 12, "style": "stone", "tier": 3},
	{"id": "guild_adventure", "name": "Adventure Guild", "width": 14, "height": 6, "depth": 12, "style": "stone", "tier": 3},
	{"id": "guild_mage", "name": "Mage Guild", "width": 14, "height": 8, "depth": 12, "style": "stone", "tier": 4},
	{"id": "guild_mercenary", "name": "Mercenary Guild", "width": 14, "height": 6, "depth": 12, "style": "stone", "tier": 3},
	{"id": "guild_thieves", "name": "Thieves Guild", "width": 12, "height": 5, "depth": 10, "style": "timber", "tier": 4},
	{"id": "town_hall", "name": "Town Hall", "width": 16, "height": 7, "depth": 14, "style": "civic", "tier": 4},
	{"id": "castle_keep", "name": "Castle Keep", "width": 20, "height": 15, "depth": 20, "style": "castle", "tier": 5},
	# Military/Defensive - Towers
	{"id": "watchtower", "name": "Watchtower", "width": 4, "height": 10, "depth": 4, "style": "tower", "tier": 2},
	{"id": "watch_tower", "name": "Watch Tower (Alt)", "width": 4, "height": 10, "depth": 4, "style": "tower", "tier": 2},
	{"id": "guard_tower", "name": "Guard Tower", "width": 5, "height": 12, "depth": 5, "style": "tower", "tier": 3},
	{"id": "wooden_outpost_tower", "name": "Wooden Outpost Tower", "width": 4, "height": 8, "depth": 4, "style": "tower", "tier": 1},
	# Military/Defensive - Walls
	{"id": "wall_segment", "name": "Wall Segment", "width": 10, "height": 5, "depth": 2, "style": "wall", "tier": 3},
	{"id": "wall_corner", "name": "Wall Corner", "width": 4, "height": 5, "depth": 4, "style": "wall", "tier": 3},
	{"id": "wall_small", "name": "Wall Small", "width": 6, "height": 4, "depth": 2, "style": "wall", "tier": 2},
	{"id": "wall_medium", "name": "Wall Medium", "width": 10, "height": 5, "depth": 2, "style": "wall", "tier": 3},
	{"id": "wall_large", "name": "Wall Large", "width": 14, "height": 6, "depth": 2, "style": "wall", "tier": 4},
	{"id": "wall_large_tower", "name": "Wall + Tower", "width": 8, "height": 10, "depth": 8, "style": "wall", "tier": 4},
	{"id": "wall_large_tower_L", "name": "Wall + Tower (L)", "width": 12, "height": 10, "depth": 12, "style": "wall", "tier": 4},
	{"id": "wall_large_tower_U", "name": "Wall + Tower (U)", "width": 14, "height": 10, "depth": 8, "style": "wall", "tier": 4},
	# Military/Defensive - Gates & Guards
	{"id": "gatehouse", "name": "Gatehouse", "width": 8, "height": 8, "depth": 6, "style": "gate", "tier": 4},
	{"id": "gate_house", "name": "Gate House (Alt)", "width": 8, "height": 8, "depth": 6, "style": "gate", "tier": 4},
	{"id": "guard_house_wall", "name": "Guard House (Wall)", "width": 6, "height": 6, "depth": 6, "style": "wall", "tier": 3},
	{"id": "barracks", "name": "Barracks", "width": 14, "height": 4, "depth": 8, "style": "military", "tier": 4},
	# Special
	{"id": "well", "name": "Well", "width": 2, "height": 2, "depth": 2, "style": "well", "tier": 1},
	{"id": "fountain", "name": "Fountain", "width": 4, "height": 2, "depth": 4, "style": "fountain", "tier": 4},
	{"id": "windmill", "name": "Windmill", "width": 6, "height": 12, "depth": 6, "style": "windmill", "tier": 2},
	{"id": "gallows", "name": "Gallows", "width": 3, "height": 4, "depth": 3, "style": "gallows", "tier": 3},
]

## Shop types that can be assigned to shop buildings
const SHOP_TYPES: Array[Dictionary] = [
	{"id": "", "name": "(None)", "npc_type": ""},
	{"id": "general", "name": "General Store", "npc_type": "merchant_general"},
	{"id": "weapons", "name": "Weapons Shop", "npc_type": "merchant_weapons"},
	{"id": "armor", "name": "Armor Shop", "npc_type": "merchant_armor"},
	{"id": "magic", "name": "Magic Shop", "npc_type": "merchant_magic"},
	{"id": "alchemy", "name": "Alchemy Shop", "npc_type": "merchant_alchemy"},
	{"id": "food", "name": "Food/Tavern", "npc_type": "innkeeper"},
	{"id": "blacksmith", "name": "Blacksmith", "npc_type": "blacksmith_npc"},
	{"id": "stable", "name": "Stable", "npc_type": "stablemaster"},
	{"id": "bank", "name": "Bank", "npc_type": "banker"},
]

const NPCS: Array[Dictionary] = [
	# Civilians
	{"id": "civilian_male", "name": "Civilian (Male)", "zoo_id": "man_civilian"},
	{"id": "civilian_female", "name": "Civilian (Female)", "zoo_id": "woman_civilian"},
	# Guards
	{"id": "guard", "name": "Guard", "zoo_id": "guard_civilian", "has_patrol": true},
	{"id": "guard_captain", "name": "Guard Captain", "zoo_id": "guard2_civilian", "has_patrol": true},
	# Merchants
	{"id": "merchant_general", "name": "General Merchant", "zoo_id": "merchant_civilian", "shop_type": "general"},
	{"id": "merchant_weapons", "name": "Weapons Merchant", "zoo_id": "blacksmith", "shop_type": "blacksmith"},
	{"id": "merchant_armor", "name": "Armor Merchant", "zoo_id": "blacksmith", "shop_type": "armor"},
	{"id": "merchant_magic", "name": "Magic Merchant", "zoo_id": "magic_shop_worker", "shop_type": "magic"},
	# Service NPCs
	{"id": "innkeeper", "name": "Innkeeper", "zoo_id": "innkeeper_male"},
	{"id": "blacksmith_npc", "name": "Blacksmith NPC", "zoo_id": "blacksmith", "shop_type": "blacksmith"},
	# Religious/Special
	{"id": "priest", "name": "Priest", "zoo_id": "monk_tan"},
	{"id": "quest_giver", "name": "Quest Giver", "zoo_id": "wizard_mage"},
	{"id": "noble", "name": "Noble", "zoo_id": "male_noble"},
	{"id": "beggar", "name": "Beggar", "zoo_id": "man_civilian"},
]

const PROPS: Array[Dictionary] = [
	# Static decorative props (CSG in export, visual only)
	{"id": "barrel", "name": "Barrel", "spawnable": false},
	{"id": "crate", "name": "Crate", "spawnable": false},
	{"id": "crate_stack", "name": "Crate Stack", "spawnable": false},
	{"id": "bench", "name": "Bench", "spawnable": false},
	{"id": "cart", "name": "Cart", "spawnable": false},
	{"id": "table", "name": "Table", "spawnable": false},
	{"id": "chair", "name": "Chair", "spawnable": false},
	{"id": "fence_wood", "name": "Wood Fence", "spawnable": false},
	{"id": "fence_stone", "name": "Stone Fence", "spawnable": false},
	{"id": "sign_post", "name": "Sign Post", "spawnable": false},
	{"id": "hay_bale", "name": "Hay Bale", "spawnable": false},
	{"id": "woodpile", "name": "Wood Pile", "spawnable": false},
	{"id": "anvil", "name": "Anvil", "spawnable": false},
	{"id": "grindstone", "name": "Grindstone", "spawnable": false},
	{"id": "hitching_post", "name": "Hitching Post", "spawnable": false},
	{"id": "statue", "name": "Statue", "spawnable": false},
	{"id": "tree_oak", "name": "Oak Tree", "spawnable": false},
	{"id": "tree_pine", "name": "Pine Tree", "spawnable": false},
	{"id": "bush", "name": "Bush", "spawnable": false},
	# Kenney Props (GLB models)
	{"id": "barrels", "name": "Barrels (Stack)", "spawnable": false},
	{"id": "bricks", "name": "Bricks", "spawnable": false},
	{"id": "column", "name": "Stone Column", "spawnable": false},
	{"id": "column_damaged", "name": "Damaged Column", "spawnable": false},
	{"id": "column_wood", "name": "Wood Column", "spawnable": false},
	{"id": "detail_barrel", "name": "Detail Barrel", "spawnable": false},
	{"id": "detail_crate", "name": "Detail Crate", "spawnable": false},
	{"id": "detail_crate_ropes", "name": "Crate w/ Ropes", "spawnable": false},
	{"id": "detail_crate_small", "name": "Small Crate", "spawnable": false},
	{"id": "fence", "name": "Stone Fence", "spawnable": false},
	{"id": "fence_top", "name": "Fence Top", "spawnable": false},
	{"id": "ladder", "name": "Ladder", "spawnable": false},
	{"id": "pulley", "name": "Pulley", "spawnable": false},
	{"id": "pulley_crate", "name": "Pulley w/ Crate", "spawnable": false},
	{"id": "tree_large", "name": "Large Tree", "spawnable": false},
	{"id": "tree_shrub", "name": "Shrub", "spawnable": false},
	{"id": "water", "name": "Water Feature", "spawnable": false},
	# Interactable props (spawn at runtime)
	{"id": "torch_wall", "name": "Wall Torch", "spawnable": true},
	{"id": "torch_standing", "name": "Standing Torch", "spawnable": true},
]

const FUNCTIONALS: Array[Dictionary] = [
	# Spawn/Navigation
	{"id": "spawn_point", "name": "Spawn Point", "func_type": "spawn_point"},
	{"id": "fast_travel_shrine", "name": "Fast Travel Shrine", "func_type": "fast_travel_shrine"},
	{"id": "bounty_board", "name": "Bounty Board", "func_type": "bounty_board"},
	# Doors
	{"id": "door_zone", "name": "Zone Exit Door", "func_type": "door_zone"},
	{"id": "door_interior", "name": "Interior Door", "func_type": "door_interior"},
	# Rest/Healing
	{"id": "rest_area", "name": "Rest Area (Bed)", "func_type": "rest_area"},
	# Containers
	{"id": "chest_common", "name": "Chest (Common)", "func_type": "chest", "loot_tier": 1},
	{"id": "chest_rare", "name": "Chest (Rare)", "func_type": "chest", "loot_tier": 3},
	{"id": "chest_locked", "name": "Chest (Locked)", "func_type": "chest_locked", "loot_tier": 2},
	# Crafting
	{"id": "crafting_station", "name": "Crafting Station", "func_type": "crafting_station"},
	{"id": "alchemy_table", "name": "Alchemy Table", "func_type": "alchemy_table"},
]

## Settlement tier mapping
const SETTLEMENT_TIERS: Dictionary = {
	"hamlet": 1,
	"village": 2,
	"town": 3,
	"city": 4,
	"capital": 5,
}


func _ready() -> void:
	level_data = LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	_build_ui_async()


## Handle keyboard shortcuts for rotation, delete, deselect
func _input(event: InputEvent) -> void:
	# Only handle keyboard when this dock is visible and has focus
	if not is_visible_in_tree():
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_R:
				# Rotate picked-up element, placing brush, or selected element
				if not picked_up_element_id.is_empty():
					_rotate_element(picked_up_element_id, 45)
				elif is_placing and not current_brush.is_empty():
					_rotate_brush(45)
				else:
					_rotate_selected(45)
				get_viewport().set_input_as_handled()
			KEY_Q:
				if not picked_up_element_id.is_empty():
					_rotate_element(picked_up_element_id, -45)
				elif is_placing and not current_brush.is_empty():
					_rotate_brush(-45)
				else:
					_rotate_selected(-45)
				get_viewport().set_input_as_handled()
			KEY_DELETE, KEY_BACKSPACE:
				_on_delete_selected()
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				# Cancel pick-up or deselect
				if not picked_up_element_id.is_empty():
					picked_up_element_id = ""
					_set_status("Cancelled pick-up")
				else:
					_deselect_all()
				get_viewport().set_input_as_handled()
			KEY_C:
				# Copy selected element (including rotation) for placement
				_copy_selected_element()
				get_viewport().set_input_as_handled()


## Rotate a specific element by degrees
func _rotate_element(elem_id: String, degrees: float) -> void:
	if not placed_elements.has(elem_id):
		return
	var node: Node3D = placed_elements[elem_id] as Node3D
	if node and is_instance_valid(node):
		node.rotation_degrees.y += degrees
		rotation_y.value = fmod(node.rotation_degrees.y + 360, 360)
		# Update element data
		for elem: LevelEditorData.PlacedElement in level_data.elements:
			if elem.id == elem_id:
				elem.rotation.y = node.rotation_degrees.y
				break


## Rotate the brush (for pre-placement rotation)
func _rotate_brush(degrees: float) -> void:
	brush_rotation = fmod(brush_rotation + degrees + 360, 360)
	_update_ghost_preview()
	var brush_name: String = ""
	if current_brush.has("data") and current_brush["data"] is Dictionary:
		brush_name = current_brush["data"].get("name", "")
	if brush_name.is_empty() and current_brush.has("data") and current_brush["data"] is Dictionary:
		brush_name = current_brush["data"].get("path", "").get_file()
	_set_status("Placing %s (rot: %.0f deg) - click to place" % [brush_name, brush_rotation])


## Copy the selected element to brush (including rotation) for repeated placement
func _copy_selected_element() -> void:
	if selected_element_id.is_empty():
		_set_status("No element selected to copy")
		return

	# Find the element data for the selected element
	var elem_data: LevelEditorData.PlacedElement = null
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem_data = elem
			break

	if not elem_data:
		_set_status("Could not find element data")
		return

	# Get the node to read its current rotation
	var node: Node3D = placed_elements.get(selected_element_id)
	if not node or not is_instance_valid(node):
		_set_status("Element node not found")
		return

	# Set up the brush based on element type
	match elem_data.element_type:
		LevelEditorData.ElementType.BUILDING:
			# Find the building data from BUILDINGS array
			var building_id: String = elem_data.properties.get("id", "")
			for b: Dictionary in BUILDINGS:
				if b["id"] == building_id:
					current_brush = {"type": "building", "data": b.duplicate()}
					break
		LevelEditorData.ElementType.NPC:
			var npc_id: String = elem_data.properties.get("id", "")
			for n: Dictionary in NPCS:
				if n["id"] == npc_id:
					current_brush = {"type": "npc", "data": n.duplicate()}
					break
		LevelEditorData.ElementType.PROP:
			var prop_id: String = elem_data.properties.get("id", "")
			for p: Dictionary in PROPS:
				if p["id"] == prop_id:
					current_brush = {"type": "prop", "data": p.duplicate()}
					break
		LevelEditorData.ElementType.FUNCTIONAL:
			var func_id: String = elem_data.properties.get("id", "")
			for f: Dictionary in FUNCTIONALS:
				if f["id"] == func_id:
					current_brush = {"type": "functional", "data": f.duplicate()}
					break
		LevelEditorData.ElementType.CUSTOM_MODEL:
			var model_path: String = elem_data.properties.get("model_path", "")
			if not model_path.is_empty():
				current_brush = {"type": "custom_model", "data": {"path": model_path}}

	if current_brush.is_empty():
		_set_status("Could not copy element")
		return

	# Copy the rotation from the selected element
	brush_rotation = node.rotation_degrees.y
	is_placing = true
	picked_up_element_id = ""

	# Clear palette selections since we're using a copied brush
	_clear_other_selections("")

	# Update ghost preview
	_update_ghost_preview()

	var elem_name: String = elem_data.properties.get("name", "element")
	_set_status("Copied %s (rot: %.0f deg) - click to place" % [elem_name, brush_rotation])


## Deselect current element and clear placing mode
func _deselect_all() -> void:
	selected_element_id = ""
	picked_up_element_id = ""
	is_placing = false
	current_brush.clear()
	brush_rotation = 0.0
	if viewport_3d:
		viewport_3d.clear_ghost_preview()
	_clear_other_selections("")
	_refresh_inspector_for_selection(null)
	_set_status("Deselected")


func _build_ui_async() -> void:
	await _build_ui()
	_connect_signals()


func _build_ui() -> void:
	# Clear any existing children first
	for child in get_children():
		child.queue_free()

	# Wait a frame for queue_free to complete to avoid duplicates
	await get_tree().process_frame

	# Main vertical layout: toolbar at top, content below
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 2)
	add_child(main_vbox)

	# Build toolbar bars at top (spans full width)
	_build_toolbar(main_vbox)
	_build_settlement_bar(main_vbox)
	_build_manipulation_bar(main_vbox)

	# Content area: palette | viewport | inspector
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hbox.add_theme_constant_override("separation", 4)
	content_hbox.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse through
	main_vbox.add_child(content_hbox)

	# LEFT: Palette panel (fixed width)
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size.x = 200
	left_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	content_hbox.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	left_panel.add_child(left_vbox)
	_build_palette(left_vbox)

	# CENTER: 3D Viewport (expands to fill)
	var center_panel := VBoxContainer.new()
	center_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_panel.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow mouse through to viewport
	content_hbox.add_child(center_panel)

	_build_viewport(center_panel)

	# RIGHT: Inspector panel (fixed width)
	var right_panel := PanelContainer.new()
	right_panel.custom_minimum_size.x = 220
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	content_hbox.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	right_panel.add_child(right_vbox)
	_build_inspector(right_vbox)

	# Status bar at bottom
	_build_status_bar(main_vbox)


func _build_palette(parent: Control) -> void:
	var header := Label.new()
	header.text = "PALETTE"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	parent.add_child(header)

	parent.add_child(HSeparator.new())

	palette_tabs = TabContainer.new()
	palette_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	palette_tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	parent.add_child(palette_tabs)

	# Buildings tab
	var buildings_container := VBoxContainer.new()
	buildings_container.name = "Build"
	palette_tabs.add_child(buildings_container)

	building_list = ItemList.new()
	building_list.auto_height = true
	building_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	building_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_list.item_selected.connect(_on_building_selected)
	buildings_container.add_child(building_list)

	_refresh_building_list()

	# NPCs tab
	var npcs_container := VBoxContainer.new()
	npcs_container.name = "NPCs"
	palette_tabs.add_child(npcs_container)

	npc_list = ItemList.new()
	npc_list.auto_height = true
	npc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	npc_list.item_selected.connect(_on_npc_selected)
	npcs_container.add_child(npc_list)

	for n: Dictionary in NPCS:
		npc_list.add_item(n["name"])

	# Named NPCs tab (from data/npcs/)
	_build_named_npcs_tab(palette_tabs)

	# Props tab
	var props_container := VBoxContainer.new()
	props_container.name = "Props"
	palette_tabs.add_child(props_container)

	prop_list = ItemList.new()
	prop_list.auto_height = true
	prop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prop_list.item_selected.connect(_on_prop_selected)
	props_container.add_child(prop_list)

	for p: Dictionary in PROPS:
		prop_list.add_item(p["name"])

	# Functional tab
	var func_container := VBoxContainer.new()
	func_container.name = "Func"
	palette_tabs.add_child(func_container)

	functional_list = ItemList.new()
	functional_list.auto_height = true
	functional_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	functional_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	functional_list.item_selected.connect(_on_functional_selected)
	func_container.add_child(functional_list)

	for f: Dictionary in FUNCTIONALS:
		functional_list.add_item(f["name"])

	# Models tab
	var models_container := VBoxContainer.new()
	models_container.name = "GLB"
	palette_tabs.add_child(models_container)

	model_browser = ModelBrowser.new()
	model_browser.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_browser.model_selected.connect(_on_custom_model_selected)
	models_container.add_child(model_browser)


## Refresh building list based on current settlement tier
func _refresh_building_list() -> void:
	if not building_list:
		return

	building_list.clear()
	var current_tier: int = SETTLEMENT_TIERS.get(level_data.settlement_type, 2)

	for b: Dictionary in BUILDINGS:
		var required_tier: int = b.get("tier", 1)
		if required_tier <= current_tier:
			building_list.add_item(b["name"])
			# Store the original index in metadata
			building_list.set_item_metadata(building_list.item_count - 1, BUILDINGS.find(b))


## ============================================================================
## NAMED NPCs TAB (from data/npcs/)
## ============================================================================

## Build the Named NPCs tab UI
func _build_named_npcs_tab(tabs: TabContainer) -> void:
	var named_container := VBoxContainer.new()
	named_container.name = "Named"
	tabs.add_child(named_container)

	# Filter dropdown
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	named_container.add_child(filter_row)

	var filter_label := Label.new()
	filter_label.text = "Filter:"
	filter_row.add_child(filter_label)

	named_npc_filter = OptionButton.new()
	named_npc_filter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named_npc_filter.add_item("All")
	named_npc_filter.add_item("quest_giver")
	named_npc_filter.add_item("merchant")
	named_npc_filter.add_item("civilian")
	named_npc_filter.add_item("guard")
	named_npc_filter.add_item("priest")
	named_npc_filter.add_item("noble")
	named_npc_filter.item_selected.connect(_on_named_npc_filter_changed)
	filter_row.add_child(named_npc_filter)

	# NPC list
	named_npc_list = ItemList.new()
	named_npc_list.auto_height = true
	named_npc_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	named_npc_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	named_npc_list.item_selected.connect(_on_named_npc_selected)
	named_container.add_child(named_npc_list)

	# Load NPCs from data/npcs/
	_load_named_npcs()
	_refresh_named_npc_list("All")


## Load all NPCData resources from data/npcs/
func _load_named_npcs() -> void:
	named_npc_data.clear()

	var dir := DirAccess.open("res://data/npcs/")
	if not dir:
		push_warning("[TownEditor] Could not open data/npcs/ directory")
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var path: String = "res://data/npcs/" + file_name
			var npc_data: Resource = load(path)
			if npc_data and npc_data.get("npc_id"):
				named_npc_data.append({
					"path": path,
					"npc_id": npc_data.npc_id,
					"display_name": npc_data.display_name,
					"archetype": npc_data.archetype,
					"sprite_path": npc_data.sprite_path,
					"sprite_h_frames": npc_data.sprite_h_frames,
					"sprite_v_frames": npc_data.sprite_v_frames,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by display name
	named_npc_data.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.display_name < b.display_name
	)


## Refresh the named NPC list based on archetype filter
func _refresh_named_npc_list(filter: String) -> void:
	if not named_npc_list:
		return

	named_npc_list.clear()

	for npc: Dictionary in named_npc_data:
		# Apply filter
		if filter != "All" and npc.archetype != filter:
			continue

		# Display: "Name (archetype)"
		var display_text: String = "%s (%s)" % [npc.display_name, npc.archetype]
		var idx: int = named_npc_list.item_count
		named_npc_list.add_item(display_text)
		named_npc_list.set_item_metadata(idx, npc)


## Handle filter dropdown change
func _on_named_npc_filter_changed(index: int) -> void:
	var filter: String = named_npc_filter.get_item_text(index)
	_refresh_named_npc_list(filter)


## Handle named NPC selection from palette
func _on_named_npc_selected(index: int) -> void:
	_clear_other_selections("named_npc")

	var npc_meta: Dictionary = named_npc_list.get_item_metadata(index)
	if npc_meta.is_empty():
		return

	# Set brush with npc_data_path reference
	current_brush = {
		"type": "named_npc",
		"data": {
			"npc_data_path": npc_meta.path,
			"npc_id": npc_meta.npc_id,
			"display_name": npc_meta.display_name,
			"archetype": npc_meta.archetype,
			"sprite_path": npc_meta.sprite_path,
			"sprite_h_frames": npc_meta.get("sprite_h_frames", 4),
			"sprite_v_frames": npc_meta.get("sprite_v_frames", 1),
			"name": npc_meta.display_name,  # For display in editor
		}
	}
	brush_rotation = 0.0
	is_placing = true
	manipulation_mode = "select"
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % npc_meta.display_name)


## ============================================================================
## QUEST ASSIGNMENT SECTION (for quest_giver NPCs)
## ============================================================================

## Build the Quest Assignment section UI
func _build_quest_section(parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

	quest_section = VBoxContainer.new()
	quest_section.visible = false
	quest_section.add_theme_constant_override("separation", 4)
	parent.add_child(quest_section)

	var quest_header := _make_label("Quest Assignment")
	quest_header.add_theme_font_size_override("font_size", 12)
	quest_header.add_theme_color_override("font_color", Color(0.8, 0.7, 0.4))  # Gold tint
	quest_section.add_child(quest_header)

	var help_label := _make_label("Select quests for this NPC to offer:")
	help_label.add_theme_font_size_override("font_size", 10)
	help_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	quest_section.add_child(help_label)

	# Multi-select quest list
	quest_list = ItemList.new()
	quest_list.select_mode = ItemList.SELECT_MULTI
	quest_list.custom_minimum_size.y = 120
	quest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_list.multi_selected.connect(_on_quest_selection_changed)
	quest_section.add_child(quest_list)

	# Load available quests
	_load_available_quests()


## Load all quests from data/quests/ (non-recursive, top-level quests only)
func _load_available_quests() -> void:
	available_quests.clear()

	# Load from main quests directory (not bounties or chains subdirs)
	_scan_quest_directory("res://data/quests/")


## Scan a directory for quest JSON files
func _scan_quest_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("[TownEditor] Could not open quest directory: %s" % dir_path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var full_path: String = dir_path + file_name
			var quest_data: Dictionary = _load_quest_json(full_path)
			if not quest_data.is_empty():
				available_quests.append({
					"id": quest_data.get("id", file_name.get_basename()),
					"title": quest_data.get("title", file_name.get_basename()),
					"giver_npc_id": quest_data.get("giver_npc_id", ""),
					"path": full_path,
				})
		file_name = dir.get_next()
	dir.list_dir_end()

	# Sort by title
	available_quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.title < b.title
	)


## Load and parse a quest JSON file
func _load_quest_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error: int = json.parse(json_str)
	if error != OK:
		push_warning("[TownEditor] Failed to parse quest JSON: %s" % path)
		return {}

	return json.data if json.data is Dictionary else {}


## Refresh the quest list for a specific NPC
## Marks quests where this NPC is the giver with [*]
func _refresh_quest_list_for_npc(npc_id: String, current_quest_ids: Array) -> void:
	if not quest_list:
		return

	quest_list.clear()

	for quest: Dictionary in available_quests:
		var is_giver: bool = (quest.giver_npc_id == npc_id)
		var is_selected: bool = quest.id in current_quest_ids

		# Format: "[*] Title" for quests where this NPC is the giver
		var display: String = quest.title
		if is_giver:
			display = "[*] " + display

		var idx: int = quest_list.item_count
		quest_list.add_item(display)
		quest_list.set_item_metadata(idx, quest.id)

		# Select items that are already assigned
		if is_selected:
			quest_list.select(idx, false)  # false = don't emit signal


## Handle quest selection changes
func _on_quest_selection_changed(_index: int, _selected: bool) -> void:
	if selected_element_id.is_empty():
		return

	# Gather all selected quest IDs
	var selected_quest_ids: Array[String] = []
	for i: int in range(quest_list.item_count):
		if quest_list.is_selected(i):
			var quest_id: Variant = quest_list.get_item_metadata(i)
			if quest_id is String:
				selected_quest_ids.append(quest_id)

	# Update element properties
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem.properties["quest_ids"] = selected_quest_ids
			break

	_set_status("Assigned %d quest(s) to NPC" % selected_quest_ids.size())


func _build_toolbar(parent: Control) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	parent.add_child(toolbar)

	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_pressed)
	toolbar.add_child(new_btn)

	var open_btn := Button.new()
	open_btn.text = "Open"
	open_btn.pressed.connect(_on_open_pressed)
	toolbar.add_child(open_btn)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_btn)

	toolbar.add_child(VSeparator.new())

	var export_btn := Button.new()
	export_btn.text = "Export .tscn"
	export_btn.pressed.connect(_on_export_pressed)
	toolbar.add_child(export_btn)

	toolbar.add_child(VSeparator.new())

	var labels_btn := CheckButton.new()
	labels_btn.text = "Labels"
	labels_btn.button_pressed = show_labels
	labels_btn.toggled.connect(_on_labels_toggled)
	toolbar.add_child(labels_btn)

	toolbar.add_child(VSeparator.new())

	# World locations dropdown
	var loc_label := Label.new()
	loc_label.text = "Load:"
	toolbar.add_child(loc_label)

	locations_dropdown = OptionButton.new()
	locations_dropdown.name = "LocationsDropdown"
	locations_dropdown.custom_minimum_size.x = 140
	_populate_locations_dropdown()
	locations_dropdown.item_selected.connect(_on_location_selected)
	toolbar.add_child(locations_dropdown)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)

	var clear_btn := Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear_pressed)
	toolbar.add_child(clear_btn)


func _build_settlement_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	parent.add_child(bar)

	bar.add_child(_make_label("Type:"))

	settlement_type_option = OptionButton.new()
	for type_key: String in LevelEditorData.SETTLEMENT_TYPES.keys():
		var type_info: Dictionary = LevelEditorData.SETTLEMENT_TYPES[type_key]
		settlement_type_option.add_item(type_info.name)
		settlement_type_option.set_item_metadata(settlement_type_option.item_count - 1, type_key)
	settlement_type_option.item_selected.connect(_on_settlement_type_changed)
	bar.add_child(settlement_type_option)

	bar.add_child(_make_label("Size:"))

	grid_size_label = Label.new()
	grid_size_label.text = "128x128"
	bar.add_child(grid_size_label)

	# District controls (visible for capital only)
	district_controls = HBoxContainer.new()
	district_controls.visible = false
	bar.add_child(district_controls)

	district_controls.add_child(_make_label("District:"))
	var district_spin := SpinBox.new()
	district_spin.min_value = 1
	district_spin.max_value = 4
	district_spin.value = 1
	district_controls.add_child(district_spin)

	# Select village by default
	_select_settlement_type("village")


func _build_manipulation_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	parent.add_child(bar)

	bar.add_child(_make_label("Mode:"))

	mode_select_btn = Button.new()
	mode_select_btn.text = "Select"
	mode_select_btn.toggle_mode = true
	mode_select_btn.button_pressed = true
	mode_select_btn.pressed.connect(func() -> void: _set_manipulation_mode("select"))
	bar.add_child(mode_select_btn)

	mode_move_btn = Button.new()
	mode_move_btn.text = "Move"
	mode_move_btn.toggle_mode = true
	mode_move_btn.tooltip_text = "Select element, then click to move it to that position"
	mode_move_btn.pressed.connect(func() -> void: _set_manipulation_mode("move"))
	bar.add_child(mode_move_btn)

	mode_rotate_btn = Button.new()
	mode_rotate_btn.text = "Rotate"
	mode_rotate_btn.toggle_mode = true
	mode_rotate_btn.pressed.connect(func() -> void: _set_manipulation_mode("rotate"))
	bar.add_child(mode_rotate_btn)

	bar.add_child(VSeparator.new())

	var rot_left := Button.new()
	rot_left.text = "< 45°"
	rot_left.pressed.connect(func() -> void: _rotate_selected(-45))
	bar.add_child(rot_left)

	var rot_right := Button.new()
	rot_right.text = "45° >"
	rot_right.pressed.connect(func() -> void: _rotate_selected(45))
	bar.add_child(rot_right)

	bar.add_child(VSeparator.new())

	# Snap controls
	snap_toggle = CheckBox.new()
	snap_toggle.text = "Snap"
	snap_toggle.button_pressed = snap_enabled
	snap_toggle.tooltip_text = "Enable grid snapping for placement"
	snap_toggle.toggled.connect(func(on: bool) -> void: snap_enabled = on)
	bar.add_child(snap_toggle)

	snap_size_spin = SpinBox.new()
	snap_size_spin.min_value = 0.5
	snap_size_spin.max_value = 16.0
	snap_size_spin.step = 0.5
	snap_size_spin.value = snap_size_custom
	snap_size_spin.tooltip_text = "Grid snap size in units"
	snap_size_spin.custom_minimum_size.x = 60
	snap_size_spin.value_changed.connect(func(v: float) -> void: snap_size_custom = v)
	bar.add_child(snap_size_spin)

	edge_snap_toggle = CheckBox.new()
	edge_snap_toggle.text = "Edge"
	edge_snap_toggle.button_pressed = edge_snap_enabled
	edge_snap_toggle.tooltip_text = "Snap building edges to nearby buildings"
	edge_snap_toggle.toggled.connect(func(on: bool) -> void: edge_snap_enabled = on)
	bar.add_child(edge_snap_toggle)

	overlap_check_toggle = CheckBox.new()
	overlap_check_toggle.text = "Collision"
	overlap_check_toggle.button_pressed = overlap_check_enabled
	overlap_check_toggle.tooltip_text = "Prevent overlapping buildings"
	overlap_check_toggle.toggled.connect(func(on: bool) -> void: overlap_check_enabled = on)
	bar.add_child(overlap_check_toggle)


func _set_manipulation_mode(mode: String) -> void:
	manipulation_mode = mode
	is_placing = false
	picked_up_element_id = ""
	current_brush.clear()
	brush_rotation = 0.0
	if viewport_3d:
		viewport_3d.clear_ghost_preview()

	# Update button states
	mode_select_btn.button_pressed = (mode == "select")
	mode_move_btn.button_pressed = (mode == "move")
	mode_rotate_btn.button_pressed = (mode == "rotate")

	# Clear palette selections
	_clear_other_selections("")

	_set_status("Click on element to pick up and move | R/Q=rotate, C=copy")


func _rotate_selected(degrees: float) -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if node:
		node.rotation_degrees.y += degrees
		rotation_y.value = fmod(node.rotation_degrees.y + 360, 360)
		# Update element data
		for elem: LevelEditorData.PlacedElement in level_data.elements:
			if elem.id == selected_element_id:
				elem.rotation.y = node.rotation_degrees.y
				break


func _select_settlement_type(type_key: String) -> void:
	for i: int in range(settlement_type_option.item_count):
		if settlement_type_option.get_item_metadata(i) == type_key:
			settlement_type_option.select(i)
			_on_settlement_type_changed(i)
			break


func _on_settlement_type_changed(index: int) -> void:
	var type_key: String = settlement_type_option.get_item_metadata(index)
	var type_info: Dictionary = LevelEditorData.SETTLEMENT_TYPES.get(type_key, {})

	level_data.settlement_type = type_key
	level_data.grid_size = type_info.get("grid_size", Vector2i(128, 128))

	grid_size_label.text = "%dx%d" % [level_data.grid_size.x, level_data.grid_size.y]

	# Show/hide district controls for capitals
	district_controls.visible = (type_info.get("max_districts", 1) > 1)

	# Auto-scale ground and grid to match settlement size
	if viewport_3d:
		var ground_size: float = float(level_data.grid_size.x)
		viewport_3d.set_ground_size(ground_size)
		viewport_3d.resize_grid(ground_size)

	# Refresh building list with new tier filter
	_refresh_building_list()


func _build_viewport(parent: Control) -> void:
	var viewport_container := PanelContainer.new()
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# CRITICAL: Allow mouse events to pass through to the viewport
	viewport_container.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(viewport_container)

	viewport_3d = Editor3DViewport.new()
	viewport_3d.set_anchors_preset(Control.PRESET_FULL_RECT)
	viewport_3d.mouse_filter = Control.MOUSE_FILTER_STOP  # Viewport captures input
	viewport_container.add_child(viewport_3d)


func _build_status_bar(parent: Control) -> void:
	var status_bar := HBoxContainer.new()
	parent.add_child(status_bar)

	status_label = Label.new()
	status_label.text = "Ready - Select a building from palette or click existing to edit"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(status_label)


func _build_inspector(parent: Control) -> void:
	var header := Label.new()
	header.text = "INSPECTOR"
	header.add_theme_font_size_override("font_size", 14)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	parent.add_child(header)

	parent.add_child(HSeparator.new())

	inspector_panel = VBoxContainer.new()
	inspector_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_theme_constant_override("separation", 6)
	parent.add_child(inspector_panel)

	# Add margin container for padding
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_child(margin)

	var fields_container := VBoxContainer.new()
	fields_container.add_theme_constant_override("separation", 8)
	margin.add_child(fields_container)

	# Name field
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	fields_container.add_child(name_row)
	var name_label := _make_label("Name:")
	name_label.custom_minimum_size.x = 70
	name_row.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(name_edit)

	fields_container.add_child(HSeparator.new())

	# Position section header
	var pos_header := _make_label("Position")
	pos_header.add_theme_font_size_override("font_size", 12)
	pos_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	fields_container.add_child(pos_header)

	var pos_row := HBoxContainer.new()
	pos_row.add_theme_constant_override("separation", 4)
	fields_container.add_child(pos_row)

	pos_row.add_child(_make_label("X"))
	position_x = SpinBox.new()
	position_x.min_value = -500
	position_x.max_value = 500
	position_x.step = 0.5
	position_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_x.value_changed.connect(_on_position_changed)
	pos_row.add_child(position_x)

	pos_row.add_child(_make_label("Z"))
	position_z = SpinBox.new()
	position_z.min_value = -500
	position_z.max_value = 500
	position_z.step = 0.5
	position_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_z.value_changed.connect(_on_position_changed)
	pos_row.add_child(position_z)

	# Height (Y)
	var height_row := HBoxContainer.new()
	height_row.add_theme_constant_override("separation", 8)
	fields_container.add_child(height_row)
	var height_label := _make_label("Height Y:")
	height_label.custom_minimum_size.x = 70
	height_row.add_child(height_label)
	position_y = SpinBox.new()
	position_y.min_value = -10
	position_y.max_value = 50
	position_y.step = 0.5
	position_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	position_y.value_changed.connect(_on_position_changed)
	height_row.add_child(position_y)

	fields_container.add_child(HSeparator.new())

	# Transform section header
	var transform_header := _make_label("Transform")
	transform_header.add_theme_font_size_override("font_size", 12)
	transform_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	fields_container.add_child(transform_header)

	# Rotation Y
	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 8)
	fields_container.add_child(rot_row)
	var rot_label := _make_label("Rotation:")
	rot_label.custom_minimum_size.x = 70
	rot_row.add_child(rot_label)
	rotation_y = SpinBox.new()
	rotation_y.min_value = 0
	rotation_y.max_value = 360
	rotation_y.step = 15
	rotation_y.suffix = "°"
	rotation_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rotation_y.value_changed.connect(_on_rotation_changed)
	rot_row.add_child(rotation_y)

	# Scale
	var scale_row := HBoxContainer.new()
	scale_row.add_theme_constant_override("separation", 8)
	fields_container.add_child(scale_row)
	var scale_label := _make_label("Scale:")
	scale_label.custom_minimum_size.x = 70
	scale_row.add_child(scale_label)
	scale_uniform = SpinBox.new()
	scale_uniform.min_value = 0.1
	scale_uniform.max_value = 5
	scale_uniform.step = 0.1
	scale_uniform.value = 1.0
	scale_uniform.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_uniform.value_changed.connect(_on_scale_changed)
	scale_row.add_child(scale_uniform)

	fields_container.add_child(HSeparator.new())

	# Shop type selector (only visible for shop buildings)
	shop_type_row = HBoxContainer.new()
	shop_type_row.visible = false
	shop_type_row.add_theme_constant_override("separation", 8)
	fields_container.add_child(shop_type_row)
	var shop_label := _make_label("Shop:")
	shop_label.custom_minimum_size.x = 70
	shop_type_row.add_child(shop_label)
	shop_type_option = OptionButton.new()
	shop_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st: Dictionary in SHOP_TYPES:
		shop_type_option.add_item(st["name"])
		shop_type_option.set_item_metadata(shop_type_option.item_count - 1, st["id"])
	shop_type_option.item_selected.connect(_on_shop_type_changed)
	shop_type_row.add_child(shop_type_option)

	fields_container.add_child(HSeparator.new())

	# NPC Section (hidden by default, shown for NPC elements)
	npc_section = VBoxContainer.new()
	npc_section.visible = false
	npc_section.add_theme_constant_override("separation", 4)
	fields_container.add_child(npc_section)

	var npc_header := _make_label("NPC Settings")
	npc_header.add_theme_font_size_override("font_size", 12)
	npc_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	npc_section.add_child(npc_header)

	# NPC ID
	var npc_id_row := HBoxContainer.new()
	npc_section.add_child(npc_id_row)
	var npc_id_label := _make_label("NPC ID:")
	npc_id_label.custom_minimum_size.x = 90
	npc_id_row.add_child(npc_id_label)
	npc_id_edit = LineEdit.new()
	npc_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	npc_id_edit.placeholder_text = "unique_npc_id"
	npc_id_edit.text_changed.connect(_on_npc_id_changed)
	npc_id_row.add_child(npc_id_edit)

	# Is Female checkbox
	var gender_row := HBoxContainer.new()
	npc_section.add_child(gender_row)
	var gender_label := _make_label("Is Female:")
	gender_label.custom_minimum_size.x = 90
	gender_row.add_child(gender_label)
	is_female_check = CheckBox.new()
	is_female_check.toggled.connect(_on_is_female_changed)
	gender_row.add_child(is_female_check)

	# Region ID
	var region_row := HBoxContainer.new()
	npc_section.add_child(region_row)
	var region_label := _make_label("Region:")
	region_label.custom_minimum_size.x = 90
	region_row.add_child(region_label)
	region_id_edit = LineEdit.new()
	region_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	region_id_edit.placeholder_text = "e.g. elder_moor"
	region_id_edit.text_changed.connect(_on_region_id_changed)
	region_row.add_child(region_id_edit)

	npc_section.add_child(HSeparator.new())

	# Merchant Section (shown for merchant NPCs)
	merchant_section = VBoxContainer.new()
	merchant_section.visible = false
	merchant_section.add_theme_constant_override("separation", 4)
	npc_section.add_child(merchant_section)

	var merchant_header := _make_label("Merchant Settings")
	merchant_header.add_theme_font_size_override("font_size", 12)
	merchant_header.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	merchant_section.add_child(merchant_header)

	# Shop Tier
	var tier_row := HBoxContainer.new()
	merchant_section.add_child(tier_row)
	var tier_label := _make_label("Shop Tier:")
	tier_label.custom_minimum_size.x = 90
	tier_row.add_child(tier_label)
	shop_tier_option = OptionButton.new()
	shop_tier_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_tier_option.add_item("Junk")       # 0
	shop_tier_option.add_item("Common")     # 1
	shop_tier_option.add_item("Uncommon")   # 2
	shop_tier_option.add_item("Rare")       # 3
	shop_tier_option.add_item("Epic")       # 4
	shop_tier_option.add_item("Legendary")  # 5
	shop_tier_option.selected = 2  # Default: Uncommon
	shop_tier_option.item_selected.connect(_on_shop_tier_changed)
	tier_row.add_child(shop_tier_option)

	# Buy Multiplier
	var buy_row := HBoxContainer.new()
	merchant_section.add_child(buy_row)
	var buy_label := _make_label("Buy Price:")
	buy_label.custom_minimum_size.x = 90
	buy_row.add_child(buy_label)
	buy_multiplier_spin = SpinBox.new()
	buy_multiplier_spin.min_value = 0.5
	buy_multiplier_spin.max_value = 3.0
	buy_multiplier_spin.step = 0.1
	buy_multiplier_spin.value = 1.0
	buy_multiplier_spin.suffix = "x"
	buy_multiplier_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_multiplier_spin.value_changed.connect(_on_buy_multiplier_changed)
	buy_row.add_child(buy_multiplier_spin)

	# Sell Multiplier
	var sell_row := HBoxContainer.new()
	merchant_section.add_child(sell_row)
	var sell_label := _make_label("Sell Price:")
	sell_label.custom_minimum_size.x = 90
	sell_row.add_child(sell_label)
	sell_multiplier_spin = SpinBox.new()
	sell_multiplier_spin.min_value = 0.1
	sell_multiplier_spin.max_value = 1.0
	sell_multiplier_spin.step = 0.05
	sell_multiplier_spin.value = 0.5
	sell_multiplier_spin.suffix = "x"
	sell_multiplier_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sell_multiplier_spin.value_changed.connect(_on_sell_multiplier_changed)
	sell_row.add_child(sell_multiplier_spin)

	# Use Conversation System
	var convo_row := HBoxContainer.new()
	merchant_section.add_child(convo_row)
	var convo_label := _make_label("Use Topics:")
	convo_label.custom_minimum_size.x = 90
	convo_row.add_child(convo_label)
	use_conversation_check = CheckBox.new()
	use_conversation_check.text = "Topic-based"
	use_conversation_check.toggled.connect(_on_use_conversation_changed)
	convo_row.add_child(use_conversation_check)

	# Quest Assignment Section (shown for quest_giver NPCs)
	_build_quest_section(npc_section)

	fields_container.add_child(HSeparator.new())

	# Delete button
	delete_btn = Button.new()
	delete_btn.text = "Delete Selected"
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	delete_btn.pressed.connect(_on_delete_selected)
	fields_container.add_child(delete_btn)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _connect_signals() -> void:
	if viewport_3d:
		viewport_3d.element_clicked.connect(_on_viewport_clicked)
		viewport_3d.element_placed.connect(_on_element_placed)
		viewport_3d.mouse_moved_on_ground.connect(_on_mouse_moved)


## ============================================================================
## PALETTE SELECTION
## ============================================================================

func _on_building_selected(index: int) -> void:
	_clear_other_selections("building")
	# Get the original building data using stored metadata
	var original_index: int = building_list.get_item_metadata(index)
	var building_data: Dictionary = BUILDINGS[original_index]
	# Set brush AFTER any mode changes to avoid it being cleared
	current_brush = {"type": "building", "data": building_data}
	brush_rotation = 0.0  # Reset rotation when selecting from palette
	is_placing = true
	manipulation_mode = "select"  # Set mode directly without clearing brush
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % building_data["name"])


func _on_npc_selected(index: int) -> void:
	_clear_other_selections("npc")
	var npc_data: Dictionary = NPCS[index]
	current_brush = {"type": "npc", "data": npc_data}
	brush_rotation = 0.0  # Reset rotation when selecting from palette
	is_placing = true
	manipulation_mode = "select"
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % npc_data["name"])


func _on_prop_selected(index: int) -> void:
	_clear_other_selections("prop")
	var prop_data: Dictionary = PROPS[index]
	current_brush = {"type": "prop", "data": prop_data}
	brush_rotation = 0.0  # Reset rotation when selecting from palette
	is_placing = true
	manipulation_mode = "select"
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % prop_data["name"])


func _on_functional_selected(index: int) -> void:
	_clear_other_selections("functional")
	var func_data: Dictionary = FUNCTIONALS[index]
	current_brush = {"type": "functional", "data": func_data}
	brush_rotation = 0.0  # Reset rotation when selecting from palette
	is_placing = true
	manipulation_mode = "select"
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % func_data["name"])


func _on_custom_model_selected(path: String) -> void:
	_clear_other_selections("model")
	current_brush = {"type": "custom_model", "data": {"path": path}}
	brush_rotation = 0.0  # Reset rotation when selecting from palette
	is_placing = true
	manipulation_mode = "select"
	mode_select_btn.button_pressed = false
	mode_move_btn.button_pressed = false
	mode_rotate_btn.button_pressed = false
	_update_ghost_preview()
	_set_status("Click to place: %s" % path.get_file())


func _clear_other_selections(except: String) -> void:
	if except != "building" and building_list:
		building_list.deselect_all()
	if except != "npc" and npc_list:
		npc_list.deselect_all()
	if except != "named_npc" and named_npc_list:
		named_npc_list.deselect_all()
	if except != "prop" and prop_list:
		prop_list.deselect_all()
	if except != "functional" and functional_list:
		functional_list.deselect_all()


## ============================================================================
## VIEWPORT HANDLERS
## ============================================================================

func _on_viewport_clicked(position: Vector3) -> void:
	if is_placing:
		return  # Will be handled by element_placed

	# If we have a picked-up element, place it
	if not picked_up_element_id.is_empty():
		_place_picked_up_element(position)
		return

	# Try to pick up an element at this position
	var clicked_id := _get_element_at(position)
	if not clicked_id.is_empty():
		_pick_up_element(clicked_id)
		return

	# Handle rotate mode for already selected element
	if manipulation_mode == "rotate" and not selected_element_id.is_empty():
		_rotate_selected(45)


## Get element ID at a world position
func _get_element_at(position: Vector3) -> String:
	var best_id: String = ""
	var best_dist: float = 6.0  # Snap radius

	for id: String in placed_elements:
		var node: Node3D = placed_elements[id]
		if not is_instance_valid(node):
			continue
		var dist: float = Vector2(position.x, position.z).distance_to(
			Vector2(node.position.x, node.position.z)
		)
		if dist < best_dist:
			best_dist = dist
			best_id = id

	return best_id


## Pick up an element - it will follow the cursor
func _pick_up_element(elem_id: String) -> void:
	# Verify element exists first
	if not placed_elements.has(elem_id):
		_set_status("Element not found")
		return

	var node: Node3D = placed_elements[elem_id] as Node3D
	if not node or not is_instance_valid(node):
		_set_status("Invalid element")
		return

	# Now safe to set picked up state
	picked_up_element_id = elem_id
	selected_element_id = elem_id

	# Update inspector
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == elem_id:
			_refresh_inspector_for_selection(elem)
			break

	_set_status("Picked up: %s - move mouse and click to place" % node.name)


## Place the picked-up element at position
func _place_picked_up_element(position: Vector3) -> void:
	if picked_up_element_id.is_empty():
		return

	if not placed_elements.has(picked_up_element_id):
		picked_up_element_id = ""
		return

	var node: Node3D = placed_elements[picked_up_element_id] as Node3D
	if node and is_instance_valid(node):
		var snapped: Vector3 = _snap_to_grid(position)
		node.position.x = snapped.x
		node.position.z = snapped.z
		position_x.value = snapped.x
		position_z.value = snapped.z
		_update_element_data_position()
		_set_status("Placed at (%.1f, %.1f) | R/Q=rotate, Del=delete" % [snapped.x, snapped.z])

	picked_up_element_id = ""


## Handle mouse movement - move picked-up element and update ghost preview
func _on_mouse_moved(position: Vector3) -> void:
	# Handle brush placement preview (ghost preview updates)
	if is_placing and not current_brush.is_empty():
		_update_placement_preview(position)
		return

	# Handle picked-up element movement
	if picked_up_element_id.is_empty():
		return

	# Verify element still exists
	if not placed_elements.has(picked_up_element_id):
		picked_up_element_id = ""
		return

	var node: Node3D = placed_elements[picked_up_element_id] as Node3D
	if node and is_instance_valid(node):
		var snapped: Vector3 = _calculate_final_position(position)
		node.position.x = snapped.x
		node.position.z = snapped.z
		# Update inspector live
		position_x.value = snapped.x
		position_z.value = snapped.z


## Update the placement preview (ghost + footprint + validity)
func _update_placement_preview(raw_pos: Vector3) -> void:
	if not viewport_3d:
		return

	var snapped := _calculate_final_position(raw_pos)
	var dims := _get_brush_dimensions()

	# Check if placement is valid
	var is_valid := _check_placement_valid(snapped, dims.x, dims.y)

	# Update ghost validity color
	viewport_3d.set_ghost_validity(is_valid)

	# Update footprint preview (only for buildings)
	if current_brush.get("type", "") == "building":
		viewport_3d.set_footprint_preview(dims.x, dims.y, snapped)
	else:
		viewport_3d.clear_footprint_preview()


func _snap_to_grid(pos: Vector3) -> Vector3:
	if not snap_enabled:
		return pos

	var s: float = snap_size_custom
	return Vector3(
		round(pos.x / s) * s,
		pos.y,
		round(pos.z / s) * s
	)


## Get the current brush dimensions (width, depth) for overlap/footprint
func _get_brush_dimensions() -> Vector2:
	if current_brush.is_empty():
		return Vector2(2.0, 2.0)  # Default for non-buildings

	var brush_data: Dictionary = current_brush.get("data", {})
	var width: float = brush_data.get("width", 2.0)
	var depth: float = brush_data.get("depth", 2.0)
	return Vector2(width, depth)


## Check if placement at position would overlap existing buildings
func _check_placement_valid(pos: Vector3, width: float, depth: float, ignore_id: String = "") -> bool:
	if not overlap_check_enabled:
		return true

	# Only check overlap for buildings
	if current_brush.get("type", "") != "building":
		return true

	# Create AABB for new placement
	var half_w: float = width / 2.0
	var half_d: float = depth / 2.0

	for id: String in placed_elements:
		if id == ignore_id:
			continue

		# Find element data
		var elem: LevelEditorData.PlacedElement = null
		for e: LevelEditorData.PlacedElement in level_data.elements:
			if e.id == id:
				elem = e
				break

		if elem == null:
			continue

		# Only check against buildings
		if elem.element_type != LevelEditorData.ElementType.BUILDING:
			continue

		var elem_w: float = elem.properties.get("width", 4.0)
		var elem_d: float = elem.properties.get("depth", 4.0)
		var elem_half_w: float = elem_w / 2.0
		var elem_half_d: float = elem_d / 2.0

		# Simple AABB overlap check on XZ plane
		var x_overlap: bool = abs(pos.x - elem.position.x) < (half_w + elem_half_w - 0.1)
		var z_overlap: bool = abs(pos.z - elem.position.z) < (half_d + elem_half_d - 0.1)

		if x_overlap and z_overlap:
			return false

	return true


## Snap position to nearest building edge if within threshold
func _snap_to_edge(pos: Vector3, width: float, depth: float) -> Vector3:
	if not edge_snap_enabled:
		return pos

	# Only edge snap for buildings
	if current_brush.get("type", "") != "building":
		return pos

	var best_snap := pos
	var best_dist: float = edge_snap_threshold
	var half_w: float = width / 2.0
	var half_d: float = depth / 2.0

	for id: String in placed_elements:
		var elem: LevelEditorData.PlacedElement = null
		for e: LevelEditorData.PlacedElement in level_data.elements:
			if e.id == id:
				elem = e
				break

		if elem == null or elem.element_type != LevelEditorData.ElementType.BUILDING:
			continue

		var elem_w: float = elem.properties.get("width", 4.0)
		var elem_d: float = elem.properties.get("depth", 4.0)
		var elem_half_w: float = elem_w / 2.0
		var elem_half_d: float = elem_d / 2.0

		# Calculate edge-to-edge snap positions
		var snap_positions: Array[Dictionary] = [
			# Snap my left edge to their right edge (place to the right of them)
			{"pos": Vector3(elem.position.x + elem_half_w + half_w, pos.y, pos.z), "type": "x"},
			# Snap my right edge to their left edge (place to the left of them)
			{"pos": Vector3(elem.position.x - elem_half_w - half_w, pos.y, pos.z), "type": "x"},
			# Snap my front to their back (place behind them)
			{"pos": Vector3(pos.x, pos.y, elem.position.z + elem_half_d + half_d), "type": "z"},
			# Snap my back to their front (place in front of them)
			{"pos": Vector3(pos.x, pos.y, elem.position.z - elem_half_d - half_d), "type": "z"},
		]

		for snap_data: Dictionary in snap_positions:
			var snap_pos: Vector3 = snap_data["pos"]
			var dist: float

			# Calculate distance based on snap axis
			if snap_data["type"] == "x":
				dist = abs(pos.x - snap_pos.x)
			else:
				dist = abs(pos.z - snap_pos.z)

			if dist < best_dist:
				# Also check Z alignment for X snaps and vice versa
				var aligned: bool = false
				if snap_data["type"] == "x":
					aligned = abs(pos.z - elem.position.z) < (half_d + elem_half_d + edge_snap_threshold)
				else:
					aligned = abs(pos.x - elem.position.x) < (half_w + elem_half_w + edge_snap_threshold)

				if aligned:
					best_dist = dist
					best_snap = snap_pos

	return best_snap


## Calculate the final snapped position with all snapping modes applied
func _calculate_final_position(raw_pos: Vector3) -> Vector3:
	var dims := _get_brush_dimensions()

	# First apply grid snap
	var snapped := _snap_to_grid(raw_pos)

	# Then apply edge snap (overrides grid if closer)
	snapped = _snap_to_edge(snapped, dims.x, dims.y)

	return snapped


func _on_element_placed(position: Vector3) -> void:
	if not is_placing or current_brush.is_empty():
		return

	var snapped_position: Vector3 = _calculate_final_position(position)
	var dims := _get_brush_dimensions()

	# Check if placement is valid (overlap check)
	if not _check_placement_valid(snapped_position, dims.x, dims.y):
		_set_status("Cannot place here - overlaps existing building!")
		return

	var element: Dictionary = _create_element(current_brush, snapped_position)
	if not element.is_empty():
		placed_elements[element.id] = element.node
		viewport_3d.add_content(element.node)
		level_data.elements.append(element.data)

		# Auto-select the newly placed element
		selected_element_id = element.id
		_refresh_inspector_for_selection(element.data)

		var elem_name: String = element.data.properties.get("name", "element")
		var rot_info: String = ""
		if brush_rotation != 0.0:
			rot_info = " (rot: %.0f)" % brush_rotation
		_set_status("Placed %s at (%.1f, %.1f)%s | C=copy, R/Q=rotate, Del=delete" % [elem_name, snapped_position.x, snapped_position.z, rot_info])


func _update_element_data_position() -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if not node:
		return
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem.position = node.position
			break


func _create_element(brush: Dictionary, pos: Vector3) -> Dictionary:
	var elem_data := LevelEditorData.PlacedElement.new()
	elem_data.position = pos
	var node: Node3D

	match brush["type"]:
		"building":
			elem_data.element_type = LevelEditorData.ElementType.BUILDING
			elem_data.properties = brush["data"].duplicate()
			# Support both "name" (from brush) and "building_name" (from saved JSON)
			elem_data.properties["name"] = brush["data"].get("name", brush["data"].get("building_name", "Building"))
			node = _create_building_node(brush["data"], pos)

		"npc":
			elem_data.element_type = LevelEditorData.ElementType.NPC
			elem_data.properties = brush["data"].duplicate()
			# Support both "name" (from brush) and "npc_name" (from saved JSON)
			elem_data.properties["name"] = brush["data"].get("name", brush["data"].get("npc_name", "NPC"))
			node = _create_npc_node(brush["data"], pos)

		"prop":
			elem_data.element_type = LevelEditorData.ElementType.PROP
			elem_data.properties = brush["data"].duplicate()
			# Support both "name" (from brush) and "prop_name" (from saved JSON)
			elem_data.properties["name"] = brush["data"].get("name", brush["data"].get("prop_name", "Prop"))
			node = _create_prop_node(brush["data"], pos)

		"functional":
			elem_data.element_type = LevelEditorData.ElementType.FUNCTIONAL
			elem_data.properties = brush["data"].duplicate()
			# Support both "name" (from brush) and "func_name" (from saved JSON)
			elem_data.properties["name"] = brush["data"].get("name", brush["data"].get("func_name", "Functional"))
			node = _create_functional_node(brush["data"], pos)

		"custom_model":
			elem_data.element_type = LevelEditorData.ElementType.CUSTOM_MODEL
			elem_data.properties = {
				"model_path": brush["data"]["path"],
				"scene_path": brush["data"]["path"],
				"name": brush["data"]["path"].get_file()
			}
			node = _create_custom_model_node(brush["data"]["path"], pos)

		"named_npc":
			elem_data.element_type = LevelEditorData.ElementType.NPC
			elem_data.properties = brush["data"].duplicate()
			elem_data.properties["is_named_npc"] = true
			node = _create_named_npc_node(brush["data"], pos)

	if node:
		# Apply brush rotation to the node and element data
		if brush_rotation != 0.0:
			node.rotation_degrees.y = brush_rotation
			elem_data.rotation.y = brush_rotation
		node.set_meta("element_id", elem_data.id)
		return {"id": elem_data.id, "node": node, "data": elem_data}

	return {}


## ============================================================================
## BUILDING CREATION - PS1 Style
## ============================================================================

func _create_building_node(data: Dictionary, pos: Vector3) -> Node3D:
	var building := Node3D.new()
	# Support both "id" (from brush selection) and "building_id" (from saved JSON)
	var building_id: String = data.get("id", data.get("building_id", "building"))
	building.name = building_id + "_" + str(randi() % 1000)
	building.position = pos

	var width: float = data.get("width", 8)
	var height: float = data.get("height", 4)
	var depth: float = data.get("depth", 6)
	var style: String = data.get("style", "timber")

	# Try to load custom model first (GLB or FBX)
	var model_path: String = _find_model_path(BUILDING_MODELS_PATH, building_id)
	if model_path != "":
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "Model"
			building.add_child(model_instance)
			# Add label if enabled
			if show_labels:
				var label := Label3D.new()
				label.name = "BuildingLabel"
				label.text = data.get("name", data.get("building_name", "Building"))
				label.position.y = height + 1.0
				label.font_size = 24
				label.outline_size = 2
				label.modulate = Color(1, 1, 1, 0.9)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				building.add_child(label)
			return building

	# Fall back to CSG placeholder if no model exists
	# Build based on style
	match style:
		"timber":
			_build_timber_house(building, width, height, depth)
		"stone":
			_build_stone_building(building, width, height, depth)
		"wood":
			_build_wood_shack(building, width, height, depth)
		"stall":
			_build_market_stall(building, width, height, depth)
		"forge":
			_build_blacksmith(building, width, height, depth)
		"barn":
			_build_barn(building, width, height, depth)
		"church":
			_build_church(building, width, height, depth)
		"civic":
			_build_civic_building(building, width, height, depth)
		"castle":
			_build_castle_keep(building, width, height, depth)
		"tower":
			_build_tower(building, width, height, depth)
		"wall":
			_build_wall_segment(building, width, height, depth)
		"gate":
			_build_gatehouse(building, width, height, depth)
		"military":
			_build_barracks(building, width, height, depth)
		"well":
			_build_well(building)
		"fountain":
			_build_fountain(building, width, depth)
		"windmill":
			_build_windmill(building, width, height, depth)
		"gallows":
			_build_gallows(building)
		_:
			_build_generic_building(building, width, height, depth)

	# Label (toggle-able via show_labels)
	if show_labels:
		var label := Label3D.new()
		label.name = "BuildingLabel"
		label.text = data.get("name", data.get("building_name", "Building"))
		label.position.y = height + 1.0
		label.font_size = 24
		label.outline_size = 2
		label.modulate = Color(1, 1, 1, 0.9)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		building.add_child(label)

	return building


func _build_timber_house(parent: Node3D, w: float, h: float, d: float) -> void:
	# Stone foundation
	var foundation := CSGBox3D.new()
	foundation.size = Vector3(w + 0.2, 0.4, d + 0.2)
	foundation.position.y = 0.2
	foundation.use_collision = true
	foundation.material = _mat(Color(0.4, 0.38, 0.35))
	parent.add_child(foundation)

	# Main walls (plaster color)
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h - 0.4, d)
	walls.position.y = 0.4 + (h - 0.4) / 2.0
	walls.use_collision = true
	walls.material = _mat(Color(0.82, 0.78, 0.7))
	parent.add_child(walls)

	# Timber beams
	var beam_color := Color(0.32, 0.22, 0.15)
	for i in range(int(w / 3) + 1):
		var beam := CSGBox3D.new()
		beam.size = Vector3(0.12, h - 0.4, d + 0.02)
		beam.position = Vector3(-w/2 + 0.5 + i * (w - 1) / max(1, int(w / 3)), 0.4 + (h - 0.4) / 2.0, 0)
		beam.material = _mat(beam_color)
		parent.add_child(beam)

	# Pitched roof
	var roof_h: float = h * 0.35
	var roof_l := CSGBox3D.new()
	roof_l.size = Vector3(w/2 + 0.5, 0.15, d + 0.5)
	roof_l.position = Vector3(-w/4, h + roof_h/2 - 0.1, 0)
	roof_l.rotation_degrees.z = 30
	roof_l.material = _mat(Color(0.42, 0.26, 0.18))
	parent.add_child(roof_l)

	var roof_r := CSGBox3D.new()
	roof_r.size = Vector3(w/2 + 0.5, 0.15, d + 0.5)
	roof_r.position = Vector3(w/4, h + roof_h/2 - 0.1, 0)
	roof_r.rotation_degrees.z = -30
	roof_r.material = _mat(Color(0.42, 0.26, 0.18))
	parent.add_child(roof_r)


func _build_stone_building(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = true
	walls.material = _mat(Color(0.5, 0.48, 0.45))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.3, 0.25, d + 0.3)
	roof.position.y = h + 0.12
	roof.material = _mat(Color(0.38, 0.36, 0.33))
	parent.add_child(roof)


func _build_wood_shack(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = true
	walls.material = _mat(Color(0.42, 0.32, 0.22))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.4, 0.12, d + 0.4)
	roof.position = Vector3(0, h + 0.25, -0.15)
	roof.rotation_degrees.x = 12
	roof.material = _mat(Color(0.28, 0.22, 0.15))
	parent.add_child(roof)


func _build_market_stall(parent: Node3D, w: float, h: float, d: float) -> void:
	var counter := CSGBox3D.new()
	counter.size = Vector3(w, 0.9, d * 0.5)
	counter.position = Vector3(0, 0.45, d * 0.15)
	counter.use_collision = true
	counter.material = _mat(Color(0.48, 0.38, 0.28))
	parent.add_child(counter)

	for side in [-1, 1]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.15, h, 0.15)
		post.position = Vector3(side * (w/2 - 0.1), h/2, -d/2 + 0.1)
		post.material = _mat(Color(0.38, 0.28, 0.18))
		parent.add_child(post)

	var awning := CSGBox3D.new()
	awning.size = Vector3(w + 0.3, 0.08, d + 0.2)
	awning.position = Vector3(0, h - 0.15, 0)
	awning.rotation_degrees.x = 8
	awning.material = _mat(Color(0.65, 0.18, 0.12))
	parent.add_child(awning)


func _build_blacksmith(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)

	var chimney := CSGBox3D.new()
	chimney.size = Vector3(1.2, h * 0.7, 1.2)
	chimney.position = Vector3(w/3, h + h * 0.35, d/3)
	chimney.material = _mat(Color(0.28, 0.26, 0.23))
	parent.add_child(chimney)


func _build_barn(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = true
	walls.material = _mat(Color(0.48, 0.32, 0.22))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.4, 0.15, d + 0.25)
	roof.position.y = h + 0.4
	roof.material = _mat(Color(0.32, 0.22, 0.15))
	parent.add_child(roof)


func _build_church(parent: Node3D, w: float, h: float, d: float) -> void:
	var nave := CSGBox3D.new()
	nave.size = Vector3(w, h * 0.55, d)
	nave.position.y = h * 0.275
	nave.use_collision = true
	nave.material = _mat(Color(0.58, 0.56, 0.53))
	parent.add_child(nave)

	var roof_l := CSGBox3D.new()
	roof_l.size = Vector3(w/2 + 0.3, 0.15, d + 0.3)
	roof_l.position = Vector3(-w/4, h * 0.65, 0)
	roof_l.rotation_degrees.z = 35
	roof_l.material = _mat(Color(0.32, 0.3, 0.28))
	parent.add_child(roof_l)

	var roof_r := CSGBox3D.new()
	roof_r.size = Vector3(w/2 + 0.3, 0.15, d + 0.3)
	roof_r.position = Vector3(w/4, h * 0.65, 0)
	roof_r.rotation_degrees.z = -35
	roof_r.material = _mat(Color(0.32, 0.3, 0.28))
	parent.add_child(roof_r)

	var tower := CSGBox3D.new()
	tower.size = Vector3(w * 0.3, h * 0.8, w * 0.3)
	tower.position = Vector3(0, h * 0.4, -d/2 + w * 0.15)
	tower.material = _mat(Color(0.58, 0.56, 0.53))
	parent.add_child(tower)

	var steeple := CSGCylinder3D.new()
	steeple.radius = w * 0.18
	steeple.height = h * 0.35
	steeple.sides = 4
	steeple.position = Vector3(0, h * 0.8 + h * 0.175, -d/2 + w * 0.15)
	steeple.material = _mat(Color(0.32, 0.3, 0.28))
	parent.add_child(steeple)


func _build_civic_building(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)

	var porch := CSGBox3D.new()
	porch.size = Vector3(w * 0.7, 0.25, 2.5)
	porch.position = Vector3(0, 0.12, -d/2 - 1.25)
	porch.material = _mat(Color(0.52, 0.5, 0.47))
	parent.add_child(porch)

	for i in range(3):
		var col := CSGCylinder3D.new()
		col.radius = 0.25
		col.height = h * 0.75
		col.position = Vector3(-w * 0.25 + i * w * 0.25, h * 0.375, -d/2 - 1.25)
		col.material = _mat(Color(0.68, 0.65, 0.62))
		parent.add_child(col)


func _build_castle_keep(parent: Node3D, w: float, h: float, d: float) -> void:
	var base := CSGBox3D.new()
	base.size = Vector3(w, h * 0.7, d)
	base.position.y = h * 0.35
	base.use_collision = true
	base.material = _mat(Color(0.45, 0.43, 0.4))
	parent.add_child(base)

	# Corner towers
	for x in [-1, 1]:
		for z in [-1, 1]:
			var tower := CSGCylinder3D.new()
			tower.radius = w * 0.12
			tower.height = h
			tower.position = Vector3(x * w/2 * 0.9, h/2, z * d/2 * 0.9)
			tower.material = _mat(Color(0.45, 0.43, 0.4))
			parent.add_child(tower)

	# Crenellations
	var top := CSGBox3D.new()
	top.size = Vector3(w + 0.3, 0.4, d + 0.3)
	top.position.y = h * 0.7 + 0.2
	top.material = _mat(Color(0.42, 0.4, 0.37))
	parent.add_child(top)


func _build_tower(parent: Node3D, w: float, h: float, d: float) -> void:
	var body := CSGBox3D.new()
	body.size = Vector3(w, h * 0.85, d)
	body.position.y = h * 0.425
	body.use_collision = true
	body.material = _mat(Color(0.48, 0.46, 0.43))
	parent.add_child(body)

	var top := CSGBox3D.new()
	top.size = Vector3(w + 0.3, 0.4, d + 0.3)
	top.position.y = h * 0.85 + 0.2
	top.material = _mat(Color(0.43, 0.41, 0.38))
	parent.add_child(top)

	# Merlons
	for i in range(2):
		for j in range(2):
			var merlon := CSGBox3D.new()
			merlon.size = Vector3(w/2.5, 0.5, d/2.5)
			merlon.position = Vector3(-w/4 + i * w/2, h * 0.85 + 0.65, -d/4 + j * d/2)
			merlon.material = _mat(Color(0.43, 0.41, 0.38))
			parent.add_child(merlon)


func _build_wall_segment(parent: Node3D, w: float, h: float, d: float) -> void:
	var wall := CSGBox3D.new()
	wall.size = Vector3(w, h, d)
	wall.position.y = h / 2.0
	wall.use_collision = true
	wall.material = _mat(Color(0.48, 0.46, 0.43))
	parent.add_child(wall)

	var walkway := CSGBox3D.new()
	walkway.size = Vector3(w, 0.15, d + 0.8)
	walkway.position.y = h + 0.07
	walkway.material = _mat(Color(0.43, 0.41, 0.38))
	parent.add_child(walkway)


func _build_gatehouse(parent: Node3D, w: float, h: float, d: float) -> void:
	var tower_w: float = w * 0.32
	for side in [-1, 1]:
		var tower := CSGBox3D.new()
		tower.size = Vector3(tower_w, h, d)
		tower.position = Vector3(side * (w/2 - tower_w/2), h/2, 0)
		tower.use_collision = true
		tower.material = _mat(Color(0.48, 0.46, 0.43))
		parent.add_child(tower)

	var arch := CSGBox3D.new()
	arch.size = Vector3(w - tower_w * 2 + 0.3, h * 0.25, d)
	arch.position = Vector3(0, h - h * 0.125, 0)
	arch.material = _mat(Color(0.48, 0.46, 0.43))
	parent.add_child(arch)


func _build_barracks(parent: Node3D, w: float, h: float, d: float) -> void:
	_build_stone_building(parent, w, h, d)


func _build_well(parent: Node3D) -> void:
	var base := CSGCylinder3D.new()
	base.radius = 0.9
	base.height = 0.7
	base.position.y = 0.35
	base.use_collision = true
	base.material = _mat(Color(0.43, 0.41, 0.38))
	parent.add_child(base)

	var hole := CSGCylinder3D.new()
	hole.radius = 0.6
	hole.height = 0.4
	hole.position.y = 0.55
	hole.material = _mat(Color(0.08, 0.08, 0.1))
	parent.add_child(hole)

	for side in [-1, 1]:
		var post := CSGBox3D.new()
		post.size = Vector3(0.12, 1.8, 0.12)
		post.position = Vector3(side * 0.7, 0.9, 0)
		post.material = _mat(Color(0.38, 0.28, 0.18))
		parent.add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(1.8, 0.12, 0.15)
	beam.position.y = 1.8
	beam.material = _mat(Color(0.38, 0.28, 0.18))
	parent.add_child(beam)


func _build_fountain(parent: Node3D, w: float, d: float) -> void:
	var basin := CSGCylinder3D.new()
	basin.radius = w / 2
	basin.height = 0.5
	basin.position.y = 0.25
	basin.use_collision = true
	basin.material = _mat(Color(0.48, 0.46, 0.43))
	parent.add_child(basin)

	var water := CSGCylinder3D.new()
	water.radius = w / 2 - 0.15
	water.height = 0.25
	water.position.y = 0.4
	water.material = _mat(Color(0.28, 0.48, 0.65, 0.8))
	parent.add_child(water)

	var pillar := CSGCylinder3D.new()
	pillar.radius = 0.25
	pillar.height = 1.3
	pillar.position.y = 0.65
	pillar.material = _mat(Color(0.52, 0.5, 0.47))
	parent.add_child(pillar)


func _build_windmill(parent: Node3D, w: float, h: float, d: float) -> void:
	var body := CSGCylinder3D.new()
	body.radius = w / 2
	body.height = h * 0.75
	body.position.y = h * 0.375
	body.use_collision = true
	body.material = _mat(Color(0.68, 0.63, 0.58))
	parent.add_child(body)

	var cap := CSGCylinder3D.new()
	cap.radius = w / 2 + 0.15
	cap.height = h * 0.12
	cap.position.y = h * 0.75 + h * 0.06
	cap.material = _mat(Color(0.38, 0.33, 0.28))
	parent.add_child(cap)

	var hub := CSGBox3D.new()
	hub.size = Vector3(0.35, 0.35, 0.5)
	hub.position = Vector3(0, h * 0.65, -w/2 - 0.25)
	hub.material = _mat(Color(0.38, 0.28, 0.18))
	parent.add_child(hub)

	for i in range(4):
		var sail := CSGBox3D.new()
		sail.size = Vector3(0.25, h * 0.45, 0.08)
		sail.position = Vector3(0, h * 0.65, -w/2 - 0.4)
		sail.rotation_degrees.z = i * 90
		sail.material = _mat(Color(0.78, 0.73, 0.68))
		parent.add_child(sail)


func _build_gallows(parent: Node3D) -> void:
	var base := CSGBox3D.new()
	base.size = Vector3(3, 1.5, 2)
	base.position.y = 0.75
	base.use_collision = true
	base.material = _mat(Color(0.38, 0.28, 0.18))
	parent.add_child(base)

	var post := CSGBox3D.new()
	post.size = Vector3(0.2, 3.5, 0.2)
	post.position = Vector3(-1, 1.5 + 1.75, 0)
	post.material = _mat(Color(0.32, 0.22, 0.15))
	parent.add_child(post)

	var beam := CSGBox3D.new()
	beam.size = Vector3(2, 0.15, 0.15)
	beam.position = Vector3(0, 5, 0)
	beam.material = _mat(Color(0.32, 0.22, 0.15))
	parent.add_child(beam)


func _build_generic_building(parent: Node3D, w: float, h: float, d: float) -> void:
	var walls := CSGBox3D.new()
	walls.size = Vector3(w, h, d)
	walls.position.y = h / 2.0
	walls.use_collision = true
	walls.material = _mat(Color(0.58, 0.53, 0.48))
	parent.add_child(walls)

	var roof := CSGBox3D.new()
	roof.size = Vector3(w + 0.3, 0.25, d + 0.3)
	roof.position.y = h + 0.12
	roof.material = _mat(Color(0.38, 0.33, 0.28))
	parent.add_child(roof)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return mat


## ============================================================================
## NPC, PROP, FUNCTIONAL CREATION
## ============================================================================

func _create_npc_node(data: Dictionary, pos: Vector3) -> Node3D:
	var npc := Node3D.new()
	# Support both "id" (from brush selection) and "npc_id" (from saved JSON)
	var npc_id: String = data.get("id", data.get("npc_id", "npc"))
	npc.name = npc_id + "_" + str(randi() % 1000)
	npc.position = pos

	var body := CSGCylinder3D.new()
	body.radius = 0.35
	body.height = 1.8
	body.position.y = 0.9

	var mat := StandardMaterial3D.new()
	match npc_id:
		"guard", "guard_captain":
			mat.albedo_color = Color(0.28, 0.32, 0.48)
		"merchant_general", "merchant_weapons", "merchant_armor", "merchant_magic":
			mat.albedo_color = Color(0.58, 0.48, 0.28)
		"priest":
			mat.albedo_color = Color(0.8, 0.78, 0.7)
		"noble":
			mat.albedo_color = Color(0.5, 0.2, 0.5)
		_:
			mat.albedo_color = Color(0.48, 0.38, 0.32)
	body.material = mat
	npc.add_child(body)

	var head := CSGSphere3D.new()
	head.radius = 0.25
	head.position.y = 2.0
	head.material = mat
	npc.add_child(head)

	if show_labels:
		var label := Label3D.new()
		label.name = "BuildingLabel"
		label.text = data.get("name", data.get("npc_name", "NPC"))
		label.position.y = 2.5
		label.font_size = 20
		label.outline_size = 2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		npc.add_child(label)

	return npc


## Create a visual placeholder for Named NPCs (from data/npcs/)
func _create_named_npc_node(data: Dictionary, pos: Vector3) -> Node3D:
	var npc := Node3D.new()
	var npc_id: String = data.get("npc_id", "named_npc")
	npc.name = npc_id + "_" + str(randi() % 1000)
	npc.position = pos

	var body := CSGCylinder3D.new()
	body.radius = 0.35
	body.height = 1.8
	body.position.y = 0.9

	# Color based on archetype
	var mat := StandardMaterial3D.new()
	var archetype: String = data.get("archetype", "civilian")
	match archetype:
		"quest_giver":
			mat.albedo_color = Color(0.8, 0.6, 0.2)  # Gold for quest givers
		"merchant":
			mat.albedo_color = Color(0.58, 0.48, 0.28)
		"guard":
			mat.albedo_color = Color(0.28, 0.32, 0.48)
		"priest":
			mat.albedo_color = Color(0.8, 0.78, 0.7)
		"noble":
			mat.albedo_color = Color(0.5, 0.2, 0.5)
		_:
			mat.albedo_color = Color(0.48, 0.38, 0.32)
	body.material = mat
	npc.add_child(body)

	var head := CSGSphere3D.new()
	head.radius = 0.25
	head.position.y = 2.0
	head.material = mat
	npc.add_child(head)

	# Add exclamation mark for quest givers
	if archetype == "quest_giver":
		var marker := CSGBox3D.new()
		marker.size = Vector3(0.15, 0.4, 0.15)
		marker.position.y = 2.6
		var marker_mat := StandardMaterial3D.new()
		marker_mat.albedo_color = Color(1.0, 0.9, 0.0)  # Bright yellow
		marker_mat.emission_enabled = true
		marker_mat.emission = Color(1.0, 0.8, 0.0)
		marker.material = marker_mat
		npc.add_child(marker)

	if show_labels:
		var label := Label3D.new()
		label.name = "BuildingLabel"
		label.text = data.get("display_name", data.get("name", "Named NPC"))
		label.position.y = 3.0 if archetype == "quest_giver" else 2.5
		label.font_size = 20
		label.outline_size = 2
		label.modulate = Color(1.0, 0.9, 0.6) if archetype == "quest_giver" else Color(1, 1, 1)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		npc.add_child(label)

	return npc


func _create_prop_node(data: Dictionary, pos: Vector3) -> Node3D:
	var prop := Node3D.new()
	# Support both "id" (from brush selection) and "prop_id" (from saved JSON)
	var prop_id: String = data.get("id", data.get("prop_id", "prop"))
	prop.name = prop_id + "_" + str(randi() % 1000)
	prop.position = pos

	# Try to load custom model first (GLB or FBX)
	var model_path: String = _find_model_path(PROP_MODELS_PATH, prop_id)
	if model_path != "":
		var model_scene: PackedScene = load(model_path)
		if model_scene:
			var model_instance: Node3D = model_scene.instantiate()
			model_instance.name = "Model"
			prop.add_child(model_instance)
			return prop

	# Fall back to CSG placeholder if no model exists
	var mesh: CSGShape3D

	match prop_id:
		"barrel":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.35
			(mesh as CSGCylinder3D).height = 0.9
			mesh.position.y = 0.45
		"crate", "crate_stack":
			mesh = CSGBox3D.new()
			var h: float = 0.7 if prop_id == "crate" else 1.4
			(mesh as CSGBox3D).size = Vector3(0.7, h, 0.7)
			mesh.position.y = h / 2
		"bench":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(1.8, 0.45, 0.5)
			mesh.position.y = 0.22
		"torch_wall", "torch_standing":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.08
			(mesh as CSGCylinder3D).height = 2.2
			mesh.position.y = 1.1
		"table":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(1.2, 0.1, 0.8)
			mesh.position.y = 0.75
		"chair":
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(0.45, 0.45, 0.45)
			mesh.position.y = 0.22
		"tree_oak", "tree_pine":
			mesh = CSGCylinder3D.new()
			(mesh as CSGCylinder3D).radius = 0.3
			(mesh as CSGCylinder3D).height = 4.0
			mesh.position.y = 2.0
		_:
			mesh = CSGBox3D.new()
			(mesh as CSGBox3D).size = Vector3(0.8, 0.8, 0.8)
			mesh.position.y = 0.4

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.43, 0.33, 0.23)
	mesh.material = mat
	mesh.use_collision = true
	prop.add_child(mesh)

	return prop


func _create_functional_node(data: Dictionary, pos: Vector3) -> Node3D:
	var func_node := Node3D.new()
	# Support both "id" (from brush selection) and "func_type" (from saved JSON)
	var func_id: String = data.get("id", data.get("func_type", "unknown"))
	func_node.name = func_id + "_" + str(randi() % 1000)
	func_node.position = pos

	var marker: CSGShape3D

	match func_id:
		"spawn_point":
			marker = CSGSphere3D.new()
			(marker as CSGSphere3D).radius = 0.45
			marker.position.y = 0.45
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.2, 0.75, 0.2, 0.65)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			marker.material = mat
		"fast_travel_shrine":
			marker = CSGCylinder3D.new()
			(marker as CSGCylinder3D).radius = 0.45
			(marker as CSGCylinder3D).height = 2.5
			marker.position.y = 1.25
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.35, 0.55, 0.95)
			mat.emission_enabled = true
			mat.emission = Color(0.25, 0.45, 0.95)
			marker.material = mat
		"door_zone", "door_interior":
			marker = CSGBox3D.new()
			(marker as CSGBox3D).size = Vector3(1.8, 2.8, 0.25)
			marker.position.y = 1.4
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.38, 0.28, 0.18)
			marker.material = mat
		"chest_common", "chest_rare", "chest_locked":
			marker = CSGBox3D.new()
			(marker as CSGBox3D).size = Vector3(0.8, 0.5, 0.5)
			marker.position.y = 0.25
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.55, 0.42, 0.25)
			marker.material = mat
		_:
			marker = CSGBox3D.new()
			(marker as CSGBox3D).size = Vector3(0.9, 0.9, 0.9)
			marker.position.y = 0.45
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.65, 0.65, 0.28)
			marker.material = mat

	func_node.add_child(marker)

	if show_labels:
		var label := Label3D.new()
		label.name = "BuildingLabel"
		label.text = data.get("name", data.get("func_name", "Functional"))
		label.position.y = 3.0
		label.font_size = 20
		label.outline_size = 2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		func_node.add_child(label)

	return func_node


func _create_custom_model_node(path: String, pos: Vector3, properties: Dictionary = {}) -> Node3D:
	var container := Node3D.new()
	container.name = "Model_" + path.get_file().get_basename()
	container.position = pos

	var loaded := load(path)
	if loaded:
		var instance: Node3D
		if loaded is PackedScene:
			instance = loaded.instantiate()
		else:
			push_error("Unsupported model format: %s" % path)
			return container

		if instance:
			# Apply PS1 texture filtering to all materials
			_apply_ps1_filtering(instance)

			# Generate collision if needed
			var collision_mode: int = properties.get("collision_mode", LevelEditorData.CollisionMode.AUTO)
			_apply_collision_mode(instance, collision_mode)

			container.add_child(instance)

	return container


## Apply PS1-style nearest-neighbor texture filtering to all materials
func _apply_ps1_filtering(node: Node3D) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mesh_inst: MeshInstance3D = child
			# Process surface override materials
			for i: int in range(mesh_inst.get_surface_override_material_count()):
				var mat: Material = mesh_inst.get_surface_override_material(i)
				if mat is BaseMaterial3D:
					var base_mat: BaseMaterial3D = mat
					base_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			# Also check mesh surface materials
			if mesh_inst.mesh:
				for i: int in range(mesh_inst.mesh.get_surface_count()):
					var mat: Material = mesh_inst.mesh.surface_get_material(i)
					if mat is BaseMaterial3D:
						var base_mat: BaseMaterial3D = mat.duplicate()
						base_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
						mesh_inst.set_surface_override_material(i, base_mat)
		if child is Node3D:
			_apply_ps1_filtering(child)


## Apply collision based on mode
func _apply_collision_mode(node: Node3D, mode: int) -> void:
	match mode:
		LevelEditorData.CollisionMode.TRIMESH:
			for child in node.get_children():
				if child is MeshInstance3D:
					child.create_trimesh_collision()
				if child is Node3D:
					_apply_collision_mode(child, mode)
		LevelEditorData.CollisionMode.CONVEX:
			for child in node.get_children():
				if child is MeshInstance3D:
					child.create_convex_collision()
				if child is Node3D:
					_apply_collision_mode(child, mode)
		# AUTO and NONE: do nothing extra (use existing collision if present)


func _update_ghost_preview() -> void:
	if not viewport_3d:
		return

	if current_brush.is_empty():
		viewport_3d.clear_ghost_preview()
		return

	var ghost: Node3D

	match current_brush["type"]:
		"building":
			ghost = _create_building_node(current_brush["data"], Vector3.ZERO)
		"npc":
			ghost = _create_npc_node(current_brush["data"], Vector3.ZERO)
		"named_npc":
			ghost = _create_named_npc_node(current_brush["data"], Vector3.ZERO)
		"prop":
			ghost = _create_prop_node(current_brush["data"], Vector3.ZERO)
		"functional":
			ghost = _create_functional_node(current_brush["data"], Vector3.ZERO)
		"custom_model":
			ghost = _create_custom_model_node(current_brush["data"]["path"], Vector3.ZERO)

	if ghost:
		# Apply brush rotation to ghost preview so user sees the rotated preview
		if brush_rotation != 0.0:
			ghost.rotation_degrees.y = brush_rotation
		viewport_3d.set_ghost_preview(ghost)
		ghost.queue_free()


## ============================================================================
## SELECTION & INSPECTOR
## ============================================================================

func _try_select_at(position: Vector3) -> void:
	var best_id: String = ""
	var best_dist: float = INF
	var snap_radius: float = 6.0

	for id: String in placed_elements:
		var node: Node3D = placed_elements[id]
		if not is_instance_valid(node):
			continue
		var dist: float = position.distance_to(node.global_position)
		if dist < snap_radius and dist < best_dist:
			best_dist = dist
			best_id = id

	if best_id.is_empty():
		selected_element_id = ""
		_refresh_inspector_for_selection(null)
		return

	selected_element_id = best_id
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == best_id:
			_refresh_inspector_for_selection(elem)
			return


func _refresh_inspector_for_selection(elem: Variant) -> void:
	if elem == null or not (elem is LevelEditorData.PlacedElement):
		name_edit.text = ""
		position_x.value = 0
		position_y.value = 0
		position_z.value = 0
		rotation_y.value = 0
		scale_uniform.value = 1.0
		shop_type_row.visible = false
		npc_section.visible = false
		merchant_section.visible = false
		if quest_section:
			quest_section.visible = false
		_set_status("No element selected")
		return

	name_edit.text = elem.properties.get("name", "")
	position_x.value = elem.position.x
	position_y.value = elem.position.y
	position_z.value = elem.position.z
	rotation_y.value = elem.rotation.y
	scale_uniform.value = elem.scale.x

	# Show shop type selector for shop buildings
	var is_shop: bool = elem.properties.get("is_shop", false)
	shop_type_row.visible = is_shop
	if is_shop:
		var current_shop_type: String = elem.properties.get("shop_type", "")
		for i: int in range(shop_type_option.item_count):
			if shop_type_option.get_item_metadata(i) == current_shop_type:
				shop_type_option.select(i)
				break

	# Show NPC section for NPC elements
	var is_npc: bool = elem.element_type == LevelEditorData.ElementType.NPC
	npc_section.visible = is_npc

	if is_npc:
		npc_id_edit.text = elem.properties.get("npc_id", elem.properties.get("id", ""))
		is_female_check.button_pressed = elem.properties.get("is_female", false)
		region_id_edit.text = elem.properties.get("region_id", "")

		# Show merchant section for merchant NPCs
		var npc_id: String = elem.properties.get("id", "")
		var shop_type: String = elem.properties.get("shop_type", "")
		var is_merchant: bool = npc_id.begins_with("merchant") or not shop_type.is_empty()
		merchant_section.visible = is_merchant

		if is_merchant:
			shop_tier_option.selected = elem.properties.get("shop_tier", 2)
			buy_multiplier_spin.value = elem.properties.get("buy_price_multiplier", 1.0)
			sell_multiplier_spin.value = elem.properties.get("sell_price_multiplier", 0.5)
			use_conversation_check.button_pressed = elem.properties.get("use_conversation_system", false)

		# Show quest section for quest_giver NPCs (Named NPCs or generic quest_giver)
		var archetype: String = elem.properties.get("archetype", "")
		var is_quest_giver: bool = (archetype == "quest_giver") or (npc_id == "quest_giver")
		if quest_section:
			quest_section.visible = is_quest_giver
			if is_quest_giver:
				var current_npc_id: String = elem.properties.get("npc_id", "")
				var current_quest_ids: Array = elem.properties.get("quest_ids", [])
				_refresh_quest_list_for_npc(current_npc_id, current_quest_ids)
	else:
		merchant_section.visible = false
		if quest_section:
			quest_section.visible = false

	_set_status("Selected: %s | R/Q=rotate, Del=delete, Esc=deselect" % elem.properties.get("name", elem.id))


func _on_name_changed(new_name: String) -> void:
	if selected_element_id.is_empty():
		return
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem.properties["name"] = new_name
			break


func _on_position_changed(_value: float) -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if node:
		node.position = Vector3(position_x.value, position_y.value, position_z.value)
		_update_element_data_position()


func _on_rotation_changed(value: float) -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if node:
		node.rotation_degrees.y = value
		for elem: LevelEditorData.PlacedElement in level_data.elements:
			if elem.id == selected_element_id:
				elem.rotation.y = value
				break


func _on_scale_changed(value: float) -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if node:
		node.scale = Vector3.ONE * value
		for elem: LevelEditorData.PlacedElement in level_data.elements:
			if elem.id == selected_element_id:
				elem.scale = Vector3.ONE * value
				break


func _on_shop_type_changed(index: int) -> void:
	if selected_element_id.is_empty():
		return
	var shop_type: String = shop_type_option.get_item_metadata(index)
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem.properties["shop_type"] = shop_type
			# Find the NPC type for this shop
			for st: Dictionary in SHOP_TYPES:
				if st["id"] == shop_type:
					elem.properties["merchant_npc_type"] = st["npc_type"]
					break
			break
	_set_status("Set shop type: %s" % SHOP_TYPES[index]["name"])


## NPC property change handlers
func _on_npc_id_changed(new_text: String) -> void:
	_update_selected_property("npc_id", new_text)


func _on_is_female_changed(pressed: bool) -> void:
	_update_selected_property("is_female", pressed)


func _on_region_id_changed(new_text: String) -> void:
	_update_selected_property("region_id", new_text)


func _on_shop_tier_changed(index: int) -> void:
	_update_selected_property("shop_tier", index)


func _on_buy_multiplier_changed(value: float) -> void:
	_update_selected_property("buy_price_multiplier", value)


func _on_sell_multiplier_changed(value: float) -> void:
	_update_selected_property("sell_price_multiplier", value)


func _on_use_conversation_changed(pressed: bool) -> void:
	_update_selected_property("use_conversation_system", pressed)


## Helper to update a property on the selected element
func _update_selected_property(key: String, value: Variant) -> void:
	if selected_element_id.is_empty():
		return
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		if elem.id == selected_element_id:
			elem.properties[key] = value
			break


func _on_delete_selected() -> void:
	if selected_element_id.is_empty():
		return
	var node: Node3D = placed_elements.get(selected_element_id)
	if node:
		node.queue_free()
		placed_elements.erase(selected_element_id)
		for i in range(level_data.elements.size() - 1, -1, -1):
			if level_data.elements[i].id == selected_element_id:
				level_data.elements.remove_at(i)
				break
		selected_element_id = ""
		_refresh_inspector_for_selection(null)
		_set_status("Element deleted")


## ============================================================================
## TOOLBAR HANDLERS
## ============================================================================

func _on_labels_toggled(pressed: bool) -> void:
	show_labels = pressed
	for id: String in placed_elements:
		var node: Node3D = placed_elements[id]
		if is_instance_valid(node):
			var label := node.get_node_or_null("BuildingLabel")
			if label:
				label.visible = show_labels
	_set_status("Labels %s" % ("shown" if show_labels else "hidden"))


func _on_new_pressed() -> void:
	_clear_all()
	current_scene_path = ""
	level_data = LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	_set_status("New town created")


func _on_open_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.json", "Town Layout")
	dialog.file_selected.connect(func(path: String) -> void:
		load_layout(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_save_pressed() -> void:
	if current_scene_path.is_empty():
		_on_save_as_pressed()
	else:
		save_layout(current_scene_path)


func _on_save_as_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.json", "Town Layout")
	dialog.file_selected.connect(func(path: String) -> void:
		save_layout(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_export_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tscn", "Godot Scene")
	dialog.file_selected.connect(func(path: String) -> void:
		export_scene(path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _on_clear_pressed() -> void:
	_clear_all()
	_set_status("All elements cleared")


func _clear_all() -> void:
	print("[TownEditor] _clear_all() called")
	print("[TownEditor] placed_elements count before: %d" % placed_elements.size())

	selected_element_id = ""
	picked_up_element_id = ""

	# Clear viewport content first - this is the authoritative source for 3D nodes
	# This prevents double-free issues since placed_elements references the same nodes
	if viewport_3d:
		var child_count_before: int = viewport_3d.content_root.get_child_count() if viewport_3d.content_root else 0
		print("[TownEditor] viewport content_root children before clear: %d" % child_count_before)
		viewport_3d.clear_content()
		var child_count_after: int = viewport_3d.content_root.get_child_count() if viewport_3d.content_root else 0
		print("[TownEditor] viewport content_root children after clear: %d" % child_count_after)
	else:
		print("[TownEditor] WARNING: viewport_3d is null!")

	# Now clear tracking data (nodes already freed above)
	placed_elements.clear()
	level_data.elements.clear()
	print("[TownEditor] _clear_all() complete")


## ============================================================================
## SAVE / LOAD / EXPORT
## ============================================================================

func save_layout(path: String) -> void:
	var json_str := level_data.to_json()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		current_scene_path = path
		_set_status("Saved: %s" % path)
		town_saved.emit(path)
	else:
		_set_status("ERROR: Failed to save!")


func load_layout(path: String) -> void:
	print("[TownEditor] load_layout() called with: %s" % path)

	if not FileAccess.file_exists(path):
		_set_status("ERROR: File not found!")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		_set_status("ERROR: Failed to open file!")
		return

	var json_str := file.get_as_text()
	file.close()

	var loaded := LevelEditorData.LevelData.from_json(json_str)
	if not loaded:
		_set_status("ERROR: Invalid layout file!")
		return

	print("[TownEditor] JSON parsed. Elements to load: %d" % loaded.elements.size())

	_clear_all()

	level_data = loaded
	current_scene_path = path

	# Rebuild elements
	var elements_added: int = 0
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		var brush: Dictionary = {"type": "", "data": elem.properties}
		match elem.element_type:
			LevelEditorData.ElementType.BUILDING:
				brush["type"] = "building"
			LevelEditorData.ElementType.NPC:
				brush["type"] = "npc"
			LevelEditorData.ElementType.PROP:
				brush["type"] = "prop"
			LevelEditorData.ElementType.FUNCTIONAL:
				brush["type"] = "functional"
			LevelEditorData.ElementType.CUSTOM_MODEL:
				brush["type"] = "custom_model"
				brush["data"] = {"path": elem.properties.get("model_path", "")}

		var result: Dictionary = _create_element(brush, elem.position)
		if not result.is_empty():
			result.node.rotation_degrees = elem.rotation
			result.node.scale = elem.scale
			placed_elements[elem.id] = result.node
			viewport_3d.add_content(result.node)
			elements_added += 1

	print("[TownEditor] Elements added: %d, placed_elements: %d, content_root children: %d" % [
		elements_added,
		placed_elements.size(),
		viewport_3d.content_root.get_child_count() if viewport_3d and viewport_3d.content_root else 0
	])

	# Update settlement type dropdown
	_select_settlement_type(level_data.settlement_type)

	_set_status("Loaded: %s (%d elements)" % [path, level_data.elements.size()])


func export_scene(path: String) -> void:
	var root := Node3D.new()
	root.name = level_data.level_name if level_data.level_name else "Town"

	# Attach TownSpawner script to root
	var spawner_script = load("res://scripts/levels/town_spawner.gd")
	if spawner_script:
		root.set_script(spawner_script)
		root.set("zone_id", level_data.level_id if level_data.level_id else level_data.level_name.to_snake_case())
		root.set("settlement_type", level_data.settlement_type)
		root.set("region_id", level_data.metadata.get("region_id", "the_greenwood"))

	# Ground
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	var gs: float = float(level_data.grid_size.x)
	ground.size = Vector3(gs, 1, gs)
	ground.position.y = -0.5
	ground.use_collision = true
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.33, 0.28, 0.23)
	ground.material = ground_mat
	root.add_child(ground)
	ground.owner = root

	# Containers for spawn system
	var buildings_container := Node3D.new()
	buildings_container.name = "Buildings"
	root.add_child(buildings_container)
	buildings_container.owner = root

	var npc_spawns := Node3D.new()
	npc_spawns.name = "NPCSpawns"
	root.add_child(npc_spawns)
	npc_spawns.owner = root

	var prop_spawns := Node3D.new()
	prop_spawns.name = "PropSpawns"
	root.add_child(prop_spawns)
	prop_spawns.owner = root

	var functional_spawns := Node3D.new()
	functional_spawns.name = "FunctionalSpawns"
	root.add_child(functional_spawns)
	functional_spawns.owner = root

	# Export elements
	for elem: LevelEditorData.PlacedElement in level_data.elements:
		var id: String = elem.id
		var node: Node3D = placed_elements.get(id)
		if not is_instance_valid(node):
			continue

		match elem.element_type:
			LevelEditorData.ElementType.BUILDING:
				# Buildings keep CSG geometry
				var copy := node.duplicate()
				buildings_container.add_child(copy)
				copy.owner = root
				_set_owner_recursive(copy, root)

				# If this is a shop, create an NPC spawn marker
				var shop_type: String = elem.properties.get("shop_type", "")
				var npc_type: String = elem.properties.get("merchant_npc_type", "")
				if shop_type and npc_type:
					var npc_marker := _create_npc_spawn_marker(elem, npc_type, shop_type)
					npc_spawns.add_child(npc_marker)
					npc_marker.owner = root

			LevelEditorData.ElementType.NPC:
				# NPCs export as Marker3D with spawn metadata
				var npc_marker := _create_npc_spawn_marker(elem, elem.properties.get("id", "civilian_male"), "")
				npc_spawns.add_child(npc_marker)
				npc_marker.owner = root

			LevelEditorData.ElementType.PROP:
				# Check if prop is spawnable or static
				var prop_data := _get_prop_data(elem.properties.get("id", ""))
				if prop_data.get("spawnable", false):
					# Spawnable props export as Marker3D
					var prop_marker := _create_prop_spawn_marker(elem)
					prop_spawns.add_child(prop_marker)
					prop_marker.owner = root
				else:
					# Static decorative props keep CSG geometry in buildings
					var copy := node.duplicate()
					buildings_container.add_child(copy)
					copy.owner = root
					_set_owner_recursive(copy, root)

			LevelEditorData.ElementType.FUNCTIONAL:
				# Functionals export as Marker3D with metadata
				var func_marker := _create_functional_spawn_marker(elem)
				functional_spawns.add_child(func_marker)
				func_marker.owner = root

			LevelEditorData.ElementType.CUSTOM_MODEL:
				# Custom models keep their geometry
				var copy := node.duplicate()
				buildings_container.add_child(copy)
				copy.owner = root
				_set_owner_recursive(copy, root)

	# Save scene
	var scene := PackedScene.new()
	var result := scene.pack(root)
	if result == OK:
		var save_result := ResourceSaver.save(scene, path)
		if save_result == OK:
			town_saved.emit(path)

			# Auto-save matching JSON layout file
			var json_path: String = path.get_basename() + ".json"
			save_layout(json_path)
			_set_status("Exported: %s + JSON" % path.get_file())
		else:
			_set_status("ERROR: Failed to save scene!")
	else:
		_set_status("ERROR: Failed to pack scene!")

	root.queue_free()


## Create a Marker3D for NPC spawning with all necessary metadata
func _create_npc_spawn_marker(elem: LevelEditorData.PlacedElement, npc_type: String, shop_type: String) -> Marker3D:
	var marker := Marker3D.new()
	marker.name = "NPC_%s_%d" % [npc_type, randi() % 1000]

	# Position with offset for shop NPCs (in front of building)
	if shop_type:
		marker.position = elem.position + Vector3(0, 0, elem.properties.get("depth", 6) / 2 + 1)
	else:
		marker.position = elem.position

	marker.rotation_degrees = elem.rotation

	# Core metadata
	marker.set_meta("spawn_type", "npc")
	marker.set_meta("npc_type", npc_type)
	marker.set_meta("npc_name", elem.properties.get("name", ""))

	# Named NPC data path (from data/npcs/)
	var npc_data_path: String = elem.properties.get("npc_data_path", "")
	if not npc_data_path.is_empty():
		marker.set_meta("npc_data_path", npc_data_path)
		# Also store archetype for TownSpawner to determine spawn type
		marker.set_meta("archetype", elem.properties.get("archetype", ""))
		# Store sprite info from NPCData
		marker.set_meta("sprite_path", elem.properties.get("sprite_path", ""))
		marker.set_meta("sprite_h_frames", elem.properties.get("sprite_h_frames", 4))
		marker.set_meta("sprite_v_frames", elem.properties.get("sprite_v_frames", 1))

	# Quest IDs for quest givers
	var quest_ids: Array = elem.properties.get("quest_ids", [])
	if not quest_ids.is_empty():
		marker.set_meta("quest_ids", quest_ids)

	# Get zoo data for sprite info (for generic NPCs)
	var zoo_id: String = ""
	for npc_def: Dictionary in NPCS:
		if npc_def["id"] == npc_type:
			zoo_id = npc_def.get("zoo_id", "")
			break
	marker.set_meta("zoo_id", zoo_id)

	# NPC identification
	var npc_id: String = elem.properties.get("npc_id", "")
	if not npc_id.is_empty():
		marker.set_meta("npc_id", npc_id)

	# Gender for sprite selection
	marker.set_meta("is_female", elem.properties.get("is_female", false))

	# Region for bounties/quest turn-in
	var region_id: String = elem.properties.get("region_id", "")
	if not region_id.is_empty():
		marker.set_meta("region_id", region_id)

	# Shop/merchant metadata
	if shop_type:
		marker.set_meta("shop_type", shop_type)
		marker.set_meta("shop_tier", elem.properties.get("shop_tier", 2))
		marker.set_meta("buy_price_multiplier", elem.properties.get("buy_price_multiplier", 1.0))
		marker.set_meta("sell_price_multiplier", elem.properties.get("sell_price_multiplier", 0.5))
		marker.set_meta("use_conversation_system", elem.properties.get("use_conversation_system", false))

	# Patrol points for guards
	var has_patrol: bool = false
	for npc_def: Dictionary in NPCS:
		if npc_def["id"] == npc_type:
			has_patrol = npc_def.get("has_patrol", false)
			break
	if has_patrol:
		marker.set_meta("patrol_points", elem.properties.get("patrol_points", []))

	return marker


## Create a Marker3D for prop spawning
func _create_prop_spawn_marker(elem: LevelEditorData.PlacedElement) -> Marker3D:
	var marker := Marker3D.new()
	var prop_id: String = elem.properties.get("id", "")
	marker.name = "Prop_%s_%d" % [prop_id, randi() % 1000]
	marker.position = elem.position
	marker.rotation_degrees = elem.rotation

	marker.set_meta("spawn_type", "prop")
	marker.set_meta("prop_type", prop_id)
	marker.set_meta("prop_id", elem.id)

	return marker


## Create a Marker3D for functional spawning
func _create_functional_spawn_marker(elem: LevelEditorData.PlacedElement) -> Marker3D:
	var marker := Marker3D.new()
	var func_id: String = elem.properties.get("id", "")
	marker.name = "Func_%s_%d" % [func_id, randi() % 1000]
	marker.position = elem.position
	marker.rotation_degrees = elem.rotation

	marker.set_meta("spawn_type", "functional")

	# Get func_type from definition
	var func_type: String = ""
	var loot_tier: int = 2
	for func_def: Dictionary in FUNCTIONALS:
		if func_def.id == func_id:
			func_type = func_def.get("func_type", func_id)
			loot_tier = func_def.get("loot_tier", 2)
			break

	marker.set_meta("func_type", func_type)

	# Type-specific metadata
	match func_id:
		"spawn_point":
			marker.set_meta("spawn_id", elem.properties.get("spawn_id", "default"))

		"fast_travel_shrine":
			marker.set_meta("shrine_name", elem.properties.get("name", "Shrine"))
			marker.set_meta("shrine_id", elem.id)

		"door_zone":
			marker.set_meta("target_scene", elem.properties.get("target_scene", ""))
			marker.set_meta("spawn_id", elem.properties.get("spawn_id", "default"))
			marker.set_meta("door_name", elem.properties.get("name", "Exit"))
			marker.set_meta("show_frame", elem.properties.get("show_frame", true))

		"door_interior":
			marker.set_meta("door_name", elem.properties.get("name", "Door"))
			marker.set_meta("is_locked", elem.properties.get("is_locked", false))
			marker.set_meta("lock_dc", elem.properties.get("lock_dc", 10))

		"chest_common", "chest_rare", "chest_locked":
			marker.set_meta("chest_id", elem.id)
			marker.set_meta("chest_name", elem.properties.get("name", "Chest"))
			marker.set_meta("loot_tier", loot_tier)
			marker.set_meta("is_locked", func_id == "chest_locked")
			marker.set_meta("lock_dc", elem.properties.get("lock_dc", 15))
			marker.set_meta("is_persistent", elem.properties.get("is_persistent", false))

		"rest_area":
			marker.set_meta("bed_name", elem.properties.get("name", "Bed"))

		"bounty_board":
			marker.set_meta("board_name", elem.properties.get("name", "Bounty Board"))

	return marker


## Get prop definition by ID
func _get_prop_data(prop_id: String) -> Dictionary:
	for prop: Dictionary in PROPS:
		if prop.id == prop_id:
			return prop
	return {}


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


## ============================================================================
## PUBLIC API
## ============================================================================

func load_scene(scene_path: String) -> void:
	_set_status("Loading scene: %s" % scene_path)


func create_new_town(poi_data: Dictionary) -> void:
	_clear_all()
	level_data = LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	level_data.level_name = poi_data.get("name", "New Town")
	level_data.level_id = poi_data.get("location_id", "")

	var poi_type: String = poi_data.get("type", "village")
	match poi_type:
		"hamlet": level_data.settlement_type = "hamlet"
		"village": level_data.settlement_type = "village"
		"town": level_data.settlement_type = "town"
		"city": level_data.settlement_type = "city"
		"capital": level_data.settlement_type = "capital"
		_: level_data.settlement_type = "village"

	var type_info: Dictionary = LevelEditorData.SETTLEMENT_TYPES.get(level_data.settlement_type, {})
	level_data.grid_size = type_info.get("grid_size", Vector2i(128, 128))

	level_data.metadata["poi_location_id"] = poi_data.get("location_id", "")
	level_data.metadata["poi_type"] = poi_type
	level_data.metadata["world_x"] = poi_data.get("world_x", 0)
	level_data.metadata["world_y"] = poi_data.get("world_y", 0)

	_select_settlement_type(level_data.settlement_type)
	_set_status("Creating new town: %s (%s)" % [level_data.level_name, level_data.settlement_type.capitalize()])


## ============================================================================
## WORLD LOCATIONS INTEGRATION
## ============================================================================

## Populate the locations dropdown with settlements from WorldGrid
func _populate_locations_dropdown() -> void:
	if not locations_dropdown:
		return

	locations_dropdown.clear()
	locations_dropdown.add_item("-- Select Location --")
	locations_dropdown.set_item_metadata(0, {})

	# Get settlements from WorldGrid LOCATIONS constant
	var WorldGridScript := load("res://scripts/data/world_grid.gd")
	if not WorldGridScript:
		push_error("[TownEditor] Could not load WorldGrid script")
		return

	var locations_data: Array = WorldGridScript.LOCATIONS
	var location_scenes: Dictionary = WorldGridScript.LOCATION_SCENES

	for loc: Dictionary in locations_data:
		var loc_type: String = loc.get("type", "")
		# Only show settlements (village, town, city, capital, outpost)
		if loc_type in ["village", "town", "city", "capital", "outpost"]:
			var display: String = "%s (%s)" % [loc.get("name", ""), loc_type]
			var idx: int = locations_dropdown.item_count
			locations_dropdown.add_item(display)

			# Store full info in metadata
			var meta: Dictionary = {
				"id": loc.get("id", ""),
				"name": loc.get("name", ""),
				"type": loc_type,
				"scene_path": location_scenes.get(loc.get("id", ""), ""),
				"x": loc.get("x", 0),
				"y": loc.get("y", 0),
			}
			locations_dropdown.set_item_metadata(idx, meta)


## Handle location selection from dropdown
func _on_location_selected(index: int) -> void:
	if index == 0:
		return  # "-- Select Location --" item

	var settlement: Dictionary = locations_dropdown.get_item_metadata(index)
	if settlement.is_empty():
		return

	var scene_path: String = settlement.get("scene_path", "")

	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		# No scene exists - create blank layout for this settlement
		_create_blank_from_settlement(settlement)
		return

	# Import existing scene
	_import_existing_scene(scene_path, settlement)

	# Reset dropdown to first item
	locations_dropdown.select(0)


## Create a blank layout from settlement info
func _create_blank_from_settlement(settlement: Dictionary) -> void:
	_clear_all()

	level_data = LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	level_data.level_id = settlement.get("id", "")
	level_data.level_name = settlement.get("name", "")
	level_data.settlement_type = _location_type_to_settlement(settlement.get("type", "village"))

	var type_info: Dictionary = LevelEditorData.SETTLEMENT_TYPES.get(level_data.settlement_type, {})
	level_data.grid_size = type_info.get("grid_size", Vector2i(128, 128))

	level_data.metadata["world_x"] = settlement.get("x", 0)
	level_data.metadata["world_y"] = settlement.get("y", 0)

	_select_settlement_type(level_data.settlement_type)

	# Update ground size
	if viewport_3d:
		var ground_size: float = float(level_data.grid_size.x)
		viewport_3d.set_ground_size(ground_size)
		viewport_3d.resize_grid(ground_size)

	_set_status("Created blank layout for: %s (%s)" % [settlement.get("name", ""), level_data.settlement_type])


## Import an existing scene into the editor
func _import_existing_scene(scene_path: String, settlement: Dictionary) -> void:
	_clear_all()

	var scene: PackedScene = load(scene_path)
	if not scene:
		_set_status("ERROR: Failed to load scene: %s" % scene_path)
		return

	var root: Node3D = scene.instantiate()

	# Setup level_data
	level_data = LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	level_data.level_id = settlement.get("id", "")
	level_data.level_name = settlement.get("name", "")
	level_data.settlement_type = _location_type_to_settlement(settlement.get("type", "village"))

	var type_info: Dictionary = LevelEditorData.SETTLEMENT_TYPES.get(level_data.settlement_type, {})
	level_data.grid_size = type_info.get("grid_size", Vector2i(128, 128))

	level_data.metadata["world_x"] = settlement.get("x", 0)
	level_data.metadata["world_y"] = settlement.get("y", 0)
	level_data.metadata["imported_from"] = scene_path

	# Parse containers
	_parse_container(root.get_node_or_null("Buildings"), LevelEditorData.ElementType.BUILDING)
	_parse_marker_container(root.get_node_or_null("NPCSpawns"), LevelEditorData.ElementType.NPC)
	_parse_marker_container(root.get_node_or_null("PropSpawns"), LevelEditorData.ElementType.PROP)
	_parse_marker_container(root.get_node_or_null("FunctionalSpawns"), LevelEditorData.ElementType.FUNCTIONAL)

	root.queue_free()

	# Update UI
	_select_settlement_type(level_data.settlement_type)

	# Update ground size
	if viewport_3d:
		var ground_size: float = float(level_data.grid_size.x)
		viewport_3d.set_ground_size(ground_size)
		viewport_3d.resize_grid(ground_size)

	_set_status("Imported %d elements from: %s" % [level_data.elements.size(), settlement.get("name", "")])


## Parse a container of Node3D children (buildings, static props)
func _parse_container(container: Node3D, elem_type: int) -> void:
	if not container:
		return
	for child in container.get_children():
		if child is Node3D:
			var elem := LevelEditorData.PlacedElement.new()
			elem.element_type = elem_type
			elem.position = child.position
			elem.rotation = child.rotation_degrees
			elem.scale = child.scale
			elem.properties = {"name": child.name, "imported": true}

			level_data.elements.append(elem)

			# Duplicate the node for the editor viewport
			var node: Node3D = child.duplicate()
			placed_elements[elem.id] = node
			if viewport_3d:
				viewport_3d.add_content(node)


## Parse a container of Marker3D children (NPCs, spawns)
func _parse_marker_container(container: Node3D, elem_type: int) -> void:
	if not container:
		return
	for child in container.get_children():
		if child is Marker3D:
			var elem := LevelEditorData.PlacedElement.new()
			elem.element_type = elem_type
			elem.position = child.position
			elem.rotation = child.rotation_degrees

			# Copy all metadata
			for meta_key: String in child.get_meta_list():
				elem.properties[meta_key] = child.get_meta(meta_key)

			# Ensure we have an id property
			elem.properties["id"] = child.get_meta("id", child.name.to_snake_case())
			elem.properties["name"] = child.name
			elem.properties["imported"] = true

			level_data.elements.append(elem)

			# Create visual placeholder element
			var brush: Dictionary = {"type": _elem_type_to_brush(elem_type), "data": elem.properties}
			var result: Dictionary = _create_element(brush, elem.position)
			if not result.is_empty():
				result.node.rotation_degrees = elem.rotation
				placed_elements[elem.id] = result.node
				if viewport_3d:
					viewport_3d.add_content(result.node)


## Convert location type string to settlement type
func _location_type_to_settlement(loc_type: String) -> String:
	match loc_type:
		"village": return "village"
		"town": return "town"
		"city": return "city"
		"capital": return "capital"
		"outpost": return "hamlet"
		"hamlet": return "hamlet"
	return "village"


## Convert element type to brush type string
func _elem_type_to_brush(elem_type: int) -> String:
	match elem_type:
		LevelEditorData.ElementType.BUILDING: return "building"
		LevelEditorData.ElementType.NPC: return "npc"
		LevelEditorData.ElementType.PROP: return "prop"
		LevelEditorData.ElementType.FUNCTIONAL: return "functional"
	return "prop"
