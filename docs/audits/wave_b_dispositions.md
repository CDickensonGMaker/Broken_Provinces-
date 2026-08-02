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

### The two story questions are STILL OPEN, deliberately

Nothing in the 8/2 ruling pass touched either of these, and nothing should have.
They are listed here at the top so no future agent reads the RULED-AND-BUILT
headings below and concludes the file is finished.

1. **Does the game reach the king's cave at all?** The bible's first
   `[OPEN — deliberately]`. `king_aldric` is still not standing in a room and
   still has no proxy — no statue, no portrait, no decree — because putting his
   face on a wall is itself a ruling about how present he is in Act I. See §2a.
2. **Who is buying the soulstones, and why?** Twelve prose touchpoints across
   twelve unrelated quests add up to somebody quietly acquiring soulstones
   across the province, and **nothing anywhere names, describes or implies who.**
   Deliberately. There is no soulstone mastermind in this repository and none was
   invented. See §2l for the six candidates the world already supports, none of
   them chosen — including "nobody", which is a legitimate answer and the
   cheapest one to keep.

Neither blocks shipping. The soulstone thread costs nothing while it sits
unresolved, which is the point of laying it that way.


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

### 2i. `variable`, and the two repeatables — **RULED-AND-BUILT**

**Ruled: implement `variable` as a simple named-counter objective, or convert
the quest honestly if that fights the engine. It fought the engine, so it was
converted:** `mage_repeatable_research`'s middle objective is a `has_item` on a
real reagent now. A counter API's only callers would have had to be authored in
dialogue data, so it would have shipped as an API with zero consumers — which is
the exact defect this whole pass exists to kill. `DEFERRED_OBJECTIVE_TYPES` is
empty; `variable` was its only entry.

`thieves_repeatable_jobs` had **no top-level `objectives` array at all** — only
six nested `job_types` — so it parsed to a quest with zero objectives and
completed instantly on accept. It has a real three-beat rotating job now, built
from targets in its own `job_types`, which are kept as the authored design they
are. Its `repeatable`/`cooldown_hours` (neither read by the engine) are now
`cooldown_days: 1`, which is.

**Both complete headlessly, and `check_quest_engine.tscn` proves it** by driving
every objective of each through the game's own entry points and asserting
COMPLETED.

**Found on the way, and worth more than the ruling:** `mage_02` through
`mage_13` all had the same defect — each gated on the previous quest's
`on_complete_flags` value through `prerequisites`, which reads *completed quest
ids*. **The entire Arcane Circle ladder was dead from its second rung down.**
All twelve are moved to `flag_prerequisites`.

One thing deliberately left: `mage_repeatable_research` authored no repeat
interval at all, so none was invented. Noted in the file.

### 2i (original text, kept for the reasoning)

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

**CLOSED.** The design question above is still unanswered and still Caleb's to
answer, but it is no longer allowed to hold a quest hostage. `complete_task` is
now `{"type": "has_item", "target": "arcane_essence"}` - the Circle's standing
list asks for one honest, checkable thing, and the quest completes. A named
counter API was the alternative; it was rejected because its only callers would
have to live in dialogue action data, so it would have shipped as another field
with no consumer, which is the exact defect this whole audit exists to kill.
When the generator is designed it re-skins that objective rather than replacing
a dead type.

`variable` is therefore off `QuestManager.DEFERRED_OBJECTIVE_TYPES`, which is
now empty. `tools/check_quest_engine.tscn` **fails if a deferred entry loses its
reason, and fails if a deferred type stops shipping and the excuse is left
behind** - so the list cannot rot in either direction.

The same quest's `prerequisites: ["arcane_circle_magister"]` was a FLAG name in
the completed-quest-id list, so it was never offered at all; it now sits in
`flag_prerequisites`. The identical defect ran through `mage_02` to `mage_13`
- twelve quests, each gating on the previous quest's `on_complete_flags` value
through the wrong list - and is fixed the same way. The Arcane Circle ladder was
dead from its second rung down.

### 2k. What a failed Deception costs — **RULED-AND-BUILT**

