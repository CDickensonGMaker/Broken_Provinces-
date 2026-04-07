## elven_outpost.gd - Elven forest settlement
## Accessible by boat from Larton
extends Node3D

const ZONE_ID := "village_elven_outpost"

var nav_region: NavigationRegion3D


func _ready() -> void:
	_create_terrain()
	_spawn_fast_travel_shrine()
	_create_spawn_points()
	_spawn_elven_npcs()
	_setup_navigation()


func _create_terrain() -> void:
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.25, 0.35, 0.2)
	ground_mat.roughness = 0.9

	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(60, 1, 60)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = ground_mat
	ground.use_collision = true
	add_child(ground)


func _spawn_fast_travel_shrine() -> void:
	FastTravelShrine.spawn_shrine(
		self,
		Vector3(0, 0, 0),
		"Elven Outpost Shrine",
		"elven_outpost_shrine"
	)


func _create_spawn_points() -> void:
	var spawn_data := [
		{"id": "default", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_fast_travel", "pos": Vector3(0, 0.1, 3)},
		{"id": "from_wilderness", "pos": Vector3(0, 0.1, 5)},
		{"id": "from_north", "pos": Vector3(0, 0.1, -25)},
		{"id": "from_south", "pos": Vector3(0, 0.1, 25)},
		{"id": "from_east", "pos": Vector3(25, 0.1, 0)},
		{"id": "from_west", "pos": Vector3(-25, 0.1, 0)},
	]

	for data: Dictionary in spawn_data:
		var spawn := Node3D.new()
		spawn.name = "SpawnPoint_" + data.id
		spawn.position = data.pos
		spawn.add_to_group("spawn_points")
		spawn.set_meta("spawn_id", data.id)
		add_child(spawn)


## Spawn elven NPCs in the outpost
func _spawn_elven_npcs() -> void:
	# === ELF DIPLOMAT SILVANA (central meeting area) ===
	var diplomat_pos := Vector3(0, 0.1, -10)  # Central diplomatic area
	var elf_diplomat := QuestGiver.spawn_quest_giver(
		self,
		diplomat_pos,
		"Envoy Silvana",
		"elf_diplomat_silvana",
		null, 8, 2,
		[],  # Quest IDs to be added later
		false
	)
	elf_diplomat.region_id = ZONE_ID
	elf_diplomat.faction_id = "elves"
	elf_diplomat.no_quest_dialogue = "Welcome to our outpost, traveler. Relations between our peoples have been... strained of late. But perhaps that can change. The Council of Elders watches your kind with interest."
	var diplomat_profile := NPCKnowledgeProfile.new()
	diplomat_profile.archetype = NPCKnowledgeProfile.Archetype.SCHOLAR
	diplomat_profile.personality_traits = ["diplomatic", "cautious", "eloquent", "observant"]
	diplomat_profile.knowledge_tags = ["elves", "diplomacy", "council", "human_relations", "elven_city"]
	diplomat_profile.base_disposition = 40  # Cautious but diplomatic
	diplomat_profile.speech_style = "formal"
	elf_diplomat.npc_profile = diplomat_profile

	# === ELF GATE GUARD (near entrance) ===
	var gate_guard_pos := Vector3(0, 0.1, 20)  # Near the southern entrance
	var elf_gate_guard := QuestGiver.spawn_quest_giver(
		self,
		gate_guard_pos,
		"Sentinel Aelindor",
		"elf_gate_guard",
		null, 8, 2,
		[],  # Quest IDs to be added later
		true  # is_talk_target
	)
	elf_gate_guard.region_id = ZONE_ID
	elf_gate_guard.faction_id = "elves"
	elf_gate_guard.no_quest_dialogue = "State your business, human. This outpost serves as the threshold between your lands and ours. Those who enter with ill intent do not leave."
	var gate_guard_profile := NPCKnowledgeProfile.new()
	gate_guard_profile.archetype = NPCKnowledgeProfile.Archetype.GUARD
	gate_guard_profile.personality_traits = ["stern", "vigilant", "proud", "dutiful"]
	gate_guard_profile.knowledge_tags = ["elves", "security", "outpost", "threats", "visitors"]
	gate_guard_profile.base_disposition = 25  # Suspicious of humans
	gate_guard_profile.speech_style = "formal"
	elf_gate_guard.npc_profile = gate_guard_profile

	# === ELF MERCHANT (trading area) ===
	var merchant_pos := Vector3(-15, 0.1, -5)  # Trading/market area
	var elf_merchant := QuestGiver.spawn_quest_giver(
		self,
		merchant_pos,
		"Trader Faeniel",
		"elf_merchant",
		null, 8, 2,
		[],  # Quest IDs to be added later
		false
	)
	elf_merchant.region_id = ZONE_ID
	elf_merchant.faction_id = "elves"
	elf_merchant.no_quest_dialogue = "Elven craftsmanship is unmatched by human hands - a simple truth. But we trade fairly with those who show respect. Our wines, textiles, and enchanted trinkets are sought across the continent."
	var merchant_profile := NPCKnowledgeProfile.new()
	merchant_profile.archetype = NPCKnowledgeProfile.Archetype.MERCHANT
	merchant_profile.personality_traits = ["proud", "shrewd", "cultured", "patient"]
	merchant_profile.knowledge_tags = ["elves", "trade", "elven_goods", "wines", "enchantments"]
	merchant_profile.base_disposition = 45  # Willing to trade
	merchant_profile.speech_style = "formal"
	elf_merchant.npc_profile = merchant_profile


func _setup_navigation() -> void:
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
