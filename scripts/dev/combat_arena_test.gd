## combat_arena_test.gd - Dev testing scene for combat arena system
## Tests: Pit Master dialogue -> Tournament waves -> Combat flow
extends Node3D

const ZONE_ID := "combat_arena_test"
const ARENA_SIZE := 30.0  # Size of the arena
const WALL_HEIGHT := 4.0  # Height of arena walls
const PLAYER_SCENE_PATH := "res://scenes/player/player.tscn"

## Arena state
var pit_master: Node3D = null
var player: Node3D = null


func _ready() -> void:
	print("[CombatArenaTest] Dev test scene loaded")
	print("[CombatArenaTest] Talk to the Pit Master to start a tournament")
	print("[CombatArenaTest] F5 = Force start tournament, F6 = Spawn test enemy, F7 = Check state")

	_setup_arena()
	_setup_test_player()
	_spawn_player()
	_spawn_pit_master()
	_setup_lighting()

	# Connect to tournament signals
	if TournamentManager:
		TournamentManager.tournament_started.connect(_on_tournament_started)
		TournamentManager.wave_started.connect(_on_wave_started)
		TournamentManager.wave_complete.connect(_on_wave_complete)
		TournamentManager.tournament_won.connect(_on_tournament_won)
		TournamentManager.tournament_lost.connect(_on_tournament_lost)


func _exit_tree() -> void:
	# Disconnect signals
	if TournamentManager:
		if TournamentManager.tournament_started.is_connected(_on_tournament_started):
			TournamentManager.tournament_started.disconnect(_on_tournament_started)
		if TournamentManager.wave_started.is_connected(_on_wave_started):
			TournamentManager.wave_started.disconnect(_on_wave_started)
		if TournamentManager.wave_complete.is_connected(_on_wave_complete):
			TournamentManager.wave_complete.disconnect(_on_wave_complete)
		if TournamentManager.tournament_won.is_connected(_on_tournament_won):
			TournamentManager.tournament_won.disconnect(_on_tournament_won)
		if TournamentManager.tournament_lost.is_connected(_on_tournament_lost):
			TournamentManager.tournament_lost.disconnect(_on_tournament_lost)


## Set up a level 10 player with good equipment for testing
func _setup_test_player() -> void:
	if not GameManager or not GameManager.player_data:
		return

	var pd: CharacterData = GameManager.player_data

	# Set player level to 10
	pd.level = 10
	pd.improvement_points = 0

	# Set reasonable stats for level 10
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

	# Give gold (gold is tracked by InventoryManager, not CharacterData)
	if InventoryManager:
		InventoryManager.gold = 500

	# Add items to inventory (player can equip via inventory screen)
	if InventoryManager:
		InventoryManager.add_item("longsword", 1)
		InventoryManager.add_item("plate_armor", 1)
		InventoryManager.add_item("health_potion", 10)
		InventoryManager.add_item("stamina_potion", 5)

	print("[CombatArenaTest] Player set to level 10 with gear in inventory")


## Spawn the player at the default spawn point
func _spawn_player() -> void:
	var spawn_point: Node3D = get_node_or_null("SpawnPoints/default")
	var spawn_pos := Vector3(0, 0.5, -8)
	if spawn_point:
		spawn_pos = spawn_point.global_position

	var player_scene: PackedScene = load(PLAYER_SCENE_PATH)
	if not player_scene:
		push_error("[CombatArenaTest] Failed to load player scene!")
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	print("[CombatArenaTest] Player spawned at %s" % spawn_pos)


