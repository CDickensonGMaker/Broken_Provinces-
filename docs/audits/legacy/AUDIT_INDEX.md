# Catacombs of Gore - Combat Audit Documentation Index

## 📋 QUICK NAVIGATION

### START HERE
- **AUDIT_SUMMARY.txt** - 2-minute executive summary with verdict and action items
- **COMBAT_AUDIT_REPORT.md** - Full technical audit with detailed analysis

### ACTION & IMPLEMENTATION
- **AUDIT_ACTION_PLAN.md** - Step-by-step fix instructions with file locations
- **ENEMY_DATA_SCHEMA.md** - Complete field reference for enemy .tres files

### QUICK REFERENCE
- **This File** - Documentation index and navigation

---

## 📊 AUDIT RESULTS AT A GLANCE

| Category | Status | Details |
|----------|--------|---------|
| **Overall System** | ✅ GOOD | Well-architected, no memory leaks |
| **Critical Issues** | ⚠️ 4 FOUND | Missing sprites/icons, boss balance |
| **Blocking .exe Export** | ⚠️ YES | Must fix sprite rendering issues |
| **Files Affected** | 26 | Need updates to enemy definitions |
| **Estimated Fix Time** | ~70 min | 1 hour 10 minutes total |

---

## 🎯 WHAT NEEDS TO HAPPEN

### Priority 1: Visual Rendering (15 min)
**7 enemies are invisible - add sprite_path fields**
- boar.tres
- deer.tres
- tenger_archer.tres
- tenger_shaman.tres
- tenger_warlord.tres
- tenger_raider.tres
- tenger_warrior.tres

See: `AUDIT_ACTION_PLAN.md` → "Action 1: Add Missing sprite_path Fields"

### Priority 2: Boss Balance (5 min)
**2 bosses are too weak - fix HP and level**
- ogre.tres: Change max_hp from 84 to 150
- vampire_lord.tres: Add level = 25 field

See: `AUDIT_ACTION_PLAN.md` → "Action 2: Fix Boss Stats"

### Priority 3: Polish (20 min)
**19 enemies missing icons - add icon_path fields**
- All goblin types
- All skeleton types
- All tenger types
- vampire_lord

See: `AUDIT_ACTION_PLAN.md` → "Action 3: Add Missing icon_path Values"

### Validation (30 min)
**Test fixes before committing**
- Spawn enemies, verify rendering
- Check Ogre takes 8-10 hits to kill
- Open Codex, verify icon display
- Kill enemies, verify loot appears

See: `AUDIT_ACTION_PLAN.md` → "Validation Steps"

---

## 📁 PROJECT FILE LOCATIONS

### Key System Files
```
C:\Users\caleb\CatacombsOfGore\
├── scripts/
│   ├── autoload/
│   │   └── combat_manager.gd          [VERIFIED ✅ - Good memory management]
│   ├── enemies/
│   │   ├── enemy_base.gd              [VERIFIED ✅ - Complete death handling]
│   │   └── enemy_spawner.gd           [VERIFIED ✅ - Within budget]
│   └── data/
│       ├── enemy_data.gd              [Schema root class]
│       ├── enemy_attack_data.gd       [Attack definitions]
│       ├── world_lexicon.gd           [Creature registry - VERIFIED ✅]
├── data/
│   └── enemies/                        [52 .tres files - 26 need fixes]
│       ├── human_bandit.tres           [VERIFIED ✅]
│       ├── ogre.tres                  [⚠️ NEEDS: HP fix]
│       ├── vampire_lord.tres          [⚠️ NEEDS: level field]
│       ├── boar.tres                  [❌ NEEDS: sprite_path + icon_path]
│       ├── deer.tres                  [❌ NEEDS: sprite_path + icon_path]
│       ├── tenger_*.tres              [❌ 5 files need sprite_path + icon_path]
│       └── ... (52 total)
└── dev/
    └── zoo/
        └── zoo_registry.gd            [Documentation - VERIFIED ✅]
```

### Documentation Files (Created by This Audit)
```
C:\Users\caleb\CatacombsOfGore\
├── COMBAT_AUDIT_REPORT.md             [Full technical analysis]
├── AUDIT_ACTION_PLAN.md               [Step-by-step fix guide]
├── AUDIT_SUMMARY.txt                  [Executive summary]
├── ENEMY_DATA_SCHEMA.md               [Field reference documentation]
└── AUDIT_INDEX.md                     [This file]
```

---

## 🔍 WHAT WAS AUDITED

### Systems Checked ✅
- **EnemyBase class** - Inheritance, death handling, memory cleanup
- **Combat manager** - Signal connections, object reference safety, memory leaks
- **Enemy spawner** - Performance budgets, registration
- **All 52 enemy .tres files** - Script references, field validation
- **Loot system** - Table connections, faction logic
- **Registries** - World lexicon, zoo registry completeness

### Issues Found
1. **7 enemies missing sprite_path** - Will render as invisible
2. **19 enemies missing icon_path** - Codex UI broken
3. **1 boss (Ogre) HP too low** - Dies in 3-4 hits instead of 8-10
4. **1 boss (Vampire Lord) missing level** - Stat scaling undefined

### No Issues Found ✅
- Memory leaks
- Signal connection problems
- Script reference errors
- Death handling incomplete
- Loot table wiring
- Combat calculations
- AI state machine logic

---

## 📖 DOCUMENT PURPOSES

### AUDIT_SUMMARY.txt
**Purpose:** Quick overview for non-technical stakeholders
**Read time:** 2-3 minutes
**Contains:**
- What works and what doesn't
- Priority order of fixes
- Timeline estimate
- Verdict (blockers for .exe)

