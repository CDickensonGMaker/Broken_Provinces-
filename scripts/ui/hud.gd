## hud.gd - Main game HUD
class_name GameHUD
extends CanvasLayer

## Node references
@export var health_bar: ProgressBar
@export var health_label: Label
@export var stamina_bar: ProgressBar
@export var mana_bar: ProgressBar
@export var spell_slots_container: HBoxContainer
@export var quick_slots_container: HBoxContainer
@export var enemy_health_container: Control
@export var enemy_health_bar: ProgressBar
@export var enemy_name_label: Label
@export var damage_numbers_container: Control
@export var notification_label: Label
## Minimap moved to code-generated var below
@export var crosshair: Control
@export var condition_icons_container: HBoxContainer
@export var gold_label: Label
@export var time_label: Label
@export var ammo_container: Control
@export var ammo_label: Label
@export var equipped_label: Label

## Menu references
@onready var game_menu: GameMenu = $GameMenu
var pause_menu: PauseMenu

## Spell slot icons (generated)
var spell_slot_icons: Array[TextureRect] = []

## Quick slot icons
var quick_slot_icons: Array[Control] = []

## Target tracking
var current_target: Node = null
var target_health_visible: bool = false

## Notification queue
var notification_queue: Array[String] = []
var notification_timer: float = 0.0
const NOTIFICATION_DURATION := 3.0

## Damage number scene
var damage_number_scene: PackedScene

## Interaction prompt
var interaction_prompt_label: Label

## Death screen
var death_screen: ColorRect
var death_load_autosave_button: Button
var death_load_save_button: Button
var death_restart_button: Button
var death_main_menu_button: Button
var death_save_select_panel: Control
var death_load_failure_count: int = 0  # Track consecutive load failures

## Durability warning
var durability_warning_label: Label
var durability_check_timer: float = 0.0
const DURABILITY_CHECK_INTERVAL := 1.0
const LOW_DURABILITY_THRESHOLD := 0.25

## Game log (side panel for events)
var game_log_container: VBoxContainer
var game_log_entries: Array[Control] = []
const MAX_LOG_ENTRIES := 8
const LOG_FADE_DURATION := 4.0
const LOG_FADE_START := 3.0  # Start fading after this many seconds

## Compass, minimap and bounty indicator
var navigation: HUDNavigation = null

## PERFORMANCE: Cached enemies array - refreshed once per frame instead of multiple get_nodes_in_group() calls
var _cached_enemies: Array = []

## Quest tracker (shows tracked quest at top of screen)
var quest_tracker_container: Control
var quest_tracker_title: Label
var quest_tracker_progress: Label


## Conditions display (below mana bar)
var conditions_container: HBoxContainer = null
var condition_labels: Dictionary = {}  # Condition enum -> PanelContainer

## Stealth indicator (HIDDEN text when player is hidden)
var stealth_indicator: Label = null

## Escort health UI (shows escorted NPC health during escort quests)
var escort_health_container: Control = null
var escort_health_bar: ProgressBar = null
var escort_name_label: Label = null
var escort_damage_flash_timer: float = 0.0
const ESCORT_DAMAGE_FLASH_DURATION: float = 0.3



## Track connected player_data to properly disconnect signals when it changes
var _connected_player_data: CharacterData = null

## Cached player reference for safety checks
var _cached_player: Node3D = null

## Debug overlay (F3 to toggle)
var debug_overlay_visible: bool = false
var debug_overlay_container: PanelContainer
var debug_cell_label: Label
var debug_world_pos_label: Label
var debug_active_cells_label: Label
var debug_world_offset_label: Label
var debug_fps_label: Label

## Decorative border frame overlay
var border_frame: GameBorderFrame = null

## Wave defense counter UI
var wave_counter_ui: WaveCounterUI = null

## Timed objective UI (countdown timer for timed objectives)
var timed_objective_ui: TimedObjectiveUI = null

## Companion HUD elements
var companion_status_ui: CompanionStatusUI = null
var companion_command_ui: CompanionCommandUI = null
var _companion_command_mode_active: bool = false

func _ready() -> void:
	# Add to hud group so other scripts can find us
	add_to_group("hud")

	# Fallback: get nodes by path if exports weren't resolved
	if not health_bar:
		health_bar = get_node_or_null("TopLeft/HealthBar") as ProgressBar
	if not health_label:
		health_label = get_node_or_null("TopLeft/HealthLabel") as Label
	if not stamina_bar:
		stamina_bar = get_node_or_null("TopLeft/StaminaBar") as ProgressBar
	if not mana_bar:
		mana_bar = get_node_or_null("TopLeft/ManaBar") as ProgressBar
	if not ammo_container:
		ammo_container = get_node_or_null("BottomRight/AmmoContainer") as Control
	if not ammo_label:
		ammo_label = get_node_or_null("BottomRight/AmmoContainer/AmmoLabel") as Label
	if not quick_slots_container:
		quick_slots_container = get_node_or_null("BottomCenter/QuickSlots") as HBoxContainer
	if not enemy_health_container:
		enemy_health_container = get_node_or_null("EnemyHealthContainer") as Control
	if not enemy_health_bar:
		enemy_health_bar = get_node_or_null("EnemyHealthContainer/EnemyHealthBar") as ProgressBar
	if not enemy_name_label:
		enemy_name_label = get_node_or_null("EnemyHealthContainer/EnemyNameLabel") as Label
	if not notification_label:
		notification_label = get_node_or_null("BottomCenter/NotificationLabel") as Label
	if not gold_label:
		gold_label = get_node_or_null("TopRight/GoldLabel") as Label
	if not equipped_label:
		equipped_label = get_node_or_null("BottomLeft/EquippedLabel") as Label

	_setup_health_frame()
	_setup_spell_slots()
	_setup_quick_slots()
	_setup_interaction_prompt()
	_setup_death_screen()
	_setup_durability_warning()
	_setup_game_log()
	_setup_navigation()
	_setup_quest_tracker()
	_setup_conditions_display()
	_setup_stealth_indicator()
	_setup_escort_health()
	_setup_wave_counter()
	_setup_timed_objective_ui()
	_setup_companion_hud()
	_connect_signals()
	_setup_menus()
	_connect_scene_signals()
	_setup_debug_overlay()
	_setup_border_frame()

	# Try to load damage number scene
	if ResourceLoader.exists("res://scenes/ui/damage_number.tscn"):
		damage_number_scene = load("res://scenes/ui/damage_number.tscn")

	# Hide enemy health by default
	if enemy_health_container:
		enemy_health_container.visible = false

