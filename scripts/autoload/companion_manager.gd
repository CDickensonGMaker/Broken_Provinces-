## companion_manager.gd - Manages active companions in the party
## Handles companion spawning, positioning, combat behavior, and zone transitions
##
## Integration Points:
## - BoatVoyage: Companions help fight during sea encounters
## - WaveSpawner: Track companion kills via enemy_killed_by_companion signal
## - CellStreamer: Persist companions across zone transitions
## - CombatManager: Companions engage enemies near player
extends Node

## Emitted when a companion joins the active party
signal companion_joined(companion_id: String, companion_npc: CompanionNPC)

## Emitted when a companion leaves the active party
signal companion_left(companion_id: String)

## Emitted when a companion is knocked out (essential companions don't die)
signal companion_knocked_out(companion_id: String)

## Emitted when a companion recovers from knockout
signal companion_revived(companion_id: String)

## Emitted when a command is issued to a companion
signal companion_command_issued(companion_id: String, command: CompanionNPC.CompanionCommand)

## Emitted when all companions receive a command
signal all_companions_commanded(command: CompanionNPC.CompanionCommand)

## Emitted when a companion kills an enemy (for WaveSpawner integration)
signal companion_kill(companion: CompanionNPC, enemy: Node)

## Emitted when a companion takes damage
signal companion_damaged(companion_id: String, amount: int)

## Maximum companions allowed in party
const MAX_COMPANIONS: int = 2

## Companion positioning modes for group formations
enum PositionMode {
	FOLLOW,      ## Follow player at distance
	SPREAD,      ## Spread out to cover area (boat deck)
	DEFENSIVE,   ## Form defensive perimeter around player
	AGGRESSIVE,  ## Rush toward enemies
	HOLD,        ## Stay in current position
}

## Currently active companion instances (max 2)
var _active_companions: Array[CompanionNPC] = []

## IDs of companions the player has unlocked (available for recruitment)
var _unlocked_companions: Array[String] = []

## Saved state for each companion (HP, knocked out, position, etc.)
## Format: { companion_id: { "current_health": int, "is_knocked_out": bool, "position": Vector3, ... } }
var _companion_states: Dictionary = {}

## Companion data cache (loaded CompanionData resources)
var _companion_data_cache: Dictionary = {}  ## companion_id -> CompanionData

## Current positioning mode
var _current_position_mode: PositionMode = PositionMode.FOLLOW

## Boat combat specific
var _is_boat_combat: bool = false
var _boat_deck_bounds: AABB = AABB()
var _boarding_spawn_points: Array[Vector3] = []


func _ready() -> void:
	add_to_group("companion_manager")

	# Connect to scene changes to handle zone transitions
	if SceneManager:
		if SceneManager.has_signal("scene_load_started"):
			SceneManager.scene_load_started.connect(_on_scene_load_started)
		if SceneManager.has_signal("scene_loaded"):
			SceneManager.scene_loaded.connect(_on_scene_loaded)


# =============================================================================
# COMPANION MANAGEMENT - CORE API
# =============================================================================

## Add a companion to the active party by ID
## Returns the spawned CompanionNPC instance, or null if failed
func add_companion(companion_id: String) -> CompanionNPC:
	if _active_companions.size() >= MAX_COMPANIONS:
		push_warning("[CompanionManager] Cannot add companion - party full (max %d)" % MAX_COMPANIONS)
		return null

	# Check if already active
	for comp: CompanionNPC in _active_companions:
		if comp.companion_id == companion_id:
			push_warning("[CompanionManager] Companion already in party: %s" % companion_id)
			return comp

	# Check if unlocked
	if not is_companion_unlocked(companion_id):
		push_warning("[CompanionManager] Companion not unlocked: %s" % companion_id)
		return null

	# Get companion data
	var companion_data: CompanionData = _get_companion_data(companion_id)
	if not companion_data:
		push_error("[CompanionManager] No CompanionData found for: %s" % companion_id)
		return null

	# Find player for spawn position
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		push_error("[CompanionManager] Cannot add companion - no player found")
		return null

	# Calculate spawn position near player
	var spawn_pos: Vector3 = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))

	# Spawn the companion
	var companion: CompanionNPC = CompanionNPC.spawn_companion_from_data(
		get_tree().current_scene,
		spawn_pos,
		companion_data
	)

	if not companion:
		push_error("[CompanionManager] Failed to spawn companion: %s" % companion_id)
		return null

	# Register the companion
	_register_companion_internal(companion)

	# Restore saved state if available
	restore_companion_state(companion_id)

	# Start following player
	companion.start_following(player)

	companion_joined.emit(companion_id, companion)
	return companion


