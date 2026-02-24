## codex_panel.gd - UI panel for viewing discovered recipes, lore, and bestiary
## Part of the game menu system
class_name CodexPanel
extends Control

## Currently selected category tab
enum Tab {
	RECIPES,
	LORE,
	BESTIARY
}

## UI colors
const COL_BACKGROUND := Color(0.1, 0.08, 0.06)
const COL_PANEL := Color(0.15, 0.12, 0.1)
const COL_HEADER := Color(0.8, 0.7, 0.5)
const COL_TEXT := Color(0.9, 0.85, 0.75)
const COL_SELECTED := Color(0.3, 0.25, 0.2)
const COL_HIGHLIGHT := Color(0.9, 0.8, 0.4)

## Current tab and selection
var current_tab: Tab = Tab.RECIPES
var selected_category: String = "alchemy"
var selected_item_index: int = -1

## UI nodes
var tab_container: HBoxContainer
var category_list: ItemList
var item_list: ItemList
var detail_panel: PanelContainer
var detail_title: Label
var detail_description: RichTextLabel

## Recipe category names for display
const RECIPE_CATEGORIES: Dictionary = {
	"alchemy": "Alchemy",
	"smithing": "Smithing",
	"cooking": "Cooking",
	"enchanting": "Enchanting",
	"engineering": "Engineering",
	"herbalism": "Herbalism"
}

## Lore category names for display
const LORE_CATEGORIES: Dictionary = {
	"history": "History",
	"factions": "Factions",
	"locations": "Locations",
	"creatures": "Creatures",
	"artifacts": "Artifacts",
	"gods": "The Gods",
	"magic": "Magic"
}

func _ready() -> void:
	_build_ui()
	_refresh_display()

## Build the UI layout
func _build_ui() -> void:
	# Main container
	custom_minimum_size = Vector2(600, 400)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(main_vbox)

	# Header with tabs
	_build_tabs(main_vbox)

	# Content area (horizontal split)
	var content_hbox := HBoxContainer.new()
	content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content_hbox)

	# Left side: Category list
	_build_category_panel(content_hbox)

	# Middle: Item list
	_build_item_panel(content_hbox)

	# Right side: Detail panel
	_build_detail_panel(content_hbox)

## Build tab buttons
func _build_tabs(parent: Control) -> void:
	tab_container = HBoxContainer.new()
	tab_container.custom_minimum_size.y = 40
	parent.add_child(tab_container)

	var tabs: Array[String] = ["Recipes", "Lore", "Bestiary"]
	for i: int in range(tabs.size()):
		var btn := Button.new()
		btn.text = tabs[i]
		btn.custom_minimum_size = Vector2(100, 35)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		tab_container.add_child(btn)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_container.add_child(spacer)

	# Stats label
	var stats_label := Label.new()
	stats_label.name = "StatsLabel"
	stats_label.add_theme_color_override("font_color", COL_TEXT)
	tab_container.add_child(stats_label)

## Build category panel
func _build_category_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 150
	parent.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_color = COL_HEADER.darkened(0.5)
	panel.add_theme_stylebox_override("panel", style)

	category_list = ItemList.new()
	category_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	category_list.add_theme_color_override("font_color", COL_TEXT)
	category_list.add_theme_color_override("font_selected_color", COL_HIGHLIGHT)
	category_list.item_selected.connect(_on_category_selected)
	panel.add_child(category_list)

## Build item list panel
func _build_item_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 200
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_PANEL
	style.border_width_right = 1
	style.border_color = COL_HEADER.darkened(0.5)
	panel.add_theme_stylebox_override("panel", style)

	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.add_theme_color_override("font_color", COL_TEXT)
	item_list.add_theme_color_override("font_selected_color", COL_HIGHLIGHT)
	item_list.item_selected.connect(_on_item_selected)
	panel.add_child(item_list)