**Ruled: a failed Deception check drops the lied-to NPC's disposition and
leaves a `caught_lying_<npc>` mark the conversation system surfaces.** The drop
is **15** — exactly one disposition band, so neutral 50 becomes cool 35 and the
greeting, the response filtering and every `min_disposition` line change
together. One blown lie is felt at once; three make somebody permanently
hostile. The mark rides the conversation flags into the save, that NPC's
greeting opens on the lie from then on, and any `FLAG_SET` condition can read
it. Other skills are untouched: they still cost the attempt and nothing more.

**Where a quest authored something harsher, it is honoured as far as it can be.**
Only one had. `thieves_07` wanted *"identified as thief, bounty placed, quest
failure"* for a lie at the Ashford gala, so its disposition hit is doubled to 30
and its own `thieves_emberlyn_enemy` flag fires. **Quest failure is not
honoured** — the objective is `is_optional` precisely so a bad roll cannot
strand a heist. **The bounty is not honoured either, and that is still yours:**
whether a lie caught at a party is a witnessed crime is a CrimeManager question
and nothing was invented.

**And one thing to fix in a scene, not in code:** `emberlyn_suspicious_guest`
has no `QuestInteractable` anywhere, so the path is wired and unreachable in
play until somebody places one.

### 2k (original text, kept for the reasoning)

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

### 2l. Who is buying the soulstones (quest-quality pass, 8/2)

The quest pass laid Caleb's "larger connection across many quests" as a
**soulstone undercurrent**: twelve small details across twelve unrelated quests
that add up to somebody quietly acquiring soulstones across the province. The
design is written up in `docs/design/quest_web.md`; the touchpoints are prose
only and change no quest data, set no flag and gate nothing.

**What is `[OPEN]` and his alone: who the buyer is, and why.** Nothing anywhere
in the repository names, describes, or implies an identity — not a file, not a
note, not a name-agnostic id. Deliberately, so the payoff can be anything he
wants later. The obvious candidates the world already supports, none of them
chosen:

1. Skarrag's agents buying above ground what the goblins cannot dig out of
   Kazan-Dun.
2. Somebody inside the Arcane Circle — the Circle's own stone-cutter has stopped
   selling to it, which reads either as a rival buyer or as an inside job.
3. The elf claimant's household, funding a claim.
4. Lord Baron Viktor's reach across the water.
5. The missing king, or somebody acting on twenty-year-old instructions from
   him.
6. Nobody — the four-scratch mark means nothing and the player pattern-matched
   on noise. This is a legitimate answer and the cheapest one to keep.

Related and also his: **the bible's `[OPEN]` on what the soulstones actually do
for the goblin king is untouched by this.** The thread was built specifically so
that it neither narrows nor answers that question. Kazan-Dun has no touchpoint
in it for that reason.

He does not need to answer this to ship. The thread costs nothing while it sits
unresolved, which is the point of laying it this way.

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


---

## 3. Batch 4 rulings (8/1, "make a hit feel like a hit")

### 3a. Melee paid armour twice — **RULED-AND-BUILT**

**Ruled: option 3.** Armour mitigates exactly once, and it is charged in
`CombatManager.apply_melee_damage`, where `armor_pierce` can be honoured —
the only version in which that field means anything.

`CombatManager.is_armor_already_applied(target)` is the answer every receiver
now asks before reducing by armour. It holds the *target node* of the hit
being delivered, not a bool, so a `take_damage` that damages somebody else in
turn cannot inherit the exemption. Spells and projectiles do not set it and
still pay armour in `take_damage` — once, on every path. Nine receivers were
charging a second time and were corrected: `EnemyBase`, `PlayerController`,
`EnemySpawner`, `CompanionNPC`, `FollowerNPC`, `GuardNPC`, `GladiatorNPC`,
`JailGuard`, `CursedTotem`.

**Measured**, the same probe as before — 20,000 swings of a 1d6 weapon against
armour 10, attacker with no stat bonuses, crits off:

| | mean damage |
|---|---|
| before (armour charged twice) | **2.0159** |
| after (armour charged once) | **2.6627** |

**+32.1%**, which lands the routed path back on the **2.67** the unrouted live
hitbox was doing before batch 4 — so the routing no longer costs the player
damage, and it brings crits, lifesteal, damage numbers and the Grit/Melee
scaling with it. No other value was tuned.

