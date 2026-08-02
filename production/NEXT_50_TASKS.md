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

### 26. `InventoryManager.get_gold()` does not exist — 3 call sites — **S**
- **System:** `scripts/autoload/boat_travel_manager.gd:659`,
  `scripts/autoload/fast_travel_manager.gd:408`,
  `scripts/autoload/game_systems.gd:551`
- **Evidence:** `grep -n 'func get_gold' scripts/autoload/inventory_manager.gd`
  → no match. The public field is `var gold`. All three sites are gold-cost
  gates: sea fare, caravan fare, guard bribe.
- **Fix:** replace with `InventoryManager.gold`. Do **not** add a `get_gold()`
  wrapper — a second accessor for the same field is how this happened. Then
  grep the repo for any other `InventoryManager.<name>()` that is a field.
- **Note:** the 8/1 fix put gold on `InventoryManager` because `CharacterData`
  had no `gold` field. These three sites were missed in that sweep.

### 27. `DiceManager.skill_check()` does not exist — 4 call sites — **S**
- **System:** `scripts/autoload/boat_travel_manager.gd:545,578`,
  `scripts/world/jail_guard.gd:597,650`
- **Evidence:** `grep -n 'func skill_check' scripts/autoload/dice_manager.gd` →
  no match. Real API: `make_check`, `passive_check`, `speech_check`,
  `lockpick_check`, `bravery_check`.
- **Fix:** map each site to the right real method by what it is checking
  (flee-encounter and resolve-encounter are ability checks; the two jail sites
  are intimidate/persuade → `speech_check`). Match the return-dictionary shape
  the callers already destructure.

### 28. `ConversationSystem.get_last_scripted_choice_index()` does not exist — **S**
- **System:** `scripts/world/jail_cell_door.gd:100`,
  `scripts/world/jail_exit_door.gd:91`, `scripts/world/prison.gd:571`
- **Evidence:** only `select_scripted_choice(idx)` exists — a setter with no
  getter. All three sites are the jail lockpick dialogue-choice flow, which with
  27 means the jail is doubly unescapable.
- **Fix:** add the getter to `ConversationSystem` (it already holds the index
  internally), or have the three doors read the index they passed in.

### 29. `SceneManager.goto_scene()` and `transition_to_adjacent_room()` do not exist — **S**
- **System:** `scripts/puzzles/puzzle_portal.gd:220`,
  `scripts/generation/town_generator.gd:794`
- **Evidence:** real API is `change_scene(scene_path, spawn_id, fade)`. Both
  sites sit under `if SceneManager:`, which is always true. Breaks the puzzle
  portal teleport and *exiting a procedurally generated town*.
- **Fix:** `goto_scene` → `change_scene`. `transition_to_adjacent_room` has no
  equivalent — route the town exit through `SceneManager.RETURN_TO_WILDERNESS`,
  which is the pattern `ZoneDoor` already uses.

### 30. `WorldGrid.get_current_location()` does not exist — **S**
- **System:** `scripts/npcs/escort_npc.gd:281`, under `if WorldGrid:`
- **Evidence:** `WorldGrid` exposes `get_cell(coords)`; the player's live
  position is `PlayerGPS.current_cell` / `current_location_id`. Escort NPC
  location logic throws.
- **Fix:** `WorldGrid.get_cell(PlayerGPS.current_cell)`, or read
  `PlayerGPS.current_location_id` directly — PlayerGPS is the documented single
  source of truth for where the player is.

### 31. `DialogueManager.set_dialogue_flag()` does not exist — **S**
- **System:** `scripts/autoload/quest_manager.gd:1756`
- **Evidence:** no such method on `DialogueManager`; the real one is `set_flag`,
  which itself delegates to `FlagManager.set_flag`. The site is the
  faction-quest-failed-via-temptation flag write, so a betrayal outcome silently
  throws instead of recording itself.
- **Fix:** call `FlagManager.set_flag()` directly — that is where the value lands
  anyway, and it removes one hop through a shim.

### 32. `AudioManager.play_sound_3d()` and `play_ui_sound()` do not exist — 6 sites — **S**
- **System:** `scripts/travel/boat_voyage.gd:464,486,1832,1873`;
  `scripts/autoload/dialogue_manager.gd:672`;
  `scripts/autoload/conversation_system.gd:2226`
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

