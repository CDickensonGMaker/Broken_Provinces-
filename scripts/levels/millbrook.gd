## millbrook.gd - Mill Brook Hamlet
## Simple farming/milling hamlet between Dalhurst and Kazan-Dun
## Runtime-only logic - geometry is pre-placed in millbrook.tscn
extends Node3D

const ZONE_ID := "millbrook"
const ZONE_SIZE := 100.0  # Matches WorldGrid.CELL_SIZE
const TOWN_AMBIENT_PATH := "res://assets/audio/ambience/towns/town_murmur_medieval_mix_60s_ps1_retro.wav"

@onready var nav_region: NavigationRegion3D = $NavigationRegion3D


func _ready() -> void:
	# Only register with PlayerGPS if we're the main scene (have Player node)
	# When loaded as a streaming cell, Player is stripped - don't touch GPS
	var is_main_scene: bool = false
	var _player_check: Node = get_node_or_null("Player")
	if _player_check and is_instance_valid(_player_check) and not _player_check.is_queued_for_deletion():
		is_main_scene = true

	if is_main_scene:
		if PlayerGPS:
			var coords := WorldGrid.get_location_coords(ZONE_ID)
			PlayerGPS.set_position(coords)
		SaveManager.set_current_zone(ZONE_ID, "Mill Brook")
		DayNightCycle.add_to_level(self)
		# Play town ambient sound and village music
		AudioManager.play_ambient(TOWN_AMBIENT_PATH)
		AudioManager.play_zone_music("village")

	_setup_spawn_points()
	_spawn_merchants()
	_spawn_npcs()
	_spawn_residents()
	_spawn_fast_travel_shrine()
	_spawn_rest_spot()
	_spawn_locked_doors()
	_spawn_road_east()
	_setup_navigation()
	_setup_cell_streaming()


## Register pre-placed spawn points with groups and metadata
func _setup_spawn_points() -> void:
	var spawn_points_node: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points_node:
		return

	for child in spawn_points_node.get_children():
		if child is Marker3D:
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.add_to_group("spawn_points")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Spawn merchants at NPC marker positions
func _spawn_merchants() -> void:
	var merchant_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_Merchant")
	var pos: Vector3 = merchant_marker.global_position if merchant_marker else Vector3(3, 0, 6)

	Merchant.spawn_merchant(
		self,
		pos,
		"Hamlet General Store",
		LootTables.LootTier.COMMON,
		"general"
	)


