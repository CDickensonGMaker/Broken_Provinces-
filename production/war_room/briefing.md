# War Room Briefing — Full Game Audit (Post-Alpha)
**Date:** 2026-07-08
**Summoner:** Caleb
**Project:** Broken Provinces: The Empty Throne (CatacombsOfGore)

## Query
Full game audit after open public alpha testing. Goal: re-scope to a smaller, shippable release that builds a cult audience. New capability unlocked: 3D-model-to-2D-sprite pipeline.

## Alpha Feedback / Known Pain Points
1. **Desert/sandy areas = severe lag** (top complaint; dev never reached them personally)
2. **UI inconsistency** — popup UIs (merchants, bounty boards especially) behave weird; all should conform to dialogue box / tab menu sizing
3. **Generic NPC dialogue** — heavy repetition, misaligned with quests given, references places that don't exist in-game
4. **NPC sprite/model size discrepancies** — standardize on most common recurring size
5. **Faction quests lack depth** — want multi-path dynamic quests with real consequences (kill/bribe/negotiate/join/usurp bandits example)
6. **Combat arena is "super busted"**
7. **Missing content** — no elf areas, pirate cove, etc. (candidates to cut for smaller scope)

## Architects Summoned
- Performance Engineer (desert lag)
- UX Designer (UI consistency)
- Dialogue/Quest Master (dialogue + lexicon audit)
- Asset Validator (sprite size standardization)
- Systems Designer (arena audit)
- Game Designer (faction quest inventory + dynamic quest gap)

## Constraints
- PS1 aesthetic pillars stand (see CLAUDE.md)
- Smaller-scale release preferred over feature completeness
- Audit only — no fixes without decree approval
