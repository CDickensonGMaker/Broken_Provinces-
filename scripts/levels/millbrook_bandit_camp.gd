## millbrook_bandit_camp.gd - The crew's camp in the woods east of Mill Brook
## The flagship's stage. Five roads out of one clearing: kill the chief, buy the
## crew off, talk terms, take their oath, or stand over the chief's body and let
## the quartermaster call you chief instead.
##
## The camp reads its own outcome out of WorldState on every visit, so a camp
## that was bought off is empty, a camp under terms is peaceable, and a camp the
## player runs pays him every day.
extends Node3D

const ZONE_ID := "millbrook_bandit_camp"
const CHIEF_POSITION := Vector3(0, 0.1, -14)
const QUARTERMASTER_POSITION := Vector3(-6, 0.1, -8)

const BANDIT_DATA := "res://data/enemies/human_bandit.tres"
const BANDIT_BOSS_DATA := "res://data/enemies/bandit_boss.tres"
const BANDIT_SPRITE := "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"

## Where the crew stands when the camp is still a going concern.
const CREW_POSTS: Array[Vector3] = [
	Vector3(-9, 0.1, 6), Vector3(9, 0.1, 6),
	Vector3(-12, 0.1, -4), Vector3(12, 0.1, -3),
	Vector3(-4, 0.1, -18), Vector3(5, 0.1, -19),
]

var nav_region: NavigationRegion3D
var enemies_container: Node3D
var npcs_container: Node3D


func _ready() -> void:
	if SceneManager:
		SceneManager.set_current_region(ZONE_ID)
	SaveManager.set_current_zone(ZONE_ID, "The Crew's Camp")

	_setup_spawn_points()
	_build_clearing()
	_populate_camp()
	_spawn_doors()
	_setup_navigation()
	_arrive()

	if WorldState and not WorldState.flag_changed.is_connected(_on_world_flag_changed):
		WorldState.flag_changed.connect(_on_world_flag_changed)
	_apply_boss_arrangement()

	var is_main_scene: bool = false
	var player_check: Node = get_node_or_null("Player")
	if player_check and is_instance_valid(player_check) and not player_check.is_queued_for_deletion():
		is_main_scene = true
	if is_main_scene:
		DayNightCycle.add_to_level(self)
		if WeatherManager:
			WeatherManager.set_outdoor(true)


func _setup_spawn_points() -> void:
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if not spawn_points:
		return

	for child: Node in spawn_points.get_children():
		if child is Marker3D:
			var spawn_id: String = child.name.replace("SpawnPoint_", "")
			child.add_to_group("spawn_points")
			child.set_meta("spawn_id", spawn_id)
			if spawn_id == "default":
				child.add_to_group("default_spawn")


## Standing in the clearing is finding it, and finding it is a durable fact -
## the quest pre-completes its "find the camp" objective for a player who
## wandered in here months before anyone asked him to.
func _arrive() -> void:
	if QuestManager:
		QuestManager.on_location_reached(ZONE_ID)
	if WorldState:
		WorldState.set_flag("millbrook_camp_found", true)


# =============================================================================
# GEOMETRY
# =============================================================================

## PS1-simple: a dirt floor, a treeline the player cannot walk through, a fire
## ring, four tents. Placeholder geometry, logged in the art manifest.
func _build_clearing() -> void:
	var terrain := Node3D.new()
	terrain.name = "Terrain"
	add_child(terrain)

	_add_block(terrain, Vector3(0, -0.25, 0), Vector3(60, 0.5, 60), Color(0.28, 0.24, 0.17), "Ground")

	# Treeline. Four slabs, so the clearing is a room and the road in is the gap.
	_add_block(terrain, Vector3(0, 3, -30), Vector3(60, 6, 2), Color(0.14, 0.2, 0.12), "TreelineNorth")
	_add_block(terrain, Vector3(-30, 3, 0), Vector3(2, 6, 60), Color(0.14, 0.2, 0.12), "TreelineWest")
	_add_block(terrain, Vector3(30, 3, 0), Vector3(2, 6, 60), Color(0.14, 0.2, 0.12), "TreelineEast")
	_add_block(terrain, Vector3(-18, 3, 30), Vector3(24, 6, 2), Color(0.14, 0.2, 0.12), "TreelineSouthWest")
	_add_block(terrain, Vector3(18, 3, 30), Vector3(24, 6, 2), Color(0.14, 0.2, 0.12), "TreelineSouthEast")

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)

	_add_block(props, Vector3(0, 0.3, 0), Vector3(3, 0.6, 3), Color(0.2, 0.16, 0.14), "FireRing")

	var tent_spots: Array[Vector3] = [
		Vector3(-11, 0, 4), Vector3(11, 0, 4), Vector3(-11, 0, -12),
	]
	for spot: Vector3 in tent_spots:
		_add_block(props, spot + Vector3(0, 1.2, 0), Vector3(4, 2.4, 5), Color(0.36, 0.31, 0.22), "Tent")

	# The chief's tent is bigger and faces the fire, because of course it does.
	_add_block(props, CHIEF_POSITION + Vector3(0, 1.6, -1), Vector3(7, 3.2, 6), Color(0.3, 0.22, 0.2), "ChiefTent")


