## town_spawner.gd - Generic spawner script for exported town scenes
## Reads child Marker3D nodes with metadata and spawns real game objects at runtime
## Attach to the root node of an exported town scene
class_name TownSpawner
extends Node3D

## Zone configuration - set these in the editor or via export
@export var zone_id: String = ""
@export var settlement_type: String = "village"
@export var region_id: String = "the_greenwood"

## Container references (populated on _ready)
var npc_spawns: Node3D
var prop_spawns: Node3D
var functional_spawns: Node3D
var buildings: Node3D

## Track spawned entities for cleanup
var spawned_npcs: Array[Node] = []
var spawned_props: Array[Node] = []
var spawned_functionals: Array[Node] = []


func _ready() -> void:
	# Find containers
	npc_spawns = get_node_or_null("NPCSpawns")
	prop_spawns = get_node_or_null("PropSpawns")
	functional_spawns = get_node_or_null("FunctionalSpawns")
	buildings = get_node_or_null("Buildings")

	# Spawn all entities
	_spawn_npcs()
	_spawn_props()
	_spawn_functionals()


## ============================================================================
## NPC SPAWNING
## ============================================================================

func _spawn_npcs() -> void:
	if not npc_spawns:
		return

	for child in npc_spawns.get_children():
		if child is Marker3D:
			var spawn_type: String = child.get_meta("spawn_type", "")
			if spawn_type == "npc":
				var npc := _spawn_npc_from_marker(child)
				if npc:
					spawned_npcs.append(npc)


func _spawn_npc_from_marker(marker: Marker3D) -> Node:
	# Check for npc_data_path first (Named NPCs from data/npcs/)
	var npc_data_path: String = marker.get_meta("npc_data_path", "")
	if not npc_data_path.is_empty():
		return _spawn_from_npc_data(marker, npc_data_path)

	var npc_type: String = marker.get_meta("npc_type", "civilian_male")
	var npc_name: String = marker.get_meta("npc_name", "")
	var shop_type: String = marker.get_meta("shop_type", "")
	var shop_tier: int = marker.get_meta("shop_tier", 2)
	var patrol_points: Array = marker.get_meta("patrol_points", [])

	var pos: Vector3 = marker.global_position
	var rot: Vector3 = marker.rotation_degrees
	var npc: Node = null

	# Get actor data from ZooRegistry for sprite info
	var actor_data: Dictionary = ZooRegistry.get_actor(npc_type)
	if actor_data.is_empty():
		# Try common mappings
		actor_data = _get_fallback_actor_data(npc_type)

	match npc_type:
		# Civilians
		"civilian_male":
			npc = CivilianNPC.spawn_man(self, pos, zone_id)
		"civilian_female":
			npc = CivilianNPC.spawn_woman(self, pos, zone_id)

		# Guards
		"guard":
			var patrol_array: Array[Vector3] = []
			for p in patrol_points:
				if p is Vector3:
					patrol_array.append(p)
			npc = GuardNPC.spawn_guard(self, pos, patrol_array, region_id)
		"guard_captain":
			var patrol_array: Array[Vector3] = []
			npc = GuardNPC.spawn_guard(self, pos, patrol_array, region_id)
			if npc and npc is GuardNPC:
				npc.npc_name = "Guard Captain"

		# Merchants
		"merchant_general":
			npc = _spawn_merchant(pos, npc_name, "general", shop_tier, actor_data)
		"merchant_weapons":
			npc = _spawn_merchant(pos, npc_name, "blacksmith", shop_tier, actor_data)
		"merchant_armor":
			npc = _spawn_merchant(pos, npc_name, "armor", shop_tier, actor_data)
		"merchant_magic":
			npc = _spawn_merchant(pos, npc_name, "magic", shop_tier, actor_data)

		# Innkeeper
		"innkeeper":
			npc = Innkeeper.spawn_innkeeper(self, pos, npc_name if npc_name else "Innkeeper")

		# Blacksmith NPC
		"blacksmith_npc":
			npc = _spawn_merchant(pos, npc_name, "blacksmith", shop_tier, actor_data)

		# Priest
		"priest":
			npc = _spawn_civilian_from_actor(pos, actor_data, zone_id)
			if npc and npc is CivilianNPC:
				npc.npc_name = npc_name if npc_name else "Priest"

		# Quest Giver
		"quest_giver":
			npc = QuestGiver.spawn_quest_giver(self, pos, npc_name if npc_name else "Quest Giver")

		# Noble
		"noble":
			if randf() < 0.5:
				npc = CivilianNPC.spawn_male_noble(self, pos, zone_id)
			else:
				npc = CivilianNPC.spawn_female_noble(self, pos, zone_id)
			if npc and npc is CivilianNPC:
				npc.npc_name = npc_name if npc_name else "Noble"

		# Beggar
		"beggar":
			npc = CivilianNPC.spawn_man(self, pos, zone_id)
			if npc and npc is CivilianNPC:
				npc.npc_name = "Beggar"

		# Default: try to spawn using actor data from zoo
		_:
			npc = _spawn_civilian_from_actor(pos, actor_data, zone_id)

	# Apply rotation if spawned
	if npc and npc is Node3D:
		npc.rotation_degrees = rot

	# Set custom name if provided
	if npc_name and npc:
		if npc.has_method("set") and "npc_name" in npc:
			npc.npc_name = npc_name

	return npc


