@tool
class_name NPCComposerDock
extends Control
## NPC Composer - Visual editor for creating NPCs with topic-based dialogue
## Allows editing NPCData resources and their associated knowledge profiles

const NPC_DATA_DIR := "res://data/npcs/"
const KNOWLEDGE_PROFILE_DIR := "res://data/npc_profiles/"

# UI References
var split_container: HSplitContainer
var left_panel: VBoxContainer
var center_panel: VBoxContainer
var right_panel: VBoxContainer

# Left panel - NPC browser
var npc_tree: Tree
var new_npc_button: Button
var delete_npc_button: Button

# Center panel - NPC configuration
var scroll_container: ScrollContainer
var properties_container: VBoxContainer
var npc_id_edit: LineEdit
var display_name_edit: LineEdit
var race_option: OptionButton
var archetype_option: OptionButton
var location_edit: LineEdit
var zone_id_edit: LineEdit
var faction_edit: LineEdit
var base_disposition_spin: SpinBox
var alignment_spin: SpinBox
var description_edit: TextEdit
var sprite_path_edit: LineEdit
var sprite_browse_button: Button
var sprite_h_frames_spin: SpinBox
var sprite_v_frames_spin: SpinBox
var dialogue_topics_list: ItemList
var add_topic_button: Button
var remove_topic_button: Button
var shop_type_option: OptionButton
var can_wander_check: CheckBox
var wander_radius_spin: SpinBox

# Knowledge profile section
var knowledge_panel: VBoxContainer
var knowledge_archetype_option: OptionButton
var personality_traits_edit: LineEdit
var knowledge_tags_edit: LineEdit
var speech_style_edit: LineEdit
var knowledge_disposition_spin: SpinBox

# Right panel - Preview
var sprite_preview: TextureRect
var preview_label: Label
var animation_timer: Timer
var current_frame: int = 0
var preview_texture: Texture2D

# Status
var status_label: Label

# State
var current_npc_path: String = ""
var current_npc_data: Resource  # NPCData
var unsaved_changes: bool = false


func _ready() -> void:
	_build_ui()
	_load_npc_list()


func _build_ui() -> void:
	# Main layout
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 4)
	add_child(main_vbox)

	# Toolbar
	var toolbar := _create_toolbar()
	main_vbox.add_child(toolbar)

	# Split container for three panels
	split_container = HSplitContainer.new()
	split_container.size_flags_vertical = SIZE_EXPAND_FILL
	main_vbox.add_child(split_container)

	# Left panel - NPC browser
	left_panel = _create_left_panel()
	split_container.add_child(left_panel)

	# Center panel - NPC properties
	center_panel = _create_center_panel()
	split_container.add_child(center_panel)

	# Right panel - Preview
	right_panel = _create_right_panel()
	split_container.add_child(right_panel)

	# Status bar
	status_label = Label.new()
	status_label.text = "Ready"
	main_vbox.add_child(status_label)

	# Set split ratios
	split_container.split_offset = 200


func _create_toolbar() -> HBoxContainer:
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "NPC Composer"
	title.add_theme_font_size_override("font_size", 18)
	toolbar.add_child(title)

	toolbar.add_child(_create_spacer())

	var save_button := Button.new()
	save_button.text = "Save"
	save_button.pressed.connect(_on_save_pressed)
	toolbar.add_child(save_button)

	var save_all_button := Button.new()
	save_all_button.text = "Save All"
	save_all_button.pressed.connect(_on_save_all_pressed)
	toolbar.add_child(save_all_button)

	var reload_button := Button.new()
	reload_button.text = "Reload"
	reload_button.pressed.connect(_on_reload_pressed)
	toolbar.add_child(reload_button)

	return toolbar