func _input(event: InputEvent) -> void:
	# Don't process if already in a menu
	if _is_menu_open():
		return

	# Escape opens the pause menu
	if event.is_action_pressed("pause"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return

	# Tab opens the game menu (inventory, spells, etc.)
	if event.is_action_pressed("menu"):
		_open_game_menu()
		get_viewport().set_input_as_handled()
		return

	# M key opens the world map directly
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_M and key_event.pressed and not key_event.echo:
			_open_map()
			get_viewport().set_input_as_handled()
			return
		# F3 toggles debug overlay
		if key_event.keycode == KEY_F3 and key_event.pressed and not key_event.echo:
			_toggle_debug_overlay()
			get_viewport().set_input_as_handled()
			return
		# C key toggles companion command mode (only when companions active)
		if key_event.keycode == KEY_C and key_event.pressed and not key_event.echo:
			if _has_active_companions():
				_toggle_companion_command_mode()
				get_viewport().set_input_as_handled()
				return

func _setup_menus() -> void:
	# Setup game menu (loaded via @onready)
	if game_menu:
		game_menu.visible = false
		if game_menu.has_signal("menu_closed"):
			game_menu.menu_closed.connect(_on_menu_closed)
	else:
		push_error("[HUD] GameMenu not found!")

	# Load and setup pause menu
	var pause_menu_scene := load("res://scenes/ui/pause_menu.tscn")
	if pause_menu_scene:
		pause_menu = pause_menu_scene.instantiate() as PauseMenu
		pause_menu.visible = false
		add_child(pause_menu)
		if pause_menu.has_signal("menu_closed"):
			pause_menu.menu_closed.connect(_on_menu_closed)
	else:
		push_error("[HUD] Failed to load PauseMenu!")

func _is_menu_open() -> bool:
	if game_menu and game_menu.visible:
		return true
	if pause_menu and pause_menu.visible:
		return true
	# Check if dialogue or conversation is active
	if DialogueManager.is_dialogue_active:
		return true
	if ConversationSystem.is_active:
		return true
	return false

func _open_game_menu() -> void:
	if game_menu:
		game_menu.open()
		# Hide minimap and quest tracker when game menu opens (Tab menu)
		navigation.set_minimap_visible(false)
		if quest_tracker_container:
			quest_tracker_container.visible = false


## Open directly to the world map (M key shortcut)
func _open_map() -> void:
	if game_menu:
		game_menu.open_to_tab(GameMenu.MenuTab.MAP)
		# Hide minimap and quest tracker when map opens
		navigation.set_minimap_visible(false)
		if quest_tracker_container:
			quest_tracker_container.visible = false

func _open_pause_menu() -> void:
	if pause_menu:
		pause_menu.open()

func _on_menu_closed() -> void:
	# Menu handles GameManager.exit_menu() itself
	# Restore minimap visibility when menus close
	navigation.set_minimap_visible(true)
	# Restore quest tracker (will show only if there's a tracked quest)
	_update_quest_tracker()

## Build the compass, minimap and bounty indicator
func _setup_navigation() -> void:
	navigation = HUDNavigation.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.setup(self)


## Rebuild the compass quest marker (called by SaveManager after a load)
func refresh_compass_quest_marker() -> void:
	navigation.refresh_compass_quest_marker()


## Connect to scene manager signals for zone transition cleanup
func _connect_scene_signals() -> void:
	if SceneManager.has_signal("scene_load_started"):
		SceneManager.scene_load_started.connect(_on_scene_load_started)
	if SceneManager.has_signal("scene_load_completed"):
		SceneManager.scene_load_completed.connect(_on_scene_load_completed)

## Called when a new scene starts loading - clean up POI markers and stale references
func _on_scene_load_started(_scene_path: String) -> void:
	navigation.clear_poi_markers()
	# Clear combat target to prevent "Trying to cast a freed object" crash
	current_target = null

## Called when scene loading completes - rebuild zone connections
func _on_scene_load_completed(_scene_path: String) -> void:
	# Defer to let the scene fully initialize
	navigation.rebuild_zone_connections.call_deferred()

func _process(delta: float) -> void:
	# Skip processing if player is dead or not valid (prevents crash after death)
	if not _cached_player or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player") as Node3D
	if not _cached_player or not is_instance_valid(_cached_player) or not _cached_player.is_inside_tree():
		return

	# PERFORMANCE: Cache enemies once per frame instead of multiple get_nodes_in_group() calls
	_cached_enemies = get_tree().get_nodes_in_group("enemies")

	_update_bars()
	_update_target_health()
	_update_notifications(delta)
	_update_conditions()
	_update_time()
	_update_durability_warning(delta)
	_update_game_log(delta)
	navigation.update(delta, _cached_player, _cached_enemies)
	_update_quest_tracker()
	_update_debug_overlay()
	_update_stealth_indicator()
	_update_escort_damage_flash(delta)
	_update_companion_command_mode()

## Skull frame texture for health/stamina bars
var skull_frame_texture: Texture2D = null
var skull_frame_container: Control = null

func _setup_health_frame() -> void:
	# Try to load the skull frame HUD scene (editable in Godot editor)
	var scene_path := "res://scenes/ui/skull_frame_hud.tscn"
	if not ResourceLoader.exists(scene_path):
		return

	var skull_scene: PackedScene = load(scene_path)
	if not skull_scene:
		return

	# Get the TopLeft VBoxContainer (parent of health bars)
	var top_left: VBoxContainer = null
	if health_bar:
		top_left = health_bar.get_parent() as VBoxContainer

	if not top_left:
		return

	# Hide the original TopLeft container - we use the scene instead
	top_left.visible = false

	# Instance the skull frame scene
	skull_frame_container = skull_scene.instantiate()
	add_child(skull_frame_container)

	# Get references to the bars from the scene
	var new_health_bar := skull_frame_container.get_node_or_null("HealthBar") as ProgressBar
	var new_stamina_bar := skull_frame_container.get_node_or_null("StaminaBar") as ProgressBar
	var new_mana_bar := skull_frame_container.get_node_or_null("ManaBar") as ProgressBar

	# Update references to use new bars
	if new_health_bar:
		health_bar = new_health_bar
	if new_stamina_bar:
		stamina_bar = new_stamina_bar
	if new_mana_bar:
		mana_bar = new_mana_bar
	health_label = null  # No more text label


func _setup_spell_slots() -> void:
	# Spell slots deprecated - mana bar is used instead
	if spell_slots_container:
		spell_slots_container.visible = false
	return

func _setup_quick_slots() -> void:
	# Quick slots disabled for now - feature not ready
	if quick_slots_container:
		quick_slots_container.visible = false
		return

	# Code below preserved for future use
	if not quick_slots_container:
		return

	# Clear existing
	for child in quick_slots_container.get_children():
		child.queue_free()

	# Create 4 quick slot displays
	for i in range(4):
		var slot_panel := Panel.new()
		slot_panel.custom_minimum_size = Vector2(48, 48)

		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		key_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		slot_panel.add_child(key_label)

		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.custom_minimum_size = Vector2(32, 32)
		slot_panel.add_child(icon)

		var count_label := Label.new()
		count_label.name = "Count"
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		slot_panel.add_child(count_label)

		quick_slots_container.add_child(slot_panel)
		quick_slot_icons.append(slot_panel)

func _connect_signals() -> void:
	# Disconnect old player_data signals if we were connected to a different one
	_disconnect_player_data_signals()

	# Connect to game signals - with error handling
	if GameManager.player_data:
		_connected_player_data = GameManager.player_data
		if GameManager.player_data.has_signal("hp_changed"):
			GameManager.player_data.hp_changed.connect(_on_hp_changed)
		if GameManager.player_data.has_signal("condition_applied"):
			GameManager.player_data.condition_applied.connect(_on_condition_applied)
		if GameManager.player_data.has_signal("condition_removed"):
			GameManager.player_data.condition_removed.connect(_on_condition_removed)
		if GameManager.player_data.has_signal("level_up"):
			GameManager.player_data.level_up.connect(_on_level_up)
		if GameManager.player_data.has_signal("ip_gained"):
			GameManager.player_data.ip_gained.connect(_on_xp_gained)

	if InventoryManager.has_signal("gold_changed"):
		InventoryManager.gold_changed.connect(_on_gold_changed)
	if InventoryManager.has_signal("quick_slot_changed"):
		InventoryManager.quick_slot_changed.connect(_on_quick_slot_changed)
	if InventoryManager.has_signal("item_added"):
		InventoryManager.item_added.connect(_on_item_added)
	if InventoryManager.has_signal("item_degraded"):
		InventoryManager.item_degraded.connect(_on_item_degraded)
	if InventoryManager.has_signal("item_repaired"):
		InventoryManager.item_repaired.connect(_on_item_repaired)

	if CombatManager.has_signal("damage_dealt"):
		CombatManager.damage_dealt.connect(_on_damage_dealt)
	if CombatManager.has_signal("critical_hit"):
		CombatManager.critical_hit.connect(_on_critical_hit)

	# Quest signals
	if QuestManager.has_signal("quest_started"):
		QuestManager.quest_started.connect(_on_quest_started)
	if QuestManager.has_signal("quest_completed"):
		QuestManager.quest_completed.connect(_on_quest_completed)
	if QuestManager.has_signal("objective_completed"):
		QuestManager.objective_completed.connect(_on_objective_completed)

	# Codex discovery signals - show notifications when things are discovered
	if CodexManager:
		if CodexManager.has_signal("recipe_discovered"):
			if not CodexManager.recipe_discovered.is_connected(_on_recipe_discovered):
				CodexManager.recipe_discovered.connect(_on_recipe_discovered)
		if CodexManager.has_signal("lore_discovered"):
			if not CodexManager.lore_discovered.is_connected(_on_lore_discovered):
				CodexManager.lore_discovered.connect(_on_lore_discovered)
		if CodexManager.has_signal("bestiary_entry_discovered"):
			if not CodexManager.bestiary_entry_discovered.is_connected(_on_bestiary_discovered):
				CodexManager.bestiary_entry_discovered.connect(_on_bestiary_discovered)

## Disconnect signals from old player_data to prevent "signal connected to freed object" errors
func _disconnect_player_data_signals() -> void:
	if _connected_player_data and is_instance_valid(_connected_player_data):
		if _connected_player_data.hp_changed.is_connected(_on_hp_changed):
			_connected_player_data.hp_changed.disconnect(_on_hp_changed)
		if _connected_player_data.condition_applied.is_connected(_on_condition_applied):
			_connected_player_data.condition_applied.disconnect(_on_condition_applied)
		if _connected_player_data.condition_removed.is_connected(_on_condition_removed):
			_connected_player_data.condition_removed.disconnect(_on_condition_removed)
		if _connected_player_data.level_up.is_connected(_on_level_up):
			_connected_player_data.level_up.disconnect(_on_level_up)
		if _connected_player_data.ip_gained.is_connected(_on_xp_gained):
			_connected_player_data.ip_gained.disconnect(_on_xp_gained)
	_connected_player_data = null

## Reconnect signals when player_data changes (e.g., new game, load game)
func reconnect_player_signals() -> void:
	_connect_signals()

func _update_bars() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		return

	# Health bar
	if health_bar:
		health_bar.max_value = char_data.max_hp
		health_bar.value = char_data.current_hp

	if health_label:
		health_label.text = "%d / %d" % [char_data.current_hp, char_data.max_hp]

	# Stamina bar
	if stamina_bar:
		stamina_bar.max_value = char_data.max_stamina
		stamina_bar.value = char_data.current_stamina

	# Mana bar
	if mana_bar:
		mana_bar.max_value = char_data.max_mana
		mana_bar.value = char_data.current_mana

	# Ammo display
	_update_ammo_display()

	# Equipped item display (bottom-left)
	_update_equipped_display()

	# Spell slots deprecated - mana is shown via mana_bar
	# _update_spell_slots(char_data.current_spell_slots, char_data.max_spell_slots)

	# Gold
	if gold_label:
		gold_label.text = "%d G" % InventoryManager.gold

func _update_spell_slots(current: int, maximum: int) -> void:
	for i in range(spell_slot_icons.size()):
		var icon: TextureRect = spell_slot_icons[i]
		if i < maximum:
			icon.visible = true
			# Could use different colors/textures for filled vs empty
			icon.modulate = Color.CYAN if i < current else Color(0.3, 0.3, 0.3)
		else:
			icon.visible = false

## Update ammo display based on equipped weapon
func _update_ammo_display() -> void:
	if not ammo_container:
		return

	# Get equipped weapon
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()

	# Hide if no weapon or melee weapon
	if not weapon or not weapon.is_ranged or weapon.ammo_type.is_empty():
		ammo_container.visible = false
		return

	# Show ammo count
	ammo_container.visible = true
	var ammo_count := InventoryManager.get_item_count(weapon.ammo_type)
	var ammo_name := _get_ammo_display_name(weapon.ammo_type)

	if ammo_label:
		ammo_label.text = "%s: %d" % [ammo_name, ammo_count]

## Get display name for ammo type
func _get_ammo_display_name(ammo_type: String) -> String:
	match ammo_type:
		"arrows": return "Arrows"
		"bolts": return "Bolts"
		"lead_balls": return "Lead Balls"
		_: return ammo_type.capitalize()

## Update equipped item display (bottom-left corner)
func _update_equipped_display() -> void:
	if not equipped_label:
		return

	# Check for equipped spell first (takes priority)
	var spell := InventoryManager.get_equipped_spell()
	if spell:
		equipped_label.text = spell.display_name
		equipped_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))  # Blue for magic
		return

	# Check for equipped weapon
	var weapon := InventoryManager.get_equipped_weapon()
	if weapon:
		equipped_label.text = weapon.display_name
		equipped_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))  # Warm white
		return

	# Nothing equipped
	equipped_label.text = "Unarmed"
	equipped_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))  # Gray