func _add_block(parent: Node3D, pos: Vector3, size: Vector3, color: Color, block_name: String) -> void:
	var body := StaticBody3D.new()
	body.name = block_name
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	body.position = pos

	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh.material_override = material
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	shape.name = "Collision"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)


# =============================================================================
# POPULATION
# =============================================================================

func _populate_camp() -> void:
	enemies_container = Node3D.new()
	enemies_container.name = "Enemies"
	add_child(enemies_container)

	npcs_container = Node3D.new()
	npcs_container.name = "NPCs"
	add_child(npcs_container)

	if _camp_is_gone():
		return

	_spawn_crew()
	_spawn_named_crew()


## True once the camp has stopped being a camp: razed, bought off, or never
## rebuilt after the player took it apart before anyone asked him to.
func _camp_is_gone() -> bool:
	if not WorldState:
		return false
	if WorldState.has_flag("bandit_camp_cleared"):
		return true
	if WorldState.has_flag("millbrook_camp_moved_on"):
		return true
	return false


func _spawn_crew() -> void:
	# A crew that has taken the player's oath, or the player's orders, does not
	# attack him.
	if WorldState and WorldState.has_flag("bandit_camp_joined"):
		return
	if WorldState and WorldState.has_flag("millbrook_camp_under_terms"):
		return

	var sprite: Texture2D = load(BANDIT_SPRITE)
	if not sprite:
		push_error("[MillbrookBanditCamp] Bandit sprite failed to load; the camp is empty")
		return

	for post: Vector3 in CREW_POSTS:
		var bandit: EnemyBase = EnemyBase.spawn_billboard_enemy(
				enemies_container, post, BANDIT_DATA, sprite, 4, 1)
		if bandit:
			bandit.add_to_group("enemies")
			if not bandit.died.is_connected(_on_camp_death):
				bandit.died.connect(_on_camp_death)


func _spawn_named_crew() -> void:
	# The chief is a person until the player decides otherwise. Once she is
	# dead she stays dead, and Pell is the one still standing in the clearing.
	if not _blood_called():
		var chief := QuestGiver.spawn_quest_giver(
			npcs_container,
			CHIEF_POSITION,
			"Chief Corla Vane",
			"millbrook_bandit_chief",
			null, 8, 2,
			[]
		)
		_dress_bandit(chief, "res://data/dialogue/millbrook_bandit_chief.json",
				["shrewd", "unbothered", "practical", "dangerous"],
				"Sit down or don't. You walked into my camp, so you wanted something.")
	else:
		_spawn_chief_as_enemy()

	var pell := QuestGiver.spawn_quest_giver(
		npcs_container,
		QUARTERMASTER_POSITION,
		"Quartermaster Pell",
		"millbrook_bandit_quartermaster",
		null, 8, 2,
		[]
	)
	_dress_bandit(pell, "res://data/dialogue/millbrook_bandit_quartermaster.json",
			["bookish", "dry", "cowardly", "loyal to the ledger"],
			"Everything in this camp is written down twice. That is why it still exists.")


## Once the player has said the words, Corla stops being a person he can talk
## to and becomes the thing standing between him and the chair.
func _spawn_chief_as_enemy() -> void:
	if _camp_is_gone():
		return
	if WorldState and WorldState.has_flag("millbrook_chief_killed"):
		return
	if not _blood_called():
		return

	var sprite: Texture2D = load(BANDIT_SPRITE)
	if not sprite:
		return
	var boss: EnemyBase = EnemyBase.spawn_billboard_enemy(
			enemies_container, CHIEF_POSITION, BANDIT_BOSS_DATA, sprite, 4, 1)
	if boss:
		boss.add_to_group("enemies")
		if not boss.died.is_connected(_on_chief_death):
			boss.died.connect(_on_chief_death)


func _blood_called() -> bool:
	if not WorldState:
		return false
	return WorldState.has_flag("millbrook_blood_called")