func _create_left_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 200
	panel.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "NPCs"
	header.add_theme_font_size_override("font_size", 14)
	panel.add_child(header)

	npc_tree = Tree.new()
	npc_tree.size_flags_vertical = SIZE_EXPAND_FILL
	npc_tree.item_selected.connect(_on_npc_selected)
	panel.add_child(npc_tree)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	panel.add_child(buttons)

	new_npc_button = Button.new()
	new_npc_button.text = "New"
	new_npc_button.size_flags_horizontal = SIZE_EXPAND_FILL
	new_npc_button.pressed.connect(_on_new_npc_pressed)
	buttons.add_child(new_npc_button)

	delete_npc_button = Button.new()
	delete_npc_button.text = "Delete"
	delete_npc_button.size_flags_horizontal = SIZE_EXPAND_FILL
	delete_npc_button.pressed.connect(_on_delete_npc_pressed)
	buttons.add_child(delete_npc_button)

	return panel


func _create_center_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	panel.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "NPC Properties"
	header.add_theme_font_size_override("font_size", 14)
	panel.add_child(header)

	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll_container)

	properties_container = VBoxContainer.new()
	properties_container.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(properties_container)

	# Basic Info Section
	properties_container.add_child(_create_section_header("Basic Info"))

	npc_id_edit = _add_line_edit_field(properties_container, "NPC ID:")
	display_name_edit = _add_line_edit_field(properties_container, "Display Name:")

	race_option = _add_option_field(properties_container, "Race:",
		["Human", "Dwarf", "Elf", "Goblin", "Orc"])

	archetype_option = _add_option_field(properties_container, "Archetype:",
		["quest_giver", "merchant", "guard", "civilian", "priest", "noble"])

	# Location Section
	properties_container.add_child(_create_section_header("Location"))
	location_edit = _add_line_edit_field(properties_container, "Location:")
	zone_id_edit = _add_line_edit_field(properties_container, "Zone ID:")
	faction_edit = _add_line_edit_field(properties_container, "Faction:")

	# Disposition Section
	properties_container.add_child(_create_section_header("Disposition"))
	base_disposition_spin = _add_spin_field(properties_container, "Base Disposition:", 0, 100, 50)
	alignment_spin = _add_spin_field(properties_container, "Alignment:", -100, 100, 0)

	# Description
	properties_container.add_child(_create_section_header("Description"))
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size.y = 60
	description_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	description_edit.placeholder_text = "NPC description..."
	properties_container.add_child(description_edit)

	# Sprite Section
	properties_container.add_child(_create_section_header("Sprite"))
	var sprite_row := HBoxContainer.new()
	properties_container.add_child(sprite_row)

	sprite_path_edit = LineEdit.new()
	sprite_path_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	sprite_path_edit.placeholder_text = "res://assets/sprites/..."
	sprite_path_edit.text_changed.connect(_on_sprite_path_changed)
	sprite_row.add_child(sprite_path_edit)

	sprite_browse_button = Button.new()
	sprite_browse_button.text = "..."
	sprite_browse_button.pressed.connect(_on_sprite_browse_pressed)
	sprite_row.add_child(sprite_browse_button)

	var frames_row := HBoxContainer.new()
	frames_row.add_theme_constant_override("separation", 8)
	properties_container.add_child(frames_row)
	var h_label := Label.new()
	h_label.text = "H:"
	h_label.custom_minimum_size.x = 20
	frames_row.add_child(h_label)
	sprite_h_frames_spin = SpinBox.new()
	sprite_h_frames_spin.min_value = 1
	sprite_h_frames_spin.max_value = 16
	sprite_h_frames_spin.value = 4
	sprite_h_frames_spin.custom_minimum_size.x = 60
	sprite_h_frames_spin.value_changed.connect(_on_sprite_frames_changed)
	frames_row.add_child(sprite_h_frames_spin)
	var v_label := Label.new()
	v_label.text = "V:"
	v_label.custom_minimum_size.x = 20
	frames_row.add_child(v_label)
	sprite_v_frames_spin = SpinBox.new()
	sprite_v_frames_spin.min_value = 1
	sprite_v_frames_spin.max_value = 16
	sprite_v_frames_spin.value = 1
	sprite_v_frames_spin.custom_minimum_size.x = 60
	sprite_v_frames_spin.value_changed.connect(_on_sprite_frames_changed)
	frames_row.add_child(sprite_v_frames_spin)

	# Dialogue Topics
	properties_container.add_child(_create_section_header("Dialogue Topics"))
	dialogue_topics_list = ItemList.new()
	dialogue_topics_list.custom_minimum_size.y = 80
	dialogue_topics_list.size_flags_horizontal = SIZE_EXPAND_FILL
	properties_container.add_child(dialogue_topics_list)

	var topic_buttons := HBoxContainer.new()
	properties_container.add_child(topic_buttons)
	add_topic_button = Button.new()
	add_topic_button.text = "Add Topic"
	add_topic_button.pressed.connect(_on_add_topic_pressed)
	topic_buttons.add_child(add_topic_button)
	remove_topic_button = Button.new()
	remove_topic_button.text = "Remove"
	remove_topic_button.pressed.connect(_on_remove_topic_pressed)
	topic_buttons.add_child(remove_topic_button)

	# Shop Type
	shop_type_option = _add_option_field(properties_container, "Shop Type:",
		["none", "general", "weapons", "armor", "alchemy", "magic", "curiosities"])

	# Wandering
	properties_container.add_child(_create_section_header("Behavior"))
	can_wander_check = CheckBox.new()
	can_wander_check.text = "Can Wander"
	properties_container.add_child(can_wander_check)
	wander_radius_spin = _add_spin_field(properties_container, "Wander Radius:", 0, 50, 5)

	# Knowledge Profile Section
	properties_container.add_child(_create_section_header("Knowledge Profile"))
	knowledge_panel = VBoxContainer.new()
	properties_container.add_child(knowledge_panel)

	knowledge_archetype_option = _add_option_field(knowledge_panel, "Archetype:",
		["Villager", "Farmer", "Guard", "Merchant", "Innkeeper", "Blacksmith",
		 "Scholar", "Priest", "Hunter", "Miner", "Noble", "Beggar", "Thief", "Bard"])

	personality_traits_edit = _add_line_edit_field(knowledge_panel, "Personality Traits:")
	personality_traits_edit.placeholder_text = "grumpy, friendly, nervous..."

	knowledge_tags_edit = _add_line_edit_field(knowledge_panel, "Knowledge Tags:")
	knowledge_tags_edit.placeholder_text = "local_area, trade, rumors..."

	speech_style_edit = _add_line_edit_field(knowledge_panel, "Speech Style:")
	speech_style_edit.placeholder_text = "casual, formal, uneducated..."

	knowledge_disposition_spin = _add_spin_field(knowledge_panel, "Base Disposition:", 0, 100, 50)

	return panel


