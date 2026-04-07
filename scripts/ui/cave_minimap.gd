## cave_minimap.gd - Cave minimap with area-based fog of war
## Designed for organic caves (not grid-based like dungeons)
class_name CaveMinimap
extends Control


## Colors
const COLOR_BACKGROUND := Color(0.1, 0.1, 0.12, 0.9)
const COLOR_FOG := Color(0.05, 0.05, 0.08, 0.95)
const COLOR_REVEALED := Color(0.2, 0.22, 0.25, 0.7)
const COLOR_PLAYER := Color(0.2, 0.9, 0.3, 1.0)
const COLOR_ENEMY := Color(0.9, 0.2, 0.2, 1.0)
const COLOR_EXIT := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_CHEST := Color(0.9, 0.8, 0.2, 1.0)
const COLOR_NAV_MARKER := Color(0.4, 0.5, 0.9, 0.8)
const COLOR_AREA_OUTLINE := Color(0.4, 0.45, 0.5, 0.5)
const COLOR_CURRENT_AREA := Color(0.5, 0.6, 0.7, 0.3)


## Map settings
const MAP_PADDING: int = 20
const PLAYER_MARKER_SIZE: int = 8
const ENEMY_MARKER_SIZE: int = 5
const CHEST_MARKER_SIZE: int = 6
const NAV_MARKER_SIZE: int = 4
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 2.0


## Cave bounds (world space)
var cave_bounds: AABB = AABB()

## Revealed areas
var revealed_areas: Dictionary = {}  ## area_id -> bool

## Fog of war image
var fog_image: Image
var fog_texture: ImageTexture

## Map state
var zoom_level: float = 1.0
var pan_offset: Vector2 = Vector2.ZERO
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO

## Update timer
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25

## Cached reference to CaveManager (to avoid class_name collision with autoload)
var _cave_mgr: Node = null


## Get CaveManager autoload (use this instead of direct CaveManager access)
func _get_cave_manager() -> Node:
	if not _cave_mgr:
		_cave_mgr = get_node_or_null("/root/CaveManager")
	return _cave_mgr


## Get area data from CaveManager
func _get_area_data() -> Dictionary:
	var cave_mgr: Node = _get_cave_manager()
	if cave_mgr and "area_data" in cave_mgr:
		return cave_mgr.area_data
	return {}


## Get current area ID from CaveManager
func _get_current_area_id() -> String:
	var cave_mgr: Node = _get_cave_manager()
	if cave_mgr and "current_area_id" in cave_mgr:
		return cave_mgr.current_area_id
	return ""


## Get nav markers from CaveManager
func _get_nav_markers() -> Array[Node]:
	var cave_mgr: Node = _get_cave_manager()
	if cave_mgr and cave_mgr.has_method("get_nav_markers"):
		return cave_mgr.get_nav_markers()
	var empty: Array[Node] = []
	return empty


func _ready() -> void:
	# Set up mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect to CaveManager signals
	var cave_mgr: Node = _get_cave_manager()
	if cave_mgr:
		if cave_mgr.has_signal("area_discovered") and not cave_mgr.area_discovered.is_connected(_on_area_discovered):
			cave_mgr.area_discovered.connect(_on_area_discovered)
		if cave_mgr.has_signal("area_changed") and not cave_mgr.area_changed.is_connected(_on_area_changed):
			cave_mgr.area_changed.connect(_on_area_changed)

	# Initialize fog texture
	_create_fog_texture()


func _process(delta: float) -> void:
	if not visible:
		return

	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at_point(mb.position, 1.1)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at_point(mb.position, 0.9)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_dragging = true
				drag_start = mb.position
			else:
				is_dragging = false

	# Handle mouse drag pan
	if event is InputEventMouseMotion and is_dragging:
		var mm: InputEventMouseMotion = event
		pan_offset += mm.relative / zoom_level
		queue_redraw()


