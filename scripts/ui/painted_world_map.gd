## painted_world_map.gd - OpenMW-inspired painted world map display
## Shows a hand-painted map image with fog of war overlay and player marker
## Supports pan, zoom, and fast travel to discovered locations
class_name PaintedWorldMap
extends Control

signal fast_travel_requested(location_id: String, spawn_id: String)
signal location_selected(location_id: String)

## Map texture path
const MAP_TEXTURE_PATH := "res://assets/textures/ui/world_map_painted.png"

## Colors - matching existing HexWorldMap theme
const COLOR_BG := Color(0.05, 0.04, 0.06, 0.98)
const COLOR_BORDER := Color(0.4, 0.35, 0.25)
const COLOR_TEXT := Color(0.9, 0.85, 0.75)
const COLOR_DIM := Color(0.5, 0.5, 0.5)
const COLOR_GOLD := Color(0.85, 0.7, 0.3)
const COLOR_PLAYER := Color(0.2, 0.9, 0.4)
const COLOR_PLAYER_GLOW := Color(0.4, 1.0, 0.6, 0.5)
const COLOR_FOG := Color(0.08, 0.08, 0.1, 0.85)
const COLOR_TOWN_MARKER := Color(1.0, 0.9, 0.5)
const COLOR_SELECTED := Color(1.0, 0.9, 0.5, 0.8)

## Map settings
const MAP_PADDING := 10
const PLAYER_ICON_SIZE := 8.0
const TOWN_MARKER_SIZE := 6.0
const DUNGEON_MARKER_SIZE := 5.0
const LANDMARK_MARKER_SIZE := 4.0
const MIN_ZOOM := 0.3
const MAX_ZOOM := 5.0  # Allow much closer zoom for detail

## Location marker colors
const COLOR_DUNGEON := Color(0.8, 0.3, 0.3)       # Red for dungeons
const COLOR_DUNGEON_UNDISCOVERED := Color(0.5, 0.3, 0.3, 0.6)  # Dim red
const COLOR_LANDMARK := Color(0.7, 0.7, 0.5)      # Tan for landmarks
const COLOR_VILLAGE := Color(0.6, 0.8, 0.6)       # Light green for villages
const COLOR_CAPITAL := Color(1.0, 0.85, 0.4)      # Bright gold for capitals
const COLOR_OUTPOST := Color(0.6, 0.5, 0.4)       # Brown for outposts
const COLOR_UNDISCOVERED := Color(0.5, 0.5, 0.5, 0.5)  # Gray for hints

## Components
var background: ColorRect
var map_canvas: Control
var map_texture: Texture2D
var title_label: Label
var location_label: Label
var coords_label: Label
var tooltip_panel: PanelContainer
var tooltip_label: Label

## Travel dialog
var travel_dialog: PanelContainer
var travel_location_label: Label
var travel_confirm_btn: Button
var travel_cancel_btn: Button

## Fog of war system
var fog_of_war: MapFogOfWar

## View state
var map_offset: Vector2 = Vector2.ZERO
var zoom_level: float = 1.0
var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var drag_offset_start: Vector2 = Vector2.ZERO

## Selection state
var selected_cell: Vector2i = Vector2i(-999, -999)
var hovered_cell: Vector2i = Vector2i(-999, -999)
var player_cell: Vector2i = Vector2i.ZERO  # Default to Elder Moor (0, 0)

## Cached values
var map_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Don't set custom_minimum_size - let parent control our size
	# This allows the map to fill whatever space is available

	_load_map_texture()
	_setup_fog_of_war()
	_setup_ui()
	_update_player_position()

	# Connect to resized signal for dynamic zoom calculation
	resized.connect(_on_resized)

	# Connect to PlayerGPS for cell changes to reveal fog
	if PlayerGPS:
		PlayerGPS.cell_changed.connect(_on_player_cell_changed)

	# Defer initial setup until we're properly sized
	call_deferred("_initial_setup")


func _initial_setup() -> void:
	_calculate_fit_zoom()
	_center_on_player()


func _on_resized() -> void:
	_calculate_fit_zoom()
	_center_on_player()
	if map_canvas:
		map_canvas.queue_redraw()


## Calculate zoom level to fit map within current panel size
func _calculate_fit_zoom() -> void:
	if map_size.x <= 0 or map_size.y <= 0:
		return
	if size.x <= 0 or size.y <= 0:
		return

	# Use actual size, not hardcoded values
	# map_canvas offsets: top=46, left=10, right=-10, bottom=-30
	var canvas_width: float = size.x - 20  # Subtract left+right padding
	var canvas_height: float = size.y - 76  # Subtract top title + bottom legend

	if canvas_width <= 0 or canvas_height <= 0:
		return

	# Calculate zoom to fit map within canvas with some padding
	var zoom_fit_x: float = canvas_width / map_size.x
	var zoom_fit_y: float = canvas_height / map_size.y

	# Use the smaller zoom to ensure entire map fits
	zoom_level = minf(zoom_fit_x, zoom_fit_y) * 0.95  # 95% to leave margin

	# Clamp to valid range
	zoom_level = clampf(zoom_level, MIN_ZOOM, MAX_ZOOM)


