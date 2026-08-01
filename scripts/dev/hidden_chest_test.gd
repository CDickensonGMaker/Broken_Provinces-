## hidden_chest_test.gd - Dev testing scene for Hidden Chest Detection System
## Tests: Detection by proximity, skill checks, re-check on skill increase, reveal VFX
extends Node3D

const HiddenChestScript = preload("res://scripts/world/hidden_chest.gd")

const ZONE_ID := "hidden_chest_test"
const ROOM_SIZE := 30.0
const WALL_HEIGHT := 4.0
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## Scene references
var player: Node3D = null
var hidden_chests: Array = []  # Array of HiddenChest instances

## Test skill values
var test_bonus: int = 0


func _ready() -> void:
	print("[HiddenChestTest] Dev test scene loaded")
	print("[HiddenChestTest] Controls:")
	print("  F5 = Set detection bonus to 5 (early game)")
	print("  F6 = Set detection bonus to 10 (some investment)")
	print("  F7 = Set detection bonus to 15 (focused build)")
	print("  F8 = Set detection bonus to 20 (high investment)")
	print("  F9 = Set detection bonus to 25 (dedicated build)")
	print("  F10 = Reset all chests (respawn)")
	print("  F11 = Show chest states")
	print("")
	print("[HiddenChestTest] Walk near chests to trigger detection checks")
	print("[HiddenChestTest] Detection radius = 6 units (shown as circles)")

	_setup_room()
	_setup_test_player()
	_spawn_player()
	_spawn_hidden_chests()
	_setup_lighting()
	_create_detection_radius_indicators()


func _exit_tree() -> void:
	# Cleanup
	for chest in hidden_chests:
		if is_instance_valid(chest):
			if chest.chest_revealed.is_connected(_on_chest_revealed):
				chest.chest_revealed.disconnect(_on_chest_revealed)


## Set up a test player with configurable skills
func _setup_test_player() -> void:
	if not GameManager or not GameManager.player_data:
		return

	var pd: CharacterData = GameManager.player_data

	# Set player level
	pd.level = 5
	pd.improvement_points = 0

	# Set base stats
	pd.grit = 10
	pd.agility = 10
	pd.will = 10
	pd.knowledge = 10  # Base knowledge gives +10 to detection

	# Set skills for detection bonus calculation:
	# get_hidden_detection_bonus() = Knowledge + History + Investigation
	pd.skills[Enums.Skill.HISTORY] = 0
	pd.skills[Enums.Skill.INVESTIGATION] = 0

	# Full health/stamina/mana
	pd.max_hp = 100 + (pd.grit * 5)
	pd.current_hp = pd.max_hp
	pd.max_stamina = 100 + (pd.agility * 3)
	pd.current_stamina = pd.max_stamina
	pd.max_mana = 50 + (pd.will * 5)
	pd.current_mana = pd.max_mana

	_update_detection_bonus_display()
	print("[HiddenChestTest] Player set to level 5, detection bonus = %d" % pd.get_hidden_detection_bonus())


## Update detection bonus to target value by adjusting skills
func _set_detection_bonus(target_bonus: int) -> void:
	if not GameManager or not GameManager.player_data:
		return

	var pd: CharacterData = GameManager.player_data

	# Knowledge gives 10 base (from Knowledge stat)
	# We adjust History and Investigation to reach target
	var needed: int = target_bonus - pd.get_effective_stat(Enums.Stat.KNOWLEDGE)

	# Split evenly between History and Investigation
	var history_val: int = needed / 2
	var invest_val: int = needed - history_val

	pd.skills[Enums.Skill.HISTORY] = maxi(0, history_val)
	pd.skills[Enums.Skill.INVESTIGATION] = maxi(0, invest_val)

	test_bonus = pd.get_hidden_detection_bonus()
	_update_detection_bonus_display()
	print("[HiddenChestTest] Detection bonus set to %d (target was %d)" % [test_bonus, target_bonus])


func _update_detection_bonus_display() -> void:
	if GameManager and GameManager.player_data:
		test_bonus = GameManager.player_data.get_hidden_detection_bonus()


