## terrain_flatten.gd - THE world-space flatten field for wilderness terrain.
##
## Hand-built places and roads need level ground. Until 8/2 that was a binary
## per-cell switch in WildernessRoom: a road cell, a cell covered by a scene, or a
## cell merely ADJACENT to one, got a flat slab instead of a heightfield. Around
## Elder Moor that is nine cells at once - every direction Caleb walked out of the
## starting town was flat, and the terrain generator was blamed for it.
##
## This replaces the switch with a field. `factor()` returns 1.0 where the full
## heightfield stands, 0.0 where the ground must be level, and a smooth ramp in
## between. The heightfield is multiplied by it, so a town sits in a bowl of its
## own making and the hills start where the town stops.
##
## SEAM CONTRACT. The factor is a pure function of WORLD position - never of which
## cell asked - so two cells sampling their shared boundary vertex get the same
## float, bit for bit. `build_sources()` gathers a 7x7 cell neighbourhood, which is
## wider than any source's reach (a cell's influence ends 50 + SCENE_MARGIN units
## from its centre, and a vertex is at most 50 units from its own cell's centre), so
## the two cells' source lists differ only by entries that return 1.0 and cannot
## move the minimum.
class_name TerrainFlatten
extends RefCounted


## How far past a hand-built scene's footprint the ground takes to reach full relief.
const SCENE_MARGIN: float = 55.0

## Half-width of the level ribbon a road carves. The road mesh is 8 units wide; the
## ribbon is a little wider so the verge is flat too.
const ROAD_HALF_WIDTH: float = 7.0

## How far past the ribbon the ground takes to reach full relief.
const ROAD_MARGIN: float = 18.0

## Impassable cells are walls, not places. They flatten over a shorter margin.
const BLOCKED_MARGIN: float = 30.0

## Level ground under a hand-built scene sits this far below the cell plane, so the
## scene's own floor wins the depth test. Scaled by the flatten factor, so it is only
## felt where the ground is already flat.
const SCENE_SINK: float = 0.05

## Cell radius gathered by build_sources(). See the seam contract above.
const SOURCE_RADIUS: int = 3

enum Kind { AREA, RIBBON }

## The world grid, reached through its SCRIPT rather than the autoload identifier.
## WorldGrid is an autoload with no class_name, so the bare identifier does not
## resolve inside a static function; its whole API is static and its cell table is a
## static var, so the preloaded script is the same data the autoload serves.
const WorldGridScript := preload("res://scripts/core/world_grid.gd")

const CELL_SIZE: float = WorldGridScript.CELL_SIZE


## Gather every flatten source that can reach any vertex of the given cell.
## Returns an array of source dictionaries for factor_from().
static func build_sources(cell_x: int, cell_z: int) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var size: float = CELL_SIZE

	for dz: int in range(-SOURCE_RADIUS, SOURCE_RADIUS + 1):
		for dx: int in range(-SOURCE_RADIUS, SOURCE_RADIUS + 1):
			var coords := Vector2i(cell_x + dx, cell_z + dz)
			var centre := Vector2(float(coords.x) * size, float(coords.y) * size)
			var info: WorldGridScript.CellInfo = WorldGridScript.get_cell(coords)

			if info == null:
				# Off the edge of the world. The old code treated out-of-bounds as
				# flat, and the map's rim is mountain and open water either way.
				sources.append({
					"kind": Kind.AREA,
					"centre": centre,
					"half": Vector2(size * 0.5, size * 0.5),
					"margin": BLOCKED_MARGIN,
				})
				continue

			if info.scene_path != "":
				var half: Vector2 = info.scene_size * 0.5
				sources.append({
					"kind": Kind.AREA,
					"centre": centre,
					"half": Vector2(maxf(half.x, size * 0.5), maxf(half.y, size * 0.5)),
					"margin": SCENE_MARGIN,
				})
			elif not info.passable:
				sources.append({
					"kind": Kind.AREA,
					"centre": centre,
					"half": Vector2(size * 0.5, size * 0.5),
					"margin": BLOCKED_MARGIN,
				})

			if info.is_road:
				sources.append({
					"kind": Kind.RIBBON,
					"centre": centre,
					"arms": _road_arms(coords),
					"margin": ROAD_MARGIN,
				})

	return sources


## The flatten factor at a world position: 1.0 full relief, 0.0 level ground.
static func factor_from(sources: Array[Dictionary], world_x: float, world_z: float) -> float:
	var p := Vector2(world_x, world_z)
	var lowest: float = 1.0

	for source: Dictionary in sources:
		var distance: float
		if int(source["kind"]) == Kind.AREA:
			distance = _box_distance(p, source["centre"], source["half"])
		else:
			distance = _ribbon_distance(p, source["centre"], source["arms"])

		if distance <= 0.0:
			return 0.0

		var margin: float = source["margin"]
		lowest = minf(lowest, smoothstep(0.0, margin, distance))
		if lowest <= 0.0:
			return 0.0

	return lowest


## Convenience for probes and one-off queries: gathers sources for the cell that
## contains the position, then evaluates. Do not call this per vertex.
static func factor(world_x: float, world_z: float) -> float:
	var cell_x: int = int(floor((world_x + CELL_SIZE * 0.5) / CELL_SIZE))
	var cell_z: int = int(floor((world_z + CELL_SIZE * 0.5) / CELL_SIZE))
	return factor_from(build_sources(cell_x, cell_z), world_x, world_z)


## Half-cell arms from a road cell's centre toward each neighbouring road cell. A
## road cell with no road neighbours keeps only the disc at its centre.
static func _road_arms(coords: Vector2i) -> Array[Vector2]:
	var arms: Array[Vector2] = []
	var reach: float = CELL_SIZE * 0.5
	var directions: Array[Vector2i] = [
		Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0)
	]
	for direction: Vector2i in directions:
		if WorldGridScript.is_road(coords + direction):
			arms.append(Vector2(float(direction.x), float(direction.y)) * reach)
	return arms


## Distance from a point to an axis-aligned box. Zero inside.
static func _box_distance(p: Vector2, centre: Vector2, half: Vector2) -> float:
	var d := Vector2(absf(p.x - centre.x) - half.x, absf(p.y - centre.y) - half.y)
	return Vector2(maxf(d.x, 0.0), maxf(d.y, 0.0)).length()


## Distance from a point to a road ribbon: the arms plus the junction disc, all
## fattened by ROAD_HALF_WIDTH. Zero on the ribbon.
static func _ribbon_distance(p: Vector2, centre: Vector2, arms: Array) -> float:
	var nearest: float = p.distance_to(centre)
	for arm: Vector2 in arms:
		nearest = minf(nearest, _segment_distance(p, centre, centre + arm))
	return maxf(nearest - ROAD_HALF_WIDTH, 0.0)


static func _segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var length_sq: float = ab.length_squared()
	if length_sq <= 0.0:
		return p.distance_to(a)
	var t: float = clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
