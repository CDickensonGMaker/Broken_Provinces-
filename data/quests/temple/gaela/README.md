# Gaela Quest Chain - Temple of Three Gods

**Goddess:** Gaela, Goddess of Harvest
**Themes:** Growth, nature, healing, agriculture, life, community
**Quest Giver:** Priestess Elara (priest_gaela_dalhurst) in Dalhurst Temple
**Total Quests:** 13 (10 main chain + 3 bonus/repeatable)

---

## Quest Chain Structure

### Tier 1: Initiate (Quests 1-3)
Low rewards, introductory quests to establish Gaela's domains.

**1. Seeds of Faith** (`gaela_01_first_offering.json`)
- Bring offering to shrine, help struggling farmer
- Rewards: 50g, 200 XP, 2x Minor Healing Herbs
- Faction: +10 church_of_gaela, +5 church_of_three

**2. The Healer's Garden** (`gaela_02_healing_herbs.json`)
- Gather medicinal herbs from 3 locations
- Rewards: 75g, 300 XP, Healing Poultice Recipe, 3x Minor Healing Herbs
- Faction: +15 church_of_gaela, +10 church_of_three

**3. Guardians of the Field** (`gaela_03_protect_harvest.json`)
- Protect Millbrook farms from dire wolves and giant rats
- Rewards: 100g, 400 XP, Farmer's Blessing Charm
- Faction: +20 church_of_gaela, +15 church_of_three, +25 millbrook_farmers

---

### Tier 2: Acolyte (Quests 4-5)
Medium rewards, moral choices, and the devotion commitment.

**4. The Sacred Grove** (`gaela_04_sacred_grove.json`)
- Negotiate between nature preservation and economic needs
- **Choice-based outcomes:**
  - **Protect Grove Fully:** +30 church_of_gaela, -10 dalhurst_merchants
  - **Allow Limited Logging:** +20 church_of_gaela, +10 dalhurst_merchants
  - **Find Alternative:** +25 church_of_gaela, +15 dalhurst_merchants
- Rewards: 150g, 500 XP, Nature's Bond Ring
- Faction: Base +25 church_of_gaela, +20 church_of_three

**5. The Mother's Embrace** (`gaela_05_devotion_choice.json`)
- **DEVOTION CHOICE:** Become a Devotee of Gaela or decline
- Sets flag: `gaela_devotee` (required for quests 6-10)
- Rewards: 200g, 600 XP, Gaela's Amulet
- Faction: +30 church_of_gaela, +25 church_of_three

---

### Tier 3: Devotee Exclusive (Quests 6-8)
**Prerequisite:** `gaela_devotee` flag must be set
Higher rewards, deeper story, nature magic themes.

**6. Root of Corruption** (`gaela_06_blight_source.json`)
- Investigate and stop blight spreading from Willow Dale
- Kill dark cultists, retrieve corrupted artifact
- Rewards: 250g, 750 XP, Purifying Charm, 2x Nature's Vigor Potion
- Faction: +40 church_of_gaela, +30 church_of_three

**7. Voice of the Green** (`gaela_07_spirit_of_land.json`)
- Free trapped land spirit near Crossroads
- Commune with nature spirits
- Rewards: 300g, 900 XP, Nature's Whisper Charm
- Faction: +45 church_of_gaela, +35 church_of_three

**8. The Eternal Seed** (`gaela_08_seed_of_life.json`)
- Retrieve legendary Seed of Life to cure plague in Thornfield
- Defeat Ancient Treant guardian
- Rewards: 350g, 1000 XP, Seed of Renewal, 3x Major Healing Herbs
- Faction: +50 church_of_gaela, +40 church_of_three, +50 thornfield_citizens

---

### Tier 4: Champion (Quests 9-10)
**Prerequisite:** `gaela_devotee` flag must be set
Best rewards, climactic multi-location quests.

**9. When Harvests Fail** (`gaela_09_famine_threat.json`)
- Stop regional famine caused by dark magic
- Investigate Elder Moor, Millbrook, Thornfield
- Defeat Dark Ritualist and destroy cursed totem
- Rewards: 500g, 1500 XP, Cornucopia Charm, 2x Gaela's Blessing Scroll
- Faction: +60 church_of_gaela, +50 church_of_three, +40 to 3 regional factions

**10. The Lifebringer** (`gaela_10_lifebringer.json`)
- **FINAL QUEST:** Become Gaela's Champion
- Perform ritual to restore corrupted lands
- Sets flags: `gaela_champion`, `lifebringer_ritual_complete`
- Rewards: 750g, 2000 XP, Gaela's Verdant Robes, Champion's Laurel, Eternal Harvest Ring
- Faction: +100 church_of_gaela, +75 church_of_three

