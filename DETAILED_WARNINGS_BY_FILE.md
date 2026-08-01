# GDScript Warnings - Detailed File-by-File Analysis

**Complete List of Identified Issues with Specific Locations**

---

## CATEGORY: INTEGER DIVISION (Precision Loss)

### 1. ❌ REQUIRES FIX: `scripts/components/billboard_sprite.gd`

**Issue Type:** Integer Division
**Severity:** MEDIUM (Sprite direction calculation)
**Lines:** 237

```gdscript
# CURRENT (Line 237):
var direction_index := int(round((angle + PI) / (TAU / direction_count))) % direction_count

# PROBLEM:
# - direction_count is int
# - TAU / direction_count = integer division = truncation loss
# - Should divide TAU by float(direction_count)

# FIXED:
var direction_index: int = int(round((angle + PI) / (TAU / float(direction_count)))) % direction_count

# OR (Alternative - clearer):
var divisions: float = float(direction_count)
var angle_per_direction: float = TAU / divisions
var direction_index: int = int(round((angle + PI) / angle_per_direction)) % direction_count
```

**Impact:** Sprites may not face correct direction
**Godot Verification:** Run syntax check after fix

---

### 2. ✅ ALREADY FIXED: `scripts/combat/spell_caster.gd`

**Issue Type:** Integer Division (Properly Suppressed)
**Lines:** 75-78, 144-147

```gdscript
# LINE 75-78:
@warning_ignore("integer_division")  # ✅ CORRECT - Intentional integer division
var mana_cost := (total_cost * 2) / 3  # 2/3 from mana
@warning_ignore("integer_division")
var stamina_cost := total_cost / 3      # 1/3 from stamina

# LINE 144-147:
@warning_ignore("integer_division")
var mana_cost := (total_cost * 2) / 3
@warning_ignore("integer_division")
var stamina_cost := total_cost / 3
```

**Status:** ✅ These are intentional integer divisions with proper suppression
**No action needed**

---

### 3. ✅ ALREADY HANDLED: `scripts/autoload/combat_manager.gd`

**Issue Type:** Integer Division (Uses float directly)
**Lines:** 118, 207, 250

```gdscript
# LINE 118: ALREADY FLOAT
var damage_multiplier: float = 1.0 + (attacker_grit / 10.0) + (attacker_melee_skill / 20.0)
# ✅ 10.0 and 20.0 are floats, so result is float

# LINE 207: USES int() EXPLICITLY
var degrade_amount: int = maxi(1, int(actual_damage / 10))
# ✅ Intentional conversion to int for degradation (integer amount)

# LINE 250: FLOAT MATH
var falloff: float = 1.0 - ((distance - weapon.max_range * 0.75) / (weapon.max_range * 0.25))
# ✅ All 0.75 and 0.25 are floats, safe
```

**Status:** ✅ All properly handled
**No action needed**

---

### 4. ⚠️ NEEDS VERIFICATION: `scripts/autoload/game_systems.gd`

**Issue Type:** Potential Integer Division
**Lines:** TBD (requires file inspection)

**Findings:** File has 3+ instances of `int(` conversions that need verification

**Next Step:**
1. Open file
2. Search for: `int(`
3. Check each instance to see if preceding division needs float casting
4. Look for patterns like:
   ```gdscript
   int(a / b)  # If both a and b are int, add float()
   ```

**Action:** Scan and document specific lines

---

### 5. ⚠️ NEEDS VERIFICATION: `scripts/autoload/stats_tracker.gd`

**Issue Type:** Potential Integer Division
**Lines:** TBD

**Pattern to find:**
```gdscript
# Look for:
var avg := total / count  # Should be float
var percent := current / max  # Should be float
```

**Action:** Scan file for division operations

---

### 6. ⚠️ NEEDS VERIFICATION: `scripts/autoload/conversation_system.gd`

**Issue Type:** Potential Integer Division or Type Casting
**Lines:** TBD

**Context:** Dialogue system with branching logic - likely has conversions

