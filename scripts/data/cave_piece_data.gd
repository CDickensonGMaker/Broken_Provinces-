## cave_piece_data.gd - Categorization data for modular mine kit pieces
## Maps mine kit GLB files to piece types and opening directions
class_name CavePieceData
extends RefCounted

## Piece type categories
enum PieceType {
	STRAIGHT,      ## 2 openings, opposite ends (N-S or E-W)
	CORNER,        ## 2 openings, 90-degree turn
	T_JUNCTION,    ## 3 openings
	CROSSROADS,    ## 4 openings
	DEAD_END,      ## 1 opening
	ROOM_SMALL,    ## Small chamber, 2+ openings
	ROOM_LARGE,    ## Large chamber, 2+ openings
	ENTRANCE,      ## Special entrance piece
	SHAFT,         ## Vertical mine shaft with ladder
	RAMP,          ## Sloped passage for height change
	DETAIL         ## Small decorative piece (props, rubble)
}

## Opening directions (matches DungeonGridData.Direction)
enum Opening {
	NORTH = 0,
	SOUTH = 1,
	EAST = 2,
	WEST = 3
}

## Standard tile size for the dungeon grid
const TILE_SIZE: float = 16.0

## Piece definitions based on Blender analysis
## Each piece includes:
##   type: PieceType enum
##   openings: Array of Opening directions
##   original_size: Vector3 of original dimensions (X, Y, Z in Blender = X, Z, Y in Godot)
##   scale: Scale factor to fit standard tile size
##   scene_path: Path to .tscn wrapper scene
##   glb_path: Path to source GLB file
const PIECES: Dictionary = {
	# Entrance piece - already properly sized at 16x16
	"mine_entrance": {
		"type": PieceType.ENTRANCE,
		"openings": [Opening.SOUTH],
		"original_size": Vector3(16.18, 16.0, 6.02),
		"scale": 1.0,
		"scene_path": "res://scenes/rooms/caves/mine_entrance.tscn",
		"glb_path": "res://assets/models/caves/cave_entrance_1exit.glb",
		"room_type": "CAVE_ENTRANCE"
	},

	# Piece 01 - Very small dead end / detail piece
	"mine_dead_end_small": {
		"type": PieceType.DEAD_END,
		"openings": [Opening.SOUTH],
		"original_size": Vector3(4.36, 6.44, 4.47),
		"scale": 2.5,  # Scale up to ~11x16
		"scene_path": "res://scenes/rooms/caves/mine_dead_end_small.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_01.glb",
		"room_type": "CAVE_DEAD_END"
	},

	# Piece 02 - Corner piece (square-ish shape suggests junction)
	"mine_corner_se": {
		"type": PieceType.CORNER,
		"openings": [Opening.SOUTH, Opening.EAST],
		"original_size": Vector3(8.60, 8.22, 5.42),
		"scale": 1.9,  # Scale to ~16x16
		"scene_path": "res://scenes/rooms/caves/mine_corner_se.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_02.glb",
		"room_type": "CAVE_CORNER_SE"
	},

	# Piece 03 - Long narrow N-S corridor
	"mine_corridor_ns_long": {
		"type": PieceType.STRAIGHT,
		"openings": [Opening.NORTH, Opening.SOUTH],
		"original_size": Vector3(5.77, 14.57, 5.33),
		"scale": 1.1,  # Scale slightly to fit 16 length
		"scene_path": "res://scenes/rooms/caves/mine_corridor_ns_long.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_03.glb",
		"room_type": "CAVE_CORRIDOR_NS"
	},

	# Piece 04 - Small piece, use as dead end variant
	"mine_dead_end_medium": {
		"type": PieceType.DEAD_END,
		"openings": [Opening.NORTH],
		"original_size": Vector3(6.47, 7.32, 4.75),
		"scale": 2.2,  # Scale up
		"scene_path": "res://scenes/rooms/caves/mine_dead_end_medium.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_04.glb",
		"room_type": "CAVE_DEAD_END"
	},

	# Piece 05 - Square corner/junction piece
	"mine_corner_nw": {
		"type": PieceType.CORNER,
		"openings": [Opening.NORTH, Opening.WEST],
		"original_size": Vector3(8.93, 8.93, 4.73),
		"scale": 1.8,  # Scale to ~16x16
		"scene_path": "res://scenes/rooms/caves/mine_corner_nw.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_05.glb",
		"room_type": "CAVE_CORNER_NW"
	},

	# Piece 06 - Narrow E-W corridor
	"mine_corridor_ew_narrow": {
		"type": PieceType.STRAIGHT,
		"openings": [Opening.EAST, Opening.WEST],
		"original_size": Vector3(4.42, 8.90, 4.47),
		"scale": 1.8,  # Scale up
		"scene_path": "res://scenes/rooms/caves/mine_corridor_ew_narrow.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_06.glb",
		"room_type": "CAVE_CORRIDOR_EW"
	},

	# Piece 07 - Long N-S corridor (similar to 03)
	"mine_corridor_ns_standard": {
		"type": PieceType.STRAIGHT,
		"openings": [Opening.NORTH, Opening.SOUTH],
		"original_size": Vector3(5.23, 14.57, 5.33),
		"scale": 1.1,
		"scene_path": "res://scenes/rooms/caves/mine_corridor_ns_standard.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_07.glb",
		"room_type": "CAVE_CORRIDOR_NS"
	},

	# Piece 08 - Tall vertical mine shaft
	"mine_shaft_vertical": {
		"type": PieceType.SHAFT,
		"openings": [Opening.NORTH, Opening.SOUTH],
		"original_size": Vector3(14.06, 12.33, 16.24),
		"scale": 1.15,  # Slight scale to 16x16 footprint
		"scene_path": "res://scenes/rooms/caves/mine_shaft_vertical.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_08.glb",
		"room_type": "CAVE_CORRIDOR_NS",  # Treated as corridor for pathfinding
		"height_change": -8.0  # Drops down 8 units
	},

	# Piece 09 - Small ramp piece
	"mine_ramp_down": {
		"type": PieceType.RAMP,
		"openings": [Opening.NORTH, Opening.SOUTH],
		"original_size": Vector3(4.57, 9.23, 7.66),
		"scale": 1.75,
		"scene_path": "res://scenes/rooms/caves/mine_ramp_down.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_09.glb",
		"room_type": "CAVE_CORRIDOR_NS",
		"height_change": -4.0  # Gradual descent
	},

	# Piece 10 - Long ramp/sloped passage
	"mine_ramp_long": {
		"type": PieceType.RAMP,
		"openings": [Opening.NORTH, Opening.SOUTH],
		"original_size": Vector3(6.11, 14.69, 7.85),
		"scale": 1.1,
		"scene_path": "res://scenes/rooms/caves/mine_ramp_long.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_10.glb",
		"room_type": "CAVE_CORRIDOR_NS",
		"height_change": -4.0
	},

	# Piece 11 - Large mining chamber
	"mine_chamber_medium": {
		"type": PieceType.ROOM_LARGE,
		"openings": [Opening.NORTH, Opening.SOUTH, Opening.EAST, Opening.WEST],
		"original_size": Vector3(12.43, 22.18, 8.44),
		"scale": 1.3,  # Scale to ~16x~28 (takes 2 grid cells)
		"scene_path": "res://scenes/rooms/caves/mine_chamber_medium.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_11.glb",
		"room_type": "CAVE_CHAMBER",
		"grid_size": Vector2i(1, 2)  # Occupies 1x2 grid cells
	},

	# Piece 12 - Largest mining hall
	"mine_hall_large": {
		"type": PieceType.ROOM_LARGE,
		"openings": [Opening.NORTH, Opening.SOUTH, Opening.EAST, Opening.WEST],
		"original_size": Vector3(12.72, 26.39, 8.48),
		"scale": 1.25,
		"scene_path": "res://scenes/rooms/caves/mine_hall_large.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_12.glb",
		"room_type": "CAVE_CHAMBER",
		"grid_size": Vector2i(1, 2)
	},

	# Piece 13 - Medium mining room
	"mine_chamber_small": {
		"type": PieceType.ROOM_SMALL,
		"openings": [Opening.NORTH, Opening.SOUTH, Opening.EAST, Opening.WEST],
		"original_size": Vector3(11.32, 18.53, 8.44),
		"scale": 1.4,  # Scale to ~16x~26
		"scene_path": "res://scenes/rooms/caves/mine_chamber_small.tscn",
		"glb_path": "res://assets/models/caves/cave_piece_13.glb",
		"room_type": "CAVE_CHAMBER",
		"grid_size": Vector2i(1, 2)
	}
}