func _update_target_health() -> void:
	if not enemy_health_container:
		return

	# There is no lock-on. `PlayerController.lock_on_target` was read here and
	# assigned nowhere, so this panel could never appear; both are deleted
	# (batch 4, task 63). `current_target` is the last thing the player hit -
	# see _on_damage_dealt - which is the target they actually have.

	# Guard against freed objects - check validity before any access
	if not is_instance_valid(current_target):
		current_target = null

	if current_target and current_target.has_method("is_dead") and not current_target.is_dead():
		enemy_health_container.visible = true

		if enemy_name_label and is_instance_valid(current_target) and current_target is EnemyBase:
			var enemy := current_target as EnemyBase
			enemy_name_label.text = enemy.enemy_data.display_name if enemy.enemy_data else "Enemy"

		if enemy_health_bar and is_instance_valid(current_target) and current_target is EnemyBase:
			var enemy := current_target as EnemyBase
			enemy_health_bar.max_value = enemy.max_hp
			enemy_health_bar.value = enemy.current_hp
	else:
		enemy_health_container.visible = false

func _update_notifications(delta: float) -> void:
	if not notification_label:
		return

	if notification_timer > 0:
		notification_timer -= delta
		if notification_timer <= 0:
			notification_label.text = ""
			_show_next_notification()

## Setup the conditions display container below mana bar
func _setup_conditions_display() -> void:
	# Find or create parent container (TopLeft VBox)
	var top_left := get_node_or_null("TopLeft")
	if not top_left:
		return

	# Create conditions container below existing bars
	conditions_container = HBoxContainer.new()
	conditions_container.name = "ConditionsContainer"
	conditions_container.add_theme_constant_override("separation", 8)
	top_left.add_child(conditions_container)

	# Move it to be after mana bar if possible
	if mana_bar:
		var mana_idx := mana_bar.get_index()
		top_left.move_child(conditions_container, mana_idx + 1)

func _update_conditions() -> void:
	if not conditions_container:
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	# CharacterData.conditions is a Dictionary of { Condition -> time_remaining }
	var active_conditions: Dictionary = char_data.conditions

	# Track which conditions we need to add/update/remove
	var conditions_to_remove: Array = []
	for condition in condition_labels.keys():
		if not active_conditions.has(condition):
			conditions_to_remove.append(condition)

	# Remove labels for expired conditions
	for condition in conditions_to_remove:
		var label_panel: Control = condition_labels[condition]
		if is_instance_valid(label_panel):
			label_panel.queue_free()
		condition_labels.erase(condition)

	# Update or add labels for active conditions
	for condition in active_conditions.keys():
		var time_left: float = active_conditions[condition]

		if condition_labels.has(condition):
			# Update existing label
			_update_condition_label(condition, time_left)
		else:
			# Create new label
			_create_condition_label(condition, time_left)

## Create a condition label with colored panel
func _create_condition_label(condition: Enums.Condition, time_left: float) -> void:
	var panel := PanelContainer.new()

	# Create stylebox for background color
	var style := StyleBoxFlat.new()
	var is_buff := _is_buff_condition(condition)
	if is_buff:
		style.bg_color = Color(0.1, 0.3, 0.1, 0.8)  # Dark green for buffs
	else:
		style.bg_color = Color(0.3, 0.1, 0.1, 0.8)  # Dark red for debuffs
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	# Create label
	var label := Label.new()
	label.name = "ConditionLabel"
	var condition_name := _get_condition_name(condition)
	label.text = "%s %.1fs" % [condition_name, time_left]
	label.add_theme_color_override("font_color", _get_condition_text_color(condition))
	label.add_theme_font_size_override("font_size", 14)
	panel.add_child(label)

	conditions_container.add_child(panel)
	condition_labels[condition] = panel

## Update an existing condition label's time display
func _update_condition_label(condition: Enums.Condition, time_left: float) -> void:
	if not condition_labels.has(condition):
		return

	var panel: PanelContainer = condition_labels[condition]
	if not is_instance_valid(panel):
		condition_labels.erase(condition)
		return

	var label := panel.get_node_or_null("ConditionLabel") as Label
	if label:
		var condition_name := _get_condition_name(condition)
		label.text = "%s %.1fs" % [condition_name, time_left]

## Check if a condition is a buff (beneficial) or debuff (harmful)
func _is_buff_condition(condition: Enums.Condition) -> bool:
	match condition:
		Enums.Condition.ARMORED: return true
		Enums.Condition.HASTED: return true
		_: return false

## Get display name for a condition
func _get_condition_name(condition: Enums.Condition) -> String:
	match condition:
		Enums.Condition.NONE: return ""
		Enums.Condition.KNOCKED_DOWN: return "DOWNED"
		Enums.Condition.POISONED: return "POISONED"
		Enums.Condition.BURNING: return "BURNING"
		Enums.Condition.FROZEN: return "FROZEN"
		Enums.Condition.HORRIFIED: return "FEARED"
		Enums.Condition.BLEEDING: return "BLEEDING"
		Enums.Condition.STUNNED: return "STUNNED"
		Enums.Condition.SILENCED: return "SILENCED"
		Enums.Condition.ARMORED: return "ARMORED"
		Enums.Condition.BLINDED: return "BLINDED"
		Enums.Condition.SLOWED: return "SLOWED"
		Enums.Condition.HASTED: return "HASTED"
		_: return "UNKNOWN"

## Setup stealth indicator (HIDDEN text at center-bottom of screen)
func _setup_stealth_indicator() -> void:
	stealth_indicator = Label.new()
	stealth_indicator.name = "StealthIndicator"
	stealth_indicator.text = "HIDDEN"
	stealth_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stealth_indicator.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Style the label
	stealth_indicator.add_theme_font_size_override("font_size", 24)
	stealth_indicator.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1.0))  # Green
	stealth_indicator.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	stealth_indicator.add_theme_constant_override("shadow_offset_x", 2)
	stealth_indicator.add_theme_constant_override("shadow_offset_y", 2)

	# Position at center-bottom of screen
	stealth_indicator.anchors_preset = Control.PRESET_CENTER_BOTTOM
	stealth_indicator.anchor_left = 0.5
	stealth_indicator.anchor_right = 0.5
	stealth_indicator.anchor_top = 1.0
	stealth_indicator.anchor_bottom = 1.0
	stealth_indicator.offset_left = -60
	stealth_indicator.offset_right = 60
	stealth_indicator.offset_top = -100
	stealth_indicator.offset_bottom = -70

	# Start hidden
	stealth_indicator.visible = false

	add_child(stealth_indicator)


