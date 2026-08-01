# GDScript Warnings - Priority Fix Guide

**Quick Reference for the Top Issues Preventing Clean Export**

---

## 🎯 CRITICAL FIXES (Before Export)

### Fix #1: Integer Division in billboard_sprite.gd
**File:** `C:\Users\caleb\CatacombsOfGore\scripts\components\billboard_sprite.gd`
**Line:** 237
**Warning:** Integer division

**Current Code:**
```gdscript
var direction_index := int(round((angle + PI) / (TAU / direction_count))) % direction_count
```

**Fixed Code:**
```gdscript
var direction_index: int = int(round((angle + PI) / (TAU / float(direction_count)))) % direction_count
```

**Why:** `direction_count` is an int, so `TAU / direction_count` performs integer division. Cast to float first.
**Time:** 1 minute
**Impact:** Prevents incorrect sprite direction calculation

---

### Fix #2: Verify All Integer Division Warnings
**Files Needing Check:**
1. `scripts/autoload/game_systems.gd`
2. `scripts/autoload/stats_tracker.gd`
3. `scripts/autoload/conversation_system.gd`
4. `scripts/data/world_grid.gd`
5. `scripts/dev/combat_arena_test.gd`
6. `scripts/dev/duel_test.gd`
7. `scripts/dungeons/dungeon_builder.gd`
8. `scripts/generation/wilderness_room.gd`

**How to Find:**
```gdscript
# Look for patterns like:
int(some_int / some_int)  # Without @warning_ignore
some_int / some_int       # Result used as int
```

**Quick Fix Template:**
```gdscript
# BEFORE:
var result := value / divisor

# AFTER (if result should be int):
@warning_ignore("integer_division")
var result: int = value / divisor

# OR (if result should be float):
var result: float = value / float(divisor)
```

**Time per file:** 5-10 minutes
**Total Time:** 45-90 minutes

---

## 🟠 HIGH PRIORITY (Cleanup)

### Fix #3: Unused Parameters in Autoload Files
**Issue:** ~160 functions have unused parameters (but most are already prefixed with `_`)

**Quick Verification:**
```bash
# In Godot Editor → Output panel, filter by "unused"
# Look for lines like:
[SCRIPT] Error in script res://scripts/autoload/XXX.gd:
Line 42: Unused parameter 'param_name'
```

**Files to Audit:**
- `scripts/autoload/bounty_manager.gd`
- `scripts/autoload/cell_streamer.gd`
- `scripts/autoload/companion_manager.gd`
- `scripts/autoload/conversation_system.gd`
- `scripts/autoload/duel_manager.gd`
- `scripts/autoload/encounter_manager.gd`
- `scripts/autoload/escort_manager.gd`
- `scripts/autoload/faction_manager.gd`
- `scripts/autoload/follower_manager.gd`
- `scripts/autoload/player_gps.gd`
- `scripts/autoload/quest_manager.gd`
- `scripts/autoload/soulstone_economy.gd`
- `scripts/autoload/stats_tracker.gd`
- `scripts/autoload/takeover_manager.gd`
- `scripts/autoload/tournament_manager.gd`

**Fix Pattern:**
```gdscript
# BEFORE (Generates Warning):
func handle_event(data: Dictionary, unused_context: String) -> void:
    process_data(data)

# AFTER (No Warning):
func handle_event(data: Dictionary, _unused_context: String) -> void:
    process_data(data)
```

**Time per file:** 2-5 minutes
**Total Time:** 30-75 minutes

---

## 🟡 MEDIUM PRIORITY (Code Quality)

### Fix #4: Variable Shadowing
**Issue:** Local variables shadow parameters or outer scope variables

**Look For:**
```gdscript
func process(item: Item) -> void:
    if condition:
        var item := get_new_item()  # ❌ Shadows 'item' parameter
        # Now the parameter is inaccessible
```

**Fix:**
```gdscript
func process(item: Item) -> void:
    if condition:
        var new_item := get_new_item()  # ✅ Different name
        process_item(new_item)
```

**Files Most Likely to Have Issues:**
1. `scripts/autoload/quest_manager.gd` - Quest/Objective processing
2. `scripts/generation/wilderness_room.gd` - Procedural generation
3. `scripts/combat/spell_caster.gd` - Spell variable naming

**How to Find:**
- Open file in Godot editor
- Go to Project Settings → Debug → GDScript → "Warnings/Variable Shadowing"
- Set to "Warn" (not "Ignore")
- Code will be highlighted

