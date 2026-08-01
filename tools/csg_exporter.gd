@tool
extends EditorScript
## CSG Exporter Tool
## Bakes all CSG nodes in Kazan-Dun scenes to meshes and exports as GLB
## Run from Editor: Script → Run (Ctrl+Shift+X)

const KAZAN_DUN_ROOMS_PATH := "res://scenes/rooms/kazan_dun/"
const KAZAN_DUN_LEVELS_PATH := "res://scenes/levels/"
const EXPORT_PATH := "res://exports/kazan_dun/"

func _run() -> void:
	print("=== CSG Exporter Tool ===")
	print("This tool bakes CSG nodes and exports scenes as GLB for Blender.")
	print("")

	# Ensure export directory exists
	var dir := DirAccess.open("res://")
	if not dir.dir_exists("exports"):
		dir.make_dir("exports")
	if not dir.dir_exists("exports/kazan_dun"):
		dir.make_dir("exports/kazan_dun")
	if not dir.dir_exists("exports/kazan_dun/rooms"):
		dir.make_dir("exports/kazan_dun/rooms")
	if not dir.dir_exists("exports/kazan_dun/levels"):
		dir.make_dir("exports/kazan_dun/levels")

	# Get all Kazan-Dun scenes
	var rooms := _get_kazan_dun_rooms()
	var levels := _get_kazan_dun_levels()

	print("Found %d rooms and %d levels to export." % [rooms.size(), levels.size()])
	print("")

	# Process rooms
	print("--- Exporting Rooms ---")
	for room_path in rooms:
		_export_scene(room_path, "rooms")

	# Process levels
	print("")
	print("--- Exporting Levels ---")
	for level_path in levels:
		_export_scene(level_path, "levels")

	print("")
	print("=== Export Complete ===")
	print("Files exported to: res://exports/kazan_dun/")
	print("Open these GLB files in Blender to edit.")


func _get_kazan_dun_rooms() -> Array[String]:
	var rooms: Array[String] = []
	var dir := DirAccess.open(KAZAN_DUN_ROOMS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tscn"):
				rooms.append(KAZAN_DUN_ROOMS_PATH + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	rooms.sort()
	return rooms


func _get_kazan_dun_levels() -> Array[String]:
	var levels: Array[String] = []
	var dir := DirAccess.open(KAZAN_DUN_LEVELS_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.begins_with("kazan_dun") and file_name.ends_with(".tscn"):
				levels.append(KAZAN_DUN_LEVELS_PATH + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	levels.sort()
	return levels


func _export_scene(scene_path: String, subfolder: String) -> void:
	var scene_name := scene_path.get_file().get_basename()
	print("  Processing: %s" % scene_name)

	# Load the scene
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_error("    Failed to load scene: %s" % scene_path)
		return

	# Instance it
	var scene_instance: Node3D = packed_scene.instantiate()
	if not scene_instance:
		push_error("    Failed to instantiate scene: %s" % scene_path)
		return

	# Add to tree temporarily (required for CSG baking)
	get_editor_interface().get_edited_scene_root().add_child(scene_instance)

	# Bake all CSG nodes
	var csg_count := _bake_all_csg(scene_instance)
	print("    Baked %d CSG nodes" % csg_count)

	# Create export root with only mesh data
	var export_root := Node3D.new()
	export_root.name = scene_name

	# Copy all MeshInstance3D nodes to export root
	_copy_meshes_to_export(scene_instance, export_root, scene_instance.global_transform)

	# Add export root to tree
	get_editor_interface().get_edited_scene_root().add_child(export_root)

	# Export as GLB
	var export_file := "res://exports/kazan_dun/%s/%s.glb" % [subfolder, scene_name]
	var gltf_document := GLTFDocument.new()
	var gltf_state := GLTFState.new()

	# Configure export settings
	gltf_state.base_path = "res://exports/kazan_dun/%s/" % subfolder

	var err := gltf_document.append_from_scene(export_root, gltf_state)
	if err != OK:
		push_error("    Failed to create GLTF from scene: %s (error %d)" % [scene_name, err])
	else:
		err = gltf_document.write_to_filesystem(gltf_state, export_file)
		if err != OK:
			push_error("    Failed to write GLB file: %s (error %d)" % [export_file, err])
		else:
			print("    Exported: %s" % export_file)

	# Cleanup
	export_root.queue_free()
	scene_instance.queue_free()


func _bake_all_csg(node: Node) -> int:
	var count := 0

	# Process children first (depth-first)
	for child in node.get_children():
		count += _bake_all_csg(child)

	# If this is a CSG node, try to bake it
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		# Only bake root CSG nodes (not children of other CSG)
		if not (node.get_parent() is CSGShape3D):
			var meshes := csg.get_meshes()
			if meshes.size() >= 2:
				var mesh: Mesh = meshes[1]
				if mesh:
					# Create a MeshInstance3D to replace the CSG
					var mesh_instance := MeshInstance3D.new()
					mesh_instance.name = csg.name + "_baked"
					mesh_instance.mesh = mesh
					mesh_instance.transform = csg.transform

					# Copy material if CSG has one
					if csg is CSGPrimitive3D:
						var primitive := csg as CSGPrimitive3D
						if primitive.material:
							mesh_instance.set_surface_override_material(0, primitive.material)

					# Add baked mesh as sibling
					csg.get_parent().add_child(mesh_instance)
					count += 1

	return count


func _copy_meshes_to_export(source: Node, target: Node3D, base_transform: Transform3D) -> void:
	for child in source.get_children():
		if child is MeshInstance3D:
			var mesh_inst := child as MeshInstance3D
			var new_mesh := MeshInstance3D.new()
			new_mesh.name = mesh_inst.name
			new_mesh.mesh = mesh_inst.mesh
			# Calculate world transform relative to base
			new_mesh.transform = base_transform.inverse() * mesh_inst.global_transform

			# Copy materials
			for i in range(mesh_inst.get_surface_override_material_count()):
				var mat := mesh_inst.get_surface_override_material(i)
				if mat:
					new_mesh.set_surface_override_material(i, mat)

			target.add_child(new_mesh)

		# Recurse into children
		if child.get_child_count() > 0:
			_copy_meshes_to_export(child, target, base_transform)
