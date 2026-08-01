## secret_wall_test.gd - Dev testing scene for Secret Wall Detection System
## Tests: Detection by proximity, skill checks, re-check on skill increase, reveal VFX
extends Node3D

const SecretWallScript = preload("res://scripts/world/secret_wall.gd")

const ZONE_ID := "secret_wall_test"
const ROOM_SIZE := 40.0
const WALL_HEIGHT := 4.0
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## Scene references
var player: Node3D = null
var secret_walls: Array = []  # Array of SecretWall instances

## Test skill values
var test_bonus: int = 0


func _ready() -> void:
	Log.d("[SecretWallTest] Dev test scene loaded")
	Log.d("[SecretWallTest] Controls:")
	Log.d("  F5 = Set detection bonus to 5 (early game)")
	Log.d("  F6 = Set detection bonus to 10 (some investment)")
	Log.d("  F7 = Set detection bonus to 15 (focused build)")
	Log.d("  F8 = Set detection bonus to 20 (high investment)")
	Log.d("  F9 = Set detection bonus to 25 (dedicated build)")
	Log.d("  F10 = Reset all walls (respawn)")
	Log.d("  F11 = Show wall states")
	Log.d("")
	Log.d("[SecretWallTest] Walk near walls to trigger detection checks")
	Log.d("[SecretWallTest] Detection radius = 6 units (shown as circles)")

	_setup_room()
	_setup_test_player()
	_spawn_player()
	_spawn_secret_walls()
	_setup_lighting()
	_create_detection_radius_indicators()


func _exit_tree() -> void:
	# Cleanup
	for wall in secret_walls:
		if is_instance_valid(wall):
			if wall.wall_revealed.is_connected(_on_wall_revealed):
				wall.wall_revealed.disconnect(_on_wall_revealed)


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
	Log.d("[SecretWallTest] Player set to level 5, detection bonus = %d" % pd.get_hidden_detection_bonus())


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
	Log.d("[SecretWallTest] Detection bonus set to %d (target was %d)" % [test_bonus, target_bonus])


func _update_detection_bonus_display() -> void:
	if GameManager and GameManager.player_data:
		test_bonus = GameManager.player_data.get_hidden_detection_bonus()


