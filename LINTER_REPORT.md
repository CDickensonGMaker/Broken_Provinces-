# GDScript Linter Report - Critical Autoload & Core Scripts
**Generated:** 2026-04-07
**Scope:** scripts/autoload/*.gd, scripts/player/*.gd, scripts/combat/*.gd, scripts/enemies/*.gd

---

## SUMMARY
- **Total Issues:** 13
- **Errors:** 3 (will crash in exported build)
- **Warnings:** 7 (may cause runtime issues)
- **Info:** 3 (code quality suggestions)

---

## CRITICAL ERRORS (Will crash in .exe build)

### [ERROR] player_controller.gd Line 504: Unchecked null access on camera
**File:** C:\Users\caleb\CatacombsOfGore\scripts\player\player_controller.gd
**Severity:** CRITICAL - Will crash in exported build

```gdscript
var camera := get_viewport().get_camera_3d()
var screen_center := get_viewport().get_visible_rect().size / 2
var ray_origin := camera.project_ray_origin(screen_center)  # CRASH if camera is null
var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 100.0
```

**Issue:** `get_camera_3d()` can return null in some contexts (e.g., during scene transitions, in headless builds, or if no Camera3D exists in the scene). Using it without a null check causes immediate crash.

**Fix:** Add null check before using camera:
```gdscript
var camera := get_viewport().get_camera_3d()
if not camera:
    can_attack = true
    return

var screen_center := get_viewport().get_visible_rect().size / 2
var ray_origin := camera.project_ray_origin(screen_center)
var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 100.0
```

---

### [ERROR] spell_caster.gd Line 438: Unchecked null access on owner_entity.get_world_3d()
**File:** C:\Users\caleb\CatacombsOfGore\scripts\combat\spell_caster.gd
**Severity:** CRITICAL - Will crash in exported build

```gdscript
var space_state := owner_entity.get_world_3d().direct_space_state
var query := PhysicsRayQueryParameters3D.create(origin, end_point)
```

**Issue:** If `owner_entity` is null (which is possible since it's an @export variable), calling `get_world_3d()` on it will crash. No null check exists before this line.

**Fix:** Add null check before using owner_entity:
```gdscript
if not owner_entity:
    return

var space_state := owner_entity.get_world_3d().direct_space_state
var query := PhysicsRayQueryParameters3D.create(origin, end_point)
```

---

### [ERROR] spell_caster.gd Line 239: Unchecked null access on get_tree().current_scene
**File:** C:\Users\caleb\CatacombsOfGore\scripts\combat\spell_caster.gd
**Severity:** CRITICAL - Will crash during scene transitions

```gdscript
get_tree().current_scene.add_child(effect)
effect.global_position = center + Vector3(0, 0.5, 0)
```

**Issue:** `get_tree().current_scene` can be null during scene transitions or in specific edge cases. Adding a child to null causes immediate crash.

**Fix:**
```gdscript
if get_tree().current_scene:
    get_tree().current_scene.add_child(effect)
    effect.global_position = center + Vector3(0, 0.5, 0)
else:
    effect.queue_free()  # Clean up since we can't add it
```

---

## TYPE SAFETY WARNINGS

### [WARNING] player_controller.gd Line 225: Type inference on boolean expression
**Severity:** MEDIUM

```gdscript
var has_stamina := DEBUG_UNLIMITED_STAMINA or (GameManager.player_data and GameManager.player_data.current_stamina > 0)
```

**Issue:** Using `:=` on a boolean comparison/expression may fail type inference in strict mode. The compiler cannot reliably infer the type from complex boolean logic.

**Fix:**
```gdscript
var has_stamina: bool = DEBUG_UNLIMITED_STAMINA or (GameManager.player_data and GameManager.player_data.current_stamina > 0)
```

---

### [WARNING] player_controller.gd Line 258: Type inference on autoload property
**Severity:** MEDIUM

```gdscript
var char_data := GameManager.player_data
```

**Issue:** Using `:=` for CharacterData assignment. While this *might* work, explicit types are required for code clarity and strict type checking.

**Fix:**
```gdscript
var char_data: CharacterData = GameManager.player_data
```

---

### [WARNING] player_controller.gd Line 633: Untyped loop variable
**Severity:** MEDIUM

```gdscript
for node in get_tree().get_nodes_in_group("interactable"):
    if not node is Node3D:
        continue
    var dist: float = global_position.distance_to((node as Node3D).global_position)
```

**Issue:** Loop variable `node` has no type annotation. Should be explicit for clarity and type safety.

**Fix:**
```gdscript
for node: Node in get_tree().get_nodes_in_group("interactable"):
    if not node is Node3D:
        continue
    var dist: float = global_position.distance_to((node as Node3D).global_position)
```

---

### [WARNING] player_controller.gd Line 850: Untyped loop variable in dictionary iteration
**Severity:** MEDIUM

```gdscript
for damage_type in dot_damage:
    var amount: int = dot_damage[damage_type]
    if amount > 0:
        take_damage(amount, damage_type, null)
```

**Issue:** Loop variable `damage_type` should be typed explicitly. Dictionary keys need type annotation.

**Fix:**
```gdscript
for damage_type: Enums.DamageType in dot_damage:
    var amount: int = dot_damage[damage_type]
    if amount > 0:
        take_damage(amount, damage_type, null)
```

---

### [WARNING] spell_caster.gd Line 73: Type inference on function return value
**Severity:** LOW-MEDIUM

```gdscript
var char_data := _get_character_data()
```

**Issue:** Using `:=` for function return value. The function has explicit return type `CharacterData`, but using `:=` is less clear.

**Fix:**
```gdscript
var char_data: CharacterData = _get_character_data()
```

---

### [WARNING] spell_caster.gd Line 135: Type inference on assignment from typed variable
**Severity:** LOW

```gdscript
var spell := current_spell
```

**Issue:** `current_spell` is already typed as `SpellData`, but `:=` is used instead of explicit type.

**Fix:**
```gdscript
var spell: SpellData = current_spell
```

---

### [WARNING] projectile_base.gd Line 51, 144, 226: Type inference on constructors and expressions
**Severity:** LOW

Lines 51, 144, 226 use `:=` on constructors and math expressions:
```gdscript
var sphere := SphereShape3D.new()           # Line 51
var sphere := SphereMesh.new()              # Line 144
var horizontal_dir := Vector3(...).normalized()  # Line 226
```

**Issue:** While these *often* work, explicit types are preferred for code clarity.

**Fix:**
```gdscript
var sphere: SphereShape3D = SphereShape3D.new()
var sphere: SphereMesh = SphereMesh.new()
var horizontal_dir: Vector3 = Vector3(...).normalized()
```

---

## CODE QUALITY ISSUES

### [INFO] player_controller.gd Line 144: Function _physics_process() is 189 lines
**Severity:** LOW (Code Quality)

This function handles too many responsibilities:
- Movement input processing
- Sprint/stamina system
- Dodging mechanics
- Ladder climbing
- Condition updates
- Mana regeneration
- Footstep audio
- Stealth visibility

**Suggestion:** Refactor into smaller functions:
```gdscript
func _physics_process(delta: float) -> void:
    if is_dead or (GameManager and (GameManager.is_in_menu or GameManager.is_in_dialogue)):
        return

    _process_crouch_and_dodge(delta)
    _process_climbing_or_normal_movement(delta)
    _process_footsteps(delta)
    _regenerate_mana(delta)
    _update_conditions(delta)
    _update_interaction()
    _update_visibility()

func _process_crouch_and_dodge(delta: float) -> void:
    if Input.is_action_just_pressed("crouch") and not is_climbing:
        _toggle_crouch()
    if Input.is_action_just_pressed("dodge") and not is_climbing:
        _try_dodge()
    # ... dodge processing ...

func _process_climbing_or_normal_movement(delta: float) -> void:
    if is_climbing and current_ladder:
        _process_climbing(delta)
    else:
        _process_normal_movement(delta)
```

---

### [INFO] spell_caster.gd Line 697: Function _spawn_sustained_beam_effect() is 156 lines
**Severity:** LOW (Code Quality)

This function creates complex beam rendering with animations. It could be split:
```gdscript
# Extract beam segment creation
func _create_beam_segments(origin: Vector3, end: Vector3, beam_container: Node3D) -> Array[MeshInstance3D]:
    # Build jagged lightning path, create segments
    # Returns array of beam mesh instances

# Extract animation/jitter logic
func _animate_beam_with_jitter(segments: Array[MeshInstance3D], duration: float, origin: Vector3, end: Vector3) -> void:
    # Set up timer, update segment positions with jitter
```

---

### [INFO] scene_manager.gd: Overall code quality - GOOD
No major issues found. Proper use of `is_instance_valid()`, explicit type annotations, good null safety patterns.

---

## SUMMARY OF FIXES NEEDED BEFORE EXPORT

### Must Fix (Crash Prevention):
1. **player_controller.gd:504** - Add null check for `get_camera_3d()`
2. **spell_caster.gd:438** - Add null check for `owner_entity` before `get_world_3d()`
3. **spell_caster.gd:239** - Add null check for `get_tree().current_scene`

### Should Fix (Type Safety):
4. **player_controller.gd:225** - Change `:=` to `: bool =`
5. **player_controller.gd:258** - Change `:=` to `: CharacterData =`
6. **player_controller.gd:633** - Add type to loop variable
7. **player_controller.gd:850** - Add type to loop variable
8. **spell_caster.gd:73** - Change `:=` to `: CharacterData =`
9. **spell_caster.gd:135** - Change `:=` to `: SpellData =`
10. **projectile_base.gd:51,144,226** - Add explicit types to constructors

### Optional (Code Quality):
11. **player_controller.gd:144** - Refactor _physics_process() (189 lines)
12. **spell_caster.gd:697** - Refactor _spawn_sustained_beam_effect() (156 lines)

---

## RECOMMENDATIONS

**Pattern 1: Never use `:=` on boolean expressions or ternary operators**
```gdscript
# BAD
var is_valid := condition_a or condition_b
var result := condition ? value_a : value_b

# GOOD
var is_valid: bool = condition_a or condition_b
var result: Type = condition ? value_a : value_b
```

**Pattern 2: Always validate optional node references**
```gdscript
# BAD
var camera := get_viewport().get_camera_3d()
camera.project_ray_origin(point)  # Crash if null

# GOOD
var camera := get_viewport().get_camera_3d()
if not camera:
    return
camera.project_ray_origin(point)
```

**Pattern 3: Always type loop variables for untyped collections**
```gdscript
# BAD
for item in array:
    var id := item["id"]

# GOOD
for item: Dictionary in array:
    var id: String = item["id"]
```

---

**Report Generated:** 2026-04-07
**Status:** READY FOR EXPORT (after fixing Priority 1 issues)