func _load_map_texture() -> void:
	if ResourceLoader.exists(MAP_TEXTURE_PATH):
		map_texture = load(MAP_TEXTURE_PATH)
		if map_texture:
			map_size = map_texture.get_size()
			print("[PaintedWorldMap] Loaded map texture: %dx%d" % [int(map_size.x), int(map_size.y)])
	else:
		push_warning("[PaintedWorldMap] Map texture not found: %s" % MAP_TEXTURE_PATH)


func _setup_fog_of_war() -> void:
	if map_size.x > 0 and map_size.y > 0:
		fog_of_war = MapFogOfWar.new(Vector2i(int(map_size.x), int(map_size.y)))

		# Reveal starting area (Elder Moor)
		fog_of_war.reveal_hex(Vector2i.ZERO)

		# Sync with PlayerGPS discovered cells
		_sync_fog_with_player_gps()

		# Reveal player's current position
		_reveal_current_cell()


## Sync fog of war with all cells discovered by PlayerGPS
func _sync_fog_with_player_gps() -> void:
	if not fog_of_war or not PlayerGPS:
		return

	var cells_to_reveal: Array = []
	for coords: Vector2i in PlayerGPS.discovered_cells:
		cells_to_reveal.append(coords)

	if cells_to_reveal.size() > 0:
		fog_of_war.bulk_reveal(cells_to_reveal)
		print("[PaintedWorldMap] Synced fog with %d discovered cells from PlayerGPS" % cells_to_reveal.size())


func _setup_ui() -> void:
	# Background with border
	var border := ColorRect.new()
	border.name = "Border"
	border.color = COLOR_BORDER
	border.set_anchors_preset(PRESET_FULL_RECT)
	border.offset_left = -2
	border.offset_top = -2
	border.offset_right = 2
	border.offset_bottom = 2
	border.z_index = -1
	add_child(border)

	background = ColorRect.new()
	background.name = "Background"
	background.color = COLOR_BG
	background.set_anchors_preset(PRESET_FULL_RECT)
	add_child(background)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = "WORLD MAP"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", COLOR_GOLD)
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.set_anchors_preset(PRESET_TOP_WIDE)
	title_label.offset_top = 6
	title_label.offset_bottom = 26
	add_child(title_label)

	# Location label
	location_label = Label.new()
	location_label.name = "LocationLabel"
	location_label.text = ""
	location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	location_label.add_theme_color_override("font_color", COLOR_TEXT)
	location_label.add_theme_font_size_override("font_size", 12)
	location_label.position = Vector2(MAP_PADDING, 28)
	add_child(location_label)

	# Coordinates label
	coords_label = Label.new()
	coords_label.name = "CoordsLabel"
	coords_label.text = ""
	coords_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	coords_label.add_theme_color_override("font_color", COLOR_DIM)
	coords_label.add_theme_font_size_override("font_size", 11)
	coords_label.set_anchors_preset(PRESET_TOP_RIGHT)
	coords_label.offset_top = 28
	coords_label.offset_right = -MAP_PADDING
	coords_label.offset_left = -100
	add_child(coords_label)

	# Map canvas for drawing
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_anchors_preset(PRESET_FULL_RECT)
	map_canvas.offset_top = 46
	map_canvas.offset_left = MAP_PADDING
	map_canvas.offset_right = -MAP_PADDING
	map_canvas.offset_bottom = -30
	map_canvas.clip_contents = true
	map_canvas.draw.connect(_draw_map)
	map_canvas.gui_input.connect(_on_map_input)
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_canvas)

	# Tooltip
	_setup_tooltip()

	# Travel dialog
	_setup_travel_dialog()

	# Legend with marker explanations
	var legend := Label.new()
	legend.name = "Legend"
	legend.text = "◆Town  ▼Dungeon  ★Landmark  ●Village | Scroll=Zoom  Drag=Pan  ?=Undiscovered"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend.add_theme_color_override("font_color", COLOR_DIM)
	legend.add_theme_font_size_override("font_size", 9)
	legend.set_anchors_preset(PRESET_BOTTOM_WIDE)
	legend.offset_bottom = -4
	legend.offset_top = -18
	add_child(legend)

	# Zoom controls (+ and - buttons in corner)
	_setup_zoom_controls()


