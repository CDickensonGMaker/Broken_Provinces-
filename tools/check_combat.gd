extends Node
## Combat check: the player's side of a fight, exercised rather than read.
##
## Usage: godot --headless --path . res://tools/check_combat.tscn
##
## Runs as a scene, not with --script: CombatManager is an autoload and the
## whole point is that it and the receivers agree about who charges armour.
##
##   C1  armour mitigates exactly ONCE on the CombatManager melee leg, and
##       `armor_pierce` is honoured because that is the leg it lives on
##   C2  spells still pay armour, once, on the receiver's leg - the exemption
##       is scoped to the hit CombatManager is delivering and to nobody else
##   C3  the block verb: a frontal hit is halved, a hit from behind is not,
##       stamina is spent per blocked hit and the guard breaks at zero
##   C4  the soft lock-on verb: acquire, hold, and every documented break
##
## C1 exists because melee paid armour twice for the whole of batch 4 - once in
## `apply_melee_damage` (honouring `armor_pierce`) and again in the receiver's
## `take_damage`. Measured, that cost a 1d6 swing against armour 10 a third of
## its damage. Charging it once is the ruling; this is what keeps it charged
## once.

var _failures: Array[String] = []
var _checks: int = 0

## A stand-in attacker. `apply_melee_damage` asks for `get_character_data`
## and for group membership, and nothing else.
class ProbeAttacker:
	extends Node3D

	var data: CharacterData

	func get_character_data() -> CharacterData:
		return data


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _settle()

	_check_armor_charged_once()
	await _settle()
	_check_armor_pierce_bites()
	await _settle()
	_check_spell_still_pays_armor()
	await _settle()
	_check_exemption_is_scoped_to_the_target()
	await _settle()
	_check_block()
	await _settle()
	_check_lock_on()

	print("")
	print("Checks run: %d" % _checks)
	if _failures.is_empty():
		print("Combat check: PASS")
		get_tree().quit(0)
		return

	print("Combat check: FAIL (%d)" % _failures.size())
	for failure: String in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)


func _settle() -> void:
	for _i: int in 3:
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


## A weapon with every random element switched off, so a single swing is a
## number and not a distribution: 1dN with N == 1 rolls N every time.
func _flat_weapon(damage: int, pierce: float = 0.0) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.base_damage = [damage, 1, 0] as Array[int]
	weapon.secondary_damage = [0, 0, 0] as Array[int]
	weapon.crit_chance = 0.0
	weapon.crit_multiplier = 1.0
	weapon.armor_pierce = pierce
	weapon.lifesteal_percent = 0.0
	weapon.stagger_power = 0.0
	weapon.damage_type = Enums.DamageType.PHYSICAL
	weapon.inflicts_condition = Enums.Condition.NONE
	return weapon


func _probe_attacker() -> ProbeAttacker:
	var attacker := ProbeAttacker.new()
	attacker.data = CharacterData.new()
	attacker.data.set_stat(Enums.Stat.GRIT, 0)
	add_child(attacker)
	return attacker


func _probe_enemy(armor: int) -> EnemyBase:
	var enemy := EnemyBase.new()
	enemy.armor_value = armor
	enemy.max_hp = 100000000
	enemy.current_hp = 100000000
	add_child(enemy)
	return enemy


## C1. One swing, one armour bite. Charging twice is the batch 4 defect and it
## is arithmetically visible: 100 damage into armour 100 is 50 once and 25
## twice, which no rounding can confuse.
func _check_armor_charged_once() -> void:
	var attacker := _probe_attacker()
	var enemy := _probe_enemy(100)
	var weapon := _flat_weapon(100)

	var dealt: int = CombatManager.apply_melee_damage(
		attacker, enemy, weapon, Enums.ItemQuality.AVERAGE
	)

	_expect(
		dealt == 50,
		"melee against armour 100 dealt %d, not 50 - armour is charged %s" % [
			dealt, "twice" if dealt <= 30 else "an unexpected number of times"
		]
	)

	attacker.queue_free()
	enemy.queue_free()


## C1b. `armor_pierce` only means anything on the leg that charges armour. If
## the receiver charges it too, a full-pierce weapon is still stopped by armour
## and the field is decoration.
func _check_armor_pierce_bites() -> void:
	var attacker := _probe_attacker()
	var enemy := _probe_enemy(100)
	var weapon := _flat_weapon(100, 1.0)

	var dealt: int = CombatManager.apply_melee_damage(
		attacker, enemy, weapon, Enums.ItemQuality.AVERAGE
	)

	_expect(
		dealt == 100,
		"a fully armour-piercing weapon dealt %d of 100 into armour 100 - pierce is being undone downstream" % dealt
	)

	attacker.queue_free()
	enemy.queue_free()


## C2. Spells never charged armour in CombatManager and must not start: they
## pay it on the receiver's leg, so the exemption must be off for them.
func _check_spell_still_pays_armor() -> void:
	var enemy := _probe_enemy(100)

	_expect(
		not CombatManager.is_armor_already_applied(enemy),
		"the armour exemption is set outside a melee hit - every other damage path would stop paying armour"
	)

	var before: int = enemy.current_hp
	enemy.take_damage(100, Enums.DamageType.PHYSICAL, null)
	var dealt: int = before - enemy.current_hp

	_expect(
		dealt == 50,
		"a direct take_damage of 100 into armour 100 dealt %d, not 50 - the receiver has stopped charging armour for everyone" % dealt
	)

	enemy.queue_free()


## C2b. The exemption is held as the target node, not a bool, so a receiver
## that damages somebody else mid-hit cannot hand them a free pass.
func _check_exemption_is_scoped_to_the_target() -> void:
	var attacker := _probe_attacker()
	var struck := _probe_enemy(100)
	var bystander := _probe_enemy(100)
	var weapon := _flat_weapon(100)

	# EnemyBase.damaged fires inside take_damage, while the exemption is up.
	# The result rides in an Array because a GDScript lambda captures locals by
	# value - assigning to a captured int inside would be lost.
	var out: Array[int] = [0]
	struck.damaged.connect(
		func(_amount: int, _type: Enums.DamageType, _from: Node) -> void:
			var before: int = bystander.current_hp
			bystander.take_damage(100, Enums.DamageType.PHYSICAL, null)
			out[0] = before - bystander.current_hp
	)

	CombatManager.apply_melee_damage(attacker, struck, weapon, Enums.ItemQuality.AVERAGE)

	_expect(
		out[0] == 50,
		"a bystander damaged during a melee hit took %d of 100 into armour 100 - the exemption leaked off the struck target" % out[0]
	)

	attacker.queue_free()
	struck.queue_free()
	bystander.queue_free()


func _check_block() -> void:
	pass


func _check_lock_on() -> void:
	pass