func _spawn_player() -> void:
	var spawn_pos := Vector3(0, 0.5, 0)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[HiddenChestTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	print("[HiddenChestTest] Player spawned at %s" % spawn_pos)


## Create the room floor and walls
func _setup_room() -> void:
	# Floor
	var floor_node := CSGBox3D.new()
	floor_node.name = "Floor"
	floor_node.size = Vector3(ROOM_SIZE, 0.5, ROOM_SIZE)
	floor_node.position = Vector3(0, -0.25, 0)
	floor_node.use_collision = true

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.4, 0.35, 0.3)  # Stone floor
	floor_node.material = floor_mat
	add_child(floor_node)

	# Create walls
	_create_wall("WallNorth", Vector3(0, WALL_HEIGHT / 2, -ROOM_SIZE / 2), Vector3(ROOM_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallSouth", Vector3(0, WALL_HEIGHT / 2, ROOM_SIZE / 2), Vector3(ROOM_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallEast", Vector3(ROOM_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ROOM_SIZE + 1))
	_create_wall("WallWest", Vector3(-ROOM_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ROOM_SIZE + 1))

	print("[HiddenChestTest] Room created (%.0f x %.0f)" % [ROOM_SIZE, ROOM_SIZE])


func _create_wall(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.use_collision = true

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.3, 0.28, 0.25)
	wall.material = wall_mat
	add_child(wall)


## Spawn hidden chests at various DCs for testing
func _spawn_hidden_chests() -> void:
	hidden_chests.clear()

	# Chest configurations: [position, dc, tier, name]
	var chest_configs: Array = [
		# Easy chests (DC 8-10) - should find early
		[Vector3(-8, 0, -8), 8, LootTables.LootTier.COMMON, "Easy Cache (DC 8)"],
		[Vector3(-8, 0, 0), 10, LootTables.LootTier.COMMON, "Easy Stash (DC 10)"],

		# Medium chests (DC 12-15) - requires some investment
		[Vector3(-8, 0, 8), 12, LootTables.LootTier.UNCOMMON, "Hidden Chest (DC 12)"],
		[Vector3(0, 0, 8), 15, LootTables.LootTier.UNCOMMON, "Secret Cache (DC 15)"],

		# Hard chests (DC 16-18) - focused build
		[Vector3(8, 0, 8), 16, LootTables.LootTier.RARE, "Concealed Coffer (DC 16)"],
		[Vector3(8, 0, 0), 18, LootTables.LootTier.RARE, "Ancient Hoard (DC 18)"],

		# Very hard chests (DC 20-22) - high investment
		[Vector3(8, 0, -8), 20, LootTables.LootTier.EPIC, "Lost Treasure (DC 20)"],
		[Vector3(0, 0, -8), 22, LootTables.LootTier.EPIC, "Forgotten Reliquary (DC 22)"],
	]

	for config: Array in chest_configs:
		var pos: Vector3 = config[0]
		var dc: int = config[1]
		var tier: LootTables.LootTier = config[2]
		var chest_name: String = config[3]

		var chest := HiddenChestScript.spawn_hidden_chest(
			self,
			pos,
			chest_name,
			dc,
			tier,
			false,  # not locked
			0
		)

		if chest:
			chest.chest_revealed.connect(_on_chest_revealed)
			hidden_chests.append(chest)

			# Create a label above the chest position
			_create_chest_label(pos, chest_name)

	print("[HiddenChestTest] Spawned %d hidden chests" % hidden_chests.size())


## Create a 3D label above chest position to show DC
func _create_chest_label(pos: Vector3, text: String) -> void:
	var label_3d := Label3D.new()
	label_3d.name = "Label_%s" % text.replace(" ", "_")
	label_3d.text = text
	label_3d.font_size = 32
	label_3d.pixel_size = 0.01
	label_3d.position = pos + Vector3(0, 2.5, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = Color(0.8, 0.7, 0.5)  # Faded gold
	add_child(label_3d)


## Create visual indicators for detection radius
func _create_detection_radius_indicators() -> void:
	for chest in hidden_chests:
		if is_instance_valid(chest):
			_create_circle_indicator(chest.global_position, chest.detection_radius)


func _create_circle_indicator(pos: Vector3, radius: float) -> void:
	# Create a torus mesh to show detection radius
	var torus := MeshInstance3D.new()
	torus.name = "RadiusIndicator"

	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = radius - 0.05
	torus_mesh.outer_radius = radius + 0.05
	torus_mesh.rings = 32
	torus_mesh.ring_segments = 8
	torus.mesh = torus_mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.3, 0.3)  # Semi-transparent green
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	torus.material_override = mat

	torus.position = pos + Vector3(0, 0.05, 0)  # Just above floor
	torus.rotation_degrees.x = 90  # Lay flat
	add_child(torus)


func _setup_lighting() -> void:
	# Main directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	light.light_color = Color(1.0, 0.95, 0.85)
	add_child(light)

	# Ambient environment
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.3, 0.35, 0.4)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.3, 0.3, 0.35)
	env.environment = environment
	add_child(env)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F5-F9 = Set detection bonus
		if event.keycode == KEY_F5:
			_set_detection_bonus(5)
		if event.keycode == KEY_F6:
			_set_detection_bonus(10)
		if event.keycode == KEY_F7:
			_set_detection_bonus(15)
		if event.keycode == KEY_F8:
			_set_detection_bonus(20)
		if event.keycode == KEY_F9:
			_set_detection_bonus(25)

		# F10 = Reset all chests
		if event.keycode == KEY_F10:
			_reset_all_chests()

		# F11 = Show chest states
		if event.keycode == KEY_F11:
			_show_chest_states()


func _reset_all_chests() -> void:
	print("[HiddenChestTest] Resetting all chests...")

	# Remove old chests
	for chest in hidden_chests:
		if is_instance_valid(chest):
			chest.queue_free()
	hidden_chests.clear()

	# Remove old labels and indicators
	for child in get_children():
		if child.name.begins_with("Label_") or child.name == "RadiusIndicator":
			child.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Respawn
	_spawn_hidden_chests()
	_create_detection_radius_indicators()


func _show_chest_states() -> void:
	print("[HiddenChestTest] === CHEST STATES ===")
	print("  Current detection bonus: %d" % test_bonus)
	print("")

	for chest in hidden_chests:
		if is_instance_valid(chest):
			var status: String = "REVEALED" if chest.is_revealed else "HIDDEN"
			var checked_str: String = " (checked at bonus %d)" % chest.check_at_bonus if chest.has_checked else " (not checked yet)"
			print("  %s [DC %d] - %s%s" % [chest.chest_name, chest.detection_dc, status, checked_str])


func _on_chest_revealed(chest: Node) -> void:  # HiddenChest type
	print("[HiddenChestTest] === CHEST REVEALED ===")
	print("  Name: %s" % chest.chest_name)
	print("  DC: %d" % chest.detection_dc)
	print("  Player bonus at check: %d" % chest.check_at_bonus)
