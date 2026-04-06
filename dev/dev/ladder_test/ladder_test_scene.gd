## ladder_test_scene.gd - Dev testing scene for ladder climbing system
## Tests: Wooden outpost tower with ladder, auto-climb, dismount
extends Node3D

const ZONE_ID := "ladder_test"
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"
const OUTPOST_GLB_PATH := "res://assets/models/buildings/wooden_outpost_tower.glb"

var player: Node3D = null
var outpost: Node3D = null


func _ready() -> void:
	print("[LadderTest] Dev test scene loaded")
	print("[LadderTest] Walk into the ladder to start climbing")
	print("[LadderTest] W/S to climb up/down, auto-dismount at top/bottom")
	print("[LadderTest] F5 = Teleport to ladder, F6 = Print player state")

	_setup_environment()
	_setup_lighting()
	_setup_ground()
	_spawn_player()
	_spawn_outpost_tower()


## Setup basic environment
func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.4, 0.55, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	environment.ambient_light_energy = 0.6
	env.environment = environment
	add_child(env)


func _setup_lighting() -> void:
	var light := DirectionalLight3D.new()
	light.name = "Sun"
	light.rotation_degrees = Vector3(-40, -30, 0)
	light.shadow_enabled = true
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 1.0
	add_child(light)


func _setup_ground() -> void:
	# Create a large ground plane
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(50, 0.5, 50)
	ground.position = Vector3(0, -0.25, 0)
	ground.use_collision = true

	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.45, 0.25)  # Grassy green
	ground.material = ground_mat
	add_child(ground)

	# Add some navigation for enemies (not needed for ladder test but good practice)
	var nav_region := NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nav_mesh
	add_child(nav_region)
	# Bake deferred to let colliders initialize
	nav_region.call_deferred("bake_navigation_mesh")


