@tool
extends Control
class_name WorldForgeDock
## Main dock UI for the World Forge editor

const EXPORT_PATH := "user://world_forge_map.json"

var map_state: WorldForgeData.MapState
var editor_state: WorldForgeData.EditorState

# UI References
var grid_width_spin: SpinBox
var grid_height_spin: SpinBox
var origin_x_spin: SpinBox
var origin_y_spin: SpinBox
var layer_tabs: TabContainer
var brush_palette: GridContainer
var brush_size_group: ButtonGroup
var eraser_button: CheckButton
var visibility_checks: Dictionary = {}
var canvas: WorldForgeCanvas
var location_list: ItemList
var selected_poi_panel: VBoxContainer
var poi_name_edit: LineEdit
var poi_type_option: OptionButton
var poi_notes_edit: LineEdit
var poi_scene_edit: LineEdit
var poi_location_id_edit: LineEdit
var poi_position_label: Label
var new_poi_name_edit: LineEdit
var new_poi_type_option: OptionButton
var status_label: Label
var zoom_label: Label
var coords_label: Label


func _ready() -> void:
	map_state = WorldForgeData.MapState.new()
	editor_state = WorldForgeData.EditorState.new()

	_build_ui()
	_connect_signals()

	# Load from WorldGrid if available
	call_deferred("_load_from_world_grid")


func _build_ui() -> void:
	custom_minimum_size = Vector2(300, 600)

	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)

	# Header
	var header := _create_header()
	main_vbox.add_child(header)

	# Layer tabs with brush palettes
	layer_tabs = TabContainer.new()
	layer_tabs.custom_minimum_size.y = 120
	main_vbox.add_child(layer_tabs)
	_create_layer_tabs()

	# Toolbar
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)

	# Canvas container with scroll
	var canvas_container := PanelContainer.new()
	canvas_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(canvas_container)

	canvas = WorldForgeCanvas.new()
	canvas.map_state = map_state
	canvas.editor_state = editor_state
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas_container.add_child(canvas)

	# Info bar
	var info_bar := _create_info_bar()
	main_vbox.add_child(info_bar)

	# Footer with buttons
	var footer := _create_footer()
	main_vbox.add_child(footer)


func _create_header() -> Control:
	var vbox := VBoxContainer.new()

	# Title
	var title := Label.new()
	title.text = "World Forge"
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	# Grid size row
	var size_row := HBoxContainer.new()
	size_row.add_child(_make_label("Grid:"))

	grid_width_spin = SpinBox.new()
	grid_width_spin.min_value = 16
	grid_width_spin.max_value = 256
	grid_width_spin.value = 64
	grid_width_spin.custom_minimum_size.x = 60
	size_row.add_child(grid_width_spin)

	size_row.add_child(_make_label("x"))

	grid_height_spin = SpinBox.new()
	grid_height_spin.min_value = 16
	grid_height_spin.max_value = 256
	grid_height_spin.value = 64
	grid_height_spin.custom_minimum_size.x = 60
	size_row.add_child(grid_height_spin)

	vbox.add_child(size_row)

	# Origin row
	var origin_row := HBoxContainer.new()
	origin_row.add_child(_make_label("Origin X:"))

	origin_x_spin = SpinBox.new()
	origin_x_spin.min_value = 0
	origin_x_spin.max_value = 255
	origin_x_spin.value = 32
	origin_x_spin.custom_minimum_size.x = 60
	origin_row.add_child(origin_x_spin)

	origin_row.add_child(_make_label("Y:"))

	origin_y_spin = SpinBox.new()
	origin_y_spin.min_value = 0
	origin_y_spin.max_value = 255
	origin_y_spin.value = 32
	origin_y_spin.custom_minimum_size.x = 60
	origin_row.add_child(origin_y_spin)

	var center_btn := Button.new()
	center_btn.text = "Center"
	center_btn.pressed.connect(_on_center_pressed)
	origin_row.add_child(center_btn)

	vbox.add_child(origin_row)

	return vbox


