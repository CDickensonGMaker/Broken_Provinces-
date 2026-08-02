# Wave B dispositions — what is done, and what is still Caleb's

**Rewritten 8/1 (late).** The original version of this file held ~70 NPC ids,
~105 item refs and 43 faction refs that no file in the repo could settle. Caleb
authorised invention within canon, so most of it has been executed and moved to
`docs/audits/invention_manifest.md`, which is the receipt — every ruling and
every invented name is listed there and can be pulled without reading a diff.

**Validator: 0 errors.** Everything remaining is a *warning*, and every warning
is on this page with the question that blocks it.

| Category | Was | Now |
|---|---|---|
| Errors | 237 | **0** |
| Warnings | 276 | 228 |
| QUEST_FACTION | 43 warnings | 0 |
| QUEST_NPC | 131 errors | 0 errors, 19 warnings (all LORE_ONLY, listed below) |
| QUEST_ITEM | 108 errors | 0 errors, 59 warnings (collect targets, listed below) |
| NPC ids in the world | 149 | 206 |
| Item ids in the world | 243 | 360 |

---

## 1. Done — no longer needs you

* **Factions (43 refs).** Eight created: `merchant_guild`, `common_folk`,
  `nobility`, `hunters_guild`, `scholars_guild`, `shadowed_hand_cult`,
  `aberdeen`, `larton`. `merchants_guild` repointed to `merchant_guild`.
* **Generic role NPCs (33).** Thirty named residents spawned, nine ids
  repointed to people who already existed, two ids split because they carried
  more than one person. Every ruling is in the invention manifest.
* **Lore-bound NPCs (19 of 30).** Nineteen characters placed, including both
  noble houses, the necromancer, the troll, the two charlatans, the High
  Chronist and Khan Toghrul.
* **The Aldric collision.** Seven things were called Aldric. The missing king
  keeps the name; everybody else gave it up, including the random name pools, so
  no procedurally-named villager can be called Aldric either.
* **Hostages (7).** All placed on grey-box marks in the rooms their quests mean.
* **Items (117).** Every reward and objective id that was an error now exists,
  with stats derived from a named donor item.

---

## 2. Blocked on Caleb — a decision no file can supply

### 2a. The seven LORE_ONLY ids (19 warnings)

These are on `tools/validate_content.gd`'s `LORE_ONLY_IDS` list, each with the
blocking question in the code beside it. They report as warnings so the list
stays visible and cannot rot.

| id | refs | The question that blocks it |
|---|---|---|
| `king_aldric` | 3 | **The bible's first `[OPEN — deliberately]`:** does this game reach the king's cave at all? Until that is answered he must not be standing in a room. No proxy was built either — no statue, no portrait, no decree — because putting his face on a wall is itself a ruling about how present he is in Act I |
| `secret_society_contact` | 7 | Act II, inside the capital. The society has no name and it touches the elf-claimant plot, which the bible places as Act II's main side quest |
| `capital_informant` | 1 | Same gate |
| `elven_elder_witness` | 1 | **Bible `[OPEN]`:** where do the elven lands sit? And **`[OPEN]`:** what did the king do for the elves? This character exists to answer the second one |
| `elven_guide` | 1 | Same two `[OPEN]`s — he is the one who knows the path to the Chamber |
| `village_elder_east_hollow` | 4 | East Hollow's grid cell points at `dusty_hollow.tscn`, which is the **destroyed** hamlet, overrun by Tengers. `tenger_diplomacy` has its elder asking you to negotiate with Tengers who are still only *approaching*. One of the two is canon. Either East Hollow fell and the quest retires, or Dusty Hollow is a different place and East Hollow needs building |
| `garrison_commander` | 2 | `southern_outpost` has no scene at all |

### 2b. Level design — the Crossroads has no buildings

Five quests send the player to the Crossroads to meet somebody, and name a
**bridge**, an **inn** and a **junction**. The Crossroads on the world grid is
`cultist_ruins_corner.tscn` — a cultist-defiled ruined intersection with none of
those things.

