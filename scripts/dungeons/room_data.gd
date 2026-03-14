## room_data.gd - Resource class for dungeon room definitions
##
## Defines the template for a room that can be placed in a procedural dungeon.
## Each RoomData resource describes a room's footprint, entrances, and constraints.
@tool
class_name RoomData
extends Resource

## Direction constants (clockwise from North)
enum Dir { NORTH = 0, EAST = 1, SOUTH = 2, WEST = 3 }

## Room type tags for generation rules
enum RoomTag {
	START,       ## Starting room - exactly one per dungeon
	BOSS,        ## Boss room - exactly one per dungeon
	TREASURE,    ## Contains loot
	HIDDEN,      ## Secret room behind false wall
	CORRIDOR,    ## Simple connector room
	SHRINE,      ## Contains shrine or altar
	TRAP,        ## Contains trap hazard
	LOCKED,      ## Requires key to enter
	DEAD_END     ## Single entrance fallback room
}

## Room footprint in grid cells (e.g., Vector2i(2, 3) = 2x3 cells)
## The anchor cell is always the bottom-left (SW) corner at rotation 0
@export var footprint: Vector2i = Vector2i(1, 1)

## Local cell positions of entrances relative to anchor (rotation 0)
## Each Vector2i is a cell offset from the anchor
@export var entrances: Array[Vector2i] = []

## Direction each entrance faces (indexes match entrances array)
## Dir.NORTH means the entrance opens to the north
@export var entrance_dirs: Array[int] = []

## Tags for this room (used for generation constraints)
@export var tags: Array[RoomTag] = []

## Valid rotations in degrees (subset of [0, 90, 180, 270])
@export var valid_rotations: Array[int] = [0, 90, 180, 270]

## Minimum depth from start before this room can appear
@export var min_depth: int = 0

## Maximum instances of this room per dungeon (0 = unlimited)
@export var max_count: int = 0

## The scene to instantiate for this room
@export var scene: PackedScene = null

## Unique identifier for this room type
@export var room_id: String = ""

## Display name for debugging
@export var display_name: String = ""


## Returns the number of entrances this room has
func get_entrance_count() -> int:
	return entrances.size()


## Check if this room has a specific tag
func has_tag(tag: RoomTag) -> bool:
	return tag in tags


## Check if this room is a start room
func is_start() -> bool:
	return has_tag(RoomTag.START)


## Check if this room is a boss room
func is_boss() -> bool:
	return has_tag(RoomTag.BOSS)


## Check if this room is a hidden room
func is_hidden() -> bool:
	return has_tag(RoomTag.HIDDEN)


## Check if this is a dead-end fallback room (single entrance)
func is_dead_end() -> bool:
	return has_tag(RoomTag.DEAD_END) or entrances.size() == 1


## Check if a rotation value is valid for this room
func is_rotation_valid(rotation_deg: int) -> bool:
	return rotation_deg in valid_rotations


## Get footprint cells in local space (before rotation)
func get_local_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(footprint.x):
		for y in range(footprint.y):
			cells.append(Vector2i(x, y))
	return cells


## Validate that entrance_dirs matches entrances count
func _validate_property(property: Dictionary) -> void:
	if property.name == "entrance_dirs":
		if entrance_dirs.size() != entrances.size():
			push_warning("RoomData '%s': entrance_dirs count (%d) doesn't match entrances count (%d)" % [
				room_id, entrance_dirs.size(), entrances.size()
			])
