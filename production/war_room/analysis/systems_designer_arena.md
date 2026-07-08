# Systems Designer Analysis — Bloodsand Arena Tournament Audit

**War Room Session: Alpha Complaint "Arena is super busted"**
**Analyst:** Systems Designer | **Date:** 2026-07-08
**Verdict up front:** The complaint is fully validated. The tournament is UNWINNABLE at wave 1 due to a signal-ordering bug, and even with that fixed it can never be WON because nothing calls the completion path after wave 5. Both are small fixes. Recommend FIX (timeboxed ~3 days) with the quest layer CUT, not the whole arena.

---

## 1. System Map

| Component | File | Role |
|---|---|---|
| TournamentManager (autoload) | `scripts/autoload/tournament_manager.gd` | Wave defs, spawn, completion detection, gold, fame, equipment lock |
| Arena level | `scripts/levels/bloodsand_arena.gd` + `scenes/levels/bloodsand_arena.tscn` | Floor w/ spike pit, barrier, spawn markers, shops, arena master spawn |
| Gladiator enemy | `scripts/npcs/gladiator_npc.gd` | All wave enemies (every enemy type spawns as this class) |
| Arena Master NPC | `scripts/npcs/arena_master.gd` | Gormund — entry dialogue, between-wave continue/leave, victory dialogue |
| Quests | `data/quests/arena_tournament.json`, `arena_tier_1.json`, `meet_the_arena_master.json` | Quest layer (mostly disconnected, see §4) |
| Dialogue JSON | `data/dialogue/arena_master_gormund.json`, `varn_the_scarred_arena.json` | Gormund JSON is ORPHANED (never loaded) |
| Enemy data | `data/enemies/arena_gladiator_*.tres`, `arena_champion_krag.tres`, `arena_legend_bloodfang.tres` | Only `arena_gladiator_novice` is ever used; rest is dead content |

## 2. Traced Tournament Flow (with break points)

```
Varn (Elder Moor, elder_moor.gd:564) gives "meet_the_arena_master"      [WORKS]
  -> Player travels to arena (0,3), talks to Gormund
     arena_master.gd:174-177 completes quest via on_npc_talked()        [WORKS]
  -> Entry dialogue (hardcoded scripted lines, arena_master.gd:170-236) [WORKS]
  -> TournamentManager.start_tournament() (tm.gd:117)
       locks equipment, emits tournament_started, start_next_wave()     [WORKS]
  -> Wave 1: barrier_enabled + _spawn_wave_enemies() (tm.gd:140-201)    [WORKS]
       2x arena_gladiator_novice spawned as GladiatorNPC                [WORKS]
  -> Player kills both gladiators
       GladiatorNPC._die() (gladiator_npc.gd:271)                       *** BREAK #1 ***
       wave NEVER registers as complete -> soft-lock in wave 1
  -> [if #1 fixed] _on_wave_complete: gold, barrier down, teleport to
       WaitingArea (0,0,35), Gormund shows continue/leave dialogue      [WORKS-ish]
  -> Continue: start_next_wave() re-enables barrier immediately
       with player STILL OUTSIDE the barrier at the waiting area        *** BREAK #3 ***
       (only playable because the barrier has giant corner gaps, #4)
  -> Waves 2-5 spawn (5 / 7 / 4 / 18 enemies)                           [balance cliff, §5]
  -> Wave 5 cleared: _on_wave_complete pays gold, teleports player,
       Gormund's handler returns early for wave>=total
       (arena_master.gd:305-307); NOTHING calls _complete_tournament()  *** BREAK #2 ***
       -> tournament stuck active forever, equipment stays locked,
          no tournament_won, no fame, no victory dialogue
  -> Player leaves zone: scene change silently resets everything
       (tm.gd:92-106) — the only "exit" from the stuck state
```

## 3. Bug List (file:line evidence)

### CRITICAL — completion blockers

**BUG-1: Wave completion never fires (the "not completable" bug).**
`gladiator_npc.gd:284` removes the enemy from group `tournament_enemy` and *then* emits `CombatManager.entity_killed` at `:287`. `TournamentManager._on_entity_killed` (`tournament_manager.gd:282`) requires `victim.is_in_group("tournament_enemy")` before erasing from `current_wave_enemies` — the check is always false, the array never empties, `_on_wave_complete()` (tm.gd:289-290) never runs. **Wave 1 is unwinnable for every player.** Note: the CLAUDE.md "freed object" patch (validity checks + `_clear_node_references`, tm.gd:92-106/294-299) is real and correct, but it fixed the *crash* class only — this ordering bug is separate and still live.

