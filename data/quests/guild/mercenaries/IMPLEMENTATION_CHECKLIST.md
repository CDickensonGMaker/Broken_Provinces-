# Iron Company Quest Chain - Implementation Checklist

## Files Created ✓

### Quest Files (14/14) ✓
All quest JSON files created in `data/quests/guild/mercenaries/`:
- [x] mercenary_01_enlistment.json
- [x] mercenary_02_drill.json
- [x] mercenary_03_first_blood.json
- [x] mercenary_04_caravan_guard.json
- [x] mercenary_05_siege_support.json
- [x] mercenary_06_hostage_rescue.json
- [x] mercenary_07_command_trial.json
- [x] mercenary_08_rival_company.json
- [x] mercenary_09_betrayal.json
- [x] mercenary_10_noble_war.json
- [x] mercenary_11_monster_battalion.json
- [x] mercenary_12_legendary_battle.json
- [x] mercenary_13_second_command.json
- [x] mercenary_repeatable_contracts.json

### NPC Blueprint ✓
- [x] captain_roderick_steele.json

### Documentation ✓
- [x] README.md (quest chain overview)
- [x] IMPLEMENTATION_CHECKLIST.md (this file)

---

## Content Verification ✓

### Quest Structure Validation
- [x] All quests use proper JSON format
- [x] All quests have unique IDs
- [x] All quests have faction: "iron_company"
- [x] Quest chain properly linked with `next_quest` field
- [x] Prerequisites correctly reference previous quests
- [x] All quests stay within geographic boundaries (Elder Moor, Dalhurst, Thornfield, Millbrook, Crossroads, Willow Dale, Bandit Hideout, Kazer-Dun Entrance)

### Reward Scaling ✓
| Rank | Quest Range | Gold | XP | Rep |
|------|-------------|------|-----|-----|
| Recruit | 1-3 | 100-150 | 250-400 | 25-50 |
| Soldier | 4-6 | 200-300 | 500-700 | 30-50 |
| Sergeant | 7-9 | 350-450 | 800-1000 | 40-60 |
| Lieutenant | 10-12 | 600-800 | 1200-1600 | 70-100 |
| Captain's Right Hand | 13 | 1000 | 2000 | 100 |
| Repeatable | 14 | 150 | 300 | 10 |

**Total Reputation Gain:** 725 (across main chain)

---

## Still Needed for Implementation

### 1. NPCs to Create
**Priority: HIGH**

- [ ] **Captain Roderick Steele** (main quest giver)
  - Location: Iron Hall, Dalhurst
  - Sprite: Guard/soldier type with veteran appearance
  - Dialogue tree with quest hooks
  - All 14 quests accessible through him

- [ ] **Training Soldiers** (Quest 1)
  - Combat trial enemies
  - 3 soldiers at recruit difficulty

- [ ] **Veteran Soldiers** (Quest 2)
  - Training drill enemies
  - 5 veterans, slightly tougher than recruits

- [ ] **Kidnapped Merchant** (Quest 6)
  - Hostage NPC in Bandit Hideout
  - Dialogue for rescue interaction

- [ ] **Black Wolf Captain** (Quest 8)
  - Rival mercenary leader
  - Dialogue options for multiple resolution paths

- [ ] **Iron Company Traitor** (Quest 9)
  - Reveals during investigation
  - Dialogue for confrontation

- [ ] **Noble Client** (Quest 10)
  - Contract giver in Millbrook
  - Brief dialogue for war context

---

### 2. Enemy Types to Create/Verify
**Priority: MEDIUM**

Standard enemies (likely exist already):
- [ ] bandit (various types: standard, scout, defender, elite, leader, commander, guard)
- [ ] goblin_warrior, goblin_scout, goblin_shaman
- [ ] orc_warrior, orc_warchief
- [ ] dark_cultist

New enemy types needed:
- [ ] **training_soldier** (Quest 1) - Weak enemies for trial
- [ ] **veteran_soldier** (Quest 2) - Mid-tier training enemies
- [ ] **black_wolf_mercenary** (Quest 8) - Rival company soldiers
- [ ] **rival_mercenary** (Quest 10) - Generic rival forces
- [ ] **rival_heavy_infantry** (Quest 10) - Tougher rival troops
- [ ] **rival_commander** (Quest 10) - Boss enemy
- [ ] **deserter_mercenary** (Quest 12) - Traitor forces
- [ ] **siege_operator** (Quest 11) - Enemies manning siege weapons
- [ ] **enemy_warlord** (Quest 12) - Final boss
- [ ] **captain_roderick_steele_duel** (Quest 13) - Special duel version of captain
- [ ] **contract_enemy** (Quest 14) - Generic repeatable enemy

---

### 3. Locations/Markers to Add
**Priority: HIGH**

#### Dalhurst
- [ ] **Iron Hall** - Guild headquarters building
- [ ] **iron_hall_training_grounds** - Training area marker
- [ ] **iron_hall_arena** - Duel arena marker (Quest 13)

#### Elder Moor Area
- [ ] **bandit_outpost_elder_moor** - First mission location (Quest 3)

#### Willow Dale Area
- [ ] **bandit_stronghold_willow_dale** - Siege location (Quest 5)

#### Bandit Hideout
- [ ] **hostage_cell** - Interior location marker (Quest 6)

#### Crossroads
- [ ] Battle/meeting markers for Quests 8 and 12

#### Millbrook
- [ ] Defense position markers (Quest 11)

