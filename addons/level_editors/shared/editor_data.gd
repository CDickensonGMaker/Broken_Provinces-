@tool
class_name LevelEditorData
extends RefCounted
## Shared data structures for Town and Dungeon editors

## Placeable element types
enum ElementType {
	BUILDING,
	NPC,
	PROP,
	FUNCTIONAL,
	CUSTOM_MODEL,
	DUNGEON_ROOM
}

## Collision modes for custom models
enum CollisionMode {
	AUTO,       # Use existing collision if present
	TRIMESH,    # Generate trimesh collision
	CONVEX,     # Generate convex collision
	NONE        # No collision
}

## Placed element data (serializable)
class PlacedElement:
	var id: String = ""
	var element_type: ElementType = ElementType.PROP
	var position: Vector3 = Vector3.ZERO
	var rotation: Vector3 = Vector3.ZERO  # Euler degrees
	var scale: Vector3 = Vector3.ONE
	var properties: Dictionary = {}  # Type-specific properties

	func _init() -> void:
		id = str(randi()) + "_" + str(Time.get_ticks_msec())

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"element_type": element_type,
			"position": {"x": position.x, "y": position.y, "z": position.z},
			"rotation": {"x": rotation.x, "y": rotation.y, "z": rotation.z},
			"scale": {"x": scale.x, "y": scale.y, "z": scale.z},
			"properties": properties
		}

	static func from_dict(data: Dictionary) -> PlacedElement:
		var elem := PlacedElement.new()
		elem.id = data.get("id", elem.id)
		elem.element_type = data.get("element_type", ElementType.PROP)
		var pos: Dictionary = data.get("position", {})
		elem.position = Vector3(pos.get("x", 0), pos.get("y", 0), pos.get("z", 0))
		var rot: Dictionary = data.get("rotation", {})
		elem.rotation = Vector3(rot.get("x", 0), rot.get("y", 0), rot.get("z", 0))
		var scl: Dictionary = data.get("scale", {})
		elem.scale = Vector3(scl.get("x", 1), scl.get("y", 1), scl.get("z", 1))
		elem.properties = data.get("properties", {})
		return elem


## Building properties
class BuildingData:
	var building_type: String = "house"  # house, inn, shop, temple, etc.
	var width: float = 8.0
	var height: float = 4.0
	var depth: float = 6.0
	var roof_type: String = "flat"  # flat, sloped, peaked
	var material_preset: String = "wood"  # wood, stone, brick
	var shop_type: String = ""  # For merchant buildings
	var has_interior: bool = false
	var interior_scene: String = ""
	var lock_dc: int = 0  # 0 = unlocked

	func to_dict() -> Dictionary:
		return {
			"building_type": building_type,
			"width": width,
			"height": height,
			"depth": depth,
			"roof_type": roof_type,
			"material_preset": material_preset,
			"shop_type": shop_type,
			"has_interior": has_interior,
			"interior_scene": interior_scene,
			"lock_dc": lock_dc
		}


## NPC properties (for level editor, not the game NPCData)
class EditorNPCData:
	var npc_type: String = "civilian"  # civilian, guard, merchant, quest_giver
	var npc_name: String = ""
	var sprite_path: String = ""
	var patrol_points: Array[Vector3] = []
	var dialogue_id: String = ""
	var merchant_type: String = ""  # For merchants
	var quest_ids: Array[String] = []  # For quest givers

	func to_dict() -> Dictionary:
		var patrol_arr: Array = []
		for p: Vector3 in patrol_points:
			patrol_arr.append({"x": p.x, "y": p.y, "z": p.z})
		return {
			"npc_type": npc_type,
			"npc_name": npc_name,
			"sprite_path": sprite_path,
			"patrol_points": patrol_arr,
			"dialogue_id": dialogue_id,
			"merchant_type": merchant_type,
			"quest_ids": quest_ids
		}


