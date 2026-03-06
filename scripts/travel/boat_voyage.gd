## boat_voyage.gd - Manages the boat voyage experience
## Player sails on a walkable boat deck through a bay with coastal scenery
## Integrated with world time system (DayNightCycle) for proper lighting
extends Node3D

const ZONE_ID := "boat_voyage"

## Voyage timing - simple 60 second voyage if no encounter
const VOYAGE_DURATION := 60.0  # Total voyage time in seconds

## Time progression during voyage (hours per real second)
## Default 60 seconds = route.travel_duration_hours (typically 1.5-3 hours in-game)
var time_per_second: float = 0.025  # Will be calculated from route duration

## Encounter chances (total 20%, 5% sea monster)
const ENCOUNTER_CHANCE := 0.20  # 20% chance of any encounter
const SEA_MONSTER_CHANCE := 0.25  # 25% of encounters are sea monsters (5% total)
const GHOST_PIRATE_CHANCE := 0.35  # 35% of encounters are ghost pirates (7% total)
## Remaining 40% are regular pirates (8% total)

## Enemy ship sprites
const PIRATE_SHIP_PORTSIDE := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_portside.png"
const PIRATE_SHIP_STARBOARDSIDE := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_starboardside.png"
const PIRATE_SHIP_FRONT := "res://assets/sprites/vehicles/pirate_ship/pirate_ship_front.png"

## Enemy ship approach settings - ADJUSTED for better visuals
const SHIP_START_DISTANCE := 120.0  # Further out on horizon (negative Z = in front)
const SHIP_APPROACH_DISTANCE := 18.0  # Don't ram the boat
const SHIP_APPROACH_SPEED := 8.0  # Slower approach for tension
const PIRATE_SHIP_SCALE := 2.0  # 200% bigger ships
const SHIP_DOCKED_HEIGHT := 15.0  # Height when alongside (visible above water)

## Circling behavior - ambient ships on horizon
const CIRCLE_RADIUS := 100.0
const CIRCLE_SPEED := 0.3  # Radians per second (slow menacing orbit)
const AMBIENT_SHIP_COUNT := 2  # Ships circling on horizon

## Boarding animation
const BOARDING_ARC_HEIGHT := 5.0
const BOARDING_DURATION := 0.8
const BOARDING_STAGGER := 0.3

## Tentacle animation
const TENTACLE_RISE_DURATION := 1.5
const TENTACLE_START_Y := -5.0
const TENTACLE_END_Y := 2.5
const TENTACLE_START_SCALE := 0.5
const TENTACLE_END_SCALE := 2.5
const TENTACLE_ATTACK_WINDUP := 0.5
const TENTACLE_ATTACK_SWING := 0.3
const TENTACLE_ATTACK_COOLDOWN := 2.5

## Level scaling for pirates
const PIRATES_BASE_COUNT := 2
const PIRATES_PER_10_LEVELS := 1
const PIRATES_MAX := 7

## Boat rocking/movement simulation
const BOAT_ROLL_AMOUNT := 2.5  # Degrees of side-to-side roll
const BOAT_ROLL_SPEED := 0.8  # Speed of roll oscillation
const BOAT_PITCH_AMOUNT := 1.5  # Degrees of bow-to-stern pitch
const BOAT_PITCH_SPEED := 0.6  # Speed of pitch oscillation
const BOAT_YAW_AMOUNT := 0.5  # Slight heading drift
const BOAT_YAW_SPEED := 0.3  # Speed of yaw drift
const WATER_SCROLL_SPEED := 2.0  # Units per second for water texture scroll
const WAKE_FOAM_SPEED := 3.0  # Speed of wake foam particles

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
var voyage_timer: float = 0.0
var voyage_started: bool = false
var encounter_rolled: bool = false
var is_in_encounter: bool = false
var voyage_completing: bool = false  # Guard against re-entry during completion

## Encounter state
var encounter_pending: SeaEncounter = null
var encounter_trigger_time: float = 0.0  # When during voyage the encounter triggers

## Ghost pirate ambient sounds
var ghost_growl_timer: float = 0.0
const GHOST_GROWL_INTERVAL_MIN := 2.0
const GHOST_GROWL_INTERVAL_MAX := 5.0

## Kraken/sea monster ambient sounds
var kraken_sound_timer: float = 0.0
const KRAKEN_SOUND_INTERVAL_MIN := 3.0
const KRAKEN_SOUND_INTERVAL_MAX := 6.0

## Enemy ship visual
var enemy_ship_sprite: Sprite3D = null
var enemy_ship_start_pos: Vector3 = Vector3.ZERO
var enemy_ship_target_pos: Vector3 = Vector3.ZERO
var ship_approach_progress: float = 0.0
var ship_approaching: bool = false
var ship_approach_direction: int = 0  # 0=port, 1=starboard, 2=bow

## Ambient circling ships (shark-like behavior)
var ambient_ships: Array[Sprite3D] = []
var ambient_ship_angles: Array[float] = []
var ambient_ships_active: bool = false

## Debug menu UI
var debug_menu: PanelContainer = null
var debug_menu_visible: bool = false

## Coastline panorama sprites
var port_coastline: Sprite3D = null
var starboard_coastline: Sprite3D = null

## Crew NPCs
var helmsman: Node3D = null
var deck_hand_1: Node3D = null
var deck_hand_2: Node3D = null
var crew_fighting: bool = false

## Boat rocking/movement nodes
var boat_pivot: Node3D = null  # Node that rocks with the waves
var boat_model: Node3D = null  # The boat GLB model
var ocean_mesh: CSGBox3D = null  # The ocean surface
var wake_particles: GPUParticles3D = null  # Wake foam behind boat
var water_offset: Vector2 = Vector2.ZERO  # For water texture scrolling

## Boat deck spawn point
var player_spawn: Marker3D = null
var deck_area: Node3D = null

## Player scene for spawning
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
var player: Node3D = null

## Tentacle tracking for attack behavior
var active_tentacles: Array[EnemyBase] = []
var tentacle_attack_timers: Dictionary = {}  # instance_id -> float

## Day/night cycle integration
var day_night_cycle: DayNightCycle = null
var voyage_start_time: float = 0.0  # GameManager.game_time when voyage started
var time_accumulated: float = 0.0  # Real seconds elapsed (for time sync)

## Ocean night colors - adjusted for time of day
const OCEAN_DAY_COLOR := Color(0.08, 0.18, 0.32, 0.95)
const OCEAN_NIGHT_COLOR := Color(0.03, 0.06, 0.12, 0.98)
const OCEAN_DUSK_COLOR := Color(0.06, 0.10, 0.20, 0.96)
const OCEAN_DAWN_COLOR := Color(0.08, 0.14, 0.25, 0.96)


func _ready() -> void:
	# Add to group so HUD can find us during encounters
	add_to_group("boat_voyage")

	# Get scene node references
	player_spawn = get_node_or_null("SpawnPoints/PlayerSpawn")
	deck_area = get_node_or_null("DeckArea")

	# Set location name override for HUD minimap display
	if PlayerGPS:
		PlayerGPS.location_name_override = "Bay of Marol"

	# Ensure player exists on the boat deck
	_ensure_player_exists()

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
			_roll_for_encounter()
			voyage_started = true
			# Calculate time progression rate from route duration
			time_per_second = current_route.travel_duration_hours / VOYAGE_DURATION
			print("[BoatVoyage] Voyage started: %s (%.1f hours over %.0f seconds)" % [
				current_route.display_name,
				current_route.travel_duration_hours,
				VOYAGE_DURATION
			])
		else:
			push_warning("[BoatVoyage] No current route - scene may have loaded incorrectly")

	# Connect to player death signal for defeat handling
	if GameManager:
		if not GameManager.player_died.is_connected(_on_player_died):
			GameManager.player_died.connect(_on_player_died)

	# Store voyage start time for time tracking
	voyage_start_time = GameManager.game_time if GameManager else 8.0

	_setup_ocean_ambient()
	_setup_bay_environment()
	_setup_day_night_cycle()  # Add world time-synced lighting
	_setup_boat_rocking()  # Set up boat rocking motion
	_setup_debug_menu()

	# Spawn ambient circling ships for tension
	_spawn_ambient_ships()


## Ensure player exists in the scene - spawn if needed
func _ensure_player_exists() -> void:
	player = get_tree().get_first_node_in_group("player")

	if not player:
		# No player in scene - spawn one
		var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
		if player_scene:
			player = player_scene.instantiate()
			add_child(player)
			print("[BoatVoyage] Spawned player on deck")

			# Ensure HUD exists when spawning fresh player
			_ensure_hud_exists()
		else:
			push_error("[BoatVoyage] Failed to load player scene!")
			return

	# Position player on deck
	_position_player()


