## crime_test_scene.gd - Dev test scene for arrest/jail loop
## Tests the complete crime -> arrest -> jail -> release cycle
extends Node3D

const ZONE_ID := "crime_test"
const REGION_ID := "crime_test"

var player: Node
var hud: CanvasLayer


func _ready() -> void:
	_setup_environment()
	_setup_player()
	_spawn_npcs()
	_spawn_prison()
	_give_starting_gold()
	_setup_navigation()
	print("[CrimeTest] Test scene loaded - Attack civilian to test crime system")


## Create flat floor and lighting
func _setup_environment() -> void:
	# Create floor - extended to fit prison building (10x8 units) at (20, 0, 20)
	var floor_mesh := CSGBox3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.size = Vector3(60, 0.5, 60)  # Extended floor to accommodate prison at (20, 0, 20)
	floor_mesh.position = Vector3(5, -0.25, 5)  # Offset to cover from -25 to +35 on both axes

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.35, 0.25)  # Grass-like
	floor_mat.roughness = 0.9
	floor_mesh.material = floor_mat
	floor_mesh.use_collision = true
	add_child(floor_mesh)

	# Add directional light
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	add_child(light)

	# Add sky/environment
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.35)
	environment.environment = env
	add_child(environment)


## Spawn player and HUD
func _setup_player() -> void:
	# Spawn player at origin
	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	if player_scene:
		player = player_scene.instantiate()
		player.position = Vector3(0, 0.5, 0)
		add_child(player)
	else:
		push_error("[CrimeTest] Failed to load player scene!")

	# Spawn HUD
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	if hud_scene:
		hud = hud_scene.instantiate()
		add_child(hud)
	else:
		push_error("[CrimeTest] Failed to load HUD scene!")


## Spawn test NPCs (civilians and guard)
func _spawn_npcs() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	# Killable civilian (attack target)
	var victim := CivilianNPC.spawn_man(npcs, Vector3(5, 0, 5), REGION_ID)
	victim.npc_id = "test_victim"
	victim.npc_name = "Test Victim"
	victim.region = REGION_ID
	print("[CrimeTest] Spawned Test Victim at (5, 0, 5)")

	# Witness civilians (will report crimes and flee)
	var witness1 := CivilianNPC.spawn_woman(npcs, Vector3(8, 0, 3), REGION_ID)
	witness1.npc_id = "witness_1"
	witness1.npc_name = "Witness 1"
	witness1.region = REGION_ID
	print("[CrimeTest] Spawned Witness 1 at (8, 0, 3)")

	var witness2 := CivilianNPC.spawn_man(npcs, Vector3(3, 0, 8), REGION_ID)
	witness2.npc_id = "witness_2"
	witness2.npc_name = "Witness 2"
	witness2.region = REGION_ID
	print("[CrimeTest] Spawned Witness 2 at (3, 0, 8)")

	# Guard (can arrest)
	var guard := GuardNPC.spawn_guard(npcs, Vector3(-5, 0, 5), [], REGION_ID)
	guard.npc_id = "test_guard"
	guard.npc_name = "Test Guard"
	print("[CrimeTest] Spawned Test Guard at (-5, 0, 5)")


## Spawn prison at edge of test area - loads the edited prison.tscn scene
func _spawn_prison() -> void:
	# Load the prison scene file (your edited version)
	var prison_scene: PackedScene = load("res://scenes/world/prison.tscn")
	if not prison_scene:
		push_error("[CrimeTest] Failed to load prison.tscn!")
		return

	var prison: Prison = prison_scene.instantiate() as Prison
	if not prison:
		push_error("[CrimeTest] Failed to instantiate prison!")
		return

	# Position it at (20, 0, 20) to give plenty of space from center NPCs
	var prison_pos := Vector3(20, 0, 20)
	prison.position = prison_pos
	prison.prison_name = "Test Jail"
	prison.region_id = REGION_ID
	add_child(prison)

	# Debug prints for prison spawn confirmation
	print("[CrimeTest] ========================================")
	print("[CrimeTest] PRISON SPAWN DEBUG (from prison.tscn):")
	print("[CrimeTest]   Position: %s" % prison_pos)
	print("[CrimeTest]   Prison name: %s" % prison.prison_name)
	print("[CrimeTest]   Region ID: %s" % prison.region_id)

	# Check if jail guard was spawned
	var jail_guard: Node3D = prison.jail_guard
	if jail_guard:
		print("[CrimeTest]   JailGuard spawned: YES")
		print("[CrimeTest]   JailGuard local position: %s" % jail_guard.position)
		print("[CrimeTest]   JailGuard global position: %s" % jail_guard.global_position)
	else:
		print("[CrimeTest]   JailGuard spawned: NO (check jail_guard.gd exists)")

	# Check interactables
	if prison.cell_door_interactable:
		print("[CrimeTest]   Cell door interactable: YES")
	if prison.exit_door_interactable:
		print("[CrimeTest]   Exit door interactable: YES")

	print("[CrimeTest] ========================================")


## Give starting gold for bribe testing
func _give_starting_gold() -> void:
	if InventoryManager:
		InventoryManager.gold = 500
		print("[CrimeTest] Set starting gold to 500")

	# Also give some lockpicks for escape testing
	if InventoryManager:
		InventoryManager.add_item("lockpick", 3)
		print("[CrimeTest] Added 3 lockpicks")


## Setup basic navigation for NPCs
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
		print("[CrimeTest] Navigation mesh baked")