## Custom model properties
class CustomModelData:
	var model_path: String = ""  # res://assets/models/...
	var collision_mode: CollisionMode = CollisionMode.AUTO
	var cast_shadows: bool = true
	var material_override: String = ""
	var tags: Array[String] = []

	func to_dict() -> Dictionary:
		return {
			"model_path": model_path,
			"collision_mode": collision_mode,
			"cast_shadows": cast_shadows,
			"material_override": material_override,
			"tags": tags
		}


## =============================================================================
## DAGGERFALL-STYLE DUNGEON BLOCK SYSTEM
## =============================================================================

## Block type definitions with connection info and CSG generation parameters
## Door positions are normalized (0-1) relative to block edge:
##   "N": Vector2(0.5, 0.0) = center of north edge
##   "S": Vector2(0.5, 1.0) = center of south edge
##   "E": Vector2(1.0, 0.5) = center of east edge
##   "W": Vector2(0.0, 0.5) = center of west edge
const BLOCK_TYPES: Dictionary = {
	"entrance": {
		"name": "Entrance",
		"color": Color(0.2, 0.7, 0.3),
		"description": "Dungeon entry point",
		"max_horizontal": 4,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 5, 15),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"room_small": {
		"name": "Small Room",
		"color": Color(0.5, 0.5, 0.6),
		"description": "1x1 combat/exploration room",
		"max_horizontal": 4,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 5, 15),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"room_large": {
		"name": "Large Room",
		"color": Color(0.6, 0.6, 0.7),
		"description": "2x2 large chamber",
		"max_horizontal": 4,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(30, 6, 30),
		"grid_size": Vector3i(2, 1, 2),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"corridor_straight": {
		"name": "Straight Corridor",
		"color": Color(0.4, 0.4, 0.4),
		"description": "Connecting hallway (N-S or E-W)",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 4, 15),
		"corridor_width": 5.0,
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0)},  # Base pattern, rotates with block
	},
	"corridor_corner": {
		"name": "Corner Corridor",
		"color": Color(0.45, 0.45, 0.45),
		"description": "90-degree turn",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 4, 15),
		"corridor_width": 5.0,
		"door_positions": {"N": Vector2(0.5, 0.0), "E": Vector2(1.0, 0.5)},  # Base pattern, rotates with block
	},
	"hallway_straight": {
		"name": "Narrow Hallway",
		"color": Color(0.35, 0.35, 0.35),
		"description": "Narrow connecting hallway (N-S or E-W, 5 units wide)",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 4, 15),
		"corridor_width": 5.0,
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0)},  # Base pattern, rotates with block
	},
	"t_junction": {
		"name": "T-Junction",
		"color": Color(0.5, 0.5, 0.5),
		"description": "3-way intersection",
		"max_horizontal": 3,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 4, 15),
		"corridor_width": 5.0,
		"door_positions": {"N": Vector2(0.5, 0.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},  # Base pattern
	},
	"crossroads": {
		"name": "Crossroads",
		"color": Color(0.55, 0.55, 0.55),
		"description": "4-way intersection",
		"max_horizontal": 4,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 4, 15),
		"corridor_width": 5.0,
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"ramp_up": {
		"name": "Ramp Up",
		"color": Color(0.2, 0.55, 0.75),
		"description": "Sloped passage going UP to the floor above. Place on the lower floor — upper exit is automatic.",
		"max_horizontal": 2,
		"can_connect_up": true,
		"can_connect_down": false,
		"default_size": Vector3(15, 8, 15),
		"is_ramp": true,
		"ramp_direction": "up",
		"spans_levels": true,
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0)},  # Entry/exit ends
	},
	"ramp_down": {
		"name": "Ramp Down",
		"color": Color(0.55, 0.3, 0.7),
		"description": "Sloped passage going DOWN to the floor below. Place on the upper floor — lower exit is automatic.",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": true,
		"default_size": Vector3(15, 8, 15),
		"is_ramp": true,
		"ramp_direction": "down",
		"spans_levels": true,
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0)},  # Entry/exit ends
	},
	"shaft": {
		"name": "Vertical Shaft",
		"color": Color(0.25, 0.5, 0.75),
		"description": "Vertical pit/climb",
		"max_horizontal": 0,
		"can_connect_up": true,
		"can_connect_down": true,
		"default_size": Vector3(10, 10, 10),
		"door_positions": {},  # No horizontal doors
	},
	"boss": {
		"name": "Boss Room",
		"color": Color(0.7, 0.2, 0.2),
		"description": "Boss encounter chamber",
		"max_horizontal": 4,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(25, 8, 25),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"treasure": {
		"name": "Treasure Room",
		"color": Color(0.8, 0.7, 0.2),
		"description": "Loot chamber",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(12, 5, 12),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"puzzle": {
		"name": "Puzzle Room",
		"color": Color(0.3, 0.6, 0.5),
		"description": "Puzzle/trap chamber",
		"max_horizontal": 2,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(15, 5, 15),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
	"secret": {
		"name": "Secret Room",
		"color": Color(0.5, 0.3, 0.6),
		"description": "Hidden chamber",
		"max_horizontal": 1,
		"can_connect_up": false,
		"can_connect_down": false,
		"default_size": Vector3(10, 4, 10),
		"door_positions": {"N": Vector2(0.5, 0.0), "S": Vector2(0.5, 1.0), "E": Vector2(1.0, 0.5), "W": Vector2(0.0, 0.5)},
	},
}

## Settlement type definitions for Town Editor
const SETTLEMENT_TYPES: Dictionary = {
	"hamlet": {"name": "Hamlet", "grid_size": Vector2i(64, 64), "max_districts": 1},
	"village": {"name": "Village", "grid_size": Vector2i(128, 128), "max_districts": 1},
	"town": {"name": "Town", "grid_size": Vector2i(256, 256), "max_districts": 1},
	"city": {"name": "City", "grid_size": Vector2i(512, 512), "max_districts": 1},
	"capital": {"name": "Capital", "grid_size": Vector2i(256, 256), "max_districts": 4},
}

## Dungeon theme definitions
const DUNGEON_THEMES: Dictionary = {
	"crypt": {
		"name": "Crypt",
		"floor_material": "res://assets/materials/dungeon/stonefloor_mat.tres",
		"wall_material": "res://assets/materials/dungeon/stonewall_mat.tres",
		"ambient_color": Color(0.15, 0.12, 0.18),
	},
	"cave": {
		"name": "Cave",
		"floor_material": "res://assets/materials/dungeon/stonefloor2_mat.tres",
		"wall_material": "res://assets/materials/dungeon/stonewall_mat.tres",
		"ambient_color": Color(0.1, 0.1, 0.12),
	},
	"sewer": {
		"name": "Sewer",
		"floor_material": "res://assets/materials/dungeon/stonefloor3_mat.tres",
		"wall_material": "res://assets/materials/dungeon/stonewall_mat.tres",
		"ambient_color": Color(0.12, 0.15, 0.1),
	},
	"castle": {
		"name": "Castle Dungeon",
		"floor_material": "res://assets/materials/dungeon/stonefloor_mat.tres",
		"wall_material": "res://assets/materials/dungeon/stonewall_mat.tres",
		"ambient_color": Color(0.18, 0.15, 0.12),
	},
	"dwarven": {
		"name": "Dwarven Hold",
		"floor_material": "res://assets/materials/dungeon/stonefloor_mat.tres",
		"wall_material": "res://assets/materials/dungeon/stonewall_mat.tres",
		"ambient_color": Color(0.2, 0.15, 0.1),
	},
}

## 3D grid position for dungeon blocks (Daggerfall-style)
class DungeonBlockData:
	var block_id: String = ""
	var block_type: String = "room_small"  # Key into BLOCK_TYPES
	var grid_position: Vector3i = Vector3i.ZERO  # X, Z = horizontal, Y = vertical level
	var rotation: int = 0  # 0, 90, 180, 270 degrees
	var connections: Dictionary = {
		"N": false, "S": false, "E": false, "W": false,
		"Up": false, "Down": false
	}
	var props: Array = []  # Props placed inside this block
	var enemy_spawns: Array = []  # Enemy spawn points
	var loot_tier: int = 1  # 1-5
	var custom_name: String = ""  # Optional display name

	func _init() -> void:
		block_id = "block_" + str(randi()) + "_" + str(Time.get_ticks_msec())

	## Get grid size of this block type (most are 1x1x1)
	func get_grid_size() -> Vector3i:
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		return type_info.get("grid_size", Vector3i(1, 1, 1))

	## Get world size of this block
	func get_world_size() -> Vector3:
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		return type_info.get("default_size", Vector3(15, 5, 15))

	## Get the color for this block type
	func get_color() -> Color:
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		return type_info.get("color", Color.GRAY)

	## Get display name
	func get_display_name() -> String:
		if custom_name != "":
			return custom_name
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		return type_info.get("name", block_type)

	## Check if this block can connect in a direction (rotation-aware)
	func can_connect_direction(direction: String) -> bool:
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		if direction == "Up":
			return type_info.get("can_connect_up", false)
		elif direction == "Down":
			return type_info.get("can_connect_down", false)
		else:
			# Get allowed directions for this block type and rotation
			var allowed: Array = get_allowed_horizontal_directions()
			return direction in allowed

	## Get allowed horizontal connection directions based on block type and rotation
	func get_allowed_horizontal_directions() -> Array:
		var type_info: Dictionary = BLOCK_TYPES.get(block_type, {})
		var max_h: int = type_info.get("max_horizontal", 4)

		# All 4 directions allowed
		if max_h >= 4:
			return ["N", "S", "E", "W"]

		# Define base patterns (at rotation 0)
		var base_pattern: Array = []
		match block_type:
			"corridor_straight":
				base_pattern = ["N", "S"]  # Straight N-S corridor
			"corridor_corner":
				base_pattern = ["N", "E"]  # Corner connecting N and E
			"t_junction":
				base_pattern = ["N", "E", "W"]  # T facing south (open N, E, W)
			"ramp_up", "ramp_down":
				base_pattern = ["N", "S"]  # Ramp entry from one end, exit to other level at other
			"shaft":
				base_pattern = []  # Shaft has no horizontal connections
			_:
				# Default: allow all horizontal if max_h > 0
				if max_h > 0:
					return ["N", "S", "E", "W"]
				return []

		# Rotate the pattern based on block rotation
		return _rotate_directions(base_pattern, rotation)

	## Rotate direction array by degrees (0, 90, 180, 270)
	func _rotate_directions(directions: Array, degrees: int) -> Array:
		var rotations: int = (degrees / 90) % 4
		var dir_order: Array[String] = ["N", "E", "S", "W"]

		var result: Array = []
		for dir: String in directions:
			var idx: int = dir_order.find(dir)
			if idx >= 0:
				var new_idx: int = (idx + rotations) % 4
				result.append(dir_order[new_idx])
		return result

	## Get active connection count
	func get_connection_count() -> int:
		var count: int = 0
		for dir: String in connections:
			if connections[dir]:
				count += 1
		return count

	## Convert to dictionary for serialization
	func to_dict() -> Dictionary:
		return {
			"block_id": block_id,
			"block_type": block_type,
			"grid_position": {
				"x": grid_position.x,
				"y": grid_position.y,
				"z": grid_position.z
			},
			"rotation": rotation,
			"connections": connections.duplicate(),
			"props": props.duplicate(true),
			"enemy_spawns": enemy_spawns.duplicate(true),
			"loot_tier": loot_tier,
			"custom_name": custom_name,
		}

	## Create from dictionary
	static func from_dict(data: Dictionary) -> DungeonBlockData:
		var block := DungeonBlockData.new()
		block.block_id = data.get("block_id", block.block_id)
		block.block_type = data.get("block_type", "room_small")
		var pos: Dictionary = data.get("grid_position", {})
		block.grid_position = Vector3i(
			pos.get("x", 0),
			pos.get("y", 0),
			pos.get("z", 0)
		)
		block.rotation = data.get("rotation", 0)
		block.connections = data.get("connections", block.connections)
		block.props = data.get("props", [])
		block.enemy_spawns = data.get("enemy_spawns", [])
		block.loot_tier = data.get("loot_tier", 1)
		block.custom_name = data.get("custom_name", "")
		return block


## Dungeon layout container (Daggerfall-style)
class DungeonLayoutData:
	var dungeon_id: String = ""
	var dungeon_name: String = "Unnamed Dungeon"
	var blocks: Dictionary = {}  # "x_y_z" string key -> DungeonBlockData
	var ramp_exits: Dictionary = {}  # "x_y_z" string key -> block_id of ramp that owns this exit
	var entrance_block_id: String = ""  # block_id of entrance
	var boss_block_id: String = ""  # block_id of boss room
	var theme: String = "crypt"  # Key into DUNGEON_THEMES
	var difficulty_tier: int = 1  # 1-5
	var poi_type: String = "dungeon"  # For World Forge identification
	var world_position: Variant = null  # Map cell coords when pinned to world
	var metadata: Dictionary = {}  # Extra data (POI info, etc.)

	const GRID_CELL_SIZE: float = 15.0  # World units per grid cell
	const LEVEL_HEIGHT: float = 8.0  # World units per vertical level

	func _init() -> void:
		dungeon_id = "dungeon_" + str(randi()) + "_" + str(Time.get_ticks_msec())

	## Get position key for a Vector3i
	static func get_position_key(pos: Vector3i) -> String:
		return "%d_%d_%d" % [pos.x, pos.y, pos.z]

	## Parse position key back to Vector3i
	static func parse_position_key(key: String) -> Vector3i:
		var parts: PackedStringArray = key.split("_")
		if parts.size() >= 3:
			return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))
		return Vector3i.ZERO

	## Add a block to the layout
	func add_block(block: DungeonBlockData) -> bool:
		var key: String = get_position_key(block.grid_position)
		if blocks.has(key):
			return false  # Position occupied
		blocks[key] = block

		# Track special blocks
		if block.block_type == "entrance" and entrance_block_id == "":
			entrance_block_id = block.block_id
		elif block.block_type == "boss" and boss_block_id == "":
			boss_block_id = block.block_id

		return true

	## Remove a block from the layout
	func remove_block(pos: Vector3i) -> DungeonBlockData:
		var key: String = get_position_key(pos)
		if not blocks.has(key):
			return null
		var block: DungeonBlockData = blocks[key]
		blocks.erase(key)

		# Clear special block references
		if block.block_id == entrance_block_id:
			entrance_block_id = ""
		elif block.block_id == boss_block_id:
			boss_block_id = ""

		return block

	## Get block at position
	func get_block(pos: Vector3i) -> DungeonBlockData:
		var key: String = get_position_key(pos)
		return blocks.get(key, null)

	## Check if position is occupied (by block or ramp exit)
	func is_occupied(pos: Vector3i) -> bool:
		var key: String = get_position_key(pos)
		return blocks.has(key) or ramp_exits.has(key)

	## Check if position is a ramp exit cell
	func is_ramp_exit(pos: Vector3i) -> bool:
		return ramp_exits.has(get_position_key(pos))

	## Get the ramp block that owns an exit cell
	func get_ramp_for_exit(pos: Vector3i) -> DungeonBlockData:
		var key: String = get_position_key(pos)
		if not ramp_exits.has(key):
			return null
		var ramp_id: String = ramp_exits[key]
		for block_key: String in blocks:
			var block: DungeonBlockData = blocks[block_key]
			if block.block_id == ramp_id:
				return block
		return null

	## Register a ramp's exit cell (called when placing a ramp)
	func register_ramp_exit(block: DungeonBlockData) -> void:
		var type_info: Dictionary = BLOCK_TYPES.get(block.block_type, {})
		if not type_info.get("is_ramp", false):
			return
		var ramp_dir: String = type_info.get("ramp_direction", "up")
		var offset: Vector3i = Vector3i(0, 1, 0) if ramp_dir == "up" else Vector3i(0, -1, 0)
		var exit_pos: Vector3i = block.grid_position + offset
		var exit_key: String = get_position_key(exit_pos)
		ramp_exits[exit_key] = block.block_id
		if ramp_dir == "up":
			block.connections["Up"] = true
		else:
			block.connections["Down"] = true

	## Clear a ramp's exit cell (called when deleting a ramp)
	func clear_ramp_exit(block: DungeonBlockData) -> void:
		var type_info: Dictionary = BLOCK_TYPES.get(block.block_type, {})
		if not type_info.get("is_ramp", false):
			return
		var ramp_dir: String = type_info.get("ramp_direction", "up")
		var offset: Vector3i = Vector3i(0, 1, 0) if ramp_dir == "up" else Vector3i(0, -1, 0)
		var exit_pos: Vector3i = block.grid_position + offset
		var exit_key: String = get_position_key(exit_pos)
		ramp_exits.erase(exit_key)

	## Get adjacent block in direction
	func get_adjacent_block(pos: Vector3i, direction: String) -> DungeonBlockData:
		var offset: Vector3i = _direction_to_offset(direction)
		return get_block(pos + offset)

	## Get direction offset
	static func _direction_to_offset(direction: String) -> Vector3i:
		match direction:
			"N": return Vector3i(0, 0, -1)
			"S": return Vector3i(0, 0, 1)
			"E": return Vector3i(1, 0, 0)
			"W": return Vector3i(-1, 0, 0)
			"Up": return Vector3i(0, 1, 0)
			"Down": return Vector3i(0, -1, 0)
		return Vector3i.ZERO

	## Get opposite direction
	static func get_opposite_direction(direction: String) -> String:
		match direction:
			"N": return "S"
			"S": return "N"
			"E": return "W"
			"W": return "E"
			"Up": return "Down"
			"Down": return "Up"
		return ""

	## Convert grid position to world position
	func grid_to_world(grid_pos: Vector3i) -> Vector3:
		return Vector3(
			grid_pos.x * GRID_CELL_SIZE,
			grid_pos.y * LEVEL_HEIGHT,
			grid_pos.z * GRID_CELL_SIZE
		)

	## Convert world position to grid position
	func world_to_grid(world_pos: Vector3) -> Vector3i:
		return Vector3i(
			int(round(world_pos.x / GRID_CELL_SIZE)),
			int(round(world_pos.y / LEVEL_HEIGHT)),
			int(round(world_pos.z / GRID_CELL_SIZE))
		)

	## Get all blocks on a specific level
	func get_blocks_on_level(level: int) -> Array[DungeonBlockData]:
		var result: Array[DungeonBlockData] = []
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			if block.grid_position.y == level:
				result.append(block)
		return result

	## Get min/max levels
	func get_level_range() -> Vector2i:
		if blocks.is_empty():
			return Vector2i(0, 0)
		var min_level: int = 999
		var max_level: int = -999
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			min_level = mini(min_level, block.grid_position.y)
			max_level = maxi(max_level, block.grid_position.y)
		return Vector2i(min_level, max_level)

	## Get bounds of all blocks
	func get_bounds() -> AABB:
		if blocks.is_empty():
			return AABB(Vector3.ZERO, Vector3.ZERO)
		var min_pos := Vector3(999, 999, 999)
		var max_pos := Vector3(-999, -999, -999)
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			var world_pos: Vector3 = grid_to_world(block.grid_position)
			var block_size: Vector3 = block.get_world_size()
			min_pos = min_pos.min(world_pos)
			max_pos = max_pos.max(world_pos + block_size)
		return AABB(min_pos, max_pos - min_pos)

	## Validate the dungeon layout
	func validate() -> Dictionary:
		var issues: Array[String] = []
		var warnings: Array[String] = []

		# Check for entrance
		if entrance_block_id == "":
			var has_entrance: bool = false
			for key: String in blocks:
				var block: DungeonBlockData = blocks[key]
				if block.block_type == "entrance":
					entrance_block_id = block.block_id
					has_entrance = true
					break
			if not has_entrance:
				issues.append("No entrance block placed")

		# Check for boss room (warning only)
		if boss_block_id == "" and blocks.size() > 3:
			var has_boss: bool = false
			for key: String in blocks:
				var block: DungeonBlockData = blocks[key]
				if block.block_type == "boss":
					boss_block_id = block.block_id
					has_boss = true
					break
			if not has_boss:
				warnings.append("No boss room placed")

		# Check connectivity
		if entrance_block_id != "":
			var reachable: Dictionary = {}
			_flood_fill_reachable(entrance_block_id, reachable)
			var unreachable_count: int = blocks.size() - reachable.size()
			if unreachable_count > 0:
				issues.append("%d block(s) not reachable from entrance" % unreachable_count)

		# Check for unconnected doorways
		var unconnected_count: int = 0
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			for dir: String in block.connections:
				if block.connections[dir]:
					var adjacent: DungeonBlockData = get_adjacent_block(block.grid_position, dir)
					if adjacent == null:
						unconnected_count += 1
					else:
						var opposite: String = get_opposite_direction(dir)
						if not adjacent.connections.get(opposite, false):
							unconnected_count += 1
		if unconnected_count > 0:
			warnings.append("%d unconnected doorway(s)" % unconnected_count)

		return {
			"valid": issues.is_empty(),
			"issues": issues,
			"warnings": warnings,
		}

	## Flood fill to find reachable blocks
	func _flood_fill_reachable(start_block_id: String, visited: Dictionary) -> void:
		var start_block: DungeonBlockData = null
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			if block.block_id == start_block_id:
				start_block = block
				break

		if start_block == null:
			return

		var queue: Array[DungeonBlockData] = [start_block]
		while not queue.is_empty():
			var current: DungeonBlockData = queue.pop_front()
			var current_key: String = get_position_key(current.grid_position)
			if visited.has(current_key):
				continue
			visited[current_key] = true

			# Check all connected directions
			for dir: String in current.connections:
				if current.connections[dir]:
					var adjacent: DungeonBlockData = get_adjacent_block(current.grid_position, dir)
					if adjacent != null:
						var opposite: String = get_opposite_direction(dir)
						if adjacent.connections.get(opposite, false):
							var adj_key: String = get_position_key(adjacent.grid_position)
							if not visited.has(adj_key):
								queue.append(adjacent)

	## Convert to dictionary for serialization
	func to_dict() -> Dictionary:
		var blocks_arr: Array = []
		for key: String in blocks:
			var block: DungeonBlockData = blocks[key]
			blocks_arr.append(block.to_dict())

		return {
			"version": 4,  # Updated format with ramps
			"dungeon_id": dungeon_id,
			"dungeon_name": dungeon_name,
			"blocks": blocks_arr,
			"ramp_exits": ramp_exits.duplicate(),
			"entrance_block_id": entrance_block_id,
			"boss_block_id": boss_block_id,
			"theme": theme,
			"difficulty_tier": difficulty_tier,
			"poi_type": poi_type,
			"world_position": world_position,
			"metadata": metadata,
		}

	## Convert to JSON string
	func to_json() -> String:
		return JSON.stringify(to_dict(), "  ")

	## Create from dictionary
	static func from_dict(data: Dictionary) -> DungeonLayoutData:
		var layout := DungeonLayoutData.new()
		layout.dungeon_id = data.get("dungeon_id", layout.dungeon_id)
		layout.dungeon_name = data.get("dungeon_name", "Unnamed Dungeon")
		layout.ramp_exits = data.get("ramp_exits", {})
		layout.entrance_block_id = data.get("entrance_block_id", "")
		layout.boss_block_id = data.get("boss_block_id", "")
		layout.theme = data.get("theme", "crypt")
		layout.difficulty_tier = data.get("difficulty_tier", 1)
		layout.poi_type = data.get("poi_type", "dungeon")
		layout.world_position = data.get("world_position", null)
		layout.metadata = data.get("metadata", {})

		var blocks_arr: Array = data.get("blocks", [])
		for block_data: Dictionary in blocks_arr:
			var block: DungeonBlockData = DungeonBlockData.from_dict(block_data)
			layout.blocks[get_position_key(block.grid_position)] = block

		return layout

	## Create from JSON string
	static func from_json(json_str: String) -> DungeonLayoutData:
		var json := JSON.new()
		if json.parse(json_str) != OK:
			push_error("Failed to parse dungeon layout JSON")
			return null
		return from_dict(json.data)


