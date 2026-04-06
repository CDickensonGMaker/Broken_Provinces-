## dungeon_grid_data.gd - Core dungeon grid data types and door definitions
## Defines room types, directions, and which doors each room type has
class_name DungeonGridData
extends RefCounted


## Direction enum - Maps to 3D coordinates
## NORTH = -Z, SOUTH = +Z, EAST = +X, WEST = -X
enum Direction {
	NORTH = 0,  ## -Z direction
	SOUTH = 1,  ## +Z direction
	EAST = 2,   ## +X direction
	WEST = 3    ## -X direction
}


## Room type enum - All possible room shapes
enum RoomType {
	EMPTY = 0,           ## No room at this position
	START = 1,           ## Starting room (usually has all 4 doors)
	CORRIDOR_NS = 2,     ## North-South corridor
	CORRIDOR_EW = 3,     ## East-West corridor
	TURN_NE = 4,         ## L-turn: North and East doors
	TURN_NW = 5,         ## L-turn: North and West doors
	TURN_SE = 6,         ## L-turn: South and East doors
	TURN_SW = 7,         ## L-turn: South and West doors
	T_NORTH = 8,         ## T-junction open to North (N, E, W doors)
	T_SOUTH = 9,         ## T-junction open to South (S, E, W doors)
	T_EAST = 10,         ## T-junction open to East (N, S, E doors)
	T_WEST = 11,         ## T-junction open to West (N, S, W doors)
	CROSS = 12,          ## 4-way intersection (all doors)
	ROOM_SMALL = 13,     ## Small combat/treasure room (all doors)
	ROOM_MEDIUM = 14,    ## Medium room (all doors)
	ROOM_LARGE = 15,     ## Large room (all doors)
	ROOM_BOSS = 16,      ## Boss room (all doors)
	DEAD_END_N = 17,     ## Dead end with North door only
	DEAD_END_S = 18,     ## Dead end with South door only
	DEAD_END_E = 19,     ## Dead end with East door only
	DEAD_END_W = 20,     ## Dead end with West door only
	ROOM_PUZZLE_CRYSTAL = 21,  ## Crystal puzzle room (collect crystals in sequence)
	ROOM_PUZZLE_PILLAR = 22,   ## Pillar puzzle room (touch pillars in order)
	ROOM_TRAP_GAUNTLET = 23,   ## Trap gauntlet room (pressure plates, portals, hazards)
	HALLWAY_NS = 24,           ## Narrow North-South hallway (5 units wide)
	HALLWAY_EW = 25,           ## Narrow East-West hallway (5 units wide)
	## Cave room types - Natural/ruined aesthetic
	CAVE_ENTRANCE = 26,        ## Cave entrance (daylight, south door only)
	CAVE_EXIT = 27,            ## Cave exit (treasure/boss room, north door only)
	CAVE_CORRIDOR_NS = 28,     ## Natural cave N-S passage
	CAVE_CORRIDOR_EW = 29,     ## Natural cave E-W passage
	CAVE_CORNER_NE = 30,       ## Cave corner turn: North and East
	CAVE_CORNER_NW = 31,       ## Cave corner turn: North and West
	CAVE_CORNER_SE = 32,       ## Cave corner turn: South and East
	CAVE_CORNER_SW = 33,       ## Cave corner turn: South and West
	CAVE_T_JUNCTION = 34,      ## Cave three-way (N, E, W doors)
	CAVE_CROSSROADS = 35,      ## Cave four-way hub
	CAVE_DEAD_END = 36,        ## Cave dead end (south door only)
	CAVE_CHAMBER = 37          ## Large cave chamber (32x32, all doors)
}


