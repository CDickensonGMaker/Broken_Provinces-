# Game Designer Analysis: Dynamic Multi-Path Faction Quests
**War Room Audit — Broken Provinces (smaller-scope release)**
**Date:** 2026-07-08
**Scope:** Full inventory of `data/quests/`, wired-vs-dead audit of `quest_manager.gd` / `faction_manager.gd` / dialogue pipeline, gap analysis vs the bandit-example vision, and flagship quest recommendations.

---

## 1. Faction Quest Inventory

**Totals:** 223 quest JSONs shippable (excluding 15 in `_future/`). 39 contain choice data (`choice_consequences` or `choice_paths`). **Only ~3 quests have a functional runtime choice today** (the temple devotion choices, which work via dialogue `set_flag`, not the choice system).

| Faction / Bucket | Quest Count | Has Choice Data (JSON) | Choice Actually Works at Runtime | Notes |
|---|---|---|---|---|
| Adventurers Guild (`guild/adventurers/` + 6 legacy `guild_*`) | 20 | 5 (adv 04, 08, 09, 11; guild_contract_troll) | 0 | All linear kill/reach/talk chains. Choice data is dormant. |
| Thieves Guild (`guild/thieves/` + 5 legacy `thieves_guild_*`) | 19 | 7 (5 legacy w/ choice_consequences; thieves_08 w/ choice_paths) | 0 | **thieves_08_rival_gang is likely un-completable** — see §2.7. Best-designed branching content in the game, all dead data. |
| Iron Company (`guild/mercenaries/`) | 14 | 0 | 0 | Betrayal/defection *written into descriptions* (merc 08–10) but zero branching structure. |
| Arcane Circle (`guild/mages/` + 9 legacy `chains/wizard_*`) | 23 | 1 (wizard_stolen_pages) | 0 | Pure linear. Heavy flag usage but flags only gate progression, not branches. |
| The Keepers (`keepers_*`) | 6 | 4 (artifact, cult_trail, infiltration, confrontation) | 0 | keepers_confrontation has a **4-outcome ending** authored in choice_consequences (seal / partial / release Hollow King / spare Malachai) — completely unwired. |
| Church of Chronos (`temple/chronos/` + legacy) | 15 | 4 | 1 (devotion choice, via dialogue set_flag) | Devotion path gating works via `flag_prerequisites`/`forbidden_flags` — this is the one *working* branch pattern. |
| Church of Gaela | 16 | 4 | 1 (devotion) | Same pattern. |
| Church of Morthane | 14 | 5 | 1 (devotion) | Same pattern. |
| **Bandits** | **0** | — | — | **No bandit faction resource exists** (`data/factions/` has 23 factions; bandits absent). No joinable bandit path anywhere. |
| Main quest / story (tharins_*, the_letter, etc.) | 6 | 0 | 0 | Linear tutorial-ish chain. |
| Bounties (`bounties/`) | 14 | 0 | 0 | Single-objective kill/deliver, cooldown-based. Fine as-is. |
| Generic chains (`chains/` rescue/theft/etc., 14 chains x 3) | 42 | 0 | 0 | Filler content, rep-tagged to common_folk / merchants_guild / human_empire / temple_of_three / etc. |
| NPC side quests (root dir) | ~34 | ~9 (fish_fraud, merchant_protection, miners_in_peril, lost_apprentice, lost_woodsman, tenger_diplomacy, whalers_debt, sailors_debt, noble_soulstone_request) | 0 | fish_fraud and merchant_protection have authored betrayal branches (dormant). |

**Headline:** the content team has been *designing* multi-path quests for a year (39 of them) against a consequence API that nothing invokes. The design intent is already in the data. The wiring is the gap, not the content.

---

## 2. Wired vs Dead Feature Matrix