func _spawn_player() -> void:
	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[LadderTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = Vector3(0, 0.5, 5)  # Spawn in front of the tower

	# Rotate the camera pivot to face the tower (not the body)
	# The camera pivot controls movement direction
	var camera_pivot: Node3D = player.get_node_or_null("CameraPivot")
	if camera_pivot:
		camera_pivot.rotation.y = PI  # Face toward -Z (the tower)

	print("[LadderTest] Player spawned at %s" % player.global_position)


func _spawn_outpost_tower() -> void:
	# Load the GLB model
	var outpost_scene: PackedScene = load(OUTPOST_GLB_PATH)
	if not outpost_scene:
		push_error("[LadderTest] Failed to load outpost model: %s" % OUTPOST_GLB_PATH)
		_create_debug_ladder()  # Fallback to debug ladder
		return

	outpost = outpost_scene.instantiate()
	outpost.name = "WoodenOutpostTower"
	outpost.global_position = Vector3(0, 0, 0)
	add_child(outpost)

	# Process collision for meshes with naming conventions
	# This handles meshes like Platform, Post, etc. based on their names
	var result: GLBCollisionProcessor.ProcessResult = GLBCollisionProcessor.process_node(outpost)
	print("[LadderTest] Collision processing: %s" % result.get_summary())

	print("[LadderTest] Outpost tower spawned")

	# Find and setup the ladder
	_setup_ladder_on_outpost()


## Find the ladder structure in the outpost and attach the Ladder script
func _setup_ladder_on_outpost() -> void:
	if not outpost:
		return

	# The GLB structure should have:
	# WoodenOutpostTower
	#   Ladder (empty parent)
	#     ladder_climb_area
	#     ladder_bottom
	#     ladder_top
	#     ... other ladder meshes

	# Try to find the Ladder node
	var ladder_node: Node3D = _find_node_recursive(outpost, "Ladder")
	if not ladder_node:
		ladder_node = _find_node_recursive(outpost, "ladder")

	if ladder_node:
		print("[LadderTest] Found ladder node: %s" % ladder_node.get_path())
		_print_node_tree(ladder_node, 0)

		# Attach the Ladder script
		var ladder_script: GDScript = load("res://scripts/world/ladder.gd")
		if ladder_script:
			ladder_node.set_script(ladder_script)
			# IMPORTANT: When set_script() is called on a node already in the tree,
			# _ready() doesn't automatically run. We must call it manually.
			ladder_node._ready()
			print("[LadderTest] Ladder script attached to %s" % ladder_node.name)
		else:
			push_error("[LadderTest] Failed to load ladder.gd script!")
	else:
		print("[LadderTest] No Ladder node found in outpost, creating debug ladder")
		_create_debug_ladder()


## Recursively find a node by name (case-insensitive)
func _find_node_recursive(parent: Node, target_name: String) -> Node3D:
	for child in parent.get_children():
		if child.name.to_lower() == target_name.to_lower():
			if child is Node3D:
				return child as Node3D
		var found: Node3D = _find_node_recursive(child, target_name)
		if found:
			return found
	return null


## Print node tree for debugging
func _print_node_tree(node: Node, depth: int) -> void:
	var indent: String = "  ".repeat(depth)
	var type_str: String = node.get_class()
	print("[LadderTest] %s%s (%s)" % [indent, node.name, type_str])
	for child in node.get_children():
		_print_node_tree(child, depth + 1)


## Create a debug ladder if the GLB doesn't have proper structure
func _create_debug_ladder() -> void:
	print("[LadderTest] Creating debug ladder...")

	# Create a simple ladder structure for testing
	var ladder_root := Node3D.new()
	ladder_root.name = "DebugLadder"
	ladder_root.global_position = Vector3(0, 0, 0)

	# Ladder rails (visual only)
	var rail_l := CSGBox3D.new()
	rail_l.name = "Ladder_Rail_L"
	rail_l.size = Vector3(0.1, 5.0, 0.1)
	rail_l.position = Vector3(-0.3, 2.5, 0)
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.4, 0.3, 0.2)
	rail_l.material = rail_mat
	ladder_root.add_child(rail_l)

	var rail_r := CSGBox3D.new()
	rail_r.name = "Ladder_Rail_R"
	rail_r.size = Vector3(0.1, 5.0, 0.1)
	rail_r.position = Vector3(0.3, 2.5, 0)
	rail_r.material = rail_mat
	ladder_root.add_child(rail_r)

	# Rungs
	for i in range(10):
		var rung := CSGBox3D.new()
		rung.name = "Ladder_Rung_%d" % i
		rung.size = Vector3(0.5, 0.08, 0.08)
		rung.position = Vector3(0, 0.5 + i * 0.5, 0)
		rung.material = rail_mat
		ladder_root.add_child(rung)

	# Climb area (trigger zone)
	var climb_area := Node3D.new()
	climb_area.name = "ladder_climb_area"
	climb_area.position = Vector3(0, 2.5, 0.3)
	ladder_root.add_child(climb_area)

	# Bottom marker
	var ladder_bottom := Node3D.new()
	ladder_bottom.name = "ladder_bottom"
	ladder_bottom.position = Vector3(0, 0.2, 0.3)
	ladder_root.add_child(ladder_bottom)

	# Top marker
	var ladder_top := Node3D.new()
	ladder_top.name = "ladder_top"
	ladder_top.position = Vector3(0, 5.0, 0.3)
	ladder_root.add_child(ladder_top)

	# Add a platform at the top
	var platform := CSGBox3D.new()
	platform.name = "TopPlatform"
	platform.size = Vector3(3.0, 0.2, 3.0)
	platform.position = Vector3(0, 5.0, -1.0)
	platform.use_collision = true
	var platform_mat := StandardMaterial3D.new()
	platform_mat.albedo_color = Color(0.5, 0.4, 0.3)
	platform.material = platform_mat
	ladder_root.add_child(platform)

	add_child(ladder_root)

	# Attach ladder script
	var ladder_script: GDScript = load("res://scripts/world/ladder.gd")
	if ladder_script:
		ladder_root.set_script(ladder_script)
		print("[LadderTest] Debug ladder created and script attached")


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F5 = Teleport to ladder
		if event.keycode == KEY_F5:
			if player:
				player.global_position = Vector3(0, 0.5, 1)  # Right in front of ladder
				print("[LadderTest] Teleported player to ladder")

		# F6 = Print player state
		if event.keycode == KEY_F6:
			if player:
				print("[LadderTest] === Player State ===")
				print("  Position: %s" % player.global_position)
				print("  is_climbing: %s" % player.get("is_climbing"))
				print("  is_crouching: %s" % player.get("is_crouching"))
				print("  is_dodging: %s" % player.get("is_dodging"))
				print("  current_ladder: %s" % player.get("current_ladder"))

		# F7 = Force stop climbing
		if event.keycode == KEY_F7:
			if player and player.has_method("stop_climbing"):
				player.stop_climbing()
				print("[LadderTest] Forced stop climbing")
