# THE DECREE — Post-Alpha Full Audit
**Session:** 2026-07-08 | **Status:** DECREED (pending Summoner ratification)
**Full evidence:** analysis/*.md | **Debate:** discussion.md

---

## Judgment

Broken Provinces is not under-built — it is under-wired. The alpha's complaints trace to a small number of root causes, most of them cheap: two one-line arena bugs, one never-called consequence function, one dead response-tier system, boundary-decoration generators, and sixteen popups with no base class. The Council decrees a **scope-locked release ("The Empty Throne — Act I")** bounded by the Summoner's own Demo Scope line, with engineering effort spent on wiring what exists rather than building what doesn't.

**Release scope:** Elder Moor, Thornfield, Dalhurst, Millbrook, Crossroads, Willow Dale, Bandit Hideout, Sunken Crypts, Bloodsand Arena. Wilderness stays open (perf-fixed) but content investment stops at the line. Kazan-Dun, Aberdeen, Larton, Whaeler's Abyss, Falkenhaften, elf/pirate content → Act II+.

---

## The Work, In Order

### Phase 0 — Ship-blockers (~1 week)
| # | Task | Evidence | Effort |
|---|------|----------|--------|
| 0.1 | Arena BUG-1: move group-removal after `entity_killed` emit (gladiator_npc.gd:284-287) | systems_designer_arena.md | 1h |
| 0.2 | Arena BUG-2: call `_complete_tournament()` after wave 5 | systems_designer_arena.md | 2h |
| 0.3 | Arena: between-wave teleport inside barrier; spike-pit kill floor; barrier rescale (timebox 3 days total w/ 0.1-0.2, else gate "closed for repairs") | systems_designer_arena.md | 2d |
| 0.4 | Thieves guild soft-lock: give thieves_08_rival_gang's `choice` objective a completion path | game_designer_quests.md | 4h |
| 0.5 | Desert perf quick wins: global enemy cap (~24, preserve difficulty via quality), boundary rock clusters 15-25→3-5, consolidate/dedupe water planes, shared static materials | performance_engineer.md | 1d |
| 0.6 | Fix desert encounter table: 60% references nonexistent enemies | performance_engineer.md | 2h |
| 0.7 | Shop UI: single owned instance (kill 4-way rebuild + canvas leak + group lookup that never matches); remove click-outside cart-discard button | ux_designer.md | 1d |
| 0.8 | Bounty board: standard margins, SIZE_EXPAND_FILL columns, PROCESS_MODE_ALWAYS on root, reparent canvas off the 3D node | ux_designer.md | 4h |
| 0.9 | EnchantingUI/SpellMakerUI render under HUD (no canvas layer set); crafting stations don't pause | ux_designer.md | 2h |

### Phase 1 — Root-cause infrastructure (~2 weeks)
| # | Task | Effort |
|---|------|--------|
| 1.1 | **Content validator tool** (editor/CI): every quest giver/turn-in/target NPC, location id, enemy id, next_quest must resolve; `LORE_ONLY` whitelist for distant places. Run AFTER scope cut. | 2-3d |
| 1.2 | **BasePopupUI + UIManager + shared Theme** (FULLSCREEN/DIALOGUE/COMPACT per ADR-003); migrate shop, bounty board, enchanting, crafting first | 3-4d |
| 1.3 | **Wire APPLY_CHOICE_CONSEQUENCE dialogue action** → activates 37 quests' dormant branches; follow with consequence QA pass | 1d + 3d QA |
| 1.4 | **Dialogue depth**: activate archetype/unique response tiers (dead registration API), make anti-repeat persistent across conversations (consult npc_memory in filter) | 2-3d |
| 1.5 | **Sprite standard**: helper `pixel_size = target_height / frame_height`, humanoid anchor 0.0256@96px (≈2.46m); fix h_frames mismatches (lady_in_red, wizard_mage); migrate via audit table, eyeball per class | 2-3d |
| 1.6 | Scope cut + reference scrub: gate below-the-line zones, reframe out-of-scope place mentions as rumor, re-stage main-quest hook to end at Dalhurst cliffhanger | 2-3d |
| 1.7 | Fix within-scope broken quest-giver ids (thornfield_guard_captain breaks 5 quests; guildmaster_nightshade breaks 4 thieves quests; etc.) — validator (1.1) produces the full list | 2d |

### Phase 2 — The identity: dynamic faction quests (~3-4 weeks)
| # | Task | Effort |
|---|------|--------|
| 2.1 | Engine: OR-objective groups (3-4d), flag-based pre-completion (2-3d), bandit faction + join mechanics (1-2d), boss-lite ongoing effects via generalized daily-penalty ticker (2-3d) | ~2wk |
| 2.2 | **Flagship: Millbrook bandit takeover** — the Summoner's canonical kill/bribe/negotiate/join/usurp quest, on already-established lore | 3-4d |
| 2.3 | Rebuild adventurers_04_bandit_contract as second multi-path showcase; 2-3 flagship branching quests per faction (~16 total; 10 already have dormant branch data) | 1-2wk |
| 2.4 | Sprite regeneration wave with new 3D→2D pipeline, sized via 1.5 formula | ongoing |

---

## Named Sacrifices (Law 2)
1. Kazan-Dun's five built dungeon levels ship dark → Act II anchor.
2. Tegner desert stays as dangerous atmosphere; zero quest content this release.
3. 37 activated choice quests require an unbudgeted ~3-4 day QA pass — accepted as the cost of Theme 1's shortcut.
4. Difficulty at far map shifts from enemy quantity to quality (perf cap).
5. Aberdeen/Larton starvation storyline (good writing) deferred; its broken NPCs go uncorrected because they go unshipped.

## Pillar Check (Law 1)
PS1 aesthetic untouched. Encumbrance/no-slot-limit untouched. Item-purpose philosophy untouched. Multi-path quest decree directly SERVES the documented Dynamic Quest System vision. No violations.

## What This Buys
Alpha complaint → decree mapping: desert lag → 0.5/0.6; weird merchant/bounty UIs → 0.7/0.8/1.2; repetitive dialogue → 1.4; phantom places → 1.1/1.6; sprite sizes → 1.5; arena → 0.1-0.3; faction depth → Phase 2; smaller scale → scope lock. Every complaint has an owner.