## Spawn an NPC from an NPCData resource (Named NPCs from data/npcs/)
func _spawn_from_npc_data(marker: Marker3D, npc_data_path: String) -> Node:
	var npc_data: Resource = load(npc_data_path)
	if not npc_data:
		push_warning("[TownSpawner] Failed to load NPCData: %s" % npc_data_path)
		return null

	var pos: Vector3 = marker.global_position
	var rot: Vector3 = marker.rotation_degrees

	# Get quest IDs from marker metadata (placement-specific)
	var quest_ids: Array = marker.get_meta("quest_ids", [])

	# Get sprite info from NPCData
	var sprite_path: String = npc_data.sprite_path
	var h_frames: int = npc_data.sprite_h_frames
	var v_frames: int = npc_data.sprite_v_frames

	# Load sprite texture
	var sprite_texture: Texture2D = null
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		sprite_texture = load(sprite_path)

	var npc: Node = null
	var archetype: String = npc_data.archetype

	match archetype:
		"quest_giver":
			# Convert quest_ids Array to Array[String]
			var typed_quest_ids: Array[String] = []
			for qid in quest_ids:
				if qid is String:
					typed_quest_ids.append(qid)

			# Spawn QuestGiver with NPCData info
			npc = QuestGiver.spawn_quest_giver(
				self,
				pos,
				npc_data.display_name,
				npc_data.npc_id,
				sprite_texture,
				h_frames,
				v_frames,
				typed_quest_ids,
				false,  # not is_talk_target
				0.0384  # standard pixel size
			)

			# Set dialogue data if available
			if npc and npc is QuestGiver:
				if not npc_data.dialogue_data_path.is_empty():
					var dialogue_data: Resource = load(npc_data.dialogue_data_path)
					if dialogue_data:
						npc.dialogue_data = dialogue_data
				npc.region_id = region_id

		"merchant":
			var shop_type: String = npc_data.shop_type if npc_data.shop_type != "none" else "general"
			var shop_tier: int = marker.get_meta("shop_tier", 2)
			npc = _spawn_merchant(
				pos,
				npc_data.display_name,
				shop_type,
				shop_tier,
				{
					"sprite_path": sprite_path,
					"h_frames": h_frames,
					"v_frames": v_frames,
					"pixel_size": 0.0384,
					"id": npc_data.npc_id
				}
			)

		"guard":
			var patrol_array: Array[Vector3] = []
			var patrol_points: Array = marker.get_meta("patrol_points", [])
			for p in patrol_points:
				if p is Vector3:
					patrol_array.append(p)
			npc = GuardNPC.spawn_guard(self, pos, patrol_array, region_id)
			if npc and npc is GuardNPC:
				npc.npc_name = npc_data.display_name
				npc.npc_id = npc_data.npc_id

		"priest":
			npc = CivilianNPC.spawn_civilian(
				self,
				pos,
				sprite_path if not sprite_path.is_empty() else "res://assets/sprites/npcs/civilians/monk_tan.png",
				h_frames,
				v_frames,
				false,
				0.0384
			)
			if npc and npc is CivilianNPC:
				npc.npc_name = npc_data.display_name
				npc.npc_id = npc_data.npc_id

		"noble":
			if sprite_texture:
				npc = CivilianNPC.spawn_civilian(self, pos, sprite_path, h_frames, v_frames, false, 0.0384)
			else:
				npc = CivilianNPC.spawn_male_noble(self, pos, zone_id)
			if npc and npc is CivilianNPC:
				npc.npc_name = npc_data.display_name
				npc.npc_id = npc_data.npc_id

		"civilian", _:
			# Default civilian spawning
			if sprite_texture:
				npc = CivilianNPC.spawn_civilian(self, pos, sprite_path, h_frames, v_frames, false, 0.0384)
			else:
				npc = CivilianNPC.spawn_man(self, pos, zone_id)
			if npc and npc is CivilianNPC:
				npc.npc_name = npc_data.display_name
				npc.npc_id = npc_data.npc_id

	# Apply rotation
	if npc and npc is Node3D:
		npc.rotation_degrees = rot

	return npc


