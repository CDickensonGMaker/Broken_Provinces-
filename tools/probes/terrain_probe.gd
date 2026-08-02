extends SceneTree
## Wilderness terrain probe.
##
## Usage: godot --headless --path . --script res://tools/probes/terrain_probe.gd
##
## Asserts, for every biome preset:
##   - relief bounds: every sample lies inside TerrainConfig.biome_relief(), and the
##     observed span is not degenerate
##   - seam continuity: adjacent cells agree on their shared edge to < 0.01 units
##   - determinism: the same seed and cell produce identical samples
##
## Exits non-zero on any failure.

const SEAM_TOLERANCE: float = 0.01
const MIN_SPAN_FRACTION: float = 0.15

var _failures: int = 0


func _init() -> void:
	var biomes: Array[int] = [
		TerrainConfig.Biome.WOODLANDS,
		TerrainConfig.Biome.GRASSLANDS,
		TerrainConfig.Biome.SWAMP,
		TerrainConfig.Biome.HILLS,
		TerrainConfig.Biome.ROCKY,
		TerrainConfig.Biome.DESERT,
		TerrainConfig.Biome.ROCKY_WOODLANDS,
		TerrainConfig.Biome.ROCKY_GRASSLANDS,
		TerrainConfig.Biome.WINTER,
		TerrainConfig.Biome.ROCKY_WINTER,
		TerrainConfig.Biome.ROCKY_DESERT,
	]

	print("biome                 min      max      budget            seam_dx   seam_dz   determinism")
	for biome: int in biomes:
		_probe_biome(biome)

	print("")
	_probe_flatten()

	print("")
	if _failures > 0:
		print("FAIL: %d assertion(s) failed" % _failures)
		quit(1)
		return
	print("OK: %d biomes pass relief, seam and determinism" % biomes.size())
	quit(0)


func _probe_biome(biome: int) -> void:
	var g: int = TerrainGenerator.GRID_SIZE
	var relief: Vector2 = TerrainConfig.biome_relief(biome)

	# Relief is measured on the RAW field. The flatten field is a separate concern
	# with its own assertions below, and measuring through it would report a town's
	# level ground as a degenerate biome.
	var a: PackedFloat32Array = TerrainGenerator.generate_heights(3, -2, biome, false)
	var east: PackedFloat32Array = TerrainGenerator.generate_heights(4, -2, biome, false)
	var south: PackedFloat32Array = TerrainGenerator.generate_heights(3, -1, biome, false)
	var again: PackedFloat32Array = TerrainGenerator.generate_heights(3, -2, biome, false)

	var min_h: float = INF
	var max_h: float = -INF
	for h: float in a:
		min_h = minf(min_h, h)
		max_h = maxf(max_h, h)

	# Shared edge: column x = GRID_SIZE - 1 of this cell is column x = 0 of the cell east.
	var seam_dx: float = 0.0
	for z in range(g):
		seam_dx = maxf(seam_dx, absf(a[z * g + (g - 1)] - east[z * g + 0]))

	var seam_dz: float = 0.0
	for x in range(g):
		seam_dz = maxf(seam_dz, absf(a[(g - 1) * g + x] - south[0 * g + x]))

	var deterministic: bool = true
	for i in range(a.size()):
		if a[i] != again[i]:
			deterministic = false
			break

	var name: String = TerrainConfig.Biome.keys()[biome]
	print("%-20s %7.3f %8.3f  [%6.2f,%6.2f] %9.5f %9.5f   %s" % [
		name, min_h, max_h, relief.x, relief.y, seam_dx, seam_dz,
		"same" if deterministic else "DRIFT"
	])

	if min_h < relief.x - 0.001 or max_h > relief.y + 0.001:
		_fail(name, "relief out of budget: %.3f..%.3f vs %.2f..%.2f" % [min_h, max_h, relief.x, relief.y])

	var span: float = max_h - min_h
	if span < (relief.y - relief.x) * MIN_SPAN_FRACTION:
		_fail(name, "degenerate relief: span %.3f of budget %.3f" % [span, relief.y - relief.x])

	if seam_dx >= SEAM_TOLERANCE or seam_dz >= SEAM_TOLERANCE:
		_fail(name, "seam discontinuity: dx=%.5f dz=%.5f" % [seam_dx, seam_dz])

	if not deterministic:
		_fail(name, "same seed produced different heights")


## The flatten field: that it bites where it must, releases where it must, and that
## it is a pure function of world position so it cannot tear a seam.
func _probe_flatten() -> void:
	var g: int = TerrainGenerator.GRID_SIZE
	var size: float = TerrainGenerator.CELL_SIZE
	var biome: int = TerrainConfig.Biome.WOODLANDS

	# Elder Moor stands at (0, 0) with a 242x219 footprint. Its own ground is level.
	var inside: float = TerrainFlatten.factor(0.0, 0.0)
	print("flatten  inside Elder Moor            %.4f" % inside)
	if inside > 0.0:
		_fail("flatten", "town footprint is not level: factor %.4f" % inside)

	# Somewhere out in the world the full heightfield must survive. If nothing does,
	# the field has swallowed the map and this probe is the only thing that would say so.
	var free_cells: int = 0
	for cz: int in range(-8, 12):
		for cx: int in range(-12, 8):
			if TerrainFlatten.factor(float(cx) * size, float(cz) * size) >= 1.0:
				free_cells += 1
	print("flatten  cells at full relief         %d" % free_cells)
	if free_cells < 40:
		_fail("flatten", "only %d cell centres keep full relief" % free_cells)

	# Purity: the vertex shared by cells (1,0) and (2,0) sits on Elder Moor's ramp.
	# Each cell gathers its own source list; both must resolve it to the same float.
	var boundary_x: float = 1.5 * size
	var left: Array[Dictionary] = TerrainFlatten.build_sources(1, 0)
	var right: Array[Dictionary] = TerrainFlatten.build_sources(2, 0)
	var purity: float = 0.0
	for z in range(g):
		var world_z: float = -size * 0.5 + float(z) * size / float(g - 1)
		var lf: float = TerrainFlatten.factor_from(left, boundary_x, world_z)
		var rf: float = TerrainFlatten.factor_from(right, boundary_x, world_z)
		purity = maxf(purity, absf(lf - rf))
	print("flatten  ramp seam purity             %.9f" % purity)
	if purity != 0.0:
		_fail("flatten", "flatten factor disagrees across a cell boundary by %.9f" % purity)

	# And the same claim measured on the delivered heightfield, on the ramp.
	var a: PackedFloat32Array = TerrainGenerator.generate_heights(1, 0, biome)
	var b: PackedFloat32Array = TerrainGenerator.generate_heights(2, 0, biome)
	var again: PackedFloat32Array = TerrainGenerator.generate_heights(1, 0, biome)
	var seam: float = 0.0
	for z in range(g):
		seam = maxf(seam, absf(a[z * g + (g - 1)] - b[z * g + 0]))
	print("flatten  ramp heightfield seam        %.9f" % seam)
	if seam >= SEAM_TOLERANCE:
		_fail("flatten", "flattened seam discontinuity: %.5f" % seam)

	for i in range(a.size()):
		if a[i] != again[i]:
			_fail("flatten", "flattened field is not deterministic")
			break


func _fail(biome_name: String, message: String) -> void:
	_failures += 1
	printerr("  [%s] %s" % [biome_name, message])
