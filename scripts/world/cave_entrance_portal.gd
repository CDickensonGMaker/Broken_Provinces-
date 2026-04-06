## cave_entrance_portal.gd - Cave entrance with GLB model, collision, and portal trigger
## Loads a cave_entrance.glb model and sets up collision for rock meshes
## and an Area3D trigger for the cave_darkness mesh (portal)
class_name CaveEntrancePortal
extends Node3D

## Portal entered signal - emitted when player enters the darkness trigger
signal portal_entered(portal: CaveEntrancePortal)

## Cave system configuration
@export_group("Cave System")
## Unique identifier for this cave system
@export var cave_system_id: String = ""
## Destination spawn point within the cave
@export var destination: String = "default"
## Whether this entrance functions as a portal (triggers scene transition)
@export var is_portal: bool = true
## Scene path to load when entering the cave
@export_file("*.tscn") var link_to_scene: String = ""

## Portal configuration
@export_group("Portal Settings")
## Name shown in interaction prompt
@export var entrance_name: String = "Cave Entrance"
## Cooldown between portal uses (prevents accidental re-entry)
@export var cooldown_duration: float = 1.0
## Whether the entrance is locked
@export var is_locked: bool = false
## Lock difficulty (0 = key required, 1-10 = lockpicking skill check)
@export var lock_difficulty: int = 0

## Internal state
var _portal_area: Area3D
var _cooldown_timer: float = 0.0
var _is_player_inside: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cave_entrances")

	# Find or create the portal trigger area
	_setup_portal_area()

	# Register as compass POI
	_register_compass_poi()


func _process(delta: float) -> void:
	if _cooldown_timer > 0:
		_cooldown_timer -= delta


## Setup the Area3D portal trigger
func _setup_portal_area() -> void:
	# Look for existing PortalTrigger node (from scene)
	_portal_area = get_node_or_null("PortalTrigger")

	if _portal_area:
		# Connect signals
		if not _portal_area.body_entered.is_connected(_on_body_entered):
			_portal_area.body_entered.connect(_on_body_entered)
		if not _portal_area.body_exited.is_connected(_on_body_exited):
			_portal_area.body_exited.connect(_on_body_exited)


## Called when a body enters the portal trigger area
func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return

	_is_player_inside = true

	# Only auto-trigger if cooldown is done
	if _cooldown_timer > 0:
		return

	if is_locked:
		_handle_locked_entrance()
		return

	_trigger_portal()


## Called when a body exits the portal trigger area
func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_is_player_inside = false


## Handle interaction (E key) when near the entrance
func interact(_interactor: Node) -> void:
	if _cooldown_timer > 0:
		return

	if is_locked:
		_handle_locked_entrance()
		return

	_trigger_portal()


## Get interaction prompt text
func get_interaction_prompt() -> String:
	if is_locked:
		if lock_difficulty > 0:
			return "Locked - %s (Lockpicking %d)" % [entrance_name, lock_difficulty]
		return "Locked - %s" % entrance_name
	return "Enter %s" % entrance_name


## Trigger the portal transition
func _trigger_portal() -> void:
	if not is_portal:
		return

	_cooldown_timer = cooldown_duration
	portal_entered.emit(self)

	# Play sound
	if AudioManager:
		AudioManager.play_sfx("door_open")

	# Transition to cave scene
	if link_to_scene.is_empty():
		push_warning("[CaveEntrancePortal] No link_to_scene specified for %s" % name)
		return

	if SceneManager:
		SceneManager.change_scene(link_to_scene, destination)


## Handle locked entrance
func _handle_locked_entrance() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		if lock_difficulty > 0:
			hud.show_notification("This entrance is locked (Lockpicking %d required)" % lock_difficulty)
		else:
			hud.show_notification("This entrance is locked")

	if AudioManager:
		AudioManager.play_sfx("door_locked")


## Unlock the entrance
func unlock() -> void:
	is_locked = false

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("%s unlocked" % entrance_name)

	if AudioManager:
		AudioManager.play_sfx("door_unlock")


## Register as compass POI
func _register_compass_poi() -> void:
	add_to_group("compass_poi")
	set_meta("poi_id", "cave_%s_%d" % [cave_system_id, get_instance_id()])
	set_meta("poi_name", entrance_name)
	set_meta("poi_color", Color(0.5, 0.4, 0.3))  # Brown/cave color


## Get save data for this entrance
func get_save_data() -> Dictionary:
	return {
		"is_locked": is_locked,
		"cave_system_id": cave_system_id
	}


## Load save data
func load_save_data(data: Dictionary) -> void:
	if data.has("is_locked"):
		is_locked = data.is_locked


## Static factory method for spawning cave entrances
static func spawn_cave_entrance(
	parent: Node,
	pos: Vector3,
	p_cave_system_id: String,
	p_destination: String,
	p_link_to_scene: String,
	p_entrance_name: String = "Cave Entrance"
) -> CaveEntrancePortal:
	var entrance := CaveEntrancePortal.new()
	entrance.position = pos
	entrance.cave_system_id = p_cave_system_id
	entrance.destination = p_destination
	entrance.link_to_scene = p_link_to_scene
	entrance.entrance_name = p_entrance_name
	entrance.is_portal = true

	parent.add_child(entrance)
	return entrance
