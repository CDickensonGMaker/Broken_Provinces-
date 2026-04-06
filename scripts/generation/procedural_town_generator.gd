class_name ProceduralTownGenerator
extends RefCounted
## Procedural town generator that outputs LevelEditorData.LevelData format
## Uses AABB collision detection via PlacementUtils to prevent overlapping buildings

## Building definitions - same as town editor for consistency
const BUILDINGS: Array[Dictionary] = [
	# Tier 1 - Hamlet buildings
	{"id": "hovel", "name": "Hovel", "width": 4, "height": 2.5, "depth": 4, "style": "wood", "tier": 1},
	{"id": "cottage", "name": "Cottage", "width": 5, "height": 3, "depth": 5, "style": "stone", "tier": 1},
	{"id": "shack", "name": "Shack", "width": 3, "height": 2, "depth": 3, "style": "wood", "tier": 1},
	# Tier 2 - Village buildings
	{"id": "house_small", "name": "Small House", "width": 6, "height": 3.5, "depth": 5, "style": "timber", "tier": 2},
	{"id": "house_medium", "name": "Medium House", "width": 8, "height": 4, "depth": 6, "style": "timber", "tier": 2},
	{"id": "barn", "name": "Barn", "width": 10, "height": 5, "depth": 8, "style": "wood", "tier": 2},
	{"id": "inn", "name": "Inn/Tavern", "width": 12, "height": 5, "depth": 10, "style": "timber", "tier": 2, "is_shop": true, "shop_type": "inn"},
	{"id": "general_store", "name": "General Store", "width": 8, "height": 4, "depth": 7, "style": "timber", "tier": 2, "is_shop": true, "shop_type": "general"},
	# Tier 3 - Town buildings
	{"id": "house_large", "name": "Large House", "width": 10, "height": 4.5, "depth": 8, "style": "stone", "tier": 3},
	{"id": "blacksmith", "name": "Blacksmith", "width": 10, "height": 4, "depth": 8, "style": "stone", "tier": 3, "is_shop": true, "shop_type": "blacksmith"},
	{"id": "temple", "name": "Temple", "width": 12, "height": 8, "depth": 15, "style": "stone", "tier": 3, "is_shop": true, "shop_type": "temple"},
	{"id": "guild_hall", "name": "Guild Hall", "width": 14, "height": 5, "depth": 12, "style": "stone", "tier": 3},
	{"id": "warehouse", "name": "Warehouse", "width": 12, "height": 5, "depth": 10, "style": "wood", "tier": 3},
	# Tier 4 - City buildings
	{"id": "manor", "name": "Manor House", "width": 16, "height": 6, "depth": 14, "style": "stone", "tier": 4},
	{"id": "magic_shop", "name": "Magic Shop", "width": 8, "height": 5, "depth": 8, "style": "stone", "tier": 4, "is_shop": true, "shop_type": "magic"},
	{"id": "armorer", "name": "Armorer", "width": 10, "height": 4, "depth": 8, "style": "stone", "tier": 4, "is_shop": true, "shop_type": "armorer"},
	{"id": "barracks", "name": "Barracks", "width": 14, "height": 4, "depth": 10, "style": "stone", "tier": 4},
	# Tier 5 - Capital buildings
	{"id": "palace", "name": "Palace", "width": 24, "height": 10, "depth": 20, "style": "marble", "tier": 5},
	{"id": "cathedral", "name": "Cathedral", "width": 18, "height": 15, "depth": 25, "style": "stone", "tier": 5},
	{"id": "tower", "name": "Mage Tower", "width": 8, "height": 12, "depth": 8, "style": "stone", "tier": 5},
]

## Settlement tier mapping
const SETTLEMENT_TIERS: Dictionary = {
	"hamlet": 1,
	"village": 2,
	"town": 3,
	"city": 4,
	"capital": 5,
}

## Grid sizes per settlement type
const GRID_SIZES: Dictionary = {
	"hamlet": Vector2i(48, 48),
	"village": Vector2i(64, 64),
	"town": Vector2i(96, 96),
	"city": Vector2i(128, 128),
	"capital": Vector2i(160, 160),
}

## Building counts per settlement type
const BUILDING_COUNTS: Dictionary = {
	"hamlet": {"houses": 3, "shops": 1},
	"village": {"houses": 5, "shops": 2},
	"town": {"houses": 8, "shops": 4},
	"city": {"houses": 12, "shops": 6},
	"capital": {"houses": 18, "shops": 10},
}