**BUG-2: Tournament can never be won even if BUG-1 is fixed.**
`_complete_tournament()` (tm.gd:386) is only reachable via `start_next_wave()` when `current_wave > TOTAL_WAVES` (tm.gd:146-149). `start_next_wave()` is only called from Gormund's "Continue" choice (arena_master.gd:367), and his between-wave dialogue explicitly returns early when `wave_number >= total_waves` (arena_master.gd:305-307). `_on_wave_complete` (tm.gd:303-322) has no wave-5 check. Result after clearing wave 5: gold paid, then permanent `is_tournament_active = true`, equipment locked, no `tournament_won`, no fame, Gormund says "Get back to fighting!" forever.

**BUG-3: Player is locked OUT of the arena for waves 2-5.**
Between waves the player is teleported to `WaitingArea` at (0,0,35) (tm.gd:320,327-343; `bloodsand_arena.tscn:90-91`), which is well outside the ~13-unit barrier. `start_next_wave()` re-enables the barrier immediately (tm.gd:151-152) and never teleports the player back in. By design the player would be sealed out while enemies spawn inside.

**BUG-4: The barrier itself is geometrically broken (which accidentally "fixes" BUG-3).**
The scene's `ArenaBarrier` (tscn:93-128) is scaled (0.715, 0.743), so walls sit at ±12.9/±13.4 but each wall shape is only 14.7 long (~10.5 after scale) against ~26-unit sides -> **large open corner gaps**. There are also four orphaned duplicate wall shapes nested *under* WestWall with arbitrary rotations (tscn:114-128). The barrier neither keeps the player in during combat nor is a coherent wall; player can walk out mid-fight through a corner (equipment stays locked while roaming until a scene change silently cancels the tournament — see BUG-10). The programmatic fallback barrier in `bloodsand_arena.gd:589-636` is actually correct (full 18-radius ring) but is never used because the broken scene node exists (`bloodsand_arena.gd:578`).

### HIGH

**BUG-5: CombatManager's kill check never fires for gladiators.**
`combat_manager.gd:226` gates on `target.has_method("is_dead")` — `GladiatorNPC` declares `var is_dead: bool` (gladiator_npc.gd:24), a property, not a method. So kill detection for every arena enemy rests solely on the broken path in BUG-1, and `_handle_kill_rewards` never runs for them.

**BUG-6: Enemies that fall in the spike pit (or through the floor) stall the wave.**
GladiatorNPC does not use navigation — it beelines at the player (`gladiator_npc.gd:184-192`), so kiting the player around the pit walks enemies into the 8x8 center hole (`bloodsand_arena.gd:55`, SPIKE_PIT_RADIUS=4 half-size). The damage zone is a 3.65-radius x 2.87-tall cylinder (tscn:10-12,134-146): the hole's **corners lie outside the cylinder**, and anything below y~-2.8 exits it — an enemy falling through a corner falls forever, un-killable, and the wave can never complete (cleanup of invalid enemies, tm.gd:286/294-299, only runs inside the kill handler that never triggers). No kill floor exists. Same void-fall applies to the player.

**BUG-7: Wave progression is single-threaded through a killable, interruptible NPC.**
Gormund is `attackable` and permanently killable (arena_master.gd:46,431-488) with no respawn — kill him and the tournament can never advance or start again this session. Worse, his between-wave dialogue fires off a one-shot 1.5s timer (arena_master.gd:291-294) into `ConversationSystem.start_scripted_dialogue`, which **aborts with a warning if any dialogue is already active** (conversation_system.gd:1043-1046). If the player is talking to a shop merchant at that moment, the continue/leave prompt is lost forever -> soft-lock (no retry mechanism).

