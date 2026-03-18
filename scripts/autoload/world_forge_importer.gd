extends Node
## WorldForgeImporter - Runtime importer for World Forge map data
## Loads JSON data exported from the World Forge editor and applies it to WorldGrid

const FORGE_MAP_PATH := "user://world_forge_map.json"

## Unified terrain to WorldGrid terrain mapping (new format)
const TERRAIN_TO_WORLDGRID: Dictionary = {
	# Biomes
	"plains": 7,   # WorldGrid.Terrain.POI (used for general passable terrain)
	"forest": 2,   # WorldGrid.Terrain.FOREST
	"swamp": 5,    # WorldGrid.Terrain.SWAMP
	"tundra": 1,   # WorldGrid.Terrain.HIGHLANDS
	"desert": 8,   # WorldGrid.Terrain.DESERT
	"badlands": 1, # WorldGrid.Terrain.HIGHLANDS
	# Elevation
	"hill": 1,     # WorldGrid.Terrain.HIGHLANDS
	"mountain": 0, # WorldGrid.Terrain.BLOCKED
	# Water
	"ocean": 3,    # WorldGrid.Terrain.WATER
	"lake": 3,     # WorldGrid.Terrain.WATER
	"river": 4,    # WorldGrid.Terrain.COAST
}

## Road types (for reference, roads overlay terrain)
const ROAD_TYPES: Array[String] = ["dirt_road", "stone_road", "cobblestone", "path", "bridge"]

## Legacy mappings for old format compatibility
const BIOME_TO_TERRAIN: Dictionary = {
	"plains": 7, "forest": 2, "swamp": 5, "tundra": 1, "desert": 8, "badlands": 1,
}
const ELEVATION_TO_TERRAIN: Dictionary = {
	"mountain": 0, "hill": 1,
}
const WATER_TO_TERRAIN: Dictionary = {
	"ocean": 3, "lake": 3, "river": 4,
}

## POI type to LocationType mapping
const POI_TO_LOCATION_TYPE: Dictionary = {
	"town": 2,      # WorldGrid.LocationType.TOWN
	"village": 1,   # WorldGrid.LocationType.VILLAGE
	"city": 3,      # WorldGrid.LocationType.CITY
	"capital": 4,   # WorldGrid.LocationType.CAPITAL
	"dungeon": 5,   # WorldGrid.LocationType.DUNGEON
	"landmark": 6,  # WorldGrid.LocationType.LANDMARK
	"outpost": 8,   # WorldGrid.LocationType.OUTPOST
	"cave": 5,      # WorldGrid.LocationType.DUNGEON (treat caves as dungeons)
	"ruins": 5,     # WorldGrid.LocationType.DUNGEON (treat ruins as dungeons)
	"shrine": 6,    # WorldGrid.LocationType.LANDMARK
}

var _loaded_data: Dictionary = {}
var _is_loaded: bool = false
var _preload_attempted: bool = false


func _ready() -> void:
	# Don't auto-load in editor
	if Engine.is_editor_hint():
		return

	# Automatically load and apply forge map if it exists
	if not _preload_attempted:
		_preload_attempted = true
		if FileAccess.file_exists(FORGE_MAP_PATH):
			var data: Dictionary = load_from_file(FORGE_MAP_PATH)
			if not data.is_empty():
				# Wait for WorldGrid to initialize first
				await get_tree().process_frame
				var count: int = apply_to_world_grid(data)


## Check if a forge map file exists
func forge_map_exists() -> bool:
	return FileAccess.file_exists(FORGE_MAP_PATH)


## Load forge map data from file
func load_from_file(path: String = FORGE_MAP_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[WorldForgeImporter] Failed to open file: %s" % path)
		return {}

	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_str)
	if error != OK:
		push_error("[WorldForgeImporter] Failed to parse JSON: %s" % json.get_error_message())
		return {}

	if not json.data is Dictionary:
		push_error("[WorldForgeImporter] JSON data is not a Dictionary")
		return {}
	_loaded_data = json.data
	_is_loaded = true
	return _loaded_data


## Convert editor coordinates to world coordinates
func editor_to_world(editor_x: int, editor_y: int, origin: Vector2i) -> Vector2i:
	return Vector2i(editor_x - origin.x, editor_y - origin.y)


## Convert world coordinates to editor coordinates
func world_to_editor(world_x: int, world_y: int, origin: Vector2i) -> Vector2i:
	return Vector2i(world_x + origin.x, world_y + origin.y)


