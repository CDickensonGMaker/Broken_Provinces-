extends Node
## WorldForgeImporter - Runtime importer for World Forge map data
## Loads JSON data exported from the World Forge editor and applies it to WorldGrid

const FORGE_MAP_PATH := "user://world_forge_map.json"

## Biome to terrain mapping
const BIOME_TO_TERRAIN: Dictionary = {
	"plains": 7,   # WorldGrid.Terrain.POI (used for general passable terrain)
	"forest": 2,   # WorldGrid.Terrain.FOREST
	"swamp": 5,    # WorldGrid.Terrain.SWAMP
	"tundra": 1,   # WorldGrid.Terrain.HIGHLANDS
	"desert": 8,   # WorldGrid.Terrain.DESERT
	"badlands": 1, # WorldGrid.Terrain.HIGHLANDS
}

## Elevation to terrain mapping (overrides biome)
const ELEVATION_TO_TERRAIN: Dictionary = {
	"mountain": 0, # WorldGrid.Terrain.BLOCKED
	"hill": 1,     # WorldGrid.Terrain.HIGHLANDS
}

## Water to terrain mapping (overrides biome and elevation)
const WATER_TO_TERRAIN: Dictionary = {
	"ocean": 3,    # WorldGrid.Terrain.WATER
	"lake": 3,     # WorldGrid.Terrain.WATER
	"river": 4,    # WorldGrid.Terrain.COAST
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

	# Attempt to preload forge data if file exists
	if not _preload_attempted:
		_preload_attempted = true
		if FileAccess.file_exists(FORGE_MAP_PATH):
			var data: Dictionary = load_from_file(FORGE_MAP_PATH)
			if not data.is_empty():
				print("[WorldForgeImporter] Preloaded forge map data")


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

	var biome_layer: Array = layers.get("biome", [])
	var elevation_layer: Array = layers.get("elevation", [])
	var water_layer: Array = layers.get("water", [])
	var poi_layer: Array = layers.get("poi", [])

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

			# Apply biome (base terrain)
			if index < biome_layer.size() and biome_layer[index] != null:
				var biome_val: String = biome_layer[index]
				var terrain_int: int = BIOME_TO_TERRAIN.get(biome_val, -1)
				if terrain_int >= 0:
					cell.terrain = terrain_int
					was_modified = true

			# Apply elevation (overrides biome for mountains/hills)
			if index < elevation_layer.size() and elevation_layer[index] != null:
				var elev_val: String = elevation_layer[index]
				var terrain_int: int = ELEVATION_TO_TERRAIN.get(elev_val, -1)
				if terrain_int >= 0:
					cell.terrain = terrain_int
					was_modified = true

			# Apply water (overrides everything)
			if index < water_layer.size() and water_layer[index] != null:
				var water_val: String = water_layer[index]
				var terrain_int: int = WATER_TO_TERRAIN.get(water_val, -1)
				if terrain_int >= 0:
					cell.terrain = terrain_int
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
		print("[WorldForgeImporter] Applied %d cell modifications from forge map" % count)
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
			print("# No forge data loaded")
			return

	var poi_data: Dictionary = _loaded_data.get("poi_data", {})
	if poi_data.is_empty():
		print("# No POI data to patch")
		return

	var origin_info: Dictionary = _loaded_data.get("editor_origin", {})
	var origin := Vector2i(origin_info.get("x", 32), origin_info.get("y", 32))

	print("# ========== WorldForge Patch ==========")
	print("# Add/modify these entries in the LOCATIONS array:")
	print("")

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

		print('\t{"id": "%s", "name": "%s", "x": %d, "y": %d, "type": "%s",' % [id_str, name_str, world_coords.x, world_coords.y, type_str])
		print('\t "description": "%s"},' % desc_str)

	print("")
	print("# ========== End Patch ==========")


## Clear loaded data
func clear() -> void:
	_loaded_data.clear()
	_is_loaded = false
