## codex_manager.gd - Tracks discovered recipes, lore entries, and bestiary
## Autoload singleton for managing the player's codex of knowledge
extends Node

## Signals
signal recipe_discovered(category: String, recipe_id: String)
signal lore_discovered(category: String, lore_id: String)
signal bestiary_entry_discovered(creature_id: String)

## Codex categories
enum CodexCategory {
	ALCHEMY,      # Potions and elixirs
	SMITHING,     # Weapons and armor
	COOKING,      # Food and drink
	ENCHANTING,   # Magical items
	ENGINEERING,  # Tools and contraptions
	HERBALISM,    # Plant preparations
}

## Recipe data structure
## Each recipe contains: {id, name, description, ingredients, result, skill_required, category}

## Discovered recipes by category (category_name -> array of recipe_ids)
var discovered_recipes: Dictionary = {}

## Discovered lore entries by category (category_name -> array of lore_ids)
var discovered_lore: Dictionary = {}

## Discovered bestiary entries (creature_id -> {name, description, weaknesses, drops})
var bestiary_entries: Dictionary = {}

## All available recipes (loaded from data files)
var all_recipes: Dictionary = {}

## All lore entries (loaded from data files)
var all_lore: Dictionary = {}

## Lore categories
const LORE_CATEGORIES: Array[String] = [
	"history",
	"factions",
	"locations",
	"creatures",
	"artifacts",
	"gods",
	"magic",
]

func _ready() -> void:
	_initialize_categories()
	_load_recipe_data()
	_load_lore_data()

## Initialize category dictionaries
func _initialize_categories() -> void:
	# Initialize recipe categories
	for cat in CodexCategory.values():
		var cat_name: String = _get_category_name(cat)
		discovered_recipes[cat_name] = []

	# Initialize lore categories
	for cat_name: String in LORE_CATEGORIES:
		discovered_lore[cat_name] = []

## Get category name from enum
func _get_category_name(category: CodexCategory) -> String:
	match category:
		CodexCategory.ALCHEMY:
			return "alchemy"
		CodexCategory.SMITHING:
			return "smithing"
		CodexCategory.COOKING:
			return "cooking"
		CodexCategory.ENCHANTING:
			return "enchanting"
		CodexCategory.ENGINEERING:
			return "engineering"
		CodexCategory.HERBALISM:
			return "herbalism"
		_:
			return "misc"

## Load recipe data from data files
func _load_recipe_data() -> void:
	var recipes_path := "res://data/recipes/"
	var dir := DirAccess.open(recipes_path)
	if not dir:
		print("[Codex] No recipes directory found at: %s" % recipes_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".json"):
			var path := recipes_path + file_name
			_load_recipe_file(path)
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[Codex] Loaded %d recipes" % all_recipes.size())

