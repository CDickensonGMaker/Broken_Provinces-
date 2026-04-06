## hitbox.gd - Reusable hitbox component for dealing damage
## Attach to any entity that can deal damage
class_name Hitbox
extends Area3D

signal hit_landed(target: Node)

## Configuration
@export var damage: int = 10
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var stagger_power: float = 1.0
@export var knockback_force: float = 5.0

## Condition infliction
@export var inflicts_condition: Enums.Condition = Enums.Condition.NONE
@export var condition_chance: float = 0.0
@export var condition_duration: float = 0.0

## Owner reference (who is attacking)
var owner_entity: Node = null

## Track what we've hit this activation
var hit_targets: Array[Node] = []

## Is this hitbox currently active
var is_active: bool = false

func _ready() -> void:
	# CRITICAL: Set up collision properly
	# Hitbox should detect hurtboxes
	monitoring = false  # Start disabled
	monitorable = false  # Other areas shouldn't detect us as a target

	# Set collision layers/masks
	# Layer 4 = player_hitbox, Layer 5 = enemy_hitbox
	# Mask should detect the opposite hurtbox layer
	# Layer 6 = player_hurtbox, Layer 7 = enemy_hurtbox

	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Store damage info as metadata for receivers
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)
	set_meta("stagger_power", stagger_power)

## Activate the hitbox (call when attack starts)
func activate() -> void:
	hit_targets.clear()
	is_active = true
	monitoring = true
	monitorable = true  # Allow detection in both directions

	# Force physics update to detect overlaps immediately
	force_update_transform()

	# Use call_deferred to check overlaps after physics processes the change
	call_deferred("_check_initial_overlaps")

## Check for overlaps that existed when hitbox was activated
func _check_initial_overlaps() -> void:
	if not is_active:
		return

	var overlapping := get_overlapping_areas()
	for area in overlapping:
		if area not in hit_targets:
			_on_area_entered(area)

## Deactivate the hitbox (call when attack ends)
func deactivate() -> void:
	is_active = false
	monitoring = false

## Called when we overlap with another Area3D (hurtbox)
func _on_area_entered(area: Area3D) -> void:
	if not is_active:
		return

	# Check if it's a hurtbox
	if not area is Hurtbox:
		# Fallback: check group
		if not area.is_in_group("hurtbox") and not area.is_in_group("enemy_hurtbox") and not area.is_in_group("player_hurtbox"):
			return

	var target := area.get_parent()
	if not target:
		return

	# Don't hit ourselves
	if target == owner_entity:
		return

	# Don't hit same target twice per activation
	if target in hit_targets:
		return

	hit_targets.append(target)
	_apply_hit(target)

## Called when we overlap with a physics body
func _on_body_entered(body: Node3D) -> void:
	if not is_active:
		return

	# Don't hit ourselves
	if body == owner_entity:
		return

	# Don't hit same target twice
	if body in hit_targets:
		return

	# Only hit valid targets (enemies, player, or attackable NPCs)
	if not body.is_in_group("enemies") and not body.is_in_group("player") and not body.is_in_group("attackable"):
		return

	hit_targets.append(body)
	_apply_hit(body)

## Apply the hit to a target
func _apply_hit(target: Node) -> void:
	hit_landed.emit(target)

	# Calculate final damage (may be modified by backstab)
	var final_damage: int = _calculate_backstab_damage(damage, owner_entity, target)

	# Apply damage if target can receive it
	if target.has_method("take_damage"):
		target.take_damage(final_damage, damage_type, owner_entity)

	# Apply stagger
	if stagger_power > 0 and target.has_method("apply_stagger"):
		target.apply_stagger(stagger_power)

	# Apply knockback
	if knockback_force > 0 and target is CharacterBody3D and owner_entity is Node3D:
		var direction: Vector3 = (target.global_position - (owner_entity as Node3D).global_position).normalized()
		direction.y = 0.2  # Slight upward
		(target as CharacterBody3D).velocity += direction * knockback_force

	# Apply condition
	if inflicts_condition != Enums.Condition.NONE and randf() < condition_chance:
		if target.has_method("apply_condition"):
			target.apply_condition(inflicts_condition, condition_duration)

## Set owner (the entity this hitbox belongs to)
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity

## Update damage values (for weapons with different stats)
func set_damage_values(new_damage: int, new_type: Enums.DamageType = Enums.DamageType.PHYSICAL) -> void:
	damage = new_damage
	damage_type = new_type
	set_meta("damage", damage)
	set_meta("damage_type", damage_type)

## Calculate backstab damage multiplier for stealth attacks
## Returns modified damage (or base damage if conditions not met)
func _calculate_backstab_damage(base_damage: int, attacker: Node, target: Node) -> int:
	# Must have a valid attacker
	if not attacker or not is_instance_valid(attacker):
		return base_damage

	# Check if attacker is player and hidden
	if not attacker.is_in_group("player"):
		return base_damage

	var is_hidden: bool = false
	if attacker.has_method("get_is_hidden"):
		is_hidden = attacker.get_is_hidden()

	if not is_hidden:
		return base_damage

	# Check if target is unaware (enemy in IDLE state with low awareness)
	var target_unaware: bool = false
	if target.has_method("is_unaware"):
		target_unaware = target.is_unaware()

	if not target_unaware:
		return base_damage

	# All conditions met - apply backstab multiplier!
	var stealth_skill: int = 0
	if GameManager and GameManager.player_data:
		stealth_skill = GameManager.player_data.get_skill(Enums.Skill.STEALTH)

	var mult: float = StealthConstants.get_stealth_backstab_multiplier(stealth_skill, true)
	var backstab_damage: int = int(base_damage * mult)

	# Show backstab feedback via HUD
	var hud := attacker.get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_notification"):
		hud.show_notification("BACKSTAB!")

	return backstab_damage
