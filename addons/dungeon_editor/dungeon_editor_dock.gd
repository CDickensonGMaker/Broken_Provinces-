@tool
## dungeon_editor_dock.gd - Visual grid-based dungeon layout editor
## Provides a visual interface to paint dungeon layouts and export them
extends Control


## Constants
const CELL_SIZE: int = 40
const GRID_SIZE: int = 20  # 20x20 grid
const ROOM_SIZE: float = 16.0  # World units per room


## UI Elements
var grid_container: Control
var room_palette: ItemList
var validate_button: Button
var export_button: Button
var clear_button: Button
var load_button: Button
var save_button: Button
var generate_cave_button: Button
var status_label: Label
var dungeon_name_edit: LineEdit
var auto_correct_checkbox: CheckBox


## Grid state
var grid_data: Dictionary = {}  # Vector2i -> RoomType
var selected_room_type: int = DungeonGridData.RoomType.EMPTY
var grid_cells: Dictionary = {}  # Vector2i -> ColorRect (visual cells)
var auto_correct_enabled: bool = true  # Auto-fix connections by default


func _init() -> void:
	name = "DungeonEditorDock"


func _ready() -> void:
	_setup_ui()
	_setup_palette()
	_clear_grid()


func _setup_ui() -> void:
	# Main horizontal split
	var main_split := HSplitContainer.new()
	main_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_split)

	# Left panel - palette and controls
	var left_panel := VBoxContainer.new()
	left_panel.custom_minimum_size = Vector2(200, 0)
	main_split.add_child(left_panel)

	# Dungeon name
	var name_label := Label.new()
	name_label.text = "Dungeon Name:"
	left_panel.add_child(name_label)

	dungeon_name_edit = LineEdit.new()
	dungeon_name_edit.text = "new_dungeon"
	dungeon_name_edit.placeholder_text = "Enter dungeon name"
	left_panel.add_child(dungeon_name_edit)

	# Separator
	left_panel.add_child(HSeparator.new())

	# Auto-correct checkbox
	auto_correct_checkbox = CheckBox.new()
	auto_correct_checkbox.text = "Auto-fix Connections"
	auto_correct_checkbox.button_pressed = auto_correct_enabled
	auto_correct_checkbox.tooltip_text = "Automatically adjust adjacent rooms to connect properly"
	auto_correct_checkbox.toggled.connect(_on_auto_correct_toggled)
	left_panel.add_child(auto_correct_checkbox)

	# Separator
	left_panel.add_child(HSeparator.new())

	# Room type label
	var palette_label := Label.new()
	palette_label.text = "Room Types:"
	left_panel.add_child(palette_label)

	# Room palette
	room_palette = ItemList.new()
	room_palette.custom_minimum_size = Vector2(180, 300)
	room_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room_palette.item_selected.connect(_on_palette_item_selected)
	left_panel.add_child(room_palette)

	# Separator
	left_panel.add_child(HSeparator.new())

	# Buttons
	var button_container := VBoxContainer.new()
	left_panel.add_child(button_container)

	validate_button = Button.new()
	validate_button.text = "Validate & Auto-Fix"
	validate_button.pressed.connect(_on_validate_pressed)
	button_container.add_child(validate_button)

	export_button = Button.new()
	export_button.text = "Export to Scene"
	export_button.pressed.connect(_on_export_pressed)
	button_container.add_child(export_button)

	button_container.add_child(HSeparator.new())

	save_button = Button.new()
	save_button.text = "Save JSON"
	save_button.pressed.connect(_on_save_pressed)
	button_container.add_child(save_button)

	load_button = Button.new()
	load_button.text = "Load JSON"
	load_button.pressed.connect(_on_load_pressed)
	button_container.add_child(load_button)

	button_container.add_child(HSeparator.new())

	clear_button = Button.new()
	clear_button.text = "Clear Grid"
	clear_button.pressed.connect(_on_clear_pressed)
	button_container.add_child(clear_button)

	button_container.add_child(HSeparator.new())

	# Generate cave button
	generate_cave_button = Button.new()
	generate_cave_button.text = "Generate Random Cave"
	generate_cave_button.tooltip_text = "Generate a random procedural cave layout"
	generate_cave_button.pressed.connect(_on_generate_cave_pressed)
	button_container.add_child(generate_cave_button)

	# Status label
	status_label = Label.new()
	status_label.text = "Ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	left_panel.add_child(status_label)

	# Right panel - grid
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_split.add_child(right_panel)

	# Grid info label
	var grid_info := Label.new()
	grid_info.text = "Click to place room, Right-click to erase"
	right_panel.add_child(grid_info)

	# Scrollable grid container
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)

	grid_container = Control.new()
	grid_container.custom_minimum_size = Vector2(GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	grid_container.mouse_filter = Control.MOUSE_FILTER_STOP  # Capture mouse input
	grid_container.gui_input.connect(_on_grid_input)
	scroll.add_child(grid_container)

	# Draw grid background
	_draw_grid()


func _setup_palette() -> void:
	# Add all room types to palette
	var room_types: Array = [
		[DungeonGridData.RoomType.EMPTY, "Empty (Erase)", Color(0.2, 0.2, 0.2)],
		[DungeonGridData.RoomType.START, "Start Room", Color(0.3, 0.6, 0.3)],
		[DungeonGridData.RoomType.CORRIDOR_NS, "Corridor N-S", Color(0.5, 0.5, 0.5)],
		[DungeonGridData.RoomType.CORRIDOR_EW, "Corridor E-W", Color(0.5, 0.5, 0.5)],
		[DungeonGridData.RoomType.TURN_NE, "Turn N-E", Color(0.55, 0.5, 0.45)],
		[DungeonGridData.RoomType.TURN_NW, "Turn N-W", Color(0.55, 0.5, 0.45)],
		[DungeonGridData.RoomType.TURN_SE, "Turn S-E", Color(0.55, 0.5, 0.45)],
		[DungeonGridData.RoomType.TURN_SW, "Turn S-W", Color(0.55, 0.5, 0.45)],
		[DungeonGridData.RoomType.T_NORTH, "T-Junction N", Color(0.6, 0.55, 0.5)],
		[DungeonGridData.RoomType.T_SOUTH, "T-Junction S", Color(0.6, 0.55, 0.5)],
		[DungeonGridData.RoomType.T_EAST, "T-Junction E", Color(0.6, 0.55, 0.5)],
		[DungeonGridData.RoomType.T_WEST, "T-Junction W", Color(0.6, 0.55, 0.5)],
		[DungeonGridData.RoomType.CROSS, "Crossroads", Color(0.65, 0.6, 0.55)],
		[DungeonGridData.RoomType.ROOM_SMALL, "Small Room", Color(0.4, 0.4, 0.55)],
		[DungeonGridData.RoomType.ROOM_MEDIUM, "Medium Room", Color(0.4, 0.45, 0.55)],
		[DungeonGridData.RoomType.ROOM_LARGE, "Large Room", Color(0.45, 0.45, 0.6)],
		[DungeonGridData.RoomType.ROOM_BOSS, "Boss Room", Color(0.6, 0.35, 0.35)],
		[DungeonGridData.RoomType.DEAD_END_N, "Dead End N", Color(0.45, 0.4, 0.4)],
		[DungeonGridData.RoomType.DEAD_END_S, "Dead End S", Color(0.45, 0.4, 0.4)],
		[DungeonGridData.RoomType.DEAD_END_E, "Dead End E", Color(0.45, 0.4, 0.4)],
		[DungeonGridData.RoomType.DEAD_END_W, "Dead End W", Color(0.45, 0.4, 0.4)],
		[DungeonGridData.RoomType.HALLWAY_NS, "Hallway N-S (Narrow)", Color(0.4, 0.4, 0.4)],
		[DungeonGridData.RoomType.HALLWAY_EW, "Hallway E-W (Narrow)", Color(0.4, 0.4, 0.4)],
		# Cave room types - organic cave pieces
		[DungeonGridData.RoomType.CAVE_ENTRANCE, "Cave Entrance", Color(0.35, 0.5, 0.35)],
		[DungeonGridData.RoomType.CAVE_EXIT, "Cave Exit", Color(0.5, 0.4, 0.3)],
		[DungeonGridData.RoomType.CAVE_CORRIDOR_NS, "Cave N-S", Color(0.4, 0.35, 0.3)],
		[DungeonGridData.RoomType.CAVE_CORRIDOR_EW, "Cave E-W", Color(0.4, 0.35, 0.3)],
		[DungeonGridData.RoomType.CAVE_CORNER_NE, "Cave Turn N-E", Color(0.45, 0.38, 0.32)],
		[DungeonGridData.RoomType.CAVE_CORNER_NW, "Cave Turn N-W", Color(0.45, 0.38, 0.32)],
		[DungeonGridData.RoomType.CAVE_CORNER_SE, "Cave Turn S-E", Color(0.45, 0.38, 0.32)],
		[DungeonGridData.RoomType.CAVE_CORNER_SW, "Cave Turn S-W", Color(0.45, 0.38, 0.32)],
		[DungeonGridData.RoomType.CAVE_T_JUNCTION, "Cave T-Junction", Color(0.5, 0.42, 0.35)],
		[DungeonGridData.RoomType.CAVE_CROSSROADS, "Cave Crossroads", Color(0.55, 0.45, 0.38)],
		[DungeonGridData.RoomType.CAVE_DEAD_END, "Cave Dead End", Color(0.38, 0.32, 0.28)],
		[DungeonGridData.RoomType.CAVE_CHAMBER, "Cave Chamber (2x2)", Color(0.5, 0.45, 0.4)]
	]

	for type_info: Array in room_types:
		var type_id: int = type_info[0]
		var type_name: String = type_info[1]
		var type_color: Color = type_info[2]

		var idx: int = room_palette.add_item(type_name)
		room_palette.set_item_metadata(idx, type_id)

		# Create color icon
		var icon := _create_color_icon(type_color)
		room_palette.set_item_icon(idx, icon)

	# Select first item
	room_palette.select(0)
	selected_room_type = DungeonGridData.RoomType.EMPTY


func _create_color_icon(color: Color) -> ImageTexture:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _draw_grid() -> void:
	# Clear existing cells
	for child: Node in grid_container.get_children():
		child.queue_free()
	grid_cells.clear()

	# Draw grid lines and cells
	for y: int in range(GRID_SIZE):
		for x: int in range(GRID_SIZE):
			var cell := ColorRect.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)
			cell.color = Color(0.15, 0.15, 0.15)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through to grid_container
			grid_container.add_child(cell)

			var pos := Vector2i(x - GRID_SIZE / 2, y - GRID_SIZE / 2)
			grid_cells[pos] = cell


