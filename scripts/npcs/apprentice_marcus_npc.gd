## apprentice_marcus_npc.gd - Rescued apprentice that can become a follower
## Marcus is freed from a crystal prison in Willow Dale and can join the party
## Part of the Crystal Hearts puzzle and lost_apprentice quest
class_name ApprenticeMarcusNPC
extends FollowerNPC

const MARCUS_SPRITE_PATH := "res://assets/sprites/npcs/civilians/wizard_civilian.png"
const MARCUS_DIALOGUE_PATH := "res://data/dialogues/apprentice_marcus.json"

## Whether Marcus has been freed from the crystal prison
@export var has_been_freed: bool = false

## Track if dialogue callback is connected
var _dialogue_callback_connected: bool = false


func _ready() -> void:
	# Set identification before parent _ready()
	npc_id = "apprentice_marcus"
	npc_name = "Marcus"
	follower_id = "apprentice_marcus"
	follower_name = "Marcus"

	# Follower properties
	is_essential = true  # Cannot die permanently
	follow_distance = 3.5
	combat_range = 8.0
	combat_style = "magic"
	leash_range = 25.0

	# Combat stats - apprentice level
	max_health = 40
	current_health = 40
	follower_damage = 15
	follower_armor = 3
	attack_cooldown_time = 2.0  # Magic attacks are slower but hit harder

	# Disable wandering by default (will follow player or stay put)
	enable_wandering = false

	# Call parent _ready
	super._ready()

	# Add to appropriate groups
	add_to_group("npcs")
	add_to_group("followers")
	add_to_group("named_npcs")
	add_to_group("quest_npcs")
	add_to_group("apprentice_marcus")

	# Connect to dialogue ended signal for choice handling
	_connect_dialogue_callback()


func _exit_tree() -> void:
	_disconnect_dialogue_callback()
	super._exit_tree()


## Connect to DialogueManager for callback when dialogue ends
func _connect_dialogue_callback() -> void:
	if _dialogue_callback_connected:
		return
	if DialogueManager and not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
		_dialogue_callback_connected = true


## Disconnect dialogue callback
func _disconnect_dialogue_callback() -> void:
	if DialogueManager and DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
		_dialogue_callback_connected = false


## Static factory method to spawn Marcus after being freed
static func spawn_apprentice_marcus(parent: Node, pos: Vector3) -> ApprenticeMarcusNPC:
	var marcus := ApprenticeMarcusNPC.new()

	# Set sprite configuration before adding to tree
	if ResourceLoader.exists(MARCUS_SPRITE_PATH):
		marcus.sprite_texture = load(MARCUS_SPRITE_PATH)
	marcus.sprite_h_frames = 1
	marcus.sprite_v_frames = 1
	marcus.sprite_pixel_size = CivilianNPC.PIXEL_SIZE_WIZARD
	marcus.tint_color = Color(0.85, 0.9, 1.0)  # Slightly blue tint (magical)

	# Validate spawn position
	var validated_pos: Vector3 = CivilianNPC.validate_spawn_position(parent, pos)
	marcus.position = validated_pos

	parent.add_child(marcus)
	marcus.has_been_freed = true

	# Show notification that Marcus has been freed
	var hud: Node = parent.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("Marcus the Apprentice has been freed!")

	return marcus


## Override interact to use Marcus-specific dialogue
func interact(_interactor: Node) -> void:
	# Check if already following - use follower conversation instead
	if FollowerManager and FollowerManager.is_follower_active(follower_id):
		_show_follower_dialogue()
		return

	# Load and start the dialogue tree
	var dialogue: DialogueData = DialogueLoader.get_dialogue(MARCUS_DIALOGUE_PATH)
	if dialogue and DialogueManager:
		# Start dialogue with context for flag substitution if needed
		DialogueManager.start_dialogue(dialogue, npc_name, {"npc_id": npc_id})
	else:
		push_warning("[ApprenticeMarcusNPC] Could not load dialogue from: %s" % MARCUS_DIALOGUE_PATH)
		# Fallback to basic conversation
		_show_fallback_dialogue()


