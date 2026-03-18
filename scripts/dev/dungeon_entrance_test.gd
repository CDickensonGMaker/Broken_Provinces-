## dungeon_entrance_test.gd - Test scene for dungeon entrance/exit functionality
extends Node3D

const ZONE_ID := "dungeon_entrance_test"

## HUD scene for interaction prompts
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

var _hud: CanvasLayer


func _ready() -> void:
	print("[DungeonEntranceTest] Setting up test scene")

	# CRITICAL: Set this scene as the "previous" scene for dungeon exits
	# This is needed because we're running directly (F6) without going through SceneManager
	if SceneManager:
		SceneManager.previous_scene_path = scene_file_path
		SceneManager.previous_spawn_id = "default"
		print("[DungeonEntranceTest] Registered as previous scene for dungeon exits: %s" % scene_file_path)

	# Initialize game state for testing
	_initialize_game_state()

	# Setup HUD for interaction prompts
	_setup_hud()

	# Create dungeon entrance door
	var entrance_door: ZoneDoor = ZoneDoor.spawn_portal(
		self,
		Vector3(5, 0, 5),
		"res://scenes/dungeons/new_dungeon3.tscn",
		"default",
		"Enter Dungeon"
	)

	if entrance_door:
		print("[DungeonEntranceTest] Dungeon entrance portal created at (5, 0, 5)")

	# Also create a wooden door variant
	var wooden_door: ZoneDoor = ZoneDoor.spawn_door(
		self,
		Vector3(-5, 0, 5),
		"res://scenes/dungeons/new_dungeon3.tscn",
		"default",
		"Dungeon Door",
		true,
		ZoneDoor.DoorStyle.WOODEN
	)

	if wooden_door:
		print("[DungeonEntranceTest] Dungeon door created at (-5, 0, 5)")

	# Add some visual markers
	_add_markers()

	print("[DungeonEntranceTest] Setup complete - Walk to a door and press E to enter dungeon")
	print("[DungeonEntranceTest] Player starts at (0, 0.5, 0), doors are at X=5 and X=-5")


## Initialize game state for standalone testing
func _initialize_game_state() -> void:
	# Check if already initialized with items
	if GameManager.player_data and GameManager.player_data.character_name != "":
		if InventoryManager.inventory.size() > 0:
			print("[DungeonEntranceTest] Game state already initialized with %d items" % InventoryManager.inventory.size())
			return
		# Character exists but no items - just give items without resetting
		print("[DungeonEntranceTest] Character exists but inventory empty - giving items")
		_give_test_items()
		return

	# Full initialization - no character exists
	print("[DungeonEntranceTest] Initializing game state for testing...")

	# Reset game state
	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()

	# Create test character
	var char_data := CharacterData.new()
	char_data.race = Enums.Race.HUMAN
	char_data.character_name = "Test Hero"
	char_data.initialize_race_bonuses()
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana
	GameManager.player_data = char_data

	_give_test_items()
	print("[DungeonEntranceTest] Test character created with basic gear")


func _give_test_items() -> void:
	var sword_added: bool = InventoryManager.add_item("iron_sword", 1)
	var armor_added: bool = InventoryManager.add_item("leather_armor", 1)
	var potions_added: bool = InventoryManager.add_item("health_potion", 5)
	var torch_added: bool = InventoryManager.add_item("torch", 3)
	InventoryManager.add_gold(500)

	print("[DungeonEntranceTest] Test gear added - sword:%s armor:%s potions:%s torch:%s" % [sword_added, armor_added, potions_added, torch_added])
	print("[DungeonEntranceTest] Inventory count: %d items" % InventoryManager.inventory.size())


## Setup HUD for interaction prompts
func _setup_hud() -> void:
	# Check if HUD already exists
	var existing_hud := get_tree().get_first_node_in_group("hud")
	if existing_hud:
		print("[DungeonEntranceTest] HUD already exists")
		return

	# Load and add HUD
	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)
		print("[DungeonEntranceTest] HUD added to scene")
	else:
		push_warning("[DungeonEntranceTest] Failed to load HUD scene")


func _add_markers() -> void:
	# Add signs/markers near doors
	var portal_marker := _create_marker(Vector3(5, 2, 3), "Portal Entrance", Color(0.5, 0.2, 0.8))
	add_child(portal_marker)

	var door_marker := _create_marker(Vector3(-5, 2, 3), "Wooden Door", Color(0.6, 0.4, 0.2))
	add_child(door_marker)


func _create_marker(pos: Vector3, text: String, color: Color) -> Node3D:
	var marker := Node3D.new()
	marker.position = pos

	# Create a simple colored cube as a marker
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	mesh.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color * 0.5
	mesh.material_override = mat

	marker.add_child(mesh)
	return marker
