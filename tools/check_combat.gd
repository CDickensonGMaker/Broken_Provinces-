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
##   C4  the verbs the combat identity ruling removed stay removed - no dodge,
##       no lock-on. The identity is Skyrim/Daggerfall, not Souls (Caleb, 8/2)
##   C5  a blow does not pass through a wall, on either side of the fight
##   C6  an enemy is never spawned inside static geometry
##   C7  a hit the enemy delivers is MARKED as melee, which is the only thing
##       the passive Dodge skill is gated on. Measured 8/2 at 0.00% reached
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
	_check_removed_verbs()
	await _settle()
	await _check_hit_line()
	await _settle()
	await _check_spawn_safety()
	await _settle()
	await _check_melee_is_marked()

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
		await get_tree().physics_frame


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


## C3. The guard. Built from the player scene itself rather than a stand-in,
## because the arc is measured off the camera pivot and the stamina comes out
## of the real character data - a stub would prove neither.
func _check_block() -> void:
	var player: PlayerController = _spawn_player()
	if player == null:
		_expect(false, "the player scene would not instance, so block cannot be checked")
		return

	var data := GameManager.player_data
	var attacker := ProbeAttacker.new()
	add_child(attacker)

	_expect(
		InputMap.has_action("block"),
		"the block action is not registered - GameSettings.ensure_runtime_actions did not run"
	)

	# The pivot looks down -Z at yaw 0, so an attacker at -Z is dead ahead.
	player.camera_pivot.rotation.y = 0.0
	attacker.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)

	_expect(not player.is_hit_blocked(attacker.global_position), "a hit is blocked while the guard is down")

	player.is_blocking = true
	_expect(player.is_hit_blocked(attacker.global_position), "a hit from dead ahead is not blocked")

	# Just inside and just outside the 120-degree arc.
	var half: float = player.block_arc_degrees * 0.5
	attacker.global_position = player.global_position + _at_angle(half - 5.0, 5.0)
	_expect(player.is_hit_blocked(attacker.global_position), "a hit inside the guard arc is not blocked")

	attacker.global_position = player.global_position + _at_angle(half + 5.0, 5.0)
	_expect(not player.is_hit_blocked(attacker.global_position), "a hit outside the guard arc is blocked anyway")

	attacker.global_position = player.global_position + Vector3(0.0, 0.0, 5.0)
	_expect(not player.is_hit_blocked(attacker.global_position), "a hit from directly behind is blocked")

	# A blocked hit is halved and costs stamina.
	data.current_stamina = data.max_stamina
	player.is_blocking = true
	attacker.global_position = player.global_position + Vector3(0.0, 0.0, -5.0)
	var stamina_before: int = data.current_stamina
	var got_through: int = player._absorb_with_block(20, attacker)

	_expect(
		got_through == int(20 * (1.0 - player.block_damage_reduction)),
		"a blocked hit of 20 let %d through, not %d" % [got_through, int(20 * (1.0 - player.block_damage_reduction))]
	)
	_expect(
		data.current_stamina < stamina_before,
		"a blocked hit cost no stamina - the guard is free"
	)
	_expect(
		not player.block_broken,
		"the guard broke on a hit the stamina bar could pay for"
	)

	# Emptying the bar breaks the guard.
	data.current_stamina = 2
	player.is_blocking = true
	player.block_broken = false
	player._absorb_with_block(20, attacker)
	_expect(player.block_broken, "the guard did not break when stamina ran out")
	_expect(not player.is_blocking, "the guard is still up after breaking")

	# And it stays broken while the key is held, which in a headless run means
	# while nothing releases it.
	player._update_block()
	_expect(not player.is_blocking, "a broken guard came back up without the key being released")

	attacker.queue_free()
	player.queue_free()