## Map from DungeonGridData.RoomType names to compatible mine pieces
## Multiple pieces can map to same room type for variety
const ROOM_TYPE_TO_PIECES: Dictionary = {
	"CAVE_ENTRANCE": ["mine_entrance"],
	"CAVE_EXIT": ["mine_dead_end_medium", "mine_dead_end_small"],
	"CAVE_CORRIDOR_NS": ["mine_corridor_ns_long", "mine_corridor_ns_standard", "mine_ramp_down", "mine_ramp_long"],
	"CAVE_CORRIDOR_EW": ["mine_corridor_ew_narrow"],
	"CAVE_CORNER_NE": ["mine_corner_se"],  # Rotate 90 CW
	"CAVE_CORNER_NW": ["mine_corner_nw"],
	"CAVE_CORNER_SE": ["mine_corner_se"],
	"CAVE_CORNER_SW": ["mine_corner_nw"],  # Rotate 90 CCW
	"CAVE_T_JUNCTION": ["mine_corner_se", "mine_corner_nw"],  # Use corners for T-junctions
	"CAVE_CROSSROADS": ["mine_chamber_small"],  # Chambers work as crossroads
	"CAVE_DEAD_END": ["mine_dead_end_small", "mine_dead_end_medium"],
	"CAVE_CHAMBER": ["mine_chamber_small", "mine_chamber_medium", "mine_hall_large"]
}


