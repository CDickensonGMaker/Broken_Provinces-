## enhanced_terrain.gd - Advanced terrain generation using TerrainEngine algorithms
## Integrates domain warping, ridged multifractal, and biome-based presets
## while maintaining compatibility with the cell-based streaming system.
##
## Based on TerrainEngine from C:\Users\caleb\TerrainEngine
## Adapted for 100x100 unit cells with 17x17 vertex grids
class_name EnhancedTerrain
extends RefCounted


## Grid configuration (same as DaggerfallTerrain for compatibility)
const GRID_SIZE: int = 17          # 17x17 vertices per cell (289 total)
const CELL_SIZE: float = 100.0     # World units per cell

## Height settings per biome
const HEIGHT_SETTINGS: Dictionary = {
	# Biome -> {max_height, min_height}
	0: {"max": 4.0, "min": -0.5},   # FOREST - moderate hills
	1: {"max": 2.0, "min": -0.3},   # PLAINS - gentle rolling
	2: {"max": 1.5, "min": -1.5},   # SWAMP - low with water depressions
	3: {"max": 8.0, "min": -1.0},   # HILLS - dramatic terrain
	4: {"max": 6.0, "min": 0.0},    # ROCKY - elevated, rough
	5: {"max": 3.0, "min": -0.5},   # DESERT - sandy dunes
}

## Edge blending settings
const BLEND_DISTANCE: int = 4

## Biome to terrain preset mapping
## Maps WildernessRoom.Biome enum values to generation parameters
const BIOME_PRESETS: Dictionary = {
	0: {  # FOREST - Rolling hills with organic shapes
		"base_frequency": 0.008,
		"base_octaves": 4,
		"warp_enabled": true,
		"warp_strength": 25.0,
		"warp_frequency": 0.012,
		"ridge_enabled": true,
		"ridge_blend": 0.2,
		"ridge_threshold": 0.4,
		"ridge_sharpness": 1.5,
		"detail_frequency": 0.03,
		"detail_amplitude": 0.06,
	},
	1: {  # PLAINS - Gentle, smooth terrain
		"base_frequency": 0.005,
		"base_octaves": 3,
		"warp_enabled": true,
		"warp_strength": 15.0,
		"warp_frequency": 0.008,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.02,
		"detail_amplitude": 0.03,
	},
	2: {  # SWAMP - Low, wet terrain with shallow pools
		"base_frequency": 0.006,
		"base_octaves": 3,
		"warp_enabled": true,
		"warp_strength": 20.0,
		"warp_frequency": 0.015,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.025,
		"detail_amplitude": 0.08,
	},
	3: {  # HILLS - Dramatic terrain with ridges
		"base_frequency": 0.012,
		"base_octaves": 5,
		"warp_enabled": true,
		"warp_strength": 40.0,
		"warp_frequency": 0.01,
		"ridge_enabled": true,
		"ridge_blend": 0.5,
		"ridge_threshold": 0.25,
		"ridge_sharpness": 2.5,
		"detail_frequency": 0.04,
		"detail_amplitude": 0.1,
	},
	4: {  # ROCKY - Elevated plateau with cliff edges
		"base_frequency": 0.01,
		"base_octaves": 4,
		"warp_enabled": false,
		"warp_strength": 0.0,
		"warp_frequency": 0.01,
		"ridge_enabled": true,
		"ridge_blend": 0.4,
		"ridge_threshold": 0.2,
		"ridge_sharpness": 3.0,
		"detail_frequency": 0.05,
		"detail_amplitude": 0.12,
	},
	5: {  # DESERT - Sandy dunes with soft rolling shapes
		"base_frequency": 0.006,
		"base_octaves": 3,
		"warp_enabled": true,
		"warp_strength": 35.0,
		"warp_frequency": 0.008,
		"ridge_enabled": false,
		"ridge_blend": 0.0,
		"ridge_threshold": 0.5,
		"ridge_sharpness": 1.0,
		"detail_frequency": 0.015,
		"detail_amplitude": 0.04,
	},
}

