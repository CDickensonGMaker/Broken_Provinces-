## millbrook_bandit_camp.gd - Millbrook Bandit Camp (Hand-crafted dungeon)
## Larger bandit camp in the woods east of Millbrook
## Contains: 6+ bandits, 1 bandit captain boss, stolen goods, camp structures
extends Node3D

const ZONE_ID := "millbrook_bandit_camp"

## Materials
var dirt_mat: StandardMaterial3D
var grass_mat: StandardMaterial3D
var wood_mat: StandardMaterial3D
var canvas_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D
var log_mat: StandardMaterial3D

## Navigation
var nav_region: NavigationRegion3D

## Node containers
var spawn_points: Node3D
var enemy_spawns: Node3D
var door_positions: Node3D
var chest_positions: Node3D


func _ready() -> void:
	SaveManager.set_current_zone(ZONE_ID, "Bandit Camp")

	_create_materials()
	_setup_navigation()
	_create_camp_terrain()
	_create_camp_structures()
	_spawn_spawn_points()
	_spawn_exit_door()
	_spawn_enemies()
	_spawn_loot()
	_spawn_quest_items()
	_create_lighting()

	# Quest trigger for entering the camp
	QuestManager.on_location_reached("millbrook_bandit_camp")

	print("[MillbrookBanditCamp] Camp initialized!")


func _create_materials() -> void:
	# Dirt ground
	dirt_mat = StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.35, 0.28, 0.2)
	dirt_mat.roughness = 0.95

	# Forest grass
	grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.22, 0.32, 0.18)
	grass_mat.roughness = 0.95

	# Wooden structures
	wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.3, 0.2)
	wood_mat.roughness = 0.9

	# Tent canvas
	canvas_mat = StandardMaterial3D.new()
	canvas_mat.albedo_color = Color(0.45, 0.4, 0.35)
	canvas_mat.roughness = 0.85

	# Rocks
	rock_mat = StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.4, 0.38, 0.36)
	rock_mat.roughness = 0.9

	# Logs
	log_mat = StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.38, 0.28, 0.18)
	log_mat.roughness = 0.9


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
		print("[MillbrookBanditCamp] Navigation mesh baked!")


## ============================================================================
## CAMP LAYOUT - Clearing in the forest with tents and fortifications
## ============================================================================

func _create_camp_terrain() -> void:
	# Large clearing ground (35x40)
	var ground := CSGBox3D.new()
	ground.name = "CampGround"
	ground.size = Vector3(40, 1, 45)
	ground.position = Vector3(0, -0.5, 0)
	ground.material = dirt_mat
	ground.use_collision = true
	add_child(ground)

	# Grass border around camp
	var grass_north := CSGBox3D.new()
	grass_north.name = "GrassNorth"
	grass_north.size = Vector3(50, 0.5, 15)
	grass_north.position = Vector3(0, -0.25, -27)
	grass_north.material = grass_mat
	grass_north.use_collision = true
	add_child(grass_north)

	var grass_south := CSGBox3D.new()
	grass_south.name = "GrassSouth"
	grass_south.size = Vector3(50, 0.5, 15)
	grass_south.position = Vector3(0, -0.25, 27)
	grass_south.material = grass_mat
	grass_south.use_collision = true
	add_child(grass_south)

	var grass_east := CSGBox3D.new()
	grass_east.name = "GrassEast"
	grass_east.size = Vector3(15, 0.5, 45)
	grass_east.position = Vector3(27, -0.25, 0)
	grass_east.material = grass_mat
	grass_east.use_collision = true
	add_child(grass_east)

	var grass_west := CSGBox3D.new()
	grass_west.name = "GrassWest"
	grass_west.size = Vector3(15, 0.5, 45)
	grass_west.position = Vector3(-27, -0.25, 0)
	grass_west.material = grass_mat
	grass_west.use_collision = true
	add_child(grass_west)

	# Scattered rocks around the perimeter
	_create_rock(Vector3(-16, 0, -15), 1.2)
	_create_rock(Vector3(15, 0, -12), 1.5)
	_create_rock(Vector3(-14, 0, 14), 1.3)
	_create_rock(Vector3(17, 0, 16), 1.0)
	_create_rock(Vector3(-8, 0, -18), 0.8)
	_create_rock(Vector3(10, 0, 18), 1.1)

	print("[MillbrookBanditCamp] Camp terrain created")


func _create_rock(pos: Vector3, size_mult: float) -> void:
	var rock := CSGSphere3D.new()
	rock.name = "Rock"
	rock.radius = 0.8 * size_mult
	rock.position = Vector3(pos.x, rock.radius * 0.6, pos.z)
	rock.material = rock_mat
	rock.use_collision = true
	# Slight random deformation via non-uniform scale
	rock.scale = Vector3(
		randf_range(0.8, 1.2),
		randf_range(0.6, 0.9),
		randf_range(0.8, 1.2)
	)
	add_child(rock)


