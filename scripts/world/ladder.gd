## ladder.gd - Simple ladder climbing system
## Attach to a ladder mesh with child markers: ladder_bottom, ladder_top, climb_trigger_zone
extends Node3D
class_name Ladder

@export var climb_speed: float = 3.0

var current_climber: Node3D = null
var climb_area: Area3D = null
var ladder_bottom: Node3D = null
var ladder_top: Node3D = null

func _ready() -> void:
	_find_markers()
	_setup_trigger()
	print("[Ladder] %s ready - bottom_y=%.1f, top_y=%.1f" % [name, get_bottom_y(), get_top_y()])

func _find_markers() -> void:
	# Recursive search for markers
	_find_markers_recursive(self)

	if not ladder_bottom:
		push_warning("[Ladder] No ladder_bottom marker found!")
	if not ladder_top:
		push_warning("[Ladder] No ladder_top marker found!")

func _find_markers_recursive(node: Node) -> void:
	for child in node.get_children():
		var child_name: String = child.name.to_lower()

		if child_name == "ladder_bottom" and child is Node3D:
			ladder_bottom = child
		elif child_name == "ladder_top" and child is Node3D:
			ladder_top = child
		elif (child_name == "climb_trigger_zone" or child_name == "ladder_climb_area") and child is Node3D:
			_create_trigger_from_mesh(child)

		if not child is Area3D:
			_find_markers_recursive(child)

func _create_trigger_from_mesh(mesh_node: Node3D) -> void:
	# Remove any StaticBody3D collision (we want a trigger, not solid)
	for child in mesh_node.get_children():
		if child is StaticBody3D:
			child.queue_free()

	# Create Area3D trigger
	climb_area = Area3D.new()
	climb_area.name = "ClimbTrigger"
	climb_area.collision_layer = 0
	climb_area.collision_mask = 2  # Detect player (layer 2)

	# Create collision box
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 4.0, 2.0)  # Large enough to catch player
	collision.shape = box
	climb_area.add_child(collision)

	# Add to scene, then position
	add_child(climb_area)
	climb_area.global_position = mesh_node.global_position

	# Hide the marker mesh
	if mesh_node is MeshInstance3D:
		mesh_node.visible = false

	# Connect signals
	climb_area.body_entered.connect(_on_body_entered)
	climb_area.body_exited.connect(_on_body_exited)

	print("[Ladder] Trigger created at %s" % climb_area.global_position)

func _setup_trigger() -> void:
	# If no trigger zone mesh found, create one between bottom and top
	if climb_area:
		return

	if not ladder_bottom or not ladder_top:
		return

	climb_area = Area3D.new()
	climb_area.name = "ClimbTrigger"
	climb_area.collision_layer = 0
	climb_area.collision_mask = 2

	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var height: float = abs(ladder_top.global_position.y - ladder_bottom.global_position.y)
	box.size = Vector3(2.0, height, 2.0)
	collision.shape = box
	climb_area.add_child(collision)

	add_child(climb_area)
	climb_area.global_position = (ladder_bottom.global_position + ladder_top.global_position) / 2.0

	climb_area.body_entered.connect(_on_body_entered)
	climb_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	if current_climber:
		return

	print("")
	print("[Ladder] ===== PLAYER ENTERED TRIGGER =====")
	print("[Ladder] Trigger position: %s" % climb_area.global_position)
	print("[Ladder] Player position: %s" % body.global_position)
	print("[Ladder] Ladder bottom: %s" % (ladder_bottom.global_position if ladder_bottom else "null"))
	print("[Ladder] Ladder top: %s" % (ladder_top.global_position if ladder_top else "null"))

	if body.has_method("start_climbing"):
		body.start_climbing(self)
		current_climber = body

func _on_body_exited(body: Node3D) -> void:
	# DON'T auto-stop climbing on exit - let the player controller handle dismount
	# This prevents issues when snapping player position briefly moves them out of trigger
	if body == current_climber:
		# Only clear our reference, don't call stop_climbing
		# The player will stop climbing when they dismount at top/bottom
		pass

# Simple getters for player_controller
func get_bottom_y() -> float:
	return ladder_bottom.global_position.y if ladder_bottom else global_position.y

func get_top_y() -> float:
	return ladder_top.global_position.y if ladder_top else global_position.y + 5.0

func get_snap_x() -> float:
	return global_position.x

func get_snap_z() -> float:
	return global_position.z

func release_climber() -> void:
	current_climber = null


func _exit_tree() -> void:
	# Clean up signal connections to prevent memory leaks
	if climb_area:
		if climb_area.body_entered.is_connected(_on_body_entered):
			climb_area.body_entered.disconnect(_on_body_entered)
		if climb_area.body_exited.is_connected(_on_body_exited):
			climb_area.body_exited.disconnect(_on_body_exited)
