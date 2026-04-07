## kazan_dun_entrance.gd - Grand Entrance Hall of Kazan-Dun
## Massive stone entrance carved into the mountain (100x80 units)
## Contains guard posts, reception area, fast travel shrine
## Connects to: road_leading_up, Level_1, Back_Entrance (locked initially)
extends Node3D

const ZONE_ID := "kazan_dun_entrance"
const ZONE_SIZE_X := 100.0
const ZONE_SIZE_Z := 80.0

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D
@onready var npcs_node: Node3D = $NPCs


func _ready() -> void:
	_setup_navigation()
	_setup_spawn_point_metadata()
	_spawn_dwarf_npcs()
	_setup_cell_streaming()


## Setup navigation mesh for NPC pathfinding
func _setup_navigation() -> void:
	if not nav_region:
		push_warning("[Kazan-Dun Entrance] NavigationRegion3D not found in scene")
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


## Add metadata to spawn points for proper identification
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child in spawn_points.get_children():
		if child.is_in_group("spawn_points"):
			child.set_meta("spawn_id", child.name)


## Spawn dwarf NPCs in the entrance hall
func _spawn_dwarf_npcs() -> void:
	if not npcs_node:
		npcs_node = Node3D.new()
		npcs_node.name = "NPCs"
		add_child(npcs_node)

	# Guards at the guard posts (left and right of entrance)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-20, 0.5, 25), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(20, 0.5, 25), ZONE_ID)

	# Guards flanking the inner door
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(-8, 0, -35), ZONE_ID)
	CivilianNPC.spawn_dwarf_guard(npcs_node, Vector3(8, 0, -35), ZONE_ID)

	# Reception desk attendant
	CivilianNPC.spawn_dwarf_civilian(npcs_node, Vector3(0, 0, -3), ZONE_ID)

	# Wandering dwarves in the hall
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(-15, 0, 0), ZONE_ID)
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(15, 0, 10), ZONE_ID)
	CivilianNPC.spawn_dwarf_random(npcs_node, Vector3(-25, 0, -15), ZONE_ID)

	# === DWARF GATE WARDEN (at main gate entrance) ===
	var warden_pos := Vector3(0, 0.5, 30)  # At the main entrance gate
	var gate_warden := QuestGiver.spawn_quest_giver(
		self,
		warden_pos,
		"Gate Warden Borik",
		"dwarf_gate_warden",
		null, 8, 2,
		[],  # Quest IDs to be added later
		false
	)
	gate_warden.region_id = ZONE_ID
	gate_warden.faction_id = "dwarves"
	gate_warden.no_quest_dialogue = "Welcome to Kazan-Dun, outsider. The gates of our hold have stood for a thousand years, and they'll stand a thousand more. Conduct yourself with honor here, and you'll find no finer allies than the dwarves. Cause trouble... and the mountain itself will swallow you."
	var warden_profile := NPCKnowledgeProfile.new()
	warden_profile.archetype = NPCKnowledgeProfile.Archetype.GUARD
	warden_profile.personality_traits = ["stern", "honorable", "traditional", "watchful"]
	warden_profile.knowledge_tags = ["dwarves", "kazan_dun", "gate_security", "visitors", "dwarf_law"]
	warden_profile.base_disposition = 35  # Cautious with outsiders
	warden_profile.speech_style = "formal"
	gate_warden.npc_profile = warden_profile


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

	# Use WorldGrid location_id (note: WorldGrid uses "kazer" spelling)
	var my_coords: Vector2i = WorldGrid.get_location_coords("kazer_dun_entrance")
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)
