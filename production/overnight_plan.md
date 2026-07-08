# Overnight Improvement Plan — 50 Items
**Date:** 2026-07-08 | **Status:** PROPOSED (Summoner says go → batch executes)
**Scope rule:** everything here is ON TOP of the 20 Beads audit issues, the Act I locations list, the 100-pool expansion, and the name expansion (done). Items are sized for autonomous overnight batch work (S = under an hour, M = a few hours). Sources: War Room audit leftovers, CLAUDE.md known-bugs list, older LINTER/SCENE reports, content gaps.

## A. Dialogue & NPC feel (10)
| # | Item | Size |
|---|------|------|
| 1 | Unique greetings ×3 for every named quest giver (~30 NPCs) so first contact never sounds generic | M |
| 2 | Expand farewells pool — worst pool in game (only 4 of 16 eligible at neutral disposition) | S |
| 3 | Expand greetings pool (only 10 of 23 eligible at neutral) + disposition-band coverage | S |
| 4 | Priest dialogue reflects god personalities (Chronos jealous-of-Morthane, Gaela serene, Morthane morbid-kind) per world bible | M |
| 5 | Guard warnings name REAL local dangers per region (bandit camp, crypts, wolf den) | S |
| 6 | Tavern ambient barks: one-line background chatter NPCs emit without interaction | M |
| 7 | Fix "Rusty Nail" vs "Rusty Anchor" tavern naming drift (career_topics.json vs quests) | S |
| 8 | Merchant haggle flavor lines tied to disposition (cheaper/pricier feel, no mechanics change) | S |
| 9 | "Heard before" dimming — UI hint when a topic has no unheard responses left | M |
| 10 | Barmaid/innkeeper room-rental dialogue actually mentions the bed/room system | S |

## B. Quests & written content (8)
| # | Item | Size |
|---|------|------|
| 11 | Retarget Act I stuck reach objectives NOT covered by planned areas → interact/kill/collect types | M |
| 12 | Journal-quality pass: rewrite Act I quest descriptions so each reads like a story beat, not a todo | M |
| 13 | +20 bounty templates (escort, recover, investigate, clear-nest — beyond kill-X) | M |
| 14 | Bounty completion dialogue: 5 templates → 20, flavored by giver archetype | S |
| 15 | 12 readable lore notes/books seeding Act II (ghost pirates, Kazan-Dun, the missing king) placed in chests/shelves | M |
| 16 | Wanted posters in towns naming actual generated bounty targets | M |
| 17 | Gravestone inscriptions bank (40 lines) for cemetery + existing graves — names from new lexicon | S |
| 18 | Tharin's 3-quest intro chain from your notes (Thornfield delivery, Dalhurst supplies, +1) verified/completed end-to-end | M |

## C. World & visual polish (10)
| # | Item | Size |
|---|------|------|
| 19 | Elder Moor floor → fallen-leaves texture (CLAUDE.md known bug) | S |
| 20 | Thornfield floor → fallen-leaves texture (known bug) | S |
| 21 | Thornfield leader sprite wrong asset (known bug) | S |
| 22 | Stop procedural artifacts/totems spawning inside hand-crafted zones (known bug) | M |
| 23 | Fast-travel spawn safety: check for enemies/objects at arrival point (known bug) | M |
| 24 | Road signposts at junctions naming real destinations + directions | M |
| 25 | Town notice boards as physical objects (bounty board access + flavor notices) | M |
| 26 | Market stall clutter pass in Dalhurst (crates, fish baskets, cloth) | M |
| 27 | Night lighting pass: window glow in towns after dark | M |
| 28 | Cell boundary seam sweep: walk all Act I boundaries, log terrain height mismatches | M |

## D. Audio (5)
| # | Item | Size |
|---|------|------|
| 29 | Wire existing audio event hooks: item_pickup, menu_open/close, projectile_fire (hooks exist, sounds silent) | M |
| 30 | Town ambience loops: forest birds (Elder Moor), gulls+rigging (Dalhurst), river+mill creak (Millbrook) | M |
| 31 | Tavern background: murmur loop + occasional laughter | S |
| 32 | Combat audio differentiation: hit vs block vs parry vs miss | M |
| 33 | Footstep surface switching verification (stone/wood/grass hooks per CLAUDE.md convention) | S |

## E. UI & QoL (7)
| # | Item | Size |
|---|------|------|
| 34 | On-screen quest tracker: current tracked objective as HUD element | M |
| 35 | Compass POI icons for discovered locations | M |
| 36 | 30 loading-screen tips drawn from real mechanics (encumbrance formula, detection DCs, duel rules) | S |
| 37 | Death screen flavor lines (20, grim-dark tone) instead of plain game-over | S |
| 38 | Gear tooltips: compare-vs-equipped arrows (spell tooltips already do this — port the pattern) | M |
| 39 | Damage number styling: crits pop, DoT ticks small | S |
| 40 | Rest/Wait menu shows what changes (shop hours, respawns, healing rate) | S |

## F. Performance & stability (5)
| # | Item | Size |
|---|------|------|
| 41 | Object pooling for damage numbers + hit particles | M |
| 42 | MultiMesh conversion for wilderness vegetation (per perf audit secondary finding) | M |
| 43 | Move cell generation off main thread OR spread over frames (kills the 100-unit hitch) | M |
| 44 | Autosave state verification: scripted save→load→diff test (known bug list) | M |
| 45 | Boot-log sweep: run game, fix every error/warning printed before main menu | M |

## G. Data hygiene & dead code (5)
| # | Item | Size |
|---|------|------|
| 46 | Whaeler's Drake decision: repurpose orphaned town script as Whaler's Abyss upgrade or delete (audit flagged it's the better-built script) | S |
| 47 | Unify spellings project-wide: Falkenhaften, Whaler's Abyss, Silvanost/Elven Outpost (pick canon, propagate) | M |
| 48 | Define or delete `kreigstan_forest` fallback in WorldLexicon (currently maps to nothing) | S |
| 49 | Sweep ALL encounter tables (not just desert) for enemy ids missing from spawn config | S |
| 50 | Full gdscript-linter pass on scripts/ + fix top-priority warnings (last report is April) | M |

## Execution notes
- Batch order: G (hygiene first, prevents rework) → B11 → C known-bugs → A → D/E → F.
- Each item gets a Beads issue on execution start; validators (gdscript-linter, asset-validator, scene-auditor) run per project CLAUDE.md after each category.
- Anything requiring in-editor visual judgment (27, 28) produces a report + screenshots for morning review instead of blind changes.