## Ensure HUD exists for player UI
func _ensure_hud_exists() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud:
		return  # HUD already exists

	# Try to load HUD scene
	var hud_scene_path := "res://scenes/ui/hud.tscn"
	if ResourceLoader.exists(hud_scene_path):
		var hud_scene: PackedScene = load(hud_scene_path)
		if hud_scene:
			var hud_instance: Node = hud_scene.instantiate()
			add_child(hud_instance)
			print("[BoatVoyage] Spawned HUD for player")


func _exit_tree() -> void:
	# Clear location name override when leaving boat voyage
	if PlayerGPS:
		PlayerGPS.location_name_override = ""

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
	voyage_started = false
	voyage_completing = false

	# Clean up enemy ship
	if enemy_ship_sprite and is_instance_valid(enemy_ship_sprite):
		enemy_ship_sprite.queue_free()
		enemy_ship_sprite = null

	# Clean up ambient ships
	for ship in ambient_ships:
		if is_instance_valid(ship):
			ship.queue_free()
	ambient_ships.clear()
	ambient_ship_angles.clear()

	# Clean up debug menu
	if debug_menu and is_instance_valid(debug_menu):
		debug_menu.queue_free()
		debug_menu = null

	# Clean up crew references (they'll be freed with the scene)
	helmsman = null
	deck_hand_1 = null
	deck_hand_2 = null

	# Clean up day/night cycle reference
	day_night_cycle = null


func _process(delta: float) -> void:
	# Update boat rocking motion for wave simulation
	_update_boat_rocking(delta)

	# Update water animation
	_update_water_animation(delta)

	# Update ocean color based on time of day
	_update_ocean_time_color(delta)

	# Update ambient circling ships
	if ambient_ships_active:
		_update_ambient_ships(delta)

	# Handle enemy ship approach animation
	if ship_approaching and enemy_ship_sprite:
		_update_ship_approach(delta)

	# Handle tentacle attack behavior
	if not active_tentacles.is_empty():
		_update_tentacle_attacks(delta)

	# Ghost pirate ambient growls during encounters
	if is_in_encounter and encounter_pending and encounter_pending.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		_update_ghost_growls(delta)

	# Sea monster ambient sounds during kraken encounters
	if is_in_encounter and encounter_pending and encounter_pending.encounter_type == SeaEncounter.EncounterType.SEA_MONSTER:
		_update_kraken_sounds(delta)

	# Simple voyage timer - 60 seconds unless in encounter
	if voyage_started and current_route and not is_in_encounter:
		voyage_timer += delta
		time_accumulated += delta

		# Progress world time continuously during voyage
		_update_world_time(delta)

		# Check for encounter trigger time
		if encounter_rolled and encounter_trigger_time > 0.0 and voyage_timer >= encounter_trigger_time:
			encounter_trigger_time = 0.0  # Only trigger once
			_trigger_scheduled_encounter()

		# Voyage complete
		if voyage_timer >= VOYAGE_DURATION:
			_complete_voyage()


## Update ship approach with two-phase behavior
## Phase 1 (0-50%): Head-on approach with FRONT sprite (bow facing player)
## Phase 2 (50-100%): Turn and travel parallel with SIDE sprite, rotated 90 degrees
func _update_ship_approach(delta: float) -> void:
	ship_approach_progress += delta * SHIP_APPROACH_SPEED / SHIP_START_DISTANCE
	ship_approach_progress = minf(ship_approach_progress, 1.0)

	var t: float = ship_approach_progress
	var base_height: float = enemy_ship_start_pos.y

	# Phase 1: Head-on approach (0% to 50%)
	# Phase 2: Turn and go parallel (50% to 100%)
	if t < 0.5:
		# Phase 1: Linear approach toward boat (front sprite, no rotation)
		var approach_t: float = t / 0.5  # 0 to 1 during phase 1
		# Approach from start to midpoint (in front of player boat, negative Z)
		var midpoint := Vector3(0, base_height, -SHIP_START_DISTANCE * 0.3)
		var pos: Vector3 = enemy_ship_start_pos.lerp(midpoint, approach_t)
		# Add wave bob effect
		pos.y = base_height + sin(voyage_timer * 2.0) * 0.5
		enemy_ship_sprite.global_position = pos
		enemy_ship_sprite.rotation_degrees.y = 0  # Facing us (bow forward)
	else:
		# Phase 2: Curve to parallel position
		var parallel_t: float = (t - 0.5) / 0.5  # 0 to 1 during phase 2

		# Switch to side sprite at start of phase 2
		if parallel_t < 0.1 and ship_approach_direction != 2:  # Not bow approach
			var side_sprite: String = enemy_ship_sprite.get_meta("docked_sprite", "")
			var current_path: String = enemy_ship_sprite.get_meta("current_sprite", "")
			if not side_sprite.is_empty() and side_sprite != current_path:
				var tex: Texture2D = load(side_sprite)
				if tex:
					enemy_ship_sprite.texture = tex
					enemy_ship_sprite.set_meta("current_sprite", side_sprite)
					# Rotate so bow points forward (direction of travel)
					match ship_approach_direction:
						0:  # Port dock - starboardside sprite - bow points right in sprite
							enemy_ship_sprite.rotation_degrees.y = 90.0   # +90 to face forward
						1:  # Starboard dock - portside sprite - bow points left in sprite
							enemy_ship_sprite.rotation_degrees.y = -90.0  # -90 to face forward

		# Curve from midpoint to final docking position
		var midpoint := Vector3(0, base_height, -SHIP_START_DISTANCE * 0.3)
		var pos: Vector3 = midpoint.lerp(enemy_ship_target_pos, parallel_t)
		# Add wave bob effect
		pos.y = base_height + sin(voyage_timer * 2.0) * 0.5
		enemy_ship_sprite.global_position = pos

	# Ship has arrived - spawn enemies with boarding animation
	if ship_approach_progress >= 1.0:
		ship_approaching = false
		_spawn_boarding_pirates()


## Update ghost pirate ambient growls - plays random eerie sounds during ghost encounters
func _update_ghost_growls(delta: float) -> void:
	ghost_growl_timer -= delta
	if ghost_growl_timer <= 0:
		# Reset timer with random interval
		ghost_growl_timer = randf_range(GHOST_GROWL_INTERVAL_MIN, GHOST_GROWL_INTERVAL_MAX)

		# Find a random ghost pirate to growl from
		var ghost_pirates: Array[Node] = get_tree().get_nodes_in_group("boat_enemies")
		if ghost_pirates.is_empty():
			return

		var growler: Node = ghost_pirates[randi() % ghost_pirates.size()]
		if not is_instance_valid(growler) or not growler is Node3D:
			return

		# Try to use the enemy's idle sounds if available (more thematic)
		if growler is EnemyBase and growler.enemy_data:
			var enemy: EnemyBase = growler as EnemyBase
			if not enemy.enemy_data.idle_sounds.is_empty():
				AudioManager.play_enemy_sound(enemy.enemy_data.idle_sounds, growler.global_position, -3.0)
				return

		# Fallback to generic growl sounds
		if AudioManager:
			var growl_sounds: Array[String] = [
				"res://assets/audio/sfx/monsters/low_growl.wav",
				"res://assets/audio/sfx/monsters/mid_growl.wav"
			]
			var sound_path: String = growl_sounds[randi() % growl_sounds.size()]
			AudioManager.play_sound_3d(sound_path, growler.global_position, -5.0)


## Update kraken/sea monster ambient sounds
func _update_kraken_sounds(delta: float) -> void:
	kraken_sound_timer -= delta
	if kraken_sound_timer <= 0:
		# Reset timer with random interval
		kraken_sound_timer = randf_range(KRAKEN_SOUND_INTERVAL_MIN, KRAKEN_SOUND_INTERVAL_MAX)

		# Find a random tentacle to make sound from
		if active_tentacles.is_empty():
			return

		var tentacle: EnemyBase = active_tentacles[randi() % active_tentacles.size()]
		if not is_instance_valid(tentacle):
			return

		# Use tentacle's idle sounds or fallback to deep growl
		if tentacle.enemy_data and not tentacle.enemy_data.idle_sounds.is_empty():
			AudioManager.play_enemy_sound(tentacle.enemy_data.idle_sounds, tentacle.global_position, 0.0)
		else:
			AudioManager.play_sound_3d("res://assets/audio/sfx/monsters/low_growl.wav", tentacle.global_position, -3.0)


func _input(event: InputEvent) -> void:
	# F4 toggles debug menu (F3 is used by global HUD debug overlay)
	if event is InputEventKey and event.pressed and event.keycode == KEY_F4:
		_toggle_debug_menu()
		get_viewport().set_input_as_handled()