## C4. The two verbs the identity ruling removed.
##
## Combat here is Skyrim/Daggerfall - move, swing, guard, armour - and not
## Souls. Ruled 8/2: no player dodge and no lock-on. Both had code and both are
## gone, and the cheapest way for either to creep back is for somebody to see a
## dead binding and helpfully implement it. This is what stops that.
func _check_removed_verbs() -> void:
	GameSettings.ensure_runtime_actions()

	_expect(
		not InputMap.has_action("dodge"),
		"the `dodge` action is bound again - the player dodge was removed by ruling, not by accident"
	)
	_expect(
		not InputMap.has_action("lock_on"),
		"the `lock_on` action is bound again - lock-on was cancelled by ruling"
	)
	_expect(
		not GameSettings.REBINDABLE_ACTIONS.has("dodge")
			and not GameSettings.REBINDABLE_ACTIONS.has("lock_on"),
		"the options menu offers a binding for a verb the game does not have"
	)

	var player_source: String = FileAccess.get_file_as_string("res://scripts/characters/player/player_controller.gd")
	_expect(
		not player_source.is_empty(),
		"could not read player_controller.gd to check for the removed verbs"
	)
	for banned: String in ["_try_dodge", "_perform_dodge", "is_dodging", "_toggle_lock_on", "lock_on_target"]:
		_expect(
			not player_source.contains("func %s" % banned) and not player_source.contains("var %s" % banned),
			"PlayerController declares `%s` again - a removed verb is growing back" % banned
		)

	var camera_source: String = FileAccess.get_file_as_string("res://scripts/characters/player/camera_pivot.gd")
	_expect(
		not camera_source.contains("bias_toward"),
		"CameraPivot.bias_toward is back - that function existed only to serve lock-on"
	)


## A point `degrees` off the pivot's forward (-Z at yaw 0), `distance` away.
func _at_angle(degrees: float, distance: float) -> Vector3:
	var radians: float = deg_to_rad(degrees)
	return Vector3(sin(radians), 0.0, -cos(radians)) * distance


## Instance the real player scene, and give it character data to spend.
func _spawn_player() -> PlayerController:
	if GameManager.player_data == null:
		GameManager.player_data = CharacterData.new()
	GameManager.player_data.max_stamina = 100
	GameManager.player_data.current_stamina = 100

	# SceneManager's path, not `scripts/player/player.tscn` - that one is an
	# older stub with none of the child nodes and nothing loads it.
	var scene: PackedScene = load(SceneManager.PLAYER_SCENE_PATH)
	if scene == null:
		return null
	var player := scene.instantiate() as PlayerController
	if player == null:
		return null
	add_child(player)
	return player


## ============================================================================
## C5. THE WALL
## ============================================================================

