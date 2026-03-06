## item_zoo.gd - Visual QA tool for all game items
## Displays every item in a list view with sprite status indicators
extends Control

## Colors for item status
const COL_OK := Color(0.4, 0.9, 0.4)       # Green - has sprite/mesh
const COL_NO_SPRITE := Color(0.9, 0.9, 0.4)  # Yellow - registered but no sprite
const COL_ORPHAN := Color(0.9, 0.4, 0.4)   # Red - has .tres but not registered
const COL_TEXT := Color(0.8, 0.8, 0.8)
const COL_SELECTED := Color(0.3, 0.5, 0.8)

## Node references
var filter_buttons: HBoxContainer
var search_box: LineEdit
var item_list_container: VBoxContainer
var details_panel: VBoxContainer
var scroll_container: ScrollContainer

## State
var all_items: Array[Dictionary] = []  # All discovered items
var visible_items: Array[Dictionary] = []
var selected_item: Dictionary = {}
var current_filter: String = "All"
var search_text: String = ""

## Categories for filtering
var categories: Array[String] = ["All", "Weapons", "Armor", "Items", "Consumables", "Materials", "Quest", "Orphan"]


func _ready() -> void:
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_create_ui()
	_scan_all_items()
	_apply_filter()


## ============================================================================
## UI CREATION
## ============================================================================

func _create_ui() -> void:
	# Main layout - full screen
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)

	# Left panel - list and filters
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 2.0
	main_hbox.add_child(left_panel)

	# Title
	var title := Label.new()
	title.text = "=== ITEM ZOO ==="
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	left_panel.add_child(title)

	# Filter buttons
	filter_buttons = HBoxContainer.new()
	filter_buttons.add_theme_constant_override("separation", 4)
	left_panel.add_child(filter_buttons)

	for category: String in categories:
		var btn := Button.new()
		btn.text = category
		btn.pressed.connect(_on_filter_pressed.bind(category))
		filter_buttons.add_child(btn)

	# Search box
	var search_row := HBoxContainer.new()
	left_panel.add_child(search_row)

	var search_label := Label.new()
	search_label.text = "Search: "
	search_row.add_child(search_label)

	search_box = LineEdit.new()
	search_box.placeholder_text = "Filter by name or ID..."
	search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_box.text_changed.connect(_on_search_changed)
	search_row.add_child(search_box)

	# Item count label
	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "Items: 0"
	left_panel.add_child(count_label)

	# Separator
	var sep := HSeparator.new()
	left_panel.add_child(sep)

	# Scroll container for item list
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(scroll_container)

	item_list_container = VBoxContainer.new()
	item_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.add_child(item_list_container)

	# Right panel - details
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	main_hbox.add_child(right_panel)

	var scroll_right := ScrollContainer.new()
	scroll_right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll_right)

	details_panel = VBoxContainer.new()
	details_panel.add_theme_constant_override("separation", 8)
	scroll_right.add_child(details_panel)

	_create_details_labels()


func _create_details_labels() -> void:
	var header := Label.new()
	header.name = "DetailsHeader"
	header.text = "Select an item"
	header.add_theme_font_size_override("font_size", 20)
	details_panel.add_child(header)

	var fields: Array[String] = [
		"ID", "Display Name", "Description", "Category", "Type",
		"Base Value", "Weight", "Stack Size",
		"Sprite Status", "Icon Path", "Mesh Path",
		"Recipe Use", "Drop Source"
	]

	for field_name: String in fields:
		var hbox := HBoxContainer.new()
		details_panel.add_child(hbox)

		var lbl := Label.new()
		lbl.text = field_name + ":"
		lbl.custom_minimum_size.x = 100
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		hbox.add_child(lbl)

		var value := Label.new()
		value.name = "Detail_" + field_name.replace(" ", "")
		value.text = "-"
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(value)


## ============================================================================
## ITEM SCANNING
## ============================================================================

func _scan_all_items() -> void:
	all_items.clear()

	# Scan registered items from InventoryManager
	if InventoryManager:
		_scan_database(InventoryManager.weapon_database, "Weapons")
		_scan_database(InventoryManager.armor_database, "Armor")
		_scan_database(InventoryManager.item_database, "Items")

	# Scan for orphan .tres files (exist but not registered)
	_scan_orphan_files()

	print("[ItemZoo] Scanned %d total items" % all_items.size())