func _create_right_panel() -> VBoxContainer:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = 180
	panel.add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Preview"
	header.add_theme_font_size_override("font_size", 14)
	panel.add_child(header)

	# Sprite preview with background
	var preview_bg := ColorRect.new()
	preview_bg.custom_minimum_size = Vector2(160, 200)
	preview_bg.color = Color(0.15, 0.15, 0.15)
	preview_bg.size_flags_horizontal = SIZE_SHRINK_CENTER
	panel.add_child(preview_bg)

	sprite_preview = TextureRect.new()
	sprite_preview.set_anchors_preset(PRESET_CENTER)
	sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_preview.custom_minimum_size = Vector2(128, 128)
	preview_bg.add_child(sprite_preview)

	preview_label = Label.new()
	preview_label.text = "No sprite loaded"
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(preview_label)

	# Animation timer
	animation_timer = Timer.new()
	animation_timer.wait_time = 0.2
	animation_timer.timeout.connect(_on_animation_tick)
	add_child(animation_timer)

	return panel


func _create_section_header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
	return label


func _add_line_edit_field(parent: Control, label_text: String) -> LineEdit:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)

	var edit := LineEdit.new()
	edit.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(edit)

	return edit


func _add_option_field(parent: Control, label_text: String, options: Array) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)

	var option := OptionButton.new()
	option.size_flags_horizontal = SIZE_EXPAND_FILL
	for opt in options:
		option.add_item(opt)
	row.add_child(option)

	return option


func _add_spin_field(parent: Control, label_text: String, min_val: float, max_val: float, default_val: float) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)

	var spin := SpinBox.new()
	spin.min_value = min_val
	spin.max_value = max_val
	spin.value = default_val
	spin.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(spin)

	return spin


func _create_spacer() -> Control:
	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	return spacer


