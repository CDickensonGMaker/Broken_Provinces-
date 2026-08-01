## biome_palette.gd - THE ground and vegetation art table for a biome.
##
## Both the wilderness cell generator and the cell streamer's flat-ground fallback read
## from here, so a cell cannot pick one ground under its terrain mesh and another under
## its fallback plane. Biome ordinals are TerrainConfig.Biome; rocky variants resolve
## through TerrainConfig.palette_of and then mix in stone.
class_name BiomePalette
extends RefCounted

const FLOORS := "res://assets/textures/environment/floors/"
const GROUND := "res://assets/sprites/environment/ground/"
const TREE_PACK := "res://assets/sprites/environment/trees/tree_pack_1.1/tree_pack_1.1/models/"

const ROCK_FLOORS: Array[String] = [
	FLOORS + "rockhill_floor1.png",
	FLOORS + "rockhill_floor2.png",
	FLOORS + "rockhill_floor3.png",
]


## Ground textures a biome may tile. Rocky variants get their parent's ground plus stone.
static func floor_textures(biome: int) -> Array[String]:
	var base: Array[String] = _base_floors(TerrainConfig.palette_of(biome))
	if not TerrainConfig.is_rocky(biome):
		return base
	var mixed: Array[String] = base.duplicate()
	mixed.append_array(ROCK_FLOORS)
	return mixed


static func _base_floors(palette: int) -> Array[String]:
	match palette:
		TerrainConfig.Biome.WOODLANDS:
			return [
				FLOORS + "leaves_full.png",
				FLOORS + "leaves_half.png",
				GROUND + "grassland_1.png",
				GROUND + "grassland_2.png",
			]
		TerrainConfig.Biome.GRASSLANDS:
			return [
				FLOORS + "plains_floor1.png",
				FLOORS + "plains_floor2.png",
				FLOORS + "plains_floor3.png",
				GROUND + "grassland_1.png",
			]
		TerrainConfig.Biome.SWAMP:
			return [
				FLOORS + "swamp_flood1.png",
				FLOORS + "swamp_flood2.png",
				FLOORS + "leaves_half.png",
			]
		TerrainConfig.Biome.HILLS:
			return [
				FLOORS + "plains_floor2.png",
				FLOORS + "rockhill_floor1.png",
				GROUND + "grassland_1.png",
			]
		TerrainConfig.Biome.ROCKY:
			return ROCK_FLOORS
		TerrainConfig.Biome.DESERT:
			return [
				FLOORS + "desert_floor1.png",
				FLOORS + "desert_floor2.png",
				FLOORS + "desert_floor3.png",
			]
		TerrainConfig.Biome.WINTER:
			return [
				FLOORS + "winter_floor1.png",
				FLOORS + "winter_floor2.png",
				FLOORS + "winter_floor3.png",
			]
		_:
			return [
				FLOORS + "plains_floor1.png",
				FLOORS + "plains_floor2.png",
			]


## Pick one ground texture deterministically from the cell's own rng.
static func pick_floor_texture(biome: int, rng: RandomNumberGenerator) -> Texture2D:
	var paths: Array[String] = floor_textures(biome)
	if paths.is_empty():
		return null
	var path: String = paths[rng.randi() % paths.size()]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## Same choice without an rng, for callers that only need a representative tile.
static func default_floor_texture(biome: int) -> Texture2D:
	var paths: Array[String] = floor_textures(biome)
	for path: String in paths:
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


## Tree models a biome plants. Winter is fir, desert is cactus; the deciduous biomes draw
## from the 36-model pack.
static func tree_models(biome: int) -> Array[String]:
	match TerrainConfig.palette_of(biome):
		TerrainConfig.Biome.WINTER:
			return ["res://assets/models/trees/fir_001.fbx"]
		TerrainConfig.Biome.DESERT:
			return ["res://assets/models/props/cactus_001.fbx"]
		TerrainConfig.Biome.ROCKY:
			return []
		_:
			return []


## Billboard trees, used where a full model would be too costly. Empty means the biome
## falls back to whatever the caller already uses for its parent biome.
static func billboard_trees(biome: int) -> Array[String]:
	const TREES := "res://assets/sprites/environment/trees/"
	match TerrainConfig.palette_of(biome):
		TerrainConfig.Biome.WOODLANDS:
			return [TREES + "green_tree1.png", TREES + "autumn_tree_1.png", TREES + "autumn_tree_2.png"]
		TerrainConfig.Biome.GRASSLANDS:
			return [TREES + "green_tree1.png", TREES + "barren_bush.png"]
		TerrainConfig.Biome.WINTER:
			return [TREES + "barren_bush.png", TREES + "barren_bush2.png"]
		TerrainConfig.Biome.DESERT:
			return [TREES + "barren_bush.png"]
		_:
			return []


## Trees per cell before zoning thins them. Zero means the biome plants no trees at all.
static func tree_density(biome: int) -> int:
	match TerrainConfig.palette_of(biome):
		TerrainConfig.Biome.WOODLANDS:
			return 40
		TerrainConfig.Biome.GRASSLANDS:
			return 8
		TerrainConfig.Biome.SWAMP:
			return 22
		TerrainConfig.Biome.HILLS:
			return 10
		TerrainConfig.Biome.ROCKY:
			return 2
		TerrainConfig.Biome.DESERT:
			return 5
		TerrainConfig.Biome.WINTER:
			return 18
		_:
			return 10


## Fraction of the biome's tree budget that survives on rocky ground.
static func rocky_density_scale() -> float:
	return 0.45
