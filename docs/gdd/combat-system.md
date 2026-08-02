# Combat System GDD

**Version:** 1.0
**Last Updated:** 2026-05-25
**Status:** Implemented

---

## 1. Overview

Broken Provinces uses a real-time action combat system inspired by Dark Souls and Elder Scrolls. Combat emphasizes positioning, stamina management, and meaningful weapon choices. The system supports melee, ranged, and magic combat with unified damage calculation.

**Core File:** `scripts/systems/combat/combat_manager.gd`

---

## 2. Player Fantasy

The player is a mortal adventurer in a dangerous world. Combat is deadly and tactical—even common bandits can kill an unprepared player. Victory comes from:
- Knowing enemy patterns
- Managing stamina
- Choosing the right weapon for the situation
- Using terrain and positioning

---

## 3. Core Mechanics

### 3.1 Attack Types

| Attack Type | Description | Stamina Cost | Modifier |
|-------------|-------------|--------------|----------|
| Light Attack | Quick swing | Low | Base damage |
| Heavy Attack | Slow, powerful | High | +50% damage |
| Backstab | Attack unaware enemy | Normal | +50% to +150% (Stealth skill) |
| Ranged | Bow/crossbow | Medium | Distance falloff |
| Spell | Magic attack | Mana | Knowledge/Arcana scaling |

### 3.2 Defense Options

| Defense | Effect | Stamina Cost |
|---------|--------|--------------|
| Block | Reduce damage by shield value | Per hit blocked |
| Dodge | I-frames during roll | High |
| Parry | Stagger attacker (timing critical) | Low |

---

## 4. Damage Formulas

### 4.1 Melee Damage

```
Base Damage = Weapon.roll_damage(quality)
Multiplier = 1.0 + (Grit / 10) + (Melee Skill / 20)
Total = Base × Multiplier × Heavy Bonus × Backstab Bonus
Final = Total × Armor Reduction × Type Modifier
```

**Heavy Attack Bonus:** ×1.5
**Backstab Bonus:** 1.5 + (Stealth × 0.1) = 1.5× to 2.5×

### 4.2 Ranged Damage

```
Base Damage = Weapon.roll_damage(quality)
Multiplier = 1.0 + (Agility / 15) + (Ranged Skill / 20)
Distance Falloff = Applied beyond 75% of max range
Final = Base × Multiplier × Falloff × Armor Reduction
```

### 4.3 Spell Damage

```
Base Effect = Spell.roll_effect(Knowledge, Arcana)
Total = Base × Charged Multiplier
Final = Total × Type Modifier × (1.0 - Magic Resistance)
```

### 4.4 Armor Reduction

```
Reduction = 100 / (100 + Armor Value)
Effective AV = Target AV × (1.0 - Armor Pierce)
```

Example: 50 AV reduces damage by 33% (100/150 = 0.67)

---

## 5. Damage Types

| Type | Description | Common Sources |
|------|-------------|----------------|
| PHYSICAL | Standard weapon damage | Swords, axes, arrows |
| FIRE | Burning damage | Fire spells, torches |
| LIGHTNING | Shock damage | Lightning spells |
| FROST | Cold damage | Ice spells |
| POISON | Toxic damage | Venomous weapons, alchemy |
| NECROTIC | Death magic | Undead attacks, dark spells |
| HOLY | Divine damage | Blessed weapons, prayers |
| MAGIC | Pure arcane | Generic spells |

### 5.1 Type Resistances

Enemies and players can have multipliers per damage type:
- **1.5×** = Weakness (takes 50% extra)
- **1.0×** = Normal
- **0.5×** = Resistance (takes 50% less)
- **0.0×** = Immunity

**Undead:** Weak to HOLY, Immune to POISON

---

## 6. Status Conditions

| Condition | Effect | Duration |
|-----------|--------|----------|
| KNOCKED_DOWN | Prone, must get up | ~2s |
| POISONED | DOT damage over time | 5-10s |
| BURNING | Fire DOT, spreads | 3-5s |
| FROZEN | Slowed movement/attack | 3-5s |
| HORRIFIED | -25% damage dealt | 5s |
| BLEEDING | Physical DOT | 5-8s |
| STUNNED | Cannot act | 1-3s |
| SILENCED | Cannot cast spells | 5-10s |
| ARMORED | -25% damage taken | Buff duration |
| BLINDED | 50% miss chance | 3-5s |
| SLOWED | -30% movement speed | 5s |
| HASTED | +30% movement speed | Buff duration |