func _clear_grid() -> void:
	grid_data.clear()
	for pos: Vector2i in grid_cells.keys():
		var cell: ColorRect = grid_cells[pos]
		cell.color = Color(0.15, 0.15, 0.15)
	status_label.text = "Grid cleared"


func _on_palette_item_selected(index: int) -> void:
	selected_room_type = room_palette.get_item_metadata(index)


func _on_auto_correct_toggled(pressed: bool) -> void:
	auto_correct_enabled = pressed


func _on_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.pressed:
			var cell_pos: Vector2i = _screen_to_grid(mouse_event.position)

			if mouse_event.button_index == MOUSE_BUTTON_LEFT:
				_set_cell(cell_pos, selected_room_type)
			elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
				_set_cell(cell_pos, DungeonGridData.RoomType.EMPTY)

	elif event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		if motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var cell_pos: Vector2i = _screen_to_grid(motion_event.position)
			_set_cell(cell_pos, selected_room_type)
		elif motion_event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			var cell_pos: Vector2i = _screen_to_grid(motion_event.position)
			_set_cell(cell_pos, DungeonGridData.RoomType.EMPTY)


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var grid_x: int = int(screen_pos.x / CELL_SIZE) - GRID_SIZE / 2
	var grid_y: int = int(screen_pos.y / CELL_SIZE) - GRID_SIZE / 2
	return Vector2i(grid_x, grid_y)