## Setup escort health UI (displayed during escort quests)
func _setup_escort_health() -> void:
	# Create container for escort health (positioned on right side, below enemy health area)
	escort_health_container = Control.new()
	escort_health_container.name = "EscortHealthContainer"
	escort_health_container.custom_minimum_size = Vector2(200, 50)

	# Position at top-right area, slightly lower
	escort_health_container.anchors_preset = Control.PRESET_TOP_RIGHT
	escort_health_container.anchor_left = 1.0
	escort_health_container.anchor_right = 1.0
	escort_health_container.anchor_top = 0.0
	escort_health_container.anchor_bottom = 0.0
	escort_health_container.offset_left = -220
	escort_health_container.offset_right = -10
	escort_health_container.offset_top = 100
	escort_health_container.offset_bottom = 150

	# Create background panel
	var bg_panel := PanelContainer.new()
	bg_panel.name = "Background"
	bg_panel.anchor_right = 1.0
	bg_panel.anchor_bottom = 1.0

	# Create dark semi-transparent style
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.5, 0.4, 0.3, 0.8)  # Bronze border
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bg_panel.add_theme_stylebox_override("panel", bg_style)
	escort_health_container.add_child(bg_panel)

	# Create vertical layout inside panel
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 4)
	bg_panel.add_child(vbox)

	# Escort name label
	escort_name_label = Label.new()
	escort_name_label.name = "EscortNameLabel"
	escort_name_label.text = "Escorting: Unknown"
	escort_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escort_name_label.add_theme_font_size_override("font_size", 12)
	escort_name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))  # Warm white
	vbox.add_child(escort_name_label)

	# Health bar
	escort_health_bar = ProgressBar.new()
	escort_health_bar.name = "EscortHealthBar"
	escort_health_bar.max_value = 100
	escort_health_bar.value = 100
	escort_health_bar.show_percentage = false
	escort_health_bar.custom_minimum_size = Vector2(0, 16)

	# Style the health bar (green/red gradient)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.1, 0.1, 0.8)  # Dark red background
	escort_health_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.7, 0.3, 0.9)  # Green fill
	escort_health_bar.add_theme_stylebox_override("fill", bar_fill)

	vbox.add_child(escort_health_bar)

	# Start hidden (only shown when escort is active)
	escort_health_container.visible = false

	add_child(escort_health_container)

	# Connect to EscortManager signals (use safe access)
	var escort_mgr: Node = get_node_or_null("/root/EscortManager")
	if escort_mgr:
		if escort_mgr.has_signal("escort_health_changed") and not escort_mgr.escort_health_changed.is_connected(_on_escort_health_changed):
			escort_mgr.escort_health_changed.connect(_on_escort_health_changed)
		if escort_mgr.has_signal("escort_started") and not escort_mgr.escort_started.is_connected(_on_escort_started):
			escort_mgr.escort_started.connect(_on_escort_started)
		if escort_mgr.has_signal("escort_ended") and not escort_mgr.escort_ended.is_connected(_on_escort_ended):
			escort_mgr.escort_ended.connect(_on_escort_ended)


## Show escort health bar with name and health values
func show_escort_health(escort_name: String, current_hp: int, max_hp: int) -> void:
	if not escort_health_container:
		return

	escort_health_container.visible = true

	if escort_name_label:
		escort_name_label.text = "Escorting: %s" % escort_name

	if escort_health_bar:
		escort_health_bar.max_value = max_hp
		escort_health_bar.value = current_hp

		# Update bar color based on health percentage
		var health_pct: float = float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
		var bar_fill := escort_health_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if bar_fill:
			if health_pct > 0.5:
				bar_fill.bg_color = Color(0.3, 0.7, 0.3, 0.9)  # Green
			elif health_pct > 0.25:
				bar_fill.bg_color = Color(0.8, 0.6, 0.2, 0.9)  # Yellow/orange
			else:
				bar_fill.bg_color = Color(0.8, 0.2, 0.2, 0.9)  # Red


## Hide escort health bar
func hide_escort_health() -> void:
	if escort_health_container:
		escort_health_container.visible = false


## Flash the escort health bar when damaged
func flash_escort_damage() -> void:
	escort_damage_flash_timer = ESCORT_DAMAGE_FLASH_DURATION

	# Flash the container red
	if escort_health_container:
		var bg_panel := escort_health_container.get_node_or_null("Background") as PanelContainer
		if bg_panel:
			var style := bg_panel.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				style.border_color = Color(1.0, 0.3, 0.3, 1.0)  # Bright red


## Update escort damage flash effect
func _update_escort_damage_flash(delta: float) -> void:
	if escort_damage_flash_timer > 0:
		escort_damage_flash_timer -= delta
		if escort_damage_flash_timer <= 0:
			# Restore normal border color
			if escort_health_container:
				var bg_panel := escort_health_container.get_node_or_null("Background") as PanelContainer
				if bg_panel:
					var style := bg_panel.get_theme_stylebox("panel") as StyleBoxFlat
					if style:
						style.border_color = Color(0.5, 0.4, 0.3, 0.8)  # Bronze


## Signal handlers for EscortManager
func _on_escort_health_changed(escort_id: String, current_hp: int, max_hp: int) -> void:
	if not EscortManager:
		return
	var escort: EscortNPC = EscortManager.get_escort(escort_id)
	if escort:
		show_escort_health(escort.npc_name, current_hp, max_hp)


func _on_escort_started(escort_id: String, escort: EscortNPC) -> void:
	if escort:
		show_escort_health(escort.npc_name, escort.current_health, escort.max_health)


func _on_escort_ended(escort_id: String, reason: String) -> void:
	# Only hide if this was the primary escort
	if EscortManager and not EscortManager.has_active_escort():
		hide_escort_health()


## Update stealth indicator visibility
func _update_stealth_indicator() -> void:
	if not stealth_indicator:
		return

	var player := get_tree().get_first_node_in_group("player")
	if not player:
		stealth_indicator.visible = false
		return

	# Check if player is hidden
	var is_hidden: bool = false
	if player.has_method("get_is_hidden"):
		is_hidden = player.get_is_hidden()

	# Check if player is crouching (show different indicator)
	var is_crouching: bool = false
	if player.has_method("get_is_crouching"):
		is_crouching = player.get_is_crouching()

	# Update visibility and text
	if is_hidden:
		stealth_indicator.text = "HIDDEN"
		stealth_indicator.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))  # Bright green
		stealth_indicator.visible = true
	elif is_crouching:
		stealth_indicator.text = "CROUCHING"
		stealth_indicator.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))  # Gray
		stealth_indicator.visible = true
	else:
		stealth_indicator.visible = false

func _update_time() -> void:
	if time_label:
		time_label.text = "Day %d - %s" % [GameManager.current_day, GameManager.get_time_string()]

## Get text color for condition display
func _get_condition_text_color(condition: Enums.Condition) -> Color:
	match condition:
		Enums.Condition.POISONED: return Color(0.4, 0.9, 0.3)  # Bright green
		Enums.Condition.BURNING: return Color(1.0, 0.6, 0.2)  # Orange
		Enums.Condition.FROZEN: return Color(0.5, 0.9, 1.0)  # Cyan
		Enums.Condition.BLEEDING: return Color(0.9, 0.3, 0.3)  # Red
		Enums.Condition.HORRIFIED: return Color(0.7, 0.3, 0.9)  # Purple
		Enums.Condition.STUNNED: return Color(1.0, 0.9, 0.3)  # Yellow
		Enums.Condition.SILENCED: return Color(0.6, 0.6, 0.8)  # Pale blue
		Enums.Condition.ARMORED: return Color(1.0, 0.85, 0.3)  # Gold
		Enums.Condition.BLINDED: return Color(1.0, 1.0, 0.8)  # White-yellow
		Enums.Condition.SLOWED: return Color(0.6, 0.4, 0.9)  # Purple
		Enums.Condition.HASTED: return Color(1.0, 0.85, 0.3)  # Gold
		Enums.Condition.KNOCKED_DOWN: return Color(0.8, 0.5, 0.3)  # Brown
		_: return Color.WHITE

func _get_condition_color(condition: Enums.Condition) -> Color:
	# Legacy function kept for compatibility
	return _get_condition_text_color(condition)

## Show a notification message
func show_notification(message: String) -> void:
	notification_queue.append(message)
	if notification_timer <= 0:
		_show_next_notification()

func _show_next_notification() -> void:
	if notification_queue.is_empty():
		return

	var message: String = notification_queue.pop_front()
	if notification_label:
		notification_label.text = message
	notification_timer = NOTIFICATION_DURATION

## Spawn a floating damage number
func spawn_damage_number(world_position: Vector3, damage: int, is_crit: bool = false, is_heal: bool = false) -> void:
	if not damage_number_scene:
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	# Convert world position to screen position
	var screen_pos := camera.unproject_position(world_position)

	# Check if on screen
	if not camera.is_position_behind(world_position):
		var dmg_num := damage_number_scene.instantiate()
		if damage_numbers_container:
			damage_numbers_container.add_child(dmg_num)
		else:
			add_child(dmg_num)

		if dmg_num is Control:
			(dmg_num as Control).position = screen_pos

		if dmg_num.has_method("setup"):
			dmg_num.setup(damage, is_heal, is_crit)

