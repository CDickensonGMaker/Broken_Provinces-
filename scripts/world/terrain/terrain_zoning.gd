## terrain_zoning.gd - THE ground-cover classifier for wilderness cells.
##
## Every system that decides what grows on a patch of ground - vegetation density,
## species choice, clutter - routes here, so the ground the player sees and the ground
## a system reasons about can never disagree.
##
## Pure function of (height, world position, biome, seed). No global RNG, no per-frame
## draw, no stream order: same seed plus same world position gives the same zone forever,
## and neighbouring cells classify their shared ground identically.
class_name TerrainZoning
extends RefCounted

enum Zone { BARE, OPEN, SCRUB, LIGHT_WOOD, DENSE_WOOD }

## Low ground is the low fraction of THIS biome's own relief, not an absolute height.
## Reading it from TerrainConfig rather than scanning a heightmap keeps the classifier
## pure - a scan would make the answer depend on which cells happen to be loaded.
const LOWLAND_RELIEF_FRACTION: float = 0.18

## Patch noise carves coherent thickets and clearings instead of per-vertex speckle.
const PATCH_FREQUENCY: float = 0.010
const MOISTURE_FREQUENCY: float = 0.006

## Cover thresholds against the patch field, ordered BARE -> DENSE_WOOD. A biome shifts
## the whole ladder by its cover bias: negative opens the ground up, positive closes it in.
const OPEN_THRESHOLD: float = -0.37
const SCRUB_THRESHOLD: float = -0.16
const LIGHT_THRESHOLD: float = 0.19

static var _patch_noise: FastNoiseLite = null
static var _moisture_noise: FastNoiseLite = null
static var _noise_seed: int = 0


## How far a biome shifts the cover ladder. Woodland closes in, dune country opens out.
static func cover_bias(biome: int) -> float:
	match TerrainConfig.palette_of(biome):
		TerrainConfig.Biome.WOODLANDS:
			return 0.22
		TerrainConfig.Biome.GRASSLANDS:
			return -0.12
		TerrainConfig.Biome.SWAMP:
			return 0.10
		TerrainConfig.Biome.HILLS:
			return -0.05
		TerrainConfig.Biome.ROCKY:
			return -0.30
		TerrainConfig.Biome.DESERT:
			return -0.45
		TerrainConfig.Biome.WINTER:
			return -0.10
		_:
			return 0.0


static func classify(height: float, world_x: float, world_z: float, biome: int, world_seed: int) -> int:
	var relief: Vector2 = TerrainConfig.biome_relief(biome)
	var lowland_ceiling: float = relief.x + LOWLAND_RELIEF_FRACTION * (relief.y - relief.x)

	var bias: float = cover_bias(biome)
	var patch: float = _patch_field(world_seed).get_noise_2d(world_x, world_z) + bias

	# Rocky variants strip cover off exposed high ground - bare stone, not thicket.
	if TerrainConfig.is_rocky(biome) and height > relief.y * 0.55:
		return Zone.BARE if patch > SCRUB_THRESHOLD else Zone.OPEN

	if height < lowland_ceiling:
		var moisture: float = _moisture_field(world_seed).get_noise_2d(world_x, world_z)
		return Zone.OPEN if moisture < 0.02 else Zone.SCRUB

	if patch < OPEN_THRESHOLD:
		return Zone.OPEN
	if patch < SCRUB_THRESHOLD:
		return Zone.SCRUB
	if patch < LIGHT_THRESHOLD:
		return Zone.LIGHT_WOOD
	return Zone.DENSE_WOOD


static func reset() -> void:
	_patch_noise = null
	_moisture_noise = null
	_noise_seed = 0


static func _patch_field(world_seed: int) -> FastNoiseLite:
	if _patch_noise == null or _noise_seed != world_seed:
		_rebuild(world_seed)
	return _patch_noise


static func _moisture_field(world_seed: int) -> FastNoiseLite:
	if _moisture_noise == null or _noise_seed != world_seed:
		_rebuild(world_seed)
	return _moisture_noise


## Both fields share the seed guard so one rebuild reseeds them coherently.
static func _rebuild(world_seed: int) -> void:
	_patch_noise = FastNoiseLite.new()
	_patch_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_patch_noise.frequency = PATCH_FREQUENCY
	_patch_noise.seed = world_seed
	_moisture_noise = FastNoiseLite.new()
	_moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_moisture_noise.frequency = MOISTURE_FREQUENCY
	_moisture_noise.seed = world_seed + 917
	_noise_seed = world_seed
