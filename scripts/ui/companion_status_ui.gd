## companion_status_ui.gd - UI element showing companion health and status
## Displays portrait, name, health bar, and current state (following, waiting, knocked out)
## Supports up to 2 companions displayed vertically
class_name CompanionStatusUI
extends Control

## Visual constants
const PORTRAIT_SIZE := Vector2(48, 48)
const HEALTH_BAR_HEIGHT := 12
const SLOT_HEIGHT := 70
const SLOT_WIDTH := 180
const SLOT_SPACING := 8

## Status text colors
const COL_FOLLOWING := Color(0.5, 0.9, 0.5, 1.0)  # Green
const COL_WAITING := Color(0.9, 0.9, 0.5, 1.0)    # Yellow
const COL_ATTACKING := Color(0.9, 0.5, 0.5, 1.0)  # Red
const COL_DEFENDING := Color(0.5, 0.7, 0.9, 1.0)  # Blue
const COL_KNOCKED_OUT := Color(0.5, 0.3, 0.3, 0.8) # Dark red

## Damage flash duration
const DAMAGE_FLASH_DURATION := 0.25

## Companion slot data structure
class CompanionSlot:
	var container: PanelContainer
	var portrait: TextureRect
	var name_label: Label
	var health_bar: ProgressBar
	var status_label: Label
	var companion_id: String = ""
	var companion_node: Node = null
	var damage_flash_timer: float = 0.0
	var is_knocked_out: bool = false

## Active companion slots (max 2)
var companion_slots: Array[CompanionSlot] = []

## Cached reference to CompanionManager
var _companion_manager: Node = null


func _ready() -> void:
	name = "CompanionStatusUI"

	# Create slot containers
	_create_slots()

	# Connect to CompanionManager signals
	_connect_companion_manager()

	# Initially hidden (no companions)
	visible = false


func _process(delta: float) -> void:
	# Update damage flash timers
	for slot in companion_slots:
		if slot.damage_flash_timer > 0:
			slot.damage_flash_timer -= delta
			if slot.damage_flash_timer <= 0:
				_reset_slot_flash(slot)

	# Update companion health/status
	_update_companion_displays()


func _create_slots() -> void:
	# Create vertical container for slots
	var vbox := VBoxContainer.new()
	vbox.name = "SlotsContainer"
	vbox.add_theme_constant_override("separation", SLOT_SPACING)
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	add_child(vbox)

	# Create 2 companion slots
	for i in range(2):
		var slot := _create_companion_slot(i)
		companion_slots.append(slot)
		vbox.add_child(slot.container)
		slot.container.visible = false  # Hidden until companion assigned


func _create_companion_slot(index: int) -> CompanionSlot:
	var slot := CompanionSlot.new()

	# Main container panel
	slot.container = PanelContainer.new()
	slot.container.name = "CompanionSlot_%d" % index
	slot.container.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)

	# Dark semi-transparent background
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.06, 0.04, 0.85)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.4, 0.35, 0.25, 0.8)  # Bronze border
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	slot.container.add_theme_stylebox_override("panel", bg_style)

	# Inner margin container
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	slot.container.add_child(margin)

	# Horizontal layout (portrait on left, info on right)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	# Portrait container with border
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = PORTRAIT_SIZE
	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = Color(0.15, 0.12, 0.1, 1.0)
	portrait_style.border_width_left = 1
	portrait_style.border_width_right = 1
	portrait_style.border_width_top = 1
	portrait_style.border_width_bottom = 1
	portrait_style.border_color = Color(0.3, 0.25, 0.2, 1.0)
	portrait_panel.add_theme_stylebox_override("panel", portrait_style)
	hbox.add_child(portrait_panel)

	# Portrait texture
	slot.portrait = TextureRect.new()
	slot.portrait.name = "Portrait"
	slot.portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	slot.portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.portrait.custom_minimum_size = PORTRAIT_SIZE - Vector2(4, 4)
	portrait_panel.add_child(slot.portrait)

	# Info container (name, health bar, status)
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# Companion name
	slot.name_label = Label.new()
	slot.name_label.name = "NameLabel"
	slot.name_label.text = "Companion"
	slot.name_label.add_theme_font_size_override("font_size", 11)
	slot.name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.8))
	info_vbox.add_child(slot.name_label)

	# Health bar
	slot.health_bar = ProgressBar.new()
	slot.health_bar.name = "HealthBar"
	slot.health_bar.max_value = 100
	slot.health_bar.value = 100
	slot.health_bar.show_percentage = false
	slot.health_bar.custom_minimum_size = Vector2(0, HEALTH_BAR_HEIGHT)

	# Health bar styling
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.1, 0.1, 0.8)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	slot.health_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.7, 0.3, 0.9)  # Green
	bar_fill.corner_radius_top_left = 2
	bar_fill.corner_radius_top_right = 2
	bar_fill.corner_radius_bottom_left = 2
	bar_fill.corner_radius_bottom_right = 2
	slot.health_bar.add_theme_stylebox_override("fill", bar_fill)

	info_vbox.add_child(slot.health_bar)

	# Status label
	slot.status_label = Label.new()
	slot.status_label.name = "StatusLabel"
	slot.status_label.text = "Following"
	slot.status_label.add_theme_font_size_override("font_size", 9)
	slot.status_label.add_theme_color_override("font_color", COL_FOLLOWING)
	info_vbox.add_child(slot.status_label)

	return slot


