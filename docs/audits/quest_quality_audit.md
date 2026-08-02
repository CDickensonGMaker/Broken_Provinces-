# Quest quality audit

*Stage 1 of the quest-quality pass, 2026-08-02. Every quest JSON under
`data/quests/` read and judged against one bar: **does it have a threat and a
story?** Caleb's directive - no generic "go here, do that".*

## The bar

A quest is **STORIED** when all three are on the page:

1. **A threat** - something is wrong and it is getting worse, to somebody
   nameable.
2. **A giver motive** - this person, in their trade's voice, has a reason it is
   *them* asking and *you* being asked.
3. **A consequence** - refusing, failing or choosing differently leaves a
   different world behind.

Anything short of all three is an **ERRAND**, however well it is written. Two
quests on this list have beautiful prose and are errands (`keepers_letter_delivery`,
`guild_contract_elite`) - atmosphere is not a stake.

`_future/` is a staging directory. `QuestManager._load_quests` skips any
directory whose name starts with an underscore, so those nine files are not in
the game; they are listed as **DEFERRED** and were not touched.

## Numbers

| | Before | After |
|---|---|---|
| STORIED | 47 | 47 |
| ERRAND | 180 | 180 |
| Live total | 227 | 227 |
| DEFERRED (`_future/`) | 9 | 9 |

> **AFTER column is filled in at Stage 4.** Until then it repeats the before
> figures so a half-finished run cannot read as a finished one.

### By questline

| Questline | Quests | STORIED | ERRAND |
|---|---|---|---|
| Bounty board | 14 | 0 | 14 |
| Three-beat chains | 45 | 0 | 45 |
| Wizard apprenticeship (Helvant) | 6 | 2 | 4 |
| Adventurer's Guild | 14 | 5 | 9 |
| Arcane Circle | 14 | 1 | 13 |
| Iron Company | 14 | 0 | 14 |
| Thieves Guild (guild/) | 14 | 4 | 10 |
| Kazan-Dun succession | 4 | 4 | 0 |
| Temple of Chronos | 11 | 3 | 8 |
| Temple of Gaela | 13 | 2 | 11 |
| Temple of Morthane | 11 | 3 | 8 |
| Staging (`_future/`, never loaded) | 9 | - | - |
| Towns and standalone | 67 | 23 | 44 |

## The three failure shapes

Nearly every ERRAND on this list is one of three things:

1. **The head-count.** A creature exists; kill some of it. Measured: 45 of the
   180 errands are kill-led. The creature wants nothing, nobody is named as its
   victim, and the world after is the world before minus some wolves.