func _set_cell(pos: Vector2i, room_type: int) -> void:
	if not grid_cells.has(pos):
		return

	if room_type == DungeonGridData.RoomType.EMPTY:
		grid_data.erase(pos)
		grid_cells[pos].color = Color(0.15, 0.15, 0.15)
		# When erasing, also auto-correct neighbors
		if auto_correct_enabled:
			_auto_correct_neighbors_after_erase(pos)
	else:
		grid_data[pos] = room_type
		grid_cells[pos].color = _get_room_color(room_type)
		# Auto-correct connections after placing
		if auto_correct_enabled:
			_auto_correct_connections(pos)


func _get_room_color(room_type: int) -> Color:
	match room_type:
		DungeonGridData.RoomType.START:
			return Color(0.3, 0.6, 0.3)
		DungeonGridData.RoomType.CORRIDOR_NS, DungeonGridData.RoomType.CORRIDOR_EW:
			return Color(0.5, 0.5, 0.5)
		DungeonGridData.RoomType.TURN_NE, DungeonGridData.RoomType.TURN_NW, \
		DungeonGridData.RoomType.TURN_SE, DungeonGridData.RoomType.TURN_SW:
			return Color(0.55, 0.5, 0.45)
		DungeonGridData.RoomType.T_NORTH, DungeonGridData.RoomType.T_SOUTH, \
		DungeonGridData.RoomType.T_EAST, DungeonGridData.RoomType.T_WEST:
			return Color(0.6, 0.55, 0.5)
		DungeonGridData.RoomType.CROSS:
			return Color(0.65, 0.6, 0.55)
		DungeonGridData.RoomType.ROOM_SMALL:
			return Color(0.4, 0.4, 0.55)
		DungeonGridData.RoomType.ROOM_MEDIUM:
			return Color(0.4, 0.45, 0.55)
		DungeonGridData.RoomType.ROOM_LARGE:
			return Color(0.45, 0.45, 0.6)
		DungeonGridData.RoomType.ROOM_BOSS:
			return Color(0.6, 0.35, 0.35)
		DungeonGridData.RoomType.DEAD_END_N, DungeonGridData.RoomType.DEAD_END_S, \
		DungeonGridData.RoomType.DEAD_END_E, DungeonGridData.RoomType.DEAD_END_W:
			return Color(0.45, 0.4, 0.4)
		DungeonGridData.RoomType.HALLWAY_NS, DungeonGridData.RoomType.HALLWAY_EW:
			return Color(0.4, 0.4, 0.4)
		# Cave room colors - earthy browns/greens
		DungeonGridData.RoomType.CAVE_ENTRANCE:
			return Color(0.35, 0.5, 0.35)
		DungeonGridData.RoomType.CAVE_EXIT:
			return Color(0.5, 0.4, 0.3)
		DungeonGridData.RoomType.CAVE_CORRIDOR_NS, DungeonGridData.RoomType.CAVE_CORRIDOR_EW:
			return Color(0.4, 0.35, 0.3)
		DungeonGridData.RoomType.CAVE_CORNER_NE, DungeonGridData.RoomType.CAVE_CORNER_NW, \
		DungeonGridData.RoomType.CAVE_CORNER_SE, DungeonGridData.RoomType.CAVE_CORNER_SW:
			return Color(0.45, 0.38, 0.32)
		DungeonGridData.RoomType.CAVE_T_JUNCTION:
			return Color(0.5, 0.42, 0.35)
		DungeonGridData.RoomType.CAVE_CROSSROADS:
			return Color(0.55, 0.45, 0.38)
		DungeonGridData.RoomType.CAVE_DEAD_END:
			return Color(0.38, 0.32, 0.28)
		DungeonGridData.RoomType.CAVE_CHAMBER:
			return Color(0.5, 0.45, 0.4)
	return Color(0.3, 0.3, 0.3)


