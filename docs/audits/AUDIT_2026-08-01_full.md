# Full Audit — CatacombsOfGore / Broken Provinces: The Empty Throne
*2026-08-01, Wyrm. Retrospective audit of earlier project.*

## 1. Project identity

- **Engine:** Godot 4.5, Forward+, 640x480 viewport scaled to 1280x960.
- **Genre/scope:** PS1-style open-world action RPG — Elder Scrolls exploration + Souls-ish combat + TTRPG dice mechanics + Fallout:NV-style faction/skill-check dialogue (README.md).
- **Identity split:** rebranded mid-life. `project.godot` says `config/name="Broken Provinces"` / "Broken Provinces: The Empty Throne"; folder, README, and one export pair still say Catacombs of Gore. Two full export pairs in repo root: `Broken_Provinces_The_Emtpy_Throne_v1.exe/.pck` (73 MB pck, typo "Emtpy") and `CatacombsofGore_v2.exe/.pck` (15 MB), both Mar 2 2026. "Broken Provinces" is the shared setting connecting it to BP_RTS_Dark_Shadows.
- **Docs unusually good for a solo project:** `design/adr/` (4 ADRs: cell-streaming, save-system, ui-patterns, travel-systems), `design/gdd/` (6 GDDs), `docs/lore_bible.md`, `docs/world_lore.md`, `docs/town_development_guide.md`, plus a complete War Room deliberation at `production/war_room/` (synthesis.md, 2026-07-08 — post-alpha audit decree defining a scope-locked "Act I: The Empty Throne" release).

## 2. Codebase health

**Volume:** 315 .gd files (excl. addons/archive), **144,441 lines of GDScript**. `scripts/autoload/` 41 files / 28,813 lines; `scripts/ui/` 37 / 23,186; `scripts/world/` 43 / 17,503; `scripts/levels/` 54 / 16,115; `scripts/npcs/` 15 / 8,408.

**Typing discipline: excellent.** 5,875 of 5,958 functions have return types (98.6%); 13,309 typed vars vs 430 untyped (97%). 178 `class_name` declarations.

**Signals: healthy.** 341 declarations, 520 emits; autoloads communicate via signals (e.g. `combat_manager.gd`, `conversation_system.gd` with 8+ documented signals).

**Concerns:**
- **44 autoload singletons** — manager-sprawl (GameManager, QuestManager, CrimeManager, BountyManager, MoralityManager, FactionManager, TournamentManager, DuelManager, EscortManager, CompanionManager, GuildRankManager, WeatherManager, SoulstoneEconomy, SpellCreator…). Init-order and cross-coupling risk; same divergent-parallel-systems blindspot RECONgame has.
- **God scripts:** `scripts/ui/hud.gd` 4,086 lines; `scripts/generation/wilderness_room.gd` 3,332; `scripts/enemies/enemy_base.gd` 3,169 (one base class carries all 64 enemies + 10-state AI machine); `quest_manager.gd` 2,577; `conversation_system.gd` 2,503; `boat_voyage.gd` 2,239; `game_menu.gd` 2,132.
- **Two dialogue systems in parallel:** `dialogue_manager.gd` (choice-tree) + `conversation_system.gd` (topic-based Daggerfall-style), with parallel data dirs `data/dialogue/` (32), `data/dialogues/` (16), `data/conversation_pools/` (11). Deliberately layered but the War Room synthesis itself flags dead tiers ("archetype/unique response tiers (dead registration API)").
- **Debug noise:** 335 `print(` calls — incl. ladder bounds printed on every climb start (`player_controller.gd:1099`).
- **TODO/FIXME density remarkably low:** 33 across 144k lines. `archive/orphaned_scripts/` shows dead code was moved out, not left in.
- **UI duplication:** sixteen popups with no base class; `BasePopupUI + UIManager` decreed (war_room synthesis Phase 1.2) but never built.

## 3. Content

- **207 .tscn scenes**: 53 levels (towns Aberdeen, Dalhurst, Duncaster, Millbrook, Larton, Falkenhaften; 5-level dwarven dungeon Kazan-Dun; bandit camps, cultist temples, Bloodsand Arena), 55 room scenes, plus dungeons/wilderness/structures.
- **780 data files:** 64 enemies (.tres), 67 quest JSONs, 146 items, 32 armor, 14 weapons, 17 spells, factions, enchantments, recipes, soulstones, per-town bounty templates, NPC profiles, lore.
- **Systems:** crime/bounty, guilds with ranks, companions, boat travel, fast travel, weather, crafting, enchanting, spell creation, tournaments, duels, escorts, morality, codex, caves, procedural dungeons (in-editor dungeon editor addon), stealth (secret walls/hidden chests — untracked work).
- **Reality check (its own alpha audit):** "under-wired, not under-built" — quests referencing NPCs that don't exist (thornfield_guard_captain breaks 5 quests), a desert encounter table where 60% of entries reference nonexistent enemies, 37 quests with dormant choice branches because APPLY_CHOICE_CONSEQUENCE was never wired, two one-line arena bugs.

## 4. Assets

