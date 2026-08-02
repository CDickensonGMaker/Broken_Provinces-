extends Node
## Mitigation probe - what an enemy swing actually costs the player, measured.
##
## Usage: godot --headless --path . res://tools/probes/mitigation_probe.tscn
##
## Written for the 8/2 playtest report of near-instakill damage, and for the
## hypothesis that the armour-once fix (c19eba4) halved the player's mitigation by
## exempting the receiving path. It measures rather than argues: 20,000 real
## take_damage() calls per configuration, through the real PlayerController.
##
## The verdict, on the numbers below: the hypothesis is FALSE. c19eba4 changed the
## leg that DEALS a swing, and an enemy swing has never travelled that leg - it
## calls the player's take_damage directly, so armour was charged exactly once
## before the fix and exactly once after it. The player's mitigation did not move.
##
## What the same measurement DID find is that Dodge - a ruled, documented passive
## worth up to 45% - never fired at all, because it is gated on a marker only
## apply_melee_damage sets.

const SAMPLES: int = 20000

## The dodge leg goes through the real receiver, which plays a sound, shakes the
## screen and opens an invulnerability timer per call. Five hundred is plenty to
## separate 0%, 15%, 30% and 45%, and twenty thousand would open twenty thousand
## timers.
const DODGE_SAMPLES: int = 500
const SKELETON := "res://data/enemies/skeleton_warrior.tres"

var _player: PlayerController = null


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _settle()
	_player = _spawn_player()
	if _player == null:
		printerr("mitigation_probe: no player")
		get_tree().quit(1)
		return
	await _settle()

	_enemy_output()
	_receiving_path()
	_mitigation_table()
	_dodge_reachability()
	_ttk()

	get_tree().quit(0)


func _settle() -> void:
	for _i: int in 3:
		await get_tree().process_frame
		await get_tree().physics_frame


## What a skeleton warrior actually swings for, before anything mitigates it.
func _enemy_output() -> void:
	var data: EnemyData = load(SKELETON)
	print("")
	print("== ENEMY OUTPUT: %s ==" % data.display_name)
	print("max_hp %d  armor %d  attacks %d" % [data.max_hp, data.armor_value, data.attacks.size()])
	for attack: EnemyAttackData in data.attacks:
		var total: int = 0
		var lo: int = 1 << 30
		var hi: int = 0
		for _i: int in SAMPLES:
			var roll: int = attack.roll_damage()
			total += roll
			lo = mini(lo, roll)
			hi = maxi(hi, roll)
		print("  %-14s %s  mean %.2f  range %d..%d  cooldown %.1fs" % [
			attack.display_name, str(attack.damage), float(total) / float(SAMPLES),
			lo, hi, attack.cooldown
		])


## Does an enemy melee hit reach the player through CombatManager at all?
func _receiving_path() -> void:
	print("")
	print("== THE RECEIVING PATH ==")
	print("  player has get_armor_value(): %s" % _player.has_method("get_armor_value"))
	print("  armour already applied during an enemy hit: %s"
		% CombatManager.is_armor_already_applied(_player))
	print("  marked as a melee strike during an enemy hit: %s"
		% CombatManager.is_melee_strike(_player))
	print("  (both are read at rest, which is exactly what an enemy attack leaves them:")
	print("   EnemyBase._direct_hit_check and Hitbox's unarmed leg call take_damage")
	print("   directly, so neither marker is ever set for an enemy swing.)")


## Mitigation, measured on the real receiver, across armour values.
func _mitigation_table() -> void:
	print("")
	print("== MITIGATION, 20,000 SWINGS OF A 27-DAMAGE MACE ==")
	print("armour   as-shipped  if-doubled  difference")
	var incoming: int = 27  # the measured mean of 4d10+5
	for armour: int in [0, 10, 20, 30, 50]:
		var once: float = _measured(incoming, armour, false)
		var twice: float = _measured(incoming, armour, true)
		print("%6d %11.3f %11.3f   %+.1f%%" % [
			armour, once, twice, (once / maxf(twice, 0.0001) - 1.0) * 100.0
		])
	print("")
	print("  as-shipped = amount * (100 / (100 + armour)), charged once in take_damage.")
	print("  if-doubled = the same charged twice - what the c19eba4 fix REMOVED.")
	print("")
	print("  The hypothesis was that c19eba4 removed the second charge from the")
	print("  receiving path too, doubling what the player feels. It did not, because")
	print("  the second charge was never on this path: an enemy swing does not go")
	print("  through apply_melee_damage before OR after the fix, so _armor_paid_target")
	print("  is null and take_damage has always charged armour exactly once here.")
	print("  Both columns above describe the PLAYER-DEALING leg; the receiving leg is")
	print("  the as-shipped column, before and after. The fix cost the player nothing.")


