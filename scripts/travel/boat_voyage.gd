## boat_voyage.gd - Manages the boat voyage experience
## Shows the player on a boat deck during sea travel with voyage progress
extends Node3D

const ZONE_ID := "boat_voyage"

## Voyage timing
const SEGMENT_DURATION := 10.0  # Seconds per segment (real-time)
const ENCOUNTER_WARNING_TIME := 3.0  # Warning before encounter spawns

## Enemy ship sprites
const PIRATE_SHIP_LEFT := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_left.png"
const PIRATE_SHIP_RIGHT := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_right.png"
const PIRATE_SHIP_FRONT := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_front.png"

## Enemy ship approach settings
const SHIP_START_DISTANCE := 60.0  # How far away the ship starts
const SHIP_APPROACH_DISTANCE := 12.0  # How close it gets before boarding
const SHIP_APPROACH_SPEED := 15.0  # Units per second

## Shipwreck flavor dialogues - player washes up on shore after sea monster defeat
const SHIPWRECK_DIALOGUES: Array[String] = [
	"The last thing you remember is the ship splintering beneath you. You awaken on the shore, half-drowned, with nothing but the clothes on your back.",
	"The creature's tentacles pulled the vessel under. Somehow, you clung to debris and drifted back to shore. Days pass before you regain consciousness.",
	"The beast devoured the ship whole. By some miracle, the sea spat you back onto familiar sands, broken and exhausted.",
	"You fought bravely, but the monster was too powerful. The ship is lost. You wash up on the shore where you started, battered but alive.",
	"The ship was torn apart. You drifted for days, delirious, until the currents carried you back to port. The crew was not so fortunate.",
	"The sea monster dragged the vessel to the depths. You escaped, barely, clinging to flotsam until fishermen found you washed ashore.",
	"When you awaken on the beach, you realize the nightmare was real. The ship, the crew, all lost to the creature. Four days have passed."
]

## Current voyage state
var current_route: BoatTravelData = null
var current_segment: int = 0
var total_segments: int = 0
var segment_timer: float = 0.0
var encounters_faced: int = 0
var is_in_encounter: bool = false

## Encounter warning state
var encounter_pending: SeaEncounter = null
var encounter_warning_timer: float = 0.0

## Enemy ship visual
var enemy_ship_sprite: Sprite3D = null
var enemy_ship_start_pos: Vector3 = Vector3.ZERO
var enemy_ship_target_pos: Vector3 = Vector3.ZERO
var ship_approach_progress: float = 0.0
var ship_approaching: bool = false

## UI references
var progress_label: Label = null
var status_label: Label = null
var warning_label: Label = null

## Debug menu UI
var debug_menu: PanelContainer = null
var debug_menu_visible: bool = false

## Boat deck spawn point
@onready var player_spawn: Marker3D = $SpawnPoints/PlayerSpawn if has_node("SpawnPoints/PlayerSpawn") else null
@onready var deck_area: Node3D = $DeckArea if has_node("DeckArea") else null


func _ready() -> void:
	# Connect to BoatTravelManager signals
	if BoatTravelManager:
		BoatTravelManager.journey_started.connect(_on_journey_started)
		BoatTravelManager.encounter_triggered.connect(_on_encounter_triggered)
		BoatTravelManager.encounter_resolved.connect(_on_encounter_resolved)
		BoatTravelManager.journey_complete.connect(_on_journey_complete)
		BoatTravelManager.journey_cancelled.connect(_on_journey_cancelled)

		# Get current route from manager
		current_route = BoatTravelManager.get_current_route()
		if current_route:
			total_segments = current_route.journey_segments
			_setup_voyage_ui()
			_position_player()
		else:
			push_warning("[BoatVoyage] No current route - scene may have loaded incorrectly")

	# Connect to player death signal for defeat handling
	if GameManager:
		if not GameManager.player_died.is_connected(_on_player_died):
			GameManager.player_died.connect(_on_player_died)

	_setup_ocean_ambient()
	_setup_debug_menu()