func _zoom_at_point(point: Vector2, factor: float) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, MAX_ZOOM)

	# Adjust pan to zoom towards mouse point
	var zoom_change: float = zoom_level / old_zoom
	var center: Vector2 = size / 2.0
	var offset_from_center: Vector2 = point - center
	pan_offset -= offset_from_center * (1.0 - 1.0 / zoom_change) / zoom_level

	queue_redraw()


func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)

	var cave_mgr: Node = _get_cave_manager()
	if not cave_mgr or not cave_mgr.has_method("is_in_cave") or not cave_mgr.is_in_cave():
		_draw_no_cave_message()
		return

	# Calculate cave bounds if not set
	if cave_bounds.size == Vector3.ZERO:
		_calculate_cave_bounds()

	# Draw fog of war
	_draw_fog_of_war()

	# Draw area outlines
	_draw_area_outlines()

	# Draw navigation markers
	_draw_nav_markers()

	# Draw chests
	_draw_chests()

	# Draw enemies
	_draw_enemies()

	# Draw exit markers
	_draw_exits()

	# Draw player
	_draw_player()

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.3, 0.3, 0.35), false, 2.0)


func _draw_no_cave_message() -> void:
	var font: Font = ThemeDB.fallback_font
	var text := "Not in a cave"
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	var pos: Vector2 = (size - text_size) / 2.0
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.5, 0.5, 0.5))


func _calculate_cave_bounds() -> void:
	## Calculate bounding box from all cave areas
	var cave_mgr: Node = _get_cave_manager()
	if not cave_mgr or not "area_data" in cave_mgr or cave_mgr.area_data.is_empty():
		cave_bounds = AABB(Vector3(-50, 0, -50), Vector3(100, 10, 100))
		return

	var min_pos: Vector3 = Vector3(INF, 0, INF)
	var max_pos: Vector3 = Vector3(-INF, 0, -INF)

	for area_id: String in cave_mgr.area_data:
		var area: RefCounted = cave_mgr.area_data[area_id]
		min_pos.x = minf(min_pos.x, area.center.x - area.radius)
		min_pos.z = minf(min_pos.z, area.center.z - area.radius)
		max_pos.x = maxf(max_pos.x, area.center.x + area.radius)
		max_pos.z = maxf(max_pos.z, area.center.z + area.radius)

	# Add padding
	var padding: float = 10.0
	min_pos -= Vector3(padding, 0, padding)
	max_pos += Vector3(padding, 0, padding)

	cave_bounds = AABB(min_pos, max_pos - min_pos)


func _world_to_map(world_pos: Vector3) -> Vector2:
	## Convert 3D world position to 2D map position
	if cave_bounds.size == Vector3.ZERO:
		return size / 2.0

	# Normalize to 0-1 within bounds
	var normalized_x: float = (world_pos.x - cave_bounds.position.x) / maxf(cave_bounds.size.x, 1.0)
	var normalized_z: float = (world_pos.z - cave_bounds.position.z) / maxf(cave_bounds.size.z, 1.0)

	# Apply zoom and pan
	var map_size: Vector2 = size - Vector2(MAP_PADDING * 2, MAP_PADDING * 2)
	var map_x: float = MAP_PADDING + normalized_x * map_size.x * zoom_level + pan_offset.x
	var map_z: float = MAP_PADDING + normalized_z * map_size.y * zoom_level + pan_offset.y

	return Vector2(map_x, map_z)


func _create_fog_texture() -> void:
	## Create initial fog image (fully fogged)
	var tex_size: int = 256
	fog_image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	fog_image.fill(COLOR_FOG)
	fog_texture = ImageTexture.create_from_image(fog_image)


func _draw_fog_of_war() -> void:
	## Draw fog with revealed areas
	# Draw base fog
	var fog_rect: Rect2 = Rect2(Vector2(MAP_PADDING, MAP_PADDING), size - Vector2(MAP_PADDING * 2, MAP_PADDING * 2))
	draw_rect(fog_rect, COLOR_FOG)

	# Draw revealed areas as circles
	for area_id: String in _get_area_data():
		var area: RefCounted = _get_area_data()[area_id]
		if area.is_visited or revealed_areas.get(area_id, false):
			var center: Vector2 = _world_to_map(area.center)
			var radius: float = area.radius * _get_world_to_map_scale() * zoom_level
			draw_circle(center, radius, COLOR_REVEALED)