## Spawn NPCs at marker positions
func _spawn_npcs() -> void:
	# Miller NPC (near the water mill)
	var miller_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_MillerOswin")
	var miller_pos: Vector3 = miller_marker.global_position if miller_marker else Vector3(-5, 0, -10)

	var miller := QuestGiver.new()
	miller.display_name = "Miller Oswin"
	miller.npc_id = "miller_oswin"
	miller.quest_ids = []
	miller.faction_id = "human_empire"
	miller.no_quest_dialogue = "Welcome to Mill Brook, traveler.\nOur mill grinds grain for the whole region.\nThe brook has powered this wheel for generations."
	miller.position = miller_pos
	add_child(miller)

	# Farmer NPC
	var farmer_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_FarmerEdda")
	var farmer_pos: Vector3 = farmer_marker.global_position if farmer_marker else Vector3(12, 0, 8)

	var farmer := QuestGiver.new()
	farmer.display_name = "Farmer Edda"
	farmer.npc_id = "farmer_edda"
	farmer.quest_ids = []
	farmer.faction_id = "human_empire"
	farmer.no_quest_dialogue = "The harvest has been good this year.\nGaela blesses these fields.\nWe send our grain to Dalhurst and the capital."
	farmer.position = farmer_pos
	add_child(farmer)

	# Millbrook Elder - Quest giver for millbrook_bandits quest
	var elder_marker: Marker3D = get_node_or_null("NPCSpawnPoints/NPC_MillbrookElder")
	var elder_pos: Vector3 = elder_marker.global_position if elder_marker else Vector3(0, 0, 10)

	var elder_quests: Array[String] = ["millbrook_bandits"]
	var elder := QuestGiver.spawn_quest_giver(
		self,
		elder_pos,
		"Elder Bram",
		"millbrook_elder",
		null,  # use default sprite
		8, 2,  # h_frames, v_frames
		elder_quests
	)
	elder.region_id = ZONE_ID
	elder.faction_id = "millbrook"
	elder.no_quest_dialogue = "You've done a great service for our hamlet.\nMay Gaela bless your travels, stranger."
	# The elder offers and takes back the flagship five different ways, so he
	# needs a real tree rather than the generic offer/turn-in cards.
	var elder_dialogue: DialogueData = DialogueLoader.get_dialogue("res://data/dialogue/trees/millbrook_elder.json")
	if elder_dialogue:
		elder.dialogue_data = elder_dialogue
		elder.use_legacy_dialogue = false
	else:
		push_warning("[Millbrook] Failed to load the elder's dialogue")

	# Victim NPCs for millbrook_bandits quest (speak_victims objective)
	# Victim 1 - near the farmhouses
	var victim1_pos := Vector3(10, 0, 2)
	var victim1 := QuestGiver.spawn_quest_giver(
		self,
		victim1_pos,
		"Frightened Farmer",
		"millbrook_victim",
		null, 8, 2, []  # No quests, just a talk target
	)
	victim1.region_id = ZONE_ID
	victim1.faction_id = "human_empire"
	victim1.npc_type = "millbrook_victim"  # For quest objective matching
	victim1.no_quest_dialogue = "Those bandits took everything!\nThey came at dawn, armed and dangerous.\nThey headed into the woods to the east."

	# Victim 2 - near the mill
	var victim2_pos := Vector3(-10, 0, -5)
	var victim2 := QuestGiver.spawn_quest_giver(
		self,
		victim2_pos,
		"Shaken Villager",
		"millbrook_victim_2",
		null, 8, 2, []  # No quests, just a talk target
	)
	victim2.region_id = ZONE_ID
	victim2.faction_id = "human_empire"
	victim2.npc_type = "millbrook_victim"  # Same type for quest counting
	victim2.no_quest_dialogue = "I saw the bandit captain - scarred face, black cloak.\nThey've made camp somewhere in the eastern woods.\nPlease, someone has to stop them!"

	# === MILLBROOK FISHERMAN (at lake shore) ===
	var fisherman_pos := Vector3(-15, 0, -15)  # Near the lake/mill brook
	var millbrook_fisherman := QuestGiver.spawn_quest_giver(
		self,
		fisherman_pos,
		"Old Finn",
		"millbrook_fisherman",
		null, 8, 2,
		[],  # Quest IDs to be added later
		true  # is_talk_target
	)
	millbrook_fisherman.region_id = ZONE_ID
	millbrook_fisherman.faction_id = "human_empire"
	millbrook_fisherman.no_quest_dialogue = "The fish ain't biting like they used to. Something's stirring in the deep waters... I've seen shadows moving beneath the surface. Best stay away from the lake after dark."
	var fisherman_profile := NPCKnowledgeProfile.new()
	fisherman_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	fisherman_profile.personality_traits = ["superstitious", "weathered", "observant"]
	fisherman_profile.knowledge_tags = ["millbrook", "fishing", "lake", "local_area", "lake_creature"]
	fisherman_profile.base_disposition = 50
	fisherman_profile.speech_style = "casual"
	millbrook_fisherman.npc_profile = fisherman_profile

	# === MILLBROOK KEEPER CONTACT (in tavern area) ===
	var keeper_pos := Vector3(5, 0, 15)  # Near the inn/tavern area
	var millbrook_keeper := QuestGiver.spawn_quest_giver(
		self,
		keeper_pos,
		"Quiet Traveler",
		"millbrook_keeper_contact",
		null, 8, 2,
		[],  # Quest IDs to be added later
		false
	)
	millbrook_keeper.region_id = ZONE_ID
	millbrook_keeper.faction_id = "keepers"
	millbrook_keeper.no_quest_dialogue = "Just passing through... like you, perhaps. This hamlet sees more traffic than you'd think. The roads between Dalhurst and the south bring all sorts."
	var keeper_profile := NPCKnowledgeProfile.new()
	keeper_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	keeper_profile.personality_traits = ["observant", "quiet", "mysterious"]
	keeper_profile.knowledge_tags = ["millbrook", "keepers", "roads", "travelers"]
	keeper_profile.base_disposition = 35  # Cautious
	keeper_profile.speech_style = "casual"
	millbrook_keeper.npc_profile = keeper_profile

	# === MAGISTRATE THORNBURY (fish_fraud giver and turn-in) ===
	var magistrate := QuestGiver.spawn_quest_giver(
		self,
		Vector3(8, 0, 4),  # Village centre, where disputes are heard
		"Magistrate Thornbury",
		"magistrate_millbrook",
		null, 8, 2,
		["fish_fraud"]
	)
	magistrate.region_id = ZONE_ID
	magistrate.faction_id = "human_empire"
	magistrate.no_quest_dialogue = "Millbrook is a small place. Small places still need the law kept straight."
	var magistrate_profile := NPCKnowledgeProfile.new()
	magistrate_profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	magistrate_profile.personality_traits = ["exacting", "impartial", "weary"]
	magistrate_profile.knowledge_tags = ["millbrook", "law", "trade", "local_area"]
	magistrate_profile.base_disposition = 45
	magistrate_profile.speech_style = "formal"
	magistrate.npc_profile = magistrate_profile

	# === HECTOR THE FISH MERCHANT (fish_fraud interview target) ===
	var hector := QuestGiver.spawn_quest_giver(
		self,
		Vector3(-11, 0, -12),  # The fish stalls by the water
		"Hector",
		"merchant_hector",
		null, 8, 2,
		[],
		true  # is_talk_target
	)
	hector.region_id = ZONE_ID
	hector.faction_id = "human_empire"
	hector.no_quest_dialogue = "The fishermen say I cheat them. The scales say otherwise. Weigh it yourself if you like."
	var hector_profile := NPCKnowledgeProfile.new()
	hector_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	hector_profile.personality_traits = ["defensive", "shrewd", "brusque"]
	hector_profile.knowledge_tags = ["millbrook", "fishing", "trade", "local_area"]
	hector_profile.base_disposition = 40
	hector_profile.speech_style = "casual"
	hector.npc_profile = hector_profile