func _connect_companion_manager() -> void:
	# Get CompanionManager autoload
	_companion_manager = get_node_or_null("/root/CompanionManager")
	if not _companion_manager:
		return

	# Connect signals (using actual signal names from CompanionManager)
	if _companion_manager.has_signal("companion_joined"):
		if not _companion_manager.companion_joined.is_connected(_on_companion_added):
			_companion_manager.companion_joined.connect(_on_companion_added)

	if _companion_manager.has_signal("companion_left"):
		if not _companion_manager.companion_left.is_connected(_on_companion_removed):
			_companion_manager.companion_left.connect(_on_companion_removed)

	if _companion_manager.has_signal("companion_damaged"):
		if not _companion_manager.companion_damaged.is_connected(_on_companion_damaged):
			_companion_manager.companion_damaged.connect(_on_companion_damaged)

	if _companion_manager.has_signal("companion_knocked_out"):
		if not _companion_manager.companion_knocked_out.is_connected(_on_companion_downed):
			_companion_manager.companion_knocked_out.connect(_on_companion_downed)

	if _companion_manager.has_signal("companion_revived"):
		if not _companion_manager.companion_revived.is_connected(_on_companion_revived):
			_companion_manager.companion_revived.connect(_on_companion_revived)

	if _companion_manager.has_signal("all_companions_commanded"):
		if not _companion_manager.all_companions_commanded.is_connected(_on_all_commanded):
			_companion_manager.all_companions_commanded.connect(_on_all_commanded)


## Called when a companion joins the party (companion_joined signal)
func _on_companion_added(companion_id: String, companion: CompanionNPC) -> void:
	# Find an empty slot
	for slot in companion_slots:
		if slot.companion_id.is_empty():
			_assign_companion_to_slot(slot, companion_id, companion)
			_update_visibility()
			return

	push_warning("[CompanionStatusUI] No empty slots for companion: %s" % companion_id)


## Called when a companion leaves the party (companion_left signal)
func _on_companion_removed(companion_id: String) -> void:
	for slot in companion_slots:
		if slot.companion_id == companion_id:
			_clear_slot(slot)
			_update_visibility()
			return


## Called when a companion takes damage
func _on_companion_damaged(companion_id: String, _amount: int) -> void:
	for slot in companion_slots:
		if slot.companion_id == companion_id:
			_flash_slot_damage(slot)
			return


## Called when a companion is knocked out
func _on_companion_downed(companion_id: String) -> void:
	for slot in companion_slots:
		if slot.companion_id == companion_id:
			slot.is_knocked_out = true
			_update_slot_status(slot, "Knocked Out", COL_KNOCKED_OUT)
			# Darken the portrait
			if slot.portrait:
				slot.portrait.modulate = Color(0.4, 0.4, 0.4, 0.8)
			return


## Called when a companion recovers from knockout (companion_revived signal)
func _on_companion_revived(companion_id: String) -> void:
	for slot in companion_slots:
		if slot.companion_id == companion_id:
			slot.is_knocked_out = false
			_update_slot_status(slot, "Following", COL_FOLLOWING)
			# Restore portrait brightness
			if slot.portrait:
				slot.portrait.modulate = Color.WHITE
			return