---

## 7. Critical Hits

**Base Crit Chance:** From weapon (typically 5-15%)
**Crit Bonus:** +1% per Melee/Ranged skill point
**Crit Multiplier:** From weapon (typically 1.5×-2.5×)

```
Effective Crit Chance = Weapon.crit_chance + (Skill × 0.01)
if random() < Effective Crit Chance:
    Damage × Weapon.crit_multiplier
```

---

## 8. Stats Affecting Combat

### Primary Stats

| Stat | Combat Effects |
|------|----------------|
| GRIT | +10% melee damage per point, stagger resistance |
| AGILITY | +6.67% ranged damage per point, dodge i-frames |
| WILL | Magic resistance, stamina regen |
| VITALITY | Max HP, HP regen, DOT resistance |
| KNOWLEDGE | +spell power, XP bonus |

### Combat Skills

| Skill | Effect |
|-------|--------|
| MELEE | +5% melee damage per point, +1% crit chance |
| RANGED | +5% ranged damage per point, +2% crit chance |
| DODGE | I-frame duration, stamina efficiency |
| STEALTH | Backstab multiplier (1.5× + Skill × 0.1) |
| BRAVERY | Horror check bonus |
| RESIST | Magic resistance |

---

## 9. Horror System

Certain enemies (undead, demons) can trigger Horror Checks.

**Trigger Conditions:**
- 25% chance on first sight of horror enemy
- 60-second cooldown per source
- Passive (no popup)

**Horror Check Formula:**
```
Roll = d10 + Will + Bravery
Pass = Roll >= Difficulty OR Natural 10 (auto-success)
```

**Outcomes:**
- **Pass:** "Fearless Inspiration" buff (+1d6 damage for 10s)
- **Fail:** HORRIFIED condition (-25% damage for 5s)

---

## 10. Weapon Degradation

**Attacking:** Weapon degrades by 1 durability per hit
**Defending:** Armor degrades by damage/10 per hit taken

At 0 durability, weapons deal 50% damage and armor provides 50% protection.

---

## 11. Humanoid Dialogue System

Special enemies with `allows_dialogue = true` trigger a FIGHT/BRIBE/NEGOTIATE/INTIMIDATE menu instead of instant combat.

**Enabled For:** Named NPCs, quest targets, boss encounters
**Disabled For:** Generic enemies (bandits attack on sight)

---

## 12. Performance Budgets

| Resource | Budget |
|----------|--------|
| Active enemies per zone | 20 max |
| Raycasts per frame (LOS) | 5 max |
| LOS check range | 50 units max |
| Projectile pool | 50 |

---

## 13. Edge Cases

### Player Death
- Death screen with respawn options
- Gold penalty on death
- Enemies reset to spawn positions

### Enemy Death
- XP awarded immediately
- Lootable corpse spawns (search to loot)
- Corpse despawns after 5 minutes

### Blocking During Attack
- Cannot block while attack animation playing
- Block priority over attack input

### Multiple Hits Same Frame
- Each hit calculated independently
- Damage numbers stack visually

---

## 14. Dependencies

| System | Dependency |
|--------|------------|
| CharacterData | Stats, skills, conditions |
| WeaponData | Damage rolls, types, conditions |
| InventoryManager | Equipment, degradation |
| Enums | DamageType, Condition, Stat, Skill |

---

## 15. Tuning Knobs

| Parameter | Location | Default |
|-----------|----------|---------|
| Heavy attack multiplier | combat_manager.gd:122 | 1.5 |
| Backstab base multiplier | combat_manager.gd:128 | 1.5 |
| Horror check cooldown | combat_manager.gd:501 | 60s |
| Horror check chance | combat_manager.gd:502 | 25% |
| Armor formula divisor | combat_manager.gd:698 | 100 |
| Max raycasts per frame | combat_manager.gd:26 | 5 |

---

## 16. Acceptance Criteria

- [ ] Melee damage scales correctly with Grit and Melee skill
- [ ] Heavy attacks deal 50% more damage
- [ ] Backstabs deal bonus damage based on Stealth skill
- [ ] Armor reduces damage according to formula
- [ ] All damage types apply correctly
- [ ] Conditions apply and expire on schedule
- [ ] Horror checks trigger passively with cooldown
- [ ] Weapon/armor degradation tracks correctly
- [ ] Performance stays within budget limits
