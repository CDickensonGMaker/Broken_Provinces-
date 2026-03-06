## jail_cell_door.gd - Cell door for jail/prison
## Requires jail key or lockpicking to unlock
class_name JailCellDoor
extends Area3D

## Reference to parent Prison
var prison: Node3D = null

## Door configuration
@export var door_name: String = "Cell Door"
@export var is_locked: bool = true
@export var lock_dc: int = 18  # Prison cells are hard to pick
@export var required_key: String = "jail_key"

## Visual components
var lock_indicator: MeshInstance3D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("lockpickable")

	collision_layer = 256  # Layer 9 for interactables
	collision_mask = 0


## Called by player interaction system
func interact(_interactor: Node) -> void:
	# Can only interact if player is jailed
	if not CrimeManager.is_jailed:
		_show_notification("The cell is empty.")
		return

	if is_locked:
		# Check for key first
		if _player_has_key():
			_unlock_with_key()
		else:
			# Show lockpick options or "need key" message
			_show_locked_options()
	else:
		_show_notification("The cell door is unlocked. You push it open.")


## Get display name for interaction prompt
func get_interaction_prompt() -> String:
	if not CrimeManager.is_jailed:
		return "Cell Door (Empty)"

	if is_locked:
		if _player_has_key():
			return "Unlock %s (Use Key)" % door_name
		else:
			return "%s (Locked - DC %d)" % [door_name, lock_dc]
	return "Open %s" % door_name


## Check if player has the required key
func _player_has_key() -> bool:
	return InventoryManager.has_item(required_key, 1)


## Unlock with key
func _unlock_with_key() -> void:
	_show_notification("You use the jail key to unlock the cell door.")
	is_locked = false
	_remove_lock_indicator()

	# Notify prison that cell door is unlocked
	if prison:
		prison.cell_door_locked = false


## Show options when locked (lockpick or need key)
func _show_locked_options() -> void:
	var has_lockpick: bool = _player_has_lockpick()

	if has_lockpick:
		# Show lockpick dialogue
		var lines: Array[Dictionary] = []
		lines.append(ConversationSystem.create_scripted_line(
			"",
			"The cell door is locked with a heavy iron lock (DC %d). The guard probably has a key." % lock_dc,
			[
				ConversationSystem.create_scripted_choice("Try to pick the lock", 1),
				ConversationSystem.create_scripted_choice("Examine the lock", 2),
				ConversationSystem.create_scripted_choice("Step back", 3)
			]
		))
		lines.append(ConversationSystem.create_scripted_line("", "You insert a lockpick into the lock...", [], true))
		lines.append(ConversationSystem.create_scripted_line("", "A sturdy iron lock. Prison-grade. The guard definitely has a key.", [], true))
		lines.append(ConversationSystem.create_scripted_line("", "You step away from the door.", [], true))

		ConversationSystem.start_scripted_dialogue(lines, _on_lockpick_choice)
	else:
		_show_notification("The cell door is locked. You need a key or lockpick.")


func _on_lockpick_choice() -> void:
	var choice: int = ConversationSystem.get_last_scripted_choice_index()
	if choice == 1:
		_attempt_lockpick()
	# Choices 2 and 3 just showed info/cancelled


## Attempt to lockpick the door
func _attempt_lockpick() -> void:
	if not _player_has_lockpick():
		_show_notification("You need a lockpick!")
		return

	var char_data := GameManager.player_data
	if not char_data:
		return

	var lockpicking_skill: int = char_data.get_skill(Enums.Skill.LOCKPICKING)
	var agility: int = char_data.get_effective_stat(Enums.Stat.AGILITY)

	# Check lockpick break (prison locks are tough)
	var break_chance: float = maxf(0.15, 0.55 - (lockpicking_skill * 0.04))
	var lockpick_broke: bool = randf() < break_chance

	# Consume lockpick
	InventoryManager.remove_item("lockpick", 1)

	if lockpick_broke:
		_show_notification("The lockpick broke!")
		if prison:
			prison.escape_attempted.emit(false)
		return

	# Lockpick check (prison lock is harder - 1.5x difficulty)
	var roll_result: Dictionary = DiceManager.lockpick_check(
		agility, lockpicking_skill, lock_dc, 1.5
	)

	if roll_result.get("success", false):
		_show_notification("Click! The cell door swings open.")
		is_locked = false
		_remove_lock_indicator()

		# Notify prison
		if prison:
			prison.cell_door_locked = false
	else:
		_show_notification("The lock holds firm...")
		if prison:
			prison.escape_attempted.emit(false)


func _player_has_lockpick() -> bool:
	for slot in InventoryManager.inventory:
		if slot.item_id == "lockpick" and slot.quantity > 0:
			return true
	return false


func _remove_lock_indicator() -> void:
	if lock_indicator and is_instance_valid(lock_indicator):
		lock_indicator.queue_free()
		lock_indicator = null


func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Static factory method
static func spawn_cell_door(parent: Node, pos: Vector3, p_prison: Node3D, p_lock_dc: int = 18) -> JailCellDoor:
	var door := JailCellDoor.new()
	door.position = pos
	door.prison = p_prison
	door.lock_dc = p_lock_dc
	door.is_locked = true
	door.required_key = "jail_key"

	# Add collision shape
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.5, 0.5)
	shape.shape = box
	shape.position = Vector3(0, 1.25, 0)
	door.add_child(shape)

	parent.add_child(door)
	return door