## Remove a companion from the active party
func remove_companion(companion_id: String) -> void:
	var companion: CompanionNPC = get_companion(companion_id)
	if not companion:
		return

	# Save state before removing
	save_companion_state(companion_id)

	# Disconnect signals
	_disconnect_companion_signals(companion)

	# Remove from array
	_active_companions.erase(companion)

	# Remove metadata and group
	if is_instance_valid(companion):
		companion.remove_meta("is_companion")
		companion.remove_from_group("companions")
		companion.queue_free()

	companion_left.emit(companion_id)


## Get all active companions
func get_active_companions() -> Array[CompanionNPC]:
	# Clean up invalid references
	var valid_companions: Array[CompanionNPC] = []
	for comp: CompanionNPC in _active_companions:
		if is_instance_valid(comp):
			valid_companions.append(comp)
	_active_companions = valid_companions
	return _active_companions


## Get a specific companion by ID
func get_companion(companion_id: String) -> CompanionNPC:
	for comp: CompanionNPC in _active_companions:
		if is_instance_valid(comp) and comp.companion_id == companion_id:
			return comp
	return null


## Check if a companion is currently active in the party
func is_companion_active(companion_id: String) -> bool:
	return get_companion(companion_id) != null


## Check if a node is a companion
func is_companion(node: Node) -> bool:
	if not is_instance_valid(node):
		return false

	# Check metadata
	if node.has_meta("is_companion") and node.get_meta("is_companion"):
		return true

	# Check if in active companions
	if node is CompanionNPC:
		return node in _active_companions

	# Check group
	if node.is_in_group("companions"):
		return true

	return false


## Unlock a companion for recruitment (adds to roster)
func unlock_companion(companion_id: String) -> void:
	if companion_id not in _unlocked_companions:
		_unlocked_companions.append(companion_id)
		print("[CompanionManager] Unlocked companion: %s" % companion_id)


## Check if a companion is unlocked
func is_companion_unlocked(companion_id: String) -> bool:
	return companion_id in _unlocked_companions


## Get all unlocked companion IDs
func get_unlocked_companions() -> Array[String]:
	return _unlocked_companions.duplicate()


## Get active companion count
func get_companion_count() -> int:
	return get_active_companions().size()


# =============================================================================
# COMPANION REGISTRATION (called by CompanionNPC)
# =============================================================================

## Register a companion that was spawned externally (e.g., from a scene)
func register_companion(companion: CompanionNPC) -> void:
	if not is_instance_valid(companion):
		return

	if companion in _active_companions:
		return

	if _active_companions.size() >= MAX_COMPANIONS:
		push_warning("[CompanionManager] Cannot register companion - party full")
		return

	_register_companion_internal(companion)

	# Auto-unlock if not already
	if not companion.companion_id.is_empty() and not is_companion_unlocked(companion.companion_id):
		unlock_companion(companion.companion_id)

	companion_joined.emit(companion.companion_id, companion)


## Unregister a companion (called when companion is freed)
func unregister_companion(companion: CompanionNPC) -> void:
	if not companion in _active_companions:
		return

	var comp_id: String = companion.companion_id if is_instance_valid(companion) else "unknown"

	# Save state before unregistering
	if not comp_id.is_empty() and comp_id != "unknown":
		save_companion_state(comp_id)

	_disconnect_companion_signals(companion)
	_active_companions.erase(companion)

	companion_left.emit(comp_id)


