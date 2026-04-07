## custom_cave_test.gd - Test scene for custom hand-crafted cave
## Integrates with CaveManager for area tracking, spawning, and minimap
extends Node3D

const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const EXTERIOR_SCENE := "res://scenes/dev/cave_door_test.tscn"

## Cave configuration
@export var cave_id: String = "custom_cave_1"
@export var cave_faction: String = "natural"  ## natural, goblin, undead, bandit, beast
@export var cave_danger_level: int = 3  ## 1-10 scale
@export var auto_spawn_content: bool = true  ## If true, spawn enemies/chests/props via CaveSpawner

var _hud: CanvasLayer
var _player_spawned: bool = false
var _content_spawned: bool = false


func _ready() -> void:
	_initialize_game_state()
	_setup_hud()
	_setup_environment()
	_generate_cave_collision()

	# Register with CaveManager BEFORE spawning player
	_register_with_cave_manager()

	_spawn_player()
	_setup_exit_door()

	# Setup navigation markers from Blender model
	_setup_navigation_markers()

	# Spawn content via CaveManager
	if auto_spawn_content:
		call_deferred("_spawn_cave_content")

	print("[CustomCave] Cave loaded successfully")


func _exit_tree() -> void:
	# Properly exit cave when scene is destroyed
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if cave_mgr and cave_mgr.has_method("exit_cave"):
		cave_mgr.exit_cave()


## Register this cave with CaveManager
func _register_with_cave_manager() -> void:
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if not cave_mgr:
		push_warning("[CustomCave] CaveManager autoload not available")
		return

	# Find the cave model to register
	var cave_model: Node3D = get_node_or_null("CaveModel")
	var register_root: Node3D = cave_model if cave_model else self

	if cave_mgr.has_method("register_cave"):
		cave_mgr.register_cave(register_root, cave_id, cave_faction, cave_danger_level)
	if cave_mgr.has_method("enter_cave"):
		cave_mgr.enter_cave(cave_id)

	# Connect to signals (use safe access)
	if cave_mgr.has_signal("area_changed") and not cave_mgr.area_changed.is_connected(_on_area_changed):
		cave_mgr.area_changed.connect(_on_area_changed)
	if cave_mgr.has_signal("area_discovered") and not cave_mgr.area_discovered.is_connected(_on_area_discovered):
		cave_mgr.area_discovered.connect(_on_area_discovered)

	print("[CustomCave] Registered with CaveManager: %s" % cave_id)


func _on_area_changed(old_area: String, new_area: String) -> void:
	if not new_area.is_empty():
		print("[CustomCave] Player moved to area: %s" % new_area)

		# Spawn content for newly entered areas if not already done
		if auto_spawn_content and not _content_spawned:
			_spawn_area_content(new_area)


func _on_area_discovered(area_id: String) -> void:
	print("[CustomCave] Discovered area: %s" % area_id)

	# Notify player
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		var cave_mgr: Node = get_node_or_null("/root/CaveManager")
		if cave_mgr and "area_data" in cave_mgr:
			var area_data: Dictionary = cave_mgr.area_data
			var area: RefCounted = area_data.get(area_id)
			if area and "area_type" in area:
				var type_name: String = _get_area_type_name(area.area_type)
				hud.show_notification("Discovered: %s" % type_name)


## CaveAreaType enum values (mirror of CaveManager.CaveAreaType)
const CAVE_AREA_TYPE_ENTRANCE: int = 0
const CAVE_AREA_TYPE_PASSAGE: int = 1
const CAVE_AREA_TYPE_JUNCTION: int = 2
const CAVE_AREA_TYPE_CHAMBER: int = 3
const CAVE_AREA_TYPE_TREASURE_ROOM: int = 4
const CAVE_AREA_TYPE_EXIT: int = 5


func _get_area_type_name(area_type: int) -> String:
	match area_type:
		CAVE_AREA_TYPE_ENTRANCE: return "Entrance"
		CAVE_AREA_TYPE_PASSAGE: return "Passage"
		CAVE_AREA_TYPE_JUNCTION: return "Junction"
		CAVE_AREA_TYPE_CHAMBER: return "Chamber"
		CAVE_AREA_TYPE_TREASURE_ROOM: return "Treasure Room"
		CAVE_AREA_TYPE_EXIT: return "Exit"
	return "Area"


