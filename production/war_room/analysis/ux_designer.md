# UX Designer Analysis — Popup UI Consistency Audit

**War Room Session:** Alpha complaint — popup UIs wildly inconsistent in size/behavior; merchant and bounty board "act really weird"
**Author:** UX Designer architect
**Date:** 2026-07-08
**Scope:** All modal/popup UIs vs the reference standard (dialogue_box.gd, game_menu.gd)
**Prior art:** ADR-003 (docs/adr/003-ui-patterns.md) already declared ShopUI the canonical blueprint on 2026-05-25 — it was never enforced. This analysis supersedes/extends it.

---

## 1. The Reference Standard

Two reference UIs, two legitimate size classes:

### A. DialogueBox (scripts/ui/dialogue_box.gd) — "proportional panel" class
- **Root:** `CanvasLayer`, `layer = 100`, `process_mode = PROCESS_MODE_ALWAYS` (lines 50-51)
- **Scaffold:** full-rect `Control` root (`PRESET_FULL_RECT`, `MOUSE_FILTER_PASS`, lines 165-170)
- **Panel sizing:** PROPORTIONAL anchors, zero offsets — `anchor 0.15–0.85 horizontal, 0.2–0.8 vertical` (lines 175-183). Scales with any resolution; no hardcoded pixel sizes on the panel itself.
- **Mouse:** containers `MOUSE_FILTER_PASS`, interactive buttons `MOUSE_FILTER_STOP` (lines 184, 303); mouse mode flips VISIBLE/CAPTURED in `_show_ui()`/`_hide_ui()` (354, 377)
- **Pause:** does not touch `get_tree().paused` itself — GameManager.start_dialogue()/end_dialogue() owns it (game_manager.gd:253-262)
- **Input:** Escape AND pause key close, `set_input_as_handled()` (lines 105-108); keyboard hotkeys 1-4; single persistent instance toggled by visibility

### B. GameMenu (scripts/ui/game_menu.gd) — "full-screen margin panel" class
- **Root:** `Control` living inside the HUD CanvasLayer (hud.tscn line 25-26, `layer = 2`), `process_mode = PROCESS_MODE_ALWAYS` (line 108)
- **Panel sizing:** `PRESET_FULL_RECT` + fixed symmetric margins: `offset_left = 60, top = 80, right = -60, bottom = -40` (lines 180-183); inner VBox padding 10/-10 (193-196)
- **Pause:** `open()` sets `paused = true`, `enter_menu()`, mouse VISIBLE (2102-2107); `close()` reverses everything (2118-2131)
- **Lifecycle:** ONE persistent instance in hud.tscn, toggled via `visible`; never re-instantiated
- **Input:** Tab/Escape close with `set_input_as_handled()` (129-132)

### The composite standard every popup should meet
| Requirement | Value |
|---|---|
| Render layer | CanvasLayer `layer = 100` (above HUD layer 2) |
| Process mode | `PROCESS_MODE_ALWAYS` on the UI root, set by the UI itself |
| Sizing | Full-screen menus: FULL_RECT + 60/80/-60/-40 margins. Dialogue-style: proportional anchors 0.15–0.85. Never fixed pixel panel sizes. |
| Pause | Tree paused while open; pause/unpause owned by ONE place, not each opener |
| Mouse | Mode set via GameManager.enter_menu()/exit_menu(); PASS on containers, STOP on interactives |
| Close | Escape + pause + menu actions, all with `set_input_as_handled()` |
| Lifecycle | One instance; visibility toggled OR create/free through a single manager |

---

## 2. Per-UI Compliance Table

