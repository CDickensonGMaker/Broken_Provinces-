## jail_guard.gd - Prison guard NPC for jail interactions
## Handles player interactions while jailed: serve time, bribe, or be killed for key
## Patrols the jail area and occasionally initiates conversation with prisoner
class_name JailGuard
extends CharacterBody3D

## Reference to parent Prison node
var prison: Node3D = null

## Region ID for bribe cost calculation
@export var region_id: String = "elder_moor"

## Guard sprite configuration
const GUARD_SPRITE := "res://assets/sprites/npcs/civilians/guard_civilian.png"
const PIXEL_SIZE := 0.0256  # Standard NPC size

## NPC identification
var npc_id: String = ""
var npc_name: String = "Jail Guard"

## Combat stats - guard is tough, needs to survive a few hits
const MAX_HEALTH := 150  # Much higher - guards are meant to be dangerous
const ARMOR := 25  # Heavy armor
const DAMAGE := 18  # Hits hard
var current_health: int = MAX_HEALTH
var _is_dead: bool = false

## Attack state
var attack_cooldown: float = 0.0
const ATTACK_COOLDOWN_TIME := 1.5
var is_in_combat: bool = false
var _target_player: Node3D = null

## Gold carried (dropped on death)
var gold_carried: int = 0

## Visual components
var billboard: BillboardSprite
var collision_shape: CollisionShape3D
var interaction_area: Area3D

## Patrol behavior
var patrol_points: Array[Vector3] = []
var current_patrol_index: int = 0
var patrol_wait_time: float = 0.0
const PATROL_WAIT_DURATION := 3.0  # Wait at each point
const PATROL_SPEED := 1.5
var _home_position: Vector3 = Vector3.ZERO

## Conversation initiation
var time_since_last_taunt: float = 0.0
const TAUNT_INTERVAL_MIN := 15.0  # Minimum seconds between taunts
const TAUNT_INTERVAL_MAX := 30.0  # Maximum seconds between taunts
var next_taunt_time: float = 20.0
var has_taunted_once: bool = false  # First taunt is quicker to help player


func _ready() -> void:
	add_to_group("npcs")
	add_to_group("interactable")
	add_to_group("attackable")
	add_to_group("jail_guards")

	# Setup collision - same as other NPCs
	collision_layer = 1
	collision_mask = 5  # Layers 1 and 3

	# Generate unique ID
	if npc_id.is_empty():
		npc_id = "jail_guard_%d" % get_instance_id()

	# Random gold
	gold_carried = randi_range(15, 35)

	_create_visual()
	_create_collision()
	_create_interaction_area()

	# Setup patrol - store home position and create patrol points
	_home_position = position
	_setup_patrol_points()

	# First taunt comes quickly to help player understand they can interact
	next_taunt_time = randf_range(8.0, 12.0)

	print("[JailGuard] Initialized at %s" % global_position)


func _exit_tree() -> void:
	# Clean up signal connections
	if ConversationSystem.scripted_line_shown.is_connected(_on_jail_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_jail_line_shown)


func _create_visual() -> void:
	var tex: Texture2D = load(GUARD_SPRITE)
	if not tex:
		push_error("[JailGuard] Failed to load sprite: %s" % GUARD_SPRITE)
		return

	billboard = BillboardSprite.new()
	billboard.sprite_sheet = tex
	billboard.h_frames = 1  # Single frame static image
	billboard.v_frames = 1
	billboard.pixel_size = PIXEL_SIZE
	billboard.idle_frames = 1
	billboard.walk_frames = 1
	billboard.idle_fps = 1.0
	billboard.walk_fps = 1.0
	billboard.name = "Billboard"
	add_child(billboard)


func _create_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.6
	collision_shape.shape = capsule
	collision_shape.position = Vector3(0, 0.8, 0)
	add_child(collision_shape)


func _create_interaction_area() -> void:
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	interaction_area.collision_layer = 256  # Layer 9 for interactables
	interaction_area.collision_mask = 0
	add_child(interaction_area)

	var area_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = 1.8
	area_shape.shape = capsule
	area_shape.position = Vector3(0, 0.9, 0)
	interaction_area.add_child(area_shape)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Combat behavior if in combat
	if is_in_combat and _target_player:
		_combat_behavior(delta)
		return  # Don't patrol while fighting

	# Patrol behavior when not in combat
	_patrol_behavior(delta)

	# Check for conversation initiation with jailed player
	_check_taunt_player(delta)