func _exit_tree() -> void:
	# Disconnect signals to prevent memory leaks
	if BoatTravelManager:
		if BoatTravelManager.journey_started.is_connected(_on_journey_started):
			BoatTravelManager.journey_started.disconnect(_on_journey_started)
		if BoatTravelManager.encounter_triggered.is_connected(_on_encounter_triggered):
			BoatTravelManager.encounter_triggered.disconnect(_on_encounter_triggered)
		if BoatTravelManager.encounter_resolved.is_connected(_on_encounter_resolved):
			BoatTravelManager.encounter_resolved.disconnect(_on_encounter_resolved)
		if BoatTravelManager.journey_complete.is_connected(_on_journey_complete):
			BoatTravelManager.journey_complete.disconnect(_on_journey_complete)
		if BoatTravelManager.journey_cancelled.is_connected(_on_journey_cancelled):
			BoatTravelManager.journey_cancelled.disconnect(_on_journey_cancelled)

	# Disconnect from player death signal
	if GameManager and GameManager.player_died.is_connected(_on_player_died):
		GameManager.player_died.disconnect(_on_player_died)

	# Clear pending state
	encounter_pending = null
	ship_approaching = false

	# Clean up enemy ship
	if enemy_ship_sprite and is_instance_valid(enemy_ship_sprite):
		enemy_ship_sprite.queue_free()
		enemy_ship_sprite = null

	# Clean up debug menu
	if debug_menu and is_instance_valid(debug_menu):
		debug_menu.queue_free()
		debug_menu = null


func _process(delta: float) -> void:
	# Handle enemy ship approach animation
	if ship_approaching and enemy_ship_sprite:
		ship_approach_progress += delta * SHIP_APPROACH_SPEED / SHIP_START_DISTANCE
		ship_approach_progress = minf(ship_approach_progress, 1.0)
		enemy_ship_sprite.global_position = enemy_ship_start_pos.lerp(enemy_ship_target_pos, ship_approach_progress)

		# Ship has arrived - spawn enemies
		if ship_approach_progress >= 1.0:
			ship_approaching = false
			_spawn_encounter_enemies()

	if is_in_encounter and not ship_approaching:
		# Handle encounter warning countdown (no ship animation)
		if encounter_pending and encounter_warning_timer > 0.0:
			encounter_warning_timer -= delta
			_update_warning_display()
			if encounter_warning_timer <= 0.0:
				_spawn_encounter_enemies()
		return

	# Process voyage segment timing
	if current_route and current_segment < total_segments:
		segment_timer += delta

		# Update progress display
		_update_progress_display()

		# Check if segment complete
		if segment_timer >= SEGMENT_DURATION:
			segment_timer = 0.0
			_complete_segment()


func _input(event: InputEvent) -> void:
	# F3 toggles debug menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()


func _setup_voyage_ui() -> void:
	# Create simple voyage UI
	var canvas := CanvasLayer.new()
	canvas.name = "VoyageUI"
	add_child(canvas)

	var container := VBoxContainer.new()
	container.anchor_left = 0.5
	container.anchor_top = 0.05
	container.anchor_right = 0.5
	container.anchor_bottom = 0.2
	container.offset_left = -150
	container.offset_right = 150
	container.add_theme_constant_override("separation", 10)
	canvas.add_child(container)

	# Route name
	var title := Label.new()
	title.text = current_route.display_name if current_route else "Sea Voyage"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	container.add_child(title)

	# Progress label
	progress_label = Label.new()
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_label.add_theme_font_size_override("font_size", 18)
	container.add_child(progress_label)

	# Status label
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	container.add_child(status_label)

	# Warning label (hidden by default)
	warning_label = Label.new()
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	warning_label.add_theme_font_size_override("font_size", 28)
	warning_label.visible = false
	canvas.add_child(warning_label)
	warning_label.anchor_left = 0.5
	warning_label.anchor_top = 0.4
	warning_label.anchor_right = 0.5
	warning_label.offset_left = -200
	warning_label.offset_right = 200

	_update_progress_display()
	_update_status("Sailing...")


func _position_player() -> void:
	# Position player at spawn point on deck
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player_spawn:
		player.global_position = player_spawn.global_position
		player.rotation.y = player_spawn.rotation.y
	elif player:
		# Fallback position on deck
		player.global_position = Vector3(0, 1, 0)


func _setup_ocean_ambient() -> void:
	# Could add ocean sounds, water shader effects, etc.

	# Disable fallback camera if player camera exists
	var fallback_camera: Camera3D = get_node_or_null("FallbackCamera")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and fallback_camera:
		fallback_camera.current = false
	elif fallback_camera:
		# No player - use fallback camera for testing
		fallback_camera.current = true


# =============================================================================
# DEBUG MENU (F3 to toggle)
# =============================================================================

