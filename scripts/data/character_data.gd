## character_data.gd - Player/NPC character statistics and progression
class_name CharacterData
extends Resource

## Signals for UI updates
signal hp_changed(old_hp: int, new_hp: int, max_hp: int)
signal stamina_changed(old_stamina: int, new_stamina: int, max_stamina: int)
signal mana_changed(old_mana: int, new_mana: int, max_mana: int)
signal condition_applied(condition: Enums.Condition)
signal condition_removed(condition: Enums.Condition)
signal buff_applied(buff_id: String, amount: float, duration: float)
signal buff_expired(buff_id: String)
signal stat_changed(stat: Enums.Stat, old_value: int, new_value: int)
signal skill_changed(skill: Enums.Skill, old_value: int, new_value: int)
signal level_up(new_level: int)
signal ip_gained(amount: int)

## Character identity
@export var character_name: String = "Unnamed"
@export var race: Enums.Race = Enums.Race.HUMAN
@export var career: Enums.Career = Enums.Career.FARMER

## Core attributes (1-20 scale, starting around 3-5)
@export var grit: int = 3       # Melee damage, stagger resistance
@export var agility: int = 3    # Movement, dodge, attack speed
@export var will: int = 3       # Spell slots, magic resistance
@export var speech: int = 3     # Shop prices, dialogue
@export var knowledge: int = 3  # Spell power, crafting, XP bonus
@export var vitality: int = 3   # Max HP, HP regen

## Derived stats
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_stamina: int = 100
@export var current_stamina: int = 100
@export var max_mana: int = 50
@export var current_mana: int = 50
@export var max_spell_slots: int = 5
@export var current_spell_slots: int = 5

## Progression
@export var level: int = 1
@export var improvement_points: int = 0  # XP/IP for buying skills/stats
@export var total_ip_earned: int = 0     # Total IP ever earned (for level calculation)

## Morality and Faction System
@export var morality_score: int = 0      # -100 (evil) to +100 (good)
var faction_reputations: Dictionary = {} # faction_id -> reputation (-100 to 100)
var faction_memberships: Dictionary = {} # faction_id -> {rank: String, joined_time: float}

## Level thresholds - level is based on total IP earned (not spent)
## Levels 1-10: Original tabletop progression
## Levels 11-17: Extended mid-game
## Levels 18-20: Endgame mastery (max level 20)
const IP_PER_LEVEL: Array[int] = [
	0, 100, 300, 600, 1000, 1500, 2500, 4000, 6000, 9000,       # Levels 1-10
	13000, 18000, 25000, 35000, 50000, 70000, 100000,           # Levels 11-17
	140000, 200000, 280000                                       # Levels 18-20
]

## Note: XP costs for stats now use Enums.get_stat_xp_cost() - unified with skill costs

## Skills dictionary (Enums.Skill -> level 0-15)
var skills: Dictionary = {}

## Active conditions dictionary (Enums.Condition -> time_remaining)
var conditions: Dictionary = {}

## DOT (Damage Over Time) configuration
const DOT_TICK_INTERVAL: float = 1.5  # Seconds between damage ticks
var dot_tick_timers: Dictionary = {}  # Tracks time until next tick per condition

## ============================================================================
## TIMED BUFFS
## ============================================================================
## Potions and blessings that raise a stat, armour, damage or a resistance for
## a while. Separate from `conditions`, which is the status-effect track
## (poisoned, bleeding, staggered) and is keyed by Enums.Condition.
##
## Nine ItemData.ConsumableEffect values described exactly this in their
## tooltips and applied nothing at all - a Blessing of Gaela cost 250 gold for
## ten minutes of nothing. This is the container they were missing.
##
## Shape: buff_id -> { "amount": float, "remaining": float }
## Reapplying a buff takes the better amount and the longer remaining time, so
## drinking a second, weaker potion never downgrades the first.

