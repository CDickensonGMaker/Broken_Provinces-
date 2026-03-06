## boat_travel_test.gd - Dev testing scene for boat travel system
## Tests: Harbor Master dialogue -> Boat voyage -> Arrival at destination
##
## Two test modes:
## 1. Standalone: Run this scene directly (F6) to test in an isolated environment
## 2. Dalhurst: Press F8 to load into real Dalhurst at the harbor dock
##
## Similar pattern to crime_test_scene.gd for jailing system tests
extends Node3D

const ZONE_ID := "boat_travel_test"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const DALHURST_SCENE := "res://scenes/levels/dalhurst.tscn"
const HARBOR_SPAWN_ID := "harbor_spawn"

var player: Node3D = null
var hud: CanvasLayer = null


func _ready() -> void:
	print("[BoatTravelTest] ========================================")
	print("[BoatTravelTest] BOAT TRAVEL TEST SCENE LOADED")
	print("[BoatTravelTest] ========================================")
	print("[BoatTravelTest] Talk to the Harbor Master to test boat travel")
	print("[BoatTravelTest] ")
	print("[BoatTravelTest] CONTROLS:")
	print("[BoatTravelTest]   F5  - Add 100 gold")
	print("[BoatTravelTest]   F6  - Force start voyage (skip dialogue)")
	print("[BoatTravelTest]   F7  - Check voyage state")
	print("[BoatTravelTest]   F8  - Load into REAL Dalhurst at harbor dock")
	print("[BoatTravelTest] ========================================")

	_setup_environment()
	_setup_test_player()
	_spawn_player()
	_spawn_hud()
	_spawn_harbor_master()
	_setup_navigation()


## Create flat dock environment with water and lighting
func _setup_environment() -> void:
	# Simple ground plane (dock area)
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(30, 0.5, 30)
	ground.position = Vector3(0, -0.25, 0)
	ground.use_collision = true

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.25, 0.2)  # Wooden dock color
	mat.roughness = 0.9
	ground.material = mat
	add_child(ground)

	# Dock extension toward water
	var dock := CSGBox3D.new()
	dock.name = "Dock"
	dock.size = Vector3(8, 0.3, 15)
	dock.position = Vector3(0, 0.15, 18)
	dock.use_collision = true

	var dock_mat := StandardMaterial3D.new()
	dock_mat.albedo_color = Color(0.4, 0.28, 0.16)  # Dark wood
	dock_mat.roughness = 0.85
	dock.material = dock_mat
	add_child(dock)

	# Water plane
	var water := CSGBox3D.new()
	water.name = "Water"
	water.size = Vector3(200, 1, 100)
	water.position = Vector3(0, -1, 60)
	water.use_collision = false

	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.12, 0.25, 0.40, 0.9)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.15
	water_mat.metallic = 0.3
	water.material = water_mat
	add_child(water)

	# Directional light (sun)
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-45, -45, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)

	# World environment
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.8)  # Sky blue
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.35, 0.4)
	env.ambient_light_energy = 0.5
	environment.environment = env
	add_child(environment)

	# Spawn a docked ship for visual flavor
	_spawn_docked_boat()


## Spawn a docked boat using CSG geometry (same style as Dalhurst harbor ships)
func _spawn_docked_boat() -> void:
	var ship := Node3D.new()
	ship.name = "DockedShip"
	ship.position = Vector3(8, 0, 20)
	ship.rotation.y = -PI / 2  # Face toward water (east)
	add_child(ship)

	# Materials (same as Dalhurst ships)
	var hull_mat := StandardMaterial3D.new()
	hull_mat.albedo_color = Color(0.35, 0.28, 0.2)
	hull_mat.roughness = 0.85

	var sail_mat := StandardMaterial3D.new()
	sail_mat.albedo_color = Color(0.9, 0.85, 0.75)

	# Hull
	var hull := CSGBox3D.new()
	hull.name = "Hull"
	hull.size = Vector3(6, 2, 15)
	hull.position = Vector3(0, 0.5, 0)
	hull.material = hull_mat
	ship.add_child(hull)

	# Mast
	var mast := CSGCylinder3D.new()
	mast.name = "Mast"
	mast.radius = 0.3
	mast.height = 12.0
	mast.sides = 6
	mast.position = Vector3(0, 7, 0)
	mast.material = hull_mat
	ship.add_child(mast)

	# Sail
	var sail := CSGBox3D.new()
	sail.name = "Sail"
	sail.size = Vector3(0.1, 8, 5)
	sail.position = Vector3(0, 8, 0)
	sail.material = sail_mat
	ship.add_child(sail)


