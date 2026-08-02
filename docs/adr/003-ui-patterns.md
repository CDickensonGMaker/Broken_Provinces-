# ADR-003: UI Patterns and Standards

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** UX Designer, Lead Programmer

---

## Context

The game has multiple menu UIs (shop, crafting, enchanting, journal, map) that were developed independently, leading to visual inconsistencies:

1. **Anchoring Issues** - Some used PRESET_CENTER, causing sizing problems
2. **Padding Variations** - Different VBox padding values
3. **Process Mode** - Some menus didn't pause correctly
4. **Color Inconsistency** - Varied color palettes

A standardized UI pattern was needed.

---

## Decision

Establish **ShopUI as the canonical blueprint** for all menu UIs:

### Panel Structure

```gdscript
# Root control - fill entire viewport
root.set_anchors_preset(Control.PRESET_FULL_RECT)

# Click-outside overlay (closes UI when clicked)
var click_outside = Button.new()
click_outside.set_anchors_preset(Control.PRESET_FULL_RECT)
click_outside.flat = true
click_outside.focus_mode = Control.FOCUS_NONE
click_outside.pressed.connect(close)

# Dark overlay (75% opacity)
var overlay = ColorRect.new()
overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
overlay.color = Color(0, 0, 0, 0.75)
overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Main panel (symmetric margins)
var main = PanelContainer.new()
main.set_anchors_preset(Control.PRESET_FULL_RECT)
main.mouse_filter = Control.MOUSE_FILTER_STOP
main.offset_left = 60
main.offset_top = 80
main.offset_right = -60
main.offset_bottom = -40
```

### Panel Offsets

| Edge | Offset | Reason |
|------|--------|--------|
| Left | 60 | Symmetric with right |
| Top | 80 | Room for HUD elements |
| Right | -60 | Symmetric with left |
| Bottom | -40 | Room for interaction hints |

### VBox Padding

```gdscript
var vbox = VBoxContainer.new()
vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
vbox.offset_left = 10
vbox.offset_top = 10
vbox.offset_right = -10
vbox.offset_bottom = -10
vbox.add_theme_constant_override("separation", 8)
```

### Gothic Color Palette

```gdscript
const COL_BG = Color(0.08, 0.08, 0.1)      # Dark background
const COL_PANEL = Color(0.12, 0.12, 0.15)  # Panel background
const COL_BORDER = Color(0.3, 0.25, 0.2)   # Border
const COL_TEXT = Color(0.9, 0.85, 0.75)    # Primary text
const COL_DIM = Color(0.5, 0.5, 0.5)       # Disabled/dim text
const COL_GOLD = Color(0.8, 0.6, 0.2)      # Gold/highlight
const COL_SELECT = Color(0.25, 0.2, 0.15)  # Selection highlight
const COL_GREEN = Color(0.3, 0.8, 0.3)     # Positive values
const COL_RED = Color(0.8, 0.3, 0.3)       # Negative values
const COL_YELLOW = Color(1.0, 0.8, 0.3)    # Warnings
```

### Process Mode

```gdscript
func _ready() -> void:
    visible = false
    process_mode = Node.PROCESS_MODE_ALWAYS  # Process during pause
```

### Input Handling

```gdscript
func _input(event: InputEvent) -> void:
    if not visible:
        return

    # Close on escape, pause, or tab menu
    if event.is_action_pressed("ui_cancel") or \
       event.is_action_pressed("pause") or \
       event.is_action_pressed("menu"):
        close()
        get_viewport().set_input_as_handled()
```

### Panel StyleBox

```gdscript
var style = StyleBoxFlat.new()
style.bg_color = COL_BG
style.border_color = COL_BORDER
style.set_border_width_all(2)
panel.add_theme_stylebox_override("panel", style)
```

---

## Consequences

### Positive

1. **Visual Consistency** - All menus look cohesive
2. **Predictable Behavior** - Same close keys, same pause behavior
3. **Maintainability** - One pattern to learn and follow
4. **Bug Prevention** - Process mode and anchoring issues eliminated

