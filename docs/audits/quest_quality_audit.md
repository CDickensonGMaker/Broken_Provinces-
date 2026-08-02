# Quest quality audit

*Quest-quality pass, 2026-08-02. Stage 1 read and judged every quest JSON
under `data/quests/`; Stage 4 filled in the AFTER states. Caleb's directive: no
generic "go here, do that" - every quest needs a threat and a story.*

## The bar

A quest is **STORIED** when all three are on the page:

1. **A threat** - something is wrong and it is getting worse, to somebody
   nameable.
2. **A giver motive** - this person, in their trade's voice, has a reason it is
   *them* asking and *you* being asked.
3. **A consequence** - refusing, failing or choosing differently leaves a
   different world behind.

Anything short of all three was an **ERRAND**, however well written. Two quests
had beautiful prose and were errands (`keepers_letter_delivery`,
`guild_contract_elite`) - atmosphere is not a stake.

`_future/` is a staging directory. `QuestManager._load_quests` skips any
directory whose name starts with an underscore, so those nine files are not in
the game. They are **DEFERRED** and were not touched; five of them turn on the
missing king and the elf claimant, which are bible `[OPEN]`s.

## Numbers

The third leg of the bar is the one worth being careful about. A consequence
*stated in prose* is not the same as a consequence the world carries, and this
pass produced far more of the first than the second. Both are counted
separately, because a table that read "180 errands, now 0" would be true only
in the sense that flatters the writer.

| | Before | After |
|---|---|---|
| **ERRAND** - no threat, or no giver motive, or both | 180 | **0** |
| **STORIED**, consequence stated in prose only | 30 | 203 |
| **STORIED**, consequence live in the world | 17 | **24** |
| Live total | 227 | 227 |
| DEFERRED (`_future/`, never loaded) | 9 | 9 |

"Live in the world" is measured, not asserted: a quest counts if it has a
branch set every member of which some dialogue action actually calls, **or** an
OR-objective group, **or** a `world_flags_to_set` on a reachable branch. The
measurement script walks both git revisions and resolves every
`apply_choice_consequence` param string in `data/dialogue/` and every `.gd`,
the same way `tools/validate_content.gd` does.

Supporting figures:

* **Validator: 0 errors throughout. Warnings 179 -> 164.** Fifteen previously
  unreachable branches were wired. No branch was authored without something to
  call it, which is why the count could only fall.
* **212 of 227 live quests now carry a `notes` field** recording the threat, the
  giver's motive, what worsens on refusal, and - where a second path was
  obvious and could not be wired without raising the warning count - exactly
  what that branch should be. That is the handover to the next pass.
* **All twelve check scenes green** on the 4.7 binary, including
  `check_quest_engine` and `check_fresh_boot`, plus a clean headless boot.

### By questline

| Questline | Quests | ERRAND before | Consequence live, before | Consequence live, after |
|---|---|---|---|---|
| Bounty board | 14 | 14 | 0 | 0 |
| Three-beat chains | 45 | 45 | 0 | 0 |
| Wizard apprenticeship (Helvant) | 6 | 4 | 0 | 0 |
| Adventurer's Guild | 14 | 9 | 4 | 4 |
| Arcane Circle | 14 | 13 | 1 | 1 |
| Iron Company | 14 | 14 | 0 | 0 |
| Thieves Guild (guild/) | 14 | 10 | 2 | 2 |
| Kazan-Dun succession | 4 | 0 | 3 | 3 |
| Temple of Chronos | 11 | 8 | 1 | 2 |
| Temple of Gaela | 13 | 11 | 2 | 2 |
| Temple of Morthane | 11 | 8 | 1 | 1 |
| Staging (`_future/`, never loaded) | 9 | - | - | - |
| Towns and standalone | 67 | 44 | 5 | 9 |

## What was wrong, before

Nearly every ERRAND was one of three things:

1. **The head-count.** A creature exists; kill some of it. Measured: 45 of the
   180. The creature wanted nothing, nobody was named as its victim, and the
   world after was the world before minus some wolves.
2. **The relay.** Carry or fetch a thing. Measured: 56 of the 180 were pure
   talk/reach/collect with no combat at all. The thing was sealed, its contents
   were never revealed, and nothing opposed the carrying - so the stated urgency
   ("before nightfall", "the fate of dwarf-human relations may depend on it")
   could not be true.
3. **The promised branch.** The description or the `notes` field described two
   or three ways to resolve the quest and the data contained one, with no
   `choice_consequences` and no OR group. At least ten:
   `thieves_02_plant_evidence`, `thieves_04_debt_collection`,
   `thieves_05_blackmail`, `thieves_06_warehouse_job`,
   `mercenary_08_rival_company`, `mercenary_09_betrayal`,
   `mercenary_10_noble_war`, `mage_10_forbidden_tome`, `supply_line_crisis`,
   `adventurers_10_dragon_rumor`.

A fourth shape, on the STORIED side: **the unreachable branch.** A branch only
fires when a dialogue action runs `apply_choice_consequence "quest_id:choice_id"`.
77 authored branches across 29 quests had no such action - storied on paper,
errands in play.

## What changed

Every ERRAND got the same three things: a named person who loses something
specific, a giver whose trade explains why *they* are asking a stranger, and a
stated cost for walking away. Beyond that the fix differed by line, because the
failure differed by line:

* **Bounty board** - a notice is written by somebody who did not want to spend
  the money. Voices split by the `faction` field, which nothing had been using.
* **Three-beat chains** - parts 2 and 3 carry no giver at all, so a chain had
  one voice and two shipping labels. Each is now one story in three beats, and
  seven of the fifteen turn on the middle beat.
* **Adventurer's Guild** - a contract house with no clients. Every job now names
  who paid and what Vorn thinks of them.
* **Arcane Circle** - an examination timetable where nothing got worse if the
  student failed. Magic now costs somebody something, and Elara has rivals.
* **Iron Company** - thirteen quests, zero branches, the most generic line in
  the game. It now has a ledger, named clients, and recruits who die.
* **Thieves Guild** - four quests promised a moral choice and shipped one
  objective. The weight moved into who the mark is; the missing branches are
  specified in `notes`.
* **The three temples** - the fix is different per god, which is the point.
  Gaela's gathering only matters when somebody is hungry. Morthane's priest is
  offended, not sad. Chronos's fake countdowns are replaced with the
  inevitability doctrine, which is a better answer than a timer nobody built.
