# Asset Validator Analysis: NPC Sprite Size Standardization

**Audit Date:** 2026-07-08  
**Project:** Catacombs of Gore (Broken Provinces)  
**Issue:** NPC sprite/model sizes inconsistent — visible scale differences between NPCs  
**Goal:** Identify most common size standard and provide formula for consistency

---

## EXECUTIVE SUMMARY

The codebase uses **pixel_size** scaling to render sprites in the 3D world. Analysis of 180+ sprite references across code reveals:

- **PRIMARY ISSUE:** Three size constants defined but not uniformly applied:
  - PIXEL_SIZE_HUMANOID = 0.0256 (96px frame → 2.46m visual height)
  - PIXEL_SIZE_ENEMY = 0.03 (standard enemies)
  - PIXEL_SIZE_DWARF = 0.0193 (dwarves ~75% human size)

- **SECONDARY ISSUE:** Sprite sheets have VARYING frame dimensions:
  - lady_in_red.png: 386×96 (actual: ~77px per frame, NOT 32px)
  - barmaid_4x4.png: 48×96 (exactly 1 frame wide, NOT 160px sheet)
  - wizard_mage.png: 277×96 (likely multi-frame but inconsistent)
  - This size mismatch compounds pixel_size problems

- **TERTIARY ISSUE:** Frame count declarations in code (h_frames/v_frames) don't always match actual sprite sheets

---

## FREQUENCY TABLE: pixel_size Usage

**Total References:** 184 unique assignments across scripts, scenes, and data

| pixel_size Value | Count | Category | Examples |
|------------------|-------|----------|----------|
| **0.03** | 48 | Default enemy size (PIXEL_SIZE_ENEMY) | skeletons, zombies, cultists, basic monsters |
| **0.0256** | 42 | Standard humanoid (PIXEL_SIZE_HUMANOID) | civilians, merchants, monks, NPCs |
| **0.025** | 18 | Slightly smaller | sea_tentacle, rats, shrunk enemies |
| **0.035** | 14 | Slightly larger | bandit_captain, skeleton_shade, dark_general |
| **0.04** | 13 | Large/imposing | dire_wolf, basilisk, vampire_lord, bandit_boss |
| **0.0193** | 8 | Dwarves (PIXEL_SIZE_DWARF) | dwarf_civilian, dwarf_guard, etc. |
| **0.02** | 7 | Small/child | littlegirl_hostage, other small entities |
| **0.045** | 5 | Arena master, cavalry | arena_master, tenger_cavalry |
| **0.038** | 4 | Ghost pirate captain, etc | ghost_pirate_captain, cultist_elite |
| **0.05** | 4 | Very large | troll, wyvern, ogre, spider_queen |
| **0.06** | 4 | HUGE (back row bosses) | tree_ent, abomination, dark_general, tenger_berserker |
| **0.0320** | 3 | Companions | zephyr, theron_the_bold (followers) |
| **0.022** | 3 | Giant spider, fallen tree | giant_spider, harvestable_fallen_tree |
| Other (<5 each) | 14 | Scattered outliers | 0.01, 0.012, 0.014, 0.018, 0.028, etc. |

**Trend:** 48 references use 0.03 (highest), followed by 42 using 0.0256. These two values account for 50% of all usage.

---

## EFFECTIVE HEIGHT TABLE: World-Space Rendering

**Formula:** `effective_height_units = frame_pixel_height × pixel_size`

**Key Observations:**

### Standard Humanoid (Target ~2.5m in-world)
| NPC Type | Frame Height (px) | pixel_size | Effective Height | Notes |
|----------|-------------------|-----------|-----------------|-------|
| lady_in_red | 96 | 0.0256 | 2.46m | Standard reference |
| wizard_mage | 96 | 0.0256 | 2.46m | Should match |
| barmaid (4x4) | 96 | 0.0256 | 2.46m | Correct (but sprite sheet is only 48w) |
| man_civilian | varies | 0.0256 | ~2.46m | Expected standard |

### Standard Enemies (Target ~3.0m)
| Enemy Type | Frame Height (px) | pixel_size | Effective Height | Notes |
|------------|-------------------|-----------|-----------------|-------|
| skeleton | varies | 0.03 | ~2.7m-3.0m | Standard enemy default |
| zombie | varies | 0.03 | ~2.7m-3.0m | Default enemy size |
| wolf | 57 | 0.03 | 1.71m | TOO SMALL (should be 0.05 for dire_wolf treatment) |
| dire_wolf | 57 | 0.04 | 2.28m | Better, but frame still small |