const BUFF_GRIT := "grit"
const BUFF_AGILITY := "agility"
const BUFF_WILL := "will"
const BUFF_ARMOR := "armor"
const BUFF_DAMAGE := "damage"          # fraction, 0.25 = +25%
const BUFF_RESIST_FIRE := "resist_fire"
const BUFF_RESIST_FROST := "resist_frost"
const BUFF_RESIST_POISON := "resist_poison"
const BUFF_INVISIBILITY := "invisibility"

## The six a priest's blessing grants. Each has a reader, named beside it -
## a buff id nothing reads ticks, saves and does nothing, which is exactly the
## defect the blessings themselves were (every bless choice in all three
## temples had `actions: []`).
const BUFF_MOVE_SPEED := "move_speed"        # fraction; get_movement_speed_multiplier
const BUFF_ATTACK_SPEED := "attack_speed"    # fraction; PlayerController attack cooldown
const BUFF_HP_REGEN := "hp_regen"            # HP per second; get_hp_regen
const BUFF_CARRY_WEIGHT := "carry_weight"    # flat; InventoryManager.get_max_carry_weight
const BUFF_UNDEAD_DAMAGE := "undead_damage"  # fraction; CombatManager.apply_melee_damage
const BUFF_HORROR_WARD := "horror_ward"      # flat roll bonus; CombatManager.trigger_horror_check

## Damage reduction a RESIST_* buff grants against its damage type.
const RESIST_BUFF_REDUCTION: float = 0.5

## How much harder the player is to see while invisible (multiplies visibility).
const INVISIBILITY_VISIBILITY_MULT: float = 0.15

var active_buffs: Dictionary = {}

func _init() -> void:
	# Initialize all skills to 0
	for skill in Enums.Skill.values():
		skills[skill] = 0

## Get a skill level
func get_skill(skill: Enums.Skill) -> int:
	if skills.has(skill):
		return skills[skill]
	return 0

## Set a skill level
func set_skill(skill: Enums.Skill, new_level: int) -> void:
	var old_level: int = skills.get(skill, 0)
	skills[skill] = clamp(new_level, 0, 15)
	if skills[skill] != old_level:
		skill_changed.emit(skill, old_level, skills[skill])

## Increase a skill by 1 (if IP available)
func increase_skill(skill: Enums.Skill) -> bool:
	var current_level: int = get_skill(skill)
	if current_level >= 15:
		return false

	var cost: int = Enums.get_skill_ip_cost(current_level + 1)
	if improvement_points < cost:
		return false

	improvement_points -= cost
	skills[skill] = current_level + 1
	skill_changed.emit(skill, current_level, current_level + 1)
	return true

## Get XP cost to increase a stat from current value
func get_stat_ip_cost(current_value: int) -> int:
	# Stats start at 3, level = current_value - 2 (so stat 3->4 is level 1, stat 4->5 is level 2, etc.)
	var level := current_value - 2
	if level < 1:
		return Enums.XP_COSTS[0]  # Minimum cost to reach baseline
	if level > Enums.XP_COSTS.size():
		return 800000  # Very expensive for stats beyond 17
	return Enums.get_stat_xp_cost(level)

## Increase a stat by 1 (if IP available)
func increase_stat(stat: Enums.Stat) -> bool:
	var current_value := get_stat(stat)
	if current_value >= 20:  # Max stat cap
		return false

	var cost := get_stat_ip_cost(current_value)
	if improvement_points < cost:
		return false

	improvement_points -= cost
	set_stat(stat, current_value + 1)
	recalculate_derived_stats()
	return true

## Add improvement points (XP)
func add_ip(amount: int) -> void:
	improvement_points += amount
	total_ip_earned += amount
	ip_gained.emit(amount)
	_check_level_up()

## Check if player should level up based on total IP earned
func _check_level_up() -> void:
	var new_level := 1
	for i in range(IP_PER_LEVEL.size()):
		if total_ip_earned >= IP_PER_LEVEL[i]:
			new_level = i + 1
	if new_level > level:
		level = new_level
		level_up.emit(level)

