## cave_manager.gd - CaveManager autoload for tracking cave areas, spawns, and visited state
## Mirrors HandCraftedDungeon patterns but designed for organic cave systems
## NOTE: Do NOT add class_name - this is an autoload and class_name conflicts with the singleton
extends Node

## Maximum enemies allowed in entire cave
const MAX_CAVE_ENEMIES: int = 15

## How often to check which area player is in (seconds)
const AREA_CHECK_INTERVAL: float = 0.5

## Distance from area center to be considered "inside" that area
const DEFAULT_AREA_RADIUS: float = 10.0

## Cave area types
enum CaveAreaType {
	ENTRANCE,      ## Safe zone, no enemies
	PASSAGE,       ## Narrow corridor, 0-1 enemies
	JUNCTION,      ## Intersection, 1-2 enemies
	CHAMBER,       ## Large room, 2-4 enemies
	TREASURE_ROOM, ## Loot room, 1-2 enemies, guaranteed chest
	EXIT           ## Exit zone, no enemies
}

## Default spawn configuration per area type
const DEFAULT_SPAWN_CONFIGS: Dictionary = {
	CaveAreaType.ENTRANCE: {"enemy_max": 0, "chest_chance": 0.0, "prop_density": 0.2},
	CaveAreaType.PASSAGE: {"enemy_max": 1, "chest_chance": 0.0, "prop_density": 0.3},
	CaveAreaType.JUNCTION: {"enemy_max": 2, "chest_chance": 0.1, "prop_density": 0.3},
	CaveAreaType.CHAMBER: {"enemy_max": 4, "chest_chance": 0.3, "prop_density": 0.5},
	CaveAreaType.TREASURE_ROOM: {"enemy_max": 2, "chest_chance": 1.0, "prop_density": 0.4},
	CaveAreaType.EXIT: {"enemy_max": 0, "chest_chance": 0.0, "prop_density": 0.2},
}


## Inner class representing a cave area
class CaveArea extends RefCounted:
	var area_id: String = ""
	var center: Vector3 = Vector3.ZERO
	var radius: float = DEFAULT_AREA_RADIUS
	var area_type: int = CaveAreaType.PASSAGE  ## Using int for CaveAreaType enum
	var spawn_config: Dictionary = {}
	var is_visited: bool = false
	var visit_timestamp: float = 0.0

	func _init(p_id: String = "", p_center: Vector3 = Vector3.ZERO, p_type: int = CaveAreaType.PASSAGE) -> void:
		area_id = p_id
		center = p_center
		area_type = p_type
		spawn_config = DEFAULT_SPAWN_CONFIGS.get(p_type, {}).duplicate()

	func contains_point(point: Vector3) -> bool:
		var distance: float = center.distance_to(Vector3(point.x, center.y, point.z))
		return distance <= radius

	func to_dict() -> Dictionary:
		return {
			"area_id": area_id,
			"center": {"x": center.x, "y": center.y, "z": center.z},
			"radius": radius,
			"area_type": area_type,
			"is_visited": is_visited,
			"visit_timestamp": visit_timestamp
		}

	static func from_dict(data: Dictionary) -> CaveArea:
		var area := CaveArea.new()
		area.area_id = data.get("area_id", "")
		var c: Dictionary = data.get("center", {})
		area.center = Vector3(c.get("x", 0.0), c.get("y", 0.0), c.get("z", 0.0))
		area.radius = data.get("radius", DEFAULT_AREA_RADIUS)
		area.area_type = data.get("area_type", CaveAreaType.PASSAGE)
		area.is_visited = data.get("is_visited", false)
		area.visit_timestamp = data.get("visit_timestamp", 0.0)
		area.spawn_config = DEFAULT_SPAWN_CONFIGS.get(area.area_type, {}).duplicate()
		return area


## Signals
signal cave_entered(cave_id: String)
signal cave_exited(cave_id: String)
signal area_changed(old_area: String, new_area: String)
signal area_discovered(area_id: String)
signal enemy_count_changed(count: int)


## Active cave tracking
var active_cave_id: String = ""
var cave_root: Node3D = null
var cave_faction: String = "natural"  ## Default enemy faction
var cave_danger_level: int = 3  ## 1-10 scale

## Area management
var area_data: Dictionary = {}  ## area_id -> CaveArea
var visited_areas: Dictionary = {}  ## area_id -> timestamp
var current_area_id: String = ""

## Enemy management
var _area_enemies: Dictionary = {}  ## area_id -> Array[Node]
var _active_enemy_count: int = 0

## Navigation markers
var _nav_markers: Array[Node] = []

## Timers
var _area_check_timer: float = 0.0


func _ready() -> void:
	# Connect to SceneManager for cleanup on scene changes
	if SceneManager:
		SceneManager.scene_load_started.connect(_on_scene_load_started)


func _process(delta: float) -> void:
	if active_cave_id.is_empty():
		return

	_area_check_timer += delta
	if _area_check_timer >= AREA_CHECK_INTERVAL:
		_area_check_timer = 0.0
		_check_player_area()