func _draw_area_outlines() -> void:
	## Draw outlines for revealed areas
	for area_id: String in _get_area_data():
		var area: RefCounted = _get_area_data()[area_id]
		if not area.is_visited and not revealed_areas.get(area_id, false):
			continue

		var center: Vector2 = _world_to_map(area.center)
		var radius: float = area.radius * _get_world_to_map_scale() * zoom_level

		# Highlight current area
		if area_id == _get_current_area_id():
			draw_circle(center, radius, COLOR_CURRENT_AREA)

		# Draw outline
		_draw_circle_outline(center, radius, COLOR_AREA_OUTLINE, 1.0)


func _draw_circle_outline(center: Vector2, radius: float, color: Color, width: float) -> void:
	var points: int = 32
	var prev_point: Vector2 = center + Vector2(radius, 0)
	for i in range(1, points + 1):
		var angle: float = (float(i) / float(points)) * TAU
		var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		draw_line(prev_point, point, color, width)
		prev_point = point


func _draw_nav_markers() -> void:
	## Draw navigation markers
	var markers: Array[Node] = _get_nav_markers()
	for marker_node: Node in markers:
		if not is_instance_valid(marker_node):
			continue
		if not marker_node is Node3D:
			continue

		var marker: Node3D = marker_node as Node3D
		var map_pos: Vector2 = _world_to_map(marker.global_position)

		# Only show in revealed areas
		if not _is_position_revealed(marker.global_position):
			continue

		# Get color based on marker state if it's a CaveNavigationMarker
		var color: Color = COLOR_NAV_MARKER
		if marker is CaveNavigationMarker:
			var nav_marker: CaveNavigationMarker = marker as CaveNavigationMarker
			match nav_marker.current_state:
				CaveNavigationMarker.MarkerState.PATH_TO_EXIT:
					color = COLOR_EXIT
				CaveNavigationMarker.MarkerState.VISITED:
					color = Color(0.7, 0.75, 0.9, 0.8)

		# Draw diamond shape
		var half: float = NAV_MARKER_SIZE / 2.0
		var points: PackedVector2Array = PackedVector2Array([
			map_pos + Vector2(0, -half),
			map_pos + Vector2(half, 0),
			map_pos + Vector2(0, half),
			map_pos + Vector2(-half, 0)
		])
		draw_colored_polygon(points, color)


func _draw_chests() -> void:
	## Draw chest markers
	var chests: Array[Node] = get_tree().get_nodes_in_group("cave_chests")
	for chest: Node in chests:
		if not is_instance_valid(chest):
			continue
		if not chest is Node3D:
			continue

		var chest_node: Node3D = chest as Node3D
		if not _is_position_revealed(chest_node.global_position):
			continue

		var map_pos: Vector2 = _world_to_map(chest_node.global_position)

		# Draw square
		var half: float = CHEST_MARKER_SIZE / 2.0
		draw_rect(Rect2(map_pos - Vector2(half, half), Vector2(CHEST_MARKER_SIZE, CHEST_MARKER_SIZE)), COLOR_CHEST)


func _draw_enemies() -> void:
	## Draw enemy markers in revealed areas
	var enemies: Array[Node] = get_tree().get_nodes_in_group("cave_enemies")
	for enemy: Node in enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy is Node3D:
			continue

		var enemy_node: Node3D = enemy as Node3D

		# Check if alive
		if enemy.has_method("is_alive") and not enemy.is_alive():
			continue

		if not _is_position_revealed(enemy_node.global_position):
			continue

		var map_pos: Vector2 = _world_to_map(enemy_node.global_position)
		draw_circle(map_pos, ENEMY_MARKER_SIZE / 2.0, COLOR_ENEMY)