`tools/check_combat.tscn` asserts armour is charged exactly once, so the
second application cannot come back.

### 3a (original text, kept for the reasoning)

Task 57 routed the player's armed melee through
`CombatManager.apply_melee_damage()`, which is where crits, lifesteal, the
damage number and the HUD signals live. That function was written before
enemies applied their own armour: it reduces by the target's armour value
(honouring `armor_pierce`, which nothing else does) and then
`EnemyBase.take_damage()` reduces by the same armour again. It also multiplies
by `1 + Grit/10 + Melee/20`, which the live hitbox path never did.

**Measured**, 20,000 swings of a 1d6 weapon against armour 10, attacker with no
stat bonuses: unrouted **2.67** average, routed **2.01** — a 25% drop from the
double armour alone. A starting character (Grit 3) roughly breaks even; a
high-Grit, high-Melee character comes out well ahead. Crits are new on top.

No value was retuned in either direction — that was the instruction. The
question for Caleb is which of these is the melee formula:

1. Leave it. Melee scales with Grit and Melee skill for the first time, and
   armour bites twice, so armoured enemies are genuinely hard to cut.
2. Apply armour once (drop the block in `apply_melee_damage`, since the target
   already does it), keeping the stat scaling. Closest to today's damage.
3. Apply armour once **in CombatManager** and stop `EnemyBase.take_damage()`
   from doing it — the only version where `armor_pierce` means anything.

### 3g. Combat identity — **RULED by Caleb, 8/2**

**The combat identity is Skyrim / Daggerfall, not Souls.** Block, swing timing,
armour and movement. **No player dodge and no lock-on.**

This ruling arrived after both were built, and it removed both:

* **Lock-on is cancelled.** The `V` binding, the acquisition and break rules,
  `CameraPivot.bias_toward()` and the compass marker are all deleted. `V` is
  unbound.
* **The player's dodge is removed.** The roll and the sidestep, their i-frames,
  their 20-stamina cost and the `dodge` binding are gone. It was in the game
  before either audit and it was the Souls half of the loop.

**Stamina stays** — sprint and block spend it. **Enemy dodge behaviour stays**;
this was about the player's verb.

**The post-hit mercy window (3f) is now the only source of player i-frames.**
It used to share that job with the roll; `hit_iframe_duration` is doing all of
it alone, and its 0.35 s is still a placeholder that has never been played.

**One thing this ruling orphaned, and it needs you.** `Enums.Skill.DODGE`
survives — Daggerfall has Dodging as a skill and it fits the identity — but the
character sheet and the rest menu both promise *"+3% dodge chance per level.
Reduces incoming damage"* and **nothing has ever computed that.** The roll's
i-frame bonus was its only real consumer, and the roll is gone. So Dodging is
now a skill that does nothing at all. Making it a real passive evasion roll is
new combat math and was not invented here. **Your call:** build the passive, or
retire the skill.

`project.godot` still declares the `dodge` action, because agents do not edit
that file. `GameSettings.RUNTIME_ACTION_REMOVALS` erases it at boot so the key
is genuinely unbound rather than bound to nothing; delete the block in
`project.godot` when convenient and that list can shrink.

`tools/check_combat.tscn` fails if either verb grows back — if `dodge` or
`lock_on` is bound, if the options menu offers to rebind them, if
`PlayerController` declares any of their symbols again, or if `bias_toward`
reappears.

### 3b. Player block — **RULED-AND-BUILT**

**Block.** Hold `Q`. A hit arriving inside a **120° frontal arc** — measured off
where the player is *looking*, because in first person that is the only facing
he can feel — is **halved**, and costs stamina scaled to the incoming damage
(`block_stamina_per_damage`, 1.5 per point). Raising the guard is free; only a
hit that lands on it is paid for, so standing behind a shield forever buys
nothing and holding through a flurry is the decision. When the bar cannot pay,
**the guard breaks with a stagger** and stays down until the key is released —
a player cannot mash back through a break. **No parry in v1:** a timing window
is a separate feature with its own read and its own tuning, and adding it later
disturbs none of this. Player-side only; enemies already block via `EnemyData`.