func _setup_debug_menu() -> void:
	# Create dedicated debug canvas layer (always separate from VoyageUI)
	var canvas := CanvasLayer.new()
	canvas.name = "DebugUI"
	canvas.layer = 101
	add_child(canvas)

	debug_menu = PanelContainer.new()
	debug_menu.name = "DebugMenu"
	debug_menu.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	debug_menu.offset_left = 20
	debug_menu.offset_right = 220
	debug_menu.offset_top = -150
	debug_menu.offset_bottom = 150
	debug_menu.visible = false

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	panel_style.border_color = Color(0.8, 0.6, 0.2)
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(10)
	debug_menu.add_theme_stylebox_override("panel", panel_style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	debug_menu.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "DEBUG: Spawn Encounter"
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Encounter buttons
	_add_debug_button(vbox, "Pirates", _debug_spawn_pirates)
	_add_debug_button(vbox, "Ghost Pirates", _debug_spawn_ghost_pirates)
	_add_debug_button(vbox, "Sea Monster (Tentacles)", _debug_spawn_sea_monster)
	_add_debug_button(vbox, "Storm", _debug_spawn_storm)

	# Separator
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Utility buttons
	_add_debug_button(vbox, "Skip to Destination", _debug_skip_voyage)
	_add_debug_button(vbox, "Kill Player (Test Defeat)", _debug_kill_player)

	# Close hint
	var hint := Label.new()
	hint.text = "[F3] Close"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	canvas.add_child(debug_menu)


func _add_debug_button(parent: Control, text: String, callback: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(callback)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.2)
	normal.border_color = Color(0.4, 0.35, 0.3)
	normal.set_border_width_all(1)
	normal.set_content_margin_all(6)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.2, 0.15)
	hover.border_color = Color(0.9, 0.7, 0.4)
	hover.set_border_width_all(1)
	hover.set_content_margin_all(6)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_color_override("font_color", Color(0.9, 0.85, 0.75))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.6))

	parent.add_child(btn)


func _toggle_debug_menu() -> void:
	if debug_menu:
		debug_menu_visible = not debug_menu_visible
		debug_menu.visible = debug_menu_visible
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if debug_menu_visible else Input.MOUSE_MODE_CAPTURED)


func _debug_spawn_pirates() -> void:
	_toggle_debug_menu()
	if is_in_encounter:
		print("[BoatVoyage] DEBUG: Already in encounter!")
		return

	# Create a pirate encounter resource
	var encounter := SeaEncounter.new()
	encounter.id = "debug_pirate"
	encounter.display_name = "Pirate Attack"
	encounter.encounter_type = SeaEncounter.EncounterType.PIRATE
	encounter.xp_reward = 100
	encounter.gold_reward = Vector2i(30, 80)

	_start_encounter_warning(encounter)
	print("[BoatVoyage] DEBUG: Spawning Pirates!")


func _debug_spawn_ghost_pirates() -> void:
	_toggle_debug_menu()
	if is_in_encounter:
		print("[BoatVoyage] DEBUG: Already in encounter!")
		return

	var encounter := SeaEncounter.new()
	encounter.id = "debug_ghost_pirate"
	encounter.display_name = "Ghost Ship"
	encounter.encounter_type = SeaEncounter.EncounterType.GHOST_PIRATE
	encounter.xp_reward = 150
	encounter.gold_reward = Vector2i(50, 120)

	_start_encounter_warning(encounter)
	print("[BoatVoyage] DEBUG: Spawning Ghost Pirates!")


func _debug_spawn_sea_monster() -> void:
	_toggle_debug_menu()
	if is_in_encounter:
		print("[BoatVoyage] DEBUG: Already in encounter!")
		return

	var encounter := SeaEncounter.new()
	encounter.id = "debug_sea_monster"
	encounter.display_name = "Sea Monster"
	encounter.encounter_type = SeaEncounter.EncounterType.SEA_MONSTER
	encounter.xp_reward = 200
	encounter.gold_reward = Vector2i(0, 0)

	_start_encounter_warning(encounter)
	print("[BoatVoyage] DEBUG: Spawning Sea Monster!")


func _debug_spawn_storm() -> void:
	_toggle_debug_menu()
	if is_in_encounter:
		print("[BoatVoyage] DEBUG: Already in encounter!")
		return

	var encounter := SeaEncounter.new()
	encounter.id = "debug_storm"
	encounter.display_name = "Storm"
	encounter.encounter_type = SeaEncounter.EncounterType.STORM
	encounter.storm_damage = 15

	_start_encounter_warning(encounter)
	print("[BoatVoyage] DEBUG: Spawning Storm!")


func _debug_skip_voyage() -> void:
	_toggle_debug_menu()
	print("[BoatVoyage] DEBUG: Skipping to destination!")
	_complete_voyage()


