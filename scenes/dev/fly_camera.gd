extends Camera3D
## Enhanced flying camera with World Forge terrain visualization
## Loads terrain from user://world_forge_map.json and displays 3D world preview
##
## Controls:
##   WASD - Move | Q/E - Up/Down | Mouse - Look | Shift - Fast | Scroll - Speed
##   G - Toggle grid overlay | T - Toggle terrain | P - Toggle POIs
##   R - Toggle roads | M - Toggle minimap | L - Toggle labels
##   Home - Reset position | F1 - Debug info | ESC - Release mouse/Quit

const BASE_SPEED := 150.0
const FAST_MULTIPLIER := 8.0
const MOUSE_SENSITIVITY := 0.002
const CELL_SIZE := 100.0

# Movement
var speed_multiplier := 1.0
var velocity := Vector3.ZERO
var mouse_captured := false

# Containers for different visualization layers
var grid_container: Node3D
var terrain_container: Node3D
var poi_container: Node3D
var road_container: Node3D
var label_container: Node3D

# Visibility toggles
var show_grid := true
var show_terrain := true
var show_pois := true
var show_roads := true
var show_minimap := true
var show_labels := true

# Forge data
var forge_data: Dictionary = {}
var terrain_layer: Array = []
var road_layer: Array = []
var poi_layer: Array = []
var poi_data: Dictionary = {}
var grid_width: int = 64
var grid_height: int = 64
var grid_origin: Vector2i = Vector2i(32, 32)

# Material pools for performance
var terrain_materials: Dictionary = {}
var road_materials: Dictionary = {}

# Minimap UI
var minimap_layer: CanvasLayer
var minimap_container: Control
var minimap_rect: TextureRect
var camera_marker: Control
var minimap_texture: ImageTexture

# Terrain colors (from WorldForgeData)
const TERRAIN_COLORS: Dictionary = {
	"plains": Color(0.55, 0.70, 0.38),
	"forest": Color(0.24, 0.42, 0.19),
	"swamp": Color(0.18, 0.29, 0.16),
	"tundra": Color(0.63, 0.78, 0.82),
	"desert": Color(0.83, 0.72, 0.59),
	"badlands": Color(0.55, 0.27, 0.07),
	"hill": Color(0.6, 0.5, 0.4),
	"mountain": Color(0.3, 0.3, 0.35),
	"ocean": Color(0.2, 0.35, 0.6),
	"lake": Color(0.25, 0.45, 0.7),
	"river": Color(0.3, 0.5, 0.75)
}

# Terrain heights
const TERRAIN_HEIGHTS: Dictionary = {
	"plains": 0.0,
	"forest": 0.0,
	"swamp": -2.0,
	"tundra": 0.0,
	"desert": 0.0,
	"badlands": 5.0,
	"hill": 15.0,
	"mountain": 40.0,
	"ocean": -10.0,
	"lake": -5.0,
	"river": -3.0
}

# Road colors
const ROAD_COLORS: Dictionary = {
	"dirt_road": Color(0.55, 0.45, 0.35),
	"stone_road": Color(0.5, 0.5, 0.5),
	"cobblestone": Color(0.45, 0.45, 0.48),
	"path": Color(0.6, 0.5, 0.4),
	"bridge": Color(0.5, 0.4, 0.3)
}

# Road widths
const ROAD_WIDTHS: Dictionary = {
	"dirt_road": 8.0,
	"stone_road": 10.0,
	"cobblestone": 10.0,
	"path": 5.0,
	"bridge": 8.0
}

# POI colors
const POI_COLORS: Dictionary = {
	"town": Color(0.9, 0.75, 0.4),
	"village": Color(0.8, 0.7, 0.5),
	"city": Color(0.95, 0.85, 0.3),
	"capital": Color(1.0, 0.9, 0.2),
	"dungeon": Color(0.6, 0.2, 0.2),
	"landmark": Color(0.7, 0.7, 0.3),
	"outpost": Color(0.5, 0.5, 0.3),
	"cave": Color(0.4, 0.35, 0.3),
	"ruins": Color(0.5, 0.45, 0.4),
	"shrine": Color(0.6, 0.5, 0.7),
	"fortress": Color(0.4, 0.4, 0.5),
	"port": Color(0.3, 0.5, 0.7),
	"camp": Color(0.6, 0.4, 0.3),
	"bridge": Color(0.5, 0.45, 0.35)
}