* **Towns** - the Elder Moor starter arc is the game's first impression and was
  four errands; the Larton/Aberdeen quests were four fetch quests about two
  towns starving and are now one crisis seen from four desks.

Running underneath twelve of them, and named in none of them, is the soulstone
undercurrent: `docs/design/quest_web.md`.

## Corrections to the Stage 1 verdicts

Found while doing the Stage 3 wiring, and recorded rather than quietly fixed.
Eight quests were marked "missing: unreachable branches" in the first pass and
their branches were **already wired**. The Stage 1 reading took the count of
QUEST_CHOICE warnings and assumed every quest carrying branches was in it:

* `adventurers_08_ogre_problem`, `adventurers_09_rival_guild`,
  `adventurers_11_guild_politics` - all wired in `guildmaster_vorn.json`.
* `keepers_artifact`, `keepers_confrontation` - wired in `aldric_vane_keepers.json`.
* `thieves_08_rival_gang` - wired in `shadowmaster_vex.json`.
* `gaela_04_sacred_grove` - wired in `priest_gaela_dalhurst.json`.
* `chronos_07_paradox` - wired in `priest_chronos_dalhurst.json`.

Their rows below are marked **[corrected]**. The lesson is the one this
repository keeps relearning: a count is not a list.

## Left for Caleb

* **Who is buying the soulstones.** `docs/audits/wave_b_dispositions.md` 2l.
  Nothing anywhere names a buyer; six candidates the world already supports are
  listed and none is chosen.
* **The nine `_future/` quests**, five of which turn on the missing king and the
  elf claimant. Reviving them is a scope decision.
* **`morthane_04_necromancer_trail`'s three branches** stay unwired. The quest
  turns in to `priest_morthane_elder_moor`, who has no dialogue file; wiring it
  to the Dalhurst priest would put the consequence on the wrong desk.
* **`mage_repeatable_research`** cannot be completed at all - objective type
  `variable` is deliberately unimplemented. Already on the dispositions list.
* **`thieves_repeatable_jobs`** has no `objectives` array and cannot run.
* **The eight duplicate pairs** listed at the foot of this file. They were
  deliberately differentiated rather than merged, because merging deletes quest
  ids and breaks saves. Whether the province wants two versions of the same
  event is his call.

## Per-quest verdicts

**Before** is the Stage 1 verdict and what the quest was missing. **After** is
the Stage 4 state: every live quest now has a threat and a giver motive, so the
column that carries information is whether its consequence is *live in the
world* (a reachable branch, an OR group, or a world flag) or *stated in prose*.

### Bounty board

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `bounty_bandit_patrol` | Bandit Patrol | thornfield | ERRAND | No threat beyond 'bandits exist'. No named victim, no worsening state, no reason the captain is paying now rather than last month. | STORIED, consequence in prose |
| `bounty_basilisk_lair` | The Basilisk's Lair | dalhurst | ERRAND | Names dead miners but never says whose mine, who is out of work, or what the town loses while the caves stay shut. | STORIED, consequence in prose |
| `bounty_cultist_activity` | Dark Cult Activity | millbrook | ERRAND | 'Put an end to their evil' is a verdict, not a stake. Nobody in the world is named as at risk. | STORIED, consequence in prose |
| `bounty_dire_wolf_pack` | Dire Wolf Pack | elder_moor | ERRAND | Pure headcount. No victim, no consequence of refusal, no reason the hunters want an outsider. | STORIED, consequence in prose |
| `bounty_goblin_scouts` | Goblin Scouts | dalhurst | ERRAND | The interesting fact - scouts mean a column behind them - is stated and then dropped. No stake if ignored. | STORIED, consequence in prose |
| `bounty_medicine_delivery` | Medicine for Millbrook | dalhurst | ERRAND | A sick town is the strongest hook on the board and it is one line long. No named patient, no deadline, no failure state. | STORIED, consequence in prose |
| `bounty_ogre_menace` | Ogre Menace | elder_moor | ERRAND | Bare head-price. No sense of who posted it or what the southern road carries. | STORIED, consequence in prose |
| `bounty_rat_extermination` | Rat Extermination | dalhurst | ERRAND | Kill 8. The cellars belong to nobody, the food spoiling is nobody's stock. | STORIED, consequence in prose |
| `bounty_spider_infestation` | Spider Infestation | dalhurst | ERRAND | Miners refusing to work is a stake the text raises and never spends. | STORIED, consequence in prose |
| `bounty_troll_bridge` | The Bridge Troll | millbrook | ERRAND | Toll-taking troll with a real bargaining hook (it wants payment) reduced to a kill count. No second path though one is obvious. | STORIED, consequence in prose |
| `bounty_undead_rising` | Undead Rising | elder_moor | ERRAND | A cursed totem with no maker, no reason it is there, and no consequence for leaving it. | STORIED, consequence in prose |
| `bounty_urgent_dispatch` | Urgent Dispatch | elder_moor | ERRAND | 'Urgent' is asserted. The dispatch says nothing; nothing changes if it arrives late. | STORIED, consequence in prose |
| `bounty_wolf_menace` | Wolf Menace | elder_moor | ERRAND | Thin out the pack. No hunter's-guild reason for hiring out rather than doing it themselves. | STORIED, consequence in prose |
| `bounty_wyvern_hunt` | Wyvern Hunt | thornfield | ERRAND | Livestock and farmers named in the abstract. No farm, no farmer, no lost season. | STORIED, consequence in prose |