func _setup_zoom_controls() -> void:
	# Container for zoom buttons (bottom-right corner)
	var zoom_container := VBoxContainer.new()
	zoom_container.name = "ZoomControls"
	zoom_container.set_anchors_preset(PRESET_BOTTOM_RIGHT)
	zoom_container.offset_right = -15
	zoom_container.offset_bottom = -35
	zoom_container.offset_left = -45
	zoom_container.offset_top = -85
	zoom_container.add_theme_constant_override("separation", 2)
	add_child(zoom_container)

	# Zoom in button
	var zoom_in_btn := Button.new()
	zoom_in_btn.text = "+"
	zoom_in_btn.custom_minimum_size = Vector2(30, 24)
	zoom_in_btn.pressed.connect(_on_zoom_in_pressed)
	_style_zoom_button(zoom_in_btn)
	zoom_container.add_child(zoom_in_btn)

	# Zoom out button
	var zoom_out_btn := Button.new()
	zoom_out_btn.text = "-"
	zoom_out_btn.custom_minimum_size = Vector2(30, 24)
	zoom_out_btn.pressed.connect(_on_zoom_out_pressed)
	_style_zoom_button(zoom_out_btn)
	zoom_container.add_child(zoom_out_btn)


func _style_zoom_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	normal.border_color = COLOR_BORDER
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.3, 0.95)
	hover.border_color = COLOR_GOLD
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(3)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_font_size_override("font_size", 16)


func _on_zoom_in_pressed() -> void:
	_zoom_at_point(map_canvas.size / 2.0, 1.5)


func _on_zoom_out_pressed() -> void:
	_zoom_at_point(map_canvas.size / 2.0, 1.0 / 1.5)


func _setup_tooltip() -> void:
	tooltip_panel = PanelContainer.new()
	tooltip_panel.name = "Tooltip"
	tooltip_panel.visible = false
	tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_panel.z_index = 100

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	tooltip_panel.add_theme_stylebox_override("panel", style)

	tooltip_label = Label.new()
	tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_label.custom_minimum_size = Vector2(180, 0)  # Max width before wrap
	tooltip_label.add_theme_color_override("font_color", COLOR_TEXT)
	tooltip_label.add_theme_font_size_override("font_size", 11)
	tooltip_panel.add_child(tooltip_label)

	add_child(tooltip_panel)


