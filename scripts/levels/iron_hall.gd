## iron_hall.gd - Iron Hall (Iron Company Mercenary Guild Headquarters)
## Interior guild hall with barracks, training area, contract board, and Captain's office
## Hub for mercenary contracts and combat-focused quests
##
## NOTE: All static geometry is defined in iron_hall.tscn
## This script handles runtime setup: NPCs, navigation, interactables
extends Node3D

const ZONE_ID := "guild_iron_hall"
const ZONE_NAME := "Iron Hall - Mercenary Guild"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)

	# Play guild interior ambiance (only when main scene)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		AudioManager.play_zone_ambiance("interior")
		AudioManager.play_zone_music("town")

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
			"RETURN_TO_PREVIOUS",  # Configured at runtime based on entry point
			"from_iron_hall",
			"Exit to City",
			true
		)
		exit_door.return_to_previous = true


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		push_warning("[Iron Hall] NavigationRegion3D not found")
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

	# === CAPTAIN RODERICK STEELE (Guild Master) ===
	var captain_pos: Vector3 = npc_positions.get_node("CaptainSteele").global_position
	var captain := QuestGiver.spawn_quest_giver(
		npc_container,
		captain_pos,
		"Captain Roderick Steele",
		"captain_steele",
		preload("res://assets/sprites/npcs/civilians/man_noble1.png"),
		1, 1,
		[],  # Quest IDs to be added when guild quests are implemented
		false
	)
	captain.region_id = ZONE_ID
	captain.faction_id = "iron_company"
	captain.no_quest_dialogue = "The Iron Company always needs capable fighters. Come back when you're ready for work, mercenary."
	var captain_profile := NPCKnowledgeProfile.new()
	captain_profile.archetype = NPCKnowledgeProfile.Archetype.GUARD
	captain_profile.personality_traits = ["stern", "honorable", "disciplined", "veteran"]
	captain_profile.knowledge_tags = ["iron_company", "mercenary_work", "combat", "contracts", "military"]
	captain_profile.base_disposition = 50
	captain_profile.speech_style = "military"
	captain.npc_profile = captain_profile

	# === CONTRACT CLERK ===
	var clerk_pos: Vector3 = npc_positions.get_node("ContractClerk").global_position
	var clerk := QuestGiver.spawn_quest_giver(
		npc_container,
		clerk_pos,
		"Contract Clerk",
		"iron_hall_clerk",
		preload("res://assets/sprites/npcs/civilians/man_civilian.png"),
		1, 1,
		[],
		false
	)
	clerk.region_id = ZONE_ID
	clerk.faction_id = "iron_company"
	clerk.no_quest_dialogue = "Check the contract board for available work. I handle the paperwork."
	var clerk_profile := NPCKnowledgeProfile.new()
	clerk_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	clerk_profile.personality_traits = ["efficient", "bureaucratic", "neutral"]
	clerk_profile.knowledge_tags = ["contracts", "bounties", "iron_company", "payments"]
	clerk_profile.base_disposition = 55
	clerk_profile.speech_style = "formal"
	clerk.npc_profile = clerk_profile

	# === MERCENARY RECRUITS (Training Area) ===
	var recruit1_pos: Vector3 = npc_positions.get_node("Recruit1").global_position
	CivilianNPC.spawn_man(npc_container, recruit1_pos, ZONE_ID)

	var recruit2_pos: Vector3 = npc_positions.get_node("Recruit2").global_position
	CivilianNPC.spawn_man(npc_container, recruit2_pos, ZONE_ID)

	# === RECRUIT IN BARRACKS ===
	var recruit3_pos: Vector3 = npc_positions.get_node("Recruit3").global_position
	CivilianNPC.spawn_man(npc_container, recruit3_pos, ZONE_ID)


## Setup interactable objects (contract board, etc.)
func _setup_interactables() -> void:
	var interactables := $Interactables

	# Contract board position - could spawn a bounty board here
	var board_pos := interactables.get_node_or_null("ContractBoardPosition")
	if board_pos:
		# TODO: Spawn a guild-specific contract board when implemented
		# For now, the visual board is in the scene geometry
		pass


## Get spawn point for scene transitions
func get_spawn_point(spawn_id: String) -> Node3D:
	var spawn_points := $SpawnPoints
	for child in spawn_points.get_children():
		if child.name.to_lower() == spawn_id or child.get_meta("spawn_id", "") == spawn_id:
			return child
	return spawn_points.get_node_or_null("DefaultSpawn")