| UI (scripts/ui/) | Root type | Panel sizing | Layer | Pauses tree? | ALWAYS? | Escape? | Verdict |
|---|---|---|---|---|---|---|---|
| dialogue_box.gd | CanvasLayer | proportional 0.15-0.85 | 100 | via GameManager | yes | yes | **REFERENCE** |
| game_menu.gd | Control (in HUD) | FULL_RECT 60/80/-60/-40 | 2 (HUD) | yes (self) | yes | yes | **REFERENCE** |
| conversation_ui.gd | CanvasLayer | proportional 0.15-0.85 (:311-314) | 100 | yes | yes | yes | COMPLIANT |
| shop_ui.gd | Control on ad-hoc canvas | FULL_RECT 60/80/-60/-40 (:95-98) | 100 | opener does (merchant.gd:568) | yes (:59) | yes (+menu) | Panel OK; **lifecycle broken** (see §3) |
| bounty_board_ui.gd | Control on ad-hoc canvas | FULL_RECT **20/20/-20/-20** (:61-64) | 100 | opener does (bounty_board.gd:397) | inherited only | yes (+menu) | **NON-COMPLIANT** (see §3) |
| chest_ui.gd | Control on ad-hoc canvas | FULL_RECT **20/20/-20/-20** (:72-75) | 100 (chest.gd:273) | yes (chest.gd:286) | yes (:27) | yes | Margins off-standard |
| corpse_loot_ui.gd | Control on ad-hoc canvas | FULL_RECT **150/100/-150/-100** (:77-80) | 100 | yes | yes (:32) | yes | Third margin variant |
| crafting_ui.gd | Control on ad-hoc canvas | FULL_RECT 60/80/-60/-40 (:89-92) | 100 (alchemy_station.gd:228) | **NO** (alchemy_station.gd:236-238, cooking_station.gd same) | **NO** (never set) | yes | **World keeps running while crafting** |
| enchanting_ui.gd | **CanvasLayer, no layer set → 1** | FULL_RECT 60/80/-60/-40 (:58-61) | **1 — BELOW HUD (2)** | **NO** (enchanting_station.gd:97-113) | **NO** | ui_cancel only (:308) | **Renders under HUD; no pause** |
| fast_travel_ui.gd | CanvasLayer | **PRESET_CENTER fixed 400×450 px** (:54-55) | **90** | yes (:268) | yes (:37) | yes | Fixed px + odd layer |
| wait_ui.gd | CanvasLayer | CENTER fixed 400×300 (:57-61) | 100 | yes (:364) | yes | yes | Fixed px size |
| humanoid_dialogue.gd | CanvasLayer | PRESET_CENTER, shrink-to-content (:64) | 100 | yes, self (:161) | yes | yes | Center class, acceptable-ish |
| npc_dialogue_ui.gd | CanvasLayer | BOTTOM_WIDE, top 0.68 (:188-193) | 100 | — | yes | yes | Dialogue class, OK |
| spell_maker_ui.gd | **CanvasLayer, no layer set → 1** | CENTER fixed **800×600 px** (:58-65) | **1 — BELOW HUD** | ? | not set | ui_cancel (:519) | Fixed px + under HUD |
| dice_roll_ui.gd | Control | TOP_RIGHT fixed 260×180; jumps to CENTER 260×200 in dialogue (:76-80, 195-207) | host-dependent | n/a (passive) | **not set → freezes if tree paused** | n/a | Risk: frozen animation during paused dialogue |
| pause_menu.gd | Control | CENTER fixed 300×360 (:101-105) | — | yes (:296) | (has own handling) | yes | Small-menu class |
| companion_command_ui.gd / companion_status_ui.gd | Control HUD overlays | anchor-stretch (:113-114) | HUD | no (correct — not modal) | — | n/a | Not popups; but corner_radius 4 (:124-127) violates ADR-003 sharp-corners rule |

**Margin spread across "full-screen" popups: 60/80/-60/-40 (shop, crafting, enchanting, game_menu) vs 20/20/-20/-20 (bounty, chest) vs 150/100/-150/-100 (corpse loot).** Three different sizes for the same interaction class is the visual inconsistency the alpha testers are seeing.

---

## 3. Root Causes: Why Merchant & Bounty Board "Act Weird"

### Merchant / Shop UI

1. **Four different spawn paths, no single owner.** The ShopUI is rebuilt from scratch (`Control.new()` + `set_script`) by merchant.gd:542-573, quest_giver.gd:965-1000, innkeeper.gd:287, and conversation_system.gd:1532 — each creating its own `CanvasLayer(layer=100)` and each hand-rolling pause/mouse/cleanup. Any drift between these copies = different behavior depending on WHICH merchant you talk to.
2. **Traveling merchant shop is silently dead.** traveling_merchant.gd:305 does `get_first_node_in_group("shop_ui")` — **nothing anywhere calls `add_to_group("shop_ui")`** (verified project-wide grep). The lookup returns null and the shop simply never opens. Classic symptom reported as "acts weird".
3. **Click-outside ring closes the shop and eats the cart.** shop_ui.gd:76-82 puts a full-rect invisible `Button` under the panel; with the 60/80 margins this leaves a border ring where ANY stray click instantly closes the UI — discarding the player's entire buy/sell cart with no confirmation. Feels like random closing.
4. **Canvas leak on re-open.** merchant.gd:544-545 frees the old `shop_ui` Control but NOT its parent `ShopUICanvas`; orphan CanvasLayers accumulate in `current_scene` if the close signal never fired.
5. **Full rebuild on every refresh.** `_refresh_display()` (shop_ui.gd:386-428) is called after every confirm/clear; children are `queue_free()`d (not freed immediately) then new rows added — one frame of doubled rows, scroll position reset to top, SpinBoxes recreated so typed quantities/focus are lost mid-edit.
6. **Index-based carts go stale.** sell_cart stores `inventory_index` (shop_ui.gd:722-728); after the first sale mutates the inventory array, later entries can mismatch — the validation at :850-870 catches it but silently *skips* those sales (push_warning only). Player sees items "refuse to sell".
7. **Vestigial visible=false + open().** shop_ui is created fresh each time yet still plays the persistent-instance pattern (`visible=false` in `_ready`, then `open()`), evidence of two lifecycles half-merged.

