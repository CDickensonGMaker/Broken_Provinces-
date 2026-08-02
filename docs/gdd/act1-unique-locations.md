# Act I Unique Locations — Turning Phantom Places Into Real Places

**Date:** 2026-07-08 | **Status:** PROPOSED (awaiting Summoner ratification)
**Source:** War Room post-alpha audit (production/war_room/analysis/dialogue_quest_master.md §2-3)

## The Principle

The alpha's "NPCs mention places that don't exist" complaint and the "world needs more unique areas" goal are the same problem viewed from two sides. Quests and dialogue already reference ~12 invented places inside Act I scope. Instead of scrubbing those references, we BUILD the best ones. Every area built:
1. Un-sticks its quest(s) — the reach objective finally has a place to fire
2. Gives NPCs something REAL to talk about (unique/archetype dialogue references it)
3. Densifies the starting region with hand-crafted landmarks

**Wiring rule for every area:** scene (or sub-area) + `WorldGrid.LOCATIONS` entry + `QuestManager.on_location_reached("<exact_id>")` call in the scene script + `WorldLexicon` entry so directions/rumors resolve. The quest-target ID strings below are EXACT — they must match or the objective stays dead.

---

## Tier 1 — Build First (signature areas, highest leverage)

### 1. The Silent Mill — Millbrook Watermill
- **IDs:** `millbrook_watermill_interior`, `mill_water_channel` | **Unlocks:** watermill_curse.json (2 stuck objectives)
- **Where:** Millbrook riverbank, attached to town
- **Vibe:** The rickety mill that IS Millbrook's livelihood — now "cursed" (sabotaged?). Creaking wheel, flooded under-channel you wade through, grain dust in god-rays. Interior + water channel sub-area.
- **Why Tier 1:** This is the anchor for the **Millbrook bandit-takeover flagship quest** (CatacombsOfGore-0rf). The bandits control the town BY controlling the mill. Curse quest becomes the thread players pull to discover the takeover. Two quests + the flagship converge on one build.
- **Build cost:** Interior scene + small exterior channel. Medium.