**HUD:** the existing stamina bar brightens while the guard is up. That is the
whole indicator, and it is the bar that is about to pay.

**Lock-on was built alongside this and then cancelled — see 3g.**

**One thing fought back:** batch 4 deleted `block` from `project.godot`'s
InputMap, and `project.godot` is not to be edited. It is registered at boot
instead by `GameSettings.ensure_runtime_actions()` on `Q` — the same shape
`SaveManager` already uses for quick-save — and is back in
`REBINDABLE_ACTIONS`, so the options menu can rebind it and
`user://settings.cfg` keeps the change.

`tools/check_combat.tscn` covers it: the arc at four angles, the halving, the
stamina spend, the break, and the guard staying broken until the key comes up.

### 3b (original text, kept for the reasoning)

`block` and `lock_on` are bound keys with no implementing code anywhere.
`block`/`block_chance` exist only on `EnemyData` — enemies block the player and
the player cannot block anything. Building either is a combat-design decision
(timing window, stamina cost, damage reduction or full negation; hard lock or
soft lock, break distance, target cycling), not wiring, so nothing was invented.
The bindings are left in place and dead until ruled. `lock_on_target` on the
player and the HUD branch that reads it were deleted per the fossil rule — a
variable nothing assigns is not a feature.

### 3e. What a heavy attack costs (the only number batch 4 invented)

`heavy_attack` (right mouse) is wired now: it is a weapon swing that passes
`is_heavy_attack: true` into `CombatManager.apply_melee_damage`, where a +50%
bonus has sat unused since the function was written. What it should *cost* was
not written anywhere, and an attack that is strictly better than the light one
is not a choice - so `PlayerController.heavy_attack_cooldown_multiplier`
defaults to **2.0** (a heavy swing takes twice as long to recover). That number
is a placeholder, exported and labelled as such. A windup, a stamina cost or a
different swing arc are all more interesting than a longer cooldown; that is
his call.

### 3f. The player's mercy window (task 64)

`take_damage` had no post-hit invulnerability at all - `_set_invulnerable()`
existed and was called only by the dodge roll, which no longer exists (3g), so
this window is the only source of player i-frames now - so two enemies in melee range
could chain the player to death with no counterplay. Batch 4 adds a 0.35s
window (`hit_iframe_duration`, exported), a hit sound, and a screen shake, and
gives `apply_stagger` a shake and a sound so it reads as something rather than
a silent boolean. **0.35s is a placeholder**: it is long enough to break a
two-enemy chain and short enough not to trivialise a crowd, and it has never
been played. Enemies still get a real `AIState.STAGGERED` and the player still
gets `can_attack = false`; a real hit animation is art, not wiring.

### 3c. Death with no save (task 66) — respawn is a design call

The death screen offers Load Autosave, Load Save, New Game and Main Menu. With
no save on disk the two Load buttons bounce back to the death screen; batch 4
disables them and says why. Whether death should offer a real respawn or
checkpoint at all is unruled and unbuilt.

### 3d. `AmbientSoundscape` is wired to nothing

The class is instantiated by no script, scene or data file. Zone ambience is
played by `AudioManager.play_zone_ambiance()` instead. Its biome table is now
collapsed to the one bed that exists (caves/ruins); the other 36 loops are in
the art manifest. Wire it to the wilderness generator, or delete it in favour
of `play_zone_ambiance` — both are defensible and neither buys anything until
biome ambience assets exist.

---

## Living World v1 — what needs a ruling (8/2)

Five things the schedule pass found or reached and did not decide. None of them
blocks the feature; all of them are yours.

### LW-1. The ambient crowd is the same people every time — **RULED-AND-BUILT**

**Ruled: seed the ambient population from `world_seed`, deterministic per NPC
slot.** `CivilianNPC.make_slot_rng(world_seed, zone_id, slot)` gives one
generator per slot, and the level script draws the position from it and hands
the same generator to the spawner — so slot 7 of Dalhurst is one person, one
spot, one archetype for a given world, and somebody else in a different world.
Every `randf()` in the ambient path now goes through it: type rolls, sprite
variants, tints, dwarf names. Corpse loot and hostile barks were deliberately
left on the global generator, because they are not identity.