## The residents whose roles the quest chains named but nobody had written.
## Mill Brook is a hamlet: everyone here does one job and everyone knows whose
## fault the last bad week was.
func _spawn_residents() -> void:
	# The market stall the thefts happen at
	Townsfolk.spawn_townsfolk(
		self, Vector3(7, 0, 6), "Greta Vance", "millbrook_merchant", ZONE_ID,
		"merchant_guild", NPCKnowledgeProfile.Archetype.MERCHANT,
		["blunt", "watchful", "unsentimental"],
		["millbrook", "trade", "market", "local_area"],
		"I lay the goods out, I count them in at dusk, and lately the two numbers disagree.",
		["market_theft_1"], false, 45)

	# The stallhand who saw the theft and would rather not have
	Townsfolk.spawn_townsfolk(
		self, Vector3(9, 0, 7), "Colm the Stallhand", "millbrook_witness", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER,
		["nervous", "young", "honest"],
		["millbrook", "market", "local_area"],
		"I saw who took it. I also have to stand at this stall tomorrow, so think on that before you use my name.",
		[], true, 40)

	# Gaela's shrine keeper. Mill Brook grinds grain and pulls fish; the god it
	# keeps a roof for is the one who decides whether there is any.
	Townsfolk.spawn_townsfolk(
		self, Vector3(2, 0, 13), "Sister Rowena Ash", "millbrook_priest", ZONE_ID,
		"church_of_gaela", NPCKnowledgeProfile.Archetype.PRIEST,
		["patient", "plain-spoken", "stubborn"],
		["millbrook", "gaela", "harvest", "rites", "local_area"],
		"Gaela's shrine here is one room and a threshing floor. It is enough. She was never a god who wanted marble.",
		["rescue_sacrifice_victim_1"], false, 55, "formal")

	# The herbwife. The shrine keeps the rites; she keeps the medicine.
	Townsfolk.spawn_townsfolk(
		self, Vector3(-2, 0, 12), "Sorcha Linn", "millbrook_healer", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER,
		["brisk", "practical", "tired"],
		["millbrook", "herbs", "medicine", "local_area"],
		"Sister Rowena prays over them and I boil something bitter. Between us they usually keep.",
		[], true, 55)

	# The pasture above the brook
	Townsfolk.spawn_townsfolk(
		self, Vector3(18, 0, -14), "Tavish Moor", "millbrook_shepherd", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.FARMER,
		["solitary", "weather-wise", "dry"],
		["millbrook", "pasture", "livestock", "wolves", "local_area"],
		"Forty-one head this morning. Forty-one is a good morning.",
		["gaela_bonus_shepherd_quest"], false, 45)

	# Yes, the hamlet has an inn. One room, four beds, and the only fire in
	# Mill Brook that anyone sits around after dark.
	Townsfolk.spawn_townsfolk(
		self, Vector3(4, 0, 16), "Hamish Roke", "millbrook_innkeeper", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.INNKEEPER,
		["talkative", "shrewd", "welcoming"],
		["millbrook", "innkeeper", "rumors", "travelers", "local_area"],
		"Four beds, and three of them are usually free. That means I hear everything the fourth one says.",
		[], true, 60)

	# Hector's accusers have a spokesman
	Townsfolk.spawn_townsfolk(
		self, Vector3(-13, 0, -13), "Eamon Quist", "head_fisherman_millbrook", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER,
		["gruff", "proud", "aggrieved"],
		["millbrook", "fishing", "lake", "trade", "local_area"],
		"Thirty years I have weighed fish. I know what a stone feels like in the hand, and Hector's is light.",
		[], true, 40)

	# Mill Brook's entire law, standing where the road comes in
	Townsfolk.spawn_townsfolk(
		self, Vector3(11, 0, 1), "Watch-Captain Ingram Vell", "guard_captain_millbrook", ZONE_ID,
		"town_guard", NPCKnowledgeProfile.Archetype.GUARD,
		["methodical", "underfunded", "unimpressed"],
		["millbrook", "law", "crime", "local_area"],
		"I am the watch. All of it. So when I say I have no time to chase this, understand it is arithmetic and not laziness.",
		[], true, 45, "formal")

	# Three griefs that used to share one id. They are three women.
	Townsfolk.spawn_townsfolk(
		self, Vector3(-4, 0, 9), "Widow Hild Marrow", "millbrook_widow", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER,
		["grieving", "precise", "private"],
		["millbrook", "local_area"],
		"It is a locket. It is not worth what you would charge to find it, and I am asking anyway.",
		["lost_locket_1"], false, 45)

	Townsfolk.spawn_townsfolk(
		self, Vector3(13, 0, 10), "Goodwife Anwen Fell", "millbrook_mother", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER,
		["frantic", "sleepless", "grateful"],
		["millbrook", "local_area"],
		"She went to the brook for water and she did not come back up the path. That is the whole of what I know.",
		[], true, 50)


	# The noble who hires the Iron Company. The war is over Mill Brook's mill
	# lands, which is why a hamlet has two houses arguing in it.
	Townsfolk.spawn_townsfolk(
		self, Vector3(6, 0, 3), "Lady Venetia Harrow", "noble_client", ZONE_ID,
		"nobility", NPCKnowledgeProfile.Archetype.NOBLE,
		["clipped", "ruthless", "courteous"],
		["millbrook", "nobility", "war", "mercenaries", "local_area"],
		"I am buying an outcome, not a battle. If your Captain can get me the outcome without the battle I will pay the same.",
		[], true, 40, "formal")

	# morthane_06's killer. He sells salt and he sold a man out.
	Townsfolk.spawn_townsfolk(
		self, Vector3(-8, 0, 3), "Dorn Vrell", "merchant_vrell", ZONE_ID,
		"merchant_guild", NPCKnowledgeProfile.Archetype.MERCHANT,
		["affable", "watchful", "rehearsed"],
		["millbrook", "trade", "local_area"],
		"Terrible business. He owed me, as it happens, but I am not the sort to bring that up now.",
		[], true, 45)

	# Chronos's charlatan number one. Thornfield has its own.
	Townsfolk.spawn_townsfolk(
		self, Vector3(0, 0, 18), "Brother Wendel Pyke", "false_prophet_millbrook", ZONE_ID,
		"common_folk", NPCKnowledgeProfile.Archetype.PRIEST,
		["theatrical", "plausible", "greedy"],
		["millbrook", "chronos", "prophecy", "local_area"],
		"I do not choose what I am shown. I only choose whether to warn you, and warning costs a candle.",
		[], true, 45, "formal")


