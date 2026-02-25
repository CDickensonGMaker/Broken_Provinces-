## bloodsand_arena.gd - Bloodsand Arena (Combat Arena south of Elder Moor)
## Gladiatorial combat arena where players fight in tournaments for fame and rewards
## Scene-based layout with runtime navigation baking
extends Node3D

const ZONE_ID := "bloodsand_arena"
const ZONE_SIZE := Vector2(100.0, 100.0)  # Standard cell size

## Grid coordinates (south of Elder Moor)
const GRID_COORDS := Vector2i(0, 3)

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

## Arena barrier reference (created at runtime or from scene)
var arena_barrier: StaticBody3D


func _ready() -> void:
	# Add to group so TournamentManager can find the arena
	add_to_group("bloodsand_arena")
	add_to_group("level_root")

	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			PlayerGPS.set_position(GRID_COORDS, true)

	_setup_navigation()
	if is_main_scene:
		_setup_day_night_cycle()
	_setup_spawn_point_metadata()
	_generate_terrain_collision()
	_spawn_arena_master()
	_spawn_spectators()
	_setup_arena_barrier()

	# Connect to TournamentManager signals
	_connect_tournament_signals()

	# Register with CellStreamer and start streaming
	_setup_cell_streaming()

	print("[Bloodsand Arena] Combat arena initialized")


## Register this scene with CellStreamer and start streaming
func _setup_cell_streaming() -> void:
	if not CellStreamer:
		push_warning("[Bloodsand Arena] CellStreamer not found")
		return

	# Register this scene as a cell
	CellStreamer.register_main_scene_cell(GRID_COORDS, self)

	# Start streaming from this cell
	CellStreamer.start_streaming(GRID_COORDS)


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Bloodsand Arena] NavigationRegion3D not found in scene")
		return

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
		print("[Bloodsand Arena] Navigation mesh baked")


## Setup dynamic day/night lighting
func _setup_day_night_cycle() -> void:
	DayNightCycle.add_to_level(self)


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Generate collision shapes for terrain and building meshes
func _generate_terrain_collision() -> void:
	# Find the terrain node
	var terrain := get_node_or_null("Terrain")
	if terrain:
		_add_collision_to_meshes(terrain)
		print("[Bloodsand Arena] Generated collision for terrain")


## Recursively add collision to all MeshInstance3D nodes
func _add_collision_to_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node
		# Check if collision already exists
		var has_collision := false
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				has_collision = true
				break

		if not has_collision and mesh_instance.mesh:
			# Create static body with trimesh collision
			mesh_instance.create_trimesh_collision()

	# Recurse into children
	for child in node.get_children():
		_add_collision_to_meshes(child)


## Spawn the Arena Master NPC (Gormund the Pitmaster)
func _spawn_arena_master() -> void:
	var master_pos := get_node_or_null("ArenaMasterPosition")
	if not master_pos:
		push_warning("[Bloodsand Arena] ArenaMasterPosition marker not found")
		return

	# Spawn the arena master NPC
	var arena_master := ArenaMaster.new()
	arena_master.position = master_pos.global_position
	arena_master.region_id = ZONE_ID
	add_child(arena_master)

	print("[Bloodsand Arena] Arena Master spawned at %s" % master_pos.global_position)


## Spawn spectator NPCs around the arena
func _spawn_spectators() -> void:
	var spectator_areas := get_node_or_null("SpectatorAreas")
	if not spectator_areas:
		return

	var spectators_container := Node3D.new()
	spectators_container.name = "SpectatorPopulation"
	add_child(spectators_container)

	var total_spawned: int = 0

	for area in spectator_areas.get_children():
		if not area is Marker3D:
			continue

		# Spawn 3-5 spectators per area
		var count: int = randi_range(3, 5)
		for i in range(count):
			# Random position within 3 meters of the marker
			var angle: float = randf() * TAU
			var dist: float = randf() * 3.0
			var spawn_pos := Vector3(
				area.global_position.x + cos(angle) * dist,
				area.global_position.y,
				area.global_position.z + sin(angle) * dist
			)

			# Spawn random civilian type (spectators watching the fights)
			var npc: CivilianNPC = CivilianNPC.spawn_worker_random(
				spectators_container,
				spawn_pos,
				ZONE_ID
			)

			# Spectators don't wander - they watch the fights
			npc.wander_radius = 1.0
			npc.wander_speed = 0.5

			total_spawned += 1

	print("[Bloodsand Arena] Spawned %d spectator NPCs" % total_spawned)

	# Store reference for day/night management
	set_meta("spectators_container", spectators_container)

	# Connect to GameManager's time of day changes for visibility management
	if GameManager:
		GameManager.time_of_day_changed.connect(_on_time_of_day_changed)
		_update_spectator_visibility()


## Called when time of day changes
func _on_time_of_day_changed(_new_time: Enums.TimeOfDay) -> void:
	_update_spectator_visibility()