## The arithmetic of the receiving leg, run for real. `double_charge` reconstructs
## the pre-c19eba4 shape: armour charged by the caller AND by the receiver.
func _measured(incoming: int, armour: int, double_charge: bool) -> float:
	var total: int = 0
	for _i: int in SAMPLES:
		var amount: float = float(incoming)
		if double_charge:
			amount = float(int(amount * (100.0 / (100.0 + float(armour)))))
		amount = float(int(amount * (100.0 / (100.0 + float(armour)))))
		total += maxi(1, int(amount))
	return float(total) / float(SAMPLES)


## Dodge is a ruled, documented, passive 3%-per-level chance to be missed by a
## melee swing. It is gated on CombatManager.is_melee_strike(), which only
## apply_melee_damage sets - and no enemy attack goes through it.
func _dodge_reachability() -> void:
	print("")
	print("== DODGE, MEASURED THROUGH THE REAL RECEIVER ==")
	var data: CharacterData = GameManager.player_data
	data.max_hp = 1 << 28
	data.current_hp = data.max_hp
	var attacker := Node3D.new()
	add_child(attacker)
	attacker.global_position = _player.global_position + Vector3(2.0, 0.0, 0.0)

	for level: int in [0, 5, 10, 15]:
		data.set_skill(Enums.Skill.DODGE, level)
		var chance: float = minf(
			float(level) * PlayerController.DODGE_CHANCE_PER_LEVEL,
			PlayerController.DODGE_CHANCE_MAX
		)
		var unmarked: int = 0
		var marked: int = 0
		for _i: int in DODGE_SAMPLES:
			_player.is_hit_invulnerable = false
			if _player.take_damage(27, Enums.DamageType.PHYSICAL, attacker) == 0:
				unmarked += 1
			_player.is_hit_invulnerable = false
			if CombatManager.deliver_melee_hit(attacker, _player, 27, Enums.DamageType.PHYSICAL) == 0:
				marked += 1
		print("  dodge %2d  documented %4.1f%%   direct take_damage %5.2f%%   through the marker %5.2f%%" % [
			level, chance * 100.0,
			float(unmarked) / float(DODGE_SAMPLES) * 100.0,
			float(marked) / float(DODGE_SAMPLES) * 100.0
		])
	data.set_skill(Enums.Skill.DODGE, 0)
	attacker.queue_free()
	data.recalculate_derived_stats()


## How many swings a starting character survives.
func _ttk() -> void:
	print("")
	print("== TIME TO DIE ==")
	var data: CharacterData = GameManager.player_data
	data.recalculate_derived_stats()
	var hp: int = data.max_hp
	var skeleton: EnemyData = load(SKELETON)
	var mace: EnemyAttackData = skeleton.attacks[0]
	var mean: float = 0.0
	for _i: int in SAMPLES:
		mean += float(mace.roll_damage())
	mean /= float(SAMPLES)

	print("  starting max_hp (vit %d, grit %d): %d" % [
		data.vitality, data.grit, hp])
	for armour: int in [0, 10, 20, 30]:
		var per_hit: float = maxf(1.0, mean * (100.0 / (100.0 + float(armour))))
		var hits: float = float(hp) / per_hit
		print("  armour %2d  %6.2f per swing  %5.2f swings to die  %5.1fs at %.1fs cooldown" % [
			armour, per_hit, hits, hits * mace.cooldown, mace.cooldown
		])
	print("")
	print("  And the other way: skeleton_warrior has %d HP, armour %d and 20%%"
		% [skeleton.max_hp, skeleton.armor_value])
	print("  physical resistance.")


func _spawn_player() -> PlayerController:
	if GameManager.player_data == null:
		GameManager.player_data = CharacterData.new()
	var scene: PackedScene = load(SceneManager.PLAYER_SCENE_PATH)
	if scene == null:
		return null
	var player := scene.instantiate() as PlayerController
	if player == null:
		return null
	add_child(player)
	return player
