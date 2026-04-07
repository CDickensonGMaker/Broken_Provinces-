# Morthane Quest Chain - Quick Reference Table

## Quest Chain Summary

| # | Quest ID | Title | Tier | Level | Gold | XP | Key Reward | Prerequisites |
|---|----------|-------|------|-------|------|-----|------------|---------------|
| 1 | `morthane_01_last_rites` | Final Rest | Initiate | 5-10 | 50 | 200 | Burial Incense | None |
| 2 | `morthane_02_restless_spirit` | Unfinished Business | Initiate | 5-10 | 75 | 300 | Ghost-touched Trinket | Quest 1 |
| 3 | `morthane_03_cemetery_duty` | Vigil of the Dead | Initiate | 5-10 | 100 | 400 | Grave Warden Blessing | Quest 2 |
| 4 | `morthane_04_necromancer_trail` | The Defiler's Path | Acolyte | 10-15 | 150 | 500 | Death Warden Cloak | Quest 3 |
| 5 | `morthane_05_devotion_choice` | Embracing the Cycle ⭐ | Acolyte | 10-15 | 200 | 600 | Morthane's Amulet | Quest 4 |
| 6 | `morthane_06_death_speaker` | Voices Beyond the Veil | Devotee | 15-25 | 250 | 750 | Speak with Dead Scrolls | Quest 5 + devotee flag |
| 7 | `morthane_07_lich_rumor` | Whispers of Immortality | Devotee | 15-25 | 300 | 900 | Anti-undead Longsword | Quest 6 |
| 8 | `morthane_08_rebirth_ritual` | The Second Chance | Devotee | 15-25 | 350 | 1000 | Cycle's Wisdom Ring | Quest 7 |
| 9 | `morthane_09_undead_army` | The Rising Tide | Champion | 25-35 | 500 | 1500 | Reaper's Blade | Quest 8 |
| 10 | `morthane_10_deathwalker` | The Deathwalker ⭐⭐ | Champion | 25-35 | 750 | 2000 | Morthane's Shroud | Quest 9 |
| 11 | `morthane_repeatable_cleansing` | Cleansing Duty | Repeatable | 10+ | 100 | 300 | None | Quest 5 + devotee flag |

**Total Rewards:** 2,925 gold, 10,250 XP (not including repeatable)

---

## Quest Objectives by Type

### Kill Objectives

| Quest | Target Enemy | Count | Location |
|-------|--------------|-------|----------|
| 3 | `human_bandit` | 4 | Thornfield |
| 3 | `skeleton_warrior` | 6 | Thornfield |
| 4 | `skeleton_warrior` | 8 | Willow Dale |
| 7 | `skeleton_shade` | 6 | Willow Dale |
| 7 | `lich_aspirant_valdris` | 1 | Willow Dale (boss) |
| 9 | `skeleton_warrior` | 12 | Crossroads |
| 9 | `skeleton_shade` | 8 | Thornfield |
| 9 | `death_knight_commander` | 1 | Bandit Hideout (boss) |
| 10 | `skeleton_shade` | 15 | Kazer-Dun Entrance |
| 10 | `undead_lord_malthor` | 1 | Kazer-Dun Entrance (final boss) |
| 11 | `skeleton_warrior` | 10 | Any (repeatable) |

### Collect Objectives

| Quest | Item | Count | Source |
|-------|------|-------|--------|
| 2 | `ghost_locket` | 1 | Chest in Dalhurst (spawned on accept) |
| 4 | `necromancer_journal` | 1 | Chest in Willow Dale (spawned on accept) |
| 7 | `phylactery_research` | 1 | Chest in Willow Dale (spawned on accept) |
| 8 | `rebirth_ritual_components` | 3 | Chest in Crossroads (spawned on accept) |

### Talk Objectives

| Quest | Target NPC | Location |
|-------|------------|----------|
| 2 | `innkeeper_dalhurst` | Dalhurst |
| 4 | `necromancer_aeris` | Willow Dale |
| 6 | `guard_captain_millbrook` | Millbrook |
| 6 | `merchant_vrell` | Millbrook |
| 8 | `merchant_elara` | Crossroads |

