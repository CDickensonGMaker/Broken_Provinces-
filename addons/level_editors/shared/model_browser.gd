@tool
class_name ModelBrowser
extends Control
## Browser panel for selecting custom 3D models (.glb, .gltf, .tscn, .obj)

signal model_selected(path: String)

const SUPPORTED_EXTENSIONS: Array[String] = ["glb", "gltf", "tscn", "obj"]
const MODELS_ROOT: String = "res://assets/models"
const THUMBNAIL_SIZE: Vector2 = Vector2(64, 64)

var model_list: ItemList
var search_edit: LineEdit
var path_label: Label
var refresh_btn: Button

var all_models: Array[Dictionary] = []  # {path, name, extension}
var filtered_models: Array[Dictionary] = []
var recent_models: Array[String] = []
var favorites: Array[String] = []

const MAX_RECENT: int = 10


func _ready() -> void:
	_build_ui()
	call_deferred("_scan_models")


func _build_ui() -> void:
	custom_minimum_size = Vector2(200, 300)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "3D Models"
	header.add_theme_font_size_override("font_size", 14)
	vbox.add_child(header)

	# Search bar
	var search_row := HBoxContainer.new()
	vbox.add_child(search_row)

	search_edit = LineEdit.new()
	search_edit.placeholder_text = "Search..."
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.text_changed.connect(_on_search_changed)
	search_row.add_child(search_edit)

	refresh_btn = Button.new()
	refresh_btn.text = "R"
	refresh_btn.tooltip_text = "Refresh model list"
	refresh_btn.pressed.connect(_scan_models)
	search_row.add_child(refresh_btn)

	# Model list
	model_list = ItemList.new()
	model_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	model_list.icon_mode = ItemList.ICON_MODE_TOP
	model_list.fixed_icon_size = Vector2i(THUMBNAIL_SIZE)
	model_list.max_columns = 0
	model_list.same_column_width = true
	model_list.item_selected.connect(_on_model_selected)
	model_list.item_activated.connect(_on_model_activated)
	vbox.add_child(model_list)

	# Path display
	path_label = Label.new()
	path_label.text = ""
	path_label.add_theme_font_size_override("font_size", 10)
	path_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(path_label)

	# Browse button
	var browse_btn := Button.new()
	browse_btn.text = "Browse Files..."
	browse_btn.pressed.connect(_on_browse_pressed)
	vbox.add_child(browse_btn)


func _scan_models() -> void:
	all_models.clear()
	_scan_directory(MODELS_ROOT)

	# Also scan common asset folders
	var extra_paths: Array[String] = [
		"res://assets/buildings",
		"res://assets/props",
		"res://assets/environment"
	]
	for path in extra_paths:
		if DirAccess.dir_exists_absolute(path):
			_scan_directory(path)

	# Sort by name
	all_models.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.name.to_lower() < b.name.to_lower()
	)

	_apply_filter()
	print("[ModelBrowser] Found %d models" % all_models.size())


func _scan_directory(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		var full_path := dir_path.path_join(file_name)

		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory(full_path)
		else:
			var ext := file_name.get_extension().to_lower()
			if ext in SUPPORTED_EXTENSIONS:
				all_models.append({
					"path": full_path,
					"name": file_name.get_basename(),
					"extension": ext
				})

		file_name = dir.get_next()

	dir.list_dir_end()


func _apply_filter() -> void:
	var search_text := search_edit.text.to_lower().strip_edges() if search_edit else ""

	filtered_models.clear()

	for model: Dictionary in all_models:
		if search_text.is_empty() or search_text in model.name.to_lower():
			filtered_models.append(model)

	_update_list()


func _update_list() -> void:
	model_list.clear()

	# Add recent models first (if no search)
	if search_edit.text.is_empty() and not recent_models.is_empty():
		for path in recent_models:
			var name := path.get_file().get_basename()
			var idx := model_list.add_item("[Recent] " + name)
			model_list.set_item_metadata(idx, path)
			model_list.set_item_tooltip(idx, path)

		# Separator
		var sep_idx := model_list.add_item("──────────")
		model_list.set_item_disabled(sep_idx, true)
		model_list.set_item_selectable(sep_idx, false)

	# Add filtered models
	for model: Dictionary in filtered_models:
		var icon := _get_icon_for_extension(model.extension)
		var idx := model_list.add_item(model.name, icon)
		model_list.set_item_metadata(idx, model.path)
		model_list.set_item_tooltip(idx, model.path)


func _get_icon_for_extension(ext: String) -> Texture2D:
	# Return simple colored box icons based on type
	var color: Color
	match ext:
		"glb", "gltf":
			color = Color(0.3, 0.7, 0.3)  # Green for GLTF
		"tscn":
			color = Color(0.3, 0.5, 0.8)  # Blue for scenes
		"obj":
			color = Color(0.7, 0.5, 0.3)  # Orange for OBJ
		_:
			color = Color(0.5, 0.5, 0.5)

	# Create simple placeholder icon
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


func _on_search_changed(_text: String) -> void:
	_apply_filter()


func _on_model_selected(index: int) -> void:
	var metadata: Variant = model_list.get_item_metadata(index)
	var path: String = str(metadata) if metadata else ""
	if path:
		path_label.text = path.get_file()


func _on_model_activated(index: int) -> void:
	var metadata: Variant = model_list.get_item_metadata(index)
	var path: String = str(metadata) if metadata else ""
	if path:
		_add_to_recent(path)
		model_selected.emit(path)


func _on_browse_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.title = "Select 3D Model"

	for ext in SUPPORTED_EXTENSIONS:
		dialog.add_filter("*." + ext)

	dialog.file_selected.connect(func(path: String) -> void:
		_add_to_recent(path)
		model_selected.emit(path)
		dialog.queue_free()
	)

	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered_ratio(0.6)


func _add_to_recent(path: String) -> void:
	# Remove if already exists
	var idx := recent_models.find(path)
	if idx >= 0:
		recent_models.remove_at(idx)

	# Add to front
	recent_models.insert(0, path)

	# Trim to max
	while recent_models.size() > MAX_RECENT:
		recent_models.pop_back()


## Get the currently selected model path
func get_selected_path() -> String:
	var selected := model_list.get_selected_items()
	if selected.is_empty():
		return ""
	var metadata: Variant = model_list.get_item_metadata(selected[0])
	return str(metadata) if metadata else ""


## Externally select a model (for loading from saved data)
func select_model(path: String) -> void:
	for i in range(model_list.item_count):
		if model_list.get_item_metadata(i) == path:
			model_list.select(i)
			model_list.ensure_current_is_visible()
			path_label.text = path.get_file()
			return
