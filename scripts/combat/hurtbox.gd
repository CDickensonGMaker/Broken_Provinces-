## hurtbox.gd - Reusable hurtbox component for receiving damage
## Attach to any entity that can take damage
class_name Hurtbox
extends Area3D

signal hurt(damage: int, damage_type: Enums.DamageType, attacker: Node)

## Owner reference
var owner_entity: Node = null

## Invincibility state
var is_invincible: bool = false

func _ready() -> void:
	# CRITICAL: Set up collision properly
	# Hurtbox should be detectable by hitboxes AND detect hitboxes entering
	# monitoring = true allows us to detect hitboxes, monitorable = true allows hitboxes to detect us
	monitoring = true  # We also detect hitboxes entering us
	monitorable = true  # Others can detect us

	# Set collision layers
	# Layer 6 = player_hurtbox, Layer 7 = enemy_hurtbox
	# Mask should detect the opposite hitbox layer for bidirectional detection

	# Connect signal for when hitboxes enter us
	area_entered.connect(_on_area_entered)

## Called when a hitbox enters our area
func _on_area_entered(area: Area3D) -> void:
	if is_invincible:
		return

	# Check if it's a hitbox
	if not area is Hitbox:
		# Fallback: check group
		if not area.is_in_group("hitbox") and not area.is_in_group("enemy_hitbox") and not area.is_in_group("player_hitbox"):
			return

	# Check if hitbox is active
	if area is Hitbox and not (area as Hitbox).is_active:
		return

	# Get damage from hitbox metadata
	var damage: int = area.get_meta("damage", 10)
	var damage_type: Enums.DamageType = area.get_meta("damage_type", Enums.DamageType.PHYSICAL)

	var attacker: Node = null
	if area is Hitbox:
		attacker = (area as Hitbox).owner_entity
	else:
		attacker = area.get_parent()

	# Don't let us hurt ourselves
	if attacker == owner_entity:
		return

	# Emit signal for UI/VFX purposes
	hurt.emit(damage, damage_type, attacker)

	# Apply damage to owner - this is the reliable path since hurtbox detects hitbox entering
	# The hitbox tracks hit_targets to prevent double-damage
	if owner_entity and owner_entity.has_method("take_damage"):
		# Check if hitbox already registered this hit (prevents double damage)
		if area is Hitbox:
			var hb := area as Hitbox
			if owner_entity in hb.hit_targets:
				return  # Already damaged by hitbox
			hb.hit_targets.append(owner_entity)
		owner_entity.take_damage(damage, damage_type, attacker)

## Set owner entity
func set_owner_entity(entity: Node) -> void:
	owner_entity = entity

## Enable/disable invincibility (for i-frames)
func set_invincible(value: bool) -> void:
	is_invincible = value

## Temporarily disable (for death, etc.)
func disable() -> void:
	set_deferred("monitorable", false)

## Re-enable
func enable() -> void:
	set_deferred("monitorable", true)
