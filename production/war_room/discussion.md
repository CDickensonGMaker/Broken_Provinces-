# The Debate — Full Post-Alpha Audit (2026-07-08)

All six Architects filed reports (see analysis/). The Arbiter held the Devil's Advocate seat. Cross-examination surfaced four themes that no single Architect owned:

---

## Theme 1: "Authored but never wired" — the game is closer to the vision than believed

- **Game Designer:** 39 quests carry authored choice/consequence data; `QuestManager.apply_choice_consequence()` has ZERO callers. A 4-ending Keepers finale sits fully written and inert.
- **Dialogue Master:** the three-tier response system (unique/archetype/generic) is dead code — `register_archetype_response()`/`register_unique_response()` never called. `COMPLETE_QUEST_OBJECTIVE` dialogue action is fully wired (CLAUDE.md wrongly says it's missing) but no content uses it. `weather.tres` never loads.
- **Systems Designer:** arena equipment locking, gold payout, death handling all WORK — the tournament fails on two one-line-class wiring bugs.

**Consensus:** The cheapest big win in the whole audit is wiring, not writing. ~1 day to activate 37 quests' choices. 2 one-liners to make the arena winnable.

**Devil's Advocate:** activating 37 quests of never-executed consequence data means 37 quests of never-TESTED consequences. Wiring day must be followed by a consequence QA pass or you ship 37 new bugs. Named sacrifice: ~3-4 days of QA nobody has scheduled.

---

## Theme 2: Content references a world that doesn't exist — and no tool catches it

Every Architect independently hit this:
- Dialogue: phantom places (Velkyr's Tower, Darkwood Grove, The Silent Mill, Whaeler's Drake ghost-script), 4 spellings of the canyon town, Falkenhafen/Falkenhaften drift.
- Dialogue: 113 of 204 reach/explore objectives can never fire; 8+ quest givers/turn-ins have wrong or unspawned NPC ids (breaks 5 Thornfield quests, 4 endgame Thieves quests, Aberdeen chain).
- Systems: arena quests target 4 nonexistent enemy ids; `next_quest` points to a missing file.
- Performance: 60% of the desert encounter table references enemies missing from spawn config.

**Consensus:** This is one disease, not thirty bugs. The fix is a **content validator tool** (run in editor/CI): every quest giver/turn-in/target NPC id, location id, enemy id, and next_quest must resolve against WorldGrid, spawned-NPC registry, enemy .tres files, and quest files. CLAUDE.md's QUEST DESIGN RULES already mandate this manually; manual verification demonstrably failed at 223-quest scale.

**Devil's Advocate:** the validator will light up hundreds of errors on first run, many in content being cut anyway. Run the scope cut FIRST, validate what remains, or you'll burn a week fixing corpses.

---

## Theme 3: The desert lag is a boundary-generation bug wearing a biome costume

- Performance: lag is not desert density — it's impassable-edge decoration (45-175 rock physics bodies per mountain edge), stacked fullscreen alpha water planes, and a 5-7x enemy budget blowout at danger-10 cells. Interior forest cells get none of this — hence the dev never saw it.
- **Implication for scope:** coastal cells near Dalhurst have the same water-plane overdraw; this is NOT cuttable by cutting the desert. The quick-win fixes (global enemy cap, cluster reduction, plane consolidation, shared materials) benefit the whole map.

**Consensus:** fix the generators (an afternoon), regardless of whether the Tenger desert stays reachable.

**Devil's Advocate:** danger-10 zones SHOULD feel deadlier than danger-1. Cap enemies globally but preserve the difficulty gradient through enemy quality, not quantity — or the far map goes flat.

---

## Theme 4: Standardize by formula and base class, not by constant

- Asset Validator: same `pixel_size` on 96px vs 64px vs 48px sheets = different world heights. 180+ scattered assignments. Standard must be `pixel_size = target_world_height / frame_height`, computed, with 0.0256@96px (≈2.46m) as the humanoid anchor (most common: 42 uses).
- UX: 16 popups, 3 margin schemes, 9 duplicated palettes, 6 cloned button-stylers, shop UI rebuilt from scratch by 4 different scripts. ADR-003 codified the standard in May; nothing enforces it. Answer: `BasePopupUI` (FULLSCREEN / DIALOGUE / COMPACT size classes) + UIManager autoload (one layer-100 canvas, modal stack, refcounted pause) + one shared Theme.

**Consensus:** identical failure shape — per-instance hand-tuning where a single source of truth should exist. Same remedy shape as Theme 2: centralize, then migrate.

**Devil's Advocate:** blind global replace of pixel_size will break scenes that were hand-tuned to LOOK right despite wrong math. Migrate via the audit table, eyeball each NPC class. UI migration: shop and bounty board first; don't touch working menus (game_menu, dialogue box) — they're the standard, not migration targets.

---

## The Scope Debate (Devil's Advocate vs. all)

The Summoner's own notes draw a "Demo Scope" line: **Elder Moor, Thornfield, Dalhurst, Millbrook, Crossroads** + their dungeons (Willow Dale, Bandit Hideout, Sunken Crypts, Bloodsand Arena). Below the line: Kazan-Dun, Aberdeen, Larton, East Hollow, Whaeler's Abyss, Pola Perron, King's Watch, Falkenhaften, elf areas, pirate cove, boat travel.

Arguments accepted:
- Alpha feedback clusters entirely inside the line (UIs, dialogue, sprites) or at its broken edges (desert, arena).
- The dynamic-quest identity (Theme 1) is buildable entirely inside the line — Millbrook is LITERALLY the bandit-takeover scenario from the Summoner's example, already lore'd ("bandits have taken the whole town operation over").
- Cutting below the line auto-deletes several broken quest chains (Aberdeen's dead Father Aldwin, mayor id mismatch).

Named sacrifices:
1. The Tegner desert becomes atmosphere, not content (keep reachable, perf-fixed, but no quest investment).
2. Kazan-Dun's 5 built dungeon levels ship dark — real sunk cost, deferred to release 2 ("keep putting things out" strategy makes this a feature, not a loss).
3. Dialogue referencing below-the-line places must be reframed as distant rumor ("across the mountains...") — validator whitelist category `LORE_ONLY`, not deletion.
4. Main quest letter-to-Falkenhaften hook must land at a within-scope cliffhanger (Dalhurst/Aldric Vane), or be re-staged.

**Resolution → synthesis.md (The Decree).**
