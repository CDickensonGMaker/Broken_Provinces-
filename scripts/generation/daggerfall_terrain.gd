## daggerfall_terrain.gd - Daggerfall-style discrete height terrain generation
## Creates PS1-appropriate stepped terrain with low vertex count
## Uses discrete height levels for authentic retro aesthetic
class_name DaggerfallTerrain
extends RefCounted


## Grid configuration - higher resolution for walkable slopes
const GRID_SIZE: int = 17          # 17x17 vertices per cell (289 total, still low poly)
const HEIGHT_LEVELS: int = 5       # Discrete height tiers: 0, 1, 2, 3, 4
const HEIGHT_STEP: float = 0.25    # Units between levels (max height 1.0) - very gentle slopes
const CELL_SIZE: float = 100.0     # World units per cell

## Noise settings - coarser for blockier terrain
const NOISE_FREQUENCY: float = 0.008  # Lower = larger features
const NOISE_SEED: int = 42069         # Fixed seed for seamless cells

## Smoothing settings
const SMOOTH_PASSES: int = 4       # Number of smoothing passes (more = gentler slopes)
const SMOOTH_FACTOR: float = 0.5   # How much neighbors influence height (0-1)


## Generate complete terrain for a cell
## Returns: Dictionary with "node" (Node3D), "heights" (PackedFloat32Array)
static func generate(
	cell_x: int,
	cell_z: int,
	biome: int,
	material: Material = null
) -> Dictionary:
	# Generate height grid
	var heights: PackedFloat32Array = _generate_height_grid(cell_x, cell_z)

	# Create root node
	var root := Node3D.new()
	root.name = "DaggerfallTerrain"

	# Create and add mesh
	var mesh_instance: MeshInstance3D = _create_mesh(heights, material)
	root.add_child(mesh_instance)

	# Create and add collision
	var collision: StaticBody3D = _create_collision(heights)
	root.add_child(collision)

	# Store heights as metadata for external access
	root.set_meta("heights", heights)
	root.set_meta("grid_size", GRID_SIZE)
	root.set_meta("cell_size", CELL_SIZE)

	return {
		"node": root,
		"heights": heights
	}


## Get height at local position (for prop placement)
## Uses bilinear interpolation between grid points
static func get_height_at(
	heights: PackedFloat32Array,
	local_x: float,
	local_z: float
) -> float:
	var half_size: float = CELL_SIZE * 0.5
	var step: float = CELL_SIZE / (GRID_SIZE - 1)

	# Convert local position to grid position
	var grid_x: float = (local_x + half_size) / step
	var grid_z: float = (local_z + half_size) / step

	# Clamp to valid range
	grid_x = clampf(grid_x, 0.0, GRID_SIZE - 1.0)
	grid_z = clampf(grid_z, 0.0, GRID_SIZE - 1.0)

	# Get integer grid coordinates
	var x0: int = int(grid_x)
	var z0: int = int(grid_z)
	var x1: int = mini(x0 + 1, GRID_SIZE - 1)
	var z1: int = mini(z0 + 1, GRID_SIZE - 1)

	# Get fractional parts for interpolation
	var fx: float = grid_x - x0
	var fz: float = grid_z - z0

	# Get heights at four corners
	var h00: float = heights[z0 * GRID_SIZE + x0]
	var h10: float = heights[z0 * GRID_SIZE + x1]
	var h01: float = heights[z1 * GRID_SIZE + x0]
	var h11: float = heights[z1 * GRID_SIZE + x1]

	# Bilinear interpolation
	var h0: float = lerpf(h00, h10, fx)
	var h1: float = lerpf(h01, h11, fx)
	return lerpf(h0, h1, fz)


## Generate discrete height grid
## Uses noise quantized to discrete levels for Daggerfall aesthetic
static func _generate_height_grid(cell_x: int, cell_z: int) -> PackedFloat32Array:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = NOISE_FREQUENCY
	noise.fractal_octaves = 2
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.4
	noise.seed = NOISE_SEED

	var heights := PackedFloat32Array()
	heights.resize(GRID_SIZE * GRID_SIZE)

	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var world_offset_x: float = cell_x * CELL_SIZE
	var world_offset_z: float = cell_z * CELL_SIZE

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var world_x: float = world_offset_x + x * step
			var world_z: float = world_offset_z + z * step

			# Get noise value (-1 to 1)
			var noise_value: float = noise.get_noise_2d(world_x, world_z)

			# Quantize to discrete height level
			var height: float = _quantize_height(noise_value)
			heights[z * GRID_SIZE + x] = height

	# Apply smoothing passes for gradual transitions
	for pass_num in range(SMOOTH_PASSES):
		heights = _smooth_heights(heights)

	return heights


