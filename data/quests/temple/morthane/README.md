# Morthane Quest Chain - Temple of Three Gods

**God:** Morthane (Death & Rebirth)
**Philosophy:** Death is a natural part of the cycle. Undeath (zombies, skeletons, liches) is an abomination that corrupts the natural order.
**Faction:** `church_of_morthane` (sub-faction of `church_of_three`)
**Quest Giver:** `priest_morthane_elder_moor` (Priest of Morthane at Temple in Elder Moor)

---

## Quest Chain Overview (11 Quests)

### Tier 1: Initiate (Quests 1-3)
Introduction to Morthane's doctrine and basic undead hunting.

1. **morthane_01_last_rites** - "Final Rest"
   - Perform burial rites for unburied dead
   - Learn Morthane's philosophy
   - **Reward:** 50g, 200 XP, Burial Incense

2. **morthane_02_restless_spirit** - "Unfinished Business"
   - Help ghost find peace
   - Investigation + emotional resolution
   - **Reward:** 75g, 300 XP, Ghost-touched trinket

3. **morthane_03_cemetery_duty** - "Vigil of the Dead"
   - Defend cemetery from grave robbers
   - Destroy risen undead
   - **Reward:** 100g, 400 XP, Grave Warden's Blessing

### Tier 2: Acolyte (Quests 4-5)
Moral complexity and the devotion choice.

4. **morthane_04_necromancer_trail** - "The Defiler's Path"
   - Track necromancer raising the dead
   - **CHOICE:** Kill, redeem, or spare them
   - Different consequences per choice
   - **Reward:** 150g, 500 XP, Death Warden Cloak

5. **morthane_05_devotion_choice** - "Embracing the Cycle" ⭐ **DEVOTEE UNLOCK**
   - Trial of Mortality (near-death ritual)
   - **CRITICAL CHOICE:** Accept or decline devotion to Morthane
   - Sets `morthane_devotee` flag if accepted
   - **Reward:** 200g, 600 XP, Morthane's Amulet, title "Keeper of the Cycle"

### Tier 3: Devotee Exclusive (Quests 6-8)
**Prerequisites:** Must have `morthane_devotee` flag (completed Quest 5 and accepted devotion)

6. **morthane_06_death_speaker** - "Voices Beyond the Veil"
   - Learn Speak with Dead ability
   - Solve murder by talking to victim
   - **Reward:** 250g, 750 XP, Speak with Dead scrolls

7. **morthane_07_lich_rumor** - "Whispers of Immortality"
   - Stop lich transformation ritual
   - Combat powerful undead
   - **Reward:** 300g, 900 XP, Anti-undead weapon

8. **morthane_08_rebirth_ritual** - "The Second Chance"
   - Witness legitimate rebirth ritual
   - Philosophical quest about death and meaning
   - **Reward:** 350g, 1000 XP, Cycle's Wisdom ring (death resistance)

### Tier 4: Champion (Quests 9-10)
Climactic quests with best rewards.

9. **morthane_09_undead_army** - "The Rising Tide"
   - Multi-stage defense against undead incursion
   - Defend multiple towns
   - Defeat Death Knight commander
   - **Reward:** 500g, 1500 XP, Reaper's Blade

10. **morthane_10_deathwalker** - "The Deathwalker" ⭐ **CHAMPION UNLOCK**
    - Final quest: become Champion of Morthane
    - Walk between life and death (near-death experience)
    - Defeat ancient undead lord
    - Sets `morthane_champion` and `deathwalker_title` flags
    - **Reward:** 750g, 2000 XP, Morthane's Shroud

### Bonus: Repeatable
11. **morthane_repeatable_cleansing** - "Cleansing Duty"
    - Clear undead spawns
    - Repeatable weekly (7-day cooldown)
    - **Prerequisites:** Must be a devotee (Quest 5)
    - **Reward:** 100g, 300 XP

---

## Geographic Constraints

**All quests confined to northern regions:**
- Elder Moor (quest hub)
- Dalhurst
- Thornfield
- Millbrook
- Crossroads
- Willow Dale (dungeon)
- Bandit Hideout (dungeon)
- Kazer-Dun Entrance (final quest location)