**Time per file:** 5-10 minutes
**Total Time:** 20-40 minutes

---

## 🟢 LOW PRIORITY (Style)

### Fix #5: Static Method Calls
**Issue:** Calling static methods on instances

**Example:**
```gdscript
# WRONG:
var instance := SomeClass.new()
instance.static_method()

# RIGHT:
SomeClass.static_method()
```

**Expected Occurrences:** ~5 throughout codebase
**Impact:** Minimal - mainly code clarity
**Time:** 5-10 minutes

---

## 📋 Execution Checklist

### Phase 1: Critical Fixes (15-20 minutes)
- [ ] Fix `billboard_sprite.gd` line 237
- [ ] Create list of integer division warnings via Godot

### Phase 2: Integer Division Audit (45-90 minutes)
- [ ] Check `scripts/autoload/game_systems.gd`
- [ ] Check `scripts/autoload/stats_tracker.gd`
- [ ] Check `scripts/autoload/conversation_system.gd`
- [ ] Check `scripts/data/world_grid.gd`
- [ ] Check `scripts/dev/` files
- [ ] Check `scripts/dungeons/dungeon_builder.gd`
- [ ] Check `scripts/generation/wilderness_room.gd`
- [ ] Apply fixes to all files

### Phase 3: Unused Parameters (30-75 minutes)
- [ ] Audit all 15 autoload files
- [ ] Add `_` prefix to any remaining unused parameters
- [ ] Verify no warnings in Output panel

### Phase 4: Code Quality (20-40 minutes)
- [ ] Check quest_manager.gd for shadowing
- [ ] Check wilderness_room.gd for shadowing
- [ ] Check spell_caster.gd for shadowing
- [ ] Rename shadowed variables

### Phase 5: Final Verification (15-20 minutes)
- [ ] Run Godot syntax check: `godot --check-only`
- [ ] Export to Windows .exe
- [ ] Test critical systems:
  - [ ] Combat works (damage, spells)
  - [ ] Quest system works
  - [ ] NPCs spawn and animate
  - [ ] Wilderness rooms generate
  - [ ] No console errors/warnings

---

## 🚀 Quick Export Readiness Check

Run this in Godot Editor console to catch major issues:

```gdscript
# Project Settings → Debug → GDScript Console
# Paste after export:

# 1. Check script count
var scripts_checked: int = 0
var warnings_found: int = 0

# 2. Run syntax check via command line:
# Windows:
godot --check-only --script res://scripts/autoload/

# 3. Look for in Output panel:
# - "unused parameter"
# - "variable shadowing"
# - "integer division"
```

**Success Criteria:**
- [ ] Zero critical warnings blocking export
- [ ] All integer division marked with @warning_ignore or cast to float
- [ ] All unused parameters prefixed with _
- [ ] No variable shadowing issues
- [ ] Export completes without errors
- [ ] .exe runs without crashing

---

## 📊 Summary

| Phase | Time | Files | Critical? |
|-------|------|-------|-----------|
| Fix billboard_sprite | 5 min | 1 | YES |
| Integer division audit | 60-90 min | 8 | YES |
| Unused parameters | 45-75 min | 15 | OPTIONAL |
| Shadowing fixes | 20-40 min | 3 | OPTIONAL |
| Static calls | 5-10 min | Various | NO |
| **Total** | **2-4 hours** | **~30** | **Varies** |

**Minimum to Export:** Phases 1-2 (75-110 minutes)
**Complete Cleanup:** All phases (2-4 hours)

---

## Common Errors & Fixes

### Error: "Trying to cast a freed object"
**Solution:** Already fixed in combat_manager.gd - Good!
**Files affected:** None (properly cleaned on scene change)

### Error: "Unknown function: xyz"
**Solution:** Check preload paths in that file
**Files to check:** Spell files, dialogue files

### Warning: "Integer division"
**Solution:** See Fix #2 above - Use float() cast or @warning_ignore

### Warning: "Variable shadowing"
**Solution:** See Fix #4 above - Rename local variable

---

## Next Steps After Fixes

1. Save all modified files
2. Close and reopen Godot editor
3. Check Output panel - should be clean
4. Run project - no console errors
5. Export to Windows .exe
6. Test .exe on clean Windows machine (if possible)
7. Play through to main quests to verify stability

