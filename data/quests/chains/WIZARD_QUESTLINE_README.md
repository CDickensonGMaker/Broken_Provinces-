# Wizard's Apprentice Questline - Implementation Guide

## Overview
A 6-quest training arc where the player becomes Master Helvant's apprentice and graduates to Adept status. All quests take place in the allowed geographic areas (Elder Moor, Dalhurst, Thornfield, Millbrook, Crossroads, Willow Dale, Bandit Hideout).

---

## Quest Files Created

### 1. wizard_aptitude_test.json - "The Spark Within"
**Location:** Dalhurst (Master Helvant)
**Objectives:**
- Collect 1 moonpetal flower (Crossroads shrine)
- Collect 1 silver dust (from undead)
- Return to Helvant

**Rewards:**
- 25 gold, 150 XP
- Spell: Magic Missile
- Wizards Guild +10 rep
- Flag: `helvant_accepted_apprentice`

**Next Quest:** wizard_first_lesson

---

### 2. wizard_first_lesson.json - "Elemental Foundations"
**Location:** Multiple zones (Dalhurst, Millbrook, Crossroads, Elder Moor)
**Objectives:**
- Interact with blacksmith forge in Dalhurst (fire essence)
- Reach Millbrook (water essence)
- Interact with Crossroads standing stones (earth essence)
- Reach Elder Moor hilltop (air essence)
- Kill 3 enemies using magic
- Return to Helvant

**Rewards:**
- 50 gold, 250 XP
- Spell: Flame Burst
- Item: Apprentice Robe
- Wizards Guild +15 rep
- Flag: `helvant_lesson_one_complete`

**Next Quest:** wizard_field_test

**Implementation Notes:**
- Need interact points: `blacksmith_forge_dalhurst`, `crossroads_stones`
- Need location markers: `millbrook`, `elder_moor_hilltop`
- Combat tracking: QuestManager needs to track kills by magic damage type

---

### 3. wizard_field_test.json - "Practical Application"
**Location:** Dalhurst, Thornfield, Crossroads
**Objectives:**
- Interact with Dalhurst harbor beacon (light it with fire spell)
- Interact with Thornfield well (purify water)
- Interact with Crossroads tree obstacle (move with telekinesis)
- Kill 5 bandits near Crossroads
- Return to Helvant

**Rewards:**
- 75 gold, 350 XP
- Spell: Ice Shard
- Item: Enchanted Amulet (Minor) - +5 arcana
- Wizards Guild +20, Common Folk +10 rep
- Flag: `helvant_field_test_complete`

**Next Quest:** wizard_lost_tome

**Implementation Notes:**
- Need interact points: `dalhurst_harbor_beacon`, `thornfield_well`, `crossroads_tree_obstacle`
- Need enemy spawn: `bandit_crossroads_group` (5 bandits)
- Each interact should show magical effect (flame, water glow, tree moving)

---

### 4. wizard_lost_tome.json - "The Lost Grimoire"
**Location:** Willow Dale dungeon
**Objectives:**
- Reach Willow Dale
- Reach Willow Dale library chamber
- Defeat arcane guardian (boss)
- Collect grimoire
- Return to Helvant

**Rewards:**
- 100 gold, 500 XP
- Spell: Lightning Bolt
- Wizards Guild +25 rep
- Flags: `helvant_grimoire_recovered`, `grimoire_pages_missing`

**Next Quest:** wizard_stolen_pages

**Spawn on Accept:**
- Enemy: `arcane_guardian` at `willow_dale_library`
- Chest: Contains `helvants_master_grimoire` (spawns after guardian defeated)

**Quest Items:**
- `helvants_master_grimoire` (cannot be sold/dropped)

**Implementation Notes:**
- Need location: `willow_dale_library` (deep in Willow Dale dungeon)
- Need enemy: Arcane Guardian (magical construct, high HP, uses elemental attacks)
- Grimoire is quest item - automatically removed on turn-in

---

### 5. wizard_stolen_pages.json - "Ink and Blood"
**Location:** Thornfield area
**Objectives:**
- Reach Thornfield
- Talk to Thornfield innkeeper
- Reach cultist cave east of Thornfield
- Confront rival mage (dialogue choice)
- [Optional] Defeat 4 cultists (if combat chosen)
- Collect stolen pages
- Return to Helvant

**Rewards:**
- 150 gold, 600 XP
- Spell: Arcane Shield
- Wizards Guild +30 rep

**Choice Consequences:**
- **Defeated rival mage:** Flag `rival_mage_defeated`, Wizards Guild +10 rep
- **Negotiated:** Flag `rival_mage_allied`, Wizards Guild +5 rep (rival may appear as ally later)
- **Bribed rival:** Flag `rival_mage_bribed`, Wizards Guild -5 rep (Helvant disapproves)

**Next Quest:** wizard_final_trial

**Spawn on Accept:**
- NPC: `rival_mage_valdric` at `thornfield_cultist_cave` (dialogue-enabled boss)
- Enemies: 4x `dark_cultist` (attack if player chooses combat)

**Quest Items:**
- `grimoire_pages_stolen`