func _create_layer_tabs() -> void:
	# Biome tab
	var biome_tab := _create_brush_tab("Biome", WorldForgeData.BIOME_VALUES, WorldForgeData.LAYER_COLORS["biome"])
	biome_tab.name = "Biome"
	layer_tabs.add_child(biome_tab)

	# Elevation tab
	var elevation_tab := _create_brush_tab("Elevation", WorldForgeData.ELEVATION_VALUES, WorldForgeData.LAYER_COLORS["elevation"])
	elevation_tab.name = "Elevation"
	layer_tabs.add_child(elevation_tab)

	# Water tab
	var water_tab := _create_brush_tab("Water", WorldForgeData.WATER_VALUES, WorldForgeData.LAYER_COLORS["water"])
	water_tab.name = "Water"
	layer_tabs.add_child(water_tab)

	# POI tab
	var poi_tab := _create_poi_tab()
	poi_tab.name = "POI"
	layer_tabs.add_child(poi_tab)


func _create_brush_tab(layer_name: String, values: Array[String], colors: Dictionary) -> Control:
	var vbox := VBoxContainer.new()

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)

	for value: String in values:
		var btn := Button.new()
		btn.text = value.capitalize()
		btn.custom_minimum_size = Vector2(80, 30)
		btn.toggle_mode = true

		# Add color indicator
		var color: Color = colors.get(value, Color.GRAY)
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_width_left = 4
		style.border_color = Color.BLACK
		btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(_on_brush_selected.bind(layer_name.to_lower(), value))
		grid.add_child(btn)

	vbox.add_child(grid)
	return vbox


