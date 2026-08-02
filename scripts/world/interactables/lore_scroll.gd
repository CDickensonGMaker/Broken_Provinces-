## lore_scroll.gd - Interactable scroll that discovers lore when read
## Used for environmental storytelling in dungeons and the world
class_name LoreScroll
extends StaticBody3D

## Lore entry ID to discover when read
@export var lore_id: String = ""
## Display name for interaction prompt
@export var scroll_name: String = "Ancient Scroll"
## Optional text shown before codex entry (for flavor)
@export_multiline var preview_text: String = ""
## Whether the scroll can be picked up as an item
@export var can_pickup: bool = false
## Item ID if this scroll becomes an inventory item
@export var item_id: String = ""

## Internal state
var _has_been_read: bool = false
var mesh_instance: MeshInstance3D
var interaction_area: Area3D


func _ready() -> void:
	add_to_group("interactable")

	# Create visual mesh if not present
	if not get_node_or_null("Mesh"):
		_create_scroll_mesh()
	else:
		mesh_instance = get_node_or_null("Mesh")

	# Create interaction area if not present
	if not get_node_or_null("InteractionArea"):
		_create_interaction_area()
	else:
		interaction_area = get_node_or_null("InteractionArea")

	# Setup collision
	collision_layer = 1
	collision_mask = 0


func _create_scroll_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	# Create a simple scroll-like cylinder
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.05
	cylinder.bottom_radius = 0.05
	cylinder.height = 0.3
	mesh_instance.mesh = cylinder
	mesh_instance.rotation_degrees = Vector3(0, 0, 90)  # Lay it on its side
	mesh_instance.position = Vector3(0, 0.05, 0)

	# Apply parchment-like material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.85, 0.78, 0.62)  # Aged parchment
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mesh_instance.material_override = material

	add_child(mesh_instance)


func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.3, 0.4)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.15, 0)
	interaction_area.add_child(col_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Discover the lore entry
	if not lore_id.is_empty() and CodexManager:
		var discovered: bool = CodexManager.discover_lore(lore_id)
		if discovered:
			_show_notification("New knowledge discovered: %s" % _get_lore_title())
		elif CodexManager.is_lore_discovered(lore_id):
			_show_notification("You have already read this.")

	# Show preview text if any
	if not preview_text.is_empty():
		_show_preview_dialogue()

	_has_been_read = true

	# Optionally pick up as item
	if can_pickup and not item_id.is_empty():
		if InventoryManager.add_item(item_id, 1):
			_show_notification("Picked up %s" % scroll_name)
			queue_free()


func _get_lore_title() -> String:
	if CodexManager:
		var lore_entry: Dictionary = CodexManager.get_lore(lore_id)
		return lore_entry.get("title", lore_id)
	return lore_id


func _show_notification(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


func _show_preview_dialogue() -> void:
	# Use ConversationSystem for simple scripted dialogue
	if not ConversationSystem:
		return

	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		scroll_name,
		preview_text,
		[],
		true  # is_end
	))

	ConversationSystem.start_scripted_dialogue(lines, func(): pass)


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Read " + scroll_name


## Static factory method
static func spawn_scroll(parent: Node, pos: Vector3, p_lore_id: String, p_name: String = "Ancient Scroll") -> LoreScroll:
	var instance := LoreScroll.new()
	instance.position = pos
	instance.lore_id = p_lore_id
	instance.scroll_name = p_name

	# Add collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.1, 0.1)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.05, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