## Signal handlers

func _on_hp_changed(_old: int, _new: int, _max: int) -> void:
	# Bars update in process, but could trigger effects here
	pass

func _on_level_up(new_level: int) -> void:
	show_notification("LEVEL UP!")
	log_level_up(new_level)
	AudioManager.play_ui_confirm()

func _on_condition_applied(condition: Enums.Condition) -> void:
	var condition_name := _get_condition_name(condition)
	show_notification(condition_name + " applied!")

func _on_condition_removed(condition: Enums.Condition) -> void:
	var condition_name := _get_condition_name(condition)
	show_notification(condition_name + " removed")

func _on_gold_changed(old_amount: int, new_amount: int) -> void:
	var diff := new_amount - old_amount
	if diff > 0:
		log_gold_gained(diff)
	elif diff < 0:
		log_gold_spent(-diff)

func _on_item_added(item_id: String, quantity: int) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	log_item_received(item_name, quantity)

func _on_quick_slot_changed(slot: int, _item_id: String) -> void:
	_update_quick_slot(slot)

func _on_damage_dealt(attacker: Node, target: Node, damage: int, _type: Enums.DamageType) -> void:
	if target is Node3D:
		spawn_damage_number((target as Node3D).global_position + Vector3.UP * 2, damage)

	# The thing the player just hit is the thing whose health bar they want.
	if is_instance_valid(attacker) and attacker.is_in_group("player") and target is EnemyBase:
		current_target = target

func _on_critical_hit(_attacker: Node, target: Node) -> void:
	if target is Node3D:
		spawn_damage_number((target as Node3D).global_position + Vector3.UP * 2.5, 0, true)

func _on_xp_gained(amount: int) -> void:
	log_xp_gained(amount)

func _on_quest_started(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		log_quest_started(quest.title)

func _on_quest_completed(quest_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		log_quest_completed(quest.title)

func _on_objective_completed(quest_id: String, _objective_id: String) -> void:
	var quest := QuestManager.get_quest(quest_id)
	if quest:
		# Count remaining objectives
		var remaining := 0
		for obj in quest.objectives:
			if not obj.is_satisfied() and not obj.is_optional:
				remaining += 1
		if remaining > 0:
			log_quest_updated("Objective complete (%d remaining)" % remaining)
		else:
			log_quest_updated("All objectives complete!")

func _update_quick_slot(slot: int) -> void:
	if slot < 0 or slot >= quick_slot_icons.size():
		return

	var item_id: String = InventoryManager.quick_slots[slot]
	var slot_ui: Control = quick_slot_icons[slot]

	if item_id.is_empty():
		var icon := slot_ui.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.texture = null
		var count := slot_ui.get_node_or_null("Count") as Label
		if count:
			count.text = ""
	else:
		# Load item data and display
		var count := InventoryManager.get_item_count(item_id)
		var count_label := slot_ui.get_node_or_null("Count") as Label
		if count_label:
			count_label.text = str(count) if count > 1 else ""

## Setup interaction prompt label
func _setup_interaction_prompt() -> void:
	interaction_prompt_label = Label.new()
	interaction_prompt_label.name = "InteractionPrompt"
	interaction_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at bottom center of screen
	interaction_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	interaction_prompt_label.offset_top = -60
	interaction_prompt_label.offset_bottom = -40
	interaction_prompt_label.offset_left = -200
	interaction_prompt_label.offset_right = 200

	# Style it
	interaction_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.7))
	interaction_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	interaction_prompt_label.add_theme_constant_override("outline_size", 2)

	interaction_prompt_label.visible = false
	add_child(interaction_prompt_label)

## Show interaction prompt
func show_interaction_prompt(text: String) -> void:
	if interaction_prompt_label:
		interaction_prompt_label.text = "[E] " + text
		interaction_prompt_label.visible = true

## Hide interaction prompt
func hide_interaction_prompt() -> void:
	if interaction_prompt_label:
		interaction_prompt_label.visible = false

## Setup death screen
func _setup_death_screen() -> void:
	# Design resolution - canvas renders at this size with viewport stretch mode
	const DESIGN_WIDTH := 640
	const DESIGN_HEIGHT := 480

	# Create full-screen black background using anchors for proper scaling
	death_screen = ColorRect.new()
	death_screen.name = "DeathScreen"
	death_screen.color = Color(0, 0, 0, 0.95)
	death_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_screen.visible = false
	death_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(death_screen)

	# Create "YOU DIED" label - centered horizontally, slightly above center vertically
	var death_label := Label.new()
	death_label.name = "DeathLabel"
	death_label.text = "YOU DIED"
	death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))  # Dark red
	death_label.add_theme_font_size_override("font_size", 72)
	death_label.size = Vector2(400, 100)
	death_label.position = Vector2((DESIGN_WIDTH - 400) / 2, (DESIGN_HEIGHT / 2) - 140)
	death_screen.add_child(death_label)

	# Button container for vertical stacking
	var button_container := VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.size = Vector2(220, 180)
	button_container.position = Vector2((DESIGN_WIDTH - 220) / 2, (DESIGN_HEIGHT / 2) - 20)
	button_container.add_theme_constant_override("separation", 10)
	death_screen.add_child(button_container)

	# Load Last Autosave button (primary option)
	death_load_autosave_button = Button.new()
	death_load_autosave_button.name = "LoadAutosaveButton"
	death_load_autosave_button.text = "Load Last Autosave"
	death_load_autosave_button.custom_minimum_size = Vector2(220, 40)
	death_load_autosave_button.pressed.connect(_on_death_load_autosave)
	button_container.add_child(death_load_autosave_button)

	# Load Save button (opens save select)
	death_load_save_button = Button.new()
	death_load_save_button.name = "LoadSaveButton"
	death_load_save_button.text = "Load Save..."
	death_load_save_button.custom_minimum_size = Vector2(220, 40)
	death_load_save_button.pressed.connect(_on_death_load_save)
	button_container.add_child(death_load_save_button)

	# New Game button (full restart)
	death_restart_button = Button.new()
	death_restart_button.name = "NewGameButton"
	death_restart_button.text = "New Game"
	death_restart_button.custom_minimum_size = Vector2(220, 40)
	death_restart_button.pressed.connect(_on_death_new_game)
	button_container.add_child(death_restart_button)

	# Main Menu button (escape to title screen)
	death_main_menu_button = Button.new()
	death_main_menu_button.name = "MainMenuButton"
	death_main_menu_button.text = "Main Menu"
	death_main_menu_button.custom_minimum_size = Vector2(220, 40)
	death_main_menu_button.pressed.connect(_on_death_main_menu)
	button_container.add_child(death_main_menu_button)

	# Create save select panel (hidden by default)
	_setup_death_save_select()

	# Connect to player death signal
	if GameManager.has_signal("player_died"):
		GameManager.player_died.connect(_on_player_died)

## Setup save select panel for death screen
func _setup_death_save_select() -> void:
	const DESIGN_WIDTH := 640
	const DESIGN_HEIGHT := 480

	death_save_select_panel = Panel.new()
	death_save_select_panel.name = "SaveSelectPanel"
	death_save_select_panel.size = Vector2(400, 350)
	death_save_select_panel.position = Vector2((DESIGN_WIDTH - 400) / 2, (DESIGN_HEIGHT - 350) / 2)
	death_save_select_panel.visible = false
	death_screen.add_child(death_save_select_panel)

	# Title
	var title := Label.new()
	title.text = "Select Save to Load"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.position = Vector2(0, 10)
	title.size = Vector2(400, 30)
	death_save_select_panel.add_child(title)

	# Scroll container for saves
	var scroll := ScrollContainer.new()
	scroll.name = "SaveScroll"
	scroll.position = Vector2(10, 50)
	scroll.size = Vector2(380, 240)
	death_save_select_panel.add_child(scroll)

	var save_list := VBoxContainer.new()
	save_list.name = "SaveList"
	save_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(save_list)

	# Back button
	var back_button := Button.new()
	back_button.text = "Back"
	back_button.position = Vector2(150, 300)
	back_button.size = Vector2(100, 35)
	back_button.pressed.connect(_on_death_save_select_back)
	death_save_select_panel.add_child(back_button)

## Show death screen
func show_death_screen() -> void:
	if death_screen:
		# Track death
		SaveManager.increment_death_count()

		# Update autosave button availability - check both autosave slots
		if death_load_autosave_button:
			var has_autosave: bool = SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT) or SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT)
			death_load_autosave_button.disabled = not has_autosave
			if not has_autosave:
				death_load_autosave_button.text = "No Autosave Found"
			else:
				death_load_autosave_button.text = "Load Last Autosave"

		death_screen.visible = true
		if death_save_select_panel:
			death_save_select_panel.visible = false

		# Show mouse cursor for button interaction
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		# Pause the game
		get_tree().paused = true