**BUG-8: Quest layer is fully disconnected from the tournament.**
- `arena_novice_tournament` (`data/quests/arena_tournament.json`) is never started by any code — `arena_master.gd` uses hardcoded scripted lines and never issues START_QUEST; the JSON dialogue that contains the start action (`data/dialogue/arena_master_gormund.json`) is orphaned (id referenced nowhere in scripts).
- Its kill objective targets `"arena_gladiator"` (count 9 — matches no wave math; actual novice count across waves is 14) and no enemy has that id; and QuestManager kill tracking requires `get_enemy_data()` (`quest_manager.gd:409-412`) which GladiatorNPC lacks — kills would never count anyway.
- `next_quest: "arena_veteran_tournament"` points to a quest JSON that **does not exist**.
- `arena_tier_1.json` targets three enemies that don't exist (`arena_pit_fighter`, `arena_beast`, `arena_champion_tier1`) and describes a 3-round format from a scrapped design.

**BUG-9: Fame is unreachable AND never persisted.**
`arena_fame += 50` only happens in the unreachable `_complete_tournament()` (tm.gd:391-393). Separately, `TournamentManager.get_save_data()/load_save_data()` (tm.gd:438-461) are **never called by SaveManager** — the only integration is `_clear_node_references()` at `save_manager.gd:668`. Fame resets to 0 every session; Gormund's fame-based greetings (arena_master.gd:180-194) beyond "Fresh meat!" are dead lines. No faction/reputation hook exists at all. README "rewards and fame incomplete" — confirmed.

### MEDIUM

**BUG-10: Exiting/saving mid-tournament silently cancels with no feedback.**
Any scene change resets state (tm.gd:92-106) with no notification and no gold clawback; wave gold already paid is kept (mild exploit: clear cheap waves, walk out through a barrier gap, zone away, repeat). Load-time reset (tm.gd:456-461) is safe but the save itself never captures tournament state (see BUG-9).

**BUG-11: Every enemy type renders as a broken static sprite.**
`gladiator_npc.gd:102-104` hardcodes `h_frames=1, v_frames=1, pixel_size=0.01` for all spawns and loads `enemy_data.icon_path` (not `sprite_path`, no ActorRegistry check) — wolves, abominations and archers appear as single-frame, wrongly-scaled billboards (standard humanoid is 0.0384); `idle_frames=3` on a 1-frame sheet.

**BUG-12: Ranged/multi-attack enemies are flattened to melee attack #1.**
GladiatorNPC has no ranged logic and reads only `attacks[0]` (gladiator_npc.gd:148-152): goblin archers walk into melee firing "arrows" point-blank; abominations use 3-8 dmg "Rend" instead of their 2-12+5 slam. XP is a flat 50/kill at NOVICE tier (gladiator_npc.gd:290-300) — an abomination worth 200 XP in its .tres pays 50.

**BUG-13: The entire tier system is dead content.**
Spawns are hardcoded `TournamentTier.NOVICE` (tm.gd:223); VETERAN/CHAMPION/LEGEND multipliers (gladiator_npc.gd:126-158), `arena_gladiator_veteran/champion/legend.tres`, boss files `arena_champion_krag.tres` / `arena_legend_bloodfang.tres`, and the tier-gated XP table are all unreachable.

## 4. Wave Balance Table

Arena is at grid (0,3) — 3 cells from the starting town; expected player level **~3-8** (danger scales with distance from Elder Moor). All enemies spawn as GladiatorNPC at NOVICE (x1.0) using only attack[0].

| Wave | Composition | Count | Total HP | Enemy levels | Effective dmg/hit | Assessment |
|---|---|---|---|---|---|---|
| 1 | 2x Novice Gladiator | 2 | 70 | 5 | 4-8 | Fair warm-up |
| 2 | 3x Novice + 2x Goblin Archer | 5 | 145 | 5 / ~2 | 4-8 / 2-8 | Fair (archers wrongly melee) |
| 3 | 2x Wolf + 2x Novice + 3x Archer | 7 | 170 | 3-5 | 2-8 | Fair, mob pressure |
| 4 | 4x Abomination | 4 | **600** | **30** | 3-8 (should be 2-12+5) | **Cliff.** Lvl-30 mid-game monsters vs lvl~6 player; 600 HP wall, armor 12; XP nerfed to 50 ea |
| 5 | 7x Novice + 5x Archer + 2x Wolf + 4x Abomination | **18** | **~985** | 3-30 | mixed | **18 simultaneous spawns** — 90% of the 20-enemy zone budget, all beelining melee; brutal + perf risk |

