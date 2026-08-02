## new_dungeon_floor_2.gd - Ancient Depths Lower Level
## Second floor of the multi-floor dungeon, accessed from Floor 1
extends "res://scripts/generation/dungeons/hand_crafted_dungeon.gd"

const ZONE_ID := "new_dungeon_floor_2"
const ZONE_NAME := "Ancient Depths - Lower Level"


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


## Setup spawn point for entry from Floor 1
func _setup_floor_spawn_points() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		push_warning("[Floor2] No Rooms node found for spawn points")
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
		# Entry from Floor 1 - spawn in the start room center
		var spawn_points_container: Node3D = start_room.get_node_or_null("SpawnPoints")
		if not spawn_points_container:
			spawn_points_container = Node3D.new()
			spawn_points_container.name = "SpawnPoints"
			start_room.add_child(spawn_points_container)

		# Create the from_floor_1 spawn point
		var from_floor1 := Marker3D.new()
		from_floor1.name = "from_floor_1"
		from_floor1.position = Vector3(8, 0.5, 10)  # Center-ish of start room
		from_floor1.set_meta("spawn_id", "from_floor_1")
		from_floor1.add_to_group("spawn_points")
		spawn_points_container.add_child(from_floor1)
		Log.d("[Floor2] Spawn point 'from_floor_1' created in start room")


## Setup portal to return to Floor 1
func _setup_floor_portals() -> void:
	var rooms_node: Node3D = get_node_or_null("Rooms")
	if not rooms_node:
		return

	# Find start room for return portal
	var start_room: Node3D = null
	for room: Node in rooms_node.get_children():
		if room is Node3D:
			var room_type_int: int = room.get_meta("room_type", 0)
			if room_type_int == DungeonGridData.RoomType.START:
				start_room = room
				break

	# Return portal in start room - goes back to Floor 1
	if start_room:
		var return_portal: ZoneDoor = ZoneDoor.spawn_portal(
			start_room,
			Vector3(8.0, 0.5, 13.0),  # Near south wall
			"res://scenes/generation/dungeons/new_dungeon.tscn",
			"from_floor_2",
			"Ascend to Upper Level"
		)
		if return_portal:
			return_portal.rotation_degrees.y = 180.0  # Face north (toward player)
			Log.d("[Floor2] Return portal placed in start room")