## Props for decoration
const PROPS: Array[Dictionary] = [
	# Small props - can be placed close to buildings
	{"id": "barrel", "name": "Barrel", "width": 1.0, "depth": 1.0, "category": "small"},
	{"id": "crate", "name": "Crate", "width": 1.0, "depth": 1.0, "category": "small"},
	{"id": "crate_stack", "name": "Crate Stack", "width": 1.5, "depth": 1.5, "category": "small"},
	{"id": "bench", "name": "Bench", "width": 2.0, "depth": 0.5, "category": "small"},
	{"id": "hay_bale", "name": "Hay Bale", "width": 1.5, "depth": 1.5, "category": "small"},
	{"id": "woodpile", "name": "Wood Pile", "width": 2.0, "depth": 1.0, "category": "small"},
	{"id": "detail_barrel", "name": "Detail Barrel", "width": 1.0, "depth": 1.0, "category": "small"},
	{"id": "detail_crate", "name": "Detail Crate", "width": 1.0, "depth": 1.0, "category": "small"},
	{"id": "bricks", "name": "Bricks", "width": 1.0, "depth": 0.5, "category": "small"},
	# Medium props
	{"id": "cart", "name": "Cart", "width": 2.0, "depth": 3.0, "category": "medium"},
	{"id": "table", "name": "Table", "width": 2.0, "depth": 1.5, "category": "medium"},
	{"id": "hitching_post", "name": "Hitching Post", "width": 1.0, "depth": 3.0, "category": "medium"},
	{"id": "sign_post", "name": "Sign Post", "width": 0.5, "depth": 0.5, "category": "medium"},
	{"id": "anvil", "name": "Anvil", "width": 1.0, "depth": 1.5, "category": "medium"},
	# Trees and vegetation
	{"id": "tree_oak", "name": "Oak Tree", "width": 3.0, "depth": 3.0, "category": "tree"},
	{"id": "tree_pine", "name": "Pine Tree", "width": 2.0, "depth": 2.0, "category": "tree"},
	{"id": "tree_large", "name": "Large Tree", "width": 4.0, "depth": 4.0, "category": "tree"},
	{"id": "bush", "name": "Bush", "width": 1.5, "depth": 1.5, "category": "vegetation"},
	{"id": "tree_shrub", "name": "Shrub", "width": 1.0, "depth": 1.0, "category": "vegetation"},
]

## Prop counts per settlement type
const PROP_COUNTS: Dictionary = {
	"hamlet": {"small": 4, "medium": 2, "trees": 3, "vegetation": 2},
	"village": {"small": 8, "medium": 4, "trees": 5, "vegetation": 4},
	"town": {"small": 15, "medium": 6, "trees": 8, "vegetation": 6},
	"city": {"small": 25, "medium": 10, "trees": 12, "vegetation": 10},
	"capital": {"small": 40, "medium": 15, "trees": 20, "vegetation": 15},
}


## Generate a town and return LevelData
static func generate_town(
	settlement_type: String,
	seed_value: int,
	location_id: String = "",
	location_name: String = ""
) -> LevelEditorData.LevelData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var level_data := LevelEditorData.LevelData.new()
	level_data.level_type = "town"
	level_data.settlement_type = settlement_type
	level_data.grid_size = GRID_SIZES.get(settlement_type, Vector2i(64, 64))
	level_data.snap_size = 4.0
	level_data.level_id = location_id if not location_id.is_empty() else "generated_%d" % seed_value
	level_data.level_name = location_name if not location_name.is_empty() else _generate_name(rng)

	var tier: int = SETTLEMENT_TIERS.get(settlement_type, 2)
	var counts: Dictionary = BUILDING_COUNTS.get(settlement_type, {"houses": 5, "shops": 2})

	# Calculate bounds
	var half_x: float = level_data.grid_size.x / 2.0
	var half_z: float = level_data.grid_size.y / 2.0
	var margin: float = 8.0
	var bounds_min := Vector2(-half_x + margin, -half_z + margin)
	var bounds_max := Vector2(half_x - margin, half_z - margin)
	var center_exclusion: float = 8.0 + tier * 2.0

	# Get available buildings for this tier
	var available_shops: Array[Dictionary] = []
	var available_houses: Array[Dictionary] = []
	for b: Dictionary in BUILDINGS:
		if b.tier <= tier:
			if b.get("is_shop", false):
				available_shops.append(b)
			else:
				available_houses.append(b)

	# Place shops first (more important)
	_shuffle_array(rng, available_shops)
	var shops_placed: int = 0
	for shop_def: Dictionary in available_shops:
		if shops_placed >= counts.shops:
			break

		var pos := PlacementUtils.find_valid_position(
			rng,
			shop_def.width,
			shop_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			center_exclusion,
			4.0,
			30
		)

		if pos != Vector3.ZERO:
			var elem := _create_building_element(shop_def, pos, rng)
			level_data.elements.append(elem)
			shops_placed += 1

	# Place houses
	var houses_placed: int = 0
	for i in range(counts.houses * 2):  # Try more times than needed
		if houses_placed >= counts.houses:
			break

		# Pick a random house type appropriate for tier
		var house_def: Dictionary = available_houses[rng.randi() % available_houses.size()]

		var pos := PlacementUtils.find_valid_position(
			rng,
			house_def.width,
			house_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			center_exclusion,
			4.0,
			30
		)

		if pos != Vector3.ZERO:
			var elem := _create_building_element(house_def, pos, rng)
			level_data.elements.append(elem)
			houses_placed += 1

	# Add functional elements (spawn point, shrine, bounty board)
	_add_functional_elements(level_data, rng, tier)

	# Add decorative props (barrels, crates, trees, etc.)
	_add_props(level_data, rng, tier)

	return level_data