## Build detail panel
func _build_detail_panel(parent: Control) -> void:
	detail_panel = PanelContainer.new()
	detail_panel.custom_minimum_size.x = 250
	detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(detail_panel)

	var style := StyleBoxFlat.new()
	style.bg_color = COL_BACKGROUND
	detail_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	detail_panel.add_child(vbox)

	# Title
	detail_title = Label.new()
	detail_title.add_theme_font_size_override("font_size", 18)
	detail_title.add_theme_color_override("font_color", COL_HEADER)
	detail_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(detail_title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Description
	detail_description = RichTextLabel.new()
	detail_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_description.bbcode_enabled = true
	detail_description.add_theme_color_override("default_color", COL_TEXT)
	vbox.add_child(detail_description)

## Tab button pressed
func _on_tab_pressed(tab_index: int) -> void:
	current_tab = tab_index as Tab
	selected_category = ""
	selected_item_index = -1
	_refresh_display()

## Category selected in list
func _on_category_selected(index: int) -> void:
	var categories: Array[String] = _get_current_categories()
	if index >= 0 and index < categories.size():
		selected_category = categories[index]
		selected_item_index = -1
		_refresh_item_list()
		_clear_detail()

## Item selected in list
func _on_item_selected(index: int) -> void:
	selected_item_index = index
	_refresh_detail()

## Get category list for current tab
func _get_current_categories() -> Array[String]:
	match current_tab:
		Tab.RECIPES:
			var result: Array[String] = []
			for key: String in RECIPE_CATEGORIES:
				result.append(key)
			return result
		Tab.LORE:
			var result: Array[String] = []
			for key: String in LORE_CATEGORIES:
				result.append(key)
			return result
		Tab.BESTIARY:
			return ["creatures"]
		_:
			return []

## Get display name for category
func _get_category_display_name(category: String) -> String:
	if RECIPE_CATEGORIES.has(category):
		return RECIPE_CATEGORIES[category]
	if LORE_CATEGORIES.has(category):
		return LORE_CATEGORIES[category]
	return category.capitalize()

## Refresh the entire display
func _refresh_display() -> void:
	_refresh_category_list()
	_refresh_item_list()
	_refresh_stats()
	_clear_detail()

## Refresh category list
func _refresh_category_list() -> void:
	category_list.clear()

	var categories: Array[String] = _get_current_categories()
	for cat: String in categories:
		var display_name: String = _get_category_display_name(cat)
		var count: int = _get_category_count(cat)
		category_list.add_item("%s (%d)" % [display_name, count])

	if categories.size() > 0 and selected_category.is_empty():
		selected_category = categories[0]
		category_list.select(0)

## Get item count for a category
func _get_category_count(category: String) -> int:
	match current_tab:
		Tab.RECIPES:
			return CodexManager.get_discovered_recipes(category).size()
		Tab.LORE:
			return CodexManager.get_discovered_lore(category).size()
		Tab.BESTIARY:
			return CodexManager.get_all_bestiary_entries().size()
		_:
			return 0

## Refresh item list for current category
func _refresh_item_list() -> void:
	item_list.clear()

	match current_tab:
		Tab.RECIPES:
			var recipe_ids: Array = CodexManager.get_discovered_recipes(selected_category)
			for recipe_id in recipe_ids:
				var recipe: Dictionary = CodexManager.get_recipe(recipe_id)
				item_list.add_item(recipe.get("name", recipe_id))

		Tab.LORE:
			var lore_ids: Array = CodexManager.get_discovered_lore(selected_category)
			for lore_id in lore_ids:
				var entry: Dictionary = CodexManager.get_lore(lore_id)
				item_list.add_item(entry.get("title", lore_id))

		Tab.BESTIARY:
			var entries: Dictionary = CodexManager.get_all_bestiary_entries()
			for creature_id: String in entries:
				var entry: Dictionary = entries[creature_id]
				item_list.add_item(entry.get("name", creature_id))

## Refresh stats label
func _refresh_stats() -> void:
	var stats_label := tab_container.get_node_or_null("StatsLabel") as Label
	if not stats_label:
		return

	var stats: Dictionary = CodexManager.get_stats()

	match current_tab:
		Tab.RECIPES:
			stats_label.text = "Recipes: %d/%d" % [stats.recipes_discovered, stats.recipes_total]
		Tab.LORE:
			stats_label.text = "Lore: %d/%d" % [stats.lore_discovered, stats.lore_total]
		Tab.BESTIARY:
			stats_label.text = "Creatures: %d" % stats.bestiary_discovered

## Clear detail panel
func _clear_detail() -> void:
	detail_title.text = "Select an entry"
	detail_description.text = ""

## Refresh detail panel for selected item
func _refresh_detail() -> void:
	if selected_item_index < 0:
		_clear_detail()
		return

	match current_tab:
		Tab.RECIPES:
			_show_recipe_detail()
		Tab.LORE:
			_show_lore_detail()
		Tab.BESTIARY:
			_show_bestiary_detail()

## Show recipe detail
func _show_recipe_detail() -> void:
	var recipe_ids: Array = CodexManager.get_discovered_recipes(selected_category)
	if selected_item_index >= recipe_ids.size():
		return

	var recipe_id: String = recipe_ids[selected_item_index]
	var recipe: Dictionary = CodexManager.get_recipe(recipe_id)

	detail_title.text = recipe.get("name", recipe_id)

	var desc: String = ""
	desc += "[color=#ccaa88]%s[/color]\n\n" % recipe.get("description", "No description.")

	# Ingredients
	var ingredients: Array = recipe.get("ingredients", [])
	if ingredients.size() > 0:
		desc += "[color=#aaaaaa]Ingredients:[/color]\n"
		for ing: Dictionary in ingredients:
			desc += "  - %s x%d\n" % [ing.get("name", ing.get("id", "?")), ing.get("amount", 1)]
		desc += "\n"

	# Result
	var result: Dictionary = recipe.get("result", {})
	if not result.is_empty():
		desc += "[color=#aaaaaa]Creates:[/color]\n"
		desc += "  %s x%d\n" % [result.get("name", result.get("id", "?")), result.get("amount", 1)]

	# Skill requirement
	var skill_req: int = recipe.get("skill_required", 0)
	if skill_req > 0:
		desc += "\n[color=#888888]Requires: %s skill %d[/color]" % [selected_category.capitalize(), skill_req]

	detail_description.text = desc

## Show lore detail
func _show_lore_detail() -> void:
	var lore_ids: Array = CodexManager.get_discovered_lore(selected_category)
	if selected_item_index >= lore_ids.size():
		return

	var lore_id: String = lore_ids[selected_item_index]
	var entry: Dictionary = CodexManager.get_lore(lore_id)

	detail_title.text = entry.get("title", lore_id)
	detail_description.text = entry.get("text", "No content.")

## Show bestiary detail
func _show_bestiary_detail() -> void:
	var entries: Dictionary = CodexManager.get_all_bestiary_entries()
	var keys: Array = entries.keys()

	if selected_item_index >= keys.size():
		return

	var creature_id: String = keys[selected_item_index]
	var entry: Dictionary = entries[creature_id]

	detail_title.text = entry.get("name", creature_id)

	var desc: String = ""
	desc += "[color=#ccaa88]%s[/color]\n\n" % entry.get("description", "A mysterious creature.")

	# Stats
	if entry.has("hp"):
		desc += "[color=#aaaaaa]Health:[/color] %d\n" % entry.hp
	if entry.has("damage"):
		desc += "[color=#aaaaaa]Damage:[/color] %d\n" % entry.damage

	# Weaknesses
	var weaknesses: Array = entry.get("weaknesses", [])
	if weaknesses.size() > 0:
		desc += "\n[color=#aa8888]Weaknesses:[/color]\n"
		for weak: String in weaknesses:
			desc += "  - %s\n" % weak

	# Drops
	var drops: Array = entry.get("drops", [])
	if drops.size() > 0:
		desc += "\n[color=#88aa88]Known Drops:[/color]\n"
		for drop: String in drops:
			desc += "  - %s\n" % drop

	detail_description.text = desc
