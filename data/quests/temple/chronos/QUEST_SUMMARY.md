# Chronos Quest Chain - Quick Reference

## Quest Chain Overview
10 main quests + 1 repeatable | Total: 2,775 gold, 8,350 XP | 315+ church_of_chronos rep

---

## Quest Flow

```
1. The First Vision (50g, 200 XP)
   ↓
2. Sands of Service (75g, 300 XP)
   ↓
3. Time-Sensitive (100g, 400 XP)
   ↓
4. The False Seer (150g, 500 XP) - CHOICE: Expose or Accept
   ↓
5. The Timekeeper's Question (200g, 600 XP) ⭐ CRITICAL: Accept/Decline Devotion
   ↓
   [Requires chronos_devotee flag]
   ↓
6. Echoes of What Was (250g, 750 XP) - Combat + Puzzle + Lore
   ↓
7. The Paradox Stone (300g, 900 XP) - CHOICE: Destroy or Harness
   ↓
8. Glimpses of Tomorrow (350g, 1000 XP) - Training Montage
   ↓
9. When Time Bleeds (500g, 1500 XP) - Multi-stage Epic
   ↓
10. The Eternal Vigil (750g, 2000 XP) ⭐ FINAL BOSS + Champion Title

11. Seeking Visions (25g, 100 XP) - Repeatable (7-day cooldown)
```

---

## Quick Quest Lookup

| # | Title | Type | Location(s) | Rewards |
|---|-------|------|------------|---------|
| 1 | First Vision | Fetch | Crossroads | 50g, 200 XP, token |
| 2 | Sands of Service | Collection | Elder Moor, Thornfield, Willow Dale | 75g, 300 XP, hourglass |
| 3 | Time-Sensitive | Delivery | Dalhurst → Thornfield | 100g, 400 XP |
| 4 | False Seer | Investigation | Millbrook | 150g, 500 XP, pendant, **CHOICE** |
| 5 | Timekeeper's Question | Ritual | Dalhurst | 200g, 600 XP, amulet, **SOFT LOCK** |
| 6 | Echoes of What Was | Combat/Puzzle | Willow Dale | 250g, 750 XP, time blade |
| 7 | Paradox Stone | Puzzle/Choice | Crossroads | 300g, 900 XP, **CHOICE: blessing or talisman** |
| 8 | Glimpses of Tomorrow | Training | Elder Moor, Thornfield, Crossroads | 350g, 1000 XP, circlet |
| 9 | When Time Bleeds | Epic Multi-stage | Bandit Hideout | 500g, 1500 XP, legendary aegis |
| 10 | Eternal Vigil | Final Boss | Kazer-Dun | 750g, 2000 XP, **CHAMPION TITLE** |
| 11 | Seeking Visions | Repeatable | Dalhurst | 25g, 100 XP, blessing |

---

## Critical Flags

| Flag | Set By | Effect |
|------|--------|--------|
| `chronos_devotee` | Quest 5 (accept) | Unlocks quests 6-10+ |
| `chronos_path_declined` | Quest 5 (decline) | Ends quest chain |
| `millbrook_seer_exposed` | Quest 4 (expose) | +10 church_of_chronos |
| `millbrook_seer_genuine` | Quest 4 (accept) | +5 chronos, +10 common_folk |
| `paradox_stone_destroyed` | Quest 7 (destroy) | +20 chronos, major blessing |
| `paradox_stone_harnessed` | Quest 7 (harness) | +10 chronos, talisman |

---

## Required NPCs

- `priest_chronos_dalhurst` - Main quest giver (Dalhurst Temple)
- `high_chronist_thornfield` - Quest 3 receiver (Thornfield)
- `false_prophet_millbrook` - Quest 4 investigation target (Millbrook)
- `temporal_echo_trigger` - Quest 6 vision object (Willow Dale)

---

## Required Enemies

