## dalhurst.gd - Dalhurst Port City (Tier 4 Major City)
## Major port city on the bay, largest commercial port for the capital Emmenburg
## 18 warships in harbor, 2600 troops garrison
## Contains: The Gilded Grog Tavern, Shipwright Guild, Lady Nightshade's Curiosities,
## Harbormaster's Office, Bounty Board, Multiple Merchants, Harbor Area
##
## NOTE: All static geometry and NPCs are defined in dalhurst.tscn
## This script only handles runtime setup like navigation and day/night cycle
extends Node3D

const ZONE_ID := "dalhurst"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)
		_setup_day_night_cycle()
		DayNightCycle.add_to_level(self)

	_setup_spawn_point_metadata()
	_setup_navigation()
	_setup_cell_streaming()
	print("[Dalhurst] Port city loaded - Tier 4 Major City")


## Setup spawn point metadata for spawn points defined in .tscn
func _setup_spawn_point_metadata() -> void:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = $NavigationRegion3D

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
		print("[Dalhurst] Navigation mesh baked!")


## Setup day/night cycle (placeholder - actual setup done by DayNightCycle autoload)
func _setup_day_night_cycle() -> void:
	# Day/night cycle is managed by DayNightCycle autoload
	# This function exists for any level-specific lighting setup
	pass


## Setup cell streaming if we're the main scene (has Player/HUD)
## When loaded as a streaming cell, this will be skipped (Player/HUD stripped by CellStreamer)
func _setup_cell_streaming() -> void:
	# Only setup streaming if we're the main scene (we have Player/HUD)
	var player: Node = get_node_or_null("Player")
	if not player:
		# We're a streaming cell, not main scene - skip streaming setup
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	var my_coords: Vector2i = WorldGrid.get_location_coords(ZONE_ID)
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
	print("[%s] Registered as main scene, streaming started at %s" % [ZONE_ID, my_coords])
