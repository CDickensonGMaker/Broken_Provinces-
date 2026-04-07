## wave_spawner.gd - Spawns enemies in configurable waves for defense scenarios
## Place in scenes that need wave-based enemy spawning (Mercenary Quests 11-12, Morthane Quest 9, Keepers Quest 4)
class_name WaveSpawner
extends Node3D

signal wave_started(wave_num: int)
signal wave_completed(wave_num: int)
signal all_waves_completed
signal enemy_spawned(enemy: Node)
signal enemy_killed(enemy: Node)
signal enemy_killed_by_companion(enemy: Node, companion: Node)  ## Emitted when a companion gets the killing blow
signal countdown_tick(seconds_remaining: int)

## Wave definition structure
## Each wave is a Dictionary with:
## - enemy_data_paths: Array[String] - Paths to EnemyData resources
## - counts: Array[int] - Number of each enemy type to spawn (parallel to enemy_data_paths)
## - spawn_delay: float - Delay between spawning each enemy in the wave
## - spawn_all_at_once: bool - If true, spawn all enemies immediately (default false)
@export var waves: Array[Dictionary] = []

## Spawn point configuration
@export var spawn_points: Array[Marker3D] = []
@export var spawn_radius: float = 2.0  ## Random offset from spawn points
@export var use_random_spawn_points: bool = true  ## Randomly select spawn points or cycle through

## Timing configuration
@export var between_wave_delay: float = 10.0  ## Seconds between waves
@export var initial_delay: float = 3.0  ## Delay before first wave starts
@export var spawn_delay_per_enemy: float = 0.5  ## Default delay between enemy spawns

## Quest integration
@export var wave_defense_id: String = ""  ## ID for quest objective tracking

## Auto-start configuration
@export var auto_start: bool = false  ## Start waves automatically on _ready()

## Runtime state
var current_wave: int = 0
var total_waves: int = 0
var is_active: bool = false
var is_paused: bool = false
var enemies_remaining: int = 0
var spawned_enemies: Array[Node] = []

## Internal timers
var _between_wave_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spawn_queue: Array[Dictionary] = []  ## Queue of enemies to spawn {data_path, spawn_pos}
var _waiting_for_wave_clear: bool = false
var _countdown_seconds: int = 0

## Spawn point cycling
var _spawn_point_index: int = 0

## Kill attribution tracking (for stats/achievements)
var player_kills: int = 0
var companion_kills: int = 0
var kill_attribution: Dictionary = {}  ## enemy instance_id -> {"killer": Node, "is_companion": bool}


func _ready() -> void:
	add_to_group("wave_spawners")
	total_waves = waves.size()

	if auto_start:
		call_deferred("start_waves")


func _process(delta: float) -> void:
	if not is_active or is_paused:
		return

	# Handle between-wave countdown
	if _between_wave_timer > 0.0:
		_between_wave_timer -= delta

		# Emit countdown ticks for UI
		var new_seconds: int = ceili(_between_wave_timer)
		if new_seconds != _countdown_seconds and new_seconds > 0:
			_countdown_seconds = new_seconds
			countdown_tick.emit(_countdown_seconds)

		if _between_wave_timer <= 0.0:
			_countdown_seconds = 0
			_start_next_wave()
		return

	# Handle spawn queue
	if _spawn_queue.size() > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_next_enemy()
		return

	# Check if wave is complete (all enemies dead)
	if _waiting_for_wave_clear:
		_cleanup_dead_enemies()
		if enemies_remaining <= 0:
			_on_wave_cleared()


## Start the wave defense sequence
func start_waves() -> void:
	if is_active:
		push_warning("[WaveSpawner] Already active, ignoring start_waves()")
		return

	if waves.is_empty():
		push_warning("[WaveSpawner] No waves configured!")
		return

	is_active = true
	current_wave = 0
	total_waves = waves.size()

	# Reset kill stats for this wave defense session
	reset_kill_stats()

	# Notify HUD to show wave counter
	_notify_hud_show()

	# Initial delay before first wave
	if initial_delay > 0.0:
		_between_wave_timer = initial_delay
		_countdown_seconds = ceili(initial_delay)
		countdown_tick.emit(_countdown_seconds)
	else:
		_start_next_wave()