# =============================================================================
# NPC LIST MANAGEMENT
# =============================================================================

func _load_npc_list() -> void:
	npc_tree.clear()
	var root: TreeItem = npc_tree.create_item()
	npc_tree.hide_root = true

	# Group NPCs by archetype
	var npcs_by_archetype: Dictionary = {}

	var dir := DirAccess.open(NPC_DATA_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while not file_name.is_empty():
			if file_name.ends_with(".tres"):
				var path: String = NPC_DATA_DIR + file_name
				var npc_data: Resource = load(path)
				if npc_data and npc_data.get("archetype"):
					var archetype: String = npc_data.get("archetype")
					if not npcs_by_archetype.has(archetype):
						npcs_by_archetype[archetype] = []
					npcs_by_archetype[archetype].append({
						"path": path,
						"name": npc_data.get("display_name") if npc_data.get("display_name") else file_name,
						"id": npc_data.get("npc_id")
					})
			file_name = dir.get_next()
		dir.list_dir_end()

	# Create tree structure
	for archetype: String in npcs_by_archetype:
		var arch_item: TreeItem = npc_tree.create_item(root)
		arch_item.set_text(0, archetype.capitalize())
		arch_item.set_selectable(0, false)

		for npc_info: Dictionary in npcs_by_archetype[archetype]:
			var npc_item: TreeItem = npc_tree.create_item(arch_item)
			npc_item.set_text(0, npc_info["name"])
			npc_item.set_metadata(0, npc_info["path"])

	_set_status("Loaded %d NPCs" % _count_npcs(npcs_by_archetype))


func _count_npcs(grouped: Dictionary) -> int:
	var count: int = 0
	for arr in grouped.values():
		count += arr.size()
	return count


# =============================================================================
# NPC SELECTION AND EDITING
# =============================================================================

func _on_npc_selected() -> void:
	var selected: TreeItem = npc_tree.get_selected()
	if not selected:
		return

	var path: Variant = selected.get_metadata(0)
	if path == null or not path is String:
		return

	_load_npc(path)


func _load_npc(path: String) -> void:
	var npc_data: Resource = load(path)
	if not npc_data:
		_set_status("Failed to load NPC: " + path)
		return

	current_npc_path = path
	current_npc_data = npc_data

	# Populate fields
	npc_id_edit.text = npc_data.get("npc_id") if npc_data.get("npc_id") else ""
	display_name_edit.text = npc_data.get("display_name") if npc_data.get("display_name") else ""

	var race: String = npc_data.get("race") if npc_data.get("race") else "Human"
	_select_option_by_text(race_option, race)

	var archetype: String = npc_data.get("archetype") if npc_data.get("archetype") else "civilian"
	_select_option_by_text(archetype_option, archetype)

	location_edit.text = npc_data.get("location") if npc_data.get("location") else ""
	zone_id_edit.text = npc_data.get("zone_id") if npc_data.get("zone_id") else ""
	faction_edit.text = npc_data.get("faction_id") if npc_data.get("faction_id") else ""

	base_disposition_spin.value = npc_data.get("base_disposition") if npc_data.get("base_disposition") else 50
	alignment_spin.value = npc_data.get("alignment") if npc_data.get("alignment") else 0

	description_edit.text = npc_data.get("description") if npc_data.get("description") else ""

	sprite_path_edit.text = npc_data.get("sprite_path") if npc_data.get("sprite_path") else ""
	sprite_h_frames_spin.value = npc_data.get("sprite_h_frames") if npc_data.get("sprite_h_frames") else 4
	sprite_v_frames_spin.value = npc_data.get("sprite_v_frames") if npc_data.get("sprite_v_frames") else 1

	# Dialogue topics
	dialogue_topics_list.clear()
	var topics: Array = npc_data.get("dialogue_topics") if npc_data.get("dialogue_topics") else []
	for topic: String in topics:
		dialogue_topics_list.add_item(topic)

	var shop_type: String = npc_data.get("shop_type") if npc_data.get("shop_type") else "none"
	_select_option_by_text(shop_type_option, shop_type)

	can_wander_check.button_pressed = npc_data.get("can_wander") if npc_data.get("can_wander") != null else true
	wander_radius_spin.value = npc_data.get("wander_radius") if npc_data.get("wander_radius") else 5.0

	# Load knowledge profile if exists
	var knowledge_path: String = npc_data.get("knowledge_profile_path") if npc_data.get("knowledge_profile_path") else ""
	if not knowledge_path.is_empty() and ResourceLoader.exists(knowledge_path):
		var profile: Resource = load(knowledge_path)
		if profile:
			_load_knowledge_profile(profile)
	else:
		_clear_knowledge_profile()

	# Update sprite preview
	_update_sprite_preview()

	unsaved_changes = false
	_set_status("Loaded: " + display_name_edit.text)


func _load_knowledge_profile(profile: Resource) -> void:
	var archetype_val: int = profile.get("archetype") if profile.get("archetype") != null else 0
	knowledge_archetype_option.select(archetype_val)

	var traits: Array = profile.get("personality_traits") if profile.get("personality_traits") else []
	personality_traits_edit.text = ", ".join(traits)

	var tags: Array = profile.get("knowledge_tags") if profile.get("knowledge_tags") else []
	knowledge_tags_edit.text = ", ".join(tags)

	speech_style_edit.text = profile.get("speech_style") if profile.get("speech_style") else "casual"
	knowledge_disposition_spin.value = profile.get("base_disposition") if profile.get("base_disposition") else 50


func _clear_knowledge_profile() -> void:
	knowledge_archetype_option.select(0)
	personality_traits_edit.text = ""
	knowledge_tags_edit.text = ""
	speech_style_edit.text = "casual"
	knowledge_disposition_spin.value = 50


func _select_option_by_text(option: OptionButton, text: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i).to_lower() == text.to_lower():
			option.select(i)
			return
	option.select(0)


# =============================================================================
# SPRITE PREVIEW
# =============================================================================

func _update_sprite_preview() -> void:
	var path: String = sprite_path_edit.text
	if path.is_empty() or not ResourceLoader.exists(path):
		sprite_preview.texture = null
		preview_label.text = "No sprite loaded"
		animation_timer.stop()
		return

	preview_texture = load(path)
	if not preview_texture:
		sprite_preview.texture = null
		preview_label.text = "Failed to load"
		animation_timer.stop()
		return

	# Create atlas texture for current frame
	_show_sprite_frame(0)
	animation_timer.start()

	var h_frames: int = int(sprite_h_frames_spin.value)
	var v_frames: int = int(sprite_v_frames_spin.value)
	preview_label.text = "%dx%d frames" % [h_frames, v_frames]


func _show_sprite_frame(frame: int) -> void:
	if not preview_texture:
		return

	var h_frames: int = int(sprite_h_frames_spin.value)
	var v_frames: int = int(sprite_v_frames_spin.value)
	var total_frames: int = h_frames * v_frames

	frame = frame % total_frames

	var frame_width: float = preview_texture.get_width() / float(h_frames)
	var frame_height: float = preview_texture.get_height() / float(v_frames)

	var frame_x: int = frame % h_frames
	var frame_y: int = frame / h_frames

	var atlas := AtlasTexture.new()
	atlas.atlas = preview_texture
	atlas.region = Rect2(frame_x * frame_width, frame_y * frame_height, frame_width, frame_height)

	sprite_preview.texture = atlas
	current_frame = frame


func _on_animation_tick() -> void:
	_show_sprite_frame(current_frame + 1)


func _on_sprite_path_changed(_text: String) -> void:
	_update_sprite_preview()


func _on_sprite_frames_changed(_value: float) -> void:
	_update_sprite_preview()


func _on_sprite_browse_pressed() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.png ; PNG Images"])
	dialog.file_selected.connect(_on_sprite_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))