## Create the arena floor and walls
func _setup_arena() -> void:
	# Arena floor
	var floor_node := CSGBox3D.new()
	floor_node.name = "ArenaFloor"
	floor_node.size = Vector3(ARENA_SIZE, 0.5, ARENA_SIZE)
	floor_node.position = Vector3(0, -0.25, 0)
	floor_node.use_collision = true

	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.6, 0.5, 0.35)  # Sandy arena color
	floor_node.material = floor_mat
	add_child(floor_node)

	# Create arena walls
	_create_wall("WallNorth", Vector3(0, WALL_HEIGHT / 2, -ARENA_SIZE / 2), Vector3(ARENA_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallSouth", Vector3(0, WALL_HEIGHT / 2, ARENA_SIZE / 2), Vector3(ARENA_SIZE + 1, WALL_HEIGHT, 1))
	_create_wall("WallEast", Vector3(ARENA_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ARENA_SIZE + 1))
	_create_wall("WallWest", Vector3(-ARENA_SIZE / 2, WALL_HEIGHT / 2, 0), Vector3(1, WALL_HEIGHT, ARENA_SIZE + 1))

	# Create spawn points container
	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	add_child(spawn_points)

	# Player spawn point (center-ish)
	var player_spawn := Marker3D.new()
	player_spawn.name = "default"
	player_spawn.position = Vector3(0, 0.5, -8)
	spawn_points.add_child(player_spawn)

	# Enemy spawn points (around the edges)
	var enemy_spawns := Node3D.new()
	enemy_spawns.name = "EnemySpawns"
	add_child(enemy_spawns)

	var spawn_positions: Array[Vector3] = [
		Vector3(-10, 0.5, 10),
		Vector3(10, 0.5, 10),
		Vector3(-10, 0.5, -5),
		Vector3(10, 0.5, -5),
		Vector3(0, 0.5, 12),
	]

	for i: int in range(spawn_positions.size()):
		var spawn := Marker3D.new()
		spawn.name = "EnemySpawn%d" % i
		spawn.position = spawn_positions[i]
		enemy_spawns.add_child(spawn)


func _create_wall(wall_name: String, pos: Vector3, size: Vector3) -> void:
	var wall := CSGBox3D.new()
	wall.name = wall_name
	wall.size = size
	wall.position = pos
	wall.use_collision = true

	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.35, 0.3, 0.25)  # Stone wall color
	wall.material = wall_mat
	add_child(wall)


## Spawn the Pit Master NPC
func _spawn_pit_master() -> void:
	var npcs := Node3D.new()
	npcs.name = "NPCs"
	add_child(npcs)

	# Spawn Pit Master
	pit_master = QuestGiver.spawn_quest_giver(
		npcs,
		Vector3(0, 0, -12),  # Near south wall
		"Pit Master (Test)",
		"pit_master_test",
		null,
		8, 2,
		[],
		false
	)
	pit_master.region_id = ZONE_ID
	pit_master.faction_id = "human_empire"
	pit_master.no_quest_dialogue = "Ready to fight? Talk to me to enter the arena!"

	# Make them face the center of the arena
	pit_master.rotation.y = 0  # Face north

	print("[CombatArenaTest] Pit Master spawned")


func _setup_lighting() -> void:
	# Main directional light
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.shadow_enabled = true
	light.light_color = Color(1.0, 0.95, 0.85)
	add_child(light)

	# Ambient fill (sky)
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
		# F5 = Force start tournament
		if event.keycode == KEY_F5:
			print("[CombatArenaTest] Force starting tournament...")
			if TournamentManager:
				# Reset any previous state
				TournamentManager.end_tournament(false)
				# Start fresh
				TournamentManager.start_tournament()

		# F6 = Spawn a single test enemy
		if event.keycode == KEY_F6:
			print("[CombatArenaTest] Spawning test enemy...")
			_spawn_test_enemy()

		# F7 = Check tournament state
		if event.keycode == KEY_F7:
			if TournamentManager:
				print("[CombatArenaTest] Tournament active: %s" % TournamentManager.is_tournament_active)
				print("[CombatArenaTest] Current wave: %d / %d" % [TournamentManager.current_wave, TournamentManager.TOTAL_WAVES])
				print("[CombatArenaTest] Enemies remaining: %d" % TournamentManager.current_wave_enemies.size())
				print("[CombatArenaTest] Gold earned: %d" % TournamentManager.total_gold_earned)

		# F8 = Give health potion and heal
		if event.keycode == KEY_F8:
			if GameManager and GameManager.player_data:
				GameManager.player_data.current_hp = GameManager.player_data.max_hp
				GameManager.player_data.current_stamina = GameManager.player_data.max_stamina
				print("[CombatArenaTest] Player fully healed!")


func _spawn_test_enemy() -> void:
	var enemy_spawns: Node3D = get_node_or_null("EnemySpawns")
	if not enemy_spawns:
		push_error("[CombatArenaTest] No EnemySpawns node!")
		return

	# Get random spawn point
	var spawn_points: Array[Node] = enemy_spawns.get_children()
	if spawn_points.is_empty():
		return

	var spawn: Node3D = spawn_points[randi() % spawn_points.size()] as Node3D
	var pos: Vector3 = spawn.global_position

	# Spawn a human bandit for testing
	var enemy_data_path := "res://data/enemies/human_bandit.tres"
	var sprite_path := "res://assets/sprites/enemies/humanoid/human_bandit_alt.png"
	var sprite_texture: Texture2D = load(sprite_path)

	if sprite_texture:
		var enemy: EnemyBase = EnemyBase.spawn_billboard_enemy(
			self,
			pos,
			enemy_data_path,
			sprite_texture,
			1, 1
		)
		if enemy:
			enemy.add_to_group("enemies")
			print("[CombatArenaTest] Spawned test enemy at %s" % pos)


# =============================================================================
# TOURNAMENT SIGNAL HANDLERS
# =============================================================================

func _on_tournament_started() -> void:
	print("[CombatArenaTest] === TOURNAMENT STARTED ===")
	# Hide the pit master during combat (optional)
	if pit_master:
		pit_master.visible = false


func _on_wave_started(wave_number: int, total_waves: int) -> void:
	print("[CombatArenaTest] === WAVE %d of %d STARTED ===" % [wave_number, total_waves])


func _on_wave_complete(wave_number: int, gold_earned: int) -> void:
	print("[CombatArenaTest] === WAVE %d COMPLETE - Earned %d gold ===" % [wave_number, gold_earned])


func _on_tournament_won(total_gold: int) -> void:
	print("[CombatArenaTest] === TOURNAMENT WON! Total gold: %d ===" % total_gold)
	# Show the pit master again
	if pit_master:
		pit_master.visible = true


func _on_tournament_lost() -> void:
	print("[CombatArenaTest] === TOURNAMENT LOST ===")
	# Show the pit master again
	if pit_master:
		pit_master.visible = true