## Get XP multiplier based on Knowledge
func get_xp_multiplier() -> float:
	# +5% XP per Knowledge point (uses effective stat)
	return 1.0 + (get_effective_stat(Enums.Stat.KNOWLEDGE) * 0.05)

## Get base stat value by enum (without equipment bonuses)
func get_stat(stat: Enums.Stat) -> int:
	match stat:
		Enums.Stat.GRIT: return grit
		Enums.Stat.AGILITY: return agility
		Enums.Stat.WILL: return will
		Enums.Stat.SPEECH: return speech
		Enums.Stat.KNOWLEDGE: return knowledge
		Enums.Stat.VITALITY: return vitality
	return 0

## Get effective stat value (base + equipment bonuses)
func get_effective_stat(stat: Enums.Stat) -> int:
	var base_value := get_stat(stat)
	var stat_name: String
	match stat:
		Enums.Stat.GRIT: stat_name = "grit"
		Enums.Stat.AGILITY: stat_name = "agility"
		Enums.Stat.WILL: stat_name = "will"
		Enums.Stat.SPEECH: stat_name = "speech"
		Enums.Stat.KNOWLEDGE: stat_name = "knowledge"
		Enums.Stat.VITALITY: stat_name = "vitality"
		_: return base_value

	# Timed buffs raise the same three stats potion tooltips promise. GRIT is
	# BUFF_STRENGTH's target because Grit is this game's strength stat.
	var buff_bonus: float = 0.0
	match stat:
		Enums.Stat.GRIT: buff_bonus = get_buff(BUFF_GRIT)
		Enums.Stat.AGILITY: buff_bonus = get_buff(BUFF_AGILITY)
		Enums.Stat.WILL: buff_bonus = get_buff(BUFF_WILL)

	return base_value + InventoryManager.get_equipment_stat_bonus(stat_name) + int(buff_bonus)

## Set stat value by enum
func set_stat(stat: Enums.Stat, value: int) -> void:
	var old_value := get_stat(stat)
	match stat:
		Enums.Stat.GRIT: grit = value
		Enums.Stat.AGILITY: agility = value
		Enums.Stat.WILL: will = value
		Enums.Stat.SPEECH: speech = value
		Enums.Stat.KNOWLEDGE: knowledge = value
		Enums.Stat.VITALITY: vitality = value
	if value != old_value:
		stat_changed.emit(stat, old_value, value)

## Initialize racial bonuses
func initialize_race_bonuses() -> void:
	match race:
		Enums.Race.HUMAN:
			# Versatile - +1d4 to Grit, Will, Speech
			grit += randi_range(1, 4)
			will += randi_range(1, 4)
			speech += randi_range(1, 4)
		Enums.Race.ELF:
			# Graceful - +2+1d4 to Vitality, Will, Speech
			vitality += 2 + randi_range(1, 4)
			will += 2 + randi_range(1, 4)
			speech += 2 + randi_range(1, 4)
		Enums.Race.HALFLING:
			# Quick and cunning - +1+1d4 to Agility, Speech, Knowledge
			agility += 1 + randi_range(1, 4)
			speech += 1 + randi_range(1, 4)
			knowledge += 1 + randi_range(1, 4)
		Enums.Race.DWARF:
			# Tough and stubborn - +3+1d4 to Grit, Knowledge, Vitality
			grit += 3 + randi_range(1, 4)
			knowledge += 3 + randi_range(1, 4)
			vitality += 3 + randi_range(1, 4)

