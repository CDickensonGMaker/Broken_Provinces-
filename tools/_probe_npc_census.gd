extends SceneTree
## Scratch probe. Boots level scenes headless and dumps every NPC's id, class,
## display name and world position as JSON, so schedule stations can be derived
## from where each NPC actually stands rather than from a regex over the spawner.
##
## Usage: godot --headless --path . --script res://tools/_probe_npc_census.gd -- <scene> [<scene> ...]

func _initialize() -> void:
	var scenes: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.ends_with(".tscn"):
			scenes.append(arg)
	if scenes.is_empty():
		print("usage: -- res://scenes/levels/x.tscn")
		quit(1)
		return

	var out: Dictionary = {}
	for scene_path: String in scenes:
		var packed: PackedScene = load(scene_path)
		if not packed:
			continue
		var level: Node = packed.instantiate()
		root.add_child(level)
		for _i in range(8):
			await process_frame

		var rows: Array = []
		for node: Node in root.get_tree().get_nodes_in_group("npcs"):
			if not node is Node3D:
				continue
			var n3: Node3D = node as Node3D
			var row: Dictionary = {
				"id": String(node.npc_id) if "npc_id" in node else "",
				"name": String(node.npc_name) if "npc_name" in node else n3.name,
				"cls": node.get_script().resource_path.get_file() if node.get_script() else n3.get_class(),
				"pos": [snappedf(n3.global_position.x, 0.01), snappedf(n3.global_position.y, 0.01), snappedf(n3.global_position.z, 0.01)],
				"quests": node.quest_ids if "quest_ids" in node else [],
			}
			rows.append(row)
		out[scene_path] = rows
		root.remove_child(level)
		level.free()

	print("CENSUS_JSON_BEGIN")
	print(JSON.stringify(out, "  "))
	print("CENSUS_JSON_END")
	quit(0)