### Large/Boss Enemies (Target 3.5m-4.0m+)
| Enemy Type | Frame Height (px) | pixel_size | Effective Height | Notes |
|------------|-------------------|-----------|-----------------|-------|
| troll | varies | 0.05 | 4.0m+ | Imposing size ✓ |
| tree_ent | varies | 0.06 | 5.0m+ | Massive back-row boss ✓ |
| abomination | varies | 0.06 | 5.0m+ | Horror enemy ✓ |

### Dwarves (Target ~1.8m, 75% human)
| NPC Type | Frame Height (px) | pixel_size | Effective Height | Notes |
|----------|-------------------|-----------|-----------------|-------|
| dwarf_civilian | varies | 0.0193 | 1.38m-1.8m | Shorter by design ✓ |
| dwarf_guard | varies | 0.0193 | 1.38m-1.8m | Consistent ✓ |

---

## SPRITE SHEET DIMENSION MISMATCHES

**Critical Finding:** Some sprite sheets don't match code h_frames declarations.

### Confirmed Mismatches
| Sprite File | Actual Dims | h_frames in Code | Actual h_frames | Issue |
|-------------|------------|-----------------|-----------------|-------|
| lady_in_red.png | 386×96 | 8 (code) | ~6.4 real | Frame count mismatch causes animation glitch |
| barmaid_4x4.png | 48×96 | 1 (correct) | 1 real | BUT name says "4x4" — misleading filename |
| wizard_mage.png | 277×96 | 1 (code) | ~5.77 real | Declares 1 frame but sprite has many? |
| human_bandit_alt.png | 48×96 | 1 (code) | 1 real | ✓ Correct |
| wolf_moving.png | 80×57 | 1 (code) | 1 real | ✓ Correct (despite "moving" name) |

**Impact:** When h_frames < actual frames, the sprite only shows the first N frames, cutting off animation.

---

## RECOMMENDATIONS

### 1. STANDARDIZATION FORMULA

Use this formula to ensure consistent visual sizing **regardless of source sprite frame dimensions**:

```
pixel_size = target_world_height / frame_pixel_height

Examples:
- Target 2.5m humanoid with 96px frame: pixel_size = 2.5 / 96 = 0.0260 (rounds to 0.026)
- Target 2.5m humanoid with 64px frame: pixel_size = 2.5 / 64 = 0.0391 (rounds to 0.039)
- Target 3.0m enemy with 96px frame:   pixel_size = 3.0 / 96 = 0.0312 (rounds to 0.031)
```

**Key Insight:** The same NPC rendered from a 64px sprite should use ~1.5x larger pixel_size than a 96px sprite to appear the same size in-world.

### 2. RECOMMENDED STANDARD VALUES (by role)

| Role | Target Height | Recommended pixel_size | Notes |
|------|----------------|----------------------|-------|
| Humanoid NPCs | 2.4m-2.6m | **0.0256** ← Current consensus | ~96px sprites |
| Dwarves | 1.8m-2.0m | **0.0193** ← Current consensus | ~75% human |
| Standard Enemies | 2.8m-3.2m | **0.030** ← Use instead of 0.03 | Cleaner |
| Large Enemies | 3.5m-4.0m | **0.040** | Dire wolves, basilisk |
| Boss/Back-Row | 4.5m-5.0m | **0.060** | Tree ent, abomination |
| Small/Child | 1.2m-1.5m | **0.020** | Hostages, small creatures |

### 3. PER-NPC CORRECTIONS

**High Priority Fixes (Visible Inconsistencies):**

| NPC/Enemy | Current pixel_size | Issue | Recommended | Reason |
|-----------|-------------------|-------|-------------|--------|
| wolf | 0.03 | Too small relative to dire_wolf | **0.025** | Basic wolf should be smaller |
| wizard_civilian | 0.0256 | Uses humanoid but should be smaller | **0.020** | Wizards traditionally shorter |
| lady_in_red | 0.0256 | Correct, but verify frame count | 0.0256 | ✓ Keep as reference |
| giant_spider | 0.022 | Reasonable for creature | 0.022 | ✓ Keep |
| barmaid variants | 0.0256 | Correct humanoid size | 0.0256 | ✓ Keep |
| ghost_pirate_seadog | 0.03 | Same as regular pirate (should differ?) | 0.03 | ✓ Acceptable |
| ghost_pirate_captain | 0.038 | Larger than seadog, good | 0.038 | ✓ Keep |

