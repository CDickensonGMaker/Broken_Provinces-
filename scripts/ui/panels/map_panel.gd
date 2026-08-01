## map_panel.gd - Map display panel that switches between local, cave, and world maps
## WORLD_GRID mode displays the square grid-based world map
## CAVE_LOCAL mode displays cave minimap with fog of war
## LOCAL_AREA mode displays simple local dungeon/interior map
class_name MapPanel
extends Control

## Map display modes
enum MapMode { LOCAL_AREA, WORLD_GRID, CAVE_LOCAL }

## Current map mode
var current_mode: MapMode = MapMode.LOCAL_AREA

## Map containers
var grid_world_map: WorldMap = null
var local_map_container: Control = null
var cave_minimap: CaveMinimap = null

## Local map components (for dungeons/interiors)
var map_container: Control
var player_marker: Control
var area_name_label: Label

## Map settings for local map
var map_scale: float = 5.0  ## World units per pixel
var map_size: Vector2 = Vector2(400, 300)

## Marker colors
const PLAYER_COLOR := Color(0.2, 0.8, 0.2)
const ENEMY_COLOR := Color(0.8, 0.2, 0.2)
const ITEM_COLOR := Color(0.8, 0.8, 0.2)
const NPC_COLOR := Color(0.2, 0.5, 0.8)

## CaveAreaType enum values (mirror of CaveManager.CaveAreaType)
const CAVE_AREA_TYPE_ENTRANCE: int = 0
const CAVE_AREA_TYPE_PASSAGE: int = 1
const CAVE_AREA_TYPE_JUNCTION: int = 2
const CAVE_AREA_TYPE_CHAMBER: int = 3
const CAVE_AREA_TYPE_TREASURE_ROOM: int = 4
const CAVE_AREA_TYPE_EXIT: int = 5

## Tracked markers
var enemy_markers: Array[Control] = []
var item_markers: Array[Control] = []
var npc_markers: Array[Control] = []

## Mode toggle button
var mode_toggle_btn: Button = null


func _ready() -> void:
	_setup_ui()
	_determine_map_mode()
	refresh()


func _setup_ui() -> void:
	# Create container for local area map
	local_map_container = Control.new()
	local_map_container.name = "LocalMapContainer"
	local_map_container.set_anchors_preset(PRESET_FULL_RECT)
	local_map_container.offset_top = 30  # Room for toggle button
	add_child(local_map_container)

	# Setup local map components inside container
	map_container = Control.new()
	map_container.name = "MapContainer"
	map_container.set_anchors_preset(PRESET_FULL_RECT)
	local_map_container.add_child(map_container)

	# Area name label
	area_name_label = Label.new()
	area_name_label.name = "AreaNameLabel"
	area_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	area_name_label.add_theme_font_size_override("font_size", 14)
	area_name_label.set_anchors_preset(PRESET_TOP_WIDE)
	area_name_label.offset_top = 5
	area_name_label.offset_bottom = 25
	local_map_container.add_child(area_name_label)

	# Create player marker
	player_marker = _create_marker(PLAYER_COLOR, 8)
	map_container.add_child(player_marker)

	# Create cave minimap (hidden by default)
	cave_minimap = CaveMinimap.new()
	cave_minimap.name = "CaveMinimap"
	cave_minimap.set_anchors_preset(PRESET_FULL_RECT)
	cave_minimap.offset_top = 30
	cave_minimap.visible = false
	add_child(cave_minimap)

	# Create grid world map (hidden by default)
	grid_world_map = WorldMap.new()
	grid_world_map.name = "GridWorldMap"
	grid_world_map.set_anchors_preset(PRESET_FULL_RECT)
	grid_world_map.offset_top = 30
	grid_world_map.visible = false
	add_child(grid_world_map)

	# Mode toggle button
	mode_toggle_btn = Button.new()
	mode_toggle_btn.name = "ModeToggle"
	mode_toggle_btn.text = "World Map"
	mode_toggle_btn.set_anchors_preset(PRESET_TOP_RIGHT)
	mode_toggle_btn.offset_right = -10
	mode_toggle_btn.offset_left = -100
	mode_toggle_btn.offset_top = 5
	mode_toggle_btn.offset_bottom = 28
	mode_toggle_btn.pressed.connect(_on_mode_toggle_pressed)
	add_child(mode_toggle_btn)


