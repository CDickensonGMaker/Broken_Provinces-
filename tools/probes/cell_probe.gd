extends Node
## Wilderness cell probe.
##
## Usage: godot --headless --path . res://tools/probes/cell_probe.tscn
##
## Generates one procedural cell per biome with the autoloads live, which is the only
## check that catches a biome the prop and texture tables forgot. A biome that returns
## no children has fallen through its density table.

const PROBE_CELL := Vector2i(-2, 2)
const MIN_CHILDREN := 20

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame

	var scene: PackedScene = load("res://scenes/generation/wilderness/wilderness_room.tscn")
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

	_report_world_biomes()

	if _failures > 0:
		print("FAIL: %d biome(s) generated no content" % _failures)
		get_tree().quit(1)
		return
	print("OK: every biome generates a populated cell")
	get_tree().quit(0)


## Census of the assigned world map, so a climate model that quietly paints one biome
## over everything is visible without opening the map.
func _report_world_biomes() -> void:
	var census: Dictionary = {}
	for coords: Vector2i in WorldGrid.cells:
		var cell: WorldGrid.CellInfo = WorldGrid.cells[coords]
		var key: String = WorldGrid.Biome.keys()[cell.biome]
		census[key] = int(census.get(key, 0)) + 1

	print("")
	print("world biome census (%d cells)" % WorldGrid.cells.size())
	var names: Array = census.keys()
	names.sort()
	for key: String in names:
		print("  %-18s %4d" % [key, census[key]])