# Legacy terrain colors (for old grid overlay)
const LEGACY_TERRAIN_COLORS: Dictionary = {
	"F": Color(0.24, 0.42, 0.19),
	"S": Color(0.18, 0.29, 0.16),
	"D": Color(0.83, 0.72, 0.59),
	"H": Color(0.6, 0.5, 0.4),
	"R": Color(0.55, 0.45, 0.35),
	"P": Color(0.9, 0.75, 0.4),
	"B": Color(0.3, 0.3, 0.35),
	"W": Color(0.2, 0.35, 0.6),
	"C": Color(0.3, 0.5, 0.75),
}


func _ready() -> void:
	print("=== FLY CAMERA ENHANCED ===")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true

	# Start high above Elder Moor
	global_position = Vector3(0, 800, 800)
	rotation_degrees = Vector3(-45, 0, 0)

	_create_environment()
	_init_material_pools()

	# Try to load World Forge data, fall back to legacy grid
	if _load_forge_map():
		print("Loaded World Forge map - spawning terrain...")
		call_deferred("_spawn_all_cells")
	else:
		print("World Forge map not found - using legacy grid overlay")
		call_deferred("_create_legacy_grid")

	# Create minimap UI
	call_deferred("_create_minimap")

	_print_controls()


func _print_controls() -> void:
	print("=== CONTROLS ===")
	print("WASD - Move | Q/E - Up/Down | Mouse - Look | Shift - Fast | Scroll - Speed")
	print("G - Toggle grid | T - Toggle terrain | P - Toggle POIs")
	print("R - Toggle roads | M - Toggle minimap | L - Toggle labels")
	print("Home - Reset position | F1 - Debug info | ESC - Release/Quit")


func _create_environment() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.4, 0.5, 0.7)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	add_child(env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -45, 0)
	add_child(light)


func _init_material_pools() -> void:
	# Pre-create materials for each terrain type
	for terrain_type: String in TERRAIN_COLORS:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = TERRAIN_COLORS[terrain_type]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		terrain_materials[terrain_type] = mat

	# Pre-create materials for each road type
	for road_type: String in ROAD_COLORS:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = ROAD_COLORS[road_type]
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		road_materials[road_type] = mat


# =============================================================================
# PHASE 1: Load World Forge JSON
# =============================================================================

func _load_forge_map() -> bool:
	var forge_path := "user://world_forge_map.json"

	if not FileAccess.file_exists(forge_path):
		print("World Forge map not found at: %s" % forge_path)
		return false

	var file := FileAccess.open(forge_path, FileAccess.READ)
	if not file:
		print("Failed to open forge map file")
		return false

	var json_str: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_str) != OK:
		print("Failed to parse JSON: %s" % json.get_error_message())
		return false

	if not json.data is Dictionary:
		print("JSON root is not a dictionary")
		return false

	forge_data = json.data

	# Parse grid info
	var grid_info: Dictionary = forge_data.get("grid", {})
	grid_width = grid_info.get("width", 64)
	grid_height = grid_info.get("height", 64)

	var origin_info: Dictionary = forge_data.get("editor_origin", {})
	grid_origin = Vector2i(origin_info.get("x", 32), origin_info.get("y", 32))

	# Parse layers
	var layers: Dictionary = forge_data.get("layers", {})
	terrain_layer = layers.get("terrain", [])
	road_layer = layers.get("road", [])
	poi_layer = layers.get("poi", [])
	poi_data = forge_data.get("poi_data", {})

	# Handle legacy format (biome/elevation/water)
	if terrain_layer.is_empty() and layers.has("biome"):
		terrain_layer = _merge_legacy_layers(layers)

	print("World Forge map loaded:")
	print("  Grid: %dx%d" % [grid_width, grid_height])
	print("  Origin: %s" % grid_origin)
	print("  Terrain cells: %d" % terrain_layer.size())
	print("  Road cells: %d" % road_layer.size())
	print("  POI cells: %d" % poi_layer.size())
	print("  POI data entries: %d" % poi_data.size())

	return not terrain_layer.is_empty()


