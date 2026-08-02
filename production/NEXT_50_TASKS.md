# Broken Provinces — the next 50 tasks (26–75)

*2026-08-01, Wyrm. Continues `ACT1_25_STEP_PLAN_2026-08-01.md`, which is closed.
Nothing here re-lists that run's work.*

## What this audit was looking for

Caleb's framing: *"this game was made with earlier claude coding and probably is
missing a lot of key things."* The 25-step run kept finding the same bug class —
code that exists, reports itself healthy, and does nothing. `start_quest` never
copying `choice_consequences`; the Adventurers Guild tree never attached to its
giver; the open world spawning zero enemies off a parenting-order null.

This pass hunted **more of that class specifically**, across seven axes: dead
wiring, copy/serialisation gaps, unexercised paths, save coverage, silent-failure
patterns, the 228 warnings, and first-ten-minutes game feel. Every finding below
was read in the source; the ones marked **VERIFIED BY RUN** were also reproduced
against Godot 4.5 headless.

**What this list deliberately excludes**, per the standing rules:
- **No art repair.** Broken or absent assets go to
  `docs/audits/art_replacement_manifest.md`, not here. Where a task touches
  audio it is *repointing code at files that already exist on disk* — wiring, not
  art. Sounds with no asset at all go to the manifest.
- **No tasks gated on Caleb's story rulings.** Those live in
  `docs/audits/wave_b_dispositions.md` and stay there. The 74 unreachable choice
  branches, the seven LORE_ONLY ids, the eight relic `[OPEN]`s, the Crossroads
  buildings and the hostage rooms are all **referenced, not re-listed**.

**Sizes:** S ≈ under an hour · M ≈ half a day · L ≈ one to three days.

---

## The ten most damning finds

Ordered by how badly they contradict what the project believes about itself.

1. **`InventoryManager.get_gold()` does not exist.** Three call sites use it:
   boat-fare affordability (`boat_travel_manager.gd:659`), fast-travel caravan
   cost (`fast_travel_manager.gd:408`), guard bribe (`game_systems.gd:551`).
   The public field is `InventoryManager.gold`. This is *literally the same bug*
   as the 8/1 "gold charged from a field that doesn't exist" — a second, unfixed
   instance of it, in three more places. Each one throws
   `Invalid call. Nonexistent function` the moment a player tries to buy passage,
   pay a caravan, or bribe a guard.
2. **`DiceManager.skill_check()` does not exist.** Four call sites:
   `boat_travel_manager.gd:545,578` (fleeing and resolving a sea encounter) and
   `jail_guard.gd:597,650` (both jail-escape social checks). The real methods are
   `make_check`, `passive_check`, `speech_check`, `lockpick_check`,
   `bravery_check`. Each site is guarded by `if DiceManager:` — which is always
   true for a loaded autoload. **The guard looks defensive and is not.** Sea
   travel and the jail escape are both hard-broken.
3. **Navigation is rejected outright in 14 levels — VERIFIED BY RUN.** The
   project sets no `[navigation]` section, so the nav map is Godot's default
   0.25/0.25. Fourteen level scripts bake their navmesh at `cell_size` 0.3 or
   0.4 and `cell_height` 0.2. Booting `sunken_crypt.tscn` headless prints
   `ERROR: Attempted to update a navigation region with a navigation mesh that
   uses a cell_size of 0.30000001192093 while assigned to a navigation map set to
   a cell_size of 0.25` — `NavRegion3D::set_navigation_mesh` returns early, so
   **those regions have no navmesh at all.** Nothing can path in Sunken Crypts,
   the Crossroads ruins, King's Watch, Mosshall Tombs, Riverside Village,
   Windmere, Iron Hall, the cult hideout, Dalhurst cemetery, the Athenaeum, the
   Tenger camp, Whaler's Abyss, Pola Perron crypt or Dusty Hollow. Two of those
   are on the Act I line. The 25-step run's closing note called these 25 error
   lines "engine-level… worth a look, it may mean regions are being rejected."
   They are being rejected.
4. **Melee — the game's primary verb — never goes through the combat system.**
   `CombatManager.apply_melee_damage()` (`combat_manager.gd:93`, 125 lines) has
   **zero callers anywhere in the repo.** It is the function that rolls crits,
   emits `damage_dealt`/`critical_hit`, applies lifesteal and spawns the damage
   number. The real melee path is
   `player_controller._do_light_attack → Hitbox._apply_hit → target.take_damage`,
   which bypasses it entirely. So melee has **no crits, no damage numbers, no
   lifesteal, and never fires the signals the HUD listens on**. Spells do (via
   `apply_spell_damage`). `apply_ranged_damage()` also has zero callers.
5. **The entire combat/UI sound layer points at an empty directory.**
   `audio_manager.gd`'s `EVENTS` table (lines 12–168) and its `play_*` shortcuts
   name ~120 files under `res://assets/audio/sfx/*.wav`. `find assets/audio/sfx
   -maxdepth 1 -type f` returns **0**. Every real asset (49 of them) lives one
   level down in `monsters/`, `npc/`, `ui/`, `weapons/`, `walking and movement/`.
   `_load_sound()` does `ResourceLoader.exists()` → `push_warning` → return null,
   and every caller does `if not stream: return`. **No hit sound, no death
   sound, no menu sound, no item sound has ever played, and nothing has ever
   crashed to say so.** Same shape in `ambient_soundscape.gd`, which targets
   `res://assets/audio/ambient/` (the real folder is `Ambiance/`) and whose
   loader *deliberately suppresses the warning* — "Don't spam warnings for
   missing ambient sounds during development." Biome ambience is a complete
   no-op in every outdoor zone.
6. **Ten objective types in shipped quest data have no handler, so the guild
   capstones cannot be completed.** `has_item`, `kill_or_persuade`,
   `special_combat`, `variable`, `lockpick`, `puzzle`, `revelation`,
   `combat_or_talk`, `heist_event`, `investigate` appear in
   `data/quests/**/*.json` and appear nowhere in `quest_manager.gd` — no
   `update_progress` call, no dedicated handler, no `world_condition` or `group`
   escape hatch. Affected: `thieves_10` through `thieves_13`, `mage_05`,
   `mage_13`, `mage_repeatable_research`, `noble_soulstone_request`. The Thieves
   Guild ladder needs 12–14 completed guild quests to reach the top rank; four of
   its final five are structurally uncompletable.
7. **`FlagManager` is never cleared on New Game.** `SaveManager.reset_world_state()`
   (line 1889) clears eleven systems and `DialogueManager.dialogue_flags` — but
   not `FlagManager.flags`, which is the actual store for deity devotion, all
   twenty-odd guild-rank gate flags, and every `set_world_flag` mirror.
   `FlagManager.reset_for_new_game()` exists at line 454 with **zero callers in
   the entire repo**. A new character therefore starts holding the last
   playthrough's guild ranks and devotions. (Persistence itself is fine, but only
   by accident: `DialogueManager.to_dict/from_dict` proxies `FlagManager.flags`
   under a comment that says the opposite — *"FlagManager handles its own
   save/load"*. It does not. `context_variables` is dropped by that route.)
8. **`CharacterData.total_ip_earned` is dropped by save/load.** It is the sole
   input to the level threshold table (`character_data.gd:137-144`) and to the XP
   bar's in-level progress (line 513). `SaveManager._collect_player_data` (486)
   and `_apply_player_data` (816) copy `CharacterData` field-by-field by hand and
   both omit it. `level` is saved directly so it cannot regress — but after every
   load the player's banked progress toward the next level silently resets to
   zero and the XP bar reads wrong. This is exactly the bug class
   `tools/check_quest_engine.tscn` was built to catch, in a class with no guard.
9. **The world map's fog of war is a deleted system that the docs still
   describe.** `scripts/map/map_fog_of_war.gd` (`MapFogOfWar`) has **zero
   references anywhere** — no script, scene, or data file names it.
   `scripts/ui/painted_world_map.gd` does not exist at all.
   `SaveManager._collect_fog_of_war_data` / `_apply_fog_of_war_data`
   (lines 1043–1053) are `pass` with a comment saying PaintedWorldMap was
   removed, while `SaveData` still allocates a `FogOfWarSaveData` and writes an
   empty dict into every save file. CLAUDE.md carries a full API table for both
   classes and a worked integration example.
10. **Four keybinds are bound to nothing, including the heavy attack.**
    `heavy_attack`, `block`, `lock_on` and `toggle_camera_mode` are declared in
    `project.godot`'s `[input]` and read by **no input code**. `heavy_attack`
    appears only inside the dead `apply_melee_damage`. `block` exists as an
    `EnemyData` field — enemies can block the player; the player cannot block
    anything. `lock_on_target` is declared at `player_controller.gd:74`, read by
    `hud.gd:611`, and **never assigned**. `toggle_camera_mode` survives only as a
    commented-out line at `camera_pivot.gd:137`.

---

# Batch 1 — Stop the calls that cannot land (26–35)

**Theme:** every task here is a method or a setting that does not exist, on a
path a player walks. These are hard failures, not degradations, and several sit
under `if Autoload:` guards that read as defensive and are not. Nothing later in
this list can be trusted until the boot and the basic verbs stop throwing —
Batch 4's combat work in particular is unmeasurable while the nav regions in 14
levels are rejected.

> **BATCH 1 DONE 8/1.** All ten tasks landed, ten commits. Validator held at
> 0 errors / 228 warnings; all seven pre-existing check scenes green, plus two
> new ones (`check_navmesh.tscn`, `check_autoload_api.tscn`).
>
> **26–32, the broken calls.** Nine sites across seven files repaired against
> the real APIs: `InventoryManager.gold` for the three gold gates,
> `make_check`/`speech_check` for the four dice sites, `change_scene` and
> `return_to_wilderness` for the two SceneManager sites,
> `PlayerGPS.current_location_id` for the escort, `FlagManager.set_flag` for
> the betrayal record, `play_sfx_3d` for the four sea-monster growls (whose
> files do exist on disk, so they go from throwing to audible). Two members
> genuinely had to be written: `ConversationSystem.get_last_scripted_choice_index()`
> and `AudioManager.play_ui_sound()`.
>
> **28 was misdiagnosed.** The audit expected ConversationSystem to already
> hold the choice index. It holds the LINE index, and `_end_scripted_dialogue()`
> zeroes it before the callback runs, so a real field was needed. Worse, all
> three jail doors were comparing the getter's result against their choices'
> `next_index` values rather than the ordinal the UI passes — a working getter
> alone would have picked the lock when the player asked to examine it. The
> call sites were corrected too.
>
> **33 was misdiagnosed in the project's favour and against it at once.** The
> `cell_size` mismatch was real and is fixed — sunken_crypt boots with zero
> `nav_region_3d.cpp` error lines where it had two. But fixing it did not make
> one of those fourteen levels pathable, and the thirty-two the audit called
> correct were not pathable either. Measured by booting all 51 level scenes and
> reading the baked mesh back: **before this batch every level in the game baked
> polygons = 0.** Two further causes, both proven by instrumented boot: all 45
> level scripts leave `geometry_source_geometry_mode` at ROOT_NODE_CHILDREN,
> which parses the region's own children, of which every region in this project
> has none; and the four CSG-built levels plus falkenhaften bake before their
> geometry exists. Elder Moor went 0 → 1998 polygons on the first fix alone.
> Every level that assigns a navmesh now bakes a real one. Five assign none at
> all (bandit_hideout_level_1/2, cultist_ruins_corner, cultist_temple,
> cultist_temple_2) — a different bug, recorded, not invented around.
>
> **35 found two more of the same class the audit missed**, both under an
> always-true guard: `QuestManager.active_quests` (the harbour route list) and
> `TournamentManager.end_tournament` (dev scene). It resolves 3,797 autoload
> member references and skips the ten that sit behind a correct
> `has_method`/`has_signal` test.
>
> **34 was not executed as written.** 313 always-true guards remain. Dedenting
> 313 blocks across 117 files, several with `else:` fallbacks, unplayed, is a
> worse risk than the no-ops it removes. The rule is written down once in
> CLAUDE.md and the count is ratcheted in `check_autoload_api.tscn` — it can
> fall, never rise.
>
> **Eye gate outstanding.** Not one line of this was played. Specifically:
> enemies can path in these levels for the first time, so any impression of AI
> or difficulty formed before today was formed with pathing switched off. And
> `crossroads_ruins` now emits a "more than 2 edges occupy the same
> rasterization space" navmesh-quality error — a complaint about overlapping
> level geometry that could only appear once a navmesh existed. It wants a
> geometry pass, not a nav pass.

