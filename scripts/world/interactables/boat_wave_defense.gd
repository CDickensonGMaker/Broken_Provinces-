## boat_wave_defense.gd - Coordinates wave defense during boat voyages
## Manages companion positioning, wave spawning, and victory conditions
##
## Usage:
## 1. Add as child of boat_voyage scene
## 2. Configure spawn points at ship rails/boarding points
## 3. Call start_defense() when encounter begins
## 4. Listen to defense_complete signal for victory
class_name BoatWaveDefense
extends Node3D

signal defense_started(encounter_type: String)
signal wave_started(wave_num: int, total_waves: int)
signal wave_completed(wave_num: int, total_waves: int)
signal defense_complete(result: DefenseResult)
signal companion_joined_fight(companion: Node)
signal enemy_boarded(enemy: Node)

enum DefenseResult {
	VICTORY,
	DEFEAT,
	FLED,
	CANCELLED
}

## Encounter types for wave configuration
enum EncounterType {
	PIRATE_RAIDERS,      ## Human pirates boarding
	GHOST_SHIP,          ## Undead crew
	SEA_CREATURE,        ## Tentacles/fish-men
	MIXED_ASSAULT,       ## Pirates + creatures
}

## Wave spawner reference
var wave_spawner: WaveSpawner = null

## Spawn point configuration
@export_group("Spawn Points")
@export var port_boarding_points: Array[Marker3D] = []   ## Left side of ship
@export var starboard_boarding_points: Array[Marker3D] = [] ## Right side of ship
@export var bow_boarding_points: Array[Marker3D] = []    ## Front of ship
@export var stern_boarding_points: Array[Marker3D] = []  ## Back of ship

## Companion positioning
@export_group("Companion Positioning")
@export var companion_defense_points: Array[Marker3D] = []
@export var deck_center: Marker3D = null
@export var deck_bounds: AABB = AABB(Vector3(-4, 2, -6), Vector3(8, 3, 12))  ## Default boat deck size

## Wave configuration overrides
@export_group("Wave Configuration")
@export var override_wave_count: int = 0  ## 0 = use default for encounter type
@export var override_enemies_per_wave: int = 0
@export var between_wave_delay: float = 8.0
@export var initial_delay: float = 3.0

## Current defense state
var current_encounter_type: EncounterType = EncounterType.PIRATE_RAIDERS
var defense_active: bool = false
var current_wave: int = 0
var total_waves: int = 0
var active_companions: Array[Node] = []

## Enemy data paths for different encounter types
const ENEMY_DATA: Dictionary = {
	"pirate_seadog": "res://data/enemies/pirate_seadog.tres",
	"pirate_captain": "res://data/enemies/pirate_captain.tres",
	"ghost_pirate_seadog": "res://data/enemies/ghost_pirate_seadog.tres",
	"ghost_pirate_captain": "res://data/enemies/ghost_pirate_captain.tres",
	"sea_tentacle": "res://data/enemies/sea_tentacle.tres",
	"kraken_tentacle": "res://data/enemies/kraken_tentacle.tres",
}

