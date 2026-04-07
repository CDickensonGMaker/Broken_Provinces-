## larton.gd - Larton Port Town (Post-Apocalyptic Fishing Town)
## A once-thriving port town now in ruins. Ghost pirates blockade the harbor,
## bandits have occupied the warehouses, and survivors hide in a fortified building.
## Dark, desperate, PS1 horror vibes - blood, bodies, few lights.
##
## Key NPCs:
## - Mayor Aldric (quest giver - ghost_pirate_investigation, larton_famine, retake_harbor)
## - Captain Harken (guard leader at survivor hideout)
## - Old Salt Willem (fisherman - knows ghost ship location)
## - 5 Survivors (generic civilians in hideout)
## - 8 Bandits (hostile, in occupied warehouse and streets)
extends Node3D

const ZONE_ID := "larton"
const ZONE_SIZE := Vector2(100.0, 100.0)  # Smaller than Dalhurst - a struggling town
const TOWN_AMBIENT_PATH := "res://assets/audio/Ambiance/cities/port_city_1.wav"  # Use same as Dalhurst for now

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true

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


## Spawn NPCs - Post-apocalyptic survivors and hostile bandits
func _spawn_npcs() -> void:
	var npcs_container: Node3D = get_node_or_null("NPCs")
	if not npcs_container:
		npcs_container = Node3D.new()
		npcs_container.name = "NPCs"
		add_child(npcs_container)

	# === MAYOR ALDRIC (Main Quest Giver - in survivor hideout) ===
	var mayor_quests: Array[String] = ["ghost_pirate_investigation", "retake_harbor"]
	var mayor := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(20, 0.5, -8),  # Inside survivor hideout
		"Mayor Aldric",
		"mayor_aldric_larton",
		preload("res://assets/sprites/npcs/civilians/man_noble1.png"),
		1, 1,
		mayor_quests
	)
	mayor.region_id = ZONE_ID
	mayor.faction_id = "human_empire"
	mayor.no_quest_dialogue = "Thank the gods someone made it through! Our town is dying... bandits have taken the warehouses, and the ghost pirates still blockade us."
	var mayor_profile := NPCKnowledgeProfile.new()
	mayor_profile.archetype = NPCKnowledgeProfile.Archetype.SCHOLAR
	mayor_profile.personality_traits = ["worried", "desperate", "determined", "haunted"]
	mayor_profile.knowledge_tags = ["larton", "politics", "ghost_pirates", "blockade", "starvation", "bandits", "survivors"]
	mayor_profile.base_disposition = 70
	mayor_profile.speech_style = "formal"
	mayor.npc_profile = mayor_profile

	# === CAPTAIN HARKEN (Guard Leader - at survivor hideout barricade) ===
	var harken := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(14, 0.5, -6),  # At the barricade
		"Captain Harken",
		"captain_harken",
		preload("res://assets/sprites/npcs/civilians/guard_civilian.png"),
		1, 1,
		[],  # No quests - turn-in target for retake_harbor
		true  # is_talk_target
	)
	harken.region_id = ZONE_ID
	harken.faction_id = "human_empire"
	harken.no_quest_dialogue = "Hold your ground. We've lost too many already. If you're here to help, speak to the Mayor."
	var harken_profile := NPCKnowledgeProfile.new()
	harken_profile.archetype = NPCKnowledgeProfile.Archetype.GUARD
	harken_profile.personality_traits = ["grim", "determined", "protective", "exhausted"]
	harken_profile.knowledge_tags = ["larton", "combat", "bandits", "defenses", "ghost_pirates", "survivors"]
	harken_profile.base_disposition = 45
	harken_profile.speech_style = "military"
	harken.npc_profile = harken_profile

	# === OLD SALT WILLEM (Fisherman - knows ghost ship location) ===
	var willem := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-42, 0.3, 40),  # Near the rotting docks
		"Old Willem",
		"old_salt_willem",
		preload("res://assets/sprites/npcs/civilians/guy_civilian1.png"),
		1, 1,
		[],  # No quests - just information
		true  # is_talk_target
	)
	willem.region_id = ZONE_ID
	willem.faction_id = "human_empire"
	willem.no_quest_dialogue = "I've seen the ghost ships... spectral lights in the fog, screams of drowned sailors. They come from an island fortress in the bay. Few who've gone there have returned."
	var willem_profile := NPCKnowledgeProfile.new()
	willem_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	willem_profile.personality_traits = ["old", "weary", "knowledgeable", "superstitious", "half_mad"]
	willem_profile.knowledge_tags = ["larton", "fishing", "sea", "ghost_pirates", "ghost_ship", "pirate_stronghold", "bay"]
	willem_profile.base_disposition = 55
	willem_profile.speech_style = "informal"
	willem.npc_profile = willem_profile

	# === LARTON ELDER (at town center - remaining authority figure) ===
	var larton_elder := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(15, 0.5, -5),  # Near town center
		"Elder Thorne",
		"larton_elder",
		null, 8, 2,
		[],  # Quests handled by Mayor Aldric
		true  # is_talk_target
	)
	larton_elder.region_id = ZONE_ID
	larton_elder.faction_id = "human_empire"
	larton_elder.no_quest_dialogue = "I've watched this town fall apart... first the ghost pirates, then the bandits. The Mayor does what he can, but we're running out of time and food."
	var elder_profile := NPCKnowledgeProfile.new()
	elder_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	elder_profile.personality_traits = ["weary", "wise", "despairing", "protective"]
	elder_profile.knowledge_tags = ["larton", "history", "ghost_pirates", "bandits", "starvation"]
	elder_profile.base_disposition = 50
	elder_profile.speech_style = "formal"
	larton_elder.npc_profile = elder_profile

	# === LARTON FISHERMAN (at docks - one of few still trying to fish) ===
	var larton_fisherman := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-38, 0.3, 35),  # Near the dock area
		"Hardy Fisherman",
		"larton_fisherman",
		null, 8, 2,
		[], true
	)
	larton_fisherman.region_id = ZONE_ID
	larton_fisherman.faction_id = "human_empire"
	larton_fisherman.no_quest_dialogue = "Can't fish if ghost ships sink your boat. Can't sell fish if bandits steal your catch. But I keep trying... what else is there?"
	var lfisher_profile := NPCKnowledgeProfile.new()
	lfisher_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	lfisher_profile.personality_traits = ["stubborn", "practical", "desperate"]
	lfisher_profile.knowledge_tags = ["larton", "fishing", "harbor", "ghost_pirates"]
	lfisher_profile.base_disposition = 45
	larton_fisherman.npc_profile = lfisher_profile

	# === LARTON SAILOR (at harbor - trapped by the blockade) ===
	var larton_sailor := QuestGiver.spawn_quest_giver(
		npcs_container,
		Vector3(-40, 0.3, 45),  # Harbor area
		"Stranded Sailor",
		"larton_sailor",
		null, 8, 2,
		[], true
	)
	larton_sailor.region_id = ZONE_ID
	larton_sailor.faction_id = "human_empire"
	larton_sailor.no_quest_dialogue = "My ship's been stuck in port for weeks. The captain won't risk the blockade... those ghost ships, they come out of nowhere. One moment clear seas, the next... screaming and fire."
	var lsailor_profile := NPCKnowledgeProfile.new()
	lsailor_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	lsailor_profile.personality_traits = ["frustrated", "scared", "knowledgeable"]
	lsailor_profile.knowledge_tags = ["larton", "ships", "harbor", "ghost_pirates", "blockade"]
	lsailor_profile.base_disposition = 40
	larton_sailor.npc_profile = lsailor_profile

	# === SURVIVOR GUARDS AT HIDEOUT (2 guards) ===
	var guard_1 := GuardNPC.spawn_guard(
		npcs_container,
		Vector3(12, 0.5, -8),  # Left barricade
		[],
		ZONE_ID
	)
	guard_1.npc_id = "guard_larton_survivor_1"
	guard_1.npc_name = "Battered Guard"

	var guard_2 := GuardNPC.spawn_guard(
		npcs_container,
		Vector3(28, 0.5, -8),  # Right barricade
		[],
		ZONE_ID
	)
	guard_2.npc_id = "guard_larton_survivor_2"
	guard_2.npc_name = "Exhausted Guard"

	# === 5 SURVIVORS IN HIDEOUT ===
	var survivor_configs: Array[Dictionary] = [
		{"pos": Vector3(18, 0.5, -12), "name": "Starving Survivor", "gender": "male"},
		{"pos": Vector3(22, 0.5, -14), "name": "Frightened Woman", "gender": "female"},
		{"pos": Vector3(16, 0.5, -10), "name": "Desperate Fisherman", "gender": "male"},
		{"pos": Vector3(24, 0.5, -12), "name": "Weeping Widow", "gender": "female"},
		{"pos": Vector3(20, 0.5, -16), "name": "Wounded Dockworker", "gender": "male"},
	]
	for i: int in range(survivor_configs.size()):
		var cfg: Dictionary = survivor_configs[i]
		var survivor: CivilianNPC
		if cfg["gender"] == "male":
			survivor = CivilianNPC.spawn_man(npcs_container, cfg["pos"], ZONE_ID)
		else:
			survivor = CivilianNPC.spawn_woman(npcs_container, cfg["pos"], ZONE_ID)
		survivor.npc_id = "survivor_larton_%d" % i
		survivor.npc_name = cfg["name"]
		var surv_profile := NPCKnowledgeProfile.new()
		surv_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
		surv_profile.personality_traits = ["hungry", "desperate", "scared", "traumatized"]
		surv_profile.knowledge_tags = ["larton", "starvation", "ghost_pirates", "bandits", "horror"]
		surv_profile.base_disposition = 40
		survivor.knowledge_profile = surv_profile

	# === 8 HOSTILE BANDITS ===
	_spawn_bandits(npcs_container)