Payout: `50 * wave * rand(1.0-2.0)` (tm.gd:304-306) -> 50-100 / 100-200 / 150-300 / 200-400 / 250-500 = **750-1500g total**, paid per-wave (kept on death/leave). Reasonable numbers *if* the difficulty curve is fixed; currently the pay curve (linear) vs difficulty curve (cliff at 4, wall at 5) is badly mismatched. Fame +50 and victory bonus: unreachable (BUG-2/9).

## 5. Fix vs Cut

### What actually works
Entry flow, Varn pointer quest, equipment locking (verified enforced at `inventory_manager.gd:407` equip, `:494` unequip, `:888` spells), player-death handling (`game_manager.gd:10/270` -> `tm.gd:347-367`), per-wave gold, the freed-object crash patches, shops/tavern in the outer ring. The architecture (signals, autoload, wave defs as data) is sound. This is a wiring problem, not a design problem.

### Minimum fix set to make it shippable (est. **2.5-3.5 dev-days** incl. playtest)

| # | Fix | Effort |
|---|---|---|
| F1 | BUG-1: track by instance, not group — in `tm.gd:_on_entity_killed` replace group check with `victim in current_wave_enemies` (keep is_instance_valid); or reorder emit-before-remove in `gladiator_npc.gd:_die` | 1h |
| F2 | BUG-2: in `_on_wave_complete`, `if current_wave >= TOTAL_WAVES: _complete_tournament(); return` (victory dialogue already wired to `tournament_won`) — also emit `barrier_disabled` there | 1h |
| F3 | BUG-3: in `start_next_wave()`, teleport player to `get_arena_center()` before enabling barrier (or move WaitingArea marker inside) | 1h |
| F4 | BUG-4: delete the scene `ArenaBarrier` node (incl. 4 orphan shapes) and let the correct programmatic barrier in `bloodsand_arena.gd:589` build | 1h |
| F5 | BUG-6: add a kill-floor DamageZone (instant_kill, box, y=-6, arena-sized) + a 5s watchdog timer in TournamentManager that runs `_cleanup_invalid_enemies()` and completes the wave if empty | 2h |
| F6 | Wave 4/5 rebalance (data-only edit of WAVE_DEFINITIONS): W4 -> 2x `arena_gladiator_veteran` + 1x abomination; W5 -> cap ~8-10, spawn in two staggered groups | 2-3h |
| F7 | BUG-7: make Gormund invulnerable while `is_tournament_active`; retry between-wave dialogue on a repeating timer until it actually shows | 2h |
| F8 | BUG-8: **cut the quest layer** — delete/disable `arena_tournament.json`, `arena_tier_1.json`, orphaned `arena_master_gormund.json`. Arena works questless (Varn pointer + gold). | 1h |
| F9 | BUG-11 cosmetic minimum: use `sprite_path`/ActorRegistry + real frame counts + 0.0384 pixel_size in GladiatorNPC | 2h |
| — | Defer: fame persistence, faction rep, tier tournaments, ranged gladiator AI, krag/bloodfang bosses | post-release |

### Cut option
Gate the arena: lock the entry, remove Varn's `meet_the_arena_master` quest, leave shops accessible. ~2-4h. Zero risk.

### Recommendation: **FIX, timeboxed at 3 days — with the quest chain cut regardless.**
Rationale: the two completion blockers are a 1-line ordering bug and one missing function call; the remaining fixes are small and localized. The arena is the game's only combat showcase side-activity and is already advertised in-world by Varn in the starting town — cutting it orphans that content too. The tier system, arena quest chain, fame persistence, and boss fights should be explicitly descoped to post-release (they are already dead content; deleting the two broken quest JSONs prevents journal confusion). **Tradeoff named:** fixing costs ~3 days of the shippable-.exe push and wave rebalance needs a real playtest pass; if F1-F5 aren't verified clean in one timeboxed pass, fall back to the gate (the gate can even be the announced fallback: "Arena closed for repairs" sign).

### Acceptance test for the fix set
1. Full 5-wave run completes -> `tournament_won` fires, equipment unlocks, victory dialogue shows.
2. Kite an enemy into the pit -> it dies (or is watchdog-culled) and the wave still completes.
3. Die in wave 3 -> `tournament_lost`, equipment unlocked, enemies gone, re-entry works.
4. Save+load mid-wave -> no crash, tournament cleanly reset, no locked equipment.
5. Attempt to leave mid-wave -> barrier actually holds on all 4 sides and corners.
6. Wave 5 on min-spec: frame time within budget with max concurrent enemies.