## Fixed seed for deterministic world generation
const NOISE_SEED: int = 42069


## Generate complete terrain for a cell
## API compatible with DaggerfallTerrain.generate()
## blend_edges: Dictionary with "north", "south", "east", "west" bools
## Returns: Dictionary with "node" (Node3D), "heights" (PackedFloat32Array)
static func generate(
	cell_x: int,
	cell_z: int,
	biome: int,
	material: Material = null,
	blend_edges: Dictionary = {}
) -> Dictionary:
	# Generate height grid with advanced algorithms
	var heights: PackedFloat32Array = _generate_height_grid(cell_x, cell_z, biome, blend_edges)

	# Create root node
	var root := Node3D.new()
	root.name = "EnhancedTerrain"

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
## API compatible with DaggerfallTerrain.get_height_at()
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


## Generate height grid using advanced algorithms from TerrainEngine
## Features: Domain warping, ridged multifractal noise, biome-based presets
static func _generate_height_grid(
	cell_x: int,
	cell_z: int,
	biome: int,
	blend_edges: Dictionary = {}
) -> PackedFloat32Array:
	# Get biome preset (default to PLAINS if unknown)
	var preset: Dictionary = BIOME_PRESETS.get(biome, BIOME_PRESETS[1])
	var height_cfg: Dictionary = HEIGHT_SETTINGS.get(biome, HEIGHT_SETTINGS[1])
	var max_height: float = height_cfg["max"]
	var min_height: float = height_cfg["min"]

	# Initialize noise generators
	var base_noise := FastNoiseLite.new()
	base_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	base_noise.frequency = preset["base_frequency"]
	base_noise.fractal_octaves = preset["base_octaves"]
	base_noise.fractal_lacunarity = 2.0
	base_noise.fractal_gain = 0.5
	base_noise.seed = NOISE_SEED

	# Domain warping noise (two separate for X and Y offsets)
	var warp_noise_x := FastNoiseLite.new()
	warp_noise_x.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise_x.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_x.fractal_octaves = 3
	warp_noise_x.frequency = preset["warp_frequency"]
	warp_noise_x.seed = NOISE_SEED + 100

	var warp_noise_y := FastNoiseLite.new()
	warp_noise_y.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp_noise_y.fractal_type = FastNoiseLite.FRACTAL_FBM
	warp_noise_y.fractal_octaves = 3
	warp_noise_y.frequency = preset["warp_frequency"]
	warp_noise_y.seed = NOISE_SEED + 200

	# Ridged multifractal noise
	var ridge_noise := FastNoiseLite.new()
	ridge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ridge_noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge_noise.frequency = preset["base_frequency"] * 1.5
	ridge_noise.fractal_octaves = 4
	ridge_noise.seed = NOISE_SEED + 300

	# Detail noise
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail_noise.fractal_octaves = 3
	detail_noise.frequency = preset["detail_frequency"]
	detail_noise.seed = NOISE_SEED + 400

	var heights := PackedFloat32Array()
	heights.resize(GRID_SIZE * GRID_SIZE)

	var step: float = CELL_SIZE / (GRID_SIZE - 1)
	var warp_enabled: bool = preset["warp_enabled"]
	var warp_strength: float = preset["warp_strength"]
	var ridge_enabled: bool = preset["ridge_enabled"]
	var ridge_blend: float = preset["ridge_blend"]
	var ridge_threshold: float = preset["ridge_threshold"]
	var ridge_sharpness: float = preset["ridge_sharpness"]
	var detail_amp: float = preset["detail_amplitude"]

	# Get blend flags
	var blend_north: bool = blend_edges.get("north", false)
	var blend_south: bool = blend_edges.get("south", false)
	var blend_east: bool = blend_edges.get("east", false)
	var blend_west: bool = blend_edges.get("west", false)

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			# Calculate world-space coordinates
			var world_x: float = cell_x * CELL_SIZE + x * step
			var world_z: float = cell_z * CELL_SIZE + z * step

			var sample_x: float = world_x
			var sample_z: float = world_z

			# Apply domain warping if enabled
			if warp_enabled:
				var warp_x: float = warp_noise_x.get_noise_2d(world_x, world_z) * warp_strength
				var warp_z: float = warp_noise_y.get_noise_2d(world_x, world_z) * warp_strength
				sample_x += warp_x
				sample_z += warp_z

			# Sample base noise (returns -1 to 1)
			var base_height: float = base_noise.get_noise_2d(sample_x, sample_z)
			base_height = (base_height + 1.0) * 0.5  # Normalize to 0-1

			# Apply ridged multifractal for mountain ridges
			if ridge_enabled and base_height > ridge_threshold:
				var ridge: float = ridge_noise.get_noise_2d(sample_x, sample_z)
				# Transform to ridged multifractal
				ridge = abs(ridge)
				ridge = 1.0 - ridge
				ridge = pow(ridge, ridge_sharpness)

				# Height-dependent blending
				var height_factor: float = smoothstep(ridge_threshold, ridge_threshold + 0.3, base_height)
				var blend: float = ridge_blend * height_factor
				base_height = base_height + ridge * blend * 0.3

			# Add detail noise
			var detail: float = detail_noise.get_noise_2d(world_x, world_z)
			detail = (detail + 1.0) * 0.5 - 0.5  # Center around 0
			base_height += detail * detail_amp

			# Clamp to 0-1 range
			base_height = clampf(base_height, 0.0, 1.0)

			# Map to height range
			var height: float
			if base_height >= 0.5:
				height = (base_height - 0.5) * 2.0 * max_height  # 0 to max_height
			else:
				height = (base_height - 0.5) * 2.0 * absf(min_height)  # min_height to 0

			# Apply edge blending for flat neighbors
			var blend: float = 1.0

			if blend_north and z < BLEND_DISTANCE:
				blend = minf(blend, float(z) / float(BLEND_DISTANCE))

			if blend_south and z >= GRID_SIZE - BLEND_DISTANCE:
				blend = minf(blend, float(GRID_SIZE - 1 - z) / float(BLEND_DISTANCE))

			if blend_west and x < BLEND_DISTANCE:
				blend = minf(blend, float(x) / float(BLEND_DISTANCE))

			if blend_east and x >= GRID_SIZE - BLEND_DISTANCE:
				blend = minf(blend, float(GRID_SIZE - 1 - x) / float(BLEND_DISTANCE))

			heights[z * GRID_SIZE + x] = height * blend

	return heights


