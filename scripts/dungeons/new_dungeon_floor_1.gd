## new_dungeon_floor_1.gd - Ancient Depths Upper Level
## First floor of the multi-floor dungeon accessible from Willow Dale
extends "res://scripts/dungeons/hand_crafted_dungeon.gd"

const ZONE_ID := "new_dungeon_floor_1"
const ZONE_NAME := "Ancient Depths - Upper Level"


func _ready() -> void:
	# Call parent _ready first for dungeon setup
	super._ready()

	# Set zone info for save system and UI
	SaveManager.set_current_zone(ZONE_ID, ZONE_NAME)
	AudioManager.play_zone_music("dungeon")

	# Setup custom spawn points for multi-floor navigation
	_setup_floor_spawn_points()


## Override parent's exit portal setup - we have custom portals
func _setup_exit_portal() -> void:
	# Don't call super - we handle portals ourselves
	_setup_floor_portals()


## Setup spawn points for entry from Willow Dale and return from Floor 2
func _setup_floor_spawn_points() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		push_warning("[Floor1] No Rooms node found for spawn points")
		return

	# Find the start room for entry spawn point
	var start_room: Node3D = null
	for room: Node in rooms_node.get_children():
		if room is Node3D:
			var room_type_int: int = room.get_meta("room_type", 0)
			if room_type_int == DungeonGridData.RoomType.START:
				start_room = room
				break

	if start_room:
		# Entry from Willow Dale - spawn in the start room center
		var spawn_points_container: Node3D = start_room.get_node_or_null("SpawnPoints")
		if not spawn_points_container:
			spawn_points_container = Node3D.new()
			spawn_points_container.name = "SpawnPoints"
			start_room.add_child(spawn_points_container)

		# Create the from_willow_dale spawn point (entry from cave)
		var from_willow := Marker3D.new()
		from_willow.name = "from_willow_dale"
		from_willow.position = Vector3(8, 0.5, 10)  # Center-ish of start room
		from_willow.set_meta("spawn_id", "from_willow_dale")
		from_willow.add_to_group("spawn_points")
		spawn_points_container.add_child(from_willow)
		Log.d("[Floor1] Spawn point 'from_willow_dale' created in start room")

	# Find the boss/end room for floor 2 return spawn
	var end_room: Node3D = null
	for room: Node in rooms_node.get_children():
		if room is Node3D:
			var room_type_int: int = room.get_meta("room_type", 0)
			if room_type_int == DungeonGridData.RoomType.BOSS:
				end_room = room
				break

	if end_room:
		# Return from Floor 2 - spawn near the descend portal
		var spawn_points_container: Node3D = end_room.get_node_or_null("SpawnPoints")
		if not spawn_points_container:
			spawn_points_container = Node3D.new()
			spawn_points_container.name = "SpawnPoints"
			end_room.add_child(spawn_points_container)

		var from_floor2 := Marker3D.new()
		from_floor2.name = "from_floor_2"
		from_floor2.position = Vector3(8, 0.5, 10)
		from_floor2.set_meta("spawn_id", "from_floor_2")
		from_floor2.add_to_group("spawn_points")
		spawn_points_container.add_child(from_floor2)
		Log.d("[Floor1] Spawn point 'from_floor_2' created in boss room")


## Setup portals for exit to wilderness and descend to Floor 2
func _setup_floor_portals() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		return

	# Find start room for exit portal
	var start_room: Node3D = null
	var boss_room: Node3D = null

	for room: Node in rooms_node.get_children():
		if room is Node3D:
			var room_type_int: int = room.get_meta("room_type", 0)
			if room_type_int == DungeonGridData.RoomType.START:
				start_room = room
			elif room_type_int == DungeonGridData.RoomType.BOSS:
				boss_room = room

	# Exit portal in start room - returns to wilderness (or Willow Dale)
	if start_room:
		var exit_portal: ZoneDoor = ZoneDoor.spawn_portal(
			start_room,
			Vector3(8.0, 0.5, 13.0),  # Near south wall
			SceneManager.RETURN_TO_WILDERNESS,
			"from_dungeon",
			"Exit to Surface"
		)
		if exit_portal:
			exit_portal.return_to_previous = true
			exit_portal.rotation_degrees.y = 180.0
			Log.d("[Floor1] Exit portal placed in start room")

	# Descend portal in boss room - goes to Floor 2
	if boss_room:
		var descend_portal: ZoneDoor = ZoneDoor.spawn_portal(
			boss_room,
			Vector3(8.0, 0.5, 3.0),  # Near north wall (deeper into dungeon)
			"res://scenes/dungeons/new_dungeon2.tscn",
			"from_floor_1",
			"Descend Deeper"
		)
		if descend_portal:
			descend_portal.rotation_degrees.y = 0.0  # Face south (toward player)
			Log.d("[Floor1] Descend portal placed in boss room")
