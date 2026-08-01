# Refactor Day Plan — 2026-08-01 (CoG track)
*Companion plan lives at `BP_RTS_Dark_Shadows\REFACTOR_PLAN_2026-08-01.md`. Shared Phase 0 below runs first across both projects.*

Sources: `docs/audits/AUDIT_2026-08-01_full.md`, `production/war_room/synthesis.md` (2026-07-08 decree — this plan executes its Phase 0/1.1 where they overlap with refactoring).

## PHASE 0 — SAFETY (both projects, first, no decisions needed) ~30 min

1. **CoG: commit the dirty tree.** 142 files (93 M / 2 D / 47 ?) unsynced since Jul 8 — includes the ADRs, GDDs, WeatherManager, secrets system. One commit on `main`, push. Message: checkpoint, not curation. Review `git status` for obvious junk (zips, exports) and exclude those from the commit; everything else goes in.
2. **BP: commit the May 11 artillery wave** (98 files). Same rule.
3. **Move misfiled RECONgame playtest notes** (`BP_RTS_Dark_Shadows\First Playtest since our new update.txt`) → `RECONgame\production\playtests\`.

Gate: `git status` clean (minus deliberately ignored paths) in both repos, both pushed.

## PHASE 1 — REPO HYGIENE (CoG) ~45 min

1. `.gitignore`: `exports/`, `*.exe`, `*.pck` at root, `*.blend1`, `data.zip`-class archives.
2. Move root exe/pck pairs + `exports/` (1.1 GB) out of the working tree (e.g. `D:` or a `_builds` folder outside the repo — disk near-full, so *move*, don't copy).
3. Delete: `data.zip`, `scripts (2).zip`, `testnew_dungeon.json`, `Sprite folders grab bag/` (after a 10-second eyeball that nothing unique lives there — flag anything doubtful instead of deleting).
4. Sweep the ~11 root audit reports (`AUDIT_*.md`, `LINTER_REPORT.md`, `WARNINGS_*.txt`, `GDSCRIPT_*`) into `docs/audits/legacy/`.
5. Delete stale branches `master` and `WHERE-WERE-AT` (local + origin) **after** confirming merged into `main` (`git branch --merged`). If not merged, report instead of deleting.

## PHASE 2 — CONTENT VALIDATOR (CoG's highest-leverage tool) ~2 h

Build `tools/validate_content.gd` (headless, `godot --headless --script`):
- Every quest JSON: giver / turn-in / target NPC ids resolve against NPC profiles; reward item ids resolve against `data/items/`.
- Every encounter table entry resolves to a real enemy .tres (kills the desert-60%-phantom class).
- Every enemy .tres: `sprite_path` / `icon_path` exist on disk (7 + 19 known missing as of Mar).
- Every dialogue action referenced actually has a handler registered.
- Output: one report file `docs/audits/validation_report.md`, non-zero exit on failure.

Then run it and **fix what it finds** — this IS the War Room's #1 defect class (under-wired, not under-built): thornfield_guard_captain (breaks 5 quests), desert encounter table, and the APPLY_CHOICE_CONSEQUENCE wiring (unlocks 37 quests' dormant branches).

## PHASE 3 — DEBUG PRINT GATE (CoG) ~45 min

- Add a `Log` autoload (or static class) with `Log.d()` gated on `OS.is_debug_build()` / a project setting.
- Mechanically convert the 335 `print(` calls in `scripts/` (scripted find/replace, hand-check the ~20 that are multi-line or format-heavy).
- Leave `push_error`/`push_warning` alone.

## PHASE 4 — GOD-SCRIPT SPLITS (CoG, biggest refactor risk — do LAST, one at a time) 2–3 h

Order by risk/reward:
1. **`scripts/ui/hud.gd` (4,086)** — safest split: extract self-contained panels (minimap, status bars, hotbar, notifications) into their own scripts on their existing scene nodes; hud.gd becomes a coordinator. UI splits are low-blast-radius.
2. **`scripts/enemies/enemy_base.gd` (3,169)** — extract the 10-state AI machine into `enemy_ai.gd` (component node or RefCounted owned by base); combat/stats stay. 64 enemies inherit this — **run the game and fight 3–4 enemy types after**, not just parse-check.
3. **`scripts/generation/wilderness_room.gd` (3,332)** — only if time remains; generation code is the hardest to verify quickly.

**NOT today:** autoload consolidation (44 → fewer). That's an architecture change with init-order blast radius across every system — needs its own War Room session, not a refactor-day line item.

## VERIFICATION RULES

- CoG is **Godot 4.5** — confirm the editor/headless binary version before opening anything; a newer editor will silently upgrade `project.godot` (same trap as the RECON 4.7 rule, in reverse).
- After each phase: project must parse headless (`godot --headless --check-only` is a liar for autoloads — do a real `--headless --quit` boot) and commit per phase, not one mega-commit.
- Final gate is Caleb's: fresh boot, walk a town, fight, open every UI panel touched. Dev saves mask fresh-player bugs.

## OUT OF SCOPE TODAY

Cave-kit re-export (479 MB → needs Blender pass), BasePopupUI/UIManager build-out, name/identity resolution ("Broken Provinces" vs "Catacombs", "Emtpy" typo — Caleb's call), any Act I content work.