## Initialize career starting skills
func initialize_career() -> void:
	match career:
		Enums.Career.APPRENTICE:
			skills[Enums.Skill.ARCANA_LORE] = 2
			skills[Enums.Skill.HISTORY] = 1
		Enums.Career.FARMER:
			skills[Enums.Skill.ENDURANCE] = 2
			skills[Enums.Skill.SURVIVAL] = 1
		Enums.Career.GRAVE_DIGGER:
			skills[Enums.Skill.ENDURANCE] = 1
			skills[Enums.Skill.RELIGION] = 1
			skills[Enums.Skill.BRAVERY] = 1
		Enums.Career.SCOUT:
			skills[Enums.Skill.INTUITION] = 2
			skills[Enums.Skill.STEALTH] = 1
		Enums.Career.SOLDIER:
			skills[Enums.Skill.MELEE] = 2
			skills[Enums.Skill.ATHLETICS] = 1
		Enums.Career.MERCHANT:
			skills[Enums.Skill.PERSUASION] = 2
			skills[Enums.Skill.DECEPTION] = 1
		Enums.Career.PRIEST:
			skills[Enums.Skill.RELIGION] = 2
			skills[Enums.Skill.FIRST_AID] = 1
		Enums.Career.THIEF:
			skills[Enums.Skill.STEALTH] = 2
			skills[Enums.Skill.LOCKPICKING] = 1

## Recalculate derived stats based on attributes (uses effective stats)
func recalculate_derived_stats() -> void:
	var eff_vitality := get_effective_stat(Enums.Stat.VITALITY)
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)

	# Skill bonuses
	var endurance_skill := get_skill(Enums.Skill.ENDURANCE)
	var concentration_skill := get_skill(Enums.Skill.CONCENTRATION)

	# Max HP = 50 + (Vitality * 10) + (Grit * 5)
	max_hp = 50 + (eff_vitality * 10) + (eff_grit * 5)

	# Max Stamina = 50 + (Agility * 5) + (Vitality * 5) + (Endurance * 10) + (Athletics * 5)
	# ENDURANCE: +10 max stamina per level
	# ATHLETICS: +5 max stamina per level
	var athletics_skill := get_skill(Enums.Skill.ATHLETICS)
	max_stamina = 50 + (eff_agility * 5) + (eff_vitality * 5) + (endurance_skill * 10) + (athletics_skill * 5)

	# Max Mana = 20 + (Will * 10) + (Knowledge * 5) + (Concentration * 8)
	# CONCENTRATION: +8 max mana per level
	max_mana = 20 + (eff_will * 10) + (eff_knowledge * 5) + (concentration_skill * 8)

## Heal HP
func heal(amount: int) -> int:
	var old_hp: int = current_hp
	current_hp = min(current_hp + amount, max_hp)
	if current_hp != old_hp:
		hp_changed.emit(old_hp, current_hp, max_hp)
	return current_hp - old_hp

## Take damage (returns actual damage taken)
func take_damage(amount: int) -> int:
	var old_hp: int = current_hp
	current_hp = max(current_hp - amount, 0)
	if current_hp != old_hp:
		hp_changed.emit(old_hp, current_hp, max_hp)
	return old_hp - current_hp

## Check if dead
func is_dead() -> bool:
	return current_hp <= 0

## Restore stamina
func restore_stamina(amount: int) -> void:
	var old_stamina := current_stamina
	current_stamina = min(current_stamina + amount, max_stamina)
	if current_stamina != old_stamina:
		stamina_changed.emit(old_stamina, current_stamina, max_stamina)

## Use stamina (returns true if had enough)
func use_stamina(amount: int) -> bool:
	if current_stamina >= amount:
		var old_stamina := current_stamina
		current_stamina -= amount
		stamina_changed.emit(old_stamina, current_stamina, max_stamina)
		return true
	return false

## Restore mana
func restore_mana(amount: int) -> void:
	var old_mana := current_mana
	current_mana = min(current_mana + amount, max_mana)
	if current_mana != old_mana:
		mana_changed.emit(old_mana, current_mana, max_mana)

## Use mana (returns true if had enough)
func use_mana(amount: int) -> bool:
	if current_mana >= amount:
		var old_mana := current_mana
		current_mana -= amount
		mana_changed.emit(old_mana, current_mana, max_mana)
		return true
	return false

## Use spell slots (returns true if had enough)
func use_spell_slots(amount: int) -> bool:
	if current_spell_slots >= amount:
		current_spell_slots -= amount
		return true
	return false