## Called when all companions receive a command (all_companions_commanded signal)
func _on_all_commanded(command: CompanionNPC.CompanionCommand) -> void:
	var status_text: String = "Following"
	var status_color: Color = COL_FOLLOWING

	match command:
		CompanionNPC.CompanionCommand.FOLLOW:
			status_text = "Following"
			status_color = COL_FOLLOWING
		CompanionNPC.CompanionCommand.WAIT:
			status_text = "Waiting"
			status_color = COL_WAITING
		CompanionNPC.CompanionCommand.ATTACK_TARGET:
			status_text = "Attacking"
			status_color = COL_ATTACKING
		CompanionNPC.CompanionCommand.DEFEND_POSITION:
			status_text = "Defending"
			status_color = COL_DEFENDING

	# Update all non-knocked-out companions
	for slot in companion_slots:
		if not slot.companion_id.is_empty() and not slot.is_knocked_out:
			_update_slot_status(slot, status_text, status_color)


## Assign a companion to a slot
func _assign_companion_to_slot(slot: CompanionSlot, companion_id: String, companion: CompanionNPC) -> void:
	slot.companion_id = companion_id
	slot.companion_node = companion
	slot.is_knocked_out = false
	slot.container.visible = true

	# Get companion name - CompanionNPC has follower_name from FollowerNPC parent
	var comp_name: String = companion.follower_name if not companion.follower_name.is_empty() else companion_id
	slot.name_label.text = comp_name

	# Try to get portrait texture from companion data
	_load_companion_portrait(slot, companion)

	# Get initial health
	slot.health_bar.max_value = companion.max_health
	slot.health_bar.value = companion.current_health

	# Initial status based on current command
	var status_text: String = "Following"
	var status_color: Color = COL_FOLLOWING
	match companion.current_command:
		CompanionNPC.CompanionCommand.WAIT:
			status_text = "Waiting"
			status_color = COL_WAITING
		CompanionNPC.CompanionCommand.ATTACK_TARGET:
			status_text = "Attacking"
			status_color = COL_ATTACKING
		CompanionNPC.CompanionCommand.DEFEND_POSITION:
			status_text = "Defending"
			status_color = COL_DEFENDING

	_update_slot_status(slot, status_text, status_color)

	# Connect to companion-specific signals if available
	_connect_companion_signals(slot, companion)


## Load portrait texture for companion
func _load_companion_portrait(slot: CompanionSlot, companion: CompanionNPC) -> void:
	# Try to get sprite texture from companion
	var texture: Texture2D = null

	# Check companion_data first
	if companion.companion_data:
		var data: CompanionData = companion.companion_data
		if not data.sprite_path.is_empty() and ResourceLoader.exists(data.sprite_path):
			texture = load(data.sprite_path)

	# Fall back to sprite_texture property (from FollowerNPC)
	if not texture and companion.sprite_texture:
		texture = companion.sprite_texture

	# Fall back to billboard sprite
	if not texture and companion.billboard:
		if companion.billboard.sprite_sheet:
			texture = companion.billboard.sprite_sheet

	if texture:
		# For sprite sheets, we use AtlasTexture to show just the first frame
		var atlas := AtlasTexture.new()
		atlas.atlas = texture

		# Calculate frame region (first frame)
		var h_frames: int = companion.sprite_h_frames if companion.sprite_h_frames > 0 else 5
		var v_frames: int = companion.sprite_v_frames if companion.sprite_v_frames > 0 else 1

		var frame_width: float = texture.get_width() / float(h_frames)
		var frame_height: float = texture.get_height() / float(v_frames)
		atlas.region = Rect2(0, 0, frame_width, frame_height)

		slot.portrait.texture = atlas
	else:
		# Default placeholder
		slot.portrait.texture = null


## Connect to individual companion signals
func _connect_companion_signals(slot: CompanionSlot, companion: CompanionNPC) -> void:
	# Connect to command_received if available
	if companion.has_signal("companion_command_received"):
		if not companion.companion_command_received.is_connected(_on_single_companion_command.bind(slot)):
			companion.companion_command_received.connect(_on_single_companion_command.bind(slot))


## Handle individual companion command
func _on_single_companion_command(command: String, slot: CompanionSlot) -> void:
	if slot.is_knocked_out:
		return

	var status_text: String = "Following"
	var status_color: Color = COL_FOLLOWING

	match command:
		"follow":
			status_text = "Following"
			status_color = COL_FOLLOWING
		"hold", "wait":
			status_text = "Waiting"
			status_color = COL_WAITING
		"attack":
			status_text = "Attacking"
			status_color = COL_ATTACKING
		"defend":
			status_text = "Defending"
			status_color = COL_DEFENDING

	_update_slot_status(slot, status_text, status_color)