### 2. The Standing Stones (Elder Moor Ritual Site)
- **ID:** `elder_moor_ritual_site` | **Unlocks:** 1 quest + user's own lore note ("old ruins from years past")
- **Where:** Forest clearing at Elder Moor's edge (cell 0,0 or adjacent)
- **Vibe:** Moss-eaten monolith circle older than the Empire. By day: harmless curiosity locals shrug at. By night: candle stubs, fresh scratch-marks, robed figures if a quest is active. Foreshadows the Act II cult (Pola Perron/Whaler's Abyss thread) without leaving Act I.
- **Why Tier 1:** Cheapest build on the list (one clearing, ~8 stones, a hidden chest), sits in the FIRST cell players explore, and gives every Elder Moor NPC a unique-dialogue topic that is real.
- **Build cost:** Tiny. Half a day with existing assets.

### 3. The Rusty Anchor Tavern (Dalhurst docks)
- **ID:** `rusty_anchor_tavern` | **Unlocks:** missing_courier chain step ("find the sailor Brennan")
- **Where:** Dalhurst harbor district, interior
- **Vibe:** The dive where dock trash drinks — opposite pole to whatever respectable inn Dalhurst has. Low ceiling, hammocks in the rafters, smuggler back room, sailor Brennan at his corner table. Rumor hub for everything nautical (Larton ghost-pirate rumors = Act II bait).
- **Why Tier 1:** Interior-only = cheap. Taverns are the highest-traffic dialogue venues in the game — this is where the new unique/archetype responses get showcased. Natural home for thieves-guild and smuggling content.
- **Build cost:** One interior. Small.

### 4. The Old Watchtower (east of Thornfield)
- **ID:** `old_watchtower` | **Unlocks:** 1 quest + 3 dialogue mentions + the missing `thornfield_guard_captain` (breaks 5 quests)
- **Where:** Hill east of Thornfield, overlooking the collapsed mountain pass
- **Vibe:** Crumbling frontier tower staring at the rockfall that severed the road to Falkenhaften — the physical symbol of "the Empire stopped answering." Player climbs it and SEES the blocked pass (Act II tease, exactly your notes' lore).
- **Why Tier 1:** Solves two audit findings at once — the phantom place AND the unspawned guard captain get one home: garrison him here (or in Thornfield proper with patrols to the tower). His 5 broken quests route through a real landmark.
- **Build cost:** One tower + hilltop. Small-medium.

---

## Tier 2 — Build Second (strong areas, single-quest leverage)

### 5. Ashford Estate (outside Thornfield)
- **ID:** `ashford_estate` | **Unlocks:** adventurers guild scout quest
- **Vibe:** Abandoned noble manor gone wrong — the family fled or died when the pass closed and trade collapsed. Overgrown grounds, boarded windows, something inside. Act I's haunted-house set piece. Sells grim-dark decay better than any dungeon.
- **Build cost:** Manor exterior + interior. Medium.

### 6. Dalhurst Cemetery
- **ID:** `dalhurst_cemetery` | **Unlocks:** 1 quest + Morthane content home
- **Vibe:** Walled port-town graveyard with a small Morthane shrine — where the death-cult misunderstanding in your lore becomes playable. Grave-robbing bounties, a mourner NPC, night burials. Pairs with the undead theme without needing a new dungeon.
- **Build cost:** Walled yard + shrine. Small.

### 7. Crossroads Bandit Camp
- **ID:** `crossroads_bandit_camp` | **Unlocks:** 2 quests + your notes ("bandits prey on travelers — yes")
- **Vibe:** The camp behind the ambushes on the Elder Moor–Dalhurst road. Hidden off-road in a ravine. **Design it as the multi-path prototype:** approachable via kill / bribe / intimidate / join — the small-scale rehearsal for the Millbrook flagship, using the FIGHT/BRIBE/NEGOTIATE/INTIMIDATE system that already exists but is enabled on only 2 enemies.
- **Build cost:** Wilderness camp. Small.

### 8. Velkyr's Tower (southeast of Dalhurst)
- **ID:** register as `velkyrs_tower` (referenced in archmage_elara.json:304,440 — Arcane Circle entrance exam)
- **Vibe:** Ruined mage tower, vertical mini-dungeon: each floor one hazard (wards, animated books, a golem?), exam objective at the top. Gives the Arcane Circle questline its own landmark instead of a name that resolves to nothing.
- **Build cost:** Vertical interior, 3-4 floors. Medium.

---

## Tier 3 — Cheap wiring, not new areas

### 9. Guild sub-areas: `guild_arena`, `iron_hall_training_grounds`
2 quest files each. These are rooms INSIDE existing guild buildings — add the room (or just designate an existing space) + fire `on_location_reached()` on entry. Hours, not days.

### 10. The Sunken Crypts (southwest of Elder Moor)
Your own notes list it and Elder Moor locals already rumor it ("lose your head"). If it exists as a scene, register + hook it; if not, it's the natural Act I bonus dungeon — undead + Morthane lore, feeds the cemetery/ritual-site theme. Decide after Tier 1-2.

### 11. Darkwood Grove
- **ID:** `darkwood_grove` | market_theft_2 chain already has chest coords (-280,0,520 ≈ cell (-3,5))
- Thieves' stash clearing in twisted woods. Borderline: 1 quest, off the main paths. Build ONLY if the market_theft chain survives the scope qc; otherwise retarget the objective to the Crossroads Bandit Camp (§7) — one string edit.

---

## Explicitly NOT built (Act II bait — reframe as rumor)
`kazan_dun_catacombs`, `ruined_temple_chronos` (Aberdeen), Whaler's Abyss content, Larton, elf/pirate areas. Dialogue may reference them as DISTANT places ("across the mountains", "down south past the hold") — validator whitelist `LORE_ONLY`. Never as somewhere the player is told to go.

## Dialogue Integration (the point of all this)
When the unique/archetype response tiers go live (CatacombsOfGore-sv2), each area above gets:
- 2-3 **unique responses** for its nearest named NPCs (Gormund knows the guild arena; Brennan lives in the Rusty Anchor; Millbrook elder fears the mill)
- 1-2 **archetype lines** (guards warn about the bandit camp; priests mutter about the ritual site; sailors know the Anchor)
- **WorldLexicon direction entries** so DIRECTIONS topic answers point at real coordinates
No generic-pool additions. Every new line names a place that exists.

## Suggested Build Order
Standing Stones → Rusty Anchor → Old Watchtower → Silent Mill → Crossroads Camp → Cemetery → Ashford → Velkyr's → Tier 3 wiring.
(Cheapest-first through the first four so the starting zone densifies immediately; Mill lands with the flagship quest work.)