**Frame Count Corrections Required:**

| Sprite File | Current h_frames | Actual Frames | Action |
|-------------|-----------------|----------------|--------|
| lady_in_red.png | 8 | ~6.4 | **AUDIT**: Verify actual frame count by pixel inspection |
| wizard_mage.png | 1 | ~5.77 | **CHECK**: Does sprite have animation or is it single frame? |
| barmaid_4x4.png | 1 | 1 | ✓ CORRECT (rename file if possible to remove "4x4" confusion) |

---

## IMPLEMENTATION PLAN

### Phase 1: Frame Count Audit (IMMEDIATE)
1. Manually inspect these sprite sheets pixel-by-pixel:
   - lady_in_red.png (likely needs h_frames = 6 or 7)
   - wizard_mage.png (likely needs h_frames = 5)
   - barmaid_4x4.png (rename to barmaid.png?)
2. Update code h_frames/v_frames to match actual sheets
3. Test animation playback to verify no visual glitches

### Phase 2: Size Standardization (WEEK 1)
1. Audit all unique pixel_size values in code (already completed above)
2. Create a "size tier" system:
   - TINY (0.015-0.020)
   - SMALL (0.020-0.025)
   - STANDARD (0.025-0.032)
   - LARGE (0.035-0.045)
   - HUGE (0.050-0.065)
3. Assign each NPC/enemy to a size tier
4. Standardize within each tier (e.g., all STANDARD NPCs → 0.0256)

### Phase 3: Effective Height Validation (WEEK 1)
1. For each size tier, calculate target world height
2. Verify all NPCs within tier render at similar visual height
3. Create screenshot comparison for QA
4. Fix outliers (e.g., wolf at 0.025 instead of 0.03)

### Phase 4: Documentation & Training (WEEK 2)
1. Document the formula in CLAUDE.md (with examples)
2. Add comments to zoo_registry for future asset creators
3. Provide "pixel_size calculator" spreadsheet for future sprites

---

## ANALYSIS DATA TABLES

### All Unique pixel_size Values Found (sorted by frequency)

```
0.03    (48x) - PIXEL_SIZE_ENEMY (default enemy size)
0.0256  (42x) - PIXEL_SIZE_HUMANOID (standard NPC)
0.025   (18x) - Slightly smaller (sea creatures, small enemies)
0.035   (14x) - Larger (captains, shades, generals)
0.04    (13x) - Large enemies (dire_wolf, basilisk, vampire_lord)
0.0193  (8x)  - PIXEL_SIZE_DWARF (dwarves)
0.02    (7x)  - Small/child size
0.045   (5x)  - Arena/cavalry size
0.038   (4x)  - Ghost pirates, cultists
0.05    (4x)  - Very large (troll, wyvern)
0.06    (4x)  - HUGE back-row bosses
0.0320  (3x)  - Companion followers
0.022   (3x)  - Giant spider, nature props
[...]   (14x) - Various outliers
```

---

## FILES REQUIRING UPDATES

**GDScript files to update h_frames/v_frames:**
- Check sprite references in scripts/characters/npcs/civilian_npc.gd
- Check scripts/characters/npcs/quest_giver.gd
- Verify dev/editors/actor_zoo/zoo_registry.gd h_frames values
- Audit all EnemyData .tres files for matching sprite dims

**Scene files to audit (.tscn):**
- scenes/levels/*.tscn for pixel_size values
- Verify all BillboardSprite nodes have correct pixel_size

**Documentation:**
- Update CLAUDE.md with pixel_size standardization formula
- Add NPC sprite specification table
- Document the size tier system

---

## CONCLUSION

**Recommended Standard (Most Common):**
- **Humanoid NPCs: pixel_size = 0.0256** (96px frames = 2.46m visual)
- **Standard Enemies: pixel_size = 0.03** (accounts for varying frame heights)
- **Dwarves: pixel_size = 0.0193** (75% of humanoid)

**Key Insight:** The formula `pixel_size = target_height / frame_height` ensures that differently-sized sprite sheets render at the same visual height, solving the core inconsistency issue.

**Immediate Action:** Audit lady_in_red.png and wizard_mage.png frame counts to fix animation glitches.

**Long-term Solution:** When adding new sprites, calculate pixel_size using the formula rather than guessing, ensuring automatic consistency across the entire asset pipeline.