**Implementation Notes:**
- Need location: `thornfield_cultist_cave` (small cave dungeon east of Thornfield)
- Need NPC: Valdric the Rival Mage (dialogue tree with combat/negotiate/bribe options)
- Dialogue choices should provide pages and set corresponding flags
- If combat path, pages drop from Valdric's corpse

---

### 6. wizard_final_trial.json - "The Adept's Challenge"
**Location:** Helvant's Trial Chamber (beneath his tower in Dalhurst)
**Objectives:**
- Enter trial chamber
- Defeat 3 summoned elementals (fire, ice, lightning)
- Solve arcane sigil puzzle
- Duel Master Helvant (non-lethal, yields at 25% HP)
- Speak to Helvant for graduation

**Rewards:**
- 200 gold, 1000 XP
- Spell: Meteor Storm (powerful AoE signature spell)
- Item: Adept Wizard Robes (+15 arcana, +50 max mana)
- Item: Staff of the Adept (two-handed, +10 arcana, +25% spell damage)
- Wizards Guild +50 rep
- Flags: `helvant_adept_graduated`, `wizard_questline_complete`, `unlock_advanced_spells`

**Next Quest:** None (questline complete)

**Spawn on Accept:**
- Enemy: `trial_fire_elemental` (vulnerable to ice)
- Enemy: `trial_ice_elemental` (vulnerable to fire)
- Enemy: `trial_lightning_elemental` (vulnerable to earth/physical)
- NPC: `master_helvant_trial` (duel projection - yields at 25% HP, not killable)

**Implementation Notes:**
- Need location: `helvant_trial_chamber` (instanced challenge room)
- Need puzzle: `helvant_trial_sigils` (rune sequence puzzle)
- Helvant duel should be scripted - he uses various spells, yields when low HP
- Completion unlocks advanced spell purchases from Helvant vendor

---

## Dialogue File Created

**File:** `master_helvant_wizard_training.json`

**Coverage:**
- Initial greeting and aptitude test offer
- Elemental lesson explanations
- Field test briefing
- Grimoire quest setup
- Stolen pages investigation
- Final trial challenge
- Graduation ceremony
- Reactive dialogue based on quest states and choice consequences

**Key Nodes:**
- `greeting_initial` - Entry point, branches based on quest state
- Quest introduction nodes for each quest
- Quest completion nodes with different paths based on player choices
- `graduation_speech` - Final reward dialogue
- `final_farewell` - Unlocks advanced spell vendor access

---

## Items/Spells Needed

### Spell Scrolls (Quest Rewards)
- `spell_scroll_magic_missile` - Basic projectile (Quest 1)
- `spell_scroll_flame_burst` - Fire AoE (Quest 2)
- `spell_scroll_ice_shard` - Ice projectile (Quest 3)
- `spell_scroll_lightning_bolt` - Lightning chain (Quest 4)
- `spell_scroll_arcane_shield` - Defensive buff (Quest 5)
- `spell_scroll_meteor_storm` - Powerful AoE signature (Quest 6)

### Equipment Items
- `apprentice_robe` - Basic mage armor (+5 arcana, light defense) (Quest 2)
- `enchanted_amulet_minor` - Neck slot (+5 arcana) (Quest 3)
- `adept_wizard_robes` - Advanced mage armor (+15 arcana, +50 max mana) (Quest 6)
- `staff_of_the_adept` - Two-handed weapon (+10 arcana, +25% spell damage) (Quest 6)

### Quest Items (auto-removed on completion)
- `helvants_master_grimoire` - Ancient spellbook (Quest 4)
- `grimoire_pages_stolen` - Missing pages (Quest 5)

### Reagents/Materials
- `moonpetal_flower` - Magical flower (Quest 1)
- `silver_dust` - Undead drop (Quest 1)

---

## Locations/Markers Needed

### Existing Locations (Should Already Exist)
- `dalhurst` - Main town
- `thornfield` - Eastern town
- `millbrook` - Lakeside town
- `crossroads` - Road intersection
- `elder_moor` - Starting area
- `willow_dale` - Dungeon entrance

### New Locations/Markers to Create
- `blacksmith_forge_dalhurst` - Interact point in Dalhurst (fire essence)
- `crossroads_stones` - Standing stones at Crossroads (earth essence)
- `elder_moor_hilltop` - High point near Elder Moor (air essence)
- `dalhurst_harbor_beacon` - Lighthouse/beacon (light with fire)
- `thornfield_well` - Town well (purify water)
- `crossroads_tree_obstacle` - Fallen tree blocking road
- `willow_dale_library` - Deep chamber in Willow Dale dungeon
- `thornfield_cultist_cave` - Small cave east of Thornfield
- `helvant_trial_chamber` - Beneath Helvant's tower in Dalhurst

---

## Enemies/NPCs Needed

### Enemies
- `arcane_guardian_willow_dale` - Magical construct boss (Quest 4)
- `trial_fire_elemental` - Fire elemental (Quest 6)
- `trial_ice_elemental` - Ice elemental (Quest 6)
- `trial_lightning_elemental` - Lightning elemental (Quest 6)
- `dark_cultist` - Cultist minions (Quest 5, 4x spawn)
- `bandit_crossroads_group` - 5 bandits (Quest 3)

