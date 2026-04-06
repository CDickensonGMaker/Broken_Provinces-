## cave_door_test.gd - Test scene for cave entrance/exit doors
## Tests player entering a cave from the outside and exiting back
extends Node3D

const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"

var _hud: CanvasLayer
var _player_spawned: bool = false


func _ready() -> void:
	_initialize_game_state()
	_setup_hud()
	_spawn_player()
	_setup_doors()
	_setup_environment()


func _spawn_player() -> void:
	var spawn_pos: Vector3 = Vector3(0, 0.5, 5)  # Default spawn
	var spawn_id: String = "default"

	# Check if coming from cave
	if SceneManager.spawn_point_id != "":
		spawn_id = SceneManager.spawn_point_id

	# Find matching spawn point
	var spawn_points: Node3D = get_node_or_null("SpawnPoints")
	if spawn_points:
		for marker: Node in spawn_points.get_children():
			if marker is Marker3D:
				var marker_spawn_id: String = marker.get_meta("spawn_id", "")
				if marker_spawn_id == spawn_id:
					spawn_pos = marker.global_position
					break

	# Get or create player
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = spawn_pos
		print("[CaveDoorTest] Teleported player to %s (spawn_id: %s)" % [str(spawn_pos), spawn_id])
	else:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos
			print("[CaveDoorTest] Spawned player at %s" % str(spawn_pos))

	_player_spawned = true


func _setup_doors() -> void:
	var door_positions: Node3D = get_node_or_null("DoorPositions")
	if not door_positions:
		return

	for marker: Node in door_positions.get_children():
		if not marker is Marker3D:
			continue

		var target_scene: String = marker.get_meta("target_scene", "")
		var spawn_id: String = marker.get_meta("spawn_id", "default")
		var door_label: String = marker.get_meta("door_label", "Enter")
		var show_frame: bool = marker.get_meta("show_frame", false)

		if target_scene.is_empty():
			continue

		var door: ZoneDoor = ZoneDoor.spawn_door(
			self,
			marker.global_position,
			target_scene,
			spawn_id,
			door_label,
			show_frame
		)

		if door:
			door.rotation = marker.rotation
			print("[CaveDoorTest] Spawned door '%s' -> %s" % [door_label, target_scene])


func _setup_environment() -> void:
	# Add environment if not present
	var world_env: WorldEnvironment = get_node_or_null("Lighting/WorldEnvironment")
	if world_env and not world_env.environment:
		var env := Environment.new()
		env.background_mode = Environment.BG_SKY

		var sky := Sky.new()
		var sky_material := ProceduralSkyMaterial.new()
		sky_material.sky_top_color = Color(0.4, 0.6, 0.9)
		sky_material.sky_horizon_color = Color(0.7, 0.75, 0.85)
		sky_material.ground_bottom_color = Color(0.2, 0.17, 0.13)
		sky_material.ground_horizon_color = Color(0.5, 0.45, 0.4)
		sky.sky_material = sky_material
		env.sky = sky
		env.background_mode = Environment.BG_SKY

		env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		env.ambient_light_energy = 0.5

		world_env.environment = env
		print("[CaveDoorTest] Created sky environment")


func _initialize_game_state() -> void:
	if GameManager.player_data and GameManager.player_data.character_name != "":
		if InventoryManager.inventory.size() > 0:
			return
		_give_test_items()
		return

	print("[CaveDoorTest] Initializing game state...")
	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()

	var char_data := CharacterData.new()
	char_data.race = Enums.Race.HUMAN
	char_data.character_name = "Cave Explorer"
	char_data.initialize_race_bonuses()
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana
	GameManager.player_data = char_data

	_give_test_items()


func _give_test_items() -> void:
	InventoryManager.add_item("iron_sword", 1)
	InventoryManager.add_item("leather_armor", 1)
	InventoryManager.add_item("health_potion", 5)
	InventoryManager.add_item("torch", 10)
	InventoryManager.add_gold(500)


func _setup_hud() -> void:
	var existing_hud := get_tree().get_first_node_in_group("hud")
	if existing_hud:
		return

	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)