### Negative

1. **Refactoring** - Existing UIs needed updates
2. **Flexibility** - Some UIs may need exceptions

### Mitigations

- Document exceptions when needed
- Use constants for shared values

---

## UIs Updated

| UI | Changes Made |
|----|--------------|
| shop_ui.gd | Blueprint (no changes) |
| crafting_ui.gd | VBox padding 15→10 |
| enchanting_ui.gd | PRESET_CENTER→PRESET_FULL_RECT + padding |
| bounty_board_ui.gd | VBox anchoring + padding + process_mode |
| repair_station_ui.gd | Already correct |
| journal_ui.gd | Already correct |

---

## Button Styling

Standard button appearance:

```gdscript
func _style_button(btn: Button) -> void:
    var normal = StyleBoxFlat.new()
    normal.bg_color = COL_PANEL
    normal.border_color = COL_BORDER
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(0)  # Sharp corners (no radius)
    btn.add_theme_stylebox_override("normal", normal)

    var hover = normal.duplicate()
    hover.bg_color = COL_SELECT
    btn.add_theme_stylebox_override("hover", hover)

    var pressed = normal.duplicate()
    pressed.bg_color = Color(0.15, 0.15, 0.2)
    btn.add_theme_stylebox_override("pressed", pressed)

    btn.add_theme_color_override("font_color", COL_TEXT)
```

### Important: No Corner Radius

PS1-style aesthetic requires **sharp corners**:
```gdscript
style.set_corner_radius_all(0)  # Not rounded
```

---

## Scroll Container Pattern

For scrollable lists:

```gdscript
var scroll = ScrollContainer.new()
scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL

var list = VBoxContainer.new()
list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
list.add_theme_constant_override("separation", 2)
scroll.add_child(list)
```

---

## List Item Pattern

For items in scrollable lists:

```gdscript
func _create_list_item(text: String, value: String) -> HBoxContainer:
    var row = HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.custom_minimum_size.y = 24

    var name_label = Label.new()
    name_label.text = text
    name_label.add_theme_color_override("font_color", COL_TEXT)
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.clip_text = true
    row.add_child(name_label)

    var value_label = Label.new()
    value_label.text = value
    value_label.add_theme_color_override("font_color", COL_GOLD)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(value_label)

    return row
```

---

## Separator Pattern

```gdscript
func _make_separator() -> HSeparator:
    var sep = HSeparator.new()
    var sep_style = StyleBoxLine.new()
    sep_style.color = COL_BORDER
    sep_style.thickness = 1
    sep.add_theme_stylebox_override("separator", sep_style)
    return sep
```

---

## Checklist for New UIs

- [ ] Root uses PRESET_FULL_RECT
- [ ] Main panel uses PRESET_FULL_RECT with 60/80/-60/-40 offsets
- [ ] VBox has 10/-10 padding
- [ ] process_mode = PROCESS_MODE_ALWAYS
- [ ] Handles ui_cancel, pause, menu actions
- [ ] Uses standard color palette
- [ ] Buttons have no corner radius
- [ ] Click-outside overlay for closing
- [ ] visible = false in _ready()

---

## Files

| File | Purpose |
|------|---------|
| scripts/ui/shop_ui.gd | Blueprint implementation |
| scripts/ui/crafting_ui.gd | Crafting menu |
| scripts/ui/enchanting_ui.gd | Enchanting menu |
| scripts/ui/bounty_board_ui.gd | Bounty board |
| scripts/ui/repair_station_ui.gd | Repair menu |
| scripts/ui/journal_ui.gd | Journal/quest log |

---

## References

- [Godot Control Anchors](https://docs.godotengine.org/en/stable/tutorials/ui/size_and_anchors.html)
- [PS1 UI Aesthetics](https://www.gamedeveloper.com/design/ui-design-in-retro-games)
