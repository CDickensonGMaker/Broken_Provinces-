## enhanced_terrain.gd - Cell terrain: heightfield to mesh, collision and readback.
##
## The heightfield itself comes from TerrainGenerator; this file owns only the two
## functions the streaming system calls - generate() and get_height_at() - and the
## geometry it builds from the samples.
class_name EnhancedTerrain
extends RefCounted


const GRID_SIZE: int = TerrainGenerator.GRID_SIZE
const CELL_SIZE: float = TerrainGenerator.CELL_SIZE


## Build terrain for a cell.
## blend_edges: Dictionary with "north", "south", "east", "west" bools - true where the
## neighbouring cell uses flat ground and this cell must ramp down to meet it.
## Returns: Dictionary with "node" (Node3D) and "heights" (PackedFloat32Array).
static func generate(
	cell_x: int,
	cell_z: int,
	biome: int,
	material: Material = null,
	blend_edges: Dictionary = {}
) -> Dictionary:
	var heights: PackedFloat32Array = TerrainGenerator.generate_heights(
		cell_x, cell_z, biome, blend_edges
	)

	var root := Node3D.new()
	root.name = "EnhancedTerrain"
	root.add_child(_create_mesh(heights, material))
	root.add_child(_create_collision(heights))

	root.set_meta("heights", heights)
	root.set_meta("grid_size", GRID_SIZE)
	root.set_meta("cell_size", CELL_SIZE)
	root.set_meta("biome", biome)

	return {
		"node": root,
		"heights": heights
	}


## Height at a local position inside the cell, for prop placement.
static func get_height_at(
	heights: PackedFloat32Array,
	local_x: float,
	local_z: float
) -> float:
	return TerrainGenerator.height_at(heights, local_x, local_z)


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

	var step: float = CELL_SIZE / float(GRID_SIZE - 1)
	var half_size: float = CELL_SIZE * 0.5

	for z in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			vertices.append(Vector3(
				x * step - half_size,
				heights[z * GRID_SIZE + x],
				z * step - half_size
			))
			uvs.append(Vector2(
				float(x) / float(GRID_SIZE - 1),
				float(z) / float(GRID_SIZE - 1)
			))

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

	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	return mesh_instance


static func _create_collision(heights: PackedFloat32Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"

	var shape := HeightMapShape3D.new()
	shape.map_width = GRID_SIZE
	shape.map_depth = GRID_SIZE
	shape.map_data = heights

	var collision := CollisionShape3D.new()
	collision.shape = shape

	var scale_factor: float = CELL_SIZE / float(GRID_SIZE - 1)
	collision.scale = Vector3(scale_factor, 1.0, scale_factor)

	body.add_child(collision)
	body.collision_layer = 1  # World layer
	body.collision_mask = 0

	return body
