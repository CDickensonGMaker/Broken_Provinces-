## boat_travel_test.gd - Dev testing scene for boat travel system
## Tests: Harbor Master dialogue -> Boat voyage -> Arrival at destination
extends Node3D

const ZONE_ID := "boat_travel_test"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

var player: Node3D = null

func _ready() -> void:
	print("[BoatTravelTest] Dev test scene loaded")
	print("[BoatTravelTest] Talk to the Harbor Master to test boat travel")

	_setup_ground()
	_setup_test_player()
	_spawn_player()
	_spawn_harbor_master()


## Set up a level 10 player with good equipment for testing
func _setup_test_player() -> void:
	if not GameManager or not GameManager.player_data:
		return

	var pd: CharacterData = GameManager.player_data

	# Set player level to 10
	pd.level = 10
	pd.improvement_points = 0  # Reset IP

	# Set reasonable stats for level 10
	pd.grit = 12
	pd.agility = 10
	pd.will = 8
	pd.knowledge = 6

	# Full health/stamina/mana
	pd.max_hp = 100 + (pd.grit * 5)
	pd.current_hp = pd.max_hp
	pd.max_stamina = 100 + (pd.agility * 3)
	pd.current_stamina = pd.max_stamina
	pd.max_mana = 50 + (pd.will * 5)
	pd.current_mana = pd.max_mana

	# Give gold for testing (gold is tracked by InventoryManager, not CharacterData)
	if InventoryManager:
		InventoryManager.gold = 500

	# Add items to inventory (player can equip via inventory screen)
	if InventoryManager:
		InventoryManager.add_item("longsword", 1)
		InventoryManager.add_item("plate_armor", 1)
		InventoryManager.add_item("health_potion", 5)
		InventoryManager.add_item("stamina_potion", 3)

	print("[BoatTravelTest] Player set to level 10 with gear in inventory")


## Spawn the player at the default spawn point
func _spawn_player() -> void:
	var spawn_point: Node3D = get_node_or_null("SpawnPoints/default")
	var spawn_pos := Vector3(0, 0.5, 0)
	if spawn_point:
		spawn_pos = spawn_point.global_position

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[BoatTravelTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	print("[BoatTravelTest] Player spawned at %s" % spawn_pos)


func _spawn_harbor_master() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	# Spawn Harbor Master for testing
	var harbor_master := QuestGiver.spawn_quest_giver(
		npcs,
		Vector3(0, 0, 5),  # In front of player
		"Harbor Master (Test)",
		"harbor_master_test",
		null,
		8, 2,
		[],
		false
	)
	harbor_master.region_id = ZONE_ID
	harbor_master.faction_id = "human_empire"

	# Load the Dalhurst harbor master dialogue (has boat travel options)
	var harbor_dialogue: DialogueData = DialogueLoader.load_from_json("res://data/dialogue/harbor_master_dalhurst.json")
	if harbor_dialogue:
		harbor_master.dialogue_data = harbor_dialogue
		harbor_master.use_legacy_dialogue = false
		print("[BoatTravelTest] Loaded boat travel dialogue")
	else:
		push_error("[BoatTravelTest] Failed to load dialogue!")

	# Make the NPC face the player spawn
	harbor_master.rotation.y = PI  # Face south (toward spawn)

	print("[BoatTravelTest] Harbor Master spawned at (0, 0, 5)")


func _setup_ground() -> void:
	# Simple ground plane
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(20, 0.5, 20)
	ground.position = Vector3(0, -0.25, 0)
	ground.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2)
	ground.material = mat
	add_child(ground)

	# Simple dock extension toward water
	var dock := CSGBox3D.new()
	dock.name = "Dock"
	dock.size = Vector3(6, 0.3, 10)
	dock.position = Vector3(0, 0.15, 12)
	dock.use_collision = true

	var dock_mat := StandardMaterial3D.new()
	dock_mat.albedo_color = Color(0.4, 0.28, 0.16)
	dock.material = dock_mat
	add_child(dock)

	# Water
	var water := CSGBox3D.new()
	water.name = "Water"
	water.size = Vector3(100, 1, 50)
	water.position = Vector3(0, -1, 40)
	water.use_collision = false

	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.1, 0.2, 0.35)
	water.material = water_mat
	add_child(water)

	# Lighting
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -45, 0)
	light.shadow_enabled = true
	add_child(light)

	# Spawn a docked boat as visual flavor
	_spawn_docked_boat()


## Spawn a docked boat using CSG geometry (same style as Dalhurst harbor ships)
func _spawn_docked_boat() -> void:
	var ship := Node3D.new()
	ship.name = "DockedShip"
	# Position ship at end of dock, rotated to face toward water
	ship.position = Vector3(6, 0, 17)
	ship.rotation.y = -PI / 2  # Face toward water (west)
	add_child(ship)

	# Materials (same as Dalhurst ships)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.35, 0.28, 0.2)  # Dark wood brown
	hull_mat.roughness = 0.85

	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.9, 0.85, 0.75)  # Off-white canvas

	# Hull - CSGBox3D (6x2x15 like Dalhurst)
	var hull := CSGBox3D.new()
	hull.name = "Hull"
	hull.size = Vector3(6, 2, 15)
	hull.position = Vector3(0, 0.5, 0)
	hull.material = hull_mat
	ship.add_child(hull)

	# Mast - CSGCylinder3D
	var mast := CSGCylinder3D.new()
	mast.name = "Mast"
	mast.radius = 0.3
	mast.height = 12.0
	mast.sides = 6
	mast.position = Vector3(0, 7, 0)
	mast.material = hull_mat
	ship.add_child(mast)

	# Sail - CSGBox3D
	var sail := CSGBox3D.new()
	sail.name = "Sail"
	sail.size = Vector3(0.1, 8, 5)
	sail.position = Vector3(0, 8, 0)
	sail.material = sail_mat
	ship.add_child(sail)

	print("[BoatTravelTest] Docked ship spawned at harbor (CSG style)")


func _input(event: InputEvent) -> void:
	# Press F5 to give more gold
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F5:
			if GameManager and GameManager.player_data:
				GameManager.player_data.gold += 100
				print("[BoatTravelTest] Added 100 gold (now: %d)" % GameManager.player_data.gold)

		# Press F6 to force start a voyage (skip dialogue)
		if event.keycode == KEY_F6:
			print("[BoatTravelTest] Force starting voyage to Larton...")
			if BoatTravelManager:
				BoatTravelManager.start_journey("dalhurst_to_larton", true)

		# Press F7 to check current voyage state
		if event.keycode == KEY_F7:
			if BoatTravelManager:
				print("[BoatTravelTest] Voyage state: %s" % BoatTravelManager.JourneyState.keys()[BoatTravelManager.current_state])
				if BoatTravelManager.current_route:
					print("[BoatTravelTest] Route: %s" % BoatTravelManager.current_route.display_name)
					print("[BoatTravelTest] Progress: %d%%" % int(BoatTravelManager.get_journey_progress() * 100))