**NO quests south of Kazer-Dun** as per design constraints.

---

## Devotee System

### Becoming a Devotee
- Complete first 4 quests (initiate tier)
- Accept devotion in Quest 5 (`morthane_05_devotion_choice`)
- Sets flag: `morthane_devotee`
- Unlocks Quests 6-10 and repeatable

### Devotee Benefits
- Access to exclusive high-tier quests
- Acknowledged by other temple priests with unique dialogue
- "One who walks with the cycle..." recognition
- Does NOT lock out other temple quests (Chronos, Gaela)
- Other priests give different dialogue acknowledging your devotion

### Declining Devotion
- If player declines in Quest 5, sets `morthane_devotion_declined` flag
- Quest chain ENDS at Quest 5
- Can still do quests for other gods
- Cannot access Quests 6-10

---

## Faction Reputation

All quests contribute to `church_of_morthane` and `church_of_three` reputation.

**Total Reputation Gain (if all completed):**
- church_of_morthane: **370 base** + bonuses from choices
- church_of_three: **187 base**
- Additional faction gains: guard_faction, mages_guild (quest-dependent)

---

## Choice Consequences

### Quest 4 - Necromancer's Fate
| Choice | Flag | Rep Change |
|--------|------|------------|
| Kill necromancer | `necromancer_aeris_killed` | +10 Morthane |
| Redeem necromancer | `necromancer_aeris_redeemed` | +5 Morthane, +10 Mages Guild |
| Spare necromancer | `necromancer_aeris_freed` | Spawns hostile enemy later |

### Quest 5 - Devotion Decision
| Choice | Flag | Rep Change |
|--------|------|------------|
| Accept devotion | `morthane_devotee` | +30 Morthane, unlocks Quests 6-10 |
| Decline devotion | `morthane_devotion_declined` | None, chain ends |

### Quest 6 - Killer's Justice
| Choice | Flag | Rep Change |
|--------|------|------------|
| Arrest killer | `merchant_vrell_arrested` | +15 Guard Faction |
| Execute killer | `merchant_vrell_executed` | +10 Morthane |

### Quest 10 - Champion Ascension
| Choice | Flag | Rep Change |
|--------|------|------------|
| Become Champion | `morthane_champion`, `deathwalker_title` | +50 Morthane |

---

## Required NPCs

These NPCs must exist in the game for quest functionality:

### Elder Moor
- `priest_morthane_elder_moor` - Quest giver/turn-in for entire chain

### Dalhurst
- `innkeeper_dalhurst` - Quest 2 dialogue

### Millbrook
- `guard_captain_millbrook` - Quest 6 dialogue
- `merchant_vrell` - Quest 6 target (killer)

### Crossroads
- `merchant_elara` - Quest 8 dying merchant

### Willow Dale (Dungeon)
- `necromancer_aeris` - Quest 4 target
- `lich_aspirant_valdris` - Quest 7 boss

### Bandit Hideout (Dungeon)
- `death_knight_commander` - Quest 9 boss

### Kazer-Dun Entrance (Dungeon)
- `undead_lord_malthor` - Quest 10 final boss

---

## Required Enemies

Enemy types that must exist for kill objectives:

- `human_bandit` - Quest 3
- `skeleton_warrior` - Quests 3, 9
- `skeleton_shade` - Quests 7, 9, 10
- `death_knight_commander` - Quest 9 (boss)
- `lich_aspirant_valdris` - Quest 7 (boss)
- `undead_lord_malthor` - Quest 10 (final boss)

---

## Required Items

Items referenced in quests (must exist in item database):

### Quest Items (Created on Accept)
- `burial_incense` - Quest 1 starter, Quest 2 reward
- `ghost_locket` - Quest 2 collectible
- `holy_water` - Quest 3 starter
- `necromancer_journal` - Quest 4 collectible
- `phylactery_research` - Quest 7 collectible
- `deaths_lily`, `grave_soil`, `rebirth_incense` - Quest 8 components
- `morthane_sacred_flame` - Quest 9 starter

