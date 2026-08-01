extends Node
## Wilderness cell probe.
##
## Usage: godot --headless --path . res://tools/cell_probe.tscn
##
## Generates one procedural cell per biome with the autoloads live, which is the only
## check that catches a biome the prop and texture tables forgot. A biome that returns
## no children has fallen through its density table.

const PROBE_CELL := Vector2i(-2, 2)
const MIN_CHILDREN := 20

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame

	var scene: PackedScene = load("res://scenes/generation/wilderness_room.tscn")
	for biome in range(TerrainConfig.Biome.size()):
		var room: Node = scene.instantiate()
		room.set("biome", biome)
		room.call("set_seamless_mode", true)
		add_child(room)
		room.call("generate", 12345 + biome, PROBE_CELL)

		var children: int = room.get_child_count()
		print("%-18s %4d nodes" % [TerrainConfig.Biome.keys()[biome], children])
		if children < MIN_CHILDREN:
			printerr("  [%s] generated only %d nodes" % [TerrainConfig.Biome.keys()[biome], children])
			_failures += 1

		room.queue_free()
		await get_tree().process_frame

	if _failures > 0:
		print("FAIL: %d biome(s) generated no content" % _failures)
		get_tree().quit(1)
		return
	print("OK: every biome generates a populated cell")
	get_tree().quit(0)