func _on_validate_pressed() -> void:
	if grid_data.is_empty():
		status_label.text = "Grid is empty!"
		return

	# First, auto-fix all connection issues
	var fixes_made: int = _auto_fix_all_connections()

	# Then validate
	var result: DungeonValidator.ValidationResult = DungeonValidator.validate(grid_data)

	if result.is_valid:
		if fixes_made > 0:
			status_label.text = "Auto-fixed %d connections!\nValidation PASSED!" % fixes_made
		else:
			status_label.text = "Validation PASSED!\n"
		if result.warnings.size() > 0:
			status_label.text += "\nWarnings: %d" % result.warnings.size()
	else:
		status_label.text = "Validation FAILED!\n"
		status_label.text += "Errors: %d\n" % result.errors.size()
		if result.errors.size() > 0:
			status_label.text += result.errors[0]


## Auto-fix all connection issues in the grid
## Returns the number of fixes made
func _auto_fix_all_connections() -> int:
	var fixes_made: int = 0
	var positions_to_check: Array = grid_data.keys().duplicate()

	# Multiple passes to handle cascading fixes
	for _pass in range(3):
		var made_fix_this_pass: bool = false

		for pos: Vector2i in positions_to_check:
			if not grid_data.has(pos):
				continue

			var room_type: int = grid_data[pos]
			if room_type == DungeonGridData.RoomType.EMPTY:
				continue

			# Skip special rooms - they have all doors
			if DungeonGridData.is_special_room(room_type):
				continue

			# Calculate what doors this cell needs based on neighbors
			var needed_doors: Array = _calculate_needed_doors(pos)

			# Get current doors
			var current_doors: Array = DungeonGridData.get_doors(room_type)

			# Check if doors match what's needed
			var current_sorted: Array = current_doors.duplicate()
			current_sorted.sort()
			var needed_sorted: Array = needed_doors.duplicate()
			needed_sorted.sort()

			if current_sorted != needed_sorted:
				# Find a connector that matches the needed doors
				if needed_doors.is_empty():
					# No neighbors need this cell - remove it
					grid_data.erase(pos)
					if grid_cells.has(pos):
						grid_cells[pos].color = Color(0.15, 0.15, 0.15)
				else:
					var corrected_type: int = DungeonGridData.find_connector_with_doors(needed_doors)
					if corrected_type != room_type:
						grid_data[pos] = corrected_type
						if grid_cells.has(pos):
							grid_cells[pos].color = _get_room_color(corrected_type)
						fixes_made += 1
						made_fix_this_pass = true

		if not made_fix_this_pass:
			break

	return fixes_made


