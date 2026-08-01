## room_small_secret.gd - Secret room with false walls as doorways
## All 4 walls are solid - secret walls spawn at doorway positions
## 75% chance: 1 legendary chest, 25% chance: 3 uncommon chests
extends Node3D

const SecretWallScript = preload("res://scripts/world/secret_wall.gd")
const ChestScript = preload("res://scripts/world/chest.gd")

## Dungeon textures - same as room walls
const WALL_TEXTURE_PATH := "res://assets/textures/environment/dungeon/stonewall.png"
const UV_SCALE := Vector3(2, 1, 2)

## Loot chances
const LEGENDARY_CHANCE := 0.75  ## 75% for single legendary chest

## Node references
var secret_wall_positions: Node3D
var chest_positions: Node3D

## Spawned objects
var secret_walls: Array[Node] = []
var chests: Array[Node] = []

## Loot mode
var use_legendary_chest: bool = true


func _ready() -> void:
	# Get marker containers
	secret_wall_positions = get_node_or_null("SecretWallPositions")
	chest_positions = get_node_or_null("ChestPositions")

	# Determine loot type (75% legendary, 25% triple uncommon)
	use_legendary_chest = randf() < LEGENDARY_CHANCE

	# Spawn secret walls at all doorways
	_spawn_secret_walls()

	# Spawn chests based on loot roll
	_spawn_chests()

	if use_legendary_chest:
		print("[RoomSmallSecret] Secret room initialized (LEGENDARY chest)")
	else:
		print("[RoomSmallSecret] Secret room initialized (3x UNCOMMON chests)")


func _spawn_secret_walls() -> void:
	if not secret_wall_positions:
		return

	var wall_texture: Texture2D = load(WALL_TEXTURE_PATH)
	if not wall_texture:
		push_error("[RoomSmallSecret] Failed to load wall texture: %s" % WALL_TEXTURE_PATH)
		return

	for marker in secret_wall_positions.get_children():
		if not marker is Marker3D:
			continue

		var wall_name: String = marker.get_meta("wall_name", "Hidden Passage")
		var detection_dc: int = marker.get_meta("detection_dc", 18)
		var wall_width: float = marker.get_meta("wall_width", 4.0)
		var wall_height: float = marker.get_meta("wall_height", 4.0)
		var wall_depth: float = marker.get_meta("wall_depth", 0.5)
		var rotation_y: float = marker.get_meta("rotation_y", 0.0)

		var wall_size := Vector3(wall_width, wall_height, wall_depth)

		var wall = SecretWallScript.spawn_secret_wall(
			self,
			marker.global_position,
			wall_name,
			detection_dc,
			wall_size,
			rotation_y,
			wall_texture,
			UV_SCALE
		)

		if wall:
			wall.wall_revealed.connect(_on_secret_wall_revealed)
			secret_walls.append(wall)
			print("[RoomSmallSecret] Spawned secret wall: %s (DC %d)" % [wall_name, detection_dc])


func _spawn_chests() -> void:
	if not chest_positions:
		return

	if use_legendary_chest:
		# Spawn single legendary chest at center
		_spawn_chest_by_id("CenterChest")
	else:
		# Spawn 3 uncommon chests at corners
		_spawn_chest_by_id("CornerChest1")
		_spawn_chest_by_id("CornerChest2")
		_spawn_chest_by_id("CornerChest3")


func _spawn_chest_by_id(marker_name: String) -> void:
	var marker: Marker3D = chest_positions.get_node_or_null(marker_name) as Marker3D
	if not marker:
		return

	var chest_id: String = marker.get_meta("chest_id", "")
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_locked: bool = marker.get_meta("is_locked", false)
	var lock_difficulty: int = marker.get_meta("lock_difficulty", 10)
	var loot_tier_str: String = marker.get_meta("loot_tier", "common")

	var chest = ChestScript.spawn_chest(
		self,
		marker.global_position,
		chest_name,
		is_locked,
		lock_difficulty,
		false,  # not persistent
		chest_id
	)

	if chest:
		var tier: int = _parse_loot_tier(loot_tier_str)
		chest.setup_with_loot(tier)
		chest.rotation = marker.rotation
		chests.append(chest)
		print("[RoomSmallSecret] Spawned chest: %s (locked=%s, tier=%s)" % [chest_name, is_locked, loot_tier_str])


func _parse_loot_tier(tier_str: String) -> int:
	match tier_str.to_lower():
		"junk":
			return 0
		"common":
			return 1
		"uncommon":
			return 2
		"rare":
			return 3
		"epic":
			return 4
		"legendary":
			return 5
		_:
			return 1


func _on_secret_wall_revealed(wall: Node) -> void:
	print("[RoomSmallSecret] Secret wall revealed: %s" % wall.wall_name)


func _exit_tree() -> void:
	for wall in secret_walls:
		if is_instance_valid(wall):
			if wall.wall_revealed.is_connected(_on_secret_wall_revealed):
				wall.wall_revealed.disconnect(_on_secret_wall_revealed)