func _create_camp_structures() -> void:
	# Main tent (Captain's tent) - larger
	_create_tent(Vector3(0, 0, -10), 6.0, 4.5, "CaptainTent")

	# Smaller tents for bandits
	_create_tent(Vector3(-10, 0, -5), 4.0, 3.0, "BanditTent1")
	_create_tent(Vector3(10, 0, -5), 4.0, 3.0, "BanditTent2")
	_create_tent(Vector3(-8, 0, 8), 4.0, 3.0, "BanditTent3")
	_create_tent(Vector3(8, 0, 8), 4.0, 3.0, "BanditTent4")

	# Campfire in center
	_create_campfire(Vector3(0, 0, 2))

	# Log seating around campfire
	_create_log_seat(Vector3(-3, 0, 2))
	_create_log_seat(Vector3(3, 0, 2))
	_create_log_seat(Vector3(0, 0, 5))

	# Weapon rack
	_create_weapon_rack(Vector3(-12, 0, -10))

	# Supply crates near captain's tent
	_create_supply_crates(Vector3(5, 0, -12))

	# Wooden barricade at entrance (south)
	_create_barricade(Vector3(0, 0, 18))

	print("[MillbrookBanditCamp] Camp structures created")


func _create_tent(pos: Vector3, width: float, depth: float, tent_name: String) -> void:
	var tent := Node3D.new()
	tent.name = tent_name
	tent.position = pos
	add_child(tent)

	# Tent base (floor)
	var floor_box := CSGBox3D.new()
	floor_box.name = "Floor"
	floor_box.size = Vector3(width, 0.1, depth)
	floor_box.position = Vector3(0, 0.05, 0)
	floor_box.material = canvas_mat
	floor_box.use_collision = true
	tent.add_child(floor_box)

	# Tent poles
	var pole_height := depth * 0.8
	var left_pole := CSGCylinder3D.new()
	left_pole.name = "LeftPole"
	left_pole.radius = 0.08
	left_pole.height = pole_height
	left_pole.position = Vector3(-width * 0.4, pole_height / 2.0, 0)
	left_pole.material = wood_mat
	left_pole.use_collision = true
	tent.add_child(left_pole)

	var right_pole := CSGCylinder3D.new()
	right_pole.name = "RightPole"
	right_pole.radius = 0.08
	right_pole.height = pole_height
	right_pole.position = Vector3(width * 0.4, pole_height / 2.0, 0)
	right_pole.material = wood_mat
	right_pole.use_collision = true
	tent.add_child(right_pole)

	# Tent canvas (simplified as sloped roof)
	var canvas := CSGBox3D.new()
	canvas.name = "Canvas"
	canvas.size = Vector3(width * 1.1, 0.1, depth * 1.2)
	canvas.position = Vector3(0, pole_height * 0.85, 0)
	canvas.rotation_degrees.x = 8  # Slight slope
	canvas.material = canvas_mat
	canvas.use_collision = true
	tent.add_child(canvas)


func _create_campfire(pos: Vector3) -> void:
	var fire := Node3D.new()
	fire.name = "Campfire"
	fire.position = pos
	add_child(fire)

	# Stone ring
	var ring := CSGTorus3D.new()
	ring.name = "StoneRing"
	ring.inner_radius = 0.8
	ring.outer_radius = 1.2
	ring.ring_sides = 6
	ring.sides = 8
	ring.position = Vector3(0, 0.15, 0)
	ring.material = rock_mat
	ring.use_collision = true
	fire.add_child(ring)

	# Fire light
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = Color(1.0, 0.6, 0.2)
	light.light_energy = 2.5
	light.omni_range = 12.0
	light.position = Vector3(0, 1.0, 0)
	fire.add_child(light)


func _create_log_seat(pos: Vector3) -> void:
	var log := CSGCylinder3D.new()
	log.name = "LogSeat"
	log.radius = 0.3
	log.height = 2.0
	log.sides = 8
	log.position = Vector3(pos.x, 0.3, pos.z)
	log.rotation_degrees.z = 90  # Horizontal
	log.material = log_mat
	log.use_collision = true
	add_child(log)


