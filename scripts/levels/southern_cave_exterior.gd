## southern_cave_exterior.gd - Southern Cave Exterior Area
## Forest clearing with a cave entrance leading into custom_cave_test dungeon
## Located southwest of Elder Moor, between Elder Moor and Kazan-Dun
##
## CONVERTED: Terrain, structures, and decorations are pre-placed in .tscn
## This script handles: environment setup, enemy spawning, interactables, doors, navigation
extends Node3D

const ZONE_ID := "southern_cave_exterior"

var nav_region: NavigationRegion3D


func _ready() -> void:
	# Set current region for world map tracking
	if SceneManager:
		SceneManager.set_current_region(ZONE_ID)

	_setup_environment()
	_spawn_enemies_from_markers()
	_spawn_chests_from_markers()
	_spawn_doors_from_markers()
	_setup_navigation()
	_setup_cell_streaming()
	# Only setup day/night lighting when this is the main scene (has Player node)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		DayNightCycle.add_to_level(self)
		if WeatherManager:
			WeatherManager.set_outdoor(true)


## Setup the forest environment
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.22, 0.28, 0.2)  # Dark forest
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.3)  # Dim forest light
	env.ambient_light_energy = 0.5
	env.fog_enabled = true
	env.fog_light_color = Color(0.2, 0.26, 0.18)
	env.fog_density = 0.015
	env.fog_sky_affect = 0.3

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	# Directional light (filtered through forest canopy)
	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.light_color = Color(0.9, 0.88, 0.75)
	light.light_energy = 0.6
	light.rotation_degrees = Vector3(-45, 25, 0)
	light.shadow_enabled = true
	light.shadow_bias = 0.02
	add_child(light)


## Spawn enemies from Marker3D positions in EnemySpawns node
func _spawn_enemies_from_markers() -> void:
	var enemy_spawns := get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		push_warning("[SouthernCaveExterior] EnemySpawns node not found")
		return

	var enemies_container := Node3D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	for marker in enemy_spawns.get_children():
		if marker is Marker3D:
			var enemy_data_path: String = marker.get_meta("enemy_data", "res://data/enemies/human_bandit.tres")

			# Extract enemy type ID from path
			var enemy_type: String = enemy_data_path.get_file().get_basename()

			# Check ActorRegistry first for sprite config (includes zoo patches)
			var sprite_config: Dictionary = ActorRegistry.get_sprite_config(enemy_type)

			var sprite_path: String
			var h_frames: int
			var v_frames: int

			if not sprite_config.is_empty():
				sprite_path = sprite_config.get("sprite_path", "")
				h_frames = sprite_config.get("h_frames", 4)
				v_frames = sprite_config.get("v_frames", 1)
			else:
				# Fall back to defaults based on enemy type
				sprite_path = "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"
				h_frames = 4
				v_frames = 1

			var sprite_texture: Texture2D = load(sprite_path)
			if not sprite_texture:
				push_error("[SouthernCaveExterior] Failed to load sprite: %s" % sprite_path)
				continue

			EnemyBase.spawn_billboard_enemy(
				enemies_container,
				marker.global_position,
				enemy_data_path,
				sprite_texture,
				h_frames,
				v_frames
			)


## Spawn chests from Marker3D positions in ChestPositions node
func _spawn_chests_from_markers() -> void:
	var chest_positions := get_node_or_null("ChestPositions")
	if not chest_positions:
		# No chests is fine for this simple exterior
		return

	var interactables := Node3D.new()
	interactables.name = "Interactables"
	add_child(interactables)

	for marker in chest_positions.get_children():
		if marker is Marker3D:
			var chest_name: String = marker.get_meta("chest_name", "Chest")
			var is_locked: bool = marker.get_meta("is_locked", false)
			var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
			var randomize_loot: bool = marker.get_meta("randomize_loot", true)
			var persistent_id: String = marker.get_meta("persistent_id", "")

			Chest.spawn_chest(
				interactables,
				marker.global_position,
				chest_name,
				is_locked,
				lock_difficulty,
				randomize_loot,
				persistent_id
			)


## Spawn zone doors from Marker3D positions in DoorPositions node
func _spawn_doors_from_markers() -> void:
	var door_positions := get_node_or_null("DoorPositions")
	if not door_positions:
		push_warning("[SouthernCaveExterior] DoorPositions node not found")
		return

	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	for marker in door_positions.get_children():
		if marker is Marker3D:
			var target_scene: String = marker.get_meta("target_scene", "")
			var spawn_id: String = marker.get_meta("spawn_id", "default")
			var door_label: String = marker.get_meta("door_label", "Exit")
			var show_frame: bool = marker.get_meta("show_frame", true)

			# Handle special case for wilderness return
			if target_scene == "RETURN_TO_WILDERNESS":
				target_scene = SceneManager.RETURN_TO_WILDERNESS

			var door := ZoneDoor.spawn_door(
				doors,
				marker.global_position,
				target_scene,
				spawn_id,
				door_label
			)
			if door:
				door.rotation = marker.rotation
				door.show_frame = show_frame


## Setup navigation mesh (baked at runtime from pre-placed geometry)
func _setup_navigation() -> void:
	nav_region = get_node_or_null("NavigationRegion3D")
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.25
	nav_mesh.cell_height = 0.25
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0
	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()


## Setup cell streaming if we're the main scene (has Player/HUD)
func _setup_cell_streaming() -> void:
	var player: Node = get_node_or_null("Player")
	if not player:
		# We're a streaming cell, not main scene - skip streaming setup
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	# Use WorldGrid location_id
	var my_coords: Vector2i = WorldGrid.get_location_coords("southern_cave")
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
