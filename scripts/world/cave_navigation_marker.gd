## cave_navigation_marker.gd - Glowing navigation crystals that guide player through caves
## Changes color based on visited/unvisited/path-to-exit state
class_name CaveNavigationMarker
extends Node3D


## Marker states
enum MarkerState {
	UNEXPLORED,    ## Not yet seen - dim blue glow
	VISITED,       ## Player has been near - bright white
	PATH_TO_EXIT   ## On the path to exit - green glow
}


## Colors for each state
const COLORS: Dictionary = {
	MarkerState.UNEXPLORED: Color(0.3, 0.4, 0.8, 1.0),    # Dim blue
	MarkerState.VISITED: Color(0.9, 0.9, 1.0, 1.0),       # Bright white
	MarkerState.PATH_TO_EXIT: Color(0.3, 0.9, 0.4, 1.0)   # Green
}


## Glow intensity for each state
const GLOW_INTENSITY: Dictionary = {
	MarkerState.UNEXPLORED: 0.5,
	MarkerState.VISITED: 1.5,
	MarkerState.PATH_TO_EXIT: 2.0
}


## Light energy for each state
const LIGHT_ENERGY: Dictionary = {
	MarkerState.UNEXPLORED: 0.3,
	MarkerState.VISITED: 0.8,
	MarkerState.PATH_TO_EXIT: 1.2
}


## Detection radius for auto-marking as visited
const VISIT_RADIUS: float = 5.0


## Export variables
@export var marker_id: String = ""
@export var is_on_exit_path: bool = false  ## Set in Blender metadata
@export var linked_area_id: String = ""  ## Optional area this marker belongs to


## Current state
var current_state: MarkerState = MarkerState.UNEXPLORED


## Visual components
var crystal_mesh: MeshInstance3D
var point_light: OmniLight3D
var crystal_material: StandardMaterial3D


## Animation
var _pulse_time: float = 0.0
var _base_emission_energy: float = 0.5


func _ready() -> void:
	add_to_group("cave_nav_markers")

	# Parse metadata from imported GLB
	_parse_metadata()

	# Create visual representation
	_create_crystal_mesh()
	_create_light()

	# Set initial state
	_update_visual_state()

	# Register with CaveManager (use safe access to avoid class_name collision)
	var cave_mgr: Node = get_node_or_null("/root/CaveManager")
	if cave_mgr and cave_mgr.has_method("register_nav_marker"):
		cave_mgr.register_nav_marker(self)

		# If on exit path, set initial state
		if is_on_exit_path:
			current_state = MarkerState.PATH_TO_EXIT
			_update_visual_state()


func _process(delta: float) -> void:
	# Pulse animation
	_pulse_time += delta * 2.0
	var pulse: float = (sin(_pulse_time) + 1.0) * 0.5  # 0 to 1

	# Vary emission energy with pulse
	var intensity: float = GLOW_INTENSITY.get(current_state, 1.0)
	var pulse_amount: float = 0.3 if current_state == MarkerState.PATH_TO_EXIT else 0.15
	crystal_material.emission_energy_multiplier = intensity * (1.0 + pulse * pulse_amount)

	# Check if player is nearby (for auto-visit)
	if current_state == MarkerState.UNEXPLORED:
		_check_player_proximity()


func _parse_metadata() -> void:
	# Read metadata set in Blender
	if has_meta("on_exit_path"):
		is_on_exit_path = get_meta("on_exit_path")
	if has_meta("area_id"):
		linked_area_id = get_meta("area_id")
	if has_meta("marker_id"):
		marker_id = get_meta("marker_id")

	# Generate ID if not set
	if marker_id.is_empty():
		marker_id = "nav_%s_%d" % [name, get_instance_id()]


func _create_crystal_mesh() -> void:
	## Create a crystal-like mesh
	crystal_mesh = MeshInstance3D.new()
	crystal_mesh.name = "CrystalMesh"

	# Create prism-like shape using ArrayMesh for crystal look
	var mesh := _create_crystal_shape()
	crystal_mesh.mesh = mesh

	# Create emissive material
	crystal_material = StandardMaterial3D.new()
	crystal_material.albedo_color = COLORS[MarkerState.UNEXPLORED]
	crystal_material.emission_enabled = true
	crystal_material.emission = COLORS[MarkerState.UNEXPLORED]
	crystal_material.emission_energy_multiplier = GLOW_INTENSITY[MarkerState.UNEXPLORED]
	crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	crystal_material.albedo_color.a = 0.85

	# Make it look crystalline
	crystal_material.roughness = 0.1
	crystal_material.metallic = 0.3
	crystal_material.metallic_specular = 0.8

	crystal_mesh.material_override = crystal_material

	add_child(crystal_mesh)


