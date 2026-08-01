## terrain_generator.gd - Heightfield generator for wilderness cells.
##
## Ported from the RECONgame terrain engine: domain warping, ridged multifractal,
## cliff terracing, gaussian relief smoothing.
##
## SEAM CONTRACT. Every stage is either pointwise in WORLD space or a symmetric
## neighbour stencil, and the tile is generated with a margin of `_pad()` samples on
## every side. A vertex on a shared cell boundary therefore resolves to the same value
## whichever cell computes it, bit for bit. Two rules keep that true:
##   1. No stage may read a statistic of the tile (mean, percentile, min/max). A
##      whole-map normalization pass is exactly what would tear the seam.
##   2. The margin must cover the full stencil support: one ring for the cliff pass
##      plus one ring per smoothing pass.
class_name TerrainGenerator
extends RefCounted


## 17x17 vertices per cell. Step is 6.25 world units - an exact binary fraction, so
## world sample positions carry no floating point drift between neighbouring cells.
const GRID_SIZE: int = 17
const CELL_SIZE: float = 100.0

## Per-biome generation parameters. Keys are TerrainConfig.Biome ordinals.
const BIOME_PRESETS: Dictionary = {
	TerrainConfig.Biome.WOODLANDS: {
		"base_frequency": 0.008,
		"base_octaves": 4,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 25.0,
		"warp_frequency": 0.012,
		"ridge_enabled": true,
		"ridge_blend": 0.2,
		"ridge_threshold": 0.4,
		"ridge_sharpness": 1.5,
		"detail_frequency": 0.03,
		"detail_amplitude": 0.06,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 1,
	},
	TerrainConfig.Biome.GRASSLANDS: {
		"base_frequency": 0.005,
		"base_octaves": 3,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 15.0,
		"warp_frequency": 0.008,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.02,
		"detail_amplitude": 0.03,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 2,
	},
	TerrainConfig.Biome.SWAMP: {
		"base_frequency": 0.006,
		"base_octaves": 3,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 20.0,
		"warp_frequency": 0.015,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.025,
		"detail_amplitude": 0.08,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 2,
	},
	TerrainConfig.Biome.HILLS: {
		"base_frequency": 0.012,
		"base_octaves": 5,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 40.0,
		"warp_frequency": 0.01,
		"ridge_enabled": true,
		"ridge_blend": 0.5,
		"ridge_threshold": 0.25,
		"ridge_sharpness": 2.5,
		"detail_frequency": 0.04,
		"detail_amplitude": 0.1,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 1,
	},
	TerrainConfig.Biome.ROCKY: {
		"base_frequency": 0.01,
		"base_octaves": 4,
		"base_persistence": 0.5,
		"warp_enabled": false,
		"warp_strength": 0.0,
		"warp_frequency": 0.01,
		"ridge_enabled": true,
		"ridge_blend": 0.4,
		"ridge_threshold": 0.2,
		"ridge_sharpness": 3.0,
		"detail_frequency": 0.05,
		"detail_amplitude": 0.12,
		"cliff_enabled": true,
		"cliff_threshold": 0.2,
		"cliff_sharpness": 2.5,
		"smoothing_passes": 1,
	},
	TerrainConfig.Biome.DESERT: {
		"base_frequency": 0.006,
		"base_octaves": 3,
		"base_persistence": 0.55,
		"warp_enabled": true,
		"warp_strength": 35.0,
		"warp_frequency": 0.008,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.015,
		"detail_amplitude": 0.04,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 3,
	},
	TerrainConfig.Biome.ROCKY_WOODLANDS: {
		"base_frequency": 0.009,
		"base_octaves": 5,
		"base_persistence": 0.45,
		"warp_enabled": true,
		"warp_strength": 30.0,
		"warp_frequency": 0.011,
		"ridge_enabled": true,
		"ridge_blend": 0.45,
		"ridge_threshold": 0.22,
		"ridge_sharpness": 2.2,
		"detail_frequency": 0.045,
		"detail_amplitude": 0.09,
		"cliff_enabled": true,
		"cliff_threshold": 0.22,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 2,
	},
	TerrainConfig.Biome.ROCKY_GRASSLANDS: {
		"base_frequency": 0.007,
		"base_octaves": 4,
		"base_persistence": 0.45,
		"warp_enabled": true,
		"warp_strength": 28.0,
		"warp_frequency": 0.009,
		"ridge_enabled": true,
		"ridge_blend": 0.4,
		"ridge_threshold": 0.25,
		"ridge_sharpness": 2.0,
		"detail_frequency": 0.035,
		"detail_amplitude": 0.07,
		"cliff_enabled": true,
		"cliff_threshold": 0.24,
		"cliff_sharpness": 1.8,
		"smoothing_passes": 2,
	},
	TerrainConfig.Biome.WINTER: {
		"base_frequency": 0.0055,
		"base_octaves": 4,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 22.0,
		"warp_frequency": 0.009,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.018,
		"detail_amplitude": 0.035,
		"cliff_enabled": false,
		"cliff_threshold": 0.25,
		"cliff_sharpness": 2.0,
		"smoothing_passes": 3,
	},
	TerrainConfig.Biome.ROCKY_WINTER: {
		"base_frequency": 0.0085,
		"base_octaves": 5,
		"base_persistence": 0.42,
		"warp_enabled": true,
		"warp_strength": 34.0,
		"warp_frequency": 0.01,
		"ridge_enabled": true,
		"ridge_blend": 0.5,
		"ridge_threshold": 0.2,
		"ridge_sharpness": 2.6,
		"detail_frequency": 0.05,
		"detail_amplitude": 0.08,
		"cliff_enabled": true,
		"cliff_threshold": 0.2,
		"cliff_sharpness": 2.6,
		"smoothing_passes": 2,
	},
	TerrainConfig.Biome.ROCKY_DESERT: {
		"base_frequency": 0.0065,
		"base_octaves": 4,
		"base_persistence": 0.5,
		"warp_enabled": true,
		"warp_strength": 18.0,
		"warp_frequency": 0.007,
		"ridge_enabled": true,
		"ridge_blend": 0.35,
		"ridge_threshold": 0.3,
		"ridge_sharpness": 1.6,
		"detail_frequency": 0.03,
		"detail_amplitude": 0.05,
		"cliff_enabled": true,
		"cliff_threshold": 0.16,
		"cliff_sharpness": 4.5,
		"smoothing_passes": 1,
	},
}