All quests have "Return to Priest" talk objective at end.

### Reach Objectives

| Quest | Target Location | Zone ID |
|-------|----------------|---------|
| 1 | Crossroads | `crossroads` |
| 2 | Dalhurst | `dalhurst` |
| 3 | Thornfield | `thornfield` |
| 4 | Willow Dale | `willow_dale` |
| 6 | Millbrook | `millbrook` |
| 8 | Crossroads | `crossroads` |
| 9 | Bandit Hideout | `bandit_hideout` |
| 10 | Kazer-Dun Entrance | `kazer_dun_entrance` |

### Interact Objectives

| Quest | Target Marker | Count | Purpose |
|-------|--------------|-------|---------|
| 1 | `burial_site_marker` | 3 | Perform burial rites |
| 2 | `ghost_grave_marker` | 1 | Place locket at grave |
| 3 | `desecrated_grave_marker` | 3 | Purify graves with holy water |
| 5 | `shrine_of_endings` | 1 | Meditate on death |
| 5 | `mortality_trial_altar` | 1 | Undergo trial |
| 6 | `murder_victim_corpse` | 1 | Use Speak with Dead |
| 7 | `lich_transformation_altar` | 1 | Stop ritual |
| 8 | `rebirth_ritual_circle` | 1 | Prepare ritual circle |
| 8 | `rebirth_ritual_altar` | 1 | Witness rebirth |
| 9 | `corruption_nexus` | 1 | Find corruption source |
| 9 | `corruption_nexus_purified` | 1 | Purify with sacred flame |
| 10 | `shrine_of_endings_champion` | 1 | Prepare for champion trial |
| 10 | `death_walk_altar` | 1 | Undergo Death Walk ritual |
| 10 | `morthane_champion_altar` | 1 | Claim champion blessing |

---

## Required NPCs

### Quest Givers / Turn-in
- `priest_morthane_elder_moor` - Main quest giver (ALL quests)

### Supporting NPCs
- `innkeeper_dalhurst` - Quest 2
- `guard_captain_millbrook` - Quest 6
- `merchant_vrell` - Quest 6 (killer)
- `merchant_elara` - Quest 8 (dying merchant)

### Enemy NPCs (Dialogue-enabled)
- `necromancer_aeris` - Quest 4 (can talk before combat)

### Boss Enemies
- `lich_aspirant_valdris` - Quest 7 boss
- `death_knight_commander` - Quest 9 boss
- `undead_lord_malthor` - Quest 10 final boss

---

## Required Items

### Starter Items (Given at Quest Start)

| Item | Quest | Quantity | Use |
|------|-------|----------|-----|
| `burial_incense` | 1 | 3 | Perform burial rites |
| `holy_water` | 3 | 3 | Purify graves |
| `morthane_sacred_flame` | 9 | 1 | Purify corruption nexus |

### Quest Items (Collected)

| Item | Quest | Found In |
|------|-------|----------|
| `ghost_locket` | 2 | Dalhurst chest |
| `necromancer_journal` | 4 | Willow Dale chest |
| `phylactery_research` | 7 | Willow Dale chest |
| `deaths_lily` | 8 | Crossroads chest |
| `grave_soil` | 8 | Crossroads chest |
| `rebirth_incense` | 8 | Crossroads chest |

### Reward Items

| Item | Quest | Type | Effect |
|------|-------|------|--------|
| `ghost_touched_trinket` | 2 | Trinket | Detect undead? |
| `grave_warden_blessing` | 3 | Consumable | Buff vs undead |
| `death_warden_cloak` | 4 | Armor | Resist death/necrotic |
| `morthane_amulet` | 5 | Amulet | +Intuition or resist undead |
| `speak_with_dead_scroll` | 6 | Consumable (x3) | Talk to corpses |
| `anti_undead_longsword` | 7 | Weapon | Bonus damage vs undead |
| `cycle_wisdom_ring` | 8 | Ring | Death resistance |
| `reapers_blade` | 9 | Weapon | Lifesteal on kill |
| `morthane_shroud` | 10 | Legendary Armor | Champion cloak |