Audited: `scripts/systems/quests/quest_manager.gd` (2,577 ln), `faction_manager.gd` (750 ln), `dialogue_manager.gd`, `dialogue_data.gd`, `dialogue_loader.gd`, `scripts/ui/humanoid_dialogue.gd`.

| Feature | Engine Status | Content Status | Verdict |
|---|---|---|---|
| `choice_consequences` JSON parsing | WIRED — parsed (qm:614–616), saved/loaded (qm:2460, 2503) | 37 quests author it | **Parsed then never fired** |
| `QuestManager.apply_choice_consequence()` (qm:1625) | Function exists, executes flags/rep/follower/spawn | **ZERO callers in entire project** (only refs: quest_manager itself, CLAUDE.md, GDD) | **DEAD CODE** — the single biggest disconnect |
| `COMPLETE_QUEST_OBJECTIVE` dialogue action | **FULLY WIRED** — enum (dialogue_data:54), loader (`"complete_quest_objective"`, loader:172), executor (`dialogue_manager:630→916`, sets `completion_method="dialogue"`) | **ZERO dialogue JSONs use it** | CLAUDE.md is stale — this "missing Phase 2 item" already exists. Pure content problem. |
| BETRAYED completion state | WIRED — but only via temptation path: sell/equip quest item → `fail_quest("temptation")` → BETRAYED + extra −25 rep + `betrayed_<faction>` flag (qm:1567–1604) | No quest can reach BETRAYED through a dialogue choice | **Half-wired** — no narrative betrayal trigger |
| FAILED state | WIRED — triggers: objective timeout, escort death, temptation only | No content-authored failure conditions | Works but underused |
| Daily faction penalties | WIRED — `add_daily_penalty`/`clear_daily_penalty`/day-tick processing (fm:154–229, hooked at fm:102) | **One caller in the game:** `soulstone_economy.gd:514` (soulstone debt) | Wired, 95% unused — this is the ready-made engine for "ongoing bandit-boss consequences" |
| `follower` reward | WIRED — sets `follower_available:` flag + `follower_unlocked:` world flag + signal (qm:1609–1616); FollowerManager exists | 2 quests use it (lost_apprentice, thieves_guild_rival) | Works (flag-level); MAX_FOLLOWERS=1 |
| `soulstone` reward | WIRED (add_item, qm:1476–1480) | 1 quest (noble_soulstone_request) | OK |
| `unlock_area` reward | WIRED (sets world flag, qm:1483+) | Rare | OK |
| `deliver_soulstone` / `solve_puzzle` / `recruit_follower` / `wave_defense` / `escort` / `duel_win` objective types | WIRED with dedicated handlers (qm:1238–1405; duel_manager:405) | Used sparsely | OK |
| Skill checks in dialogue (SKILL_CHECK action + success/failure nodes + DiceManager) | WIRED | Used only in old `.tres` dialogues (guard_generic, merchant_haggle...). **Zero of the 31 JSON quest-giver dialogues use a skill check.** | Engine ready; content never adopted it |
| `flag_prerequisites` / `forbidden_flags` on quests | WIRED (qm:545–554, 661–676) | Used well by temple devotion paths | **The one fully-working branch mechanism** |
| Humanoid FIGHT/BRIBE/NEGOTIATE/INTIMIDATE (`humanoid_dialogue.gd`) | Exists | Enabled on only 2 enemies (bounty_hunter, ratfang_snotcheeze); **no QuestManager hook whatsoever** — a successful bribe/intimidation cannot progress any quest | **Orphaned system** — exactly the mechanic the bandit example needs |
| `choice_paths` / objective `type: "choice"` (thieves_08) | **NO parser support** — quest_manager never reads `choice_paths`; no handler for type "choice" | 1 quest | **DEAD + BUG**: thieves_08's `obj_deal_with_rivals` can never complete → the thieves questline soft-locks at rank 2 unless something manually calls the objective |
| OR-objectives ("kill OR intimidate") | **MISSING** | — | Confirmed gap |
| Pre-completion / world-state checks | **MISSING** (no WorldState autoload; FlagManager exists as substrate) | — | Confirmed gap |
| Bandit faction / joinable enemy faction | **MISSING** — `join_faction()` is wired (fm:365) but there is no `bandits.tres` | — | Confirmed gap |

