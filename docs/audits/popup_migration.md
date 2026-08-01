# Popup Migration - BasePopupUI

Where every popup in the game stands after steps 16 and 17.

`tools/check_popups.tscn` instantiates all eighteen of these for real, runs them
a frame and closes them. Run it after touching any of them:

```
_tools\godot45\Godot_v4.5-stable_win64_console.exe --headless --path . res://tools/check_popups.tscn
```

It runs as a scene, not with `--script`, because `--script` starts an engine with
no autoloads and these popups reach for six.

## Migrated

| Popup | Tier | Owns the pause? | Notes |
|---|---|---|---|
| `shop_ui.gd` | FULLSCREEN | yes | Still has no click-outside; that used to discard the cart. `ShopUI.open_for()` now gets its single instance from UIManager instead of rebuilding a canvas per merchant. |
| `bounty_board_ui.gd` | FULLSCREEN | no - the board does | Gained a `class_name`; the board now types it instead of `set_script`ing a bare Control. |
| `crafting_ui.gd` | FULLSCREEN | no - the station does | All three stations (anvil, alchemy, cooking) host it on the shared canvas. |
| `enchanting_ui.gd` | FULLSCREEN | no - the station does | Was a CanvasLayer of its own. Keeps its violet panel, loses its own layer number. No click-outside: a stray click should not lose a half-chosen enchantment. |
| `repair_station_ui.gd` | FULLSCREEN | no - the station does | **Margins changed**: was 20/20/-20/-20, now the standard 60/80/-60/-40. Also now processes while paused, which it did not before. |
| `chest_ui.gd` | FULLSCREEN | no - the chest does | **Margins changed**: was 20/20/-20/-20, now standard. |
| `corpse_loot_ui.gd` | FULLSCREEN | no - the corpse does | Keeps its gore palette under `GORE_*` names; the `COL_*` names now mean the shared colours. Keeps its own tighter 150/100 margins - a body holds less than a shop. |
| `spell_maker_ui.gd` | FULLSCREEN | no - the altar does | Was a CanvasLayer with a fixed 800x600 centred panel; now a standard full-screen menu, so it no longer overflows small windows. |

## Held on their old base

A working ugly popup beats a broken pretty one. These stay as they are, with the
reason each was left.

| Popup | Why held |
|---|---|
| `conversation_ui.gd` | 1418 lines, driven by ConversationSystem and TakeoverManager, with a bespoke topic/response layout that shares almost nothing with the menu chrome. Nothing here can be verified headlessly beyond "it built a tree", and its behaviour is the subject of steps 18-19. Migrate after the dialogue work settles. |
| `npc_dialogue_ui.gd` | Same family. It already calls `TakeoverManager.end_dialogue()` from `_ready()` (visible in the popup check's warning), so its lifecycle is entangled with an autoload's state machine, not with a base class. |
| `dialogue_box.gd` | Same family. Typewriter text, portraits and choice lists; the DIALOGUE tier would have to grow to fit it rather than the other way round. |
| `humanoid_dialogue.gd` | The FIGHT/BRIBE/NEGOTIATE menu. It pauses mid-combat and hands control back to CombatManager; getting the pause handoff wrong turns a fight into a soft-lock, and only a real fight proves it. |
| `intro_dialogue_ui.gd` | Not a popup. It is a full-screen cinematic card with its own fade, shown once at the start of a game. |
| `fast_travel_ui.gd` | Deliberately sits on layer 90, *below* the pause menu. The shared popup canvas is layer 100, so hosting it there would silently reverse that ordering. Needs a ruling on which should win before it moves. |
| `wait_ui.gd` | A CanvasLayer singleton parented to the GameManager autoload, with its own time-passing animation loop running while the game is paused. Its lifetime rules are unlike every other popup's. |
| `dice_roll_ui.gd` | Not a popup. A transient roll-result toast with no chrome, no close key and a queue. |
| `companion_status_ui.gd` | Not a popup. An always-on HUD widget. |
| `companion_command_ui.gd` | Not a popup. An always-on HUD widget. |
| `game_menu.gd`, `pause_menu.gd` | Not popups. Tabbed full-screen menus that host the panels under `scripts/ui/panels/`. They are the next real migration target, and they are big enough to deserve their own step. |

## Eye-check list for Caleb

Things headless testing cannot see. All of these are visual only - nothing here
changes what a menu does.

1. **Repair station and chest menus are bigger.** Both used 20px margins and now
   use the standard 60/80/-60/-40. Open an anvil and a chest and say whether the
   new size reads better or worse.
2. **Spell maker is now full-screen** instead of a fixed 800x600 card. Check it
   still reads well; the effect lists have more room than they used to.
3. **Rounded corners are gone** from the enchanting table and the spell maker
   (ADR-003: PS1 aesthetic is sharp corners). Confirm you want that.
4. **Separators are now a drawn line** in the shop, crafting, repair and bounty
   menus rather than the default gap.
5. **Buttons in the enchanting table are now styled** like every other menu's
   buttons; they used to be Godot's default grey.
6. **Every popup now draws above the HUD**, on one canvas. Open a shop, a chest
   and a bounty board and confirm nothing draws underneath the compass or the
   health bar.