## Spawn cave content using CaveSpawner
func _spawn_cave_content() -> void:
	if _content_spawned:
		return

	_content_spawned = true

	# First, try spawning at Blender markers
	var spawned_from_markers: bool = _spawn_content_from_markers()

	# If no markers found, spawn based on area definitions
	if not spawned_from_markers:
		_spawn_content_from_areas()

	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	var enemy_count: int = 0
	if cave_mgr and cave_mgr.has_method("get_enemy_count"):
		enemy_count = cave_mgr.get_enemy_count()
	print("[CustomCave] Content spawning complete. Enemies: %d" % enemy_count)


## Spawn content from Blender markers (EnemySpawn_*, ChestPos_*, etc.)
func _spawn_content_from_markers() -> bool:
	var cave_model: Node3D = get_node_or_null("CaveModel")
	if not cave_model:
		return false

	var had_markers: bool = false

	# Spawn enemies at markers
	var enemies: Array = CaveSpawner.spawn_enemies_at_markers(self, cave_faction, cave_danger_level)
	if not enemies.is_empty():
		had_markers = true
		print("[CustomCave] Spawned %d enemies from markers" % enemies.size())

	# Spawn chests at markers
	var chests: Array = CaveSpawner.spawn_chests_at_markers(self)
	if not chests.is_empty():
		had_markers = true
		print("[CustomCave] Spawned %d chests from markers" % chests.size())

	return had_markers


## Spawn content based on CaveManager area definitions
func _spawn_content_from_areas() -> void:
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if not cave_mgr or not "area_data" in cave_mgr:
		print("[CustomCave] No areas defined, skipping area-based spawning")
		return

	var area_data: Dictionary = cave_mgr.area_data
	if area_data.is_empty():
		print("[CustomCave] No areas defined, skipping area-based spawning")
		return

	for area_id: String in area_data:
		_spawn_area_content(area_id)


## Spawn content for a specific area
func _spawn_area_content(area_id: String) -> void:
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if not cave_mgr or not "area_data" in cave_mgr:
		return

	var area_data: Dictionary = cave_mgr.area_data
	var area: RefCounted = area_data.get(area_id)
	if not area:
		return

	# Skip if already spawned in this area (check for existing enemies)
	if cave_mgr.has_method("get_area_enemies"):
		var existing: Array = cave_mgr.get_area_enemies(area_id)
		if not existing.is_empty():
			return

	var result: Dictionary = CaveSpawner.spawn_area_content(
		area,
		self,
		cave_faction,
		cave_danger_level
	)

	var enemies: Array = result.get("enemies", []) as Array
	var chests: Array = result.get("chests", []) as Array
	var props: Array = result.get("props", []) as Array

	if not enemies.is_empty() or not chests.is_empty() or not props.is_empty():
		print("[CustomCave] Area %s: %d enemies, %d chests, %d props" % [
			area_id, enemies.size(), chests.size(), props.size()
		])


## Setup navigation markers from Blender model
func _setup_navigation_markers() -> void:
	var cave_model: Node3D = get_node_or_null("CaveModel")
	if not cave_model:
		return

	# Find and convert NavMarker_* nodes to CaveNavigationMarker
	var markers: Array[CaveNavigationMarker] = CaveNavigationMarker.find_and_convert_markers(cave_model)

	if not markers.is_empty():
		print("[CustomCave] Created %d navigation markers" % markers.size())


func _spawn_player() -> void:
	var spawn_pos: Vector3 = Vector3(0, 5, 0)  # Fallback

	# First, try to find spawn point from the imported GLB model
	var cave_model: Node3D = get_node_or_null("CaveModel")
	if cave_model:
		var model_spawn: Node3D = _find_node_recursive(cave_model, "SpawnPoint_Entrance")
		if model_spawn:
			spawn_pos = model_spawn.global_position
			print("[CustomCave] Found spawn point in model at %s" % str(spawn_pos))

	# Fallback to scene markers if model spawn not found
	if spawn_pos == Vector3(0, 5, 0):
		var spawn_marker: Node3D = get_node_or_null("SpawnPoints/EntranceSpawn")
		if spawn_marker:
			spawn_pos = spawn_marker.global_position

	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player:
		player.global_position = spawn_pos
		print("[CustomCave] Teleported player to %s" % str(spawn_pos))
	else:
		var player_scene: PackedScene = load("res://scenes/player/player.tscn")
		if player_scene:
			var new_player: Node3D = player_scene.instantiate()
			add_child(new_player)
			new_player.global_position = spawn_pos
			print("[CustomCave] Spawned player at %s" % str(spawn_pos))

	_player_spawned = true


## Recursively search for a node by name in the imported model
func _find_node_recursive(parent: Node, node_name: String) -> Node3D:
	for child in parent.get_children():
		if child.name == node_name or child.name.begins_with(node_name):
			return child as Node3D
		var found: Node3D = _find_node_recursive(child, node_name)
		if found:
			return found
	return null