**A second bug fell out of testing, and it was the one that actually mattered.**
Seeding the ambient draw was not enough. The ambient slot indexes into what is
*left* of the zone's name pool, and every hand-placed NPC ahead of it takes a
name first — most then throw it away and set their own — and those draws were
unseeded. So the pool shifted under the ambient slots and the same seed still
produced different names. Naming within a zone is now a fixed sequence.

`tools/check_living_world.tscn` boots Dalhurst and Elder Moor three times — the
same seed twice, then a different seed — and fails if the crowd is not identical
across the first two and different in the third.

### LW-1 (original text, kept for the reasoning)

`spawn_random` / `spawn_gendered_random` / `spawn_worker_random` draw a
townsperson's name from `WorldLexicon`'s pool and their position from `randf()`.
Booting Dalhurst twice gives 50 of its 107 NPCs a different `npc_id` **and** a
different spot; Elder Moor 20 of 34, Thornfield 6 of 24. So no authored record
can name them, and none does — they get a schedule at runtime from the trade
their spawner declares.

That is fine for schedules. It is not fine for anything that needs to remember
a person: a disposition earned with Mabel is spent on a stranger next session,
and no quest can ever name one of them. **The question is whether the ambient
population should be seeded off `world_seed`** so a town's people are the same
people every time you come back. That is a small change and a real design call
about what kind of world this is.

### LW-2. Dalhurst is wider than Dalhurst says it is

`WorldGrid.LOCATIONS` declares Dalhurst's `scene_size` as 160x172. The Seabreeze
Armory stands at local x=86, against a declared half-width of 80, and eight
other stations sit outside the same box. The station bounds rule carries a 20%
tolerance so this passes rather than failing nine NPCs who are demonstrably fine
where they are. Either the declared size is wrong or the town sprawls past its
cell; **it is a level-design call**, and the streaming ring will have an opinion
about it before the schedules do.

### LW-3. Three duplicate npc_ids — **RULED-AND-BUILT (deduped)**

`worried_merchant_dalhurst`, `wizard_dalhurst` and `aldric_vane` were each
spawned twice, once from `dalhurst.tscn` and once from `dalhurst.gd`, so
whichever the engine found first was the one quest turn-ins and dispositions
counted and the other was a ghost. **The script body survives in all three
cases** — it carries the ruled post-rename names, the factions, the profiles,
and it is the body each schedule record was measured against. The scene nodes
are deleted, not kept as second people: each was a bare instance offering the
*same* quest under the *same* id, so keeping it would have meant a second mute
quest giver rather than a second character.

What the scene had and the script lacked was moved onto the survivor: Severin
Vane gains his `dialogue_data`, and his `faction_id` is corrected from
`"keepers"` — which names no faction file at all — to `"the_keepers"`.

### LW-3 (original text, kept for the reasoning)

`worried_merchant_dalhurst`, `wizard_dalhurst` and `aldric_vane` are each
spawned twice, at different positions, with different display names — "Worried
Merchant" and a second Worried Merchant; "Maelorn the Wizard" and "Master Edric
Vayle"; "Aldric Vane" and "Severin Vane". Quest turn-ins and dispositions key on
the id, so whichever the engine finds first is the one that counts. The schedule
table keeps the first and ignores the second. **Which of each pair is the real
one, and what is the other one's id?**

### LW-4. The Drowned Man keeps a ghost's hours — **RULED-AND-BUILT**

New archetype `revenant`: **present 20:00–03:00**, absent the rest of the day
behind an `interior: true` home station, which is how `NPCScheduler` removes an
NPC from the world. He works his harbour post 20:00–22:00, stands about the
dockside until midnight, and works again until three.

**This collided with a gate, and the gate was the one that was wrong.**
`validate_content` failed him as an *error*, because every quest talk target
must be awake and outdoors 09:00–17:00 — and `morthane_restless_soul`'s own
objective text reads *"Locate the restless spirit in Dalhurst **at night**."*
The authored design already wanted a nocturnal ghost, and the rule only passed
before because he was wrongly keeping a beggar's hours. Rather than list his id
in the validator, the exemption is data: an archetype may declare
`"nocturnal": true`. `revenant` is the only one that does, and an archetype that
claims it falsely is still caught by the whole-day-coverage rule.

