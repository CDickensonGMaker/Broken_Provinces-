## quest_interactable.gd - A thing in the world a quest objective can point at
## Settles an `interact` objective (and optionally a quest choice branch and a
## world fact) the moment the player uses it. One-shot by default: a lever that
## brings a roof down does not go back up.
class_name QuestInteractable
extends StaticBody3D

## The id quest objectives name in their `target` field.
@export var object_id: String = ""
## Interaction prompt verb + noun, e.g. "Cut the gallery props".
@export var display_name: String = "Object"
@export var prompt_verb: String = "Use"
## Line shown when the player uses it. Empty shows nothing.
@export_multiline var use_message: String = ""
## Optional quest branch to commit to, written "quest_id:choice_id".
@export var choice_consequence: String = ""
## Optional durable world fact, written "flag" or "flag=value".
@export var world_flag: String = ""
## Optional flag that must be set on FlagManager before this can be used.
@export var required_flag: String = ""
## Optional lockpicking DC. Above zero, using this rolls a real
## DiceManager.lockpick_check and only settles the objective on a success - the
## machinery Chest and LockableDoor already use. A failure costs nothing but
## the attempt, so a locked quest object can never dead-end a quest.
@export var lock_dc: int = 0
## Line shown when the lock beats the player.
@export_multiline var lock_failed_message: String = "The lock holds."
## Line shown when required_flag is missing.
@export_multiline var locked_message: String = "Not yet."
## Whether using it consumes it.
@export var one_shot: bool = true
## Visual footprint of the generated placeholder body.
@export var body_size: Vector3 = Vector3(1.2, 1.4, 1.2)
## Placeholder tint. Art replaces this later; see art_replacement_manifest.md.
@export var body_color: Color = Color(0.45, 0.4, 0.3)

var used: bool = false

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("quest_interactables")

	collision_layer = 1
	collision_mask = 0

	if not get_node_or_null("Mesh"):
		_build_placeholder_body()


## Builds an untextured block so the object is findable in-engine. Deliberately
## plain: the ART RULE says agents wire, they do not author art.
func _build_placeholder_body() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var box := BoxMesh.new()
	box.size = body_size
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.roughness = 0.9
	mesh_instance.material_override = material
	mesh_instance.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	add_child(mesh_instance)

	collision_shape = CollisionShape3D.new()
	collision_shape.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision_shape.shape = shape
	collision_shape.position = Vector3(0.0, body_size.y * 0.5, 0.0)
	add_child(collision_shape)


func get_interaction_prompt() -> String:
	return "%s %s" % [prompt_verb, display_name]


func interact(_interactor: Node) -> void:
	if used and one_shot:
		return

	if not required_flag.is_empty() and FlagManager and not FlagManager.has_flag(required_flag):
		_notify(locked_message)
		return

	if lock_dc > 0 and not _pick_the_lock():
		return

	used = true

	if not object_id.is_empty() and QuestManager:
		QuestManager.on_interact(object_id)

	if not choice_consequence.is_empty() and QuestManager:
		var parts: PackedStringArray = choice_consequence.split(":")
		if parts.size() >= 2:
			QuestManager.apply_choice_consequence(parts[0], parts[1])
		else:
			push_warning("[QuestInteractable] choice_consequence needs \"quest_id:choice_id\", got \"%s\"" % choice_consequence)

	if not world_flag.is_empty() and WorldState:
		var separator: int = world_flag.find("=")
		if separator == -1:
			WorldState.set_flag(world_flag, true)
		else:
			WorldState.set_flag(world_flag.substr(0, separator).strip_edges(),
					world_flag.substr(separator + 1).strip_edges())

	if not use_message.is_empty():
		_notify(use_message)

	if one_shot and mesh_instance:
		mesh_instance.visible = false


## Rolls the player's lockpicking against lock_dc. Returns true on a success.
## Deliberately does not consume a lockpick or break one - this is a quest
## object, not a loot container, and a broken pick must never strand a quest.
func _pick_the_lock() -> bool:
	var char_data: Object = GameManager.player_data
	if char_data == null:
		return true

	var result: Dictionary = DiceManager.lockpick_check(
		char_data.get_effective_stat(Enums.Stat.AGILITY),
		char_data.get_skill(Enums.Skill.LOCKPICKING),
		lock_dc
	)

	if bool(result.get("success", false)):
		return true

	_notify(lock_failed_message)
	return false


func _notify(message: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(message)


## Static factory - the level scripts' one-liner.
static func spawn(parent: Node, pos: Vector3, p_object_id: String, p_display_name: String,
		p_verb: String = "Use", p_use_message: String = "",
		p_choice: String = "", p_world_flag: String = "") -> QuestInteractable:
	var instance := QuestInteractable.new()
	instance.name = "QuestInteractable_%s" % p_object_id
	instance.object_id = p_object_id
	instance.display_name = p_display_name
	instance.prompt_verb = p_verb
	instance.use_message = p_use_message
	instance.choice_consequence = p_choice
	instance.world_flag = p_world_flag
	parent.add_child(instance)
	instance.global_position = pos
	return instance