### Bounty Board UI

1. **Wrong size class.** bounty_board_ui.gd:61-64 uses 20/20/-20/-20 margins — near-fullscreen, visibly bigger than shop/crafting/game_menu (60/80/-60/-40) despite the comment on :57 claiming it "match[es] shop_ui.gd". It matches the scaffold but not the numbers.
2. **Interior layout doesn't expand.** The content HBox children have fixed `custom_minimum_size` — list 280px (:116), detail panel 320px (:127) — and **no `size_flags_horizontal = SIZE_EXPAND_FILL`**. On a 1920-wide window the content occupies ~615px hugging the left edge with a huge dead void on the right. This is the single biggest "looks broken" item.
3. **process_mode roulette.** The root Control never sets `PROCESS_MODE_ALWAYS`; it only works because bounty_board.gd:411 sets ALWAYS on the wrapping canvas. Someone clearly got burned before: individual buttons redundantly set `process_mode = ALWAYS` (bounty_board_ui.gd:146, 156, 228, 390, 397, 405) — cargo-cult patching of a paused-UI bug instead of fixing the root.
4. **UI parented to a world object.** bounty_board.gd:412 `add_child(canvas)` puts the CanvasLayer under the 3D board node — unlike shop/chest which parent to `current_scene`. If the board's cell streams out or the board is freed while the UI is open, the menu vanishes without running the close path, leaving the game **paused forever with mouse captured** (pause/unpause only happens in `_on_bounty_ui_closed`, :419-422).
5. **Same 20px click-outside ring** (:42-48) — a click near the screen edge closes the board while reading bounty details.
6. **Close is signal-dependent.** `_close()` (:457-458) only emits `ui_closed`; the UI cannot close itself. Any opener that forgets to connect the signal produces an unclosable, permanently-paused screen.
7. **Pause ordering differs from merchant.** bounty_board.gd pauses BEFORE building the UI (:397); merchant pauses AFTER (:568). Harmless today, but it means the two flows exercise different frame-order edge cases.

### Cross-cutting causes (why the whole popup family drifts)

- **No base class, no shared theme.** Every UI re-declares the gothic palette (`COL_BG`, `COL_BORDER`, ...) — 9+ copies — and re-implements `_style_button()` with slightly different hover/pressed states (compare shop_ui.gd:961 vs bounty_board_ui.gd:161 vs dialogue_box.gd:313). ADR-003 documented the pattern but provided no enforcing code.
- **Pause management is distributed.** `get_tree().paused` is written directly by merchant.gd, chest.gd, bounty_board.gd, game_menu.gd, pause_menu.gd, wait_ui.gd, humanoid_dialogue.gd, fast_travel_ui.gd, GameManager — while crafting and enchanting stations pause NOTHING (alchemy_station.gd:236-242, enchanting_station.gd:97-113). Consequences: (a) you can be attacked while crafting; (b) stacked UIs fight over one boolean — whichever closes first unpauses the world behind the other.
- **Layer conflicts.** EnchantingUI and SpellMakerUI are CanvasLayers that never set `layer` → default 1, **below the HUD at layer 2** — health bars, crosshair, and notifications draw on top of these menus. Everything else is 100 except fast_travel at 90.
- **Runtime-built vs .tscn split.** Only conversation_ui, dialogue_box, game_menu, npc_dialogue_ui, enchanting_ui have scenes; shop/bounty/chest/corpse/crafting are `Control.new()+set_script()` at runtime — invisible to the editor, un-themable, and each opener re-implements the wrapper.

---