func _determine_map_mode() -> void:
	# Check if CaveManager has an active cave first (use safe access to avoid class_name collision)
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if cave_mgr and cave_mgr.has_method("is_in_cave") and cave_mgr.is_in_cave():
		_set_mode(MapMode.CAVE_LOCAL)
		return

	# Determine which map to show based on context
	# In region-based system, show world map for outdoor regions, local map for dungeons
	var zone_id: String = ""
	if SceneManager:
		zone_id = SceneManager.get_current_region_id()
	if zone_id.is_empty() and PlayerGPS:
		zone_id = PlayerGPS.current_location_id

	# Check if this is a dungeon/interior (local map) or outdoor region (world map)
	var is_outdoor: bool = _is_outdoor_region(zone_id)

	if is_outdoor:
		# In outdoor region - show grid world map (uses WorldGrid)
		_set_mode(MapMode.WORLD_GRID)
	else:
		# In dungeon/town/interior - show local map
		_set_mode(MapMode.LOCAL_AREA)


## Check if a zone is an outdoor region (should show world map)
func _is_outdoor_region(zone_id: String) -> bool:
	if zone_id.is_empty():
		return false

	# Dungeons and interiors use local map
	var dungeon_keywords: Array[String] = ["dungeon", "crypt", "cave", "tomb", "hideout", "interior", "inn_"]
	for keyword in dungeon_keywords:
		if keyword in zone_id.to_lower():
			return false

	# Towns and outdoor regions use world map
	var outdoor_keywords: Array[String] = ["village", "town", "city", "capital", "hamlet", "outpost", "moor", "field", "brook", "dale", "watch", "crossing"]
	for keyword in outdoor_keywords:
		if keyword in zone_id.to_lower():
			return true

	# Default to world map for unknown zones
	return true


func _set_mode(mode: MapMode) -> void:
	current_mode = mode

	# Hide all maps
	local_map_container.visible = false
	grid_world_map.visible = false
	if cave_minimap:
		cave_minimap.visible = false

	# Show the appropriate map
	match mode:
		MapMode.LOCAL_AREA:
			local_map_container.visible = true
			mode_toggle_btn.text = "World Map"
		MapMode.WORLD_GRID:
			grid_world_map.visible = true
			grid_world_map.refresh()
			mode_toggle_btn.text = "Local Map"
		MapMode.CAVE_LOCAL:
			if cave_minimap:
				cave_minimap.visible = true
				cave_minimap.recalculate_bounds()
			mode_toggle_btn.text = "World Map"


func _on_mode_toggle_pressed() -> void:
	# Toggle between modes
	match current_mode:
		MapMode.LOCAL_AREA, MapMode.CAVE_LOCAL:
			# Switch to grid world map
			_set_mode(MapMode.WORLD_GRID)
		MapMode.WORLD_GRID:
			# Switch back to appropriate local map (use safe access for CaveManager)
			var cave_mgr: Node = get_node_or_null("/root/CaveManager")
			if cave_mgr and cave_mgr.has_method("is_in_cave") and cave_mgr.is_in_cave():
				_set_mode(MapMode.CAVE_LOCAL)
			else:
				_set_mode(MapMode.LOCAL_AREA)


func _process(_delta: float) -> void:
	if not visible:
		return

	match current_mode:
		MapMode.LOCAL_AREA:
			_update_player_position()
		MapMode.CAVE_LOCAL:
			# CaveMinimap handles its own updates
			pass


func refresh() -> void:
	_determine_map_mode()

	match current_mode:
		MapMode.LOCAL_AREA:
			_update_area_name()
			_refresh_markers()
		MapMode.WORLD_GRID:
			if grid_world_map:
				grid_world_map.refresh()
		MapMode.CAVE_LOCAL:
			if cave_minimap:
				cave_minimap.recalculate_bounds()
				_update_cave_area_name()


func _update_area_name() -> void:
	if not area_name_label:
		return

	# Get current area name from GameManager or scene
	var area_name := "Unknown Area"
	if GameManager.has_method("get_current_area_name"):
		area_name = GameManager.get_current_area_name()
	else:
		var current_scene := get_tree().current_scene
		if current_scene:
			area_name = current_scene.name.replace("_", " ").capitalize()

	area_name_label.text = area_name


