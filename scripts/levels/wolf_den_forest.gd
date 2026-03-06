## wolf_den_forest.gd - Wolf Pack Den (Forest encounter area)
## A forested clearing with a wolf pack for the wolf_pack_menace quest
## Contains: 5+ wolves, 1 dire wolf boss, wolf den structure
extends Node3D

const ZONE_ID := "wolf_den_forest"

## Materials
var grass_mat: StandardMaterial3D
var dirt_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D
var bark_mat: StandardMaterial3D
var foliage_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Wolf Den - Eastern Forest")

	_create_materials()
	_setup_navigation()
	_create_forest_clearing()
	_create_wolf_den()
	_spawn_spawn_points()
	_spawn_exit_door()
	_spawn_wolves()
	_spawn_loot()
	_create_lighting()

	# Quest trigger for reaching the wolf den
	QuestManager.on_location_reached("wolf_den_forest")

	print("[WolfDenForest] Wolf den initialized!")


func _create_materials() -> void:
	# Forest grass
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.22, 0.35, 0.18)
	grass_mat.roughness = 0.95

	# Dirt/mud
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.28, 0.22, 0.16)
	dirt_mat.roughness = 0.98

	# Rocks
	rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.4, 0.38, 0.36)
	rock_mat.roughness = 0.9

	# Tree bark
	bark_mat = StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.3, 0.22, 0.15)
	bark_mat.roughness = 0.9

	# Tree foliage
	foliage_mat = StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.15, 0.28, 0.12)
	foliage_mat.roughness = 0.85


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
		print("[WolfDenForest] Navigation mesh baked!")


## ============================================================================
## FOREST CLEARING - Open area surrounded by trees
## ============================================================================

func _create_forest_clearing() -> void:
	# Ground (30x35 clearing)
	var ground := CSGBox3D.new()
	ground.name = "ClearingGround"
	ground.size = Vector3(35, 1, 40)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = grass_mat
	ground.use_collision = true
	add_child(ground)

	# Muddy area near the den
	var mud := CSGBox3D.new()
	mud.name = "MuddyArea"
	mud.size = Vector3(10, 0.02, 12)
	mud.position = Vector3(0, 0.01, -10)
	mud.material = dirt_mat
	mud.use_collision = false
	add_child(mud)

	# Scattered rocks
	_create_rock(Vector3(-12, 0, 8), 1.5)
	_create_rock(Vector3(10, 0, 5), 1.2)
	_create_rock(Vector3(-8, 0, -15), 1.8)
	_create_rock(Vector3(14, 0, -8), 1.0)
	_create_rock(Vector3(-15, 0, -5), 1.3)

	# Surrounding trees (forest border)
	_create_forest_border()

	print("[WolfDenForest] Forest clearing created")


func _create_rock(pos: Vector3, size_mult: float) -> void:
	var rock := CSGSphere3D.new()
	rock.name = "Rock"
	rock.radius = 0.7 * size_mult
	rock.position = Vector3(pos.x, rock.radius * 0.5, pos.z)
	rock.material = rock_mat
	rock.use_collision = true
	rock.scale = Vector3(
		randf_range(0.8, 1.2),
		randf_range(0.5, 0.8),
		randf_range(0.8, 1.2)
	)
	add_child(rock)


func _create_forest_border() -> void:
	# Trees around the clearing edge
	var tree_positions: Array[Vector3] = [
		# North edge
		Vector3(-12, 0, -18), Vector3(-6, 0, -19), Vector3(0, 0, -18),
		Vector3(6, 0, -19), Vector3(12, 0, -18),
		# South edge
		Vector3(-10, 0, 18), Vector3(-4, 0, 19), Vector3(4, 0, 18),
		Vector3(10, 0, 19),
		# East edge
		Vector3(16, 0, -10), Vector3(17, 0, 0), Vector3(16, 0, 10),
		# West edge
		Vector3(-16, 0, -10), Vector3(-17, 0, 0), Vector3(-16, 0, 10),
	]

	for i in tree_positions.size():
		_create_tree(tree_positions[i], "Tree_%d" % i)