func _on_scene_load_started() -> void:
	# Clear node references when scene changes to prevent freed object issues
	_clear_node_references()


func _clear_node_references() -> void:
	cave_root = null
	_area_enemies.clear()
	_nav_markers.clear()
	_active_enemy_count = 0


## Register a cave with the manager
## Call this from the cave scene's _ready()
func register_cave(root: Node3D, cave_id: String, faction: String = "natural", danger: int = 3) -> void:
	cave_root = root
	active_cave_id = cave_id
	cave_faction = faction
	cave_danger_level = danger

	# Detect areas from Blender markers in the cave model
	_detect_areas_from_markers(root)

	print("[CaveManager] Registered cave: %s with %d areas" % [cave_id, area_data.size()])


## Enter a cave (call after register_cave)
func enter_cave(cave_id: String) -> void:
	if active_cave_id != cave_id:
		push_warning("[CaveManager] Entering cave %s but %s is registered" % [cave_id, active_cave_id])
		return

	cave_entered.emit(cave_id)
	print("[CaveManager] Entered cave: %s" % cave_id)

	# Check initial area
	_check_player_area()


## Exit the current cave
func exit_cave() -> void:
	if active_cave_id.is_empty():
		return

	var exited_id: String = active_cave_id
	active_cave_id = ""
	cave_exited.emit(exited_id)

	# Keep visited_areas for save/load but clear runtime data
	area_data.clear()
	current_area_id = ""
	_clear_node_references()

	print("[CaveManager] Exited cave: %s" % exited_id)


## Check if player is in a cave
func is_in_cave() -> bool:
	return not active_cave_id.is_empty()


## Get the current area the player is in
func get_current_area() -> CaveArea:
	if current_area_id.is_empty():
		return null
	return area_data.get(current_area_id)


## Get all areas in the current cave
func get_all_areas() -> Array[CaveArea]:
	var areas: Array[CaveArea] = []
	for area: CaveArea in area_data.values():
		areas.append(area)
	return areas


## Get visited areas in the current cave
func get_visited_areas() -> Array[CaveArea]:
	var areas: Array[CaveArea] = []
	for area: CaveArea in area_data.values():
		if area.is_visited:
			areas.append(area)
	return areas


## Check if an area has been visited
func is_area_visited(area_id: String) -> bool:
	var area: CaveArea = area_data.get(area_id)
	if area:
		return area.is_visited
	return visited_areas.has(area_id)


## Manually mark an area as visited
func mark_area_visited(area_id: String) -> void:
	if area_data.has(area_id):
		var area: CaveArea = area_data[area_id]
		if not area.is_visited:
			area.is_visited = true
			area.visit_timestamp = Time.get_unix_time_from_system()
			visited_areas[area_id] = area.visit_timestamp
			area_discovered.emit(area_id)


## Register an enemy spawned in an area
func register_enemy(enemy: Node, area_id: String) -> void:
	if not _area_enemies.has(area_id):
		_area_enemies[area_id] = []
	_area_enemies[area_id].append(enemy)
	_active_enemy_count += 1

	# Connect to enemy death signal if available
	if enemy.has_signal("died"):
		enemy.died.connect(_on_enemy_died.bind(enemy, area_id))

	enemy_count_changed.emit(_active_enemy_count)


func _on_enemy_died(enemy: Node, area_id: String) -> void:
	if _area_enemies.has(area_id):
		var enemies: Array[Node] = _area_enemies[area_id] as Array[Node]
		var idx: int = enemies.find(enemy)
		if idx >= 0:
			enemies.remove_at(idx)
	_active_enemy_count = maxi(0, _active_enemy_count - 1)
	enemy_count_changed.emit(_active_enemy_count)


## Get current enemy count
func get_enemy_count() -> int:
	return _active_enemy_count


## Can spawn more enemies?
func can_spawn_enemy() -> bool:
	return _active_enemy_count < MAX_CAVE_ENEMIES


## Get enemies in a specific area
func get_area_enemies(area_id: String) -> Array[Node]:
	if _area_enemies.has(area_id):
		# Filter out freed instances
		var valid: Array[Node] = []
		for enemy: Node in _area_enemies[area_id]:
			if is_instance_valid(enemy):
				valid.append(enemy)
		_area_enemies[area_id] = valid
		return valid
	return []


## Detect areas from Blender markers in the cave model
## Looks for nodes named CaveArea_* with metadata
func _detect_areas_from_markers(root: Node3D) -> void:
	area_data.clear()
	_find_area_markers_recursive(root)

	# If no areas found, create a default entrance area at origin
	if area_data.is_empty():
		var default_area := CaveArea.new("entrance_default", Vector3.ZERO, CaveAreaType.ENTRANCE)
		area_data["entrance_default"] = default_area
		print("[CaveManager] No area markers found, created default entrance area")


