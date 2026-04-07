# Gaela Quest Chain - Implementation Checklist

Use this checklist to ensure all dependencies are created before activating the quest chain.

---

## Phase 1: Core NPCs (CRITICAL - Must exist before quests work)

### Already Exists
- [x] `priest_gaela_dalhurst` - Located in Dalhurst Temple (verified in blueprints)

### Must Create
- [ ] **millbrook_farmer** (Millbrook)
  - Used in: Quest 1, Quest 3
  - Type: civilian
  - Archetype: farmer
  - Location: Millbrook farms area
  - Dialogue: Talks about crop struggles, thanks player for help

- [ ] **logging_foreman_elder_moor** (Elder Moor)
  - Used in: Quest 4
  - Type: civilian
  - Archetype: laborer/foreman
  - Location: Elder Moor logging camp
  - Dialogue: Needs to negotiate about Sacred Grove logging

- [ ] **thornfield_healer** (Thornfield)
  - Used in: Quest 8
  - Type: civilian
  - Archetype: priest/healer
  - Location: Thornfield temple or healer's hut
  - Dialogue: Receives Seed of Life to cure plague

- [ ] **millbrook_shepherd** (Millbrook)
  - Used in: Bonus quest
  - Type: civilian
  - Archetype: shepherd
  - Location: Millbrook outskirts
  - Dialogue: Lost flock quest giver

---

## Phase 2: Enemy Verification (Ensure enemies exist)

### Verify Exist
- [ ] `dire_wolf` - Used in Quest 3, Quest 9, Bonus quest
- [ ] `giant_rat` - Used in Quest 3
- [ ] `dark_cultist` - Used in Quest 6, Quest 7, Quest 9
- [ ] `ancient_treant` - Used in Quest 8 (boss)
- [ ] `dark_ritualist` - Used in Quest 9 (boss)
- [ ] `corrupted_beast` - Used in Quest 10

### If Missing, Create
- [ ] Create missing enemy .tres files in `data/enemies/`
- [ ] Add to zoo registry (`dev/zoo/zoo_registry.gd`)
- [ ] Add to WorldLexicon creature database

---

## Phase 3: Items & Collectibles

### Quest Reward Items (create in ItemData)
- [ ] `farmers_blessing_charm` - Food heals more (passive bonus)
- [ ] `natures_bond_ring` - Nature affinity bonus
- [ ] `gaelas_amulet` - Devotee marker item (worn in amulet slot)
- [ ] `purifying_charm` - Removes corruption effects
- [ ] `natures_whisper_charm` - Detect plants/animals (increased gather radius)
- [ ] `seed_of_renewal` - Powerful healing consumable (full HP + cure)
- [ ] `cornucopia_charm` - Food never spoils (passive inventory effect)
- [ ] `gaelas_verdant_robes` - Champion armor (chest piece, +nature resist)
- [ ] `champions_laurel` - Title/cosmetic headpiece
- [ ] `eternal_harvest_ring` - Champion ring (+harvest yield bonus)
- [ ] `harvest_festival_crown` - Cosmetic reward (headpiece)
- [ ] `gaelas_bounty_potion` - Powerful buff (HP regen + stamina regen)
- [ ] `natures_vigor_potion` - Stamina regen buff
- [ ] `gaelas_blessing_scroll` - Consumable blessing (temporary +growth bonus)
- [ ] `wool_cloak` - Shepherd quest reward (back slot, +cold resist)
- [ ] `shepherds_crook` - Shepherd quest reward (staff weapon)

### Quest Collectible Items
- [ ] `wildflower` - Common offering item
- [ ] `moonleaf` - Medicinal herb (gatherable in Elder Moor)
- [ ] `silvervine` - Medicinal herb (gatherable in Crossroads)
- [ ] `sunroot` - Medicinal herb (gatherable in Thornfield)
- [ ] `corrupted_stone` - Quest item (looted in Quest 6)
- [ ] `cursed_famine_totem` - Quest item (looted in Quest 9)
- [ ] `sacred_soil` - Ritual component (gathered in Quest 10)
- [ ] `moonwater` - Ritual component (gathered in Quest 10)
- [ ] `ancient_lifeseed` - Ritual component (gathered in Quest 10)
- [ ] `fresh_wheat` - Harvest item (Bonus quest)
- [ ] `autumn_apple` - Harvest item (Bonus quest)
- [ ] `great_pumpkin` - Harvest item (Bonus quest)
- [ ] `wild_honey` - Harvest item (Bonus quest, drop from giant bees)
- [ ] `rotting_vegetation` - Compost material (Repeatable quest)
- [ ] `weeds` - Weed removal (Repeatable quest)