---

## 3. Gap Analysis vs the Bandit Example (kill / bribe / join / usurp)

What each canonical path needs, what exists, and effort (1 dev-day = focused day incl. test):

### Path 1 — Kill the bandits
Works today. Kill objectives + rep rewards are the core loop. **Effort: 0.**

### Path 2 — Bribe/talk them into leaving
- Needs: bandit boss as a dialogue-capable NPC; a persuade/bribe skill-check choice; the choice completing a quest objective.
- Have: `SKILL_CHECK` action w/ branch nodes, `TAKE_GOLD`, `COMPLETE_QUEST_OBJECTIVE` — **all wired**. `allows_dialogue` on enemies exists.
- Missing: nothing engine-side if the boss is authored as a quest-giver-style NPC with a dialogue JSON. If you want it through the FIGHT/BRIBE/NEGOTIATE combat popup instead, add one QuestManager hook on successful outcome.
- **Effort: 0 (dialogue-NPC route) or 1 day (hook humanoid_dialogue → `update_progress("pacified", group_id)`).**

### Path 3 — Join the bandits / attack the town
- Needs: `bandits.tres` faction (hostile default, hidden until joined), `join_faction("bandits")` via dialogue action or flag, a bandit-side quest chain, town-rep nuking, guards-hostile handling via existing crime/rep systems.
- Have: `join_faction()`, cascading rep, `MODIFY_REPUTATION`, `START_QUEST` dialogue actions all wired. `forbidden_flags` cleanly locks out the town-side quest line once `joined_bandits` is set (proven pattern: devotion choices).
- Missing: the faction resource, a `JOIN_FACTION` dialogue action (or just do it via SET_FLAG + a listener), attack-the-town content.
- **Effort: 1–2 days engine (faction resource + join action + hostility check), 2–4 days content (bandit-side chain of 2–3 quests).**

### Path 4 — Kill the leader, take over the gang (minions, ongoing effects)
- Needs: usurp trigger (kill boss then talk to lieutenant), "gang boss" world flag, minions, ongoing income/consequences.
- Have: kill tracking; follower system (cap 1); `daily_penalties` engine is a ready-made **daily ticker** that can be generalized to daily *income* + rep drain; `betrayed_<faction>` flag pattern.
- Missing: multi-minion support (FollowerManager MAX_FOLLOWERS=1), ongoing-effects framing, NPC reactions to boss status.
- **Effort (full vision): 1.5–2 weeks.**
- **Effort (recommended "lite" cut): 2–3 days** — `bandit_boss` flag; 1 lieutenant follower via existing reward; daily gold delivered via a generalized daily-tick (mirror `_process_daily_penalties`); guards/town rep penalty via existing daily_penalty; dialogue reactions gated on the flag. Ship the fantasy, not the simulation.