### LW-4 (original text, kept for the reasoning)

`restless_ghost` is a ghost, and the schedule has him standing about the harbour
in daylight like everyone else because there is no archetype for the dead.
Whether a ghost should be visible by day, only by night, or never on a schedule
at all is **a story ruling**, not a scheduling one.

### LW-5. Nobody has been seen doing any of this

Everything above is proved by a headless check counting nodes. Nothing has been
watched. Three present at 03:00 and thirty-three at 13:00 is the right shape;
whether the town *reads* as alive — whether the teleport transitions are
jarring, whether an empty night is atmospheric or just empty — is the eye gate,
and it is entirely outstanding.

---

## FX — Factions, devotion and the lockout web (8/2)

Full evidence, link-by-link verification and the fixes applied are in
`docs/audits/faction_exclusivity_audit.md`. The eight items below are the ones
that need **his ruling** and nothing else moves without them.

### FX-1 / FX-2 / FX-3. Devotion — **RULED-AND-BUILT**

**FX-1 confirmed: the dialogue is canon, and the three READMEs are corrected.**
Each now carries the ruling at the point where it used to claim the opposite,
plus a line telling the next agent not to restore it.

**FX-2 — yes, there is a road back, and it costs.** A renunciation choice sits
at the player's OWN god's priest, gated on that god's devotee flag, written in
that priest's voice. It clears the devotee flag, costs **−50** with that church,
and starts a **seven-day `forsworn_<god>`** daily penalty. While the `forsworn`
flag stands the other two bonds are closed — the three `*_05_devotion_choice`
quests forbid it — and when the penalty expires it clears the flag and they
open. The sentence and the lockout are the same object, so they cannot drift.

Each god takes it differently, which is the whole point of putting it in three
voices rather than one menu:

> **Chronos** — cold inevitability. *"There is no releasing… What you are asking
> me for is not freedom. It is for the record to be corrected."*
>
> **Gaela** — sorrow. *"What will hurt is that in a month you will smell cut hay
> and it will still mean me."*
>
> **Morthane** — acceptance of endings. *"You want an ending. That is the one
> thing I am actually qualified to give you, so let us not pretend it is a
> tragedy. Morthane is the god of things stopping."*

**FX-3 — yes, serving one god costs the others.** Taking the bond costs the
other two churches **−15** each. It fires on the devotee flag being *set*,
watched in FlagManager, so all three doors into devotion — the ritual,
`become_devotee()`, and a raw `set_flag` from data — charge the same price.

`tools/check_faction_loop.tscn` proves the whole transaction per god: the rival
cost, that a non-devotee cannot renounce, the flag clearing, the −50, the
penalty starting, the other two bonds being shut while it runs, the penalty
expiring on its own after seven days, and the bonds reopening.

**One thing this needed that did not exist:** an ongoing effect had no end.
`add_ongoing_effect` now takes `days` (or `expires_on_day`) and
`process_ongoing_effects` retires the effect after the last day it is felt.
Every effect written before this is unaffected — no expiry means forever, which
is what a debt should be.

### FX-1 (original text, kept for the reasoning)

All three priests say devotion is exclusive, in voice, with a written refusal
for a rival's devotee. All three `data/quests/temple/*/README.md` say it is not
("Allow multi-devotion"). The dialogue was taken as canon and the lockout is
now wired — he asked for it directly, and the speeches are older, in voice and
player-facing where the READMEs are agent-generated and bulk-added in one
commit. **Confirm.** If confirmed, the READMEs should be corrected so the next
agent does not undo it.

### FX-2. Can a devotee ever change gods?

Chronos has a `devotee_regret` node; the refusals call the bond "a sacred bond
that cannot be undone". `FlagManager.become_devotee()` would switch it silently
and has zero callers. Permanent, or is there a road back — and at what price?

### FX-3. Should serving one god cost standing with the others?

