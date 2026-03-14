## placed_room.gd - Runtime data for a room placed in the dungeon grid
##
## This is a plain class (not Resource) that tracks the state of a room
## after it has been placed during dungeon generation.
class_name PlacedRoom
extends RefCounted

## Reference to the RoomData template this room was created from
var room_data: RoomData = null

## Grid cell position of this room's anchor (bottom-left corner)
var cell: Vector2i = Vector2i.ZERO

## Rotation applied to this room in degrees (0, 90, 180, 270)
var rotation_deg: int = 0

## Indices of exits that are connected to other rooms
## Index corresponds to room_data.entrances array
var connected_exits: Array[int] = []

## BFS depth from the start room (start room = 0)
var depth: int = 0

## Whether this is a hidden room (behind false wall)
var is_hidden: bool = false

## Unique instance ID assigned during placement
var instance_id: int = -1

## Scene instance (set during population phase, null during generation)
var scene_instance: Node3D = null


## Create a new PlacedRoom
static func create(
	p_room_data: RoomData,
	p_cell: Vector2i,
	p_rotation_deg: int,
	p_depth: int = 0
) -> PlacedRoom:
	var room := PlacedRoom.new()
	room.room_data = p_room_data
	room.cell = p_cell
	room.rotation_deg = p_rotation_deg
	room.depth = p_depth
	return room


## Get the world-space transform origin for this room
func get_world_position() -> Vector3:
	return DungeonUtils.grid_to_world(cell)


## Get all grid cells occupied by this room (accounting for rotation)
func get_occupied_cells() -> Array[Vector2i]:
	if room_data == null:
		return []
	return DungeonUtils.get_footprint_cells(cell, room_data.footprint, rotation_deg)


## Get the rotated entrance positions in world grid coordinates
func get_world_entrances() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if room_data == null:
		return result

	for local_entrance: Vector2i in room_data.entrances:
		# Rotate the local entrance offset
		var rotated: Vector2i = DungeonUtils.rotate_cell(local_entrance, room_data.footprint, rotation_deg)
		# Add to anchor position
		result.append(cell + rotated)
	return result


## Get the rotated entrance directions in world space
func get_world_entrance_dirs() -> Array[int]:
	var result: Array[int] = []
	if room_data == null:
		return result

	for dir: int in room_data.entrance_dirs:
		result.append(DungeonUtils.rotate_dir(dir, rotation_deg))
	return result


## Check if a specific exit index is connected
func is_exit_connected(exit_index: int) -> bool:
	return exit_index in connected_exits


## Mark an exit as connected
func connect_exit(exit_index: int) -> void:
	if exit_index not in connected_exits:
		connected_exits.append(exit_index)


## Get the number of unconnected exits
func get_unconnected_exit_count() -> int:
	if room_data == null:
		return 0
	return room_data.get_entrance_count() - connected_exits.size()


## Get indices of unconnected exits
func get_unconnected_exits() -> Array[int]:
	var result: Array[int] = []
	if room_data == null:
		return result

	for i in range(room_data.get_entrance_count()):
		if i not in connected_exits:
			result.append(i)
	return result


## Get debug string representation
func to_string() -> String:
	var room_name: String = room_data.room_id if room_data else "null"
	return "PlacedRoom[%s @ %s rot=%d depth=%d connected=%d/%d hidden=%s]" % [
		room_name,
		str(cell),
		rotation_deg,
		depth,
		connected_exits.size(),
		room_data.get_entrance_count() if room_data else 0,
		str(is_hidden)
	]