func _on_sprite_file_selected(path: String) -> void:
	sprite_path_edit.text = path
	_update_sprite_preview()


# =============================================================================
# TOPIC MANAGEMENT
# =============================================================================

func _on_add_topic_pressed() -> void:
	var topics: Array[String] = ["local_news", "rumors", "personal", "directions", "trade", "weather", "quests"]
	# Show popup menu with available topics
	var popup := PopupMenu.new()
	for topic: String in topics:
		popup.add_item(topic)
	popup.id_pressed.connect(func(id: int) -> void:
		dialogue_topics_list.add_item(topics[id])
		popup.queue_free()
	)
	add_child(popup)
	popup.popup(Rect2i(get_global_mouse_position(), Vector2i(150, 200)))


func _on_remove_topic_pressed() -> void:
	var selected: PackedInt32Array = dialogue_topics_list.get_selected_items()
	for i in range(selected.size() - 1, -1, -1):
		dialogue_topics_list.remove_item(selected[i])


# =============================================================================
# SAVING AND LOADING
# =============================================================================

func _on_save_pressed() -> void:
	if current_npc_path.is_empty() or not current_npc_data:
		_set_status("No NPC loaded to save")
		return

	_save_current_npc()
	_set_status("Saved: " + display_name_edit.text)


func _save_current_npc() -> void:
	if not current_npc_data:
		return

	# Update NPCData properties
	current_npc_data.set("npc_id", npc_id_edit.text)
	current_npc_data.set("display_name", display_name_edit.text)
	current_npc_data.set("race", race_option.get_item_text(race_option.selected))
	current_npc_data.set("archetype", archetype_option.get_item_text(archetype_option.selected))
	current_npc_data.set("location", location_edit.text)
	current_npc_data.set("zone_id", zone_id_edit.text)
	current_npc_data.set("faction_id", faction_edit.text)
	current_npc_data.set("base_disposition", int(base_disposition_spin.value))
	current_npc_data.set("alignment", int(alignment_spin.value))
	current_npc_data.set("description", description_edit.text)
	current_npc_data.set("sprite_path", sprite_path_edit.text)
	current_npc_data.set("sprite_h_frames", int(sprite_h_frames_spin.value))
	current_npc_data.set("sprite_v_frames", int(sprite_v_frames_spin.value))

	# Dialogue topics
	var topics: Array[String] = []
	for i in range(dialogue_topics_list.item_count):
		topics.append(dialogue_topics_list.get_item_text(i))
	current_npc_data.set("dialogue_topics", topics)

	current_npc_data.set("shop_type", shop_type_option.get_item_text(shop_type_option.selected))
	current_npc_data.set("can_wander", can_wander_check.button_pressed)
	current_npc_data.set("wander_radius", wander_radius_spin.value)

	# Save the resource
	var err: Error = ResourceSaver.save(current_npc_data, current_npc_path)
	if err != OK:
		_set_status("Failed to save: " + error_string(err))
		return

	unsaved_changes = false