func _setup_travel_dialog() -> void:
	travel_dialog = PanelContainer.new()
	travel_dialog.name = "TravelDialog"
	travel_dialog.visible = false
	travel_dialog.z_index = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.98)
	style.border_color = COLOR_GOLD
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	travel_dialog.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	travel_dialog.add_child(vbox)

	var title := Label.new()
	title.text = "Fast Travel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(title)

	travel_location_label = Label.new()
	travel_location_label.text = "Travel to ?"
	travel_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	travel_location_label.add_theme_color_override("font_color", COLOR_TEXT)
	vbox.add_child(travel_location_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	travel_confirm_btn = Button.new()
	travel_confirm_btn.text = "Travel"
	travel_confirm_btn.custom_minimum_size = Vector2(70, 26)
	travel_confirm_btn.pressed.connect(_on_travel_confirmed)
	btn_row.add_child(travel_confirm_btn)

	travel_cancel_btn = Button.new()
	travel_cancel_btn.text = "Cancel"
	travel_cancel_btn.custom_minimum_size = Vector2(70, 26)
	travel_cancel_btn.pressed.connect(_on_travel_cancelled)
	btn_row.add_child(travel_cancel_btn)

	travel_dialog.set_anchors_preset(PRESET_CENTER)
	travel_dialog.offset_left = -90
	travel_dialog.offset_right = 90
	travel_dialog.offset_top = -45
	travel_dialog.offset_bottom = 45

	add_child(travel_dialog)


## ============================================================================
## COORDINATE CONVERSION (Square Grid System)
## ============================================================================

## Grid dimensions (must match WorldData and map image)
const GRID_COLS := 20
const GRID_ROWS := 20

## Get cell size in pixels based on map texture size
func _get_cell_size() -> float:
	if map_size.x > 0:
		return map_size.x / float(GRID_COLS)
	return 54.0  # Default: 1080 / 20 = 54


## Convert map pixel position to canvas position (with zoom and offset)
func map_to_canvas(map_pixel: Vector2) -> Vector2:
	var canvas_center: Vector2 = map_canvas.size / 2.0
	return canvas_center + (map_pixel - map_size / 2.0) * zoom_level + map_offset


## Convert canvas position to map pixel position
func canvas_to_map(canvas_pos: Vector2) -> Vector2:
	var canvas_center: Vector2 = map_canvas.size / 2.0
	return (canvas_pos - canvas_center - map_offset) / zoom_level + map_size / 2.0


## Convert grid coords to map pixel position (center of cell)
## Elder Moor (0,0) is at map center; coords are Elder Moor-relative
func grid_to_pixel(coords: Vector2i) -> Vector2:
	var cell_size: float = _get_cell_size()
	var map_center: Vector2 = map_size / 2.0
	var pixel_x: float = map_center.x + float(coords.x) * cell_size
	var pixel_y: float = map_center.y + float(coords.y) * cell_size
	return Vector2(pixel_x, pixel_y)


## Convert grid coords to canvas position
func grid_to_canvas(coords: Vector2i) -> Vector2:
	var map_pixel: Vector2 = grid_to_pixel(coords)
	return map_to_canvas(map_pixel)


## Convert map pixel position to grid coords (inverse of grid_to_pixel)
func pixel_to_grid(pixel: Vector2) -> Vector2i:
	var cell_size: float = _get_cell_size()
	var map_center: Vector2 = map_size / 2.0
	var col: int = int((pixel.x - map_center.x) / cell_size)
	var row: int = int((pixel.y - map_center.y) / cell_size)
	# Clamp to valid grid range (Elder Moor-relative coords)
	col = clampi(col, WorldGrid.GRID_MIN.x, WorldGrid.GRID_MAX.x)
	row = clampi(row, WorldGrid.GRID_MIN.y, WorldGrid.GRID_MAX.y)
	return Vector2i(col, row)


## Convert canvas position to grid coords
func canvas_to_grid(canvas_pos: Vector2) -> Vector2i:
	var map_pixel: Vector2 = canvas_to_map(canvas_pos)
	return pixel_to_grid(map_pixel)


## ============================================================================
## DRAWING
## ============================================================================

func _draw_map() -> void:
	if not map_texture:
		_draw_placeholder()
		return

	# Calculate map display rect
	var scaled_size: Vector2 = map_size * zoom_level
	var canvas_center: Vector2 = map_canvas.size / 2.0
	var map_rect := Rect2(
		canvas_center - scaled_size / 2.0 + map_offset,
		scaled_size
	)

	# Draw map texture
	map_canvas.draw_texture_rect(map_texture, map_rect, false)

	# Draw fog of war overlay
	_draw_fog_overlay(map_rect)

	# Draw all location markers (towns, dungeons, landmarks, etc.)
	_draw_all_location_markers()

	# Draw quest objective markers
	_draw_quest_markers()

	# Draw player marker
	_draw_player_marker()

	# Draw selection highlight
	if selected_cell.x != -999:
		_draw_cell_highlight(selected_cell, COLOR_SELECTED)


func _draw_placeholder() -> void:
	# Draw placeholder if map texture not loaded
	var rect := Rect2(Vector2.ZERO, map_canvas.size)
	map_canvas.draw_rect(rect, Color(0.1, 0.1, 0.15))
	var center: Vector2 = map_canvas.size / 2.0
	_draw_text_centered(center, "Map texture not found", COLOR_DIM, 14)


func _draw_fog_overlay(map_rect: Rect2) -> void:
	if not fog_of_war:
		return

	# Check if fog of war is disabled
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	if fog_disabled:
		return

	# Get fog texture - white = revealed, black = hidden
	var fog_tex: ImageTexture = fog_of_war.get_texture()
	if not fog_tex:
		return

	# Draw fog overlay by iterating cells and drawing fog rectangles for hidden areas
	# This is more performant than per-pixel and gives proper cell-based fog
	var cell_pixel_size: float = _get_cell_size() * zoom_level

	# Only draw cells that are visible on screen
	var visible_min: Vector2i = canvas_to_grid(Vector2.ZERO)
	var visible_max: Vector2i = canvas_to_grid(map_canvas.size)

	# Add padding to ensure we cover edges
	visible_min -= Vector2i(2, 2)
	visible_max += Vector2i(2, 2)

	# Clamp to valid grid range
	visible_min.x = clampi(visible_min.x, WorldGrid.GRID_MIN.x, WorldGrid.GRID_MAX.x)
	visible_min.y = clampi(visible_min.y, WorldGrid.GRID_MIN.y, WorldGrid.GRID_MAX.y)
	visible_max.x = clampi(visible_max.x, WorldGrid.GRID_MIN.x, WorldGrid.GRID_MAX.x)
	visible_max.y = clampi(visible_max.y, WorldGrid.GRID_MIN.y, WorldGrid.GRID_MAX.y)

	# Draw fog for each unexplored cell
	for y in range(visible_min.y, visible_max.y + 1):
		for x in range(visible_min.x, visible_max.x + 1):
			var coords := Vector2i(x, y)

			# Check if this cell is explored
			if fog_of_war.is_explored(coords):
				continue

			# Check if cell is discovered via other means (dev mode, etc.)
			var cell: WorldGrid.CellInfo = WorldGrid.get_cell(coords)
			if cell and cell.discovered:
				continue

			# Draw fog rectangle for this cell
			var canvas_pos: Vector2 = grid_to_canvas(coords)
			var half_cell: float = cell_pixel_size / 2.0

			var fog_rect := Rect2(
				canvas_pos.x - half_cell,
				canvas_pos.y - half_cell,
				cell_pixel_size,
				cell_pixel_size
			)

			# Clip to map bounds
			var clipped_rect: Rect2 = fog_rect.intersection(Rect2(Vector2.ZERO, map_canvas.size))
			if clipped_rect.size.x > 0 and clipped_rect.size.y > 0:
				map_canvas.draw_rect(clipped_rect, COLOR_FOG)


## Draw all location markers (towns, dungeons, landmarks, etc.)
func _draw_all_location_markers() -> void:
	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled

	# Iterate through all cells to find locations
	for coords: Vector2i in WorldGrid.cells:
		var cell: WorldGrid.CellInfo = WorldGrid.cells[coords]

		# Skip cells with no location
		if cell.location_type == WorldGrid.LocationType.NONE:
			continue
		if cell.location_type == WorldGrid.LocationType.BLOCKED:
			continue

		# Check visibility
		var is_discovered: bool = cell.discovered or is_dev or fog_disabled
		if fog_of_war:
			is_discovered = is_discovered or fog_of_war.is_explored(coords)

		# Check if player is nearby (within 3 cells) - show hint markers
		var is_nearby: bool = false
		if not is_discovered:
			var player_dist: int = abs(coords.x - player_cell.x) + abs(coords.y - player_cell.y)
			is_nearby = player_dist <= 3

		# Skip if not visible and not nearby
		if not is_discovered and not is_nearby:
			continue

		var canvas_pos: Vector2 = grid_to_canvas(coords)

		# Skip if off screen
		if canvas_pos.x < -20 or canvas_pos.x > map_canvas.size.x + 20:
			continue
		if canvas_pos.y < -20 or canvas_pos.y > map_canvas.size.y + 20:
			continue

		# Draw marker based on location type
		match cell.location_type:
			WorldGrid.LocationType.TOWN, WorldGrid.LocationType.CITY:
				_draw_town_marker(canvas_pos, cell, is_discovered)
			WorldGrid.LocationType.CAPITAL:
				_draw_capital_marker(canvas_pos, cell, is_discovered)
			WorldGrid.LocationType.VILLAGE:
				_draw_village_marker(canvas_pos, cell, is_discovered)
			WorldGrid.LocationType.DUNGEON:
				_draw_dungeon_marker(canvas_pos, cell, is_discovered)
			WorldGrid.LocationType.LANDMARK:
				_draw_landmark_marker(canvas_pos, cell, is_discovered)
			WorldGrid.LocationType.OUTPOST, WorldGrid.LocationType.BRIDGE:
				_draw_outpost_marker(canvas_pos, cell, is_discovered)


## Draw town/city marker (diamond)
func _draw_town_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = TOWN_MARKER_SIZE * zoom_level
	var color: Color = COLOR_TOWN_MARKER if is_discovered else COLOR_UNDISCOVERED

	var points: PackedVector2Array = [
		canvas_pos + Vector2(0, -marker_size),
		canvas_pos + Vector2(marker_size, 0),
		canvas_pos + Vector2(0, marker_size),
		canvas_pos + Vector2(-marker_size, 0)
	]
	map_canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	map_canvas.draw_polyline(points, color.lightened(0.3), 1.5)

	# Draw name if discovered and zoomed in
	if is_discovered and zoom_level >= 0.8:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 8), cell.location_name, COLOR_TEXT, 10)
	elif not is_discovered and zoom_level >= 1.5:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 6), "?", COLOR_UNDISCOVERED, 12)