## Default wave configurations for each encounter type
const WAVE_CONFIGS: Dictionary = {
	EncounterType.PIRATE_RAIDERS: {
		"wave_count": 3,
		"waves": [
			{"enemies": ["pirate_seadog"], "counts": [3], "spawn_delay": 0.5},
			{"enemies": ["pirate_seadog", "pirate_captain"], "counts": [4, 1], "spawn_delay": 0.4},
			{"enemies": ["pirate_seadog", "pirate_captain"], "counts": [5, 1], "spawn_delay": 0.3},
		]
	},
	EncounterType.GHOST_SHIP: {
		"wave_count": 3,
		"waves": [
			{"enemies": ["ghost_pirate_seadog"], "counts": [3], "spawn_delay": 0.6},
			{"enemies": ["ghost_pirate_seadog"], "counts": [4], "spawn_delay": 0.5},
			{"enemies": ["ghost_pirate_seadog", "ghost_pirate_captain"], "counts": [4, 1], "spawn_delay": 0.4},
		]
	},
	EncounterType.SEA_CREATURE: {
		"wave_count": 3,
		"waves": [
			{"enemies": ["sea_tentacle"], "counts": [2], "spawn_delay": 1.0, "spawn_all_at_once": true},
			{"enemies": ["sea_tentacle"], "counts": [3], "spawn_delay": 0.8, "spawn_all_at_once": true},
			{"enemies": ["sea_tentacle", "kraken_tentacle"], "counts": [2, 1], "spawn_delay": 0.8, "spawn_all_at_once": true},
		]
	},
	EncounterType.MIXED_ASSAULT: {
		"wave_count": 4,
		"waves": [
			{"enemies": ["pirate_seadog"], "counts": [2], "spawn_delay": 0.5},
			{"enemies": ["sea_tentacle"], "counts": [2], "spawn_delay": 1.0, "spawn_all_at_once": true},
			{"enemies": ["pirate_seadog", "pirate_captain"], "counts": [3, 1], "spawn_delay": 0.4},
			{"enemies": ["ghost_pirate_seadog", "sea_tentacle"], "counts": [3, 1], "spawn_delay": 0.5},
		]
	}
}


func _ready() -> void:
	add_to_group("boat_wave_defense")
	_setup_wave_spawner()


func _setup_wave_spawner() -> void:
	# Look for existing WaveSpawner or create one
	wave_spawner = get_node_or_null("WaveSpawner") as WaveSpawner

	if not wave_spawner:
		wave_spawner = WaveSpawner.new()
		wave_spawner.name = "WaveSpawner"
		add_child(wave_spawner)

	# Connect signals
	wave_spawner.wave_started.connect(_on_wave_started)
	wave_spawner.wave_completed.connect(_on_wave_completed)
	wave_spawner.all_waves_completed.connect(_on_all_waves_completed)
	wave_spawner.enemy_spawned.connect(_on_enemy_spawned)
	wave_spawner.enemy_killed.connect(_on_enemy_killed)
	wave_spawner.enemy_killed_by_companion.connect(_on_enemy_killed_by_companion)

	# Configure spawn points
	_configure_spawn_points()


func _configure_spawn_points() -> void:
	var all_spawn_points: Array[Marker3D] = []

	# Collect all boarding points
	all_spawn_points.append_array(port_boarding_points)
	all_spawn_points.append_array(starboard_boarding_points)
	all_spawn_points.append_array(bow_boarding_points)
	all_spawn_points.append_array(stern_boarding_points)

	if all_spawn_points.is_empty():
		# Create default spawn points if none configured
		_create_default_spawn_points()
	else:
		wave_spawner.spawn_points = all_spawn_points

	wave_spawner.spawn_radius = 1.5
	wave_spawner.use_random_spawn_points = true


func _create_default_spawn_points() -> void:
	# Create default boarding points around the ship
	var default_positions: Array[Vector3] = [
		Vector3(-5, 2.5, 2),   # Port side front
		Vector3(-5, 2.5, -2),  # Port side back
		Vector3(5, 2.5, 2),    # Starboard side front
		Vector3(5, 2.5, -2),   # Starboard side back
		Vector3(0, 2.5, 6),    # Stern
		Vector3(0, 2.5, -6),   # Bow
	]

	for i in range(default_positions.size()):
		var marker := Marker3D.new()
		marker.name = "BoardingPoint%d" % i
		marker.position = default_positions[i]
		add_child(marker)
		wave_spawner.spawn_points.append(marker)


# =============================================================================
# DEFENSE CONTROL
# =============================================================================