### 26. `InventoryManager.get_gold()` does not exist — 3 call sites — **S**
- **System:** `scripts/systems/travel/boat_travel_manager.gd:659`,
  `scripts/systems/travel/fast_travel_manager.gd:408`,
  `scripts/core/game_systems.gd:551`
- **Evidence:** `grep -n 'func get_gold' scripts/systems/economy/inventory_manager.gd`
  → no match. The public field is `var gold`. All three sites are gold-cost
  gates: sea fare, caravan fare, guard bribe.
- **Fix:** replace with `InventoryManager.gold`. Do **not** add a `get_gold()`
  wrapper — a second accessor for the same field is how this happened. Then
  grep the repo for any other `InventoryManager.<name>()` that is a field.
- **Note:** the 8/1 fix put gold on `InventoryManager` because `CharacterData`
  had no `gold` field. These three sites were missed in that sweep.

### 27. `DiceManager.skill_check()` does not exist — 4 call sites — **S**
- **System:** `scripts/systems/travel/boat_travel_manager.gd:545,578`,
  `scripts/characters/npcs/jail_guard.gd:597,650`
- **Evidence:** `grep -n 'func skill_check' scripts/core/dice_manager.gd` →
  no match. Real API: `make_check`, `passive_check`, `speech_check`,
  `lockpick_check`, `bravery_check`.
- **Fix:** map each site to the right real method by what it is checking
  (flee-encounter and resolve-encounter are ability checks; the two jail sites
  are intimidate/persuade → `speech_check`). Match the return-dictionary shape
  the callers already destructure.

### 28. `ConversationSystem.get_last_scripted_choice_index()` does not exist — **S**
- **System:** `scripts/world/interactables/jail_cell_door.gd:100`,
  `scripts/world/interactables/jail_exit_door.gd:91`, `scripts/world/interactables/prison.gd:571`
- **Evidence:** only `select_scripted_choice(idx)` exists — a setter with no
  getter. All three sites are the jail lockpick dialogue-choice flow, which with
  27 means the jail is doubly unescapable.
- **Fix:** add the getter to `ConversationSystem` (it already holds the index
  internally), or have the three doors read the index they passed in.

### 29. `SceneManager.goto_scene()` and `transition_to_adjacent_room()` do not exist — **S**
- **System:** `scripts/systems/puzzles/puzzle_portal.gd:220`,
  `scripts/generation/towns/town_generator.gd:794`
- **Evidence:** real API is `change_scene(scene_path, spawn_id, fade)`. Both
  sites sit under `if SceneManager:`, which is always true. Breaks the puzzle
  portal teleport and *exiting a procedurally generated town*.
- **Fix:** `goto_scene` → `change_scene`. `transition_to_adjacent_room` has no
  equivalent — route the town exit through `SceneManager.RETURN_TO_WILDERNESS`,
  which is the pattern `ZoneDoor` already uses.

### 30. `WorldGrid.get_current_location()` does not exist — **S**
- **System:** `scripts/characters/npcs/escort_npc.gd:281`, under `if WorldGrid:`
- **Evidence:** `WorldGrid` exposes `get_cell(coords)`; the player's live
  position is `PlayerGPS.current_cell` / `current_location_id`. Escort NPC
  location logic throws.
- **Fix:** `WorldGrid.get_cell(PlayerGPS.current_cell)`, or read
  `PlayerGPS.current_location_id` directly — PlayerGPS is the documented single
  source of truth for where the player is.

### 31. `DialogueManager.set_dialogue_flag()` does not exist — **S**
- **System:** `scripts/systems/quests/quest_manager.gd:1756`
- **Evidence:** no such method on `DialogueManager`; the real one is `set_flag`,
  which itself delegates to `FlagManager.set_flag`. The site is the
  faction-quest-failed-via-temptation flag write, so a betrayal outcome silently
  throws instead of recording itself.
- **Fix:** call `FlagManager.set_flag()` directly — that is where the value lands
  anyway, and it removes one hop through a shim.

### 32. `AudioManager.play_sound_3d()` and `play_ui_sound()` do not exist — 6 sites — **S**
- **System:** `scripts/systems/travel/boat_voyage.gd:464,486,1832,1873`;
  `scripts/systems/dialogue/dialogue_manager.gd:672`;
  `scripts/systems/dialogue/conversation_system.gd:2226`
- **Evidence:** real methods are `play_sfx_3d()` and the specific
  `play_ui_select/confirm/cancel/open/close()`. The four boat sites are every
  sea-monster growl. The two dialogue sites are the dispatch for the
  **`PLAY_SOUND` dialogue action**, which CLAUDE.md documents as supported — it
  would throw the first time a writer used it. No `data/` file uses
  `"type": "play_sound"` today, so it is a loaded trap rather than a live crash.
- **Fix:** `play_sound_3d` → `play_sfx_3d`. For `play_ui_sound(param)`, either
  add a generic `play_ui_sound(name)` dispatcher to AudioManager or map the
  action's `param_string` onto the existing wrappers.

### 33. Navmesh rejected in 14 levels — nothing can path — **M**
- **System:** `project.godot` (no `[navigation]` section) vs.
  `scripts/levels/{athenaeum, crossroads_ruins, cult_hideout, dalhurst_cemetery,
  dusty_hollow, iron_hall, kings_watch, mosshall_tombs, pola_perron_crypt,
  riverside_village, sunken_crypt, tenger_camp, whalers_abyss, windmere}.gd`
- **Evidence:** **VERIFIED BY RUN.** Booting `sunken_crypt.tscn` headless:
  `ERROR: … cell_size of 0.30000001192093 while assigned to a navigation map set
  to a cell_size of 0.25` at `nav_region_3d.cpp:104`, plus the matching
  `cell_height` 0.2 vs 0.25 error at line 108. `set_navigation_mesh` returns
  early on mismatch, so the region ends up with **no navmesh**. 32 level scripts
  use the correct 0.25; 14 do not.
- **Fix:** normalise all 14 to `cell_size = 0.25` / `cell_height = 0.25`. Do it
  in the level scripts rather than by widening the project default, so the
  agreement is visible where the mesh is built. Then re-bake and confirm agents
  path. Guard it: extend the boot sweep to fail on any nav error line.
- **Then re-check:** any "enemies don't chase me" or "NPCs stand still"
  impression formed in these levels was formed without navigation.

### 34. `if Autoload:` used as a method-existence guard — **S**
- **System:** the call sites in 27, 29, 30 and elsewhere
- **Evidence:** an autoload in `project.godot` is always non-null, so
  `if DiceManager:` / `if SceneManager:` / `if WorldGrid:` guard nothing. Five of
  the nine broken-call sites in this batch are wrapped in one. The codebase
  *also* uses the correct `has_method()` form in five places
  (`cell_streamer.gd:372,391,422`, `ui_manager.gd:78,88`) — so both idioms are
  live and one of them is a lie.
- **Fix:** after 26–32 land, sweep `if <AutoloadName>:` and either delete the
  guard (the autoload is always there) or convert to `has_method()` where the
  call is genuinely optional. Write the rule down once.

### 35. New guard: `tools/check_autoload_api.tscn` — **M**
- **System:** new tool, alongside the seven existing `check_*.tscn`
- **Evidence:** nine nonexistent-method call sites across seven files reached a
  milestone build. There is no check that catches them; GDScript resolves
  autoload calls at runtime, so nothing fails until a player walks the path.
- **Fix:** a headless probe that greps every `<AutoloadName>.<identifier>(`
  across `scripts/`, resolves the autoload's script from `project.godot`, and
  asserts the method exists on it (`has_method` on the singleton, or the property
  list for field access). Emit a whitelist for genuine dynamic dispatch. Add to
  the session gate beside `validate.ps1`.
- **This is the batch's real deliverable** — 26–32 are the symptoms it would
  have caught.

---

# Batch 2 — Make the save file hold the game (36–45)

**Theme:** every gap here is state the player earned and the save file does not
carry, or state the New Game path fails to clear. Batch 1 must land first —
several of these are only observable once the systems they belong to stop
throwing. This batch ends by generalising the one guard that already works, so
the next dropped field fails the day it is written rather than a month later.

> **BATCH 2 DONE 8/1.** All ten tasks landed, nine commits (42 and 43 are the
> same bug in the same shape and share one). Validator held at 0 errors / 228
> warnings; all nine existing check scenes green, plus a new
> `check_serialization.tscn`. Real headless boot clean.
>
> **Every one of the ten was reproduced before it was fixed.** A scratch probe
> dirtied each field, ran the real `SaveManager.save_game` / `load_game` pair,
> and printed DROP or PASS. Fourteen of fifteen assertions read DROP on the
> first run. That probe is gone; task 45 is its permanent replacement.
>
> **36–37, the flag store.** `reset_world_state()` never touched
> `FlagManager.flags`, so a new character inherited the last run's guild ranks
> and devotions — proved, fixed, and `check_fresh_boot` now walks the real New
> Game path (19 checks → 23; it dirties a rank, a devotion, a flag context and
> a world fact and demands all four are gone). Flags also persisted only by
> accident: `SaveManager` had **no reference to FlagManager at all**, and
> `DialogueManager.to_dict()` was the courier, under a comment saying the
> opposite. `FlagManager` now has a real section, `context_variables` is
> carried, and `DialogueManager`'s shadow store, its `to_dict`/`from_dict` and
> its nine always-true `if FlagManager:` fallbacks are deleted (guard ratchet
> 313 → 304).
>
> **The version drift was worse than task 54 describes.** `SAVE_VERSION` was
> two constants, `SaveManager`'s at 5 and `SaveData`'s at 7 — which is why the
> "Version 5 → 6" block could never run. There is now one constant. Bumping to
> 8 made the old blocks live, so they are guarded: an unguarded 5→6 would have
> wiped the weather every v5 save already carried. 6→7 fills in WorldState, 7→8
> renames `dialogue.flags` and back-solves `total_ip_earned` from `level`.
> Verified against a hand-written version 5 save.
>
> **38–44, the dropped fields.** `total_ip_earned` (both hand-copies), the
> crime return scene and position, the quest countdown timers and the paused
> ones, the whole of `FastTravelManager`, `TournamentManager` and
> `CaveManager`, and the follower's state. `check_quest_engine` was extended to
> reflect over `QuestManager`'s own member state — the exact gap that let the
> timers through — and verified to bite.
>
> **45 is the batch's real deliverable.** `tools/check_serialization.tscn`, 417
> checks over seventeen classes. It is not just check_quest_engine pointed at
> more classes: it round-trips through the **real SaveManager save/load pair,
> on disk**, because every bug in this batch was a class with a perfectly
> correct `to_dict` that SaveManager never called, read three keys out of, or
> replaced with a hand-copy. A class-only guard would have passed on all of
> them. Verified by re-breaking two of the fixes; it names both.
>
> **Three tasks were partly misdiagnosed, and are recorded rather than forced.**
> - **40.** `_quest_spawns` cannot be carried. It holds live node references,
>   every one freed by the scene change a load performs. It is declared
>   transient with that reason. The real gap it exposes is different and is
>   **open**: a chest or hostage from `spawn_on_accept` is not respawned after
>   a load at all.
> - **41.** "Saving mid-caravan strands the journey" cannot happen today — the
>   caravan system is dead code by its own header comment, `_load_caravan_routes()`
>   is a stub and `caravan_routes` is always empty. The save path is fixed
>   anyway, and the fast-travel fields beside it are live.
> - **37's third flag store.** `SaveManager.world_flags` has five writers
>   (`game_systems`, `quest_manager` ×4) and **zero readers anywhere in the
>   repo**. Deleting it changes the save format again and belongs with Batch
>   5's deletions.
>
> **Two dead keys were deleted rather than carried.** `CaveManager.get_save_data`
> wrote `areas` (every CaveArea serialised) and `active_cave_id`, and
> `load_save_data` read neither — `area_data` is rebuilt from the cave model's
> markers on registration. A key nothing reads is the same trap as a field
> nothing writes.
>
> **Eye gate outstanding, and one rules call inside it.** Nothing here was
> played. Specifically worth his eyes: a follower knocked unconscious now
> **stays** unconscious across a save (its 30-second recovery timer restarts);
> letting a load heal him would have made reloading the cheapest way to pick a
> companion up, but that is a design reading, not a fact. And arena fame and
> winnings now persist for the first time, so any impression of the Bloodsand
> Arena's progression formed before today was formed with the scoreboard wiped
> on every load.