func _position_player() -> void:
	# Position player at spawn point on deck
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if player and player_spawn:
		player.global_position = player_spawn.global_position
		player.rotation.y = player_spawn.rotation.y
		print("[BoatVoyage] Player positioned at spawn point: %s" % player_spawn.global_position)
	elif player:
		# Fallback position on deck - deck surface is at Y ~2.31
		player.global_position = Vector3(0, 2.31, 0)
		print("[BoatVoyage] Player positioned at fallback: (0, 2.31, 0)")


func _setup_ocean_ambient() -> void:
	# Disable fallback camera - player has their own camera for walkable deck
	var fallback_camera: Camera3D = get_node_or_null("FallbackCamera")
	if player and fallback_camera:
		fallback_camera.current = false
		print("[BoatVoyage] Disabled fallback camera - using player camera")
	elif fallback_camera:
		# No player - use fallback camera for testing
		fallback_camera.current = true
		print("[BoatVoyage] Using fallback camera (no player)")

	# Spawn crew NPCs using lightweight BoatCrewMember class
	_spawn_crew()


## Set up the bay environment with coastline panoramas on both sides
func _setup_bay_environment() -> void:
	# Create coastline sprites on port and starboard sides
	# These are distant backdrop sprites representing the bay coastline

	# Port side coastline (left, west)
	port_coastline = Sprite3D.new()
	port_coastline.name = "PortCoastline"
	port_coastline.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	port_coastline.pixel_size = 0.5
	port_coastline.modulate = Color(0.4, 0.5, 0.4, 0.8)  # Distant hazy green
	port_coastline.position = Vector3(-150, 5, 0)
	port_coastline.rotation_degrees.y = 90  # Face the boat
	add_child(port_coastline)

	# Starboard side coastline (right, east)
	starboard_coastline = Sprite3D.new()
	starboard_coastline.name = "StarboardCoastline"
	starboard_coastline.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	starboard_coastline.pixel_size = 0.5
	starboard_coastline.modulate = Color(0.4, 0.5, 0.4, 0.8)  # Distant hazy green
	starboard_coastline.position = Vector3(150, 5, 0)
	starboard_coastline.rotation_degrees.y = -90  # Face the boat
	add_child(starboard_coastline)

	# Try to load coastline texture if available
	var coastline_texture: Texture2D = null
	if ResourceLoader.exists("res://assets/textures/environment/coastline_silhouette.png"):
		coastline_texture = load("res://assets/textures/environment/coastline_silhouette.png")

	if coastline_texture:
		port_coastline.texture = coastline_texture
		starboard_coastline.texture = coastline_texture
	else:
		# Create a simple procedural coastline shape if no texture
		_create_procedural_coastline()

	# Always set up water waves shader for time-synced colors
	# (called in _create_procedural_coastline too, but ensure it runs regardless)
	_setup_water_waves()


## Create simple procedural coastline if no texture available
func _create_procedural_coastline() -> void:
	# Use a simple colored box mesh as distant land mass
	var coastline_mesh := BoxMesh.new()
	coastline_mesh.size = Vector3(300, 15, 5)

	var port_land := MeshInstance3D.new()
	port_land.name = "PortLand"
	port_land.mesh = coastline_mesh
	port_land.position = Vector3(-180, 3, 0)

	var port_material := StandardMaterial3D.new()
	port_material.albedo_color = Color(0.25, 0.35, 0.2, 1.0)  # Dark forest green
	port_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	port_land.material_override = port_material
	add_child(port_land)

	var starboard_land := MeshInstance3D.new()
	starboard_land.name = "StarboardLand"
	starboard_land.mesh = coastline_mesh
	starboard_land.position = Vector3(180, 3, 0)
	starboard_land.material_override = port_material
	add_child(starboard_land)

	# Remove the placeholder sprites since we're using meshes
	if port_coastline:
		port_coastline.queue_free()
		port_coastline = null
	if starboard_coastline:
		starboard_coastline.queue_free()
		starboard_coastline = null

	# Set up water animation with wave shader
	_setup_water_waves()


## Set up the boat model reference for rocking animation
func _setup_boat_rocking() -> void:
	boat_model = get_node_or_null("BoatModel")
	ocean_mesh = get_node_or_null("Ocean")

	# Create a pivot node for the entire boat to rock around
	if boat_model and not boat_pivot:
		boat_pivot = Node3D.new()
		boat_pivot.name = "BoatPivot"

		# Insert pivot between boat model and root
		var boat_parent: Node = boat_model.get_parent()
		var boat_transform: Transform3D = boat_model.transform
		boat_parent.remove_child(boat_model)
		boat_parent.add_child(boat_pivot)
		boat_pivot.add_child(boat_model)
		boat_model.transform = boat_transform


# =============================================================================
# DAY/NIGHT CYCLE INTEGRATION
# =============================================================================

## Set up the day/night cycle system for world time-synced lighting
func _setup_day_night_cycle() -> void:
	# DayNightCycle.add_to_level will remove any existing WorldEnvironment
	# and DirectionalLight3D, replacing them with dynamic time-synced versions
	day_night_cycle = DayNightCycle.add_to_level(self)
	if day_night_cycle:
		print("[BoatVoyage] Day/night cycle initialized - synced to world time (%.1f)" % GameManager.game_time)
	else:
		push_warning("[BoatVoyage] Failed to initialize day/night cycle")


## Update world time continuously during voyage
## This advances GameManager.game_time gradually instead of all at once at voyage end
func _update_world_time(delta: float) -> void:
	if not GameManager:
		return

	# Calculate how much time to advance this frame
	var time_advance: float = delta * time_per_second

	# Advance time (this handles day rollover and signals internally)
	# We use direct manipulation here to avoid emitting time_advanced signal repeatedly
	GameManager.game_time += time_advance

	# Handle day rollover
	if GameManager.game_time >= 24.0:
		GameManager.game_time -= 24.0
		GameManager.current_day += 1
		GameManager.day_changed.emit(GameManager.current_day)

	# Update time of day enum if it changed
	var new_time: Enums.TimeOfDay = _get_time_of_day_from_hour(GameManager.game_time)
	if new_time != GameManager.current_time_of_day:
		GameManager.current_time_of_day = new_time
		GameManager.time_of_day_changed.emit(new_time)
		print("[BoatVoyage] Time of day changed to: %s" % GameManager.get_time_of_day_name())


## Get time of day enum from hour (mirrors GameManager._get_time_of_day)
func _get_time_of_day_from_hour(hour: float) -> Enums.TimeOfDay:
	if hour >= 5.0 and hour < 7.0:
		return Enums.TimeOfDay.DAWN
	elif hour >= 7.0 and hour < 11.0:
		return Enums.TimeOfDay.MORNING
	elif hour >= 11.0 and hour < 14.0:
		return Enums.TimeOfDay.NOON
	elif hour >= 14.0 and hour < 18.0:
		return Enums.TimeOfDay.AFTERNOON
	elif hour >= 18.0 and hour < 21.0:
		return Enums.TimeOfDay.DUSK
	elif hour >= 21.0 or hour < 1.0:
		return Enums.TimeOfDay.NIGHT
	else:
		return Enums.TimeOfDay.MIDNIGHT


## Update ocean water color based on time of day for atmospheric effect
func _update_ocean_time_color(_delta: float) -> void:
	if not ocean_mesh or not ocean_mesh.material is ShaderMaterial:
		return

	var mat: ShaderMaterial = ocean_mesh.material
	var current_hour: float = GameManager.game_time if GameManager else 12.0

	# Calculate target ocean color based on time of day
	var target_color: Color = _get_ocean_color_for_time(current_hour)

	# Smoothly interpolate water color
	var current_color: Color = mat.get_shader_parameter("water_color")
	var new_color: Color = current_color.lerp(target_color, _delta * 2.0)
	mat.set_shader_parameter("water_color", new_color)


## Get ocean color based on the current hour (0-24)
func _get_ocean_color_for_time(hour: float) -> Color:
	# Night: 21-5
	if hour >= 21.0 or hour < 5.0:
		return OCEAN_NIGHT_COLOR
	# Dawn: 5-7
	elif hour >= 5.0 and hour < 7.0:
		var t: float = (hour - 5.0) / 2.0
		return OCEAN_NIGHT_COLOR.lerp(OCEAN_DAWN_COLOR, t)
	# Morning: 7-10
	elif hour >= 7.0 and hour < 10.0:
		var t: float = (hour - 7.0) / 3.0
		return OCEAN_DAWN_COLOR.lerp(OCEAN_DAY_COLOR, t)
	# Day: 10-17
	elif hour >= 10.0 and hour < 17.0:
		return OCEAN_DAY_COLOR
	# Dusk: 17-21
	elif hour >= 17.0 and hour < 21.0:
		var t: float = (hour - 17.0) / 4.0
		return OCEAN_DAY_COLOR.lerp(OCEAN_DUSK_COLOR, t).lerp(OCEAN_NIGHT_COLOR, t * 0.5)
	# Default day
	return OCEAN_DAY_COLOR