## Apply loaded forge data to WorldGrid
## Returns the number of cells modified
func apply_to_world_grid(data: Dictionary) -> int:
	if data.is_empty():
		return 0

	var modified_count: int = 0

	var grid_info: Dictionary = data.get("grid", {})
	var grid_width: int = grid_info.get("width", 64)
	var grid_height: int = grid_info.get("height", 64)

	var origin_info: Dictionary = data.get("editor_origin", {})
	var origin := Vector2i(origin_info.get("x", 32), origin_info.get("y", 32))

	var layers: Dictionary = data.get("layers", {})
	var poi_data: Dictionary = data.get("poi_data", {})

	# Detect format: new format has "terrain" layer, old format has "biome" layer
	var is_new_format: bool = layers.has("terrain")

	var terrain_layer: Array = []
	var road_layer: Array = []
	var poi_layer: Array = []

	if is_new_format:
		# New format: terrain, road, poi
		terrain_layer = layers.get("terrain", [])
		road_layer = layers.get("road", [])
		poi_layer = layers.get("poi", [])
	else:
		# Old format: biome, elevation, water, poi
		var biome_layer: Array = layers.get("biome", [])
		var elevation_layer: Array = layers.get("elevation", [])
		var water_layer: Array = layers.get("water", [])
		poi_layer = layers.get("poi", [])

		# Merge old layers into terrain layer
		terrain_layer.resize(grid_width * grid_height)
		for i: int in range(terrain_layer.size()):
			# Start with biome
			if i < biome_layer.size() and biome_layer[i] != null:
				terrain_layer[i] = biome_layer[i]
			# Elevation overrides
			if i < elevation_layer.size() and elevation_layer[i] != null:
				terrain_layer[i] = elevation_layer[i]
			# Water overrides everything
			if i < water_layer.size() and water_layer[i] != null:
				terrain_layer[i] = water_layer[i]

	# Process each cell
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var index: int = y * grid_width + x
			var world_coords := editor_to_world(x, y, origin)

			# Check if WorldGrid has this cell
			if not WorldGrid.is_in_bounds(world_coords):
				continue

			var cell: WorldGrid.CellInfo = WorldGrid.get_cell(world_coords)
			if not cell:
				continue

			var was_modified: bool = false

			# Apply terrain
			if index < terrain_layer.size() and terrain_layer[index] != null:
				var terrain_val: String = terrain_layer[index]
				var terrain_int: int = TERRAIN_TO_WORLDGRID.get(terrain_val, -1)
				if terrain_int >= 0:
					cell.terrain = terrain_int
					was_modified = true

			# Apply road (marks cell as road)
			if index < road_layer.size() and road_layer[index] != null:
				cell.is_road = true
				# Roads are always passable
				cell.terrain = WorldGrid.Terrain.ROAD
				was_modified = true

			# Apply POI
			if index < poi_layer.size() and poi_layer[index] != null:
				var poi_val: String = poi_layer[index]
				var poi_info: Dictionary = poi_data.get(str(index), {})

				var loc_type_int: int = POI_TO_LOCATION_TYPE.get(poi_val, 0)
				cell.location_type = loc_type_int

				# Apply POI data
				if not poi_info.is_empty():
					cell.location_name = poi_info.get("name", "")
					cell.location_id = poi_info.get("location_id", "")
					cell.description = poi_info.get("notes", "")

					var scene_path: String = poi_info.get("scene_path", "")
					if not scene_path.is_empty():
						cell.scene_path = scene_path

					# Register location
					if not cell.location_id.is_empty():
						WorldGrid.locations[cell.location_id] = world_coords

				was_modified = true

			# Update passability based on terrain
			if was_modified:
				cell.passable = (cell.terrain != WorldGrid.Terrain.BLOCKED and cell.terrain != WorldGrid.Terrain.WATER)
				modified_count += 1

	return modified_count


## Main entry point - load and apply forge map
func import_and_apply(path: String = FORGE_MAP_PATH) -> bool:
	var data := load_from_file(path)
	if data.is_empty():
		return false

	var count := apply_to_world_grid(data)
	if count > 0:
		return true

	return false


## Get the loaded data (for debugging)
func get_loaded_data() -> Dictionary:
	return _loaded_data


## Print GDScript code to bake forge changes into WorldGrid
## Call this from the debugger to get code that can be pasted into world_grid.gd
func print_gdscript_patch() -> void:
	if _loaded_data.is_empty():
		if not load_from_file():
			return

	var poi_data: Dictionary = _loaded_data.get("poi_data", {})
	if poi_data.is_empty():
		return

	var origin_info: Dictionary = _loaded_data.get("editor_origin", {})
	var origin := Vector2i(origin_info.get("x", 32), origin_info.get("y", 32))

	for key: String in poi_data:
		var poi: Dictionary = poi_data[key]
		var name_str: String = poi.get("name", "")
		if name_str.is_empty():
			continue

		var editor_x: int = poi.get("x", 0)
		var editor_y: int = poi.get("y", 0)
		var world_coords := editor_to_world(editor_x, editor_y, origin)

		var id_str: String = poi.get("location_id", name_str.to_snake_case())
		var type_str: String = poi.get("type", "landmark")
		var desc_str: String = poi.get("notes", "")
		var scene_str: String = poi.get("scene_path", "")


## Clear loaded data
func clear() -> void:
	_loaded_data.clear()
	_is_loaded = false