- **2.7 GB total; 764 MB assets/, 1.1 GB exports/.**
- **Biggest problem: `assets/models/caves/` = 479 MB** — ~26 cave GLBs at ~18 MB each = 63% of all assets in one kit; almost certainly unoptimized. `assets/audio` 111 MB, `buildings` 72 MB, `textures` 42 MB, `sprites` 32 MB.
- **Root junk:** `data.zip`, `scripts (2).zip`, `testnew_dungeon.json`, `Sprite folders grab bag/` (11 MB), `Gameplay footage/`, ~11 machine-generated audit reports (`AUDIT_*.md`, `LINTER_REPORT.md`, `WARNINGS_*.txt`) untracked. 170+ MB exe/pck in root + 1.1 GB `exports/`.
- Uncommitted `.blend`/`.blend1` source art in-repo without LFS (`assets/models/dwarven/bridge/kazans_span_bridge.blend`).

## 5. Git state

- On `main`; stale branches `master` and `WHERE-WERE-AT` (local + origin).
- Commits: Feb 2026 (31) → Mar (11) → Apr (2) → Jul (5). Last commit `b8c8e2f` 2026-07-08.
- **142 dirty files, ~3.5 weeks unsynced:** 93 modified, 2 deleted, 47 untracked — real work: WeatherManager, secret-wall/hidden-chest system, summons, terrain scripts, southern_cave_exterior, dungeon floors, **and the ADRs/GDDs themselves.** One disk failure loses the whole post-alpha design record.

## 6. Completeness

- **Playable and exported** — two shipped .exe builds (Mar 2026); reached real alpha with player feedback (War Room briefing responds to concrete complaints: desert lag, repetitive dialogue, phantom places, broken arena).
- **Finished:** core loop (move/melee/block/dodge/lock-on), cell-streamed open world (`cell_streamer.gd` 1,134 lines + ADR-001), save system, inventory/encumbrance, 4 working spell types, loot, 52+ enemies with drop tables, conversation + dialogue, crime/bounty, arena (buggy), boat travel.
- **Stubbed/broken (per its own audits):** CONE/AOE_POINT/SINGLE_ENEMY/SELF spells untested (ROADMAP.md); arena tournament never completes; 37 quests' branches dormant; 7 enemies missing sprite_path, 19 missing icon_path (Mar 2026 audit, unverified since); thieves-guild soft-lock.
- **Verdict:** not shippable as-is, but a well-mapped ~6–8 weeks from an honest Act I release — and the map already exists (`production/war_room/synthesis.md` Phases 0–2 with per-task estimates). Work simply stopped in July when attention moved to RECONgame.

## 7. Strengths worth carrying forward

1. **Ladder system (confirmed gold-standard):** `scripts/world/ladder.gd` (148 lines) + `player_controller.gd:1076-1150+`. Self-contained Node3D discovers `ladder_bottom`/`ladder_top`/`climb_trigger_zone` markers by name convention, auto-builds its own Area3D trigger, talks to player via duck-typed `has_method()` calls — zero hard coupling; artists drop named markers in the GLB. Direct ancestor of RECONgame's marker contracts. Ruling stands: **port, never rewrite.**
2. **Strict typing at scale** — 98%+ across 144k lines proves the discipline scales.
3. **Data-driven content** — enemies/items/spells as .tres, quests as JSON, per-town bounty templates.
4. **ADR + GDD + War Room paper trail** — the post-alpha decree is a model of scope-cutting with named sacrifices.
5. **In-editor tooling** — `addons/dungeon_editor`, `level_editors`, `world_forge`, `dev/zoo/zoo_registry.gd` (1,756-line creature zoo), `dev/unit_viewer/` — the "every rig needs an exercising probe" instinct predates RECONgame.
6. **Archive discipline** — dead scripts/assets moved to `archive/`, not rotting in place.

## 8. Top improvements, prioritized

1. **Commit the dirty tree.** 142 files incl. ADRs, GDDs, WeatherManager, secrets system unsynced since Jul 8. Single-disk risk on the *design record*. Zero decisions needed.
2. **Resolve the identity split.** Pick "Broken Provinces: The Empty Throne", fix README/folder references, drop the stale Catacombs export pair, fix the "Emtpy" typo.
3. **3 GB → ~1 GB:** gitignore/move `exports/` + root exe/pck; re-export the cave kit (479 MB → likely <50 MB — PS1 aesthetic doesn't need 18 MB/piece); delete `data.zip`, `scripts (2).zip`, `Sprite folders grab bag/`; sweep root audit reports into `docs/audits/`.
4. **Execute War Room Phase 0** — ~1 week of already-scoped ship-blockers (two 1-line arena bugs, thieves soft-lock, desert perf caps, shop/bounty UI). Analysis done; only execution missing.
5. **Build the content validator** (Phase 1.1, 2–3 days) — quests referencing nonexistent NPCs was the #1 defect class; a check that every giver/turn-in/target/enemy id resolves kills the whole class. Directly reusable in RECONgame.
6. **Break up top god scripts** (`hud.gd`, `wilderness_room.gd`, `enemy_base.gd`) and cap autoload growth (fold trivial ones like DiceManager/RestManager into GameSystems).
7. **Delete stale branches** `master` / `WHERE-WERE-AT` once confirmed merged.
8. **Gate the 335 debug prints** behind a debug flag before any future export.

## Bottom line

A shockingly large, well-typed, well-documented solo project (144k lines, 207 scenes, 780 data files) that reached alpha, produced its own honest audit, and went dormant with the fix-plan written but unexecuted and three weeks of work uncommitted. Its marker-contract patterns, data-driven content, dev-probe tooling, and War Room process are the direct ancestors of how RECONgame is run.