func _dress_bandit(npc: QuestGiver, dialogue_path: String, traits: Array[String],
		idle_line: String) -> void:
	if not npc:
		push_error("[MillbrookBanditCamp] Failed to spawn a named bandit")
		return

	npc.region_id = ZONE_ID
	npc.faction_id = "bandits"
	npc.no_quest_dialogue = idle_line

	var dialogue: DialogueData = DialogueLoader.get_dialogue(dialogue_path)
	if dialogue:
		npc.dialogue_data = dialogue
		npc.use_legacy_dialogue = false
	else:
		push_warning("[MillbrookBanditCamp] Failed to load dialogue %s" % dialogue_path)

	var profile := NPCKnowledgeProfile.new()
	profile.archetype = NPCKnowledgeProfile.Archetype.GENERIC_VILLAGER
	profile.personality_traits = traits
	profile.knowledge_tags = ["millbrook", "bandits", "the_road", "underworld"]
	profile.base_disposition = 30
	npc.npc_profile = profile


func _on_camp_death(_killer: Node) -> void:
	call_deferred("_check_camp_emptied")


func _on_chief_death(_killer: Node) -> void:
	if WorldState:
		WorldState.set_flag("millbrook_chief_killed", true)
	# Killing her is the branch. It is not reported anywhere, it just happened.
	if QuestManager:
		QuestManager.apply_choice_consequence("millbrook_bandits", "killed_the_crew")
	call_deferred("_check_camp_emptied")


## A camp with nobody left standing is a cleared camp, whether or not anybody
## ever handed the player a quest about it. That fact is what makes the quest
## complete on offer later.
func _check_camp_emptied() -> void:
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node) and not node.is_queued_for_deletion() and is_ancestor_of(node):
			return

	if WorldState and not WorldState.has_flag("bandit_camp_joined"):
		WorldState.set_flag("bandit_camp_cleared", true)
		WorldState.set_flag("millbrook_road_safe", true)


# =============================================================================
# THE STANDING ARRANGEMENT
# =============================================================================

func _on_world_flag_changed(flag: String, _old_value: Variant, _new_value: Variant) -> void:
	match flag:
		"player_is_bandit_boss":
			_apply_boss_arrangement()
		"millbrook_blood_called":
			_turn_on_the_chief()


## The moment the player says it out loud, the camp stops being a negotiation.
## Corla is pulled out of the conversation and put back in as a fight, and the
## crew that was standing around the fire is now standing between the two.
func _turn_on_the_chief() -> void:
	if not npcs_container:
		return
	var chief: Node = npcs_container.get_node_or_null("QuestGiver_millbrook_bandit_chief")
	if chief == null:
		for child: Node in npcs_container.get_children():
			if child.get("npc_id") == "millbrook_bandit_chief":
				chief = child
				break
	if chief:
		chief.queue_free()
	_spawn_chief_as_enemy()


## Running a crew is not a title, it is a standing arrangement: the camp's share
## arrives every day, and every guard on the road starts looking harder for the
## man who is collecting it. Both sides of it are tagged to one source, so
## losing the chair clears them together.
func _apply_boss_arrangement() -> void:
	if not (WorldState and FactionManager):
		return
	if not WorldState.has_flag("player_is_bandit_boss"):
		return
	if FactionManager.has_ongoing_effect("millbrook_crew_share"):
		return

	FactionManager.add_ongoing_effect("millbrook_crew_share", {
		"type": "gold",
		"amount": 25,
		"reason_display": "The Mill Brook crew's share",
		"source": "bandit_boss",
	})

	FactionManager.add_ongoing_effect("millbrook_crew_hunted", {
		"type": "hostility",
		"faction": "town_guard",
		"amount": 4,
		"reason_display": "Word of who runs the eastern camp",
		"source": "bandit_boss",
	})

	FactionManager.add_ongoing_effect("millbrook_crew_resented", {
		"type": "reputation",
		"faction": "millbrook",
		"amount": -2,
		"reason_display": "Mill Brook pays your crew every week",
		"source": "bandit_boss",
	})


# =============================================================================
# PLUMBING
# =============================================================================

func _spawn_doors() -> void:
	var doors := Node3D.new()
	doors.name = "Doors"
	add_child(doors)

	ZoneDoor.spawn_door(
		doors,
		Vector3(0, 0.1, 27),
		"res://scenes/levels/millbrook.tscn",
		"from_bandit_camp",
		"The road back to Mill Brook",
		false
	)


func _setup_navigation() -> void:
	nav_region = get_node_or_null("NavigationRegion3D")
	if not nav_region:
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
