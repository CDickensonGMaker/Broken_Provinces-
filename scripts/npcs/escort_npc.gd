## escort_npc.gd - Escort NPCs for escort quests
## Non-combatant NPCs that follow the player and need protection
## Used with "escort" objective type in quest system
class_name EscortNPC
extends FollowerNPC

## Escort-specific signals
signal escort_damaged(current_hp: int, max_hp: int, damage: int)
signal escort_died(escort_id: String)
signal escort_arrived(escort_id: String, destination: String)
signal escort_started(escort_id: String)

## Escort behavior types
enum EscortBehavior {
	COWER,      # Stop and cower when enemies near (default)
	FLEE,       # Run away from enemies
	HIDE,       # Try to hide behind player
}

## Escort identification
@export var escort_id: String = ""

## Quest tracking
@export var quest_id: String = ""
@export var objective_id: String = ""

## Destination tracking
@export var destination_id: String = ""  # Location ID to reach
@export var destination_position: Vector3 = Vector3.ZERO  # World position (alternative)
@export var arrival_radius: float = 3.0  # How close to destination counts as "arrived"

## Escort behavior configuration
@export var escort_behavior: EscortBehavior = EscortBehavior.COWER
@export var fear_range: float = 8.0  # Range at which escort detects threats
@export var cower_duration: float = 3.0  # How long to cower after threat passes

## Visual feedback
@export var panic_tint: Color = Color(0.9, 0.8, 0.8)  # Tint when scared

## Internal state
var is_cowering: bool = false
var cower_timer: float = 0.0
var destination_reached: bool = false
var _original_tint: Color = Color.WHITE

## Destination marker (if using a Marker3D in the scene)
var _destination_marker: Node3D = null


func _ready() -> void:
	# Escorts are NOT essential by default - their death fails the quest
	is_essential = false

	# Escorts don't fight
	combat_range = 0.0
	combat_style = "none"

	# Generate escort_id if not set
	if escort_id.is_empty():
		escort_id = "escort_%d" % get_instance_id()

	# Set follower_id to match escort_id
	follower_id = escort_id

	# Call parent _ready
	super._ready()

	# Add to escorts group
	add_to_group("escorts")

	# Store original tint
	_original_tint = tint_color

	# Register with EscortManager (use safe access)
	var escort_mgr: Node = get_node_or_null("/root/EscortManager")
	if escort_mgr and escort_mgr.has_method("register_escort"):
		escort_mgr.register_escort(self)


func _exit_tree() -> void:
	# Unregister from EscortManager (use safe access)
	var escort_mgr: Node = get_node_or_null("/root/EscortManager")
	if escort_mgr and escort_mgr.has_method("unregister_escort"):
		escort_mgr.unregister_escort(self)

	super._exit_tree()


func _physics_process(delta: float) -> void:
	# Check for threats (enemies nearby)
	if current_state != FollowerState.UNCONSCIOUS:
		_check_for_threats()

	# Update cower timer
	if is_cowering:
		cower_timer -= delta
		if cower_timer <= 0:
			_stop_cowering()

	# Check destination arrival
	if not destination_reached:
		_check_destination_arrival()

	# Parent physics processing
	super._physics_process(delta)


## Override _process_following to handle cower behavior
func _process_following(delta: float) -> void:
	if is_cowering:
		velocity = Vector3.ZERO
		return

	# Normal following behavior
	super._process_following(delta)


## Check for nearby enemies and react
func _check_for_threats() -> void:
	if is_cowering:
		return

	var enemies := get_tree().get_nodes_in_group("enemies")
	var threat_found: bool = false

	for enemy in enemies:
		if not enemy is Node3D:
			continue

		# Skip dead enemies
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var distance: float = global_position.distance_to((enemy as Node3D).global_position)
		if distance < fear_range:
			threat_found = true
			break

	if threat_found:
		_react_to_threat()


## React to nearby threat based on behavior type
func _react_to_threat() -> void:
	match escort_behavior:
		EscortBehavior.COWER:
			_start_cowering()
		EscortBehavior.FLEE:
			_flee_from_threat()
		EscortBehavior.HIDE:
			_hide_behind_player()


## Start cowering (stop moving, show fear)
func _start_cowering() -> void:
	is_cowering = true
	cower_timer = cower_duration
	velocity = Vector3.ZERO

	# Visual feedback - pale/scared tint
	if billboard and billboard.sprite:
		billboard.sprite.modulate = panic_tint

	# Play cower animation if available
	if billboard:
		billboard.set_state(BillboardSprite.AnimState.IDLE)


## Stop cowering and resume following
func _stop_cowering() -> void:
	is_cowering = false
	cower_timer = 0.0

	# Restore normal tint
	if billboard and billboard.sprite:
		billboard.sprite.modulate = _original_tint


## Flee from threat (run opposite direction)
func _flee_from_threat() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var flee_direction: Vector3 = Vector3.ZERO

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var to_enemy: Vector3 = (enemy as Node3D).global_position - global_position
		if to_enemy.length() < fear_range:
			flee_direction -= to_enemy.normalized()

	if flee_direction.length() > 0.1:
		flee_direction = flee_direction.normalized()
		flee_direction.y = 0
		velocity = flee_direction * wander_speed * 1.5
		move_and_slide()