func _debug_kill_player() -> void:
	_toggle_debug_menu()
	print("[BoatVoyage] DEBUG: Killing player to test defeat!")
	if GameManager and GameManager.player_data:
		GameManager.player_data.current_hp = 0
		GameManager.on_player_death()


func _update_progress_display() -> void:
	if not progress_label:
		return

	var segment_progress: float = segment_timer / SEGMENT_DURATION
	var total_progress: float = (current_segment + segment_progress) / total_segments
	var percent: int = int(total_progress * 100)

	progress_label.text = "Voyage Progress: %d%% (Leg %d of %d)" % [percent, current_segment + 1, total_segments]


func _update_status(text: String) -> void:
	if status_label:
		status_label.text = text


func _update_warning_display() -> void:
	if not warning_label or not encounter_pending:
		return

	warning_label.visible = true
	var seconds_left: int = ceili(encounter_warning_timer)
	warning_label.text = "%s in %d..." % [encounter_pending.display_name, seconds_left]


func _complete_segment() -> void:
	current_segment += 1
	print("[BoatVoyage] Completed segment %d/%d" % [current_segment, total_segments])

	# Advance game time
	if current_route and GameManager:
		var time_per_segment: float = current_route.travel_duration_hours / total_segments
		GameManager.advance_time(time_per_segment)

	# Roll for encounter
	if encounters_faced < current_route.max_encounters_per_journey:
		var encounter_resource: Resource = current_route.roll_encounter()
		if encounter_resource and encounter_resource is SeaEncounter:
			_start_encounter_warning(encounter_resource as SeaEncounter)
			return

	# Check if voyage complete
	if current_segment >= total_segments:
		_complete_voyage()
	else:
		_update_status("Sailing...")


func _start_encounter_warning(encounter: SeaEncounter) -> void:
	encounter_pending = encounter
	encounter_warning_timer = ENCOUNTER_WARNING_TIME
	is_in_encounter = true
	encounters_faced += 1

	_update_status("DANGER!")
	print("[BoatVoyage] Encounter incoming: %s" % encounter.display_name)

	# For pirate/ghost ship encounters, spawn an approaching enemy ship
	if encounter.encounter_type == SeaEncounter.EncounterType.PIRATE or \
	   encounter.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		_spawn_approaching_enemy_ship(encounter)

	# Play warning sound
	# AudioManager.play_sfx("encounter_warning")


## Spawn an enemy ship sprite that approaches from the distance
func _spawn_approaching_enemy_ship(encounter: SeaEncounter) -> void:
	# Choose random approach direction (port, starboard, or bow)
	var approach_dir: int = randi() % 3  # 0=port, 1=starboard, 2=bow

	# Select appropriate sprite based on direction
	var sprite_path: String
	match approach_dir:
		0:  # Port (left side) - ship faces right
			enemy_ship_start_pos = Vector3(-SHIP_START_DISTANCE, 0, 0)
			enemy_ship_target_pos = Vector3(-SHIP_APPROACH_DISTANCE, 0, 0)
			sprite_path = PIRATE_SHIP_RIGHT
		1:  # Starboard (right side) - ship faces left
			enemy_ship_start_pos = Vector3(SHIP_START_DISTANCE, 0, 0)
			enemy_ship_target_pos = Vector3(SHIP_APPROACH_DISTANCE, 0, 0)
			sprite_path = PIRATE_SHIP_LEFT
		_:  # Bow (front) - ship faces forward
			enemy_ship_start_pos = Vector3(0, 0, SHIP_START_DISTANCE)
			enemy_ship_target_pos = Vector3(0, 0, SHIP_APPROACH_DISTANCE)
			sprite_path = PIRATE_SHIP_FRONT

	# Load and create the ship sprite
	var ship_texture: Texture2D = load(sprite_path)
	if not ship_texture:
		push_warning("[BoatVoyage] Failed to load ship texture: %s" % sprite_path)
		return

	enemy_ship_sprite = Sprite3D.new()
	enemy_ship_sprite.name = "EnemyShip"
	enemy_ship_sprite.texture = ship_texture
	enemy_ship_sprite.pixel_size = 0.06  # Adjust size as needed
	enemy_ship_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED  # Static, no billboard
	enemy_ship_sprite.global_position = enemy_ship_start_pos

	# Tint ghost ships with an eerie glow
	if encounter.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		enemy_ship_sprite.modulate = Color(0.6, 0.8, 1.0, 0.85)  # Ghostly blue tint

	add_child(enemy_ship_sprite)

	# Start the approach animation
	ship_approach_progress = 0.0
	ship_approaching = true

	print("[BoatVoyage] Enemy ship spawned, approaching from %s" % ["port", "starboard", "bow"][approach_dir])