func _create_poi_tab() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	# POI type palette
	var type_label := Label.new()
	type_label.text = "POI Types:"
	vbox.add_child(type_label)

	var type_grid := GridContainer.new()
	type_grid.columns = 5
	for poi_type: String in WorldForgeData.POI_VALUES:
		var btn := Button.new()
		btn.text = WorldForgeData.POI_ICONS.get(poi_type, "?")
		btn.tooltip_text = poi_type.capitalize()
		btn.custom_minimum_size = Vector2(30, 30)
		btn.pressed.connect(_on_brush_selected.bind("poi", poi_type))
		type_grid.add_child(btn)
	vbox.add_child(type_grid)

	# Location list
	var list_label := Label.new()
	list_label.text = "Locations:"
	vbox.add_child(list_label)

	location_list = ItemList.new()
	location_list.custom_minimum_size.y = 80
	location_list.max_columns = 1
	location_list.item_selected.connect(_on_location_list_selected)
	vbox.add_child(location_list)

	# New POI panel
	var new_panel := VBoxContainer.new()
	var new_label := Label.new()
	new_label.text = "New Location:"
	new_panel.add_child(new_label)

	var new_row := HBoxContainer.new()
	new_poi_name_edit = LineEdit.new()
	new_poi_name_edit.placeholder_text = "Name"
	new_poi_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_row.add_child(new_poi_name_edit)

	new_poi_type_option = OptionButton.new()
	for poi_type: String in WorldForgeData.POI_VALUES:
		new_poi_type_option.add_item(poi_type.capitalize())
	new_row.add_child(new_poi_type_option)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_btn.pressed.connect(_on_add_poi_pressed)
	new_row.add_child(add_btn)

	new_panel.add_child(new_row)
	vbox.add_child(new_panel)

	# Selected POI panel
	selected_poi_panel = VBoxContainer.new()
	selected_poi_panel.visible = false

	var sep := HSeparator.new()
	selected_poi_panel.add_child(sep)

	var sel_label := Label.new()
	sel_label.text = "Selected Location:"
	selected_poi_panel.add_child(sel_label)

	var name_row := HBoxContainer.new()
	name_row.add_child(_make_label("Name:"))
	poi_name_edit = LineEdit.new()
	poi_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poi_name_edit.text_changed.connect(_on_poi_name_changed)
	name_row.add_child(poi_name_edit)
	selected_poi_panel.add_child(name_row)

	var type_row := HBoxContainer.new()
	type_row.add_child(_make_label("Type:"))
	poi_type_option = OptionButton.new()
	for poi_type: String in WorldForgeData.POI_VALUES:
		poi_type_option.add_item(poi_type.capitalize())
	poi_type_option.item_selected.connect(_on_poi_type_changed)
	type_row.add_child(poi_type_option)
	selected_poi_panel.add_child(type_row)

	# Position controls row
	var pos_row := HBoxContainer.new()
	pos_row.add_child(_make_label("Position:"))

	var left_btn := Button.new()
	left_btn.text = "<"
	left_btn.tooltip_text = "Move West"
	left_btn.custom_minimum_size.x = 30
	left_btn.pressed.connect(_move_selected_poi.bind(-1, 0))
	pos_row.add_child(left_btn)

	var up_btn := Button.new()
	up_btn.text = "^"
	up_btn.tooltip_text = "Move North"
	up_btn.custom_minimum_size.x = 30
	up_btn.pressed.connect(_move_selected_poi.bind(0, -1))
	pos_row.add_child(up_btn)

	var down_btn := Button.new()
	down_btn.text = "v"
	down_btn.tooltip_text = "Move South"
	down_btn.custom_minimum_size.x = 30
	down_btn.pressed.connect(_move_selected_poi.bind(0, 1))
	pos_row.add_child(down_btn)

	var right_btn := Button.new()
	right_btn.text = ">"
	right_btn.tooltip_text = "Move East"
	right_btn.custom_minimum_size.x = 30
	right_btn.pressed.connect(_move_selected_poi.bind(1, 0))
	pos_row.add_child(right_btn)

	poi_position_label = Label.new()
	poi_position_label.text = "(X: 0, Y: 0)"
	pos_row.add_child(poi_position_label)

	selected_poi_panel.add_child(pos_row)

	var notes_row := HBoxContainer.new()
	notes_row.add_child(_make_label("Notes:"))
	poi_notes_edit = LineEdit.new()
	poi_notes_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poi_notes_edit.text_changed.connect(_on_poi_notes_changed)
	notes_row.add_child(poi_notes_edit)
	selected_poi_panel.add_child(notes_row)

	var scene_row := HBoxContainer.new()
	scene_row.add_child(_make_label("Scene:"))
	poi_scene_edit = LineEdit.new()
	poi_scene_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poi_scene_edit.placeholder_text = "res://scenes/levels/..."
	poi_scene_edit.text_changed.connect(_on_poi_scene_changed)
	scene_row.add_child(poi_scene_edit)
	selected_poi_panel.add_child(scene_row)

	var id_row := HBoxContainer.new()
	id_row.add_child(_make_label("ID:"))
	poi_location_id_edit = LineEdit.new()
	poi_location_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poi_location_id_edit.placeholder_text = "location_id"
	poi_location_id_edit.text_changed.connect(_on_poi_location_id_changed)
	id_row.add_child(poi_location_id_edit)
	selected_poi_panel.add_child(id_row)

	var delete_btn := Button.new()
	delete_btn.text = "Delete Location"
	delete_btn.pressed.connect(_on_delete_poi_pressed)
	selected_poi_panel.add_child(delete_btn)

	vbox.add_child(selected_poi_panel)

	return vbox


func _create_toolbar() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Brush size
	hbox.add_child(_make_label("Brush:"))

	brush_size_group = ButtonGroup.new()
	for size_val: int in [1, 3, 5]:
		var btn := Button.new()
		btn.text = "%dx%d" % [size_val, size_val]
		btn.toggle_mode = true
		btn.button_group = brush_size_group
		btn.button_pressed = (size_val == 1)
		btn.pressed.connect(_on_brush_size_changed.bind(size_val))
		hbox.add_child(btn)

	# Eraser
	eraser_button = CheckButton.new()
	eraser_button.text = "Eraser"
	eraser_button.toggled.connect(_on_eraser_toggled)
	hbox.add_child(eraser_button)

	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# Visibility toggles
	hbox.add_child(_make_label("Show:"))
	for layer: String in ["biome", "elevation", "water", "poi"]:
		var check := CheckButton.new()
		check.text = layer.substr(0, 1).to_upper()
		check.tooltip_text = layer.capitalize()
		check.button_pressed = true
		check.toggled.connect(_on_visibility_toggled.bind(layer))
		visibility_checks[layer] = check
		hbox.add_child(check)

	return hbox