## Restore spell slots
func restore_spell_slots(amount: int) -> void:
	current_spell_slots = min(current_spell_slots + amount, max_spell_slots)

## Get movement speed multiplier based on Agility (uses effective stat)
func get_movement_multiplier() -> float:
	return 1.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.05)

## Get attack speed multiplier (uses effective stat)
func get_attack_speed_multiplier() -> float:
	return 1.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.03) + get_buff(BUFF_ATTACK_SPEED)

## Get magic resistance (0.0 to ~0.5) (uses effective stat + RESIST skill)
## RESIST: +3% magic resistance per level (stacks with Will's 2% per point)
func get_magic_resistance() -> float:
	var will_resist := get_effective_stat(Enums.Stat.WILL) * 0.02
	var skill_resist := get_skill(Enums.Skill.RESIST) * 0.03
	return minf(will_resist + skill_resist, 0.75)  # Cap at 75% resistance

## Get stamina drain multiplier based on ENDURANCE and ATHLETICS skills
## ENDURANCE: -5% stamina consumption per level
## ATHLETICS: -3% stamina consumption per level
## Combined cap at 50% reduction
func get_stamina_drain_multiplier() -> float:
	var endurance_skill := get_skill(Enums.Skill.ENDURANCE)
	var athletics_skill := get_skill(Enums.Skill.ATHLETICS)
	var reduction := (endurance_skill * 0.05) + (athletics_skill * 0.03)
	return maxf(0.5, 1.0 - reduction)

## Get HP regen per second. Zero by default - the player recovers through
## potions and rest - so any regen at all is something granted, and today that
## is Gaela's blessing.
func get_hp_regen() -> float:
	return get_buff(BUFF_HP_REGEN)

## Get stamina regen per second (slow passive regen for movement) (uses effective stat)
## ATHLETICS: +0.3 stamina regen per level
func get_stamina_regen() -> float:
	var athletics_skill := get_skill(Enums.Skill.ATHLETICS)
	return 2.0 + (get_effective_stat(Enums.Stat.AGILITY) * 0.2) + (athletics_skill * 0.3)

## Get mana regen per second (uses effective stats)
## Same rate as stamina regen, but scales with Will instead of Agility
func get_mana_regen() -> float:
	return 2.0 + (get_effective_stat(Enums.Stat.WILL) * 0.2)

## Get movement speed multiplier based on Agility and Athletics
## Agility: +2% per point
## ATHLETICS: +3% per level
## Returns multiplier (1.0 = normal speed)
func get_movement_speed_multiplier() -> float:
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var athletics_skill := get_skill(Enums.Skill.ATHLETICS)
	return 1.0 + (eff_agility * 0.02) + (athletics_skill * 0.03) + get_buff(BUFF_MOVE_SPEED)


## Roll bonus against a horror check, on top of Will + Bravery.
func get_horror_ward() -> int:
	return int(get_buff(BUFF_HORROR_WARD))

## Apply (or refresh) a timed buff. Takes the better amount and the longer
## remaining time, so a weaker potion never downgrades a stronger one.
func apply_buff(buff_id: String, amount: float, duration: float) -> void:
	if duration <= 0.0:
		return
	var existing: Dictionary = active_buffs.get(buff_id, {})
	var best_amount: float = maxf(amount, float(existing.get("amount", 0.0)))
	var best_remaining: float = maxf(duration, float(existing.get("remaining", 0.0)))
	active_buffs[buff_id] = {"amount": best_amount, "remaining": best_remaining}
	buff_applied.emit(buff_id, best_amount, best_remaining)


## Current magnitude of a buff, or 0.0 if it is not running.
func get_buff(buff_id: String) -> float:
	var entry: Dictionary = active_buffs.get(buff_id, {})
	return float(entry.get("amount", 0.0))


func has_buff(buff_id: String) -> bool:
	return active_buffs.has(buff_id)