## Start wave defense for specified encounter type
func start_defense(encounter_type: EncounterType) -> void:
	if defense_active:
		push_warning("[BoatWaveDefense] Defense already active")
		return

	current_encounter_type = encounter_type
	defense_active = true

	# Configure waves for encounter type
	_configure_waves_for_encounter(encounter_type)

	# Position companions for defense
	_position_companions_for_defense()

	# Notify CompanionManager to enter combat mode
	if has_node("/root/CompanionManager"):
		var cm: Node = get_node("/root/CompanionManager")
		cm.setup_boat_combat(deck_bounds, _get_companion_positions())
		cm.enter_combat()

	defense_started.emit(_encounter_type_to_string(encounter_type))

	# Start waves
	wave_spawner.between_wave_delay = between_wave_delay
	wave_spawner.initial_delay = initial_delay
	wave_spawner.start_waves()


## Stop defense (abort/cancel)
func stop_defense(result: DefenseResult = DefenseResult.CANCELLED) -> void:
	if not defense_active:
		return

	defense_active = false
	wave_spawner.stop_waves()

	# Exit companion combat mode
	if has_node("/root/CompanionManager"):
		var cm: Node = get_node("/root/CompanionManager")
		cm.end_boat_combat()
		cm.exit_combat()

	defense_complete.emit(result)


## Pause defense (for cutscenes/dialogue)
func pause_defense() -> void:
	wave_spawner.pause_waves()


## Resume defense
func resume_defense() -> void:
	wave_spawner.resume_waves()


# =============================================================================
# WAVE CONFIGURATION
# =============================================================================

func _configure_waves_for_encounter(encounter_type: EncounterType) -> void:
	var config: Dictionary = WAVE_CONFIGS.get(encounter_type, WAVE_CONFIGS[EncounterType.PIRATE_RAIDERS])

	# Scale based on player level
	var level_scale: float = _get_level_scale()

	var wave_configs: Array[Dictionary] = []
	var waves_data: Array = config.get("waves", [])

	# Apply override if set
	var wave_count: int = override_wave_count if override_wave_count > 0 else config.get("wave_count", 3)
	wave_count = mini(wave_count, waves_data.size())

	for i in range(wave_count):
		var wave_data: Dictionary = waves_data[i] if i < waves_data.size() else waves_data[waves_data.size() - 1]

		var enemy_paths: Array[String] = []
		var counts: Array[int] = []

		var enemies: Array = wave_data.get("enemies", [])
		var base_counts: Array = wave_data.get("counts", [])

		for j in range(enemies.size()):
			var enemy_key: String = enemies[j]
			if ENEMY_DATA.has(enemy_key):
				enemy_paths.append(ENEMY_DATA[enemy_key])

				var base_count: int = base_counts[j] if j < base_counts.size() else 1
				if override_enemies_per_wave > 0:
					base_count = override_enemies_per_wave
				var scaled_count: int = int(base_count * level_scale)
				counts.append(maxi(1, scaled_count))

		wave_configs.append({
			"enemy_data_paths": enemy_paths,
			"counts": counts,
			"spawn_delay": wave_data.get("spawn_delay", 0.5),
			"spawn_all_at_once": wave_data.get("spawn_all_at_once", false)
		})

	total_waves = wave_configs.size()
	wave_spawner.configure_waves(wave_configs)


func _get_level_scale() -> float:
	var player_level: int = 1
	if GameManager and GameManager.player_data:
		player_level = GameManager.player_data.level

	# Scale enemies from 1.0 (level 1) to 1.5 (level 20+)
	return 1.0 + (mini(player_level, 20) - 1) * 0.025


# =============================================================================
# COMPANION POSITIONING
# =============================================================================

func _position_companions_for_defense() -> void:
	active_companions.clear()

	# Get companions from CompanionManager
	if has_node("/root/CompanionManager"):
		var cm: Node = get_node("/root/CompanionManager")
		if cm.has_method("get_active_companions"):
			active_companions = cm.get_active_companions()

	# Also include boat crew as "allies" for positioning
	var boat_crew: Array[Node] = get_tree().get_nodes_in_group("boat_crew")
	for crew in boat_crew:
		if is_instance_valid(crew) and crew not in active_companions:
			if not (crew.has_method("is_dead") and crew.is_dead()):
				active_companions.append(crew)

	# Get positions for all defenders
	var positions: Array[Vector3] = _get_companion_positions()

	# Position each companion
	for i in range(active_companions.size()):
		var companion: Node = active_companions[i]
		if i < positions.size() and is_instance_valid(companion):
			_position_companion(companion, positions[i])
			companion_joined_fight.emit(companion)