## Setup patrol points around the guard area
func _setup_patrol_points() -> void:
	# Create patrol points relative to home position
	# Guard walks around the desk area and occasionally near the cell
	patrol_points = [
		_home_position,  # At desk
		_home_position + Vector3(1.5, 0, 1.5),  # Behind desk
		_home_position + Vector3(-2.0, 0, 0),  # Near cell bars
		_home_position + Vector3(-2.0, 0, 1.5),  # Near cell door
		_home_position + Vector3(0, 0, 2.0),  # Near exit door
		_home_position + Vector3(1.5, 0, 0),  # Side of desk
	]
	current_patrol_index = 0
	patrol_wait_time = PATROL_WAIT_DURATION


## Check if we should taunt/talk to the player
func _check_taunt_player(delta: float) -> void:
	# Only taunt if player is jailed
	if not CrimeManager.is_jailed:
		return

	time_since_last_taunt += delta

	if time_since_last_taunt >= next_taunt_time:
		_initiate_taunt()
		time_since_last_taunt = 0.0
		next_taunt_time = randf_range(TAUNT_INTERVAL_MIN, TAUNT_INTERVAL_MAX)
		has_taunted_once = true


## Guard initiates conversation with player - move to cell bars and offer dialogue
func _initiate_taunt() -> void:
	# Don't interrupt if dialogue is already active
	if ConversationSystem.is_active:
		return

	# Move to cell bars position for interaction
	_move_to_cell_for_interaction()


## Move guard to cell bars so player can interact
func _move_to_cell_for_interaction() -> void:
	# Target position near cell bars (relative to home)
	var cell_position: Vector3 = _home_position + Vector3(-2.5, 0, 0)

	# If already close, start dialogue immediately
	var distance: float = position.distance_to(cell_position)
	if distance < 1.0:
		_start_interactive_taunt()
		return

	# Walk to cell position, then start dialogue
	_pending_cell_interaction = true
	_cell_interaction_target = cell_position


var _pending_cell_interaction: bool = false
var _cell_interaction_target: Vector3 = Vector3.ZERO


## Override patrol to handle cell interaction movement
func _patrol_behavior(delta: float) -> void:
	# If pending cell interaction, move there instead of patrolling
	if _pending_cell_interaction:
		var to_target: Vector3 = _cell_interaction_target - position
		to_target.y = 0
		var distance: float = to_target.length()

		if distance < 0.5:
			# Reached cell, start dialogue
			_pending_cell_interaction = false
			velocity = Vector3.ZERO
			if billboard:
				billboard.set_walking(false)
			_start_interactive_taunt()
		else:
			# Walk toward cell
			var direction: Vector3 = to_target.normalized()
			velocity = direction * PATROL_SPEED * 1.5  # Walk faster when approaching
			move_and_slide()
			if billboard:
				billboard.set_walking(true)
		return

	# Normal patrol behavior
	if patrol_points.is_empty():
		return

	# Waiting at patrol point
	if patrol_wait_time > 0:
		patrol_wait_time -= delta
		velocity = Vector3.ZERO
		if billboard:
			billboard.set_walking(false)
		return

	# Move to current patrol point
	var target: Vector3 = patrol_points[current_patrol_index]
	var to_target: Vector3 = target - position
	to_target.y = 0
	var distance: float = to_target.length()

	if distance < 0.3:
		# Reached patrol point, wait then move to next
		patrol_wait_time = randf_range(PATROL_WAIT_DURATION * 0.5, PATROL_WAIT_DURATION * 1.5)
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		velocity = Vector3.ZERO
		if billboard:
			billboard.set_walking(false)
	else:
		# Walk toward patrol point
		var direction: Vector3 = to_target.normalized()
		velocity = direction * PATROL_SPEED
		move_and_slide()
		if billboard:
			billboard.set_walking(true)


## Start interactive taunt dialogue at cell bars - directly shows jail options
func _start_interactive_taunt() -> void:
	has_taunted_once = true
	# Directly show jail options - no need for intermediate dialogue
	_show_jail_options()