## Seconds left on a buff, or 0.0.
func get_buff_remaining(buff_id: String) -> float:
	var entry: Dictionary = active_buffs.get(buff_id, {})
	return float(entry.get("remaining", 0.0))


func remove_buff(buff_id: String) -> void:
	if active_buffs.erase(buff_id):
		buff_expired.emit(buff_id)


func clear_buffs() -> void:
	for buff_id: String in active_buffs.keys():
		buff_expired.emit(buff_id)
	active_buffs.clear()


## Tick every buff down. Called from update_conditions so there is one clock.
func update_buffs(delta: float) -> void:
	if active_buffs.is_empty():
		return
	var expired: Array[String] = []
	for buff_id: String in active_buffs.keys():
		var entry: Dictionary = active_buffs[buff_id]
		entry["remaining"] = float(entry["remaining"]) - delta
		if float(entry["remaining"]) <= 0.0:
			expired.append(buff_id)
	for buff_id: String in expired:
		remove_buff(buff_id)


## Damage reduction (0.0 - 1.0) this character's buffs grant against a type.
func get_buff_damage_resistance(damage_type: Enums.DamageType) -> float:
	var buff_id: String = ""
	match damage_type:
		Enums.DamageType.FIRE: buff_id = BUFF_RESIST_FIRE
		Enums.DamageType.FROST: buff_id = BUFF_RESIST_FROST
		Enums.DamageType.POISON: buff_id = BUFF_RESIST_POISON
		_: return 0.0
	if not has_buff(buff_id):
		return 0.0
	return RESIST_BUFF_REDUCTION


## Apply a condition with duration
func apply_condition(condition: Enums.Condition, duration: float) -> void:
	conditions[condition] = duration
	condition_applied.emit(condition)

## Remove a condition
func remove_condition(condition: Enums.Condition) -> void:
	if conditions.has(condition):
		conditions.erase(condition)
		# Clean up DOT timer if present
		if dot_tick_timers.has(condition):
			dot_tick_timers.erase(condition)
		condition_removed.emit(condition)

## Check if has a condition
func has_condition(condition: Enums.Condition) -> bool:
	return conditions.has(condition) and conditions[condition] > 0

## Update conditions (call every frame with delta)
## Returns a dictionary of DOT damage to apply: { DamageType: damage_amount }
func update_conditions(delta: float) -> Dictionary:
	update_buffs(delta)

	var dot_damage: Dictionary = {}
	var to_remove: Array = []

	for condition in conditions:
		conditions[condition] -= delta
		if conditions[condition] <= 0:
			to_remove.append(condition)
		else:
			# Process DOT conditions
			var dot_result: Dictionary = _process_dot_condition(condition, delta)
			if not dot_result.is_empty():
				for damage_type in dot_result:
					if dot_damage.has(damage_type):
						dot_damage[damage_type] += dot_result[damage_type]
					else:
						dot_damage[damage_type] = dot_result[damage_type]

	for condition in to_remove:
		remove_condition(condition)

	return dot_damage

## Process DOT damage for a specific condition
## Returns { DamageType: damage } if damage should be dealt this frame, empty otherwise
func _process_dot_condition(condition: Enums.Condition, delta: float) -> Dictionary:
	# Only process DOT conditions
	if condition not in [Enums.Condition.POISONED, Enums.Condition.BLEEDING, Enums.Condition.BURNING]:
		return {}

	# Initialize timer if not present
	if not dot_tick_timers.has(condition):
		dot_tick_timers[condition] = DOT_TICK_INTERVAL

	# Decrement timer
	dot_tick_timers[condition] -= delta

	# Check if it's time to tick
	if dot_tick_timers[condition] <= 0:
		dot_tick_timers[condition] = DOT_TICK_INTERVAL

		# Return damage based on condition type
		match condition:
			Enums.Condition.POISONED:
				# Poison: 2-3 damage per tick
				return { Enums.DamageType.POISON: randi_range(2, 3) }
			Enums.Condition.BLEEDING:
				# Bleeding: 1-2 damage per tick
				return { Enums.DamageType.PHYSICAL: randi_range(1, 2) }
			Enums.Condition.BURNING:
				# Burning: 3-4 damage per tick
				return { Enums.DamageType.FIRE: randi_range(3, 4) }

	return {}