func _create_tree(pos: Vector3, tree_name: String) -> void:
	var tree := Node3D.new()
	tree.name = tree_name
	tree.position = pos
	add_child(tree)

	# Trunk
	var trunk := CSGCylinder3D.new()
	trunk.name = "Trunk"
	trunk.radius = 0.4 + randf_range(-0.1, 0.15)
	trunk.height = 4.0 + randf_range(-0.5, 1.0)
	trunk.sides = 8
	trunk.position = Vector3(0, trunk.height / 2.0, 0)
	trunk.material = bark_mat
	trunk.use_collision = true
	tree.add_child(trunk)

	# Foliage (simple sphere)
	var foliage := CSGSphere3D.new()
	foliage.name = "Foliage"
	foliage.radius = 2.5 + randf_range(-0.5, 0.5)
	foliage.position = Vector3(0, trunk.height + foliage.radius * 0.6, 0)
	foliage.material = foliage_mat
	foliage.use_collision = false
	tree.add_child(foliage)


## ============================================================================
## WOLF DEN - Rock formation with cave-like structure
## ============================================================================

func _create_wolf_den() -> void:
	var den := Node3D.new()
	den.name = "WolfDen"
	den.position = Vector3(0, 0, -12)
	add_child(den)

	# Large rock formation as den entrance
	var main_rock := CSGSphere3D.new()
	main_rock.name = "MainRock"
	main_rock.radius = 3.0
	main_rock.position = Vector3(0, 1.5, 0)
	main_rock.scale = Vector3(1.5, 0.6, 1.2)
	main_rock.material = rock_mat
	main_rock.use_collision = true
	den.add_child(main_rock)

	# Side rocks
	var left_rock := CSGSphere3D.new()
	left_rock.name = "LeftRock"
	left_rock.radius = 2.0
	left_rock.position = Vector3(-3, 1.0, 1)
	left_rock.scale = Vector3(1.0, 0.7, 0.9)
	left_rock.material = rock_mat
	left_rock.use_collision = true
	den.add_child(left_rock)

	var right_rock := CSGSphere3D.new()
	right_rock.name = "RightRock"
	right_rock.radius = 2.2
	right_rock.position = Vector3(3.5, 1.2, 0.5)
	right_rock.scale = Vector3(0.9, 0.65, 1.1)
	right_rock.material = rock_mat
	right_rock.use_collision = true
	den.add_child(right_rock)

	# Bones scattered around (decoration)
	_create_bone_scatter(den, Vector3(-2, 0, 4))
	_create_bone_scatter(den, Vector3(1.5, 0, 5))
	_create_bone_scatter(den, Vector3(-0.5, 0, 6))

	print("[WolfDenForest] Wolf den created")


func _create_bone_scatter(parent: Node3D, pos: Vector3) -> void:
	# Simple bone representation using small white cylinders
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.9, 0.88, 0.82)
	bone_mat.roughness = 0.9

	for i in range(3):
		var bone := CSGCylinder3D.new()
		bone.name = "Bone_%d" % i
		bone.radius = 0.04
		bone.height = 0.3 + randf_range(-0.1, 0.15)
		bone.sides = 4
		bone.position = pos + Vector3(randf_range(-0.3, 0.3), 0.02, randf_range(-0.3, 0.3))
		bone.rotation_degrees = Vector3(85 + randf_range(-10, 10), randf_range(0, 180), 0)
		bone.material = bone_mat
		parent.add_child(bone)


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	# Player spawn from Thornfield (south entrance)
	var from_thornfield := Node3D.new()
	from_thornfield.name = "from_thornfield"
	from_thornfield.position = Vector3(0, 1.0, 18)
	from_thornfield.add_to_group("spawn_points")
	from_thornfield.set_meta("spawn_id", "from_thornfield")
	add_child(from_thornfield)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 18)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[WolfDenForest] Spawn points created at: ", from_thornfield.position)