Gurm the troll, Tomas the informant, Valdris, Captain Kolt and Commander
Brackmoor now stand on grey-box marks in that scene, so their quests are
walkable today. **Your call:** does the Crossroads get a wayhouse and a bridge,
or do those five quests move somewhere that already exists?

Same shape, smaller: **Thornfield has no Temple of Time.** The High Chronist
keeps a shrine-stone and a water clock under an awning and says so out loud. If
Thornfield should have a temple, that is a building.

### 2c. Level design — the hostage rooms

All seven hostages are placed but nothing is *around* them: no cage, no altar
stone, no cell, no ritual frame, no cut ropes. The list of what each room wants
is in `art_replacement_manifest.md`.

### 2d. Quest design — the heist loot abstractions (about 10 warnings)

`vault_treasures`, `vault_gold`, `valuable_goods`, `ashford_artifacts`,
`harwick_valuables`, `stolen_jewelry`, `debt_payment`, `brennan_debt_gold`,
`garrett_debt`. These are **piles of money**, not objects. Cleanest is a gold
reward, or the `stolen_goods` stack that already exists — but that is a per-heist
quest-design choice about what the player is actually carrying out of the
building, so nothing was invented.

### 2e. Lore relics that touch bible `[OPEN]`s (about 8 warnings)

`sacred_hourglass`, `paradox_stone`, `paradox_talisman`, `chronos_sealing_stone`,
`soulbound_phylactery`, `seed_of_life`, `ancient_lifeseed`, `blade_of_legends`.
Named relics of the Three Gods and the Keepers. Each is a piece of world story
rather than a stat block.

### 2f. Quest-object collect targets (about 40 warnings)

`traitor_evidence`, `betrayal_evidence`, `witch_evidence`, `informant_evidence`,
`guild_ledger_evidence`, `cult_documents`, `necromancer_journal`,
`phylactery_research`, `shadow_circle_research`, `harwick_ledger`,
`grimoire_pages_stolen`, `helvants_master_grimoire`, `masquerade_invitation`,
`ashford_gala_invitation`, `heist_supplies`, `tenger_battle_plans`,
`elven_treaty`, the three `*_sand` samples, and friends.

These are all "a piece of paper that proves the thing" — cheap to create, but
each one is a *quest author's* decision about what the evidence actually says
and whether it can be faked, sold or destroyed. They are warnings, not errors,
so they do not block anything, and creating 40 flavourless notes would be exactly
the junk the item philosophy forbids.

### 2g. Enemy stats (was 76 warnings, now about 41)

**Filed wholesale, and about half of it was not a balance question at all.**
Task 52 (8/1) read all 74 QUEST_ENEMY warnings against the 64 ids in
`data/enemies/` and found 33 that were typos and near-misses against enemies
that already exist, not missing stat blocks. Those are repointed:
`skeleton`→`skeleton_warrior`, `dark_cultist`/`cult_defender`→`cultist`,
`ghost_captain`→`ghost_pirate_captain`, `cave_spider_queen`→`spider_queen`,
`bandit`/`bandit_guard`/`bandit_defender`→`human_bandit`,
`bandit_elite`→`bandit_captain`, `bandit_commander`→`bandit_leader`,
`goblin_warrior`→`goblin_soldier`, `goblin_shaman`→`goblin_mage`,
`goblin_scout`→`goblin_archer`, `bridge_troll`→`troll`,
`malachai_the_profane`→`malachai_profane`, `the_timeless_one`→`timeless_one`,
`undead_lord`→`undead_lord_malthor`, `alpha_wolf`/`alpha_dire_wolf`→`dire_wolf`,
`black_wolf_mercenary`/`rival_heavy_infantry`/`deserter_mercenary`→`rival_mercenary`,
`temporal_rift_guardian`/`corrupted_temporal_guardian`→`temporal_guardian`,
`planar_horror`→`planar_entity`, `shadow_circle_mage`→`shadow_mage`,
`ancient_treant`→`tree_ent`.

