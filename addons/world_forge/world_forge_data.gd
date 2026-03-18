@tool
class_name WorldForgeData
extends RefCounted
## Data structures for the World Forge editor state

## Layer value definitions
const TERRAIN_VALUES: Array[String] = [
	"plains", "forest", "swamp", "tundra", "desert", "badlands",
	"hill", "mountain",
	"ocean", "lake", "river"
]

const ROAD_VALUES: Array[String] = [
	"dirt_road", "stone_road", "cobblestone", "path", "bridge"
]

const POI_VALUES: Array[String] = ["town", "village", "city", "capital", "dungeon", "landmark", "outpost", "cave", "ruins", "shrine", "fortress", "port", "camp", "bridge"]

## Layer colors for rendering
const LAYER_COLORS: Dictionary = {
	"terrain": {
		# Land biomes
		"plains": Color(0.55, 0.70, 0.38),
		"forest": Color(0.24, 0.42, 0.19),
		"swamp": Color(0.18, 0.29, 0.16),
		"tundra": Color(0.63, 0.78, 0.82),
		"desert": Color(0.83, 0.72, 0.59),
		"badlands": Color(0.55, 0.27, 0.07),
		# Elevation
		"hill": Color(0.6, 0.5, 0.4),
		"mountain": Color(0.3, 0.3, 0.35),
		# Water
		"ocean": Color(0.2, 0.35, 0.6),
		"lake": Color(0.25, 0.45, 0.7),
		"river": Color(0.3, 0.5, 0.75)
	},
	"road": {
		"dirt_road": Color(0.55, 0.45, 0.35),
		"stone_road": Color(0.5, 0.5, 0.5),
		"cobblestone": Color(0.45, 0.45, 0.48),
		"path": Color(0.6, 0.5, 0.4),
		"bridge": Color(0.5, 0.4, 0.3)
	},
	"poi": {
		"town": Color(0.9, 0.75, 0.4),
		"village": Color(0.8, 0.7, 0.5),
		"city": Color(0.95, 0.85, 0.3),
		"capital": Color(1.0, 0.9, 0.2),
		"dungeon": Color(0.6, 0.2, 0.2),
		"landmark": Color(0.7, 0.7, 0.3),
		"outpost": Color(0.5, 0.5, 0.3),
		"cave": Color(0.4, 0.35, 0.3),
		"ruins": Color(0.5, 0.45, 0.4),
		"shrine": Color(0.6, 0.5, 0.7),
		"fortress": Color(0.4, 0.4, 0.5),
		"port": Color(0.3, 0.5, 0.7),
		"camp": Color(0.6, 0.4, 0.3),
		"bridge": Color(0.5, 0.45, 0.35)
	}
}

## POI icons (Unicode symbols for now)
const POI_ICONS: Dictionary = {
	"town": "T",
	"village": "v",
	"city": "C",
	"capital": "K",
	"dungeon": "D",
	"landmark": "L",
	"outpost": "O",
	"cave": "c",
	"ruins": "R",
	"shrine": "S",
	"fortress": "F",
	"port": "P",
	"camp": "^",
	"bridge": "="
}


