## larton.gd - Larton Port Town (Starving Port Town)
## A once-thriving port town now starving due to the ghost pirate blockade
## No supplies can reach them by sea, and the land route through Kazer-Dun is blocked by goblins
## Few guards remain, most having abandoned their posts or fled
##
## Key NPCs:
## - Harbor Master (for return trips)
## - Mayor Aldric (quest giver - ghost pirate investigation)
## - Old Fisherman Torben (knows about the Pirate Stronghold location)
## - Few desperate civilians
extends Node3D

const ZONE_ID := "larton"
const ZONE_SIZE := Vector2(100.0, 100.0)  # Smaller than Dalhurst - a struggling town
const TOWN_AMBIENT_PATH := "res://assets/audio/Ambiance/cities/port_city_1.wav"  # Use same as Dalhurst for now

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	var is_main_scene: bool = get_node_or_null("Player") != null

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)
			# Mark as discovered
			PlayerGPS.discover_location(ZONE_ID)
		_setup_day_night_cycle()
		DayNightCycle.add_to_level(self)
		# Quieter ambient - town is nearly deserted
		AudioManager.play_ambient(TOWN_AMBIENT_PATH)
		AudioManager.play_zone_music("village")

	_setup_spawn_point_metadata()
	_setup_navigation()
	_spawn_npcs()
	_spawn_environment()
	_setup_cell_streaming()


## Setup spawn point metadata
func _setup_spawn_point_metadata() -> void:
	var spawn_points := get_node_or_null("SpawnPoints")
	if not spawn_points:
		return
	for child in spawn_points.get_children():
		child.set_meta("spawn_id", child.name)


## Setup navigation mesh for NPCs
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = get_node_or_null("NavigationRegion3D")

	if not nav_region:
		# Create navigation region if it doesn't exist
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


## Setup day/night cycle
func _setup_day_night_cycle() -> void:
	pass


## Setup cell streaming
func _setup_cell_streaming() -> void:
	var player: Node = get_node_or_null("Player")
	if not player:
		return

	if not CellStreamer:
		push_warning("[%s] CellStreamer not found" % ZONE_ID)
		return

	var my_coords: Vector2i = WorldGrid.get_location_coords(ZONE_ID)
	CellStreamer.register_main_scene_cell(my_coords, self)
	CellStreamer.start_streaming(my_coords)


