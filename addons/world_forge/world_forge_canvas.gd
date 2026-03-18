@tool
extends Control
class_name WorldForgeCanvas
## Custom Control for the World Forge grid painting canvas

signal cell_painted(x: int, y: int, layer: String, value)
signal cell_erased(x: int, y: int, layer: String)
signal poi_selected(index: int)
signal poi_moved(index: int, new_x: int, new_y: int)
signal poi_double_clicked(index: int)
signal canvas_panned(offset: Vector2)
signal canvas_zoomed(zoom: float)

const CELL_SIZE := 16  # Base pixel size per cell
const MIN_ZOOM := 0.25
const MAX_ZOOM := 4.0
const ZOOM_STEP := 0.1

var map_state: WorldForgeData.MapState
var editor_state: WorldForgeData.EditorState

var _is_painting: bool = false
var _is_panning: bool = false
var _pan_start: Vector2 = Vector2.ZERO
var _last_painted_cell: Vector2i = Vector2i(-1, -1)
var _hovered_cell: Vector2i = Vector2i(-1, -1)
var _road_connections: Array[Array] = []  # Array of [Vector2i, Vector2i]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	custom_minimum_size = Vector2(400, 400)


func _draw() -> void:
	if not map_state or not editor_state:
		return

	var cell_size: float = CELL_SIZE * editor_state.zoom
	var offset: Vector2 = editor_state.pan_offset

	# Draw background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.15))

	# Calculate visible cell range
	var start_x: int = maxi(0, int(-offset.x / cell_size))
	var start_y: int = maxi(0, int(-offset.y / cell_size))
	var end_x: int = mini(map_state.grid_width, int((-offset.x + size.x) / cell_size) + 1)
	var end_y: int = mini(map_state.grid_height, int((-offset.y + size.y) / cell_size) + 1)

	# Draw layers in order: terrain -> road -> poi
	if editor_state.layer_visibility.get("terrain", true):
		_draw_layer("terrain", start_x, start_y, end_x, end_y, cell_size, offset)

	# Draw road overlay layer
	if editor_state.layer_visibility.get("road", true):
		_draw_roads_layer(start_x, start_y, end_x, end_y, cell_size, offset)

	# Draw road connections (lines between POIs) - deprecated but keep for now
	if editor_state.show_roads and _road_connections.size() > 0:
		_draw_roads(cell_size, offset)

	# Draw POIs on top
	if editor_state.layer_visibility.get("poi", true):
		_draw_pois(start_x, start_y, end_x, end_y, cell_size, offset)

	# Draw grid
	if editor_state.show_grid:
		_draw_grid(start_x, start_y, end_x, end_y, cell_size, offset)

	# Draw origin marker
	if editor_state.show_origin:
		_draw_origin_marker(cell_size, offset)

	# Draw hovered cell highlight
	if _hovered_cell.x >= 0 and _hovered_cell.y >= 0:
		_draw_cell_highlight(_hovered_cell, cell_size, offset, Color(1, 1, 1, 0.3))

	# Draw brush preview
	if editor_state.current_layer != "poi" and _hovered_cell.x >= 0:
		_draw_brush_preview(cell_size, offset)


func _draw_layer(layer: String, start_x: int, start_y: int, end_x: int, end_y: int, cell_size: float, offset: Vector2) -> void:
	var colors: Dictionary = WorldForgeData.LAYER_COLORS.get(layer, {})

	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			var value: Variant = map_state.get_layer_value(layer, x, y)
			if value == null:
				continue

			var color: Color = colors.get(value, Color.MAGENTA)
			var rect := Rect2(
				Vector2(x * cell_size, y * cell_size) + offset,
				Vector2(cell_size, cell_size)
			)
			draw_rect(rect, color)


