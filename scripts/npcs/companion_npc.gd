## companion_npc.gd - Combat companion NPC that fights alongside the player
## Different from EscortNPC (non-combatant) - companions actively participate in combat
## Use cases: boat voyage defense, guild questline rewards, Red Mara recruitment
class_name CompanionNPC
extends FollowerNPC

## Companion-specific signals
signal companion_attacked(target: Node)
signal companion_killed_enemy(enemy: Node)
signal companion_knocked_out(companion_id: String)
signal companion_revived(companion_id: String)
signal companion_command_received(command: String)

## Command types
enum CompanionCommand {
	FOLLOW,          ## Default - follow player, auto-engage enemies
	WAIT,            ## Stay in place, defend position
	ATTACK_TARGET,   ## Attack specific target
	DEFEND_POSITION, ## Hold position and attack enemies that come close
}

## Current command
var current_command: CompanionCommand = CompanionCommand.FOLLOW

## Companion data resource
var companion_data: CompanionData = null

## Companion identification (separate from follower_id for clarity)
@export var companion_id: String = ""

## Combat configuration (can override CompanionData)
@export var ai_behavior: CompanionData.AIBehavior = CompanionData.AIBehavior.BALANCED
@export var preferred_attack_range: float = 2.0

## Engagement rules - respects player combat state
var player_in_combat: bool = false
var engaged_enemies: Array[Node] = []  ## Enemies we've already engaged
var _command_target: Node = null  ## Target for ATTACK_TARGET command
var _defend_position: Vector3 = Vector3.ZERO  ## Position for DEFEND_POSITION

## Combat stats
var _last_attack_time: float = 0.0
var _attack_windup: float = 0.0
var _is_attacking_animation: bool = false

## Knockback immunity timer (prevents stun-lock)
var _knockback_immunity_timer: float = 0.0
const KNOCKBACK_IMMUNITY_DURATION: float = 0.5

## Kill tracking for wave defense
var kills_this_session: int = 0

## Recovery state
var _knockout_timer: float = 0.0
var _is_knocked_out: bool = false

## Combat barks cooldown
var _bark_cooldown: float = 0.0
const BARK_COOLDOWN_TIME: float = 10.0


func _ready() -> void:
	# Set companion as essential by default
	is_essential = true

	# Initialize from companion_data if available
	if companion_data:
		_init_from_companion_data()

	# Generate IDs if not set
	if companion_id.is_empty():
		companion_id = "companion_%d" % get_instance_id()

	# Call parent ready (sets up follower behavior)
	super._ready()

	# Add to companion-specific group
	add_to_group("companions")
	add_to_group("player_allies")

	# Remove from civilians (companions aren't regular civilians)
	remove_from_group("civilians")

	# Register with CompanionManager (use safe access)
	var comp_mgr: Node = get_node_or_null("/root/CompanionManager")
	if comp_mgr and comp_mgr.has_method("register_companion"):
		comp_mgr.register_companion(self)


func _exit_tree() -> void:
	# Unregister from CompanionManager (use safe access)
	var comp_mgr: Node = get_node_or_null("/root/CompanionManager")
	if comp_mgr and comp_mgr.has_method("unregister_companion"):
		comp_mgr.unregister_companion(self)

	super._exit_tree()


## Initialize from CompanionData resource
func _init_from_companion_data() -> void:
	if not companion_data:
		return

	companion_id = companion_data.id
	follower_id = companion_data.id
	follower_name = companion_data.display_name
	npc_name = companion_data.display_name

	# Stats
	max_health = companion_data.max_health
	current_health = max_health
	follower_damage = companion_data.base_damage
	follower_armor = companion_data.armor
	attack_cooldown_time = companion_data.attack_cooldown
	combat_range = companion_data.combat_range
	preferred_attack_range = companion_data.attack_range
	ai_behavior = companion_data.ai_behavior

	# Sprite configuration
	if not companion_data.sprite_path.is_empty():
		sprite_texture = load(companion_data.sprite_path) as Texture2D
		sprite_h_frames = companion_data.sprite_h_frames
		sprite_v_frames = companion_data.sprite_v_frames
		sprite_pixel_size = companion_data.sprite_pixel_size
		tint_color = companion_data.tint_color