func _update_cave_area_name() -> void:
	## Update area name for cave mode
	if not area_name_label:
		return

	var area_name := "Cave"

	# Get cave name from CaveManager (use safe access to avoid class_name collision)
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if cave_mgr and cave_mgr.has_method("is_in_cave") and cave_mgr.is_in_cave():
		# Get current area name
		if cave_mgr.has_method("get_current_area"):
			var current_area: RefCounted = cave_mgr.get_current_area()
			if current_area and "area_id" in current_area and "area_type" in current_area:
				area_name = _format_area_name(current_area.area_id, current_area.area_type)
			elif "active_cave_id" in cave_mgr:
				area_name = cave_mgr.active_cave_id.replace("_", " ").capitalize()

	area_name_label.text = area_name


func _format_area_name(area_id: String, area_type: int) -> String:
	## Format area ID into display name
	var type_prefix: String = ""
	match area_type:
		CAVE_AREA_TYPE_ENTRANCE:
			type_prefix = "Entrance"
		CAVE_AREA_TYPE_PASSAGE:
			type_prefix = "Passage"
		CAVE_AREA_TYPE_JUNCTION:
			type_prefix = "Junction"
		CAVE_AREA_TYPE_CHAMBER:
			type_prefix = "Chamber"
		CAVE_AREA_TYPE_TREASURE_ROOM:
			type_prefix = "Treasure Room"
		CAVE_AREA_TYPE_EXIT:
			type_prefix = "Exit"

	# Clean up area_id
	var name_part: String = area_id.replace("_", " ").capitalize()

	if type_prefix.is_empty():
		return name_part
	return "%s - %s" % [type_prefix, name_part]


func _update_player_position() -> void:
	if not player_marker or not map_container:
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if not player or not player is Node3D:
		return

	var world_pos: Vector3 = (player as Node3D).global_position
	var map_pos := _world_to_map(world_pos)
	player_marker.position = map_pos

	# Rotate marker based on player facing
	if player.has_node("MeshRoot"):
		var mesh_root: Node3D = player.get_node("MeshRoot")
		player_marker.rotation = -mesh_root.rotation.y


func _world_to_map(world_pos: Vector3) -> Vector2:
	# Convert 3D world position to 2D map position
	# Center of map is (0, 0) in world space
	var container_size: Vector2 = map_container.size if map_container else map_size
	var map_center := container_size / 2.0
	var map_x := map_center.x + (world_pos.x / map_scale)
	var map_y := map_center.y + (world_pos.z / map_scale)

	# Clamp to map bounds
	map_x = clampf(map_x, 0, container_size.x)
	map_y = clampf(map_y, 0, container_size.y)

	return Vector2(map_x, map_y)


func _refresh_markers() -> void:
	# Clear old markers
	for marker in enemy_markers:
		marker.queue_free()
	enemy_markers.clear()

	for marker in item_markers:
		marker.queue_free()
	item_markers.clear()

	for marker in npc_markers:
		marker.queue_free()
	npc_markers.clear()

	if not map_container:
		return

	# Add enemy markers
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D and enemy.has_method("is_alive") and enemy.is_alive():
			var marker: Control = _create_marker(ENEMY_COLOR, 4)
			map_container.add_child(marker)
			marker.position = _world_to_map((enemy as Node3D).global_position)
			enemy_markers.append(marker)

	# Add item markers
	for item: Node in get_tree().get_nodes_in_group("world_items"):
		if item is Node3D:
			var marker: Control = _create_marker(ITEM_COLOR, 3)
			map_container.add_child(marker)
			marker.position = _world_to_map((item as Node3D).global_position)
			item_markers.append(marker)

	# Add NPC markers
	for npc: Node in get_tree().get_nodes_in_group("npcs"):
		if npc is Node3D:
			var marker: Control = _create_marker(NPC_COLOR, 5)
			map_container.add_child(marker)
			marker.position = _world_to_map((npc as Node3D).global_position)
			npc_markers.append(marker)


func _create_marker(color: Color, marker_size: int) -> Control:
	var marker := ColorRect.new()
	marker.color = color
	marker.custom_minimum_size = Vector2(marker_size, marker_size)
	marker.size = Vector2(marker_size, marker_size)
	marker.pivot_offset = Vector2(marker_size / 2.0, marker_size / 2.0)
	return marker


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()
