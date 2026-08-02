## lore_tablet.gd - Interactable stone tablet that discovers lore when examined
## Used for environmental storytelling in dungeons and ruins
class_name LoreTablet
extends StaticBody3D

## Lore entry ID to discover when examined
@export var lore_id: String = ""
## Display name for interaction prompt
@export var tablet_name: String = "Stone Tablet"
## Optional text inscription visible on the tablet
@export_multiline var inscription_text: String = ""
## Whether the tablet requires a skill check to read (ancient languages)
@export var requires_skill_check: bool = false
## History or Arcana skill required to read (0 = no check)
@export var skill_dc: int = 0
## Use Arcana instead of History for the skill check
@export var use_arcana: bool = false

## Visual elements
var mesh_instance: MeshInstance3D
var interaction_area: Area3D


func _ready() -> void:
	add_to_group("interactable")

	# Create visual mesh if not present
	if not get_node_or_null("Mesh"):
		_create_tablet_mesh()
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


func _create_tablet_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"

	# Create a slab-like box for the tablet
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.8, 0.1)
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(0, 0.4, 0)

	# Apply stone material
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.43, 0.40)  # Gray stone
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.9
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
	box.size = Vector3(0.8, 1.0, 0.4)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.5, 0)
	interaction_area.add_child(col_shape)


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Check if skill check is required
	if requires_skill_check and skill_dc > 0:
		var success: bool = _perform_skill_check()
		if not success:
			_show_notification("You cannot decipher the ancient script.")
			return

	# Discover the lore entry
	if not lore_id.is_empty() and CodexManager:
		var discovered: bool = CodexManager.discover_lore(lore_id)
		if discovered:
			_show_notification("New knowledge discovered: %s" % _get_lore_title())
		elif CodexManager.is_lore_discovered(lore_id):
			_show_notification("You have already deciphered this tablet.")

	# Show inscription text
	if not inscription_text.is_empty():
		_show_inscription_dialogue()


func _perform_skill_check() -> bool:
	if not GameManager.player_data:
		return false

	var skill_enum: int = Enums.Skill.ARCANA_LORE if use_arcana else Enums.Skill.HISTORY
	var skill_value: int = GameManager.player_data.get_skill(skill_enum)

	# Simple passive check (no roll)
	return skill_value >= skill_dc


func _get_lore_title() -> String:
	if CodexManager:
		var lore_entry: Dictionary = CodexManager.get_lore(lore_id)
		return lore_entry.get("title", lore_id)
	return lore_id


func _show_notification(text: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


func _show_inscription_dialogue() -> void:
	# Use ConversationSystem for simple scripted dialogue
	if not ConversationSystem:
		return

	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		tablet_name,
		inscription_text,
		[],
		true  # is_end
	))

	ConversationSystem.start_scripted_dialogue(lines, func(): pass)


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	return "Examine " + tablet_name


## Static factory method
static func spawn_tablet(parent: Node, pos: Vector3, p_lore_id: String, p_name: String = "Stone Tablet", p_inscription: String = "") -> LoreTablet:
	var instance := LoreTablet.new()
	instance.position = pos
	instance.lore_id = p_lore_id
	instance.tablet_name = p_name
	instance.inscription_text = p_inscription

	# Add collision shape
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.8, 0.1)
	col_shape.shape = box
	col_shape.position = Vector3(0, 0.4, 0)
	instance.add_child(col_shape)

	parent.add_child(instance)
	return instance