func _spawn_player() -> void:
	var spawn_pos := Vector3(0, 0.5, 0)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[SecretWallTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	Log.d("[SecretWallTest] Player spawned at %s" % spawn_pos)


## Create the room floor and outer walls
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

	# Create outer walls
	_create_wall("WallNorth", Vector3(0, WALL_HEIGHT / 2, -ROOM_SIZE / 2), Vector3(ROOM_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallSouth", Vector3(0, WALL_HEIGHT / 2, ROOM_SIZE / 2), Vector3(ROOM_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallEast", Vector3(ROOM_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ROOM_SIZE + 1))
	_create_wall("WallWest", Vector3(-ROOM_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ROOM_SIZE + 1))

	# Create divider walls (with gaps for secret walls)
	_create_divider_walls()

	Log.d("[SecretWallTest] Room created (%.0f x %.0f)" % [ROOM_SIZE, ROOM_SIZE])


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


func _create_divider_walls() -> void:
	## Create internal walls with gaps where secret passages will go

	# North-South divider (with gap in middle for secret passage)
	_create_wall("DividerNS_Top", Vector3(0, WALL_HEIGHT / 2, -12), Vector3(0.5, WALL_HEIGHT, 8))
	_create_wall("DividerNS_Bottom", Vector3(0, WALL_HEIGHT / 2, 12), Vector3(0.5, WALL_HEIGHT, 8))

	# East-West divider (with gaps for secret passages)
	_create_wall("DividerEW_Left", Vector3(-12, WALL_HEIGHT / 2, 0), Vector3(8, WALL_HEIGHT, 0.5))
	_create_wall("DividerEW_Right", Vector3(12, WALL_HEIGHT / 2, 0), Vector3(8, WALL_HEIGHT, 0.5))

	# Create visible "rooms" behind the secret walls
	_create_secret_room("SecretRoom1", Vector3(-15, 0, -15), Vector3(8, WALL_HEIGHT, 8), Color(0.5, 0.3, 0.3, 0.3))
	_create_secret_room("SecretRoom2", Vector3(15, 0, -15), Vector3(8, WALL_HEIGHT, 8), Color(0.3, 0.5, 0.3, 0.3))
	_create_secret_room("SecretRoom3", Vector3(-15, 0, 15), Vector3(8, WALL_HEIGHT, 8), Color(0.3, 0.3, 0.5, 0.3))
	_create_secret_room("SecretRoom4", Vector3(15, 0, 15), Vector3(8, WALL_HEIGHT, 8), Color(0.5, 0.5, 0.3, 0.3))


func _create_secret_room(room_name: String, pos: Vector3, size: Vector3, floor_color: Color) -> void:
	## Create a colored floor to indicate a hidden room behind the wall
	var room_floor := CSGBox3D.new()
	room_floor.name = room_name
	room_floor.size = Vector3(size.x, 0.1, size.z)
	room_floor.position = pos + Vector3(0, 0.01, 0)  # Just above main floor

	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	room_floor.material = mat
	add_child(room_floor)


## Spawn secret walls at various DCs for testing
func _spawn_secret_walls() -> void:
	secret_walls.clear()

	# Wall configurations: [position, dc, name, rotation_y, size]
	var wall_configs: Array = [
		# Easy walls (DC 8-10) - should find early
		[Vector3(-8, 0, -4), 8, "Easy Passage (DC 8)", 0.0, Vector3(3.0, 3.0, 0.5)],
		[Vector3(-4, 0, -8), 10, "Easy Doorway (DC 10)", 90.0, Vector3(3.0, 3.0, 0.5)],

		# Medium walls (DC 12-15) - requires some investment
		[Vector3(4, 0, -8), 12, "Hidden Corridor (DC 12)", 90.0, Vector3(3.0, 3.0, 0.5)],
		[Vector3(8, 0, -4), 15, "Secret Entry (DC 15)", 0.0, Vector3(3.0, 3.0, 0.5)],

		# Hard walls (DC 16-18) - focused build
		[Vector3(8, 0, 4), 16, "Concealed Path (DC 16)", 0.0, Vector3(3.0, 3.0, 0.5)],
		[Vector3(4, 0, 8), 18, "Ancient Passage (DC 18)", 90.0, Vector3(3.0, 3.0, 0.5)],

		# Very hard walls (DC 20-22) - high investment
		[Vector3(-4, 0, 8), 20, "Lost Chamber (DC 20)", 90.0, Vector3(3.0, 3.0, 0.5)],
		[Vector3(-8, 0, 4), 22, "Forgotten Gate (DC 22)", 0.0, Vector3(3.0, 3.0, 0.5)],
	]

	for config: Array in wall_configs:
		var pos: Vector3 = config[0]
		var dc: int = config[1]
		var wall_name: String = config[2]
		var rot_y: float = config[3]
		var size: Vector3 = config[4]

		var wall := SecretWallScript.spawn_secret_wall(
			self,
			pos,
			wall_name,
			dc,
			size,
			rot_y
		)

		if wall:
			wall.wall_revealed.connect(_on_wall_revealed)
			secret_walls.append(wall)

			# Create a label above the wall position
			_create_wall_label(pos, wall_name)

	Log.d("[SecretWallTest] Spawned %d secret walls" % secret_walls.size())


## Create a 3D label above wall position to show DC
func _create_wall_label(pos: Vector3, text: String) -> void:
	var label_3d := Label3D.new()
	label_3d.name = "Label_%s" % text.replace(" ", "_")
	label_3d.text = text
	label_3d.font_size = 32
	label_3d.pixel_size = 0.01
	label_3d.position = pos + Vector3(0, 4.0, 0)
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.modulate = Color(0.8, 0.7, 0.5)  # Faded gold
	add_child(label_3d)


## Create visual indicators for detection radius
func _create_detection_radius_indicators() -> void:
	for wall in secret_walls:
		if is_instance_valid(wall):
			_create_circle_indicator(wall.global_position, wall.detection_radius)


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
	mat.albedo_color = Color(0.8, 0.6, 0.2, 0.3)  # Semi-transparent gold (different from chest green)
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
	environment.background_color = Color(0.25, 0.28, 0.32)  # Darker dungeon-like
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.25, 0.3)
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

		# F10 = Reset all walls
		if event.keycode == KEY_F10:
			_reset_all_walls()

		# F11 = Show wall states
		if event.keycode == KEY_F11:
			_show_wall_states()


func _reset_all_walls() -> void:
	Log.d("[SecretWallTest] Resetting all walls...")

	# Remove old walls
	for wall in secret_walls:
		if is_instance_valid(wall):
			wall.queue_free()
	secret_walls.clear()

	# Remove old labels and indicators
	for child in get_children():
		if child.name.begins_with("Label_") or child.name == "RadiusIndicator":
			child.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Respawn
	_spawn_secret_walls()
	_create_detection_radius_indicators()


func _show_wall_states() -> void:
	Log.d("[SecretWallTest] === WALL STATES ===")
	Log.d("  Current detection bonus: %d" % test_bonus)
	Log.d("")

	for wall in secret_walls:
		if is_instance_valid(wall):
			var status: String = "REVEALED" if wall.is_revealed else "HIDDEN"
			var checked_str: String = " (checked at bonus %d)" % wall.check_at_bonus if wall.has_checked else " (not checked yet)"
			Log.d("  %s [DC %d] - %s%s" % [wall.wall_name, wall.detection_dc, status, checked_str])


func _on_wall_revealed(wall: Node) -> void:  # SecretWall type
	Log.d("[SecretWallTest] === WALL REVEALED ===")
	Log.d("  Name: %s" % wall.wall_name)
	Log.d("  DC: %d" % wall.detection_dc)
	Log.d("  Player bonus at check: %d" % wall.check_at_bonus)