### 36. `FlagManager` is never cleared on New Game — **S**
- **System:** `scripts/autoload/save_manager.gd:1889` `reset_world_state()`
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
- **System:** `scripts/autoload/dialogue_manager.gd:1169-1187`,
  `scripts/autoload/flag_manager.gd:442-456`, `scripts/autoload/save_manager.gd`
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
- **System:** `scripts/autoload/save_manager.gd:486-511` and `816-836`
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
- **System:** `scripts/npcs/follower_npc.gd:702` (write), `:727-770` (read)
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

### 46. Ten objective types have no handler — guild capstones uncompletable — **L**
- **System:** `scripts/autoload/quest_manager.gd`; `data/quests/guild/thieves/`,
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
- **System:** `scripts/dialogue/dialogue_loader.gd:164-193`,
  `scripts/dialogue/dialogue_data.gd:65`,
  `scripts/autoload/dialogue_manager.gd:678`
- **Evidence:** `ActionType.SPAWN_ERRAND` is in the enum and **is dispatched** at
  runtime, but `_parse_action_type()` has no `"spawn_errand"` case. Any such
  string falls to the `_:` default, which `push_warning`s and coerces to `NONE`.
  All 29 other action types round-trip correctly. Latent — no data file uses it
  yet.
- **Fix:** add the case. Then make the `_:` default a hard error in the loader
  rather than a warning, so the next omission cannot be silent.

### 50. `morality` and `guild_rank` conditions silently evaluate TRUE — **S**
- **System:** `scripts/dialogue/dialogue_loader.gd:138-158` vs.
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
- **System:** `scripts/autoload/save_manager.gd:24`, `:1461-1589`, `:367`
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
- **System:** `scripts/autoload/quest_manager.gd`,
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

### 57. Melee bypasses `CombatManager` entirely — **L**
- **System:** `scripts/autoload/combat_manager.gd:93-218`,
  `scripts/combat/hitbox.gd:_apply_hit`,
  `scripts/player/player_controller.gd:_do_light_attack`
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
- **System:** `scripts/autoload/combat_manager.gd:221`
- **Evidence:** same grep, same result. Bows and muskets take whatever path the
  projectile code takes and get none of the CombatManager treatment.
- **Fix:** find the live ranged damage path and route it through, or delete the
  function. Do it in the same pass as 57 so all three verbs agree.

### 59. `AudioManager`'s event table points at an empty directory — **L**
- **System:** `scripts/autoload/audio_manager.gd:12-168` (`EVENTS`), `620-684`
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
- **System:** `scripts/audio/ambient_soundscape.gd:42-128` (`SOUNDSCAPES`),
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
- **System:** `project.godot` `[input]`, `scripts/player/player_controller.gd`,
  `scripts/player/camera_pivot.gd:137`
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
- **System:** `scripts/player/player_controller.gd:74`, `scripts/ui/hud.gd:611-612`
- **Evidence:** declared `var lock_on_target: Node3D = null`, read by the HUD to
  pick the target nameplate, **assigned nowhere**. There is no lock-on, no aim
  assist and no soft-lock; melee aim is whatever the forward hitbox overlaps.
- **Fix:** either implement lock-on behind the existing `lock_on` action (62) or
  delete the variable and the HUD branch. The HUD currently has a target-display
  path that can never run.

### 64. No i-frames or hit reaction on the player — **M**
- **System:** `scripts/player/player_controller.gd:727-793`
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
- **System:** `scripts/player/player_controller.gd:853-880`, `:912-929`
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
  `scripts/autoload/game_manager.gd:269-271`
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
- **System:** `scripts/ui/minimap.gd:329,723` vs. `scripts/world/zone_door.gd:40`
- **Evidence:** the minimap reads `get_nodes_in_group("zone_doors")`. The only
  place doors register calls `add_to_group("doors")`. `"zone_doors"` is joined by
  nothing in the repo, so the lookup always returns an empty array. Deterministic,
  silent, nothing thrown.
- **Fix:** one string. Then check the other direction — `"doors"` may have other
  readers that would now see the same nodes.

### 70. Quest compass markers silently resolve to the origin — **M**
- **System:** `scripts/autoload/quest_manager.gd:2495-2530`
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
  `scripts/world/damage_zone.gd:224` + `triggered_trap.gd:201` (`gladiators`),
  `scripts/ui/companion_command_ui.gd:311` (`game_menu`),
  `scripts/autoload/conversation_system.gd:787` + `minimap.gd:760` (`guilds`),
  `scripts/player/player_controller.gd:1053-1056` (`sun`)
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
  text), `scripts/autoload/inventory_manager.gd:798-800`
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
  `scripts/autoload/inventory_manager.gd:~669`
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
- Godot 4.5 binary only (`~/_tools/godot45/`). Validator green before any commit
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