## =============================================================================
## LEGACY 2D DUNGEON ROOM SYSTEM (kept for backwards compatibility)
## =============================================================================

## Dungeon room properties (legacy 2D grid-based system)
class DungeonRoomData:
	var room_type: String = "combat"  # entrance, combat, treasure, boss, corridor, empty
	var grid_position: Vector2i = Vector2i.ZERO
	var width: int = 1  # Grid units
	var depth: int = 1  # Grid units
	var height: float = 5.0  # World units
	var doors: Dictionary = {"N": false, "S": false, "E": false, "W": false}
	var enemy_min: int = 0
	var enemy_max: int = 3
	var loot_tier: int = 1
	var has_rest_spot: bool = false
	var is_boss_room: bool = false

	func to_dict() -> Dictionary:
		return {
			"room_type": room_type,
			"grid_position": {"x": grid_position.x, "y": grid_position.y},
			"width": width,
			"depth": depth,
			"height": height,
			"doors": doors,
			"enemy_min": enemy_min,
			"enemy_max": enemy_max,
			"loot_tier": loot_tier,
			"has_rest_spot": has_rest_spot,
			"is_boss_room": is_boss_room
		}


## Level data container (for saving/loading)
class LevelData:
	var level_id: String = ""
	var level_name: String = ""
	var level_type: String = "town"  # town, dungeon
	var elements: Array[PlacedElement] = []
	var metadata: Dictionary = {}  # Extra level-specific data
	# Settlement-specific fields
	var settlement_type: String = "village"
	var grid_size: Vector2i = Vector2i(128, 128)
	var snap_size: float = 4.0
	var is_district: bool = false
	var district_name: String = ""
	var district_index: int = 0
	var master_layout_path: String = ""

	func to_dict() -> Dictionary:
		var elem_arr: Array = []
		for e: PlacedElement in elements:
			elem_arr.append(e.to_dict())
		return {
			"level_id": level_id,
			"level_name": level_name,
			"level_type": level_type,
			"elements": elem_arr,
			"metadata": metadata,
			"settlement_type": settlement_type,
			"grid_size": {"x": grid_size.x, "y": grid_size.y},
			"snap_size": snap_size,
			"is_district": is_district,
			"district_name": district_name,
			"district_index": district_index,
			"master_layout_path": master_layout_path
		}

	func to_json() -> String:
		return JSON.stringify(to_dict(), "  ")

	static func from_json(json_str: String) -> LevelData:
		var json := JSON.new()
		if json.parse(json_str) != OK:
			push_error("Failed to parse level JSON")
			return null
		return from_dict(json.data)

	static func from_dict(data: Dictionary) -> LevelData:
		var level := LevelData.new()
		level.level_id = data.get("level_id", "")
		level.level_name = data.get("level_name", "")
		level.level_type = data.get("level_type", "town")
		level.metadata = data.get("metadata", {})
		level.settlement_type = data.get("settlement_type", "village")
		var gs: Dictionary = data.get("grid_size", {})
		level.grid_size = Vector2i(gs.get("x", 128), gs.get("y", 128))
		level.snap_size = data.get("snap_size", 4.0)
		level.is_district = data.get("is_district", false)
		level.district_name = data.get("district_name", "")
		level.district_index = data.get("district_index", 0)
		level.master_layout_path = data.get("master_layout_path", "")

		var elem_arr: Array = data.get("elements", [])
		for e_data: Dictionary in elem_arr:
			level.elements.append(PlacedElement.from_dict(e_data))

		return level
