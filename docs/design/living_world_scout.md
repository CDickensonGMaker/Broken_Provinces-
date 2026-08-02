# Living World — RECONgame SimClock/Station Scout Report (2026-08-02)
*Read-only scout of RECONgame's simulation architecture, briefing the CoG implementation. RECONgame paths are SOURCE ONLY — never modify that repo. This report is the implementation agent's primary brief; the memory directive is `bp-living-world-directive`.*

## 1. SimClock (RECON: `scripts/autoload/sim_clock.gd`, 107 lines)
- No `class_name` (avoids autoload collision). API: `Period {DAWN 5-7, DAY 7-17, DUSK 17-19, NIGHT}`, signals `hour_advanced(sim_hour)`, `time_period_changed(period)`, `sim_event(kind, payload)`; `sim_hour: float` 0-24, `sim_day: int`, `real_to_sim_ratio = 60.0`, `paused: bool`; `advance(delta_real_seconds)`, `schedule_event(day, hour, kind, payload)` (day == -1 = daily), `clear_schedules()`, `set_time()` (boot/tests ONLY).
- Frame-driven, not fixed-tick; `hour_advanced` + schedule tick only on integer-hour crossings.
- **Port verbatim: the per-entry dedup key** (`sim_clock.gd:93-99`) — `"%d-%d-%d" % [sim_day, s_hour, i]`. A kind-wide key silently dropped all but the first of three same-hour events.
- **Load-bearing rule** (`game_flow.gd:51-53`): time skips route through `advance()`, NEVER `set_time()` — set_time doesn't emit `time_period_changed`, so lighting/sight stay stale.
- **RECON has NO save integration for the clock — that's a known gap, not a design. CoG must persist.**
- Subscriber pattern in every `_ready()`: `if not SimClock.sig.is_connected(cb): connect` — idempotent because the autoload outlives scenes.