2. **The relay.** Carry or fetch a thing. Measured: 56 of the 180 are pure
   talk/reach/collect with no combat at all. The thing is usually sealed, its
   contents are never revealed, and nothing opposes the carrying - so the stated
   urgency ("before nightfall", "the fate of dwarf-human relations may depend
   on it") cannot be true.
3. **The promised branch.** The description or the `notes` field describes two or
   three ways to resolve the quest and the data contains one path, with no
   `choice_consequences` and no OR group. At least ten: `thieves_02_plant_evidence`,
   `thieves_04_debt_collection`, `thieves_05_blackmail`, `thieves_06_warehouse_job`,
   `mercenary_08_rival_company`, `mercenary_09_betrayal`, `mercenary_10_noble_war`,
   `mage_10_forbidden_tome`, `supply_line_crisis`, `adventurers_10_dragon_rumor`.

A fourth, smaller shape: **the unreachable branch.** 77 authored branches across
29 quests have real `choice_consequences` that no dialogue action invokes. Those
are already counted as warnings in `docs/audits/validation_report.md` and tabled
in `docs/audits/invention_manifest.md`; they are STORIED on paper and errands in
play. They are marked in the tables below, and this pass did not add to the pile:
**no branch was authored without something that calls it.**

## Per-quest verdicts

### Bounty board

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `bounty_bandit_patrol` | Bandit Patrol | thornfield | **ERRAND** | No threat beyond 'bandits exist'. No named victim, no worsening state, no reason the captain is paying now rather than last month. |
| `bounty_basilisk_lair` | The Basilisk's Lair | dalhurst | **ERRAND** | Names dead miners but never says whose mine, who is out of work, or what the town loses while the caves stay shut. |
| `bounty_cultist_activity` | Dark Cult Activity | millbrook | **ERRAND** | 'Put an end to their evil' is a verdict, not a stake. Nobody in the world is named as at risk. |
| `bounty_dire_wolf_pack` | Dire Wolf Pack | elder_moor | **ERRAND** | Pure headcount. No victim, no consequence of refusal, no reason the hunters want an outsider. |
| `bounty_goblin_scouts` | Goblin Scouts | dalhurst | **ERRAND** | The interesting fact - scouts mean a column behind them - is stated and then dropped. No stake if ignored. |
| `bounty_medicine_delivery` | Medicine for Millbrook | dalhurst | **ERRAND** | A sick town is the strongest hook on the board and it is one line long. No named patient, no deadline, no failure state. |
| `bounty_ogre_menace` | Ogre Menace | elder_moor | **ERRAND** | Bare head-price. No sense of who posted it or what the southern road carries. |
| `bounty_rat_extermination` | Rat Extermination | dalhurst | **ERRAND** | Kill 8. The cellars belong to nobody, the food spoiling is nobody's stock. |
| `bounty_spider_infestation` | Spider Infestation | dalhurst | **ERRAND** | Miners refusing to work is a stake the text raises and never spends. |
| `bounty_troll_bridge` | The Bridge Troll | millbrook | **ERRAND** | Toll-taking troll with a real bargaining hook (it wants payment) reduced to a kill count. No second path though one is obvious. |
| `bounty_undead_rising` | Undead Rising | elder_moor | **ERRAND** | A cursed totem with no maker, no reason it is there, and no consequence for leaving it. |
| `bounty_urgent_dispatch` | Urgent Dispatch | elder_moor | **ERRAND** | 'Urgent' is asserted. The dispatch says nothing; nothing changes if it arrives late. |
| `bounty_wolf_menace` | Wolf Menace | elder_moor | **ERRAND** | Thin out the pack. No hunter's-guild reason for hiring out rather than doing it themselves. |
| `bounty_wyvern_hunt` | Wyvern Hunt | thornfield | **ERRAND** | Livestock and farmers named in the abstract. No farm, no farmer, no lost season. |

### Three-beat chains

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `bandit_justice_1` | Bandit Justice | elder_moor | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. |
| `bandit_justice_2` | Eliminate the Bandits | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. |
| `bandit_justice_3` | Report to the Guard Captain | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Raiding caravans is stated once and never costs anybody anything. |
| `cursed_tome_1` | The Cursed Tome | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. |
| `cursed_tome_2` | Recover the Tome | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. |
| `cursed_tome_3` | Return the Tome | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A book of dark magic in cult hands is the whole threat and it is never described as dangerous to a named person or place. |
| `family_heirloom_1` | The Family Heirloom | elder_moor | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. |
| `family_heirloom_2` | Retrieve the Ring | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. |
| `family_heirloom_3` | Return the Heirloom | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A grandmother's ring with no grandmother in it. |
| `lost_locket_1` | The Lost Locket | millbrook | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. |
| `lost_locket_2` | Find the Locket | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. |
| `lost_locket_3` | Return the Locket | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The widow has a dead husband and no grief in the prose. |
| `market_theft_1` | Theft at the Market | millbrook | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. |
| `market_theft_2` | Track the Thief | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. |
| `market_theft_3` | Return the Stolen Goods | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. An accusation against 'one of the locals' that never becomes a person, so there is nothing to get wrong. |
| `missing_courier_1` | The Missing Courier | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. |
| `missing_courier_2` | Find the Courier | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. |
| `missing_courier_3` | Deliver the Letter | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A dead man on the road and the quest never asks what the letter says. |
| `rescue_merchant_daughter_1` | Find the Kidnappers | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. |
| `rescue_merchant_daughter_2` | Rescue the Merchant's Daughter | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. |
| `rescue_merchant_daughter_3` | Return to the Merchant | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A ransom the merchant chose not to pay - that decision is the story and it is one clause long. |
| `rescue_missing_child_1` | The Missing Child | millbrook | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. |
| `rescue_missing_child_2` | Save the Child | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. |
| `rescue_missing_child_3` | Return the Child | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Hooded figures, a temple, a child. No cult motive, no deadline, no cost to the hamlet. |
| `rescue_sacrifice_victim_1` | The Ritual Sacrifice | millbrook | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. |
| `rescue_sacrifice_victim_2` | Stop the Sacrifice | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. |
| `rescue_sacrifice_victim_3` | Return the Rescued | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A full moon deadline that is never enforced or referenced again. |
| `rescue_soldier_1` | Missing Soldier | thornfield | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. |
| `rescue_soldier_2` | Free the Soldier | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. |
| `rescue_soldier_3` | Report to the Guard Captain | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A captain who loses a man and shows no feeling about it. |
| `rescue_wizard_apprentice_1` | The Missing Apprentice | thornfield | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. |
| `rescue_wizard_apprentice_2` | Free the Apprentice | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. |
| `rescue_wizard_apprentice_3` | Return the Apprentice | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Cultists draining a boy for his magic - stated, never made to matter. |
| `rescue_woodsman_1` | The Kidnapped Woodsman | elder_moor | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. |
| `rescue_woodsman_2` | Free the Woodsman | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. |
| `rescue_woodsman_3` | Return the Woodsman | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. The wife is the giver and has no line of her own. |
| `road_safety_1` | Road Safety | thornfield | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. |
| `road_safety_2` | Eliminate the Threat | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. |
| `road_safety_3` | Collect Your Bounty | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. Interchangeable with bandit_justice; nothing distinguishes the two chains. |
| `stolen_ledger_1` | The Stolen Ledger | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. |
| `stolen_ledger_2` | Recover the Ledger | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. |
| `stolen_ledger_3` | Return the Ledger | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. 'He may lose everything' is the stake and the quest never says to whom he owes it. |
| `stolen_relic_1` | The Stolen Temple Relic | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. |
| `stolen_relic_2` | Recover the Sacred Relic | - | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. |
| `stolen_relic_3` | Return the Relic | dalhurst | **ERRAND** | Three-beat chain written as three shipping labels: find it, kill it, hand it back. No giver motive in any beat, no worsening if abandoned mid-chain, and beats 2-3 carry no giver at all so the story has no voice after the first line. A relic with no name, no use and no reason a cult wants this one. |

### Wizard apprenticeship (Helvant)

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `wizard_aptitude_test` | The Spark Within | dalhurst | **ERRAND** | Fetch two reagents. Helvant's reason for testing strangers at all is missing, and failure costs nothing. |
| `wizard_field_test` | Practical Application | dalhurst | **ERRAND** | Four good utility beats with no one on the other end of them - no villager is named, nothing goes wrong if the well stays foul. |
| `wizard_final_trial` | The Adept's Challenge | dalhurst | **STORIED** | Rite of passage with a clear giver motive. Thin on consequence - passing and failing lead to the same world. |
| `wizard_first_lesson` | Elemental Foundations | dalhurst | **ERRAND** | Four essences and three kills. Pure checklist; no threat anywhere in it. |
| `wizard_lost_tome` | The Lost Grimoire | dalhurst | **ERRAND** | Dungeon errand. Helvant's stake (his own master's book) is stated in a clause and never felt. |
| `wizard_stolen_pages` | Ink and Blood | dalhurst | **STORIED** | Has three roads and a real antagonist. Missing: the branches are unreachable - no dialogue action calls them (already a standing warning). |