## Edge blend ramp, in vertices, applied where a neighbouring cell uses flat ground.
const BLEND_DISTANCE: int = 4

## Base seed for the heightfield. Terrain shape is stable across playthroughs; the
## per-playthrough variation lives in biome assignment and prop placement instead.
const NOISE_SEED: int = 42069

## The ridge pass can add at most this fraction of its blend weight to a sample. Used
## to bound the raw signal analytically so the normalization never has to clamp - a
## clamp against [0,1] is what shears mountain tops flat.
const RIDGE_MAX_GAIN: float = 0.3


## Generate the heightfield for one cell, in world units relative to the cell's ground
## plane. Returns GRID_SIZE * GRID_SIZE samples in row-major (z, x) order.
static func generate_heights(
	cell_x: int,
	cell_z: int,
	biome: int,
	blend_edges: Dictionary = {},
	world_seed: int = NOISE_SEED
) -> PackedFloat32Array:
	var preset: Dictionary = BIOME_PRESETS.get(biome, BIOME_PRESETS[TerrainConfig.Biome.GRASSLANDS])
	var pad: int = _pad(preset)
	var padded_size: int = GRID_SIZE + 2 * pad
	var step: float = CELL_SIZE / float(GRID_SIZE - 1)
	var origin_x: float = float(cell_x) * CELL_SIZE - float(pad) * step
	var origin_z: float = float(cell_z) * CELL_SIZE - float(pad) * step

	var field: PackedFloat32Array = _sample_field(preset, padded_size, origin_x, origin_z, step, world_seed)

	if bool(preset["cliff_enabled"]):
		field = _apply_cliffs(field, padded_size, preset)

	var passes: int = int(preset["smoothing_passes"])
	for i in range(passes):
		field = _smooth(field, padded_size)

	return _extract_cell(field, padded_size, pad, biome, blend_edges)


