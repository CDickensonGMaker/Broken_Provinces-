## escort_manager.gd - Manages active escort NPCs
## Coordinates between escort NPCs, quest system, and UI
extends Node

## Signals
signal escort_started(escort_id: String, escort_npc: EscortNPC)
signal escort_ended(escort_id: String, reason: String)  # reason: "arrived", "died", "cancelled"
signal escort_health_changed(escort_id: String, current: int, max_hp: int)
signal escort_arrived(escort_id: String, destination: String)
signal escort_died(escort_id: String)

## Active escorts (can have multiple but usually one at a time)
var active_escorts: Dictionary = {}  # escort_id -> EscortNPC

## Primary escort (the one shown in HUD)
var primary_escort: EscortNPC = null


func _ready() -> void:
	add_to_group("escort_manager")


## Register an escort NPC with the manager
func register_escort(escort: EscortNPC) -> void:
	if not escort:
		return

	var escort_id: String = escort.escort_id
	active_escorts[escort_id] = escort

	# Connect to escort signals
	if not escort.escort_damaged.is_connected(_on_escort_damaged):
		escort.escort_damaged.connect(_on_escort_damaged.bind(escort_id))
	if not escort.escort_died.is_connected(_on_escort_died):
		escort.escort_died.connect(_on_escort_died)
	if not escort.escort_arrived.is_connected(_on_escort_arrived):
		escort.escort_arrived.connect(_on_escort_arrived)
	if not escort.escort_started.is_connected(_on_escort_started):
		escort.escort_started.connect(_on_escort_started.bind(escort))

	# Set as primary if no primary escort
	if not primary_escort:
		primary_escort = escort

	# Update HUD
	_update_hud()


## Unregister an escort NPC
func unregister_escort(escort: EscortNPC) -> void:
	if not escort:
		return

	var escort_id: String = escort.escort_id
	if active_escorts.has(escort_id):
		active_escorts.erase(escort_id)

	# Update primary escort if needed
	if primary_escort == escort:
		primary_escort = null
		# Try to find another active escort
		for id: String in active_escorts:
			primary_escort = active_escorts[id]
			break

	# Update HUD
	_update_hud()


## Start an escort quest
func start_escort_quest(
	escort_id: String,
	quest_id: String,
	destination_id: String,
	npc_position: Vector3,
	npc_name: String,
	sprite_path: String,
	h_frames: int = 1,
	v_frames: int = 1
) -> EscortNPC:
	# Get player
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		push_error("[EscortManager] No player found!")
		return null

	# Spawn escort NPC
	var escort := EscortNPC.spawn_escort(
		player.get_parent(),
		npc_position,
		escort_id,
		npc_name,
		sprite_path,
		h_frames,
		v_frames,
		CivilianNPC.PIXEL_SIZE_MAN,
		quest_id,
		destination_id
	)

	if escort:
		escort.start_escort(player)

	return escort


## Get active escort by ID
func get_escort(escort_id: String) -> EscortNPC:
	return active_escorts.get(escort_id)


## Get primary escort (for HUD display)
func get_primary_escort() -> EscortNPC:
	return primary_escort


## Check if any escort is active
func has_active_escort() -> bool:
	return not active_escorts.is_empty()


## Cancel an escort (quest failed or cancelled)
func cancel_escort(escort_id: String) -> void:
	var escort: EscortNPC = active_escorts.get(escort_id)
	if escort and is_instance_valid(escort):
		escort_ended.emit(escort_id, "cancelled")
		escort.queue_free()
		unregister_escort(escort)


## Signal handlers
func _on_escort_damaged(current_hp: int, max_hp: int, damage: int, escort_id: String) -> void:
	escort_health_changed.emit(escort_id, current_hp, max_hp)
	_update_hud()

	# Flash warning on HUD
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("flash_escort_damage"):
		hud.flash_escort_damage()


func _on_escort_died(escort_id: String) -> void:
	escort_died.emit(escort_id)
	escort_ended.emit(escort_id, "died")
	_update_hud()


func _on_escort_arrived(escort_id: String, destination: String) -> void:
	escort_arrived.emit(escort_id, destination)
	escort_ended.emit(escort_id, "arrived")

	# Notify quest system
	QuestManager.on_escort_arrived(escort_id, destination)

	_update_hud()


func _on_escort_started(escort_id: String, escort: EscortNPC) -> void:
	escort_started.emit(escort_id, escort)
	_update_hud()


## Update HUD with escort info
func _update_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return

	if primary_escort and is_instance_valid(primary_escort):
		if hud.has_method("show_escort_health"):
			hud.show_escort_health(
				primary_escort.npc_name,
				primary_escort.current_health,
				primary_escort.max_health
			)
	else:
		if hud.has_method("hide_escort_health"):
			hud.hide_escort_health()