### Path 5 — Pre-completion ("I already killed them")
- Needs: world-state check when quest is offered.
- Have: FlagManager + kill events. Missing: a lightweight `WorldState` (or just conventions on FlagManager: `cleared:<camp_id>` set by the camp's spawner when all its enemies die) + a `pre_completed_if_flags` field checked in `start_quest` that auto-completes matching objectives and jumps to turn-in.
- **Effort: 2–3 days** (spawner group death detection + quest field + auto-complete pass). Do NOT build a general world-sim; flags are enough for this release.

### Cross-cutting: OR-objectives
- The journal/completion model assumes AND. Minimal design: `objective_groups: [{"id":"resolve","any_of":["kill_all","bribe_boss","join_gang"]}]` — quest completes a group when any member completes; journal renders group as "Deal with the bandits (choose your approach)" with sub-lines.
- **Effort: 3–4 days** (parser + completion logic + journal UI + save/load). This is the single most valuable engine item; without it every multi-path quest shows misleading "incomplete" objectives.

### Priority wiring order (total ≈ 2 weeks engine for everything above at "lite" scope)
1. **1 day:** New dialogue ActionType `APPLY_CHOICE_CONSEQUENCE` → `QuestManager.apply_choice_consequence(quest_id, choice_id)`. **Instantly activates dormant data in 37 quests.**
2. **0 days:** Start using `complete_quest_objective` in dialogue JSONs (already wired).
3. **3–4 days:** OR-objective groups.
4. **2–3 days:** Pre-completion via flags.
5. **1–2 days:** Bandits faction + join.
6. **2–3 days:** Boss-lite ongoing effects (daily ticker generalization).
7. **1 day:** Fix thieves_08_rival_gang (convert `choice_paths` to the OR-group format or dialogue-driven objectives) — currently a **soft-lock bug**.

---

## 4. The "Dynamic Quest" Template (works with CURRENT systems + item 1 above)

The proven working stack is: **dialogue skill checks + flags + choice_consequences + rep + `complete_quest_objective` + `forbidden_flags`**. Canonical pattern:

**Quest JSON** (`data/quests/...`):
```json
{
  "id": "millbrook_bandit_threat",
  "faction": "millbrook",
  "objectives": [
    {"id": "find_camp", "type": "reach", "target": "millbrook_bandit_camp"},
    {"id": "resolve_threat", "type": "talk", "target": "bandit_boss_grath",
     "description": "Deal with the bandits — by blade, coin, or word"},
    {"id": "kill_bandits", "type": "kill", "target": "human_bandit",
     "required_count": 6, "is_optional": true},
    {"id": "report", "type": "talk", "target": "elder_maren_millbrook"}
  ],
  "rewards": {"gold": 150, "xp": 400,
    "faction_reputation": {"millbrook": 25}},
  "choice_consequences": {
    "killed_all":   {"flags_to_set": ["millbrook_bandits_dead"],
                     "reputation_changes": {"millbrook": 15}},
    "bribed_away":  {"flags_to_set": ["millbrook_bandits_bribed"],
                     "reputation_changes": {"millbrook": 5}},
    "joined_gang":  {"flags_to_set": ["joined_bandits", "betrayed_millbrook"],
                     "reputation_changes": {"millbrook": -60}},
    "became_boss":  {"flags_to_set": ["bandit_boss_millbrook"],
                     "unlock_follower": "bandit_lieutenant_kess"}
  }
}
```
Until OR-groups land: make `resolve_threat` the single mandatory "hub" objective completed from the boss's dialogue (or auto-completed when the kill path finishes via a spawner hook), and mark path-specific objectives `is_optional`. The journal reads honestly, and every path funnels through one completion point.

**Boss dialogue JSON** (`data/dialogue/bandit_boss_grath.json`) — choices:
- *Attack* → ends dialogue, camp hostile (kill path; last kill completes `resolve_threat` via camp script or dialogue on lieutenant's surrender).
- *"Leave, and I'll pay you"* → condition `HAS_GOLD 200`; actions: `take_gold`, `complete_quest_objective millbrook_bandit_threat:resolve_threat`, `apply_choice_consequence:bribed_away`.
- *Persuade/Intimidate* → `skill_check` action (DC by Persuasion/Might) with `success_node`/`failure_node`; success runs same completion, failure turns camp hostile.
- *"I want in"* → actions: `set_flag joined_bandits`, `modify_reputation millbrook -60`, `start_quest bandits_01_raid_millbrook`; town quest fails/locks via `forbidden_flags: ["joined_bandits"]` on its turn-in.
- *(after boss dead, on lieutenant)* *"I'm in charge now"* → `apply_choice_consequence:became_boss`.

This exact structure needs **zero new engine code except the 1-day `apply_choice_consequence` action**, and 80% of it works today.

---

## 5. Flagship Multi-Path Quests per Faction (content bar for the release)

Rule: 2–3 flagships per major faction, each with ≥3 genuinely different resolutions and at least one consequence that a later quest checks. Everything else stays honest linear filler.

| Faction | Flagships | Paths (build on existing dormant data) |
|---|---|---|
| **Adventurers Guild** | **adventurers_04_bandit_contract** (make THE canonical bandit quest — kill / bribe / join / usurp); adventurers_09_rival_guild (sabotage / expose / defect); adventurers_11_guild_politics (back either faction leader) | 04 already has stealth/assault choice_consequences authored; extend to the 4-path template above |
| **Thieves Guild** | **thieves_08_rival_gang** (fix + wire its 3 authored paths: eliminate / sabotage-steal / negotiate truce); thieves_05_blackmail (deliver / warn the victim / keep the leverage → BETRAYED); thieves_12_guild_traitor (expose / join the traitor / blackmail both) | 08's design doc is already in the JSON — best ROI in the game, and fixing it removes a questline soft-lock |
| **Iron Company** | mercenary_09_betrayal (stay loyal / defect to Black Serpents); mercenary_10_noble_war (choose which noble wins — town-visible outcome) | Betrayal is already in the fiction; give it structure + `betrayed_iron_company` flag |
| **Arcane Circle** | mage_05_rogue_mage (kill / capture / let flee with her research); mage_10_forbidden_tome (deliver / destroy / keep it → BETRAYED + daily penalty) | Tome-keeping is the perfect showcase for the temptation→BETRAYED system that already works |
| **The Keepers** | **keepers_confrontation** (wire its existing 4 endings) + keepers_infiltration (stealth / assault / turn double-agent) | The 4-outcome ending is fully authored in choice_consequences today |
| **Temples (3 gods)** | Keep devotion choices as-is (they work); add one flagship per god where devotee flag changes the resolution options (e.g., morthane_04: destroy the necromancer / grant him the rite of rebirth) | Devotion flags (`chronos_devotee` etc.) already gate content — reuse |
| **Bandits (NEW)** | bandits_01_raid_millbrook (the join-path payoff) + bandits_02_boss_of_the_hills (usurp payoff w/ lite ongoing income) | Requires `bandits.tres` + 2 quests; this is the release's marquee "real consequences" story |

**Content budget:** ~16 flagship quests, of which **10 already exist and carry dormant branch data** — the work is wiring + dialogue authoring, not new quest design. Estimated content effort: 1–2 days per flagship after engine items 1–4 land.

### What is sacrificed (named, per Council law)
- Full minion-army / gang-management sim → cut to boss-lite (flag + 1 follower + daily gold/rep ticker).
- General WorldState simulation → cut to flag conventions on FlagManager.
- Branch depth in the other ~200 quests → they stay linear; flagships carry the pillar.
- The 42 generic chains and 14 bounties get no choices — correct call; they are pacing filler.

### Bugs/stale docs found during audit
1. **thieves_08_rival_gang** objective `obj_deal_with_rivals` (type "choice") has no completion path → thieves questline soft-locks at rank 2.
2. CLAUDE.md states `COMPLETE_QUEST_OBJECTIVE` is missing — it is fully implemented (dialogue_data.gd:54, dialogue_loader.gd:172, dialogue_manager.gd:630/916). Update the doc.
3. `apply_choice_consequence()` (quest_manager.gd:1625) has zero callers — 37 quests' consequence data is inert.
4. No `bandits.tres` in `data/factions/` despite bandit enemies being faction-tagged in the enemy-creator spec.
5. Humanoid FIGHT/BRIBE/NEGOTIATE/INTIMIDATE has no quest hooks and is enabled on only 2 enemies.