## Maps each RoomType to its available doors
## Value is an Array of Direction enums
const ROOM_DOORS: Dictionary = {
	RoomType.EMPTY: [],
	RoomType.START: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.CORRIDOR_NS: [Direction.NORTH, Direction.SOUTH],
	RoomType.CORRIDOR_EW: [Direction.EAST, Direction.WEST],
	RoomType.TURN_NE: [Direction.NORTH, Direction.EAST],
	RoomType.TURN_NW: [Direction.NORTH, Direction.WEST],
	RoomType.TURN_SE: [Direction.SOUTH, Direction.EAST],
	RoomType.TURN_SW: [Direction.SOUTH, Direction.WEST],
	RoomType.T_NORTH: [Direction.NORTH, Direction.EAST, Direction.WEST],
	RoomType.T_SOUTH: [Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.T_EAST: [Direction.NORTH, Direction.SOUTH, Direction.EAST],
	RoomType.T_WEST: [Direction.NORTH, Direction.SOUTH, Direction.WEST],
	RoomType.CROSS: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_SMALL: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_MEDIUM: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_LARGE: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_BOSS: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.DEAD_END_N: [Direction.NORTH],
	RoomType.DEAD_END_S: [Direction.SOUTH],
	RoomType.DEAD_END_E: [Direction.EAST],
	RoomType.DEAD_END_W: [Direction.WEST],
	RoomType.ROOM_PUZZLE_CRYSTAL: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_PUZZLE_PILLAR: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.ROOM_TRAP_GAUNTLET: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.HALLWAY_NS: [Direction.NORTH, Direction.SOUTH],
	RoomType.HALLWAY_EW: [Direction.EAST, Direction.WEST],
	## Cave room doors
	RoomType.CAVE_ENTRANCE: [Direction.SOUTH],
	RoomType.CAVE_EXIT: [Direction.NORTH],
	RoomType.CAVE_CORRIDOR_NS: [Direction.NORTH, Direction.SOUTH],
	RoomType.CAVE_CORRIDOR_EW: [Direction.EAST, Direction.WEST],
	RoomType.CAVE_CORNER_NE: [Direction.NORTH, Direction.EAST],
	RoomType.CAVE_CORNER_NW: [Direction.NORTH, Direction.WEST],
	RoomType.CAVE_CORNER_SE: [Direction.SOUTH, Direction.EAST],
	RoomType.CAVE_CORNER_SW: [Direction.SOUTH, Direction.WEST],
	RoomType.CAVE_T_JUNCTION: [Direction.NORTH, Direction.EAST, Direction.WEST],
	RoomType.CAVE_CROSSROADS: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST],
	RoomType.CAVE_DEAD_END: [Direction.SOUTH],
	RoomType.CAVE_CHAMBER: [Direction.NORTH, Direction.SOUTH, Direction.EAST, Direction.WEST]
}


## Room size in world units (16x16 meter rooms)
const ROOM_SIZE: float = 16.0


## Get the opposite direction
static func get_opposite_direction(dir: Direction) -> Direction:
	match dir:
		Direction.NORTH:
			return Direction.SOUTH
		Direction.SOUTH:
			return Direction.NORTH
		Direction.EAST:
			return Direction.WEST
		Direction.WEST:
			return Direction.EAST
	return Direction.NORTH


## Get the offset for a direction as a Vector2i (grid coordinates)
static func get_direction_offset(dir: Direction) -> Vector2i:
	match dir:
		Direction.NORTH:
			return Vector2i(0, -1)
		Direction.SOUTH:
			return Vector2i(0, 1)
		Direction.EAST:
			return Vector2i(1, 0)
		Direction.WEST:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


## Check if a room type has a door in a specific direction
static func has_door(room_type: RoomType, dir: Direction) -> bool:
	if room_type == RoomType.EMPTY:
		return false
	var doors: Array = ROOM_DOORS.get(room_type, [])
	return dir in doors


## Get all doors for a room type
static func get_doors(room_type: RoomType) -> Array:
	return ROOM_DOORS.get(room_type, [])


## Convert grid coordinates to world position
static func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(grid_pos.x * ROOM_SIZE, 0.0, grid_pos.y * ROOM_SIZE)


## Convert world position to grid coordinates
static func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / ROOM_SIZE)),
		int(floor(world_pos.z / ROOM_SIZE))
	)


