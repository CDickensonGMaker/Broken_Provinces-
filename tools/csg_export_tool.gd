extends Node3D
## CSG Export Tool - Run this scene (F6) to export all Kazan-Dun geometry to GLB
## The exported files will be in res://exports/kazan_dun/
## Open them in Blender to edit, then re-import to Godot

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

var _export_queue: Array[String] = []
var _current_index := 0
var _export_type := ""  # "rooms" or "levels"
var _status_label: Label


func _ready() -> void:
	# Create UI
	_setup_ui()

	# Ensure export directories exist
	_ensure_directories()

	print("=== Kazan-Dun CSG Export Tool ===")
	print("Press SPACE to start exporting rooms")
	print("Press L to start exporting levels")
	print("Press A to export ALL (rooms + levels)")
	print("Press ESC to quit")


func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.anchor_left = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_top = 0.1
	vbox.anchor_bottom = 0.9
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "KAZAN-DUN CSG EXPORT TOOL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var info := Label.new()
	info.text = """
This tool exports all Kazan-Dun CSG geometry to GLB files
that can be opened in Blender for editing.

Found: %d rooms, %d levels

CONTROLS:
  SPACE - Export rooms only
  L - Export levels only
  A - Export ALL (rooms + levels)
  ESC - Quit

Export location: res://exports/kazan_dun/
""" % [KAZAN_DUN_ROOMS.size(), KAZAN_DUN_LEVELS.size()]
	info.add_theme_font_size_override("font_size", 18)
	vbox.add_child(info)

	vbox.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = "Ready. Press a key to start."
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	vbox.add_child(_status_label)


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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE:
				_start_export("rooms", KAZAN_DUN_ROOMS)
			KEY_L:
				_start_export("levels", KAZAN_DUN_LEVELS)
			KEY_A:
				var all_scenes: Array[String] = []
				all_scenes.append_array(KAZAN_DUN_ROOMS)
				all_scenes.append_array(KAZAN_DUN_LEVELS)
				_start_export("all", all_scenes)


func _start_export(type: String, scenes: Array[String]) -> void:
	_export_type = type
	_export_queue = scenes.duplicate()
	_current_index = 0
	_status_label.text = "Starting export of %d scenes..." % scenes.size()

	# Process one per frame to avoid freezing
	set_process(true)
	_process_next()


func _process(delta: float) -> void:
	# Handled by _process_next via call_deferred
	pass


func _process_next() -> void:
	if _current_index >= _export_queue.size():
		_status_label.text = "COMPLETE! Exported %d files to res://exports/kazan_dun/" % _export_queue.size()
		_status_label.add_theme_color_override("font_color", Color.GREEN)
		print("=== Export Complete ===")
		set_process(false)
		return

	var scene_path: String = _export_queue[_current_index]
	var scene_name := scene_path.get_file().get_basename()

	_status_label.text = "Exporting [%d/%d]: %s" % [_current_index + 1, _export_queue.size(), scene_name]
	print("Exporting: %s" % scene_name)

	# Export the scene
	_export_scene(scene_path)

	_current_index += 1

	# Process next frame
	call_deferred("_process_next")


func _export_scene(scene_path: String) -> void:
	var scene_name := scene_path.get_file().get_basename()

	# Determine subfolder
	var subfolder := "rooms" if "rooms" in scene_path else "levels"

	# Load and instantiate
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_error("Failed to load: %s" % scene_path)
		return

	var scene_instance: Node = packed_scene.instantiate()
	if not scene_instance:
		push_error("Failed to instantiate: %s" % scene_path)
		return

	# Add to tree (required for transforms)
	add_child(scene_instance)

	# Create export container
	var export_root := Node3D.new()
	export_root.name = scene_name

	# Bake CSG and collect meshes
	_process_node_for_export(scene_instance, export_root, Transform3D.IDENTITY)

	# Export as GLB
	if export_root.get_child_count() > 0:
		var export_file := "res://exports/kazan_dun/%s/%s.glb" % [subfolder, scene_name]

		var gltf_doc := GLTFDocument.new()
		var gltf_state := GLTFState.new()

		add_child(export_root)

		var err := gltf_doc.append_from_scene(export_root, gltf_state)
		if err == OK:
			err = gltf_doc.write_to_filesystem(gltf_state, export_file)
			if err == OK:
				print("  -> Exported: %s" % export_file)
			else:
				push_error("  Failed to write: %s (error %d)" % [export_file, err])
		else:
			push_error("  Failed to create GLTF (error %d)" % err)

		export_root.queue_free()
	else:
		print("  -> No meshes found in: %s" % scene_name)

	# Cleanup
	scene_instance.queue_free()


func _process_node_for_export(node: Node, export_root: Node3D, parent_transform: Transform3D) -> void:
	var current_transform := parent_transform

	if node is Node3D:
		current_transform = parent_transform * (node as Node3D).transform

	# Handle CSG nodes - bake to mesh
	if node is CSGShape3D:
		var csg := node as CSGShape3D
		# Only process root CSG (not children being used in boolean ops)
		if not (node.get_parent() is CSGShape3D):
			var meshes := csg.get_meshes()
			if meshes.size() >= 2 and meshes[1] is Mesh:
				var mesh: Mesh = meshes[1]
				var mesh_instance := MeshInstance3D.new()
				mesh_instance.name = csg.name
				mesh_instance.mesh = mesh
				mesh_instance.transform = current_transform

				# Try to get material
				if csg.has_method("get_material"):
					var mat: Material = csg.material
					if mat:
						mesh_instance.set_surface_override_material(0, mat)

				export_root.add_child(mesh_instance)

	# Handle existing MeshInstance3D nodes
	elif node is MeshInstance3D:
		var source_mesh := node as MeshInstance3D
		if source_mesh.mesh:
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = source_mesh.name
			mesh_instance.mesh = source_mesh.mesh
			mesh_instance.transform = current_transform

			# Copy materials
			for i in range(source_mesh.get_surface_override_material_count()):
				var mat := source_mesh.get_surface_override_material(i)
				if mat:
					mesh_instance.set_surface_override_material(i, mat)

			export_root.add_child(mesh_instance)

	# Process children (skip CSG children as they're part of boolean ops)
	if not (node is CSGShape3D and node.get_parent() is CSGShape3D):
		for child in node.get_children():
			_process_node_for_export(child, export_root, current_transform)
