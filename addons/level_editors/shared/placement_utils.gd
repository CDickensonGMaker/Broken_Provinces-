@tool
class_name PlacementUtils
extends RefCounted
## Shared placement utilities for town editor and procedural generation
## Uses AABB collision detection to prevent building overlaps

const DEFAULT_SNAP_SIZE: float = 4.0

## Check if placement would overlap existing buildings using AABB
## Returns true if valid (no overlap), false if overlap detected
static func check_overlap(
	pos: Vector3,
	width: float,
	depth: float,
	existing_elements: Array,
	ignore_id: String = ""
) -> bool:
	var half_w: float = width / 2.0
	var half_d: float = depth / 2.0

	for elem in existing_elements:
		var elem_id: String = ""
		var elem_pos: Vector3 = Vector3.ZERO
		var elem_w: float = 4.0
		var elem_d: float = 4.0
		var elem_type: int = -1

		if elem is LevelEditorData.PlacedElement:
			elem_id = elem.id
			elem_pos = elem.position
			elem_w = elem.properties.get("width", 4.0)
			elem_d = elem.properties.get("depth", 4.0)
			elem_type = elem.element_type
		elif elem is Dictionary:
			elem_id = elem.get("id", "")
			var pos_dict: Dictionary = elem.get("position", {})
			elem_pos = Vector3(pos_dict.get("x", 0), pos_dict.get("y", 0), pos_dict.get("z", 0))
			var props: Dictionary = elem.get("properties", {})
			elem_w = props.get("width", 4.0)
			elem_d = props.get("depth", 4.0)
			elem_type = elem.get("element_type", 0)
		else:
			continue

		if elem_id == ignore_id:
			continue

		# Only check against buildings
		if elem_type != LevelEditorData.ElementType.BUILDING:
			continue

		var elem_half_w: float = elem_w / 2.0
		var elem_half_d: float = elem_d / 2.0

		# AABB overlap check on XZ plane
		var x_overlap: bool = abs(pos.x - elem_pos.x) < (half_w + elem_half_w - 0.1)
		var z_overlap: bool = abs(pos.z - elem_pos.z) < (half_d + elem_half_d - 0.1)

		if x_overlap and z_overlap:
			return false

	return true


## Snap position to grid
static func snap_to_grid(pos: Vector3, snap_size: float = DEFAULT_SNAP_SIZE) -> Vector3:
	return Vector3(
		roundf(pos.x / snap_size) * snap_size,
		0.0,  # Always Y=0 for buildings
		roundf(pos.z / snap_size) * snap_size
	)


## Find a valid position for a building
static func find_valid_position(
	rng: RandomNumberGenerator,
	width: float,
	depth: float,
	bounds_min: Vector2,
	bounds_max: Vector2,
	existing_elements: Array,
	center_exclusion: float = 10.0,
	snap_size: float = DEFAULT_SNAP_SIZE,
	max_attempts: int = 50
) -> Vector3:
	for attempt in range(max_attempts):
		var x: float = rng.randf_range(bounds_min.x, bounds_max.x)
		var z: float = rng.randf_range(bounds_min.y, bounds_max.y)
		var pos := snap_to_grid(Vector3(x, 0, z), snap_size)

		# Skip center area
		if center_exclusion > 0 and abs(pos.x) < center_exclusion and abs(pos.z) < center_exclusion:
			continue

		if check_overlap(pos, width, depth, existing_elements):
			return pos

	return Vector3.ZERO