## Draw capital marker (larger diamond with glow)
func _draw_capital_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = (TOWN_MARKER_SIZE + 3) * zoom_level
	var color: Color = COLOR_CAPITAL if is_discovered else COLOR_UNDISCOVERED

	# Glow effect
	if is_discovered:
		map_canvas.draw_circle(canvas_pos, marker_size + 2, Color(color.r, color.g, color.b, 0.3))

	var points: PackedVector2Array = [
		canvas_pos + Vector2(0, -marker_size),
		canvas_pos + Vector2(marker_size, 0),
		canvas_pos + Vector2(0, marker_size),
		canvas_pos + Vector2(-marker_size, 0)
	]
	map_canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	map_canvas.draw_polyline(points, color.lightened(0.3), 2.0)

	if is_discovered and zoom_level >= 0.6:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 10), cell.location_name, COLOR_CAPITAL, 12)


## Draw village marker (small circle)
func _draw_village_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = 4.0 * zoom_level
	var color: Color = COLOR_VILLAGE if is_discovered else COLOR_UNDISCOVERED

	map_canvas.draw_circle(canvas_pos, marker_size, color)
	map_canvas.draw_arc(canvas_pos, marker_size, 0, TAU, 16, color.lightened(0.3), 1.0)

	if is_discovered and zoom_level >= 1.0:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 6), cell.location_name, COLOR_TEXT, 9)