## Height at a local position inside a cell, bilinearly interpolated.
static func height_at(heights: PackedFloat32Array, local_x: float, local_z: float) -> float:
	var half_size: float = CELL_SIZE * 0.5
	var step: float = CELL_SIZE / float(GRID_SIZE - 1)

	var grid_x: float = clampf((local_x + half_size) / step, 0.0, float(GRID_SIZE - 1))
	var grid_z: float = clampf((local_z + half_size) / step, 0.0, float(GRID_SIZE - 1))

	var x0: int = int(grid_x)
	var z0: int = int(grid_z)
	var x1: int = mini(x0 + 1, GRID_SIZE - 1)
	var z1: int = mini(z0 + 1, GRID_SIZE - 1)

	var fx: float = grid_x - float(x0)
	var fz: float = grid_z - float(z0)

	var h0: float = lerpf(heights[z0 * GRID_SIZE + x0], heights[z0 * GRID_SIZE + x1], fx)
	var h1: float = lerpf(heights[z1 * GRID_SIZE + x0], heights[z1 * GRID_SIZE + x1], fx)
	return lerpf(h0, h1, fz)


## Margin the padded tile needs so every neighbour stencil is fully supported.
static func _pad(preset: Dictionary) -> int:
	var passes: int = int(preset["smoothing_passes"])
	return passes + (1 if bool(preset["cliff_enabled"]) else 0)


## Pointwise stages: base noise under domain warp, ridged multifractal, detail.
## Result is normalized to [0,1] by an analytic bound, never by a clamp.
static func _sample_field(
	preset: Dictionary,
	padded_size: int,
	origin_x: float,
	origin_z: float,
	step: float,
	world_seed: int
) -> PackedFloat32Array:
	var base_noise := FastNoiseLite.new()
	base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_noise.frequency = preset["base_frequency"]
	base_noise.fractal_octaves = preset["base_octaves"]
	base_noise.fractal_lacunarity = 2.0
	base_noise.fractal_gain = preset["base_persistence"]
	base_noise.seed = world_seed

	var warp_noise_x := FastNoiseLite.new()
	warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise_x.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_x.fractal_octaves = 3
	warp_noise_x.frequency = preset["warp_frequency"]
	warp_noise_x.seed = world_seed + 100

	var warp_noise_z := FastNoiseLite.new()
	warp_noise_z.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise_z.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_z.fractal_octaves = 3
	warp_noise_z.frequency = preset["warp_frequency"]
	warp_noise_z.seed = world_seed + 200

	var ridge_noise := FastNoiseLite.new()
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.frequency = float(preset["base_frequency"]) * 1.5
	ridge_noise.fractal_octaves = 4
	ridge_noise.seed = world_seed + 300

	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.frequency = preset["detail_frequency"]
	detail_noise.seed = world_seed + 400

	var warp_enabled: bool = preset["warp_enabled"]
	var warp_strength: float = preset["warp_strength"]
	var ridge_enabled: bool = preset["ridge_enabled"]
	var ridge_blend: float = preset["ridge_blend"]
	var ridge_threshold: float = preset["ridge_threshold"]
	var ridge_sharpness: float = preset["ridge_sharpness"]
	var detail_amp: float = preset["detail_amplitude"]

	# Analytic bounds of the raw signal. Rescaling by these instead of clamping is what
	# keeps peaks from shearing flat against the top of the range.
	var raw_lo: float = -detail_amp
	var raw_hi: float = 1.0 + detail_amp + (ridge_blend * RIDGE_MAX_GAIN if ridge_enabled else 0.0)

	var field := PackedFloat32Array()
	field.resize(padded_size * padded_size)

	for z in range(padded_size):
		var world_z: float = origin_z + float(z) * step
		for x in range(padded_size):
			var world_x: float = origin_x + float(x) * step

			var sample_x: float = world_x
			var sample_z: float = world_z
			if warp_enabled:
				sample_x += warp_noise_x.get_noise_2d(world_x, world_z) * warp_strength
				sample_z += warp_noise_z.get_noise_2d(world_x, world_z) * warp_strength

			var raw: float = (base_noise.get_noise_2d(sample_x, sample_z) + 1.0) * 0.5

			if ridge_enabled and raw > ridge_threshold:
				var ridge: float = clampf(1.0 - absf(ridge_noise.get_noise_2d(sample_x, sample_z)), 0.0, 1.0)
				ridge = pow(ridge, ridge_sharpness)
				var height_factor: float = smoothstep(ridge_threshold, ridge_threshold + 0.3, raw)
				raw += ridge * ridge_blend * height_factor * RIDGE_MAX_GAIN

			raw += ((detail_noise.get_noise_2d(world_x, world_z) + 1.0) * 0.5 - 0.5) * detail_amp

			field[z * padded_size + x] = _normalize_raw(raw, raw_lo, raw_hi)

	return field


