## follower_manager.gd - Global follower tracking autoload
## Manages active followers, persists across zone transitions, handles save/load
extends Node

## Signals
signal follower_added(follower_id: String)
signal follower_dismissed(follower_id: String)
signal follower_unconscious(follower_id: String)
signal follower_recovered(follower_id: String)
signal all_followers_commanded(command: String)

## Maximum number of active followers
const MAX_FOLLOWERS: int = 1  # Start with 1 max, can be expanded later

## Follower data resource (loaded from data files)
class FollowerData:
	var id: String = ""
	var display_name: String = "Follower"
	var sprite_path: String = ""
	var h_frames: int = 1
	var v_frames: int = 1
	var pixel_size: float = 0.0256
	var max_health: int = 50
	var damage: int = 12
	var armor: int = 10
	var combat_style: String = "melee"
	var is_essential: bool = true

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"display_name": display_name,
			"sprite_path": sprite_path,
			"h_frames": h_frames,
			"v_frames": v_frames,
			"pixel_size": pixel_size,
			"max_health": max_health,
			"damage": damage,
			"armor": armor,
			"combat_style": combat_style,
			"is_essential": is_essential
		}

	static func from_dict(data: Dictionary) -> FollowerData:
		var fd := FollowerData.new()
		fd.id = data.get("id", "")
		fd.display_name = data.get("display_name", "Follower")
		fd.sprite_path = data.get("sprite_path", "")
		fd.h_frames = data.get("h_frames", 1)
		fd.v_frames = data.get("v_frames", 1)
		fd.pixel_size = data.get("pixel_size", 0.0256)
		fd.max_health = data.get("max_health", 50)
		fd.damage = data.get("damage", 12)
		fd.armor = data.get("armor", 10)
		fd.combat_style = data.get("combat_style", "melee")
		fd.is_essential = data.get("is_essential", true)
		return fd


## Active followers (follower_id -> FollowerNPC reference)
## WARNING: These references become invalid on scene change - use follower_data instead
var active_followers: Dictionary = {}

## Saved follower state (follower_id -> serialized data dict)
## Used for zone transitions and save/load
var follower_data: Dictionary = {}

## Unlocked follower IDs (followers the player can recruit)
var available_followers: Array[String] = []

## Follower database (loaded from data files)
## Maps follower_id -> FollowerData
var follower_database: Dictionary = {}


func _ready() -> void:
	add_to_group("managers")

	# Connect to scene transitions to handle follower persistence
	if SceneManager and SceneManager.has_signal("scene_load_started"):
		SceneManager.scene_load_started.connect(_on_scene_load_started)
	if SceneManager and SceneManager.has_signal("scene_load_completed"):
		SceneManager.scene_load_completed.connect(_on_scene_load_completed)

	# Connect to QuestManager for follower recruitment via quests
	if QuestManager and QuestManager.has_signal("follower_recruited"):
		QuestManager.follower_recruited.connect(_on_follower_recruited_from_quest)

	# Load follower database
	_load_follower_database()