func _spawn_merchant(pos: Vector3, npc_name: String, shop_type: String, shop_tier: int, actor_data: Dictionary) -> Merchant:
	var tier: LootTables.LootTier = shop_tier as LootTables.LootTier

	var sprite_path: String = actor_data.get("sprite_path", "res://assets/sprites/npcs/merchants/merchant_civilian.png")
	var h_frames: int = actor_data.get("h_frames", 1)
	var v_frames: int = actor_data.get("v_frames", 1)
	var pixel_size: float = actor_data.get("pixel_size", ZooRegistry.PIXEL_SIZE_HUMANOID)

	var merchant: Merchant = Merchant.spawn_merchant(
		self,
		pos,
		npc_name if npc_name else "Merchant",
		tier,
		shop_type,
		sprite_path,
		h_frames,
		v_frames,
		pixel_size,
		false,
		actor_data.get("id", "")
	)

	if merchant:
		merchant.region_id = region_id

	return merchant


func _spawn_civilian_from_actor(pos: Vector3, actor_data: Dictionary, p_zone_id: String) -> CivilianNPC:
	if actor_data.is_empty():
		return CivilianNPC.spawn_man(self, pos, p_zone_id)

	var sprite_path: String = actor_data.get("sprite_path", "")
	var h_frames: int = actor_data.get("h_frames", 1)
	var v_frames: int = actor_data.get("v_frames", 1)
	var pixel_size: float = actor_data.get("pixel_size", ZooRegistry.PIXEL_SIZE_HUMANOID)

	if sprite_path.is_empty():
		return CivilianNPC.spawn_man(self, pos, p_zone_id)

	return CivilianNPC.spawn_civilian(self, pos, sprite_path, h_frames, v_frames, false, pixel_size)


func _get_fallback_actor_data(npc_type: String) -> Dictionary:
	# Map common NPC types to zoo registry IDs
	var mapping: Dictionary = {
		"civilian_male": "man_civilian",
		"civilian_female": "woman_civilian",
		"guard": "guard_civilian",
		"guard_captain": "guard2_civilian",
		"merchant_general": "merchant_civilian",
		"merchant_weapons": "blacksmith",
		"merchant_armor": "blacksmith",
		"merchant_magic": "magic_shop_worker",
		"innkeeper": "innkeeper_male",
		"blacksmith_npc": "blacksmith",
		"priest": "monk_tan",
		"noble": "male_noble",
		"beggar": "man_civilian",
	}

	var zoo_id: String = mapping.get(npc_type, "")
	if zoo_id.is_empty():
		return {}

	return ZooRegistry.get_actor(zoo_id)


## ============================================================================
## PROP SPAWNING
## ============================================================================

func _spawn_props() -> void:
	if not prop_spawns:
		return

	for child in prop_spawns.get_children():
		if child is Marker3D:
			var spawn_type: String = child.get_meta("spawn_type", "")
			if spawn_type == "prop":
				var prop := _spawn_prop_from_marker(child)
				if prop:
					spawned_props.append(prop)