func _create_weapon_rack(pos: Vector3) -> void:
	var rack := Node3D.new()
	rack.name = "WeaponRack"
	rack.position = pos
	add_child(rack)

	# Vertical posts
	var post1 := CSGBox3D.new()
	post1.name = "Post1"
	post1.size = Vector3(0.15, 2.0, 0.15)
	post1.position = Vector3(-0.8, 1.0, 0)
	post1.material = wood_mat
	post1.use_collision = true
	rack.add_child(post1)

	var post2 := CSGBox3D.new()
	post2.name = "Post2"
	post2.size = Vector3(0.15, 2.0, 0.15)
	post2.position = Vector3(0.8, 1.0, 0)
	post2.material = wood_mat
	post2.use_collision = true
	rack.add_child(post2)

	# Horizontal bars
	var bar1 := CSGBox3D.new()
	bar1.name = "Bar1"
	bar1.size = Vector3(2.0, 0.1, 0.1)
	bar1.position = Vector3(0, 1.6, 0)
	bar1.material = wood_mat
	bar1.use_collision = true
	rack.add_child(bar1)

	var bar2 := CSGBox3D.new()
	bar2.name = "Bar2"
	bar2.size = Vector3(2.0, 0.1, 0.1)
	bar2.position = Vector3(0, 0.8, 0)
	bar2.material = wood_mat
	bar2.use_collision = true
	rack.add_child(bar2)


func _create_supply_crates(pos: Vector3) -> void:
	var crates := Node3D.new()
	crates.name = "SupplyCrates"
	crates.position = pos
	add_child(crates)

	# Several crates stacked
	var crate1 := CSGBox3D.new()
	crate1.name = "Crate1"
	crate1.size = Vector3(1.2, 1.0, 1.2)
	crate1.position = Vector3(0, 0.5, 0)
	crate1.material = wood_mat
	crate1.use_collision = true
	crates.add_child(crate1)

	var crate2 := CSGBox3D.new()
	crate2.name = "Crate2"
	crate2.size = Vector3(1.0, 0.8, 1.0)
	crate2.position = Vector3(1.3, 0.4, 0.2)
	crate2.material = wood_mat
	crate2.use_collision = true
	crates.add_child(crate2)

	var crate3 := CSGBox3D.new()
	crate3.name = "Crate3"
	crate3.size = Vector3(0.8, 0.7, 0.8)
	crate3.position = Vector3(0.3, 1.35, 0.1)
	crate3.rotation_degrees.y = 15
	crate3.material = wood_mat
	crate3.use_collision = true
	crates.add_child(crate3)


func _create_barricade(pos: Vector3) -> void:
	var barricade := Node3D.new()
	barricade.name = "Barricade"
	barricade.position = pos
	add_child(barricade)

	# Horizontal logs forming a barrier
	for i in range(5):
		var log := CSGCylinder3D.new()
		log.name = "BarricadeLog_%d" % i
		log.radius = 0.25
		log.height = 3.0
		log.sides = 8
		log.position = Vector3(-4 + i * 2, 0.8, 0)
		log.rotation_degrees.z = 90 + randf_range(-5, 5)  # Slight variation
		log.material = log_mat
		log.use_collision = true
		barricade.add_child(log)

	# Support stakes
	for i in range(3):
		var stake := CSGCylinder3D.new()
		stake.name = "Stake_%d" % i
		stake.radius = 0.12
		stake.height = 1.5
		stake.sides = 6
		stake.position = Vector3(-3 + i * 3, 0.75, 0.5)
		stake.rotation_degrees.x = 25  # Angled forward
		stake.material = wood_mat
		stake.use_collision = true
		barricade.add_child(stake)


## ============================================================================
## SPAWN POINTS
## ============================================================================

func _spawn_spawn_points() -> void:
	# Player spawn from Millbrook (south entrance)
	var from_millbrook := Node3D.new()
	from_millbrook.name = "from_millbrook"
	from_millbrook.position = Vector3(0, 1.0, 22)
	from_millbrook.add_to_group("spawn_points")
	from_millbrook.set_meta("spawn_id", "from_millbrook")
	add_child(from_millbrook)

	# Default spawn
	var default_spawn := Node3D.new()
	default_spawn.name = "default_spawn"
	default_spawn.position = Vector3(0, 1.0, 22)
	default_spawn.add_to_group("spawn_points")
	default_spawn.set_meta("spawn_id", "default")
	add_child(default_spawn)

	print("[MillbrookBanditCamp] Spawn points created at: ", from_millbrook.position)


func _spawn_exit_door() -> void:
	# Exit portal at south end (back to wilderness near Millbrook)
	var portal := ZoneDoor.spawn_door(
		self,
		Vector3(0, 0, 25),
		SceneManager.RETURN_TO_WILDERNESS,
		"from_millbrook_bandit_camp",
		"Exit to Wilderness"
	)
	portal.rotation.y = PI  # Face into the camp
	portal.show_frame = false  # No door frame for outdoor exit
	print("[MillbrookBanditCamp] Spawned exit portal")


## ============================================================================
## ENEMY SPAWNS
## ============================================================================