## Clear a companion slot
func _clear_slot(slot: CompanionSlot) -> void:
	# Disconnect signals
	if slot.companion_node and is_instance_valid(slot.companion_node):
		if slot.companion_node.has_signal("companion_command_received"):
			if slot.companion_node.companion_command_received.is_connected(_on_single_companion_command):
				slot.companion_node.companion_command_received.disconnect(_on_single_companion_command)

	slot.companion_id = ""
	slot.companion_node = null
	slot.is_knocked_out = false
	slot.container.visible = false
	slot.portrait.texture = null
	slot.name_label.text = "Companion"
	slot.health_bar.value = 100
	slot.status_label.text = "Following"


## Update slot status text and color
func _update_slot_status(slot: CompanionSlot, text: String, color: Color) -> void:
	slot.status_label.text = text
	slot.status_label.add_theme_color_override("font_color", color)


## Flash slot border on damage
func _flash_slot_damage(slot: CompanionSlot) -> void:
	slot.damage_flash_timer = DAMAGE_FLASH_DURATION

	# Change border to red
	var style := slot.container.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(1.0, 0.3, 0.3, 1.0)


## Reset slot flash to normal
func _reset_slot_flash(slot: CompanionSlot) -> void:
	var style := slot.container.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.border_color = Color(0.4, 0.35, 0.25, 0.8)  # Bronze


## Update health bars from companion nodes
func _update_companion_displays() -> void:
	for slot in companion_slots:
		if slot.companion_id.is_empty():
			continue

		if not slot.companion_node or not is_instance_valid(slot.companion_node):
			# Companion node was freed - clear slot
			_clear_slot(slot)
			continue

		# Cast to CompanionNPC for type-safe access
		if not slot.companion_node is CompanionNPC:
			continue
		var companion: CompanionNPC = slot.companion_node as CompanionNPC

		# Update health bar
		slot.health_bar.max_value = companion.max_health
		slot.health_bar.value = companion.current_health

		# Update health bar color based on percentage
		var health_pct: float = float(companion.current_health) / float(companion.max_health) if companion.max_health > 0 else 0.0
		var bar_fill := slot.health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if bar_fill:
			if slot.is_knocked_out:
				bar_fill.bg_color = Color(0.3, 0.2, 0.2, 0.6)  # Dark gray
			elif health_pct > 0.5:
				bar_fill.bg_color = Color(0.3, 0.7, 0.3, 0.9)  # Green
			elif health_pct > 0.25:
				bar_fill.bg_color = Color(0.8, 0.6, 0.2, 0.9)  # Yellow/orange
			else:
				bar_fill.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # Red

		# Check knocked out state
		var is_ko: bool = companion.is_knocked_out()
		if is_ko and not slot.is_knocked_out:
			slot.is_knocked_out = true
			_update_slot_status(slot, "Knocked Out", COL_KNOCKED_OUT)
			if slot.portrait:
				slot.portrait.modulate = Color(0.4, 0.4, 0.4, 0.8)
		elif not is_ko and slot.is_knocked_out:
			slot.is_knocked_out = false
			_update_slot_status(slot, "Following", COL_FOLLOWING)
			if slot.portrait:
				slot.portrait.modulate = Color.WHITE


## Update visibility based on active companions
func _update_visibility() -> void:
	var has_companions: bool = false
	for slot in companion_slots:
		if not slot.companion_id.is_empty():
			has_companions = true
			break

	visible = has_companions


## Manually refresh companion list (e.g., after scene load)
func refresh_companions() -> void:
	# Clear all slots first
	for slot in companion_slots:
		_clear_slot(slot)

	# Re-populate from CompanionManager
	if _companion_manager and _companion_manager.has_method("get_active_companions"):
		var companions: Array = _companion_manager.get_active_companions()
		for companion in companions:
			if is_instance_valid(companion) and companion is CompanionNPC:
				var comp: CompanionNPC = companion as CompanionNPC
				var comp_id: String = comp.companion_id if not comp.companion_id.is_empty() else comp.name
				_on_companion_added(comp_id, comp)

	_update_visibility()