func _draw_roads_layer(start_x: int, start_y: int, end_x: int, end_y: int, cell_size: float, offset: Vector2) -> void:
	var colors: Dictionary = WorldForgeData.LAYER_COLORS.get("road", {})

	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			var value: Variant = map_state.get_layer_value("road", x, y)
			if value == null:
				continue

			var color: Color = colors.get(value, Color.MAGENTA)
			var cell_pos := Vector2(x * cell_size, y * cell_size) + offset

			# Draw road cells slightly smaller to show terrain underneath
			var inset: float = cell_size * 0.15
			var road_rect := Rect2(
				cell_pos + Vector2(inset, inset),
				Vector2(cell_size - inset * 2, cell_size - inset * 2)
			)
			draw_rect(road_rect, color)

			# Draw special indicator for bridges
			if value == "bridge":
				# Draw bridge planks pattern
				var plank_color := Color(0.4, 0.3, 0.2)
				var plank_width: float = cell_size * 0.1
				var center := cell_pos + Vector2(cell_size / 2, cell_size / 2)
				for i: int in range(3):
					var plank_offset: float = (i - 1) * cell_size * 0.25
					draw_line(
						center + Vector2(-cell_size * 0.3, plank_offset),
						center + Vector2(cell_size * 0.3, plank_offset),
						plank_color, plank_width
					)