func _physics_process(delta: float) -> void:
	# Handle knocked out state
	if _is_knocked_out:
		_process_knocked_out(delta)
		return

	# Update knockback immunity
	if _knockback_immunity_timer > 0:
		_knockback_immunity_timer -= delta

	# Update bark cooldown
	if _bark_cooldown > 0:
		_bark_cooldown -= delta

	# Update attack windup
	if _attack_windup > 0:
		_attack_windup -= delta
		if _attack_windup <= 0 and _is_attacking_animation:
			_complete_attack()

	# Check if player is in combat
	_update_player_combat_state()

	# Process based on current command
	match current_command:
		CompanionCommand.FOLLOW:
			_process_follow_command(delta)
		CompanionCommand.WAIT:
			_process_wait_command(delta)
		CompanionCommand.ATTACK_TARGET:
			_process_attack_target_command(delta)
		CompanionCommand.DEFEND_POSITION:
			_process_defend_position_command(delta)

	# Check leash periodically (from parent)
	_leash_check_timer += delta
	if _leash_check_timer >= LEASH_CHECK_INTERVAL:
		_leash_check_timer = 0.0
		_check_leash()


func _process(delta: float) -> void:
	# Update billboard facing direction based on velocity or target
	if billboard:
		if _current_target and is_instance_valid(_current_target) and _current_target is Node3D:
			var dir: Vector3 = (_current_target.global_position - global_position).normalized()
			dir.y = 0
			if dir.length() > 0.1:
				billboard.facing_direction = dir
		elif velocity.length() > 0.1:
			billboard.facing_direction = velocity.normalized()

		# Update animation state
		if _is_attacking_animation:
			billboard.set_state(BillboardSprite.AnimState.ATTACK)
		elif velocity.length() > 0.1:
			billboard.set_state(BillboardSprite.AnimState.WALK)
		else:
			billboard.set_state(BillboardSprite.AnimState.IDLE)


## Update player combat state by checking if player has aggroed enemies
func _update_player_combat_state() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			player_in_combat = false
			return

	# Check if any enemies are targeting the player
	var enemies := get_tree().get_nodes_in_group("enemies")
	player_in_combat = false

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		# Check if enemy has player as target
		if "current_target" in enemy and enemy.current_target == _player:
			player_in_combat = true
			break


## Process FOLLOW command - follow player, engage enemies when player is in combat
func _process_follow_command(delta: float) -> void:
	# Look for enemies to engage
	var target: Node = _find_best_target()

	if target:
		# Engage enemy
		_current_target = target
		_process_combat_with_target(delta)
	else:
		# No enemies - follow player
		_current_target = null
		_process_following(delta)


## Process WAIT command - stay in place, defend self
func _process_wait_command(_delta: float) -> void:
	velocity = Vector3.ZERO

	# Find nearby enemies attacking us
	var attacker: Node = _find_attacking_enemy()
	if attacker:
		_current_target = attacker
		_attack_if_in_range()
	else:
		_current_target = null


## Process ATTACK_TARGET command - pursue and attack specific target
func _process_attack_target_command(delta: float) -> void:
	if not is_instance_valid(_command_target):
		# Target gone - return to follow
		command_follow()
		return

	if _command_target.has_method("is_dead") and _command_target.is_dead():
		# Target dead - return to follow
		command_follow()
		return

	_current_target = _command_target
	_process_combat_with_target(delta)


## Process DEFEND_POSITION command - hold position, attack nearby enemies
func _process_defend_position_command(delta: float) -> void:
	# Look for enemies near the defend position
	var target: Node = _find_enemy_near_position(_defend_position, combat_range)

	if target:
		_current_target = target
		_process_combat_with_target(delta)
	else:
		# Return to defend position
		_current_target = null
		var distance_to_pos: float = global_position.distance_to(_defend_position)
		if distance_to_pos > 2.0:
			var direction: Vector3 = (_defend_position - global_position).normalized()
			direction.y = 0
			velocity = direction * wander_speed
			move_and_slide()
		else:
			velocity = Vector3.ZERO