func _get_companion_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Use configured defense points if available
	for marker in companion_defense_points:
		if is_instance_valid(marker):
			positions.append(marker.global_position)

	# Generate positions if needed
	var needed: int = active_companions.size() - positions.size()
	if needed > 0:
		var generated: Array[Vector3] = _generate_defense_positions(needed)
		positions.append_array(generated)

	return positions


func _generate_defense_positions(count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []
	var center: Vector3 = deck_center.global_position if deck_center else global_position

	# Spread defenders across the deck
	var angle_step: float = TAU / (count + 1)  # +1 to leave gap for player
	var radius: float = 2.5

	for i in range(count):
		var angle: float = angle_step * i
		var pos: Vector3 = center + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		positions.append(pos)

	return positions


func _position_companion(companion: Node, pos: Vector3) -> void:
	if companion.has_method("move_to_position"):
		companion.move_to_position(pos)
	elif companion is Node3D:
		companion.global_position = pos


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_wave_started(wave_num: int) -> void:
	current_wave = wave_num
	wave_started.emit(wave_num, total_waves)

	# Re-engage companions at wave start
	for companion in active_companions:
		if is_instance_valid(companion) and companion.has_method("enter_combat"):
			companion.enter_combat()


func _on_wave_completed(wave_num: int) -> void:
	wave_completed.emit(wave_num, total_waves)


func _on_all_waves_completed() -> void:
	defense_active = false

	# Exit companion combat mode
	if has_node("/root/CompanionManager"):
		var cm: Node = get_node("/root/CompanionManager")
		cm.end_boat_combat()
		cm.exit_combat()

	defense_complete.emit(DefenseResult.VICTORY)


func _on_enemy_spawned(enemy: Node) -> void:
	# Mark enemy as boarded
	if is_instance_valid(enemy):
		enemy.add_to_group("boat_enemies")
		enemy_boarded.emit(enemy)


func _on_enemy_killed(_enemy: Node) -> void:
	# Enemy killed (regardless of who killed them)
	pass


func _on_enemy_killed_by_companion(enemy: Node, companion: Node) -> void:
	# Companion got the kill - could award bonus XP or track stats
	if is_instance_valid(companion):
		var companion_name: String = companion.name
		if companion.has_method("get_display_name"):
			companion_name = companion.get_display_name()


# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

func _encounter_type_to_string(encounter_type: EncounterType) -> String:
	match encounter_type:
		EncounterType.PIRATE_RAIDERS:
			return "pirate_raiders"
		EncounterType.GHOST_SHIP:
			return "ghost_ship"
		EncounterType.SEA_CREATURE:
			return "sea_creature"
		EncounterType.MIXED_ASSAULT:
			return "mixed_assault"
	return "unknown"


## Get current defense stats
func get_defense_stats() -> Dictionary:
	return {
		"current_wave": current_wave,
		"total_waves": total_waves,
		"enemies_remaining": wave_spawner.get_enemies_remaining() if wave_spawner else 0,
		"player_kills": wave_spawner.get_player_kills() if wave_spawner else 0,
		"companion_kills": wave_spawner.get_companion_kills() if wave_spawner else 0,
		"active_companions": active_companions.size()
	}


## Check if defense is active
func is_defense_active() -> bool:
	return defense_active


## Get encounter type as SeaEncounter.EncounterType for compatibility
func get_sea_encounter_type() -> int:
	match current_encounter_type:
		EncounterType.PIRATE_RAIDERS:
			return 0  # SeaEncounter.EncounterType.PIRATE
		EncounterType.GHOST_SHIP:
			return 1  # SeaEncounter.EncounterType.GHOST_PIRATE
		EncounterType.SEA_CREATURE:
			return 2  # SeaEncounter.EncounterType.SEA_MONSTER
	return 0
