## duel_test.gd - Dev testing scene for NPC Duel System
## Tests: Non-lethal combat, yield detection, arena boundaries, quest integration
extends Node3D

const ZONE_ID := "duel_test"
const ARENA_SIZE := 20.0
const WALL_HEIGHT := 4.0
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## Scene references
var player: Node3D = null
var duel_opponent: Node = null


func _ready() -> void:
	print("[DuelTest] Dev test scene loaded")
	print("[DuelTest] Controls:")
	print("  F5 = Start duel with opponent")
	print("  F6 = Player surrender")
	print("  F7 = Check duel state")
	print("  F8 = Heal player")
	print("  F9 = Spawn new opponent")

	_setup_arena()
	_setup_test_player()
	_spawn_player()
	_spawn_duel_opponent()
	_setup_lighting()

	# Connect to duel signals
	if DuelManager:
		DuelManager.duel_started.connect(_on_duel_started)
		DuelManager.duel_ended.connect(_on_duel_ended)
		DuelManager.opponent_yielded.connect(_on_opponent_yielded)
		DuelManager.player_yielded.connect(_on_player_yielded)


func _exit_tree() -> void:
	# Disconnect signals
	if DuelManager:
		if DuelManager.duel_started.is_connected(_on_duel_started):
			DuelManager.duel_started.disconnect(_on_duel_started)
		if DuelManager.duel_ended.is_connected(_on_duel_ended):
			DuelManager.duel_ended.disconnect(_on_duel_ended)
		if DuelManager.opponent_yielded.is_connected(_on_opponent_yielded):
			DuelManager.opponent_yielded.disconnect(_on_opponent_yielded)
		if DuelManager.player_yielded.is_connected(_on_player_yielded):
			DuelManager.player_yielded.disconnect(_on_player_yielded)


## Set up a level 10 player for testing
func _setup_test_player() -> void:
	if not GameManager or not GameManager.player_data:
		return

	var pd: CharacterData = GameManager.player_data

	# Set player level
	pd.level = 10
	pd.improvement_points = 0

	# Set stats
	pd.grit = 12
	pd.agility = 10
	pd.will = 8
	pd.knowledge = 6

	# Full health/stamina/mana
	pd.max_hp = 100 + (pd.grit * 5)
	pd.current_hp = pd.max_hp
	pd.max_stamina = 100 + (pd.agility * 3)
	pd.current_stamina = pd.max_stamina
	pd.max_mana = 50 + (pd.will * 5)
	pd.current_mana = pd.max_mana

	# Give gold and items
	if InventoryManager:
		InventoryManager.gold = 500
		InventoryManager.add_item("longsword", 1)
		InventoryManager.add_item("health_potion", 10)

	print("[DuelTest] Player set to level 10 with gear")