func _draw_pois(start_x: int, start_y: int, end_x: int, end_y: int, cell_size: float, offset: Vector2) -> void:
	var colors: Dictionary = WorldForgeData.LAYER_COLORS.get("poi", {})
	var icons: Dictionary = WorldForgeData.POI_ICONS

	for y: int in range(start_y, end_y):
		for x: int in range(start_x, end_x):
			var value: Variant = map_state.get_layer_value("poi", x, y)
			if value == null:
				continue

			var index: int = map_state.get_cell_index(x, y)
			var poi_info: Dictionary = map_state.poi_data.get(str(index), {})
			var color: Color = colors.get(value, Color.WHITE)
			var icon: String = icons.get(value, "?")

			var center := Vector2(x * cell_size + cell_size / 2, y * cell_size + cell_size / 2) + offset
			var radius: float = cell_size * 0.4

			# Draw POI circle
			draw_circle(center, radius, color)
			draw_arc(center, radius, 0, TAU, 32, Color.BLACK, 2.0)

			# Draw icon
			var font: Font = ThemeDB.fallback_font
			var font_size: int = int(cell_size * 0.5)
			var text_size: Vector2 = font.get_string_size(icon, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			draw_string(font, center - text_size / 2 + Vector2(0, text_size.y * 0.35), icon, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)

			# Draw selection highlight
			if index == editor_state.selected_poi_index:
				draw_arc(center, radius + 3, 0, TAU, 32, Color.WHITE, 3.0)

			# Draw name label if zoomed in enough
			if editor_state.zoom >= 1.0 and poi_info.has("name") and not poi_info["name"].is_empty():
				var name_size: Vector2 = font.get_string_size(poi_info["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
				var name_pos := Vector2(center.x - name_size.x / 2, center.y + radius + 12)
				draw_string(font, name_pos, poi_info["name"], HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.WHITE)


func _draw_roads(cell_size: float, offset: Vector2) -> void:
	var road_color := Color(0.55, 0.45, 0.35, 0.8)
	var road_width: float = cell_size * 0.2

	for connection: Array in _road_connections:
		if connection.size() < 2:
			continue
		var from: Vector2i = connection[0]
		var to: Vector2i = connection[1]

		var from_center := Vector2(from.x * cell_size + cell_size / 2, from.y * cell_size + cell_size / 2) + offset
		var to_center := Vector2(to.x * cell_size + cell_size / 2, to.y * cell_size + cell_size / 2) + offset

		draw_line(from_center, to_center, road_color, road_width)


func _draw_grid(start_x: int, start_y: int, end_x: int, end_y: int, cell_size: float, offset: Vector2) -> void:
	var grid_color := Color(0.3, 0.3, 0.3, 0.5)

	# Vertical lines
	for x: int in range(start_x, end_x + 1):
		var x_pos: float = x * cell_size + offset.x
		draw_line(Vector2(x_pos, start_y * cell_size + offset.y), Vector2(x_pos, end_y * cell_size + offset.y), grid_color)

	# Horizontal lines
	for y: int in range(start_y, end_y + 1):
		var y_pos: float = y * cell_size + offset.y
		draw_line(Vector2(start_x * cell_size + offset.x, y_pos), Vector2(end_x * cell_size + offset.x, y_pos), grid_color)


func _draw_origin_marker(cell_size: float, offset: Vector2) -> void:
	var origin: Vector2i = map_state.origin
	var origin_pos := Vector2(origin.x * cell_size, origin.y * cell_size) + offset
	var gold := Color(1.0, 0.85, 0.0, 0.9)

	# Draw crosshairs extending from origin
	var line_length: float = cell_size * 10
	draw_line(Vector2(origin_pos.x + cell_size / 2, origin_pos.y - line_length),
			  Vector2(origin_pos.x + cell_size / 2, origin_pos.y + cell_size + line_length), gold, 2.0)
	draw_line(Vector2(origin_pos.x - line_length, origin_pos.y + cell_size / 2),
			  Vector2(origin_pos.x + cell_size + line_length, origin_pos.y + cell_size / 2), gold, 2.0)

	# Draw cell border
	draw_rect(Rect2(origin_pos, Vector2(cell_size, cell_size)), gold, false, 3.0)

	# Draw "0,0" label
	var font: Font = ThemeDB.fallback_font
	draw_string(font, origin_pos + Vector2(2, cell_size - 2), "0,0", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, gold)


func _draw_cell_highlight(cell: Vector2i, cell_size: float, offset: Vector2, color: Color) -> void:
	var rect := Rect2(
		Vector2(cell.x * cell_size, cell.y * cell_size) + offset,
		Vector2(cell_size, cell_size)
	)
	draw_rect(rect, color, false, 2.0)


func _draw_brush_preview(cell_size: float, offset: Vector2) -> void:
	var brush_color: Color = Color(1, 1, 1, 0.3) if not editor_state.is_eraser else Color(1, 0, 0, 0.3)
	var half_size: int = editor_state.brush_size / 2

	for dy: int in range(-half_size, half_size + 1):
		for dx: int in range(-half_size, half_size + 1):
			var cell := Vector2i(_hovered_cell.x + dx, _hovered_cell.y + dy)
			if cell.x >= 0 and cell.x < map_state.grid_width and cell.y >= 0 and cell.y < map_state.grid_height:
				_draw_cell_highlight(cell, cell_size, offset, brush_color)


func _gui_input(event: InputEvent) -> void:
	if not map_state or not editor_state:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var cell_size: float = CELL_SIZE * editor_state.zoom
	var cell := _screen_to_cell(event.position)

	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				if editor_state.current_layer == "poi":
					# Check if clicking on existing POI
					var index: int = _get_poi_at_cell(cell)
					if index >= 0:
						if event.double_click:
							poi_double_clicked.emit(index)
						else:
							editor_state.selected_poi_index = index
							poi_selected.emit(index)
					else:
						editor_state.selected_poi_index = -1
						poi_selected.emit(-1)
				else:
					_is_painting = true
					_paint_at_cell(cell)
			else:
				_is_painting = false
				_last_painted_cell = Vector2i(-1, -1)
			queue_redraw()

		MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if editor_state.current_layer == "poi":
					# Deselect POI
					editor_state.selected_poi_index = -1
					poi_selected.emit(-1)
				else:
					_is_painting = true
					_erase_at_cell(cell)
			else:
				_is_painting = false
				_last_painted_cell = Vector2i(-1, -1)
			queue_redraw()

		MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_is_panning = true
				_pan_start = event.position
			else:
				_is_panning = false

		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom_at_point(event.position, ZOOM_STEP)

		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom_at_point(event.position, -ZOOM_STEP)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	var cell := _screen_to_cell(event.position)
	_hovered_cell = cell

	if _is_panning:
		editor_state.pan_offset += event.relative
		canvas_panned.emit(editor_state.pan_offset)
		queue_redraw()
	elif _is_painting and cell != _last_painted_cell:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_paint_at_cell(cell)
		elif event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_erase_at_cell(cell)
		queue_redraw()
	else:
		queue_redraw()


func _screen_to_cell(screen_pos: Vector2) -> Vector2i:
	var cell_size: float = CELL_SIZE * editor_state.zoom
	var adjusted := screen_pos - editor_state.pan_offset
	return Vector2i(int(adjusted.x / cell_size), int(adjusted.y / cell_size))


func _paint_at_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= map_state.grid_width or cell.y < 0 or cell.y >= map_state.grid_height:
		return

	var half_size: int = editor_state.brush_size / 2
	var value = editor_state.current_brush if not editor_state.is_eraser else null

	for dy: int in range(-half_size, half_size + 1):
		for dx: int in range(-half_size, half_size + 1):
			var target := Vector2i(cell.x + dx, cell.y + dy)
			if target.x >= 0 and target.x < map_state.grid_width and target.y >= 0 and target.y < map_state.grid_height:
				if editor_state.is_eraser:
					cell_erased.emit(target.x, target.y, editor_state.current_layer)
				else:
					cell_painted.emit(target.x, target.y, editor_state.current_layer, value)

	_last_painted_cell = cell


func _erase_at_cell(cell: Vector2i) -> void:
	if cell.x < 0 or cell.x >= map_state.grid_width or cell.y < 0 or cell.y >= map_state.grid_height:
		return

	var half_size: int = editor_state.brush_size / 2

	for dy: int in range(-half_size, half_size + 1):
		for dx: int in range(-half_size, half_size + 1):
			var target := Vector2i(cell.x + dx, cell.y + dy)
			if target.x >= 0 and target.x < map_state.grid_width and target.y >= 0 and target.y < map_state.grid_height:
				cell_erased.emit(target.x, target.y, editor_state.current_layer)

	_last_painted_cell = cell


func _get_poi_at_cell(cell: Vector2i) -> int:
	var value: Variant = map_state.get_layer_value("poi", cell.x, cell.y)
	if value != null:
		return map_state.get_cell_index(cell.x, cell.y)
	return -1


func _zoom_at_point(point: Vector2, delta: float) -> void:
	var old_zoom: float = editor_state.zoom
	editor_state.zoom = clampf(editor_state.zoom + delta, MIN_ZOOM, MAX_ZOOM)

	if old_zoom != editor_state.zoom:
		# Adjust pan to zoom towards mouse position
		var zoom_factor: float = editor_state.zoom / old_zoom
		var point_before := (point - editor_state.pan_offset)
		var point_after := point_before * zoom_factor
		editor_state.pan_offset -= (point_after - point_before)

		canvas_zoomed.emit(editor_state.zoom)
		queue_redraw()


func set_road_connections(connections: Array) -> void:
	_road_connections.clear()
	for conn: Variant in connections:
		if conn is Array:
			_road_connections.append(conn)
	queue_redraw()


func center_on_origin() -> void:
	if not map_state or not editor_state:
		return

	var cell_size: float = CELL_SIZE * editor_state.zoom
	var origin_pos := Vector2(map_state.origin.x * cell_size, map_state.origin.y * cell_size)
	editor_state.pan_offset = size / 2 - origin_pos - Vector2(cell_size / 2, cell_size / 2)
	queue_redraw()


func world_to_editor(world_coords: Vector2i) -> Vector2i:
	return world_coords + map_state.origin


func editor_to_world(editor_coords: Vector2i) -> Vector2i:
	return editor_coords - map_state.origin