## Spawn hostile bandits occupying the town
func _spawn_bandits(parent: Node3D) -> void:
	var bandit_data_path := "res://data/enemies/human_bandit.tres"
	var bandit_captain_path := "res://data/enemies/bandit_captain.tres"
	var bandit_sprite: Texture2D = preload("res://assets/sprites/enemies/humanoid/human_bandit_alt.png")

	# Bandit positions - warehouse and streets
	var bandit_positions: Array[Vector3] = [
		Vector3(-20, 0.5, 42),   # Patrol near warehouse
		Vector3(-25, 0.5, 45),   # Patrol near warehouse
		Vector3(-22, 0.5, 52),   # Guard at warehouse entrance
		Vector3(-18, 0.5, 52),   # Guard at warehouse entrance
		Vector3(-22, 0.5, 48),   # Inside warehouse
		Vector3(-20, 0.5, 48),   # Inside warehouse
		Vector3(-5, 0.5, 25),    # Street patrol
	]

	for i: int in range(bandit_positions.size()):
		var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
			parent,
			bandit_positions[i],
			bandit_data_path,
			bandit_sprite,
			1, 1
		)
		if enemy:
			enemy.add_to_group("enemies")
			enemy.add_to_group("bandits_larton")

	# Spawn bandit lieutenant (mini-boss) in warehouse
	var lieutenant: EnemyBase = EnemyBase.spawn_billboard_enemy(
		parent,
		Vector3(-22, 0.5, 50),
		bandit_captain_path,
		bandit_sprite,
		1, 1
	)
	if lieutenant:
		lieutenant.add_to_group("enemies")
		lieutenant.add_to_group("bandits_larton")
		lieutenant.add_to_group("boss")


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