## Stop the wave defense (abort)
func stop_waves() -> void:
	is_active = false
	_between_wave_timer = 0.0
	_spawn_queue.clear()
	_waiting_for_wave_clear = false

	# Clean up remaining enemies
	for enemy in spawned_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	spawned_enemies.clear()
	enemies_remaining = 0

	_notify_hud_hide()


## Pause wave spawning (enemies stay active)
func pause_waves() -> void:
	is_paused = true


## Resume wave spawning
func resume_waves() -> void:
	is_paused = false


## Get current wave number (1-indexed for display)
func get_current_wave() -> int:
	return current_wave


## Get total number of waves
func get_total_waves() -> int:
	return total_waves


## Get number of enemies remaining in current wave
func get_enemies_remaining() -> int:
	return enemies_remaining


## Get time remaining until next wave
func get_countdown_remaining() -> float:
	return max(0.0, _between_wave_timer)


## Check if currently in countdown between waves
func is_in_countdown() -> bool:
	return _between_wave_timer > 0.0


## Start the next wave
func _start_next_wave() -> void:
	current_wave += 1

	if current_wave > total_waves:
		_on_all_waves_complete()
		return

	var wave_data: Dictionary = waves[current_wave - 1]

	# Build spawn queue
	_build_spawn_queue(wave_data)

	wave_started.emit(current_wave)

	# Notify quest system
	if not wave_defense_id.is_empty():
		QuestManager.update_progress("wave_started", wave_defense_id, 1)

	# Start spawning
	var spawn_delay: float = wave_data.get("spawn_delay", spawn_delay_per_enemy)
	var spawn_all: bool = wave_data.get("spawn_all_at_once", false)

	if spawn_all:
		# Spawn all enemies immediately
		while _spawn_queue.size() > 0:
			_spawn_next_enemy()
	else:
		# Spawn first enemy, rest on timer
		_spawn_timer = 0.0
		_spawn_next_enemy()
		_spawn_timer = spawn_delay


## Build the spawn queue from wave data
func _build_spawn_queue(wave_data: Dictionary) -> void:
	_spawn_queue.clear()

	var enemy_paths: Array = wave_data.get("enemy_data_paths", [])
	var counts: Array = wave_data.get("counts", [])

	if enemy_paths.is_empty():
		push_warning("[WaveSpawner] Wave has no enemy_data_paths!")
		return

	# Ensure counts matches paths length
	while counts.size() < enemy_paths.size():
		counts.append(1)

	# Build queue with all enemies
	for i in range(enemy_paths.size()):
		var path: String = enemy_paths[i]
		var count: int = counts[i] if i < counts.size() else 1

		for j in range(count):
			var spawn_pos: Vector3 = _get_spawn_position()
			_spawn_queue.append({
				"data_path": path,
				"spawn_pos": spawn_pos
			})

	# Shuffle queue for variety
	_spawn_queue.shuffle()

	# Track total enemies for this wave
	enemies_remaining = _spawn_queue.size()
	_waiting_for_wave_clear = true