func _spawn_player() -> void:
	var spawn_pos := Vector3(0, 0.5, -6)

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[DuelTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	print("[DuelTest] Player spawned at %s" % spawn_pos)


## Create the arena floor and walls
func _setup_arena() -> void:
	# Arena floor
	var floor_node := CSGBox3D.new()
	floor_node.name = "ArenaFloor"
	floor_node.size = Vector3(ARENA_SIZE, 0.5, ARENA_SIZE)
	floor_node.position = Vector3(0, -0.25, 0)
	floor_node.use_collision = true

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.5, 0.45, 0.35)  # Sandy arena color
	floor_node.material = floor_mat
	add_child(floor_node)

	# Create arena walls
	_create_wall("WallNorth", Vector3(0, WALL_HEIGHT / 2, -ARENA_SIZE / 2), Vector3(ARENA_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallSouth", Vector3(0, WALL_HEIGHT / 2, ARENA_SIZE / 2), Vector3(ARENA_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallEast", Vector3(ARENA_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ARENA_SIZE + 1))
	_create_wall("WallWest", Vector3(-ARENA_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ARENA_SIZE + 1))

	print("[DuelTest] Arena created (%.0f x %.0f)" % [ARENA_SIZE, ARENA_SIZE])


func _create_wall(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.use_collision = true

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.3, 0.25)
	wall.material = wall_mat
	add_child(wall)


## Spawn a duel opponent (human bandit for testing)
func _spawn_duel_opponent() -> void:
	var spawn_pos := Vector3(0, 0.5, 6)

	# Use EnemyBase to spawn a human bandit
	var enemy_data_path := "res://data/enemies/human_bandit.tres"
	var sprite_path := "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"
	var sprite_texture: Texture2D = load(sprite_path)

	if not sprite_texture:
		push_error("[DuelTest] Failed to load sprite texture!")
		return

	duel_opponent = EnemyBase.spawn_billboard_enemy(
		self,
		spawn_pos,
		enemy_data_path,
		sprite_texture,
		1, 1
	)

	if duel_opponent:
		duel_opponent.add_to_group("enemies")
		duel_opponent.name = "DuelOpponent"
		# Give opponent lower HP for faster testing
		duel_opponent.max_hp = 50
		duel_opponent.current_hp = 50
		print("[DuelTest] Duel opponent spawned at %s (HP: %d)" % [spawn_pos, duel_opponent.max_hp])
	else:
		push_error("[DuelTest] Failed to spawn duel opponent!")


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
	environment.background_color = Color(0.5, 0.6, 0.8)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.4, 0.4, 0.5)
	env.environment = environment
	add_child(env)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# F5 = Start duel
		if event.keycode == KEY_F5:
			print("[DuelTest] Starting duel...")
			if duel_opponent and is_instance_valid(duel_opponent):
				var success: bool = DuelManager.start_duel(
					duel_opponent,
					"test_duel_001",
					0.2,  # 20% yield threshold
					Vector3.ZERO,  # Arena center
					ARENA_SIZE / 2.0 - 2.0,  # Barrier radius
					true  # Create barrier
				)
				print("[DuelTest] Duel start result: %s" % success)
			else:
				print("[DuelTest] No valid opponent! Spawn one first (F9)")

		# F6 = Player surrender
		if event.keycode == KEY_F6:
			print("[DuelTest] Player surrendering...")
			DuelManager.player_surrender()

		# F7 = Check duel state
		if event.keycode == KEY_F7:
			print("[DuelTest] === DUEL STATE ===")
			print("  Active: %s" % DuelManager.is_duel_active())
			print("  State: %s" % DuelManager.DuelState.keys()[DuelManager.current_state])
			print("  Duel ID: %s" % DuelManager.duel_id)
			if duel_opponent and is_instance_valid(duel_opponent):
				var hp_pct: float = float(duel_opponent.current_hp) / float(duel_opponent.max_hp) * 100.0
				print("  Opponent HP: %d / %d (%.1f%%)" % [duel_opponent.current_hp, duel_opponent.max_hp, hp_pct])
			if GameManager and GameManager.player_data:
				var pd: CharacterData = GameManager.player_data
				var player_hp_pct: float = float(pd.current_hp) / float(pd.max_hp) * 100.0
				print("  Player HP: %d / %d (%.1f%%)" % [pd.current_hp, pd.max_hp, player_hp_pct])

		# F8 = Heal player
		if event.keycode == KEY_F8:
			if GameManager and GameManager.player_data:
				GameManager.player_data.current_hp = GameManager.player_data.max_hp
				GameManager.player_data.current_stamina = GameManager.player_data.max_stamina
				print("[DuelTest] Player fully healed!")

		# F9 = Spawn new opponent
		if event.keycode == KEY_F9:
			if duel_opponent and is_instance_valid(duel_opponent):
				duel_opponent.queue_free()
			_spawn_duel_opponent()


# =============================================================================
# DUEL SIGNAL HANDLERS
# =============================================================================

func _on_duel_started(opponent: Node, id: String) -> void:
	print("[DuelTest] === DUEL STARTED ===")
	print("  Opponent: %s" % (opponent.name if opponent else "null"))
	print("  Duel ID: %s" % id)


func _on_duel_ended(result: DuelManager.DuelResult, opponent: Node, id: String) -> void:
	print("[DuelTest] === DUEL ENDED ===")
	print("  Result: %s" % DuelManager.DuelResult.keys()[result])
	print("  Opponent: %s" % (opponent.name if opponent else "null"))
	print("  Duel ID: %s" % id)


func _on_opponent_yielded(opponent: Node, id: String) -> void:
	print("[DuelTest] === OPPONENT YIELDED ===")
	print("  Opponent: %s" % (opponent.name if opponent else "null"))
	print("  Duel ID: %s" % id)


func _on_player_yielded(id: String) -> void:
	print("[DuelTest] === PLAYER YIELDED ===")
	print("  Duel ID: %s" % id)
