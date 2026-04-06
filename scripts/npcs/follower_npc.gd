## follower_npc.gd - Base follower class for NPC companions
## Followers can follow the player, engage in combat, and persist across zone transitions
class_name FollowerNPC
extends CivilianNPC

## Follower AI states
enum FollowerState {
	FOLLOWING,      # Following player at distance
	COMBAT,         # Engaged with enemies
	WAITING,        # Stay command
	RETURNING,      # Coming back after leash break
	UNCONSCIOUS,    # Essential followers go down, not die
}

## Signals
signal state_changed(old_state: FollowerState, new_state: FollowerState)
signal entered_combat(enemy: Node)
signal became_unconscious
signal recovered

## Follower identification
@export var follower_id: String = ""
@export var follower_name: String = "Follower"

## Follower behavior configuration
## Note: is_essential inherited from CivilianNPC, set to true in _ready()
@export var follow_distance: float = 3.0     ## Distance to maintain behind player
@export var combat_range: float = 10.0       ## Range to detect and engage enemies
@export var leash_range: float = 20.0        ## Teleport if too far from player
@export var combat_style: String = "melee"   ## melee, ranged, magic

## Combat stats
@export var follower_damage: int = 12
@export var follower_armor: int = 10
@export var attack_cooldown_time: float = 1.5

## Current state
var current_state: FollowerState = FollowerState.FOLLOWING

## Internal references
var _player: Node3D = null
var _current_target: Node = null
var _navigation_agent: NavigationAgent3D

## Combat state
var _attack_cooldown: float = 0.0
var _is_attacking: bool = false

## Leash check timer
var _leash_check_timer: float = 0.0
const LEASH_CHECK_INTERVAL: float = 0.5

## Unconscious recovery time
const UNCONSCIOUS_DURATION: float = 30.0
var _unconscious_timer: float = 0.0


func _ready() -> void:
	# Override parent settings
	is_essential = true  # Followers should be essential by default
	enable_wandering = false  # Don't wander - follow player instead

	# Set follower name if not set
	if follower_name.is_empty():
		follower_name = npc_name
	else:
		npc_name = follower_name

	# Generate follower_id if not set
	if follower_id.is_empty():
		follower_id = "follower_%d" % get_instance_id()

	# Set npc_id for tracking
	if npc_id.is_empty():
		npc_id = follower_id

	# Call parent _ready
	super._ready()

	# Add to followers group
	add_to_group("followers")

	# Setup navigation
	_setup_navigation()


## Setup NavigationAgent3D for pathfinding
func _setup_navigation() -> void:
	_navigation_agent = NavigationAgent3D.new()
	_navigation_agent.path_desired_distance = 0.5
	_navigation_agent.target_desired_distance = follow_distance
	_navigation_agent.path_max_distance = 3.0
	_navigation_agent.navigation_layers = 1  # Default navigation layer
	add_child(_navigation_agent)


func _physics_process(delta: float) -> void:
	# Update attack cooldown
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	# Process based on current state
	match current_state:
		FollowerState.FOLLOWING:
			_process_following(delta)
		FollowerState.COMBAT:
			_process_combat(delta)
		FollowerState.WAITING:
			pass  # Do nothing when waiting
		FollowerState.RETURNING:
			_process_returning(delta)
		FollowerState.UNCONSCIOUS:
			_process_unconscious(delta)

	# Check leash periodically
	_leash_check_timer += delta
	if _leash_check_timer >= LEASH_CHECK_INTERVAL:
		_leash_check_timer = 0.0
		_check_leash()


func _process(_delta: float) -> void:
	# Update billboard facing direction based on velocity
	if billboard and velocity.length() > 0.1:
		billboard.facing_direction = velocity.normalized()

	# Update animation state
	if billboard:
		if velocity.length() > 0.1:
			billboard.set_state(BillboardSprite.AnimState.WALK)
		else:
			billboard.set_state(BillboardSprite.AnimState.IDLE)