## Internal registration (shared by add_companion and register_companion)
func _register_companion_internal(companion: CompanionNPC) -> void:
	if companion in _active_companions:
		return

	_active_companions.append(companion)

	# Set companion metadata
	companion.set_meta("is_companion", true)
	companion.set_meta("companion_id", companion.companion_id)

	# Add to companion group
	companion.add_to_group("companions")

	# Connect signals
	_connect_companion_signals(companion)


# =============================================================================
# COMPANION COMMANDS
# =============================================================================

## Issue a command to all active companions
func command_all(command: CompanionNPC.CompanionCommand) -> void:
	for comp: CompanionNPC in get_active_companions():
		_issue_command_to_companion(comp, command)

	all_companions_commanded.emit(command)


## Issue a command to a specific companion
func command_companion(companion_id: String, command: CompanionNPC.CompanionCommand) -> void:
	var companion: CompanionNPC = get_companion(companion_id)
	if companion:
		_issue_command_to_companion(companion, command)
		companion_command_issued.emit(companion_id, command)


## Internal: Execute a command on a companion
func _issue_command_to_companion(companion: CompanionNPC, command: CompanionNPC.CompanionCommand) -> void:
	if not is_instance_valid(companion):
		return

	match command:
		CompanionNPC.CompanionCommand.FOLLOW:
			companion.command_follow()
		CompanionNPC.CompanionCommand.WAIT:
			companion.command_wait()
		CompanionNPC.CompanionCommand.ATTACK_TARGET:
			# For ATTACK_TARGET, caller should use command_attack_target directly
			companion.command_follow()
		CompanionNPC.CompanionCommand.DEFEND_POSITION:
			companion.command_defend_position(companion.global_position)


## Set positioning mode for all companions
func set_position_mode(mode: PositionMode) -> void:
	_current_position_mode = mode

	match mode:
		PositionMode.FOLLOW:
			command_all(CompanionNPC.CompanionCommand.FOLLOW)
		PositionMode.HOLD:
			command_all(CompanionNPC.CompanionCommand.WAIT)
		PositionMode.AGGRESSIVE:
			command_all(CompanionNPC.CompanionCommand.FOLLOW)
			# Set aggressive AI behavior
			for comp: CompanionNPC in get_active_companions():
				comp.ai_behavior = CompanionData.AIBehavior.AGGRESSIVE
		PositionMode.DEFENSIVE:
			command_all(CompanionNPC.CompanionCommand.DEFEND_POSITION)
		PositionMode.SPREAD:
			_position_companions_spread()


## Make companions enter combat mode
func enter_combat() -> void:
	for comp: CompanionNPC in get_active_companions():
		if comp.has_method("enter_combat"):
			comp.enter_combat()


## Make companions exit combat mode
func exit_combat() -> void:
	for comp: CompanionNPC in get_active_companions():
		if comp.has_method("exit_combat"):
			comp.exit_combat()


## Command a companion to attack a specific target
func command_attack_target(companion_id: String, target: Node) -> void:
	var companion: CompanionNPC = get_companion(companion_id)
	if companion and is_instance_valid(target):
		companion.command_attack_target(target)
		companion_command_issued.emit(companion_id, CompanionNPC.CompanionCommand.ATTACK_TARGET)


## Command all companions to attack a specific target
func command_all_attack_target(target: Node) -> void:
	if not is_instance_valid(target):
		return

	for comp: CompanionNPC in get_active_companions():
		comp.command_attack_target(target)

	all_companions_commanded.emit(CompanionNPC.CompanionCommand.ATTACK_TARGET)


# =============================================================================
# STATE MANAGEMENT
# =============================================================================