### Adventurer's Guild

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `adventurers_01_proving_ground` | Proving Ground | dalhurst | **ERRAND** | Kill 8 wolves as an entrance fee. Vorn's reason for taking anyone on is missing. |
| `adventurers_02_pest_control` | Pest Control | dalhurst | **ERRAND** | Warehouse rats. The merchants are 'desperate' in the abstract. |
| `adventurers_03_escort_duty` | Safe Passage | dalhurst | **ERRAND** | Halvard has cargo and no personality; the ambush is scripted scenery. |
| `adventurers_04_bandit_contract` | Bandit Elimination | dalhurst | **STORIED** | Second showcase. Four roads, giver motive on the page, consequences wired. |
| `adventurers_05_missing_team` | Missing in Action | dalhurst | **STORIED** | Real stake (the Guild's own dead) and a stated Guild value. Missing: no branch, no consequence for how it is handled. |
| `adventurers_06_monster_hunt` | The Beast of Millbrook | dalhurst | **ERRAND** | 'Livestock mutilated, travelers disappearing' with no Millbrook person attached, and a promotion as the only stake. |
| `adventurers_07_dungeon_delve` | Into the Deep | dalhurst | **ERRAND** | Map it, clear it, keep what you find. No threat at all - the danger is generic traps. |
| `adventurers_08_ogre_problem` | Giant Troubles | dalhurst | **STORIED** | Three roads including a non-violent best outcome. Missing: unreachable branches; the ogre has no wants of its own on the page. |
| `adventurers_09_rival_guild` | Professional Rivalry | dalhurst | **STORIED** | Five roads and a real rivalry. Missing: unreachable branches; the Iron Blades have no reason for undercutting. |
| `adventurers_10_dragon_rumor` | Smoke on the Horizon | dalhurst | **ERRAND** | 'Don't engage' is set up and never becomes a decision. Trophy hunt. |
| `adventurers_11_guild_politics` | Internal Affairs | dalhurst | **STORIED** | Corruption inside the employer, three roads including taking the bribe. Missing: the corrupt officer has no name and no motive. |
| `adventurers_12_legendary_contract` | The Impossible Contract | dalhurst | **ERRAND** | A loot run dressed as a legend. Nobody in the world is affected either way. |
| `adventurers_13_champion` | Legend in the Making | dalhurst | **ERRAND** | A title fight. Fine as a capstone; carries no threat and no world consequence. |
| `adventurers_repeatable_bounty` | Guild Bounty Board | dalhurst | **ERRAND** | Board wrapper. Acceptable as a system, but the framing has no voice. |

### Arcane Circle

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `mage_01_entrance_exam` | The Entrance Exam | dalhurst | **ERRAND** | Gather essence at a shrine. The Circle's reason for admitting anybody is absent. |
| `mage_02_library_duty` | Cataloging the Arcane | dalhurst | **ERRAND** | Shelving, with a dangerous tome found and filed. The danger is never allowed to be dangerous. |
| `mage_03_reagent_gathering` | Essence Collection | dalhurst | **ERRAND** | Three gathers. Why the Circle is short of reagents at all is the interesting question and is not asked. |
| `mage_04_enchantment_task` | First Enchantment | dalhurst | **ERRAND** | Fetch a silver ingot for a ritual. No stake; the ring is made either way. |
| `mage_05_rogue_mage` | Unsanctioned Magic | dalhurst | **STORIED** | Kill-or-persuade in a real OR group with a moral edge. Missing: the rogue has no name and no argument of her own. |
| `mage_06_artifact_recovery` | Lost Knowledge | dalhurst | **ERRAND** | Decades-long search compressed into 'go and get it'. No rival, no deadline. |
| `mage_07_thesis_project` | Original Research | dalhurst | **ERRAND** | Choose a specialisation and file paperwork. The choice sets nothing in the world. |
| `mage_08_magical_disaster` | Containment | dalhurst | **ERRAND** | Urgency asserted ('Time is of the essence!') with no clock and no cost. Nobody is hurt whether you hurry or not. |
| `mage_09_rival_circle` | The Shadow Circle | dalhurst | **ERRAND** | Introduces a recurring antagonist and gives it no goal beyond 'something catastrophic'. |
| `mage_10_forbidden_tome` | The Locked Section | dalhurst | **ERRAND** | Claims a morality test in its notes and ships no branch and no consequence. |
| `mage_11_planar_breach` | Beyond the Veil | dalhurst | **ERRAND** | Cosmic threat, zero local victims. Nothing near Crossroads is named as being at risk. |
| `mage_12_archmage_trial` | The Final Theorem | dalhurst | **ERRAND** | Examination. No threat, no consequence, and the Theorem is scenery. |
| `mage_13_council_seat` | The Inner Circle | dalhurst | **ERRAND** | Ceremonial duel. The seat changes nothing about the Circle or the town. |
| `mage_repeatable_research` | Guild Assignments | dalhurst | **ERRAND** | Deferred objective type `variable` - cannot be completed at all. Already on the dispositions list. |

### Iron Company

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `mercenary_01_enlistment` | Sign the Contract | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Enlistment trial with no reason the Company is recruiting. |
| `mercenary_02_drill` | Sword and Shield | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Drill. No threat; nothing is at stake in an obstacle course. |
| `mercenary_03_first_blood` | Baptism of Steel | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. First contract, generic bandit outpost, no client and no reason. |
| `mercenary_04_caravan_guard` | Gold on the Road | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Escort. Ashe is cargo with a name. |
| `mercenary_05_siege_support` | Breach the Walls | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Assault a stronghold. Who contracted it and what they want is never said. |
| `mercenary_06_hostage_rescue` | No One Left Behind | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. A hostage with no name and a ransom deadline with no clock. |
| `mercenary_07_command_trial` | Lead from the Front | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'Your tactical decisions determine their survival' - there are no decisions in the objectives. |
| `mercenary_08_rival_company` | Blood and Honor | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Description offers three resolutions; the data has one kill objective and no branch. |
| `mercenary_09_betrayal` | The Turncloak | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. A traitor with no name, no motive, and an execute-or-exile choice that is one objective with no consequence. |
| `mercenary_10_noble_war` | Proxy War | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'Morally gray' is claimed in prose and never expressed as a choice. The two houses are unnamed. |
| `mercenary_11_monster_battalion` | The Horde | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Defend Millbrook - the one quest here with a town to lose, and Millbrook is not characterised at all. |
| `mercenary_12_legendary_battle` | Hold the Line | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. 'This is your Thermopylae' with no consequence for losing and no named defenders. |
| `mercenary_13_second_command` | The Iron Will | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Promotion duel. No threat, no world change. |
| `mercenary_repeatable_contracts` | Company Contracts | dalhurst | **ERRAND** | Iron Company line has no branches anywhere in it: thirteen quests, zero choice_consequences. Wrapper with no voice. |

### Thieves Guild (guild/)

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `thieves_01_light_fingers` | Light Fingers | dalhurst | **ERRAND** | Steal a ledger. Horace is a shop, not a man, and getting caught costs nothing. |
| `thieves_02_plant_evidence` | Framed | dalhurst | **ERRAND** | Framing an innocent blacksmith is the strongest moral hook in the guild line and ships with no branch and no consequence for Marcus. |
| `thieves_03_fence_connection` | Moving Goods | dalhurst | **ERRAND** | Carry a package. The guards are decoration. |
| `thieves_04_debt_collection` | The Sailor's Debt | dalhurst | **ERRAND** | Notes promise 'multiple approaches, moral dilemma'; the data has one collect objective. Garrett is not written. |
| `thieves_05_blackmail` | Leverage | dalhurst | **ERRAND** | 'What you do with it is up to you' - and there is nothing in the file that lets you do anything with it. |
| `thieves_06_warehouse_job` | The Dalhurst Job | dalhurst | **ERRAND** | Three approaches named in prose, none in data. |
| `thieves_07_noble_heist` | High Society | dalhurst | **ERRAND** | Good set-piece; no one is harmed, no one reacts, nothing worsens if the sapphire stays on its stand. |
| `thieves_08_rival_gang` | Turf War | dalhurst | **STORIED** | Three genuine roads with different guild-reputation outcomes. Missing: the Crimson Blades have no leader and no grievance. |
| `thieves_09_informant` | Loose Lips | dalhurst | **STORIED** | Investigation with four fates for the traitor. Missing: the three suspects are names on a list. |
| `thieves_10_government_job` | State Secrets | dalhurst | **ERRAND** | 'A decree that could destroy the Guild' - never says what it decrees, so the threat cannot land. |
| `thieves_11_impossible_vault` | The Impossible Vault | dalhurst | **ERRAND** | Puzzle box. Nobody wants it, nobody loses it, no rival is racing you. |
| `thieves_12_guild_traitor` | Shadows Within | dalhurst | **STORIED** | Real misdirection and an OR group at the confrontation. Missing: no consequence data behind either road. |
| `thieves_13_right_hand` | The Guildmaster's Trust | dalhurst | **STORIED** | Three ambush sites with different risk. Missing: the convoy belongs to nobody in particular. |
| `thieves_repeatable_jobs` | Guild Contracts | dalhurst | **ERRAND** | Zero objectives in the file. Structurally empty. |

### Kazan-Dun succession

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `kazan_dun_01_the_stair_holds` | The Stair Holds | kazan_dun_entrance | **STORIED** | Nothing missing. Threat, giver motive and refusal-cost all on the page. |
| `kazan_dun_02_what_the_pits_held` | What the Pits Held | kazan_dun_level_1 | **STORIED** | Nothing missing. The word Morgrim will not say is the whole quest. |
| `kazan_dun_03_the_devourers_table` | The Devourer's Table | kazan_dun_level_1 | **STORIED** | Nothing missing. Three roads, one of which is shameful, and the [OPEN] mechanism stays open. |
| `kazan_dun_04_the_empty_chair` | The Empty Chair | kazan_dun_level_1 | **STORIED** | Nothing missing. Three roads, real politics, gates nothing. |

### Temple of Chronos

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `chronos_01_first_vision` | The First Vision | dalhurst | **ERRAND** | Meditate and fetch a token. The Priest's reason for testing strangers is absent. |
| `chronos_02_hourglasses` | Sands of Service | dalhurst | **ERRAND** | Three sands. Geography tour with no threat. |
| `chronos_03_late_delivery` | Time-Sensitive | dalhurst | **ERRAND** | 'Before nightfall' with no clock and no consequence for arriving late - which is the one thing a time-god quest must not get wrong. |
| `chronos_04_false_prophet` | The False Seer | dalhurst | **STORIED** | Two real readings of the same man. Missing: the seer is never given a reason to lie. |
| `chronos_05_devotion_choice` | The Timekeeper's Question | dalhurst | **STORIED** | Genuine fork with lasting flags. Missing: declining costs nothing and changes nothing. |
| `chronos_06_temporal_echo` | Echoes of What Was | dalhurst | **ERRAND** | Witness a vision, kill the guardians. What the player learns is never said, so nothing is at stake. |
| `chronos_07_paradox` | The Paradox Stone | dalhurst | **STORIED** | Destroy or harness, with different rewards. Missing: nobody is harmed by the loops, so the 'safe' choice is free. |
| `chronos_08_prophet_training` | Glimpses of Tomorrow | dalhurst | **ERRAND** | Three meditations. Training montage with no threat and no failure. |
| `chronos_09_timeline_threat` | When Time Bleeds | dalhurst | **ERRAND** | 'Time bleeds monsters' with no bleeding into anyone's life. No town, no victim. |
| `chronos_10_eternal_vigil` | The Eternal Vigil | dalhurst | **ERRAND** | Boss run. The Timeless One wants nothing and threatens no named place. |
| `chronos_repeatable_visions` | Seeking Visions | dalhurst | **ERRAND** | Repeatable flavour. Acceptable as a system; carries no threat by design. |

### Temple of Gaela

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `gaela_01_first_offering` | Seeds of Faith | dalhurst | **ERRAND** | Bring flowers. A struggling farmer is talked to and never helped. |
| `gaela_02_healing_herbs` | The Healer's Garden | dalhurst | **ERRAND** | Three gathers, no patient. |
| `gaela_03_protect_harvest` | Guardians of the Field | dalhurst | **ERRAND** | Wolves and rats at the crops with no farm and no farmer who loses one. |
| `gaela_04_sacred_grove` | The Sacred Grove | dalhurst | **STORIED** | Three roads through a real conflict of interests. Missing: the loggers have no foreman with a reason. |
| `gaela_05_devotion_choice` | The Mother's Embrace | dalhurst | **STORIED** | Genuine commitment fork. Missing: declining is consequence-free. |
| `gaela_06_blight_source` | Root of Corruption | dalhurst | **ERRAND** | Cultists maintaining a corruption with no motive and no victim named. |
| `gaela_07_spirit_of_land` | Voice of the Green | dalhurst | **ERRAND** | Free the spirit. Nothing is worse if it stays bound. |
| `gaela_08_seed_of_life` | The Eternal Seed | dalhurst | **ERRAND** | A plague in Thornfield used as a fetch-quest justification; no sick person is written. |
| `gaela_09_famine_threat` | When Harvests Fail | dalhurst | **ERRAND** | Regional famine as scenery. Three towns investigated, none characterised, nobody starves. |
| `gaela_10_lifebringer` | The Lifebringer | dalhurst | **ERRAND** | Ritual capstone. `accept_champion_title` is the only branch and it is not a choice. |
| `gaela_bonus_bountiful_harvest` | Bountiful Harvest | dalhurst | **ERRAND** | Four gathers for a festival that is never held. |
| `gaela_bonus_shepherd_quest` | The Lost Flock | millbrook | **ERRAND** | Lost sheep. The shepherd's livelihood is the obvious stake and is unstated. |
| `gaela_repeatable_tending` | Tending the Garden | dalhurst | **ERRAND** | Gardening. Fine as flavour; no threat by design. |

### Temple of Morthane

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `morthane_01_last_rites` | Final Rest | elder_moor | **ERRAND** | Perform rites on unburied dead. Who they were and why they lie unburied is the story, and it is not told. |
| `morthane_02_restless_spirit` | Unfinished Business | elder_moor | **ERRAND** | A ghost with unfinished business the quest never specifies. |
| `morthane_03_cemetery_duty` | Vigil of the Dead | elder_moor | **ERRAND** | Grave robbers with no motive - and no answer to the obvious question of what is worth stealing from a grave. |
| `morthane_04_necromancer_trail` | The Defiler's Path | elder_moor | **STORIED** | Three fates and a doctrine that permits mercy. Missing: the necromancer has no argument written for him. |
| `morthane_05_devotion_choice` | Embracing the Cycle | elder_moor | **STORIED** | Commitment fork with a near-death trial. Missing: declining changes nothing. |
| `morthane_06_death_speaker` | Voices Beyond the Veil | elder_moor | **STORIED** | A murder solved by the victim's own testimony - the best premise in the temple lines. Missing: victim, killer and motive are all unwritten. |
| `morthane_07_lich_rumor` | Whispers of Immortality | elder_moor | **ERRAND** | A man trying to become a lich, with no reason given for wanting it. |
| `morthane_08_rebirth_ritual` | The Second Chance | elder_moor | **ERRAND** | A dying woman consents to rebirth - all ceremony, no stake, no chance for it to go wrong. |
| `morthane_09_undead_army` | The Rising Tide | elder_moor | **ERRAND** | Waves at two towns. Neither town has a person in it. |
| `morthane_10_deathwalker` | The Deathwalker | elder_moor | **ERRAND** | Champion capstone. `become_champion` is not a choice. |
| `morthane_repeatable_cleansing` | Cleansing Duty | elder_moor | **ERRAND** | One kill objective and one line. Fine as a system, voiceless. |

### Staging (`_future/`, never loaded)

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `capital_intrigue` | Turmoil in the Capital | falkenhaften | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `journey_to_kazandun` | Journey to Kazan-Dun | dalhurst | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `larton_famine` | The Starving Coast | larton | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `missing_surveyors` | The Missing Surveyors | elder_moor | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `rat_problem` | The Rat Problem | aberdeen | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `tenger_scouts` | Scouts from the South | southern_outpost | **DEFERRED** | Staging dir, never loaded. Left as-is; reviving them is a scope decision, not a quality pass. |
| `the_false_queen` | The False Queen | falkenhaften | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `the_imprisoned_king` | The Imprisoned King | chamber_of_immortality | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |
| `the_kings_secret` | The King's Secret | falkenhaften | **DEFERRED** | Staging dir, never loaded. Touches the missing king and the elf claimant - both bible `[OPEN]`. Caleb's call, not a rewrite. |

### Towns and standalone

| Quest id | Title | Region | Verdict | What it is missing |
|---|---|---|---|---|
| `aberdeen_relief` | Aberdeen Relief | larton | **ERRAND** | A cut-off swamp town is a strong situation with no person in it - Bjorn sends 'desperate messages' that are never quoted. |
| `aberdeens_blessing` | Aberdeen's Blessing | aberdeen | **ERRAND** | Fetch a relic from a ruin. No consequence if the relic stays where it is. |
| `arena_tier_1` | First Blood | bloodsand_arena | **ERRAND** | Three rounds. Gormund has no reason to want this fighter specifically. |
| `arena_novice_tournament` | Trial of the Newcomer | bloodsand_arena | **ERRAND** | Nine opponents. Framing is a scoreboard. |
| `bandit_trouble` | Bandit Trouble | dalhurst | **ERRAND** | Board bounty. 'Before more innocent blood is spilled' is the only stake and it names nobody. |
| `chronos_false_prophet` | The False Seer | dalhurst | **STORIED** | Duplicate of chronos_04 at root with a third road (exploit the seer). Missing: unreachable branches, and the duplication itself. |
| `chronos_hourglass` | The Shattered Hourglass | dalhurst | **ERRAND** | Recover a stolen artifact. The bandits do not know what they took, which is interesting and never used. |
| `chronos_time_fragment` | Echoes of the Past | dalhurst | **ERRAND** | Collect artifacts before their power fades - a deadline stated and never enforced. |
| `dwarf_messenger` | Iron Words | elder_moor | **ERRAND** | 'The fate of dwarf-human relations may depend on it' and the letter's contents are never revealed, so nothing can depend on anything. |
| `eastern_wolves` | The Eastern Wolf Pack | thornfield | **ERRAND** | Thin the pack. Greta and Elric both exist and neither is given a reason to care. |
| `elven_ambassador` | The Elven Embassy | dalhurst | **ERRAND** | The best premise on the root list - a missing treaty and a collapsing peace - with no branch, no consequence and no failure state. |
| `fish_fraud` | Fishy Business | millbrook | **STORIED** | Three honest readings of a dispute, including siding with the accused. Missing: unreachable branches only. |
| `gaela_blight` | The Spreading Blight | dalhurst | **ERRAND** | Blight investigation duplicating gaela_06. No farmer, no lost harvest, no branch. |
| `gaela_sacred_grove` | The Sacred Grove | dalhurst | **STORIED** | Three roads. Missing: unreachable branches; duplicates gaela_04. |
| `gaela_seed_of_life` | Seed of Renewal | dalhurst | **ERRAND** | Sick villagers as a reason to enter a dungeon. None of them is written. |
| `ghost_pirate_investigation` | The Ghost Pirate Menace | larton | **ERRAND** | Blockaded port, which would starve Larton, treated as a boss location. |
| `ghost_ship_rumors` | Ghost Ship Rumors | dalhurst | **ERRAND** | Good atmosphere, no threat: the ship takes nothing from anyone on the page. |
| `guild_contract_bandits` | Bandit Elimination Contract | dalhurst | **ERRAND** | Camp, captain, report. The merchants who are being ambushed are never named. |
| `guild_contract_elite` | The Thornfield Terror | dalhurst | **ERRAND** | Well-written monster copy with no farmer, no lost herd and no consequence for leaving it alive. |
| `guild_contract_spiders` | Silk and Venom | dalhurst | **ERRAND** | Clear a mine. The fled miners are the stake and never appear. |
| `guild_contract_troll` | Bridge Toll | dalhurst | **STORIED** | Four roads including a negotiated toll. Missing: unreachable branches. |
| `guild_elite_trial` | The Elite Trial | dalhurst | **ERRAND** | Solo clear plus duel. Rite with no world consequence. |
| `guild_initiation` | Proving Ground | dalhurst | **ERRAND** | Duplicate of adventurers_01 with different objectives. Same missing pieces, plus the duplication. |
| `harbor_ghost_ship` | The Phantom Vessel | dalhurst | **ERRAND** | Lighthouse investigation with no owner, no missing crew named, and no ending in the objectives. |
| `keepers_artifact` | The Forbidden Relic | dalhurst | **STORIED** | Destroy or keep, with a stated cost for keeping. Missing: unreachable branches. |
| `keepers_confrontation` | The Shadow Revealed | dalhurst | **STORIED** | Four outcomes including partial failure. Missing: unreachable branches. |
| `keepers_cult_trail` | Following the Thread | dalhurst | **STORIED** | Stealth grades the outcome. Missing: unreachable branches. |
| `keepers_infiltration` | Among the Faithful | dalhurst | **STORIED** | Cover-blown is a real second outcome. Missing: unreachable branches. |
| `keepers_initiation` | The Keeper's Trust | dalhurst | **ERRAND** | Long, atmospheric, and structurally 'go there, kill them, come back'. No consequence for refusing. |
| `keepers_test` | Eyes in the Shadows | dalhurst | **ERRAND** | Three-town investigation whose finding is never stated. Nine objectives, no stake. |
| `lake_creature` | Terror in the Lake | millbrook | **ERRAND** | The village depends on the lake - stated once. No fisherman, no lost season, no alternative to killing it. |
| `logging_troubles` | Wolves in the Wood | elder_moor | **ERRAND** | Two dead woodsmen and a settlement short of winter timber, and neither fact is allowed to cost anything. |
| `lost_apprentice` | The Lost Apprentice | dalhurst | **STORIED** | Three fates for Marcus. Missing: unreachable branches. |
| `lost_woodsman` | The Lost Woodsman | thornfield | **STORIED** | Alive or dead, both written. Missing: unreachable branches; Harlen's family is not present. |
| `meet_the_arena_master` | Blood and Glory | elder_moor | **ERRAND** | A signpost quest. Acceptable as a pointer; no threat by design. |
| `merchant_protection` | Road Guard | thornfield | **STORIED** | Cargo intact, cargo lost, or bribed by bandits. Missing: unreachable branches. |
| `millbrook_bandits` | Trouble in Millbrook | millbrook | **STORIED** | The flagship. Nothing missing. |
| `miners_in_peril` | Frozen Tunnels | duncaster | **STORIED** | All saved or some lost - a real cost. Missing: unreachable branches. |
| `missing_miner` | The Missing Miner | aberdeen | **ERRAND** | A man missing three days. The mayor 'fears the worst' and the town loses nothing either way. |
| `morthane_cycle_broken` | The Broken Cycle | dalhurst | **ERRAND** | A region-wide undead rising with no settlement written into it. |
| `morthane_necromancer` | The Necromancer's Trail | dalhurst | **STORIED** | Three fates and a doctrine that allows mercy. Missing: unreachable branches. |
| `morthane_restless_soul` | Unfinished Business | dalhurst | **ERRAND** | A ghost, a keepsake, a loved one - three people, none of them named or given a line. |
| `noble_soulstone_request` | A Noble's Request | dalhurst | **STORIED** | Deliver or keep, with a daily-penalty debt for keeping. The only quest in the game where a soulstone is the point. |
| `retake_harbor` | Retake the Harbor | larton | **ERRAND** | Clear a warehouse. The survivors who need the supplies never appear. |
| `sailors_debt` | The Sailor's Debt | dalhurst | **STORIED** | Three roads on one drunk sailor. Missing: unreachable branches; Brennan has no reason for the debt. |
| `starving_south` | The Starving South | larton | **ERRAND** | A town facing starvation, resolved by a bureaucratic errand nobody obstructs. |
| `supply_line_crisis` | Supply Line Crisis | aberdeen | **ERRAND** | Has a genuine either/or in the objective text and no branch data behind it - the choice is not recorded anywhere. |
| `temple_blessing_quest` | The Three's Blessing | dalhurst | **ERRAND** | Two gathers. Nothing at stake. |
| `temple_prophecy_chronos` | Visions of Time | dalhurst | **ERRAND** | Duplicate of chronos_03. Same missing clock, same missing consequence. |
| `temple_undead_menace` | Cleanse the Restless Dead | dalhurst | **ERRAND** | Cemetery clear-out. The priest 'takes personal offense', which is the closest any bounty here gets to a motive, and it stops there. |
| `tenger_diplomacy` | Desert Parley | east_hollow | **STORIED** | Peace, trade or failure - and failure is a real outcome. Missing: unreachable branches. |
| `tharins_message` | A Message for Thornfield | elder_moor | **ERRAND** | Deliver a message. Explicitly framed as a trust test, which is a motive; nothing else. |
| `tharins_supplies` | Supply Run to Dalhurst | elder_moor | **ERRAND** | Collect a shipment. No threat anywhere. |
| `tharins_wolf_problem` | The Wolf Problem | elder_moor | **ERRAND** | One kill objective. The logging teams being attacked is stated in the description and nowhere else. |
| `keepers_letter_delivery` | A Letter for Dalhurst | elder_moor | **ERRAND** | Excellent prose, zero stakes: a sealed letter that stays sealed and a delivery nothing opposes. |
| `thieves_guild_heist` | The Dalhurst Job | dalhurst | **STORIED** | Four approaches including being caught. Missing: unreachable branches. |
| `thieves_guild_informant` | Loose Lips | dalhurst | **STORIED** | Four fates for Tomas. Missing: unreachable branches. |
| `thieves_guild_initiation` | Light Fingers | dalhurst | **STORIED** | Clean or caught. Missing: unreachable branches; the merchant is not a person. |
| `thieves_guild_mastermind` | The Big Score | dalhurst | **STORIED** | Three outcomes including keeping the haul. Missing: unreachable branches. |
| `thieves_guild_rival` | Turf War | dalhurst | **STORIED** | Four roads including absorbing the rival crew. Missing: unreachable branches. |
| `tutorial_alchemy` | Herbalism Basics | elder_moor | **ERRAND** | Craft one potion. Tutorial; no threat by design, but Brennan has no reason to teach a stranger. |
| `tutorial_cooking` | A Warm Meal | elder_moor | **ERRAND** | Cook one meat. Same. |
| `tutorial_crafting` | The Smith's Apprentice | elder_moor | **ERRAND** | Craft one dagger. Same. |
| `watermill_curse` | The Silent Mill | millbrook | **ERRAND** | The mill stops and the village cannot grind before winter - a real threat, stated once, with an objective list that ends on 'remove or appease the obstruction' and no outcome either way. |
| `whalers_debt` | The Canyon Ledger | whalers_abyss | **STORIED** | Full collection, mercy, or a bribe. Missing: unreachable branches. |
| `willow_dale_investigation` | Missing Caravan | dalhurst | **ERRAND** | A caravan and its men are missing; finding survivors is marked optional. Nothing turns on it. |
| `wolf_pack_menace` | Wolf Pack Menace | thornfield | **ERRAND** | Third wolf-pack quest in the region. No distinguishing threat, no reason Marek cannot do it himself. |

## Notes on duplicates found while reading

Not part of the brief, recorded because the reading surfaced them and a future
pass will otherwise rediscover them:

* `chronos_false_prophet` duplicates `chronos_04_false_prophet`; the root copy
  has a third branch (`exploit_seer`) the temple copy lacks.
* `temple_prophecy_chronos` duplicates `chronos_03_late_delivery`.
* `gaela_sacred_grove` duplicates `gaela_04_sacred_grove`; `gaela_blight`
  duplicates `gaela_06_blight_source`; `gaela_seed_of_life` duplicates
  `gaela_08_seed_of_life`.
* `morthane_restless_soul` duplicates `morthane_02_restless_spirit`;
  `morthane_necromancer` duplicates `morthane_04_necromancer_trail`;
  `temple_undead_menace` overlaps `morthane_03_cemetery_duty`.
* `guild_initiation` duplicates `adventurers_01_proving_ground`;
  `guild_contract_bandits` overlaps `adventurers_04_bandit_contract`.
* `thieves_guild_*` at root duplicates most of `guild/thieves/`;
  `sailors_debt` duplicates `thieves_04_debt_collection` with a different debtor.

Both copies of each pair were rewritten, and deliberately **not** merged: merging
would delete quest ids and break saves, which the brief forbids. Where a pair
exists the two copies were given different givers' angles on the same event so
they read as two people's business rather than one file printed twice.