### NPCs
- `master_helvant_dalhurst` - Quest giver, main NPC (all quests)
- `thornfield_innkeeper` - Provides investigation info (Quest 5)
- `rival_mage_valdric` - Boss NPC with dialogue options (Quest 5)
- `master_helvant_trial` - Helvant's trial projection (Quest 6 duel)

---

## Puzzle Needed

**Puzzle ID:** `helvant_trial_sigils`
**Type:** Arcane rune sequence puzzle
**Location:** Trial chamber
**Description:** Player must activate magical sigils in correct order based on elemental theory learned throughout questline
**Solution Hint:** Fire → Water → Earth → Air (order learned in Quest 2)

---

## Integration with Existing Systems

### QuestManager
- All quests use standard quest JSON format
- `next_quest` field chains the quests automatically
- `choice_consequences` used in Quest 5 for multiple resolution paths
- Combat tracking for "kill with magic" objectives (may need flag in CombatManager)

### DialogueManager
- Dialogue uses quest state conditions to show appropriate nodes
- Flags track player choices (defeated/negotiated/bribed rival mage)
- Actions trigger quest starts and completions

### FlagManager
Flags Used:
- `helvant_accepted_apprentice`
- `helvant_lesson_one_complete`
- `helvant_field_test_complete`
- `helvant_grimoire_recovered`
- `grimoire_pages_missing`
- `rival_mage_defeated`
- `rival_mage_allied`
- `rival_mage_bribed`
- `helvant_grimoire_complete`
- `ready_for_final_trial`
- `helvant_adept_graduated`
- `wizard_questline_complete`
- `unlock_advanced_spells`

### FactionManager
- `wizards_guild` faction reputation tracks throughout
- Final quest gives +50 rep (total ~145 rep if all quests completed optimally)

---

## Testing Checklist

- [ ] Master Helvant NPC spawns in Dalhurst
- [ ] Initial dialogue offers aptitude test
- [ ] Quest 1: Can collect moonpetal and silver dust
- [ ] Quest 1: Completion gives Magic Missile spell
- [ ] Quest 2: All 4 elemental essence locations work
- [ ] Quest 2: "Kill with magic" tracking works
- [ ] Quest 3: All interact points work (beacon, well, tree)
- [ ] Quest 3: Bandit spawn and combat works
- [ ] Quest 4: Willow Dale library accessible
- [ ] Quest 4: Arcane guardian spawns and is defeatable
- [ ] Quest 4: Grimoire appears after guardian defeated
- [ ] Quest 5: Investigation path through innkeeper works
- [ ] Quest 5: Valdric dialogue has combat/negotiate/bribe options
- [ ] Quest 5: Each choice path gives pages and sets correct flags
- [ ] Quest 6: Trial chamber accessible
- [ ] Quest 6: All 3 elementals spawn and are defeatable with magic
- [ ] Quest 6: Sigil puzzle works
- [ ] Quest 6: Helvant duel is non-lethal and yields at 25% HP
- [ ] Quest 6: Graduation dialogue triggers
- [ ] Quest 6: Final rewards given (Meteor Storm, robes, staff)
- [ ] `unlock_advanced_spells` flag unlocks vendor options from Helvant

---

## Design Philosophy

This questline follows the classic RPG apprentice-to-master arc:
1. **Prove Yourself** - Aptitude test shows basic competence
2. **Learn Fundamentals** - Elemental theory builds foundation
3. **Apply Knowledge** - Help people with magic (not just combat)
4. **Fetch Quest with Stakes** - Dungeon delve for important artifact
5. **Moral Choice** - Multiple paths to resolve conflict (combat/negotiate/bribe)
6. **Final Exam** - Multi-stage challenge proving mastery

The questline respects player agency:
- Multiple resolution paths in Quest 5
- Choices have consequences (flags, reputation)
- Mix of combat and non-combat objectives
- Rewards scale with difficulty
- Final trial tests all learned skills

All content stays within allowed geographic areas and uses existing game systems (quests, dialogue, flags, faction rep, items, spells).

---

## Future Expansion Hooks

- Rival mage Valdric (if negotiated with) could return as ally in future content
- `unlock_advanced_spells` flag enables Helvant as advanced spell vendor
- Player could take their own apprentice (faction quest?)
- Grimoire could be referenced in higher-level wizard content
- Adept rank could unlock wizard guild membership or special quests

---

**Author Notes:**
This questline is ready for implementation. All quest JSONs and dialogue are complete and follow existing game formats. The main work needed is:
1. Create NPC: Master Helvant with dialogue tree
2. Add location markers (shrines, interact points, dungeons)
3. Create enemies (guardian, elementals, cultists, Valdric)
4. Create items/spells (scrolls, robes, staff, amulet)
5. Build trial chamber scene with puzzle
6. Hook up quest completion tracking for "kill with magic" objectives
7. Test the full questline from start to finish

Geographic constraint honored: Everything takes place in Elder Moor, Dalhurst, Thornfield, Millbrook, Crossroads, Willow Dale, and nearby areas.