### COMBAT_AUDIT_REPORT.md
**Purpose:** Complete technical analysis with detailed findings
**Read time:** 10-15 minutes
**Contains:**
- Issue breakdown with line numbers
- Analysis of each problem
- Recommendations by priority
- Test checklist
- Evidence and verification

### AUDIT_ACTION_PLAN.md
**Purpose:** Actual implementation guide with code examples
**Read time:** 10 minutes (during fixes: as reference)
**Contains:**
- Exact file paths to edit
- Code samples for each fix
- Step-by-step instructions
- Validation test procedures
- Success criteria

### ENEMY_DATA_SCHEMA.md
**Purpose:** Complete field reference for enemy definitions
**Read time:** 5-10 minutes (reference doc)
**Contains:**
- Field descriptions
- Valid value ranges
- Examples and templates
- Common mistakes
- Audit checklist

### AUDIT_INDEX.md (This File)
**Purpose:** Navigation and quick reference
**Helps with:** Finding specific information quickly

---

## ⚡ COMMON QUESTIONS

### Q: Which files need immediate fixes?
A: The 7 enemies with missing sprite_path. See AUDIT_ACTION_PLAN.md Action 1.

### Q: Can I export the .exe before fixing these?
A: Not recommended. Missing sprites will cause visual bugs. Fix first, then export.

### Q: How long will fixes take?
A: ~70 minutes total (15 min sprites + 5 min boss balance + 20 min icons + 30 min testing)

### Q: Do I need to understand the entire system?
A: No. Just follow AUDIT_ACTION_PLAN.md step by step. It's a checklist.

### Q: What if I miss a field when editing .tres files?
A: Use ENEMY_DATA_SCHEMA.md as reference. It has complete field list and examples.

### Q: Are there any code changes needed?
A: No. All fixes are data only (editing .tres files). No script changes needed.

### Q: Can I commit fixes incrementally?
A: Yes. Commit by issue:
1. First commit: All 7 sprite_path fixes
2. Second commit: All 19 icon_path fixes
3. Third commit: Boss balance fixes

---

## ✅ QUALITY ASSURANCE

### Pre-Fix Checklist
- [ ] Read AUDIT_SUMMARY.txt (understand what's broken)
- [ ] Read ENEMY_DATA_SCHEMA.md (understand field rules)
- [ ] Read AUDIT_ACTION_PLAN.md (understand specific fixes)

### During-Fix Checklist
- [ ] Edit each file exactly as shown in action plan
- [ ] Verify file saved properly
- [ ] Check for typos in field names
- [ ] Maintain consistent indentation

### Post-Fix Validation
- [ ] Launch game
- [ ] Spawn 7 previously invisible enemies - verify visible
- [ ] Spawn Ogre - count hits (should take 8-10, not 3-4)
- [ ] Open Codex - verify all icons display
- [ ] Kill 5+ enemies - verify loot corpses appear
- [ ] Check console for errors (should be none)

### Final Commit
```
git add data/enemies/*.tres
git commit -m "fix(enemies): add missing sprite and icon paths, balance boss HP"
```

---

## 📞 TROUBLESHOOTING

### Problem: Enemy still invisible after fix
**Solution:**
1. Check sprite_path points to actual file (not typo)
2. Check h_frames/v_frames match actual sprite dimensions
3. Verify sprite_pixel_size is in reasonable range (0.01-0.05)

### Problem: Sprite looking wrong size
**Solution:**
- Increase sprite_pixel_size if too small (0.01 → 0.03)
- Decrease sprite_pixel_size if too large (0.05 → 0.03)

### Problem: Boss still dies too fast
**Solution:**
1. Check max_hp was changed to 150 (not 84)
2. Verify file saved
3. Close and reopen game (reload data)

### Problem: Codex showing blank icons
**Solution:**
1. Check icon_path field was added
2. Check path points to valid image file
3. Clear browser cache / force refresh if web-based UI

---

## 📚 REFERENCE LINKS (In This Project)

- **Enemy script:** `C:\Users\caleb\CatacombsOfGore\scripts\enemies\enemy_base.gd`
- **Combat manager:** `C:\Users\caleb\CatacombsOfGore\scripts\autoload\combat_manager.gd`
- **Enemy data schema:** `C:\Users\caleb\CatacombsOfGore\scripts\data\enemy_data.gd`
- **World lexicon:** `C:\Users\caleb\CatacombsOfGore\scripts\data\world_lexicon.gd`
- **Zoo registry:** `C:\Users\caleb\CatacombsOfGore\dev\zoo\zoo_registry.gd`
- **Game design doc:** `C:\Users\caleb\CatacombsOfGore\CLAUDE.md`

---

## 🎓 LEARNING PATH

If you want to understand the system deeply:

1. **Start:** Read AUDIT_SUMMARY.txt (overview)
2. **Learn:** Read ENEMY_DATA_SCHEMA.md (what fields mean)
3. **Understand:** Read COMBAT_AUDIT_REPORT.md (why these issues exist)
4. **Implement:** Follow AUDIT_ACTION_PLAN.md (step by step)
5. **Verify:** Run validation tests (success criteria)
6. **Deep Dive:** Read enemy_base.gd source (how it works)

---

## 📝 NEXT STEPS

1. **Right now:** Read AUDIT_SUMMARY.txt (2 min)
2. **Next:** Read ENEMY_DATA_SCHEMA.md (understand what to change)
3. **Then:** Follow AUDIT_ACTION_PLAN.md exactly (step by step)
4. **Finally:** Run validation tests and commit

---

**Total time to complete all fixes: ~70 minutes**

**Questions? See AUDIT_ACTION_PLAN.md for detailed examples.**

Good luck! 🎮