func _spawn_exit_door() -> void:
	# Exit portal at south end (back to wilderness near Thornfield)
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 20),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_wolf_den",
		"Exit to Forest"
	)
	portal.rotation.y = PI
	portal.show_frame = false
	print("[WolfDenForest] Spawned exit portal")


## ============================================================================
## WOLF SPAWNS
## ============================================================================

func _spawn_wolves() -> void:
	# 5+ wolves for the wolf_pack_menace quest "kill_wolves" objective
	_spawn_wolf(Vector3(-5, 0, -5))
	_spawn_wolf(Vector3(4, 0, -6))
	_spawn_wolf(Vector3(-3, 0, 2))
	_spawn_wolf(Vector3(6, 0, 0))
	_spawn_wolf(Vector3(0, 0, 5))
	_spawn_wolf(Vector3(-8, 0, -2))

	# Dire wolf pack leader boss
	_spawn_dire_wolf(Vector3(0, 0, -8))

	print("[WolfDenForest] Spawned wolf pack")


func _spawn_wolf(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/beasts/wolf.png")
	if not sprite:
		sprite = load("res://assets/sprites/enemies/undead/skeleton_shade_walking.png")
	if not sprite:
		push_warning("[WolfDenForest] Missing wolf sprite")
		return

	var data_path := "res://data/enemies/wolf.tres"
	if not ResourceLoader.exists(data_path):
		push_warning("[WolfDenForest] Missing wolf enemy data")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		3, 1  # h_frames, v_frames for wolf sprite
	)
	if enemy:
		enemy.add_to_group("wolf_pack")
		enemy.add_to_group("wolf")  # For quest objective tracking
		print("[WolfDenForest] Spawned wolf at %s" % pos)


func _spawn_dire_wolf(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/beasts/wolf.png")
	if not sprite:
		sprite = load("res://assets/sprites/enemies/undead/skeleton_shade_walking.png")
	if not sprite:
		push_warning("[WolfDenForest] Missing dire wolf sprite")
		return

	var data_path := "res://data/enemies/dire_wolf.tres"
	if not ResourceLoader.exists(data_path):
		data_path = "res://data/enemies/wolf.tres"

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		data_path,
		sprite,
		3, 1
	)
	if enemy:
		enemy.add_to_group("wolf_pack")
		enemy.add_to_group("dire_wolf")  # For quest objective tracking
		enemy.add_to_group("bosses")
		print("[WolfDenForest] Spawned Dire Wolf (BOSS) at %s" % pos)


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Hidden cache near the den
	var den_chest := Chest.spawn_chest(
		self,
		Vector3(-4, 0, -10),
		"Hunter's Lost Cache",
		false, 0,
		false, "wolf_den_cache"
	)
	if den_chest:
		den_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	# Wolf pelts can also drop from wolf corpses via loot system
	print("[WolfDenForest] Spawned loot")


## ============================================================================
## LIGHTING
## ============================================================================

func _create_lighting() -> void:
	# Forest canopy filtered light
	var sun := DirectionalLight3D.new()
	sun.name = "ForestLight"
	sun.light_color = Color(0.75, 0.82, 0.65)
	sun.light_energy = 0.7
	sun.rotation_degrees = Vector3(-50, 25, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Ambient forest glow
	var ambient := OmniLight3D.new()
	ambient.name = "AmbientLight"
	ambient.light_color = Color(0.45, 0.55, 0.42)
	ambient.light_energy = 0.3
	ambient.omni_range = 40.0
	ambient.position = Vector3(0, 10, 0)
	add_child(ambient)

	# Eerie glow near the den
	var den_light := OmniLight3D.new()
	den_light.name = "DenLight"
	den_light.light_color = Color(0.3, 0.35, 0.28)
	den_light.light_energy = 0.5
	den_light.omni_range = 8.0
	den_light.position = Vector3(0, 2, -10)
	add_child(den_light)

	print("[WolfDenForest] Created lighting")