The three churches are `neutrals` of each other: zero cascade in either
direction. Nothing was invented here because no note anywhere fixes a
magnitude. Exclusion alone, or a reciprocal reputation penalty as well?

### FX-4. `undead` is named as an enemy by six factions and does not exist

It is used everywhere as an enemy *category* (spawners, loot tables, encounter
tables) and there is no `undead.tres`. Create the political faction, or strip
the six references?

### FX-5. Faction relationships are one-way

`merchant_guild` names `thieves_guild` an enemy; the thieves do not name the
merchants. Cascade reads only the source's list, so helping the merchants costs
you with the thieves and robbing for the thieves costs you nothing with the
merchants. True across many pairs. Intended asymmetry, or should they be
reciprocal?

### FX-6. Morthane's priest is two people

`priest_morthane_elder_moor` gives all eleven Morthane quests and is spawned
with `null` dialogue. `priest_morthane_dalhurst` has the dialogue — including
the devotion ritual — and gives no quests. So the Morthane bond can only be
taken in Dalhurst while the chain runs out of Elder Moor. Merge them, or give
the Elder Moor priest the dialogue too?

### FX-7. Authored quest fields nothing reads — **RULED-AND-BUILT** (the four named)

**Partly closed.** `on_complete_flags` (22), `flags_set` (14) and
`rank_required` (14) are wired: the first two union into one
`Quest.on_complete_flags` raised through `FlagManager` by `complete_quest()`,
and `rank_required` gates on `GuildRankManager.get_guild_rank_level(faction)` in
both `is_quest_available()` and `start_quest()`. `flags_required` has zero
remaining uses in `data/`. `check_quest_engine.tscn` asserts all three.

Still unread, each written in two or more quest files with zero consumers in
`scripts/`: `unlocks_quests` (6), `xp_bonus`/`gold_bonus`/`reward_bonus` (12),
`is_tutorial` (3), `is_repeatable` (3), `detection_consequences` (3),
`optional_objectives`/`choice_paths`/`time_pressure`/`phases` (2 each). Wire or
delete, per field. Related: the `moral_choice` blocks in `thieves_02`, `_04`,
`_05` and `_10` are decorative — two siblings were migrated to real
`choice_consequences` and these four were not.

### FX-8 blessings — **RULED-AND-BUILT**

Every priest offered a blessing to any visitor, repeatedly, and **every bless
and pray choice in all three files had `actions: []`.** They are real now, as
timed buffs on the consumables' machinery (`CharacterData.apply_buff`, same
clock, saved, cleared by sleep) via a new `apply_buff` dialogue action — a
second door into the buff system, not a second implementation.

| God | Blessing |
|---|---|
| **Chronos** | +12% movement speed, +15% attack speed |
| **Gaela** | +0.6 HP/sec regeneration, +60 carry weight |
| **Morthane** | +30% damage against the undead, +4 to horror checks |

**Donation: 100 gold** — twice a health potion (50), well under the permanent
blessing consumables (250), unaffordable at level 1 and an easy tithe by
mid-game. **Duration: one game-day** (1440 real seconds; 1 real second is 1 game
minute). **A devotee of that god gets double**, and each priest says why in his
own register — Chronos calls it resonance, Gaela calls it favouritism and does
not apologise, Morthane says the cycle already knows your name.

**Six new buff ids, and every one has a reader**, because a buff id nothing
reads is the same lie one step further in: `move_speed` →
`get_movement_speed_multiplier`, `attack_speed` → the player's attack cooldown,
`hp_regen` → `get_hp_regen` (which returned a hard 0.0 and now returns what was
granted), `carry_weight` → `get_max_carry_weight`, `undead_damage` →
`apply_melee_damage` against `Faction.UNDEAD`/`ABOMINATION`, `horror_ward` →
`trigger_horror_check`.

**Two things were already broken and are fixed on the way past.** The player had
no HP-regeneration tick at all, so any granted regen would have ticked into
nothing; and `get_attack_speed_multiplier` — the Agility attack-speed bonus,
displayed on the character sheet since forever — had **no gameplay consumer**.
It does now.

### FX-8 (original text, and the three items still outstanding)