#### Other Markers
- [ ] **squad_survival_checkpoint** (Quest 7) - For tracking squad deaths

---

### 4. Items to Create
**Priority: MEDIUM**

Quest reward items:
- [ ] **iron_company_token** - Initiation token
- [ ] **iron_company_sword** - Basic company weapon
- [ ] **iron_company_shield** - Basic company shield
- [ ] **iron_company_armor** - Recruit armor
- [ ] **sergeant_insignia** - Rank marker
- [ ] **sergeant_cloak** - Sergeant gear
- [ ] **black_wolf_trophy** - Quest 8 trophy
- [ ] **lieutenant_badge** - Rank marker
- [ ] **war_veteran_medal** - Quest 10 medal
- [ ] **siege_veteran_medal** - Quest 5 medal
- [ ] **horde_breaker_blade** - Quest 11 legendary weapon
- [ ] **crossroads_defender_shield** - Quest 12 legendary shield
- [ ] **iron_lieutenant_armor** - Final rank armor
- [ ] **iron_lieutenant_sword** - Final rank weapon
- [ ] **company_commander_cloak** - Final rank cloak

Quest items:
- [ ] **betrayal_evidence** - Quest 9 collectible documents (3 needed)

---

### 5. Dialogue Integration
**Priority: HIGH**

- [ ] Create dialogue tree for Captain Roderick Steele
  - Initial recruitment conversation
  - Quest acceptance dialogue for all 14 quests
  - Quest turn-in dialogue
  - Rank promotion dialogue (quests 3, 6, 9)
  - Final duel challenge dialogue (quest 13)

- [ ] Add QUESTS topic responses for Captain Steele
- [ ] Wire quest chain to start when player first talks to Captain

---

### 6. Faction System Integration
**Priority: HIGH**

- [ ] Verify `iron_company` faction exists in FactionManager
- [ ] Set up faction reputation thresholds if needed
- [ ] Test reputation gain across quest chain
- [ ] Configure faction cascading relationships (if any)
  - Iron Company vs Bandits (hostile)
  - Iron Company vs Human Empire (neutral/friendly)

---

### 7. Scene/Level Work
**Priority: MEDIUM**

#### Iron Hall (new scene or add to Dalhurst)
- [ ] Create fortified guild hall building
- [ ] Add training grounds area
- [ ] Add duel arena
- [ ] Place Captain Roderick Steele NPC
- [ ] Add ambient NPCs (veteran soldiers, recruits)

#### Quest-Specific Encounters
- [ ] Quest 1: Spawn training soldiers for trial
- [ ] Quest 3: Bandit outpost near Elder Moor
- [ ] Quest 5: Bandit stronghold near Willow Dale
- [ ] Quest 6: Hostage cell in Bandit Hideout
- [ ] Quest 7: Goblin camp near Thornfield with squad spawning
- [ ] Quest 8: Black Wolves encounter at Crossroads
- [ ] Quest 11: Horde defense at Millbrook
- [ ] Quest 12: Epic battle at Crossroads

---

### 8. Testing Checklist
**Priority: CRITICAL (before release)**

- [ ] Talk to Captain Steele, receive Quest 1
- [ ] Complete all 14 quests in sequence
- [ ] Verify quest chaining (next_quest auto-starts)
- [ ] Verify reputation gains at each turn-in
- [ ] Verify rank promotions (quests 3, 6, 9)
- [ ] Test optional objectives (quests 8, 9, 10)
- [ ] Test final duel (quest 13)
- [ ] Test repeatable quest (quest 14)
- [ ] Verify all rewards granted correctly
- [ ] Check quest journal displays properly
- [ ] Save/load during quest chain

---

## Geographic Compliance ✓

All quests stay within allowed zones:
- Elder Moor ✓
- Dalhurst ✓
- Thornfield ✓
- Millbrook ✓
- Crossroads ✓
- Willow Dale ✓
- Bandit Hideout ✓
- Kazer-Dun Entrance (boundary) ✓

**No quests send player south of Kazer-Dun.** ✓

---

## Quest Design Quality Checklist ✓

- [x] All quests have clear military/tactical themes
- [x] Escalating difficulty and scale (small skirmishes → epic battles)
- [x] Mix of combat types (ambushes, sieges, defense, infiltration)
- [x] Character progression through ranks
- [x] Choice moments (quests 8, 9, 10)
- [x] Climactic finale (duel with Captain Steele)
- [x] Repeatable endgame content
- [x] Differentiated from Adventurer's Guild (military vs exploration)

---

## Notes

**Current Status:** Quest JSON files and NPC blueprint complete. Ready for implementation phase.

**Estimated Implementation Time:**
- NPCs & Dialogue: 4-6 hours
- Enemy types: 2-3 hours
- Locations/Markers: 2-3 hours
- Items: 1-2 hours
- Scene work: 4-6 hours
- Testing: 2-3 hours
**Total: ~15-23 hours**

**Dependencies:**
- QuestManager autoload (exists)
- FactionManager autoload (exists)
- DialogueManager autoload (exists)
- InventoryManager autoload (exists)
- Enemy spawning system (exists)
- NPC conversation system (exists)

**Recommended Implementation Order:**
1. Create Captain Roderick Steele NPC and basic dialogue
2. Add Iron Hall to Dalhurst scene
3. Create all required enemy types
4. Create quest reward items
5. Add location markers
6. Wire quest chain to dialogue
7. Test first 3 quests thoroughly
8. Implement remaining quests
9. Full playthrough test