func _create_crystal_shape() -> Mesh:
	## Create a double-ended crystal shape
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Crystal parameters
	var height: float = 0.5
	var width: float = 0.12
	var point_offset: float = 0.2

	# Top pyramid (4 faces pointing up)
	var top: Vector3 = Vector3(0, height / 2 + point_offset, 0)
	var a: Vector3 = Vector3(-width, height / 2 - point_offset, -width)
	var b: Vector3 = Vector3(width, height / 2 - point_offset, -width)
	var c: Vector3 = Vector3(width, height / 2 - point_offset, width)
	var d: Vector3 = Vector3(-width, height / 2 - point_offset, width)

	# Bottom pyramid (4 faces pointing down)
	var bottom: Vector3 = Vector3(0, -height / 2 - point_offset, 0)
	var e: Vector3 = Vector3(-width, -height / 2 + point_offset, -width)
	var f: Vector3 = Vector3(width, -height / 2 + point_offset, -width)
	var g: Vector3 = Vector3(width, -height / 2 + point_offset, width)
	var h: Vector3 = Vector3(-width, -height / 2 + point_offset, width)

	# Top pyramid faces
	_add_triangle(st, top, a, b)
	_add_triangle(st, top, b, c)
	_add_triangle(st, top, c, d)
	_add_triangle(st, top, d, a)

	# Middle faces (connecting top and bottom bases)
	_add_triangle(st, a, e, f)
	_add_triangle(st, a, f, b)
	_add_triangle(st, b, f, g)
	_add_triangle(st, b, g, c)
	_add_triangle(st, c, g, h)
	_add_triangle(st, c, h, d)
	_add_triangle(st, d, h, e)
	_add_triangle(st, d, e, a)

	# Bottom pyramid faces
	_add_triangle(st, bottom, f, e)
	_add_triangle(st, bottom, g, f)
	_add_triangle(st, bottom, h, g)
	_add_triangle(st, bottom, e, h)

	st.generate_normals()
	return st.commit()


func _add_triangle(st: SurfaceTool, v1: Vector3, v2: Vector3, v3: Vector3) -> void:
	st.add_vertex(v1)
	st.add_vertex(v2)
	st.add_vertex(v3)


func _create_light() -> void:
	## Create point light for glow effect
	point_light = OmniLight3D.new()
	point_light.name = "CrystalLight"
	point_light.light_color = COLORS[MarkerState.UNEXPLORED]
	point_light.light_energy = LIGHT_ENERGY[MarkerState.UNEXPLORED]
	point_light.omni_range = 4.0
	point_light.omni_attenuation = 1.5
	point_light.shadow_enabled = false  # Performance

	add_child(point_light)


func _update_visual_state() -> void:
	## Update visuals based on current state
	var color: Color = COLORS.get(current_state, COLORS[MarkerState.UNEXPLORED])
	var intensity: float = GLOW_INTENSITY.get(current_state, 1.0)
	var light_energy: float = LIGHT_ENERGY.get(current_state, 0.5)

	if crystal_material:
		crystal_material.albedo_color = Color(color.r, color.g, color.b, 0.85)
		crystal_material.emission = color
		crystal_material.emission_energy_multiplier = intensity

	if point_light:
		point_light.light_color = color
		point_light.light_energy = light_energy


func _check_player_proximity() -> void:
	## Check if player is close enough to mark as visited
	var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return

	var distance: float = global_position.distance_to(player.global_position)
	if distance <= VISIT_RADIUS:
		mark_visited()


## Mark this marker as visited
func mark_visited() -> void:
	if current_state == MarkerState.UNEXPLORED:
		current_state = MarkerState.VISITED
		_update_visual_state()


## Set marker to path-to-exit state
func set_path_to_exit(is_path: bool) -> void:
	is_on_exit_path = is_path
	if is_path:
		current_state = MarkerState.PATH_TO_EXIT
	elif current_state == MarkerState.PATH_TO_EXIT:
		current_state = MarkerState.VISITED
	_update_visual_state()


## Get current state
func get_state() -> MarkerState:
	return current_state


## Static factory method for spawning markers
static func spawn_marker(
	parent: Node,
	pos: Vector3,
	p_marker_id: String = "",
	p_on_exit_path: bool = false,
	p_area_id: String = ""
) -> CaveNavigationMarker:
	var marker := CaveNavigationMarker.new()
	marker.position = pos
	marker.marker_id = p_marker_id
	marker.is_on_exit_path = p_on_exit_path
	marker.linked_area_id = p_area_id

	parent.add_child(marker)
	return marker


## Find markers in a node hierarchy (for imported GLB scenes)
static func find_and_convert_markers(root: Node) -> Array[CaveNavigationMarker]:
	var markers: Array[CaveNavigationMarker] = []
	_find_markers_recursive(root, markers)
	return markers


static func _find_markers_recursive(node: Node, markers: Array[CaveNavigationMarker]) -> void:
	# Check if this node is a nav marker placeholder
	if node.name.begins_with("NavMarker_"):
		if node is Node3D:
			var node3d: Node3D = node as Node3D

			# Create actual marker at this position
			var marker := CaveNavigationMarker.new()
			marker.position = node3d.position
			marker.rotation = node3d.rotation
			marker.marker_id = node.name.replace("NavMarker_", "")

			# Read metadata
			if node.has_meta("on_exit_path"):
				marker.is_on_exit_path = node.get_meta("on_exit_path")
			if node.has_meta("area_id"):
				marker.linked_area_id = node.get_meta("area_id")

			# Add marker as sibling
			node.get_parent().add_child(marker)
			markers.append(marker)

			# Optionally hide the original placeholder
			node3d.visible = false

	# Recurse
	for child in node.get_children():
		_find_markers_recursive(child, markers)