func _spawn_encounter_enemies() -> void:
	if not encounter_pending:
		return

	if warning_label:
		warning_label.visible = false
	_update_status("Under attack!")

	print("[BoatVoyage] Spawning encounter: %s" % encounter_pending.display_name)

	# Spawn enemies on the deck based on encounter type
	match encounter_pending.encounter_type:
		SeaEncounter.EncounterType.PIRATE:
			_spawn_pirates()
		SeaEncounter.EncounterType.GHOST_PIRATE:
			_spawn_ghost_pirates()
		SeaEncounter.EncounterType.SEA_MONSTER:
			_spawn_sea_creature()
		SeaEncounter.EncounterType.STORM:
			_handle_storm()
		_:
			# Unknown type - resolve immediately
			_resolve_current_encounter(BoatTravelManager.EncounterResult.PEACEFUL)


func _spawn_pirates() -> void:
	# Spawn pirate enemies on the deck - seadogs with chance for captain
	var enemy_count: int = randi_range(2, 4)
	var spawn_positions: Array[Vector3] = _get_deck_spawn_positions(enemy_count)
	var has_captain: bool = randf() < 0.4  # 40% chance for a captain

	for i in range(enemy_count):
		var pos: Vector3 = spawn_positions[i] if i < spawn_positions.size() else Vector3(randf_range(-3, 3), 1, randf_range(-2, 2))

		# First enemy might be a captain
		if i == 0 and has_captain:
			_spawn_enemy_at("res://data/enemies/pirate_captain.tres", pos, "Pirate Captain")
		else:
			_spawn_enemy_at("res://data/enemies/pirate_seadog.tres", pos, "Pirate Seadog")

	# Connect to enemy death signals to track combat progress
	_setup_encounter_tracking()


func _spawn_ghost_pirates() -> void:
	# Spawn ghost pirate enemies on the deck - seadogs with chance for captain
	var enemy_count: int = randi_range(2, 4)
	var spawn_positions: Array[Vector3] = _get_deck_spawn_positions(enemy_count)
	var has_captain: bool = randf() < 0.3  # 30% chance for a ghost captain

	for i in range(enemy_count):
		var pos: Vector3 = spawn_positions[i] if i < spawn_positions.size() else Vector3(randf_range(-3, 3), 1, randf_range(-2, 2))

		# First enemy might be a ghost captain
		if i == 0 and has_captain:
			_spawn_enemy_at("res://data/enemies/ghost_pirate_captain.tres", pos, "Ghost Captain")
		else:
			_spawn_enemy_at("res://data/enemies/ghost_pirate_seadog.tres", pos, "Ghost Pirate")

	_setup_encounter_tracking()


func _spawn_sea_creature() -> void:
	# Spawn 2-4 tentacles reaching up from the WATER around the boat
	# Tentacles stay OUTSIDE the boat bounds and attack "over the railing"
	var tentacle_count: int = randi_range(2, 4)

	# Try to use scene markers first, fallback to hardcoded positions
	var tentacle_positions: Array[Vector3] = _get_tentacle_spawn_positions()
	tentacle_positions.shuffle()

	# Tentacle sprites (randomly pick between variants)
	var tentacle_sprites: Array[String] = [
		"res://assets/sprites/enemies/beasts/sea monsters/tentacle_1.png",
		"res://assets/sprites/enemies/beasts/sea monsters/tentacle_2.png",
		"res://assets/sprites/enemies/beasts/sea monsters/tentacle_animation.png",
	]

	for i in range(mini(tentacle_count, tentacle_positions.size())):
		var pos: Vector3 = tentacle_positions[i]
		var sprite_path: String = tentacle_sprites[randi() % tentacle_sprites.size()]
		_spawn_tentacle(pos, sprite_path, i)

	_setup_encounter_tracking()


## Get tentacle spawn positions from scene markers or fallback to hardcoded
func _get_tentacle_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Try to get positions from scene markers
	var tentacle_spawns: Node3D = get_node_or_null("TentacleSpawns")
	if tentacle_spawns:
		for child in tentacle_spawns.get_children():
			if child is Marker3D:
				positions.append(child.global_position)

	# Fallback if no scene markers
	if positions.is_empty():
		# Hardcoded positions in the WATER (outside boat bounds)
		# Boat is roughly 10 units wide, so spawn at 8+ units from center
		# Y position at water level (-2.0) so they emerge from the ocean
		positions = [
			Vector3(-9, -2.0, 4),    # Port side bow (water)
			Vector3(9, -2.0, 4),     # Starboard side bow (water)
			Vector3(-9, -2.0, -3),   # Port side stern (water)
			Vector3(9, -2.0, -3),    # Starboard side stern (water)
			Vector3(-8, -2.0, 0),    # Port side center (water)
			Vector3(8, -2.0, 0),     # Starboard side center (water)
			Vector3(0, -2.0, 14),    # Far bow (water)
		]

	return positions


