## harvestable_rock.gd - Interactable rock that yields stone/ore when mined with a pickaxe
class_name HarvestableRock
extends StaticBody3D

signal harvested(yield_amount: int)

## Rock types with different yields
enum RockType { STONE, IRON_VEIN, RICH_IRON }

## Visual representation
var mesh: CSGBox3D
var interaction_area: Area3D
var collision_shape: CollisionShape3D

## Harvest state
var has_been_harvested: bool = false

## Configuration
@export var rock_type: RockType = RockType.STONE
@export var yield_min: int = 1
@export var yield_max: int = 2
@export var display_name: String = "Rock"

## Rock material
var rock_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("harvestable_rocks")
	add_to_group("interactable")

	_setup_material()
	_setup_collision()
	_setup_interaction_area()
	_setup_visuals()


func _setup_material() -> void:
	rock_material = StandardMaterial3D.new()
	rock_material.roughness = 0.95
	rock_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	# Use stone texture
	var stone_tex: Texture2D = load("res://Sprite folders grab bag/stonewall.png")
	if stone_tex:
		rock_material.albedo_texture = stone_tex
		rock_material.uv1_scale = Vector3(0.3, 0.3, 0.3)
	else:
		rock_material.albedo_color = Color(0.4, 0.38, 0.35)

	# Apply color tint based on rock type
	match rock_type:
		RockType.STONE:
			rock_material.albedo_color = Color(0.75, 0.73, 0.7)  # Gray stone
		RockType.IRON_VEIN:
			rock_material.albedo_color = Color(0.6, 0.5, 0.45)  # Brownish-gray with iron
		RockType.RICH_IRON:
			rock_material.albedo_color = Color(0.5, 0.35, 0.3)  # Dark rust color


func _setup_collision() -> void:
	collision_layer = 1  # World layer
	collision_mask = 0   # Doesn't collide with anything


func _setup_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2  # Detection radius for rocks
	area_shape.shape = sphere
	interaction_area.add_child(area_shape)


func _setup_visuals() -> void:
	# Random rock size
	var size_x: float = randf_range(0.8, 2.0)
	var size_y: float = randf_range(0.5, 1.5)
	var size_z: float = randf_range(0.8, 2.0)

	mesh = CSGBox3D.new()
	mesh.name = "RockMesh"
	mesh.size = Vector3(size_x, size_y, size_z)
	mesh.position = Vector3(0, size_y / 2.0, 0)
	mesh.rotation_degrees = Vector3(
		randf_range(-15, 15),
		randf_range(0, 360),
		randf_range(-15, 15)
	)
	mesh.material = rock_material
	mesh.use_collision = true
	add_child(mesh)


## Check if player has a pickaxe equipped
func _has_pickaxe_equipped() -> bool:
	var weapon: WeaponData = InventoryManager.get_equipped_weapon()
	if not weapon:
		return false
	return weapon.weapon_type == Enums.WeaponType.PICKAXE


## Called by player interaction system
func interact(_interactor: Node) -> void:
	if has_been_harvested:
		return

	if not _has_pickaxe_equipped():
		# Show notification that pickaxe is required
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Requires a Pickaxe to mine")
		return

	# Calculate yields based on rock type
	var yields: Array[Dictionary] = _get_yields_for_rock_type()
	var success := true
	var notification_parts: Array[String] = []

	# Try to add all items
	for yield_info: Dictionary in yields:
		var item_id: String = yield_info["item_id"]
		var amount: int = randi_range(yield_info["min"], yield_info["max"])
		if amount > 0:
			if InventoryManager.add_item(item_id, amount):
				QuestManager.on_item_collected(item_id, amount)
				notification_parts.append("%d %s" % [amount, InventoryManager.get_item_name(item_id)])
			else:
				success = false
				break

	if success and notification_parts.size() > 0:
		has_been_harvested = true

		# Play sound
		AudioManager.play_item_pickup()

		# Calculate total yield for signal
		var total_yield := 0
		for yield_info: Dictionary in yields:
			total_yield += randi_range(yield_info["min"], yield_info["max"])

		# Emit signal
		harvested.emit(total_yield)

		# Show notification
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Mined: " + ", ".join(notification_parts))

		# Visual feedback - remove the rock
		_on_harvested()
	elif not success:
		# Inventory full
		var hud := _interactor.get_tree().get_first_node_in_group("hud") if _interactor else null
		if hud and hud.has_method("show_notification"):
			hud.show_notification("Inventory full!")


## Get yield items based on rock type
func _get_yields_for_rock_type() -> Array[Dictionary]:
	var yields: Array[Dictionary] = []

	match rock_type:
		RockType.STONE:
			# Stone: 2-4 stone_block
			yields.append({"item_id": "stone_block", "min": 2, "max": 4})
		RockType.IRON_VEIN:
			# Iron vein: 1-2 iron_ore + 1-2 stone_block
			yields.append({"item_id": "iron_ore", "min": 1, "max": 2})
			yields.append({"item_id": "stone_block", "min": 1, "max": 2})
		RockType.RICH_IRON:
			# Rich iron: 2-4 iron_ore
			yields.append({"item_id": "iron_ore", "min": 2, "max": 4})

	return yields


func _on_harvested() -> void:
	# Remove from interactable group so prompt doesn't show
	remove_from_group("interactable")

	# Hide the rock mesh (disappears when mined)
	if mesh:
		mesh.visible = false

	# Disable collision
	collision_layer = 0


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if has_been_harvested:
		return ""
	if not _has_pickaxe_equipped():
		return display_name + " (requires Pickaxe)"
	return "Mine " + display_name


## Static factory method for spawning rocks
static func spawn_rock(parent: Node, pos: Vector3, p_display_name: String = "Rock", p_rock_type: RockType = RockType.STONE) -> HarvestableRock:
	var instance := HarvestableRock.new()
	instance.rock_type = p_rock_type
	instance.display_name = p_display_name
	instance.position = pos

	# Set yield ranges based on rock type
	match p_rock_type:
		RockType.STONE:
			instance.yield_min = 2
			instance.yield_max = 4
		RockType.IRON_VEIN:
			instance.yield_min = 2
			instance.yield_max = 4
		RockType.RICH_IRON:
			instance.yield_min = 2
			instance.yield_max = 4

	parent.add_child(instance)
	return instance


## Static factory method for spawning random rock type (weighted by biome)
static func spawn_random_rock(parent: Node, pos: Vector3, highlands: bool = false) -> HarvestableRock:
	var roll: float = randf()
	var rock_type_sel: RockType
	var name: String

	if highlands:
		# Highlands have more iron
		if roll < 0.5:
			rock_type_sel = RockType.STONE
			name = "Rock"
		elif roll < 0.85:
			rock_type_sel = RockType.IRON_VEIN
			name = "Iron Vein"
		else:
			rock_type_sel = RockType.RICH_IRON
			name = "Rich Iron Deposit"
	else:
		# Normal areas - mostly stone
		if roll < 0.8:
			rock_type_sel = RockType.STONE
			name = "Rock"
		elif roll < 0.95:
			rock_type_sel = RockType.IRON_VEIN
			name = "Iron Vein"
		else:
			rock_type_sel = RockType.RICH_IRON
			name = "Rich Iron Deposit"

	return spawn_rock(parent, pos, name, rock_type_sel)