func _on_export_pressed() -> void:
	if grid_data.is_empty():
		status_label.text = "Cannot export empty grid!"
		return

	# Validate first
	var validation: DungeonValidator.ValidationResult = DungeonValidator.validate(grid_data)
	if not validation.is_valid:
		status_label.text = "Fix validation errors before exporting!"
		return

	# Build the dungeon
	var build_result: DungeonBuilder.BuildResult = DungeonBuilder.build(grid_data, null, false)

	if not build_result.success:
		status_label.text = "Build failed: " + build_result.errors[0] if build_result.errors.size() > 0 else "Unknown error"
		return

	# Attach the hand_crafted_dungeon script
	var dungeon_script: Script = load("res://scripts/dungeons/hand_crafted_dungeon.gd")
	if dungeon_script:
		build_result.dungeon_root.set_script(dungeon_script)

	# Pack and save the scene
	var packed_scene := PackedScene.new()
	var error: int = packed_scene.pack(build_result.dungeon_root)
	if error != OK:
		status_label.text = "Failed to pack scene!"
		build_result.dungeon_root.queue_free()
		return

	var scene_name: String = dungeon_name_edit.text.strip_edges()
	if scene_name.is_empty():
		scene_name = "new_dungeon"

	# Sanitize name
	scene_name = scene_name.replace(" ", "_").to_lower()

	var save_path: String = "res://scenes/dungeons/%s.tscn" % scene_name

	# Ensure directory exists
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("scenes/dungeons"):
		dir.make_dir_recursive("scenes/dungeons")

	error = ResourceSaver.save(packed_scene, save_path)
	if error == OK:
		status_label.text = "Exported to:\n%s" % save_path
		EditorInterface.get_resource_filesystem().scan()
	else:
		status_label.text = "Failed to save scene!"

	build_result.dungeon_root.queue_free()


