## town_gate.gd - Interactable gate/signpost leading to a town
## Spawned in wilderness cells adjacent to towns
## Player interacts to enter the town scene
class_name TownGate
extends Node3D

## Town data
@export var town_id: String = ""
@export var town_name: String = ""
@export var town_coords: Vector2i = Vector2i.ZERO
@export var direction_to_town: int = 0  # RoomEdge.Direction (0=NORTH, 1=SOUTH, 2=EAST, 3=WEST)

## Interaction area
var interact_area: Area3D
var is_player_nearby: bool = false

## Visual components
var gate_mesh: Node3D
var label_3d: Label3D

## Signal for interaction
signal gate_activated(town_id: String)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("town_gate")

	_setup_interaction_area()
	_create_visuals()


func _setup_interaction_area() -> void:
	interact_area = Area3D.new()
	interact_area.name = "InteractArea"
	interact_area.collision_layer = 0
	interact_area.collision_mask = 2  # Player layer

	var col_shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 4.0)
	col_shape.shape = box
	col_shape.position = Vector3(0, 2.0, 0)
	interact_area.add_child(col_shape)

	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)

	add_child(interact_area)


func _create_visuals() -> void:
	gate_mesh = Node3D.new()
	gate_mesh.name = "GateMesh"
	add_child(gate_mesh)

	# Materials
	var wood_mat: StandardMaterial3D = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.4, 0.3, 0.2)
	wood_mat.roughness = 0.9

	var sign_mat: StandardMaterial3D = StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.5, 0.4, 0.3)
	sign_mat.roughness = 0.85

	# Left post
	var left_post: CSGBox3D = CSGBox3D.new()
	left_post.size = Vector3(0.4, 4.0, 0.4)
	left_post.position = Vector3(-2.5, 2.0, 0)
	left_post.material = wood_mat
	gate_mesh.add_child(left_post)

	# Right post
	var right_post: CSGBox3D = CSGBox3D.new()
	right_post.size = Vector3(0.4, 4.0, 0.4)
	right_post.position = Vector3(2.5, 2.0, 0)
	right_post.material = wood_mat
	gate_mesh.add_child(right_post)

	# Cross beam
	var beam: CSGBox3D = CSGBox3D.new()
	beam.size = Vector3(5.4, 0.35, 0.35)
	beam.position = Vector3(0, 3.8, 0)
	beam.material = wood_mat
	gate_mesh.add_child(beam)

	# Sign board
	var sign_board: CSGBox3D = CSGBox3D.new()
	sign_board.size = Vector3(4.0, 0.8, 0.12)
	sign_board.position = Vector3(0, 3.2, 0.25)
	sign_board.material = sign_mat
	gate_mesh.add_child(sign_board)

	# 3D Label for town name
	label_3d = Label3D.new()
	label_3d.name = "TownLabel"
	label_3d.text = town_name if town_name else "Unknown Town"
	label_3d.font_size = 64
	label_3d.pixel_size = 0.01
	label_3d.position = Vector3(0, 3.2, 0.35)
	label_3d.modulate = Color(0.15, 0.1, 0.05)  # Dark text
	label_3d.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label_3d.no_depth_test = false
	add_child(label_3d)

	# Arrow pointing toward town
	var arrow: CSGPolygon3D = CSGPolygon3D.new()
	arrow.name = "DirectionArrow"
	# Simple arrow shape polygon
	var arrow_points: PackedVector2Array = PackedVector2Array([
		Vector2(0, 0.5),
		Vector2(0.3, 0),
		Vector2(0.15, 0),
		Vector2(0.15, -0.5),
		Vector2(-0.15, -0.5),
		Vector2(-0.15, 0),
		Vector2(-0.3, 0)
	])
	arrow.polygon = arrow_points
	arrow.depth = 0.1
	arrow.position = Vector3(0, 2.3, 0.25)
	arrow.material = wood_mat
	gate_mesh.add_child(arrow)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		_show_interact_prompt()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
		_hide_interact_prompt()


func _show_interact_prompt() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_interact_prompt"):
		hud.show_interact_prompt("Enter %s" % town_name)


func _hide_interact_prompt() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("hide_interact_prompt"):
		hud.hide_interact_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not is_player_nearby:
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_enter_town()


func _enter_town() -> void:
	print("[TownGate] Entering town: %s (%s) at (%d, %d)" % [
		town_name, town_id, town_coords.x, town_coords.y
	])

	gate_activated.emit(town_id)
	_hide_interact_prompt()

	# Transition to town
	if SceneManager:
		# Get the scene for this town
		var town_scene: String = SceneManager.get_scene_for_location(town_id)

		if not town_scene.is_empty():
			# Update room coords for world map tracking
			SceneManager.current_room_coords = town_coords

			# Calculate spawn ID based on entry direction (opposite of travel direction)
			var entry_dir: int = _get_opposite_direction(direction_to_town)
			var spawn_id: String = "from_region_" + _direction_to_name(entry_dir).to_lower()

			await SceneManager.change_scene(town_scene, spawn_id)
		else:
			# No scene found for this town
			var hud := get_tree().get_first_node_in_group("hud")
			if hud and hud.has_method("show_notification"):
				hud.show_notification("Cannot enter %s - no scene available" % town_name)


## Configure the gate with town data
func setup(p_town_id: String, p_town_name: String, p_town_coords: Vector2i, p_direction: int) -> void:
	town_id = p_town_id
	town_name = p_town_name
	town_coords = p_town_coords
	direction_to_town = p_direction

	# Update label if already created
	if label_3d:
		label_3d.text = town_name


## Get opposite direction (cartesian: 0=NORTH, 1=SOUTH, 2=EAST, 3=WEST)
func _get_opposite_direction(direction: int) -> int:
	match direction:
		0: return 1  # NORTH -> SOUTH
		1: return 0  # SOUTH -> NORTH
		2: return 3  # EAST -> WEST
		3: return 2  # WEST -> EAST
	return 0


## Convert direction enum to name
func _direction_to_name(direction: int) -> String:
	match direction:
		0: return "north"
		1: return "south"
		2: return "east"
		3: return "west"
	return "center"


## Get rotation angle for direction (cartesian: 0=NORTH, 1=SOUTH, 2=EAST, 3=WEST)
static func _get_direction_angle(direction: int) -> float:
	match direction:
		0: return 0.0       # NORTH - face -Z
		1: return PI        # SOUTH - face +Z
		2: return PI / 2.0  # EAST - face +X
		3: return -PI / 2.0 # WEST - face -X
	return 0.0


## Static factory method
static func spawn_town_gate(
	parent: Node,
	pos: Vector3,
	p_town_id: String,
	p_town_name: String,
	p_town_coords: Vector2i,
	p_direction: int
) -> TownGate:
	var gate: TownGate = TownGate.new()
	gate.name = "TownGate_%s" % p_town_id
	gate.position = pos

	# Rotate to face the direction of travel
	gate.rotation.y = _get_direction_angle(p_direction)

	parent.add_child(gate)
	gate.setup(p_town_id, p_town_name, p_town_coords, p_direction)

	return gate