## Get the room type name as a string (for debugging/display)
static func get_room_type_name(room_type: RoomType) -> String:
	match room_type:
		RoomType.EMPTY: return "empty"
		RoomType.START: return "start"
		RoomType.CORRIDOR_NS: return "corridor_ns"
		RoomType.CORRIDOR_EW: return "corridor_ew"
		RoomType.TURN_NE: return "turn_ne"
		RoomType.TURN_NW: return "turn_nw"
		RoomType.TURN_SE: return "turn_se"
		RoomType.TURN_SW: return "turn_sw"
		RoomType.T_NORTH: return "t_north"
		RoomType.T_SOUTH: return "t_south"
		RoomType.T_EAST: return "t_east"
		RoomType.T_WEST: return "t_west"
		RoomType.CROSS: return "cross"
		RoomType.ROOM_SMALL: return "room_small"
		RoomType.ROOM_MEDIUM: return "room_medium"
		RoomType.ROOM_LARGE: return "room_large"
		RoomType.ROOM_BOSS: return "room_boss"
		RoomType.DEAD_END_N: return "dead_end_n"
		RoomType.DEAD_END_S: return "dead_end_s"
		RoomType.DEAD_END_E: return "dead_end_e"
		RoomType.DEAD_END_W: return "dead_end_w"
		RoomType.ROOM_PUZZLE_CRYSTAL: return "room_puzzle_crystal"
		RoomType.ROOM_PUZZLE_PILLAR: return "room_puzzle_pillar"
		RoomType.ROOM_TRAP_GAUNTLET: return "room_trap_gauntlet"
		RoomType.HALLWAY_NS: return "hallway_ns"
		RoomType.HALLWAY_EW: return "hallway_ew"
		RoomType.CAVE_ENTRANCE: return "cave_entrance"
		RoomType.CAVE_EXIT: return "cave_exit"
		RoomType.CAVE_CORRIDOR_NS: return "cave_corridor_ns"
		RoomType.CAVE_CORRIDOR_EW: return "cave_corridor_ew"
		RoomType.CAVE_CORNER_NE: return "cave_corner_ne"
		RoomType.CAVE_CORNER_NW: return "cave_corner_nw"
		RoomType.CAVE_CORNER_SE: return "cave_corner_se"
		RoomType.CAVE_CORNER_SW: return "cave_corner_sw"
		RoomType.CAVE_T_JUNCTION: return "cave_t_junction"
		RoomType.CAVE_CROSSROADS: return "cave_crossroads"
		RoomType.CAVE_DEAD_END: return "cave_dead_end"
		RoomType.CAVE_CHAMBER: return "cave_chamber"
	return "unknown"


## Get room type from string name
static func get_room_type_from_name(type_name: String) -> RoomType:
	match type_name.to_lower():
		"empty": return RoomType.EMPTY
		"start": return RoomType.START
		"corridor_ns": return RoomType.CORRIDOR_NS
		"corridor_ew": return RoomType.CORRIDOR_EW
		"turn_ne": return RoomType.TURN_NE
		"turn_nw": return RoomType.TURN_NW
		"turn_se": return RoomType.TURN_SE
		"turn_sw": return RoomType.TURN_SW
		"t_north": return RoomType.T_NORTH
		"t_south": return RoomType.T_SOUTH
		"t_east": return RoomType.T_EAST
		"t_west": return RoomType.T_WEST
		"cross": return RoomType.CROSS
		"room_small": return RoomType.ROOM_SMALL
		"room_medium": return RoomType.ROOM_MEDIUM
		"room_large": return RoomType.ROOM_LARGE
		"room_boss": return RoomType.ROOM_BOSS
		"dead_end_n": return RoomType.DEAD_END_N
		"dead_end_s": return RoomType.DEAD_END_S
		"dead_end_e": return RoomType.DEAD_END_E
		"dead_end_w": return RoomType.DEAD_END_W
		"room_puzzle_crystal": return RoomType.ROOM_PUZZLE_CRYSTAL
		"room_puzzle_pillar": return RoomType.ROOM_PUZZLE_PILLAR
		"room_trap_gauntlet": return RoomType.ROOM_TRAP_GAUNTLET
		"hallway_ns": return RoomType.HALLWAY_NS
		"hallway_ew": return RoomType.HALLWAY_EW
		"cave_entrance": return RoomType.CAVE_ENTRANCE
		"cave_exit": return RoomType.CAVE_EXIT
		"cave_corridor_ns": return RoomType.CAVE_CORRIDOR_NS
		"cave_corridor_ew": return RoomType.CAVE_CORRIDOR_EW
		"cave_corner_ne": return RoomType.CAVE_CORNER_NE
		"cave_corner_nw": return RoomType.CAVE_CORNER_NW
		"cave_corner_se": return RoomType.CAVE_CORNER_SE
		"cave_corner_sw": return RoomType.CAVE_CORNER_SW
		"cave_t_junction": return RoomType.CAVE_T_JUNCTION
		"cave_crossroads": return RoomType.CAVE_CROSSROADS
		"cave_dead_end": return RoomType.CAVE_DEAD_END
		"cave_chamber": return RoomType.CAVE_CHAMBER
	return RoomType.EMPTY