## Process combat with current target
func _process_combat_with_target(delta: float) -> void:
	if not is_instance_valid(_current_target):
		_current_target = null
		return

	var target_pos: Vector3 = _current_target.global_position
	var distance: float = global_position.distance_to(target_pos)

	# Determine attack range based on combat style
	var attack_range: float = preferred_attack_range
	if companion_data:
		if companion_data.combat_style == CompanionData.CombatStyle.RANGED:
			attack_range = 8.0
		elif companion_data.combat_style == CompanionData.CombatStyle.MAGIC:
			attack_range = 10.0

	# Move towards target if too far
	if distance > attack_range:
		var direction: Vector3 = (target_pos - global_position).normalized()
		direction.y = 0
		velocity = direction * wander_speed * 2.0  # Combat speed
		move_and_slide()
	else:
		velocity = Vector3.ZERO
		_attack_if_in_range()


## Find the best target based on AI behavior
func _find_best_target() -> Node:
	match ai_behavior:
		CompanionData.AIBehavior.AGGRESSIVE:
			return _find_nearest_enemy()

		CompanionData.AIBehavior.DEFENSIVE:
			# Only engage if player is being attacked or we are
			return _find_attacking_enemy()

		CompanionData.AIBehavior.BALANCED, _:
			# Engage if player is in combat OR we're being attacked
			if player_in_combat:
				return _find_nearest_enemy()
			return _find_attacking_enemy()


