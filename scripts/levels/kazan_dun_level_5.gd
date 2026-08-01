## kazan_dun_level_5_modular.gd - Goblin-Held Zone of Kazan-Dun (Modular Version)
## Level 5: Goblin Camp, Ritual Chamber, Throne Room (Boss), Barricades
## Connects to: Level 4 (above via bridge)
extends KazanDunModularBase


func _init() -> void:
	zone_id = "kazan_dun_level_5"
	zone_display_name = "Kazan-Dun - Goblin-Held Zone"
	zone_size = 120.0


## Register all rooms in this level
func _register_rooms() -> void:
	var rooms_node := get_node_or_null("Rooms")
	if not rooms_node:
		push_error("[KD Level 5 Modular] Rooms node not found!")
		return

	for child in rooms_node.get_children():
		if child.has_method("get_room_id"):
			var room_id: String = child.room_id
			register_room(room_id, child)
		elif child.get("room_id"):
			register_room(child.room_id, child)


## Connect doors between rooms
func _connect_room_doors() -> void:
	# Stairwell from Level 4 connects to first barricade
	connect_rooms("kd_stairwell_down_1", "door_south", "kd_barricade_1", "door_north")

	# Barricade leads to Goblin Camp
	connect_rooms("kd_barricade_1", "door_south", "kd_goblin_camp", "door_north")

	# Goblin Camp connects to second barricade
	connect_rooms("kd_goblin_camp", "door_south", "kd_barricade_2", "door_north")

	# Second barricade leads to Ritual Chamber
	connect_rooms("kd_barricade_2", "door_south", "kd_ritual_chamber", "door_north")

	# Ritual Chamber connects to Throne Room (Boss arena)
	connect_rooms("kd_ritual_chamber", "door_south", "kd_throne_room", "door_north")


## The depths hold three answers to one problem: Skarrag himself in the throne
## room, the gallery props that will bring the ritual chamber down, and the
## stacked soulstone stash the goblins will trade a corpse for.
func _initialize_level() -> void:
	super._initialize_level()
	call_deferred("_spawn_devourer")
	_spawn_recovery_objects()


func _spawn_devourer() -> void:
	spawn_enemy_in_room(
		"kd_throne_room",
		"res://data/enemies/goblin_warboss.tres",
		"res://assets/sprites/enemies/goblins/goblin_sword.png",
		Vector3(0, 0, -4)
	)


func _spawn_recovery_objects() -> void:
	var objects := Node3D.new()
	objects.name = "QuestObjects"
	add_child(objects)

	var props := QuestInteractable.spawn(
		objects,
		Vector3(7, -7.8, -113),
		"kd_gallery_props",
		"the old props under the ritual gallery",
		"Cut",
		"The gallery comes down in one long breath, and the feast beneath it stops being a feast. You drag the king clear by one arm before the dust settles.",
		"",
		"kazan_dun_gallery_collapsed"
	)
	props.body_size = Vector3(0.8, 3.0, 0.8)
	props.body_color = Color(0.34, 0.27, 0.18)

	var parley := QuestInteractable.spawn(
		objects,
		Vector3(-7, -7.8, -117),
		"kd_soulstone_parley",
		"the stacked soulstone stash beside the table",
		"Push toward Skarrag",
		"You push the whole stack across the floor toward the table. The hall goes quiet, then greedy. Nobody stops you taking the body. Nobody in this room thinks you got the better half of the trade.",
		"",
		"kazan_dun_soulstones_traded"
	)
	parley.body_size = Vector3(1.4, 1.0, 1.4)
	parley.body_color = Color(0.35, 0.45, 0.4)


## Setup level-specific environment - corrupted goblin atmosphere
func _setup_environment() -> void:
	super._setup_environment()

	if has_node("WorldEnvironment"):
		var world_env := $WorldEnvironment as WorldEnvironment
		if world_env and world_env.environment:
			# Dark, eerie green-tinted atmosphere for goblin lair
			world_env.environment.ambient_light_energy = 0.18
			world_env.environment.ambient_light_color = Color(0.4, 0.5, 0.35)
			world_env.environment.fog_enabled = true
			world_env.environment.fog_density = 0.03
			world_env.environment.fog_light_color = Color(0.3, 0.35, 0.25)
			world_env.environment.background_color = Color(0.08, 0.1, 0.07)