## Combat AI - approach and attack player
func _combat_behavior(_delta: float) -> void:
	if not _target_player:
		return

	# Validate target still exists
	if not is_instance_valid(_target_player):
		is_in_combat = false
		_target_player = null
		return

	# Check if player is dead
	if _target_player.has_method("is_dead") and _target_player.is_dead():
		is_in_combat = false
		_target_player = null
		return

	var distance: float = global_position.distance_to(_target_player.global_position)

	if distance > 2.0:
		# Move towards player aggressively
		var direction: Vector3 = (_target_player.global_position - global_position).normalized()
		direction.y = 0
		velocity = direction * 4.0  # Faster chase speed
		move_and_slide()
		if billboard:
			billboard.set_walking(true)
	else:
		# Stop moving when in range
		velocity = Vector3.ZERO
		if billboard:
			billboard.set_walking(false)

		# Attack if cooldown is ready
		if attack_cooldown <= 0:
			_attack_player()
			attack_cooldown = ATTACK_COOLDOWN_TIME


func _attack_player() -> void:
	if not _target_player or not is_instance_valid(_target_player):
		return

	# Visual feedback - flash
	if billboard and is_instance_valid(billboard) and billboard.sprite:
		billboard.sprite.modulate = Color(1.5, 0.6, 0.6)
		var billboard_ref: BillboardSprite = billboard
		get_tree().create_timer(0.2).timeout.connect(func():
			if is_instance_valid(billboard_ref) and billboard_ref.sprite:
				billboard_ref.sprite.modulate = Color.WHITE
		)

	# Deal damage
	if _target_player.has_method("take_damage"):
		_target_player.take_damage(DAMAGE, Enums.DamageType.PHYSICAL, self)
		print("[JailGuard] Attacked player for %d damage" % DAMAGE)


## Get interaction prompt
func get_interaction_prompt() -> String:
	return "Talk to " + npc_name


## Handle player interaction
func interact(_interactor: Node) -> void:
	if _is_dead:
		return

	# Check if player is jailed
	if not CrimeManager.is_jailed:
		_show_not_jailed_dialogue()
		return

	# Show jail options
	_show_jail_options()


## Show dialogue when player isn't jailed
func _show_not_jailed_dialogue() -> void:
	var lines: Array[Dictionary] = []
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"Move along, citizen. Nothing to see here.",
		[],
		true  # is_end
	))
	ConversationSystem.start_scripted_dialogue(lines, func(): pass)


## Show jail interaction options
func _show_jail_options() -> void:
	var bounty: int = CrimeManager.get_bounty(region_id)
	var bribe_cost: int = _calculate_bribe_cost(bounty)
	var jail_time: float = CrimeManager.calculate_jail_time(region_id)
	var player_gold: int = InventoryManager.gold

	var can_afford_bribe: bool = player_gold >= bribe_cost

	# Get player skills for intimidate/negotiate
	var char_data := GameManager.player_data
	var intimidate_skill: int = 0
	var persuade_skill: int = 0
	if char_data:
		intimidate_skill = char_data.get_skill(Enums.Skill.INTIMIDATION)
		persuade_skill = char_data.get_skill(Enums.Skill.PERSUASION)

	var lines: Array[Dictionary] = []

	# Line 0: Guard's greeting with choices
	var greeting_text: String = "You've got %.1f hours left to serve. What do you want?" % jail_time
	var choices: Array[Dictionary] = [
		ConversationSystem.create_scripted_choice("I'll serve my time.", 1),
	]

	# Bribe option - show cost and whether affordable
	if can_afford_bribe:
		choices.append(ConversationSystem.create_scripted_choice(
			"Let me go. (Bribe: %d gold)" % bribe_cost, 2
		))
	else:
		choices.append(ConversationSystem.create_scripted_choice(
			"Let me go. (Bribe: %d gold - Can't afford)" % bribe_cost, 3
		))

	# Intimidate option - always available, shows skill level
	choices.append(ConversationSystem.create_scripted_choice(
		"You don't want trouble. Let me out. [Intimidate %d]" % intimidate_skill, 5
	))

	# Negotiate option - always available, shows skill level
	choices.append(ConversationSystem.create_scripted_choice(
		"Surely we can work something out... [Persuade %d]" % persuade_skill, 7
	))

	choices.append(ConversationSystem.create_scripted_choice("Never mind.", 4))

	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		greeting_text,
		choices
	))

	# Line 1: Serve time response
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"Fine. Sit tight and think about what you've done.",
		[],
		true
	))

	# Line 2: Successful bribe
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"*pockets the gold* Alright, get out of here before I change my mind.",
		[],
		true
	))

	# Line 3: Can't afford bribe
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"You don't have enough gold. Come back when you can pay.",
		[],
		true
	))

	# Line 4: Never mind
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"Then stop wasting my time.",
		[],
		true
	))

	# Line 5: Intimidate attempt (will roll in callback)
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"*The guard eyes you nervously...*",
		[],
		true
	))

	# Line 6: Intimidate success (shown after roll)
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"*sweating* A-alright, just... just go. I didn't see anything.",
		[],
		true
	))

	# Line 7: Negotiate attempt (will roll in callback)
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"*The guard considers your words...*",
		[],
		true
	))

	# Line 8: Negotiate success (shown after roll)
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"You know what, you seem reasonable. I'll let you out this time.",
		[],
		true
	))

	# Line 9: Skill check failed
	lines.append(ConversationSystem.create_scripted_line(
		npc_name,
		"Ha! Nice try. You're not going anywhere.",
		[],
		true
	))

	# Store bribe cost for later
	_pending_bribe_cost = bribe_cost

	# Track which line we end on
	if not ConversationSystem.scripted_line_shown.is_connected(_on_jail_line_shown):
		ConversationSystem.scripted_line_shown.connect(_on_jail_line_shown)

	ConversationSystem.start_scripted_dialogue(lines, _on_jail_dialogue_ended)