**What is still yours.** Roughly 41 ids genuinely need a stat block —
`goblin_king`, `arena_champion_tier1`, `lich_aspirant_valdris`,
`rival_commander`, `orc_warrior`, `orc_warchief`, `ice_elemental`,
`stone_guardian`, `arcane_guardian`, `necromancer_valdris`,
`death_knight_commander`, `keeper_assassin`, `thornfield_chimera`,
`katrina_steelwind`, `vorn_champion_form`, `hostile_marcus` and friends. Each
needs HP, armour, damage, a level for the loot tier, a faction and a sprite.
Still a balance pass, and `balance-reviewer` should own it.

**Four are an engine gap, not a content gap.** `any_enemy_with_magic`,
`bounty_target`, `contract_enemy` and `bandit_crossroads_group` are wildcards
and groups: they want "any enemy matching a predicate" resolution, which
`on_enemy_killed` cannot express beyond its one hardcoded `enemies` catch-all
and its prefix-category split. Creating four stat blocks would be the wrong
answer. Either extend `on_enemy_killed` with a tag/predicate match or convert
the four objectives to something the engine can already count.

**One audit misdiagnosis, recorded not forced.** The 8/1 audit read
`tomas_informant` as "a `kill` objective targeting an *informant* — that reads
like a `talk` objective mistyped." It is not. `thieves_guild_informant` has a
`talk` objective on Tomas *and* a separate **optional** `kill` objective whose
own description is "Deal with Tomas (kill, bribe, or intimidate)". Tomas is a
real spawned NPC (`cultist_temple.gd:395`), killable by design. What the
objective actually wants is an OR group of kill / bribe / intimidate, which is
the machinery step 21 built — a quest-design job, not a typo fix. The warning
stands because no `tomas_informant` enemy stat block exists for the kill road.

### 2h. Choice branches nobody can reach (74 warnings)

Was 107, then 70 after step 24, now 74 because stage 3 and 5 made two more
quests reachable enough to notice. Twenty-seven quests still carry branch data
no dialogue node fires. The per-quest reasons are tabled in
`docs/audits/invention_manifest.md` under "Tabled — 27 quests". Several of them
unblocked in this pass, because their turn-in NPCs now exist: `sailors_debt`,
`whalers_debt`, `fish_fraud`, `noble_soulstone_request`, `morthane_necromancer`,
`wizard_stolen_pages` and the three `morthane_*` quests whose giver now has a
tree to hang nodes on. That is the cheapest next wave of content work.

### 2i. `variable` — what a repeatable research assignment *is* (1 objective)

`mage_repeatable_research` is the Arcane Circle's post-capstone loop. Its middle
objective is `{"type": "variable", "target": "assignment_variable"}`, with the
note *"Could be: collect reagents, kill magical creatures, explore ruins,
deliver items"*.

Task 46 implemented or converted the other nine unhandled objective types. This
one is not an engine gap: nothing is missing from `QuestManager` that a handler
would supply. The question is a design one — **what does a randomly generated
guild assignment actually consist of, and who generates it?** `BountyManager`
already generates bounties from a region and hands them to `QuestManager`, so
the machinery for "a quest whose objective is chosen at runtime" exists; whether
the Arcane Circle's repeatable is that, a fixed rotation of four hand-written
assignments, or something else is Caleb's call.

Until it is answered, `variable` is named in
`QuestManager.DEFERRED_OBJECTIVE_TYPES` with this reason, and
`tools/check_quest_engine.tscn` **fails if the entry loses its reason, and fails
if the type stops shipping and the excuse is left behind.** The quest itself
stays uncompletable; it is repeatable content behind a capstone that is now
finishable, so it blocks no ladder.

### 2k. What a failed Deception costs (design call)

CLAUDE.md has carried this for months: *"Deception (HIGH RISK/REWARD):
Deception skill checks should have CONSEQUENCES for failure. Higher rewards for
successful deception checks."* Task 56 built the plumbing and stopped exactly
there, because the rest is yours.