## Update boat rocking motion - simulates waves
func _update_boat_rocking(_delta: float) -> void:
	if not boat_model:
		boat_model = get_node_or_null("BoatModel")
		if not boat_model:
			return

	# Calculate wave-based rotation using sine waves at different frequencies
	var time: float = voyage_timer
	var roll: float = sin(time * BOAT_ROLL_SPEED) * BOAT_ROLL_AMOUNT
	var pitch: float = sin(time * BOAT_PITCH_SPEED + 0.5) * BOAT_PITCH_AMOUNT
	var yaw: float = sin(time * BOAT_YAW_SPEED + 1.0) * BOAT_YAW_AMOUNT

	# Apply rotation to boat model
	boat_model.rotation_degrees.x = pitch
	boat_model.rotation_degrees.z = roll

	# Subtle vertical bob
	var bob: float = sin(time * 1.2) * 0.15
	var base_y: float = 0.0  # Original Y position
	boat_model.position.y = base_y + bob

	# Also rock the deck collision if it exists
	var deck_collision: Node3D = get_node_or_null("DeckCollision")
	if deck_collision:
		deck_collision.rotation_degrees.x = pitch * 0.5
		deck_collision.rotation_degrees.z = roll * 0.5


## Set up water with wave shader for ripple effect
func _setup_water_waves() -> void:
	ocean_mesh = get_node_or_null("Ocean")
	if not ocean_mesh:
		return

	# Create shader material for animated water waves
	var water_shader := Shader.new()
	water_shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.08, 0.18, 0.32, 1.0);
uniform vec4 foam_color : source_color = vec4(0.6, 0.7, 0.8, 0.8);
uniform float wave_speed : hint_range(0.1, 5.0) = 1.0;
uniform float wave_height : hint_range(0.0, 2.0) = 0.3;
uniform float wave_frequency : hint_range(0.1, 10.0) = 2.0;
uniform float foam_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float time_offset = 0.0;

varying float wave_factor;

void vertex() {
	// Create wave displacement using multiple sine waves
	float t = TIME * wave_speed + time_offset;
	float wave1 = sin(VERTEX.x * wave_frequency + t) * wave_height;
	float wave2 = sin(VERTEX.z * wave_frequency * 0.7 + t * 1.3) * wave_height * 0.5;
	float wave3 = sin((VERTEX.x + VERTEX.z) * wave_frequency * 0.5 + t * 0.8) * wave_height * 0.3;

	VERTEX.y += wave1 + wave2 + wave3;

	// Store wave height for foam calculation
	wave_factor = (wave1 + wave2 + wave3) / wave_height;
}