## Save the current state of a companion
func save_companion_state(companion_id: String) -> void:
	var companion: CompanionNPC = get_companion(companion_id)
	if not is_instance_valid(companion):
		return

	_companion_states[companion_id] = {
		"current_health": companion.current_health,
		"max_health": companion.max_health,
		"is_knocked_out": companion.is_knocked_out(),
		"knockout_timer": companion._knockout_timer,
		"current_command": companion.current_command,
		"ai_behavior": companion.ai_behavior,
		"kills_this_session": companion.kills_this_session,
		"position": {
			"x": companion.global_position.x,
			"y": companion.global_position.y,
			"z": companion.global_position.z
		}
	}


## Restore saved state to a companion
func restore_companion_state(companion_id: String) -> void:
	if not _companion_states.has(companion_id):
		return

	var companion: CompanionNPC = get_companion(companion_id)
	if not is_instance_valid(companion):
		return

	var state: Dictionary = _companion_states[companion_id]

	companion.current_health = state.get("current_health", companion.max_health)
	companion._is_knocked_out = state.get("is_knocked_out", false)
	companion._knockout_timer = state.get("knockout_timer", 0.0)
	companion.current_command = state.get("current_command", CompanionNPC.CompanionCommand.FOLLOW)
	companion.ai_behavior = state.get("ai_behavior", CompanionData.AIBehavior.BALANCED)
	companion.kills_this_session = state.get("kills_this_session", 0)


## Get saved state for a companion (for UI display)
func get_companion_state(companion_id: String) -> Dictionary:
	return _companion_states.get(companion_id, {})


## Serialize all companion manager data for save system
func to_dict() -> Dictionary:
	# Save all active companion states first
	for comp: CompanionNPC in get_active_companions():
		save_companion_state(comp.companion_id)

	# Get active companion IDs
	var active_ids: Array[String] = []
	for comp: CompanionNPC in get_active_companions():
		active_ids.append(comp.companion_id)

	return {
		"unlocked_companions": _unlocked_companions.duplicate(),
		"active_companion_ids": active_ids,
		"companion_states": _companion_states.duplicate(true),
		"position_mode": _current_position_mode,
	}


## Deserialize companion manager data from save
func from_dict(data: Dictionary) -> void:
	_unlocked_companions.clear()
	var unlocked: Array = data.get("unlocked_companions", [])
	for id in unlocked:
		if id is String:
			_unlocked_companions.append(id)

	_companion_states = data.get("companion_states", {}).duplicate(true)
	_current_position_mode = data.get("position_mode", PositionMode.FOLLOW)

	# Note: Active companions will be respawned after scene load
	# Store the IDs for respawning
	var active_ids: Array = data.get("active_companion_ids", [])
	# We'll use a deferred call to respawn after scene is ready
	if not active_ids.is_empty():
		call_deferred("_respawn_saved_companions", active_ids)


## Respawn companions from saved data (called after scene load)
func _respawn_saved_companions(companion_ids: Array) -> void:
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	for comp_id: Variant in companion_ids:
		if comp_id is String and not is_companion_active(comp_id):
			var spawned: CompanionNPC = add_companion(comp_id)
			if spawned:
				print("[CompanionManager] Respawned companion: %s" % comp_id)


# =============================================================================
# BOAT COMBAT INTEGRATION
# =============================================================================

## Configure for boat combat scenario
func setup_boat_combat(deck_bounds: AABB, spawn_points: Array[Vector3] = []) -> void:
	_is_boat_combat = true
	_boat_deck_bounds = deck_bounds
	_boarding_spawn_points = spawn_points

	# Set spread positioning for deck coverage
	set_position_mode(PositionMode.SPREAD)

	# Notify companions of boat combat mode
	for comp: CompanionNPC in get_active_companions():
		comp.set_meta("boat_combat", true)
		if comp.has_method("setup_boat_combat"):
			comp.setup_boat_combat(deck_bounds)


## End boat combat mode
func end_boat_combat() -> void:
	_is_boat_combat = false
	_boat_deck_bounds = AABB()
	_boarding_spawn_points.clear()

	set_position_mode(PositionMode.FOLLOW)

	for comp: CompanionNPC in get_active_companions():
		comp.remove_meta("boat_combat")


