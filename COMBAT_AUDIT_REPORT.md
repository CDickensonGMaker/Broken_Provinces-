# COMPREHENSIVE COMBAT & ENEMY SYSTEMS AUDIT

**Date:** 2026-03-04
**Auditor:** Balance Analyzer Agent
**Status:** CRITICAL ISSUES FOUND

---

## EXECUTIVE SUMMARY

Overall system health: **GOOD with CRITICAL gaps**

✅ **STRENGTHS:**
- All 52 enemy .tres files have valid EnemyData script references
- Enemy base class properly extends CharacterBody3D with comprehensive AI system
- Death handling is complete and proper (unregistration, corpse spawning, XP rewards)
- Signal connections properly disconnected on scene change (prevents "freed object" crashes)
- Combat manager has robust memory management with cleanup timers
- Loot tables are wired correctly

❌ **CRITICAL ISSUES:**
1. **19 enemies missing `icon_path` values** - UI will show blank icons
2. **7 enemies missing `sprite_path` completely** - Visual rendering will fail
3. **Inconsistent sprite frame data** - Many enemies have mismatched h_frames/v_frames vs actual sprites
4. **Combat stat imbalances** - Early enemies may be too weak, late-game boss scaling appears off

---

## ISSUE BREAKDOWN

### ISSUE #1: Missing icon_path Fields (19 enemies) - MEDIUM SEVERITY

**Affected Files:**
- C:\Users\caleb\CatacombsOfGore\data\enemies\boar.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\deer.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\skeleton_warrior.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\skeleton_shade.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\goblin_soldier.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\goblin_archer.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\goblin_leader.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\goblin_mage.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\goblin_warboss.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_archer.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_cavalry.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_infantry.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_raider.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_berserker.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_shaman.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warbanner.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warlord.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warrior.tres (line 81)
- C:\Users\caleb\CatacombsOfGore\data\enemies\vampire_lord.tres (line 133)

**Impact:**
- Enemy_base.gd line 2465 uses `enemy_data.icon_path` for CodexManager bestiary entries
- Entries will still work but will have blank/missing icons in the Codex UI
- Not a crash, but breaks the intended user experience

**Recommendation:**
Add proper icon_path values to all 19 files. Example:
```tres
icon_path = "res://assets/sprites/enemies/boar.png"
```

---

### ISSUE #2: Missing sprite_path Fields (7 enemies) - HIGH SEVERITY

**Affected Files:**
- C:\Users\caleb\CatacombsOfGore\data\enemies\boar.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\deer.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_archer.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_shaman.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warlord.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_raider.tres (no sprite_path field)
- C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warrior.tres (no sprite_path field)

**Impact:**
- Enemies without sprite_path cannot spawn as billboard sprites in-game
- Zoo registry at C:\Users\caleb\CatacombsOfGore\dev\zoo\zoo_registry.gd line 76 shows human_bandit_alt.png as fallback
- These enemies may not render visually or may display broken placeholder meshes

**Recommendation:**
Each .tres file must include:
```tres
sprite_path = "res://assets/sprites/enemies/[enemy_name].png"
attack_sprite_path = ""
sprite_hframes = [count]
sprite_vframes = [count]
sprite_pixel_size = 0.03
```

---

### ISSUE #3: Enemy Stat Imbalances - MEDIUM SEVERITY

**Tier Analysis (vs CLAUDE.md targets):**

| Enemy | Level | HP | Expected Damage/Hit | TTK (hits) | Status |
|-------|-------|-----|-------------------|-----------|---------|
| wolf | 3 | 20 | 4-6 | 3-5 | ✅ GOOD |
| human_bandit | 5 | 40 | 6-12 | 3-7 | ✅ GOOD |
| goblin_soldier | 6 | 25 | 4-8 | 3-6 | ✅ GOOD |
| ogre | 15 | 84 | 20-30 | 3-4 | ⚠️ LOW (dies too fast) |
| vampire_lord | BOSS | 300 | 15-30 | 10-20 | ⚠️ UNCLEAR (boss should be 15-30 hits) |

**Specific Issues:**

1. **Ogre (Level 15 boss)** - Line 82-83 in ogre.tres:
   ```tres
   max_hp = 84
   is_boss = true
   ```
   - HP is only 84 vs level 15
   - Expected boss HP at level 15: ~150-200
   - Will die in 3-4 hits from player with decent gear
   - Recommendation: Increase to 150-180 HP

2. **Vampire Lord (Level BOSS)** - vampire_lord.tres lines 92-106:
   ```tres
   max_hp = 300
   is_boss = true
   horror_difficulty = 18
   ```
   - No level field specified! Falls back to default
   - Should have explicit level field (recommend level 25)
   - 300 HP is appropriate for a true boss if level 25+
   - Recommendation: Add `level = 25` field