## Apply smoothing pass to blend neighboring heights
static func _smooth_heights(heights: PackedFloat32Array) -> PackedFloat32Array:
	var smoothed := PackedFloat32Array()
	smoothed.resize(GRID_SIZE * GRID_SIZE)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var idx: int = z * GRID_SIZE + x
			var current: float = heights[idx]

			# Get neighbor heights (with edge clamping)
			var sum: float = 0.0
			var count: int = 0

			for dz in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					var nx: int = clampi(x + dx, 0, GRID_SIZE - 1)
					var nz: int = clampi(z + dz, 0, GRID_SIZE - 1)
					sum += heights[nz * GRID_SIZE + nx]
					count += 1

			var neighbor_avg: float = sum / count
			# Blend current height with neighbor average
			smoothed[idx] = lerpf(current, neighbor_avg, SMOOTH_FACTOR)

	return smoothed


## Quantize continuous noise value to discrete height level
## Maps -1.0 to 1.0 range to discrete levels
static func _quantize_height(noise_value: float) -> float:
	# Map noise (-1 to 1) to (0 to 1) range
	var normalized: float = (noise_value + 1.0) * 0.5

	# Quantize to level index (0, 1, 2, 3, 4)
	var level: int = int(normalized * HEIGHT_LEVELS)
	level = clampi(level, 0, HEIGHT_LEVELS - 1)

	# Return actual height value
	return level * HEIGHT_STEP


## Create mesh from height grid
## Builds low-poly terrain with 8x8 quads (128 triangles)
static func _create_mesh(
	heights: PackedFloat32Array,
	material: Material
) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var half_size: float = CELL_SIZE * 0.5

	# Generate vertices (9x9 = 81)
	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var height: float = heights[z * GRID_SIZE + x]
			vertices.append(Vector3(
				x * step - half_size,
				height,
				z * step - half_size
			))
			uvs.append(Vector2(
				float(x) / (GRID_SIZE - 1),
				float(z) / (GRID_SIZE - 1)
			))

	# Generate indices for quads
	for z in range(GRID_SIZE - 1):
		for x in range(GRID_SIZE - 1):
			var tl: int = z * GRID_SIZE + x
			var tr: int = tl + 1
			var bl: int = (z + 1) * GRID_SIZE + x
			var br: int = bl + 1

			# Two triangles per quad - CCW winding when viewed from above (+Y looking down)
			# Triangle 1: tl -> tr -> bl
			indices.append(tl)
			indices.append(tr)
			indices.append(bl)

			# Triangle 2: tr -> br -> bl
			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	# Calculate normals - start with up vector
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

	# Compute face normals and accumulate at vertices
	# For CCW winding (tl->tr->bl), use (v1-v0).cross(v2-v0) for upward normals
	for i in range(0, indices.size(), 3):
		var i0: int = indices[i]
		var i1: int = indices[i + 1]
		var i2: int = indices[i + 2]

		var v0: Vector3 = vertices[i0]
		var v1: Vector3 = vertices[i1]
		var v2: Vector3 = vertices[i2]

		var normal: Vector3 = (v1 - v0).cross(v2 - v0).normalized()

		normals[i0] += normal
		normals[i1] += normal
		normals[i2] += normal

	# Normalize accumulated normals
	for i in range(normals.size()):
		if normals[i].length_squared() > 0.0001:
			normals[i] = normals[i].normalized()
		else:
			normals[i] = Vector3.UP

	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Terrain"
	mesh_instance.mesh = mesh
	if material:
		mesh_instance.material_override = material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	return mesh_instance


## Create collision from height grid
## Uses ConcavePolygonShape3D (trimesh) to exactly match visual geometry
static func _create_collision(heights: PackedFloat32Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.collision_layer = 1
	body.collision_mask = 0

	var faces := PackedVector3Array()
	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var half_size: float = CELL_SIZE * 0.5

	# Build triangle faces for collision (same geometry as mesh)
	for z in range(GRID_SIZE - 1):
		for x in range(GRID_SIZE - 1):
			var tl := Vector3(
				x * step - half_size,
				heights[z * GRID_SIZE + x],
				z * step - half_size
			)
			var tr := Vector3(
				(x + 1) * step - half_size,
				heights[z * GRID_SIZE + (x + 1)],
				z * step - half_size
			)
			var bl := Vector3(
				x * step - half_size,
				heights[(z + 1) * GRID_SIZE + x],
				(z + 1) * step - half_size
			)
			var br := Vector3(
				(x + 1) * step - half_size,
				heights[(z + 1) * GRID_SIZE + (x + 1)],
				(z + 1) * step - half_size
			)

			# Triangle 1 - same winding as mesh for collision
			faces.append(tl)
			faces.append(tr)
			faces.append(bl)

			# Triangle 2 - same winding as mesh
			faces.append(tr)
			faces.append(br)
			faces.append(bl)

	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	collision.shape = shape
	body.add_child(collision)

	return body
