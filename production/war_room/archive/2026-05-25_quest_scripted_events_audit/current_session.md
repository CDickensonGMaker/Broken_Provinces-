# War-Room Session: Quest & Scripted Events Audit

**Date:** 2026-05-25
**Status:** DECREED
**Previous Session:** Post-Playtest Audit (COMPLETE)

---

# ⛧ THE COUNCIL HAS CONVENED ⛧

## The Question Before Us
> Audit the quest and scripted event systems - assess what exists, what works, what's missing, and how to strengthen the experience.

## The Architects Summoned
- **game-designer** - Quest structure, player motivation, pacing
- **systems-designer** - Technical implementation, quest manager capabilities
- **writer** - Narrative coherence, quest chains, story beats

---

## What Was Revealed

### Quest Inventory (Massive)

| Category | Count | Status |
|----------|-------|--------|
| **Main Story Quests** | 14 | Tharin chain + Keepers + Future capital arc |
| **Guild Questlines** | 56 | Adventurers (13), Thieves (13), Mercenaries (13), Mages (13) + repeatables |
| **Temple Questlines** | 30 | Chronos (10), Gaela (10), Morthane (10) |
| **Side Quest Chains** | ~36 | 12 chains × 3 quests each (rescue, stolen items, etc.) |
| **Bounties** | 13 | Repeatable combat contracts |
| **Standalone Quests** | ~25 | Arena, tutorials, regional quests |
| **Future/WIP** | 14 | Capital intrigue, Kazan-Dun succession |
| **TOTAL** | ~188 quests defined |

### What's Working Well

1. **Quest System Infrastructure** - Robust quest_manager.gd with:
   - All objective types (kill, collect, talk, reach, interact, deliver_soulstone, solve_puzzle, recruit_follower, wave_defense)
   - Timed objectives with pause/resume
   - Choice consequences that set flags, modify reputation, unlock followers, spawn enemies
   - Quest chains with auto-progression (`next_quest`)
   - Temptation system (quest items that fail quest if sold)
   - Bounty cooldowns

2. **Faction Integration** - Quests tied to guilds/temples with reputation rewards and rank progression

3. **Narrative Depth** - Multi-approach quests like the Thieves Guild heist with stealth/disguise/smash-grab options and different reputation consequences

4. **Demo Endpoint** - Smart `demo_endpoint` flag on Journey to Kazan-Dun for vertical slice

### What's Missing or Broken

#### Critical Gaps

1. **Scripted Events System - DOES NOT EXIST**
   - No cutscene system
   - No triggered story moments
   - No camera control for dramatic reveals
   - No NPC movement choreography
   - Quest dialogue is the ONLY narrative delivery mechanism

2. **Location-to-Quest Mismatch**
   - Many quests reference locations that don't have scenes (e.g., `harwick_manor`, `hostage_cell`, many bandit camps)
   - `spawn_on_accept` objects have no spawning implementation verified
   - Quest targets like `apprentice_belongings`, `willow_dale_altar` may not exist in scenes

3. **NPC Quest Giver Coverage**
   - Temple priests have dialogue files but need verified spawning
   - Guild NPCs (Vorn, Lady Nightshade, etc.) - presence in scenes unverified
   - Many quest givers are defined but not placed in world

4. **Main Story Progression**
   - Tharin chain works: message → supplies → wolves → letter
   - After letter delivery → Keepers initiation is the branch point
   - Capital arc (capital_intrigue → false_queen → kings_secret → imprisoned_king) is all in `_future/`
   - No clear "main story" through middle game

#### Technical Gaps

1. **No `COMPLETE_QUEST_OBJECTIVE` dialogue action** - Can't complete objectives through conversation
2. **No pre-completion detection** - Can't check if player already did something before quest started
3. **No OR objectives** - Can't do "kill OR intimidate leader"
4. **Dungeon spawn system** - `dungeon_spawn` field exists but implementation unclear

---

## Existing Scenes (53 levels)

| Category | Scenes |
|----------|--------|
| Towns | elder_moor, dalhurst, thornfield, millbrook, larton, aberdeen, windmere, duncaster, falkenhaften, riverside_village |
| Dungeons | willow_dale, bandit_hideout (3 levels), kazan_dun (6 levels), crossroads_ruins, cult_hideout, sunken_crypt, mosshall_tombs, pola_perron_crypt |
| Camps | bandit_camp_north/east/south, goblin_camp, millbrook_bandit_camp, tenger_camp, cultist_temple (2), cultist_ruins_corner |
| Special | bloodsand_arena, iron_hall, athenaeum, wyverns_roost, wolf_den_forest, dalhurst_cemetery, whalers_abyss, elven_outpost, kings_watch |

---

## ⛧ THE DECREE ⛧

**The quest SYSTEM is strong. The quest CONTENT is ambitious. The CONNECTION between them is unverified.**

Before adding more quests or features, the Council decrees:

### Immediate Priority: Validate Existing Content

1. **Scene Audit** - Walk every quest in the Tharin chain and verify:
   - NPCs spawn correctly
   - Objectives are completable
   - Rewards apply

2. **Create Quest Validation Report** - List every quest with:
   - Does giver NPC exist and spawn?
   - Do all objective targets exist?
   - Does turn-in NPC exist?

3. **Document the Critical Path** - What quests form the "demo" experience?
   - Tharin chain → Keepers letter → Keepers initiation → ???
   - What's the hook that keeps players going?

### Near-Term: Basic Scripted Events

A simple `ScriptedEvent` system that can:
- Move camera to position over N seconds
- Move NPC to position
- Play dialogue
- Set flag on completion

This enables "discovery moments" and "arrival cinematics" without full cutscene complexity.

### Deferred: Everything Else

The 188 quests defined are enough content for a full game. The problem isn't quantity - it's verifying what's actually playable.

---

## Paths Rejected

1. **"Add more quests first"** - Cast aside because: quantity without verification is technical debt
2. **"Build full cutscene system"** - Cast aside because: basic scripted events serve 80% of needs at 20% complexity
3. **"Procedural quest generation"** - Cast aside because: hand-crafted content quality is a strength, don't dilute it

---

## The Work That Follows

Should you accept this decree:

1. **Create quest validation spreadsheet** - Every quest, its NPCs, its locations, its status
2. **Playtest Tharin chain end-to-end** - Document every break
3. **Identify "demo critical path"** - What 10-15 quests form the core experience?
4. **Design basic ScriptedEvent class** - Camera, NPC movement, dialogue trigger
5. **Implement one scripted intro** - Player waking at Elder Moor

---

## ⛧ SPEAK YOUR WILL, SUMMONER ⛧

- [ ] **"So it shall be."** - Accept the decree, begin validation
- [ ] **"Show me the critical path."** - Map out which quests matter for demo
- [ ] **"Design the scripted event system."** - Spec out the ScriptedEvent class
- [ ] **"I want to verify the Tharin chain now."** - Hands-on playtest
- [ ] **"The Council has failed me."** - Reject all, speak new direction

