## crossroads_ruins.gd - Crossroads Ruins (Keepers Questline Finale)
## Exterior scene with ancient ruined intersection, collapsed structures, and boss arena
## Final confrontation location for The Keepers faction questline
##
## NOTE: All static geometry is defined in crossroads_ruins.tscn
## This script handles runtime setup: boss encounter, magic effects, navigation
extends Node3D

const ZONE_ID := "crossroads_ruins"
const ZONE_NAME := "The Crossroads Ruins"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# Boss encounter configuration
var boss_spawned := false
var boss_defeated := false
var arena_active := false


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)

	# Play ominous outdoor ambiance (only when main scene)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		AudioManager.play_zone_ambiance("ruins")
		AudioManager.play_zone_music("boss")

	_setup_spawn_points()
	_setup_enemy_spawns()
	_setup_doors()
	_setup_chests()
	_setup_navigation()
	_setup_interactables()
	_setup_ambient_magic_effects()


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


## Configure enemy spawn points
func _setup_enemy_spawns() -> void:
	var enemy_spawns := $EnemySpawnPoints

	# Enemy type configuration - mostly guards, with final boss
	var enemy_configs: Dictionary = {
		"CultistSpawn_0": {"type": "cultist_elite", "respawn": -1.0},  # No respawn for finale
		"CultistSpawn_1": {"type": "cultist_elite", "respawn": -1.0},
		"CultistSpawn_2": {"type": "cultist_mage", "respawn": -1.0},
		"CultistSpawn_3": {"type": "cultist_mage", "respawn": -1.0},
		"CultistSpawn_4": {"type": "cultist_elite", "respawn": -1.0},
		"CultistSpawn_5": {"type": "cultist_elite", "respawn": -1.0},
		"BossSpawn": {"type": "keeper_master", "respawn": -1.0, "is_boss": true},
	}

	for child in enemy_spawns.get_children():
		if child is Marker3D:
			child.add_to_group("enemy_spawn")
			var config: Dictionary = enemy_configs.get(child.name, {"type": "cultist", "respawn": -1.0})
			child.set_meta("enemy_type", config.get("type", "cultist"))
			child.set_meta("respawn_time", config.get("respawn", -1.0))
			child.set_meta("faction", "keepers")
			if config.get("is_boss", false):
				child.set_meta("is_boss", true)
				child.add_to_group("boss_spawn")
				child.add_to_group("finale_boss")


## Setup door connections
func _setup_doors() -> void:
	var door_positions := $DoorPositions

	# South exit - back to wilderness/previous area
	var south_exit := door_positions.get_node_or_null("SouthExit")
	if south_exit:
		var exit_door := ZoneDoor.spawn_door(
			self,
			south_exit.global_position,
			"RETURN_TO_WILDERNESS",
			"from_crossroads",
			"Leave Ruins",
			false  # No frame for outdoor exit
		)
		exit_door.rotation.y = PI


## Setup chest spawns
func _setup_chests() -> void:
	var chest_positions := $ChestPositions

	var chest_configs: Dictionary = {
		"Chest_Ruins_NW": {"tier": "uncommon", "locked": false},
		"Chest_Ruins_SE": {"tier": "uncommon", "locked": true, "difficulty": 18},
		"Chest_Boss": {"tier": "rare", "locked": true, "difficulty": 25},  # Boss reward chest
	}

	for child in chest_positions.get_children():
		if child is Marker3D:
			child.add_to_group("loot_chest")
			var config: Dictionary = chest_configs.get(child.name, {"tier": "common"})
			child.set_meta("loot_tier", config.get("tier", "common"))
			child.set_meta("is_locked", config.get("locked", false))
			child.set_meta("lock_difficulty", config.get("difficulty", 10))


## Setup navigation mesh for enemy pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		push_warning("[Crossroads Ruins] NavigationRegion3D not found")
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


## Setup interactable objects
func _setup_interactables() -> void:
	var interactables := $Interactables

	# Boss arena center marker
	var arena_center := interactables.get_node_or_null("BossArenaCenter")
	if arena_center:
		arena_center.add_to_group("boss_arena")
		arena_center.set_meta("arena_radius", 25.0)

	# Ancient altar - could be quest objective
	var altar := interactables.get_node_or_null("AncientAltar")
	if altar:
		altar.add_to_group("quest_objective")
		altar.add_to_group("ancient_altar")
		altar.set_meta("altar_type", "keepers_finale")


## Setup ambient magic particle effects
func _setup_ambient_magic_effects() -> void:
	# TODO: Add floating particle effects when VFX system is implemented
	# The lighting is set up in the scene, but particles would enhance it
	pass


## Activate boss arena (locks player in until boss defeated)
func activate_boss_arena() -> void:
	if arena_active:
		return

	arena_active = true
	# TODO: Spawn invisible barrier around arena
	# TODO: Trigger boss music change
	AudioManager.play_zone_music("boss_fight")

	# Spawn the boss if not already spawned
	if not boss_spawned:
		_spawn_boss()


## Spawn the finale boss
func _spawn_boss() -> void:
	var boss_marker := $EnemySpawnPoints/BossSpawn
	if boss_marker and not boss_spawned:
		boss_spawned = true
		# TODO: Actually spawn the boss enemy using EnemyBase.spawn_billboard_enemy()
		# The enemy type "keeper_master" should be defined in the enemy data


## Called when boss is defeated
func on_boss_defeated() -> void:
	boss_defeated = true
	arena_active = false

	# TODO: Remove arena barrier
	# TODO: Play victory music
	AudioManager.play_zone_music("victory")

	# Update quest progress
	QuestManager.update_progress("keepers_finale", "defeat_master", 1)


## Check if player is inside boss arena
func is_in_boss_arena(world_pos: Vector3) -> bool:
	var arena_center := Vector3.ZERO
	var arena_radius := 25.0
	var distance: float = Vector2(world_pos.x - arena_center.x, world_pos.z - arena_center.z).length()
	return distance <= arena_radius


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name.to_lower() == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	return spawn_points.get_node_or_null("DefaultSpawn")
