extends SceneTree
## Wilderness terrain render probe - writes heightfield images so the ground can be
## looked at rather than argued about.
##
## Usage:
##   godot --headless --path . --script res://tools/probes/terrain_render.gd -- --out <dir>
##
## For each subject it writes one PNG: a hillshaded relief map of a 3x3 block of cells
## sampled at four times the generator's grid, with the cell boundaries drawn in. A
## seam that tears shows as a hard line on a boundary; flat ground shows as flat.
##
## Subjects are three biomes over open wilderness, plus the block of cells around Elder
## Moor - the town-edge case that was flat in every direction in the 8/2 playtest.

const SUPERSAMPLE: int = 4
const BLOCK: int = 3


func _init() -> void:
	var out_dir: String = "user://terrain_render"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))

	var subjects: Array[Dictionary] = [
		{"name": "woodlands", "biome": TerrainConfig.Biome.WOODLANDS, "cell": Vector2i(-3, 3)},
		{"name": "hills", "biome": TerrainConfig.Biome.HILLS, "cell": Vector2i(-3, 3)},
		{"name": "rocky_woodlands", "biome": TerrainConfig.Biome.ROCKY_WOODLANDS, "cell": Vector2i(-3, 3)},
		{"name": "elder_moor_edge", "biome": TerrainConfig.Biome.WOODLANDS, "cell": Vector2i(0, 0)},
	]

	for subject: Dictionary in subjects:
		var path: String = "%s/%s.png" % [out_dir, subject["name"]]
		var span: Vector2 = _render(subject["cell"], int(subject["biome"]), path)
		print("%-18s cells %s  relief %6.2f .. %6.2f  -> %s" % [
			subject["name"], str(subject["cell"]), span.x, span.y, ProjectSettings.globalize_path(path)
		])

	quit(0)


## Render a BLOCK x BLOCK cell neighbourhood centred on `centre`. Returns min/max height.
func _render(centre: Vector2i, biome: int, path: String) -> Vector2:
	var g: int = TerrainGenerator.GRID_SIZE
	var size: float = TerrainGenerator.CELL_SIZE
	var per_cell: int = (g - 1) * SUPERSAMPLE
	var pixels: int = per_cell * BLOCK

	var fields: Dictionary = {}
	for dz: int in range(BLOCK):
		for dx: int in range(BLOCK):
			var coords := Vector2i(centre.x + dx - 1, centre.y + dz - 1)
			fields[coords] = TerrainGenerator.generate_heights(coords.x, coords.y, biome)

	var heights := PackedFloat32Array()
	heights.resize(pixels * pixels)
	var min_h: float = INF
	var max_h: float = -INF

	var origin_x: float = float(centre.x - 1) * size - size * 0.5
	var origin_z: float = float(centre.y - 1) * size - size * 0.5
	var step: float = size / float(per_cell)

	for py in range(pixels):
		var world_z: float = origin_z + float(py) * step
		for px in range(pixels):
			var world_x: float = origin_x + float(px) * step
			var cell_x: int = int(floor((world_x + size * 0.5) / size))
			var cell_z: int = int(floor((world_z + size * 0.5) / size))
			var field: PackedFloat32Array = fields.get(Vector2i(cell_x, cell_z), PackedFloat32Array())
			var h: float = 0.0
			if not field.is_empty():
				h = TerrainGenerator.height_at(
					field,
					world_x - float(cell_x) * size,
					world_z - float(cell_z) * size
				)
			heights[py * pixels + px] = h
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)

	var image := Image.create(pixels, pixels, false, Image.FORMAT_RGB8)
	var range_h: float = maxf(max_h - min_h, 0.001)

	for py in range(pixels):
		for px in range(pixels):
			var h: float = heights[py * pixels + px]
			var tone: float = (h - min_h) / range_h

			# Hillshade from the local gradient, so shape reads even when relief is low.
			var xl: int = maxi(px - 1, 0)
			var xr: int = mini(px + 1, pixels - 1)
			var zu: int = maxi(py - 1, 0)
			var zd: int = mini(py + 1, pixels - 1)
			var gx: float = (heights[py * pixels + xr] - heights[py * pixels + xl]) / (2.0 * step)
			var gz: float = (heights[zd * pixels + px] - heights[zu * pixels + px]) / (2.0 * step)
			var normal: Vector3 = Vector3(-gx, 1.0, -gz).normalized()
			var light: float = clampf(normal.dot(Vector3(0.45, 0.75, 0.49).normalized()), 0.0, 1.0)

			var value: float = clampf(0.25 + 0.45 * tone + 0.55 * light - 0.4, 0.0, 1.0)
			var colour := Color(value, value * 0.98, value * 0.92)

			# Cell boundaries in red, so a torn seam is unmistakable.
			if px % per_cell == 0 or py % per_cell == 0:
				colour = Color(0.85, 0.15, 0.15)

			image.set_pixel(px, py, colour)

	image.save_png(path)
	return Vector2(min_h, max_h)