void fragment() {
	// Base water color with foam on wave peaks
	float foam = smoothstep(foam_threshold, 1.0, wave_factor);
	vec3 color = mix(water_color.rgb, foam_color.rgb, foam * 0.4);

	ALBEDO = color;
	ROUGHNESS = 0.2 - foam * 0.1;
	METALLIC = 0.1;

	// Slight transparency for depth effect
	ALPHA = water_color.a;
}
"""

	var water_material := ShaderMaterial.new()
	water_material.shader = water_shader
	water_material.set_shader_parameter("water_color", Color(0.08, 0.18, 0.32, 0.95))
	water_material.set_shader_parameter("foam_color", Color(0.5, 0.6, 0.7, 0.8))
	water_material.set_shader_parameter("wave_speed", 1.2)
	water_material.set_shader_parameter("wave_height", 0.4)
	water_material.set_shader_parameter("wave_frequency", 0.15)  # Low frequency for ocean swells
	water_material.set_shader_parameter("foam_threshold", 0.6)

	ocean_mesh.material = water_material
	print("[BoatVoyage] Water wave shader applied")


## Update water animation
func _update_water_animation(_delta: float) -> void:
	# The shader handles animation via TIME uniform, but we can update offset for variety
	if ocean_mesh and ocean_mesh.material is ShaderMaterial:
		var mat: ShaderMaterial = ocean_mesh.material
		mat.set_shader_parameter("time_offset", voyage_timer * 0.1)


## Roll for encounter at voyage start
func _roll_for_encounter() -> void:
	encounter_rolled = true
	var roll: float = randf()

	if roll < ENCOUNTER_CHANCE:
		# Encounter will happen - determine type and timing
		var type_roll: float = randf()
		var encounter := SeaEncounter.new()

		if type_roll < SEA_MONSTER_CHANCE:
			encounter.id = "voyage_sea_monster"
			encounter.display_name = "Sea Monster"
			encounter.encounter_type = SeaEncounter.EncounterType.SEA_MONSTER
			encounter.xp_reward = 200
			encounter.gold_reward = Vector2i(0, 0)
		elif type_roll < SEA_MONSTER_CHANCE + GHOST_PIRATE_CHANCE:
			encounter.id = "voyage_ghost_pirates"
			encounter.display_name = "Ghost Ship"
			encounter.encounter_type = SeaEncounter.EncounterType.GHOST_PIRATE
			encounter.xp_reward = 150
			encounter.gold_reward = Vector2i(50, 120)
		else:
			encounter.id = "voyage_pirates"
			encounter.display_name = "Pirate Attack"
			encounter.encounter_type = SeaEncounter.EncounterType.PIRATE
			encounter.xp_reward = 100
			encounter.gold_reward = Vector2i(30, 80)

		encounter_pending = encounter
		# Trigger encounter between 15-45 seconds into voyage
		encounter_trigger_time = randf_range(15.0, 45.0)
		print("[BoatVoyage] Encounter scheduled: %s at %.1fs" % [encounter.display_name, encounter_trigger_time])
	else:
		print("[BoatVoyage] Safe voyage - no encounter")


## Trigger the scheduled encounter
func _trigger_scheduled_encounter() -> void:
	if not encounter_pending:
		return
	_start_encounter(encounter_pending)


## Spawn crew NPCs - helmsman and two deck hands
## Uses varied sprites for visual diversity
func _spawn_crew() -> void:
	# Use scene markers if available, otherwise use defaults
	var crew_spawns: Node3D = get_node_or_null("CrewSpawns")

	# Deck surface is at Y ~2.31 (collision Y 2.21 + offset + half-height)
	const DECK_SPAWN_Y := 2.31
	var helm_pos := Vector3(0, DECK_SPAWN_Y, -6)
	var deck1_pos := Vector3(-2, DECK_SPAWN_Y, 2)
	var deck2_pos := Vector3(2, DECK_SPAWN_Y, 0)

	if crew_spawns:
		var helm_marker: Marker3D = crew_spawns.get_node_or_null("HelmsmanSpawn")
		var deck1_marker: Marker3D = crew_spawns.get_node_or_null("DeckHand1Spawn")
		var deck2_marker: Marker3D = crew_spawns.get_node_or_null("DeckHand2Spawn")
		if helm_marker:
			helm_pos = helm_marker.global_position
		if deck1_marker:
			deck1_pos = deck1_marker.global_position
		if deck2_marker:
			deck2_pos = deck2_marker.global_position

	# Spawn helmsman at the stern (steering position) - stays at wheel
	# Use guard sprite for capable look
	helmsman = _spawn_crew_member(helm_pos, "Ship's Helmsman", false, "res://assets/sprites/npcs/civilians/guard_civilian.png")
	if helmsman:
		helmsman.name = "Helmsman"
		helmsman.rotation_degrees.y = 180  # Face forward (toward bow)
		helmsman.set_meta("is_crew", true)

	# Spawn two deck hands who patrol the deck - use varied sprites
	deck_hand_1 = _spawn_crew_member(deck1_pos, "Deck Hand", true, "res://assets/sprites/npcs/combat/bandit_3.png")
	if deck_hand_1:
		deck_hand_1.name = "DeckHand1"
		deck_hand_1.wander_radius = 4.0
		deck_hand_1.set_meta("is_crew", true)
		deck_hand_1.set_meta("helps_fight", true)

	deck_hand_2 = _spawn_crew_member(deck2_pos, "Deck Hand", true, "res://assets/sprites/npcs/civilians/guy_civilian1.png")
	if deck_hand_2:
		deck_hand_2.name = "DeckHand2"
		deck_hand_2.wander_radius = 4.0
		deck_hand_2.set_meta("is_crew", true)
		deck_hand_2.set_meta("helps_fight", true)

	print("[BoatVoyage] Spawned crew: Helmsman + 2 Deck Hands")


## Spawn a crew member with custom sprite
func _spawn_crew_member(pos: Vector3, crew_name: String, wandering: bool, sprite_path: String) -> BoatCrewMember:
	var crew := BoatCrewMember.new()
	crew.display_name = crew_name
	crew.enable_wandering = wandering

	# Override sprite path before adding to scene
	crew.set_meta("custom_sprite", sprite_path)

	# Add to scene first, then set position
	add_child(crew)
	crew.global_position = pos

	# Apply custom sprite after adding to scene
	if crew.billboard and ResourceLoader.exists(sprite_path):
		var texture: Texture2D = load(sprite_path)
		if texture:
			crew.billboard.sprite_sheet = texture
			if crew.billboard.sprite:
				crew.billboard.sprite.texture = texture

	return crew


# =============================================================================
# AMBIENT CIRCLING SHIPS (Shark-like behavior)
# =============================================================================

## Spawn ambient ships that circle on the horizon for tension
func _spawn_ambient_ships() -> void:
	for i in range(AMBIENT_SHIP_COUNT):
		var ship := Sprite3D.new()
		ship.name = "AmbientShip%d" % i

		# Load ship texture - will be updated based on position
		var ship_texture: Texture2D = load(PIRATE_SHIP_PORTSIDE)
		if ship_texture:
			ship.texture = ship_texture

		ship.pixel_size = 0.06 * PIRATE_SHIP_SCALE  # Bigger ships
		ship.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		ship.modulate = Color(0.7, 0.7, 0.7, 0.9)  # Slightly faded/distant

		# Start at random angles around the horizon
		var angle: float = randf() * TAU
		ambient_ship_angles.append(angle)

		# Position ships above water (Y = 20.0 base height for tall ship sprites)
		var pos := Vector3(
			cos(angle) * CIRCLE_RADIUS,
			20.0 + sin(voyage_timer * 1.5) * 1.5,  # Base height + wave bob
			sin(angle) * CIRCLE_RADIUS
		)

		# Add to scene first, then set position
		add_child(ship)
		ship.global_position = pos
		ambient_ships.append(ship)

		# Set initial sprite based on position
		_update_ship_sprite_direction(ship, pos)

	ambient_ships_active = true
	print("[BoatVoyage] Spawned %d ambient ships circling on horizon" % AMBIENT_SHIP_COUNT)


## Update ambient ships - slow circling motion
func _update_ambient_ships(delta: float) -> void:
	for i in range(ambient_ships.size()):
		if not is_instance_valid(ambient_ships[i]):
			continue

		var ship: Sprite3D = ambient_ships[i]

		# Update angle for orbit
		ambient_ship_angles[i] += CIRCLE_SPEED * delta
		var angle: float = ambient_ship_angles[i]

		# Calculate position on circle with wave bob - ships at Y=20.0 base height
		var pos := Vector3(
			cos(angle) * CIRCLE_RADIUS,
			20.0 + sin(voyage_timer * 1.5 + float(i)) * 1.5,  # Base height + wave bob
			sin(angle) * CIRCLE_RADIUS
		)
		ship.global_position = pos

		# Update sprite direction based on position
		_update_ship_sprite_direction(ship, pos)


## Update ship sprite to face correctly based on position relative to player boat
func _update_ship_sprite_direction(ship: Sprite3D, pos: Vector3) -> void:
	# Determine which sprite to use based on ship position relative to boat (at origin)
	# Ships circling should show their side facing the boat
	var ship_texture_path: String

	# Calculate the tangent direction (perpendicular to radius = direction ship is moving)
	# Ship is at pos, moving counter-clockwise around origin
	# If ship is on east side (pos.x > 0), it's moving south (showing port side to boat)
	# If ship is on west side (pos.x < 0), it's moving north (showing starboard side to boat)
	# If ship is in front (pos.z > 50), show front
	# If ship is behind (pos.z < -50), show front (coming toward)

	if pos.z > abs(pos.x) * 0.8:  # In front of boat (bow direction)
		ship_texture_path = PIRATE_SHIP_FRONT
	elif pos.z < -abs(pos.x) * 0.8:  # Behind boat (stern direction)
		ship_texture_path = PIRATE_SHIP_FRONT
	elif pos.x > 0:  # East/starboard side - ship moving south, shows port side to boat
		ship_texture_path = PIRATE_SHIP_PORTSIDE
	else:  # West/port side - ship moving north, shows starboard side to boat
		ship_texture_path = PIRATE_SHIP_STARBOARDSIDE

	# Update texture if changed
	var current_path: String = ship.get_meta("texture_path", "")
	if current_path != ship_texture_path:
		var tex: Texture2D = load(ship_texture_path)
		if tex:
			ship.texture = tex
			ship.set_meta("texture_path", ship_texture_path)


## One ambient ship breaks off to attack
## Converts an ambient circling ship into an approaching enemy with proper sprite transitions
func _convert_ambient_ship_to_attacker() -> void:
	if ambient_ships.is_empty():
		return

	# Pick a random ambient ship to become the attacker
	var index: int = randi() % ambient_ships.size()
	var attacking_ship: Sprite3D = ambient_ships[index]

	if not is_instance_valid(attacking_ship):
		return

	# Remove from ambient tracking
	ambient_ships.remove_at(index)
	ambient_ship_angles.remove_at(index)

	# Set up as the main enemy ship
	enemy_ship_sprite = attacking_ship
	enemy_ship_sprite.modulate = Color(1, 1, 1, 1)  # Full visibility now

	# Determine approach direction based on current position
	# Use negative Z so ship approaches from in front of player boat
	var final_side_sprite: String
	if attacking_ship.global_position.x < -20:
		ship_approach_direction = 0  # Will dock on port
		enemy_ship_target_pos = Vector3(-SHIP_APPROACH_DISTANCE, SHIP_DOCKED_HEIGHT, 0)
		final_side_sprite = PIRATE_SHIP_STARBOARDSIDE  # We'll see their starboard side
	elif attacking_ship.global_position.x > 20:
		ship_approach_direction = 1  # Will dock on starboard
		enemy_ship_target_pos = Vector3(SHIP_APPROACH_DISTANCE, SHIP_DOCKED_HEIGHT, 0)
		final_side_sprite = PIRATE_SHIP_PORTSIDE  # We'll see their port side
	else:
		ship_approach_direction = 2  # Bow approach
		enemy_ship_target_pos = Vector3(0, SHIP_DOCKED_HEIGHT, -SHIP_APPROACH_DISTANCE)
		final_side_sprite = PIRATE_SHIP_FRONT

	# Move ship to start position (in front of player for head-on approach)
	# Negative Z = in front of player, visible during approach
	enemy_ship_start_pos = Vector3(0, SHIP_DOCKED_HEIGHT, -SHIP_START_DISTANCE)
	enemy_ship_sprite.global_position = enemy_ship_start_pos

	# Switch to FRONT sprite for head-on approach
	var front_texture: Texture2D = load(PIRATE_SHIP_FRONT)
	if front_texture:
		enemy_ship_sprite.texture = front_texture
	enemy_ship_sprite.rotation_degrees.y = 0  # Face the player

	# Store metadata for phase 2 transition
	enemy_ship_sprite.set_meta("docked_sprite", final_side_sprite)
	enemy_ship_sprite.set_meta("current_sprite", PIRATE_SHIP_FRONT)
	enemy_ship_sprite.set_meta("approach_direction", ship_approach_direction)

	ship_approach_progress = 0.0
	ship_approaching = true

	print("[BoatVoyage] Ambient ship breaks orbit - approaching head-on, will dock on %s!" % ["port", "starboard", "bow"][ship_approach_direction])


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

	# Separator for time controls
	var sep3 := HSeparator.new()
	vbox.add_child(sep3)

	# Time buttons
	_add_debug_button(vbox, "Set Time: Dawn (6:00)", _debug_set_dawn)
	_add_debug_button(vbox, "Set Time: Night (22:00)", _debug_set_night)

	# Close hint
	var hint := Label.new()
	hint.text = "[F4] Close"
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

	_start_encounter(encounter)
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

	_start_encounter(encounter)
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

	_start_encounter(encounter)
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

	_start_encounter(encounter)
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


func _debug_set_dawn() -> void:
	_toggle_debug_menu()
	print("[BoatVoyage] DEBUG: Setting time to Dawn (6:00)")
	if GameManager:
		GameManager.set_time(6.0)


func _debug_set_night() -> void:
	_toggle_debug_menu()
	print("[BoatVoyage] DEBUG: Setting time to Night (22:00)")
	if GameManager:
		GameManager.set_time(22.0)


## Called when crew should help fight enemies
func _crew_engage_enemies() -> void:
	crew_fighting = true

	# Tell all crew members to enter combat mode
	for crew_member in [helmsman, deck_hand_1, deck_hand_2]:
		if crew_member and is_instance_valid(crew_member) and crew_member is BoatCrewMember:
			crew_member.enter_combat()


## Called when encounter ends to return crew to normal
func _crew_stop_fighting() -> void:
	crew_fighting = false

	# Tell all crew members to exit combat mode
	for crew_member in [helmsman, deck_hand_1, deck_hand_2]:
		if crew_member and is_instance_valid(crew_member) and crew_member is BoatCrewMember:
			crew_member.exit_combat()


func _start_encounter(encounter: SeaEncounter) -> void:
	encounter_pending = encounter
	is_in_encounter = true

	# Initialize growl timer for ghost pirates
	if encounter.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		ghost_growl_timer = randf_range(1.0, 2.0)  # First growl comes quickly

	# Initialize kraken sound timer for sea monsters
	if encounter.encounter_type == SeaEncounter.EncounterType.SEA_MONSTER:
		kraken_sound_timer = randf_range(1.0, 2.0)  # First sound comes quickly

	print("[BoatVoyage] DANGER! Encounter incoming: %s" % encounter.display_name)

	# Alert crew
	_crew_engage_enemies()

	# For pirate/ghost ship encounters, have an ambient ship attack or spawn new one
	if encounter.encounter_type == SeaEncounter.EncounterType.PIRATE or \
	   encounter.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		if not ambient_ships.is_empty():
			_convert_ambient_ship_to_attacker()
		else:
			_spawn_approaching_enemy_ship(encounter)
	elif encounter.encounter_type == SeaEncounter.EncounterType.SEA_MONSTER:
		# Sea monster - start the kraken sequence
		_start_kraken_attack()
	elif encounter.encounter_type == SeaEncounter.EncounterType.STORM:
		_handle_storm()


## Spawn an enemy ship sprite that approaches from the distance
## ALL ships start with FRONT sprite (head-on approach), then switch to SIDE sprite when parallel
func _spawn_approaching_enemy_ship(encounter: SeaEncounter) -> void:
	# Choose random approach direction (port, starboard, or bow)
	ship_approach_direction = randi() % 3  # 0=port, 1=starboard, 2=bow

	# Determine final docking position and the side sprite to use when parallel
	# Use negative Z so ship approaches from in front of player boat
	var final_side_sprite: String
	match ship_approach_direction:
		0:  # Will dock on port (left) - we'll see their starboard side
			enemy_ship_target_pos = Vector3(-SHIP_APPROACH_DISTANCE, SHIP_DOCKED_HEIGHT, 0)
			final_side_sprite = PIRATE_SHIP_STARBOARDSIDE
		1:  # Will dock on starboard (right) - we'll see their port side
			enemy_ship_target_pos = Vector3(SHIP_APPROACH_DISTANCE, SHIP_DOCKED_HEIGHT, 0)
			final_side_sprite = PIRATE_SHIP_PORTSIDE
		_:  # Bow approach - stays front the whole time
			enemy_ship_target_pos = Vector3(0, SHIP_DOCKED_HEIGHT, -SHIP_APPROACH_DISTANCE)
			final_side_sprite = PIRATE_SHIP_FRONT

	# ALL ships START with front sprite (approaching head-on from in front of player boat)
	# Negative Z = in front of player, visible during approach
	enemy_ship_start_pos = Vector3(0, SHIP_DOCKED_HEIGHT, -SHIP_START_DISTANCE)
	var initial_sprite_path: String = PIRATE_SHIP_FRONT

	# Load and create the ship sprite with FRONT sprite for approach
	var ship_texture: Texture2D = load(initial_sprite_path)
	if not ship_texture:
		push_warning("[BoatVoyage] Failed to load ship texture: %s" % initial_sprite_path)
		# Spawn enemies immediately if we can't show ship
		_spawn_boarding_pirates()
		return

	enemy_ship_sprite = Sprite3D.new()
	enemy_ship_sprite.name = "EnemyShip"
	enemy_ship_sprite.texture = ship_texture
	enemy_ship_sprite.pixel_size = 0.06 * PIRATE_SHIP_SCALE  # BIGGER ships
	enemy_ship_sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	enemy_ship_sprite.global_position = enemy_ship_start_pos

	# Tint ghost ships with an eerie glow
	if encounter.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE:
		enemy_ship_sprite.modulate = Color(0.6, 0.8, 1.0, 0.85)  # Ghostly blue tint

	# Store metadata for phase 2 transition
	enemy_ship_sprite.set_meta("docked_sprite", final_side_sprite)
	enemy_ship_sprite.set_meta("current_sprite", initial_sprite_path)
	enemy_ship_sprite.set_meta("approach_direction", ship_approach_direction)

	add_child(enemy_ship_sprite)

	# Start the approach animation
	ship_approach_progress = 0.0
	ship_approaching = true

	print("[BoatVoyage] Enemy ship spawned with FRONT sprite, will dock on %s" % ["port", "starboard", "bow"][ship_approach_direction])


## Spawn pirates with boarding arc animation
func _spawn_boarding_pirates() -> void:
	if not encounter_pending:
		return

	print("[BoatVoyage] Pirates boarding the ship!")

	# Calculate pirate count based on player level
	var pirate_count: int = _calculate_pirate_count()
	var spawn_positions: Array[Vector3] = _get_deck_spawn_positions(pirate_count)
	var has_captain: bool = randf() < 0.4  # 40% chance for a captain

	# Determine ship position for boarding arc - deck surface is at Y ~2.31
	const DECK_SPAWN_Y := 2.31
	var ship_pos: Vector3 = enemy_ship_target_pos if enemy_ship_sprite else Vector3(-SHIP_APPROACH_DISTANCE, DECK_SPAWN_Y, 0)

	# Track spawned enemies for target assignment
	var spawned_enemies: Array[EnemyBase] = []

	# Spawn pirates with staggered boarding animation
	for i in range(pirate_count):
		var deck_pos: Vector3 = spawn_positions[i] if i < spawn_positions.size() else Vector3(randf_range(-3, 3), DECK_SPAWN_Y, randf_range(-2, 2))
		# Add random offset to prevent stacking
		deck_pos.x += randf_range(-0.5, 0.5)
		deck_pos.z += randf_range(-0.5, 0.5)

		# Determine enemy type
		var enemy_data_path: String
		var display_name: String
		var is_ghost: bool = encounter_pending.encounter_type == SeaEncounter.EncounterType.GHOST_PIRATE

		if i == 0 and has_captain:
			enemy_data_path = "res://data/enemies/ghost_pirate_captain.tres" if is_ghost else "res://data/enemies/pirate_captain.tres"
			display_name = "Ghost Captain" if is_ghost else "Pirate Captain"
		else:
			enemy_data_path = "res://data/enemies/ghost_pirate_seadog.tres" if is_ghost else "res://data/enemies/pirate_seadog.tres"
			display_name = "Ghost Pirate" if is_ghost else "Pirate Seadog"

		# Spawn with boarding arc animation (staggered)
		var delay: float = float(i) * BOARDING_STAGGER
		var enemy: EnemyBase = await _spawn_boarding_pirate_async(enemy_data_path, ship_pos, deck_pos, display_name, delay)
		if enemy:
			spawned_enemies.append(enemy)

	# Wait for all boarding animations to complete
	await get_tree().create_timer(BOARDING_DURATION + 0.5).timeout

	# Crew enters combat to help fight
	_crew_engage_enemies()

	# Assign some pirates to target crew members (makes fight feel larger)
	_assign_pirate_targets(spawned_enemies)

	_setup_encounter_tracking()


## Calculate pirate count based on player level
func _calculate_pirate_count() -> int:
	var player_level: int = 1
	if GameManager and GameManager.player_data:
		player_level = GameManager.player_data.level

	# Formula: base + level/10, with random variance
	var count: int = PIRATES_BASE_COUNT + (player_level / 10)
	count += randi_range(-1, 1)  # Small variance
	count = clampi(count, 2, PIRATES_MAX)

	print("[BoatVoyage] Spawning %d pirates (player level %d)" % [count, player_level])
	return count


## Spawn a single pirate with boarding arc animation (async, returns enemy)
func _spawn_boarding_pirate_async(enemy_data_path: String, start_pos: Vector3, end_pos: Vector3, display_name: String, delay: float) -> EnemyBase:
	await get_tree().create_timer(delay).timeout

	# Check if enemy data exists
	if not ResourceLoader.exists(enemy_data_path):
		push_warning("[BoatVoyage] Enemy data not found: %s" % enemy_data_path)
		return null

	var enemy_data: EnemyData = load(enemy_data_path)
	if not enemy_data:
		return null

	# Get sprite texture
	var sprite_path: String = enemy_data.sprite_path if enemy_data.sprite_path else "res://assets/sprites/enemies/humanoid/pirate_seadog.png"
	var sprite_texture: Texture2D = load(sprite_path) if ResourceLoader.exists(sprite_path) else null

	if not sprite_texture:
		push_warning("[BoatVoyage] Sprite not found: %s" % sprite_path)
		return null

	# Spawn enemy at start position (on the ship)
	var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
		self,
		start_pos,
		enemy_data_path,
		sprite_texture,
		enemy_data.sprite_hframes,
		enemy_data.sprite_vframes
	)

	if enemy:
		enemy.add_to_group("boat_enemies")
		enemy.add_to_group("enemies")

		# Animate the boarding arc
		_animate_boarding_arc(enemy, start_pos, end_pos)

		print("[BoatVoyage] %s boards the ship!" % display_name)

	return enemy


## Assign pirate targets - some attack player, some attack crew for a larger battle feel
func _assign_pirate_targets(enemies: Array[EnemyBase]) -> void:
	if enemies.is_empty():
		return

	# Get available crew targets
	var crew_targets: Array[Node3D] = []
	for crew_member in [helmsman, deck_hand_1, deck_hand_2]:
		if crew_member and is_instance_valid(crew_member) and crew_member is BoatCrewMember:
			if not crew_member.is_dead:
				crew_targets.append(crew_member)

	if crew_targets.is_empty():
		print("[BoatVoyage] No crew available to fight - all pirates target player")
		return

	# Assign ~40% of pirates to target crew members (captain always targets player)
	var crew_assigned: int = 0
	for i in range(enemies.size()):
		var enemy: EnemyBase = enemies[i]
		if not is_instance_valid(enemy):
			continue

		# Captain (first enemy) always targets player
		if i == 0:
			continue

		# 40% chance to target a crew member instead of player
		if randf() < 0.4 and not crew_targets.is_empty():
			var target: Node3D = crew_targets[randi() % crew_targets.size()]
			enemy.set_meta("forced_target", target)
			enemy.set_meta("targets_crew", true)
			crew_assigned += 1
			print("[BoatVoyage] Pirate %d assigned to attack %s" % [i, target.display_name if target.has_method("get") else "crew"])

	print("[BoatVoyage] Target assignment: %d pirates attack crew, %d attack player" % [crew_assigned, enemies.size() - crew_assigned])


## Animate enemy flying through arc from ship to deck
func _animate_boarding_arc(enemy: Node3D, start_pos: Vector3, end_pos: Vector3) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)

	# Create arc path using custom method
	var mid_point := (start_pos + end_pos) / 2.0
	mid_point.y += BOARDING_ARC_HEIGHT  # Arc up through the air

	# Animate through arc
	tween.tween_method(
		func(t: float) -> void:
			if is_instance_valid(enemy):
				enemy.global_position = _quadratic_bezier(start_pos, mid_point, end_pos, t),
		0.0,
		1.0,
		BOARDING_DURATION
	)


## Quadratic bezier for smooth arc
func _quadratic_bezier(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var q0: Vector3 = p0.lerp(p1, t)
	var q1: Vector3 = p1.lerp(p2, t)
	return q0.lerp(q1, t)


# =============================================================================
# KRAKEN/SEA MONSTER ENCOUNTER
# =============================================================================

## Start the kraken attack sequence with pre-attack warning
func _start_kraken_attack() -> void:
	print("[BoatVoyage] THE KRAKEN AWAKENS!")

	# Pre-attack warning effects
	_kraken_rumble_effect()

	# Wait for rumble, then spawn tentacles
	await get_tree().create_timer(1.5).timeout
	_spawn_sea_creature()


## Pre-attack rumble effect (camera shake + audio hook)
func _kraken_rumble_effect() -> void:
	# Camera shake via player camera if available
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera:
		_shake_camera(camera, 0.3, 1.5)

	# Audio hook for kraken rumble
	if AudioManager:
		AudioManager.play_sfx("kraken_rumble")

	# Show warning notification
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("The water churns ominously...")


## Camera shake effect
func _shake_camera(camera: Camera3D, intensity: float, duration: float) -> void:
	var original_pos: Vector3 = camera.position
	var tween := create_tween()

	var shake_count: int = int(duration * 20)
	for i in range(shake_count):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		tween.tween_property(camera, "position", original_pos + offset, 0.05)

	tween.tween_property(camera, "position", original_pos, 0.1)


func _spawn_sea_creature() -> void:
	# Spawn 2-4 tentacles reaching up from the WATER around the boat
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

	active_tentacles.clear()
	tentacle_attack_timers.clear()

	for i in range(mini(tentacle_count, tentacle_positions.size())):
		var pos: Vector3 = tentacle_positions[i]
		var sprite_path: String = tentacle_sprites[randi() % tentacle_sprites.size()]
		_spawn_tentacle_with_rise_animation(pos, sprite_path, i)

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
		positions = [
			Vector3(-9, TENTACLE_START_Y, 4),
			Vector3(9, TENTACLE_START_Y, 4),
			Vector3(-9, TENTACLE_START_Y, -3),
			Vector3(9, TENTACLE_START_Y, -3),
			Vector3(-8, TENTACLE_START_Y, 0),
			Vector3(8, TENTACLE_START_Y, 0),
			Vector3(0, TENTACLE_START_Y, 14),
		]

	return positions


## Spawn a tentacle with dramatic rise animation
func _spawn_tentacle_with_rise_animation(pos: Vector3, sprite_path: String, index: int) -> void:
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

	# Start position underwater
	var start_pos := Vector3(pos.x, TENTACLE_START_Y, pos.z)

	var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
		self,
		start_pos,
		enemy_data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		enemy.add_to_group("boat_enemies")
		enemy.add_to_group("enemies")
		enemy.add_to_group("tentacles")

		# Start small, will scale up during rise
		if enemy.has_node("BillboardSprite"):
			var billboard: Node3D = enemy.get_node("BillboardSprite")
			billboard.scale = Vector3(TENTACLE_START_SCALE, TENTACLE_START_SCALE, TENTACLE_START_SCALE)

		# Mark tentacle as stationary
		enemy.set_meta("stationary", true)
		enemy.set_meta("water_enemy", true)

		# Track for attack behavior
		active_tentacles.append(enemy)
		tentacle_attack_timers[enemy.get_instance_id()] = randf_range(1.0, 3.0)  # Stagger initial attacks

		# Animate the rise
		_animate_tentacle_rise(enemy, index)

		print("[BoatVoyage] Spawned Tentacle %d at %s (rising from water)" % [index + 1, start_pos])


## Animate tentacle rising from the water
func _animate_tentacle_rise(enemy: EnemyBase, index: int) -> void:
	var tween := create_tween()
	tween.set_parallel(true)

	# Rise from water
	var end_y: float = TENTACLE_END_Y
	tween.tween_property(enemy, "global_position:y", end_y, TENTACLE_RISE_DURATION).set_delay(float(index) * 0.3)

	# Scale up dramatically
	if enemy.has_node("BillboardSprite"):
		var billboard: Node3D = enemy.get_node("BillboardSprite")
		var end_scale := Vector3(TENTACLE_END_SCALE, TENTACLE_END_SCALE, TENTACLE_END_SCALE)
		tween.tween_property(billboard, "scale", end_scale, TENTACLE_RISE_DURATION).set_delay(float(index) * 0.3)


## Update tentacle attack behavior
func _update_tentacle_attacks(delta: float) -> void:
	# Clean up dead tentacles
	var valid_tentacles: Array[EnemyBase] = []
	for tent in active_tentacles:
		if is_instance_valid(tent) and not tent.is_dead():
			valid_tentacles.append(tent)
	active_tentacles = valid_tentacles

	if active_tentacles.is_empty():
		return

	# Find player
	if not player or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if not player:
			return

	# Update attack timers and execute attacks
	for tentacle in active_tentacles:
		var id: int = tentacle.get_instance_id()
		if not tentacle_attack_timers.has(id):
			tentacle_attack_timers[id] = TENTACLE_ATTACK_COOLDOWN

		tentacle_attack_timers[id] -= delta

		if tentacle_attack_timers[id] <= 0:
			# Choose attack pattern: 60% sweep, 40% targeted lunge
			if randf() < 0.6:
				_tentacle_sweep_attack(tentacle)
			else:
				_tentacle_lunge_attack(tentacle)

			tentacle_attack_timers[id] = TENTACLE_ATTACK_COOLDOWN + randf_range(-0.5, 0.5)


## Tentacle sweep attack - wide area
func _tentacle_sweep_attack(tentacle: EnemyBase) -> void:
	if not is_instance_valid(tentacle):
		return

	print("[BoatVoyage] Tentacle sweeps across the deck!")

	# Play attack sound from enemy data
	if tentacle.enemy_data and not tentacle.enemy_data.attack_sounds.is_empty():
		AudioManager.play_enemy_sound(tentacle.enemy_data.attack_sounds, tentacle.global_position, 3.0)
	else:
		AudioManager.play_sound_3d("res://assets/audio/sfx/monsters/mid_growl.wav", tentacle.global_position, 0.0)

	# Wind-up: visual pulse on the sprite child
	if tentacle.has_node("BillboardSprite"):
		var billboard: BillboardSprite = tentacle.get_node("BillboardSprite") as BillboardSprite
		if billboard and billboard.sprite:
			var original_color: Color = billboard.sprite.modulate

			var tween := create_tween()
			# Glow during wind-up - access sprite.modulate not billboard.modulate
			tween.tween_property(billboard.sprite, "modulate", Color(1.5, 0.8, 0.8, 1.0), TENTACLE_ATTACK_WINDUP)
			tween.tween_callback(_execute_sweep_damage.bind(tentacle))
			tween.tween_property(billboard.sprite, "modulate", original_color, 0.3)
		else:
			# No sprite, just execute the attack after windup
			await get_tree().create_timer(TENTACLE_ATTACK_WINDUP).timeout
			_execute_sweep_damage(tentacle)


## Execute sweep damage check
func _execute_sweep_damage(tentacle: EnemyBase) -> void:
	if not is_instance_valid(tentacle) or not player:
		return

	# Check if player is in sweep range (wide area around tentacle)
	var dist: float = tentacle.global_position.distance_to(player.global_position)
	if dist < 6.0:  # Wide sweep range
		var damage: int = randi_range(8, 15)
		if GameManager and GameManager.player_data:
			GameManager.player_data.take_damage(damage)
			print("[BoatVoyage] Tentacle sweep hits player for %d damage!" % damage)


## Tentacle lunge attack - targeted at player
func _tentacle_lunge_attack(tentacle: EnemyBase) -> void:
	if not is_instance_valid(tentacle) or not player:
		return

	print("[BoatVoyage] Tentacle lunges at player!")

	# Play attack sound
	if tentacle.enemy_data and not tentacle.enemy_data.attack_sounds.is_empty():
		AudioManager.play_enemy_sound(tentacle.enemy_data.attack_sounds, tentacle.global_position, 3.0)
	else:
		AudioManager.play_sound_3d("res://assets/audio/sfx/monsters/low_growl.wav", tentacle.global_position, 0.0)

	var original_pos: Vector3 = tentacle.global_position
	var target_pos: Vector3 = player.global_position

	# Quick lunge toward player
	var tween := create_tween()
	var lunge_pos: Vector3 = original_pos.lerp(target_pos, 0.6)  # Lunge 60% toward player

	tween.tween_property(tentacle, "global_position", lunge_pos, TENTACLE_ATTACK_SWING)
	tween.tween_callback(_execute_lunge_damage.bind(tentacle, target_pos))
	tween.tween_property(tentacle, "global_position", original_pos, 0.5)  # Retract


## Execute lunge damage check
func _execute_lunge_damage(tentacle: EnemyBase, target_pos: Vector3) -> void:
	if not is_instance_valid(tentacle) or not player:
		return

	# Check if player is still near the lunge target
	var dist: float = target_pos.distance_to(player.global_position)
	if dist < 2.5:  # Narrow lunge hitbox
		var damage: int = randi_range(12, 20)  # Higher damage for targeted attack
		if GameManager and GameManager.player_data:
			GameManager.player_data.take_damage(damage)
			print("[BoatVoyage] Tentacle lunge hits player for %d damage!" % damage)


func _handle_storm() -> void:
	# No combat - just damage and continue
	if GameManager and GameManager.player_data:
		var damage: int = randi_range(5, 15)
		GameManager.player_data.take_damage(damage)
		print("[BoatVoyage] Weathered the storm! (-%d HP)" % damage)

	# Brief delay then continue
	await get_tree().create_timer(2.0).timeout
	_resolve_current_encounter(BoatTravelManager.EncounterResult.STORM_SURVIVED)


func _get_deck_spawn_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Deck surface is at Y ~2.31 - spawn enemies at deck level
	const DECK_SPAWN_Y := 2.31

	# Spawn positions around the deck edges
	var deck_positions: Array[Vector3] = [
		Vector3(-4, DECK_SPAWN_Y, 0),    # Port side
		Vector3(4, DECK_SPAWN_Y, 0),     # Starboard side
		Vector3(0, DECK_SPAWN_Y, 3),     # Bow
		Vector3(-3, DECK_SPAWN_Y, 2),    # Port bow
		Vector3(3, DECK_SPAWN_Y, 2),     # Starboard bow
		Vector3(-2, DECK_SPAWN_Y, -2),   # Port stern
		Vector3(2, DECK_SPAWN_Y, -2),    # Starboard stern
	]

	for i in range(mini(count, deck_positions.size())):
		positions.append(deck_positions[i])

	return positions


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
			if not e.is_dead():
				alive_count += 1
				# Connect death signal if not already connected
				if not e.died.is_connected(_on_enemy_died):
					e.died.connect(_on_enemy_died)

	print("[BoatVoyage] Enemies remaining: %d" % alive_count)

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
	active_tentacles.clear()
	tentacle_attack_timers.clear()

	# Stand down crew
	_crew_stop_fighting()

	# Remove the enemy ship sprite
	if enemy_ship_sprite and is_instance_valid(enemy_ship_sprite):
		enemy_ship_sprite.queue_free()
		enemy_ship_sprite = null

	# Remove any remaining boat enemies
	for enemy in get_tree().get_nodes_in_group("boat_enemies"):
		if is_instance_valid(enemy):
			enemy.queue_free()

	# Continue voyage - will complete when timer runs out


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
		hud.show_notification("Victory! +%d XP, +%d gold" % [encounter_pending.xp_reward, gold])


func _complete_voyage() -> void:
	# Guard against re-entry (signal handlers can cause recursion)
	if voyage_completing:
		return
	voyage_completing = true
	voyage_started = false  # Stop the timer

	# Fade out ambient ships
	ambient_ships_active = false
	for ship in ambient_ships:
		if is_instance_valid(ship):
			var tween := create_tween()
			tween.tween_property(ship, "modulate:a", 0.0, 2.0)
			tween.tween_callback(ship.queue_free)
	ambient_ships.clear()

	print("[BoatVoyage] Voyage complete! Arrived at %s" % current_route.destination_port)

	# Time was advanced continuously during voyage via _update_world_time()
	# Only emit the time_advanced signal here for systems that need to know voyage ended
	if current_route and GameManager:
		# Calculate actual time elapsed (may differ slightly from route duration due to encounters)
		var actual_elapsed: float = time_accumulated * time_per_second
		GameManager.time_advanced.emit(actual_elapsed)
		print("[BoatVoyage] Total voyage time: %.1f hours (world time now: %s)" % [
			actual_elapsed, GameManager.get_time_string()
		])

	# Reset BoatTravelManager state
	var encounters_count: int = 1 if encounter_pending else 0
	if BoatTravelManager:
		BoatTravelManager.journey_complete.emit(current_route, encounters_count)
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
	voyage_timer = 0.0
	voyage_started = true
	_roll_for_encounter()


func _on_encounter_triggered(encounter: SeaEncounter) -> void:
	# Manager detected encounter - we handle it visually
	_start_encounter(encounter)


func _on_encounter_resolved(_encounter: SeaEncounter, _result: BoatTravelManager.EncounterResult) -> void:
	# Encounter resolved via manager (shouldn't happen if we're handling it)
	pass


func _on_journey_complete(_route: BoatTravelData, _encounters_count: int) -> void:
	_complete_voyage()


func _on_journey_cancelled(_route: BoatTravelData, reason: String) -> void:
	print("[BoatVoyage] Journey cancelled: %s" % reason)

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
	# Player is knocked out but rescued by crew, loses gold (25-150)
	var gold_loss: int = randi_range(25, 150)

	if InventoryManager:
		var actual_loss: int = mini(gold_loss, InventoryManager.gold)
		InventoryManager.remove_gold(actual_loss)
		gold_loss = actual_loss

	# Revive player with 1 HP
	if GameManager and GameManager.player_data:
		GameManager.player_data.current_hp = 1

	# Show notification
	var encounter_name: String = encounter_pending.get_type_name() if encounter_pending else "pirates"
	print("[BoatVoyage] You were overwhelmed...")

	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("You lost %d gold to the %s!" % [gold_loss, encounter_name])

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

	print("[BoatVoyage] Returning to %s..." % departure)

	# Reset boat travel state
	if BoatTravelManager:
		BoatTravelManager._reset_journey_state()

	# Brief pause before transition
	await get_tree().create_timer(1.5).timeout

	# Travel back to departure port
	_travel_to_destination(departure)