## Map the raw signal into [0,1] with 0.5 pinned to the biome's ground plane. Piecewise
## linear and monotone, so it is pointwise in world space and cannot tear a seam.
static func _normalize_raw(raw: float, raw_lo: float, raw_hi: float) -> float:
	const PIVOT: float = 0.5
	if raw <= PIVOT:
		return 0.5 * (raw - raw_lo) / (PIVOT - raw_lo)
	return 0.5 + 0.5 * (raw - PIVOT) / (raw_hi - PIVOT)


## Terrace steep ground into cliff bands. One-ring stencil; the outermost ring of the
## padded tile is left untouched and discarded by _extract_cell.
static func _apply_cliffs(field: PackedFloat32Array, padded_size: int, preset: Dictionary) -> PackedFloat32Array:
	var threshold: float = preset["cliff_threshold"]
	var sharpness: float = preset["cliff_sharpness"]
	var out: PackedFloat32Array = field.duplicate()

	for z in range(1, padded_size - 1):
		for x in range(1, padded_size - 1):
			var idx: int = z * padded_size + x
			var gx: float = (field[idx + 1] - field[idx - 1]) * 0.5
			var gz: float = (field[idx + padded_size] - field[idx - padded_size]) * 0.5
			var grad: float = sqrt(gx * gx + gz * gz)

			if grad <= threshold * 0.5:
				continue

			var h: float = field[idx]
			var levels: float = 8.0 + sharpness * 2.0
			var terraced: float = round(h * levels) / levels
			var blend: float = pow(smoothstep(threshold * 0.5, threshold, grad), 1.0 / sharpness)
			out[idx] = lerpf(h, terraced, blend * 0.4)

	return out


## 3x3 gaussian pass. One-ring stencil, symmetric, so it is seam-safe inside the margin.
static func _smooth(field: PackedFloat32Array, padded_size: int) -> PackedFloat32Array:
	const KERNEL: Array[float] = [
		0.0625, 0.125, 0.0625,
		0.125, 0.25, 0.125,
		0.0625, 0.125, 0.0625
	]
	var out: PackedFloat32Array = field.duplicate()

	for z in range(1, padded_size - 1):
		for x in range(1, padded_size - 1):
			var sum: float = 0.0
			var ki: int = 0
			for kz in range(-1, 2):
				for kx in range(-1, 2):
					sum += field[(z + kz) * padded_size + (x + kx)] * KERNEL[ki]
					ki += 1
			out[z * padded_size + x] = sum

	return out


## Crop the padded tile to the cell, convert normalized samples to world units through
## TerrainConfig, and ramp edges that meet flat neighbours.
static func _extract_cell(
	field: PackedFloat32Array,
	padded_size: int,
	pad: int,
	biome: int,
	blend_edges: Dictionary
) -> PackedFloat32Array:
	var relief: Vector2 = TerrainConfig.biome_relief(biome)
	var min_height: float = relief.x
	var max_height: float = relief.y

	var blend_north: bool = blend_edges.get("north", false)
	var blend_south: bool = blend_edges.get("south", false)
	var blend_east: bool = blend_edges.get("east", false)
	var blend_west: bool = blend_edges.get("west", false)

	var heights := PackedFloat32Array()
	heights.resize(GRID_SIZE * GRID_SIZE)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var n: float = field[(z + pad) * padded_size + (x + pad)]

			var height: float
			if n >= 0.5:
				height = (n - 0.5) * 2.0 * max_height
			else:
				height = (n - 0.5) * 2.0 * absf(min_height)

			var ramp: float = 1.0
			if blend_north and z < BLEND_DISTANCE:
				ramp = minf(ramp, float(z) / float(BLEND_DISTANCE))
			if blend_south and z >= GRID_SIZE - BLEND_DISTANCE:
				ramp = minf(ramp, float(GRID_SIZE - 1 - z) / float(BLEND_DISTANCE))
			if blend_west and x < BLEND_DISTANCE:
				ramp = minf(ramp, float(x) / float(BLEND_DISTANCE))
			if blend_east and x >= GRID_SIZE - BLEND_DISTANCE:
				ramp = minf(ramp, float(GRID_SIZE - 1 - x) / float(BLEND_DISTANCE))

			heights[z * GRID_SIZE + x] = height * ramp

	return heights