var _pending_bribe_cost: int = 0
var _last_jail_line_index: int = 0


func _on_jail_line_shown(_line: Dictionary, index: int) -> void:
	_last_jail_line_index = index


func _on_jail_dialogue_ended() -> void:
	# Disconnect signal
	if ConversationSystem.scripted_line_shown.is_connected(_on_jail_line_shown):
		ConversationSystem.scripted_line_shown.disconnect(_on_jail_line_shown)

	match _last_jail_line_index:
		1:  # Serve time
			_handle_serve_time()
		2:  # Successful bribe
			_handle_bribe()
		3:  # Can't afford - do nothing
			pass
		4:  # Never mind - do nothing
			pass
		5:  # Intimidate attempt
			_handle_intimidate()
		6:  # Intimidate success (from skill check)
			_handle_intimidate_success()
		7:  # Negotiate attempt
			_handle_negotiate()
		8:  # Negotiate success (from skill check)
			_handle_negotiate_success()
		9:  # Skill check failed - do nothing
			pass

	_last_jail_line_index = 0


## Handle serving time - skip time and release
func _handle_serve_time() -> void:
	var jail_time: float = CrimeManager.calculate_jail_time(region_id)

	_show_notification("You serve your time...")

	# Skip time
	if GameManager:
		GameManager.advance_time(jail_time)

	# Release player through prison
	if prison and prison.has_method("guard_releases_player"):
		prison.guard_releases_player()
	else:
		# Fallback if no prison reference
		CrimeManager.clear_bounty(region_id)
		CrimeManager.is_jailed = false
		CrimeManager.jail_region = ""
		CrimeManager.jail_time_remaining = 0.0
		_show_notification("You are free to go.")


## Handle bribe payment
func _handle_bribe() -> void:
	# Take gold
	InventoryManager.remove_gold(_pending_bribe_cost)

	_show_notification("You paid %d gold to the guard." % _pending_bribe_cost)

	# Release player through prison
	if prison and prison.has_method("guard_releases_player"):
		prison.guard_releases_player()
	else:
		# Fallback
		CrimeManager.clear_bounty(region_id)
		CrimeManager.is_jailed = false
		CrimeManager.jail_region = ""
		CrimeManager.jail_time_remaining = 0.0


