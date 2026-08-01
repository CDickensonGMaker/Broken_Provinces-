extends Node3D
## Auto-running CSG Export Tool - Exports all Kazan-Dun geometry then quits

const KAZAN_DUN_ROOMS: Array[String] = [
	"res://scenes/rooms/kazan_dun/kd_armory.tscn",
	"res://scenes/rooms/kazan_dun/kd_barricade.tscn",
	"res://scenes/rooms/kazan_dun/kd_bathhouse.tscn",
	"res://scenes/rooms/kazan_dun/kd_bridge_connector.tscn",
	"res://scenes/rooms/kazan_dun/kd_bridge_gatehouse.tscn",
	"res://scenes/rooms/kazan_dun/kd_bridge_span.tscn",
	"res://scenes/rooms/kazan_dun/kd_command_center.tscn",
	"res://scenes/rooms/kazan_dun/kd_common_quarters.tscn",
	"res://scenes/rooms/kazan_dun/kd_corridor_corner.tscn",
	"res://scenes/rooms/kazan_dun/kd_corridor_straight.tscn",
	"res://scenes/rooms/kazan_dun/kd_council_chamber.tscn",
	"res://scenes/rooms/kazan_dun/kd_feast_hall.tscn",
	"res://scenes/rooms/kazan_dun/kd_forge_main.tscn",
	"res://scenes/rooms/kazan_dun/kd_goblin_camp.tscn",
	"res://scenes/rooms/kazan_dun/kd_great_hall_corridor.tscn",
	"res://scenes/rooms/kazan_dun/kd_kitchen.tscn",
	"res://scenes/rooms/kazan_dun/kd_mine_shaft.tscn",
	"res://scenes/rooms/kazan_dun/kd_noble_quarters.tscn",
	"res://scenes/rooms/kazan_dun/kd_ritual_chamber.tscn",
	"res://scenes/rooms/kazan_dun/kd_rune_ward_hall.tscn",
	"res://scenes/rooms/kazan_dun/kd_stairwell_down.tscn",
	"res://scenes/rooms/kazan_dun/kd_storage_cellar.tscn",
	"res://scenes/rooms/kazan_dun/kd_throne_room.tscn",
	"res://scenes/rooms/kazan_dun/kd_treasury.tscn",
]

const KAZAN_DUN_LEVELS: Array[String] = [
	"res://scenes/levels/kazan_dun.tscn",
	"res://scenes/levels/kazan_dun_back_entrance.tscn",
	"res://scenes/levels/kazan_dun_entrance.tscn",
	"res://scenes/levels/kazan_dun_exit.tscn",
	"res://scenes/levels/kazan_dun_level_1.tscn",
	"res://scenes/levels/kazan_dun_level_2.tscn",
	"res://scenes/levels/kazan_dun_level_3.tscn",
	"res://scenes/levels/kazan_dun_level_4.tscn",
	"res://scenes/levels/kazan_dun_level_5.tscn",
	"res://scenes/levels/kazan_dun_road_leading_up.tscn",
	"res://scenes/levels/kazan_dun_south_road.tscn",
]

var _all_scenes: Array[String] = []
var _current_index := 0
var _exported_count := 0
var _failed_count := 0


func _ready() -> void:
	print("=== Kazan-Dun Auto Export Tool ===")
	_ensure_directories()

	_all_scenes.append_array(KAZAN_DUN_ROOMS)
	_all_scenes.append_array(KAZAN_DUN_LEVELS)

	print("Exporting %d scenes..." % _all_scenes.size())
	print("")

	# Start export on next frame
	call_deferred("_process_next")


func _ensure_directories() -> void:
	var dir := DirAccess.open("res://")
	if dir:
		if not dir.dir_exists("exports"):
			dir.make_dir("exports")
		dir = DirAccess.open("res://exports")
		if dir:
			if not dir.dir_exists("kazan_dun"):
				dir.make_dir("kazan_dun")
			dir = DirAccess.open("res://exports/kazan_dun")
			if dir:
				if not dir.dir_exists("rooms"):
					dir.make_dir("rooms")
				if not dir.dir_exists("levels"):
					dir.make_dir("levels")


func _process_next() -> void:
	if _current_index >= _all_scenes.size():
		print("")
		print("=== Export Complete ===")
		print("Exported: %d" % _exported_count)
		print("Failed: %d" % _failed_count)
		print("Output: res://exports/kazan_dun/")

		# Quit after a short delay
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()
		return

	var scene_path: String = _all_scenes[_current_index]
	var scene_name := scene_path.get_file().get_basename()

	print("[%d/%d] %s" % [_current_index + 1, _all_scenes.size(), scene_name])

	if _export_scene(scene_path):
		_exported_count += 1
	else:
		_failed_count += 1

	_current_index += 1

	# Process next frame
	call_deferred("_process_next")


func _export_scene(scene_path: String) -> bool:
	var scene_name := scene_path.get_file().get_basename()
	var subfolder := "rooms" if "rooms" in scene_path else "levels"

	# Load and instantiate
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_error("  Failed to load")
		return false

	var scene_instance: Node = packed_scene.instantiate()
	if not scene_instance:
		push_error("  Failed to instantiate")
		return false

	add_child(scene_instance)

	# Create export container
	var export_root := Node3D.new()
	export_root.name = scene_name

	# Bake CSG and collect meshes
	_process_node_for_export(scene_instance, export_root, Transform3D.IDENTITY)

	var success := false

	if export_root.get_child_count() > 0:
		var export_file := "res://exports/kazan_dun/%s/%s.glb" % [subfolder, scene_name]

		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()

		add_child(export_root)

		var err := gltf_doc.append_from_scene(export_root, gltf_state)
		if err == OK:
			err = gltf_doc.write_to_filesystem(gltf_state, export_file)
			if err == OK:
				print("  -> %s" % export_file)
				success = true
			else:
				push_error("  Write failed: error %d" % err)
		else:
			push_error("  GLTF failed: error %d" % err)

		export_root.queue_free()
	else:
		print("  -> No meshes found")
		success = true  # Not a failure, just empty

	scene_instance.queue_free()
	return success


func _process_node_for_export(node: Node, export_root: Node3D, parent_transform: Transform3D) -> void:
	var current_transform := parent_transform

	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	# Handle CSG nodes
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		if not (node.get_parent() is CSGShape3D):
			var meshes := csg.get_meshes()
			if meshes.size() >= 2 and meshes[1] is Mesh:
				var mesh: Mesh = meshes[1]
				var mesh_instance := MeshInstance3D.new()
				mesh_instance.name = csg.name
				mesh_instance.mesh = mesh
				mesh_instance.transform = current_transform

				if "material" in csg and csg.material:
					mesh_instance.set_surface_override_material(0, csg.material)

				export_root.add_child(mesh_instance)

	# Handle MeshInstance3D
	elif node is MeshInstance3D:
		var source_mesh := node as MeshInstance3D
		if source_mesh.mesh:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = source_mesh.name
			mesh_instance.mesh = source_mesh.mesh
			mesh_instance.transform = current_transform

			for i in range(source_mesh.get_surface_override_material_count()):
				var mat := source_mesh.get_surface_override_material(i)
				if mat:
					mesh_instance.set_surface_override_material(i, mat)

			export_root.add_child(mesh_instance)

	# Process children
	if not (node is CSGShape3D and node.get_parent() is CSGShape3D):
		for child in node.get_children():
			_process_node_for_export(child, export_root, current_transform)
