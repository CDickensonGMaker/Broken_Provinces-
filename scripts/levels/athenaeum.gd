## athenaeum.gd - The Athenaeum (Arcane Circle Mage Guild Library/Tower)
## Interior guild hall with library stacks, study alcoves, restricted archive, and Archmage's chamber
## Hub for magic-focused quests, spell research, and arcane knowledge
##
## NOTE: All static geometry is defined in athenaeum.tscn
## This script handles runtime setup: NPCs, navigation, interactables
extends Node3D

const ZONE_ID := "guild_athenaeum"
const ZONE_NAME := "The Athenaeum - Arcane Circle"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)

	# Play mystical interior ambiance (only when main scene)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		AudioManager.play_zone_ambiance("interior")
		AudioManager.play_zone_music("mystic")

	_setup_spawn_points()
	_setup_doors()
	_setup_navigation()
	_spawn_npcs()
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


## Setup door connections
func _setup_doors() -> void:
	var door_positions := $DoorPositions

	# Main exit - will be configured to return to parent city/location
	var exit_marker := door_positions.get_node_or_null("ExitDoor")
	if exit_marker:
		var exit_door := ZoneDoor.spawn_door(
			self,
			exit_marker.global_position,
			"RETURN_TO_PREVIOUS",
			"from_athenaeum",
			"Exit to City",
			true
		)
		exit_door.return_to_previous = true

	# Restricted Archive door (could be locked until certain conditions)
	var restricted_marker := door_positions.get_node_or_null("RestrictedDoor")
	if restricted_marker:
		# This is an internal door marker - actual restriction handled by script
		pass

	# Archmage's Chamber door (could require guild rank)
	var archmage_marker := door_positions.get_node_or_null("ArchmageDoor")
	if archmage_marker:
		# This is an internal door marker - access restriction handled by script
		pass


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		push_warning("[Athenaeum] NavigationRegion3D not found")
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


## Spawn guild NPCs
func _spawn_npcs() -> void:
	var npc_container := $NPCs
	var npc_positions := $NPCs/NPCPositions

	# === ARCHMAGE ELARA (Guild Master) ===
	var archmage_pos: Vector3 = npc_positions.get_node("ArchmageElara").global_position
	var archmage := QuestGiver.spawn_quest_giver(
		npc_container,
		archmage_pos,
		"Archmage Elara",
		"archmage_elara",
		preload("res://assets/sprites/npcs/civilians/female_noble1.png"),
		1, 1,
		[],  # Quest IDs to be added when guild quests are implemented
		false
	)
	archmage.region_id = ZONE_ID
	archmage.faction_id = "arcane_circle"
	archmage.no_quest_dialogue = "The Arcane Circle welcomes those who seek knowledge. Return when you are ready to prove your dedication to the mystical arts."
	var archmage_profile := NPCKnowledgeProfile.new()
	archmage_profile.archetype = NPCKnowledgeProfile.Archetype.SCHOLAR
	archmage_profile.personality_traits = ["wise", "mysterious", "patient", "powerful"]
	archmage_profile.knowledge_tags = ["arcane_circle", "magic", "spells", "artifacts", "ancient_lore", "enchantment"]
	archmage_profile.base_disposition = 45
	archmage_profile.speech_style = "mystical"
	archmage.npc_profile = archmage_profile

	# === LIBRARIAN ===
	var librarian_pos: Vector3 = npc_positions.get_node("Librarian").global_position
	var librarian := QuestGiver.spawn_quest_giver(
		npc_container,
		librarian_pos,
		"Archivist Thorne",
		"athenaeum_librarian",
		preload("res://assets/sprites/npcs/civilians/man_civilian.png"),
		1, 1,
		[],
		false
	)
	librarian.region_id = ZONE_ID
	librarian.faction_id = "arcane_circle"
	librarian.no_quest_dialogue = "Silence in the library, please. If you seek specific knowledge, I may be able to direct you."
	var librarian_profile := NPCKnowledgeProfile.new()
	librarian_profile.archetype = NPCKnowledgeProfile.Archetype.SCHOLAR
	librarian_profile.personality_traits = ["meticulous", "knowledgeable", "quiet", "helpful"]
	librarian_profile.knowledge_tags = ["books", "history", "magic_theory", "archive", "restricted_texts"]
	librarian_profile.base_disposition = 55
	librarian_profile.speech_style = "formal"
	librarian.npc_profile = librarian_profile

	# === APPRENTICES (Study Alcoves) ===
	var apprentice1_pos: Vector3 = npc_positions.get_node("Apprentice1").global_position
	CivilianNPC.spawn_woman(npc_container, apprentice1_pos, ZONE_ID)

	var apprentice2_pos: Vector3 = npc_positions.get_node("Apprentice2").global_position
	CivilianNPC.spawn_man(npc_container, apprentice2_pos, ZONE_ID)

	# === APPRENTICE IN MAIN LIBRARY ===
	var apprentice3_pos: Vector3 = npc_positions.get_node("Apprentice3").global_position
	CivilianNPC.spawn_woman(npc_container, apprentice3_pos, ZONE_ID)


## Setup interactable objects
func _setup_interactables() -> void:
	var interactables := $Interactables

	# Librarian desk position - could be used for book lookup system
	var desk_pos := interactables.get_node_or_null("LibrarianDesk")
	if desk_pos:
		# TODO: Implement book catalog/research system
		pass


## Check if player has access to restricted archive
func has_restricted_access() -> bool:
	# TODO: Check Arcane Circle guild rank or quest progress
	return false


## Check if player has access to Archmage's chamber
func has_archmage_access() -> bool:
	# TODO: Check Arcane Circle guild rank (high rank required)
	return false


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name.to_lower() == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	return spawn_points.get_node_or_null("DefaultSpawn")
