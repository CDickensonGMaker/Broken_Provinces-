## kazan_dun_level_1_modular.gd - The Great Hall of Kazan-Dun (Modular Version)
## Level 1: Feast Hall, Council Chamber, Kitchen connected by corridor
## Connects to: Entrance (outside), Level 2 (below)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_1"
	zone_display_name = "Kazan-Dun - Great Hall"
	zone_size = 100.0


## Register all rooms in this level
func _register_rooms() -> void:
	# Get references to instanced room nodes
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 1 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Connect Feast Hall to Council Chamber (north corridor)
	connect_rooms("kd_feast_hall", "door_north", "kd_great_hall_corridor", "door_south")
	connect_rooms("kd_great_hall_corridor", "door_north", "kd_council_chamber", "door_south")

	# Connect Feast Hall to Kitchen (west)
	connect_rooms("kd_feast_hall", "door_west", "kd_kitchen", "door_east")


## The Great Hall is where the succession argument lives: the regent, the thane
## who wants the old rite instead, the loremaster who keeps the rolls, the pyre
## the king has to reach, and the muster roll that can end the regent.
func _initialize_level() -> void:
	super._initialize_level()
	_spawn_succession_cast()
	_spawn_succession_objects()


func _spawn_succession_cast() -> void:
	# If the hold fell while the player was elsewhere, there is nobody left in
	# the Great Hall to argue about the chair.
	if WorldState and WorldState.has_flag("kazan_dun_fallen"):
		return

	var npcs_node := get_node_or_null("NPCs") as Node3D
	if not npcs_node:
		npcs_node = Node3D.new()
		npcs_node.name = "NPCs"
		add_child(npcs_node)

	var regent_quests: Array[String] = [
		"kazan_dun_02_what_the_pits_held",
		"kazan_dun_03_the_devourers_table",
		"kazan_dun_04_the_empty_chair",
	]
	var regent := QuestGiver.spawn_quest_giver(
		npcs_node,
		Vector3(-4, 0.2, -45),
		"Regent Morgrim Ironvein",
		"dwarf_regent",
		null, 8, 2,
		regent_quests
	)
	_dress_dwarf(regent, "res://data/dialogue/trees/kazan_dun_regent.json",
			["measured", "burdened", "honest", "stubborn"],
			["kazan_dun", "dwarves", "succession", "dwarf_law", "the_siege"],
			"The chair stays empty until my brother has burned. That is not grief. That is law.")

	var thane := QuestGiver.spawn_quest_giver(
		npcs_node,
		Vector3(9, 0.2, -6),
		"Thane Vurka Stonebrand",
		"dwarf_thane_challenger",
		null, 8, 2,
		[]
	)
	_dress_dwarf(thane, "res://data/dialogue/trees/kazan_dun_thane.json",
			["blunt", "proud", "impatient", "fearless"],
			["kazan_dun", "dwarves", "succession", "the_siege", "trial_by_combat"],
			"Third gate still stands. Ask anyone which gate that is.")

	var loremaster := QuestGiver.spawn_quest_giver(
		npcs_node,
		Vector3(4, 0.2, -47),
		"Loremaster Dwalki Runeglass",
		"dwarf_loremaster",
		null, 8, 2,
		[]
	)
	_dress_dwarf(loremaster, "res://data/dialogue/trees/kazan_dun_loremaster.json",
			["scholarly", "dry", "precise", "guarded"],
			["kazan_dun", "dwarves", "dwarf_law", "funeral_rites", "soulstones"],
			"Six hundred years of names, and I am three columns behind.")


## Shared dressing for the Great Hall's named dwarves.
func _dress_dwarf(npc: QuestGiver, dialogue_path: String, traits: Array[String],
		knowledge: Array[String], idle_line: String) -> void:
	if not npc:
		push_error("[KD Level 1] Failed to spawn a Great Hall dwarf")
		return

	npc.region_id = zone_id
	npc.faction_id = "dwarves"
	npc.no_quest_dialogue = idle_line

	var dialogue: DialogueData = DialogueLoader.get_dialogue(dialogue_path)
	if dialogue:
		npc.dialogue_data = dialogue
		npc.use_legacy_dialogue = false
	else:
		push_warning("[KD Level 1] Failed to load dialogue %s" % dialogue_path)

	var profile := NPCKnowledgeProfile.new()
	profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	profile.personality_traits = traits
	profile.knowledge_tags = knowledge
	profile.base_disposition = 40
	profile.speech_style = "formal"
	npc.npc_profile = profile


func _spawn_succession_objects() -> void:
	var objects := Node3D.new()
	objects.name = "QuestObjects"
	add_child(objects)

	QuestInteractable.spawn(
		objects,
		Vector3(0, 0.2, -9),
		"kd_thurgans_pyre",
		"the king on his hearthstone",
		"Lay",
		"The hold stops working to watch you carry him in. Nobody helps. Nobody is allowed to."
	)

	var roll := QuestInteractable.spawn(
		objects,
		Vector3(-8, 0.2, -49),
		"kd_regents_roll",
		"the muster roll for the night of the assault",
		"Read out",
		"You read the night's muster aloud. A hundred axes held back at the council chamber, in Morgrim's own hand. The Loremaster does not stop you. He has been waiting for someone with no clan to do this.",
		"",
		"kazan_dun_regent_disgraced"
	)
	roll.choice_consequence = "kazan_dun_04_the_empty_chair:undercut_the_regent"
	roll.required_flag = "kazan_dun_knows_about_roll"
	roll.locked_message = "A muster roll. Columns of names in a dwarf's neat hand. It means nothing to you yet."
	roll.body_size = Vector3(1.0, 0.9, 0.6)


## Setup level-specific environment overrides
func _setup_environment() -> void:
	# Use base environment but with slightly warmer lighting for the Great Hall
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			world_env.environment.ambient_light_energy = 0.4
