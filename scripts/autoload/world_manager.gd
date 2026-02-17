## world_manager.gd - Manages world state, location discovery, and region tracking
## Simplified for region-based world design (no chunk streaming)
extends Node

signal location_discovered(location_id: String, location_name: String, location_type: int)
signal region_entered(region_name: String)
signal cell_entered(coords: Vector2i, cell_data: WorldData.CellData)

## Discovered locations (location_id -> discovery data)
## Separate from WorldData.CellData.discovered for richer tracking
var discovered_locations: Dictionary = {}  # location_id -> {name, type, coords, discovered_time}

## Current player location tracking
var current_cell: Vector2i = Vector2i.ZERO
var current_region: String = ""
var current_location_id: String = ""

## Travel statistics (for achievements/stats)
var cells_traveled: int = 0
var locations_visited: int = 0


func _ready() -> void:
	# Ensure WorldData is initialized
	if WorldData.world_grid.is_empty():
		WorldData.initialize()

	# Auto-discover starting location
	discover_location_at(Vector2i.ZERO)


## Discover a location by its ID
func discover_location(location_id: String) -> void:
	if location_id.is_empty():
		return
	if discovered_locations.has(location_id):
		return  # Already discovered

	# Find location in world grid
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			_register_discovery(location_id, cell.location_name, cell.location_type, coords)
			WorldData.discover_cell(coords)
			return