## Map state container - the actual data being edited
class MapState:
	var version: int = 1
	var grid_width: int = 64
	var grid_height: int = 64
	var origin: Vector2i = Vector2i(32, 32)
	var layers: Dictionary = {
		"terrain": [],
		"road": [],
		"poi": []
	}
	var poi_data: Dictionary = {}  # String(index) -> Dictionary {name, type, notes, x, y, scene_path, layout_path, location_id}

	func _init() -> void:
		_init_layers()

	func _init_layers() -> void:
		var total_cells: int = grid_width * grid_height
		for layer_name: String in layers.keys():
			layers[layer_name] = []
			layers[layer_name].resize(total_cells)
			for i: int in range(total_cells):
				layers[layer_name][i] = null

	func get_cell_index(x: int, y: int) -> int:
		return y * grid_width + x

	func get_cell_coords(index: int) -> Vector2i:
		return Vector2i(index % grid_width, index / grid_width)

	func set_layer_value(layer: String, x: int, y: int, value: Variant) -> void:
		if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
			return
		var index: int = get_cell_index(x, y)
		if layers.has(layer) and index >= 0 and index < layers[layer].size():
			layers[layer][index] = value

	func get_layer_value(layer: String, x: int, y: int) -> Variant:
		if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
			return null
		var index: int = get_cell_index(x, y)
		if layers.has(layer) and index >= 0 and index < layers[layer].size():
			return layers[layer][index]
		return null

	func clear_all() -> void:
		_init_layers()
		poi_data.clear()

	func to_dict() -> Dictionary:
		return {
			"version": version,
			"editor_origin": {"x": origin.x, "y": origin.y},
			"grid": {"width": grid_width, "height": grid_height},
			"layers": layers.duplicate(true),
			"poi_data": poi_data.duplicate(true)
		}

	func from_dict(data: Dictionary) -> void:
		version = data.get("version", 1)
		var grid_data: Dictionary = data.get("grid", {})
		grid_width = grid_data.get("width", 64)
		grid_height = grid_data.get("height", 64)
		var origin_data: Dictionary = data.get("editor_origin", {})
		origin = Vector2i(origin_data.get("x", 32), origin_data.get("y", 32))

		var loaded_layers: Dictionary = data.get("layers", {})
		_init_layers()

		# Check if this is old format (has biome/elevation/water) or new format (has terrain/road)
		var is_old_format: bool = loaded_layers.has("biome") and not loaded_layers.has("terrain")

		if is_old_format:
			# Migrate old format: merge biome/elevation/water into terrain
			var biome_array: Array = loaded_layers.get("biome", [])
			var elevation_array: Array = loaded_layers.get("elevation", [])
			var water_array: Array = loaded_layers.get("water", [])
			var poi_array: Array = loaded_layers.get("poi", [])

			# Map old elevation values to terrain values
			var elevation_to_terrain: Dictionary = {
				"hill": "hill",
				"mountain": "mountain"
			}

			# Map old water values to terrain values
			var water_to_terrain: Dictionary = {
				"ocean": "ocean",
				"lake": "lake",
				"river": "river"
			}

			# Build terrain layer: start with biome, overlay elevation, overlay water
			for i: int in range(mini(biome_array.size(), layers["terrain"].size())):
				var terrain_val: Variant = biome_array[i]

				# Elevation overwrites biome (hill, mountain)
				if i < elevation_array.size() and elevation_array[i] != null:
					var elev_val: Variant = elevation_array[i]
					if elev_val in elevation_to_terrain:
						terrain_val = elevation_to_terrain[elev_val]

				# Water overwrites everything (ocean, lake, river)
				if i < water_array.size() and water_array[i] != null:
					var water_val: Variant = water_array[i]
					if water_val in water_to_terrain:
						terrain_val = water_to_terrain[water_val]

				layers["terrain"][i] = terrain_val

			# POI layer stays the same
			for i: int in range(mini(poi_array.size(), layers["poi"].size())):
				layers["poi"][i] = poi_array[i]

			# Road layer starts empty (old format didn't have painted roads)
		else:
			# New format: load layers directly
			for layer_name: String in loaded_layers.keys():
				if layers.has(layer_name):
					var loaded_array: Array = loaded_layers[layer_name]
					for i: int in range(mini(loaded_array.size(), layers[layer_name].size())):
						layers[layer_name][i] = loaded_array[i]

		poi_data = data.get("poi_data", {}).duplicate(true)


## Editor state container - UI/tool state
class EditorState:
	var current_layer: String = "terrain"
	var current_brush: String = "forest"
	var brush_size: int = 1
	var is_eraser: bool = false
	var selected_poi_index: int = -1
	var dragging_poi: bool = false
	var drag_start_cell: Vector2i = Vector2i(-1, -1)
	var zoom: float = 1.0
	var pan_offset: Vector2 = Vector2.ZERO
	var layer_visibility: Dictionary = {
		"terrain": true,
		"road": true,
		"poi": true
	}
	var show_grid: bool = true
	var show_origin: bool = true
	var show_roads: bool = true  # Deprecated, use layer_visibility["road"]