### Three-beat chains

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `bandit_justice_1` | Bandit Justice | elder_moor | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. | STORIED, consequence in prose |
| `bandit_justice_2` | Eliminate the Bandits | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. | STORIED, consequence in prose |
| `bandit_justice_3` | Report to the Guard Captain | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. | STORIED, consequence in prose |
| `cursed_tome_1` | The Cursed Tome | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. | STORIED, consequence in prose |
| `cursed_tome_2` | Recover the Tome | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. | STORIED, consequence in prose |
| `cursed_tome_3` | Return the Tome | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. | STORIED, consequence in prose |
| `family_heirloom_1` | The Family Heirloom | elder_moor | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. | STORIED, consequence in prose |
| `family_heirloom_2` | Retrieve the Ring | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. | STORIED, consequence in prose |
| `family_heirloom_3` | Return the Heirloom | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. | STORIED, consequence in prose |
| `lost_locket_1` | The Lost Locket | millbrook | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. | STORIED, consequence in prose |
| `lost_locket_2` | Find the Locket | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. | STORIED, consequence in prose |
| `lost_locket_3` | Return the Locket | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. | STORIED, consequence in prose |
| `market_theft_1` | Theft at the Market | millbrook | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. | STORIED, consequence in prose |
| `market_theft_2` | Track the Thief | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. | STORIED, consequence in prose |
| `market_theft_3` | Return the Stolen Goods | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. | STORIED, consequence in prose |
| `missing_courier_1` | The Missing Courier | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. | STORIED, consequence in prose |
| `missing_courier_2` | Find the Courier | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. | STORIED, consequence in prose |
| `missing_courier_3` | Deliver the Letter | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. | STORIED, consequence in prose |
| `rescue_merchant_daughter_1` | Find the Kidnappers | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. | STORIED, consequence in prose |
| `rescue_merchant_daughter_2` | Rescue the Merchant's Daughter | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. | STORIED, consequence in prose |
| `rescue_merchant_daughter_3` | Return to the Merchant | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. | STORIED, consequence in prose |
| `rescue_missing_child_1` | The Missing Child | millbrook | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. | STORIED, consequence in prose |
| `rescue_missing_child_2` | Save the Child | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. | STORIED, consequence in prose |
| `rescue_missing_child_3` | Return the Child | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. | STORIED, consequence in prose |
| `rescue_sacrifice_victim_1` | The Ritual Sacrifice | millbrook | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. | STORIED, consequence in prose |
| `rescue_sacrifice_victim_2` | Stop the Sacrifice | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. | STORIED, consequence in prose |
| `rescue_sacrifice_victim_3` | Return the Rescued | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. | STORIED, consequence in prose |
| `rescue_soldier_1` | Missing Soldier | thornfield | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. | STORIED, consequence in prose |
| `rescue_soldier_2` | Free the Soldier | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. | STORIED, consequence in prose |
| `rescue_soldier_3` | Report to the Guard Captain | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. | STORIED, consequence in prose |
| `rescue_wizard_apprentice_1` | The Missing Apprentice | thornfield | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. | STORIED, consequence in prose |
| `rescue_wizard_apprentice_2` | Free the Apprentice | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. | STORIED, consequence in prose |
| `rescue_wizard_apprentice_3` | Return the Apprentice | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. | STORIED, consequence in prose |
| `rescue_woodsman_1` | The Kidnapped Woodsman | elder_moor | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. | STORIED, consequence in prose |
| `rescue_woodsman_2` | Free the Woodsman | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. | STORIED, consequence in prose |
| `rescue_woodsman_3` | Return the Woodsman | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. | STORIED, consequence in prose |
| `road_safety_1` | Road Safety | thornfield | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. | STORIED, consequence in prose |
| `road_safety_2` | Eliminate the Threat | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. | STORIED, consequence in prose |
| `road_safety_3` | Collect Your Bounty | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. | STORIED, consequence in prose |
| `stolen_ledger_1` | The Stolen Ledger | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. | STORIED, consequence in prose |
| `stolen_ledger_2` | Recover the Ledger | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. | STORIED, consequence in prose |
| `stolen_ledger_3` | Return the Ledger | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. | STORIED, consequence in prose |
| `stolen_relic_1` | The Stolen Temple Relic | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. | STORIED, consequence in prose |
| `stolen_relic_2` | Recover the Sacred Relic | - | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. | STORIED, consequence in prose |
| `stolen_relic_3` | Return the Relic | dalhurst | ERRAND | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. | STORIED, consequence in prose |

### Wizard apprenticeship (Helvant)

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `wizard_aptitude_test` | The Spark Within | dalhurst | ERRAND | Fetch two reagents. Helvant's reason for testing strangers at all is missing, and failure costs nothing. | STORIED, consequence in prose |
| `wizard_field_test` | Practical Application | dalhurst | ERRAND | Four good utility beats with no one on the other end of them - no villager is named, nothing goes wrong if the well stays foul. | STORIED, consequence in prose |
| `wizard_final_trial` | The Adept's Challenge | dalhurst | STORIED | Rite of passage with a clear giver motive. Thin on consequence - passing and failing lead to the same world. | STORIED, consequence in prose |
| `wizard_first_lesson` | Elemental Foundations | dalhurst | ERRAND | Four essences and three kills. Pure checklist; no threat anywhere in it. | STORIED, consequence in prose |
| `wizard_lost_tome` | The Lost Grimoire | dalhurst | ERRAND | Dungeon errand. Helvant's stake (his own master's book) is stated in a clause and never felt. | STORIED, consequence in prose |
| `wizard_stolen_pages` | Ink and Blood | dalhurst | STORIED | Has three roads and a real antagonist. Missing: the branches are unreachable - no dialogue action calls them (already a standing warning). | STORIED, consequence in prose |