func _on_save_all_pressed() -> void:
	_on_save_pressed()
	_set_status("All changes saved")


func _on_reload_pressed() -> void:
	_load_npc_list()
	if not current_npc_path.is_empty():
		_load_npc(current_npc_path)


func _on_new_npc_pressed() -> void:
	# Create a new NPCData resource
	var npc_script: Script = load("res://scripts/data/npc_data.gd")
	if not npc_script:
		_set_status("Failed to load NPCData script")
		return

	var new_npc: Resource = npc_script.new()
	var new_id: String = "new_npc_%d" % Time.get_unix_time_from_system()
	new_npc.set("npc_id", new_id)
	new_npc.set("display_name", "New NPC")
	new_npc.set("archetype", "civilian")

	var path: String = NPC_DATA_DIR + new_id + ".tres"
	var err: Error = ResourceSaver.save(new_npc, path)
	if err != OK:
		_set_status("Failed to create NPC: " + error_string(err))
		return

	_load_npc_list()
	_load_npc(path)
	_set_status("Created new NPC")


func _on_delete_npc_pressed() -> void:
	if current_npc_path.is_empty():
		return

	# Delete the file
	var dir := DirAccess.open(NPC_DATA_DIR)
	if dir:
		var file_name: String = current_npc_path.get_file()
		dir.remove(file_name)
		_set_status("Deleted: " + file_name)
		current_npc_path = ""
		current_npc_data = null
		_load_npc_list()


func _set_status(msg: String) -> void:
	if status_label:
		status_label.text = msg