func _merge_legacy_layers(layers: Dictionary) -> Array:
	var biome_layer: Array = layers.get("biome", [])
	var elevation_layer: Array = layers.get("elevation", [])
	var water_layer: Array = layers.get("water", [])

	var total_size: int = grid_width * grid_height
	var result: Array = []
	result.resize(total_size)

	var elevation_to_terrain: Dictionary = {
		"hill": "hill",
		"mountain": "mountain"
	}
	var water_to_terrain: Dictionary = {
		"ocean": "ocean",
		"lake": "lake",
		"river": "river"
	}

	for i: int in range(total_size):
		var val: Variant = null

		if i < biome_layer.size() and biome_layer[i] != null:
			val = biome_layer[i]

		if i < elevation_layer.size() and elevation_layer[i] != null:
			var elev: Variant = elevation_layer[i]
			if elev in elevation_to_terrain:
				val = elevation_to_terrain[elev]

		if i < water_layer.size() and water_layer[i] != null:
			var water: Variant = water_layer[i]
			if water in water_to_terrain:
				val = water_to_terrain[water]

		result[i] = val

	return result


# =============================================================================
# PHASE 2 & 5: Create Terrain Mesh Generator + Cell Loading
# =============================================================================

func _spawn_all_cells() -> void:
	print("Spawning all cells...")

	# Create containers
	terrain_container = Node3D.new()
	terrain_container.name = "TerrainContainer"
	get_tree().root.add_child(terrain_container)

	road_container = Node3D.new()
	road_container.name = "RoadContainer"
	get_tree().root.add_child(road_container)

	poi_container = Node3D.new()
	poi_container.name = "POIContainer"
	get_tree().root.add_child(poi_container)

	label_container = Node3D.new()
	label_container.name = "LabelContainer"
	get_tree().root.add_child(label_container)

	var terrain_count := 0
	var road_count := 0
	var poi_count := 0

	# Spawn terrain and road cells
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var index: int = y * grid_width + x
			var world_x: int = x - grid_origin.x
			var world_z: int = y - grid_origin.y

			# Terrain
			if index < terrain_layer.size() and terrain_layer[index] != null:
				var terrain_type: String = terrain_layer[index]
				var terrain_mesh := _create_terrain_cell(world_x, world_z, terrain_type)
				if terrain_mesh:
					terrain_container.add_child(terrain_mesh)
					terrain_count += 1

			# Roads
			if index < road_layer.size() and road_layer[index] != null:
				var road_type: String = road_layer[index]
				var road_mesh := _create_road_segment(world_x, world_z, road_type)
				if road_mesh:
					road_container.add_child(road_mesh)
					road_count += 1

			# POIs
			if index < poi_layer.size() and poi_layer[index] != null:
				var poi_type: String = poi_layer[index]
				var poi_info: Dictionary = poi_data.get(str(index), {})
				var poi_node := _create_poi_marker(world_x, world_z, poi_type, poi_info)
				if poi_node:
					poi_container.add_child(poi_node)
					poi_count += 1

	print("Spawned: %d terrain, %d roads, %d POIs" % [terrain_count, road_count, poi_count])