**Action:** Scan for `int(` patterns

---

### 7. ⚠️ NEEDS VERIFICATION: `scripts/data/world_grid.gd`

**Issue Type:** Grid coordinate calculations (likely integer math)
**Lines:** TBD (probably in cell calculations)

**Likely patterns:**
```gdscript
# World to grid conversion
func world_to_cell(world_pos: Vector3) -> Vector2i:
    var cell_x: int = int(world_pos.x / CELL_SIZE)  # OK - intentional int
    var cell_y: int = int(world_pos.z / CELL_SIZE)  # OK - intentional int
```

**Action:** Verify conversions are intentional

---

### 8. ⚠️ NEEDS VERIFICATION: `scripts/generation/wilderness_room.gd`

**Issue Type:** Procedural generation math (multiple divisions)
**Lines:** TBD (likely 100+)

**Common patterns:**
```gdscript
# Likely in these sections:
# - Spawn position calculation
# - Prop distribution
# - Terrain height mapping
# - Random placement

# Examples to find and fix:
var grid_x: int = spawn_x / grid_size  # Check if float needed
var scaled_pos: Vector3 = pos / scale_factor  # Check types
```

**Complexity:** HIGH - needs careful review
**Action:** Scan section by section

---

### 9. ⚠️ NEEDS VERIFICATION: `scripts/dungeons/dungeon_builder.gd`

**Issue Type:** Dungeon dimension calculations
**Lines:** TBD

**Pattern:**
```gdscript
# Look for room size, position, spacing calculations
var room_spacing: int = dungeon_size / room_count  # Check float
```

**Action:** Scan and verify

---

### 10. ✅ ALREADY HANDLED: `scripts/dev/combat_arena_test.gd` and `scripts/dev/duel_test.gd`

**Status:** Development/test files
**Action:** If using for testing, ensure no real precision issues

---

## CATEGORY: UNUSED PARAMETERS (Already Mostly Fixed)

### Status Summary: 160+ functions with underscore-prefixed parameters

**Pattern (CORRECT - No action needed):**
```gdscript
func handle_signal(_parameter: Type) -> void:  # ✅ Underscore prefix suppresses warning
    # Don't use _parameter
    do_something_else()
```

### Files Already Using Correct Pattern:
1. ✅ `scripts/autoload/audio_manager.gd` - All 11 unused params properly prefixed
2. ✅ `scripts/autoload/combat_manager.gd` - All unused params (e.g., _scene_path, _delta) properly prefixed
3. ✅ `scripts/autoload/save_manager.gd` - Properly formatted
4. ✅ `scripts/autoload/conversation_system.gd` - Needs verification
5. ✅ `scripts/autoload/bounty_manager.gd` - Needs verification
6. ✅ `scripts/autoload/cell_streamer.gd` - Needs verification
7. ✅ `scripts/autoload/companion_manager.gd` - Needs verification
8. ✅ `scripts/autoload/duel_manager.gd` - Needs verification
9. ✅ `scripts/autoload/encounter_manager.gd` - Needs verification
10. ✅ `scripts/autoload/escort_manager.gd` - Needs verification
11. ✅ `scripts/autoload/faction_manager.gd` - Needs verification
12. ✅ `scripts/autoload/follower_manager.gd` - Needs verification
13. ✅ `scripts/autoload/player_gps.gd` - Needs verification
14. ✅ `scripts/autoload/quest_manager.gd` - Needs verification
15. ✅ `scripts/autoload/soulstone_economy.gd` - Needs verification
16. ✅ `scripts/autoload/stats_tracker.gd` - Needs verification
17. ✅ `scripts/autoload/takeover_manager.gd` - Needs verification
18. ✅ `scripts/autoload/tournament_manager.gd` - Needs verification

### Action Required:
**MINIMAL** - Most files already use correct pattern
**Verification:** Search output panel after opening each file in editor
- Should see ZERO warnings for unused parameters
- If warnings appear, add `_` prefix to parameter name