### Recipes
- [ ] `healing_poultice_recipe` - Crafting recipe reward (Quest 2)

---

## Phase 4: Faction System

### Verify Factions Exist
- [ ] `church_of_gaela` - Primary faction for this quest chain
- [ ] `church_of_three` - Parent faction
- [ ] `millbrook_farmers` - Regional faction
- [ ] `thornfield_citizens` - Regional faction
- [ ] `dalhurst_merchants` - Regional faction (Quest 4 choice)

### If Missing, Create
- [ ] Add faction definitions to `FactionManager`
- [ ] Set up parent-child relationship (church_of_gaela → church_of_three)
- [ ] Define reputation thresholds and titles

---

## Phase 5: Dialogue Integration

### Priestess Elara Dialogue Nodes
- [ ] **Initial greeting** - No quests started yet
- [ ] **Quest 1 offer** - "Seeds of Faith" introduction
- [ ] **Quest 2 offer** - After Quest 1 complete
- [ ] **Quest 3 offer** - After Quest 2 complete
- [ ] **Quest 4 offer** - After Quest 3 complete
  - [ ] Choice outcomes: protect_grove_fully, allow_limited_logging, find_alternative
- [ ] **Quest 5 offer** - CRITICAL: Devotion choice
  - [ ] Choice outcomes: accept_devotion (set flag), decline_devotion (end chain)
- [ ] **Quest 6-10 offers** - Devotee-only (check `gaela_devotee` flag)
- [ ] **Repeatable quest offer** - Check cooldown, devotee-only
- [ ] **Champion celebration** - After Quest 10 complete

### Other NPC Dialogues
- [ ] **millbrook_farmer** - Quest 1, Quest 3 dialogue
- [ ] **logging_foreman_elder_moor** - Quest 4 negotiation dialogue
- [ ] **thornfield_healer** - Quest 8 delivery dialogue
- [ ] **millbrook_shepherd** - Bonus quest giver dialogue

### Cross-Temple Acknowledgment
- [ ] **Priest of Chronos** - Acknowledge Gaela devotion if flag set
- [ ] **Priest of Morthane** - Acknowledge Gaela devotion if flag set

---

## Phase 6: World Locations

### Verify Locations Exist (all verified in WorldGrid)
- [x] `elder_moor` - Quest 1, 4, 9
- [x] `dalhurst` - Temple location (quest giver)
- [x] `thornfield` - Quest 2, 8, 9
- [x] `millbrook` - Quest 2, 3, 9, Bonus quest
- [x] `crossroads` - Quest 2, 7, 9
- [x] `willow_dale` - Quest 6, 10, Bonus quest
- [x] `bandit_hideout` - Quest 8

### Add Quest Markers/Interactables
- [ ] **Gaela's Shrine** in Elder Moor (Quest 1 interaction point)
- [ ] **Sacred Grove** near Elder Moor (Quest 4 location)
- [ ] **Temple Gardens** in Dalhurst (Repeatable quest area)
- [ ] **Corrupted Zone** near Willow Dale (Quest 10 ritual site)
- [ ] **Land Spirit Location** near Crossroads (Quest 7)
- [ ] **Seed Guardian Location** near Bandit Hideout (Quest 8)

---

## Phase 7: Flags & Quest Prerequisites

### Quest Manager Flags
- [ ] `gaela_devotee` - Set by Quest 5, required for Quests 6-10
- [ ] `gaela_devotion_declined` - Set by Quest 5 if player declines
- [ ] `gaela_champion` - Set by Quest 10
- [ ] `lifebringer_ritual_complete` - Set by Quest 10
- [ ] `sacred_grove_protected` - Quest 4 choice flag
- [ ] `sacred_grove_compromise` - Quest 4 choice flag
- [ ] `sacred_grove_alternative` - Quest 4 choice flag