## Handle player death signal
func _on_player_died() -> void:
	# Don't show death screen during boat voyage encounters (soft defeat handles it)
	var boat_voyage: Node = get_tree().get_first_node_in_group("boat_voyage")
	if boat_voyage and boat_voyage.is_in_encounter:
		return  # Boat voyage handles defeat with soft mechanics
	show_death_screen()

## Load autosave on death - prefer exit autosave, fallback to periodic
func _on_death_load_autosave() -> void:
	# Determine which autosave slot to load (prefer exit, fallback to periodic)
	var slot_to_load: int = -1
	if SaveManager.save_exists(SaveManager.AUTOSAVE_EXIT_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_EXIT_SLOT
	elif SaveManager.save_exists(SaveManager.AUTOSAVE_PERIODIC_SLOT):
		slot_to_load = SaveManager.AUTOSAVE_PERIODIC_SLOT

	if slot_to_load < 0:
		push_warning("[HUD] No autosave found to load")
		return

	_load_save_slot(slot_to_load)

## Shared function to load a save slot from death screen
func _load_save_slot(slot: int) -> void:
	# Get save info BEFORE loading to get the scene path
	var save_info: Dictionary = SaveManager.get_save_info(slot)
	var scene_path: String = save_info.get("current_scene", "")

	if scene_path.is_empty():
		push_warning("[HUD] Save has no current_scene, falling back to Elder Moor")
		scene_path = "res://scenes/levels/elder_moor.tscn"

	# Hide death screen and unpause
	if death_screen:
		death_screen.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# Load the save data (restores player stats, inventory, etc.)
	if not SaveManager.load_game(slot):
		push_error("[HUD] Failed to load save slot %d" % slot)
		death_load_failure_count += 1

		# Show death screen again on failure
		show_death_screen()

		# After 2 failures, highlight the Main Menu button as escape option
		if death_load_failure_count >= 2 and death_main_menu_button:
			death_main_menu_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			death_main_menu_button.text = "Main Menu (Escape)"
			show_notification("Save may be corrupted. Use 'Main Menu' to escape.")
		return

	# Reset failure counter on success
	death_load_failure_count = 0

	# Change to the saved scene
	SceneManager.change_scene(scene_path)

## Open save select panel
func _on_death_load_save() -> void:
	if not death_save_select_panel:
		return

	# Populate save list
	_populate_death_save_list()
	death_save_select_panel.visible = true

## Populate save list in death screen
func _populate_death_save_list() -> void:
	var save_list := death_save_select_panel.get_node_or_null("SaveScroll/SaveList") as VBoxContainer
	if not save_list:
		return

	# Clear existing entries
	for child in save_list.get_children():
		child.queue_free()

	# Get all saves
	var saves := SaveManager.get_all_save_infos()
	var has_any_save := false

	for save_info in saves:
		var slot: int = save_info.get("slot", -1)
		if save_info.get("empty", true):
			continue

		has_any_save = true

		var entry := Button.new()
		var char_name: String = save_info.get("character_name", "Unknown")
		var level: int = save_info.get("level", 1)
		var location: String = save_info.get("location", "Unknown")
		var datetime: String = save_info.get("datetime", "")

		# Format slot name
		var slot_name: String = "Slot %d" % slot
		if slot == SaveManager.AUTOSAVE_EXIT_SLOT:
			slot_name = "Exit Autosave"
		elif slot == SaveManager.AUTOSAVE_PERIODIC_SLOT:
			slot_name = "30s Autosave"
		elif slot == 0:
			slot_name = "Quick Save"

		entry.text = "%s - %s (Lv.%d) - %s" % [slot_name, char_name, level, location]
		entry.tooltip_text = datetime
		entry.custom_minimum_size = Vector2(360, 35)
		entry.pressed.connect(_on_death_load_slot.bind(slot))
		save_list.add_child(entry)

	if not has_any_save:
		var no_saves := Label.new()
		no_saves.text = "No saves found"
		no_saves.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_saves.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		save_list.add_child(no_saves)

## Load specific save slot from death screen
func _on_death_load_slot(slot: int) -> void:
	_load_save_slot(slot)

## Go back from save select panel
func _on_death_save_select_back() -> void:
	if death_save_select_panel:
		death_save_select_panel.visible = false

## Start a completely new game
func _on_death_new_game() -> void:
	# Reset failure counter
	death_load_failure_count = 0

	# Unpause first
	get_tree().paused = false

	# Reset all game state
	GameManager.reset_for_new_game()
	InventoryManager.reset_for_new_game()
	QuestManager.reset_for_new_game()
	SaveManager.reset_world_state()

	# Go to character creation for a fresh start
	get_tree().change_scene_to_file("res://scenes/ui/character_creation.tscn")


## Return to main menu (escape from broken save state)
func _on_death_main_menu() -> void:
	# Reset failure counter
	death_load_failure_count = 0

	# Unpause first
	get_tree().paused = false

	# Go to title screen without resetting game state
	# This allows player to potentially load a different save
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

## Setup durability warning label
func _setup_durability_warning() -> void:
	durability_warning_label = Label.new()
	durability_warning_label.name = "DurabilityWarning"
	durability_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	durability_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Position at top-left, below the health/stamina bars
	durability_warning_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	durability_warning_label.offset_top = 80
	durability_warning_label.offset_left = 10
	durability_warning_label.offset_right = 250
	durability_warning_label.offset_bottom = 100

	# Style with red warning color
	durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	durability_warning_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	durability_warning_label.add_theme_constant_override("outline_size", 2)

	durability_warning_label.visible = false
	add_child(durability_warning_label)

## Update durability warning (called every frame, but checks every DURABILITY_CHECK_INTERVAL)
## Only shows warnings for LOW (about to break) or BROKEN items
func _update_durability_warning(delta: float) -> void:
	durability_check_timer += delta
	if durability_check_timer < DURABILITY_CHECK_INTERVAL:
		return

	durability_check_timer = 0.0

	if not durability_warning_label:
		return

	# Check all equipment slots for LOW or BROKEN durability
	var low_slots: Array[String] = []
	var broken_slots: Array[String] = []
	var slot_display_names: Dictionary = {
		"main_hand": "Weapon",
		"off_hand": "Shield",
		"head": "Helm",
		"body": "Armor",
		"hands": "Gloves",
		"feet": "Boots"
	}

	for slot in ["main_hand", "off_hand", "head", "body", "hands", "feet"]:
		if InventoryManager.equipment[slot].is_empty():
			continue

		var state: InventoryManager.DurabilityState = InventoryManager.get_equipment_durability_state(slot)
		var display_name: String = slot_display_names.get(slot, slot)

		if state == InventoryManager.DurabilityState.BROKEN:
			broken_slots.append(display_name)
		elif state == InventoryManager.DurabilityState.LOW:
			low_slots.append(display_name)

	if low_slots.is_empty() and broken_slots.is_empty():
		durability_warning_label.visible = false
	else:
		# Flash effect using time-based modulation
		var flash_alpha := 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.005)
		durability_warning_label.modulate.a = flash_alpha

		# Build warning text - BROKEN takes priority over LOW
		var warning_text := ""
		if not broken_slots.is_empty():
			# Red warning for broken items
			durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
			warning_text = "!! " + " / ".join(broken_slots) + " BROKEN!"
		elif not low_slots.is_empty():
			# Orange-red for low items
			durability_warning_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
			warning_text = "! " + " / ".join(low_slots) + " Low!"

		durability_warning_label.text = warning_text
		durability_warning_label.visible = true

## Handle item degradation notification
func _on_item_degraded(_slot: String, item_id: String, new_quality: Enums.ItemQuality) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	var quality_name := _get_quality_display_name(new_quality)
	show_notification("Your %s has degraded to %s quality!" % [item_name, quality_name])

## Handle item repair notification
func _on_item_repaired(_slot: String, item_id: String, _durability_restored: int) -> void:
	var item_name := InventoryManager.get_item_name(item_id)
	show_notification("%s repaired!" % item_name)


## Handle recipe discovered notification
func _on_recipe_discovered(_category: String, recipe_id: String) -> void:
	var recipe: Dictionary = CodexManager.get_recipe(recipe_id)
	var recipe_name: String = recipe.get("display_name", recipe.get("name", recipe_id))
	show_notification("Recipe Learned: " + recipe_name)


## Handle lore discovered notification
func _on_lore_discovered(_category: String, lore_id: String) -> void:
	var lore: Dictionary = CodexManager.get_lore(lore_id)
	var lore_title: String = lore.get("title", lore_id)
	show_notification("Lore Discovered: " + lore_title)


## Handle bestiary entry discovered notification
func _on_bestiary_discovered(creature_id: String) -> void:
	var entry: Dictionary = CodexManager.get_bestiary_entry(creature_id)
	var creature_name: String = entry.get("name", creature_id)
	show_notification("Bestiary Entry: " + creature_name)