## 4. Recommended Standardization Plan

### Phase 1 — BasePopupUI + UIManager (the structural fix)

**`scripts/ui/base_popup_ui.gd`** — `class_name BasePopupUI extends Control`:
- `_ready()`: `set_anchors_preset(PRESET_FULL_RECT)`, `process_mode = PROCESS_MODE_ALWAYS`, builds standard scaffold (dim overlay 75%, PanelContainer styled from shared theme), calls virtual `_build_content(panel_vbox)`.
- `enum SizeClass { FULLSCREEN, DIALOGUE, COMPACT }`:
  - FULLSCREEN → FULL_RECT + 60/80/-60/-40 (game_menu standard)
  - DIALOGUE → proportional anchors 0.15–0.85 / 0.2–0.8 (dialogue_box standard)
  - COMPACT → PRESET_CENTER + proportional max (e.g. anchors 0.35–0.65), for wait/fast-travel/pause — proportional, not fixed pixels
- Built-in `_input`: ui_cancel + pause + menu → `close()` + `set_input_as_handled()`.
- `open()`/`close()` delegate to UIManager; emits `ui_closed` for legacy compatibility.
- Click-outside: default OFF for transactional UIs (shop, bounty); if enabled, it must live on the overlay only and never overlap within 0px of the panel.

**`scripts/core/ui_manager.gd`** — owns:
- ONE persistent `CanvasLayer(layer = 100)` for all popups (kills the per-opener canvas creation, leaks, and layer drift).
- A modal stack: `push(popup)` / `pop()` — only top popup receives input; opening a second popup no longer double-pauses.
- **Pause refcount:** `paused = stack.size() > 0`. Removes every direct `get_tree().paused =` write from openers. Crafting/enchanting get pause for free.
- Mouse mode + GameManager.enter_menu/exit_menu in exactly one place.
- Safety: `tree_exiting` hook on popups so a freed world-object opener can never strand the game paused.

### Phase 2 — Shared theme
One `Theme` resource (`assets/ui/gothic_theme.tres`) carrying panel StyleBox, button normal/hover/pressed/disabled (sharp corners per ADR-003), font sizes, and the palette as theme colors. Delete the 9 copied `COL_*` blocks and 6 `_style_button` clones.

### Phase 3 — Migrate the offenders (priority order)
1. **bounty_board_ui.gd** — FULLSCREEN size class; add `SIZE_EXPAND_FILL` to list (weight 1) and detail (weight 2); delete per-button process_mode; parent via UIManager not the board node.
2. **shop_ui.gd** — keep layout; move instantiation into ONE place (`UIManager.open_shop(merchant)`); merchant.gd/quest_giver.gd/innkeeper.gd/traveling_merchant.gd all call it. Fixes the dead traveling-merchant path and the 4-way drift. Replace index carts with item-ref carts. Refresh in place instead of rebuild (update labels/spinners, only rebuild on inventory count change).
3. **enchanting_ui.gd / spell_maker_ui.gd** — convert to BasePopupUI Controls (fixes layer-1-under-HUD automatically).
4. **crafting_ui.gd** — BasePopupUI FULLSCREEN; stations stop hand-rolling; gains pause.
5. **chest_ui.gd / corpse_loot_ui.gd** — COMPACT or FULLSCREEN class (pick one; recommend COMPACT for loot), same margins as each other.
6. **fast_travel_ui.gd / wait_ui.gd** — COMPACT class, proportional; move to layer 100 via manager.
7. dice_roll_ui.gd — set `process_mode = ALWAYS` so it animates during paused dialogue.

### Tradeoffs (named, per Law 2)
- Migration touches ~12 UI files + 8 opener scripts; regression risk in save/load-adjacent pause states. Mitigate by migrating one UI per commit with the bug-testing checklist's UI section.
- A modal stack changes behavior where two UIs currently stack accidentally (conversation → shop). That accidental behavior is currently a bug source; intentional stacking must be re-specified.
- Losing click-outside-to-close on shop is a deliberate UX regression for one tester habit in exchange for never losing a cart.

### Acceptance criteria
- Every popup opens at one of exactly 3 size classes; screenshots at 1280×720 and 1920×1080 show identical proportions.
- Tree is paused whenever any popup is open; never paused after all close — including when an opener node is freed mid-open.
- Escape closes the top popup only, in every popup, paused or not.
- No CanvasLayer besides UIManager's (layer 100), HUD (2), and dialogue systems.
- Traveling merchant opens a shop.
