## terrain_config.gd - THE vertical scale contract for wilderness terrain.
##
## `WORLD_HEIGHT_MAX` is the ceiling, in world units, that any biome's peak may reach
## above the cell's ground plane. Every conversion between normalized generator output
## and world units resolves here, and nothing else may declare a height scale.
##
## The per-biome relief table lives beside the cap because the two are one unit:
## `biome_relief(b).y` must stay <= `WORLD_HEIGHT_MAX`, so a biome can never be raised
## without checking it against the cap in the same file.
class_name TerrainConfig
extends RefCounted


## World units. A cell is 100 units across; anything taller than this stops reading as
## walkable ground and starts reading as a wall.
const WORLD_HEIGHT_MAX: float = 24.0


## Biome ordinals. These match WildernessRoom.Biome and are APPEND-ONLY: existing saves
## and World Forge maps store the integer, so no value may be reordered or reused.
enum Biome {
	WOODLANDS,        # 0 - deciduous European forest
	GRASSLANDS,       # 1 - open pasture and meadow
	SWAMP,            # 2 - fen, standing water
	HILLS,            # 3 - downland
	ROCKY,            # 4 - bare stone
	DESERT,           # 5 - dune country
	ROCKY_WOODLANDS,  # 6 - forested crags
	ROCKY_GRASSLANDS, # 7 - upland pasture on rock
	WINTER,           # 8 - snowfield
	ROCKY_WINTER,     # 9 - alpine peaks
	ROCKY_DESERT,     # 10 - mesa and butte
}


## Peak-to-valley relief for a biome, in world units: x = lowest point below the cell
## ground plane (negative), y = highest point above it. Asserted by tools/probes/terrain_probe.gd.
static func biome_relief(biome: int) -> Vector2:
	match biome:
		Biome.WOODLANDS:
			return Vector2(-0.5, 4.0)
		Biome.GRASSLANDS:
			return Vector2(-0.3, 2.0)
		Biome.SWAMP:
			return Vector2(-1.5, 1.5)
		Biome.HILLS:
			return Vector2(-1.0, 8.0)
		Biome.ROCKY:
			return Vector2(0.0, 6.0)
		Biome.DESERT:
			return Vector2(-0.5, 3.0)
		Biome.ROCKY_WOODLANDS:
			return Vector2(-1.0, 11.0)
		Biome.ROCKY_GRASSLANDS:
			return Vector2(-1.0, 9.0)
		Biome.WINTER:
			return Vector2(-0.5, 3.5)
		Biome.ROCKY_WINTER:
			return Vector2(-1.0, 12.0)
		Biome.ROCKY_DESERT:
			return Vector2(-1.0, 10.0)
		_:
			return Vector2(-0.3, 2.0)


## True when the biome is one of the rocky variants, which share a base palette with
## their parent biome but generate mountain relief.
static func is_rocky(biome: int) -> bool:
	return biome == Biome.ROCKY \
		or biome == Biome.ROCKY_WOODLANDS \
		or biome == Biome.ROCKY_GRASSLANDS \
		or biome == Biome.ROCKY_WINTER \
		or biome == Biome.ROCKY_DESERT


## The palette a biome draws its ground and vegetation from. Rocky variants resolve to
## their parent so texture and species tables are declared once.
static func palette_of(biome: int) -> int:
	match biome:
		Biome.ROCKY_WOODLANDS:
			return Biome.WOODLANDS
		Biome.ROCKY_GRASSLANDS:
			return Biome.GRASSLANDS
		Biome.ROCKY_WINTER:
			return Biome.WINTER
		Biome.ROCKY_DESERT:
			return Biome.DESERT
		_:
			return biome