## Get human-readable quality name
func _get_quality_display_name(quality: Enums.ItemQuality) -> String:
	match quality:
		Enums.ItemQuality.POOR:
			return "Poor"
		Enums.ItemQuality.BELOW_AVERAGE:
			return "Worn"
		Enums.ItemQuality.AVERAGE:
			return "Average"
		Enums.ItemQuality.ABOVE_AVERAGE:
			return "Fine"
		Enums.ItemQuality.PERFECT:
			return "Perfect"
		_:
			return "Unknown"

## Setup game log container (bottom-right side panel)
func _setup_game_log() -> void:
	game_log_container = VBoxContainer.new()
	game_log_container.name = "GameLog"

	# Position at bottom-right
	game_log_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	game_log_container.anchor_left = 1.0
	game_log_container.anchor_right = 1.0
	game_log_container.anchor_top = 1.0
	game_log_container.anchor_bottom = 1.0
	game_log_container.offset_left = -280
	game_log_container.offset_right = -10
	game_log_container.offset_top = -200
	game_log_container.offset_bottom = -10

	# Align entries to bottom (newest at bottom)
	game_log_container.alignment = BoxContainer.ALIGNMENT_END
	game_log_container.add_theme_constant_override("separation", 2)

	add_child(game_log_container)

## Add an entry to the game log
func add_log_entry(message: String, color: Color = Color.WHITE) -> void:
	if not game_log_container:
		return

	var label := Label.new()
	label.text = message
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 12)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 260

	# Store timestamp for fading
	label.set_meta("spawn_time", Time.get_ticks_msec() / 1000.0)

	game_log_container.add_child(label)
	game_log_entries.append(label)

	# Remove oldest entries if over limit
	while game_log_entries.size() > MAX_LOG_ENTRIES:
		var old_entry: Control = game_log_entries.pop_front()
		old_entry.queue_free()

## Update game log (fade out old entries)
func _update_game_log(_delta: float) -> void:
	if not game_log_container:
		return

	var current_time := Time.get_ticks_msec() / 1000.0
	var entries_to_remove: Array[Control] = []

	for entry in game_log_entries:
		if not is_instance_valid(entry):
			entries_to_remove.append(entry)
			continue

		var spawn_time: float = entry.get_meta("spawn_time", current_time)
		var age := current_time - spawn_time

		if age > LOG_FADE_DURATION:
			entries_to_remove.append(entry)
		elif age > LOG_FADE_START:
			# Fade out
			var fade_progress := (age - LOG_FADE_START) / (LOG_FADE_DURATION - LOG_FADE_START)
			entry.modulate.a = 1.0 - fade_progress

	# Remove expired entries
	for entry in entries_to_remove:
		game_log_entries.erase(entry)
		if is_instance_valid(entry):
			entry.queue_free()

## Convenience methods for different log types
func log_xp_gained(amount: int) -> void:
	add_log_entry("+%d XP" % amount, Color(0.4, 0.8, 1.0))  # Light blue

func log_gold_gained(amount: int) -> void:
	add_log_entry("+%d Gold" % amount, Color(1.0, 0.85, 0.3))  # Gold color

func log_gold_spent(amount: int) -> void:
	add_log_entry("-%d Gold" % amount, Color(0.8, 0.6, 0.2))  # Darker gold

func log_item_received(item_name: String, quantity: int = 1) -> void:
	if quantity > 1:
		add_log_entry("+ %s x%d" % [item_name, quantity], Color(0.7, 0.9, 0.7))
	else:
		add_log_entry("+ %s" % item_name, Color(0.7, 0.9, 0.7))

func log_quest_started(quest_name: String) -> void:
	add_log_entry("Quest: %s" % quest_name, Color(1.0, 0.9, 0.5))

func log_quest_updated(message: String) -> void:
	add_log_entry(message, Color(0.9, 0.85, 0.6))

func log_quest_completed(quest_name: String) -> void:
	add_log_entry("Completed: %s" % quest_name, Color(0.5, 1.0, 0.5))

func log_level_up(new_level: int) -> void:
	add_log_entry("LEVEL UP! Now level %d" % new_level, Color(1.0, 1.0, 0.3))

func log_combat(message: String) -> void:
	add_log_entry(message, Color(0.9, 0.5, 0.5))  # Light red

## ============================================================================

## Setup quest tracker display at top of screen
func _setup_quest_tracker() -> void:
	quest_tracker_container = Control.new()
	quest_tracker_container.name = "QuestTracker"
	quest_tracker_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_container.offset_left = 10
	quest_tracker_container.offset_top = 110  # Below health/stamina/mana bars
	quest_tracker_container.offset_right = 350
	quest_tracker_container.offset_bottom = 160
	add_child(quest_tracker_container)

	# Semi-transparent background
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.0, 0.0, 0.0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	quest_tracker_container.add_child(bg)

	# Quest title label
	quest_tracker_title = Label.new()
	quest_tracker_title.name = "QuestTitle"
	quest_tracker_title.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_title.offset_left = 5
	quest_tracker_title.offset_top = 3
	quest_tracker_title.offset_right = 340
	quest_tracker_title.offset_bottom = 25
	quest_tracker_title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))  # Gold
	quest_tracker_title.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	quest_tracker_title.add_theme_constant_override("outline_size", 2)
	quest_tracker_title.add_theme_font_size_override("font_size", 14)
	quest_tracker_title.text = ""
	quest_tracker_container.add_child(quest_tracker_title)

	# Quest progress label
	quest_tracker_progress = Label.new()
	quest_tracker_progress.name = "QuestProgress"
	quest_tracker_progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quest_tracker_progress.offset_left = 5
	quest_tracker_progress.offset_top = 25
	quest_tracker_progress.offset_right = 340
	quest_tracker_progress.offset_bottom = 50
	quest_tracker_progress.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	quest_tracker_progress.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	quest_tracker_progress.add_theme_constant_override("outline_size", 1)
	quest_tracker_progress.add_theme_font_size_override("font_size", 12)
	quest_tracker_progress.text = ""
	quest_tracker_container.add_child(quest_tracker_progress)

	# Initially hidden
	quest_tracker_container.visible = false


## Update quest tracker with current tracked quest info
func _update_quest_tracker() -> void:
	if not quest_tracker_container:
		return

	var tracked_quest := QuestManager.get_tracked_quest()
	if not tracked_quest:
		quest_tracker_container.visible = false
		return

	# Hide quest tracker when any menu is open
	if _is_menu_open():
		quest_tracker_container.visible = false
		return

	quest_tracker_container.visible = true
	quest_tracker_title.text = tracked_quest.title

	# Build progress text from objectives
	var progress_parts: Array[String] = []
	for objective in tracked_quest.objectives:
		if objective.is_optional:
			continue  # Skip optional objectives
		var obj_text: String = objective.description
		var current: int = QuestManager.get_objective_progress(tracked_quest.id, objective.id)
		var required: int = objective.required_count
		if required > 1:
			obj_text += " (%d/%d)" % [current, required]
		elif current >= required:
			obj_text += " [DONE]"
		progress_parts.append(obj_text)

	quest_tracker_progress.text = " | ".join(progress_parts) if not progress_parts.is_empty() else ""


## ============================================================================
## DEBUG OVERLAY (F3 to toggle)
## ============================================================================

func _setup_debug_overlay() -> void:
	# Create container
	debug_overlay_container = PanelContainer.new()
	debug_overlay_container.name = "DebugOverlay"
	debug_overlay_container.visible = false
	debug_overlay_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	debug_overlay_container.offset_left = 10
	debug_overlay_container.offset_top = 10

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	debug_overlay_container.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	debug_overlay_container.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "DEBUG (F3)"
	title.add_theme_color_override("font_color", Color.YELLOW)
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	# Cell coordinates
	debug_cell_label = Label.new()
	debug_cell_label.text = "Cell: (0, 0)"
	debug_cell_label.add_theme_color_override("font_color", Color.WHITE)
	debug_cell_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debug_cell_label)

	# World position
	debug_world_pos_label = Label.new()
	debug_world_pos_label.text = "World Pos: (0, 0, 0)"
	debug_world_pos_label.add_theme_color_override("font_color", Color.WHITE)
	debug_world_pos_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debug_world_pos_label)

	# Active cells
	debug_active_cells_label = Label.new()
	debug_active_cells_label.text = "Active Cells: 0"
	debug_active_cells_label.add_theme_color_override("font_color", Color.WHITE)
	debug_active_cells_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debug_active_cells_label)

	# World offset
	debug_world_offset_label = Label.new()
	debug_world_offset_label.text = "World Offset: (0, 0, 0)"
	debug_world_offset_label.add_theme_color_override("font_color", Color.WHITE)
	debug_world_offset_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debug_world_offset_label)

	# FPS
	debug_fps_label = Label.new()
	debug_fps_label.text = "FPS: 0"
	debug_fps_label.add_theme_color_override("font_color", Color.GREEN)
	debug_fps_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(debug_fps_label)

	add_child(debug_overlay_container)