func _create_terrain_cell(gx: int, gz: int, terrain_type: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()

	var height: float = TERRAIN_HEIGHTS.get(terrain_type, 0.0)
	var box_height: float = maxf(5.0, absf(height) + 5.0)

	box.size = Vector3(CELL_SIZE * 0.95, box_height, CELL_SIZE * 0.95)
	mi.mesh = box

	# Position: center the cell, adjust Y based on terrain type
	var base_y: float = height / 2.0
	if height < 0:
		base_y = height + box_height / 2.0
	else:
		base_y = box_height / 2.0

	mi.position = Vector3(
		gx * CELL_SIZE + CELL_SIZE / 2.0,
		base_y,
		gz * CELL_SIZE + CELL_SIZE / 2.0
	)

	# Use pooled material
	if terrain_materials.has(terrain_type):
		mi.material_override = terrain_materials[terrain_type]
	else:
		# Fallback for unknown terrain
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color.MAGENTA
		mi.material_override = mat

	return mi


# =============================================================================
# PHASE 3: POI Markers and Buildings
# =============================================================================

func _create_poi_marker(gx: int, gz: int, poi_type: String, poi_info: Dictionary) -> Node3D:
	var node := Node3D.new()
	var world_pos := Vector3(
		gx * CELL_SIZE + CELL_SIZE / 2.0,
		0,
		gz * CELL_SIZE + CELL_SIZE / 2.0
	)
	node.position = world_pos

	var color: Color = POI_COLORS.get(poi_type, Color.WHITE)

	# Create POI-specific geometry
	match poi_type:
		"town", "city", "capital":
			_create_settlement_preview(node, poi_type, color)
		"village":
			_create_village_preview(node, color)
		"dungeon", "cave", "ruins":
			_create_dungeon_marker(node, poi_type, color)
		"landmark", "shrine":
			_create_landmark_marker(node, poi_type, color)
		"outpost", "camp":
			_create_outpost_marker(node, color)
		"fortress":
			_create_fortress_marker(node, color)
		"port":
			_create_port_marker(node, color)
		"bridge":
			_create_bridge_marker(node, color)
		_:
			_create_default_marker(node, color)

	# Add label if POI has a name
	var poi_name: String = poi_info.get("name", "")
	if not poi_name.is_empty():
		var label := _create_poi_label(poi_name, color)
		label_container.add_child(label)
		label.global_position = world_pos + Vector3(0, 60, 0)

	return node


func _create_settlement_preview(parent: Node3D, poi_type: String, color: Color) -> void:
	var building_count: int = 3
	var building_scale: float = 1.0

	match poi_type:
		"town":
			building_count = 5
			building_scale = 1.2
		"city":
			building_count = 8
			building_scale = 1.5
		"capital":
			building_count = 12
			building_scale = 2.0

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Create clustered buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(parent.position)

	for i: int in range(building_count):
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()

		var width: float = rng.randf_range(8, 15) * building_scale
		var height: float = rng.randf_range(15, 35) * building_scale
		var depth: float = rng.randf_range(8, 15) * building_scale

		box.size = Vector3(width, height, depth)
		building.mesh = box
		building.material_override = mat

		# Scatter buildings around center
		var angle: float = (float(i) / float(building_count)) * TAU + rng.randf_range(-0.3, 0.3)
		var radius: float = rng.randf_range(10, 30) * building_scale
		building.position = Vector3(
			cos(angle) * radius,
			height / 2.0,
			sin(angle) * radius
		)

		parent.add_child(building)


func _create_village_preview(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Create 2-3 small buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(parent.position)

	for i: int in range(rng.randi_range(2, 3)):
		var building := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(rng.randf_range(6, 10), rng.randf_range(10, 18), rng.randf_range(6, 10))
		building.mesh = box
		building.material_override = mat

		var angle: float = (float(i) / 3.0) * TAU
		building.position = Vector3(cos(angle) * 15, box.size.y / 2.0, sin(angle) * 15)
		parent.add_child(building)


func _create_dungeon_marker(parent: Node3D, poi_type: String, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Create archway/entrance marker
	var arch := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 25, 10)
	arch.mesh = box
	arch.material_override = mat
	arch.position.y = 12.5
	parent.add_child(arch)

	# Add dark interior
	var dark_mat := StandardMaterial3D.new()
	dark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark_mat.albedo_color = Color(0.1, 0.1, 0.1)

	var interior := MeshInstance3D.new()
	var interior_box := BoxMesh.new()
	interior_box.size = Vector3(12, 18, 6)
	interior.mesh = interior_box
	interior.material_override = dark_mat
	interior.position = Vector3(0, 9, 3)
	parent.add_child(interior)


func _create_landmark_marker(parent: Node3D, poi_type: String, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	if poi_type == "shrine":
		# Glowing pillar
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 4
		cyl.bottom_radius = 5
		cyl.height = 30
		pillar.mesh = cyl
		pillar.material_override = mat
		pillar.position.y = 15
		parent.add_child(pillar)
	else:
		# Tall obelisk
		var obelisk := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(8, 50, 8)
		obelisk.mesh = box
		obelisk.material_override = mat
		obelisk.position.y = 25
		parent.add_child(obelisk)


func _create_outpost_marker(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Guard tower
	var tower := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12, 35, 12)
	tower.mesh = box
	tower.material_override = mat
	tower.position.y = 17.5
	parent.add_child(tower)


func _create_fortress_marker(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Main keep
	var keep := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(30, 50, 30)
	keep.mesh = box
	keep.material_override = mat
	keep.position.y = 25
	parent.add_child(keep)

	# Corner towers
	for i: int in range(4):
		var tower := MeshInstance3D.new()
		var tower_box := BoxMesh.new()
		tower_box.size = Vector3(10, 60, 10)
		tower.mesh = tower_box
		tower.material_override = mat
		var angle: float = (float(i) / 4.0) * TAU + PI / 4.0
		tower.position = Vector3(cos(angle) * 25, 30, sin(angle) * 25)
		parent.add_child(tower)


func _create_port_marker(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Dock building
	var building := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 20, 15)
	building.mesh = box
	building.material_override = mat
	building.position.y = 10
	parent.add_child(building)

	# Pier extending into water
	var pier := MeshInstance3D.new()
	var pier_box := BoxMesh.new()
	pier_box.size = Vector3(8, 3, 40)
	pier.mesh = pier_box
	pier.material_override = mat
	pier.position = Vector3(0, 1.5, 30)
	parent.add_child(pier)


func _create_bridge_marker(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	# Bridge span
	var span := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(15, 5, 80)
	span.mesh = box
	span.material_override = mat
	span.position.y = 15
	parent.add_child(span)

	# Support pillars
	for i: int in range(2):
		var pillar := MeshInstance3D.new()
		var pillar_box := BoxMesh.new()
		pillar_box.size = Vector3(8, 30, 8)
		pillar.mesh = pillar_box
		pillar.material_override = mat
		pillar.position = Vector3(0, 7.5, (float(i) - 0.5) * 50)
		parent.add_child(pillar)


func _create_default_marker(parent: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color

	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 10
	sphere.height = 20
	marker.mesh = sphere
	marker.material_override = mat
	marker.position.y = 15
	parent.add_child(marker)


func _create_poi_label(text: String, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 72
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label.modulate = color
	return label


# =============================================================================
# PHASE 4: Road Visualization
# =============================================================================

func _create_road_segment(gx: int, gz: int, road_type: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()

	var width: float = ROAD_WIDTHS.get(road_type, 8.0)
	# Roads are flat and slightly raised
	box.size = Vector3(width, 1.5, width)
	mi.mesh = box

	mi.position = Vector3(
		gx * CELL_SIZE + CELL_SIZE / 2.0,
		0.75,  # Slightly above ground
		gz * CELL_SIZE + CELL_SIZE / 2.0
	)

	if road_materials.has(road_type):
		mi.material_override = road_materials[road_type]
	else:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.5, 0.4, 0.3)
		mi.material_override = mat

	return mi


# =============================================================================
# PHASE 6: Minimap UI
# =============================================================================

func _create_minimap() -> void:
	minimap_layer = CanvasLayer.new()
	minimap_layer.layer = 100
	add_child(minimap_layer)

	# Main container - upper right corner
	minimap_container = Control.new()
	minimap_container.name = "MinimapContainer"
	minimap_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap_container.offset_left = -220
	minimap_container.offset_top = 20
	minimap_container.offset_right = -20
	minimap_container.offset_bottom = 220
	minimap_layer.add_child(minimap_container)

	# Background panel
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = Color(0.4, 0.35, 0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	minimap_container.add_child(panel)

	# Generate minimap texture
	minimap_texture = _generate_minimap_texture()

	# Minimap image
	minimap_rect = TextureRect.new()
	minimap_rect.texture = minimap_texture
	minimap_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	minimap_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap_rect.offset_left = 4
	minimap_rect.offset_top = 4
	minimap_rect.offset_right = -4
	minimap_rect.offset_bottom = -4
	minimap_container.add_child(minimap_rect)

	# Camera position marker
	camera_marker = Control.new()
	camera_marker.name = "CameraMarker"
	camera_marker.custom_minimum_size = Vector2(12, 12)
	minimap_container.add_child(camera_marker)
	camera_marker.draw.connect(_draw_camera_marker)


func _generate_minimap_texture() -> ImageTexture:
	# Create image from terrain data
	var img := Image.create(grid_width, grid_height, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.15))

	# Draw terrain
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var index: int = y * grid_width + x
			if index < terrain_layer.size() and terrain_layer[index] != null:
				var terrain_type: String = terrain_layer[index]
				var color: Color = TERRAIN_COLORS.get(terrain_type, Color(0.3, 0.3, 0.3))
				img.set_pixel(x, y, color)

	# Draw roads on top
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var index: int = y * grid_width + x
			if index < road_layer.size() and road_layer[index] != null:
				var road_type: String = road_layer[index]
				var color: Color = ROAD_COLORS.get(road_type, Color(0.5, 0.4, 0.3))
				img.set_pixel(x, y, color.lightened(0.2))

	# Draw POIs on top
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var index: int = y * grid_width + x
			if index < poi_layer.size() and poi_layer[index] != null:
				var poi_type: String = poi_layer[index]
				var color: Color = POI_COLORS.get(poi_type, Color.WHITE)
				img.set_pixel(x, y, color)

	# Draw origin marker (Elder Moor)
	if grid_origin.x >= 0 and grid_origin.x < grid_width and grid_origin.y >= 0 and grid_origin.y < grid_height:
		img.set_pixel(grid_origin.x, grid_origin.y, Color.WHITE)

	var texture := ImageTexture.create_from_image(img)
	return texture


func _draw_camera_marker() -> void:
	if not camera_marker:
		return

	# Draw a triangle pointing in camera direction
	var size := 6.0
	var yaw: float = -rotation.y

	var points: PackedVector2Array = [
		Vector2(0, -size).rotated(yaw),
		Vector2(-size * 0.6, size * 0.6).rotated(yaw),
		Vector2(size * 0.6, size * 0.6).rotated(yaw)
	]

	for i: int in range(points.size()):
		points[i] += Vector2(size, size)

	camera_marker.draw_colored_polygon(points, Color.RED)
	camera_marker.draw_polyline(points + PackedVector2Array([points[0]]), Color.WHITE, 1.5)


func _update_minimap() -> void:
	if not minimap_container or not minimap_container.visible:
		return
	if not camera_marker or not minimap_rect:
		return

	# Convert camera world position to minimap position
	var cam_cell_x: float = global_position.x / CELL_SIZE
	var cam_cell_z: float = global_position.z / CELL_SIZE

	# Convert to minimap coordinates (add origin offset)
	var map_x: float = cam_cell_x + grid_origin.x
	var map_y: float = cam_cell_z + grid_origin.y

	# Convert to pixel position within minimap rect
	var rect_size: Vector2 = minimap_rect.size
	var pixel_x: float = (map_x / float(grid_width)) * rect_size.x + minimap_rect.offset_left
	var pixel_y: float = (map_y / float(grid_height)) * rect_size.y + minimap_rect.offset_top

	# Position the marker
	camera_marker.position = Vector2(pixel_x - 6, pixel_y - 6)
	camera_marker.queue_redraw()


# =============================================================================
# LEGACY GRID (Fallback if no World Forge data)
# =============================================================================

func _create_legacy_grid() -> void:
	print("Creating legacy grid overlay...")

	grid_container = Node3D.new()
	grid_container.name = "GridOverlay"
	get_tree().root.add_child(grid_container)

	var world_grid_script = load("res://scripts/data/world_grid.gd")
	if not world_grid_script:
		print("ERROR: Could not load WorldGrid script!")
		_create_debug_grid()
		return

	var grid_data: Array = world_grid_script.GRID_DATA
	var internal_offset: Vector2i = world_grid_script._INTERNAL_OFFSET
	var locs: Array = world_grid_script.LOCATIONS

	print("WorldGrid loaded: %d rows, offset %s" % [grid_data.size(), internal_offset])

	if grid_data.is_empty():
		_create_debug_grid()
		return

	for row: int in range(grid_data.size()):
		var row_data: Array = grid_data[row]
		for col: int in range(row_data.size()):
			var terrain_char: String = row_data[col]
			var color: Color = LEGACY_TERRAIN_COLORS.get(terrain_char, Color.MAGENTA)

			var world_x: int = col - internal_offset.x
			var world_z: int = row - internal_offset.y

			var mesh := _create_legacy_cell(world_x, world_z, color)
			grid_container.add_child(mesh)

	# Add location markers
	label_container = Node3D.new()
	label_container.name = "LabelContainer"
	get_tree().root.add_child(label_container)

	for loc: Dictionary in locs:
		var marker := _create_legacy_marker(loc)
		grid_container.add_child(marker)

	print("Legacy grid created: %d objects" % grid_container.get_child_count())

	# Generate minimap from legacy data
	_generate_legacy_minimap(grid_data, internal_offset)


func _create_legacy_cell(gx: int, gz: int, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(CELL_SIZE * 0.9, 2.0, CELL_SIZE * 0.9)
	mi.mesh = box

	mi.position = Vector3(gx * CELL_SIZE + CELL_SIZE / 2.0, 0, gz * CELL_SIZE + CELL_SIZE / 2.0)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat

	return mi


func _create_legacy_marker(loc: Dictionary) -> Node3D:
	var node := Node3D.new()
	var lx: int = loc.get("x", 0)
	var lz: int = loc.get("y", 0)
	var lname: String = loc.get("name", "?")
	var ltype: String = loc.get("type", "")

	node.position = Vector3(lx * CELL_SIZE + CELL_SIZE / 2.0, 0, lz * CELL_SIZE + CELL_SIZE / 2.0)

	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 3.0
	cyl.bottom_radius = 3.0
	cyl.height = 50.0
	pole.mesh = cyl
	pole.position.y = 25.0

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match ltype:
		"town", "city", "capital":
			mat.albedo_color = Color.GOLD
		"dungeon":
			mat.albedo_color = Color.RED
		"village":
			mat.albedo_color = Color.SANDY_BROWN
		_:
			mat.albedo_color = Color.WHITE
	pole.material_override = mat
	node.add_child(pole)

	var label := Label3D.new()
	label.text = lname
	label.position.y = 55.0
	label.font_size = 72
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.outline_size = 8
	label_container.add_child(label)
	label.global_position = node.position + Vector3(0, 55, 0)

	return node


func _create_debug_grid() -> void:
	print("Creating debug grid (10x10 cells)...")

	grid_container = Node3D.new()
	grid_container.name = "GridOverlay"
	get_tree().root.add_child(grid_container)

	for x: int in range(-5, 5):
		for z: int in range(-5, 5):
			var color := Color(0.3, 0.5, 0.3)
			if (x + z) % 2 == 0:
				color = Color(0.4, 0.6, 0.4)
			var mesh := _create_legacy_cell(x, z, color)
			grid_container.add_child(mesh)

	var origin_marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 20.0
	sphere.height = 40.0
	origin_marker.mesh = sphere
	origin_marker.position = Vector3(0, 50, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.RED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	origin_marker.material_override = mat
	grid_container.add_child(origin_marker)


func _generate_legacy_minimap(grid_data: Array, internal_offset: Vector2i) -> void:
	var rows: int = grid_data.size()
	var cols: int = grid_data[0].size() if rows > 0 else 0

	var img := Image.create(cols, rows, false, Image.FORMAT_RGB8)
	img.fill(Color(0.1, 0.1, 0.15))

	for row: int in range(rows):
		var row_data: Array = grid_data[row]
		for col: int in range(row_data.size()):
			var terrain_char: String = row_data[col]
			var color: Color = LEGACY_TERRAIN_COLORS.get(terrain_char, Color(0.3, 0.3, 0.3))
			img.set_pixel(col, row, color)

	# Mark origin
	if internal_offset.x >= 0 and internal_offset.x < cols and internal_offset.y >= 0 and internal_offset.y < rows:
		img.set_pixel(internal_offset.x, internal_offset.y, Color.WHITE)

	if minimap_texture:
		minimap_texture.update(img)
	elif minimap_rect:
		minimap_texture = ImageTexture.create_from_image(img)
		minimap_rect.texture = minimap_texture

	# Update grid dimensions for minimap tracking
	grid_width = cols
	grid_height = rows
	grid_origin = internal_offset


# =============================================================================
# PHASE 7: Toggle Controls + Input Handling
# =============================================================================

func _input(event: InputEvent) -> void:
	# Mouse look
	if event is InputEventMouseMotion and mouse_captured:
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		rotate_object_local(Vector3.RIGHT, -event.relative.y * MOUSE_SENSITIVITY)
		rotation.x = clamp(rotation.x, -PI / 2 + 0.1, PI / 2 - 0.1)

	# Mouse buttons
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				speed_multiplier = minf(speed_multiplier * 1.3, 10.0)
				print("Speed: %.1fx" % speed_multiplier)
			MOUSE_BUTTON_WHEEL_DOWN:
				speed_multiplier = maxf(speed_multiplier / 1.3, 0.2)
				print("Speed: %.1fx" % speed_multiplier)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				if not mouse_captured:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
					mouse_captured = true
					print("Mouse captured")

	# Keyboard
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				if mouse_captured:
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
					mouse_captured = false
					print("Mouse released - press ESC again to quit")
				else:
					get_tree().quit()
			KEY_G:
				_toggle_grid()
			KEY_T:
				_toggle_terrain()
			KEY_P:
				_toggle_pois()
			KEY_R:
				_toggle_roads()
			KEY_M:
				_toggle_minimap()
			KEY_L:
				_toggle_labels()
			KEY_HOME:
				_reset_position()
			KEY_F1:
				_print_debug_info()


func _toggle_grid() -> void:
	show_grid = not show_grid
	if grid_container:
		grid_container.visible = show_grid
	print("Grid: %s" % ("visible" if show_grid else "hidden"))


func _toggle_terrain() -> void:
	show_terrain = not show_terrain
	if terrain_container:
		terrain_container.visible = show_terrain
	print("Terrain: %s" % ("visible" if show_terrain else "hidden"))


func _toggle_pois() -> void:
	show_pois = not show_pois
	if poi_container:
		poi_container.visible = show_pois
	print("POIs: %s" % ("visible" if show_pois else "hidden"))


func _toggle_roads() -> void:
	show_roads = not show_roads
	if road_container:
		road_container.visible = show_roads
	print("Roads: %s" % ("visible" if show_roads else "hidden"))


func _toggle_minimap() -> void:
	show_minimap = not show_minimap
	if minimap_container:
		minimap_container.visible = show_minimap
	print("Minimap: %s" % ("visible" if show_minimap else "hidden"))


func _toggle_labels() -> void:
	show_labels = not show_labels
	if label_container:
		label_container.visible = show_labels
	print("Labels: %s" % ("visible" if show_labels else "hidden"))


func _reset_position() -> void:
	global_position = Vector3(0, 800, 800)
	rotation_degrees = Vector3(-45, 0, 0)
	print("Reset position to Elder Moor overview")


func _print_debug_info() -> void:
	print("=== DEBUG INFO ===")
	print("Position: %s" % global_position)
	print("Cell: (%d, %d)" % [int(global_position.x / CELL_SIZE), int(global_position.z / CELL_SIZE)])
	print("Rotation: %s" % rotation_degrees)
	print("Speed multiplier: %.1fx" % speed_multiplier)
	if terrain_container:
		print("Terrain meshes: %d" % terrain_container.get_child_count())
	if road_container:
		print("Road meshes: %d" % road_container.get_child_count())
	if poi_container:
		print("POI markers: %d" % poi_container.get_child_count())


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO

	if Input.is_key_pressed(KEY_W):
		dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		dir += transform.basis.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir += Vector3.DOWN

	var speed := BASE_SPEED * speed_multiplier
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FAST_MULTIPLIER

	if dir.length() > 0:
		velocity = dir.normalized() * speed
	else:
		velocity = velocity.lerp(Vector3.ZERO, 10.0 * delta)

	global_position += velocity * delta

	# Update minimap camera marker
	_update_minimap()