func _scan_database(database: Dictionary, category: String) -> void:
	for item_id: String in database:
		var data: Resource = database[item_id]
		var item_entry := _create_item_entry(item_id, data, category, true)
		all_items.append(item_entry)


func _create_item_entry(item_id: String, data: Resource, category: String, is_registered: bool) -> Dictionary:
	var entry := {
		"id": item_id,
		"display_name": "",
		"description": "",
		"category": category,
		"type": "",
		"base_value": 0,
		"weight": 0.0,
		"stack_size": 1,
		"is_registered": is_registered,
		"has_sprite": false,
		"icon_path": "",
		"mesh_path": "",
		"data": data
	}

	if data is WeaponData:
		var weapon: WeaponData = data as WeaponData
		entry.display_name = weapon.display_name
		entry.description = weapon.description
		entry.type = "Weapon"
		entry.base_value = weapon.base_value
		entry.weight = weapon.weight
		entry.stack_size = 1
		entry.has_sprite = not weapon.mesh_path.is_empty()
		entry.mesh_path = weapon.mesh_path
	elif data is ArmorData:
		var armor: ArmorData = data as ArmorData
		entry.display_name = armor.display_name
		entry.description = armor.description
		entry.type = _get_armor_slot_name(armor.slot)
		entry.base_value = armor.base_value
		entry.weight = armor.weight
		entry.stack_size = 1
		entry.has_sprite = not armor.mesh_path.is_empty() or not armor.icon_path.is_empty()
		entry.icon_path = armor.icon_path
		entry.mesh_path = armor.mesh_path
	elif data is ItemData:
		var item: ItemData = data as ItemData
		entry.display_name = item.display_name
		entry.description = item.description
		entry.type = _get_item_type_name(item.item_type)
		entry.base_value = item.base_value
		entry.weight = item.weight
		entry.stack_size = item.max_stack
		entry.has_sprite = not item.icon_path.is_empty() or not item.mesh_path.is_empty()
		entry.icon_path = item.icon_path
		entry.mesh_path = item.mesh_path

		# Determine subcategory
		match item.item_type:
			ItemData.ItemType.CONSUMABLE:
				entry.category = "Consumables"
			ItemData.ItemType.MATERIAL:
				entry.category = "Materials"
			ItemData.ItemType.QUEST, ItemData.ItemType.KEY:
				entry.category = "Quest"

	return entry


func _scan_orphan_files() -> void:
	# Scan items directory
	_scan_directory_for_orphans("res://data/items/", "Items")
	_scan_directory_for_orphans("res://data/weapons/", "Weapons")
	_scan_directory_for_orphans("res://data/armor/", "Armor")


func _scan_directory_for_orphans(path: String, category: String) -> void:
	var dir := DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") and not dir.current_is_dir():
			var full_path := path + file_name
			var item_id := file_name.get_basename()

			# Check if already registered
			var already_found := false
			for existing: Dictionary in all_items:
				if existing.id == item_id:
					already_found = true
					break

			if not already_found:
				# Load and add as orphan
				var res: Resource = load(full_path)
				if res:
					var entry := _create_item_entry(item_id, res, category, false)
					entry.category = "Orphan"
					all_items.append(entry)

		file_name = dir.get_next()
	dir.list_dir_end()


func _get_armor_slot_name(slot: int) -> String:
	match slot:
		0: return "Head"
		1: return "Body"
		2: return "Hands"
		3: return "Feet"
		4: return "Ring"
		5: return "Ring"
		6: return "Amulet"
		7: return "Shield"
		_: return "Unknown"


func _get_item_type_name(item_type: int) -> String:
	match item_type:
		0: return "Consumable"
		1: return "Material"
		2: return "Quest"
		3: return "Key"
		4: return "Scroll"
		5: return "Book"
		6: return "Misc"
		7: return "Repair Kit"
		8: return "Ammunition"
		9: return "Bedroll"
		10: return "Torch"
		_: return "Unknown"


## ============================================================================
## FILTERING
## ============================================================================

func _on_filter_pressed(category: String) -> void:
	current_filter = category
	_apply_filter()


func _on_search_changed(text: String) -> void:
	search_text = text.to_lower()
	_apply_filter()