## A static box on the world layer, between the two of them.
func _wall(at: Vector3, size: Vector3 = Vector3(0.6, 4.0, 8.0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	body.global_position = at
	return body


## Melee resolved by Area3D overlap and, for enemies, a bare distance check.
## Both pass straight through a wall. Caleb was hit through one and hit back
## through it in the same fight.
func _check_hit_line() -> void:
	var attacker := _probe_attacker()
	var enemy := _probe_enemy(0)
	var weapon := _flat_weapon(50)

	attacker.global_position = Vector3(0, 0, 0)
	enemy.global_position = Vector3(2.0, 0, 0)

	var clear_damage: int = CombatManager.apply_melee_damage(
		attacker, enemy, weapon, Enums.ItemQuality.AVERAGE)
	_expect(clear_damage > 0, "C5: an unobstructed swing lands (got %d)" % clear_damage)
	_expect(CombatManager.has_hit_line(attacker, enemy),
		"C5: has_hit_line is true across open ground")

	var wall := _wall(Vector3(1.0, 0, 0))
	await _settle()
	_expect(not CombatManager.has_hit_line(attacker, enemy),
		"C5: has_hit_line is false through a wall")
	var blocked_damage: int = CombatManager.apply_melee_damage(
		attacker, enemy, weapon, Enums.ItemQuality.AVERAGE)
	_expect(blocked_damage == 0,
		"C5: a swing through a wall does nothing (got %d)" % blocked_damage)

	# And the same wall in the other direction: fairness cuts both ways.
	_expect(not CombatManager.has_hit_line(enemy, attacker),
		"C5: the wall blocks the enemy's swing too")

	wall.queue_free()
	attacker.queue_free()
	enemy.queue_free()


## ============================================================================
## C6. NOTHING SPAWNS INSIDE A WALL
## ============================================================================

func _check_spawn_safety() -> void:
	var room := Node3D.new()
	add_child(room)
	await _settle()

	# A pillar three units across, centred on the origin of the room - the shape
	# a ruin wall or a totem actually is.
	var slab := _wall(Vector3.ZERO, Vector3(3.0, 6.0, 3.0))
	slab.reparent(room)
	slab.position = Vector3.ZERO
	await _settle()

	var inside: Vector3 = EnemyBase.find_safe_spawn(room, Vector3.ZERO, 1.0)
	_expect(inside != Vector3.ZERO,
		"C6: a position inside a slab is not returned unchanged")
	_expect(inside != Vector3.INF,
		"C6: a way out of a 3-unit pillar is found (got %s)" % inside)

	var enemy: EnemyBase = EnemyBase.spawn_skeleton_enemy(room, Vector3.ZERO)
	_expect(enemy != null, "C6: the skeleton still spawns")
	if enemy != null:
		_expect(enemy.position != Vector3.ZERO,
			"C6: the skeleton is not left standing in the slab (at %s)" % enemy.position)
		enemy.queue_free()

	# A slab wider than the whole search refuses the spawn rather than burying it.
	var vault := _wall(Vector3(200.0, 0, 200.0), Vector3(40.0, 8.0, 40.0))
	vault.reparent(room)
	vault.position = Vector3(200.0, 0.0, 200.0)
	await _settle()
	_expect(EnemyBase.find_safe_spawn(room, Vector3(200.0, 0.0, 200.0), 1.0) == Vector3.INF,
		"C6: a position with no way out refuses rather than spawning embedded")
	_expect(EnemyBase.spawn_skeleton_enemy(room, Vector3(200.0, 0.0, 200.0)) == null,
		"C6: and the factory returns null rather than a buried enemy")

	# Open ground is left exactly alone - the safety net must not drift a spawn
	# that was already fine, or hand-placed markers stop meaning anything.
	var clear_spot := Vector3(40.0, 0.0, 40.0)
	_expect(EnemyBase.find_safe_spawn(room, clear_spot, 1.0) == clear_spot,
		"C6: a clear position is returned unchanged")

	room.queue_free()


## ============================================================================
## C7. AN ENEMY SWING IS A MELEE STRIKE
## ============================================================================

## Dodge is a passive +3% per level, capped at 45%, rolled in take_damage BEFORE
## the guard and before armour - and gated on CombatManager.is_melee_strike().
## Only apply_melee_damage set that marker, and no enemy attack goes through it:
## _direct_hit_check, Hitbox's unarmed leg and Hurtbox all called take_damage
## straight. Measured on the real receiver at dodge 5, 10 and 15, the documented
## 15/30/45% fired 0.00%, 0.00% and 0.00%.
func _check_melee_is_marked() -> void:
	var player := _spawn_player()
	if player == null:
		_expect(false, "C7: the player scene loads")
		return
	await _settle()

	var attacker := Node3D.new()
	add_child(attacker)
	attacker.global_position = player.global_position + Vector3(2.0, 0.0, 0.0)

	var data: CharacterData = GameManager.player_data
	var kept_hp: int = data.max_hp
	data.max_hp = 1 << 24
	data.current_hp = data.max_hp
	data.set_skill(Enums.Skill.DODGE, 15)  # 45%, the cap

	var direct_evaded: int = 0
	var marked_evaded: int = 0
	for _i: int in 400:
		player.is_hit_invulnerable = false
		if player.take_damage(10, Enums.DamageType.PHYSICAL, attacker) == 0:
			direct_evaded += 1
		player.is_hit_invulnerable = false
		if CombatManager.deliver_melee_hit(attacker, player, 10, Enums.DamageType.PHYSICAL) == 0:
			marked_evaded += 1

	_expect(direct_evaded == 0,
		"C7: an unmarked hit never dodges (got %d/400)" % direct_evaded)
	_expect(marked_evaded > 120 and marked_evaded < 240,
		"C7: a marked hit dodges near the 45%% cap (got %d/400)" % marked_evaded)

	data.set_skill(Enums.Skill.DODGE, 0)
	data.max_hp = kept_hp
	attacker.queue_free()
	player.queue_free()
