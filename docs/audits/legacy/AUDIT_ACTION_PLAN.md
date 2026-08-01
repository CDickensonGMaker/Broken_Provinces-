# COMBAT AUDIT - ACTION PLAN

## IMMEDIATE ACTIONS (DO FIRST - Critical Path)

### Action 1: Add Missing sprite_path Fields (7 files)

These enemies WILL NOT RENDER without sprite_path:

**File 1:** `C:\Users\caleb\CatacombsOfGore\data\enemies\boar.tres`
```
Add after line 80 (before current icon_path):
sprite_path = "res://assets/sprites/enemies/boar.png"
attack_sprite_path = ""
sprite_hframes = 1
sprite_vframes = 1
sprite_pixel_size = 0.03
```

**File 2:** `C:\Users\caleb\CatacombsOfGore\data\enemies\deer.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/deer.png"
attack_sprite_path = ""
sprite_hframes = 1
sprite_vframes = 1
sprite_pixel_size = 0.03
```

**File 3:** `C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_archer.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/tengers/tenger_archer.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 2
sprite_pixel_size = 0.025
```

**File 4:** `C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_shaman.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/tengers/tenger_shaman.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 2
sprite_pixel_size = 0.025
```

**File 5:** `C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warlord.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/tengers/tenger_warlord.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 2
sprite_pixel_size = 0.025
```

**File 6:** `C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_raider.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/tengers/tenger_raider.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 2
sprite_pixel_size = 0.025
```

**File 7:** `C:\Users\caleb\CatacombsOfGore\data\enemies\tenger_warrior.tres`
```
Add after line 80:
sprite_path = "res://assets/sprites/enemies/tengers/tenger_warrior.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 2
sprite_pixel_size = 0.025
```

---

### Action 2: Fix Boss Stats (2 files)

**File 1:** `C:\Users\caleb\CatacombsOfGore\data\enemies\ogre.tres`
- **Line 68:** Change `max_hp = 84` to `max_hp = 150`
- **Reason:** Bosses should survive 8-10 hits minimum, not 3-4

**File 2:** `C:\Users\caleb\CatacombsOfGore\data\enemies\vampire_lord.tres`
- **Line 92:** Add `level = 25` BEFORE `max_hp = 300`
- **Reason:** Missing level field breaks stat scaling formula

**Correct order for vampire_lord.tres (lines 88-108):**
```tres
[resource]
script = ExtResource("1")
id = "vampire_lord"
display_name = "Vampire Lord"
description = "An ancient vampire of terrifying power..."
level = 25
min_level = 20
max_level = 40
max_hp = 300
armor_value = 14
```

---

## SECONDARY ACTIONS (Do Next - Polish)

### Action 3: Add Missing icon_path Values (19 files)

These files need icon_path for the Codex to display properly:

**Files to update (add `icon_path` field after `scale` or at end):**

1. `boar.tres` - Add: `icon_path = "res://assets/sprites/enemies/boar.png"`
2. `deer.tres` - Add: `icon_path = "res://assets/sprites/enemies/deer.png"`
3. `goblin_soldier.tres` - Add: `icon_path = "res://assets/sprites/enemies/goblins/goblin_sword.png"`
4. `goblin_archer.tres` - Add: `icon_path = "res://assets/sprites/enemies/goblins/goblin_archer.png"`
5. `goblin_leader.tres` - Add: `icon_path = "res://assets/sprites/enemies/goblins/goblin_leader.png"`
6. `goblin_mage.tres` - Add: `icon_path = "res://assets/sprites/enemies/goblins/goblin_mage.png"`
7. `goblin_warboss.tres` - Add: `icon_path = "res://assets/sprites/enemies/goblins/goblin_warboss.png"`
8. `skeleton_warrior.tres` - Add: `icon_path = "res://assets/sprites/enemies/undead/skeleton.png"`
9. `skeleton_shade.tres` - Add: `icon_path = "res://assets/sprites/enemies/undead/skeleton_shade.png"`
10. `tenger_archer.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_archer.png"`
11. `tenger_cavalry.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_cavalry.png"`
12. `tenger_infantry.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_infantry.png"`
13. `tenger_raider.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_raider.png"`
14. `tenger_berserker.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_berserker.png"`
15. `tenger_shaman.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_shaman.png"`
16. `tenger_warbanner.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_warbanner.png"`
17. `tenger_warlord.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_warlord.png"`
18. `tenger_warrior.tres` - Add: `icon_path = "res://assets/sprites/enemies/tengers/tenger_warrior.png"`
19. `vampire_lord.tres` - Add: `icon_path = "res://assets/sprites/enemies/vampire_lord.png"`

---

## VALIDATION STEPS

After applying fixes, run these tests:

### Test 1: Visual Rendering
1. Launch game
2. Spawn boar, deer, and all tenger enemies (use console or level script)
3. Verify each enemy displays a sprite (not invisible or placeholder mesh)
4. Verify sprites are correct size and centered

### Test 2: Boss Balance
1. Spawn Ogre (level 15 boss)
2. Attack with baseline player damage (~20 per hit)
3. Count hits needed to kill
4. **Expected:** 8-10 hits (150 HP / 20 damage = 7.5 hits)
5. **Current:** ~4 hits (84 HP / 20 damage = 4.2 hits) ❌

1. Spawn Vampire Lord
2. Check that stat scaling works (has a level value)
3. Verify combat feels appropriately difficult

### Test 3: Codex Integration
1. Kill various enemies
2. Open Codex → Bestiary
3. Verify all 52 enemy entries have icon_path values (no broken images)

### Test 4: Loot System
1. Kill 5+ enemies of different types
2. Verify corpses appear with loot (not empty)
3. Pick up items from corpses

---

## FILES TO COMMIT

After all fixes, these files should be committed:

```
data/enemies/boar.tres
data/enemies/deer.tres
data/enemies/goblin_soldier.tres
data/enemies/goblin_archer.tres
data/enemies/goblin_leader.tres
data/enemies/goblin_mage.tres
data/enemies/goblin_warboss.tres
data/enemies/ogre.tres (HP fix)
data/enemies/skeleton_warrior.tres
data/enemies/skeleton_shade.tres
data/enemies/tenger_archer.tres
data/enemies/tenger_cavalry.tres
data/enemies/tenger_infantry.tres
data/enemies/tenger_raider.tres
data/enemies/tenger_berserker.tres
data/enemies/tenger_shaman.tres
data/enemies/tenger_warbanner.tres
data/enemies/tenger_warlord.tres
data/enemies/tenger_warrior.tres
data/enemies/vampire_lord.tres (added level field)
```

---

## ESTIMATED TIMELINE

- **Action 1 (sprite_path):** 15 minutes
- **Action 2 (boss stats):** 5 minutes
- **Action 3 (icon_path):** 20 minutes
- **Validation Testing:** 30 minutes
- **Total:** ~70 minutes (1 hour 10 minutes)

---

## SUCCESS CRITERIA

✅ All 52 enemies render visually in-game
✅ Boar, Deer, Tengers are no longer invisible
✅ Ogre takes 8-10 hits to kill (not 3-4)
✅ Vampire Lord stat scaling works
✅ Codex displays icons for all enemies
✅ Loot corpses appear for all enemies
✅ No console errors or warnings about missing sprites

---

*After completing these actions, re-run full combat audit for verification.*