func _apply_filter() -> void:
	visible_items.clear()

	for item: Dictionary in all_items:
		# Category filter
		var passes_category := false
		if current_filter == "All":
			passes_category = true
		elif current_filter == "Orphan":
			passes_category = not item.is_registered
		else:
			passes_category = (item.category == current_filter)

		# Search filter
		var passes_search := true
		if not search_text.is_empty():
			var name_lower: String = item.display_name.to_lower()
			var id_lower: String = item.id.to_lower()
			passes_search = name_lower.contains(search_text) or id_lower.contains(search_text)

		if passes_category and passes_search:
			visible_items.append(item)

	# Sort by name
	visible_items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.display_name.to_lower() < b.display_name.to_lower()
	)

	_rebuild_list()


func _rebuild_list() -> void:
	# Clear existing list
	for child in item_list_container.get_children():
		child.queue_free()

	# Update count
	var count_label: Label = get_node("CountLabel") if has_node("CountLabel") else null
	if not count_label:
		for child in get_children():
			if child is VBoxContainer:
				count_label = child.get_node_or_null("CountLabel")
				break
	if count_label:
		count_label.text = "Items: %d / %d" % [visible_items.size(), all_items.size()]

	# Create list entries
	for item: Dictionary in visible_items:
		var row := _create_list_row(item)
		item_list_container.add_child(row)


func _create_list_row(item: Dictionary) -> Control:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_item_selected.bind(item))

	# Determine status color
	var status_color: Color
	var status_text: String
	if not item.is_registered:
		status_color = COL_ORPHAN
		status_text = "[NOT REG]"
	elif item.has_sprite:
		status_color = COL_OK
		status_text = "[OK]"
	else:
		status_color = COL_NO_SPRITE
		status_text = "[NO SPRITE]"

	# Format: [STATUS] Name - Category - ID
	btn.text = "%s %s - %s - %s" % [
		status_text,
		item.display_name if not item.display_name.is_empty() else item.id,
		item.category,
		item.id
	]

	# Set button modulate based on status
	btn.modulate = status_color

	return btn


## ============================================================================
## DETAILS PANEL
## ============================================================================

func _on_item_selected(item: Dictionary) -> void:
	selected_item = item
	_update_details_panel()


func _update_details_panel() -> void:
	if selected_item.is_empty():
		return

	var header: Label = details_panel.get_node_or_null("DetailsHeader")
	if header:
		header.text = selected_item.display_name if not selected_item.display_name.is_empty() else selected_item.id

	_set_detail("ID", selected_item.id)
	_set_detail("DisplayName", selected_item.display_name)
	_set_detail("Description", selected_item.description)
	_set_detail("Category", selected_item.category)
	_set_detail("Type", selected_item.type)
	_set_detail("BaseValue", str(selected_item.base_value) + " gold")
	_set_detail("Weight", "%.1f" % selected_item.weight)
	_set_detail("StackSize", str(selected_item.stack_size))

	# Sprite status
	var status_text: String
	if not selected_item.is_registered:
		status_text = "NOT REGISTERED - Add to InventoryManager!"
	elif selected_item.has_sprite:
		status_text = "OK - Has sprite/mesh"
	else:
		status_text = "NO SPRITE - Needs icon_path or mesh_path"
	_set_detail("SpriteStatus", status_text)

	_set_detail("IconPath", selected_item.icon_path if not selected_item.icon_path.is_empty() else "(none)")
	_set_detail("MeshPath", selected_item.mesh_path if not selected_item.mesh_path.is_empty() else "(none)")

	# Check recipe use
	var recipe_use := _find_recipe_use(selected_item.id)
	_set_detail("RecipeUse", recipe_use if not recipe_use.is_empty() else "(none)")

	# Check drop source (would need to scan enemy data)
	_set_detail("DropSource", "(not scanned)")


func _set_detail(field: String, value: String) -> void:
	var lbl: Label = details_panel.find_child("Detail_" + field, true, false) as Label
	if lbl:
		lbl.text = value


func _find_recipe_use(item_id: String) -> String:
	if not CraftingManager:
		return ""

	var uses: Array[String] = []
	for recipe_id: String in CraftingManager.recipes:
		var recipe: CraftingRecipe = CraftingManager.recipes[recipe_id]
		if recipe.materials.has(item_id):
			uses.append(recipe.display_name)

	if uses.is_empty():
		return ""
	return ", ".join(uses)


## ============================================================================
## INPUT
## ============================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			# Return to main menu or close
			get_tree().quit()