### 36. `FlagManager` is never cleared on New Game — **S**
- **System:** `scripts/core/save_manager.gd:1889` `reset_world_state()`
- **Evidence:** the function resets eleven systems by name and clears
  `DialogueManager.dialogue_flags` (line 1915) — but never touches
  `FlagManager.flags`. `FlagManager.reset_for_new_game()` exists
  (`flag_manager.gd:454`) and has **zero callers repo-wide**. Consequence: a new
  character inherits the previous run's deity devotion, all guild-rank gate
  flags, and every mirrored world fact.
- **Fix:** call `FlagManager.reset_for_new_game()` from `reset_world_state()`.
  Extend `check_fresh_boot.tscn` to set a flag, start a new game, and assert it
  is gone — the current smoke test only proves flags survive a *load*.

### 37. `FlagManager` persists only by accident, and drops `context_variables` — **M**
- **System:** `scripts/systems/dialogue/dialogue_manager.gd:1169-1187`,
  `scripts/core/flag_manager.gd:442-456`, `scripts/core/save_manager.gd`
- **Evidence:** `SaveManager` contains **no reference to FlagManager at all**.
  Flags survive only because `DialogueManager.to_dict()` returns
  `FlagManager.flags.duplicate()` and `from_dict()` assigns it back — under the
  comment *"FlagManager handles its own save/load, but we keep dialogue_flags in
  sync for backward compatibility."* Both halves of that sentence are false.
  `FlagManager.to_dict/from_dict` are dead. `context_variables`
  (`flag_manager.gd:128`, the substitution context behind
  `{merchant_id}:befriend` flag names) is in neither path and is lost on load.
  `DialogueManager.dialogue_flags` is left as a stale shadow copy that diverges
  after the first `set_flag`.
- **Fix:** give `FlagManager` a real section in `SaveManager` (collect + apply),
  serialise `context_variables`, delete the `dialogue_flags` shadow store or
  make it a read-only view, and correct the comment. Bump the save version and
  migrate the old `dialogue_flags` key forward.
- **Also note:** three parallel flag stores now exist — `FlagManager.flags`,
  `WorldState.flags`, and `SaveManager.world_flags` (with its own
  `set_world_flag`/`get_world_flag` at lines 1714–1724). Decide which two survive.

### 38. `CharacterData.total_ip_earned` dropped by save/load — **S**
- **System:** `scripts/core/save_manager.gd:486-511` and `816-836`
- **Evidence:** the field is declared at `character_data.gd:42`, incremented by
  `add_ip()` (132), and is the **only** input to the level threshold table (137)
  and the XP bar's in-level progress (513). Both the collect and apply
  hand-copies omit it. `SaveData.PlayerSaveData` has no slot for it either.
- **Fix:** add the field to `PlayerSaveData` and to both hand-copies; migrate old
  saves by back-solving from `level` via `IP_PER_LEVEL`.

### 39. `CrimeManager.return_scene` / `return_position` dropped — **S**
- **System:** `crime_manager.gd:454-455` → `save_manager.gd:615-626` →
  `save_data.gd:560` (`CrimeSaveData`)
- **Evidence:** `CrimeManager.to_dict()` writes both. `_collect_crime_data()`
  reads only six other keys out of that dict, and `CrimeSaveData` has no fields
  for them. Save while jailed and reload: the location to return the player to
  after serving time is `""` / `Vector3.ZERO`.
- **Fix:** add both to `CrimeSaveData` and to the collect/apply pair.

### 40. `QuestManager` timers and spawns dropped — **M**
- **System:** `quest_manager.gd:2648` (`to_dict`), `:172`, `:871`;
  `save_manager.gd:590-600`
- **Evidence:** `to_dict()` includes `"timed_objectives"`, but
  `_collect_quest_data()` extracts only `quests`, `tracked_quest_id` and
  `bounty_cooldowns`, and `QuestSaveData` has no field for it — any countdown
  objective loses its deadline. `_paused_timers` and `_quest_spawns` are member
  state that `to_dict()` never writes at all.
- **Fix:** carry all three through `QuestSaveData`. This is inside the class
  `check_quest_engine.tscn` guards — extend the guard to cover `QuestManager`'s
  own member state, not just `Quest`/`Objective` fields, since that is precisely
  the gap it missed.

### 41. `FastTravelManager` save hooks never called — **S**
- **System:** `fast_travel_manager.gd:301` / `:310`
- **Evidence:** working `to_dict`/`from_dict`; `SaveManager` calls neither.
  Lost on save: `caravan_routes` and the whole in-progress caravan state
  (`is_caravan_traveling`, `caravan_destination`, `caravan_segments`,
  `caravan_current_segment`). Saving mid-caravan strands the journey.
- **Fix:** wire into the save pipeline with a `FastTravelSaveData` section.

### 42. `TournamentManager` save hooks never called — **S**
- **System:** `tournament_manager.gd:460` / `:471`
- **Evidence:** same shape. `total_gold_earned` and `arena_fame` are
  progression, not session state, and reset to zero every load. The Bloodsand
  Arena's entire sense of standing is unsaved.
- **Fix:** wire it in. Confirm against the 8/1 fix that made arena winnings
  actually pay — those winnings currently do not persist.

### 43. `CaveManager` save hooks never called — **S**
- **System:** `cave_manager.gd:439` / `:456`
- **Evidence:** same shape. `visited_areas`, `area_data`, `cave_danger_level` are
  per-area persistent state. Every cave is fresh on every load.
- **Fix:** wire it in.

### 44. `FollowerNPC` writes a state it never reads back — **S**
- **System:** `scripts/characters/npcs/follower_npc.gd:702` (write), `:727-770` (read)
- **Evidence:** `get_save_data()` writes `"state": current_state`;
  `load_save_data()` never reads the `"state"` key. Followers always come back
  `FOLLOWING`, regardless of whether they were `WAITING` or `UNCONSCIOUS`. A
  follower told to wait rejoins the player through any zone transition.
- **Fix:** read the key back. Decide explicitly whether `UNCONSCIOUS` should
  survive a load or heal (that is a rules question with a defensible default:
  restore it, since `recover_from_unconscious()` exists).

### 45. Generalise the field guard to every `to_dict`/`from_dict` pair — **L**
- **System:** new `tools/check_serialization.tscn`, modelled on
  `tools/check_quest_engine.gd`
- **Evidence:** `check_quest_engine.tscn` is the **only** reflection-based field
  guard in the repo, and it covers exactly two classes. Tasks 38, 39, 40 and 44
  are four more instances of the same bug in four unguarded classes, found by
  hand. Roughly two dozen `to_dict`/`from_dict` pairs exist.
- **Fix:** a headless probe that, for each registered class, reads the property
  list by reflection and asserts (a) every non-transient field appears in
  `to_dict`, (b) every key `to_dict` writes is read by `from_dict`, (c) a
  dirty→save→load round trip returns every field. Carry a declared
  `TRANSIENT_FIELDS` whitelist per class so "deliberately not saved" is written
  down rather than assumed. Cover `CharacterData`, `FollowerNPC`, `CrimeManager`,
  `FactionManager`, `WorldState`, `ConversationSystem`, `WeatherManager`,
  `SoulstoneEconomy`, `GuildRankManager`, `MoralityManager`, `CodexManager`,
  `JournalManager`, `StatsTracker`.

---

# Batch 3 — Wire the quest and dialogue data the engine never reads (46–56)

**Theme:** content authors have been writing keys and types the code does not
handle, and nothing warns. Batch 2 must land first — several of these fixes make
new state that then has to survive a save. This batch ends by teaching the
validator to catch the whole class, so authoring a dead key becomes a red
session gate instead of a silent no-op.

