## crafting_test_scene.gd - Dev test scene with all crafting stations and universal merchant
## Allows testing: alchemy, cooking, enchanting, repair, crafting, and buying any item
extends Node3D

const ZONE_ID := "crafting_test"

## Player reference
var player: CharacterBody3D

func _ready() -> void:
	_setup_environment()
	_setup_player()
	_spawn_stations()
	_spawn_universal_merchant()
	_give_test_resources()
	_print_instructions()


func _setup_environment() -> void:
	## Create flat floor and basic lighting

	# Large flat floor (100x100)
	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(100, 0.5, 100)
	floor_mesh.mesh = box
	floor_mesh.position = Vector3(0, -0.25, 0)

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.3, 0.3, 0.28)
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)

	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 0.5, 100)
	floor_col.shape = floor_shape
	floor_col.position = Vector3(0, -0.25, 0)
	floor_body.add_child(floor_col)

	# Directional light (sun)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-45, 45, 0)
	sun.light_energy = 1.2
	add_child(sun)

	# Fill light (softer from opposite direction)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-30, -135, 0)
	fill.light_energy = 0.4
	add_child(fill)

	# World environment for ambient light
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.15, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.5)

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _setup_player() -> void:
	## Spawn player at origin

	var player_scene: PackedScene = load("res://scenes/player/player.tscn")
	if player_scene:
		player = player_scene.instantiate()
		player.position = Vector3(0, 0.5, 0)
		add_child(player)

	# Spawn HUD
	var hud_scene: PackedScene = load("res://scenes/ui/hud.tscn")
	if hud_scene:
		var hud: CanvasLayer = hud_scene.instantiate()
		add_child(hud)


func _spawn_stations() -> void:
	## Spawn all 4 crafting/enchanting stations in a row

	var stations := Node3D.new()
	stations.name = "Stations"
	add_child(stations)

	# Station positions - arranged in a semicircle in front of player spawn
	# Alchemy station (potions)
	var alchemy := AlchemyStation.spawn_alchemy_station(stations, Vector3(-6, 0, -5))
	_add_station_label(stations, Vector3(-6, 1.5, -5), "ALCHEMY\n(Potions)")

	# Cooking station (food)
	var cooking := CookingStation.spawn_cooking_station(stations, Vector3(-2, 0, -5))
	_add_station_label(stations, Vector3(-2, 1.5, -5), "COOKING\n(Food)")

	# Enchanting station (soulstones/enchants)
	var enchanting := EnchantingStation.spawn_station(stations, Vector3(2, 0, -5))
	_add_station_label(stations, Vector3(2, 1.5, -5), "ENCHANTING\n(Soulstones)")

	# Repair station (anvil - repair/craft weapons/armor)
	var repair := RepairStation.spawn_station(stations, Vector3(6, 0, -5))
	_add_station_label(stations, Vector3(6, 1.5, -5), "ANVIL\n(Repair/Craft)")

	print("[CraftingTest] Spawned all 4 stations")


func _add_station_label(parent: Node3D, pos: Vector3, text: String) -> void:
	## Add a floating 3D label above a station
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 32
	label.modulate = Color(0, 1, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _spawn_universal_merchant() -> void:
	## Spawn a merchant that sells EVERYTHING in the game

	var merchant := Merchant.spawn_merchant(
		self,
		Vector3(0, 0, -8),  # Behind the stations
		"Universal Merchant",
		LootTables.LootTier.LEGENDARY,
		"general",
		"",  # Use default sprite
		5, 1,  # Standard sprite frames
		0.0518,  # Standard humanoid size
		false,
		""
	)

	if not merchant:
		push_error("[CraftingTest] Failed to spawn universal merchant!")
		return

	# Clear default inventory and add ALL items
	merchant.shop_inventory.clear()

	# Add ALL weapons
	for weapon_id in InventoryManager.weapon_database.keys():
		merchant.shop_inventory.append({
			"item_id": weapon_id,
			"price": 1,  # Cheap for testing
			"quantity": -1,  # Infinite
			"quality": Enums.ItemQuality.AVERAGE
		})

	# Add ALL armor
	for armor_id in InventoryManager.armor_database.keys():
		merchant.shop_inventory.append({
			"item_id": armor_id,
			"price": 1,
			"quantity": -1,
			"quality": Enums.ItemQuality.AVERAGE
		})

	# Add ALL items (consumables, materials, etc.)
	for item_id in InventoryManager.item_database.keys():
		merchant.shop_inventory.append({
			"item_id": item_id,
			"price": 1,
			"quantity": -1,
			"quality": Enums.ItemQuality.AVERAGE
		})

	# Add ALL spells as scrolls (if they have scroll items)
	for spell_id in InventoryManager.spell_database.keys():
		var scroll_id: String = "scroll_" + spell_id
		if InventoryManager.item_database.has(scroll_id):
			merchant.shop_inventory.append({
				"item_id": scroll_id,
				"price": 1,
				"quantity": -1,
				"quality": Enums.ItemQuality.AVERAGE
			})

	# Add floating label
	var label := Label3D.new()
	label.text = "UNIVERSAL MERCHANT\n(All Items 1g)"
	label.position = Vector3(0, 2.2, -8)
	label.font_size = 32
	label.modulate = Color(1, 0.8, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

	print("[CraftingTest] Universal merchant stocked with %d items" % merchant.shop_inventory.size())


func _give_test_resources() -> void:
	## Give player gold, materials, and soulstones for testing

	# Lots of gold
	InventoryManager.gold = 100000

	# Give player starting IP/XP for learning spells and skills
	if GameManager.player_data:
		GameManager.player_data.improvement_points = 50
		# Set Arcana Lore high enough to use enchanting station
		GameManager.player_data.set_skill(Enums.Skill.ARCANA_LORE, 5)

	# Give some crafting materials
	var test_materials: Array[String] = [
		"iron_ore", "iron_ingot", "steel_ingot", "coal",
		"leather", "leather_strip", "wood_plank",
		"healing_herb", "red_herb", "empty_vial",
		"bread", "cheese", "cooked_meat", "ale",
		"soulstone_petty_empty", "soulstone_lesser_empty", "soulstone_common_empty",
		"soulstone_petty_filled", "soulstone_lesser_filled",
		"lockpick", "repair_kit"
	]

	for mat_id in test_materials:
		InventoryManager.add_item(mat_id, 20)

	print("[CraftingTest] Gave player 100k gold, 50 IP, and crafting materials")


func _print_instructions() -> void:
	print("")
	print("=== CRAFTING TEST SCENE ===")
	print("")
	print("Stations available:")
	print("  - ALCHEMY: Brew potions and consumables")
	print("  - COOKING: Cook food items")
	print("  - ENCHANTING: Use soulstones to enchant equipment")
	print("  - ANVIL: Repair equipment or craft weapons/armor")
	print("")
	print("Universal Merchant sells ALL items for 1 gold each.")
	print("")
	print("You have 100k gold, 50 IP, and basic crafting materials.")
	print("Arcana Lore is set to 5 (required for enchanting).")
	print("")
	print("Press E to interact with stations/merchant.")
	print("Press TAB for inventory, M for map, J for journal.")
	print("")
	print("=============================")