## Direction helpers
static func get_direction_name(dir: Direction) -> String:
	match dir:
		Direction.NORTH: return "North"
		Direction.SOUTH: return "South"
		Direction.EAST: return "East"
		Direction.WEST: return "West"
	return "Unknown"


## Find a corridor/connector room type that has exactly the required doors
## Does NOT return special rooms (boss, small, medium, large) - only connectors
## required_doors: Array of Direction values that the room MUST have
## Returns the best matching RoomType, or CROSS if no exact match
static func find_connector_with_doors(required_doors: Array) -> RoomType:
	if required_doors.is_empty():
		return RoomType.EMPTY

	# Sort for comparison
	var sorted_required: Array = required_doors.duplicate()
	sorted_required.sort()

	# Only check connector types (not special rooms)
	var connector_types: Array[RoomType] = [
		RoomType.CORRIDOR_NS,
		RoomType.CORRIDOR_EW,
		RoomType.HALLWAY_NS,
		RoomType.HALLWAY_EW,
		RoomType.TURN_NE,
		RoomType.TURN_NW,
		RoomType.TURN_SE,
		RoomType.TURN_SW,
		RoomType.T_NORTH,
		RoomType.T_SOUTH,
		RoomType.T_EAST,
		RoomType.T_WEST,
		RoomType.CROSS,
		RoomType.DEAD_END_N,
		RoomType.DEAD_END_S,
		RoomType.DEAD_END_E,
		RoomType.DEAD_END_W
	]

	# Try exact match first
	for room_type: RoomType in connector_types:
		var doors: Array = ROOM_DOORS[room_type].duplicate()
		doors.sort()
		if doors == sorted_required:
			return room_type

	# No exact match - find one with minimum extra doors that has all required
	var best_type: RoomType = RoomType.CROSS
	var min_extra: int = 999

	for room_type: RoomType in connector_types:
		var doors: Array = ROOM_DOORS[room_type]

		# Check if this room has all required doors
		var has_all: bool = true
		for req_door: Direction in required_doors:
			if req_door not in doors:
				has_all = false
				break

		if has_all:
			var extra: int = doors.size() - required_doors.size()
			if extra < min_extra:
				min_extra = extra
				best_type = room_type

	return best_type


## Check if a room type is a "special" room (not just a connector)
## Special rooms should not be auto-replaced
static func is_special_room(room_type: RoomType) -> bool:
	return room_type in [
		RoomType.START,
		RoomType.ROOM_SMALL,
		RoomType.ROOM_MEDIUM,
		RoomType.ROOM_LARGE,
		RoomType.ROOM_BOSS,
		RoomType.ROOM_PUZZLE_CRYSTAL,
		RoomType.ROOM_PUZZLE_PILLAR,
		RoomType.ROOM_TRAP_GAUNTLET,
		RoomType.CAVE_ENTRANCE,
		RoomType.CAVE_EXIT,
		RoomType.CAVE_CHAMBER
	]