## Spawn fast travel shrine at marker position
func _spawn_fast_travel_shrine() -> void:
	var shrine_marker: Marker3D = get_node_or_null("Interactables/FastTravelShrine")
	var pos: Vector3 = shrine_marker.global_position if shrine_marker else Vector3(5, 0, 2)

	FastTravelShrine.spawn_shrine(
		self,
		pos,
		"Mill Brook Shrine",
		"millbrook_shrine"
	)


## Spawn rest spot at marker position
func _spawn_rest_spot() -> void:
	var rest_marker: Marker3D = get_node_or_null("Interactables/RestSpot")
	var pos: Vector3 = rest_marker.global_position if rest_marker else Vector3(-2, 0, 8)

	RestSpot.spawn_rest_spot(self, pos, "Mill Brook Bench")


## Spawn locked doors from markers placed in the scene
## Add a Node3D container called "LockedDoors" with Marker3D children
## Set metadata on each marker: door_name (String), lock_dc (int)
func _spawn_locked_doors() -> void:
	var doors_container := get_node_or_null("LockedDoors")
	if not doors_container:
		return

	var doors_spawned: int = 0
	for marker in doors_container.get_children():
		if not marker is Marker3D:
			continue

		var door_name: String = marker.get_meta("door_name", "Locked Door")
		var lock_dc: int = marker.get_meta("lock_dc", 12)

		var door := LockableDoor.spawn_door(
			self,
			marker.global_position,
			door_name,
			lock_dc
		)
		door.rotation = marker.rotation
		doors_spawned += 1

	if doors_spawned > 0:
		pass