## Hide behind player
func _hide_behind_player() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	# Get position behind player (away from enemies)
	var player_pos: Vector3 = _player.global_position
	var enemies := get_tree().get_nodes_in_group("enemies")

	if enemies.is_empty():
		return

	# Find average enemy direction
	var avg_threat_dir: Vector3 = Vector3.ZERO
	var threat_count: int = 0
	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var to_enemy: Vector3 = (enemy as Node3D).global_position - player_pos
		if to_enemy.length() < fear_range * 2:
			avg_threat_dir += to_enemy.normalized()
			threat_count += 1

	if threat_count > 0:
		avg_threat_dir = (avg_threat_dir / float(threat_count)).normalized()
		# Position behind player relative to threat
		var hide_pos: Vector3 = player_pos - avg_threat_dir * follow_distance
		hide_pos.y = player_pos.y

		_navigation_agent.target_position = hide_pos
		if not _navigation_agent.is_navigation_finished():
			var next_position: Vector3 = _navigation_agent.get_next_path_position()
			var direction: Vector3 = (next_position - global_position).normalized()
			direction.y = 0
			velocity = direction * wander_speed * 1.2
			move_and_slide()


## Check if escort has reached destination
func _check_destination_arrival() -> void:
	if destination_reached:
		return

	var at_destination: bool = false

	# Check destination marker first
	if _destination_marker and is_instance_valid(_destination_marker):
		var distance: float = global_position.distance_to(_destination_marker.global_position)
		at_destination = distance <= arrival_radius
	# Check destination position
	elif destination_position != Vector3.ZERO:
		var distance: float = global_position.distance_to(destination_position)
		at_destination = distance <= arrival_radius
	# Check destination_id via PlayerGPS/WorldData
	elif not destination_id.is_empty():
		at_destination = _check_location_arrival(destination_id)

	if at_destination:
		_on_destination_reached()


## Check if at a named location
func _check_location_arrival(location_id: String) -> bool:
	# Check current zone
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		# Check if the scene has this location_id or zone_id
		if "zone_id" in current_scene:
			if current_scene.zone_id == location_id:
				return true
		if "location_id" in current_scene:
			if current_scene.location_id == location_id:
				return true

	# Check WorldGrid location
	if WorldGrid:
		var current_loc: Dictionary = WorldGrid.get_current_location()
		if current_loc.get("id", "") == location_id:
			return true

	return false


## Called when destination is reached
func _on_destination_reached() -> void:
	destination_reached = true

	# Emit arrival signal
	escort_arrived.emit(escort_id, destination_id)

	# Notify quest system
	if not quest_id.is_empty():
		QuestManager.on_escort_arrived(escort_id, destination_id)

	# Stop following
	velocity = Vector3.ZERO

	# Visual feedback - relief/happy
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color.WHITE


## Override take_damage for escort-specific handling
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	# Apply damage via parent
	var actual_damage: int = super.take_damage(amount, damage_type, attacker)

	# Emit escort-specific signal for UI updates
	escort_damaged.emit(current_health, max_health, actual_damage)

	# Start cowering when hit
	if not is_cowering and current_health > 0:
		_start_cowering()
		cower_timer = cower_duration * 2  # Cower longer when hit

	return actual_damage


## Override death handling - escorts die and fail the quest
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true

	# Emit death signal
	escort_died.emit(escort_id)

	# Notify quest system
	if not quest_id.is_empty():
		QuestManager.on_escort_died(escort_id, quest_id)

	# Stop movement
	velocity = Vector3.ZERO

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("escorts")
	remove_from_group("followers")

	# Visual feedback - death
	if billboard:
		billboard.play_death()

	# Show notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("%s has died!" % npc_name)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("npc_death")

	# Queue removal after short delay
	get_tree().create_timer(2.0).timeout.connect(queue_free)


## Start the escort (call when quest begins)
func start_escort(player: Node3D) -> void:
	_player = player
	_change_state(FollowerState.FOLLOWING)
	escort_started.emit(escort_id)


## Set destination marker from scene
func set_destination_marker(marker: Node3D) -> void:
	_destination_marker = marker
	destination_position = marker.global_position


## Get interaction prompt
func get_interaction_prompt() -> String:
	if current_state == FollowerState.WAITING:
		return "Tell %s to follow" % npc_name
	else:
		return "Talk to %s" % npc_name


## Handle interaction (talk to escort)
func interact(_interactor: Node) -> void:
	if current_state == FollowerState.WAITING:
		command_follow()
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			hud.show_notification("%s is now following you." % npc_name)
	else:
		# Could show dialogue or status
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_notification"):
			var status: String = "following you"
			if is_cowering:
				status = "cowering in fear"
			elif destination_reached:
				status = "relieved to have arrived safely"
			hud.show_notification("%s is %s." % [npc_name, status])


## Get health percentage for UI
func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)


## Static factory method for spawning escort NPCs
static func spawn_escort(
	parent: Node,
	pos: Vector3,
	p_escort_id: String,
	p_escort_name: String,
	sprite_path: String,
	h_frames: int = 1,
	v_frames: int = 1,
	pixel_size: float = CivilianNPC.PIXEL_SIZE_MAN,
	p_quest_id: String = "",
	p_destination_id: String = ""
) -> EscortNPC:
	var escort := EscortNPC.new()

	# Set identification
	escort.escort_id = p_escort_id
	escort.follower_id = p_escort_id
	escort.follower_name = p_escort_name
	escort.npc_id = p_escort_id
	escort.npc_name = p_escort_name

	# Set quest tracking
	escort.quest_id = p_quest_id
	escort.destination_id = p_destination_id

	# Set position
	var validated_pos := CivilianNPC.validate_spawn_position(parent, pos)
	escort.position = validated_pos

	# Set sprite
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		escort.sprite_texture = load(sprite_path)
		escort.sprite_h_frames = h_frames
		escort.sprite_v_frames = v_frames
		escort.sprite_pixel_size = pixel_size

	parent.add_child(escort)
	return escort