| Enemy | Used In | Type |
|-------|---------|------|
| `temporal_guardian` | Quest 6 | Spectral humanoid (3x) |
| `time_aberration` | Quest 9 | Twisted creatures (5x) |
| `temporal_rift_guardian` | Quest 9 | Boss |
| `corrupted_temporal_guardian` | Quest 10 | Enhanced spectral (6x) |
| `the_timeless_one` | Quest 10 | Epic boss |

---

## Unique Rewards

| Item | Quest | Type | Effect |
|------|-------|------|--------|
| Ceremonial Hourglass | 2 | Trinket | Keepsake |
| Truth Seeker's Pendant | 4 | Equipment | Investigation bonus |
| Chronos Amulet | 5 | Unique equipment | +Intuition, time effects |
| Time-Touched Blade | 6 | Unique weapon | Slow on hit |
| Chronos Blessing (Major) | 7 | Blessing | Major buff |
| Paradox Talisman | 7 | Talisman | Powerful but unstable |
| Prophet's Circlet | 8 | Unique headpiece | +Intuition, Prophet's Sight |
| Timekeeper's Aegis | 9 | Legendary armor/shield | Time-based protection |
| Eternal Hourglass Fragment | 10 | Legendary set piece | Champion set |
| Champion's Mantle | 10 | Unique cloak | Powerful abilities |

---

## Reputation Breakdown

### Total Possible (All Quests, Orthodox Path)
- **church_of_chronos:** 315
- **church_of_three:** 135

### By Quest
| Quest | church_of_chronos | church_of_three |
|-------|-------------------|-----------------|
| 1 | +10 | +5 |
| 2 | +15 | +5 |
| 3 | +20 | +10 |
| 4 | +25 | +10 |
| 5 | +50 | +15 |
| 6 | +30 | +10 |
| 7 | +35 | — |
| 8 | +40 | +15 |
| 9 | +50 | +20 |
| 10 | +100 | +50 |
| 11 | +5 (repeatable) | — |

---

## Tier Progression

### Tier 1: Initiate (1-3)
- **Level:** 5-10
- **Rewards:** 225g, 900 XP
- **Theme:** Introduction and service

### Tier 2: Acolyte (4-5)
- **Level:** 10-15
- **Rewards:** 350g, 1100 XP
- **Theme:** Testing and commitment

### Tier 3: Devotee (6-8)
- **Level:** 15-25
- **Rewards:** 900g, 2650 XP
- **Theme:** Mastery and power
- **Requires:** `chronos_devotee` flag

### Tier 4: Champion (9-10)
- **Level:** 25-35+
- **Rewards:** 1250g, 3500 XP
- **Theme:** Heroism and apotheosis
- **Requires:** `chronos_devotee` flag

---

## Key Design Points

1. **Quest 5 is the soft lock** - Accept devotion to continue, decline to end chain
2. **Devotion doesn't block other gods** - Can still worship Gaela and Morthane
3. **Multiple meaningful choices** - Quests 4, 5, and 7 have consequences
4. **Escalating difficulty** - Early quests are accessible, late quests are endgame
5. **Repeatable engagement** - Quest 11 provides ongoing content
6. **Epic payoff** - Quest 10 grants Champion title and legendary rewards

---

## Geographic Restrictions

**ALLOWED ZONES:**
- Elder Moor
- Dalhurst
- Thornfield
- Millbrook
- Crossroads
- Willow Dale
- Bandit Hideout
- Kazer-Dun Entrance

**DO NOT USE:**
- Anything south of Kazer-Dun
- Western coastal areas
- Eastern highlands beyond Thornfield

---

## Implementation Priority

### High Priority
1. Create Quest 5 dialogue (soft lock point)
2. Create False Prophet NPC (Quest 4)
3. Create Temporal Guardian enemy (Quest 6)
4. Verify priest_chronos_dalhurst spawns correctly

### Medium Priority
5. Create boss enemies (Quests 9, 10)
6. Create unique reward items
7. Write vision/cutscene dialogues

### Low Priority
8. Create repeatable quest mechanics
9. Polish visual effects for temporal abilities
10. Balance boss encounters

---

**Version:** 1.0
**Created:** 2026-04-06
**Status:** Design Complete