## Discover location at specific coordinates
func discover_location_at(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	# Always mark cell as discovered
	WorldData.discover_cell(coords)

	# If cell has a location, register it
	if not cell.location_id.is_empty() and not discovered_locations.has(cell.location_id):
		_register_discovery(cell.location_id, cell.location_name, cell.location_type, coords)


## Internal: Register a discovery
func _register_discovery(location_id: String, location_name: String, location_type: int, coords: Vector2i) -> void:
	discovered_locations[location_id] = {
		"name": location_name,
		"type": location_type,
		"coords": coords,
		"discovered_time": Time.get_unix_time_from_system()
	}
	locations_visited += 1
	location_discovered.emit(location_id, location_name, location_type)


## Check if a location is discovered
func is_location_discovered(location_id: String) -> bool:
	return discovered_locations.has(location_id)


## Check if coordinates are discovered
func is_cell_discovered(coords: Vector2i) -> bool:
	return WorldData.is_discovered(coords)


## Get all discovered locations
func get_discovered_locations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		result.append({
			"id": loc_id,
			"name": data.get("name", "Unknown"),
			"type": data.get("type", 0),
			"coords": _extract_coords(data.get("coords", Vector2i.ZERO))
		})
	return result


## Get discovered locations in a specific region
func get_discovered_in_region(region_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		var coords: Vector2i = _extract_coords(data.get("coords", Vector2i.ZERO))
		var cell: WorldData.CellData = WorldData.get_cell(coords)
		if cell and cell.region_name == region_name:
			result.append({
				"id": loc_id,
				"name": data.get("name", "Unknown"),
				"type": data.get("type", 0),
				"coords": coords
			})
	return result


## Get discovered locations by type (settlements, dungeons, etc.)
func get_discovered_by_type(location_type: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for loc_id: String in discovered_locations:
		var data: Dictionary = discovered_locations[loc_id]
		if data.get("type", 0) == location_type:
			result.append({
				"id": loc_id,
				"name": data.get("name", "Unknown"),
				"coords": _extract_coords(data.get("coords", Vector2i.ZERO))
			})
	return result


## Called when player enters a new cell/region
func on_cell_entered(coords: Vector2i) -> void:
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if not cell:
		return

	cells_traveled += 1
	current_cell = coords

	# Check for region change
	if cell.region_name != current_region:
		current_region = cell.region_name
		region_entered.emit(current_region)

	# Auto-discover cell and location
	discover_location_at(coords)

	# Update current location
	current_location_id = cell.location_id

	cell_entered.emit(coords, cell)


## Get location name by ID
func get_location_name(location_id: String) -> String:
	if discovered_locations.has(location_id):
		return discovered_locations[location_id].name

	# Search in world data
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			return cell.location_name

	return "Unknown Location"


## Helper to safely extract Vector2i coords from save data (handles Dict, Vector2i, or String)
func _extract_coords(coords_raw) -> Vector2i:
	if coords_raw is Vector2i:
		return coords_raw
	elif coords_raw is Dictionary:
		return Vector2i(coords_raw.get("x", 0), coords_raw.get("y", 0))
	return Vector2i.ZERO


## Get location coordinates by ID
func get_location_coords(location_id: String) -> Vector2i:
	if discovered_locations.has(location_id):
		var loc_data: Dictionary = discovered_locations[location_id]
		return _extract_coords(loc_data.get("coords", Vector2i.ZERO))

	# Search in world data
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		if cell.location_id == location_id:
			return coords

	return Vector2i.ZERO


## Get location region by ID
func get_location_region(location_id: String) -> String:
	var coords: Vector2i = get_location_coords(location_id)
	var cell: WorldData.CellData = WorldData.get_cell(coords)
	if cell:
		return cell.region_name
	return ""


## Calculate distance between two locations (in cells)
func get_distance(from_id: String, to_id: String) -> int:
	var from_coords := get_location_coords(from_id)
	var to_coords := get_location_coords(to_id)
	# Manhattan distance for grid-based world
	return absi(to_coords.x - from_coords.x) + absi(to_coords.y - from_coords.y)


## Get distance from current location
func get_distance_from_current(location_id: String) -> int:
	var to_coords := get_location_coords(location_id)
	return absi(to_coords.x - current_cell.x) + absi(to_coords.y - current_cell.y)


## Get current region name
func get_current_region() -> String:
	return current_region


## Get current location ID
func get_current_location_id() -> String:
	return current_location_id


## Serialize for saving
func to_dict() -> Dictionary:
	# Also save WorldData discovered cells
	var discovered_cells: Array[Dictionary] = []
	for coords: Vector2i in WorldData.get_discovered_cells():
		discovered_cells.append({"x": coords.x, "y": coords.y})

	# Convert discovered_locations coords from Vector2i to Dictionary for JSON
	var locations_for_save: Dictionary = {}
	for loc_id: String in discovered_locations:
		var loc_data: Dictionary = discovered_locations[loc_id]
		var coords_val = loc_data.get("coords", Vector2i.ZERO)
		var coords_dict: Dictionary = {"x": 0, "y": 0}
		if coords_val is Vector2i:
			coords_dict = {"x": coords_val.x, "y": coords_val.y}
		elif coords_val is Dictionary:
			coords_dict = coords_val
		locations_for_save[loc_id] = {
			"name": loc_data.get("name", "Unknown"),
			"type": loc_data.get("type", 0),
			"coords": coords_dict,
			"discovered_time": loc_data.get("discovered_time", 0)
		}

	return {
		"discovered_locations": locations_for_save,
		"discovered_cells": discovered_cells,
		"current_cell": {"x": current_cell.x, "y": current_cell.y},
		"current_region": current_region,
		"current_location_id": current_location_id,
		"cells_traveled": cells_traveled,
		"locations_visited": locations_visited
	}


## Deserialize from save
func from_dict(data: Dictionary) -> void:
	discovered_locations = data.get("discovered_locations", {}).duplicate(true)

	# Restore current state
	var cell_data: Dictionary = data.get("current_cell", {"x": 0, "y": 0})
	current_cell = Vector2i(cell_data.get("x", 0), cell_data.get("y", 0))
	current_region = data.get("current_region", "")
	current_location_id = data.get("current_location_id", "")
	cells_traveled = data.get("cells_traveled", 0)
	locations_visited = data.get("locations_visited", 0)

	# Restore WorldData discovered cells
	var discovered_cells: Array = data.get("discovered_cells", [])
	for cell_dict: Dictionary in discovered_cells:
		var coords := Vector2i(cell_dict.get("x", 0), cell_dict.get("y", 0))
		WorldData.discover_cell(coords)

	# Also restore from discovered_locations (for compatibility)
	for loc_id: String in discovered_locations:
		var loc_data: Dictionary = discovered_locations[loc_id]
		if loc_data.has("coords"):
			var coords: Vector2i = _extract_coords(loc_data.get("coords"))
			WorldData.discover_cell(coords)


## Reset for new game
func reset_for_new_game() -> void:
	discovered_locations.clear()
	current_cell = Vector2i.ZERO
	current_region = ""
	current_location_id = ""
	cells_traveled = 0
	locations_visited = 0

	# Reset WorldData discovered flags
	for coords: Vector2i in WorldData.world_grid:
		var cell: WorldData.CellData = WorldData.world_grid[coords]
		cell.discovered = false

	# Auto-discover starting location
	discover_location_at(Vector2i.ZERO)