## Create a PlacedElement from a building definition
static func _create_building_element(
	building_def: Dictionary,
	pos: Vector3,
	rng: RandomNumberGenerator
) -> LevelEditorData.PlacedElement:
	var elem := LevelEditorData.PlacedElement.new()
	elem.element_type = LevelEditorData.ElementType.BUILDING
	elem.position = pos
	elem.rotation = Vector3(0, rng.randi_range(0, 3) * 90, 0)  # Random 90-degree rotation
	elem.scale = Vector3.ONE

	elem.properties = {
		"building_id": building_def.id,
		"building_name": building_def.name,
		"width": building_def.width,
		"height": building_def.height,
		"depth": building_def.depth,
		"style": building_def.style,
		"tier": building_def.tier,
	}

	if building_def.get("is_shop", false):
		elem.properties["is_shop"] = true
		elem.properties["shop_type"] = building_def.get("shop_type", "general")

	return elem


## Add spawn point, shrine, bounty board
static func _add_functional_elements(
	level_data: LevelEditorData.LevelData,
	rng: RandomNumberGenerator,
	tier: int
) -> void:
	# Spawn point at center
	var spawn := LevelEditorData.PlacedElement.new()
	spawn.element_type = LevelEditorData.ElementType.FUNCTIONAL
	spawn.position = Vector3(0, 0, 4)
	spawn.properties = {
		"func_type": "spawn_point",
		"spawn_id": "default"
	}
	level_data.elements.append(spawn)

	# Fast travel shrine (towns and larger)
	if tier >= 2:
		var shrine := LevelEditorData.PlacedElement.new()
		shrine.element_type = LevelEditorData.ElementType.FUNCTIONAL
		shrine.position = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
		shrine.properties = {
			"func_type": "fast_travel_shrine"
		}
		level_data.elements.append(shrine)

	# Bounty board (towns and larger)
	if tier >= 3:
		var board := LevelEditorData.PlacedElement.new()
		board.element_type = LevelEditorData.ElementType.FUNCTIONAL
		board.position = Vector3(6, 0, -3)
		board.properties = {
			"func_type": "bounty_board"
		}
		level_data.elements.append(board)


## Add decorative props (barrels, crates, trees, etc.)
static func _add_props(
	level_data: LevelEditorData.LevelData,
	rng: RandomNumberGenerator,
	tier: int
) -> void:
	var settlement_type: String = level_data.settlement_type
	var counts: Dictionary = PROP_COUNTS.get(settlement_type, {"small": 5, "medium": 2, "trees": 3, "vegetation": 2})

	# Calculate bounds with margin from edge
	var half_x: float = level_data.grid_size.x / 2.0
	var half_z: float = level_data.grid_size.y / 2.0
	var margin: float = 4.0
	var bounds_min := Vector2(-half_x + margin, -half_z + margin)
	var bounds_max := Vector2(half_x - margin, half_z - margin)

	# Filter props by category
	var small_props: Array[Dictionary] = []
	var medium_props: Array[Dictionary] = []
	var trees: Array[Dictionary] = []
	var vegetation: Array[Dictionary] = []

	for prop: Dictionary in PROPS:
		var cat: String = prop.get("category", "small")
		if cat == "small":
			small_props.append(prop)
		elif cat == "medium":
			medium_props.append(prop)
		elif cat == "tree":
			trees.append(prop)
		elif cat == "vegetation":
			vegetation.append(prop)

	# Place small props (barrels, crates, etc.)
	for i in range(counts.get("small", 5)):
		if small_props.is_empty():
			break
		var prop_def: Dictionary = small_props[rng.randi() % small_props.size()]
		var pos: Vector3 = PlacementUtils.find_valid_position(
			rng,
			prop_def.width,
			prop_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			2.0,  # Can be closer to center than buildings
			2.0,  # Smaller snap for props
			20
		)
		if pos != Vector3.ZERO:
			var elem: LevelEditorData.PlacedElement = _create_prop_element(prop_def, pos, rng)
			level_data.elements.append(elem)

	# Place medium props (carts, tables, etc.)
	for i in range(counts.get("medium", 2)):
		if medium_props.is_empty():
			break
		var prop_def: Dictionary = medium_props[rng.randi() % medium_props.size()]
		var pos: Vector3 = PlacementUtils.find_valid_position(
			rng,
			prop_def.width,
			prop_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			3.0,
			2.0,
			20
		)
		if pos != Vector3.ZERO:
			var elem: LevelEditorData.PlacedElement = _create_prop_element(prop_def, pos, rng)
			level_data.elements.append(elem)

	# Place trees (larger, more spacing needed)
	for i in range(counts.get("trees", 3)):
		if trees.is_empty():
			break
		var tree_def: Dictionary = trees[rng.randi() % trees.size()]
		var pos: Vector3 = PlacementUtils.find_valid_position(
			rng,
			tree_def.width,
			tree_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			5.0,  # Keep trees away from center
			4.0,  # Larger snap for trees
			20
		)
		if pos != Vector3.ZERO:
			var elem: LevelEditorData.PlacedElement = _create_prop_element(tree_def, pos, rng)
			level_data.elements.append(elem)

	# Place vegetation (bushes, shrubs)
	for i in range(counts.get("vegetation", 2)):
		if vegetation.is_empty():
			break
		var veg_def: Dictionary = vegetation[rng.randi() % vegetation.size()]
		var pos: Vector3 = PlacementUtils.find_valid_position(
			rng,
			veg_def.width,
			veg_def.depth,
			bounds_min,
			bounds_max,
			level_data.elements,
			2.0,
			2.0,
			20
		)
		if pos != Vector3.ZERO:
			var elem: LevelEditorData.PlacedElement = _create_prop_element(veg_def, pos, rng)
			level_data.elements.append(elem)