## Spawn NPCs
func _spawn_npcs() -> void:
	var npcs_container: Node3D = get_node_or_null("NPCs")
	if not npcs_container:
		npcs_container = Node3D.new()
		npcs_container.name = "NPCs"
		add_child(npcs_container)

	# === HARBOR MASTER (Return Trip NPC) ===
	var harbor_master := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-35, 0, 40),  # Near the harbor
		"Harbor Master Giles",
		"harbor_master_larton",
		null,
		8, 2,
		[],  # No quests - uses dialogue for boat travel
		false
	)
	harbor_master.region_id = ZONE_ID
	harbor_master.faction_id = "human_empire"
	# Load boat travel dialogue - create a basic one inline
	var harbor_profile := NPCKnowledgeProfile.new()
	harbor_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	harbor_profile.personality_traits = ["weary", "desperate", "hopeful"]
	harbor_profile.knowledge_tags = ["larton", "harbor", "ships", "ghost_pirates", "dalhurst", "blockade"]
	harbor_profile.base_disposition = 50
	harbor_profile.speech_style = "informal"
	harbor_master.npc_profile = harbor_profile
	# Load return trip dialogue from JSON
	var harbor_dialogue: DialogueData = DialogueLoader.load_from_json("res://data/dialogue/harbor_master_larton.json")
	if harbor_dialogue:
		harbor_master.dialogue_data = harbor_dialogue
		harbor_master.use_legacy_dialogue = false
	else:
		push_warning("[Larton] Failed to load Harbor Master dialogue")

	# === MAYOR ALDRIC (Main Quest Giver) ===
	var mayor_quests: Array[String] = ["ghost_pirate_investigation"]
	var mayor := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(10, 0, -10),  # Near town center
		"Mayor Aldric",
		"mayor_aldric_larton",
		null,
		8, 2,
		mayor_quests
	)
	mayor.region_id = ZONE_ID
	mayor.faction_id = "human_empire"
	mayor.no_quest_dialogue = "Thank the gods someone made it through! Our town is dying... the ghost pirates have blockaded us completely."
	var mayor_profile := NPCKnowledgeProfile.new()
	mayor_profile.archetype = NPCKnowledgeProfile.Archetype.SCHOLAR
	mayor_profile.personality_traits = ["worried", "desperate", "determined"]
	mayor_profile.knowledge_tags = ["larton", "politics", "ghost_pirates", "blockade", "starvation", "kazer_dun", "goblins"]
	mayor_profile.base_disposition = 70  # Very friendly to anyone who arrives
	mayor_profile.speech_style = "formal"
	mayor.npc_profile = mayor_profile

	# === OLD FISHERMAN TORBEN (Information about Pirate Stronghold) ===
	var fisherman := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-25, 0, 35),  # By the docks
		"Old Torben",
		"fisherman_torben_larton",
		null,
		8, 2,
		[],  # No quests, just information
		true  # is_talk_target
	)
	fisherman.region_id = ZONE_ID
	fisherman.faction_id = "human_empire"
	fisherman.no_quest_dialogue = "I've seen the ghost ships... they come from an island fortress in the bay. Few who've gone there have returned."
	var fisherman_profile := NPCKnowledgeProfile.new()
	fisherman_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	fisherman_profile.personality_traits = ["old", "weary", "knowledgeable", "superstitious"]
	fisherman_profile.knowledge_tags = ["larton", "fishing", "sea", "ghost_pirates", "pirate_stronghold", "bay"]
	fisherman_profile.base_disposition = 55
	fisherman_profile.speech_style = "informal"
	fisherman.npc_profile = fisherman_profile

	# === SINGLE GUARD (Demoralized) ===
	var guard := GuardNPC.spawn_guard(
		npcs_container,
		Vector3(0, 0, 30),  # Main entrance
		[],  # No patrol
		ZONE_ID
	)
	guard.npc_id = "guard_larton_0"

	# === FEW STARVING CIVILIANS ===
	var civilian_positions: Array[Vector3] = [
		Vector3(5, 0, 5),
		Vector3(-10, 0, 0),
		Vector3(15, 0, -5),
	]
	for i: int in range(civilian_positions.size()):
		var civilian: CivilianNPC = CivilianNPC.spawn_man(npcs_container, civilian_positions[i], ZONE_ID)
		civilian.npc_id = "beggar_larton_%d" % i
		civilian.npc_name = "Starving Villager"
		var civ_profile := NPCKnowledgeProfile.new()
		civ_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
		civ_profile.personality_traits = ["hungry", "desperate", "scared"]
		civ_profile.knowledge_tags = ["larton", "starvation", "ghost_pirates"]
		civ_profile.base_disposition = 40  # Suspicious of strangers
		civilian.knowledge_profile = civ_profile


## Spawn environmental elements
func _spawn_environment() -> void:
	# Check if we already have terrain
	if get_node_or_null("Terrain"):
		return

	# Create basic ground plane
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(100, 1, 100)
	ground.position = Vector3(0, -0.5, 0)
	ground.use_collision = true

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.3, 0.25)  # Dusty brown - bleak atmosphere
	ground.material = ground_mat
	add_child(ground)

	# Create basic ocean plane (to the north/west - water side)
	var ocean := CSGBox3D.new()
	ocean.name = "Ocean"
	ocean.size = Vector3(200, 1, 100)
	ocean.position = Vector3(-100, -1, 50)
	ocean.use_collision = false

	var ocean_mat := StandardMaterial3D.new()
	ocean_mat.albedo_color = Color(0.1, 0.2, 0.35)  # Dark water
	ocean.material = ocean_mat
	add_child(ocean)

	# Simple dock structure
	var dock := CSGBox3D.new()
	dock.name = "Dock"
	dock.size = Vector3(30, 0.5, 8)
	dock.position = Vector3(-35, 0.25, 40)
	dock.use_collision = true

	var dock_mat := StandardMaterial3D.new()
	dock_mat.albedo_color = Color(0.4, 0.28, 0.16)  # Wooden dock
	dock.material = dock_mat
	add_child(dock)

	# Few rundown buildings (represented as simple boxes)
	var building_positions: Array[Vector3] = [
		Vector3(10, 2, -10),   # Mayor's house (center)
		Vector3(-15, 1.5, 10), # Abandoned shop
		Vector3(20, 1.5, 5),   # Abandoned home
		Vector3(-5, 2, -20),   # Tavern (closed)
	]
	var building_sizes: Array[Vector3] = [
		Vector3(12, 4, 10),
		Vector3(8, 3, 6),
		Vector3(7, 3, 7),
		Vector3(10, 4, 8),
	]

	for i in range(building_positions.size()):
		var building := CSGBox3D.new()
		building.name = "Building_%d" % i
		building.size = building_sizes[i]
		building.position = building_positions[i]
		building.use_collision = true

		var building_mat := StandardMaterial3D.new()
		building_mat.albedo_color = Color(0.45, 0.38, 0.32)  # Weathered gray-brown
		building.material = building_mat
		add_child(building)