## Handle intimidate attempt - perform skill check
func _handle_intimidate() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		_show_notification("Skill check failed.")
		return

	var intimidate_skill: int = char_data.get_skill(Enums.Skill.INTIMIDATION)
	var strength: int = char_data.get_effective_stat(Enums.Stat.GRIT)

	# DC 14 for guard - tough but doable
	const INTIMIDATE_DC := 14

	# Roll intimidation check (uses DiceManager)
	var roll_result: Dictionary = DiceManager.skill_check(
		strength, intimidate_skill, INTIMIDATE_DC, 1.0
	)

	if roll_result.get("success", false):
		# Show success dialogue
		var lines: Array[Dictionary] = []
		lines.append(ConversationSystem.create_scripted_line(
			npc_name,
			"*sweating* A-alright, just... just go. I didn't see anything.",
			[],
			true
		))
		ConversationSystem.start_scripted_dialogue(lines, _handle_intimidate_success)
		_show_notification("Intimidation successful! (Roll: %d vs DC %d)" % [roll_result.get("total", 0), INTIMIDATE_DC])
	else:
		# Show failure dialogue
		var lines: Array[Dictionary] = []
		lines.append(ConversationSystem.create_scripted_line(
			npc_name,
			"Ha! Nice try, but I've dealt with tougher than you.",
			[],
			true
		))
		ConversationSystem.start_scripted_dialogue(lines, func(): pass)
		_show_notification("Intimidation failed! (Roll: %d vs DC %d)" % [roll_result.get("total", 0), INTIMIDATE_DC])


## Handle successful intimidation - release player
func _handle_intimidate_success() -> void:
	# Release player - bounty stays but player is free
	if prison and prison.has_method("guard_releases_player"):
		prison.guard_releases_player()
	else:
		CrimeManager.is_jailed = false
		CrimeManager.jail_region = ""
		CrimeManager.jail_time_remaining = 0.0


## Handle negotiate attempt - perform skill check
func _handle_negotiate() -> void:
	var char_data := GameManager.player_data
	if not char_data:
		_show_notification("Skill check failed.")
		return

	var persuade_skill: int = char_data.get_skill(Enums.Skill.PERSUASION)
	var charisma: int = char_data.get_effective_stat(Enums.Stat.SPEECH)

	# DC 12 for guard - negotiation is slightly easier than intimidation
	const NEGOTIATE_DC := 12

	# Roll persuasion check
	var roll_result: Dictionary = DiceManager.skill_check(
		charisma, persuade_skill, NEGOTIATE_DC, 1.0
	)

	if roll_result.get("success", false):
		# Show success dialogue
		var lines: Array[Dictionary] = []
		lines.append(ConversationSystem.create_scripted_line(
			npc_name,
			"You know what, you seem reasonable. I'll let you out this time. But stay out of trouble.",
			[],
			true
		))
		ConversationSystem.start_scripted_dialogue(lines, _handle_negotiate_success)
		_show_notification("Negotiation successful! (Roll: %d vs DC %d)" % [roll_result.get("total", 0), NEGOTIATE_DC])
	else:
		# Show failure dialogue
		var lines: Array[Dictionary] = []
		lines.append(ConversationSystem.create_scripted_line(
			npc_name,
			"Nice words, but I'm not falling for that. Serve your time like everyone else.",
			[],
			true
		))
		ConversationSystem.start_scripted_dialogue(lines, func(): pass)
		_show_notification("Negotiation failed! (Roll: %d vs DC %d)" % [roll_result.get("total", 0), NEGOTIATE_DC])


## Handle successful negotiation - release player and reduce bounty
func _handle_negotiate_success() -> void:
	# Negotiation also clears some of the bounty as a reward
	var current_bounty: int = CrimeManager.get_bounty(region_id)
	var reduced_bounty: int = int(current_bounty * 0.5)  # Reduce by 50%
	CrimeManager.set_bounty(region_id, reduced_bounty)

	if reduced_bounty > 0:
		_show_notification("Your bounty was reduced to %d gold." % reduced_bounty)

	# Release player
	if prison and prison.has_method("guard_releases_player"):
		prison.guard_releases_player()
	else:
		CrimeManager.is_jailed = false
		CrimeManager.jail_region = ""
		CrimeManager.jail_time_remaining = 0.0


## Calculate bribe cost based on bounty
func _calculate_bribe_cost(bounty: int) -> int:
	# Bribe costs 50% of bounty, minimum 50 gold
	return maxi(50, int(bounty * 0.5))