func _spawn_prop_from_marker(marker: Marker3D) -> Node:
	var prop_type: String = marker.get_meta("prop_type", "")
	var prop_id: String = marker.get_meta("prop_id", "")

	var pos: Vector3 = marker.global_position
	var rot: Vector3 = marker.rotation_degrees
	var prop: Node = null

	match prop_type:
		# Interactable chests
		"chest_common":
			prop = _spawn_chest(pos, marker, LootTables.LootTier.COMMON)
		"chest_rare":
			prop = _spawn_chest(pos, marker, LootTables.LootTier.RARE)
		"chest_locked":
			prop = _spawn_locked_chest(pos, marker)

		# World items
		"world_item":
			var item_id: String = marker.get_meta("item_id", "health_potion")
			prop = WorldItem.spawn_item(self, pos, item_id)

		# Torches
		"torch_wall", "torch_standing":
			prop = TorchProp.spawn_torch(self, pos, prop_type == "torch_wall")

		# Static decorative props - keep as CSG in buildings, don't spawn separately
		"barrel", "crate", "crate_stack", "bench", "cart", "table", "chair", \
		"fence_wood", "fence_stone", "sign_post", "hay_bale", "woodpile", \
		"anvil", "grindstone", "hitching_post", "statue", "tree_oak", "tree_pine", "bush":
			# These are visual props - keep the marker's CSG children if any
			# Or spawn a TerrainProp if we have one
			prop = _spawn_decorative_prop(pos, rot, prop_type)

	if prop and prop is Node3D:
		prop.rotation_degrees = rot

	return prop


func _spawn_chest(pos: Vector3, marker: Marker3D, tier: LootTables.LootTier) -> Chest:
	var chest_id: String = marker.get_meta("chest_id", "")
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_persistent: bool = marker.get_meta("is_persistent", false)

	var chest := Chest.spawn_chest(
		self,
		pos,
		chest_name,
		false,  # Not locked
		0,
		is_persistent,
		chest_id
	)

	if chest:
		chest.setup_with_loot(tier)

	return chest


func _spawn_locked_chest(pos: Vector3, marker: Marker3D) -> Chest:
	var chest_id: String = marker.get_meta("chest_id", "")
	var chest_name: String = marker.get_meta("chest_name", "Locked Chest")
	var lock_dc: int = marker.get_meta("lock_dc", 15)
	var is_persistent: bool = marker.get_meta("is_persistent", false)
	var tier: int = marker.get_meta("loot_tier", 3)  # UNCOMMON default

	var chest := Chest.spawn_chest(
		self,
		pos,
		chest_name,
		true,  # Locked
		lock_dc,
		is_persistent,
		chest_id
	)

	if chest:
		chest.setup_with_loot(tier as LootTables.LootTier)

	return chest


func _spawn_decorative_prop(pos: Vector3, rot: Vector3, prop_type: String) -> Node3D:
	# For decorative props, check if TerrainProp has a spawn method for this type
	# Otherwise return null - the CSG geometry in Buildings handles visuals
	# This is a stub for future expansion
	return null


## ============================================================================
## FUNCTIONAL SPAWNING
## ============================================================================

func _spawn_functionals() -> void:
	if not functional_spawns:
		return

	for child in functional_spawns.get_children():
		if child is Marker3D:
			var spawn_type: String = child.get_meta("spawn_type", "")
			if spawn_type == "functional":
				var func_obj := _spawn_functional_from_marker(child)
				if func_obj:
					spawned_functionals.append(func_obj)