---

## Bonus & Repeatable Quests

**Bountiful Harvest** (`gaela_bonus_bountiful_harvest.json`)
- Gather harvest festival produce from across the valley
- Prerequisite: `gaela_devotee`
- Rewards: 400g, 1200 XP, Harvest Festival Crown, 2x Gaela's Bounty Potion
- Faction: +50 church_of_gaela, +35 church_of_three, +25 millbrook_farmers, +25 thornfield_citizens

**The Lost Flock** (`gaela_bonus_shepherd_quest.json`)
- Rescue shepherd's flock from dire wolves
- Escort mission near Willow Dale
- Prerequisite: Quest 3 complete
- Rewards: 150g, 600 XP, Wool Cloak, Shepherd's Crook
- Faction: +20 church_of_gaela, +35 millbrook_farmers

**Tending the Garden** (REPEATABLE) (`gaela_repeatable_tending.json`)
- Weekly repeatable quest to maintain temple gardens
- Prerequisite: `gaela_devotee`
- Cooldown: 7 days
- Rewards: 25g, 100 XP, Minor Healing Herb, Wildflower
- Faction: +5 church_of_gaela, +2 church_of_three

---

## Geographic Limitations

**CRITICAL:** All quests restricted to northern regions:
- Elder Moor
- Dalhurst
- Thornfield
- Millbrook
- Crossroads
- Willow Dale
- Bandit Hideout
- Kazer-Dun Entrance (not beyond)

**DO NOT send players south of Kazer-Dun.**

---

## Required NPCs

These NPCs must exist and be spawned in their respective zones:

| NPC ID | Location | Purpose |
|--------|----------|---------|
| `priest_gaela_dalhurst` | dalhurst | Main quest giver/receiver |
| `millbrook_farmer` | millbrook | Quest 1 & 3 target |
| `logging_foreman_elder_moor` | elder_moor | Quest 4 target |
| `thornfield_healer` | thornfield | Quest 8 target |
| `millbrook_shepherd` | millbrook | Bonus quest giver |

---

## Faction System

**Primary Faction:** `church_of_gaela` (sub-faction of `church_of_three`)

**Reputation Thresholds:**
- 0-50: Initiate
- 51-150: Acolyte
- 151-300: Devotee (requires flag)
- 301+: Champion (requires flag)

**Cross-faction Effects:**
- Other temple priests acknowledge Gaela devotion with unique dialogue
- Does NOT lock out Chronos or Morthane quests
- High Gaela reputation grants slight bonuses to nature/healing skill checks

---

## Devotee System

**Trigger:** Quest 5 (`gaela_05_devotion_choice`)

**Effects of becoming a Devotee:**
1. Sets flag: `gaela_devotee`
2. Unlocks quests 6-10 (exclusive content)
3. Unlocks repeatable quest
4. NPCs acknowledge devotion in dialogue
5. Temple priests of other gods give different greetings

**Player can still:**
- Accept quests from Chronos and Morthane priests
- Complete quests for other factions
- Worship at other shrines

**Devotion is NOT exclusive** - it's a dedication, not a hard lock.

---

## Progression Summary

| Quest Tier | Quests | Total Gold | Total XP | Reputation Gain |
|------------|--------|------------|----------|-----------------|
| Tier 1 (Initiate) | 1-3 | 225g | 900 XP | +45 Gaela |
| Tier 2 (Acolyte) | 4-5 | 350g | 1100 XP | +55 Gaela |
| Tier 3 (Devotee) | 6-8 | 900g | 2650 XP | +135 Gaela |
| Tier 4 (Champion) | 9-10 | 1250g | 3500 XP | +160 Gaela |
| **TOTAL (Main Chain)** | **10** | **2725g** | **8150 XP** | **+395 Gaela** |

**Bonus/Repeatable:**
- Bountiful Harvest: 400g, 1200 XP, +50 Gaela
- Lost Flock: 150g, 600 XP, +20 Gaela
- Tending Garden (weekly): 25g, 100 XP, +5 Gaela

---

## Implementation Checklist

### Required Items (to create)
- [ ] `farmers_blessing_charm` - Food heals more
- [ ] `natures_bond_ring` - Nature affinity bonus
- [ ] `gaelas_amulet` - Devotee marker item
- [ ] `purifying_charm` - Removes corruption
- [ ] `natures_whisper_charm` - Detect plants/animals
- [ ] `seed_of_renewal` - Powerful healing consumable
- [ ] `cornucopia_charm` - Food never spoils
- [ ] `gaelas_verdant_robes` - Champion armor
- [ ] `champions_laurel` - Title item
- [ ] `eternal_harvest_ring` - Champion ring
- [ ] `harvest_festival_crown` - Cosmetic reward
- [ ] `gaelas_bounty_potion` - Powerful buff
- [ ] `natures_vigor_potion` - Stamina regen buff
- [ ] `gaelas_blessing_scroll` - Consumable blessing