## Get escort health percentage
func get_escort_health_percent(escort_id: String = "") -> float:
	var escort: EscortNPC = null

	if escort_id.is_empty():
		escort = primary_escort
	else:
		escort = active_escorts.get(escort_id)

	if escort and is_instance_valid(escort):
		return escort.get_health_percent()

	return 0.0


## Check if escort is at destination
func is_escort_at_destination(escort_id: String = "") -> bool:
	var escort: EscortNPC = null

	if escort_id.is_empty():
		escort = primary_escort
	else:
		escort = active_escorts.get(escort_id)

	if escort and is_instance_valid(escort):
		return escort.destination_reached

	return false


## Get all active escort IDs
func get_active_escort_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in active_escorts:
		ids.append(id)
	return ids


## Serialize escort manager state for save system
func to_dict() -> Dictionary:
	var escort_states: Dictionary = {}

	# Save state for each active escort
	for escort_id: String in active_escorts:
		var escort: EscortNPC = active_escorts[escort_id]
		if is_instance_valid(escort):
			escort_states[escort_id] = {
				"npc_name": escort.npc_name,
				"current_health": escort.current_health,
				"max_health": escort.max_health,
				"destination_id": escort.destination_id,
				"destination_reached": escort.destination_reached,
				"quest_id": escort.quest_id,
				"sprite_path": escort.sprite_path,
				"h_frames": escort.h_frames,
				"v_frames": escort.v_frames,
				"position": {
					"x": escort.global_position.x,
					"y": escort.global_position.y,
					"z": escort.global_position.z
				}
			}

	return {
		"escort_states": escort_states,
		"primary_escort_id": primary_escort.escort_id if primary_escort and is_instance_valid(primary_escort) else ""
	}


## Deserialize escort manager state from save
func from_dict(data: Dictionary) -> void:
	# Clear current escorts (they will be respawned)
	for escort_id: String in active_escorts.keys():
		var escort: EscortNPC = active_escorts[escort_id]
		if is_instance_valid(escort):
			escort.queue_free()
	active_escorts.clear()
	primary_escort = null

	# Store saved state for respawning after scene load
	var escort_states: Dictionary = data.get("escort_states", {})
	var primary_id: String = data.get("primary_escort_id", "")

	# Note: Escorts will be respawned after scene loads
	# Store the data for deferred respawning
	if not escort_states.is_empty():
		call_deferred("_respawn_saved_escorts", escort_states, primary_id)


## Respawn escorts from saved data (called after scene load)
func _respawn_saved_escorts(escort_states: Dictionary, primary_id: String) -> void:
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	for escort_id: String in escort_states:
		var state: Dictionary = escort_states[escort_id]

		# Don't respawn if already at destination
		if state.get("destination_reached", false):
			continue

		# Reconstruct position
		var pos_data: Dictionary = state.get("position", {})
		var pos := Vector3(
			pos_data.get("x", player.global_position.x),
			pos_data.get("y", player.global_position.y),
			pos_data.get("z", player.global_position.z)
		)

		# Spawn escort near player
		var escort := EscortNPC.spawn_escort(
			player.get_parent(),
			pos,
			escort_id,
			state.get("npc_name", "Escort"),
			state.get("sprite_path", ""),
			state.get("h_frames", 1),
			state.get("v_frames", 1),
			CivilianNPC.PIXEL_SIZE_MAN,
			state.get("quest_id", ""),
			state.get("destination_id", "")
		)

		if escort:
			# Restore health
			escort.current_health = state.get("current_health", escort.max_health)
			escort.max_health = state.get("max_health", 100)

			# Start following player
			escort.start_escort(player)

			# Set as primary if it was before
			if escort_id == primary_id:
				primary_escort = escort

			print("[EscortManager] Respawned escort: %s" % escort_id)


## Set destination marker for escort
func set_escort_destination(escort_id: String, marker: Node3D) -> void:
	var escort: EscortNPC = active_escorts.get(escort_id)
	if escort and is_instance_valid(escort):
		escort.set_destination_marker(marker)


## Set destination position for escort
func set_escort_destination_position(escort_id: String, pos: Vector3) -> void:
	var escort: EscortNPC = active_escorts.get(escort_id)
	if escort and is_instance_valid(escort):
		escort.destination_position = pos


## Process active escorts (called by HUD or game loop if needed)
func _process(_delta: float) -> void:
	# Clean up invalid escort references
	var to_remove: Array[String] = []
	for escort_id: String in active_escorts:
		var escort: EscortNPC = active_escorts[escort_id]
		if not is_instance_valid(escort):
			to_remove.append(escort_id)

	for escort_id: String in to_remove:
		active_escorts.erase(escort_id)
		if primary_escort and not is_instance_valid(primary_escort):
			primary_escort = null

	# Update HUD periodically for health changes
	if primary_escort and is_instance_valid(primary_escort):
		_update_hud()