## Draw dungeon marker (skull/triangle pointing down)
func _draw_dungeon_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = DUNGEON_MARKER_SIZE * zoom_level
	var color: Color = COLOR_DUNGEON if is_discovered else COLOR_DUNGEON_UNDISCOVERED

	# Triangle pointing down (dangerous!)
	var points: PackedVector2Array = [
		canvas_pos + Vector2(-marker_size, -marker_size * 0.6),
		canvas_pos + Vector2(marker_size, -marker_size * 0.6),
		canvas_pos + Vector2(0, marker_size)
	]
	map_canvas.draw_colored_polygon(points, color)
	points.append(points[0])
	map_canvas.draw_polyline(points, color.lightened(0.3), 1.5)

	# Draw name or "?" based on discovery
	if is_discovered and zoom_level >= 0.8:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 8), cell.location_name, COLOR_DUNGEON, 10)
	elif not is_discovered and zoom_level >= 1.2:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 6), "?", COLOR_DUNGEON_UNDISCOVERED, 10)


## Draw landmark marker (star)
func _draw_landmark_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = LANDMARK_MARKER_SIZE * zoom_level
	var color: Color = COLOR_LANDMARK if is_discovered else COLOR_UNDISCOVERED

	# Draw star shape
	var points: PackedVector2Array = []
	for i in 10:
		var angle: float = i * TAU / 10.0 - PI / 2.0
		var radius: float = marker_size if i % 2 == 0 else marker_size * 0.5
		points.append(canvas_pos + Vector2(cos(angle), sin(angle)) * radius)
	map_canvas.draw_colored_polygon(points, color)

	if is_discovered and zoom_level >= 1.0:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 6), cell.location_name, COLOR_TEXT, 9)


## Draw outpost/bridge marker (square)
func _draw_outpost_marker(canvas_pos: Vector2, cell: WorldGrid.CellInfo, is_discovered: bool) -> void:
	var marker_size: float = 3.0 * zoom_level
	var color: Color = COLOR_OUTPOST if is_discovered else COLOR_UNDISCOVERED

	var rect := Rect2(canvas_pos - Vector2(marker_size, marker_size), Vector2(marker_size * 2, marker_size * 2))
	map_canvas.draw_rect(rect, color)
	map_canvas.draw_rect(rect, color.lightened(0.3), false, 1.0)

	if is_discovered and zoom_level >= 1.2:
		_draw_text_centered(canvas_pos + Vector2(0, marker_size + 6), cell.location_name, COLOR_TEXT, 8)


## Draw quest objective markers on world map
func _draw_quest_markers() -> void:
	if not QuestManager:
		return

	# Color constants for quest markers
	const COLOR_QUEST_MAIN := Color(1.0, 0.85, 0.2, 1.0)  # Gold
	const COLOR_QUEST_SIDE := Color(0.2, 0.8, 0.8, 1.0)   # Teal
	const COLOR_QUEST_GLOW := Color(1.0, 0.9, 0.3, 0.4)   # Gold glow

	# Get all active quests
	var active_quests: Array = QuestManager.get_active_quests()

	for quest in active_quests:
		var is_main: bool = quest.is_main_quest if "is_main_quest" in quest else false
		var quest_color: Color = COLOR_QUEST_MAIN if is_main else COLOR_QUEST_SIDE

		# Check if all objectives complete (turn-in)
		var all_complete: bool = QuestManager.are_objectives_complete(quest.id)

		var target_cell: Vector2i = Vector2i.ZERO
		var has_target: bool = false

		if all_complete:
			# Point to turn-in location
			var turnin_cell: Vector2i = QuestManager.get_turnin_hex(quest.id)
			if turnin_cell != Vector2i.ZERO:
				target_cell = turnin_cell
				has_target = true
		else:
			# Find first incomplete objective location
			for obj in quest.objectives:
				if obj.is_completed or obj.is_optional:
					continue
				var obj_location: Dictionary = QuestManager.get_cached_objective_location(quest.id, obj.id)
				if obj_location.get("hex", Vector2i.ZERO) != Vector2i.ZERO:
					target_cell = obj_location.get("hex", Vector2i.ZERO)
					has_target = true
					break

		if not has_target:
			continue

		var canvas_pos: Vector2 = grid_to_canvas(target_cell)

		# Skip if off screen
		if canvas_pos.x < -20 or canvas_pos.x > map_canvas.size.x + 20:
			continue
		if canvas_pos.y < -20 or canvas_pos.y > map_canvas.size.y + 20:
			continue

		# Pulsing effect for quest markers
		var pulse: float = (sin(Time.get_ticks_msec() * 0.005 + quest.id.hash() * 0.1) + 1.0) / 2.0
		var marker_size: float = (6.0 + pulse * 2.0) * zoom_level

		# Draw glow
		map_canvas.draw_circle(canvas_pos, marker_size + 3.0, COLOR_QUEST_GLOW)

		# Draw star shape for quest marker
		var points: PackedVector2Array = []
		for i in 10:
			var angle: float = i * TAU / 10.0 - PI / 2.0
			var radius: float = marker_size if i % 2 == 0 else marker_size * 0.5
			points.append(canvas_pos + Vector2(cos(angle), sin(angle)) * radius)
		map_canvas.draw_colored_polygon(points, quest_color)