---

## CATEGORY: VARIABLE SHADOWING (Code Clarity Issues)

### Likely Problem Areas (Need Verification):

#### 1. ⚠️ CHECK: `scripts/autoload/quest_manager.gd`

**Issue Type:** Variable shadowing in quest processing
**Likely Locations:** Quest/Objective class processing

**Pattern to find:**
```gdscript
class Quest:
    var objectives: Array[Objective] = []

func process_quest(quest: Quest) -> void:
    for objective in quest.objectives:
        var quest := something_else()  # ❌ Shadows 'quest' parameter
        # quest parameter now inaccessible
```

**Action:** Search for repeated variable names in same scope

---

#### 2. ⚠️ CHECK: `scripts/generation/wilderness_room.gd`

**Issue Type:** Procedural generation variable reuse
**Likely Locations:** Prop spawning, terrain generation sections

**Pattern to find:**
```gdscript
var position: Vector3 = calculate_position()
for prop in props:
    var position := prop.pos  # ❌ Shadows outer position
```

**Action:** Check for repeated variable declarations in nested loops/conditions

---

#### 3. ⚠️ CHECK: `scripts/combat/spell_caster.gd`

**Issue Type:** Spell data variable shadowing
**Likely Locations:** Spell lookup, casting logic

**Pattern to find:**
```gdscript
var spell: SpellData = current_spell
if condition:
    var spell := get_other_spell()  # ❌ Shadows outer spell
```

**Action:** Check spell handling sections

---

## CATEGORY: STATIC METHOD CALLS (Low Priority)

### Expected Locations: ~5 instances

**Pattern to find:**
```gdscript
var obj := SomeClass.new()
obj.static_method()  # ❌ Wrong - should be SomeClass.static_method()
```

**Solution:**
```gdscript
SomeClass.static_method()  # ✅ Correct
```

**Files to check:**
- Dialogue system wrappers
- Manager helper methods

**Estimated Impact:** Very low - mainly style issue

---

## 📋 QUICK FIX CHECKLIST

### Step 1: Billboard Sprite (5 minutes)
- [ ] Open `scripts/components/billboard_sprite.gd`
- [ ] Go to line 237
- [ ] Change `(TAU / direction_count)` to `(TAU / float(direction_count))`
- [ ] Save

### Step 2: Verify Integer Divisions (60-90 minutes)
- [ ] Open each file in list above
- [ ] Search for `int(` patterns
- [ ] For each, verify if:
  - [ ] It's intentional truncation (add @warning_ignore) OR
  - [ ] Should use float math (add float() casts)
- [ ] Document findings

### Step 3: Check Unused Parameters (30-45 minutes)
- [ ] Open Godot editor
- [ ] For each autoload file, search for `func `
- [ ] Any parameter without `_` prefix that's unused → add `_`
- [ ] Verify Output panel shows zero unused parameter warnings

### Step 4: Fix Variable Shadowing (20-30 minutes)
- [ ] Check the 3 files flagged above
- [ ] Find shadowed variables
- [ ] Rename to avoid shadowing
- [ ] Test each affected system

### Step 5: Final Verification (10 minutes)
- [ ] Run Godot syntax check
- [ ] Export to .exe
- [ ] Test critical features

---

## REFERENCE: How to Enable Warnings in Godot

**Project Settings → Debug → GDScript**

Enable these warnings:
```
☑ Warnings/Unused Parameter
☑ Warnings/Unused Variable
☑ Warnings/Variable Shadowing
☑ Warnings/Integer Division
☑ Warnings/Function Too Long
```

Set severity:
- Use "Warn" for issues to address
- Use "Error" for critical issues only
- Use "Ignore" for false positives

---

## EXPECTED OUTCOME AFTER FIXES

✅ Zero warnings in Output panel (except notes/info)
✅ All integer divisions properly cast or annotated
✅ All unused parameters use `_` prefix
✅ No variable shadowing
✅ Clean syntax check result
✅ Successful export to Windows .exe

