extends Node
## Cliff outcrop check: the rocky biome family actually gets its cliffs.
##
## Usage: godot --headless --path . res://tools/check_cliff_props.tscn
##
## Cliff_01.obj and Cliff_02.obj came over with the terrain engine port and sat
## in assets/models/rocks/ with no spawner for a day. This guards against them
## going quiet again, and against the two mistakes the spawner can make that no
## error message would report:
##
##   1. SCALE. The source meshes are 22 m and 36 m tall around their own origin.
##      Spawned at native size an outcrop is a third of a 100 m cell. The check
##      asserts the world-space height of every outcrop lands in the intended
##      band, which catches both "forgot to scale" and "scaled off one mesh".
##
##   2. BURIAL. The meshes are centred, so half of each is below its origin. If
##      the base lift is dropped, the outcrop is a boulder half-sunk in the
##      hill. The check asserts the base sits just under the prop origin, not
##      halfway down.
##
## It also asserts the non-rocky biomes stay clear: a cliff in a swamp is a bug.

const ROOM_SCENE := "res://scenes/generation/wilderness_room.tscn"

## Biomes that must produce outcrops, and biomes that must not.
const ROCKY_BIOMES: Array[int] = [4, 6, 7, 9, 10]   # ROCKY, ROCKY_FOREST/PLAINS/WINTER/DESERT
const CLEAR_BIOMES: Array[int] = [0, 2, 5, 8]       # FOREST, SWAMP, DESERT, WINTER

## Cells sampled per biome. One cell can legitimately roll a low count; the
## spawner is only silent if a whole run of them is.
const SAMPLE_CELLS: int = 6

var _failures: int = 0


func _ready() -> void:
	var scene: PackedScene = load(ROOM_SCENE)
	if scene == null:
		_fail("setup", "could not load %s" % ROOM_SCENE)
		_finish()
		return

	print("biome  cells  outcrops  height_min  height_max  base_y")

	for biome: int in ROCKY_BIOMES:
		_probe(scene, biome, true)
	for biome: int in CLEAR_BIOMES:
		_probe(scene, biome, false)

	_finish()


func _probe(scene: PackedScene, biome: int, expect_cliffs: bool) -> void:
	var total: int = 0
	var height_min: float = 1e9
	var height_max: float = -1e9
	var worst_base: float = 0.0

	for cell: int in range(SAMPLE_CELLS):
		var room: Node = scene.instantiate()
		room.set("biome", biome)
		# The room must be in the tree before generate(): it reads the scene
		# tree for the world enemy budget.
		add_child(room)
		if room.has_method("generate"):
			room.call("generate", 4400 + cell * 97, Vector2i(cell, biome))

		for child: Node in room.get_children():
			# Outcrops are found by their mesh child, not by name. When siblings
			# collide on a name Godot renames them off the CLASS - the second
			# outcrop in a cell is "@Node3D@246", not "CliffOutcrop2" - so any
			# name match counts one per cell and would call a spawner healthy
			# that had quietly dropped to a single rock.
			var mesh_node: MeshInstance3D = child.get_node_or_null("CliffMesh") as MeshInstance3D
			if mesh_node == null:
				continue
			total += 1
			var bounds: AABB = mesh_node.mesh.get_aabb()
			var height: float = bounds.size.y * mesh_node.scale.y
			height_min = minf(height_min, height)
			height_max = maxf(height_max, height)
			# Base of the mesh in the outcrop's own space.
			var base_y: float = mesh_node.position.y + bounds.position.y * mesh_node.scale.y
			worst_base = minf(worst_base, base_y)

		remove_child(room)
		room.queue_free()

	if total == 0:
		height_min = 0.0
		height_max = 0.0
	print("%5d  %5d  %8d  %10.2f  %10.2f  %6.2f" % [biome, SAMPLE_CELLS, total, height_min, height_max, worst_base])

	if not expect_cliffs:
		if total > 0:
			_fail(str(biome), "non-rocky biome spawned %d outcrop(s)" % total)
		return

	if total == 0:
		_fail(str(biome), "rocky biome spawned no outcrops across %d cells" % SAMPLE_CELLS)
		return

	var wanted_min: float = float(WildernessRoom.CLIFF_HEIGHT_MIN)
	var wanted_max: float = float(WildernessRoom.CLIFF_HEIGHT_MAX)
	if height_min < wanted_min - 0.01 or height_max > wanted_max + 0.01:
		_fail(str(biome), "outcrop heights %.2f-%.2f outside the intended %.1f-%.1f m" % [
			height_min, height_max, wanted_min, wanted_max])

	# Base must sit just below the prop origin - the sink - and never anywhere
	# near half the mesh height, which is what an unlifted centred mesh gives.
	var deepest_allowed: float = -wanted_max * float(WildernessRoom.CLIFF_SINK_FRACTION) - 0.01
	if worst_base < deepest_allowed:
		_fail(str(biome), "outcrop base at %.2f is deeper than the %.2f sink allows - base lift dropped?" % [
			worst_base, deepest_allowed])


func _fail(context: String, message: String) -> void:
	_failures += 1
	printerr("FAIL [%s]: %s" % [context, message])


func _finish() -> void:
	print("")
	if _failures > 0:
		print("FAIL: %d assertion(s) failed" % _failures)
		get_tree().quit(1)
		return
	print("OK: rocky biomes carry cliff outcrops, non-rocky biomes do not")
	get_tree().quit(0)