> **BATCH 3 DONE 8/1.** All eleven tasks landed, ten commits (49 and 50 are the
> same bug in two tables and share one). Validator held at **0 errors**, and
> warnings fell **228 → 179**. All ten check scenes green, plus the new gates.
> Real headless boot clean.
>
> **Commits were not taken in numeric order,** and the reason is the warning
> ratchet: 46 legitimately *creates* nine warnings, so 53 and 52 (which remove
> 55 between them) landed first. Every commit therefore held or lowered the
> count, which is now enforced by a hook rather than by intention.
>
> **46, the headline. Reproduced before it was fixed.** A probe started all nine
> affected quests and fired every driver `QuestManager` owns at every objective:
> **21 objectives across nine quests could not be settled by anything the engine
> can do.** After the fix, **eight of the nine complete**; the ninth
> (`mage_repeatable_research`) is the `variable` type, a design call, tabled in
> dispositions §2i. Both guild ladders are unblocked: `thieves_10` through
> `thieves_13` and `mage_05`/`mage_13` all finish.
>
> Types were mapped onto machinery that already existed rather than new systems:
> `kill_or_persuade`/`combat_or_talk` → OR groups (step 21); `puzzle` →
> `solve_puzzle` off the puzzle controller's flags; `lockpick`/`revelation`/
> `heist_event`/`investigate` → `interact` against `QuestInteractable`
> (step 24); `special_combat` → `duel_win`. Only `has_item` needed a real
> handler — it is a question about the pack, not a count of pickups, so it polls
> on offer and on pickup.
>
> **The reproduction found two things the audit did not.** `thieves_09` and
> `thieves_13` could not settle their `choice` objectives either: both author
> `choice_paths`, a key the engine has never read, and
> `apply_choice_consequence` returns early unless the branch is in
> `choice_consequences`. And `soulstone_greater` is an item id that has never
> existed (the real ones are `..._empty`/`..._filled`).
>
> **48 uncovered a second instance of task 36.**
> `GuildRankManager.reset_for_new_game()` had **zero callers repo-wide**, exactly
> as `FlagManager`'s did. Task 36 cleared the rank *flags* on New Game; the
> ladder itself — `guild_rank_levels`, `guild_quest_counts` — was never touched,
> so a new character started twelve quests into the Thieves Guild with the badge
> taken off him. Reproduced in `check_fresh_boot` (3 of 26 red) before fixing.
>
> **50 was much larger than the audit measured.** It named `morality` and
> `guild_rank`. The real data uses `flag` (52), `faction_reputation` (14) and
> `quest_active` (1) — spellings the loader parsed *none* of. **67 gated dialogue
> choices have been standing open**, because an unparsed condition coerced to
> `NONE` and a `NONE` condition passes. That also meant "make the default fail
> closed" could not be done alone: flipping it without teaching the loader those
> three spellings would have *hidden* 67 choices instead of ungating them. Both
> halves landed together, with a new `ConditionType.INVALID` that is immune to
> `invert`.
>
> **53 was worse than "a validator-counting artifact."** `QuestManager`'s own
> loader walks `data/quests/` recursively, reaches `_future/` last, and lets it
> **overwrite**. Proved by boot: `aberdeens_blessing` was loading with giver
> `priest_chronos_aberdeen` and `missing_miner` with the typo'd
> `mayor_aberdeeen`, both NPCs spawned nowhere. The repaired shipped versions
> were being thrown away, so both quests were unofferable in the milestone build.
>
> **55: `.git/hooks/` would never have run.** The audit found the directory empty
> and concluded there was no hook. This repo sets
> `core.hooksPath = .beads/hooks`, so a hook installed the obvious way is a
> silent no-op — the same shape as everything else in this document.
> `tools/install_hooks.ps1` resolves the real path and appends its own marked
> section below the beads block. Proved in both directions (a bogus reward key
> blocks with "1 validator ERRORS", a bogus enemy id with "warnings rose
> 179 → 180"), and it fired on this batch's own last commit.
>
> **56 found a third hand-copy about to be written.** There was no canonical
> skill → stat map: `DialogueManager` and `ConversationSystem` each kept one and
> **they had already drifted**. `DiceManager` owns it now, both delegate, and the
> guard asserts all three agree for every skill in the enum.
>
> **The class-closing guards.** `check_quest_engine` grew from 19 to 292 checks:
> every type in `HANDLED_OBJECTIVE_TYPES` is now driven end to end through the
> same entry point the game uses (a type on the list with no driver fails, so
> adding to the list must be paid for), every type in shipping data must be on
> that list or deferred **with a written reason**, and a deferred type that stops
> shipping fails as a stale excuse. Verified by re-breaking two fixes.
> `validate_content` learned all four vocabularies — objective types, reward
> keys, consequence keys, and both dialogue tables — **read out of the engine's
> own source** so they cannot rot, verified by poisoning a quest.
> `check_serialization` gained a migration-ladder assertion so task 54's bug
> shape (a block above `SAVE_VERSION` that can never run) cannot recur.
>
> **Three tasks were partly or wholly misdiagnosed, and are recorded.**
> - **52.** `tomas_informant` is not a mistyped `talk` objective. It is an
>   *optional* `kill` on a real spawned killable NPC, beside a `talk` objective
>   on the same man, described as "kill, bribe, or intimidate" — an OR group
>   waiting to be authored. Four more ids (`any_enemy_with_magic`,
>   `bounty_target`, `contract_enemy`, `bandit_crossroads_group`) are an engine
>   gap, not missing stat blocks.
> - **54.** Obsolete on arrival: batch 2 had already collapsed the two
>   `SAVE_VERSION` constants and gone to 8. Per instruction no second constant
>   was reintroduced; the *class* was guarded instead.
> - **47.** `optional_rewards` is read by nothing and appears in one quest.
>   Recorded, not fixed — it is a top-level key, outside 51's four vocabularies.
>
> **Warnings this batch deliberately created (9), all itemised in dispositions
> §2j.** Seven newly-*executable* quest branches that no dialogue node fires yet
> (the cheapest content work in the file), and two antagonists the validator can
> finally see and which need stat blocks.
>
> **Eye gate outstanding, and it is bigger than usual.** Nothing here was played.
> Specifically:
> 1. **67 dialogue choices that were always shown are now conditional.** Any
>    impression of how gated the conversation system feels — guild-rank options,
>    reputation options, quest-state options — was formed with every gate open.
>    This is the single most visible change in the batch and it needs eyes.
> 2. **Two quests come back from the dead with different givers.**
>    `aberdeens_blessing` is Father Aldwin's now, not a priest who does not
>    exist; `missing_miner` is Mayor Bjorn Aberdeen's. Both were unofferable.
> 3. **The Thieves and Arcane Circle ladders are completable for the first
>    time**, but their last quests want world content: interactables for the
>    vault, the clues, the ledger, the convoy and the parleys, and dialogue nodes
>    for the seven new branches. The engine no longer blocks them; the world
>    still does.
> 4. **A new character no longer inherits guild rank.** Any save made before
>    today may carry ranks from an earlier playthrough.
> 5. **`.claude/hooks.json` is still inert prose** naming six agents that do not
>    exist. It is Caleb's configuration, not an agent's to rewrite.

### 46. Ten objective types have no handler — guild capstones uncompletable — **L**
- **System:** `scripts/systems/quests/quest_manager.gd`; `data/quests/guild/thieves/`,
  `data/quests/guild/mages/`, `data/quests/noble_soulstone_request.json`
- **Evidence:** parsing all 55 quest JSONs yields 21 distinct objective `type`
  values. `quest_manager.gd` dispatches `kill`, `collect`, `talk`,
  `reach`/`explore`, `interact`, `choice`, `deliver_soulstone`, `solve_puzzle`,
  `recruit_follower`, `wave_defense`, `craft`, `escort` (via
  `on_escort_arrived`). **Unhandled and unreachable:** `has_item`
  (`noble_soulstone_request`), `kill_or_persuade` (`mage_05_rogue_mage`),
  `special_combat` (`mage_13_council_seat`), `variable`
  (`mage_repeatable_research`), `lockpick` (`thieves_10_government_job`),
  `puzzle` ×2 (`thieves_11_impossible_vault`), `revelation` and
  `combat_or_talk` (`thieves_12_guild_traitor`), `heist_event`
  (`thieves_13_right_hand`), `investigate`. None have a `world_condition` or
  `group` escape.
- **Fix:** per type, either implement the handler or convert the data to an
  existing type. Cheapest honest mapping: `has_item` → poll inventory on offer
  and on pickup; `kill_or_persuade` / `combat_or_talk` → an **OR group** of
  `kill` + `talk` (the engine already supports this, built in step 21);
  `lockpick`/`puzzle`/`revelation`/`heist_event` → `interact` against a
  `QuestInteractable` (built in step 24). `special_combat` → `duel_win`, which
  already exists. `variable` needs a design call on what a repeatable research
  task *is* — if that turns out to be a quest-design question, table it in
  `wave_b_dispositions.md` rather than inventing.
- **Impact:** the Thieves ladder needs 12–14 guild quests for its top rank; four
  of the last five cannot be finished.

### 47. Reward key typos — reputation silently never granted — **S**
- **System:** `data/quests/eastern_wolves.json`, `lost_woodsman.json`,
  `noble_soulstone_request.json`
- **Evidence:** `quest_manager.complete_quest()` (1624–1685) reads exactly nine
  reward keys. A key census over all quest data: `faction_reputation` ×203,
  and then `reputation` ×2 and `reputation_changes` ×1 — three quests using the
  wrong key name for the same thing. `{"thornfield": 15}`, `{"thornfield": 10}`
  and `{"nobility": 15, "dalhurst": 10}` are never granted.
- **Fix:** rename the keys in the three data files to `faction_reputation`.

### 48. Reward type `title` is not implemented — **S**
- **System:** `data/quests/guild/thieves/thieves_13_right_hand.json`
- **Evidence:** `"title": "Guildmaster's Hand"` in the rewards block; no
  title-granting code exists anywhere. The capstone's headline reward is inert
  flavour text.
- **Fix:** either implement a minimal title (a `FlagManager` flag plus a display
  string the HUD/journal can read — `GuildRankManager` already owns exactly this
  shape of thing), or drop the key and give the quest a real reward. Small
  either way; the first is the better fit with the guild rank system.

### 49. `spawn_errand` action cannot be written from JSON — **S**
- **System:** `scripts/systems/dialogue/dialogue_loader.gd:164-193`,
  `scripts/systems/dialogue/dialogue_data.gd:65`,
  `scripts/systems/dialogue/dialogue_manager.gd:678`
- **Evidence:** `ActionType.SPAWN_ERRAND` is in the enum and **is dispatched** at
  runtime, but `_parse_action_type()` has no `"spawn_errand"` case. Any such
  string falls to the `_:` default, which `push_warning`s and coerces to `NONE`.
  All 29 other action types round-trip correctly. Latent — no data file uses it
  yet.
- **Fix:** add the case. Then make the `_:` default a hard error in the loader
  rather than a warning, so the next omission cannot be silent.

### 50. `morality` and `guild_rank` conditions silently evaluate TRUE — **S**
- **System:** `scripts/systems/dialogue/dialogue_loader.gd:138-158` vs.
  `dialogue_manager.gd:444,451,564,576`
- **Evidence:** both `ConditionType.MORALITY` and `GUILD_RANK` are fully
  implemented at runtime. `_parse_condition_type()` has no case for either, so
  `"type": "morality"` / `"guild_rank"` fall through to `NONE` — **and a `NONE`
  condition passes**. A writer gating a choice on guild rank would get a choice
  that is always shown. Worse than the action case, which fails closed.
- **Fix:** add both cases, and make the condition loader's `_:` default fail
  closed (or error) rather than coerce to always-true.

### 51. Validator: fail on unknown objective, reward, action and condition keys — **M**
- **System:** `tools/validate_content.gd`
- **Evidence:** tasks 46–50 are five separate instances of "content names a thing
  the code does not handle" and the validator — which already reads all this
  data — does not check for any of them. It checks that ids *resolve*, not that
  keys are *dispatched*.
- **Fix:** teach it the four vocabularies. Read the handled objective types, the
  nine reward keys, the six consequence keys, and the loader's parse cases
  directly out of the source where possible (so the check cannot rot), and raise
  an **error** — not a warning — for any data key outside them. This is the guard
  that would have caught the dead `explore` objective type and the dead
  response-tier registration before either shipped.

### 52. Repoint 35 near-miss enemy ids — **M**
- **System:** `data/quests/**/*.json`, against the 64 ids in `data/enemies/`
- **Evidence:** the 76 QUEST_ENEMY warnings were filed wholesale as "enemy stats,
  a balance pass, Caleb-blocked" in `wave_b_dispositions.md` §2g. Roughly half
  are not: they are typos and near-misses against enemies that already exist —
  `skeleton`→`skeleton_warrior` (×3), `dark_cultist`→`cultist` (×4),
  `cultist_leader`→`cult_leader`, `cave_spider_queen`→`spider_queen` (×2),
  `ghost_captain`→`ghost_pirate_captain`, `bandit`→`human_bandit`,
  `goblin_warrior`→`goblin_soldier`, `goblin_shaman`→`goblin_mage`,
  `bridge_troll`→`troll`, `malachai_the_profane`→`malachai_profane`,
  `the_timeless_one`→`timeless_one`, `undead_lord`→`undead_lord_malthor`, and
  ~20 more.
- **Fix:** repoint the high-confidence set; leave the ~41 that genuinely need new
  stat blocks in the dispositions file. Expect warnings 228 → roughly 190.
- **Also flag:** `tomas_informant` is a `kill` objective targeting an *informant*
  — that reads like a `talk` objective mistyped, not a missing enemy.
  `any_enemy_with_magic`, `bounty_target`, `contract_enemy` and
  `bandit_crossroads_group` want wildcard/group resolution, which is an engine
  gap, not a content gap. Note both in the dispositions file.

### 53. `_future/` is scanned, and two stale duplicates diverge from the live quests — **S**
- **System:** `tools/validate_content.gd` (`QUEST_DIR` walk is recursive),
  `data/quests/_future/`
- **Evidence:** 15 of the 19 QUEST_NPC warnings and a share of the enemy/item
  warnings come from `data/quests/_future/`, a staging area. Worse,
  `_future/aberdeens_blessing.json` and `_future/missing_miner.json` are **stale
  forks** of live quests: the `_future` copies still name
  `priest_chronos_aberdeen` and the typo'd `mayor_aberdeeen`, where the shipped
  versions were repaired to `father_aldwin` and `mayor_bjorn_aberdeen`. Both
  copies are double-counted in the warning total and one of each pair is
  definitionally wrong.
- **Fix:** delete the two stale duplicates; exclude `_future/` from the walk (or
  scan it under a separate, non-gating heading). Also: `wyvern_scales` →
  `wyvern_scale` is the one genuine item typo in the 59 QUEST_ITEM warnings —
  fix it; the rest are real missing MacGuffins and stay in the dispositions file.

### 54. Dead save-migration block claims v5→v6 while `SAVE_VERSION` is 5 — **S**
- **System:** `scripts/core/save_manager.gd:24`, `:1461-1589`, `:367`
- **Evidence:** `_migrate_save_data` contains a live "Version 5 → 6: Add
  WeatherManager data" block (1576–1587) that sets `migrated["version"] = 6`,
  but `SAVE_VERSION` was never bumped past 5 and `load_game()` only migrates
  `if version < SAVE_VERSION`. The block can never run. Weather saves correctly
  anyway, unconditionally — so the code is harmless and the version table is a
  lie. The next person to add a save-affecting system will find v6 "taken."
- **Fix:** delete the block, or bump `SAVE_VERSION` to 6 and let it run. Do this
  *before* tasks 37–43 bump the version for real.

### 55. Make the validator an actual gate — **S**
- **System:** `tools/validate.ps1`, `.git/hooks/`, `.claude/hooks.json`
- **Evidence:** step 13 of the 25-step plan was "validator into the workflow: a
  pre-commit/session gate so phantom refs can never accumulate again."
  `ls .git/hooks/ | grep -v sample` returns **nothing** — there is no hook.
  `.claude/hooks.json` is prose describing agent triggers in a format Claude Code
  does not execute, and it names six agents (`ui-consistency-checker`,
  `dungeon-validator`, `combat-flow-tester`, …) that do not exist as agent
  definitions. The gate is entirely honour-system.
- **Fix:** install a real `pre-commit` hook that runs `validate.ps1` when the
  staged diff touches `data/` or `scripts/levels/`, fails on any error, and fails
  if the warning count rose against the committed report. Then add the other
  `check_*.tscn` probes to it or to a `run_all_checks.ps1`.

### 56. `QuestManager` never reads a quest's `skill_checks`, and DECEPTION is dead — **M**
- **System:** `scripts/systems/quests/quest_manager.gd`,
  `data/quests/guild/thieves/thieves_07_noble_heist.json:62`
- **Evidence:** the quest declares `{"type": "deception", "dc": 14}` in a
  `skill_checks` block that `QuestManager` never reads — there is no
  `skill_checks` handling anywhere. `Enums.Skill.DECEPTION` has no gameplay
  consumer at all: it is raisable and read only by cosmetic label lookups. 24 of
  25 skills have a real formula consumer; Deception is the sole fully dead one.
  (CLAUDE.md also flags INVESTIGATION as TODO — that note is **stale**:
  `get_hidden_detection_bonus()` is live-called from `hidden_chest.gd:109` and
  `secret_wall.gd:123`. Only the "press NPCs for info" sub-feature is unbuilt.)
- **Fix:** either implement `skill_checks` on objectives (routing through
  `DiceManager` — the dialogue system already does this well and can be copied)
  or delete the block from the data. Give DECEPTION at least one real consumer.
  The **consequences** of a failed deception are a design call and belong in
  `wave_b_dispositions.md`; the plumbing does not.

---

# Batch 4 — Make a hit feel like a hit (57–67)

**Theme:** the first ten minutes. A fresh player swings a sword and gets no
sound, no crit, and no number; walks into a biome with no ambience; and has four
keys bound to nothing. Batches 1–3 make the game *correct*; this batch is the
first one aimed at whether it is any good. Nothing here is art — every audio task
is repointing code at files that already exist on disk, and anything with no
asset at all goes to `art_replacement_manifest.md`.

> **BATCH 4 DONE 8/1-8/2.** All eleven tasks landed, ten commits (62 and 63
> are the same dead-input class and share one), plus two commits for bugs the
> wiring exposed. Validator held at **0 errors / 179 warnings**; all eleven
> existing check scenes green plus a new `check_audio_events.tscn`; real
> headless boot clean.
>
> **57, the headline. Reproduced before and after.** `apply_melee_damage` had
> zero callers - proved by grep across the whole repo, then by a probe: a
> hitbox hit emitted **no signals at all**, and after routing every hit emits
> `damage_dealt`. Hitbox now carries an optional WeaponData; set, it hands the
> hit to CombatManager and keeps only its knockback, and left null (unarmed,
> every enemy hitbox) it behaves exactly as before. Weapon degradation moved
> with the damage - per landed hit, not per swing - so a hit is not charged
> twice.
>
> **The routing is not damage-neutral, and the numbers are measured.**
> `apply_melee_damage` multiplies by `1 + Grit/10 + Melee/20`, which the live
> path never did, and reduces by the target's armour, which `take_damage` then
> does again. 20,000 swings of a 1d6 weapon against armour 10 with no stat
> bonuses: **2.67 before, 2.01 after** - a 25% drop from the double armour
> alone, which a starting character's Grit roughly cancels and a heavy build
> beats comfortably. Nothing was retuned in either direction; the three ways
> to resolve it are laid out in dispositions 3a for Caleb.
>
> **Two bugs the routing exposed, both fixed in their own commits.**
> `QuestManager._on_entity_killed` counted a kill that `EnemyBase._on_death`
> had already counted, under a comment calling itself a backup - so **every
> spell kill has been advancing kill objectives by two**, and with melee
> routed every kill would have. And every hit spawned **two** damage numbers,
> because CombatManager spawned one and the HUD spawned another off the same
> signal; CombatManager now spawns only for heals and DOT ticks, which the HUD
> cannot hear about. Both were invisible while melee was disconnected.
>
> **58 was misdiagnosed in the audit's own terms.** `apply_ranged_damage`
> could not honestly be routed: it is WeaponData-based and the live ranged
> verb is ProjectileData-based - an arrow's damage belongs to the arrow, and
> routing would have replaced arrow damage with bow damage. Deleted as a
> fossil. What was actually missing is the feedback, and that is shared:
> `CombatManager.report_damage()` gives a projectile hit the signals, the
> number and the kill rewards without touching a damage value.
>
> **XP has never been paid for a melee or a bow kill.** `_handle_kill_rewards`
> is the only `add_ip` on the kill path and only the CombatManager functions
> called it. Until today only *spell* kills granted XP. 57 and 58 fix that as
> a side effect; it is the largest silent progression change in the batch.
>
> **59, the audio layer. Measured before: 113 events, 46 resolving, 67 dead.**
> After: 117 events, 84 resolve, 33 silent and every one of the 33 declared.
> Not 120 hand edits - three tables and a resolver (`EVENT_ALIASES`,
> `EVENT_SUBSTITUTES`, `MISSING_SFX`). No asset was invented or repaired: the
> 33 silent events and the substitutions standing in for them are rows in
> `art_replacement_manifest.md`. 61 settled the other half in one line -
> `play_sfx("player_hit")` now resolves the event name, so the CLAUDE.md audio
> vocabulary is finally understood by the thing it was written for, and
> CLAUDE.md says which of the two options was taken so nobody adds the other.
>
> **60 was worse than the audit found: the class is wired to nothing.**
> `AmbientSoundscape` is instantiated by no script, scene or data file - zone
> ambience goes through `AudioManager.play_zone_ambiance()` instead. Its table
> named 36 loops in a directory that does not exist, and its loader suppressed
> its own warning. Collapsed to the one bed that exists (caves/ruins),
> suppression deleted, 36 loops logged to the manifest, and the wire-it-or-
> delete-it call recorded in dispositions 3d rather than taken.
>
> **62/63, the dead keys.** `heavy_attack` is a real verb now - right mouse
> swings the weapon, never a cast, and passes the +50% flag that has sat
> unused in the damage function since it was written. `block` and `lock_on`
> are real mechanics with real design questions behind them, so per the
> audit's own rule ("do not ship a keybind that does nothing") the bindings
> were **removed** rather than faked; `toggle_camera_mode` went with them, the
> camera script having already disabled it because the game is first-person
> only. `lock_on_target` and the HUD branch reading it are deleted; the target
> health panel now follows the last enemy the player hit, which 57 makes
> knowable.
>
> **64/65/66, the first ten minutes.** The player has a 0.35s mercy window
> after a hit, a hit sound and a shake, and `apply_stagger` reads as something
> rather than a silent boolean. Footsteps are no longer gated to grass biomes:
> surface is looked up, unknown ground is dirt, and silence is never the
> answer - so dungeons, towns and stone floors have footsteps (and stealth
> noise) for the first time. The death screen stops offering saves that do not
> exist; whether death should offer a respawn at all is a design call and is
> logged, not taken. 66 was partly misdiagnosed - the autosave button already
> disabled itself.
>
> **67.** The four feedback signals that carry feel are connected (item_use
> sound, pause ducking, the five follower notifications) and the three dead
> ones deleted - `rank_check_failed` and `LootableCorpse.looted` were never
> emitted, and `GameManager.weather_changed` was a name-collision duplicate of
> the live `WeatherManager.weather_changed`. The other 179 emitted-into-the-
> void signals are left alone deliberately.
>
> **Two numbers were invented, both exported and both labelled.**
> `heavy_attack_cooldown_multiplier = 2.0` (dispositions 3e) and
> `hit_iframe_duration = 0.35` (3f). Nothing else was tuned.
>
> **The class-closing guard: `tools/check_audio_events.tscn`, 252 checks.**
> An event that resolves to nothing must be in `MISSING_SFX`; every
> `MISSING_SFX` entry must be a real event with a manifest row, and fails as a
> stale excuse the day it starts resolving; every substitute must itself have
> a file; and every sound name written at a call site must resolve - which is
> what would have caught `enemy_roar`, `magic_attack`, `gold_drop`,
> `npc_death`, `guard_death` and `kraken_rumble`, six names no table has ever
> contained.
>
> **Eye gate outstanding, and this batch is the one that most needs it -
> nothing here was played.** In rough order of how differently the game will
> behave:
> 1. **Melee damage changed** (see the measured numbers above), melee crits
>    now happen, and melee kills pay XP for the first time. Any impression of
>    difficulty, TTK or levelling speed formed before today was formed with
>    swords disconnected from the combat system.
> 2. **Kill objectives now count once, not twice.** A quest that wanted six
>    bandits was being satisfied by three spell kills.
> 3. **The game makes noise.** Hits, footsteps everywhere, menu clicks, item
>    use, a hit sound and shake when the player is struck, ducking on pause.
>    Several of those are stand-ins (every impact is a sword clank, every menu
>    sound is one click); the point of the eye gate is whether the
>    substitutions read as cheap or as fine.
> 4. **A 0.35s mercy window after every hit** changes what a crowd feels like
>    more than any other line in the batch.
> 5. **Right mouse is a heavy attack** with a 2x cooldown, and Q, F and V no
>    longer do anything (they never did).
> 6. **One damage number per hit, not two.**

### 57. Melee bypasses `CombatManager` entirely — **L**
- **System:** `scripts/systems/combat/combat_manager.gd:93-218`,
  `scripts/systems/combat/hitbox.gd:_apply_hit`,
  `scripts/characters/player/player_controller.gd:_do_light_attack`
- **Evidence:** `grep -rn 'apply_melee_damage' scripts/` returns **only the
  declaration**. 125 lines of crit rolling, lifesteal, `damage_dealt` /
  `critical_hit` emission and `_spawn_damage_number` have zero callers. The live
  melee path goes `_do_light_attack → melee_hitbox.activate() →
  Hitbox._apply_hit() → target.take_damage()`. Spells route correctly through
  `apply_spell_damage` (7 call sites in `spell_caster.gd`), which is why *magic*
  shows damage numbers and crits and *swords* do not.
- **Fix:** route `Hitbox._apply_hit` through `CombatManager.apply_melee_damage`.
  Preserve what the hitbox path already does right (knockback at 137,
  `apply_stagger` with a resistance roll, the backstab bonus and notification at
  158–197) — fold those into the CombatManager path rather than losing them.
- **Impact:** this single change gives melee crits, damage numbers, lifesteal and
  the two signals the HUD already listens on (`hud.gd:1101`).

### 58. `apply_ranged_damage` also has zero callers — **M**
- **System:** `scripts/systems/combat/combat_manager.gd:221`
- **Evidence:** same grep, same result. Bows and muskets take whatever path the
  projectile code takes and get none of the CombatManager treatment.
- **Fix:** find the live ranged damage path and route it through, or delete the
  function. Do it in the same pass as 57 so all three verbs agree.

### 59. `AudioManager`'s event table points at an empty directory — **L**
- **System:** `scripts/core/audio_manager.gd:12-168` (`EVENTS`), `620-684`
  (`play_*` shortcuts), `687-697` (`_load_sound`)
- **Evidence:** ~120 hardcoded paths under `res://assets/audio/sfx/*.wav`.
  `find assets/audio/sfx -maxdepth 1 -type f` → **0**. The 49 real files live in
  `monsters/`, `npc/`, `ui/`, `weapons/`, `walking and movement/`, and
  `foraging and crafting and potion and enchanting/`. `_load_sound` checks
  `ResourceLoader.exists()`, `push_warning`s, returns null; every caller does
  `if not stream: return`. Missing this way: `hit`, `miss`, `block`, `death`,
  `critical_hit`, every `footstep_*`, every `player_*`/`enemy_*`, every `menu_*`,
  every `item_*`, `chest_open`, `door_*`, every `spell_*`, `save_game`.
- **Fix:** repoint every `EVENTS` entry at the real file on disk. Where nothing
  on disk fits (`hit`, `death`, `critical_hit`, the menu set), leave the entry,
  add a row to `art_replacement_manifest.md`, and let `_load_sound` fall back to
  a nearby real sound rather than silence. Then make `_load_sound` `push_error`
  on a miss during development so this can never be quiet again.
- **This is the single largest game-feel item in the list.**

### 60. `ambient_soundscape.gd` targets a directory that does not exist, silently — **M**
- **System:** `scripts/world/ambient_soundscape.gd:42-128` (`SOUNDSCAPES`),
  `:342-344` (`_load_sound`)
- **Evidence:** every path is `res://assets/audio/ambient/*.ogg`; the real folder
  is `assets/audio/Ambiance/` (`cities/`, `towns/`, `ruins/`, `combat arena/`)
  and holds `.wav`. All 7 biomes × day/night × 3 layers resolve to null, and the
  loader's own comment says *"Don't spam warnings for missing ambient sounds
  during development"* — it returns null with **no warning at all**. Every
  outdoor zone has been silent.
- **Fix:** repoint at the real files; there are fewer of them than the table
  wants, so collapse the layer scheme to what exists and log the rest to the art
  manifest. Delete the warning suppression.

### 61. `AudioManager`'s event API has no callers — **S**
- **System:** `audio_manager.gd:754` (`play_event`), `:764` (`play_event_3d`),
  `has_event`, `get_event_path`
- **Evidence:** `grep -rn 'AudioManager.play_event'` → nothing. Gameplay code
  instead calls `play_sfx("some_event_name")`, which treats the argument as a
  **resource path** and fails the `ResourceLoader.exists()` check. So the
  CLAUDE.md audio convention (`player_hit`, `enemy_hit`, `item_pickup`,
  `menu_open`, `footstep_*`) is spoken by call sites and understood by nobody:
  the one function that maps event names to paths is dead.
- **Fix:** after 59, either make `play_sfx` fall back to an `EVENTS` lookup when
  the string is not a path, or convert the call sites to `play_event`. One of the
  two, written down, not both.

### 62. Four dead keybinds, including the heavy attack and block — **M**
- **System:** `project.godot` `[input]`, `scripts/characters/player/player_controller.gd`,
  `scripts/characters/player/camera_pivot.gd:137`
- **Evidence:** `heavy_attack`, `block`, `lock_on`, `toggle_camera_mode` are
  declared and read by no input code. `heavy_attack` appears only as a parameter
  inside the dead `apply_melee_damage` (`is_heavy_attack`, line 98) — so the
  heavy attack is *implemented in the damage function nothing calls* and *bound
  to a key nothing reads*. `block`/`block_chance` exist only on `EnemyData`
  (`enemy_data.gd:39-40`): enemies block the player, the player cannot block.
  `toggle_camera_mode` survives as a commented-out line.
- **Fix:** with 57 landing, `heavy_attack` becomes nearly free — read the action
  and pass `is_heavy_attack: true`. `block` and `lock_on` are real features:
  either build them or remove the bindings, but do not ship a keybind that does
  nothing. Uncomment or delete `toggle_camera_mode`.

### 63. `lock_on_target` is read by the HUD and never assigned — **S**
- **System:** `scripts/characters/player/player_controller.gd:74`, `scripts/ui/hud.gd:611-612`
- **Evidence:** declared `var lock_on_target: Node3D = null`, read by the HUD to
  pick the target nameplate, **assigned nowhere**. There is no lock-on, no aim
  assist and no soft-lock; melee aim is whatever the forward hitbox overlaps.
- **Fix:** either implement lock-on behind the existing `lock_on` action (62) or
  delete the variable and the HUD branch. The HUD currently has a target-display
  path that can never run.

### 64. No i-frames or hit reaction on the player — **M**
- **System:** `scripts/characters/player/player_controller.gd:727-793`
- **Evidence:** `take_damage` does armour math, HP, a damage number, armour
  degradation and a death check. There is no post-hit invulnerability window —
  `_set_invulnerable` (720) exists but is called **only** from the dodge roll.
  `apply_stagger` on the player (788) sets `can_attack = false` and nothing else:
  no animation, no flash, no knockback. Enemies get a real `AIState.STAGGERED`;
  the player gets a boolean.
- **Fix:** add a short post-hit i-frame window (reuse `_set_invulnerable`) and a
  visible hit reaction. Without i-frames, two enemies in melee range can chain
  the player to death with no counterplay — and the open world has only just
  started spawning enemies again, so nobody has felt this yet.

### 65. Footsteps: one hardcoded file, gated to grass — **S**
- **System:** `scripts/characters/player/player_controller.gd:853-880`, `:912-929`
  (`_is_grass_terrain`), `audio_manager.gd:99-100`
- **Evidence:** `_update_footsteps` only fires in grass/forest/plains/hills/swamp
  and always plays a single hardcoded `footstep_1.wav`. `footstep_stone`,
  `footstep_wood`, `footstep_water`, `footstep_metal`, `footstep_dirt` are
  defined in `EVENTS` and never called. So there are **no footsteps at all**
  indoors, in dungeons, in towns, or on any stone floor — which is most of Act I.
  Footsteps also feed the stealth noise system (`_emit_footstep_noise`, 883), so
  stealth detection is surface-blind too.
- **Fix:** give `_update_footsteps` a surface lookup with a generic fallback,
  and never let the absence of a surface match mean silence.

### 66. Death dead-ends when there is no save — **S**
- **System:** `scripts/ui/hud.gd:1189-1379`,
  `scripts/core/game_manager.gd:269-271`
- **Evidence:** HP 0 → `_on_death()` → `player_died` → a full-screen panel with
  four buttons: Load Last Autosave, Load Save…, New Game (full character wipe),
  Main Menu. There is **no in-place respawn or checkpoint of any kind**. If no
  save exists, both Load buttons bounce back to the death screen (1367–1379) and
  the only exits are wiping the character or quitting to the menu.
- **Fix:** at minimum, make the no-save case honest — hide or disable the Load
  buttons and say why. Autosave runs every 30s (`save_manager.gd:33`) so this is
  rare, but a player who dies in the first 30 seconds gets a dead end.
  *(Whether death should offer a real respawn is a design call; log it to
  `wave_b_dispositions.md` rather than deciding it here.)*

### 67. Feedback signals emitted into the void — **M**
- **System:** `game_manager.gd:4-5`, `inventory_manager.gd:6`,
  `world_item.gd:5`, `follower_manager.gd:6-10`, `guild_rank_manager.gd:7`,
  `lootable_corpse.gd:7`
- **Evidence:** of 300 declared signals, 183 are emitted with nothing connected.
  Two are never emitted at all: `GuildRankManager.rank_check_failed` and
  `LootableCorpse.looted`. The ones that matter for feel are exactly the audio
  and UI hook points CLAUDE.md's convention names: `item_used`, `picked_up`,
  `game_paused`/`game_resumed`, the five `follower_*` signals. Also a name
  collision worth killing: `GameManager.weather_changed(new_weather)` is a dead
  duplicate of the live `WeatherManager.weather_changed(old, new)` — different
  shape, same name, one autoload apart.
- **Fix:** connect the handful that carry feedback (pickup sound, use sound,
  pause ducking, follower notifications) as part of 59/61; delete the two
  never-emitted signals and the duplicate `weather_changed`. Do **not** try to
  connect all 183 — most are managers built signal-first and consumed by direct
  calls, which is a style question, not a bug.

---

# Batch 5 — Delete what is not there, and fix what says it is (68–75)

**Theme:** dead systems, dead lookups and dead documentation. This batch is last
because every deletion here is safer once the earlier batches have proved what is
actually load-bearing. It ends on CLAUDE.md, which should be rewritten only after
the code it describes has stopped moving.

> **BATCH 5 DONE 8/2. The 50-task run is CLOSED.** All eight tasks landed,
> nine commits (68 carries a deferred Batch 2 deletion in its own commit, and
> the CLAUDE.md pass is the ninth). Validator held at **0 errors / 179
> warnings**; all twelve check scenes green, including a new
> `check_groups.tscn`; real headless boot to the title screen clean; a
> hand-built pre-batch save loads.
>
> **Three of the eight were misdiagnosed, and the misdiagnosis was always in
> the project's favour** - the thing the audit called broken was fine, and the
> thing beside it was dead.
>
> **68, the headline, was right and CLAUDE.md was wrong about *why*.** Fog of
> war is a live feature - it is `PlayerGPS.discovered_cells`, re-synced onto
> `WorldGrid.CellInfo.discovered` when `scripts/ui/world_map.gd` opens.
> `MapFogOfWar` had nothing to do with it: zero references repo-wide, no
> script, scene, `.tres` or data file naming the class or its path, both
> SaveManager hooks `pass` under a comment saying so, and `SaveData` still
> allocating a `FogOfWarSaveData` to write `"fog_of_war": {}` into every save.
> The class is deleted and the docs corrected to describe the map that exists.
> **SAVE_VERSION 8 -> 9**, with a migration that erases the dead key rather
> than carrying it, verified against a hand-written version-8 save: it loads,
> does not crash, and re-saves without it.
>
> **The deferred Batch 2 deletion went with it.** `SaveManager.world_flags`
> had five writers and zero readers. Each writer was resolved rather than
> dropped blind: two were exact duplicates of a `DialogueManager.set_flag`
> call on the same line, one (`_spawn_consequence_enemy`, whose comment says
> "for level scripts to check") moved to WorldState where a level script can
> actually see it, and one moved to FlagManager. `world.flags` is dropped by
> the same 8 -> 9 migration. Five always-true guards went with the lines they
> wrapped; the ratchet ceiling drops 304 -> 299.
>
> **69's "one string" was the wrong string.** The audit said to repoint the
> minimap at `"doors"` and check the other direction; checking it changed the
> fix. `"doors"` is also joined by `LockableDoor`, a house door, so the
> repoint would have put portal icons on every lockable door in every town.
> `ZoneDoor` joins `"zone_doors"` instead.
>
> **70 was wrong twice.** "The quest waypoint points at the world origin"
> cannot happen - every caller already guards `if pos != Vector3.ZERO`. And
> the subsystem those helpers belong to, `QuestNavigation` /
> `get_tracked_quest_navigation` / `get_active_quests_with_positions`, has
> **zero callers anywhere**; the live compass is
> `hud_navigation._update_compass_quest_marker`, which resolves positions
> itself and hides the marker when it finds nothing. 275 lines deleted.
>
> **71 is the batch's real deliverable.** Six dead group lookups, each fixed
> by what the read was for rather than by reflex: `gladiators`, `game_menu`
> and `guilds` got their joiners (the last via a QuestGiver setter, because
> level scripts assign `faction_id` *after* spawn, so a line in `_ready()`
> would have seen the default); `containers` was deleted as dead twice over
> (no joiner, and no class implements the `has_item()` its branch requires);
> `shrines` and `fast_travel` were dead aliases of rows already in the same
> table; `portals` got two joiners.
>
> **And the day/night light, which is the largest silent behaviour change in
> the batch.** `_get_light_level()` was a three-step fallback chain with all
> three steps dead - `has_method("get_time_of_day_light")` on a method that
> did not exist, then the `"sun"` group nothing joined, then a hardcoded 0.5.
> **Enemy detection has never reflected the hour, at any hour: stealth at
> midnight played exactly like noon.** DayNightCycle's light joins `"sun"`,
> GameManager gained a real `get_time_of_day_light()` whose curve is
> DayNightCycle's own energies normalised against noon, and the chain is
> reordered so the sun group means "outdoors" rather than being a value
> source - a cave at noon stays a cave.
>
> **`tools/check_groups.tscn` closes the class.** 566 files, 61 group names
> read, 153 joined; any read with no joiner fails. It reproduced all six of
> this batch's dead lookups before they were fixed, and a
> `KNOWN_EXTERNAL_JOINS` entry that stops being needed fails as a stale
> excuse. The rule is written down once in CLAUDE.md.
>
> **72, four orphans deleted.** The panels directory made the case: GameMenu
> builds five tabs, two of which instantiate the class in `scripts/ui/panels/`
> while Codex, Stats and Magic are hand-built inline - so three of the five
> panel classes were the superseded half of a pair. `npc_dialogue_ui` is the
> same shape against `dialogue_box.tscn`. Per the audit's own rule, the inline
> versions stay.
>
> **73 is the one thing in this batch a player will feel.** Nine consumable
> effects wrote a tooltip and applied nothing - `blessing_of_gaela` is 250
> gold for "+3 Grit for 600s" and did nothing at all. CharacterData gained a
> timed-buff container on the same clock as `conditions`; each buff lands in
> the code that already does that job (stats through `get_effective_stat`,
> armour through `get_total_armor_value`, damage in `apply_melee_damage`, the
> resistances in the player's `take_damage`, invisibility as a stealth
> multiplier). It serialises, the HUD shows it, and a probe drinks all six
> shipped buff items through the real `use_item` path: Grit 4 -> 7, six of
> six.
>
> **74 deleted five ItemData fields and 850 lines of data.** The literacy gate
> is not "commented out pending a decision" - the block is labelled *"REMOVED:
> Arcana Lore skill check - scrolls can now be read without skill
> requirements"*, a decision already taken, so the fields go with it.
> `shop_bundle_size` is superseded, not unbuilt: ShopUI already gives every row
> a quantity spinner. A `.tres` carrying a property its script no longer
> declares errors on load, so all 185 ItemData resources were stripped too;
> verified by loading all 208 item resources headless.
>
> **75 was worse than the audit found.** It is not only that options were
> inline and mid-game-only - the only settings that survived a restart were
> the three volumes, and they survived by riding in the **save file**, via
> `SaveData.audio_settings`. A player who set the volume on the title screen
> lost it; a player with no save had no settings at all. `GameSettings` now
> keeps preferences in `user://settings.cfg`, applied at boot in two phases
> (GameManager is the first autoload and cannot see AudioManager or
> DiceManager in its own `_ready()`). `OptionsMenu` is a BasePopupUI popup
> opened from both the title's main menu and the pause menu, with display,
> interface, audio, gameplay and a rebinding panel over the thirteen input
> actions the game actually reads.
>
> **CLAUDE.md, last as planned.** Every section the audit listed as stale, in
> its own commit: the "All Complete" systems table (now saying what a green
> row means, which is "boots and passes its gate", never "is good"), the
> Investigation TODO that had been done for some time, the agent table that
> named five agents no loadable definition declares, and the Beads section
> that mandated `bd` while seventy commits of audit work were tracked in
> `production/`. Three new sections for what this batch built.
>
> **`.claude/hooks.json` was NOT touched, as instructed.** It is inert prose
> naming six agents that do not exist, in a format Claude Code does not
> execute - and it is Caleb's configuration. Same for `settings.json`'s
> `auto_validate_on_edit` and `proactive_agents` keys, which are not schema
> Claude Code reads. All three are now *described* accurately in CLAUDE.md so
> nobody trusts them again, and none is changed.
>
> **One thing landed in this repo that was not this batch's work.** Commit
> `a4e4bbd` "Adopt Godot 4.7 as the project engine version" was authored by a
> concurrent session at 00:34, between task 72 and task 73, and flips
> `config/features` from 4.5 to 4.7. It was left alone rather than reverted.
> Every gate in this batch, before and after it, was run with the **4.5**
> binary at `_tools\godot45` per the standing rule, and 4.5 still opens the
> project - but this run has verified nothing about 4.7, and the standing rule
> and that commit now disagree. **It needs Caleb's decision.**
>
> **Eye gate outstanding, as for every batch.** Nothing here was played. In
> order of how differently the game behaves:
> 1. **Stealth finally has a day and a night.** Every impression of detection,
>    sneaking or enemy awareness formed before today was formed at a constant
>    half light, at every hour, outdoors and in.
> 2. **Buff potions work.** Six shipped items, including four blessings at
>    250 gold, went from inert to real. Three numbers in that system were
>    invented and are labelled in the source: the 50% resistance reduction, the
>    0.15 invisibility multiplier, and clearing buffs on sleep.
> 3. **The options screen exists and is reachable from the title**, so the
>    window size, the volume and the keys are the player's for the first time.
>    Nobody has clicked a single control in it.
> 4. Minimap portal and guild icons appear where they never did; arena hazards
>    can hit gladiators; companion hotkeys stop firing into an open menu.
> 5. **The save format is version 9.** Saves from the milestone build load and
>    migrate, proved headless - but proved by a probe, not by a player loading
>    his own game.

### 68. `MapFogOfWar` is an orphan, and the save writes an empty dict for it — **S**
- **System:** `scripts/map/map_fog_of_war.gd`, `save_manager.gd:1043-1053`,
  `scripts/data/save_data.gd:55,118,153`
- **Evidence:** `MapFogOfWar` has **zero references repo-wide** — no script,
  scene, or data file names the class or the file path.
  `scripts/ui/painted_world_map.gd` does not exist. Both save hooks are `pass`
  with the comment "PaintedWorldMap removed - fog of war handled by
  PlayerGPS.discovered_cells", yet `SaveData` still allocates a
  `FogOfWarSaveData` and writes `"fog_of_war": {}` into every save file.
- **Fix:** delete `map_fog_of_war.gd`, `FogOfWarSaveData`, the two stub methods
  and the save key (migrate by ignoring it). Confirm first that the live map
  (`scripts/ui/world_map.gd`) genuinely reads `PlayerGPS.discovered_cells`.

### 69. Minimap door icons never appear — group name mismatch — **S**
- **System:** `scripts/ui/minimap.gd:329,723` vs. `scripts/world/interactables/zone_door.gd:40`
- **Evidence:** the minimap reads `get_nodes_in_group("zone_doors")`. The only
  place doors register calls `add_to_group("doors")`. `"zone_doors"` is joined by
  nothing in the repo, so the lookup always returns an empty array. Deterministic,
  silent, nothing thrown.
- **Fix:** one string. Then check the other direction — `"doors"` may have other
  readers that would now see the same nodes.

### 70. Quest compass markers silently resolve to the origin — **M**
- **System:** `scripts/systems/quests/quest_manager.gd:2495-2530`
- **Evidence:** `_find_enemy_spawn_position`, `_find_item_position` and
  `_find_location_position` fall back to `get_nodes_in_group()` on
  `"enemy_spawns"`, `"items"`, `"location_markers"` and `"exits"`. **None of
  those four groups is joined by anything.** Every fallback returns
  `Vector3.ZERO`, so when no live enemy or item node exists, the quest waypoint
  points at the world origin instead of failing visibly.
- **Fix:** either join the groups at the spawn sites (level scripts already build
  these markers) or return a sentinel and have the compass hide the marker.
  A waypoint at (0,0,0) is worse than no waypoint.

### 71. Five more group lookups nothing joins, and day/night light is always 0.5 — **S**
- **System:** `scripts/ui/hud/hud_navigation.gd:1339` (`containers`),
  `scripts/world/interactables/damage_zone.gd:224` + `triggered_trap.gd:201` (`gladiators`),
  `scripts/ui/companion_command_ui.gd:311` (`game_menu`),
  `scripts/systems/dialogue/conversation_system.gd:787` + `minimap.gd:760` (`guilds`),
  `scripts/characters/player/player_controller.gd:1053-1056` (`sun`)
- **Evidence:** all six group names are read and joined nowhere. The `"guilds"`
  one means guild NPCs never get their distinct minimap icon or dialogue branch.
  The `"sun"` one is the second step of a three-step fallback chain:
  `has_method("get_time_of_day_light")` (the method does not exist) → group
  `"sun"` (nothing joins it) → hardcoded `0.5`. So **enemy detection has never
  reflected day or night** — it is always half light, silently, at every hour.
- **Fix:** join the groups or delete the lookups. For the light level, implement
  `GameManager.get_time_of_day_light()` or read the day/night cycle directly;
  stealth at midnight currently plays identically to noon.

### 72. Four orphan UI classes — **S**
- **System:** `scripts/ui/panels/codex_panel.gd`, `panels/stats_panel.gd`,
  `panels/magic_panel.gd`, `scripts/ui/npc_dialogue_ui.gd` +
  `scenes/ui/npc_dialogue_ui.tscn`
- **Evidence:** none is instantiated anywhere outside itself and
  `tools/check_popups.gd`. `game_menu.gd` hand-builds the Codex, Stats and Magic
  tabs inline (Magic at 1654). NPC dialogue goes through `dialogue_box.tscn`
  (`dialogue_manager.gd:50`); `npc_dialogue_ui` is its superseded predecessor and
  is still listed in the popup-migration checker.
- **Fix:** delete all four, or extract the inline `game_menu` tabs into them —
  but pick one. Per the fossil rule, deleting the superseded version is the
  default. Remove `npc_dialogue_ui.gd` from `check_popups.gd` when it goes.

### 73. Nine consumable effect types are never applied — **M**
- **System:** `scripts/data/item_data.gd:72-80` (enum), `:151-167` (tooltip
  text), `scripts/systems/economy/inventory_manager.gd:798-800`
- **Evidence:** `BUFF_STRENGTH`, `BUFF_AGILITY`, `BUFF_WILL`, `BUFF_ARMOR`,
  `BUFF_DAMAGE`, `RESIST_FIRE`, `RESIST_FROST`, `RESIST_POISON` and
  `INVISIBILITY` all generate a tooltip describing what they do, and
  `_apply_item_effect()` falls through to `_: return false` under the comment
  *"Buff effects would need a buff system on the player."* Real items ship with
  them: `blessing_of_gaela.tres` (`consumable_effect = 7`,
  `effect_value = [0,0,3]`, `effect_duration = 600.0`, `base_value = 250`), plus
  `blessing_of_chronos`, `blessing_of_foresight`, `blessing_of_bounty`. The
  player pays 250 gold for a ten-minute buff that does nothing and reads a
  tooltip that says it does.
- **Fix:** build a minimal timed-buff container on `CharacterData` (it already
  has a `conditions` list and a DOT tick loop to model it on), apply the nine
  effects through it, show them in the HUD, and make sure they serialise — task
  45's guard should cover the new field.

### 74. Dead `ItemData` fields, and the literacy gate is commented out — **S**
- **System:** `scripts/data/item_data.gd`,
  `scripts/systems/economy/inventory_manager.gd:~669`
- **Evidence:** `requires_literacy` / `literacy_dc` are set to real values in
  data (`scroll_chain_lightning.tres:19` → `literacy_dc = 18`) and the check that
  reads them **is commented out** in `use_item`. `shop_bundle_size` is set on
  `arrows.tres`, `bolts.tres`, `lead_balls.tres` and read by no shop code.
  `use_sound` and `icon_path` have no reader at all.
- **Fix:** re-enable the literacy gate or strip the fields from the data; wire
  `shop_bundle_size` into the shop or drop it; delete `use_sound` (task 59 owns
  item audio) and `icon_path` (the inventory renders text only). A field a
  content author can set and nothing reads is the same trap as a dead JSON key.

### 75. Options menu covers three settings, and is unreachable from the title — **M**
- **System:** `scripts/ui/pause_menu.gd:481-672` (`_create_options_panel`),
  `scripts/ui/main_menu.gd`, `scripts/ui/title_screen.gd`
- **Evidence:** there is no options scene — options are built inline in the pause
  menu and reachable **only** mid-game. They cover Dice Roll toggle, UI Scale,
  and Master/Music/SFX volume. **No resolution, no fullscreen toggle, no key
  rebinding exists anywhere in the project**, and neither the title screen nor
  the main menu has an options entry. The window opens at a 1280×960 override on
  a 640×480 viewport with no way for a player to change it.
- **Fix:** extract options into its own scene on `BasePopupUI`, reachable from
  the title screen and the pause menu; add fullscreen/resolution/vsync backed by
  `DisplayServer`, and a rebinding panel over the 28 declared input actions
  (which task 62 will have pruned to the ones that do something). Persist through
  the settings path `AudioManager.get_settings()` already uses.

---

## Ordering rationale

- **Batch 1 before everything.** Nine of these are runtime throws on paths a
  player walks; the navmesh one means fourteen levels have no AI movement at all.
  Any judgement about balance, feel or AI formed before 33 lands was formed in
  levels where nothing could path — the same trap as the empty open world.
- **Batch 2 before Batch 3.** Batch 3 creates new persistent state (titles,
  objective completion methods, world facts); it should land on a save file that
  has been proved to carry what it is given.
- **Batch 3 before Batch 4.** Task 51's validator extension is what stops the
  next dead key, and 46's objective work is what makes the guild ladders
  playable — both are prerequisites for a playthrough long enough to judge feel.
- **Batch 4 before Batch 5.** Batch 5 is largely deletion. Deleting is safest
  once the systems around it have been exercised.
- **Batch 5 last, and CLAUDE.md last within it.** Rewriting the reference while
  the code is still moving is how it got stale in the first place.

## Standing rules, unchanged

- **ART RULE.** Never hand-repair a broken model or sprite. Route around it, keep
  the code path correct, log it in `docs/audits/art_replacement_manifest.md`.
  Tasks 59 and 60 repoint code at files that already exist — that is wiring. Any
  sound with no asset at all goes to the manifest.
- Godot 4.7 binary only (`~/_tools/godot47/`), per Caleb's 8/1 ruling — `project.godot`
  is stamped `4.7` by `a4e4bbd` and `tools/validate.ps1`, `tools/run_all_checks.ps1`
  and the pre-commit hook all default to it. Validator green before any commit
  touching content; **errors stay at zero and warnings never go up.**
- Strict typing held. One commit per task or per coherent group, pushed.
- **Caleb's eye gate ends every batch. Headless checks prove a system loads and
  round-trips; they cannot tell you whether it is any good.** Every finding in
  this document was made by reading code and booting scenes. Not one of them was
  found by playing.

## A note on CLAUDE.md

Task 75 is the options menu, not the doc. The doc itself needs a pass, and these
are the sections this audit proved stale — recorded here so the rewrite has a
list rather than an instinct:

- **Fog of war / PaintedWorldMap** — both documented with full API tables; the
  map class does not exist and the fog class has zero references (task 68).
- **Systems Status: "All Complete"** — the table marks Combat, Save/Load and
  World Map ✅. Melee never reaches the combat system (57), four autoloads are
  not saved (41–43), and the map's fog is deleted (68).
- **"AUDIO EVENT NAMING CONVENTION"** — the named events are spoken by call
  sites and understood by nothing (59, 61).
- **Skill System: "Investigation TODO"** — stale. `get_hidden_detection_bonus()`
  is live-called from two places (56).
- **MapFogOfWar API table, PaintedWorldMap integration example** — both describe
  deleted code.
- **The PROACTIVE AGENT ENGAGEMENT table** is half-real. Of the agents it names
  under a MANDATORY trigger table, `gdscript-linter`, `asset-validator`,
  `balance-reviewer` and `dialogue-quest-master` do load. `scene-auditor`,
  `quest-validator` and `dungeon-validator` are declared in `.claude/settings.json`
  under an `"agents"` key but do not surface in the agent roster;
  `town-builder` and `enemy-creator` are declared in no loadable location at all
  (`dev/agents/enemy-creator.md` is documentation, not a definition). The
  `settings.json` keys `auto_validate_on_edit` and `proactive_agents: true` are
  not schema Claude Code reads. `.claude/hooks.json` describes automatic
  post-edit agent runs in a format nothing executes — it is inert prose. The one
  real hook configured (`settings.json` → `hooks` → `SessionStart`/`PreCompact`
  → `bd prime`) has nothing to do with validation (task 55).
- **NPC SPRITE SPECIFICATIONS** — already correctly marked historical on 8/1;
  leave the marker, it is working.
- **The Beads section** mandates `bd` for all task tracking. `.beads/` and the
  `bd` binary both exist, but this run's work was tracked in
  `production/` documents. Reconcile or retire the section.

---

## The 50-task run is CLOSED (8/2)

All fifty tasks, 26 through 75, across five batches and roughly fifty commits
in about thirty hours. Honestly:

**What shipped.** Nine nonexistent-method call sites that reached a milestone
build now resolve, and `check_autoload_api.tscn` resolves all 3,961 autoload
member references so a tenth cannot ship. Every level in the game baked a
navmesh with **zero** polygons before batch 1; every level that assigns one now
bakes a real one, so enemies can path for the first time. The save file carries
what the player earned - `total_ip_earned`, the crime return point, quest
timers, three whole autoloads, follower state, flags and their context
variables - and `check_serialization.tscn` round-trips 436 assertions through
the real SaveManager pair on disk, because every save bug found was a class
with a perfectly correct `to_dict` that SaveManager never called. Both guild
ladders are completable, 67 dialogue conditions that silently passed now gate,
two quests came back from the dead with the right givers, and the validator is
a real pre-commit hook rather than honour-system. Melee routes through the
combat system, so swords have crits, damage numbers and - for the first time -
XP. The game makes noise: 84 of 117 audio events resolve and the other 33 are
declared silent with manifest rows. And this batch deleted the fog-of-war
system, the quest-navigation subsystem, four orphan UI classes, a fourth flag
store and five ItemData fields, none of which anything referenced.

**What was deferred, and where.** Design and story calls went to
`docs/audits/wave_b_dispositions.md` - the melee damage retune batch 4's
routing implies (3a), whether AmbientSoundscape is wired or deleted (3d), the
two invented combat numbers (3e, 3f), whether death should offer a respawn, the
`variable` objective type, and the consequences of a failed Deception. Content
an agent must not invent stayed in `docs/audits/invention_manifest.md` - 27
quests and 70 branches. Every asset routed around is a row in
`docs/audits/art_replacement_manifest.md`. Inside the code, the things left
undone are named where they live: 299 always-true `if Autoload:` guards behind
a ratchet that can only fall, five levels that assign no navmesh at all, a
quest chest from `spawn_on_accept` that is not respawned after a load, and
`_quest_spawns` declared transient with its reason. `.claude/hooks.json` and
two `settings.json` keys are inert and were left inert on purpose - they are
Caleb's configuration, now accurately described rather than quietly rewritten.

**What this run cannot tell you.** Every one of the fifty tasks was closed
against a headless check, a validator or an instrumented boot. **Not one was
closed against a person playing the game.** Five batches of findings say the
project believed things about itself that were not true; the same caution
applies to this document. Headless proof that a system loads, round-trips and
fires its signals is not evidence that combat feels good, that the stealth that
now has a night is fun at night, that 250-gold blessings are worth 250 gold, or
that an open world with pathing enemies plays the way the last two months of
work assumed. The single most important outstanding item in this project is
still Caleb sitting down with a build and forming his own opinion - and it now
matters more than it did on 8/1, because far more has changed underneath him.

---

## Godot 4.7 migration, verified (8/2)

Caleb ruled 4.7 on 8/1 and `a4e4bbd` stamped `project.godot`. Everything above
this section was proved on the **4.5** binary. This is the re-verification on
**4.7** (`4.7.stable.official.5b4e0cb0f`, installed at `~/_tools/godot47/`).

**The gauntlet is green on 4.7.** `validate_content` reports `Errors: 0
Warnings: 179` — identical to its 4.5 verdict — and all twelve `check_*.tscn`
probes PASS. `check_navmesh` was the canary for the NavigationServer API and it
passes; nothing in the 4.5→4.7 nav changes reached this project's baking code.

**The 51-scene boot sweep moved 124 → 130 lines, and every line is accounted
for.** Both sweeps were run with the same script on the same tree, so the delta
is real rather than a change of method:

| Class | 4.5 | 4.7 | Reading |
|---|---|---|---|
| Nav source geometry parsed at runtime | 44 | 44 | unchanged |
| `ext_resource, invalid UID` | 24 | 24 → **0** | pre-existing on both; fixed, see below |
| `ObjectDB instances were leaked at exit` | 9 | 13 | shutdown race, see below |
| `N resources still in use at exit` | 9 | 13 | same race |
| **`Navigation region synchronization error`** | **3** | **0** | **4.7 fixes this** |
| `Condition "p.d == 0"` | 3 | 4 | same three scenes, one doubled |
| everything else (ModularRoom doors, Codex, WildernessRoom…) | 32 | 32 | unchanged, all project-level |

**No 4.7-only regression exists.** The only class that got quieter is
navigation: Crossroads Ruins, Dalhurst and Mosshall Tombs each threw a
`Navigation region synchronization error` about edges occupying the same
rasterization space on 4.5, and none of them throws it on 4.7.

**The two classes that got louder are both noise, and were checked rather than
assumed.** The exit-time leak pair is nondeterministic — three consecutive
`--headless --quit` boots on 4.7 produced the leak twice, not at all, and not at
all, and the *set of scenes* that report it differs between the 4.5 and 4.7
sweeps almost entirely. It is a shutdown-ordering race in the engine's own
teardown, after `--quit-after` has already fired; it is not a per-scene defect
and no gameplay code runs at that point. `Condition "p.d == 0"` is a degenerate
plane inside Godot's geometry code, raised by the same three scenes
(`dusty_hollow`, `tenger_camp`, `willow_dale`) on both versions; 4.7 just
reaches it twice in Dusty Hollow. Both are **documented, not fixed** — a fix
would be a behaviour change to level geometry, which this migration is not
licensed to make.

**One class was fixed:** nine `ext_resource` UIDs across seven level scenes
named UIDs no `.import` file on disk carries. Godot fell back to the text path
and warned once per load, on 4.5 and 4.7 alike — 24 of the sweep's lines. This
is an import-class defect, not a version one; it was fixed here because the
migration surfaced it. All seven scenes now boot with zero invalid-UID lines.

**The milestone build.** `Broken_Provinces_The_Empty_Throne_milestone47_2026-08-02.exe`
(109 MB) + `.pck` (316 MB) in `C:\Users\caleb\_builds\CatacombsOfGore\`, exported
release with the 4.7 templates, zero errors in the export log. Launched: it
opens a responding **Broken Provinces** window and holds it. That is the whole
claim — **it starts.** It has still never been played, and the closing note
above stands unchanged: headless green on a newer engine is not evidence that
any of this is any good.

**Tooling repointed.** `tools/validate.ps1`, `tools/run_all_checks.ps1` and
`tools/hooks/pre-commit-validate.sh` defaulted to `~/_tools/godot45/`, which
would have silently gated every future commit on the abandoned binary. All three
now default to 4.7. `~/_tools/godot45/` is left in place; pass `-Godot` (or
`BP_GODOT`) to reach it.

---

## Batch record — factions, devotion and the lockout web (8/2)

Caleb's two questions: "the faction system was a little wonky", and "certain
things can lock you out of other things — if you go too far into devotion of
one temple it'll soft lock you out of the other ones." Findings in
`docs/audits/faction_exclusivity_audit.md`, rulings in
`wave_b_dispositions.md` FX-1..FX-8. Four commits.

**The wonk had one cause and it was not the faction system.** `complete_quest`
read every `items` reward entry as `item["id"]`. That throws on a String, a
throw aborts the function, and **114 of 236 quests write `"items": ["id"]`** —
so for nearly half the game the reward pass stopped at the item and never
reached the faction reputation on the next line, nor the follower, soulstone,
title, area unlock, lore or `next_quest` chaining after it. The quest still
wrote itself COMPLETED, because the state is set before the rewards are paid.
Completing `gaela_03_protect_harvest` headless left Millbrook at 0; it pays 25.
The same crash sat in three reward-preview sites, truncating the line a player
reads before accepting.

**`FactionManager.reset()` did not reset.** It cleared `player_reputations` and
then `_initialize_player_reputations()` restored every value from
`GameManager.player_data`, which `_sync_to_player_data()` had been mirroring all
along. Both callers are new-game paths.

**The devotion lockout was real and had never fired.** His notes are in the
game's own dialogue, not in any design doc: each priest states the rule in his
own voice and each has a written refusal for a rival's devotee. But quests are
offered through `is_quest_available()`, and the temple chains used only
`prerequisites` — so a devotee of Gaela could take the entire Chronos chain
through the QUESTS topic and end up devoted to two gods, having never reached
the refusal, which sits on a different door. Declining devotion also still
unlocked the devotee-only content. The gate had in fact been authored for
Chronos 6-10 under the key `flags_required`, which nothing reads; the field is
`flag_prerequisites`. 22 bond quests are now gated both ways. Quests 1-4 stay
open, because the same speeches promise open service to anyone — going *too
far* is what closes the doors, which is exactly what he said. No threshold was
invented: the metric is the devotee flag, binary, which is the boundary the
content itself names.

**19 dead cascade ids.** Seven `cultists` references repointed to
`shadowed_hand_cult`; four ids with no determinate target recorded in the check
instead, so a new one fails and a stale excuse fails too.

`tools/check_faction_loop.tscn` is the fourteenth gate — 585 checks proving the
quest → reputation → cascade → gate → rank → flag loop end to end. Validator
held at 0 errors / 164 warnings throughout.

**Nothing here was played.** The lockout is proven to fire headlessly; whether
being refused by two priests reads as meaningful or as a wall is his call.