## 2. Stations & the assigner (RECON: `site_planner.gd`)
- Markers: prefix-matched (`work_*`, `home_*`, `prop_sleep`), transform accumulated to root, Blender `.001`/glTF `_001` suffixes stripped, deterministic X-then-Z sort (`:896-914`). **Prefix-not-exact-name is the contract** — a re-export renamed helipads once and everything kept working (`air_traffic.gd:16-20`).
- **An absent marker is SKIPPED with a warning, never relocated to town centre** (`:788-790`).
- Population cap and variety cap are SEPARATE constants (`:856-861`); round-robin **by station type**, not positional stride (`:936-941` — the fix that made the base read alive); critical pairs seeded not rolled (medic+patient, `:962-976`).
- Per-man distinct stations spread by index around a post (`mission_generator.gd:894-898`); Y from surface + arrive checks must be **XZ-only** in CoG (RECON's buried-marker forever-walk bug, `:905-910`).
- Households (`mission_generator.gd:995-1018`): 3-6 residents share one home + one work target — the schedule alone walks a family out together, no group AI.
- Runtime claims: ordinary work markers have **NO claim system** — deterministic name-hash jitter (`civilian.gd:849-852`: `a = absi(hash(name)) % 360`, jitter 1.5 m). Claim/release (`mortar_pit.gd:49-60`) only for exclusive seats; `stand_down` MUST release (`garrison_defender.gd:107-111`) or seats leak.

## 3. Daily cycle (RECON: `civilian_schedules.gd` + `civilian.gd`)
- `action_for(occupation, sim_hour) -> StringName`: match + hour-ladder; unknown occupation → `idle`, **never invents a schedule** (`:253-254`).
- **The schedule lesson** (`:95-103`): a schedule whose "off" hours coincide with when the player is present ships a dead world. RECON's night garrison slept at dusk. CoG's player is in town by DAY — shops/taverns busiest then.
- `_bt_settle` (`civilian.gd:837-861`): THE one settle implementation (there were SEVEN byte-identical freezes before). Walk to target + name-hash jitter, arrive 1.6 m, hold. All of work/rest/cook/sleep/fish/sit/talk are one-liners delegating to it.
- **`place_for_current_hour()` (`civilian.gd:742-766`) — the most portable function in RECON:** position = pure function of (schedule, hour); called on first physics tick after spawn and on wake from FAR. "The world assembling itself on approach instead of having been there all along" — this is what it prevents.
- Animation dispatch: action → pose table with per-man rotated chain head, LAST entry pinned (degrade target). For CoG billboards this collapses to action → `{facing, sit_flag}` + `sprite.set_walking(bool)`.

## 4. Perf (RECON measured)
- 40 garrison men = 0 FPS cost (measured A/B); the game is draw-call-bound, not entity-bound.
- Civilian LOD: FULL <80 m (BT + pathing), NEAR 80-300 m (BT + straight-line), FAR >300 m (**physics hard-returns — no tick at all**). Hysteresis 5 m, recompute every 2 s.
- **Gate the body, never the tick that ungates it** (`civilian.gd:280-283`) — `_physics_process` returns AFTER `_update_lod`.
- Far NPCs do NOT sim abstractly — continuity is `place_for_current_hour()` at wake. **Never build an abstract ticker.** (ADR-025's superseded LOD-tier design is the tombstone: registry entries without nodes caused second-spawn-authority failures.)
- `lazy_group.gd`: dormant data-only node spawning bodies at 120 m, 1 Hz poll; one attach path for "existed at load" and "arrived later" (`camp_director.attach`, used by both world-build and lazy wake).

## 5. CoG implementation sketch (the plan)
**CoG already has:** `GameManager.game_time/time_scale=60/current_day/time_of_day signals` (**this IS the clock — do NOT add a SimClock autoload**), CellStreamer (3×3 ring, 100 u cells, floating origin `world_offset`), CivilianNPC (1941 ln, billboard, WanderBehavior), WorldState, check_serialization gate.

**Gaps:** no (day, hour) scheduling API; floating origin breaks naive position math (**store stations in WORLD coords, convert `pos - CellStreamer.world_offset` at exactly ONE place**); NPCs built by level scripts, not a data table.

**Additive clock port (into GameManager):** `hour_advanced(hour:int)`, `sim_event(kind,payload)`, `_schedules` + per-entry-dedup `_fired_event_keys`, `schedule_event()`, `clear_schedules()`, `advance(hours)` as THE only time-skip door (RestManager routes through it). Serialize `game_time/current_day/_schedules/_fired_event_keys` + fixture row (check_serialization will rightly fail otherwise).

**Schedule data (data-driven, mirrors the 3-tier conversation pattern):**
- `data/schedules/archetypes/<archetype>.json`: blocks `{from, to, action, station}` (actions: sleep/travel/work/eat/socialise/idle).
- `data/npc_schedules.json` per npc_id: `archetype`, `stations {home/work/leisure: {cell, pos(WORLD), facing, sit}}`, optional `overrides` (with `days`).
- Contract: station in a non-passable/out-of-bounds cell → SKIPPED + warning, never relocated; missing station key → authored spawn pos + LOUD warning; unmatched hour → idle, never invented.
- Validator rules (into validate.ps1): every scheduled npc_id spawns somewhere; stations in-bounds/passable; archetypes resolve; **every quest giver/turn-in/target NPC reachable at hours a player can reasonably be present** (hard error — the schedule-era version of the giver/receiver law).

**Three-state model:** LIVE (station in loaded cell, near — full behavior) / PLACED (loaded cell, far — `place_for_current_hour()` only) / ABSTRACT (unloaded cell — NO node, zero cost, position derivable on demand). Two queries: `NPCScheduler.station_of(npc_id, hour)` and `npcs_in_cell(coords, hour)` (per-hour inverse index).

**Spawn seam:** on cell load, spawn the roster and `place_for_current_hour()` each (one code path for existed-at-load and arrived-by-schedule); on `hour_advanced`, roster-diff all loaded cells (9 dictionary lookups/hour); on unload just free (no state capture). Hazards: floating-origin double-offset; XZ-only arrive checks.

**Shops/dialogue — presence is the gate, never a second boolean (Fossil Law):** shop open ⇔ keeper exists ∧ action=="work" ∧ at station; guard lives in the OPEN_SHOP path only. Closed shop shows a prompt ("Closed — come back in the morning"), never a silent locked door. Sleeping NPC: `will_interact()` false, prompt "Asleep." **Defer schedule-despawn while `GameManager.is_in_dialogue`** and clear `ConversationSystem.current_npc` on despawn — CLAUDE.md crash class #1 becomes routine otherwise.

**Versions:** v1 = schedules + presence + teleport transitions + availability gating + validator rules. **Ship gate: Elder Moor at 03:00 vs 13:00 must be visibly different places.** v2 = visible walking (port `_bt_settle`, active cell only; optional claim seats for tavern chairs/pews; households). v3 = renamed to **reactive overrides** (flee/cower beat the schedule; curfew/festival/attack rewrite a town's day via WorldState) — needs/moods dropped, RECON never needed them.

## Five lines to port verbatim
1. `place_for_current_hour()` — `civilian.gd:742-766`.
2. `_bt_settle` — `civilian.gd:837-861`.
3. LOD re-entry rule — `civilian.gd:280-283`.
4. Per-entry schedule dedup — `sim_clock.gd:93-99`.
5. Prefix marker matching + skip-never-relocate — `site_planner.gd:896-907, 788-790`.

---

## v1 as built (8/2)

Seven commits, against this brief. What was followed, and what the code found
that the scout could not have known.

**Followed as written:** the additive clock on GameManager rather than a second
autoload; `advance()` as the one time-skip door; the per-entry dedup key,
verbatim; `place_for_current_hour()` as the one placement implementation with
per-class doors onto it; skip-never-relocate; missing station key → authored
spawn + loud warning; unmatched hour → idle; stations in WORLD coordinates with
the floating origin subtracted in exactly one place (`world_to_local()`);
presence as the shop gate with the guard in the OPEN_SHOP path only; deferred
despawn while in dialogue; `current_npc` cleared on despawn.

**Added, because the scout was right that CoG must persist:** the clock is
saved (format 9 → 10) and GameManager is registered in `check_serialization`
with a written reason for each field it does not save.

**What the code found.** The scout assumed a data table could name the town
NPCs. Measuring says two-thirds of them cannot be named at all: 76 of 189 draw
their `npc_id` from `WorldLexicon`'s pool and their position from `randf()`, so
both change every boot. Records exist for the 112 that survive two cold boots;
the rest get a runtime record from the archetype their spawner declares
(`attach_ambient`). This is the same three-state model — it just accepts that
one tier of the population has no stable identity, which is itself a design
question now sitting in `wave_b_dispositions.md` as LW-1.

**Also:** RECON's absent-marker rule needed a partner here. An NPC who leaves
the world keeps their node (freeing an authored quest giver means rebuilding
their quest state on the way back), so "absent" has to mean invisible AND
collisionless AND not processing. An invisible body with live collision is a
wall the player walks into and cannot see; `check_living_world.tscn` asserts
against it by name.

**Deferred to v2 exactly as scoped:** visible walking (`_bt_settle`), claimed
seats, households. v3's reactive overrides untouched.