func _spawn_enemies() -> void:
	# 6+ regular bandits spread around the camp
	_spawn_bandit(Vector3(-8, 0, -3))   # Near tent 1
	_spawn_bandit(Vector3(9, 0, -4))    # Near tent 2
	_spawn_bandit(Vector3(-6, 0, 9))    # Near tent 3
	_spawn_bandit(Vector3(7, 0, 10))    # Near tent 4
	_spawn_bandit(Vector3(-2, 0, 5))    # Near campfire
	_spawn_bandit(Vector3(3, 0, 3))     # Near campfire
	_spawn_bandit(Vector3(0, 0, 15))    # Near barricade (guard)

	# Bandit Captain boss in front of captain's tent
	_spawn_bandit_captain(Vector3(0, 0, -6))

	print("[MillbrookBanditCamp] Spawned enemies")


func _spawn_bandit(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/human_bandit.png")
	if not sprite:
		push_warning("[MillbrookBanditCamp] Missing bandit sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/human_bandit.tres",
		sprite,
		3, 1  # h_frames, v_frames for bandit sprite
	)
	if enemy:
		enemy.add_to_group("millbrook_camp_bandits")
		print("[MillbrookBanditCamp] Spawned bandit at %s" % pos)


func _spawn_bandit_captain(pos: Vector3) -> void:
	var sprite: Texture2D = load("res://assets/sprites/enemies/human_bandit.png")
	if not sprite:
		push_warning("[MillbrookBanditCamp] Missing bandit sprite")
		return

	var enemy := EnemyBase.spawn_billboard_enemy(
		self,
		pos,
		"res://data/enemies/bandit_captain.tres",
		sprite,
		3, 1  # h_frames, v_frames
	)
	if enemy:
		enemy.add_to_group("millbrook_camp_bandits")
		enemy.add_to_group("bosses")
		print("[MillbrookBanditCamp] Spawned Bandit Captain (BOSS) at %s" % pos)


## ============================================================================
## LOOT
## ============================================================================

func _spawn_loot() -> void:
	# Captain's chest in the main tent
	var captain_chest := Chest.spawn_chest(
		self,
		Vector3(0, 0, -12),
		"Captain's Strongbox",
		true, 15,  # Locked with DC 15
		false, "millbrook_captain_chest"
	)
	if captain_chest:
		captain_chest.setup_with_loot(LootTables.LootTier.RARE)

	# Supply chest near crates
	var supply_chest := Chest.spawn_chest(
		self,
		Vector3(7, 0, -11),
		"Stolen Supplies",
		false, 0,
		false, "millbrook_supply_chest"
	)
	if supply_chest:
		supply_chest.setup_with_loot(LootTables.LootTier.UNCOMMON)

	print("[MillbrookBanditCamp] Spawned loot chests")


## ============================================================================
## QUEST ITEMS - Stolen goods for millbrook_bandits quest
## ============================================================================

func _spawn_quest_items() -> void:
	# Stolen goods collectible for the "recover_goods" objective
	# Uses WorldItem which automatically triggers QuestManager.on_item_collected()
	var stolen_goods_pos := Vector3(-3, 0, -11)

	# Use WorldItem.spawn_item which handles interaction, collection, and quest updates
	var goods := WorldItem.spawn_item(
		self,
		stolen_goods_pos,
		"stolen_goods",  # item_id - must exist in InventoryManager databases
		Enums.ItemQuality.AVERAGE,
		1  # quantity
	)
	if goods:
		goods.add_to_group("quest_items")
		print("[MillbrookBanditCamp] Spawned stolen goods at %s" % stolen_goods_pos)


## ============================================================================
## LIGHTING
## ============================================================================

func _create_lighting() -> void:
	# Directional light (sun through trees)
	var sun := DirectionalLight3D.new()
	sun.name = "SunLight"
	sun.light_color = Color(0.85, 0.8, 0.65)
	sun.light_energy = 0.6
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	# Ambient fill light
	var ambient := OmniLight3D.new()
	ambient.name = "AmbientLight"
	ambient.light_color = Color(0.5, 0.55, 0.6)
	ambient.light_energy = 0.4
	ambient.omni_range = 50.0
	ambient.position = Vector3(0, 15, 0)
	add_child(ambient)

	# Torch lights at tent entrances
	_spawn_torch_light(Vector3(-10, 2, -3))
	_spawn_torch_light(Vector3(10, 2, -3))
	_spawn_torch_light(Vector3(-8, 2, 10))
	_spawn_torch_light(Vector3(8, 2, 10))

	print("[MillbrookBanditCamp] Created lighting")


func _spawn_torch_light(pos: Vector3) -> void:
	var light := OmniLight3D.new()
	light.name = "TorchLight"
	light.light_color = Color(1.0, 0.7, 0.3)
	light.light_energy = 1.5
	light.omni_range = 8.0
	light.position = pos
	add_child(light)