## Spawn a tentacle enemy at the given position (in the water, reaching toward the boat)
func _spawn_tentacle(pos: Vector3, sprite_path: String, index: int) -> void:
	var sprite_texture: Texture2D = load(sprite_path)
	if not sprite_texture:
		push_warning("[BoatVoyage] Failed to load tentacle sprite: %s" % sprite_path)
		return

	# Check if we have tentacle enemy data, otherwise use drowned_dead as fallback
	var enemy_data_path := "res://data/enemies/sea_tentacle.tres"
	if not ResourceLoader.exists(enemy_data_path):
		enemy_data_path = "res://data/enemies/drowned_dead.tres"

	# Determine h_frames based on sprite (animation sprite has multiple frames)
	var h_frames: int = 1
	var v_frames: int = 1
	if sprite_path.contains("animation"):
		h_frames = 4  # Animation sprite sheet

	var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("boat_enemies")
		enemy.add_to_group("enemies")
		enemy.add_to_group("tentacles")

		# Make tentacles larger and more menacing (scale up the sprite)
		if enemy.has_node("BillboardSprite"):
			var billboard: Node3D = enemy.get_node("BillboardSprite")
			billboard.scale = Vector3(2.5, 2.5, 2.5)  # Make tentacles imposing

		# Mark tentacle as stationary (should not move onto the boat)
		enemy.set_meta("stationary", true)
		enemy.set_meta("water_enemy", true)

		print("[BoatVoyage] Spawned Tentacle %d at %s (water position)" % [index + 1, pos])


func _handle_storm() -> void:
	# No combat - just damage and continue
	if GameManager and GameManager.player_data:
		var damage: int = randi_range(5, 15)
		GameManager.player_data.take_damage(damage)
		_update_status("Weathered the storm! (-%d HP)" % damage)

	# Brief delay then continue
	await get_tree().create_timer(2.0).timeout
	_resolve_current_encounter(BoatTravelManager.EncounterResult.STORM_SURVIVED)


func _get_deck_spawn_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Spawn positions around the deck edges
	var deck_positions: Array[Vector3] = [
		Vector3(-4, 1, 0),    # Port side
		Vector3(4, 1, 0),     # Starboard side
		Vector3(0, 1, 3),     # Bow
		Vector3(-3, 1, 2),    # Port bow
		Vector3(3, 1, 2),     # Starboard bow
	]

	for i in range(mini(count, deck_positions.size())):
		positions.append(deck_positions[i])

	return positions


func _spawn_enemy_at(enemy_data_path: String, pos: Vector3, display_name: String) -> void:
	# Check if enemy data exists
	if not ResourceLoader.exists(enemy_data_path):
		push_warning("[BoatVoyage] Enemy data not found: %s" % enemy_data_path)
		return

	var enemy_data: EnemyData = load(enemy_data_path)
	if not enemy_data:
		return

	# Get sprite texture
	var sprite_path: String = enemy_data.sprite_path if enemy_data.sprite_path else "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"
	var sprite_texture: Texture2D = load(sprite_path) if ResourceLoader.exists(sprite_path) else null

	if not sprite_texture:
		push_warning("[BoatVoyage] Sprite not found: %s" % sprite_path)
		return

	var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		enemy_data_path,
		sprite_texture,
		enemy_data.sprite_hframes,
		enemy_data.sprite_vframes
	)

	if enemy:
		enemy.add_to_group("boat_enemies")
		enemy.add_to_group("enemies")
		print("[BoatVoyage] Spawned %s at %s" % [display_name, pos])


func _setup_encounter_tracking() -> void:
	# Track when all enemies are defeated
	# Use deferred check since enemies may not be immediately ready
	call_deferred("_check_enemies_remaining")


func _check_enemies_remaining() -> void:
	if not is_in_encounter:
		return

	var enemies: Array[Node] = get_tree().get_nodes_in_group("boat_enemies")
	var alive_count: int = 0

	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is EnemyBase:
			var e: EnemyBase = enemy as EnemyBase
			if not e.is_dead:
				alive_count += 1
				# Connect death signal if not already connected
				if not e.died.is_connected(_on_enemy_died):
					e.died.connect(_on_enemy_died)

	if alive_count == 0 and is_in_encounter:
		_resolve_current_encounter(BoatTravelManager.EncounterResult.VICTORY)