## Create a PlacedElement from a prop definition
static func _create_prop_element(
	prop_def: Dictionary,
	pos: Vector3,
	rng: RandomNumberGenerator
) -> LevelEditorData.PlacedElement:
	var elem := LevelEditorData.PlacedElement.new()
	elem.element_type = LevelEditorData.ElementType.PROP
	elem.position = pos
	elem.rotation = Vector3(0, rng.randi_range(0, 7) * 45, 0)  # Random 45-degree rotation
	elem.scale = Vector3.ONE

	elem.properties = {
		"prop_id": prop_def.id,
		"prop_name": prop_def.name,
		"width": prop_def.get("width", 1.0),
		"depth": prop_def.get("depth", 1.0),
		"category": prop_def.get("category", "small"),
	}
	return elem


## Shuffle array in place
static func _shuffle_array(rng: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var temp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = temp


## Generate a random town name
static func _generate_name(rng: RandomNumberGenerator) -> String:
	var prefixes: Array[String] = [
		"Oak", "River", "Stone", "Green", "High", "Low", "North", "South",
		"East", "West", "Red", "White", "Black", "Gold", "Silver", "Iron"
	]
	var suffixes: Array[String] = [
		"wood", "brook", "ford", "field", "vale", "dale", "holm", "ton",
		"bury", "bridge", "haven", "keep", "hold", "watch", "gate", "well"
	]
	return prefixes[rng.randi() % prefixes.size()] + suffixes[rng.randi() % suffixes.size()]


## Save generated town to JSON file
static func save_to_file(level_data: LevelEditorData.LevelData, path: String) -> Error:
	var json_str: String = level_data.to_json()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(json_str)
	file.close()
	return OK


## Regenerate all test towns with proper collision detection
static func regenerate_test_towns() -> Dictionary:
	var results: Dictionary = {}
	var base_path := "res://scenes/levels/town editor towns/"

	# Define test towns to regenerate (v2 versions)
	# Note: Dalhurst and Elder Moor are hand-crafted and NOT regenerated
	var towns: Array[Dictionary] = [
		{"name": "Thornfield", "file": "thornfield.json", "type": "village", "seed": 12345},
		{"name": "Millbrook", "file": "millbrook.json", "type": "village", "seed": 67890},
		{"name": "Aberdeen", "file": "aberdeen.json", "type": "town", "seed": 11111},
		{"name": "Larton", "file": "larton.json", "type": "hamlet", "seed": 22222},
		{"name": "Pirate Cove", "file": "pirate_cove.json", "type": "village", "seed": 33333},
		{"name": "Elven Sanctuary", "file": "elven_sanctuary.json", "type": "town", "seed": 44444},
		{"name": "Combat Arena", "file": "combat_arena.json", "type": "town", "seed": 55555},
	]

	for town: Dictionary in towns:
		var level_data := generate_town(
			town.type,
			town.seed,
			town.name.to_lower().replace(" ", "_"),
			town.name
		)

		var full_path: String = base_path + town.file
		var err := save_to_file(level_data, full_path)

		results[town.name] = {
			"success": err == OK,
			"path": full_path,
			"element_count": level_data.elements.size()
		}

	return results