func _draw_exits() -> void:
	## Draw exit markers
	# EXIT = 5 in CaveManager.CaveAreaType enum
	const CAVE_AREA_TYPE_EXIT: int = 5
	for area_id: String in _get_area_data():
		var area: RefCounted = _get_area_data()[area_id]
		if area.area_type != CAVE_AREA_TYPE_EXIT:
			continue

		if not area.is_visited and not revealed_areas.get(area_id, false):
			continue

		var map_pos: Vector2 = _world_to_map(area.center)

		# Draw arrow pointing up (exit indicator)
		var arrow_size: float = 10.0
		var points: PackedVector2Array = PackedVector2Array([
			map_pos + Vector2(0, -arrow_size),
			map_pos + Vector2(arrow_size / 2.0, 0),
			map_pos + Vector2(0, -arrow_size / 3.0),
			map_pos + Vector2(-arrow_size / 2.0, 0)
		])
		draw_colored_polygon(points, COLOR_EXIT)


func _draw_player() -> void:
	## Draw player marker
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var map_pos: Vector2 = _world_to_map(player.global_position)

	# Draw directional triangle
	var facing: float = 0.0
	if player.has_node("MeshRoot"):
		var mesh_root: Node3D = player.get_node("MeshRoot")
		facing = -mesh_root.rotation.y

	var half: float = PLAYER_MARKER_SIZE / 2.0
	var points: PackedVector2Array = PackedVector2Array([
		map_pos + Vector2(sin(facing), -cos(facing)) * half * 1.5,
		map_pos + Vector2(sin(facing + 2.5), -cos(facing + 2.5)) * half,
		map_pos + Vector2(sin(facing - 2.5), -cos(facing - 2.5)) * half
	])
	draw_colored_polygon(points, COLOR_PLAYER)

	# Draw glow ring
	draw_circle(map_pos, PLAYER_MARKER_SIZE, Color(COLOR_PLAYER.r, COLOR_PLAYER.g, COLOR_PLAYER.b, 0.3))


func _is_position_revealed(world_pos: Vector3) -> bool:
	## Check if a world position is in a revealed area
	for area_id: String in _get_area_data():
		var area: RefCounted = _get_area_data()[area_id]
		if area.contains_point(world_pos):
			return area.is_visited or revealed_areas.get(area_id, false)
	return false


func _get_world_to_map_scale() -> float:
	## Get scale factor for converting world units to map pixels
	if cave_bounds.size == Vector3.ZERO:
		return 1.0

	var map_size: Vector2 = size - Vector2(MAP_PADDING * 2, MAP_PADDING * 2)
	var scale_x: float = map_size.x / maxf(cave_bounds.size.x, 1.0)
	var scale_z: float = map_size.y / maxf(cave_bounds.size.z, 1.0)
	return minf(scale_x, scale_z)


func _on_area_discovered(area_id: String) -> void:
	revealed_areas[area_id] = true
	queue_redraw()


func _on_area_changed(_old_area: String, _new_area: String) -> void:
	queue_redraw()


## Reveal all areas (for debug/testing)
func reveal_all() -> void:
	for area_id: String in _get_area_data():
		revealed_areas[area_id] = true
	queue_redraw()


## Reset fog of war
func reset_fog() -> void:
	revealed_areas.clear()
	queue_redraw()


## Recalculate bounds (call if cave layout changes)
func recalculate_bounds() -> void:
	cave_bounds = AABB()
	_calculate_cave_bounds()
	queue_redraw()


## Center map on player
func center_on_player() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var player_map_pos: Vector2 = _world_to_map(player.global_position)
	var center: Vector2 = size / 2.0
	pan_offset = center - player_map_pos
	queue_redraw()


## Reset zoom and pan
func reset_view() -> void:
	zoom_level = 1.0
	pan_offset = Vector2.ZERO
	queue_redraw()