- **Blessings.** All three priests offer blessing to any visitor, repeatedly.
  Every bless/pray choice in all three files has `actions: []`. The only real
  blessing in the game is the one-time devotee quest item.
- **Thieves Guild capstone.** `rank_benefits` names `guild_vault_access`,
  `command_authority`, `share_of_all_guild_jobs` and `personal_safehouse`.
  Zero hits in `scripts/`. The item is granted; everything it claims to confer
  is prose.
- **Deception failure has no consequence** — CLAUDE.md's TODO is still true.
- **Intuition and Endurance** — CLAUDE.md claims enemy radar, trap detection,
  stamina, fall damage and jump height. Both skills appear only in stat-map and
  display-name switches.
- **`elves_anti_human`** — the only faction no quest can move.

---

## 8/2 — the reactive layer and THE GROUNDING LAW

### Closed by this pass

| Item | Was | Now |
|---|---|---|
| **Thieves Guild capstone `rank_benefits`** | "The item is granted; everything it claims to confer is prose." | `Merchant.get_guild_price_modifier()` / `get_guild_fence_sell_bonus()`: +20% from a fence at rank 3, +35% and a 10% standing discount everywhere at rank 5 |
| **Intuition** | "appears only in stat-map and display-name switches" | `TriggeredTrap.detection_dc` and `AmbushTrigger.detection_dc` both spend `get_trap_detection_bonus()`, which had zero call sites |
| **DODGE (3g)** | "Dodging now does nothing at all. Building a passive evasion roll is new combat math and was not invented here." | RULED passive: +3%/level to be missed by melee, capped 45%, no verb, no animation. Exactly what the character sheet already promised |
| **`moral_choice` in four thieves quests** | "decorative — two siblings were migrated to real `choice_consequences` and these four were not" | `apply_choice_consequence()` falls through to `moral_choice.consequences` and executes it; the branch is saved in `moral_choices` and raised as a flag |
| **`get_quest_data()`** | not recorded, and worse than anything that was: it guessed a flat path and silently returned a four-key stand-in for every quest in a subdirectory | Serves the parsed contents the loader's own recursive walk already read |

### Opened by this pass — these need Caleb

| # | Question | Why it is blocked |
|---|---|---|
| G-1 | **Four Arcane Circle board reagents do not exist as items.** `arcane_circle_research_board.json` asks the player to bring Shadowroot, Glowcap and Moonpetals; `archmage_elara.json` and `mage_13_council_seat.json` name Moonweave. There is no `ItemData` for any of them. | Inventing four herbs is content design, and whether the board should ask for *existing* alchemy reagents instead is a quest-design call. Whitelisted as `offscreen` meanwhile, which is honest but is not a fix |
| G-2 | **The map says Kazer-Dun; everything else says Kazan-Dun.** `world_grid.gd` has `kazer_dun_entrance`, "Kazer-Dun South Gate" and "Road to Kazer-Dun"; the bible, the flags (`kazan_dun_helped`), the quest folder and every dialogue file say Kazan. | A rename is text-only on one side and an id change on the other. Which spelling is the hold's actual name is his |
| G-3 | **Six proper nouns are spoken of and cannot be reached**: the Siege of Blackmont, the Ironpeak foothills (where a wyvern nest is said to be), the Ashgrave Cantos, the Merrow's Kiss, Silverleaf, and Archmage Verendil. | Each is defensible as lore a world would carry — but *Ironpeak is a direction, not a memory*. If that nest ever becomes somewhere the player travels to, the reference must be re-pointed at the real cell rather than left whitelisted |
| G-4 | **No reaction line touches Act II.** Nothing in the reactive layer responds to the claimant, the capital, the undead continent, or the missing king. | Every one of those touches a live `[OPEN]`. Writing a townsperson's opinion of Sylvaine would settle her reception before he has settled her |
| G-5 | **`caught_lying_<npc_id>` is per-NPC and nothing ever clears it.** `clear_caught_lying()` exists and has no caller, so a single failed Deception check sours one NPC permanently. | Whether a lie should be forgivable — by time, by gold, by a later favour — is a design call. The reaction lines written for that state currently assume permanence |