---

## Flags and Choices

### Progression Flags

| Flag | Set By | Effect |
|------|--------|--------|
| `morthane_devotee` | Quest 5 (accept choice) | Unlocks Quests 6-10 |
| `morthane_devotion_declined` | Quest 5 (decline choice) | Ends quest chain |
| `morthane_champion` | Quest 10 (completion) | Champion status |
| `deathwalker_title` | Quest 10 (completion) | Title display |

### Choice Outcome Flags

| Flag | Quest | Choice | Rep Change |
|------|-------|--------|------------|
| `necromancer_aeris_killed` | 4 | Kill | +10 Morthane |
| `necromancer_aeris_redeemed` | 4 | Redeem | +5 Morthane, +10 Mages Guild |
| `necromancer_aeris_freed` | 4 | Spare | Spawns enemy |
| `merchant_vrell_arrested` | 6 | Arrest | +15 Guard |
| `merchant_vrell_executed` | 6 | Execute | +10 Morthane |

---

## Faction Reputation Breakdown

### Base Reputation (No Choices)

| Quest | Morthane | Church of Three | Other |
|-------|----------|-----------------|-------|
| 1 | +10 | +5 | - |
| 2 | +15 | +8 | - |
| 3 | +20 | +10 | - |
| 4 | +25 | +12 | +5/+10 Mages (choice) |
| 5 | +40 (+30 if accept) | +15 | - |
| 6 | +35 | - | +20 Guard (base), +15 (choice) |
| 7 | +40 | +20 | - |
| 8 | +45 | +22 | - |
| 9 | +60 | +30 | +25 Guard |
| 10 | +100 (+50 if champion) | +50 | - |
| 11 | +10 | +5 | - |

**Total (with all bonuses):** 370+ Morthane, 187 Church of Three

---

## Geographic Distribution

### Quests by Location

**Elder Moor (Temple Hub):** All quests start/end here

**Crossroads:**
- Quest 1 (burial rites)
- Quest 8 (dying merchant)
- Quest 9 (defend from undead)

**Dalhurst:**
- Quest 2 (ghost investigation)

**Thornfield:**
- Quest 3 (cemetery defense)
- Quest 9 (defend from undead)

**Millbrook:**
- Quest 6 (murder investigation)

**Willow Dale (Dungeon):**
- Quest 4 (necromancer)
- Quest 7 (lich aspirant)

**Bandit Hideout (Dungeon):**
- Quest 9 (corruption source, final battle)

**Kazer-Dun Entrance (Dungeon):**
- Quest 10 (final quest, champion trial)

---

## Combat Encounters

### Enemy Counts by Quest

| Quest | Combat Difficulty |
|-------|-------------------|
| 1 | None (ritual quest) |
| 2 | None (investigation) |
| 3 | Medium (10 enemies) |
| 4 | Medium (8 enemies + boss) |
| 5 | None (trial/ritual) |
| 6 | None/Light (optional combat) |
| 7 | Hard (6 elite + boss) |
| 8 | None (ritual quest) |
| 9 | Very Hard (20+ enemies + boss) |
| 10 | Epic (15+ elite + final boss) |
| 11 | Medium (10 enemies) |

---

## Quest Chain Summary

**Total Quests:** 11 (10 main + 1 repeatable)

**Critical Decision Points:**
- Quest 4: Necromancer fate (3 choices)
- Quest 5: Accept/decline devotion (2 choices, gates rest of chain)
- Quest 6: Killer's fate (2 choices)

**Tiers:**
- Initiate: Quests 1-3 (introduction)
- Acolyte: Quests 4-5 (devotion choice)
- Devotee: Quests 6-8 (advanced training)
- Champion: Quests 9-10 (epic finale)
- Repeatable: Quest 11 (ongoing duty)

**Estimated Playtime:** 6-10 hours (all quests)

**Faction:** `church_of_morthane`

**Philosophy:** Death is natural, undeath is corruption. Devotees are undead hunters who understand mortality.