## Spawn the next enemy from the queue
func _spawn_next_enemy() -> void:
	if _spawn_queue.is_empty():
		return

	var spawn_data: Dictionary = _spawn_queue.pop_front()
	var data_path: String = spawn_data.data_path
	var spawn_pos: Vector3 = spawn_data.spawn_pos

	# Load enemy data
	var enemy_data: EnemyData = load(data_path) as EnemyData
	if not enemy_data:
		push_warning("[WaveSpawner] Failed to load enemy data: %s" % data_path)
		enemies_remaining -= 1
		return

	# Get sprite info from enemy data
	var sprite_path: String = enemy_data.sprite_path
	if sprite_path.is_empty():
		push_warning("[WaveSpawner] Enemy data has no sprite_path: %s" % data_path)
		enemies_remaining -= 1
		return

	var sprite_texture: Texture2D = load(sprite_path) as Texture2D
	if not sprite_texture:
		push_warning("[WaveSpawner] Failed to load sprite: %s" % sprite_path)
		enemies_remaining -= 1
		return

	var h_frames: int = enemy_data.sprite_hframes if enemy_data.sprite_hframes > 0 else 4
	var v_frames: int = enemy_data.sprite_vframes if enemy_data.sprite_vframes > 0 else 4

	# Spawn the enemy
	var parent: Node = get_tree().current_scene
	if not parent:
		push_warning("[WaveSpawner] No current scene for spawning")
		enemies_remaining -= 1
		return

	var enemy: Node3D = EnemyBase.spawn_billboard_enemy(
		parent,
		spawn_pos,
		data_path,
		sprite_texture,
		h_frames,
		v_frames
	)

	if enemy:
		spawned_enemies.append(enemy)
		enemy.add_to_group("wave_spawner_enemy")

		# Connect to death signal
		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died.bind(enemy))

		enemy_spawned.emit(enemy)
	else:
		push_warning("[WaveSpawner] Failed to spawn enemy from %s" % data_path)
		enemies_remaining -= 1

	# Set timer for next spawn
	if _spawn_queue.size() > 0:
		var wave_data: Dictionary = waves[current_wave - 1]
		_spawn_timer = wave_data.get("spawn_delay", spawn_delay_per_enemy)


## Get a spawn position from configured spawn points
func _get_spawn_position() -> Vector3:
	if spawn_points.is_empty():
		# Use spawner's own position with offset
		var offset: Vector3 = Vector3(
			randf_range(-spawn_radius, spawn_radius),
			0,
			randf_range(-spawn_radius, spawn_radius)
		)
		return global_position + offset

	var spawn_point: Marker3D

	if use_random_spawn_points:
		spawn_point = spawn_points[randi() % spawn_points.size()]
	else:
		spawn_point = spawn_points[_spawn_point_index]
		_spawn_point_index = (_spawn_point_index + 1) % spawn_points.size()

	# Add random offset
	var offset: Vector3 = Vector3(
		randf_range(-spawn_radius, spawn_radius),
		0,
		randf_range(-spawn_radius, spawn_radius)
	)

	return spawn_point.global_position + offset


## Handle enemy death
func _on_enemy_died(killer: Node, enemy: Node) -> void:
	if enemy in spawned_enemies:
		spawned_enemies.erase(enemy)

	enemies_remaining = max(0, enemies_remaining - 1)

	# Track kill attribution
	var is_companion_kill: bool = _is_companion(killer)
	if is_companion_kill:
		companion_kills += 1
		enemy_killed_by_companion.emit(enemy, killer)
	else:
		player_kills += 1

	# Store attribution for stats
	if is_instance_valid(enemy):
		kill_attribution[enemy.get_instance_id()] = {
			"killer": killer,
			"is_companion": is_companion_kill
		}

	enemy_killed.emit(enemy)


## Clean up dead/freed enemies from tracking
func _cleanup_dead_enemies() -> void:
	var to_remove: Array[Node] = []
	for enemy in spawned_enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			to_remove.append(enemy)
		elif enemy.has_method("is_dead") and enemy.is_dead():
			to_remove.append(enemy)

	for enemy in to_remove:
		spawned_enemies.erase(enemy)
		enemies_remaining = max(0, enemies_remaining - 1)


## Called when current wave is cleared
func _on_wave_cleared() -> void:
	_waiting_for_wave_clear = false

	wave_completed.emit(current_wave)

	# Notify quest system (uses both generic and dedicated functions)
	if not wave_defense_id.is_empty():
		QuestManager.update_progress("wave_defense", wave_defense_id, 1)
		if QuestManager.has_method("on_wave_defense_progress"):
			QuestManager.on_wave_defense_progress(wave_defense_id)

	if current_wave >= total_waves:
		_on_all_waves_complete()
	else:
		# Start countdown to next wave
		_between_wave_timer = between_wave_delay
		_countdown_seconds = ceili(between_wave_delay)
		countdown_tick.emit(_countdown_seconds)