func _create_info_bar() -> Control:
	var hbox := HBoxContainer.new()

	coords_label = Label.new()
	coords_label.text = "Cell: --"
	hbox.add_child(coords_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	zoom_label = Label.new()
	zoom_label.text = "Zoom: 100%"
	hbox.add_child(zoom_label)

	return hbox


func _create_footer() -> Control:
	var vbox := VBoxContainer.new()

	var row1 := HBoxContainer.new()

	var export_btn := Button.new()
	export_btn.text = "Export JSON"
	export_btn.pressed.connect(_on_export_pressed)
	row1.add_child(export_btn)

	var import_btn := Button.new()
	import_btn.text = "Import JSON"
	import_btn.pressed.connect(_on_import_pressed)
	row1.add_child(import_btn)

	var apply_btn := Button.new()
	apply_btn.text = "Apply to Game"
	apply_btn.pressed.connect(_on_apply_pressed)
	row1.add_child(apply_btn)

	vbox.add_child(row1)

	var row2 := HBoxContainer.new()

	var clear_btn := Button.new()
	clear_btn.text = "Clear All"
	clear_btn.pressed.connect(_on_clear_pressed)
	row2.add_child(clear_btn)

	var reload_btn := Button.new()
	reload_btn.text = "Reload from WorldGrid"
	reload_btn.pressed.connect(_on_reload_pressed)
	row2.add_child(reload_btn)

	vbox.add_child(row2)

	status_label = Label.new()
	status_label.text = "Ready"
	vbox.add_child(status_label)

	return vbox


func _connect_signals() -> void:
	grid_width_spin.value_changed.connect(_on_grid_size_changed)
	grid_height_spin.value_changed.connect(_on_grid_size_changed)
	origin_x_spin.value_changed.connect(_on_origin_changed)
	origin_y_spin.value_changed.connect(_on_origin_changed)
	layer_tabs.tab_changed.connect(_on_layer_tab_changed)

	canvas.cell_painted.connect(_on_cell_painted)
	canvas.cell_erased.connect(_on_cell_erased)
	canvas.poi_selected.connect(_on_poi_selected)
	canvas.poi_moved.connect(_on_poi_moved)
	canvas.poi_double_clicked.connect(_on_poi_double_clicked)
	canvas.canvas_zoomed.connect(_on_canvas_zoomed)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


# Signal handlers
func _on_grid_size_changed(_value: float) -> void:
	map_state.grid_width = int(grid_width_spin.value)
	map_state.grid_height = int(grid_height_spin.value)
	map_state._init_layers()
	canvas.queue_redraw()


func _on_origin_changed(_value: float) -> void:
	map_state.origin = Vector2i(int(origin_x_spin.value), int(origin_y_spin.value))
	canvas.queue_redraw()


func _on_center_pressed() -> void:
	canvas.center_on_origin()


func _on_layer_tab_changed(tab: int) -> void:
	var layer_names: Array[String] = ["biome", "elevation", "water", "poi"]
	if tab >= 0 and tab < layer_names.size():
		editor_state.current_layer = layer_names[tab]
		# Set default brush for layer
		match editor_state.current_layer:
			"biome":
				editor_state.current_brush = "forest"
			"elevation":
				editor_state.current_brush = "hill"
			"water":
				editor_state.current_brush = "lake"
			"poi":
				editor_state.current_brush = "town"


func _on_brush_selected(layer: String, value: String) -> void:
	editor_state.current_layer = layer
	editor_state.current_brush = value
	_set_status("Brush: %s (%s)" % [value, layer])


func _on_brush_size_changed(size_val: int) -> void:
	editor_state.brush_size = size_val


func _on_eraser_toggled(pressed: bool) -> void:
	editor_state.is_eraser = pressed


func _on_visibility_toggled(pressed: bool, layer: String) -> void:
	editor_state.layer_visibility[layer] = pressed
	canvas.queue_redraw()


func _on_cell_painted(x: int, y: int, layer: String, value) -> void:
	map_state.set_layer_value(layer, x, y, value)

	# If painting a POI, create poi_data entry
	if layer == "poi" and value != null:
		var index: int = map_state.get_cell_index(x, y)
		if not map_state.poi_data.has(str(index)):
			var world_coords := canvas.editor_to_world(Vector2i(x, y))
			map_state.poi_data[str(index)] = {
				"name": "",
				"type": value,
				"notes": "",
				"x": x,
				"y": y,
				"world_x": world_coords.x,
				"world_y": world_coords.y,
				"scene_path": "",
				"location_id": ""
			}
		_update_location_list()

	canvas.queue_redraw()
	_update_coords_label(x, y)


func _on_cell_erased(x: int, y: int, layer: String) -> void:
	map_state.set_layer_value(layer, x, y, null)

	# If erasing a POI, remove poi_data entry
	if layer == "poi":
		var index: int = map_state.get_cell_index(x, y)
		map_state.poi_data.erase(str(index))
		_update_location_list()

	canvas.queue_redraw()


func _on_poi_selected(index: int) -> void:
	editor_state.selected_poi_index = index
	_update_poi_panel()


func _on_poi_moved(index: int, new_x: int, new_y: int) -> void:
	# Validate new position is in bounds
	if new_x < 0 or new_x >= map_state.grid_width or new_y < 0 or new_y >= map_state.grid_height:
		_set_status("Cannot move POI out of bounds")
		return

	# Get old position
	var old_coords := map_state.get_cell_coords(index)

	# Don't move if same position
	if old_coords.x == new_x and old_coords.y == new_y:
		return

	# Move POI data
	var poi_info: Dictionary = map_state.poi_data.get(str(index), {}).duplicate()
	var poi_type: Variant = map_state.get_layer_value("poi", old_coords.x, old_coords.y)

	# Validate we actually have POI data
	if poi_type == null:
		_set_status("No POI data found at source position")
		return

	# Clear old position
	map_state.set_layer_value("poi", old_coords.x, old_coords.y, null)
	map_state.poi_data.erase(str(index))

	# Set new position
	map_state.set_layer_value("poi", new_x, new_y, poi_type)
	var new_index: int = map_state.get_cell_index(new_x, new_y)
	var world_coords := canvas.editor_to_world(Vector2i(new_x, new_y))
	poi_info["x"] = new_x
	poi_info["y"] = new_y
	poi_info["world_x"] = world_coords.x
	poi_info["world_y"] = world_coords.y
	map_state.poi_data[str(new_index)] = poi_info

	editor_state.selected_poi_index = new_index
	_update_location_list()
	_update_poi_panel()
	canvas.queue_redraw()

	_set_status("Moved POI to (%d, %d)" % [new_x, new_y])


func _move_selected_poi(dx: int, dy: int) -> void:
	if editor_state.selected_poi_index < 0:
		_set_status("No POI selected")
		return

	var key: String = str(editor_state.selected_poi_index)
	if not map_state.poi_data.has(key):
		_set_status("Selected POI not found")
		return

	var poi_info: Dictionary = map_state.poi_data[key]
	var old_x: int = poi_info.get("x", 0)
	var old_y: int = poi_info.get("y", 0)
	var new_x: int = old_x + dx
	var new_y: int = old_y + dy

	# Delegate to the existing move logic
	_on_poi_moved(editor_state.selected_poi_index, new_x, new_y)


func _on_poi_double_clicked(index: int) -> void:
	editor_state.selected_poi_index = index
	_update_poi_panel()
	# Focus the name edit
	if poi_name_edit:
		poi_name_edit.grab_focus()


func _on_canvas_zoomed(zoom: float) -> void:
	zoom_label.text = "Zoom: %d%%" % int(zoom * 100)


func _on_location_list_selected(index: int) -> void:
	if index >= 0 and index < location_list.item_count:
		var poi_index: int = location_list.get_item_metadata(index)
		editor_state.selected_poi_index = poi_index
		_update_poi_panel()
		canvas.queue_redraw()


func _on_add_poi_pressed() -> void:
	if new_poi_name_edit.text.is_empty():
		_set_status("Enter a name for the new location")
		return

	# Add at origin by default
	var x: int = map_state.origin.x
	var y: int = map_state.origin.y
	var poi_type: String = WorldForgeData.POI_VALUES[new_poi_type_option.selected]

	map_state.set_layer_value("poi", x, y, poi_type)
	var index: int = map_state.get_cell_index(x, y)
	var world_coords := canvas.editor_to_world(Vector2i(x, y))
	map_state.poi_data[str(index)] = {
		"name": new_poi_name_edit.text,
		"type": poi_type,
		"notes": "",
		"x": x,
		"y": y,
		"world_x": world_coords.x,
		"world_y": world_coords.y,
		"scene_path": "",
		"location_id": new_poi_name_edit.text.to_snake_case()
	}

	new_poi_name_edit.text = ""
	_update_location_list()
	canvas.queue_redraw()
	_set_status("Added new location: %s" % map_state.poi_data[str(index)]["name"])


func _on_delete_poi_pressed() -> void:
	if editor_state.selected_poi_index < 0:
		return

	var coords := map_state.get_cell_coords(editor_state.selected_poi_index)
	map_state.set_layer_value("poi", coords.x, coords.y, null)
	map_state.poi_data.erase(str(editor_state.selected_poi_index))

	editor_state.selected_poi_index = -1
	_update_location_list()
	_update_poi_panel()
	canvas.queue_redraw()
	_set_status("Deleted location")


func _on_poi_name_changed(new_text: String) -> void:
	if editor_state.selected_poi_index >= 0:
		var key: String = str(editor_state.selected_poi_index)
		if map_state.poi_data.has(key):
			map_state.poi_data[key]["name"] = new_text
			_update_location_list()


func _on_poi_type_changed(index: int) -> void:
	if editor_state.selected_poi_index >= 0:
		var key: String = str(editor_state.selected_poi_index)
		var poi_type: String = WorldForgeData.POI_VALUES[index]
		if map_state.poi_data.has(key):
			map_state.poi_data[key]["type"] = poi_type
			var coords := map_state.get_cell_coords(editor_state.selected_poi_index)
			map_state.set_layer_value("poi", coords.x, coords.y, poi_type)
			canvas.queue_redraw()


func _on_poi_notes_changed(new_text: String) -> void:
	if editor_state.selected_poi_index >= 0:
		var key: String = str(editor_state.selected_poi_index)
		if map_state.poi_data.has(key):
			map_state.poi_data[key]["notes"] = new_text


func _on_poi_scene_changed(new_text: String) -> void:
	if editor_state.selected_poi_index >= 0:
		var key: String = str(editor_state.selected_poi_index)
		if map_state.poi_data.has(key):
			map_state.poi_data[key]["scene_path"] = new_text


func _on_poi_location_id_changed(new_text: String) -> void:
	if editor_state.selected_poi_index >= 0:
		var key: String = str(editor_state.selected_poi_index)
		if map_state.poi_data.has(key):
			map_state.poi_data[key]["location_id"] = new_text


func _update_poi_panel() -> void:
	if editor_state.selected_poi_index < 0:
		selected_poi_panel.visible = false
		return

	var key: String = str(editor_state.selected_poi_index)
	if not map_state.poi_data.has(key):
		selected_poi_panel.visible = false
		return

	selected_poi_panel.visible = true
	var poi_info: Dictionary = map_state.poi_data[key]

	poi_name_edit.text = poi_info.get("name", "")
	poi_notes_edit.text = poi_info.get("notes", "")
	poi_scene_edit.text = poi_info.get("scene_path", "")
	poi_location_id_edit.text = poi_info.get("location_id", "")

	var poi_type: String = poi_info.get("type", "town")
	var type_index: int = WorldForgeData.POI_VALUES.find(poi_type)
	if type_index >= 0:
		poi_type_option.selected = type_index

	# Update position label with world coordinates
	var world_x: int = poi_info.get("world_x", 0)
	var world_y: int = poi_info.get("world_y", 0)
	poi_position_label.text = "(X: %d, Y: %d)" % [world_x, world_y]


func _update_location_list() -> void:
	location_list.clear()

	for key: String in map_state.poi_data:
		var poi_info: Dictionary = map_state.poi_data[key]
		var name_str: String = poi_info.get("name", "Unnamed")
		var type_str: String = poi_info.get("type", "town")
		var x: int = poi_info.get("world_x", 0)
		var y: int = poi_info.get("world_y", 0)

		var display := "%s (%d, %d) - %s" % [name_str, x, y, type_str]
		var idx: int = location_list.add_item(display)
		location_list.set_item_metadata(idx, int(key))


func _update_coords_label(x: int, y: int) -> void:
	var world_coords := canvas.editor_to_world(Vector2i(x, y))
	coords_label.text = "Cell: (%d, %d) World: (%d, %d)" % [x, y, world_coords.x, world_coords.y]


func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text


# Export/Import
func _on_export_pressed() -> void:
	var data: Dictionary = map_state.to_dict()
	var json_str: String = JSON.stringify(data, "  ")

	var file := FileAccess.open(EXPORT_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		_set_status("Exported to: %s" % EXPORT_PATH)
	else:
		_set_status("Failed to export!")


func _on_import_pressed() -> void:
	if not FileAccess.file_exists(EXPORT_PATH):
		_set_status("No export file found at: %s" % EXPORT_PATH)
		return

	var file := FileAccess.open(EXPORT_PATH, FileAccess.READ)
	if not file:
		_set_status("Failed to open export file!")
		return

	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_str)
	if error != OK:
		_set_status("Failed to parse JSON: %s" % json.get_error_message())
		return

	if not json.data is Dictionary:
		_set_status("Invalid JSON format!")
		return
	var data: Dictionary = json.data
	map_state.from_dict(data)

	# Update UI
	grid_width_spin.value = map_state.grid_width
	grid_height_spin.value = map_state.grid_height
	origin_x_spin.value = map_state.origin.x
	origin_y_spin.value = map_state.origin.y

	_update_location_list()
	canvas.queue_redraw()
	_set_status("Imported from: %s" % EXPORT_PATH)


func _on_apply_pressed() -> void:
	# Export first
	_on_export_pressed()

	# Note: In editor, we can't directly call runtime autoloads
	# The WorldForgeImporter will load on next game run
	_set_status("Exported. Changes will apply on next game run.")


func _on_clear_pressed() -> void:
	map_state.clear_all()
	_update_location_list()
	canvas.queue_redraw()
	_set_status("Cleared all data")


func _on_reload_pressed() -> void:
	_load_from_world_grid()


func _load_from_world_grid() -> void:
	# This runs in the editor, so we need to load the WorldGrid script
	var world_grid_script = load("res://scripts/data/world_grid.gd")
	if not world_grid_script:
		_set_status("Could not load WorldGrid script")
		return

	# Get constants from the script
	var grid_data: Array = world_grid_script.GRID_DATA
	var locations_data: Array = world_grid_script.LOCATIONS
	var road_connections: Array = world_grid_script.ROAD_CONNECTIONS
	var terrain_map: Dictionary = world_grid_script.TERRAIN_MAP
	var internal_offset: Vector2i = world_grid_script._INTERNAL_OFFSET

	if grid_data.is_empty():
		_set_status("WorldGrid GRID_DATA is empty")
		return

	# Clear and resize map state
	var grid_rows: int = grid_data.size()
	var grid_cols: int = grid_data[0].size() if grid_rows > 0 else 0

	# Set grid size to accommodate WorldGrid data
	# WorldGrid uses Elder Moor at internal (12, 8)
	# We want a 64x64 grid with origin at center (32, 32)
	map_state.grid_width = 64
	map_state.grid_height = 64
	map_state.origin = Vector2i(32, 32)
	map_state._init_layers()
	map_state.poi_data.clear()

	# Update UI spinboxes
	grid_width_spin.value = map_state.grid_width
	grid_height_spin.value = map_state.grid_height
	origin_x_spin.value = map_state.origin.x
	origin_y_spin.value = map_state.origin.y

	# Map terrain characters to biome values
	var terrain_to_biome: Dictionary = {
		"F": "forest",
		"S": "swamp",
		"D": "desert",
		"H": "tundra",  # Highlands -> tundra
		"R": "plains",  # Road -> plains
		"P": "plains",  # POI -> plains
		"B": null,      # Blocked -> no biome
		"W": null,      # Water -> no biome
		"C": null       # Coast -> no biome
	}

	var terrain_to_elevation: Dictionary = {
		"B": "mountain",
		"H": "hill"
	}

	var terrain_to_water: Dictionary = {
		"W": "ocean",
		"C": "river"
	}

	# First pass: terrain data
	for row: int in range(grid_rows):
		for col: int in range(grid_cols):
			var terrain_char: String = grid_data[row][col]

			# Convert raw coords to Elder Moor-relative
			var world_coords := Vector2i(col, row) - internal_offset
			# Convert to editor coords
			var editor_coords := world_coords + map_state.origin

			if editor_coords.x < 0 or editor_coords.x >= map_state.grid_width:
				continue
			if editor_coords.y < 0 or editor_coords.y >= map_state.grid_height:
				continue

			# Set biome
			var biome_val = terrain_to_biome.get(terrain_char)
			if biome_val != null:
				map_state.set_layer_value("biome", editor_coords.x, editor_coords.y, biome_val)

			# Set elevation
			var elev_val = terrain_to_elevation.get(terrain_char)
			if elev_val != null:
				map_state.set_layer_value("elevation", editor_coords.x, editor_coords.y, elev_val)

			# Set water
			var water_val = terrain_to_water.get(terrain_char)
			if water_val != null:
				map_state.set_layer_value("water", editor_coords.x, editor_coords.y, water_val)

	# Second pass: location data
	var location_type_map: Dictionary = {
		"town": "town",
		"village": "village",
		"city": "city",
		"capital": "capital",
		"dungeon": "dungeon",
		"landmark": "landmark",
		"outpost": "outpost"
	}

	for loc: Dictionary in locations_data:
		var world_x: int = loc.get("x", 0)
		var world_y: int = loc.get("y", 0)
		var editor_coords := Vector2i(world_x, world_y) + map_state.origin

		if editor_coords.x < 0 or editor_coords.x >= map_state.grid_width:
			continue
		if editor_coords.y < 0 or editor_coords.y >= map_state.grid_height:
			continue

		var loc_type: String = loc.get("type", "landmark")
		var poi_type: String = location_type_map.get(loc_type, "landmark")

		map_state.set_layer_value("poi", editor_coords.x, editor_coords.y, poi_type)

		var index: int = map_state.get_cell_index(editor_coords.x, editor_coords.y)
		map_state.poi_data[str(index)] = {
			"name": loc.get("name", ""),
			"type": poi_type,
			"notes": loc.get("description", ""),
			"x": editor_coords.x,
			"y": editor_coords.y,
			"world_x": world_x,
			"world_y": world_y,
			"scene_path": world_grid_script.LOCATION_SCENES.get(loc.get("id", ""), ""),
			"location_id": loc.get("id", "")
		}

	# Load road connections for display
	var road_display: Array = []
	for road: Array in road_connections:
		if road.size() >= 2:
			var from_arr: Array = road[0]
			var to_arr: Array = road[1]
			var from_world := Vector2i(from_arr[0], from_arr[1])
			var to_world := Vector2i(to_arr[0], to_arr[1])
			var from_editor := from_world + map_state.origin
			var to_editor := to_world + map_state.origin
			road_display.append([from_editor, to_editor])

	canvas.set_road_connections(road_display)

	_update_location_list()
	canvas.queue_redraw()
	canvas.center_on_origin()
	_set_status("Loaded %d cells, %d locations from WorldGrid" % [grid_rows * grid_cols, locations_data.size()])