func _spawn_functional_from_marker(marker: Marker3D) -> Node:
	var func_type: String = marker.get_meta("func_type", "")

	var pos: Vector3 = marker.global_position
	var rot: Vector3 = marker.rotation_degrees
	var func_obj: Node = null

	match func_type:
		# Spawn point - just a marker, nothing to spawn
		"spawn_point":
			# Register this as a spawn point
			marker.add_to_group("spawn_points")
			return null

		# Fast travel shrine
		"fast_travel_shrine":
			var shrine_name: String = marker.get_meta("shrine_name", "Shrine of Passage")
			var shrine_id: String = marker.get_meta("shrine_id", zone_id + "_shrine")
			func_obj = FastTravelShrine.spawn_shrine(self, pos, shrine_name, shrine_id)

		# Zone exit door
		"door_zone":
			var target: String = marker.get_meta("target_scene", "")
			var spawn_id: String = marker.get_meta("spawn_id", "default")
			var door_name: String = marker.get_meta("door_name", "Exit")
			var show_frame: bool = marker.get_meta("show_frame", true)
			func_obj = ZoneDoor.spawn_door(self, pos, target, spawn_id, door_name, show_frame)

		# Interior door (lockable)
		"door_interior":
			func_obj = LockableDoor.new()
			func_obj.position = pos
			func_obj.is_locked = marker.get_meta("is_locked", false)
			func_obj.lock_difficulty = marker.get_meta("lock_dc", 10)
			func_obj.door_name = marker.get_meta("door_name", "Door")
			add_child(func_obj)

		# Rest area / bed
		"rest_area":
			func_obj = RestSpot.spawn_rest_spot(self, pos, marker.get_meta("bed_name", "Bed"))

		# Bounty board
		"bounty_board":
			func_obj = BountyBoard.spawn_bounty_board(self, pos, marker.get_meta("board_name", "Bounty Board"))
			if func_obj:
				func_obj.region_id = region_id

		# Crafting stations
		"crafting_station":
			func_obj = RepairStation.spawn_station(self, pos)
		"alchemy_table":
			func_obj = AlchemyStation.spawn_alchemy_station(self, pos)

		# Chests (functionals in town editor)
		"chest_common":
			func_obj = _spawn_chest_functional(pos, marker, LootTables.LootTier.COMMON)
		"chest_rare":
			func_obj = _spawn_chest_functional(pos, marker, LootTables.LootTier.RARE)
		"chest_locked":
			func_obj = _spawn_locked_chest_functional(pos, marker)

	if func_obj and func_obj is Node3D:
		func_obj.rotation_degrees = rot

	return func_obj


## Spawn chest from functional marker (common/rare)
func _spawn_chest_functional(pos: Vector3, marker: Marker3D, tier: LootTables.LootTier) -> Chest:
	var chest_id: String = marker.get_meta("chest_id", "")
	var chest_name: String = marker.get_meta("chest_name", "Chest")
	var is_persistent: bool = marker.get_meta("is_persistent", false)

	var chest := Chest.spawn_chest(
		self,
		pos,
		chest_name,
		false,  # Not locked
		0,
		is_persistent,
		chest_id
	)

	if chest:
		chest.setup_with_loot(tier)

	return chest


## Spawn locked chest from functional marker
func _spawn_locked_chest_functional(pos: Vector3, marker: Marker3D) -> Chest:
	var chest_id: String = marker.get_meta("chest_id", "")
	var chest_name: String = marker.get_meta("chest_name", "Locked Chest")
	var lock_dc: int = marker.get_meta("lock_dc", 15)
	var is_persistent: bool = marker.get_meta("is_persistent", false)
	var tier: int = marker.get_meta("loot_tier", 3)  # UNCOMMON default

	var chest := Chest.spawn_chest(
		self,
		pos,
		chest_name,
		true,  # Locked
		lock_dc,
		is_persistent,
		chest_id
	)

	if chest:
		chest.setup_with_loot(tier as LootTables.LootTier)

	return chest


## ============================================================================
## CLEANUP
## ============================================================================

func _exit_tree() -> void:
	# Cleanup spawned entities
	for npc in spawned_npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	for prop in spawned_props:
		if is_instance_valid(prop):
			prop.queue_free()
	for func_obj in spawned_functionals:
		if is_instance_valid(func_obj):
			func_obj.queue_free()


## ============================================================================
## HELPER - Get spawn point by ID
## ============================================================================

func get_spawn_point(spawn_id: String) -> Vector3:
	if not functional_spawns:
		return Vector3.ZERO

	for child in functional_spawns.get_children():
		if child is Marker3D:
			var marker_id: String = child.get_meta("spawn_id", "")
			if marker_id == spawn_id:
				return child.global_position

	# Fallback - return first spawn point
	for child in functional_spawns.get_children():
		if child is Marker3D:
			var func_type: String = child.get_meta("func_type", "")
			if func_type == "spawn_point":
				return child.global_position

	return Vector3.ZERO