## Show/hide spectators based on time of day (arena is open during daytime)
func _update_spectator_visibility() -> void:
	var spectators_container: Node3D = get_meta("spectators_container", null) as Node3D
	if not spectators_container:
		return

	var current_time: Enums.TimeOfDay = GameManager.current_time_of_day if GameManager else Enums.TimeOfDay.NOON

	# Arena is open during daytime hours (DAWN through DUSK, not NIGHT or MIDNIGHT)
	var is_daytime: bool = current_time in [
		Enums.TimeOfDay.DAWN,
		Enums.TimeOfDay.MORNING,
		Enums.TimeOfDay.NOON,
		Enums.TimeOfDay.AFTERNOON,
		Enums.TimeOfDay.DUSK
	]

	for child in spectators_container.get_children():
		if child is CivilianNPC:
			child.visible = is_daytime
			child.set_physics_process(is_daytime)
			child.set_process(is_daytime)
			if child.wander:
				child.wander.set_physics_process(is_daytime)


## Get gladiator spawn positions for tournament fights
func get_gladiator_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var spawns := get_node_or_null("GladiatorSpawns")
	if spawns:
		for child in spawns.get_children():
			if child is Marker3D:
				positions.append(child.global_position)
	return positions


## Get the arena center position
func get_arena_center() -> Vector3:
	var center := get_node_or_null("ArenaCenter")
	if center:
		return center.global_position
	return Vector3.ZERO


## Get the waiting area position (where player goes between waves)
func get_waiting_area_position() -> Vector3:
	var waiting := get_node_or_null("WaitingArea")
	if waiting:
		return waiting.global_position

	# Fallback to arena master position if waiting area not defined
	var master_pos := get_node_or_null("ArenaMasterPosition")
	if master_pos:
		return master_pos.global_position

	# Ultimate fallback
	return Vector3(5, 0, 40)


## Setup arena barrier (invisible wall during combat)
func _setup_arena_barrier() -> void:
	# Check if barrier exists in scene
	arena_barrier = get_node_or_null("ArenaBarrier") as StaticBody3D

	if not arena_barrier:
		# Create barrier programmatically
		arena_barrier = _create_arena_barrier()

	# Start with barrier disabled
	disable_arena_barrier()


## Create the arena barrier programmatically
func _create_arena_barrier() -> StaticBody3D:
	var barrier := StaticBody3D.new()
	barrier.name = "ArenaBarrier"

	# Get arena center for positioning
	var center: Vector3 = get_arena_center()
	barrier.global_position = center

	# Create invisible wall collision - a ring around the arena
	# We'll use 4 box colliders to form a square boundary
	var barrier_radius: float = 18.0  # Distance from center to barrier
	var barrier_height: float = 10.0  # Tall enough to prevent jumping over
	var barrier_thickness: float = 1.0

	# North wall
	var north_wall := _create_barrier_wall(
		Vector3(0, barrier_height / 2, -barrier_radius),
		Vector3(barrier_radius * 2, barrier_height, barrier_thickness)
	)
	barrier.add_child(north_wall)

	# South wall
	var south_wall := _create_barrier_wall(
		Vector3(0, barrier_height / 2, barrier_radius),
		Vector3(barrier_radius * 2, barrier_height, barrier_thickness)
	)
	barrier.add_child(south_wall)

	# East wall
	var east_wall := _create_barrier_wall(
		Vector3(barrier_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, barrier_radius * 2)
	)
	barrier.add_child(east_wall)

	# West wall
	var west_wall := _create_barrier_wall(
		Vector3(-barrier_radius, barrier_height / 2, 0),
		Vector3(barrier_thickness, barrier_height, barrier_radius * 2)
	)
	barrier.add_child(west_wall)

	# Set collision layer (layer 1 for world collision)
	barrier.collision_layer = 1
	barrier.collision_mask = 0

	add_child(barrier)
	return barrier


## Create a single barrier wall segment
func _create_barrier_wall(pos: Vector3, size: Vector3) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = pos
	return collision


## Connect to TournamentManager signals
func _connect_tournament_signals() -> void:
	if not TournamentManager:
		push_warning("[Bloodsand Arena] TournamentManager not found")
		return

	TournamentManager.barrier_enabled.connect(enable_arena_barrier)
	TournamentManager.barrier_disabled.connect(disable_arena_barrier)


## Enable the arena barrier (prevents leaving during combat)
func enable_arena_barrier() -> void:
	if arena_barrier:
		arena_barrier.collision_layer = 1  # Enable collision
		print("[Bloodsand Arena] Arena barrier ENABLED")


## Disable the arena barrier (allows leaving between waves)
func disable_arena_barrier() -> void:
	if arena_barrier:
		arena_barrier.collision_layer = 0  # Disable collision
		print("[Bloodsand Arena] Arena barrier DISABLED")


func _exit_tree() -> void:
	# Disconnect TournamentManager signals
	if TournamentManager:
		if TournamentManager.barrier_enabled.is_connected(enable_arena_barrier):
			TournamentManager.barrier_enabled.disconnect(enable_arena_barrier)
		if TournamentManager.barrier_disabled.is_connected(disable_arena_barrier):
			TournamentManager.barrier_disabled.disconnect(disable_arena_barrier)
