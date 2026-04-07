## dalhurst_cemetery.gd - Dalhurst Cemetery
## Exterior graveyard location for Morthane temple quest
## Features tombstones, crypts, mausoleum, consecrated ground, and undead spawn points
##
## NOTE: All static geometry is defined in dalhurst_cemetery.tscn
## This script handles runtime setup: enemies, navigation, quest triggers
extends Node3D

const ZONE_ID := "dalhurst_cemetery"
const ZONE_NAME := "Dalhurst Cemetery"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# Undead respawn configuration
var undead_respawn_time := 300.0  # 5 minutes


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)

	# Play cemetery ambiance (only when main scene)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		AudioManager.play_zone_ambiance("graveyard")
		AudioManager.play_zone_music("horror")

	_setup_spawn_points()
	_setup_enemy_spawns()
	_setup_doors()
	_setup_navigation()
	_setup_interactables()


## Configure spawn points from pre-placed markers
func _setup_spawn_points() -> void:
	var spawn_points := $SpawnPoints

	for child in spawn_points.get_children():
		child.add_to_group("spawn_points")
		var spawn_id: String = child.name.to_lower()
		if spawn_id == "defaultspawn":
			spawn_id = "default"
			child.add_to_group("default_spawn")
		child.set_meta("spawn_id", spawn_id)


## Configure enemy spawn points for undead
func _setup_enemy_spawns() -> void:
	var enemy_spawns := $EnemySpawnPoints

	# Enemy type configuration based on spawn position
	var enemy_configs: Dictionary = {
		"UndeadSpawn_0": {"type": "skeleton", "respawn": undead_respawn_time},
		"UndeadSpawn_1": {"type": "skeleton", "respawn": undead_respawn_time},
		"UndeadSpawn_2": {"type": "skeleton", "respawn": undead_respawn_time},
		"UndeadSpawn_3": {"type": "ghost", "respawn": undead_respawn_time},
		"UndeadSpawn_4": {"type": "ghost", "respawn": undead_respawn_time},
		"UndeadSpawn_5": {"type": "wraith", "respawn": undead_respawn_time * 1.5},
		"UndeadSpawn_6": {"type": "wraith", "respawn": undead_respawn_time * 1.5},  # Near consecrated ground
	}

	for child in enemy_spawns.get_children():
		if child is Marker3D:
			child.add_to_group("enemy_spawn")
			var config: Dictionary = enemy_configs.get(child.name, {"type": "skeleton", "respawn": undead_respawn_time})
			child.set_meta("enemy_type", config.get("type", "skeleton"))
			child.set_meta("respawn_time", config.get("respawn", undead_respawn_time))
			child.set_meta("faction", "undead")


## Setup door connections
func _setup_doors() -> void:
	var door_positions := $DoorPositions

	# Exit back to Dalhurst town
	var exit_marker := door_positions.get_node_or_null("ExitToDalhurst")
	if exit_marker:
		var exit_door := ZoneDoor.spawn_door(
			self,
			exit_marker.global_position,
			"res://scenes/levels/dalhurst.tscn",  # TODO: Verify Dalhurst scene path exists
			"from_cemetery",
			"Return to Dalhurst",
			false  # No frame for outdoor exit
		)
		exit_door.rotation.y = PI  # Face away from cemetery


## Setup navigation mesh for NPC/enemy pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		push_warning("[Dalhurst Cemetery] NavigationRegion3D not found")
		return

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 0.3
	nav_mesh.cell_height = 0.2
	nav_mesh.agent_height = 2.0
	nav_mesh.agent_radius = 0.5
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.agent_max_slope = 45.0

	nav_region.navigation_mesh = nav_mesh
	call_deferred("_bake_navigation")


func _bake_navigation() -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()


## Setup interactable objects (shrine, mausoleum entrance)
func _setup_interactables() -> void:
	var interactables := $Interactables

	# Morthane Shrine (consecrated ground) - used for temple quest
	var shrine_pos := interactables.get_node_or_null("MorthaneShrine")
	if shrine_pos:
		# TODO: Spawn Morthane shrine interactable when temple quest system is implemented
		shrine_pos.add_to_group("morthane_shrine")
		shrine_pos.set_meta("shrine_type", "morthane")
		shrine_pos.set_meta("consecrated", true)

	# Mausoleum entrance - could lead to dungeon
	var mausoleum_pos := interactables.get_node_or_null("MausoleumEntrance")
	if mausoleum_pos:
		# TODO: Add mausoleum dungeon when implemented
		mausoleum_pos.add_to_group("dungeon_entrance")
		mausoleum_pos.set_meta("dungeon_type", "crypt")


## Check if a position is on consecrated ground (affects undead)
func is_on_consecrated_ground(world_pos: Vector3) -> bool:
	# Consecrated ground is centered at (0, 0, -42) with size 12x10
	var consecrated_center := Vector3(0, 0, -42)
	var half_size := Vector3(6, 5, 5)

	return (abs(world_pos.x - consecrated_center.x) < half_size.x and
			abs(world_pos.z - consecrated_center.z) < half_size.z)


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name.to_lower() == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	return spawn_points.get_node_or_null("DefaultSpawn")
