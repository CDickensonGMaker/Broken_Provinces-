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
	if _failures > 0:
		print("FAIL: %d assertion(s) failed" % _failures)
		quit(1)
		return
	print("OK: %d biomes pass relief, seam and determinism" % biomes.size())
	quit(0)


func _probe_biome(biome: int) -> void:
	var g: int = TerrainGenerator.GRID_SIZE
	var relief: Vector2 = TerrainConfig.biome_relief(biome)

	var a: PackedFloat32Array = TerrainGenerator.generate_heights(3, -2, biome)
	var east: PackedFloat32Array = TerrainGenerator.generate_heights(4, -2, biome)
	var south: PackedFloat32Array = TerrainGenerator.generate_heights(3, -1, biome)
	var again: PackedFloat32Array = TerrainGenerator.generate_heights(3, -2, biome)

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


func _fail(biome_name: String, message: String) -> void:
	_failures += 1
	printerr("  [%s] %s" % [biome_name, message])