## Create mesh from height grid
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

	# Generate vertices
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

			indices.append(tl)
			indices.append(tr)
			indices.append(bl)

			indices.append(tr)
			indices.append(br)
			indices.append(bl)

	# Calculate normals
	normals.resize(vertices.size())
	for i in range(normals.size()):
		normals[i] = Vector3.ZERO

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
	mesh_instance.mesh = mesh
	mesh_instance.name = "TerrainMesh"

	if material:
		mesh_instance.material_override = material

	# Enable shadow casting
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	return mesh_instance


## Create collision from height grid
static func _create_collision(heights: PackedFloat32Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"

	var shape := HeightMapShape3D.new()
	shape.map_width = GRID_SIZE
	shape.map_depth = GRID_SIZE
	shape.map_data = heights

	var collision := CollisionShape3D.new()
	collision.shape = shape

	# Scale and position the collision to match the mesh
	var scale_factor: float = CELL_SIZE / (GRID_SIZE - 1)
	collision.scale = Vector3(scale_factor, 1.0, scale_factor)

	body.add_child(collision)
	body.collision_layer = 1  # World layer
	body.collision_mask = 0   # Doesn't need to detect others

	return body


## Utility: Smooth step function for blending
static func smoothstep(edge0: float, edge1: float, x: float) -> float:
	var t: float = clampf((x - edge0) / (edge1 - edge0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
