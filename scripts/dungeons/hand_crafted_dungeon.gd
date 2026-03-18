## hand_crafted_dungeon.gd - Base script for hand-crafted dungeon scenes
## Attach this to dungeon scenes created by the Dungeon Assembler
extends Node3D

const ZONE_ID := "hand_crafted_dungeon"

@export var spawn_id: String = "default"

var _player_spawned: bool = false


func _ready() -> void:
	print("[HandCraftedDungeon] _ready() called")
	print("[HandCraftedDungeon] Children: %s" % str(get_children().map(func(c): return c.name)))

	var rooms_node: Node = get_node_or_null("Rooms")
	if rooms_node:
		print("[HandCraftedDungeon] Rooms node found with %d children" % rooms_node.get_child_count())
		for room in rooms_node.get_children():
			print("[HandCraftedDungeon]   - Room: %s at %s" % [room.name, str(room.position) if room is Node3D else "N/A"])
	else:
		print("[HandCraftedDungeon] ERROR: No 'Rooms' node found!")

	# Ensure dungeon has proper lighting
	_ensure_lighting()
	# Find and spawn player at the designated spawn point
	call_deferred("_spawn_player")


func _spawn_player() -> void:
	print("[HandCraftedDungeon] _spawn_player() called, spawn_id=%s" % spawn_id)
	if _player_spawned:
		print("[HandCraftedDungeon] Player already spawned, skipping")
		return

	var spawn_point: Marker3D = _find_spawn_point(spawn_id)
	print("[HandCraftedDungeon] _find_spawn_point('%s') returned: %s" % [spawn_id, spawn_point])
	if not spawn_point:
		# Try finding any spawn point
		spawn_point = _find_any_spawn_point()
		print("[HandCraftedDungeon] _find_any_spawn_point() returned: %s" % spawn_point)

	if not spawn_point:
		push_error("[HandCraftedDungeon] No spawn point found!")
		print("[HandCraftedDungeon] ERROR: No spawn point found anywhere!")
		return

	var spawn_pos: Vector3 = spawn_point.global_position
	print("[HandCraftedDungeon] Spawning player at %s" % str(spawn_pos))

	# Try to find existing player
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player is Node3D:
		player.global_position = spawn_pos + Vector3(0, 0.5, 0)
		_player_spawned = true
		print("[HandCraftedDungeon] Player teleported to spawn point")
	else:
		# Player doesn't exist yet - instantiate it
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos + Vector3(0, 0.5, 0)
			_player_spawned = true
			print("[HandCraftedDungeon] Player instantiated at spawn point")


func _find_spawn_point(target_spawn_id: String) -> Marker3D:
	# Search for spawn point with matching spawn_id in all rooms
	var rooms: Node3D = get_node_or_null("Rooms")
	if not rooms:
		return null

	for room: Node in rooms.get_children():
		var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
		if spawn_points:
			for marker: Node in spawn_points.get_children():
				if marker is Marker3D:
					var marker_spawn_id: String = marker.get_meta("spawn_id", "")
					if marker_spawn_id == target_spawn_id:
						return marker

	return null


func _find_any_spawn_point() -> Marker3D:
	# Find the first spawn point in the starter_room or first room
	var rooms: Node3D = get_node_or_null("Rooms")
	if not rooms:
		return null

	# Try start room first - check for rooms named "start_X_Y" (from DungeonBuilder)
	for room: Node in rooms.get_children():
		if room.name.begins_with("start_"):
			var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
			if spawn_points and spawn_points.get_child_count() > 0:
				var first_spawn: Node = spawn_points.get_child(0)
				if first_spawn is Marker3D:
					return first_spawn

	# Fall back to first room with spawn points
	for room: Node in rooms.get_children():
		var spawn_points: Node3D = room.get_node_or_null("SpawnPoints")
		if spawn_points and spawn_points.get_child_count() > 0:
			var first_spawn: Node = spawn_points.get_child(0)
			if first_spawn is Marker3D:
				return first_spawn

	return null


func _ensure_lighting() -> void:
	# Check if dungeon already has lighting
	var has_light: bool = false
	for child: Node in get_children():
		if child is DirectionalLight3D or child is WorldEnvironment:
			has_light = true
			break

	if not has_light:
		_add_default_dungeon_lighting()


func _add_default_dungeon_lighting() -> void:
	# Add directional light for basic visibility
	var light := DirectionalLight3D.new()
	light.name = "DungeonLight"
	light.rotation_degrees = Vector3(-45, 45, 0)
	light.light_energy = 1.2  # Increased for better visibility
	light.shadow_enabled = false
	add_child(light)

	# Add ambient lighting via WorldEnvironment
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.06, 0.05)  # Dark dungeon background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.25, 0.2)  # Brighter ambient for visibility
	env.ambient_light_energy = 1.0  # Increased from 0.6

	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	print("[HandCraftedDungeon] Added default dungeon lighting")