## Get a random piece ID for a given room type
static func get_piece_for_room_type(room_type_name: String) -> String:
	var pieces: Array = ROOM_TYPE_TO_PIECES.get(room_type_name, [])
	if pieces.is_empty():
		push_warning("[CavePieceData] No piece found for room type: %s" % room_type_name)
		return ""
	return pieces[randi() % pieces.size()]


## Get piece data by ID
static func get_piece_data(piece_id: String) -> Dictionary:
	return PIECES.get(piece_id, {})


## Get the scene path for a piece
static func get_scene_path(piece_id: String) -> String:
	var data: Dictionary = PIECES.get(piece_id, {})
	return data.get("scene_path", "")


## Get rotation needed to align piece openings with target direction
## Returns rotation in degrees around Y axis
static func get_rotation_for_opening(piece_id: String, target_opening: int) -> float:
	var data: Dictionary = PIECES.get(piece_id, {})
	var openings: Array = data.get("openings", [])

	if openings.is_empty():
		return 0.0

	# Find the first opening and calculate rotation to align it with target
	var first_opening: int = openings[0]

	# Rotation needed to move first_opening to target_opening
	# Opening enum: NORTH=0, SOUTH=1, EAST=2, WEST=3
	# Each 90 degrees clockwise: N->E->S->W->N
	var rotation_map: Dictionary = {
		Opening.NORTH: {Opening.NORTH: 0, Opening.EAST: 90, Opening.SOUTH: 180, Opening.WEST: 270},
		Opening.SOUTH: {Opening.NORTH: 180, Opening.EAST: 270, Opening.SOUTH: 0, Opening.WEST: 90},
		Opening.EAST: {Opening.NORTH: 270, Opening.EAST: 0, Opening.SOUTH: 90, Opening.WEST: 180},
		Opening.WEST: {Opening.NORTH: 90, Opening.EAST: 180, Opening.SOUTH: 270, Opening.WEST: 0}
	}

	return rotation_map.get(first_opening, {}).get(target_opening, 0.0)


## Get all piece IDs of a specific type
static func get_pieces_by_type(piece_type: PieceType) -> Array[String]:
	var result: Array[String] = []
	for piece_id: String in PIECES.keys():
		var data: Dictionary = PIECES[piece_id]
		if data.get("type", -1) == piece_type:
			result.append(piece_id)
	return result


## Check if a piece has height change (ramp or shaft)
static func has_height_change(piece_id: String) -> bool:
	var data: Dictionary = PIECES.get(piece_id, {})
	return data.has("height_change")


## Get the height change for a piece (negative = descending)
static func get_height_change(piece_id: String) -> float:
	var data: Dictionary = PIECES.get(piece_id, {})
	return data.get("height_change", 0.0)