func _on_enemy_died(_enemy: EnemyBase) -> void:
	# Check remaining enemies after a brief delay
	await get_tree().create_timer(0.5).timeout
	_check_enemies_remaining()


func _resolve_current_encounter(result: BoatTravelManager.EncounterResult) -> void:
	if not encounter_pending:
		return

	print("[BoatVoyage] Encounter resolved: %s" % BoatTravelManager.EncounterResult.keys()[result])

	# Award rewards for victory
	if result == BoatTravelManager.EncounterResult.VICTORY:
		_award_encounter_rewards()

	# Clear encounter state
	encounter_pending = null
	is_in_encounter = false
	ship_approaching = false

	# Remove the enemy ship sprite
	if enemy_ship_sprite and is_instance_valid(enemy_ship_sprite):
		enemy_ship_sprite.queue_free()
		enemy_ship_sprite = null

	# Remove any remaining boat enemies
	for enemy in get_tree().get_nodes_in_group("boat_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Check if voyage complete
	if current_segment >= total_segments:
		_complete_voyage()
	else:
		_update_status("Sailing...")


func _award_encounter_rewards() -> void:
	if not encounter_pending:
		return

	# XP reward
	if GameManager and GameManager.player_data:
		GameManager.player_data.add_ip(encounter_pending.xp_reward)
		print("[BoatVoyage] Awarded %d XP" % encounter_pending.xp_reward)

	# Gold reward
	var gold: int = encounter_pending.roll_gold_reward()
	if gold > 0 and InventoryManager:
		InventoryManager.add_gold(gold)
		print("[BoatVoyage] Awarded %d gold" % gold)

	# Notify player
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Victory! +%d XP, +%d gold" % [encounter_pending.xp_reward, gold], Color(0.3, 1.0, 0.3))


func _complete_voyage() -> void:
	print("[BoatVoyage] Voyage complete! Arrived at %s" % current_route.destination_port)
	_update_status("Arriving at destination...")

	# Reset BoatTravelManager state
	if BoatTravelManager:
		BoatTravelManager.journey_complete.emit(current_route, encounters_faced)
		BoatTravelManager._reset_journey_state()

	# Brief pause before transition
	await get_tree().create_timer(2.0).timeout

	# Transition to destination
	var destination: String = current_route.destination_port
	_travel_to_destination(destination)


func _travel_to_destination(port_id: String) -> void:
	# Get destination scene from WorldGrid using location info
	var location_info: Dictionary = WorldGrid.get_location_info(port_id)
	if not location_info.is_empty():
		var scene_path: String = location_info.get("scene_path", "")
		var coords: Vector2i = location_info.get("coords", Vector2i.ZERO)

		if not scene_path.is_empty():
			print("[BoatVoyage] Loading destination scene: %s" % scene_path)
			if SceneManager:
				SceneManager.change_scene(scene_path, "harbor_spawn")
				return

		# Scene path empty but location exists - teleport to wilderness at coords
		print("[BoatVoyage] No scene for %s, loading wilderness at %s" % [port_id, coords])
		if PlayerGPS:
			PlayerGPS.set_position(coords)
		if SceneManager:
			SceneManager.change_scene("res://scenes/wilderness/wilderness.tscn", "default")
		return

	# Unknown location - log error and stay put
	push_error("[BoatVoyage] Unknown destination port: %s" % port_id)
	if SceneManager:
		SceneManager.return_to_previous_scene()


# =============================================================================
# BOAT TRAVEL MANAGER SIGNAL HANDLERS
# =============================================================================

func _on_journey_started(route: BoatTravelData) -> void:
	current_route = route
	total_segments = route.journey_segments
	current_segment = 0
	_setup_voyage_ui()


func _on_encounter_triggered(encounter: SeaEncounter) -> void:
	# Manager detected encounter - we handle it visually
	_start_encounter_warning(encounter)


func _on_encounter_resolved(_encounter: SeaEncounter, _result: BoatTravelManager.EncounterResult) -> void:
	# Encounter resolved via manager (shouldn't happen if we're handling it)
	pass


func _on_journey_complete(_route: BoatTravelData, _encounters_count: int) -> void:
	_complete_voyage()


func _on_journey_cancelled(_route: BoatTravelData, reason: String) -> void:
	print("[BoatVoyage] Journey cancelled: %s" % reason)
	_update_status("Journey cancelled: %s" % reason)

	# Return to departure port
	await get_tree().create_timer(2.0).timeout
	if SceneManager:
		SceneManager.return_to_previous_scene()


# =============================================================================
# PLAYER DEFEAT HANDLING
# =============================================================================

## Called when player dies during a boat encounter
func _on_player_died() -> void:
	# Only handle if we're in an encounter on the boat
	if not is_in_encounter or not encounter_pending:
		return

	print("[BoatVoyage] Player died during encounter: %s" % encounter_pending.display_name)
	_handle_player_defeat()


## Handle player defeat based on encounter type
func _handle_player_defeat() -> void:
	is_in_encounter = false

	# Clean up enemies
	for enemy in get_tree().get_nodes_in_group("boat_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Remove the enemy ship sprite
	if enemy_ship_sprite and is_instance_valid(enemy_ship_sprite):
		enemy_ship_sprite.queue_free()
		enemy_ship_sprite = null

	match encounter_pending.encounter_type:
		SeaEncounter.EncounterType.PIRATE, SeaEncounter.EncounterType.GHOST_PIRATE:
			_handle_pirate_defeat()
		SeaEncounter.EncounterType.SEA_MONSTER:
			_handle_sea_monster_defeat()
		_:
			# Other encounter types - just arrive at destination
			_complete_voyage()


## Handle defeat by pirates/ghost pirates - player is knocked out but rescued, loses gold
func _handle_pirate_defeat() -> void:
	# Player is knocked out but rescued by crew, loses gold (25-100)
	var gold_loss: int = randi_range(25, 100)

	if InventoryManager:
		var actual_loss: int = mini(gold_loss, InventoryManager.get_gold())
		InventoryManager.remove_gold(actual_loss)
		gold_loss = actual_loss

	# Revive player with 1 HP
	if GameManager and GameManager.player_data:
		GameManager.player_data.current_hp = 1

	# Show notification
	var encounter_name: String = encounter_pending.get_type_name() if encounter_pending else "pirates"
	_update_status("You were overwhelmed...")

	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("You lost %d gold to the %s!" % [gold_loss, encounter_name], Color(1.0, 0.5, 0.3))

	print("[BoatVoyage] Pirate defeat - lost %d gold, continuing to destination" % gold_loss)

	# Brief delay then continue to destination (you're still rescued)
	await get_tree().create_timer(2.0).timeout

	# Clear encounter state
	encounter_pending = null

	# Continue to destination
	_complete_voyage()


## Handle defeat by sea monster - ship destroyed, return to origin, 4 day time skip
func _handle_sea_monster_defeat() -> void:
	# Revive player with 1 HP
	if GameManager and GameManager.player_data:
		GameManager.player_data.current_hp = 1

	# Advance time 4 days (96 hours)
	if GameManager:
		GameManager.advance_time(96.0)

	# No gold refund - the voyage cost is lost
	print("[BoatVoyage] Sea monster defeat - 4 days lost, returning to %s" % BoatTravelManager.departure_port)

	# Show shipwreck dialogue
	var dialogue_text: String = SHIPWRECK_DIALOGUES[randi() % SHIPWRECK_DIALOGUES.size()]
	await _show_shipwreck_dialogue(dialogue_text)

	# Clear encounter state
	encounter_pending = null

	# Return to departure port
	_return_to_departure_port()


## Display shipwreck narrative dialogue using ConversationSystem
func _show_shipwreck_dialogue(text: String) -> void:
	# Use ConversationSystem for a scripted dialogue sequence
	if not ConversationSystem:
		await get_tree().create_timer(3.0).timeout
		return

	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		"",  # No speaker (narrator)
		text,
		[ConversationSystem.create_scripted_choice("...", 1)]
	))
	lines.append(ConversationSystem.create_scripted_line(
		"",
		"You have lost four days recovering from your ordeal.",
		[],
		true  # is_end
	))

	ConversationSystem.start_scripted_dialogue(lines)
	await ConversationSystem.scripted_dialogue_ended


## Return player to the port they departed from after sea monster defeat
func _return_to_departure_port() -> void:
	var departure: String = BoatTravelManager.departure_port
	if departure.is_empty():
		departure = current_route.departure_port if current_route else "dalhurst"

	_update_status("Returning to %s..." % departure)

	# Reset boat travel state
	if BoatTravelManager:
		BoatTravelManager._reset_journey_state()

	# Brief pause before transition
	await get_tree().create_timer(1.5).timeout

	# Travel back to departure port
	_travel_to_destination(departure)