## The way to the crew's camp. Every victim in the hamlet says "the eastern
## woods" and until now there was nothing east to walk to.
func _spawn_road_east() -> void:
	var doors := Node3D.new()
	doors.name = "RoadEast"
	add_child(doors)

	ZoneDoor.spawn_door(
		doors,
		Vector3(26, 0, 4),
		"res://scenes/levels/millbrook_bandit_camp.tscn",
		"from_millbrook",
		"The cart track east",
		false
	)

	# The camp sends the player back here; give that arrival somewhere to land.
	var arrival := Marker3D.new()
	arrival.name = "SpawnPoint_from_bandit_camp"
	arrival.position = Vector3(23, 0, 4)
	arrival.add_to_group("spawn_points")
	arrival.set_meta("spawn_id", "from_bandit_camp")
	add_child(arrival)


## Setup navigation mesh
func _setup_navigation() -> void:
	if not nav_region:
		nav_region = NavigationRegion3D.new()
		nav_region.name = "NavigationRegion3D"
		add_child(nav_region)

	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	# Parse the level and everything under it. Left at the default
	# ROOT_NODE_CHILDREN the bake reads the region's own children, of
	# which there are none, and produces an empty navmesh.
	var nav_group: StringName = StringName("navmesh_src_%d" % get_instance_id())
	add_to_group(nav_group)
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = nav_group
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