## Process following behavior - stay behind player at follow_distance
func _process_following(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	# Check for enemies in combat range
	var nearest_enemy: Node = _find_nearest_enemy()
	if nearest_enemy:
		engage_enemy(nearest_enemy)
		return

	# Calculate target position behind player
	var player_pos: Vector3 = _player.global_position
	var player_forward: Vector3 = -_player.global_transform.basis.z.normalized()
	var target_pos: Vector3 = player_pos - player_forward * follow_distance
	target_pos.y = player_pos.y  # Stay on same height

	var distance_to_target: float = global_position.distance_to(target_pos)

	# Only move if too far from ideal position
	if distance_to_target > 1.0:
		_navigation_agent.target_position = target_pos

		if not _navigation_agent.is_navigation_finished():
			var next_position: Vector3 = _navigation_agent.get_next_path_position()
			var direction: Vector3 = (next_position - global_position).normalized()
			direction.y = 0

			var speed: float = wander_speed * 1.5  # Move faster than wander
			velocity = direction * speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO
	else:
		velocity = Vector3.ZERO


## Process combat behavior - attack current target
func _process_combat(delta: float) -> void:
	if not is_instance_valid(_current_target):
		# Target died or was freed - return to following
		_current_target = null
		_change_state(FollowerState.FOLLOWING)
		return

	# Check if target is dead
	if _current_target.has_method("is_dead") and _current_target.is_dead():
		_current_target = null
		_change_state(FollowerState.FOLLOWING)
		return

	var target_pos: Vector3 = _current_target.global_position
	var distance: float = global_position.distance_to(target_pos)

	# Move towards target if too far
	var attack_range: float = 2.0 if combat_style == "melee" else 8.0

	if distance > attack_range:
		var direction: Vector3 = (target_pos - global_position).normalized()
		direction.y = 0
		velocity = direction * wander_speed * 2.0  # Move faster in combat
		move_and_slide()
	else:
		velocity = Vector3.ZERO

		# Attack if cooldown ready
		if _attack_cooldown <= 0 and not _is_attacking:
			_perform_attack()
			_attack_cooldown = attack_cooldown_time


## Process returning behavior - teleport back if too far
func _process_returning(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	# Move towards player quickly
	var direction: Vector3 = (_player.global_position - global_position).normalized()
	direction.y = 0
	velocity = direction * wander_speed * 2.5
	move_and_slide()

	# Check if close enough to player
	var distance: float = global_position.distance_to(_player.global_position)
	if distance <= follow_distance * 1.5:
		_change_state(FollowerState.FOLLOWING)


## Process unconscious state - recover after timer
func _process_unconscious(delta: float) -> void:
	_unconscious_timer -= delta
	if _unconscious_timer <= 0:
		recover_from_unconscious()


## Start following a player
func start_following(player: Node3D) -> void:
	_player = player
	_change_state(FollowerState.FOLLOWING)


## Command follower to wait at current position
func command_wait() -> void:
	_change_state(FollowerState.WAITING)
	velocity = Vector3.ZERO


## Command follower to resume following
func command_follow() -> void:
	_change_state(FollowerState.FOLLOWING)


## Engage an enemy in combat
func engage_enemy(enemy: Node) -> void:
	_current_target = enemy
	_change_state(FollowerState.COMBAT)
	entered_combat.emit(enemy)


## Override take_damage to handle essential NPC knockout
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead or current_state == FollowerState.UNCONSCIOUS:
		return 0

	# Apply armor reduction
	var armor_mult: float = 100.0 / (100.0 + float(follower_armor))
	var reduced_amount: int = int(float(amount) * armor_mult)
	reduced_amount = maxi(1, reduced_amount)

	# Apply damage
	var actual_damage: int = mini(reduced_amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red
	if billboard and billboard.sprite:
		var original_color: Color = billboard.sprite.modulate
		billboard.sprite.modulate = Color(1.5, 0.4, 0.4)
		get_tree().create_timer(0.15).timeout.connect(func():
			if billboard and billboard.sprite:
				billboard.sprite.modulate = original_color
		)

	# If attacked by an enemy, engage them
	if attacker and not attacker.is_in_group("player"):
		if attacker is Node3D and current_state != FollowerState.UNCONSCIOUS:
			engage_enemy(attacker)

	# Check for knockdown
	if current_health <= 0:
		if is_essential:
			# Essential followers go unconscious
			_go_unconscious()
		else:
			# Non-essential followers can die
			_die(attacker)

	return actual_damage


## Go unconscious instead of dying
func _go_unconscious() -> void:
	_change_state(FollowerState.UNCONSCIOUS)
	current_health = 0
	_unconscious_timer = UNCONSCIOUS_DURATION
	velocity = Vector3.ZERO

	# Visual feedback - darken sprite significantly
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(0.3, 0.3, 0.3)

	became_unconscious.emit()


## Recover from unconscious state
func recover_from_unconscious() -> void:
	current_health = max_health / 2  # Recover to half health

	# Restore visual
	if billboard and billboard.sprite:
		billboard.sprite.modulate = tint_color

	_change_state(FollowerState.FOLLOWING)
	recovered.emit()


## Check leash range and teleport if too far
func _check_leash() -> void:
	if current_state == FollowerState.UNCONSCIOUS or current_state == FollowerState.WAITING:
		return

	if not is_instance_valid(_player):
		return

	var distance: float = global_position.distance_to(_player.global_position)

	if distance > leash_range:
		# Teleport to player
		var player_pos: Vector3 = _player.global_position
		var player_forward: Vector3 = -_player.global_transform.basis.z.normalized()
		var teleport_pos: Vector3 = player_pos - player_forward * follow_distance
		teleport_pos.y = player_pos.y

		global_position = teleport_pos

		# If was in combat, return to following
		if current_state == FollowerState.COMBAT:
			_current_target = null
			_change_state(FollowerState.FOLLOWING)


## Find nearest enemy in combat range
func _find_nearest_enemy() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_distance: float = combat_range

	for enemy in enemies:
		if not enemy is Node3D:
			continue

		# Skip dead enemies
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var distance: float = global_position.distance_to((enemy as Node3D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest


## Perform an attack on current target
func _perform_attack() -> void:
	_is_attacking = true

	# Visual feedback
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(1.5, 0.7, 0.7)
		get_tree().create_timer(0.2).timeout.connect(func():
			if billboard and billboard.sprite:
				billboard.sprite.modulate = tint_color
			_is_attacking = false
		)

	# Deal damage to target
	if is_instance_valid(_current_target) and _current_target.has_method("take_damage"):
		_current_target.take_damage(follower_damage, Enums.DamageType.PHYSICAL, self)


## Change follower state with signal emission
func _change_state(new_state: FollowerState) -> void:
	if new_state == current_state:
		return

	var old_state: FollowerState = current_state
	current_state = new_state
	state_changed.emit(old_state, new_state)


## Get serialized data for save/load
func get_save_data() -> Dictionary:
	return {
		"follower_id": follower_id,
		"follower_name": follower_name,
		"current_health": current_health,
		"max_health": max_health,
		"state": current_state,
		"combat_style": combat_style,
		"is_essential": is_essential,
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z
		},
		"sprite_path": sprite_texture.resource_path if sprite_texture else "",
		"h_frames": sprite_h_frames,
		"v_frames": sprite_v_frames,
		"pixel_size": sprite_pixel_size
	}


## Load data from serialized dict
func load_save_data(data: Dictionary) -> void:
	follower_id = data.get("follower_id", follower_id)
	follower_name = data.get("follower_name", follower_name)
	npc_name = follower_name
	current_health = data.get("current_health", max_health)
	max_health = data.get("max_health", max_health)
	combat_style = data.get("combat_style", combat_style)
	is_essential = data.get("is_essential", is_essential)

	var pos_data: Dictionary = data.get("position", {})
	if not pos_data.is_empty():
		global_position = Vector3(
			pos_data.get("x", 0.0),
			pos_data.get("y", 0.0),
			pos_data.get("z", 0.0)
		)


## Override armor value
func get_armor_value() -> int:
	return follower_armor


## Static factory method for spawning followers
static func spawn_follower(parent: Node, pos: Vector3, p_follower_id: String,
		p_follower_name: String, sprite_path: String, h_frames: int = 1,
		v_frames: int = 1, pixel_size: float = CivilianNPC.PIXEL_SIZE_MAN) -> FollowerNPC:
	var follower := FollowerNPC.new()

	# Set identification
	follower.follower_id = p_follower_id
	follower.follower_name = p_follower_name
	follower.npc_id = p_follower_id
	follower.npc_name = p_follower_name

	# Set position
	var validated_pos := CivilianNPC.validate_spawn_position(parent, pos)
	follower.position = validated_pos

	# Set sprite
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		follower.sprite_texture = load(sprite_path)
		follower.sprite_h_frames = h_frames
		follower.sprite_v_frames = v_frames
		follower.sprite_pixel_size = pixel_size

	parent.add_child(follower)
	return follower