## Generate collision for all meshes in the cave model
func _generate_cave_collision() -> void:
	var cave_model: Node3D = get_node_or_null("CaveModel")
	if not cave_model:
		push_error("[CustomCave] No CaveModel found for collision generation")
		return

	# Debug: print the node hierarchy to understand structure
	print("[CustomCave] Analyzing model structure...")
	_debug_print_hierarchy(cave_model, 0)

	var collision_count: int = _add_collision_recursive(cave_model)
	print("[CustomCave] Generated collision for %d meshes" % collision_count)


## Debug print the node hierarchy
func _debug_print_hierarchy(node: Node, depth: int) -> void:
	var indent: String = "  ".repeat(depth)
	var class_name_str: String = node.get_class()
	print("%s- %s (%s)" % [indent, node.name, class_name_str])

	# Only go 4 levels deep to avoid spam
	if depth < 4:
		for child in node.get_children():
			_debug_print_hierarchy(child, depth + 1)


## Recursively add collision to all mesh nodes
func _add_collision_recursive(parent: Node) -> int:
	var count: int = 0

	for child in parent.get_children():
		# Check if this node has a mesh property (works for MeshInstance3D and ImporterMeshInstance3D)
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child as MeshInstance3D

			# Skip if already has collision child
			var has_collision: bool = false
			for subchild in mesh_instance.get_children():
				if subchild is StaticBody3D:
					has_collision = true
					break

			if not has_collision and mesh_instance.mesh:
				mesh_instance.create_trimesh_collision()
				count += 1
				print("[CustomCave] Added collision to: %s" % mesh_instance.name)

		# Recurse into children
		count += _add_collision_recursive(child)

	return count


func _setup_exit_door() -> void:
	var door_marker: Marker3D = get_node_or_null("DoorPositions/ExitDoor") as Marker3D
	if not door_marker:
		push_error("[CustomCave] No exit door marker found")
		return

	var target: String = door_marker.get_meta("target_scene", EXTERIOR_SCENE)
	var spawn_id: String = door_marker.get_meta("spawn_id", "from_cave")
	var label: String = door_marker.get_meta("door_label", "Exit Cave")
	var show_frame: bool = door_marker.get_meta("show_frame", false)

	var door: ZoneDoor = ZoneDoor.spawn_door(
		self,
		door_marker.global_position,
		target,
		spawn_id,
		label,
		show_frame
	)

	if door:
		door.rotation = door_marker.rotation
		print("[CustomCave] Exit door placed -> %s" % target)
	else:
		push_error("[CustomCave] Failed to spawn exit door")


func _setup_environment() -> void:
	# Create cave environment if not present
	var world_env: WorldEnvironment = get_node_or_null("Lighting/WorldEnvironment") as WorldEnvironment
	if world_env and not world_env.environment:
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.1, 0.1, 0.12)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.6, 0.55, 0.5)
		env.ambient_light_energy = 1.5

		# Disable fog for now so we can see
		env.volumetric_fog_enabled = false

		world_env.environment = env
		print("[CustomCave] Created cave environment")

	# Also boost the directional light
	var cave_light: DirectionalLight3D = get_node_or_null("Lighting/CaveLight") as DirectionalLight3D
	if cave_light:
		cave_light.light_energy = 1.5


func _initialize_game_state() -> void:
	if GameManager.player_data and GameManager.player_data.character_name != "":
		return

	print("[CustomCave] Initializing game state...")
	GameManager.reset_for_new_game()
	InventoryManager.clear_inventory_state()
	QuestManager.reset_for_new_game()

	var char_data := CharacterData.new()
	char_data.race = Enums.Race.HUMAN
	char_data.character_name = "Cave Explorer"
	char_data.initialize_race_bonuses()
	char_data.recalculate_derived_stats()
	char_data.current_hp = char_data.max_hp
	char_data.current_stamina = char_data.max_stamina
	char_data.current_mana = char_data.max_mana
	GameManager.player_data = char_data

	InventoryManager.add_item("iron_sword", 1)
	InventoryManager.add_item("leather_armor", 1)
	InventoryManager.add_item("health_potion", 5)
	InventoryManager.add_item("torch", 10)
	InventoryManager.add_gold(500)


func _setup_hud() -> void:
	var existing_hud := get_tree().get_first_node_in_group("hud")
	if existing_hud:
		return

	var hud_scene: PackedScene = load(HUD_SCENE_PATH)
	if hud_scene:
		_hud = hud_scene.instantiate()
		add_child(_hud)
