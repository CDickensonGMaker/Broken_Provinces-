# Gaela Quest Chain - File Index

**Location:** `C:\Users\caleb\CatacombsOfGore\data\quests\temple\gaela\`

**Created:** 2026-04-06
**Total Files:** 17

---

## Quest JSON Files (13 total)

### Main Quest Chain (10 files)
1. `gaela_01_first_offering.json` - Seeds of Faith (Tier 1)
2. `gaela_02_healing_herbs.json` - The Healer's Garden (Tier 1)
3. `gaela_03_protect_harvest.json` - Guardians of the Field (Tier 1)
4. `gaela_04_sacred_grove.json` - The Sacred Grove (Tier 2, choice-based)
5. `gaela_05_devotion_choice.json` - The Mother's Embrace (Tier 2, DEVOTION CHOICE)
6. `gaela_06_blight_source.json` - Root of Corruption (Tier 3, devotee-only)
7. `gaela_07_spirit_of_land.json` - Voice of the Green (Tier 3, devotee-only)
8. `gaela_08_seed_of_life.json` - The Eternal Seed (Tier 3, devotee-only)
9. `gaela_09_famine_threat.json` - When Harvests Fail (Tier 4, devotee-only)
10. `gaela_10_lifebringer.json` - The Lifebringer (Tier 4, devotee-only, CHAMPION QUEST)

### Bonus & Repeatable Quests (3 files)
11. `gaela_bonus_bountiful_harvest.json` - Bountiful Harvest (devotee-only)
12. `gaela_bonus_shepherd_quest.json` - The Lost Flock (after Quest 3)
13. `gaela_repeatable_tending.json` - Tending the Garden (weekly repeatable, devotee-only)

---

## Documentation Files (4 total)

### Primary Documentation
- **README.md** (12 KB)
  - Full quest chain documentation
  - Detailed quest descriptions
  - Progression tables
  - Faction system
  - Devotee system explanation
  - Implementation requirements

### Quick Reference
- **QUEST_SUMMARY.txt** (5.9 KB)
  - At-a-glance quest list
  - Reward totals
  - Progression path
  - Required NPCs
  - File listing

### Implementation Guide
- **IMPLEMENTATION_CHECKLIST.md** (11 KB)
  - 10-phase implementation checklist
  - NPC requirements (4 to create)
  - Enemy verification (6 types)
  - Item requirements (30+ items)
  - Faction setup
  - Dialogue integration
  - Testing procedures
  - Estimated time: 21-26 hours

### Narrative Guide
- **LORE_AND_THEMES.md** (14 KB)
  - Gaela's divine portfolio
  - Priestess Elara character profile
  - Thematic progression analysis
  - Tier-by-tier narrative arcs
  - Symbolism and motifs
  - Voice and tone guidelines
  - Future expansion hooks

### This Index
- **INDEX.md** (this file)

---

## File Size Summary

| File Type | Count | Total Size |
|-----------|-------|------------|
| Quest JSON files | 13 | ~25 KB |
| Documentation (MD/TXT) | 4 | ~43 KB |
| **TOTAL** | **17** | **~68 KB** |

---

## Quick Start Guide

### For Quest Designers
1. Read **QUEST_SUMMARY.txt** for overview
2. Read **README.md** for detailed mechanics
3. Reference **LORE_AND_THEMES.md** for narrative guidance

### For Implementers
1. Read **IMPLEMENTATION_CHECKLIST.md** first
2. Create required NPCs (Phase 1)
3. Verify enemies exist (Phase 2)
4. Create items (Phase 3)
5. Follow checklist phases 4-10

### For Writers/Dialogue Creators
1. Read **LORE_AND_THEMES.md** for Priestess Elara's voice
2. Reference thematic progression for each tier
3. Use README.md for specific quest dialogue needs

### For Testers
1. Reference **QUEST_SUMMARY.txt** for expected progression
2. Use **IMPLEMENTATION_CHECKLIST.md** Phase 9 for test cases
3. Verify all flags and choices work correctly

---

## Integration Points

### Quest System
- Load all 13 JSON files into `QuestManager`
- Verify `next_quest` auto-progression works
- Test `required_flags` and `prerequisites` systems
- Test `choice_consequences` for Quests 4, 5, 10

### Dialogue System
- Create Priestess Elara dialogue tree with 10+ quest offer nodes
- Implement devotion choice dialogue (Quest 5)
- Create NPC dialogues for 4 new NPCs
- Add acknowledgment dialogue to other temple priests

### Item System
- Create 16 reward items
- Create 14 collectible/quest items
- Create 1 crafting recipe
- Verify all items can be received and used

### Faction System
- Verify `church_of_gaela` faction exists
- Set up parent-child relationship with `church_of_three`
- Add 3 regional factions (millbrook_farmers, thornfield_citizens, dalhurst_merchants)

### Flag System
- Implement `gaela_devotee` flag (Quest 5)
- Implement `gaela_champion` flag (Quest 10)
- Implement `lifebringer_ritual_complete` flag (Quest 10)
- Implement Quest 4 choice flags (3 variants)

---

## Development Phases

### Phase A: Core Chain (Quests 1-5)
**Files:** gaela_01 through gaela_05
**Deliverable:** Fully playable Initiate + Acolyte tiers with devotion choice
**Dependencies:** 2 NPCs (millbrook_farmer, logging_foreman), basic items
**Estimated Time:** 8-10 hours

### Phase B: Devotee Content (Quests 6-8)
**Files:** gaela_06 through gaela_08
**Deliverable:** Devotee-exclusive mystical quests
**Dependencies:** thornfield_healer NPC, ancient_treant boss, mystical items
**Estimated Time:** 6-8 hours

### Phase C: Champion Finale (Quests 9-10)
**Files:** gaela_09, gaela_10
**Deliverable:** Epic conclusion with Champion title
**Dependencies:** dark_ritualist boss, ritual items, champion gear
**Estimated Time:** 5-6 hours

### Phase D: Bonus Content (Quests 11-13)
**Files:** gaela_bonus_*, gaela_repeatable_*
**Deliverable:** Optional side content and repeatable
**Dependencies:** millbrook_shepherd NPC, cooldown system test
**Estimated Time:** 2-3 hours

---

## Testing Checklist

- [ ] Full playthrough (Quests 1-10) without errors
- [ ] Test devotion acceptance path
- [ ] Test devotion decline path (chain should end gracefully)
- [ ] Test all 3 Quest 4 choice outcomes
- [ ] Test repeatable quest cooldown (7 days)
- [ ] Test bonus quests
- [ ] Verify all items are receivable
- [ ] Verify all NPCs exist and dialogue works
- [ ] Test save/load preserves quest states
- [ ] Test faction reputation changes apply
- [ ] Test flags set correctly

---

## Known Dependencies

### Must Exist Before Activation
- `priest_gaela_dalhurst` NPC (EXISTS - verified)
- QuestManager support for `required_flags`
- QuestManager support for `choice_consequences`
- FactionManager with `church_of_gaela` faction
- Repeatable quest cooldown system

### Must Create Before Activation
- 4 new NPCs (farmers, foreman, healer, shepherd)
- 30+ items (rewards, collectibles, ritual components)
- 6 enemy types verification
- Dialogue trees for all quest nodes

---

## Maintenance Notes

### Future Updates
- If adding new Gaela quests, insert between existing tiers or after Quest 10
- Maintain devotee flag requirement for advanced content
- Keep geographic limits (no quests south of Kazer-Dun)
- Maintain escalating reward structure

### Balancing
- If adjusting rewards, maintain tier progression (Tier 1 < Tier 2 < Tier 3 < Tier 4)
- Gold range: 50-750g
- XP range: 200-2000 XP
- Faction reputation: 10-100 per quest

---

**End of Index**