## Find nearest enemy in combat range
func _find_nearest_enemy() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_distance: float = combat_range

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var distance: float = global_position.distance_to((enemy as Node3D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest


## Find an enemy that is attacking us or the player
func _find_attacking_enemy() -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		# Check if enemy is targeting us or player
		if "current_target" in enemy:
			if enemy.current_target == self or enemy.current_target == _player:
				var distance: float = global_position.distance_to((enemy as Node3D).global_position)
				if distance <= combat_range:
					return enemy

	return null


## Find enemy near a specific position
func _find_enemy_near_position(pos: Vector3, search_range: float) -> Node:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node = null
	var nearest_distance: float = search_range

	for enemy in enemies:
		if not enemy is Node3D:
			continue
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue

		var distance: float = pos.distance_to((enemy as Node3D).global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy

	return nearest


## Attack if target is in range and cooldown is ready
func _attack_if_in_range() -> void:
	if not is_instance_valid(_current_target):
		return

	if _is_attacking_animation:
		return

	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_attack_time < attack_cooldown_time:
		return

	var distance: float = global_position.distance_to(_current_target.global_position)

	# Determine attack range
	var attack_range: float = preferred_attack_range
	if companion_data and companion_data.combat_style == CompanionData.CombatStyle.RANGED:
		attack_range = 10.0

	if distance <= attack_range + 0.5:  # Small buffer
		_start_attack()


## Start attack animation/windup
func _start_attack() -> void:
	_is_attacking_animation = true
	_attack_windup = 0.3  # Brief windup
	_last_attack_time = Time.get_ticks_msec() / 1000.0

	# Visual feedback
	if billboard:
		billboard.play_attack()

	# Combat bark
	_try_combat_bark()


## Complete the attack (deal damage)
func _complete_attack() -> void:
	_is_attacking_animation = false

	if not is_instance_valid(_current_target):
		return

	# Check if still in range
	var distance: float = global_position.distance_to(_current_target.global_position)
	var attack_range: float = preferred_attack_range + 1.0

	if companion_data and companion_data.combat_style == CompanionData.CombatStyle.RANGED:
		attack_range = 12.0
		# Spawn projectile for ranged
		_fire_projectile()
		return

	if distance > attack_range:
		return

	# Deal damage
	if _current_target.has_method("take_damage"):
		var damage: int = follower_damage
		_current_target.take_damage(damage, Enums.DamageType.PHYSICAL, self)
		companion_attacked.emit(_current_target)

		# Check if enemy died from this attack
		if _current_target.has_method("is_dead") and _current_target.is_dead():
			_on_enemy_killed(_current_target)


## Fire projectile for ranged attacks
func _fire_projectile() -> void:
	if not is_instance_valid(_current_target):
		return

	# Use projectile from companion data or default
	var projectile_path: String = "res://resources/projectiles/arrow_basic.tres"
	if companion_data and not companion_data.ranged_projectile_path.is_empty():
		projectile_path = companion_data.ranged_projectile_path

	var projectile_data: ProjectileData = load(projectile_path) as ProjectileData
	if not projectile_data:
		# Fall back to melee damage
		if _current_target.has_method("take_damage"):
			_current_target.take_damage(follower_damage, Enums.DamageType.PHYSICAL, self)
		return

	# Calculate direction to target
	var target_pos: Vector3 = _current_target.global_position + Vector3(0, 1.0, 0)
	var spawn_pos: Vector3 = global_position + Vector3(0, 1.5, 0)
	var direction: Vector3 = (target_pos - spawn_pos).normalized()

	# Spawn projectile via CombatManager
	if CombatManager and CombatManager.has_method("spawn_projectile"):
		CombatManager.spawn_projectile(projectile_data, self, spawn_pos, direction)


## Called when companion kills an enemy
func _on_enemy_killed(enemy: Node) -> void:
	kills_this_session += 1
	companion_killed_enemy.emit(enemy)

	# Track enemy no longer engaged
	if enemy in engaged_enemies:
		engaged_enemies.erase(enemy)

	# Notify wave spawner for kill tracking
	var wave_spawners := get_tree().get_nodes_in_group("wave_spawners")
	for spawner in wave_spawners:
		if spawner.has_signal("enemy_killed"):
			spawner.enemy_killed.emit(enemy)


## Try to play a combat bark
func _try_combat_bark() -> void:
	if _bark_cooldown > 0:
		return

	if not companion_data or companion_data.combat_bark_lines.is_empty():
		return

	_bark_cooldown = BARK_COOLDOWN_TIME

	var bark: String = companion_data.combat_bark_lines[randi() % companion_data.combat_bark_lines.size()]
	# Show as floating text or notification
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_companion_bark"):
		hud.show_companion_bark(follower_name, bark)


## ============================================================================
## COMMAND SYSTEM
## ============================================================================

## Command: Follow player
func command_follow() -> void:
	current_command = CompanionCommand.FOLLOW
	_command_target = null
	_change_state(FollowerState.FOLLOWING)
	companion_command_received.emit("follow")


## Command: Wait at current position (override parent)
func command_wait() -> void:
	current_command = CompanionCommand.WAIT
	_defend_position = global_position
	_change_state(FollowerState.WAITING)
	companion_command_received.emit("wait")


## Command: Attack a specific target
func command_attack_target(target: Node) -> void:
	if not is_instance_valid(target):
		return

	current_command = CompanionCommand.ATTACK_TARGET
	_command_target = target
	_change_state(FollowerState.COMBAT)
	companion_command_received.emit("attack")


## Command: Defend a specific position
func command_defend_position(pos: Vector3) -> void:
	current_command = CompanionCommand.DEFEND_POSITION
	_defend_position = pos
	_change_state(FollowerState.FOLLOWING)
	companion_command_received.emit("defend")


## ============================================================================
## BOAT COMBAT INTEGRATION
## ============================================================================

## Boat combat bounds for deck constraint
var _boat_deck_bounds: AABB = AABB()
var _is_boat_combat: bool = false
var _target_position: Vector3 = Vector3.ZERO
var _moving_to_position: bool = false

## Setup companion for boat combat mode
func setup_boat_combat(deck_bounds: AABB) -> void:
	_boat_deck_bounds = deck_bounds
	_is_boat_combat = true

	# Set aggressive behavior during boat combat
	ai_behavior = CompanionData.AIBehavior.AGGRESSIVE


## Move companion to a specific position (for strategic positioning)
func move_to_position(pos: Vector3) -> void:
	# Constrain position to deck bounds if in boat combat
	if _is_boat_combat and _boat_deck_bounds.has_volume():
		pos.x = clamp(pos.x, _boat_deck_bounds.position.x, _boat_deck_bounds.end.x)
		pos.z = clamp(pos.z, _boat_deck_bounds.position.z, _boat_deck_bounds.end.z)
		pos.y = _boat_deck_bounds.position.y + 0.5  # Stay on deck

	_target_position = pos
	_moving_to_position = true

	# Use navigation agent if available
	if _navigation_agent:
		_navigation_agent.set_target_position(pos)


## Called every physics frame - override to add boat combat constraint
func _process_following(delta: float) -> void:
	# If moving to a specific position, go there first
	if _moving_to_position:
		var dist_to_target: float = global_position.distance_to(_target_position)
		if dist_to_target < 1.0:
			_moving_to_position = false
		else:
			# Move toward target position
			var direction: Vector3 = (_target_position - global_position).normalized()
			direction.y = 0
			velocity = direction * wander_speed * 1.5
			move_and_slide()
			_constrain_to_deck()
			return

	# Normal following behavior
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if not _player:
			return

	var distance_to_player: float = global_position.distance_to(_player.global_position)

	# If too close, don't move
	if distance_to_player < follow_distance:
		velocity = Vector3.ZERO
		return

	# Use navigation agent for pathfinding if available
	if _navigation_agent and _navigation_agent.is_navigation_finished() == false:
		_navigation_agent.set_target_position(_player.global_position)
		var next_pos: Vector3 = _navigation_agent.get_next_path_position()
		var direction: Vector3 = (next_pos - global_position).normalized()
		direction.y = 0
		velocity = direction * wander_speed
	else:
		# Direct movement fallback
		var direction: Vector3 = (_player.global_position - global_position).normalized()
		direction.y = 0
		velocity = direction * wander_speed

	move_and_slide()

	# Constrain to deck during boat combat
	_constrain_to_deck()


## Constrain position to boat deck bounds
func _constrain_to_deck() -> void:
	if not _is_boat_combat or not _boat_deck_bounds.has_volume():
		return

	var pos: Vector3 = global_position

	# Clamp to deck bounds
	pos.x = clamp(pos.x, _boat_deck_bounds.position.x, _boat_deck_bounds.end.x)
	pos.z = clamp(pos.z, _boat_deck_bounds.position.z, _boat_deck_bounds.end.z)

	# Keep on deck surface
	if pos.y < _boat_deck_bounds.position.y:
		pos.y = _boat_deck_bounds.position.y + 0.1

	global_position = pos


## Clear boat combat mode
func clear_boat_combat() -> void:
	_is_boat_combat = false
	_boat_deck_bounds = AABB()
	_moving_to_position = false

	# Restore balanced behavior
	ai_behavior = CompanionData.AIBehavior.BALANCED


## Enter combat mode (public interface for CompanionManager)
func enter_combat() -> void:
	_change_state(FollowerState.COMBAT)

	# Find nearest enemy to engage
	var nearest: Node = _find_nearest_enemy()
	if nearest:
		_current_target = nearest


## Exit combat mode (public interface for CompanionManager)
func exit_combat() -> void:
	_change_state(FollowerState.FOLLOWING)
	_current_target = null
	engaged_enemies.clear()


## ============================================================================
## DAMAGE & KNOCKOUT SYSTEM
## ============================================================================

## Override take_damage for companion-specific handling
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead or _is_knocked_out:
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

	# Play hurt animation
	if billboard:
		billboard.play_hurt()

	# If attacked by an enemy, engage them (unless on WAIT command)
	if attacker and not attacker.is_in_group("player"):
		if current_command != CompanionCommand.WAIT:
			if attacker is Node3D and not _is_knocked_out:
				_current_target = attacker
				if not attacker in engaged_enemies:
					engaged_enemies.append(attacker)

	# Check for knockout
	if current_health <= 0:
		if is_essential:
			_go_knocked_out()
		else:
			_die(attacker)

	return actual_damage


## Go knocked out instead of dying
func _go_knocked_out() -> void:
	_is_knocked_out = true
	current_health = 0
	velocity = Vector3.ZERO
	_current_target = null

	# Set knockout timer (0 = recover after combat)
	var duration: float = 30.0  # Default 30 seconds
	if companion_data and companion_data.knockout_duration > 0:
		duration = companion_data.knockout_duration
	_knockout_timer = duration

	# Visual feedback - darken and drop
	if billboard and billboard.sprite:
		billboard.sprite.modulate = Color(0.3, 0.3, 0.3)
		billboard.play_death()

	# Play knockout voice line
	if companion_data and not companion_data.knockout_lines.is_empty():
		var line: String = companion_data.knockout_lines[randi() % companion_data.knockout_lines.size()]
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_companion_bark"):
			hud.show_companion_bark(follower_name, line)

	companion_knocked_out.emit(companion_id)
	became_unconscious.emit()


## Process knocked out state
func _process_knocked_out(delta: float) -> void:
	_knockout_timer -= delta

	# Also check if combat is over (recover early)
	var enemies_alive: bool = false
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			# Check if enemy is near
			if enemy is Node3D:
				var dist: float = global_position.distance_to((enemy as Node3D).global_position)
				if dist < combat_range * 2:
					enemies_alive = true
					break

	# Recover if timer expired OR combat is over
	if _knockout_timer <= 0 or not enemies_alive:
		revive()


## Revive from knockout
func revive() -> void:
	_is_knocked_out = false
	_knockout_timer = 0.0

	# Recover to partial health
	current_health = max_health / 2

	# Restore visual
	if billboard and billboard.sprite:
		billboard.sprite.modulate = tint_color if tint_color else Color.WHITE

	# Resume following
	current_command = CompanionCommand.FOLLOW
	_change_state(FollowerState.FOLLOWING)

	# Play recovery voice line
	if companion_data and not companion_data.recovery_lines.is_empty():
		var line: String = companion_data.recovery_lines[randi() % companion_data.recovery_lines.size()]
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_companion_bark"):
			hud.show_companion_bark(follower_name, line)

	companion_revived.emit(companion_id)
	recovered.emit()


## Check if knocked out
func is_knocked_out() -> bool:
	return _is_knocked_out


## ============================================================================
## SERIALIZATION
## ============================================================================

## Get save data (extends parent)
func get_save_data() -> Dictionary:
	var data: Dictionary = super.get_save_data()

	# Add companion-specific data
	data["companion_id"] = companion_id
	data["companion_data_path"] = companion_data.resource_path if companion_data else ""
	data["ai_behavior"] = ai_behavior
	data["current_command"] = current_command
	data["kills_this_session"] = kills_this_session
	data["is_knocked_out"] = _is_knocked_out
	data["knockout_timer"] = _knockout_timer

	return data


## Load save data (extends parent)
func load_save_data(data: Dictionary) -> void:
	super.load_save_data(data)

	companion_id = data.get("companion_id", companion_id)

	var data_path: String = data.get("companion_data_path", "")
	if not data_path.is_empty() and ResourceLoader.exists(data_path):
		companion_data = load(data_path) as CompanionData
		_init_from_companion_data()

	ai_behavior = data.get("ai_behavior", ai_behavior)
	current_command = data.get("current_command", CompanionCommand.FOLLOW)
	kills_this_session = data.get("kills_this_session", 0)
	_is_knocked_out = data.get("is_knocked_out", false)
	_knockout_timer = data.get("knockout_timer", 0.0)


## ============================================================================
## STATIC FACTORY
## ============================================================================

## Spawn a companion from CompanionData
static func spawn_companion_from_data(
	parent: Node,
	pos: Vector3,
	data: CompanionData
) -> CompanionNPC:
	if not data:
		push_error("[CompanionNPC] Cannot spawn companion without CompanionData")
		return null

	var companion := CompanionNPC.new()
	companion.companion_data = data
	companion.position = pos

	parent.add_child(companion)
	return companion


## Spawn a companion manually (without CompanionData resource)
static func spawn_companion(
	parent: Node,
	pos: Vector3,
	p_companion_id: String,
	p_companion_name: String,
	sprite_path: String,
	h_frames: int = 5,
	v_frames: int = 1,
	pixel_size: float = 0.0256,
	p_damage: int = 15,
	p_armor: int = 10,
	p_health: int = 100
) -> CompanionNPC:
	var companion := CompanionNPC.new()

	# Set identification
	companion.companion_id = p_companion_id
	companion.follower_id = p_companion_id
	companion.follower_name = p_companion_name
	companion.npc_name = p_companion_name
	companion.npc_id = p_companion_id

	# Set stats
	companion.max_health = p_health
	companion.current_health = p_health
	companion.follower_damage = p_damage
	companion.follower_armor = p_armor

	# Set position
	companion.position = pos

	# Set sprite
	if not sprite_path.is_empty() and ResourceLoader.exists(sprite_path):
		companion.sprite_texture = load(sprite_path)
		companion.sprite_h_frames = h_frames
		companion.sprite_v_frames = v_frames
		companion.sprite_pixel_size = pixel_size

	parent.add_child(companion)
	return companion