## Load follower definitions from data files
func _load_follower_database() -> void:
	var data_path := "res://data/followers/"
	var dir := DirAccess.open(data_path)
	if not dir:
		# Create empty database if no data folder exists
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".json"):
			var full_path: String = data_path + file_name
			_load_follower_from_file(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


## Load a single follower from file
func _load_follower_from_file(path: String) -> void:
	if path.ends_with(".json"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file:
			var json := JSON.new()
			var parse_result := json.parse(file.get_as_text())
			file.close()
			if parse_result == OK and json.data is Dictionary:
				var fd := FollowerData.from_dict(json.data)
				if not fd.id.is_empty():
					follower_database[fd.id] = fd


## Add a follower to the active party
func add_follower(follower: FollowerNPC) -> bool:
	if active_followers.size() >= MAX_FOLLOWERS:
		_show_notification("Cannot have more than %d follower(s)" % MAX_FOLLOWERS)
		return false

	if active_followers.has(follower.follower_id):
		return false  # Already following

	active_followers[follower.follower_id] = follower

	# Connect to follower signals
	if not follower.became_unconscious.is_connected(_on_follower_unconscious):
		follower.became_unconscious.connect(_on_follower_unconscious.bind(follower.follower_id))
	if not follower.recovered.is_connected(_on_follower_recovered):
		follower.recovered.connect(_on_follower_recovered.bind(follower.follower_id))

	# Store initial data
	follower_data[follower.follower_id] = follower.get_save_data()

	# Start following player
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		follower.start_following(player)

	follower_added.emit(follower.follower_id)
	_show_notification("%s is now following you" % follower.follower_name)
	return true


## Dismiss a follower from the party
func dismiss_follower(follower_id: String) -> void:
	if not active_followers.has(follower_id):
		return

	var follower: FollowerNPC = active_followers[follower_id]
	var follower_name_temp: String = follower.follower_name if is_instance_valid(follower) else follower_id

	# Disconnect signals
	if is_instance_valid(follower):
		if follower.became_unconscious.is_connected(_on_follower_unconscious):
			follower.became_unconscious.disconnect(_on_follower_unconscious)
		if follower.recovered.is_connected(_on_follower_recovered):
			follower.recovered.disconnect(_on_follower_recovered)

		# Stop following
		follower.command_wait()

	active_followers.erase(follower_id)
	follower_data.erase(follower_id)

	follower_dismissed.emit(follower_id)
	_show_notification("%s has left your party" % follower_name_temp)


## Get a specific follower by ID
func get_follower(follower_id: String) -> FollowerNPC:
	var follower: FollowerNPC = active_followers.get(follower_id)
	if is_instance_valid(follower):
		return follower
	return null


## Get all active followers
func get_all_followers() -> Array[FollowerNPC]:
	var result: Array[FollowerNPC] = []
	for id: String in active_followers:
		var follower: FollowerNPC = active_followers[id]
		if is_instance_valid(follower):
			result.append(follower)
	return result


## Issue a command to all followers
func issue_command_all(command: String) -> void:
	for follower_id: String in active_followers:
		var follower: FollowerNPC = active_followers[follower_id]
		if not is_instance_valid(follower):
			continue

		match command:
			"wait":
				follower.command_wait()
			"follow":
				follower.command_follow()

	all_followers_commanded.emit(command)


## Prepare followers for zone transition - save state
func prepare_for_zone_transition() -> void:
	for id: String in active_followers:
		var follower: FollowerNPC = active_followers[id]
		if is_instance_valid(follower):
			follower_data[id] = follower.get_save_data()

	# Clear active references (they will be invalid after scene change)
	active_followers.clear()


## Respawn followers after zone transition
func respawn_followers_after_transition(player: Node3D, spawn_position: Vector3) -> void:
	if follower_data.is_empty():
		return

	var parent: Node = player.get_parent()
	if not parent:
		return

	# Spawn each follower near the player
	var offset_index: int = 0
	var offsets: Array[Vector3] = [
		Vector3(2, 0, 2),
		Vector3(-2, 0, 2),
		Vector3(2, 0, -2),
		Vector3(-2, 0, -2)
	]

	for follower_id: String in follower_data:
		var data: Dictionary = follower_data[follower_id]
		var offset: Vector3 = offsets[offset_index % offsets.size()]
		var spawn_pos: Vector3 = spawn_position + offset
		offset_index += 1

		var follower: FollowerNPC = _spawn_follower_from_data(parent, spawn_pos, data)
		if follower:
			active_followers[follower_id] = follower
			follower.start_following(player)

			# Reconnect signals
			if not follower.became_unconscious.is_connected(_on_follower_unconscious):
				follower.became_unconscious.connect(_on_follower_unconscious.bind(follower_id))
			if not follower.recovered.is_connected(_on_follower_recovered):
				follower.recovered.connect(_on_follower_recovered.bind(follower_id))


## Spawn a follower from saved data
func _spawn_follower_from_data(parent: Node, pos: Vector3, data: Dictionary) -> FollowerNPC:
	var sprite_path: String = data.get("sprite_path", "")
	var h_frames: int = data.get("h_frames", 1)
	var v_frames: int = data.get("v_frames", 1)
	var pixel_size: float = data.get("pixel_size", 0.0256)

	var follower := FollowerNPC.spawn_follower(
		parent,
		pos,
		data.get("follower_id", ""),
		data.get("follower_name", "Follower"),
		sprite_path,
		h_frames,
		v_frames,
		pixel_size
	)

	if follower:
		follower.load_save_data(data)

	return follower


## Unlock a follower for recruitment
func unlock_follower(follower_id: String) -> void:
	if not available_followers.has(follower_id):
		available_followers.append(follower_id)


## Check if a follower is available for recruitment
func is_follower_available(follower_id: String) -> bool:
	return available_followers.has(follower_id)


## Check if a follower is currently active
func is_follower_active(follower_id: String) -> bool:
	return active_followers.has(follower_id)


## Get follower data from database
func get_follower_data(follower_id: String) -> FollowerData:
	return follower_database.get(follower_id)


## Get save data for persistence
func get_save_data() -> Dictionary:
	# Update follower_data with current state of active followers
	for id: String in active_followers:
		var follower: FollowerNPC = active_followers[id]
		if is_instance_valid(follower):
			follower_data[id] = follower.get_save_data()

	return {
		"active_follower_ids": active_followers.keys(),
		"follower_data": follower_data,
		"available_followers": available_followers
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	available_followers.clear()
	var available: Array = data.get("available_followers", [])
	for follower_id: Variant in available:
		if follower_id is String:
			available_followers.append(follower_id)

	follower_data = data.get("follower_data", {})

	# Active followers will be respawned on scene load via respawn_followers_after_transition


## Reset for new game
func reset_for_new_game() -> void:
	active_followers.clear()
	follower_data.clear()
	available_followers.clear()


## Clear node references before scene change
func _clear_node_references() -> void:
	active_followers.clear()


## Handle scene load started - save follower state
func _on_scene_load_started() -> void:
	prepare_for_zone_transition()


## Handle scene load completed - respawn followers
func _on_scene_load_completed(_scene_path: String) -> void:
	# Wait a frame for player to be set up
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		respawn_followers_after_transition(player, player.global_position)


## Handle follower becoming unconscious
func _on_follower_unconscious(follower_id: String) -> void:
	follower_unconscious.emit(follower_id)
	_show_notification("%s is unconscious!" % _get_follower_name(follower_id))


## Handle follower recovering
func _on_follower_recovered(follower_id: String) -> void:
	follower_recovered.emit(follower_id)
	_show_notification("%s has recovered" % _get_follower_name(follower_id))


## Handle follower recruited from quest
func _on_follower_recruited_from_quest(follower_id: String, _quest_id: String) -> void:
	unlock_follower(follower_id)


## Get follower name from ID
func _get_follower_name(follower_id: String) -> String:
	var follower: FollowerNPC = get_follower(follower_id)
	if follower:
		return follower.follower_name

	var data: Dictionary = follower_data.get(follower_id, {})
	return data.get("follower_name", follower_id)


## Show notification via HUD
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Get number of active followers
func get_active_follower_count() -> int:
	return active_followers.size()


## Check if at max followers
func is_at_max_followers() -> bool:
	return active_followers.size() >= MAX_FOLLOWERS


## Convert FollowerData to dict for serialization
func to_dict() -> Dictionary:
	return get_save_data()


## Load from dict (for save compatibility)
func from_dict(data: Dictionary) -> void:
	load_save_data(data)