func _draw_player_marker() -> void:
	var canvas_pos: Vector2 = grid_to_canvas(player_cell)

	# Pulsing glow effect
	var pulse: float = (sin(Time.get_ticks_msec() * 0.004) + 1.0) / 2.0
	var glow_size: float = (PLAYER_ICON_SIZE + pulse * 4.0) * zoom_level

	# Draw glow
	map_canvas.draw_circle(canvas_pos, glow_size, COLOR_PLAYER_GLOW)

	# Draw player dot
	map_canvas.draw_circle(canvas_pos, PLAYER_ICON_SIZE * zoom_level, COLOR_PLAYER)

	# Draw direction indicator (triangle pointing north)
	var tri_size: float = 4.0 * zoom_level
	var tri_offset: float = (PLAYER_ICON_SIZE + 3) * zoom_level
	var tri_points: PackedVector2Array = [
		canvas_pos + Vector2(0, -tri_offset - tri_size),
		canvas_pos + Vector2(-tri_size, -tri_offset),
		canvas_pos + Vector2(tri_size, -tri_offset)
	]
	map_canvas.draw_colored_polygon(tri_points, COLOR_PLAYER)


func _draw_cell_highlight(coords: Vector2i, color: Color) -> void:
	var canvas_pos: Vector2 = grid_to_canvas(coords)
	var highlight_size: float = 12.0 * zoom_level

	# Draw highlight circle
	map_canvas.draw_arc(canvas_pos, highlight_size, 0, TAU, 32, color, 2.0)