**Built:** objectives take a `skill_check: {"skill": "deception", "dc": 14}`,
`QuestInteractable` rolls it through `DiceManager.quest_skill_check`, and
`thieves_07_noble_heist` now carries the deception check its own
`challenge.skill_checks` block authored — DECEPTION's first gameplay consumer
in the project's history. `tools/check_quest_engine.tscn` fails if it loses it.

**Not built, and needs a ruling:** what a *failed* lie does. Today it costs the
attempt and nothing more, deliberately, because the alternative is inventing a
punishment. The plausible answers all have real consequences and none of them
is obviously right:

- the guest raises the alarm (hostility, and the heist goes loud)
- the NPC's disposition drops permanently and the road closes
- the lie is remembered — a flag other NPCs read, so lying has a reputation
- nothing, and Deception is just a second Persuasion with a different name

Until this is answered, the `skill_check` field has no failure branch and
objectives that use it are marked `is_optional` so a bad roll can never strand
a quest. The three remaining `skill_checks` blocks in
`thieves_04`, `thieves_07` and `thieves_10/11` describe scene phases that do
not exist yet — they are level-design notes now, not dead code, because the
mechanism they were waiting for is real.

### 2j. Warnings task 46 deliberately created (9)

Making the guild capstones completable added nine warnings, and all nine are the
validator correctly asking for content that does not exist yet:

- **7 × QUEST_CHOICE.** `thieves_09_informant` (4 branches) and
  `thieves_13_right_hand` (3 ambush sites) now carry real `choice_consequences`
  instead of `choice_paths`, a key the engine has never read. Their `choice`
  objectives could not settle at all before — `apply_choice_consequence` returns
  early when the branch id is not in `choice_consequences`. The branches are
  executable now and nothing calls them, which is exactly what §2h tracks: they
  need a dialogue node. This is the cheapest content work in the file.
- **2 × QUEST_ENEMY.** `rogue_mage_thaddeus` (`mage_05_rogue_mage`) and
  `guild_high_traitor` (`thieves_12_guild_traitor`) are now `kill` objectives
  inside OR groups, so the validator can finally see them. Both need a stat
  block — see §2g.

---

## 3. Eye-check list — what to look at in the running game

Nothing below is a known bug. These are the places where a headless validator
cannot tell you whether the result is any good.

1. **Dalhurst market and guild hall.** Thirteen new residents were added to
   Dalhurst on hardcoded coordinates. Some of them may be standing inside a wall
   or on a roof. Walk the market, the quays, the guild hall and the thieves' den.
2. **Mill Brook.** Eleven new residents in a hamlet that had six. It may now read
   as crowded.
3. **The Crossroads** (`cultist_ruins_corner`). Five characters on grey-box
   marks, in a scene that also spawns cultists. Check they are reachable and not
   immediately in combat.
4. **Khan Toghrul** at the Tenger camp, **Gurm** at the Crossroads and **the
   Drowned Man** in Dalhurst are drawn on the default human townsman sprite. The
   Khan is supposed to be an eight-foot bear-man.
5. **The seven hostages.** Each is a mark on a floor with nothing around it.
6. **The Arcane Circle gear ladder.** Thirteen mage contracts now pay in robes
   and staves. Play three of them in a row and see whether the curve feels like a
   progression or like a shopping list.
7. **The five named uniques.** They barely out-damage Flamebrand on purpose. If
   that reads as an anticlimax, the fix is the number and not the fiction.
8. **The renames.** "Master Edric Vayle", "Severin Vane", "Guildmaster Wulfric",
   "Brother Anselm", "Mayor Kendrick Brennworth", "Talbot Ashe". Any one of them
   can be overruled — they are display strings, and the ids under them are
   name-agnostic.
9. **Faction standing.** Eight new factions start reputations moving that never
   moved before. `nobility` starts at −10 and `shadowed_hand_cult` at −20; check
   nothing tips hostile from a single bounty.