### Adventurer's Guild

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `adventurers_01_proving_ground` | Proving Ground | dalhurst | ERRAND | Kill 8 wolves as an entrance fee. Vorn's reason for taking anyone on is missing. | STORIED, consequence in prose |
| `adventurers_02_pest_control` | Pest Control | dalhurst | ERRAND | Warehouse rats. The merchants are 'desperate' in the abstract. | STORIED, consequence in prose |
| `adventurers_03_escort_duty` | Safe Passage | dalhurst | ERRAND | Halvard has cargo and no personality; the ambush is scripted scenery. | STORIED, consequence in prose |
| `adventurers_04_bandit_contract` | Bandit Elimination | dalhurst | STORIED | Second showcase. Four roads, giver motive on the page, consequences wired. | STORIED, **consequence live** |
| `adventurers_05_missing_team` | Missing in Action | dalhurst | STORIED | Real stake (the Guild's own dead) and a stated Guild value. Missing: no branch, no consequence for how it is handled. | STORIED, consequence in prose |
| `adventurers_06_monster_hunt` | The Beast of Millbrook | dalhurst | ERRAND | 'Livestock mutilated, travelers disappearing' with no Millbrook person attached, and a promotion as the only stake. | STORIED, consequence in prose |
| `adventurers_07_dungeon_delve` | Into the Deep | dalhurst | ERRAND | Map it, clear it, keep what you find. No threat at all - the danger is generic traps. | STORIED, consequence in prose |
| `adventurers_08_ogre_problem` | Giant Troubles | dalhurst | STORIED | Three roads including a non-violent best outcome. **[corrected]** - branches were already wired; the ogre has no wants of its own on the page. | STORIED, **consequence live** |
| `adventurers_09_rival_guild` | Professional Rivalry | dalhurst | STORIED | Five roads and a real rivalry. **[corrected]** - branches were already wired; the Iron Blades have no reason for undercutting. | STORIED, **consequence live** |
| `adventurers_10_dragon_rumor` | Smoke on the Horizon | dalhurst | ERRAND | 'Don't engage' is set up and never becomes a decision. Trophy hunt. | STORIED, consequence in prose |
| `adventurers_11_guild_politics` | Internal Affairs | dalhurst | STORIED | Corruption inside the employer, three roads including taking the bribe. Missing: the corrupt officer has no name and no motive. | STORIED, **consequence live** |
| `adventurers_12_legendary_contract` | The Impossible Contract | dalhurst | ERRAND | A loot run dressed as a legend. Nobody in the world is affected either way. | STORIED, consequence in prose |
| `adventurers_13_champion` | Legend in the Making | dalhurst | ERRAND | A title fight. Fine as a capstone; carries no threat and no world consequence. | STORIED, consequence in prose |
| `adventurers_repeatable_bounty` | Guild Bounty Board | dalhurst | ERRAND | Board wrapper. Acceptable as a system, but the framing has no voice. | STORIED, consequence in prose |

### Arcane Circle

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `mage_01_entrance_exam` | The Entrance Exam | dalhurst | ERRAND | Gather essence at a shrine. The Circle's reason for admitting anybody is absent. | STORIED, consequence in prose |
| `mage_02_library_duty` | Cataloging the Arcane | dalhurst | ERRAND | Shelving, with a dangerous tome found and filed. The danger is never allowed to be dangerous. | STORIED, consequence in prose |
| `mage_03_reagent_gathering` | Essence Collection | dalhurst | ERRAND | Three gathers. Why the Circle is short of reagents at all is the interesting question and is not asked. | STORIED, consequence in prose |
| `mage_04_enchantment_task` | First Enchantment | dalhurst | ERRAND | Fetch a silver ingot for a ritual. No stake; the ring is made either way. | STORIED, consequence in prose |
| `mage_05_rogue_mage` | Unsanctioned Magic | dalhurst | STORIED | Kill-or-persuade in a real OR group with a moral edge. Missing: the rogue has no name and no argument of her own. | STORIED, **consequence live** |
| `mage_06_artifact_recovery` | Lost Knowledge | dalhurst | ERRAND | Decades-long search compressed into 'go and get it'. No rival, no deadline. | STORIED, consequence in prose |
| `mage_07_thesis_project` | Original Research | dalhurst | ERRAND | Choose a specialisation and file paperwork. The choice sets nothing in the world. | STORIED, consequence in prose |
| `mage_08_magical_disaster` | Containment | dalhurst | ERRAND | Urgency asserted ('Time is of the essence!') with no clock and no cost. Nobody is hurt whether you hurry or not. | STORIED, consequence in prose |
| `mage_09_rival_circle` | The Shadow Circle | dalhurst | ERRAND | Introduces a recurring antagonist and gives it no goal beyond 'something catastrophic'. | STORIED, consequence in prose |
| `mage_10_forbidden_tome` | The Locked Section | dalhurst | ERRAND | Claims a morality test in its notes and ships no branch and no consequence. | STORIED, consequence in prose |
| `mage_11_planar_breach` | Beyond the Veil | dalhurst | ERRAND | Cosmic threat, zero local victims. Nothing near Crossroads is named as being at risk. | STORIED, consequence in prose |
| `mage_12_archmage_trial` | The Final Theorem | dalhurst | ERRAND | Examination. No threat, no consequence, and the Theorem is scenery. | STORIED, consequence in prose |
| `mage_13_council_seat` | The Inner Circle | dalhurst | ERRAND | Ceremonial duel. The seat changes nothing about the Circle or the town. | STORIED, consequence in prose |
| `mage_repeatable_research` | Guild Assignments | dalhurst | ERRAND | Deferred objective type `variable` - cannot be completed at all. Already on the dispositions list. | STORIED, consequence in prose |

### Iron Company

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `mercenary_01_enlistment` | Sign the Contract | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Enlistment trial with no reason the Company is recruiting. | STORIED, consequence in prose |
| `mercenary_02_drill` | Sword and Shield | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Drill. No threat; nothing is at stake in an obstacle course. | STORIED, consequence in prose |
| `mercenary_03_first_blood` | Baptism of Steel | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. First contract, generic bandit outpost, no client and no reason. | STORIED, consequence in prose |
| `mercenary_04_caravan_guard` | Gold on the Road | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Escort. Ashe is cargo with a name. | STORIED, consequence in prose |
| `mercenary_05_siege_support` | Breach the Walls | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Assault a stronghold. Who contracted it and what they want is never said. | STORIED, consequence in prose |
| `mercenary_06_hostage_rescue` | No One Left Behind | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. A hostage with no name and a ransom deadline with no clock. | STORIED, consequence in prose |
| `mercenary_07_command_trial` | Lead from the Front | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'Your tactical decisions determine their survival' - there are no decisions in the objectives. | STORIED, consequence in prose |
| `mercenary_08_rival_company` | Blood and Honor | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Description offers three resolutions; the data has one kill objective and no branch. | STORIED, consequence in prose |
| `mercenary_09_betrayal` | The Turncloak | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. A traitor with no name, no motive, and an execute-or-exile choice that is one objective with no consequence. | STORIED, consequence in prose |
| `mercenary_10_noble_war` | Proxy War | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'Morally gray' is claimed in prose and never expressed as a choice. The two houses are unnamed. | STORIED, consequence in prose |
| `mercenary_11_monster_battalion` | The Horde | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Defend Millbrook - the one quest here with a town to lose, and Millbrook is not characterised at all. | STORIED, consequence in prose |
| `mercenary_12_legendary_battle` | Hold the Line | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'This is your Thermopylae' with no consequence for losing and no named defenders. | STORIED, consequence in prose |
| `mercenary_13_second_command` | The Iron Will | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Promotion duel. No threat, no world change. | STORIED, consequence in prose |
| `mercenary_repeatable_contracts` | Company Contracts | dalhurst | ERRAND | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Wrapper with no voice. | STORIED, consequence in prose |

### Thieves Guild (guild/)

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `thieves_01_light_fingers` | Light Fingers | dalhurst | ERRAND | Steal a ledger. Horace is a shop, not a man, and getting caught costs nothing. | STORIED, consequence in prose |
| `thieves_02_plant_evidence` | Framed | dalhurst | ERRAND | Framing an innocent blacksmith is the strongest moral hook in the guild line and ships with no branch and no consequence for Marcus. | STORIED, consequence in prose |
| `thieves_03_fence_connection` | Moving Goods | dalhurst | ERRAND | Carry a package. The guards are decoration. | STORIED, consequence in prose |
| `thieves_04_debt_collection` | The Sailor's Debt | dalhurst | ERRAND | Notes promise 'multiple approaches, moral dilemma'; the data has one collect objective. Garrett is not written. | STORIED, consequence in prose |
| `thieves_05_blackmail` | Leverage | dalhurst | ERRAND | 'What you do with it is up to you' - and there is nothing in the file that lets you do anything with it. | STORIED, consequence in prose |
| `thieves_06_warehouse_job` | The Dalhurst Job | dalhurst | ERRAND | Three approaches named in prose, none in data. | STORIED, consequence in prose |
| `thieves_07_noble_heist` | High Society | dalhurst | ERRAND | Good set-piece; no one is harmed, no one reacts, nothing worsens if the sapphire stays on its stand. | STORIED, consequence in prose |
| `thieves_08_rival_gang` | Turf War | dalhurst | STORIED | Three genuine roads with different guild-reputation outcomes. Missing: the Crimson Blades have no leader and no grievance. | STORIED, **consequence live** |
| `thieves_09_informant` | Loose Lips | dalhurst | STORIED | Investigation with four fates for the traitor. Missing: the three suspects are names on a list. | STORIED, consequence in prose |
| `thieves_10_government_job` | State Secrets | dalhurst | ERRAND | 'A decree that could destroy the Guild' - never says what it decrees, so the threat cannot land. | STORIED, consequence in prose |
| `thieves_11_impossible_vault` | The Impossible Vault | dalhurst | ERRAND | Puzzle box. Nobody wants it, nobody loses it, no rival is racing you. | STORIED, consequence in prose |
| `thieves_12_guild_traitor` | Shadows Within | dalhurst | STORIED | Real misdirection and an OR group at the confrontation. Missing: no consequence data behind either road. | STORIED, **consequence live** |
| `thieves_13_right_hand` | The Guildmaster's Trust | dalhurst | STORIED | Three ambush sites with different risk. Missing: the convoy belongs to nobody in particular. | STORIED, consequence in prose |
| `thieves_repeatable_jobs` | Guild Contracts | dalhurst | ERRAND | Zero objectives in the file. Structurally empty. | STORIED, consequence in prose |

### Kazan-Dun succession

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `kazan_dun_01_the_stair_holds` | The Stair Holds | kazan_dun_entrance | STORIED | Nothing missing. Threat, giver motive and refusal-cost all on the page. | STORIED, consequence in prose |
| `kazan_dun_02_what_the_pits_held` | What the Pits Held | kazan_dun_level_1 | STORIED | Nothing missing. The word Morgrim will not say is the whole quest. | STORIED, **consequence live** |
| `kazan_dun_03_the_devourers_table` | The Devourer's Table | kazan_dun_level_1 | STORIED | Nothing missing. Three roads, one of which is shameful, and the [OPEN] mechanism stays open. | STORIED, **consequence live** |
| `kazan_dun_04_the_empty_chair` | The Empty Chair | kazan_dun_level_1 | STORIED | Nothing missing. Three roads, real politics, gates nothing. | STORIED, **consequence live** |

### Temple of Chronos

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `chronos_01_first_vision` | The First Vision | dalhurst | ERRAND | Meditate and fetch a token. The Priest's reason for testing strangers is absent. | STORIED, consequence in prose |
| `chronos_02_hourglasses` | Sands of Service | dalhurst | ERRAND | Three sands. Geography tour with no threat. | STORIED, consequence in prose |
| `chronos_03_late_delivery` | Time-Sensitive | dalhurst | ERRAND | 'Before nightfall' with no clock and no consequence for arriving late - which is the one thing a time-god quest must not get wrong. | STORIED, consequence in prose |
| `chronos_04_false_prophet` | The False Seer | dalhurst | STORIED | Two real readings of the same man. Missing: the seer is never given a reason to lie. | STORIED, **consequence live** (branches wired this pass) |
| `chronos_05_devotion_choice` | The Timekeeper's Question | dalhurst | STORIED | Genuine fork with lasting flags. Missing: declining costs nothing and changes nothing. | STORIED, consequence in prose |
| `chronos_06_temporal_echo` | Echoes of What Was | dalhurst | ERRAND | Witness a vision, kill the guardians. What the player learns is never said, so nothing is at stake. | STORIED, consequence in prose |
| `chronos_07_paradox` | The Paradox Stone | dalhurst | STORIED | Destroy or harness, with different rewards. Missing: nobody is harmed by the loops, so the 'safe' choice is free. | STORIED, **consequence live** |
| `chronos_08_prophet_training` | Glimpses of Tomorrow | dalhurst | ERRAND | Three meditations. Training montage with no threat and no failure. | STORIED, consequence in prose |
| `chronos_09_timeline_threat` | When Time Bleeds | dalhurst | ERRAND | 'Time bleeds monsters' with no bleeding into anyone's life. No town, no victim. | STORIED, consequence in prose |
| `chronos_10_eternal_vigil` | The Eternal Vigil | dalhurst | ERRAND | Boss run. The Timeless One wants nothing and threatens no named place. | STORIED, consequence in prose |
| `chronos_repeatable_visions` | Seeking Visions | dalhurst | ERRAND | Repeatable flavour. Acceptable as a system; carries no threat by design. | STORIED, consequence in prose |

### Temple of Gaela

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `gaela_01_first_offering` | Seeds of Faith | dalhurst | ERRAND | Bring flowers. A struggling farmer is talked to and never helped. | STORIED, consequence in prose |
| `gaela_02_healing_herbs` | The Healer's Garden | dalhurst | ERRAND | Three gathers, no patient. | STORIED, consequence in prose |
| `gaela_03_protect_harvest` | Guardians of the Field | dalhurst | ERRAND | Wolves and rats at the crops with no farm and no farmer who loses one. | STORIED, consequence in prose |
| `gaela_04_sacred_grove` | The Sacred Grove | dalhurst | STORIED | Three roads through a real conflict of interests. Missing: the loggers have no foreman with a reason. | STORIED, **consequence live** |
| `gaela_05_devotion_choice` | The Mother's Embrace | dalhurst | STORIED | Genuine commitment fork. Missing: declining is consequence-free. | STORIED, consequence in prose |
| `gaela_06_blight_source` | Root of Corruption | dalhurst | ERRAND | Cultists maintaining a corruption with no motive and no victim named. | STORIED, consequence in prose |
| `gaela_07_spirit_of_land` | Voice of the Green | dalhurst | ERRAND | Free the spirit. Nothing is worse if it stays bound. | STORIED, consequence in prose |
| `gaela_08_seed_of_life` | The Eternal Seed | dalhurst | ERRAND | A plague in Thornfield used as a fetch-quest justification; no sick person is written. | STORIED, consequence in prose |
| `gaela_09_famine_threat` | When Harvests Fail | dalhurst | ERRAND | Regional famine as scenery. Three towns investigated, none characterised, nobody starves. | STORIED, consequence in prose |
| `gaela_10_lifebringer` | The Lifebringer | dalhurst | ERRAND | Ritual capstone. `accept_champion_title` is the only branch and it is not a choice. | STORIED, **consequence live** |
| `gaela_bonus_bountiful_harvest` | Bountiful Harvest | dalhurst | ERRAND | Four gathers for a festival that is never held. | STORIED, consequence in prose |
| `gaela_bonus_shepherd_quest` | The Lost Flock | millbrook | ERRAND | Lost sheep. The shepherd's livelihood is the obvious stake and is unstated. | STORIED, consequence in prose |
| `gaela_repeatable_tending` | Tending the Garden | dalhurst | ERRAND | Gardening. Fine as flavour; no threat by design. | STORIED, consequence in prose |

### Temple of Morthane

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `morthane_01_last_rites` | Final Rest | elder_moor | ERRAND | Perform rites on unburied dead. Who they were and why they lie unburied is the story, and it is not told. | STORIED, consequence in prose |
| `morthane_02_restless_spirit` | Unfinished Business | elder_moor | ERRAND | A ghost with unfinished business the quest never specifies. | STORIED, consequence in prose |
| `morthane_03_cemetery_duty` | Vigil of the Dead | elder_moor | ERRAND | Grave robbers with no motive - and no answer to the obvious question of what is worth stealing from a grave. | STORIED, consequence in prose |
| `morthane_04_necromancer_trail` | The Defiler's Path | elder_moor | STORIED | Three fates and a doctrine that permits mercy. Missing: the necromancer has no argument written for him. | STORIED, consequence in prose |
| `morthane_05_devotion_choice` | Embracing the Cycle | elder_moor | STORIED | Commitment fork with a near-death trial. Missing: declining changes nothing. | STORIED, consequence in prose |
| `morthane_06_death_speaker` | Voices Beyond the Veil | elder_moor | STORIED | A murder solved by the victim's own testimony - the best premise in the temple lines. Missing: victim, killer and motive are all unwritten. | STORIED, consequence in prose |
| `morthane_07_lich_rumor` | Whispers of Immortality | elder_moor | ERRAND | A man trying to become a lich, with no reason given for wanting it. | STORIED, consequence in prose |
| `morthane_08_rebirth_ritual` | The Second Chance | elder_moor | ERRAND | A dying woman consents to rebirth - all ceremony, no stake, no chance for it to go wrong. | STORIED, consequence in prose |
| `morthane_09_undead_army` | The Rising Tide | elder_moor | ERRAND | Waves at two towns. Neither town has a person in it. | STORIED, consequence in prose |
| `morthane_10_deathwalker` | The Deathwalker | elder_moor | ERRAND | Champion capstone. `become_champion` is not a choice. | STORIED, **consequence live** |
| `morthane_repeatable_cleansing` | Cleansing Duty | elder_moor | ERRAND | One kill objective and one line. Fine as a system, voiceless. | STORIED, consequence in prose |

### Staging (`_future/`, never loaded)

| Quest id | Title | Verdict | Why it was left |
|---|---|---|---|
| `capital_intrigue` | Turmoil in the Capital | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `journey_to_kazandun` | Journey to Kazan-Dun | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `larton_famine` | The Starving Coast | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `missing_surveyors` | The Missing Surveyors | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `rat_problem` | The Rat Problem | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `tenger_scouts` | Scouts from the South | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `the_false_queen` | The False Queen | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `the_imprisoned_king` | The Imprisoned King | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `the_kings_secret` | The King's Secret | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |

### Towns and standalone

| Quest id | Title | Region | Before | What it was missing | After |
|---|---|---|---|---|---|
| `aberdeen_relief` | Aberdeen Relief | larton | ERRAND | A cut-off swamp town is a strong situation with no person in it - Bjorn sends 'desperate messages' that are never quoted. | STORIED, consequence in prose |
| `aberdeens_blessing` | Aberdeen's Blessing | aberdeen | ERRAND | Fetch a relic from a ruin. No consequence if the relic stays where it is. | STORIED, consequence in prose |
| `arena_tier_1` | First Blood | bloodsand_arena | ERRAND | Three rounds. Gormund has no reason to want this fighter specifically. | STORIED, consequence in prose |
| `arena_novice_tournament` | Trial of the Newcomer | bloodsand_arena | ERRAND | Nine opponents. Framing is a scoreboard. | STORIED, consequence in prose |
| `bandit_trouble` | Bandit Trouble | dalhurst | ERRAND | Board bounty. 'Before more innocent blood is spilled' is the only stake and it names nobody. | STORIED, consequence in prose |
| `chronos_false_prophet` | The False Seer | dalhurst | STORIED | Duplicate of chronos_04 at root with a third road (exploit the seer). Missing: unreachable branches, and the duplication itself. | STORIED, **consequence live** (branches wired this pass) |
| `chronos_hourglass` | The Shattered Hourglass | dalhurst | ERRAND | Recover a stolen artifact. The bandits do not know what they took, which is interesting and never used. | STORIED, consequence in prose |
| `chronos_time_fragment` | Echoes of the Past | dalhurst | ERRAND | Collect artifacts before their power fades - a deadline stated and never enforced. | STORIED, consequence in prose |
| `dwarf_messenger` | Iron Words | elder_moor | ERRAND | 'The fate of dwarf-human relations may depend on it' and the letter's contents are never revealed, so nothing can depend on anything. | STORIED, consequence in prose |
| `eastern_wolves` | The Eastern Wolf Pack | thornfield | ERRAND | Thin the pack. Greta and Elric both exist and neither is given a reason to care. | STORIED, consequence in prose |
| `elven_ambassador` | The Elven Embassy | dalhurst | ERRAND | The best premise on the root list - a missing treaty and a collapsing peace - with no branch, no consequence and no failure state. | STORIED, consequence in prose |
| `fish_fraud` | Fishy Business | millbrook | STORIED | Three honest readings of a dispute, including siding with the accused. Missing: unreachable branches only. | STORIED, consequence in prose |
| `gaela_blight` | The Spreading Blight | dalhurst | ERRAND | Blight investigation duplicating gaela_06. No farmer, no lost harvest, no branch. | STORIED, consequence in prose |
| `gaela_sacred_grove` | The Sacred Grove | dalhurst | STORIED | Three roads. Missing: unreachable branches; duplicates gaela_04. | STORIED, **consequence live** (branches wired this pass) |
| `gaela_seed_of_life` | Seed of Renewal | dalhurst | ERRAND | Sick villagers as a reason to enter a dungeon. None of them is written. | STORIED, consequence in prose |
| `ghost_pirate_investigation` | The Ghost Pirate Menace | larton | ERRAND | Blockaded port, which would starve Larton, treated as a boss location. | STORIED, consequence in prose |
| `ghost_ship_rumors` | Ghost Ship Rumors | dalhurst | ERRAND | Good atmosphere, no threat: the ship takes nothing from anyone on the page. | STORIED, consequence in prose |
| `guild_contract_bandits` | Bandit Elimination Contract | dalhurst | ERRAND | Camp, captain, report. The merchants who are being ambushed are never named. | STORIED, consequence in prose |
| `guild_contract_elite` | The Thornfield Terror | dalhurst | ERRAND | Well-written monster copy with no farmer, no lost herd and no consequence for leaving it alive. | STORIED, consequence in prose |
| `guild_contract_spiders` | Silk and Venom | dalhurst | ERRAND | Clear a mine. The fled miners are the stake and never appear. | STORIED, consequence in prose |
| `guild_contract_troll` | Bridge Toll | dalhurst | STORIED | Four roads including a negotiated toll. Missing: unreachable branches. | STORIED, **consequence live** (branches wired this pass) |
| `guild_elite_trial` | The Elite Trial | dalhurst | ERRAND | Solo clear plus duel. Rite with no world consequence. | STORIED, consequence in prose |
| `guild_initiation` | Proving Ground | dalhurst | ERRAND | Duplicate of adventurers_01 with different objectives. Same missing pieces, plus the duplication. | STORIED, consequence in prose |
| `harbor_ghost_ship` | The Phantom Vessel | dalhurst | ERRAND | Lighthouse investigation with no owner, no missing crew named, and no ending in the objectives. | STORIED, consequence in prose |
| `keepers_artifact` | The Forbidden Relic | dalhurst | STORIED | Destroy or keep, with a stated cost for keeping. **[corrected]** - branches were already wired. | STORIED, **consequence live** |
| `keepers_confrontation` | The Shadow Revealed | dalhurst | STORIED | Four outcomes including partial failure. **[corrected]** - branches were already wired. | STORIED, **consequence live** |
| `keepers_cult_trail` | Following the Thread | dalhurst | STORIED | Stealth grades the outcome. Missing: unreachable branches. | STORIED, consequence in prose |
| `keepers_infiltration` | Among the Faithful | dalhurst | STORIED | Cover-blown is a real second outcome. Missing: unreachable branches. | STORIED, consequence in prose |
| `keepers_initiation` | The Keeper's Trust | dalhurst | ERRAND | Long, atmospheric, and structurally 'go there, kill them, come back'. No consequence for refusing. | STORIED, consequence in prose |
| `keepers_test` | Eyes in the Shadows | dalhurst | ERRAND | Three-town investigation whose finding is never stated. Nine objectives, no stake. | STORIED, consequence in prose |
| `lake_creature` | Terror in the Lake | millbrook | ERRAND | The village depends on the lake - stated once. No fisherman, no lost season, no alternative to killing it. | STORIED, consequence in prose |
| `logging_troubles` | Wolves in the Wood | elder_moor | ERRAND | Two dead woodsmen and a settlement short of winter timber, and neither fact is allowed to cost anything. | STORIED, consequence in prose |
| `lost_apprentice` | The Lost Apprentice | dalhurst | STORIED | Three fates for Marcus. Missing: unreachable branches. | STORIED, consequence in prose |
| `lost_woodsman` | The Lost Woodsman | thornfield | STORIED | Alive or dead, both written. Missing: unreachable branches; Harlen's family is not present. | STORIED, consequence in prose |
| `meet_the_arena_master` | Blood and Glory | elder_moor | ERRAND | A signpost quest. Acceptable as a pointer; no threat by design. | STORIED, consequence in prose |
| `merchant_protection` | Road Guard | thornfield | STORIED | Cargo intact, cargo lost, or bribed by bandits. Missing: unreachable branches. | STORIED, consequence in prose |
| `millbrook_bandits` | Trouble in Millbrook | millbrook | STORIED | The flagship. Nothing missing. | STORIED, **consequence live** |
| `miners_in_peril` | Frozen Tunnels | duncaster | STORIED | All saved or some lost - a real cost. Missing: unreachable branches. | STORIED, consequence in prose |
| `missing_miner` | The Missing Miner | aberdeen | ERRAND | A man missing three days. The mayor 'fears the worst' and the town loses nothing either way. | STORIED, consequence in prose |
| `morthane_cycle_broken` | The Broken Cycle | dalhurst | ERRAND | A region-wide undead rising with no settlement written into it. | STORIED, consequence in prose |
| `morthane_necromancer` | The Necromancer's Trail | dalhurst | STORIED | Three fates and a doctrine that allows mercy. Missing: unreachable branches. | STORIED, **consequence live** (branches wired this pass) |
| `morthane_restless_soul` | Unfinished Business | dalhurst | ERRAND | A ghost, a keepsake, a loved one - three people, none of them named or given a line. | STORIED, consequence in prose |
| `noble_soulstone_request` | A Noble's Request | dalhurst | STORIED | Deliver or keep, with a daily-penalty debt for keeping. The only quest in the game where a soulstone is the point. | STORIED, consequence in prose |
| `retake_harbor` | Retake the Harbor | larton | ERRAND | Clear a warehouse. The survivors who need the supplies never appear. | STORIED, consequence in prose |
| `sailors_debt` | The Sailor's Debt | dalhurst | STORIED | Three roads on one drunk sailor. Missing: unreachable branches; Brennan has no reason for the debt. | STORIED, consequence in prose |
| `starving_south` | The Starving South | larton | ERRAND | A town facing starvation, resolved by a bureaucratic errand nobody obstructs. | STORIED, consequence in prose |
| `supply_line_crisis` | Supply Line Crisis | aberdeen | ERRAND | Has a genuine either/or in the objective text and no branch data behind it - the choice is not recorded anywhere. | STORIED, consequence in prose |
| `temple_blessing_quest` | The Three's Blessing | dalhurst | ERRAND | Two gathers. Nothing at stake. | STORIED, consequence in prose |
| `temple_prophecy_chronos` | Visions of Time | dalhurst | ERRAND | Duplicate of chronos_03. Same missing clock, same missing consequence. | STORIED, consequence in prose |
| `temple_undead_menace` | Cleanse the Restless Dead | dalhurst | ERRAND | Cemetery clear-out. The priest 'takes personal offense', which is the closest any bounty here gets to a motive, and it stops there. | STORIED, consequence in prose |
| `tenger_diplomacy` | Desert Parley | east_hollow | STORIED | Peace, trade or failure - and failure is a real outcome. Missing: unreachable branches. | STORIED, consequence in prose |
| `tharins_message` | A Message for Thornfield | elder_moor | ERRAND | Deliver a message. Explicitly framed as a trust test, which is a motive; nothing else. | STORIED, consequence in prose |
| `tharins_supplies` | Supply Run to Dalhurst | elder_moor | ERRAND | Collect a shipment. No threat anywhere. | STORIED, consequence in prose |
| `tharins_wolf_problem` | The Wolf Problem | elder_moor | ERRAND | One kill objective. The logging teams being attacked is stated in the description and nowhere else. | STORIED, consequence in prose |
| `keepers_letter_delivery` | A Letter for Dalhurst | elder_moor | ERRAND | Excellent prose, zero stakes: a sealed letter that stays sealed and a delivery nothing opposes. | STORIED, consequence in prose |
| `thieves_guild_heist` | The Dalhurst Job | dalhurst | STORIED | Four approaches including being caught. Missing: unreachable branches. | STORIED, consequence in prose |
| `thieves_guild_informant` | Loose Lips | dalhurst | STORIED | Four fates for Tomas. Missing: unreachable branches. | STORIED, **consequence live** |
| `thieves_guild_initiation` | Light Fingers | dalhurst | STORIED | Clean or caught. Missing: unreachable branches; the merchant is not a person. | STORIED, consequence in prose |
| `thieves_guild_mastermind` | The Big Score | dalhurst | STORIED | Three outcomes including keeping the haul. Missing: unreachable branches. | STORIED, consequence in prose |
| `thieves_guild_rival` | Turf War | dalhurst | STORIED | Four roads including absorbing the rival crew. Missing: unreachable branches. | STORIED, **consequence live** |
| `tutorial_alchemy` | Herbalism Basics | elder_moor | ERRAND | Craft one potion. Tutorial; no threat by design, but Brennan has no reason to teach a stranger. | STORIED, consequence in prose |
| `tutorial_cooking` | A Warm Meal | elder_moor | ERRAND | Cook one meat. Same. | STORIED, consequence in prose |
| `tutorial_crafting` | The Smith's Apprentice | elder_moor | ERRAND | Craft one dagger. Same. | STORIED, consequence in prose |
| `watermill_curse` | The Silent Mill | millbrook | ERRAND | The mill stops and the village cannot grind before winter - a real threat, stated once, with an objective list that ends on 'remove or appease the obstruction' and no outcome either way. | STORIED, consequence in prose |
| `whalers_debt` | The Canyon Ledger | whalers_abyss | STORIED | Full collection, mercy, or a bribe. Missing: unreachable branches. | STORIED, consequence in prose |
| `willow_dale_investigation` | Missing Caravan | dalhurst | ERRAND | A caravan and its men are missing; finding survivors is marked optional. Nothing turns on it. | STORIED, consequence in prose |
| `wolf_pack_menace` | Wolf Pack Menace | thornfield | ERRAND | Third wolf-pack quest in the region. No distinguishing threat, no reason Marek cannot do it himself. | STORIED, consequence in prose |

## Duplicate pairs found while reading

Recorded because the reading surfaced them and a future pass will otherwise
rediscover them:

* `chronos_false_prophet` / `chronos_04_false_prophet` - the root copy has a
  third branch (`exploit_seer`) the temple copy lacks.
* `temple_prophecy_chronos` / `chronos_03_late_delivery`.
* `gaela_sacred_grove` / `gaela_04_sacred_grove`; `gaela_blight` /
  `gaela_06_blight_source`; `gaela_seed_of_life` / `gaela_08_seed_of_life`.
* `morthane_restless_soul` / `morthane_02_restless_spirit`;
  `morthane_necromancer` / `morthane_04_necromancer_trail`;
  `temple_undead_menace` overlapping `morthane_03_cemetery_duty`.
* `guild_initiation` / `adventurers_01_proving_ground`;
  `guild_contract_bandits` overlapping `adventurers_04_bandit_contract`.
* `thieves_guild_*` at root against most of `guild/thieves/`; `sailors_debt`
  against `thieves_04_debt_collection`, with a different debtor.

Both copies of each pair were rewritten and deliberately **not** merged -
merging deletes quest ids and breaks saves. Each pair was given two different
people's angle on the same event, so it reads as two parties' business rather
than one file printed twice, and each file's `notes` says which pair it belongs
to.
