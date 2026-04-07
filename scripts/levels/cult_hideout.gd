## cult_hideout.gd - Cult Hideout (Keepers Questline Dungeon)
## Hidden cellar/cave system with ritual chamber, prison cells, and cultist enemies
## Key location for The Keepers faction questline
##
## NOTE: All static geometry is defined in cult_hideout.tscn
## This script handles runtime setup: enemies, prisoners, navigation, quest triggers
extends Node3D

const ZONE_ID := "dungeon_cult_hideout"
const ZONE_NAME := "Cult Hideout"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D

# Cultist respawn configuration (longer respawn for quest dungeon)
var cultist_respawn_time := 600.0  # 10 minutes


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)

	# Play creepy dungeon ambiance (only when main scene)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		AudioManager.play_zone_ambiance("dungeon")
		AudioManager.play_zone_music("horror")

	_setup_spawn_points()
	_setup_enemy_spawns()
	_setup_doors()
	_setup_chests()
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


## Configure enemy spawn points for cultists
func _setup_enemy_spawns() -> void:
	var enemy_spawns := $EnemySpawnPoints

	# Enemy type configuration
	var enemy_configs: Dictionary = {
		"CultistSpawn_0": {"type": "cultist", "respawn": cultist_respawn_time},
		"CultistSpawn_1": {"type": "cultist", "respawn": cultist_respawn_time},
		"CultistSpawn_2": {"type": "cultist", "respawn": cultist_respawn_time},
		"CultistSpawn_3": {"type": "cultist_guard", "respawn": cultist_respawn_time},  # Prison guard
		"CultistSpawn_4": {"type": "cultist_mage", "respawn": cultist_respawn_time},
		"CultistSpawn_5": {"type": "cultist_mage", "respawn": cultist_respawn_time},
		"CultistSpawn_6": {"type": "cultist", "respawn": cultist_respawn_time},
		"CultistSpawn_7": {"type": "cultist", "respawn": cultist_respawn_time},
		"CultLeaderSpawn": {"type": "cult_leader", "respawn": cultist_respawn_time * 2, "is_boss": true},
	}

	for child in enemy_spawns.get_children():
		if child is Marker3D:
			child.add_to_group("enemy_spawn")
			var config: Dictionary = enemy_configs.get(child.name, {"type": "cultist", "respawn": cultist_respawn_time})
			child.set_meta("enemy_type", config.get("type", "cultist"))
			child.set_meta("respawn_time", config.get("respawn", cultist_respawn_time))
			child.set_meta("faction", "cult")
			if config.get("is_boss", false):
				child.set_meta("is_boss", true)
				child.add_to_group("boss_spawn")


## Setup door connections
func _setup_doors() -> void:
	var door_positions := $DoorPositions

	# Exit back to exterior (will be configured based on entry point)
	var exit_marker := door_positions.get_node_or_null("ExitDoor")
	if exit_marker:
		var exit_door := ZoneDoor.spawn_door(
			self,
			exit_marker.global_position,
			"RETURN_TO_PREVIOUS",
			"from_cult_hideout",
			"Exit",
			true
		)
		exit_door.return_to_previous = true
		exit_door.rotation.y = PI


## Setup chest spawns
func _setup_chests() -> void:
	var chest_positions := $ChestPositions

	var chest_configs: Dictionary = {
		"Chest_Cellar": {"tier": "common", "locked": false},
		"Chest_Ritual": {"tier": "uncommon", "locked": true, "difficulty": 15},
	}

	for child in chest_positions.get_children():
		if child is Marker3D:
			child.add_to_group("loot_chest")
			var config: Dictionary = chest_configs.get(child.name, {"tier": "common"})
			child.set_meta("loot_tier", config.get("tier", "common"))
			child.set_meta("is_locked", config.get("locked", false))
			child.set_meta("lock_difficulty", config.get("difficulty", 10))


## Setup navigation mesh for NPC/enemy pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		push_warning("[Cult Hideout] NavigationRegion3D not found")
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


## Setup interactable objects (prisoner cells, ritual altar)
func _setup_interactables() -> void:
	var interactables := $Interactables

	# Prisoner cells - can be rescued for quest objectives
	var cell1 := interactables.get_node_or_null("PrisonerCell1")
	if cell1:
		cell1.add_to_group("prisoner_cell")
		cell1.set_meta("prisoner_id", "prisoner_1")
		cell1.set_meta("cell_locked", true)
		cell1.set_meta("lock_difficulty", 12)

	var cell2 := interactables.get_node_or_null("PrisonerCell2")
	if cell2:
		cell2.add_to_group("prisoner_cell")
		cell2.set_meta("prisoner_id", "prisoner_2")
		cell2.set_meta("cell_locked", true)
		cell2.set_meta("lock_difficulty", 12)

	# Ritual altar - quest objective / interactable
	var altar := interactables.get_node_or_null("RitualAltar")
	if altar:
		altar.add_to_group("quest_objective")
		altar.add_to_group("ritual_altar")
		altar.set_meta("altar_type", "dark_ritual")
		altar.set_meta("quest_id", "keepers_cult_investigation")


## Check if ritual is active (for environmental effects)
func is_ritual_active() -> bool:
	# TODO: Check quest state to determine if ritual is in progress
	return false


## Trigger ritual interruption (quest objective)
func interrupt_ritual() -> void:
	# TODO: Trigger quest progress when player interrupts the ritual
	QuestManager.update_progress("cult_ritual", "interrupt", 1)


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name.to_lower() == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	return spawn_points.get_node_or_null("DefaultSpawn")