## Load a single recipe file
func _load_recipe_file(path: String) -> void:
	if path.ends_with(".json"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			var error := json.parse(file.get_as_text())
			if error == OK:
				var data: Variant = json.get_data()
				if data is Array:
					for recipe: Dictionary in data:
						if recipe.has("id"):
							all_recipes[recipe.id] = recipe
				elif data is Dictionary and data.has("id"):
					all_recipes[data.id] = data
			file.close()
	elif path.ends_with(".tres"):
		var resource: Resource = load(path)
		if resource and "id" in resource:
			all_recipes[resource.id] = _recipe_resource_to_dict(resource)

## Convert a recipe resource to dictionary
func _recipe_resource_to_dict(resource: Resource) -> Dictionary:
	var dict: Dictionary = {}
	for prop: Dictionary in resource.get_property_list():
		var prop_name: String = prop["name"]
		if not prop_name.begins_with("_"):
			dict[prop_name] = resource.get(prop_name)
	return dict

## Load lore data from data files
func _load_lore_data() -> void:
	var lore_path := "res://data/lore/"
	var dir := DirAccess.open(lore_path)
	if not dir:
		print("[Codex] No lore directory found at: %s" % lore_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".json"):
			var path := lore_path + file_name
			_load_lore_file(path)
		file_name = dir.get_next()

	dir.list_dir_end()
	print("[Codex] Loaded %d lore entries" % all_lore.size())

## Load a single lore file
func _load_lore_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error == OK:
			var data: Variant = json.get_data()
			if data is Array:
				for entry: Dictionary in data:
					if entry.has("id"):
						all_lore[entry.id] = entry
			elif data is Dictionary and data.has("id"):
				all_lore[data.id] = data
		file.close()

## Discover a recipe
func discover_recipe(recipe_id: String) -> bool:
	# Find the recipe
	if not all_recipes.has(recipe_id):
		push_warning("[Codex] Unknown recipe: %s" % recipe_id)
		return false

	var recipe: Dictionary = all_recipes[recipe_id]
	var category: String = recipe.get("category", "misc")

	# Check if already discovered
	if not discovered_recipes.has(category):
		discovered_recipes[category] = []

	if recipe_id in discovered_recipes[category]:
		return false  # Already known

	# Add to discovered
	discovered_recipes[category].append(recipe_id)
	recipe_discovered.emit(category, recipe_id)

	print("[Codex] Discovered recipe: %s (%s)" % [recipe.get("name", recipe_id), category])
	return true

## Check if a recipe is discovered
func is_recipe_discovered(recipe_id: String) -> bool:
	for category: String in discovered_recipes:
		if recipe_id in discovered_recipes[category]:
			return true
	return false

## Get all discovered recipes in a category
func get_discovered_recipes(category: String) -> Array:
	return discovered_recipes.get(category, [])

## Get recipe data by ID
func get_recipe(recipe_id: String) -> Dictionary:
	return all_recipes.get(recipe_id, {})

## Get all recipes in a category (discovered or not)
func get_category_recipes(category: String) -> Array:
	var result: Array = []
	for recipe_id: String in all_recipes:
		var recipe: Dictionary = all_recipes[recipe_id]
		if recipe.get("category", "misc") == category:
			result.append(recipe)
	return result

## Discover a lore entry
func discover_lore(lore_id: String) -> bool:
	if not all_lore.has(lore_id):
		push_warning("[Codex] Unknown lore entry: %s" % lore_id)
		return false

	var entry: Dictionary = all_lore[lore_id]
	var category: String = entry.get("category", "history")

	if not discovered_lore.has(category):
		discovered_lore[category] = []

	if lore_id in discovered_lore[category]:
		return false  # Already known

	discovered_lore[category].append(lore_id)
	lore_discovered.emit(category, lore_id)

	print("[Codex] Discovered lore: %s (%s)" % [entry.get("title", lore_id), category])
	return true

## Check if a lore entry is discovered
func is_lore_discovered(lore_id: String) -> bool:
	for category: String in discovered_lore:
		if lore_id in discovered_lore[category]:
			return true
	return false

## Get all discovered lore in a category
func get_discovered_lore(category: String) -> Array:
	return discovered_lore.get(category, [])

## Get lore entry data by ID
func get_lore(lore_id: String) -> Dictionary:
	return all_lore.get(lore_id, {})

## Discover a bestiary entry when killing a creature
func discover_bestiary_entry(creature_id: String, creature_data: Dictionary = {}) -> bool:
	if bestiary_entries.has(creature_id):
		return false  # Already known

	bestiary_entries[creature_id] = creature_data
	bestiary_entry_discovered.emit(creature_id)

	print("[Codex] Discovered bestiary entry: %s" % creature_data.get("name", creature_id))
	return true

## Check if a bestiary entry is discovered
func is_bestiary_discovered(creature_id: String) -> bool:
	return bestiary_entries.has(creature_id)

## Get a bestiary entry
func get_bestiary_entry(creature_id: String) -> Dictionary:
	return bestiary_entries.get(creature_id, {})

## Get all discovered bestiary entries
func get_all_bestiary_entries() -> Dictionary:
	return bestiary_entries

## Get total counts for UI
func get_stats() -> Dictionary:
	var total_recipes: int = 0
	var discovered_recipe_count: int = 0
	for category: String in discovered_recipes:
		discovered_recipe_count += discovered_recipes[category].size()
	total_recipes = all_recipes.size()

	var total_lore: int = 0
	var discovered_lore_count: int = 0
	for category: String in discovered_lore:
		discovered_lore_count += discovered_lore[category].size()
	total_lore = all_lore.size()

	return {
		"recipes_discovered": discovered_recipe_count,
		"recipes_total": total_recipes,
		"lore_discovered": discovered_lore_count,
		"lore_total": total_lore,
		"bestiary_discovered": bestiary_entries.size()
	}

## Reset all discoveries (for new game)
func reset() -> void:
	_initialize_categories()
	bestiary_entries.clear()

## Save codex state to dictionary
func to_dict() -> Dictionary:
	return {
		"discovered_recipes": discovered_recipes.duplicate(true),
		"discovered_lore": discovered_lore.duplicate(true),
		"bestiary_entries": bestiary_entries.duplicate(true)
	}

## Load codex state from dictionary
func from_dict(data: Dictionary) -> void:
	# Reset first
	_initialize_categories()
	bestiary_entries.clear()

	# Load saved data
	var saved_recipes: Dictionary = data.get("discovered_recipes", {})
	for category: String in saved_recipes:
		discovered_recipes[category] = saved_recipes[category].duplicate()

	var saved_lore: Dictionary = data.get("discovered_lore", {})
	for category: String in saved_lore:
		discovered_lore[category] = saved_lore[category].duplicate()

	bestiary_entries = data.get("bestiary_entries", {}).duplicate(true)