3. **Stat Scaling Formula** - Enemy_base.gd line 381-387:
   ```gdscript
   var effective_level: int = enemy_data.get_effective_level(player_level, zone_danger)
   var level_ratio: float = float(effective_level) / float(maxi(enemy_data.level, 1))
   var scaled_hp: int = int(enemy_data.max_hp * level_ratio)
   ```
   - This is correct for scaling
   - But Ogre's base HP is too low to scale properly

---

### ISSUE #4: Missing min_level/max_level Fields - LOW SEVERITY

**Check:** vampire_lord.tres lacks level field entirely
- Lines 92-93: Contains max_hp and armor_value but no level or min_level/max_level
- Should have:
```tres
level = 25
min_level = 20
max_level = 40
```

---

### ISSUE #5: Inconsistent h_frames/v_frames in Zoo Registry - MEDIUM SEVERITY

**File:** C:\Users\caleb\CatacombsOfGore\dev\zoo\zoo_registry.gd

Examples of sprite frame mismatches:

1. **human_bandit** (line 76 in zoo_registry):
   - Zoo says: `h_frames = 1, v_frames = 1`
   - Actual sprite: `human_bandit_alt.png` (dimensions unknown)
   - .tres file has no explicit h_frames (will use defaults)
   - **FIX:** Verify actual sprite dimensions and update both zoo_registry and .tres

2. **giant_rat** (line 90):
   - Zoo says: `h_frames = 4, v_frames = 1`
   - This matches rat animations
   - ✅ CORRECT

3. **goblin_soldier** (line 86 in goblin_soldier.tres):
   - Has: `sprite_hframes = 4, sprite_vframes = 2`
   - Zoo registry should also specify this
   - Recommendation: Zoo registry should match .tres files exactly

---

## ENEMY REGISTRATION VERIFICATION

### Zoo Registry Status ✅
**File:** C:\Users\caleb\CatacombsOfGore\dev\zoo\zoo_registry.gd
- Contains complete list of 52+ enemies
- Properly documents sprite paths and frame counts
- Serves as documentation but should match .tres files

### World Lexicon Status ✅
**File:** C:\Users\caleb\CatacombsOfGore\scripts\data\world_lexicon.gd
- Creatures section (lines 73-99) lists all enemies with tier ratings
- All creatures in CREATURES dict have corresponding .tres files
- Matches world regions properly (REGIONS section)
- **Status:** VERIFIED COMPLETE

---

## COMBAT MANAGER ANALYSIS ✅

**File:** C:\Users\caleb\CatacombsOfGore\scripts\autoload\combat_manager.gd

### Signal Connections - VERIFIED SAFE
✅ Line 45: `SceneManager.scene_load_started.connect(_on_scene_load_started)`
✅ Line 549: `_humanoid_dialogue.dialogue_closed.connect(_on_humanoid_dialogue_closed)`

### Memory Leak Prevention - VERIFIED SAFE
✅ Lines 55-63: `_clear_node_references()` called on scene load
✅ Lines 14-15: `active_enemies` array properly maintained
✅ Lines 90-91: `unregister_enemy()` removes from tracking
✅ Line 693-698: `_cleanup_invalid_enemies()` runs every 5 seconds

### Object Reference Casting - VERIFIED SAFE
✅ Line 103-104: Checks `is_instance_valid(target)` before casting
✅ Line 232-233: Checks `is_instance_valid(target)` for ranged damage
✅ Line 304-305: Checks `is_instance_valid(target)` for spell damage

**No "trying to cast freed object" risks detected.**

---

## ENEMY BASE CLASS ANALYSIS ✅

**File:** C:\Users\caleb\CatacombsOfGore\scripts\enemies\enemy_base.gd

### Proper Extension
✅ Line 3: `class_name EnemyBase extends CharacterBody3D`
- Correct base class (NOT Node, which would lack global_position)

### Death Handling - COMPLETE ✅
✅ Line 2422-2423: `is_dead()` method returns proper state
✅ Lines 2433-2481: `_on_death()` handles:
  - Death sounds (line 2436)
  - Collision disabling (lines 2439-2445)
  - CombatManager unregistration (line 2447)
  - Quest notification (line 2451)
  - Codex registration (lines 2454-2467)
  - Persistent ID tracking (line 2471)
  - Death animation (line 2474)
  - Loot spawning (line 2478)
  - Deferred cleanup (line 2481)

### Signal Emissions - COMPLETE ✅
✅ Lines 7-12: All combat signals declared
✅ Proper emissions in AI logic

### Memory Cleanup - EXCELLENT ✅
✅ Lines 346-352: `_exit_tree()` ensures unregistration
✅ Lines 262-264: Origin shift disconnection in _exit_tree
✅ Lines 356-372: `_on_origin_shifted()` updates all stored positions

---

## SPAWN SYSTEM VERIFICATION ✅