### Required Enemies (verify exist)
- [ ] `dire_wolf` - Common threat
- [ ] `giant_rat` - Pest enemy
- [ ] `dark_cultist` - Main antagonist type
- [ ] `ancient_treant` - Boss guardian
- [ ] `dark_ritualist` - Boss cultist
- [ ] `corrupted_beast` - Blight-corrupted enemies

### Required Collectibles (to create)
- [ ] `wildflower` - Common offering
- [ ] `moonleaf` - Medicinal herb
- [ ] `silvervine` - Medicinal herb
- [ ] `sunroot` - Medicinal herb
- [ ] `corrupted_stone` - Quest item
- [ ] `cursed_famine_totem` - Quest item
- [ ] `sacred_soil` - Ritual component
- [ ] `moonwater` - Ritual component
- [ ] `ancient_lifeseed` - Ritual component
- [ ] `fresh_wheat` - Harvest item
- [ ] `autumn_apple` - Harvest item
- [ ] `great_pumpkin` - Harvest item
- [ ] `wild_honey` - Harvest item

### Required Locations (verify exist)
- [x] `elder_moor` - Starting area
- [x] `dalhurst` - Temple location
- [x] `thornfield` - Eastern town
- [x] `millbrook` - Southern town
- [x] `crossroads` - Central landmark
- [x] `willow_dale` - Dungeon
- [x] `bandit_hideout` - Dungeon

### Required NPCs (to verify/create)
- [x] `priest_gaela_dalhurst` - EXISTS (verified in blueprints)
- [ ] `millbrook_farmer` - CREATE
- [ ] `logging_foreman_elder_moor` - CREATE
- [ ] `thornfield_healer` - CREATE
- [ ] `millbrook_shepherd` - CREATE

---

## Quest Flow Diagram

```
Start: Talk to Priestess Elara in Dalhurst Temple
  ↓
[1] Seeds of Faith
  ↓
[2] The Healer's Garden
  ↓
[3] Guardians of the Field
  ↓
[4] The Sacred Grove (choice-based)
  ↓
[5] The Mother's Embrace (DEVOTION CHOICE)
  ↓
  ├── Accept Devotion → Set flag `gaela_devotee`
  │   ↓
  │   [6] Root of Corruption
  │   ↓
  │   [7] Voice of the Green
  │   ↓
  │   [8] The Eternal Seed
  │   ↓
  │   [9] When Harvests Fail
  │   ↓
  │   [10] The Lifebringer (CHAMPION) → Set flag `gaela_champion`
  │
  └── Decline Devotion → Set flag `gaela_devotion_declined`
      (Quest chain ends)

Side Branches (if devotee):
- Bountiful Harvest (bonus quest)
- Tending the Garden (repeatable weekly)

Other:
- The Lost Flock (after Quest 3, not devotee-locked)
```

---

## Notes for Developers

1. **Faction IDs:** Ensure `church_of_gaela` exists as a sub-faction of `church_of_three`
2. **Flag System:** Quest 5 sets the critical `gaela_devotee` flag that gates quests 6-10
3. **Choice Consequences:** Quest 4 and Quest 10 use `choice_consequences` system
4. **Repeatable Quest:** Quest `gaela_repeatable_tending` uses `cooldown_days: 7`
5. **Escalating Difficulty:** Enemy counts and boss encounters increase with tier
6. **Cross-Regional:** Quests span multiple towns to encourage exploration
7. **Lore Integration:** References the Three Gods pantheon, maintains world consistency

---

## Dialogue Hooks

Priestess Elara should have dialogue nodes for:
- Initial greeting (no quests started)
- Quest 1 offer (Seeds of Faith)
- Quest 2-4 progression
- **Quest 5 CRITICAL:** Devotion choice dialogue with branching outcomes
- Quest 6-10 progression (devotee-only)
- Repeatable quest offer (devotee-only, weekly cooldown check)
- Completion celebration for Champion title

Other priests (Chronos, Morthane) should acknowledge if player has `gaela_devotee` flag:
- "The Harvest Mother's blessing upon you, Devotee."
- "I see Gaela has claimed your heart. Her path is not mine, but I respect your choice."

---

**Created:** 2026-04-06
**Author:** Claude (Dialogue-Quest-Master Agent)
**Version:** 1.0
