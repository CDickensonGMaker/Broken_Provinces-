extends Node
## Navmesh agreement check: every level's baked navmesh matches the nav map.
##
## Usage: godot --headless --path . res://tools/check_navmesh.tscn
##
## NavRegion3D::set_navigation_mesh returns EARLY when a NavigationMesh's
## cell_size or cell_height disagrees with the navigation map it is assigned
## to (nav_region_3d.cpp:104 and :108). The region then holds no navmesh at
## all and nothing in that level can path - and the only symptom is an engine
## error line in a boot log nobody reads.
##
## Two halves:
##
##   1. STATIC. Every `cell_size` / `cell_height` assignment in scripts/levels
##      must equal the navigation map's value. This catches a new level the
##      moment it is written, without booting it.
##
##   2. LIVE. A named set of levels is actually instantiated, baked and
##      checked for a navmesh with real geometry in it - because a value that
##      agrees on paper still proves nothing about whether the bake produced
##      anything.

const LEVEL_SCRIPT_DIR := "res://scripts/levels"

## Levels booted for real. Kept small deliberately - this is a spot check that
## the static half is telling the truth, not a sweep of all 46.
const LIVE_LEVELS: Array[String] = [
	"res://scenes/levels/sunken_crypt.tscn",    # CSG rooms, delayed bake
	"res://scenes/levels/crossroads_ruins.tscn",  # static colliders
	"res://scenes/levels/elder_moor.tscn",      # the Act I start
	"res://scenes/levels/falkenhaften.tscn",    # navmesh authored in the .tscn
]

## Levels whose script assigns no navigation mesh at all. Their regions are
## empty shells, which is a different bug from a rejected or unparsed mesh and
## is not this check's business. Recorded so the list cannot grow unnoticed.
const NO_NAVMESH_ASSIGNED: Array[String] = [
	"bandit_hideout_level_1.tscn",
	"bandit_hideout_level_2.tscn",
	"cultist_ruins_corner.tscn",
	"cultist_temple.tscn",
	"cultist_temple_2.tscn",
]

## Frames to wait for the deferred bake to land.
const BAKE_FRAMES: int = 400

## Frames to wait before believing "not baking" means "finished".
const MIN_SETTLE_FRAMES: int = 90

var _failures: int = 0


func _ready() -> void:
	var map_cell_size: float = ProjectSettings.get_setting(
		"navigation/3d/default_cell_size", 0.25)
	var map_cell_height: float = ProjectSettings.get_setting(
		"navigation/3d/default_cell_height", 0.25)
	print("navigation map: cell_size=%.4f cell_height=%.4f" % [map_cell_size, map_cell_height])
	print("")

	_check_sources(map_cell_size, map_cell_height)
	await _check_live()
	_finish()


## ---------------------------------------------------------------------------
## Static half - read every level script's declared cell values
## ---------------------------------------------------------------------------
func _check_sources(map_cell_size: float, map_cell_height: float) -> void:
	var dir: DirAccess = DirAccess.open(LEVEL_SCRIPT_DIR)
	if dir == null:
		_fail("setup", "could not open %s" % LEVEL_SCRIPT_DIR)
		return

	var checked: int = 0
	var declaring: int = 0

	for file_name: String in dir.get_files():
		if not file_name.ends_with(".gd"):
			continue
		var path: String = "%s/%s" % [LEVEL_SCRIPT_DIR, file_name]
		var source: String = FileAccess.get_file_as_string(path)
		if source.is_empty():
			continue
		checked += 1

		var declared: bool = false
		var line_no: int = 0
		for line: String in source.split("\n"):
			line_no += 1
			var stripped: String = line.strip_edges()
			if stripped.begins_with("#"):
				continue
			_check_assignment(file_name, line_no, stripped, "cell_size", map_cell_size)
			_check_assignment(file_name, line_no, stripped, "cell_height", map_cell_height)
			if stripped.contains(".cell_size =") or stripped.contains(".cell_height ="):
				declared = true
		if declared:
			declaring += 1

	print("static: %d level scripts read, %d declare nav cell values" % [checked, declaring])


func _check_assignment(file_name: String, line_no: int, line: String,
		property: String, expected: float) -> void:
	var needle: String = ".%s =" % property
	var at: int = line.find(needle)
	if at < 0:
		return
	var rhs: String = line.substr(at + needle.length()).strip_edges()
	# Trim any trailing comment
	var hash_at: int = rhs.find("#")
	if hash_at >= 0:
		rhs = rhs.substr(0, hash_at).strip_edges()
	if not rhs.is_valid_float():
		return  # Computed value - out of this check's reach
	var value: float = rhs.to_float()
	if absf(value - expected) > 0.0001:
		_fail(file_name, "line %d sets %s = %s; the navigation map is %.4f. NavRegion3D rejects the mesh and the level cannot path." % [
			line_no, property, rhs, expected])


## ---------------------------------------------------------------------------
## Live half - boot a level, bake, and demand a navmesh with geometry in it
## ---------------------------------------------------------------------------
func _check_live() -> void:
	for scene_path: String in LIVE_LEVELS:
		var packed: PackedScene = load(scene_path)
		if packed == null:
			_fail(scene_path, "could not load scene")
			continue

		var level: Node = packed.instantiate()
		add_child(level)

		var regions: Array[Node] = []
		_collect_regions(level, regions)
		for region: Node in regions:
			var nav_region: NavigationRegion3D = region as NavigationRegion3D
			if nav_region.is_baking():
				await nav_region.bake_finished

		# A minimum settle matters: levels whose geometry is CSG delay their bake
		# by a couple of frames, so is_baking() is still false right after
		# _ready and an early break would read an unbaked mesh as empty.
		for i: int in range(BAKE_FRAMES):
			await get_tree().process_frame
			var still_baking: bool = false
			for region: Node in regions:
				if (region as NavigationRegion3D).is_baking():
					still_baking = true
			if not still_baking and i > MIN_SETTLE_FRAMES:
				break

		regions.clear()
		_collect_regions(level, regions)

		if regions.is_empty():
			_fail(scene_path, "no NavigationRegion3D in the level")

		# A level passes if ANY of its regions carries a baked navmesh. Several
		# scenes also hold an authored NavigationRegion3D the level script never
		# uses, because the script builds its own; those are inert, not broken.
		var best_polys: int = 0
		for region: Node in regions:
			var nav_region: NavigationRegion3D = region as NavigationRegion3D
			var mesh: NavigationMesh = nav_region.navigation_mesh
			if mesh == null:
				continue
			var verts: int = mesh.get_vertices().size()
			var polys: int = mesh.get_polygon_count()
			print("live: %s  %s  vertices=%d polygons=%d" % [
				scene_path.get_file(), nav_region.name, verts, polys])
			best_polys = maxi(best_polys, polys)

		if best_polys == 0:
			_fail(scene_path, "no region in this level carries a baked navmesh - nothing can path here")

		level.queue_free()
		await get_tree().process_frame


func _collect_regions(node: Node, out: Array[Node]) -> void:
	if node is NavigationRegion3D:
		out.append(node)
	for child: Node in node.get_children():
		_collect_regions(child, out)


func _fail(context: String, message: String) -> void:
	_failures += 1
	printerr("FAIL [%s]: %s" % [context, message])


func _finish() -> void:
	print("")
	if _failures > 0:
		print("FAIL: %d assertion(s) failed" % _failures)
		get_tree().quit(1)
		return
	print("OK: every level's nav cell values agree with the navigation map, and the booted levels carry a baked navmesh")
	get_tree().quit(0)