## Get optimal companion positions for boat deck
func get_deck_positions(companion_count: int) -> Array[Vector3]:
	var positions: Array[Vector3] = []

	# Use provided spawn points if available
	if _boarding_spawn_points.size() >= companion_count:
		for i: int in range(companion_count):
			positions.append(_boarding_spawn_points[i])
		return positions

	# Generate positions within deck bounds
	if _boat_deck_bounds.has_volume():
		var center: Vector3 = _boat_deck_bounds.get_center()
		var size: Vector3 = _boat_deck_bounds.size

		# Spread companions across deck
		match companion_count:
			1:
				positions.append(center)
			2:
				positions.append(center + Vector3(-size.x * 0.25, 0, 0))
				positions.append(center + Vector3(size.x * 0.25, 0, 0))
			_:
				# Spread evenly
				var angle_step: float = TAU / companion_count
				var radius: float = min(size.x, size.z) * 0.3
				for i: int in range(companion_count):
					var angle: float = angle_step * i
					positions.append(center + Vector3(cos(angle) * radius, 0, sin(angle) * radius))

	return positions


## Position companions in spread formation (for boat deck)
func _position_companions_spread() -> void:
	var companions: Array[CompanionNPC] = get_active_companions()
	var positions: Array[Vector3] = get_deck_positions(companions.size())

	for i: int in range(companions.size()):
		var companion: CompanionNPC = companions[i]
		if i < positions.size() and companion.has_method("move_to_position"):
			companion.move_to_position(positions[i])


## Constrain companion to deck bounds (called during boat combat)
func constrain_to_deck(companion: Node) -> void:
	if not _is_boat_combat or not is_instance_valid(companion):
		return

	if not _boat_deck_bounds.has_volume():
		return

	var pos: Vector3 = companion.global_position

	# Clamp to deck bounds
	pos.x = clamp(pos.x, _boat_deck_bounds.position.x, _boat_deck_bounds.end.x)
	pos.z = clamp(pos.z, _boat_deck_bounds.position.z, _boat_deck_bounds.end.z)

	# Keep on deck surface (don't modify Y if within bounds)
	if pos.y < _boat_deck_bounds.position.y:
		pos.y = _boat_deck_bounds.position.y

	companion.global_position = pos


# =============================================================================
# ZONE TRANSITION HANDLING
# =============================================================================

## Called before scene change - save companion state
func _on_scene_load_started() -> void:
	_prepare_for_zone_transition()


## Called after scene load - respawn companions
func _on_scene_loaded(_scene_path: String) -> void:
	# Delay to allow player to spawn first
	await get_tree().create_timer(0.1).timeout
	_respawn_companions_after_transition()


## Save companion state before zone transition
func _prepare_for_zone_transition() -> void:
	# Store companion data for respawning
	for comp: CompanionNPC in get_active_companions():
		save_companion_state(comp.companion_id)

	# Clear active companions (they will be freed when scene changes)
	# Note: We don't queue_free here as the scene change will handle that
	_active_companions.clear()


## Respawn companions near player after zone transition
func _respawn_companions_after_transition() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	# Respawn companions from saved states
	for comp_id: String in _companion_states.keys():
		var state: Dictionary = _companion_states[comp_id]
		# Only respawn if they were active (have saved position)
		if state.has("position") and is_companion_unlocked(comp_id):
			var spawned: CompanionNPC = add_companion(comp_id)
			if spawned:
				# Position near player
				spawned.global_position = player.global_position + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))


# =============================================================================
# COMPANION DATA LOADING
# =============================================================================