### Quest Prerequisites (verify QuestManager supports)
- [ ] Quest 2 requires Quest 1 complete
- [ ] Quest 3 requires Quest 2 complete
- [ ] Quest 4 requires Quest 3 complete
- [ ] Quest 5 requires Quest 4 complete
- [ ] Quest 6 requires Quest 5 complete + `gaela_devotee` flag
- [ ] Quest 7 requires Quest 6 complete + `gaela_devotee` flag
- [ ] Quest 8 requires Quest 7 complete + `gaela_devotee` flag
- [ ] Quest 9 requires Quest 8 complete + `gaela_devotee` flag
- [ ] Quest 10 requires Quest 9 complete + `gaela_devotee` flag
- [ ] Bonus Bountiful Harvest requires `gaela_devotee` flag
- [ ] Bonus Lost Flock requires Quest 3 complete
- [ ] Repeatable Tending requires `gaela_devotee` flag + 7-day cooldown

---

## Phase 8: Special Mechanics

### Quest 4: Choice Consequences
- [ ] Verify `choice_consequences` system works in QuestManager
- [ ] Test all three choice outcomes apply correct reputation changes

### Quest 5: Devotion Choice
- [ ] Verify flag-setting works on choice selection
- [ ] Test that declining devotion prevents access to Quests 6-10

### Quest 10: Champion Title
- [ ] Verify `gaela_champion` flag grants title in player stats
- [ ] Verify ritual completion triggers world state change (optional)

### Repeatable Quest
- [ ] Verify cooldown system works (7 days)
- [ ] Test quest can be repeated after cooldown expires

---

## Phase 9: Balance & Testing

### Reward Balance
- [ ] Verify gold rewards scale appropriately (50g → 750g)
- [ ] Verify XP rewards scale appropriately (200 XP → 2000 XP)
- [ ] Verify faction reputation gains are balanced

### Combat Difficulty
- [ ] Test Quest 3: 5 dire wolves + 8 giant rats (appropriate for Tier 1?)
- [ ] Test Quest 6: 6 dark cultists (appropriate for Tier 3?)
- [ ] Test Quest 8: Ancient Treant boss fight (appropriate for Tier 3?)
- [ ] Test Quest 9: 10 cultists + Dark Ritualist boss (appropriate for Tier 4?)
- [ ] Test Quest 10: 12 corrupted beasts (appropriate for Tier 4?)

### Player Progression
- [ ] Verify quest chain is completable at expected player levels
- [ ] Test that devotion choice feels meaningful (not forced)
- [ ] Test that Champion rewards feel epic

---

## Phase 10: Integration & Polish

### QuestManager Integration
- [ ] Load all 13 quest JSON files into QuestManager
- [ ] Verify `next_quest` auto-start works for chain progression
- [ ] Test save/load preserves quest states and flags

### UI Display
- [ ] Verify all quests show correctly in Quest Journal
- [ ] Test objective tracking updates properly
- [ ] Test turn-in notifications work

### Documentation
- [x] README.md created with full documentation
- [x] QUEST_SUMMARY.txt created for quick reference
- [x] IMPLEMENTATION_CHECKLIST.md created (this file)

---

## Final Verification

- [ ] Full playthrough test of all 10 main quests
- [ ] Test both devotion paths (accept and decline)
- [ ] Test all 3 choice outcomes in Quest 4
- [ ] Test bonus quests
- [ ] Test repeatable quest cooldown
- [ ] Verify all NPCs exist and dialogue works
- [ ] Verify all items exist and can be received/used
- [ ] Verify faction reputation changes apply correctly
- [ ] Bug test: Edge cases, save/load, progression blockers

---

## Estimated Implementation Time

| Phase | Estimated Time |
|-------|----------------|
| Phase 1: NPCs | 2-3 hours |
| Phase 2: Enemies | 1 hour (if all exist) |
| Phase 3: Items | 3-4 hours |
| Phase 4: Factions | 30 min (if system exists) |
| Phase 5: Dialogue | 4-5 hours |
| Phase 6: Locations | 2 hours |
| Phase 7: Flags | 1 hour |
| Phase 8: Mechanics | 2 hours |
| Phase 9: Testing | 3-4 hours |
| Phase 10: Polish | 2 hours |
| **TOTAL** | **21-26 hours** |

---

**Note:** This is a comprehensive quest chain. Consider implementing in phases:
- **Phase A:** Quests 1-5 (Initiate + Acolyte tiers)
- **Phase B:** Quests 6-8 (Devotee tier)
- **Phase C:** Quests 9-10 (Champion tier)
- **Phase D:** Bonus/Repeatable quests

Each phase can be tested and released independently.
