extends SceneTree
## Boots a level scene headless and prints every spawned npc_id.
##
## Usage: godot --headless --path . --script res://tools/probes/probe_npc_ids.gd -- <scene_path>

func _initialize() -> void:
	var scene_path: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.ends_with(".tscn"):
			scene_path = arg
	if scene_path.is_empty():
		print("usage: --script res://tools/probes/probe_npc_ids.gd -- res://scenes/levels/x.tscn")
		quit(1)
		return

	var packed: PackedScene = load(scene_path)
	if not packed:
		print("could not load ", scene_path)
		quit(1)
		return
	var level: Node = packed.instantiate()
	root.add_child(level)
	await process_frame
	await process_frame

	var ids: Array[String] = []
	for node: Node in root.get_tree().get_nodes_in_group("npcs"):
		if "npc_id" in node:
			ids.append(String(node.npc_id))
	ids.sort()
	print("npc ids in %s (%d):" % [scene_path, ids.size()])
	for id: String in ids:
		print("  ", id)
	quit(0)