# =============================================================================
# COMBAT SCALING - Build choices matter in combat
# =============================================================================

## Get melee damage bonus from stats and skills
## Formula: (Grit × 0.5) + (Melee skill × 2)
func get_melee_damage_bonus() -> int:
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var melee_skill := get_skill(Enums.Skill.MELEE)
	return int(eff_grit * 0.5) + (melee_skill * 2)

## Get ranged damage bonus from stats and skills
## Formula: (Agility × 0.5) + (Ranged skill × 2)
func get_ranged_damage_bonus() -> int:
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var ranged_skill := get_skill(Enums.Skill.RANGED)
	return int(eff_agility * 0.5) + (ranged_skill * 2)

## Get spell damage bonus from stats and skills
## Formula: (Knowledge × 0.5) + (Arcana Lore × 2)
func get_spell_damage_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var arcana_skill := get_skill(Enums.Skill.ARCANA_LORE)
	return int(eff_knowledge * 0.5) + (arcana_skill * 2)

## Get spell cost reduction multiplier based on Will
## Formula: 1.0 - (Will × 0.02) -- Will 10 = 20% reduction
func get_spell_cost_multiplier() -> float:
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	return maxf(0.5, 1.0 - (eff_will * 0.02))  # Cap at 50% reduction

## Get enemy detection range based on INTUITION skill
## INTUITION: Base 15 + 5 per level = up to 65 units at level 10
## Also influenced by Knowledge stat
func get_enemy_detection_range() -> float:
	var base_range := 15.0
	var intuition_skill := get_skill(Enums.Skill.INTUITION)
	var knowledge_bonus := get_effective_stat(Enums.Stat.KNOWLEDGE) * 0.5
	return base_range + (intuition_skill * 5.0) + knowledge_bonus

## Get intimidation check bonus (Grit + Intimidation skill)
## Used when intimidating enemies
func get_intimidation_bonus() -> int:
	var eff_grit := get_effective_stat(Enums.Stat.GRIT)
	var intimidation_skill := get_skill(Enums.Skill.INTIMIDATION)
	return eff_grit + intimidation_skill

## Get IP needed for next level (for UI display)
func get_ip_for_next_level() -> int:
	if level >= IP_PER_LEVEL.size():
		return 0  # Max level
	return IP_PER_LEVEL[level]

## Get IP progress toward next level (for UI progress bar)
func get_level_progress() -> float:
	if level >= IP_PER_LEVEL.size():
		return 1.0  # Max level
	var current_threshold := IP_PER_LEVEL[level - 1] if level > 1 else 0
	var next_threshold := IP_PER_LEVEL[level]
	var progress_in_level := total_ip_earned - current_threshold
	var level_range := next_threshold - current_threshold
	return float(progress_in_level) / float(level_range)

# =============================================================================
# SKILL HELPER FUNCTIONS - For use by various game systems
# =============================================================================

## Get pickpocket success bonus (Agility + Thievery + Stealth/2)
## THIEVERY: Primary pickpocket skill, STEALTH provides half bonus
func get_pickpocket_bonus() -> int:
	var eff_agility := get_effective_stat(Enums.Stat.AGILITY)
	var thievery_skill := get_skill(Enums.Skill.THIEVERY)
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	@warning_ignore("integer_division")
	return eff_agility + thievery_skill + (stealth_skill / 2)

## Get stealth effectiveness multiplier
## STEALTH: Base detection range reduced by 5% per level (up to 50%)
## Crouching adds +10% bonus (handled by PlayerController)
func get_stealth_multiplier() -> float:
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	return maxf(0.5, 1.0 - (stealth_skill * 0.05))