## Take damage from an attacker
func take_damage(amount: int, damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL, attacker: Node = null) -> int:
	if _is_dead:
		return 0

	# Apply armor reduction
	var armor_mult: float = 100.0 / (100.0 + float(ARMOR))
	var reduced_amount: int = int(float(amount) * armor_mult)
	reduced_amount = maxi(1, reduced_amount)

	# Apply damage
	var actual_damage: int = mini(reduced_amount, current_health)
	current_health -= actual_damage

	# Visual feedback - flash red
	if billboard and is_instance_valid(billboard) and billboard.sprite:
		billboard.sprite.modulate = Color(1.5, 0.4, 0.4)
		var billboard_ref: BillboardSprite = billboard
		get_tree().create_timer(0.15).timeout.connect(func():
			if is_instance_valid(billboard_ref) and billboard_ref.sprite:
				billboard_ref.sprite.modulate = Color.WHITE
		)

	# Enter combat if attacked by player
	if attacker and attacker is Node3D:
		_target_player = attacker as Node3D
		if not is_in_combat:
			is_in_combat = true
			print("[JailGuard] ENTERING COMBAT with %s!" % attacker.name)
			attack_cooldown = 0.3  # Quick first response

		# Report crime - attacking a guard
		if attacker.is_in_group("player"):
			CrimeManager.report_crime(CrimeManager.CrimeType.ASSAULT, region_id, [self])

	# Check for death
	if current_health <= 0:
		_die(attacker)

	var damage_type_name: String = Enums.DamageType.keys()[damage_type] if damage_type < Enums.DamageType.size() else "UNKNOWN"
	var attacker_name: String = attacker.name if attacker else "unknown"
	print("[JailGuard] Took %d %s damage (reduced from %d) from %s (HP: %d/%d)" % [
		actual_damage,
		damage_type_name,
		amount,
		attacker_name,
		current_health,
		MAX_HEALTH
	])

	return actual_damage


## Check if dead
func is_dead() -> bool:
	return _is_dead


## Handle death
func _die(killer: Node = null) -> void:
	if _is_dead:
		return

	_is_dead = true
	is_in_combat = false

	print("[JailGuard] Killed by %s" % (killer.name if killer else "unknown"))

	# Report murder crime
	if killer and killer.is_in_group("player"):
		CrimeManager.report_crime(CrimeManager.CrimeType.MURDER, region_id, [])

	# Notify prison
	if prison and prison.has_method("on_guard_killed"):
		prison.on_guard_killed()

	# Remove from groups
	remove_from_group("interactable")
	remove_from_group("npcs")
	remove_from_group("attackable")
	remove_from_group("jail_guards")

	# Stop movement
	velocity = Vector3.ZERO

	# Spawn lootable corpse with jail key
	_spawn_corpse()

	# Emit killed signal
	CombatManager.entity_killed.emit(self, killer)

	# Play death sound
	if AudioManager:
		AudioManager.play_sfx("guard_death")

	# Queue removal
	get_tree().create_timer(0.1).timeout.connect(queue_free)


## Spawn corpse with jail key
func _spawn_corpse() -> void:
	var corpse: LootableCorpse = LootableCorpse.spawn_corpse(
		get_parent(),
		global_position,
		npc_name,
		npc_id,
		8  # Level 8 - jail guard
	)

	# Validate corpse was created
	if not corpse:
		push_error("[JailGuard] Failed to spawn corpse!")
		return

	# Add gold
	corpse.gold = gold_carried

	# Add jail key - always drops
	corpse.add_item("jail_key", 1, Enums.ItemQuality.AVERAGE)

	# Maybe add a weapon
	if InventoryManager.weapon_database.has("iron_sword"):
		corpse.add_item("iron_sword", 1, Enums.ItemQuality.BELOW_AVERAGE)

	# Maybe add a health potion
	if randf() < 0.3:
		if InventoryManager.item_database.has("health_potion"):
			corpse.add_item("health_potion", 1, Enums.ItemQuality.AVERAGE)


## Get armor value for combat calculations
func get_armor_value() -> int:
	return ARMOR


## Show notification via HUD
func _show_notification(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text)


## Static factory method
static func spawn_jail_guard(parent: Node, pos: Vector3, p_prison: Node3D = null, p_region_id: String = "elder_moor") -> Node3D:
	var script: Script = load("res://scripts/world/jail_guard.gd")
	var guard: JailGuard = script.new() as JailGuard
	if not guard:
		push_error("[JailGuard] Failed to create jail guard instance")
		return null
	guard.position = pos
	guard.prison = p_prison
	guard.region_id = p_region_id

	parent.add_child(guard)
	return guard