## Show dialogue when Marcus is already a follower
func _show_follower_dialogue() -> void:
	var lines: Array = []

	var idle_lines: Array[String] = [
		"This place has fascinating magical resonance...",
		"I wonder what Master Aldric would say about this.",
		"Thank you again for freeing me.",
		"I've read about places like this in my studies.",
		"My magical abilities grow stronger with each battle.",
	]

	var line: String = idle_lines[randi() % idle_lines.size()]
	lines.append(ConversationSystem.create_scripted_line(
		"Marcus",
		line,
		[],
		true  # is_end
	))

	ConversationSystem.start_scripted_dialogue(lines)


## Fallback dialogue if JSON cannot be loaded
func _show_fallback_dialogue() -> void:
	var lines: Array = []
	lines.append(ConversationSystem.create_scripted_line(
		"Marcus",
		"Thank you for freeing me from that crystal prison. I am in your debt.",
		[],
		true
	))
	ConversationSystem.start_scripted_dialogue(lines)


## Called when any dialogue ends - check if player made a choice about Marcus
func _on_dialogue_ended(dialogue_data: DialogueData) -> void:
	# Only process if this was Marcus's dialogue
	if not dialogue_data or dialogue_data.id != "apprentice_marcus":
		return

	if not DialogueManager:
		return

	# Check if player chose to have Marcus join
	if DialogueManager.has_flag("marcus_joined_party"):
		_become_follower()
	elif DialogueManager.has_flag("marcus_sent_home"):
		_teleport_to_dalhurst()


## Become a follower and start following the player
func _become_follower() -> void:
	# Check if already following
	if FollowerManager and FollowerManager.is_follower_active(follower_id):
		return

	# Add to follower manager
	if FollowerManager:
		var success: bool = FollowerManager.add_follower(self)
		if success:
			var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
			if player:
				start_following(player)

			# Unlock follower for future recruitment if dismissed
			FollowerManager.unlock_follower(follower_id)


## Teleport Marcus to Dalhurst (remove from current scene)
func _teleport_to_dalhurst() -> void:
	# Store that Marcus went home for save data
	if DialogueManager:
		DialogueManager.set_flag("marcus_in_dalhurst", true)

	# The NPC will be spawned in Dalhurst later via save data
	_disconnect_dialogue_callback()
	queue_free()


## Override attack for magic-style combat
func _perform_attack() -> void:
	_is_attacking = true

	# Magic attack visual - blue flash
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(0.5, 0.7, 1.5)  # Blue glow for magic
		get_tree().create_timer(0.25).timeout.connect(func():
			if billboard and billboard.sprite:
				billboard.sprite.modulate = tint_color
			_is_attacking = false
		)

	# Deal magic damage to target
	if is_instance_valid(_current_target) and _current_target.has_method("take_damage"):
		_current_target.take_damage(follower_damage, Enums.DamageType.MAGIC, self)

	# Play magic sound
	if AudioManager:
		AudioManager.play_sfx("magic_attack")


## Get combat line for when entering combat
func get_combat_line() -> String:
	var lines: Array[String] = [
		"By the Three Gods!",
		"My magic will protect you!",
		"I've read about creatures like this!",
		"Stand back - I'll handle this!",
		"Time to put my studies to use!",
	]
	return lines[randi() % lines.size()]


## Get serialized data for save/load
func get_save_data() -> Dictionary:
	var data: Dictionary = super.get_save_data()
	data["has_been_freed"] = has_been_freed
	data["npc_type"] = "apprentice_marcus"  # For respawn identification
	return data


## Load data from serialized dict
func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)
	has_been_freed = data.get("has_been_freed", false)


## Get interaction prompt
func get_interaction_prompt() -> String:
	if FollowerManager and FollowerManager.is_follower_active(follower_id):
		return "Talk to Marcus (Following)"
	return "Talk to Marcus"