## Get backstab crit chance bonus
## STEALTH: +3% backstab crit chance per level
func get_backstab_crit_bonus() -> float:
	var stealth_skill := get_skill(Enums.Skill.STEALTH)
	return stealth_skill * 0.03

## Get plant harvest yield multiplier
## HERBALISM: +20% plant yields per level (up to 200% at level 10)
func get_herbalism_yield_multiplier() -> float:
	var herbalism_skill := get_skill(Enums.Skill.HERBALISM)
	return 1.0 + (herbalism_skill * 0.2)

## Get potion effectiveness multiplier
## HERBALISM: +10% potion strength per level (up to 100% at level 10)
func get_potion_strength_multiplier() -> float:
	var herbalism_skill := get_skill(Enums.Skill.HERBALISM)
	return 1.0 + (herbalism_skill * 0.1)

## Get horror check bonus (Will + Bravery)
## BRAVERY: Resistance to horror effects, also provides Fearless Inspiration on success
func get_horror_check_bonus() -> int:
	var eff_will := get_effective_stat(Enums.Stat.WILL)
	var bravery_skill := get_skill(Enums.Skill.BRAVERY)
	return eff_will + bravery_skill

## Get holy damage multiplier against undead
## RELIGION: +10% holy damage per level (up to +100% at level 10)
func get_holy_damage_multiplier() -> float:
	var religion_skill := get_skill(Enums.Skill.RELIGION)
	return 1.0 + (religion_skill * 0.1)

## Get undead resistance bonus (damage reduction from undead attackers)
## RELIGION: +5% damage reduction from undead per level
func get_undead_resistance() -> float:
	var religion_skill := get_skill(Enums.Skill.RELIGION)
	return minf(0.5, religion_skill * 0.05)  # Cap at 50% reduction

## Get plant identification bonus (chance to find extra herbs)
## NATURE: +10% chance to find bonus herbs per level
func get_nature_bonus_chance() -> float:
	var nature_skill := get_skill(Enums.Skill.NATURE)
	return minf(1.0, nature_skill * 0.1)  # Cap at 100%

## Get first aid healing bonus (healing done to self and others)
## FIRST_AID: +8% healing effectiveness per level
func get_first_aid_multiplier() -> float:
	var first_aid_skill := get_skill(Enums.Skill.FIRST_AID)
	return 1.0 + (first_aid_skill * 0.08)

## Get trap detection bonus (Knowledge + Intuition)
## INTUITION: General awareness, helps detect traps and hidden objects
func get_trap_detection_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var intuition_skill := get_skill(Enums.Skill.INTUITION)
	return eff_knowledge + intuition_skill

## Get hidden door/object detection bonus (Knowledge + History + Investigation)
## HISTORY: Lore knowledge helps find secret passages
## INVESTIGATION: Thorough searching
func get_hidden_detection_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var history_skill := get_skill(Enums.Skill.HISTORY)
	var investigation_skill := get_skill(Enums.Skill.INVESTIGATION)
	return eff_knowledge + history_skill + investigation_skill

## Get crafting quality bonus (Knowledge + Engineering)
## ENGINEERING: Improves crafted item quality
func get_crafting_quality_bonus() -> int:
	var eff_knowledge := get_effective_stat(Enums.Stat.KNOWLEDGE)
	var engineering_skill := get_skill(Enums.Skill.ENGINEERING)
	return eff_knowledge + engineering_skill

## Get repair effectiveness multiplier
## ENGINEERING: +10% repair effectiveness per level
func get_repair_effectiveness_multiplier() -> float:
	var engineering_skill := get_skill(Enums.Skill.ENGINEERING)
	return 1.0 + (engineering_skill * 0.1)

## Get wilderness rest bonus multiplier
## SURVIVAL: +15% wilderness rest recovery per level
func get_wilderness_rest_multiplier() -> float:
	var survival_skill := get_skill(Enums.Skill.SURVIVAL)
	return 1.0 + (survival_skill * 0.15)