func _toggle_debug_overlay() -> void:
	debug_overlay_visible = not debug_overlay_visible
	if debug_overlay_container:
		debug_overlay_container.visible = debug_overlay_visible


## ============================================================================
## DECORATIVE BORDER FRAME
## ============================================================================

func _setup_border_frame() -> void:
	# Create the border frame as a separate CanvasLayer
	# It renders on top of regular HUD but hides when menus open
	border_frame = GameBorderFrame.new()
	border_frame.name = "GameBorderFrame"
	# Layer 10 puts it above most HUD elements (HUD is usually layer 1)
	# But it will hide itself when menus are open
	border_frame.layer = 10

	# Add to scene tree at root level so it's independent of HUD hierarchy
	get_tree().root.call_deferred("add_child", border_frame)


func _update_debug_overlay() -> void:
	if not debug_overlay_visible or not debug_overlay_container:
		return

	# Get player world position
	var world_pos := Vector3.ZERO
	if _cached_player and is_instance_valid(_cached_player):
		world_pos = _cached_player.global_position

	# Get cell info from CellStreamer
	var current_cell := Vector2i.ZERO
	var active_cell_count := 0
	var world_offset := Vector3.ZERO

	if CellStreamer:
		current_cell = CellStreamer.active_cell
		active_cell_count = CellStreamer.loaded_cells.size()
		world_offset = CellStreamer.world_offset

	# Calculate true world position (accounting for offset)
	var true_world_pos := world_pos + world_offset

	# Update labels
	debug_cell_label.text = "Cell: (%d, %d)" % [current_cell.x, current_cell.y]
	debug_world_pos_label.text = "World Pos: (%.1f, %.1f, %.1f)" % [true_world_pos.x, true_world_pos.y, true_world_pos.z]
	debug_active_cells_label.text = "Active Cells: %d" % active_cell_count
	debug_world_offset_label.text = "Offset: (%.0f, %.0f, %.0f)" % [world_offset.x, world_offset.y, world_offset.z]

	# FPS with color coding
	var fps := Engine.get_frames_per_second()
	debug_fps_label.text = "FPS: %d" % fps
	if fps >= 55:
		debug_fps_label.add_theme_color_override("font_color", Color.GREEN)
	elif fps >= 30:
		debug_fps_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		debug_fps_label.add_theme_color_override("font_color", Color.RED)


## Flash the screen with a color (used for pickpocket alerts, damage, etc.)
func flash_screen(color: Color = Color(1.0, 0.2, 0.2, 0.3), duration: float = 0.3) -> void:
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)

	# Fade out the flash
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.0, duration)
	tween.tween_callback(flash.queue_free)


## ============================================================================
## WAVE DEFENSE COUNTER
## ============================================================================

func _setup_wave_counter() -> void:
	# Create wave counter UI (hidden by default)
	wave_counter_ui = WaveCounterUI.new()
	wave_counter_ui.name = "WaveCounterUI"

	# Position in top-center area of screen
	wave_counter_ui.anchor_left = 0.5
	wave_counter_ui.anchor_right = 0.5
	wave_counter_ui.anchor_top = 0.0
	wave_counter_ui.anchor_bottom = 0.0
	wave_counter_ui.offset_left = -100
	wave_counter_ui.offset_right = 100
	wave_counter_ui.offset_top = 60  # Below any top-center elements
	wave_counter_ui.offset_bottom = 160

	add_child(wave_counter_ui)


## Show the wave counter and connect to a wave spawner
func show_wave_counter(spawner: WaveSpawner) -> void:
	if wave_counter_ui:
		wave_counter_ui.connect_to_spawner(spawner)
		wave_counter_ui.show_counter()


## Hide the wave counter
func hide_wave_counter() -> void:
	if wave_counter_ui:
		wave_counter_ui.disconnect_spawner()
		wave_counter_ui.hide_counter()


# =============================================================================
# TIMED OBJECTIVE UI
# =============================================================================

func _setup_timed_objective_ui() -> void:
	# Create timed objective UI (hidden by default, auto-shows when timer active)
	timed_objective_ui = TimedObjectiveUI.new()
	timed_objective_ui.name = "TimedObjectiveUI"

	# Position in top-right area, below escort health area
	timed_objective_ui.anchor_left = 1.0
	timed_objective_ui.anchor_right = 1.0
	timed_objective_ui.anchor_top = 0.0
	timed_objective_ui.anchor_bottom = 0.0
	timed_objective_ui.offset_left = -250
	timed_objective_ui.offset_right = -10
	timed_objective_ui.offset_top = 160  # Below escort health area
	timed_objective_ui.offset_bottom = 260

	add_child(timed_objective_ui)


# =============================================================================
# COMPANION HUD
# =============================================================================

func _setup_companion_hud() -> void:
	# Create companion status UI (positioned on left side)
	companion_status_ui = CompanionStatusUI.new()
	companion_status_ui.name = "CompanionStatusUI"

	# Position on left side of screen, below skull frame/health bars
	companion_status_ui.anchor_left = 0.0
	companion_status_ui.anchor_right = 0.0
	companion_status_ui.anchor_top = 0.0
	companion_status_ui.anchor_bottom = 0.0
	companion_status_ui.offset_left = 10
	companion_status_ui.offset_right = 200
	companion_status_ui.offset_top = 180  # Below health bars area
	companion_status_ui.offset_bottom = 340

	add_child(companion_status_ui)

	# Create companion command UI (positioned at bottom center)
	companion_command_ui = CompanionCommandUI.new()
	companion_command_ui.name = "CompanionCommandUI"

	# Position at bottom-center of screen
	companion_command_ui.anchor_left = 0.5
	companion_command_ui.anchor_right = 0.5
	companion_command_ui.anchor_top = 1.0
	companion_command_ui.anchor_bottom = 1.0
	companion_command_ui.offset_left = -140  # Half of PANEL_WIDTH
	companion_command_ui.offset_right = 140
	companion_command_ui.offset_top = -120
	companion_command_ui.offset_bottom = -20

	add_child(companion_command_ui)

	# Connect to CompanionManager signals for auto-show/hide
	_connect_companion_hud_signals()


## Connect companion HUD to CompanionManager signals
func _connect_companion_hud_signals() -> void:
	if not CompanionManager:
		return

	if CompanionManager.has_signal("companion_joined"):
		if not CompanionManager.companion_joined.is_connected(_on_companion_hud_companion_added):
			CompanionManager.companion_joined.connect(_on_companion_hud_companion_added)

	if CompanionManager.has_signal("companion_left"):
		if not CompanionManager.companion_left.is_connected(_on_companion_hud_companion_removed):
			CompanionManager.companion_left.connect(_on_companion_hud_companion_removed)


## Check if any companions are active
func _has_active_companions() -> bool:
	if not CompanionManager:
		return false
	return CompanionManager.get_companion_count() > 0


## Toggle companion command mode
func _toggle_companion_command_mode() -> void:
	_companion_command_mode_active = not _companion_command_mode_active

	if companion_command_ui:
		if _companion_command_mode_active:
			companion_command_ui.show_command_mode()
		else:
			companion_command_ui.hide_command_mode()


## Update companion command mode (auto-hide when no companions)
func _update_companion_command_mode() -> void:
	# Auto-hide command mode if no companions
	if _companion_command_mode_active and not _has_active_companions():
		_companion_command_mode_active = false
		if companion_command_ui:
			companion_command_ui.hide_command_mode()


## Called when a companion joins (auto-show status UI)
func _on_companion_hud_companion_added(_companion_id: String, _companion: CompanionNPC) -> void:
	# Status UI handles its own visibility via signals
	# Just ensure command UI hint is shown briefly
	if companion_command_ui and CompanionManager.get_companion_count() == 1:
		# First companion added - show command hint notification
		show_notification("Press [C] to command companions")


## Called when a companion is removed
func _on_companion_hud_companion_removed(_companion_id: String) -> void:
	# Auto-hide command mode if no more companions
	if not _has_active_companions():
		_companion_command_mode_active = false
		if companion_command_ui:
			companion_command_ui.hide_command_mode()


## Manually show companion command UI (for external scripts)
func show_companion_commands() -> void:
	if _has_active_companions() and companion_command_ui:
		_companion_command_mode_active = true
		companion_command_ui.show_command_mode()


## Manually hide companion command UI
func hide_companion_commands() -> void:
	_companion_command_mode_active = false
	if companion_command_ui:
		companion_command_ui.hide_command_mode()


## Show a companion bark (speech bubble text) - called by CompanionNPC
func show_companion_bark(companion_name: String, text: String) -> void:
	# Show as a game log entry or notification
	var bark_text: String = "%s: \"%s\"" % [companion_name, text]
	add_log_entry(bark_text, Color(0.7, 0.85, 0.9))


## Refresh companion HUD after scene load
func refresh_companion_hud() -> void:
	if companion_status_ui:
		companion_status_ui.refresh_companions()

	# Auto-hide command mode if no companions
	if not _has_active_companions():
		_companion_command_mode_active = false
		if companion_command_ui:
			companion_command_ui.hide_command_mode()