func _on_save_pressed() -> void:
	if grid_data.is_empty():
		status_label.text = "Cannot save empty grid!"
		return

	var dungeon_name: String = dungeon_name_edit.text.strip_edges()
	if dungeon_name.is_empty():
		dungeon_name = "new_dungeon"

	dungeon_name = dungeon_name.replace(" ", "_").to_lower()

	var save_path: String = "res://data/dungeons/layouts/%s.json" % dungeon_name

	# Ensure directory exists
	var dir := DirAccess.open("res://")
	if dir:
		if not dir.dir_exists("data/dungeons"):
			dir.make_dir_recursive("data/dungeons/layouts")
		elif not dir.dir_exists("data/dungeons/layouts"):
			dir.make_dir("data/dungeons/layouts")

	if DungeonBuilder.save_grid_to_json(grid_data, save_path):
		status_label.text = "Saved to:\n%s" % save_path
		EditorInterface.get_resource_filesystem().scan()
	else:
		status_label.text = "Failed to save JSON!"


func _on_load_pressed() -> void:
	# Create file dialog
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.json", "JSON Files")
	dialog.current_dir = "res://data/dungeons/layouts/"
	dialog.file_selected.connect(_on_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_file_selected(path: String) -> void:
	var loaded_grid: Dictionary = DungeonBuilder.load_grid_from_json(path)

	if loaded_grid.is_empty():
		status_label.text = "Failed to load or empty file!"
		return

	_clear_grid()
	grid_data = loaded_grid

	# Update visual grid
	for pos: Vector2i in grid_data.keys():
		var room_type: int = grid_data[pos]
		if grid_cells.has(pos):
			grid_cells[pos].color = _get_room_color(room_type)

	# Extract name from path
	var file_name: String = path.get_file().get_basename()
	dungeon_name_edit.text = file_name

	status_label.text = "Loaded: %s\nRooms: %d" % [file_name, grid_data.size()]


func _on_clear_pressed() -> void:
	_clear_grid()


func _on_generate_cave_pressed() -> void:
	_clear_grid()

	# Generate random cave using CaveGenerator
	var cave_grid: Dictionary = CaveGenerator.generate(
		randi_range(6, 10),  # Main path length
		randi_range(1, 3),   # Branch count
		-1                    # Random seed
	)

	# Apply to editor grid
	for pos: Vector2i in cave_grid.keys():
		var room_type: int = cave_grid[pos]
		if grid_cells.has(pos):
			grid_data[pos] = room_type
			grid_cells[pos].color = _get_room_color(room_type)

	status_label.text = "Generated cave with %d rooms" % cave_grid.size()


## Auto-correct adjacent rooms when a room is placed
## This ensures connections match up properly
func _auto_correct_connections(placed_pos: Vector2i) -> void:
	if not grid_data.has(placed_pos):
		return

	var placed_type: int = grid_data[placed_pos]
	var placed_doors: Array = DungeonGridData.get_doors(placed_type)

	# Direction info: [Direction enum, Vector2i offset]
	var directions: Array = [
		[DungeonGridData.Direction.NORTH, Vector2i(0, -1)],
		[DungeonGridData.Direction.SOUTH, Vector2i(0, 1)],
		[DungeonGridData.Direction.EAST, Vector2i(1, 0)],
		[DungeonGridData.Direction.WEST, Vector2i(-1, 0)]
	]

	for dir_info: Array in directions:
		var dir: int = dir_info[0]
		var offset: Vector2i = dir_info[1]
		var neighbor_pos: Vector2i = placed_pos + offset

		if not grid_data.has(neighbor_pos):
			continue

		var neighbor_type: int = grid_data[neighbor_pos]
		var opposite_dir: int = DungeonGridData.get_opposite_direction(dir)

		# Check door states
		var placed_has_door: bool = dir in placed_doors
		var neighbor_has_door: bool = DungeonGridData.has_door(neighbor_type, opposite_dir)

		# If there's a mismatch, fix the neighbor (not special rooms)
		if placed_has_door != neighbor_has_door:
			if DungeonGridData.is_special_room(neighbor_type):
				# Don't modify special rooms - they have all doors anyway
				continue

			# Calculate what doors the neighbor needs
			var needed_doors: Array = _calculate_needed_doors(neighbor_pos)

			# If placed room has a door toward neighbor, neighbor needs door back
			if placed_has_door and opposite_dir not in needed_doors:
				needed_doors.append(opposite_dir)
			# If placed room doesn't have door toward neighbor, neighbor shouldn't have one either
			elif not placed_has_door:
				needed_doors.erase(opposite_dir)

			if needed_doors.is_empty():
				# No doors needed - remove the room
				grid_data.erase(neighbor_pos)
				if grid_cells.has(neighbor_pos):
					grid_cells[neighbor_pos].color = Color(0.15, 0.15, 0.15)
			else:
				# Find a connector that matches
				var corrected_type: int = DungeonGridData.find_connector_with_doors(needed_doors)
				if corrected_type != neighbor_type:
					grid_data[neighbor_pos] = corrected_type
					if grid_cells.has(neighbor_pos):
						grid_cells[neighbor_pos].color = _get_room_color(corrected_type)


## Auto-correct neighbors when a room is erased
## Neighbors that pointed to this cell need to remove their doors
func _auto_correct_neighbors_after_erase(erased_pos: Vector2i) -> void:
	var directions: Array = [
		[DungeonGridData.Direction.NORTH, Vector2i(0, -1)],
		[DungeonGridData.Direction.SOUTH, Vector2i(0, 1)],
		[DungeonGridData.Direction.EAST, Vector2i(1, 0)],
		[DungeonGridData.Direction.WEST, Vector2i(-1, 0)]
	]

	for dir_info: Array in directions:
		var dir: int = dir_info[0]
		var offset: Vector2i = dir_info[1]
		var neighbor_pos: Vector2i = erased_pos + offset

		if not grid_data.has(neighbor_pos):
			continue

		var neighbor_type: int = grid_data[neighbor_pos]
		var opposite_dir: int = DungeonGridData.get_opposite_direction(dir)

		# Skip special rooms
		if DungeonGridData.is_special_room(neighbor_type):
			continue

		# If neighbor has a door toward the erased cell, it needs fixing
		if DungeonGridData.has_door(neighbor_type, opposite_dir):
			var needed_doors: Array = _calculate_needed_doors(neighbor_pos)
			# Remove the door that pointed to erased cell
			needed_doors.erase(opposite_dir)

			if needed_doors.is_empty():
				# No doors needed - remove the room
				grid_data.erase(neighbor_pos)
				if grid_cells.has(neighbor_pos):
					grid_cells[neighbor_pos].color = Color(0.15, 0.15, 0.15)
			else:
				var corrected_type: int = DungeonGridData.find_connector_with_doors(needed_doors)
				if corrected_type != neighbor_type:
					grid_data[neighbor_pos] = corrected_type
					if grid_cells.has(neighbor_pos):
						grid_cells[neighbor_pos].color = _get_room_color(corrected_type)


## Calculate what doors a cell needs based on its neighbors
func _calculate_needed_doors(pos: Vector2i) -> Array:
	var needed: Array = []

	var directions: Array = [
		[DungeonGridData.Direction.NORTH, Vector2i(0, -1)],
		[DungeonGridData.Direction.SOUTH, Vector2i(0, 1)],
		[DungeonGridData.Direction.EAST, Vector2i(1, 0)],
		[DungeonGridData.Direction.WEST, Vector2i(-1, 0)]
	]

	for dir_info: Array in directions:
		var dir: int = dir_info[0]
		var offset: Vector2i = dir_info[1]
		var neighbor_pos: Vector2i = pos + offset

		if not grid_data.has(neighbor_pos):
			continue

		var neighbor_type: int = grid_data[neighbor_pos]
		var opposite_dir: int = DungeonGridData.get_opposite_direction(dir)

		# If neighbor has a door facing us, we need a door facing them
		if DungeonGridData.has_door(neighbor_type, opposite_dir):
			needed.append(dir)

	return needed