func _draw_text_centered(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos: Vector2 = pos - Vector2(text_size.x / 2.0, -text_size.y / 4.0)
	map_canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## ============================================================================
## INPUT HANDLING
## ============================================================================

func _on_map_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion

		if is_dragging:
			# Pan the map
			map_offset += mouse_event.relative
			_clamp_offset()
			map_canvas.queue_redraw()
		else:
			# Update hovered cell
			var coords: Vector2i = canvas_to_grid(mouse_event.position)
			if coords != hovered_cell:
				hovered_cell = coords
				_update_tooltip(coords, mouse_event.position)
				map_canvas.queue_redraw()

	elif event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				is_dragging = true
				drag_start = mouse_event.position
				drag_offset_start = map_offset
			else:
				is_dragging = false
				# Check if it was a click (not a drag)
				var drag_dist: float = (mouse_event.position - drag_start).length()
				if drag_dist < 5.0:
					var coords: Vector2i = canvas_to_grid(mouse_event.position)
					_on_cell_clicked(coords)

		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			# Zoom in
			_zoom_at_point(mouse_event.position, 1.2)

		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			# Zoom out
			_zoom_at_point(mouse_event.position, 1.0 / 1.2)

		elif mouse_event.button_index == MOUSE_BUTTON_MIDDLE and mouse_event.pressed:
			# Center on player
			_center_on_player()


func _zoom_at_point(point: Vector2, factor: float) -> void:
	var old_zoom: float = zoom_level
	zoom_level = clampf(zoom_level * factor, MIN_ZOOM, MAX_ZOOM)

	if zoom_level != old_zoom:
		# Adjust offset to keep point stationary
		var canvas_center: Vector2 = map_canvas.size / 2.0
		var point_offset: Vector2 = point - canvas_center - map_offset
		map_offset -= point_offset * (zoom_level / old_zoom - 1.0)
		_clamp_offset()
		map_canvas.queue_redraw()


func _clamp_offset() -> void:
	# Clamp offset so map stays visible
	var scaled_size: Vector2 = map_size * zoom_level
	var max_offset: float = maxf(scaled_size.x, scaled_size.y) / 2.0
	map_offset.x = clampf(map_offset.x, -max_offset, max_offset)
	map_offset.y = clampf(map_offset.y, -max_offset, max_offset)


func _center_on_player() -> void:
	# Get player position on map using local grid_to_pixel
	var player_map_pos: Vector2 = grid_to_pixel(player_cell)

	# Calculate offset to center player
	map_offset = (map_size / 2.0 - player_map_pos) * zoom_level

	_clamp_offset()
	map_canvas.queue_redraw()


func _update_tooltip(coords: Vector2i, mouse_pos: Vector2) -> void:
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(coords)

	if not cell:
		tooltip_panel.visible = false
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	var text: String = ""

	if is_discovered:
		if not cell.location_name.is_empty():
			text = cell.location_name + "\n"
		if not cell.region_name.is_empty():
			text += cell.region_name + "\n"
		# Show biome type
		var biome_name: String = WorldGrid.Biome.keys()[cell.biome].capitalize()
		text += biome_name
		if coords == player_cell:
			text += "\n[Current Location]"
	elif not cell.passable:
		text = "Impassable"
	else:
		text = "Undiscovered"

	# Show Elder Moor-relative coordinates
	text += "\nCoords: (%d, %d)" % [coords.x, coords.y]

	tooltip_label.text = text
	tooltip_panel.reset_size()
	tooltip_panel.visible = true

	# Position tooltip
	var tooltip_pos: Vector2 = map_canvas.position + mouse_pos + Vector2(15, -tooltip_panel.size.y / 2.0)

	# Keep on screen
	if tooltip_pos.x + tooltip_panel.size.x > size.x - 5:
		tooltip_pos.x = map_canvas.position.x + mouse_pos.x - tooltip_panel.size.x - 15
	if tooltip_pos.y < 5:
		tooltip_pos.y = 5
	if tooltip_pos.y + tooltip_panel.size.y > size.y - 5:
		tooltip_pos.y = size.y - tooltip_panel.size.y - 5

	tooltip_panel.position = tooltip_pos


func _on_cell_clicked(coords: Vector2i) -> void:
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(coords)

	if not cell:
		return

	var is_dev: bool = SceneManager and SceneManager.dev_mode
	var fog_disabled: bool = SceneManager and not SceneManager.fog_of_war_enabled
	var is_discovered: bool = cell.discovered or is_dev or fog_disabled

	# Can't interact with undiscovered cells
	if not is_discovered:
		return

	# Can't travel to current location
	if coords == player_cell:
		return

	# Can fast travel to settlements and discovered dungeons
	var valid_travel_types: Array[WorldGrid.LocationType] = [
		WorldGrid.LocationType.TOWN,
		WorldGrid.LocationType.CITY,
		WorldGrid.LocationType.CAPITAL,
		WorldGrid.LocationType.VILLAGE,
		WorldGrid.LocationType.DUNGEON,
		WorldGrid.LocationType.OUTPOST,
	]
	if cell.location_type not in valid_travel_types:
		return

	if cell.location_id.is_empty():
		return

	selected_cell = coords
	location_selected.emit(cell.location_id)

	# Show travel dialog
	travel_location_label.text = "Travel to %s?" % cell.location_name
	travel_dialog.visible = true

	map_canvas.queue_redraw()


func _on_travel_confirmed() -> void:
	if selected_cell.x == -999:
		travel_dialog.visible = false
		return

	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(selected_cell)
	if not cell or cell.location_id.is_empty():
		travel_dialog.visible = false
		return

	travel_dialog.visible = false

	# Use SceneManager's fast travel
	if SceneManager:
		SceneManager.fast_travel_to(cell.location_id)

	fast_travel_requested.emit(cell.location_id, "from_fast_travel")

	selected_cell = Vector2i(-999, -999)
	map_canvas.queue_redraw()


func _on_travel_cancelled() -> void:
	travel_dialog.visible = false
	selected_cell = Vector2i(-999, -999)
	map_canvas.queue_redraw()


## ============================================================================
## UPDATE METHODS
## ============================================================================

func _reveal_current_cell() -> void:
	if fog_of_war:
		fog_of_war.reveal_hex(player_cell)


## Called when player moves to a new cell
func _on_player_cell_changed(_old_cell: Vector2i, new_cell: Vector2i) -> void:
	player_cell = new_cell
	_reveal_current_cell()


func _update_player_position() -> void:
	# Get player's current grid position from PlayerGPS (primary) or SceneManager (fallback)
	if PlayerGPS:
		player_cell = PlayerGPS.current_cell
	elif SceneManager:
		player_cell = SceneManager.current_room_coords
	else:
		player_cell = Vector2i.ZERO  # Default to Elder Moor (0,0)

	# Reveal fog at player position
	_reveal_current_cell()

	# Update info labels using WorldGrid
	var cell: WorldGrid.CellInfo = WorldGrid.get_cell(player_cell)

	if cell:
		if not cell.location_name.is_empty():
			location_label.text = cell.location_name
		elif not cell.region_name.is_empty():
			location_label.text = cell.region_name
		else:
			# Show biome type for wilderness
			var biome_name: String = WorldGrid.Biome.keys()[cell.biome].capitalize()
			location_label.text = "%s Wilderness" % biome_name
	else:
		location_label.text = "Wilderness"

	# Show Elder Moor-relative coordinates
	var region_coords: Vector2i = player_cell
	if PlayerGPS:
		region_coords = PlayerGPS.current_cell
	coords_label.text = "Region: (%d, %d)" % [region_coords.x, region_coords.y]


func _process(_delta: float) -> void:
	if visible:
		_update_player_position()
		map_canvas.queue_redraw()


func refresh() -> void:
	_update_player_position()
	_center_on_player()
	map_canvas.queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		refresh()


## ============================================================================
## SAVE/LOAD SUPPORT
## ============================================================================

## Get fog of war state for saving
func get_fog_state() -> Dictionary:
	if fog_of_war:
		return fog_of_war.to_dict()
	return {}


## Load fog of war state from save
func load_fog_state(data: Dictionary) -> void:
	if fog_of_war and not data.is_empty():
		fog_of_war.from_dict(data)


## Get the MapFogOfWar instance
func get_fog_of_war() -> MapFogOfWar:
	return fog_of_war