func _find_area_markers_recursive(node: Node) -> void:
	# Check if this node is an area marker
	if node.name.begins_with("CaveArea_"):
		var area: CaveArea = _parse_area_marker(node)
		if area:
			area_data[area.area_id] = area

			# Restore visited state from previous visits
			if visited_areas.has(area.area_id):
				area.is_visited = true
				area.visit_timestamp = visited_areas[area.area_id]

	# Recurse into children
	for child in node.get_children():
		_find_area_markers_recursive(child)


func _parse_area_marker(node: Node) -> CaveArea:
	if not node is Node3D:
		return null

	var node3d: Node3D = node as Node3D
	var area_id: String = node.name.replace("CaveArea_", "").to_lower()

	# Parse area type from marker name or metadata
	var type_str: String = node.get_meta("area_type", "")
	if type_str.is_empty():
		# Try to determine from name
		var name_lower: String = area_id.to_lower()
		if "entrance" in name_lower:
			type_str = "entrance"
		elif "passage" in name_lower:
			type_str = "passage"
		elif "junction" in name_lower:
			type_str = "junction"
		elif "chamber" in name_lower:
			type_str = "chamber"
		elif "treasure" in name_lower:
			type_str = "treasure_room"
		elif "exit" in name_lower:
			type_str = "exit"
		else:
			type_str = "passage"

	var area_type: int = _string_to_area_type(type_str)
	var area := CaveArea.new(area_id, node3d.global_position, area_type)

	# Override radius if specified in metadata
	area.radius = node.get_meta("area_radius", DEFAULT_AREA_RADIUS)

	# Override spawn config from metadata
	if node.has_meta("enemy_max"):
		area.spawn_config["enemy_max"] = node.get_meta("enemy_max")
	if node.has_meta("chest_chance"):
		area.spawn_config["chest_chance"] = node.get_meta("chest_chance")
	if node.has_meta("prop_density"):
		area.spawn_config["prop_density"] = node.get_meta("prop_density")

	return area


func _string_to_area_type(type_str: String) -> int:
	match type_str.to_lower():
		"entrance": return CaveAreaType.ENTRANCE
		"passage": return CaveAreaType.PASSAGE
		"junction": return CaveAreaType.JUNCTION
		"chamber": return CaveAreaType.CHAMBER
		"treasure_room", "treasure": return CaveAreaType.TREASURE_ROOM
		"exit": return CaveAreaType.EXIT
	return CaveAreaType.PASSAGE


## Check which area the player is in
func _check_player_area() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var player_pos: Vector3 = player.global_position
	var found_area: String = ""

	# Find which area contains the player
	for area_id: String in area_data:
		var area: CaveArea = area_data[area_id]
		if area.contains_point(player_pos):
			found_area = area_id
			break

	# If player moved to a new area
	if found_area != current_area_id:
		var old_area: String = current_area_id
		current_area_id = found_area

		if not found_area.is_empty():
			# Mark as visited if new
			mark_area_visited(found_area)

		area_changed.emit(old_area, found_area)

		# Update enemy processing for performance
		_update_enemy_processing()


## Enable/disable enemy processing based on distance from player
func _update_enemy_processing() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var player_pos: Vector3 = player.global_position

	# Get areas within processing range (current + adjacent)
	var active_areas: Array[String] = []
	if not current_area_id.is_empty():
		active_areas.append(current_area_id)

	# Also activate adjacent areas (within 2x radius)
	for area_id: String in area_data:
		var area: CaveArea = area_data[area_id]
		var distance: float = area.center.distance_to(player_pos)
		if distance <= area.radius * 2.5:
			if area_id not in active_areas:
				active_areas.append(area_id)

	# Enable/disable enemy processing
	for area_id: String in _area_enemies:
		var should_process: bool = area_id in active_areas
		for enemy: Node in _area_enemies[area_id]:
			if is_instance_valid(enemy):
				enemy.set_process(should_process)
				enemy.set_physics_process(should_process)


## Register a navigation marker
func register_nav_marker(marker: Node) -> void:
	_nav_markers.append(marker)


## Get all navigation markers
func get_nav_markers() -> Array[Node]:
	# Filter out freed instances
	var valid: Array[Node] = []
	for marker: Node in _nav_markers:
		if is_instance_valid(marker):
			valid.append(marker)
	_nav_markers.assign(valid)
	return valid


## Get save data for persistence
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"active_cave_id": active_cave_id,
		"cave_faction": cave_faction,
		"cave_danger_level": cave_danger_level,
		"visited_areas": visited_areas.duplicate(),
		"areas": {}
	}

	for area_id: String in area_data:
		var area: CaveArea = area_data[area_id]
		data.areas[area_id] = area.to_dict()

	return data


## Load save data
func load_save_data(data: Dictionary) -> void:
	visited_areas = data.get("visited_areas", {}).duplicate()
	cave_faction = data.get("cave_faction", "natural")
	cave_danger_level = data.get("cave_danger_level", 3)

	# Note: actual cave registration happens when the cave scene loads
	# The visited_areas dict persists across sessions


## Reset for new game
func reset_for_new_game() -> void:
	exit_cave()
	visited_areas.clear()
	cave_faction = "natural"
	cave_danger_level = 3