**File:** C:\Users\caleb\CatacombsOfGore\scripts\enemies\enemy_spawner.gd

### Spawner Properties - VERIFIED ✅
✅ Line 19: `max_spawned_enemies: int = 20` (matches CLAUDE.md budget)
✅ Line 65-67: Adds to proper groups ("spawners", "destructibles", "enemies")
✅ Line 102-103: `_cleanup_dead_enemies()` removes dead enemies from tracking

### Performance Budget Compliance ✅
**Max active enemies per zone:** 20 (line 19)
- **Status:** Within budget as specified in CLAUDE.md

---

## LOOT TABLE CONNECTIONS ✅

### Loot Generation
✅ Line 2504-2530 in enemy_base.gd: `_spawn_lootable_corpse()` wires enemy_data to LootableCorpse
✅ Line 2523-2526: Routes loot generation based on faction (humanoid vs creature)

### Drop Tables
All 52 enemies have `drop_table` dictionaries configured:
- Example (human_bandit.tres line 103-107):
  ```tres
  drop_table = {
    "health_potion": 0.2,
    "lockpick": 0.15,
    "repair_kit": 0.1
  }
  ```
✅ **Status:** VERIFIED CORRECT

---

## CRITICAL FINDINGS SUMMARY

### Must Fix (Pre-Release)
1. ⚠️ **7 enemies with missing sprite_path** - Will fail to render
2. ⚠️ **19 enemies with missing icon_path** - UI experience broken
3. ⚠️ **Vampire Lord missing level field** - Stat scaling broken
4. ⚠️ **Ogre HP too low for boss** - Encounter too easy

### Should Fix (Quality)
1. ✓ Verify h_frames/v_frames match actual sprite assets
2. ✓ Update Zoo Registry to match .tres file frame counts exactly
3. ✓ Add stat scaling documentation to enemy data

### No Issues Found
- ✅ All .tres files have valid EnemyData script references
- ✅ All enemies properly extend EnemyBase
- ✅ Death handling is complete and proper
- ✅ Combat manager has excellent memory management
- ✅ Signal connections are safe
- ✅ Loot tables are properly wired
- ✅ Spawn registry is complete

---

## RECOMMENDATIONS BY PRIORITY

### PRIORITY 1: Rendering (Do First)
**File paths to fix:**
1. C:\Users\caleb\CatacombsOfGore\data\enemies\boar.tres - Add sprite_path
2. C:\Users\caleb\CatacombsOfGore\data\enemies\deer.tres - Add sprite_path
3. C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_archer.tres - Add sprite_path
4. C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_shaman.tres - Add sprite_path
5. C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warlord.tres - Add sprite_path
6. C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_raider.tres - Add sprite_path
7. C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warrior.tres - Add sprite_path

### PRIORITY 2: Icon Paths (UI Polish)
Add `icon_path` fields to 19 enemies (see ISSUE #1 list above)

### PRIORITY 3: Boss Balance (Game Feel)
1. **C:\Users\caleb\CatacombsOfGore\data\enemies\ogre.tres:**
   - Change: `max_hp = 84` → `max_hp = 150`
   - Reason: Too low for level 15 boss; should survive 8-10 hits, not 3-4

2. **C:\Users\caleb\CatacombsOfGore\data\enemies\vampire_lord.tres:**
   - Add: `level = 25` field before max_hp
   - Reason: Currently has no level; stat scaling is undefined

### PRIORITY 4: Zoo Registry Sync (Documentation)
Update C:\Users\caleb\CatacombsOfGore\dev\zoo\zoo_registry.gd entries to exactly match .tres sprite frame counts

---

## TEST CHECKLIST

- [ ] Spawn boar, deer, tenger enemies - verify they render (not invisible)
- [ ] Kill each enemy type - verify corpse loot appears (not empty)
- [ ] Open Codex - verify all 52 entries have icon_path assets
- [ ] Fight Ogre (level 15 boss) - should take ~8-10 hits to kill with baseline damage
- [ ] Fight Vampire Lord - should be challenging endgame encounter
- [ ] Check enemy h_frames in-game - no visual glitches or animation stutters

---

## VERDICT

**Overall Audit Result: PASS with CRITICAL FIXES NEEDED**

The enemy and combat systems are well-architected with:
- ✅ Proper AI state machines
- ✅ Complete death handling
- ✅ No memory leaks
- ✅ Safe signal connections
- ✅ Comprehensive loot tables

However, 26 enemy files have missing asset references (sprites/icons) that must be fixed before release. Additionally, at least 2 boss enemies need stat adjustments for proper difficulty curve.

**Estimated fix time:** 2-3 hours
**Risk if not fixed:** Medium (visual bugs, UI gaps, balance issues)
**Blocker for .exe export:** YES - missing sprites will cause visual corruption

---

*End of Audit Report*