## Called when all waves are complete
func _on_all_waves_complete() -> void:
	is_active = false
	all_waves_completed.emit()

	# Notify quest system (uses both generic and dedicated functions)
	if not wave_defense_id.is_empty():
		QuestManager.update_progress("wave_defense_complete", wave_defense_id, 1)
		if QuestManager.has_method("on_wave_defense_complete"):
			QuestManager.on_wave_defense_complete(wave_defense_id)

	# Notify HUD to hide wave counter
	call_deferred("_notify_hud_hide")


## Notify HUD to show wave counter
func _notify_hud_show() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_wave_counter"):
		hud.show_wave_counter(self)


## Notify HUD to hide wave counter
func _notify_hud_hide() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_wave_counter"):
		hud.hide_wave_counter()


# =============================================================================
# COMPANION KILL TRACKING
# =============================================================================

## Check if the killer node is a companion (ally NPC)
func _is_companion(killer: Node) -> bool:
	if not is_instance_valid(killer):
		return false

	# Check if killer is in companion/ally groups
	if killer.is_in_group("companions"):
		return true
	if killer.is_in_group("allies"):
		return true
	if killer.is_in_group("boat_crew"):
		return true

	# Check via CompanionManager if available
	if has_node("/root/CompanionManager"):
		var cm: Node = get_node("/root/CompanionManager")
		if cm.has_method("is_companion"):
			return cm.is_companion(killer)

	# Check for companion metadata
	if killer.has_meta("is_companion") and killer.get_meta("is_companion"):
		return true

	return false


## Get total player kills this wave defense
func get_player_kills() -> int:
	return player_kills


## Get total companion kills this wave defense
func get_companion_kills() -> int:
	return companion_kills


## Get kill attribution for a specific enemy (by instance ID)
func get_kill_attribution(enemy_instance_id: int) -> Dictionary:
	return kill_attribution.get(enemy_instance_id, {})


## Reset kill stats (called when starting new wave defense)
func reset_kill_stats() -> void:
	player_kills = 0
	companion_kills = 0
	kill_attribution.clear()


## Configure waves programmatically (alternative to export vars)
## wave_configs: Array of {enemy_data_paths: Array[String], counts: Array[int], spawn_delay: float, spawn_all_at_once: bool}
func configure_waves(wave_configs: Array[Dictionary]) -> void:
	waves = wave_configs
	total_waves = waves.size()


## Add a single wave configuration
func add_wave(enemy_data_paths: Array[String], counts: Array[int] = [], spawn_delay: float = 0.5, spawn_all_at_once: bool = false) -> void:
	var wave_config: Dictionary = {
		"enemy_data_paths": enemy_data_paths,
		"counts": counts if counts.size() > 0 else [1],
		"spawn_delay": spawn_delay,
		"spawn_all_at_once": spawn_all_at_once
	}
	waves.append(wave_config)
	total_waves = waves.size()


## Create a standard weak-enemy swarm configuration
## Returns wave configs for multiple waves of weak enemies
static func create_swarm_config(
	enemy_path: String,
	wave_count: int = 5,
	enemies_per_wave_start: int = 3,
	enemies_per_wave_end: int = 8
) -> Array[Dictionary]:
	var configs: Array[Dictionary] = []

	for i in range(wave_count):
		var progress: float = float(i) / max(1.0, float(wave_count - 1))
		var enemy_count: int = int(lerp(float(enemies_per_wave_start), float(enemies_per_wave_end), progress))

		configs.append({
			"enemy_data_paths": [enemy_path],
			"counts": [enemy_count],
			"spawn_delay": 0.3,
			"spawn_all_at_once": false
		})

	return configs


## Create a tough-enemy configuration
## Returns wave configs for fewer waves of stronger enemies
static func create_elite_config(
	enemy_paths: Array[String],
	wave_count: int = 3,
	enemies_per_wave: int = 2
) -> Array[Dictionary]:
	var configs: Array[Dictionary] = []

	for i in range(wave_count):
		var counts: Array[int] = []
		for j in range(enemy_paths.size()):
			counts.append(enemies_per_wave)

		configs.append({
			"enemy_data_paths": enemy_paths,
			"counts": counts,
			"spawn_delay": 1.0,
			"spawn_all_at_once": false
		})

	return configs