## Set up a level 10 player with good equipment for testing
func _setup_test_player() -> void:
	if not GameManager or not GameManager.player_data:
		push_warning("[BoatTravelTest] GameManager not available yet")
		return

	var pd: CharacterData = GameManager.player_data

	# Set player level to 10
	pd.level = 10
	pd.improvement_points = 0

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

	# Give gold for testing boat travel (tickets cost 50-100 gold)
	if InventoryManager:
		InventoryManager.gold = 500

	# Add items to inventory
	if InventoryManager:
		InventoryManager.add_item("longsword", 1)
		InventoryManager.add_item("plate_armor", 1)
		InventoryManager.add_item("health_potion", 5)
		InventoryManager.add_item("stamina_potion", 3)

	print("[BoatTravelTest] Player set to level 10 with 500 gold")


## Spawn the player
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


## Spawn the HUD
func _spawn_hud() -> void:
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
		print("[BoatTravelTest] HUD spawned")
	else:
		push_error("[BoatTravelTest] Failed to load HUD scene!")


## Spawn the Harbor Master NPC with boat travel dialogue
func _spawn_harbor_master() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	# Spawn Harbor Master in front of player, facing them
	var harbor_master := QuestGiver.spawn_quest_giver(
		npcs,
		Vector3(0, 0, 5),  # In front of player
		"Harbor Master",
		"harbor_master_test",
		null,  # Default sprite
		8, 2,  # h_frames, v_frames
		[],    # No quests - uses dialogue tree
		false  # is_talk_target = false
	)
	harbor_master.region_id = ZONE_ID
	harbor_master.faction_id = "human_empire"

	# Load the Dalhurst harbor master dialogue (has boat travel options)
	var harbor_dialogue: DialogueData = DialogueLoader.load_from_json("res://data/dialogue/harbor_master_dalhurst.json")
	if harbor_dialogue:
		harbor_master.dialogue_data = harbor_dialogue
		harbor_master.use_legacy_dialogue = false
		print("[BoatTravelTest] Loaded Dalhurst harbor master dialogue")
	else:
		push_error("[BoatTravelTest] Failed to load dialogue!")

	# Face the player spawn
	harbor_master.rotation.y = PI  # Face south (toward spawn)

	print("[BoatTravelTest] Harbor Master spawned at (0, 0, 5)")


## Setup basic navigation for NPC movement
func _setup_navigation() -> void:
	var nav_region := NavigationRegion3D.new()
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
	call_deferred("_bake_navigation", nav_region)


func _bake_navigation(nav_region: NavigationRegion3D) -> void:
	if nav_region and nav_region.navigation_mesh:
		nav_region.bake_navigation_mesh()
		print("[BoatTravelTest] Navigation mesh baked")


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	match event.keycode:
		KEY_F5:
			# Add gold
			if InventoryManager:
				InventoryManager.gold += 100
				print("[BoatTravelTest] Added 100 gold (now: %d)" % InventoryManager.gold)

		KEY_F6:
			# Force start voyage (skip dialogue)
			print("[BoatTravelTest] Force starting voyage to Larton...")
			if BoatTravelManager:
				BoatTravelManager.start_journey("dalhurst_to_larton", true)

		KEY_F7:
			# Check voyage state
			if BoatTravelManager:
				print("[BoatTravelTest] Voyage state: %s" % BoatTravelManager.JourneyState.keys()[BoatTravelManager.current_state])
				if BoatTravelManager.current_route:
					print("[BoatTravelTest] Route: %s" % BoatTravelManager.current_route.display_name)
					print("[BoatTravelTest] Progress: %d%%" % int(BoatTravelManager.get_journey_progress() * 100))

		KEY_F8:
			# Load into real Dalhurst at harbor dock
			print("[BoatTravelTest] Loading into Dalhurst at harbor dock...")
			_load_dalhurst_harbor()


## Load Dalhurst scene with harbor spawn point
func _load_dalhurst_harbor() -> void:
	if not SceneManager:
		push_error("[BoatTravelTest] SceneManager not available!")
		return

	# Setup player first if not already done
	_setup_test_player()

	print("[BoatTravelTest] Transitioning to Dalhurst (harbor_spawn)...")
	SceneManager.change_scene(DALHURST_SCENE, HARBOR_SPAWN_ID, true)