### Reward Items
- `ghost_touched_trinket` - Quest 2
- `grave_warden_blessing` - Quest 3
- `death_warden_cloak` - Quest 4
- `morthane_amulet` - Quest 5
- `speak_with_dead_scroll` - Quest 6
- `anti_undead_longsword` - Quest 7
- `cycle_wisdom_ring` - Quest 8 (death resistance)
- `reapers_blade` - Quest 9
- `morthane_shroud` - Quest 10 (champion item)

---

## Required Interactables

Interactive objects/markers referenced in quests:

### Elder Moor
- `shrine_of_endings` - Quest 5 meditation
- `mortality_trial_altar` - Quest 5 trial
- `shrine_of_endings_champion` - Quest 10 preparation
- `death_walk_altar` - Quest 10 ritual
- `rebirth_ritual_circle`, `rebirth_ritual_altar` - Quest 8

### Crossroads
- `burial_site_marker` - Quest 1 (3 locations)

### Dalhurst
- `ghost_grave_marker` - Quest 2

### Thornfield
- `desecrated_grave_marker` - Quest 3 (3 locations)

### Willow Dale
- `lich_transformation_altar` - Quest 7

### Millbrook
- `murder_victim_corpse` - Quest 6

### Bandit Hideout
- `corruption_nexus`, `corruption_nexus_purified` - Quest 9

### Kazer-Dun Entrance
- `kazer_dun_catacombs` - Quest 10 entrance
- `morthane_champion_altar` - Quest 10 final blessing

---

## Implementation Notes

### Quest Chain Loading
All quests auto-link via `next_quest` field:
- Quest 1 → Quest 2 → Quest 3 → Quest 4 → Quest 5
- Quest 5 (if devotee) → Quest 6 → Quest 7 → Quest 8 → Quest 9 → Quest 10

### Devotee Gate
Quest 6-10 should check for `morthane_devotee` flag before starting.
If player declined devotion, priest should have dialogue explaining they cannot offer advanced training.

### Spawn on Accept
Several quests use `spawn_on_accept` to place quest items in the world:
- Quests 2, 4, 7, 8 spawn chests with quest items

### Choice Tracking
QuestManager handles choice consequences automatically via `choice_consequences` field.

### Faction Integration
All quests contribute to `church_of_morthane` faction. Quest 10 completion should trigger special acknowledgment from ALL temple priests (Chronos, Gaela).

---

## Dialogue Integration

### Priest of Morthane Starting Dialogue
Should offer Quest 1 when player first visits temple.

### After Becoming Devotee
Priest dialogue should change to acknowledge player's status.
Repeatable quest should become available.

### After Becoming Champion
Priest should address player as "Champion" or "Deathwalker".
All temple priests should have special dialogue for Morthane champions.

### Other Gods' Priests
If player is Morthane devotee/champion, other priests (Chronos, Gaela) should acknowledge this in dialogue but NOT lock out their quests.

---

## Testing Checklist

- [ ] All 11 quest files load without errors
- [ ] Quest chain auto-advances through `next_quest` links
- [ ] Devotee flag gates Quests 6-10 properly
- [ ] Choice consequences apply correctly
- [ ] Faction reputation accumulates
- [ ] Spawn-on-accept creates quest items
- [ ] All NPCs exist and are interactable
- [ ] All enemies exist with correct IDs
- [ ] All items exist in item database
- [ ] All interactable markers placed in levels
- [ ] Repeatable quest has 7-day cooldown
- [ ] Champion title displays in UI

---

## Lore & Philosophy

**Morthane is NOT evil.** The deity represents the natural cycle of life and death.

**Core Beliefs:**
- Death is not an end, but a transition
- The cycle must be respected and honored
- Undeath (zombies, skeletons, liches) is an abomination that corrupts the natural order
- Necromancy for undeath purposes is a perversion
- The Rebirth Ritual is a sacred exception - willing transformation to serve the cycle

**Devotees are:**
- Undead hunters who understand mortality
- Guardians of burial grounds
- Speakers for the dead
- Champions against corruption of the cycle

**Morthane's Two Aspects:**
- Death: The ending, the reaper, the natural conclusion
- Rebirth: The beginning, the cycle renewed, transformation

This makes Morthane devotees philosophical undead slayers, NOT dark cultists.