## Get CompanionData resource for a companion ID
func _get_companion_data(companion_id: String) -> CompanionData:
	# Check cache first
	if _companion_data_cache.has(companion_id):
		return _companion_data_cache[companion_id]

	# Try to load from data folder
	var data_path: String = "res://data/companions/%s.tres" % companion_id
	if ResourceLoader.exists(data_path):
		var data: CompanionData = load(data_path) as CompanionData
		if data:
			_companion_data_cache[companion_id] = data
			return data

	# Try alternate path
	data_path = "res://resources/companions/%s.tres" % companion_id
	if ResourceLoader.exists(data_path):
		var data: CompanionData = load(data_path) as CompanionData
		if data:
			_companion_data_cache[companion_id] = data
			return data

	return null


## Preload companion data (for loading screen)
func preload_companion_data(companion_ids: Array[String]) -> void:
	for comp_id: String in companion_ids:
		_get_companion_data(comp_id)


# =============================================================================
# SIGNAL CONNECTIONS
# =============================================================================

func _connect_companion_signals(companion: CompanionNPC) -> void:
	if companion.has_signal("companion_knocked_out"):
		if not companion.companion_knocked_out.is_connected(_on_companion_knocked_out):
			companion.companion_knocked_out.connect(_on_companion_knocked_out)

	if companion.has_signal("companion_revived"):
		if not companion.companion_revived.is_connected(_on_companion_revived):
			companion.companion_revived.connect(_on_companion_revived)

	if companion.has_signal("companion_killed_enemy"):
		if not companion.companion_killed_enemy.is_connected(_on_companion_killed_enemy):
			companion.companion_killed_enemy.connect(_on_companion_killed_enemy.bind(companion))

	if companion.has_signal("damaged"):
		if not companion.damaged.is_connected(_on_companion_damaged):
			companion.damaged.connect(_on_companion_damaged.bind(companion))


func _disconnect_companion_signals(companion: CompanionNPC) -> void:
	if not is_instance_valid(companion):
		return

	if companion.has_signal("companion_knocked_out") and companion.companion_knocked_out.is_connected(_on_companion_knocked_out):
		companion.companion_knocked_out.disconnect(_on_companion_knocked_out)

	if companion.has_signal("companion_revived") and companion.companion_revived.is_connected(_on_companion_revived):
		companion.companion_revived.disconnect(_on_companion_revived)

	if companion.has_signal("companion_killed_enemy") and companion.companion_killed_enemy.is_connected(_on_companion_killed_enemy):
		companion.companion_killed_enemy.disconnect(_on_companion_killed_enemy)

	if companion.has_signal("damaged") and companion.damaged.is_connected(_on_companion_damaged):
		companion.damaged.disconnect(_on_companion_damaged)


func _on_companion_knocked_out(comp_id: String) -> void:
	companion_knocked_out.emit(comp_id)


func _on_companion_revived(comp_id: String) -> void:
	companion_revived.emit(comp_id)


func _on_companion_killed_enemy(enemy: Node, companion: CompanionNPC) -> void:
	companion_kill.emit(companion, enemy)

	# Notify wave spawners for kill tracking
	var wave_spawners := get_tree().get_nodes_in_group("wave_spawners")
	for spawner in wave_spawners:
		if spawner.has_signal("enemy_killed"):
			spawner.enemy_killed.emit(enemy)


func _on_companion_damaged(amount: int, _damage_type: int, _attacker: Node, companion: CompanionNPC) -> void:
	if is_instance_valid(companion):
		companion_damaged.emit(companion.companion_id, amount)


# =============================================================================
# LEGACY COMPATIBILITY (for existing code that uses old API)
# =============================================================================

## Legacy: Get save data (now uses to_dict)
func get_save_data() -> Dictionary:
	return to_dict()


## Legacy: Load save data (now uses from_dict)
func load_save_data(data: Dictionary) -> void:
	from_dict(data)


## Legacy: Check if node is unlocked
func is_unlocked(companion_id: String) -> bool:
	return is_companion_unlocked(companion_id)


## Legacy: Get active companions as generic nodes
func get_active_companions_as_nodes() -> Array[Node]:
	var result: Array[Node] = []
	for comp: CompanionNPC in get_active_companions():
		result.append(comp)
	return result
