# Invention manifest

Every character, line of world-fact and quest beat written for steps 14, 15, 23
and 24 that is **not** already in `docs/world_story_bible.md`. Caleb authorised
invention within canon on 8/1; this file is the receipt, so anything he dislikes
can be found and pulled without reading the diff.

Columns: **what** · **where it lives** · **why it was needed** · **what in the
bible it is built on**.

The two rules the inventions obey:

1. The bible's `[OPEN — deliberately]` question — does this game reach the
   king's cave — is untouched. No content added here moves it one inch.
2. The goblin-king/soulstone mechanism stays `[OPEN]`. Goblins wanting to feed
   the dwarf king to theirs is canon and is written as canon; **why** it works
   is written only as rumour, theory and refusal-to-answer. Three characters
   guess at it, all three guesses contradict, and nobody is right on the page.

---

## Step 14 — Kazan-Dun succession arc

| What | Where | Why it was needed | Bible basis |
|---|---|---|---|
| **Thane Vurka Stonebrand** — leads the trial-by-combat side, holds the third gate, blunt and not certain she wins | `data/dialogue/trees/kazan_dun_thane.json`, `scripts/levels/kazan_dun_level_1.gd` (`dwarf_thane_challenger`) | The bible names "the other side" but no person. A faction with no face cannot be argued with, and the succession choice is the arc's payload | "The other side: demands trial by combat... originally they wanted to fight *the child*, which is why the uncle stepped up" |
| **Loremaster Dwalki Runeglass** — keeps the funeral rites and the muster rolls | `data/dialogue/trees/kazan_dun_loremaster.json`, `kazan_dun_level_1.gd` (`dwarf_loremaster`) | The bible makes the funeral rites the hinge of the whole arc ("cannot declare a new heir until the king's body receives proper funeral rites") without saying who performs them. Also the neutral turn-in for a choice between two rivals | "dwarves cannot declare a new heir until the king's body receives proper funeral rites" |
| The rite's exact rule: a dwarf king is dead when he has burned on his own hearthstone and the Loremaster has struck his name through | `kazan_dun_loremaster.json` node `the_rites` | The bible says rites gate the succession; the *content* of the gate had to be sayable in one paragraph to a player | Same line as above |
| Vurka named the infant as a claimant because the rite names every living claimant, and a champion would have stood for him | `kazan_dun_thane.json` node `the_accusation` | Makes the "will-they-won't-they fight a baby" readable as a political manoeuvre rather than cartoon villainy, so backing her is a real option | "originally they wanted to fight *the child*, which is why the uncle stepped up in his place" |
| **The muster roll** — Morgrim held a hundred axes back at the council chamber the night his brother went into the pits, and never explained it | `kazan_dun_thane.json` node `the_roll`, `kd_regents_roll` interactable in `kazan_dun_level_1.gd`, objective `undercut_the_regent` | The bible asks for "maybe *weaken the uncle* so the other side wins, for some benefit" and gives no lever. This is that lever, and it is ambiguous on purpose — the roll proves he held them back, not why | "Maybe *weaken the uncle* so the other side wins, for some benefit" |
| Three roads off Skarrag's table: kill him · bring the ritual gallery down · trade the dwarves' soulstone stash for the body | `data/quests/kazan_dun/kazan_dun_03_the_devourers_table.json`, `kazan_dun_level_5.gd` | Step 14 asks for OR groups; the bible supplies one goal (recover the body from goblin-held depths) and one bargaining chip (the stash the goblins want) | "the player must recover the body from goblin-held depths"; "the dwarves hold a large stash of soulstones... the goblins with the soul gems + eating the king will do *something*" |
| Three contradictory theories about the soulstones, none endorsed: a vessel · a mockery · "the stones do exactly what they were made to do, and we never knew what we made" | `kazan_dun_loremaster.json` node `the_stones` | The mechanism has to be *present* in the fiction without being answered. Three guesses that cannot all be true is how you write an open question without a shrug | `[OPEN]` "Goblin king + soulstones + eating the dwarf king — what does it actually do?" — deliberately not resolved |
| Loremaster's refusal: "We cut them. There is a difference between cutting a thing and making it" | `kazan_dun_loremaster.json` node `the_stones_2` | Puts a door in the wall so a later ruling from Caleb has somewhere to enter | Same `[OPEN]` |
| Gate Warden Borik given the opening skirmish quest | `scripts/levels/kazan_dun_entrance.gd` | The chain needed a doorway at the gate; Borik already existed, spawned, with a written voice — reuse over invention | "after a couple of skirmishes, the dwarf king is found dead" |
| Items: **Grave Ale** (+3 Grit, 90s), **Deep Gate Key**, **Hold-Friend Token** (dwarven discount) | `data/items/` | Rewards must exist for the validator and must have a use per the item-purpose philosophy. The token is also the carrier for step 15's dwarf gratitude | "Help them → rewards and unique interactions later down the road" |

**Deliberately NOT invented:** why the goblins want stones and a corpse together;
what Skarrag becomes if he succeeds; whether Vurka or Morgrim wins the trial (the
quest ends when the rite is *called*, not fought); anything touching the human
king's cave.

**Retired as superseded:** `data/quests/_future/kazan_dun_succession.json`,
`kazan_dun_succession_choice.json`, `kazan_dun_traditionalist_path.json`,
`kazan_dun_rite_seeker_path.json`. They told the same story with different names
(Regent Borin — colliding with Gate Warden Borik — and Thane Grimjaw, colliding
with the existing companion `grimjaw`), were gated behind a prerequisite chain
that does not exist, and referenced four items and two NPCs that were never
built. The live chain in `data/quests/kazan_dun/` replaces them.

---

## Step 15 — World-reacts pass

| What | Where | Why it was needed | Bible basis |
|---|---|---|---|
| Arriving at Falkenhaften is the moment the south stops waiting. No `kazan_dun_helped` on arrival → `kazan_dun_fallen` is written, permanently | `scripts/levels/falkenhaften.gd` (`_settle_the_south`) | The bible ties the fall to "by the time the player reaches the kingdom". Falkenhaften is the ruled capital and the Act I→II hinge, so it is the honest trigger — not a timer, not a level count | "Skip it → by the time the player reaches the kingdom, Kazan-Dun is completely overrun by goblins" |
| Fallen-hold state of the entrance: the same nine posts, goblins standing in them, no Gate Warden | `scripts/levels/kazan_dun_entrance.gd` (`_spawn_fallen_hold`) | "Visiting shows the fallen fortress" needed a cheap, readable form. Reusing the exact dwarf posts makes it the same room with the wrong people in it | "the player hears about the fall from NPCs, and visiting shows the fallen fortress" |
| The Great Hall cast does not spawn if the hold fell | `scripts/levels/kazan_dun_level_1.gd` | Otherwise Morgrim is arguing about a chair in an overrun fortress | Same |
| **Hold-friend pricing**: dwarven traders take 25% off for a player who saved the hold (30% carrying the token), and add 15% if the hold fell | `scripts/characters/npcs/merchant.gd` (`get_world_price_modifier`, new `faction_id` export) | "Rewards and unique interactions later down the road" needed a mechanical form that is not a quest. Hung off the world fact, not an inventory check, so it survives selling the token | "Help them → rewards and unique interactions later down the road" |
| **Durn Shieldbearer** — a Kazan-Dun hearth-guard the hold lends the player after the succession is settled. Tower shield, taunt, no conversation in him | `data/followers/durn_shieldbearer.json`, offer node in `data/dialogue/trees/kazan_dun_loremaster.json` | The dwarf companion offer hook step 15 asks for. No dwarf follower existed — the nearest, Grimjaw, is a half-orc | Same "unique interactions later down the road" |
| 10 Kazan-Dun rumour lines, gated on the world facts: 4 for the fall, 3 for the hold standing, 3 for which way the succession went | `data/dialogue/pools/rumors.json` | Design law #1: consequences surface later, through people talking, not through a notification | "the player hears about the fall from NPCs" |
| 5 elf-claimant rumour lines naming **Sylvaine** and **Corwin** — ungated, low weight, all hearsay, all contradictory in tone | `data/dialogue/pools/rumors.json` | The claimant is Act I *chatter* and Act II *plot*. Nothing here confirms the boy is the king's son, nobody in Act I has met either of them, and no quest, flag or NPC references them | "sprinkled into Act I — NPCs talk about it in passing, nothing more"; the truth (the boy IS the king's son) is deliberately absent from every line |

**Deliberately NOT invented:** any way to meet Sylvaine or Corwin; any Act I
confirmation or refutation of the claim; anything about the king's whereabouts.
The rumour lines are the entire Act I surface of that plot, exactly as ruled.

---

## Step 23 — Millbrook bandit takeover

Built on established Millbrook lore only: an existing hamlet, an existing elder
(`millbrook_elder`, "Elder Bram"), two existing victims, an existing quest id
(`millbrook_bandits`) and an existing but **empty and script-less** camp scene.

| What | Where | Why it was needed | Basis |
|---|---|---|---|
| **Chief Corla Vane** — runs the crew, has a standing rule about the mill, argues in arithmetic rather than menace | `data/dialogue/trees/millbrook_bandit_chief.json` | Four of the five roads are things you say to a person. The old quest had a nameless "bandit captain" who existed only as a kill count | Existing quest text: "I saw the bandit captain - scarred face, black cloak"; `bandit_boss.tres` |
| **Quartermaster Pell** — keeps the ledger, has written down four chiefs, none of them elected | `data/dialogue/trees/millbrook_bandit_quartermaster.json` | The usurp road needs somebody to *say* the player is chief. A crew that keeps books is also why the takeover has an income to inherit | `bandits.tres` faction description: "shares of the take and a short memory for men who cost them money" |
| Elder Bram's careful non-answer, and the plain answer if you push him | `data/dialogue/trees/millbrook_elder.json` | The quest's premise is a man who wants a thing done and does not want to have asked. It also makes all five turn-ins land differently on the same character | Existing NPC; existing quest premise |
| Five turn-in scenes including the two where the player is now the problem | `millbrook_elder.json` | "Join" and "usurp" are quest completions from the player's side and betrayals from the hamlet's. The elder counting the reward out in front of a man who now runs the crew is the whole design statement | Design law #1 |
| **The camp itself** — clearing, treeline, fire ring, four tents, the crew's six posts, a road east from the hamlet and back | `scripts/levels/millbrook_bandit_camp.gd`, `_spawn_road_east` in `scripts/levels/millbrook.gd` | `scenes/levels/millbrook_bandit_camp.tscn` existed with a broken script reference, no geometry and nothing reachable pointing at it. The quest's "find the camp in the eastern woods" objective had never been completable | Existing scene stub; every victim line says "the eastern woods" |
| Camp reads its own outcome on every visit: razed and bought camps are empty, a camp under terms or under the player's oath does not attack him, a camp he runs pays him | `millbrook_bandit_camp.gd` | Design law #1 again, at the scale of one clearing | — |
| The standing arrangement: 25g/day crew share, +4/day town-guard hostility, −2/day Mill Brook reputation, all tagged `bandit_boss` | `_apply_boss_arrangement` in `millbrook_bandit_camp.gd` | Step 23 asks the ongoing-effects ticker to be exercised. Pell states all three consequences out loud before the player commits | `bandits.tres` Chief rank benefit `extortion_income` |
| Corla's price is 300 gold; her terms are a tenth of the mill's take, taken openly, in exchange for the crew standing between the hamlet and the next crew | chief dialogue | Bribe and negotiate must be *different* answers, not two buttons with the same result. Terms leaves the crew in the world; the bribe removes it and puts it on somebody else's road | — |

**Engine, for this step:** `join_faction` dialogue action (front door and the
`force`/`force:Rank` door), so the join and usurp roads are data rather than
special-case code. Validator taught to see a branch fired by a world object's
`choice_consequence`, not only by a dialogue action.

**Deliberately NOT invented:** who the crew were before; any connection between
this camp and the organised bandits on the Falkenhaften road (the bible has
those and they are a different, larger thing); anything about Mill Brook's
shrine or priest, which `wave_b_dispositions.md` still holds for Caleb.

---

## Step 24 — Second showcase + faction spread

### The showcase: `adventurers_04_bandit_contract`

| What | Where | Why it was needed | Basis |
|---|---|---|---|
| Four roads through the contract: take the outpost apart · bring the captain back alive · one quiet throat and let the crew scatter · warn them, take their purse, tell Vorn they had gone | `data/quests/guild/adventurers/adventurers_04_bandit_contract.json` | The counterpart to the Millbrook flagship, and a deliberately different flavour: Millbrook is a hamlet asking a stranger for help, this is an employer handing over a contract with a word in it he hopes you will interpret | Existing quest premise: the Guild is *hired* to eliminate |
| Vorn's four turn-in scenes, including the one where he writes "dispersed" on the contract and your name beside it | `data/dialogue/trees/guildmaster_vorn.json` | The quest's meaning lives in his reaction, not in the reward table. He prefers the quiet execution and cannot say so; he knows you sold the contract and pays you anyway | His written voice in the existing tree |
| Old objective "kill 8 bandits" dropped | same quest | It forced the assault road onto every path, which is the opposite of a multi-path quest | — |
| `locate_camp` repointed `crossroads_bandit_camp` → `bandit_camp_east` | same quest | `crossroads_bandit_camp` has never existed in `world_grid.gd` or on disk. `bandit_camp_east` is the built "Bandit Outpost" | Repoint, not invention |
| The eastern outpost now records that it was found and that it was emptied | `scripts/levels/bandit_camp_east.gd` | So `locate_camp` and `killed_the_captain` pre-complete for a player who cleared it before taking the contract — the same New Vegas moment as the Millbrook flagship, in a second place | Step 21's `world_condition` |

### The spread: ten quests whose branches nobody could reach

Step 12 catalogued 42 quests carrying `choice_consequences` that no dialogue
action ever fired. Ten are now live — **34 branches**, validator warnings 310 →
276. Almost none of this was invention: most of these quests already had branch
turn-in prose written and abandoned.

| Faction | Quests activated | Branches | Notes |
|---|---|---|---|
| Adventurers Guild | `adventurers_04_bandit_contract`, `adventurers_08_ogre_problem`, `adventurers_09_rival_guild`, `adventurers_11_guild_politics` | 15 | **`guildmaster_vorn.json` was never attached to Guildmaster Vorn** — the entire thirteen-contract Guild line existed as a written dialogue tree nobody could open. Attached in `dalhurst.gd`. Its 09 and 11 branch nodes were already authored and simply never fired a consequence; 04 and 08 got new branch scenes, and 09's bribe road had no node at all |
| Thieves Guild | `thieves_guild_informant`, `thieves_guild_rival` | 8 | New turn-in hubs on `thieves_guild_fence.json`. The Fence's read on each outcome is the content: every road works today and costs something in two years |
| The Keepers | `keepers_artifact`, `keepers_confrontation` | 7 | New hubs on `aldric_vane_keepers.json`. Aldric believes whatever you tell him, and says so before you answer |
| Temple of the Three | `gaela_04_sacred_grove`, `chronos_07_paradox` | 5 | New hubs on `priest_gaela_dalhurst.json` and `priest_chronos_dalhurst.json` |

**Defect found and fixed:** every turn-in choice in `guildmaster_vorn.json`
tested `quest_state == 1` (AVAILABLE) against a quest that is `2` (ACTIVE) once
started, so thirteen turn-ins could never appear even if the tree had been
attached. 13 conditions corrected.

**Defect found and left alone:** these trees use `"type": "flag"` for
conditions, which `DialogueLoader` does not recognise and treats as NONE — the
choice always shows. Correcting it to `flag_set` would hide branch choices
whose flags nothing sets, making several quests unturninable. The current
behaviour (the player states what he did) is what the content was written for.
Left as-is deliberately; noted here so nobody "fixes" it in isolation.

### Tabled — 27 quests, 70 branches still unreachable

Not activated, and each needs something no file supplies:

| Quest | Branches | Why it was tabled |
|---|---|---|
| `guild_contract_troll` | 4 | Vorn's tree has no node for it; the contract quests sit outside the numbered Guild line and need their own hub |
| `thieves_guild_heist`, `thieves_guild_mastermind`, `thieves_guild_initiation` | 9 | Turn in to `guildmaster_nightshade` / `guild_mastermind` — `wave_b_dispositions.md` holds the question of whether the mastermind IS Nightshade, and that is a story call |
| `keepers_cult_trail`, `keepers_infiltration` | 6 | Branches are *stealth outcomes* ("perfect_stealth", "cover_blown"), which the stealth system has to report, not a dialogue choice. Wiring them to a menu would be a lie |
| `morthane_04_necromancer_trail`, `morthane_06_death_speaker`, `morthane_10_deathwalker` | 6 | Giver is `priest_morthane_elder_moor`, who has no dialogue tree at all (the Dalhurst priest's tree is a different NPC) |
| `chronos_04_false_prophet`, `chronos_05_devotion_choice`, `gaela_05_devotion_choice`, `morthane_05_devotion_choice`, `gaela_10_lifebringer` | 9 | The devotion choices are already made through the devotee ritual nodes; wiring a second door would let a player take devotion twice |
| `chronos_false_prophet`, `gaela_sacred_grove` | 6 | Duplicates of the `temple/` versions under old ids. Which id survives is a cleanup decision, not a wiring one |
| `lost_apprentice`, `lost_woodsman`, `miners_in_peril`, `merchant_protection` | 10 | Branches are *rescue outcomes* — who lived. They belong to the escort/rescue code reporting a result, not to a menu |
| `sailors_debt`, `whalers_debt`, `fish_fraud` | 9 | Turn in to NPCs on the `wave_b_dispositions.md` list (`head_fisherman_millbrook`, the Larton figures) |
| `noble_soulstone_request` | 2 | Giver `noble_hakon` is unspawned and on the dispositions list |
| `tenger_diplomacy` | 3 | Giver `khan_toghrul`; the bible's Tegnar question is `[OPEN]` |
| `morthane_necromancer` | 3 | Two differently-named necromancers in one line; dispositions list asks Caleb whether they are one villain |
| `wizard_stolen_pages` | 3 | Wizard questline giver is `thornfield_wizard`, unspawned, on the dispositions list |

**Nothing here was invented to make a number move.** Where a branch could not be
reached without inventing a person, a place or a ruling, it stayed unreachable
and went in this table.

---

## Wave B backlog — stage 1: the eight missing factions

| What | Where | Why it was needed | Basis |
|---|---|---|---|
| **Merchant Guild** — chartered traders, Blacklisted→Guild Master, joinable at 25 | `data/factions/merchant_guild.tres` | 18 reputation changes named it (10 as `merchant_guild`, 8 as the near-miss `merchants_guild`, now repointed) and every one was dropped on the floor | The caravan/courier/market chains already treat it as an institution with standing |
| **The Common Folk** — not an organisation, unjoinable, Feared→The Province's Own | `data/factions/common_folk.tres` | 10 bounties and rescue chains thank "the common folk" | CLAUDE.md's faction reputation system; the hamlets already exist as factions, this is what they share |
| **The Noble Houses** — sub-faction of `human_empire`, starts at −10 | `data/factions/nobility.tres` | The soulstone request and the gala heist both move noble reputation | Bible: a crumbling empire with an empty throne for twenty years — the houses stopped waiting for orders |
| **Hunters' Lodge** — a board and a bounty box, joinable at 25 | `data/factions/hunters_guild.tres` | Three wolf/wyvern bounties pay into it | The bounty board already exists as an interactable; this is who runs the beast half of it |
| **The Athenaeum** (`scholars_guild`) — libraries and antiquarians | `data/factions/scholars_guild.tres` | `cursed_tome_3` pays into it | `scenes/levels/athenaeum.tscn` already exists; this is its faction |
| **The Shadowed Hand** — hidden cult, starts at −20 | `data/factions/shadowed_hand_cult.tres` | Four Keeper quests move its standing | The Keepers already have an enemy in the quest data with no resource behind it |
| **Aberdeen**, **Larton** — settlement factions on the relief road | `data/factions/aberdeen.tres`, `larton.tres` | `supply_line_crisis` pays both | Both are real grid locations with built scenes |

**Deliberately NOT invented:** who leads any of them; where the Shadowed Hand's
cult meets; whether the Merchant Guild has a hall the player can enter.

---

## Wave B backlog — stage 2: the residents the quests named by role

Thirty-eight quest references wanted "the merchant in Dalhurst", "the healer in
Mill Brook", "the guard captain". Each is now a named person standing where their
quests expect them, with a conversation archetype — so the Wave C tiers give them
their trade's voice for free — and one line in their own words. None has art of
its own; see `art_replacement_manifest.md`.

**Engine, for this stage:** `Townsfolk.spawn_townsfolk()`
(`scripts/characters/npcs/townsfolk.gd`) — one call for the six things every resident needs.
`tools/validate_content.gd` was taught to read ids out of it, exactly as it
already does for `spawn_quest_giver` and `spawn_from_registry`.

### Repointed, not invented

`dalhurst_innkeeper`→`innkeeper_dalhurst` · `thornfield_merchant`→`thornfield_trader` ·
`millbrook_farmer`→`farmer_edda` · `mine_foreman_duncaster`→`duncaster_foreman` ·
`logging_foreman` and `logging_foreman_elder_moor`→`foreman_garvek` ·
`guild_members`→`thieves_guild_recruiter` (thieves_13 wanted a roster, and the
Guild's recruiter already keeps one) · `garrett_sailor`→`debtor_garrett` — the
Whaler's Abyss debtor **is** the Crossroads debtor, because a man who owes the
Guild two hundred gold does not stay at the Crossroads; quest prose updated to
match.

### Split, because one id carried more than one person

| Old id | Now | Why |
|---|---|---|
| `millbrook_civilian` (6 refs) | `millbrook_widow` (Hild Marrow), `millbrook_witness` (Colm the Stallhand), `millbrook_mother` (Anwen Fell) | A widow, a market witness and the mother of a taken child were three griefs sharing one id. They are three women |
| `elder_moor_civilian` (6 refs) | `elder_moor_old_woman` (Hester Crow), `elder_moor_woodsmans_wife` (Bridget Hale) | The heirloom's "old woman" and the woodsman's family are not the same household |

### Invented residents

| Who | id | Where | The one thing that makes them a person |
|---|---|---|---|
| **Corvin Ashford**, market merchant | `dalhurst_merchant` | Dalhurst market | Four chains wanted "the merchant in Dalhurst"; he owns all four, and is one man having a very bad year rather than four flat people |
| **Lector Ysolde Bramwell** | `dalhurst_scholar` | Dalhurst reading room | RULING: the Dalhurst library **is** the Athenaeum's reading room, not a second building. She buys books the temple would rather she did not |
| **Padraig**, beggar | `dalhurst_witness` | A Dalhurst doorway | "Somebody saw something" is a man who gets looked past all day and knows what that is worth |
| **Old Ketch Dougal** | `old_fisherman_dalhurst` | Dalhurst quays | RULING: not Larton's Old Salt Willem — two ports, two old men |
| **Nerys Corrin** | `widow_dalhurst` | Dalhurst | The restless soul's widow. People tell her kindly that they have seen him, which is worse |
| **Sergeant Baird Holt** | `iron_company_veteran` | Dalhurst billet | Knows every man in the billet, which is exactly why the betrayal quest hurts |
| **Kerenza Doyle** | `guild_witness` | Dalhurst guild hall | Indiscreet; the only one saying the missing-adventurer number out loud |
| **Ivo Renn**, clerk | `inside_contact` | Dalhurst magistrate's office | The Guild's plant is a clerk, because nobody has ever wondered where a clerk goes at night |
| **Quillan the Ferret** | `informant_crossroads` | Dalhurst, works the Crossroads road | Sells the same story twice and both buyers are happy |
| **Greta Vance** | `millbrook_merchant` | Mill Brook stall | Counts the goods in at dusk and the two numbers disagree |
| **Colm the Stallhand** | `millbrook_witness` | Mill Brook stall | Will name the thief, and has to stand at that stall tomorrow |
| **Sister Rowena Ash** | `millbrook_priest` | Mill Brook shrine | RULING: Mill Brook's shrine keeps **Gaela** — it is a milling and fishing hamlet, and Gaela decides whether there is anything to mill |
| **Sorcha Linn**, herbwife | `millbrook_healer` | Mill Brook | RULING: healer and priest are two people. The shrine prays; she boils something bitter |
| **Tavish Moor**, shepherd | `millbrook_shepherd` | The pasture above the brook | Counts to forty-one and calls that a good morning |
| **Hamish Roke**, innkeep | `millbrook_innkeeper` | Mill Brook | RULING: yes, the hamlet has an inn — four beds, three of them usually free |
| **Eamon Quist** | `head_fisherman_millbrook` | Mill Brook docks | Hector's counterweight: thirty years of weighing fish against one merchant's scales |
| **Watch-Captain Ingram Vell** | `guard_captain_millbrook` | Mill Brook road | He is the whole watch, and says so as arithmetic rather than as an excuse |
| **Widow Hild Marrow** | `millbrook_widow` | Mill Brook | Knows the locket is not worth the fee and asks anyway |
| **Goodwife Anwen Fell** | `millbrook_mother` | Mill Brook | "She went to the brook for water and she did not come back up the path" |
| **Watch-Captain Osbert Dunmoor** | `elder_moor_guard` | Elder Moor camp | RULING: the watchman `guard_elder_moor_1` stays a GuardNPC; the chain's "guard captain" is his officer, and the chain exists *because* neither of them can leave the camp |
| **Goodwife Hester Crow** | `elder_moor_old_woman` | Elder Moor | Knows exactly what the ring is worth and that is not why she wants it |
| **Bridget Hale** | `elder_moor_woodsmans_wife` | Elder Moor lumber camp | "The north crew came back without him, and nobody will say more than that" |
| **Master Lavinia Wyke** | `thornfield_wizard` | Thornfield | RULING: a **third** Circle wizard, posted east and forgotten. Dalhurst's two are both Dalhurst's |
| **Godfrey Larke**, innkeep | `thornfield_innkeeper` | Thornfield market | Everyone who comes east comes through his door, and everyone who comes through his door talks |
| **Nuala Birch**, healer | `thornfield_healer` | Thornfield | Thornfield has no temple, so she is the whole of its medicine and she is out of everything |
| **Struan Ryke**, farmer | `thornfield_farmer` | Thornfield slope | Knows how far the thing carried a full-grown ox, and would rather not have learned it |
| **Trade Master Petra Halloran** | `trade_master_larton` | Larton wharf | RULING: Trade Master is a **Larton port office**, not an imperial rank. Every week she decides which town eats |
| **Magistrate Uther Craine** | `imperial_magistrate` | Larton | RULING: the empire's civil authority in the south is one man with a seal and no soldiers. "Where it goes after that has not been answered in nineteen years" — the empty throne, felt at a desk |
| **Mayor Ysolde Kerr** | `whaelers_abyss_mayor` | Whaler's Abyss | Governs a canyon full of people who came there to stop being asked questions, so she does not ask many |
| **Yoren the Carter** | `caravan_survivor` | Willow Dale ruins | RULING: yes, one man survived. He got under the cart and counted every one of them walking past |

**Deliberately NOT invented:** any Crossroads settlement (the grid calls the
Crossroads a cultist-ruined dungeon and three quests want a tavern there — held
in `wave_b_dispositions.md`); Mill Brook's shrine building; a Thornfield temple;
the Athenaeum's relationship to the Arcane Circle beyond "allied".

---

## Wave B backlog — stage 3: the lore-bound characters, and the Aldric collision

### The Aldric collision, resolved

The bible adopted **Aldric** for the missing king and flagged that Dalhurst
already had three. It had more than three. Seven things in shipped content were
called Aldric, four of them people the player can walk up to:

| Was | Now | Why |
|---|---|---|
| **King Aldric** — the missing king | **Aldric**, unchanged | The bible's adopted name. He keeps it, and he keeps it alone |
| **Master Aldric**, `wizard_dalhurst` | **Master Edric Vayle** | Display text only; the id was already name-agnostic |
| **Aldric Vane**, `aldric_vane`, the Keepers contact | **Severin Vane** | Surname kept — the Keepers' whole line, the letter quest and Tharin's dialogue all lean on "Vane" |
| **Senior Mage Aldric**, `mage_aldric_dalhurst` | **repointed to `wizard_dalhurst`** | RULING: he was never a second wizard. Dalhurst's senior enchanter is Master Edric Vayle, and mage_04/mage_08 are now his |
| **Aldric the merchant**, `aldric_the_merchant` (Crossroads) | **Talbot Ashe**, `merchant_talbot`, in the Dalhurst market | RULING: the escort runs Dalhurst → Crossroads → Thornfield, so meeting him in Dalhurst gains the quest the whole road instead of losing it |
| **Mayor Aldric Brennworth** (Larton blueprint, harbour dialogue) | **Mayor Kendrick Brennworth** | Rename only |
| **Captain Aldric Iron**, the Iron Company's dead founder | **Captain Hadrian Iron** | Rename only |
| **Guildmaster Aldric** (Falkenhaften) | **Guildmaster Wulfric** | Rename only |
| **Brother Aldric** (Pola Perron library) | **Brother Anselm** | Rename only; marker and id renamed with him |
| "the merchant Aldric" / "Lord Aldric" in the conversation pools | **Corvin Ashford** / **Lord Hakon** | Both are now real people standing in Dalhurst, so the rumour points at somebody |
| "Aldric" in the innkeeper, character-creation and lexicon random name pools | removed | So no procedurally-named villager is ever called Aldric again |

`raven_thief_contact.json` frames a Dalhurst shop merchant for counterfeiting.
That merchant is now **Corvin Ashford**, the same man four other chains send you
to — which makes the Thieves Guild's cruellest early job land on somebody the
player has already helped.

### Other collisions ruled

* **Elara** named three people: the Arcane Circle's `archmage_elara_dalhurst`, a
  Priestess of Gaela, and a dying merchant in `morthane_08`. The merchant is now
  **Ilsabet Corr** (`dying_merchant_ilsabet`) and was carried off the Crossroads
  road to the Shrine of Endings at Elder Moor, which is where the Priest of
  Morthane who gives the quest actually stands.
* **Necromancer Aeris / Necromancer Valdris** were two names in one questline.
  RULING: one villain. Everything is **Valdris** now, matching the existing
  `lich_aspirant_valdris` enemy id.
* **`guild_traitor`** was one id doing duty for two unrelated traitors in two
  guilds — a data bug. Split into `guild_traitor_adventurers` (Officer Malcolm
  Rede) and `guild_traitor_thieves` (Sable Quint).
* **`guild_mastermind`** repointed to `guildmaster_nightshade`. RULING: the
  mastermind IS Nightshade. She runs the Guild from behind her own counter and
  briefs the Ashford gala heist herself; a separate unseen mastermind was a
  layer with nobody in it.
* **Brennan** appears twice — Elder Moor's Old Sage Brennan and the indebted
  sailor. RULING: two men, and the coincidence stays. The sailor is
  **Brennan Locke**, in the Dalhurst harbour.

### Characters spawned

| Who | id | Where | Ruling |
|---|---|---|---|
| **Lord Hakon Greyfell** | `noble_hakon` | Dalhurst | The first noble house with a name on it. House Greyfell has held the coast since before the throne emptied and does not ask for things |
| **Lady Venetia Harrow** | `noble_client` | Mill Brook | The other end of the noble war. She is buying an outcome, not a battle |
| **Commander Roderic Brackmoor** | `enemy_commander` | Crossroads | The house on the other side. He wants to keep as many of his four hundred as he is allowed to |
| **Officer Malcolm Rede** | `guild_traitor_adventurers` | Dalhurst guild hall | |
| **Sable Quint** | `guild_traitor_thieves` | Dalhurst thieves' den | "I sold names. You would have sold names" |
| **Corporal Nils Hark** | `iron_company_traitor` | Dalhurst billet | |
| **Captain Dane Ferrow**, Iron Blades | `iron_blades_leader` | Thornfield | RULING: the rival company is not a conspiracy, it is a calendar — they sign the contracts Vorn's people are slow on |
| **Captain Vashka Kolt**, Black Wolves | `black_wolf_captain` | Crossroads | |
| **Brennan Locke** | `sailor_brennan` | Dalhurst harbour | |
| **The Drowned Man** | `restless_ghost` | Dalhurst, at night | RULING: he is a talk target, not a monster. His widow is thirty yards away and does not know he is there |
| **Dorn Vrell** | `merchant_vrell` | Mill Brook | RULING: the murderer is the affable one, and he brings up the debt himself |
| **Brother Wendel Pyke** | `false_prophet_millbrook` | Mill Brook | RULING: two charlatans, not one man in two towns. Warning costs a candle |
| **Seer Ambrose Tine** | `false_seer_thornfield` | Thornfield | "Asked to leave two towns for being right too early" |
| **High Chronist Cassian Mere** | `high_chronist_thornfield` | Thornfield | RULING: the "Temple of Time in Thornfield" is a shrine-stone and a water clock under an awning. **The temple building is not invented** — that is level design and stays Caleb's |
| **Gurm**, the troll on the bridge | `bridge_troll` | Crossroads | RULING: he talks. `guild_contract_troll` has a bribe branch and a fair-toll branch, and a monster cannot take a toll |
| **Tomas Redd** | `tomas_informant` | Crossroads | He is both a talk target and a kill target, and the quest is exactly that choice |
| **Valdris**, necromancer | `necromancer_valdris` | Crossroads | "Your priest calls it desecration. I call it refusing to waste a person" |
| **Ilsabet Corr** | `dying_merchant_ilsabet` | Elder Moor, Shrine of Endings | "I am not frightened, I am negotiating" |
| **Khan Toghrul** | `khan_toghrul` | Tenger war camp | He leads a **warband at a scouting camp** — which is what the bible already says the desert is. Nothing he says touches the [OPEN] question of whether the Tegnar ever become an Act-scale invasion |

### The Crossroads, grey-boxed

Five quests send the player to the Crossroads to meet a person: a troll on a
bridge, an informant in an inn, a necromancer near the junction, a rival captain
and an enemy commander. The Crossroads on the grid is a **cultist-ruined
intersection** — there is no wayhouse, no inn and no bridge geometry. The five
now stand on grey-box marks inside `crossroads_ruins.tscn` so their quests are
walkable today. **Whether the Crossroads gets buildings is level design and is
held for Caleb** in `wave_b_dispositions.md`.

### LORE_ONLY — deliberately never spawned

`tools/validate_content.gd`'s `LORE_ONLY_IDS` list is no longer empty. Seven ids
are on it, each with the question that blocks it written beside it in the code
and a row in `wave_b_dispositions.md`: `king_aldric`, `secret_society_contact`,
`capital_informant`, `elven_elder_witness`, `elven_guide`,
`village_elder_east_hollow`, `garrison_commander`. They report as warnings, so
the list stays visible and cannot rot quietly.

**Deliberately NOT invented:** the missing king in any form — no statue, no
portrait, no decree, because no Act I quest needs one and putting his face on a
wall is a ruling about how present he is; the secret society's name; the elves'
position on the map; whether East Hollow is destroyed or intact; the Thornfield
temple; any Crossroads building.

---

## Wave B backlog — stage 5: 117 items

Every item obeys the CLAUDE.md philosophy: it does something. Gear stats are
derived from the closest existing item of the same tier, and the donor is named
below so a balance pass can find the anchor. All three databases in
`InventoryManager` were updated, because that list is hand-maintained and an
unregistered `.tres` is invisible at runtime even though the validator sees it.

### Gear, and what it was derived from

| Group | Donor | The rule |
|---|---|---|
| Arcane Circle robes — novice → apprentice → journeyman → adept → magister | `leather_armor` (AV 10, 100g) for the cloth curve; `ring_of_protection` (magic 0.15, 150g) for the warding curve | AV 3/5/7/9/12, Will +1→+4, magic resistance appears at journeyman and doubles each rank. 60g → 900g |
| Arcane Circle staves — apprentice → adept → containment → archmage | `longsword` ([3,6,4], 150g) at the bottom, `flamebrand` ([5,6,0], 1500g) at the top | Magical class, 150g → 1800g. The containment staff trades a die for armour-pierce, because its job is holding rather than hitting |
| Iron Company issue | `chainmail` (AV 11, 300g) and `steel_sword` ([3,6,3], 200g) | Company harness is chainmail +1 AV for the shoulder band. The lieutenant's is plate-class and costs double. Company blades are the steel sword, plain |
| Thieves Guild and Keepers | `leather_armor` and `fur_cloak` (AV 6, 120g) | Everything in this group pays for stealth with a **negative stealth penalty**, which is the only lever in ArmorData that rewards being quiet |
| Adventurers Guild / arena top end | `plate_armor` (AV 18, 800g), `scale_mail` (AV 14, 600g), `wooden_shield` (block 5, 50g) | Guild rewards top out around 1400g and buy resistances rather than raw AV, so they do not obsolete the smith |
| Cloaks — wool → hunter → wolf → dire wolf | `fur_cloak` | AV 4/7/7/10, frost the whole ladder, 45g → 550g |
| Charms, amulets, rings, circlets | `amulet_of_wisdom` (Will+1 Know+2, 225g), `ring_of_protection` | One resistance and one or two stat points each; 60g for a hamlet charm, 900g for Gaela's high gift |
| Named uniques — Vorn's axe, Nightshade's dagger, the Ghost Captain's cutlass, Horde-Breaker, the Time-Touched Blade | `battleaxe` ([3,8,0], 250g), `dagger` ([2,6,6], 50g), `longsword`, `flamebrand` | Each is its donor plus one die step and pierce, at 1200–1700g. None of them out-damages Flamebrand by much, because uniques here are **lore**, not a power tier |

### The six spells that do not exist

`spell_scroll_ice_shard`, `_ice_spike`, `_flame_burst`, `_flame_bolt`,
`_arcane_shield`, `_meteor_storm` name spells the game has never had. Repointing
them silently would have changed what the reward is, so instead each is a real
SCROLL that **teaches the nearest existing spell in the same school and says so
in its own description** — the Flame Bolt scroll admits the bolt grew into a
Fireball, and the Meteor Storm scroll admits the archmage who titled it was
showing off. Six one-line repoints the day those spells are written.

Mapping: flame_bolt→`fireball` · flame_burst→`fire_gate` · ice_shard→`cone_of_cold` ·
ice_spike→`ice_storm` · arcane_shield→`armor` · meteor_storm→`summon_flaming_skulls`.

### Divine blessings, as timed buffs

The Three Gods' favour has no rules, and none were invented. Each blessing is a
consumable using an effect type that already exists, chosen so the god decides
the stat:

* **Gaela** — +3 Grit, 10 minutes. The strength that gets a field in before the rain.
* **Chronos** — +3 Agility, 10 minutes. Time's favour does not slow the world; it makes you slightly earlier.
* **Foresight** (Chronos rite) — +4 Armour, 10 minutes. You do not dodge; you are already leaning.
* **Bounty** (Gaela) — cures all conditions. A full meal and a hand on the shoulder.
* **Minor Time Blessing** — +1 Agility, 5 minutes. What an acolyte can manage.

Morthane has no blessing consumable, because nothing in the effect list means
*death and rebirth* and guessing would have been an answer. His favour is
jewellery instead: necrotic resistance on an amulet and a ring.

### The three literal placeholders, fixed in the quest data

| Was | Now | Where |
|---|---|---|
| `research_materials_variable` (collect) | `arcane_essence` — a new reagent the Circle measures research in | `mage_07_thesis_project` |
| `specialization_bonus_variable` (reward) | `amulet_arcane_sight` — the thesis earns you the eye, not a stat block | `mage_07_thesis_project` |
| `forbidden_spell_variable` (reward) | `scroll_soul_drain` — an existing forbidden spell, which is the point of the restricted vault | `mage_10_forbidden_tome` |
| `adept_wizard_robes` | repointed to `adept_robes` | `wizard_final_trial` — one adept robe, not two |

### Also created

Nineteen herbs, reagents and foods (the group the dispositions file called "a
small design pass of its own"), each with an effect or a crafting use: the
moon-set (moonpetal, moonleaf, moonwater), silvervine, sunroot, sacred soil and
spring water, six arcane reagents, and six foods that each do something
different — wild honey heals, the great pumpkin is a ten-minute +2 Grit for a
whole household, a ration pack restores stamina and does not spoil, and a sack
of grain is what the relief road is actually carrying.

Two tools needed a real system behind them and got one: `healing_poultice_recipe`
is a SCHEMATIC, so `craft_healing_poultice` was added to
`data/recipes/crafting_recipes.json` and `healing_poultice` created as its output.

**Deliberately NOT invented:** the six missing spells; a Morthane blessing
consumable; any belt slot (the arena victor's belt is a rank token, because
ArmorData has no belt); the heist loot abstractions (`vault_gold`,
`valuable_goods`, `harwick_valuables` and friends) which are piles of money
rather than objects and want a gold reward per heist — a quest-design call, held
in `wave_b_dispositions.md`; and the lore relics that touch bible `[OPEN]`s
(`sacred_hourglass`, `paradox_stone`, `crown_of_mountain_kings`,
`hammer_of_first_king`, `soulbound_phylactery`). Those remain validator
*warnings*, which is where they belong.

---

## Quest-quality pass, 8/2 - every name written into 182 quests

The quest pass (`docs/audits/quest_quality_audit.md`, `docs/design/quest_web.md`)
rewrote 180 errand quests and touched two more for the soulstone undercurrent.
Giving a quest a threat means giving it somebody to threaten, so this pass
invented a great many farmers, foremen, captains and dead men.

**Everything below is prose colour.** Not one row invented an item id, NPC id,
faction id or enemy id - the validator held at 0 errors and the warning count did
not rise, which is the mechanical proof of it. Every name here exists only inside
a `description` or a `notes` string; nothing in the game looks any of them up. A
name Caleb dislikes is a find-and-replace in one file.

**Three things this pass deliberately did not invent:**

1. Any answer to a bible `[OPEN]`. `elven_ambassador` and `dwarf_messenger` were
   where the temptation was strongest - the treaty is written as road access and
   jurisdiction, and the dwarf message is stated in outline and takes no position
   on the succession.
2. The soulstone undercurrent's owner. Twelve quests carry a detail; nothing
   anywhere carries a buyer. See `docs/audits/wave_b_dispositions.md` 2l.
3. What the soulstones do for the goblin king. Untouched, and Kazan-Dun was
   deliberately left with no touchpoint in it so that the province-wide buying
   cannot be read as an answer to the siege.

Rows are grouped by the batch that wrote them. Formats differ slightly between
groups because eight writers filled them in; the four columns are the same
everywhere - **what · where it lives · why it was needed · what it is built on**.


### Bounty board (14 quests)

| What | Where it lives | Why it was needed | What in the bible it is built on |
|---|---|---|---|
| Captain Bess Ordell (Thornfield guard captain) | `bandit_patrol.json` description/notes | Notice needed a named voice for the guard-captain's irritation and the soulstone touchpoint (audit row #5) | No bible basis - local colour; faction is `human_empire`, town is Thornfield per existing data |
| Caravan-master Otto Praed, the Hollow Vein mine | `basilisk_lair.json` description/notes | Merchant Guild notice needed a named payer and a named mine to give the dead miners and lost shipments a stake | No bible basis - local colour; Dalhurst is the existing merchant hub |
| Ferris Coale (missing villager) | `cultist_activity.json` description/notes | Millbrook common-folk notice needed a named person lost to the temple, not an abstraction | No bible basis - local colour |
| Guildmaster Tam Ashby, three unnamed trappers | `dire_wolf_pack.json` description/notes | Hunters' Guild voice needed a professional reason (trap lines lost) distinct from the ordinary-wolf bounty in the same town | No bible basis - local colour |
| Watch-Sergeant Coel Renn | `goblin_scouts.json` description/notes | Human Empire militia notice needed a named officer whose count of paired scouts makes the "column behind them" stake concrete | No bible basis - local colour |
| Dalhurst apothecary (unnamed), fever among Millbrook mill workers | `medicine_delivery.json` description/notes | Turn-in-to-NPC quest needed a real illness, a source and a worsening clock in prose (no data hook existed to wire it) | No bible basis - local colour |
| Garrison Captain Yorick Dane, Hollow's Bend | `ogre_menace.json` description/notes | Elder Moor human_empire notice needed a distinct captain and place-name from the other Elder Moor human_empire bounty (urgent_dispatch) | No bible basis - local colour |
| Warehouse-master Corin Petsch | `rat_extermination.json` description/notes | Merchant Guild notice needed a named account holder to make "coin nobody stole, just eaten" land | No bible basis - local colour |
| Foreman Alsett, Cutter's Claim mine | `spider_infestation.json` description/notes | Merchant Guild notice needed a distinct mine name and foreman from basilisk_lair's Hollow Vein, in the same town | No bible basis - local colour |
| Widow Sarel | `undead_rising.json` description/notes | Common-folk notice needed a named villager who personally re-buried her own husband, to carry the stake instead of an abstract totem | No bible basis - local colour. Notes explicitly avoid naming who made the totem, since that risks the bible's open goblin-king/soulstone mechanism |
| Elder Moor watch turning back a supply column for Thornfield's garrison | `urgent_dispatch.json` description/notes | The original text asserted "urgent" with no content; needed a concrete reason two garrisons would correspond, without touching the soulstone thread (which is exclusive to bandit_patrol per the brief) | No bible basis - local colour; both towns and the human_empire faction already exist |
| Hale farmstead, three sheep and a plow-ox | `wyvern_hunt.json` description/notes | Hunters' Guild notice needed a named farm and a concrete loss, plus the guild's own memory of wyverns escalating from deer to livestock | No bible basis - local colour |

No bible `[OPEN]` was touched or resolved. No item/NPC/faction/enemy id was invented - every proper name above is prose colour only, never referenced as a data id.


### Three-beat chains, first eight (24 quests)

| What | Where it lives | Why it was needed | What in the bible it is built on |
|---|---|---|---|
| Tome name "The Ashgrave Cantos" | `cursed_tome_1.json` description | The stolen book needed a concrete name so the scholar's fear reads as specific, not generic "dark magic" | No bible basis - local colour |
| Shaken cataloguer boy (unnamed) | `cursed_tome_1.json` description | Gives the scholar's motive a source (he feels responsible for the loss) and shows the tome's danger without naming a mechanism | No bible basis - local colour |
| Effect of reading the tome untrained ("lost the rest of that week") | `cursed_tome_1.json` description | Concrete, small-scale consequence for the threat, in place of "forbidden knowledge" | No bible basis - local colour |
| Old woman's ring is her mother's/grandmother's, three generations | `family_heirloom_1.json` description | Grounds the giver's motive (shame at asking) in something specific rather than "an heirloom" | No bible basis - local colour |
| Empty ring setting / missing stone | `family_heirloom_2.json` description | Soulstone touchpoint directed by `docs/design/quest_web.md` #3 - mandated by the brief, not invented content in the "new fact" sense | Built on `docs/design/quest_web.md` Tell 1 and the SoulstoneEconomy system |
| Widow married ten years, locket portrait is not her husband | `lost_locket_1.json` / `lost_locket_2.json` description | REWRITE_SPEC-directed "turn" (one of the three examples given verbatim in the spec: "a locket with a portrait in it that is not the husband") | No bible basis - local colour, per spec's own example |
| Locked case not recovered, thief paid to leave the rest | `market_theft_2.json` description | Soulstone touchpoint directed by `docs/design/quest_web.md` #4 | Built on `docs/design/quest_web.md` Tell 1 and the SoulstoneEconomy system |
| Courier not robbed (purse and letter both intact); death reads as accident | `missing_courier_1.json` / `missing_courier_2.json` description | REWRITE_SPEC-directed "turn" (one of the three examples given verbatim: "a courier who was not robbed") | No bible basis - local colour, per spec's own example |
| Merchant's stated reason for refusing to pay ransom ("every merchant who pays once pays again") | `rescue_merchant_daughter_1.json` description | REWRITE_SPEC mandate for this chain: the merchant's choice not to pay is the whole story and must cost him something in the prose | No bible basis - local colour, mandated by the batch brief |
| Merchant's household cost (can't speak to his daughter once alone) | `rescue_merchant_daughter_3.json` description | Same mandate - the "cost" landing in part 3 | No bible basis - local colour |
| Girl's name "Elin" | `rescue_missing_child_1/2/3.json` | The chain needed a name to carry the turn (village assumption of abduction vs. what actually happened) across three files without a giver voice in parts 2-3 | No bible basis - local colour |
| Elin followed the cult's lights on her own, was not dragged off | `rescue_missing_child_1.json` / `rescue_missing_child_2.json` description | REWRITE_SPEC-directed "turn," adapted from the spec's "ransom note in her own handwriting" example - the point being the village's assumption of abduction is wrong even though rescue is still necessary | No bible basis - local colour, per spec's own example shape |
| Guard's reasoning for requisitioning scouted intel before requesting help (bandit_justice) | `bandit_justice_1.json` description | Giver motive requirement - guard voice, empire authority procedural tone | No bible basis - local colour |
| Merchant's trade-politics reasoning (accusing wrong neighbor costs custom) | `market_theft_1.json` description | Giver motive requirement - merchant voice | No bible basis - local colour |


### Three-beat chains, last seven (21 quests)

| What | Where it lives | Why it was needed | What in the bible it is built on |
|---|---|---|---|
| Fenna Voss, name and situation (followed a preacher, taken for sacrifice at full moon, does not want rescuing) | `rescue_sacrifice_victim_1/2/3.json` prose | Audit verdict required naming the victim and giving the chain a distinct rescue "kind" (does not want to come back), per batch brief instruction to differentiate the four rescue chains | No bible basis - local colour. Cult/ritual/full-moon premise already existed in the file; the willing-victim twist and her name are new. |
| Corporal Wex Bramwell and Private Toma Idle, names and fates (two-man patrol, one already dead on arrival) | `rescue_soldier_1/2/3.json` prose | Batch brief required a "too late for part of it" rescue kind; original file had one unnamed soldier and no second victim | No bible basis - local colour. Thornfield garrison/guard captain context already existed. |
| Perrin, name and backstory (apprentice who sought the cultists out himself after his master refused to teach him a working) | `rescue_wizard_apprentice_1/2/3.json` prose | Batch brief required a "captors were not the danger" rescue kind; original framed cultists as straightforward kidnappers | No bible basis - local colour. Thornfield wizard/mages circle context already existed. |
| Tomas, name (woodsman husband, straightforward captured-and-recovered) | `rescue_woodsman_1/2/3.json` prose | Batch brief required giving the wife-giver a voice and naming the husband for the "straight and grim" rescue kind | No bible basis - local colour. Elder Moor woodsman's wife giver NPC already existed. |
| The eastern lookout rise/outpost as a strategic overwatch position (not merely a bandit camp robbing travelers), and the captain's manpower figure ("eleven men for a wall that wants twenty") | `road_safety_1/2/3.json` prose | Batch brief required distinguishing road_safety from bandit_justice (a different chain about caravan raiding out of Elder Moor); reframed as a garrison-manpower problem | No bible basis - local colour, invented to differentiate two mechanically identical chains per explicit batch instruction. |
| The merchant's overpriced, unnamed sale (one ledger leaf, sold at 3x value, paid in new imperial coin, buyer named no house) and the abandoned chest's untouched coin + four-scratch mark | `stolen_ledger_1.json`, `stolen_ledger_2.json` prose | Mandated soulstone-undercurrent touchpoints, exact content specified verbatim by the batch brief and `docs/design/quest_web.md` touchpoints #1-2 | Built directly on `docs/design/quest_web.md`'s soulstone-undercurrent brief (Tells 1-3) and the bible's soulstone-scarcity premise (SoulstoneEconomy, Kazan-Dun goblin king wanting soulstones). Never names soulstones, patterns, or a buyer, per the brief's hard rules. |
| The seed-relic's function (spoken blessing over the spring planting, three-week deadline) and the priestess not trusting the guard's speed | `stolen_relic_1/2/3.json` prose | Original file's relic had no name, no function and no reason a cult wanted it specifically (audit verdict); needed a concrete, nameable stake per the rewrite spec's bar | No bible basis - local colour. Temple of Gaela / harvest themes already exist elsewhere in the game (gaela quest line), so a Gaela-priestess relic tied to planting is consistent with established temple flavor, not new to the world. |


### Adventurer's Guild (14 quests)

| What | Where it lives | Why needed | Built on |
|---|---|---|---|
| Oda Renn, a hauler who paid the Guild to clear a wolf den | `data/quests/guild_initiation.json` | Spec required `guild_initiation` and `adventurers_01_proving_ground` to read as two different contracts with two different clients rather than a merged duplicate. Vorn's own dialogue already frames the wolves as "killing merchants" without naming one. | Existing wolf-pack threat already in both quest files and `guildmaster_vorn.json` dialogue; no new id, prose only. |
| Corrin Dale, a grain factor whose warehouse is losing stock to rats | `data/quests/guild/adventurers/adventurers_02_pest_control.json` | Audit: "the merchants are 'desperate' in the abstract." Needed one named person losing something specific per quest. | Existing warehouse/merchant setup in the quest and Vorn's dialogue ("merchants are terrified"). |
| Ansel Crake, a Millbrook shepherd who lost his flock | `data/quests/guild/adventurers/adventurers_06_monster_hunt.json` | Audit: "livestock mutilated... no Millbrook person attached." | Millbrook already an established town with an elder NPC in the quest's own objectives. |
| Toman Ashcroft, a Thornfield farmer who lost eleven sheep and both dogs; Thornfield's council vote to abandon the eastern fields at first frost | `data/quests/guild_contract_elite.json` | Audit: "no farmer, no lost herd, no consequence for leaving it alive." | Existing Thornfield farmlands/farmer NPC target already referenced in the quest's own objectives. |
| Kettil Marsh, the mine foreman who pulled his crew after losing two miners | `data/quests/guild_contract_spiders.json` | Audit: "the fled miners are the stake and never appear." | Existing abandoned-mine premise already in the quest text. |
| Grain factors (unnamed collective) who pooled coin to end the raids on the Millbrook south road; the soulstone-buyer detail (new-struck, non-Dalhurst coin, unnamed hirer) | `data/quests/guild_contract_bandits.json` | Audit: "the merchants who are being ambushed are never named." Soulstone touchpoint #6 mandated by `docs/design/quest_web.md`, exact wording assigned to this quest id. | Existing bandit-camp/captain premise in the quest; soulstone detail is verbatim per the quest_web.md brief, not new invention beyond assigning it prose placement. |
| Iron Blades buying a second key-fragment map off a Thornfield fence (rival threat) | `data/quests/guild/adventurers/adventurers_12_legendary_contract.json` | Audit: "a loot run dressed as a legend. Nobody in the world is affected either way." Needed a client-facing stake for a dungeon-mapping contract per batch instructions ("somebody wants it mapped, and wants it mapped before somebody else does"). | Iron Blades already an established rival guild introduced in `adventurers_09_rival_guild.json`; no new faction or id, prose only. |
| The Thieves Guild has already sent someone to scout the new Willow Dale section | `data/quests/guild/adventurers/adventurers_07_dungeon_delve.json` | Same instruction as above, applied to the earlier dungeon-delve quest. Audit: "Map it, clear it, keep what you find. No threat at all." | Thieves Guild already an established faction/questline in this game; no new id, prose only ("Vorn has heard, from where he won't say"). |
| Three reports of a winged creature over the Kazan-Dun quarry camp; stonecutters idled | `data/quests/guild/adventurers/adventurers_10_dragon_rumor.json` | Audit: "'Don't engage' is set up and never becomes a decision. Trophy hunt." Needed a nameable group at risk. | Kazan-Dun entrance region already exists and is the quest's own target zone; "quarry camp" is local colour, no bible basis beyond the region existing. |
| Vorn hasn't fought a real bout in six years; the Guild's best contracts go to whoever wins the Champion trial, displacing waiting Elites | `data/quests/guild/adventurers/adventurers_13_champion.json` | Audit: "A title fight... carries no threat and no world consequence." Batch brief: "what happens to the person you displace." | The quest's own objective already targets Vorn himself (`vorn_champion_form`), not Katrina (who appears instead in `guild_elite_trial.json`'s dialogue) - this rewrite worked with the data's actual target rather than the possibly-inconsistent dialogue reference. No bible basis - local colour. |
| Katrina Steelwind undefeated three years running; a loss costs her authority over the fighters beneath her | `data/quests/guild_elite_trial.json` | Audit: "Rite with no world consequence." Batch brief: "what the Guild does with a Champion, and what happens to the person you displace." | Katrina Steelwind already named and established as reigning champion in `guildmaster_vorn.json` dialogue and this quest's existing objectives; no new id. |

No new item ids, NPC ids, faction ids, or enemy ids were created. No bible `[OPEN]` item was touched or resolved.


### Arcane Circle and the Helvant apprenticeship (17 quests)

- **Harmon Voss** (harbormaster, Dalhurst) · `data/quests/chains/wizard_field_test.json` description + `light_harbor_beacon` objective · the brief required naming the villager behind each of the four field-test beats · no bible basis - local colour.
- **Ysolt Bracken** (well-owner, Thornfield) · `data/quests/chains/wizard_field_test.json` description + `purify_thornfield_well` objective · same · no bible basis - local colour.
- **Denner Cobb** (carter, Crossroads) · `data/quests/chains/wizard_field_test.json` description + `clear_road_obstacle` objective, and `notes` · same, and specifically the brief's instruction that one named villager be written ungrateful despite being helped · no bible basis - local colour.
- **Two archivists burned** (unnamed, Athenaeum basement) · `data/quests/guild/mages/mage_08_magical_disaster.json` description + notes · brief required "somebody is already hurt" for this quest specifically, replacing the old unearned "time is of the essence" framing · no bible basis - local colour, deliberately left unnamed since the quest has no room to develop them as characters.
- **A dead Circle courier, branded with a Shadow Circle sigil** (unnamed) and **a Dalhurst patron waiting on a paid-for shipment** (unnamed) · `data/quests/guild/mages/mage_09_rival_circle.json` description + objectives · gave the Shadow Circle a concrete goal (poaching the Circle's own patron) per the audit's complaint that they "want nothing beyond something catastrophic" · no bible basis - local colour, built on the CLAUDE.md-documented fact that soulstone/enchanting patrons already exist in this world (`noble_soulstone_request`).
- **Two missing caravan guards at the Crossroads shrine** (unnamed) · `data/quests/guild/mages/mage_11_planar_breach.json` description + objectives · brief required grounding the planar breach in named local stakes ("a breach near the Crossroads means the Crossroads, which has people in it") · no bible basis - local colour.
- **Three council Magisters watching Elara's handling of the Shadow Circle incident**, **two Magisters who voted against sponsoring the player**, **two Adepts broken by grief after failing the Theorem of Infinite Recursion**, **an outside party asking after Willow Dale ahead of the player** (all unnamed) · spread across `mage_06`, `mage_09`, `mage_12`, `mage_13` descriptions/notes · gave the Circle the internal politics and rivals-inside-the-institution texture the brief specifically asked for ("Elara has rivals inside it and a reputation to protect. A Novice is a liability to her.") · no bible basis - local colour, consistent with the existing dialogue file's own reference to "the council debates" and "who might succeed me."
- **The Circle's stone-cutter refusing to sell to them, and an unnamed buyer paying triple for the whole cut** · `data/quests/guild/mages/mage_03_reagent_gathering.json` description + notes · this is the assigned soulstone-undercurrent touchpoint (quest_web.md row 7, tell 2), written as an unexplained budget complaint per the brief's rules - no buyer named, no pattern called, nothing sinister · built directly on `docs/design/quest_web.md`'s own brief for this exact quest id.
- **A Dalhurst merchant patron who already paid for the ring in `mage_04`**, **the Journeyman's endowment/patron in `mage_07`** (both unnamed) · gave institutional stakes (a paying customer, a lapsing grant) to two previously stakes-free quests · no bible basis - local colour, consistent with the Circle-has-patrons framing the brief assigned this batch.

No item ids, NPC ids, faction ids or enemy ids were invented. No quest branch was added; `mage_10_forbidden_tome`'s notes record the unwired moral-choice branch that already existed in the file's own claims (necromancy/blood magic/dimensional-travel choice at `moral_choice`) without adding a `choice_consequences` entry.


### Iron Company and Thieves Guild (24 quests)

| what | where it lives | why it was needed | bible basis |
|---|---|---|---|
| Iron Company down forty soldiers since the Thornfield Rebellion, still short-handed | mercenary_01_enlistment.json, mercenary_02_drill.json (description/notes) | Gives Steele's recruiting a reason beyond "test combat prowess" | Reuses Captain Steele's own dialogue (captain_roderick_steele.json: "lost forty good soldiers" at Thornfield, twelve years ago). No new invention, only reused facts. |
| Halworth timber concern (client), bandit toll on the Elder Moor logging road | mercenary_03_first_blood.json | Named client + threat for a contract that had neither | No bible basis - local colour |
| Ser Aldous Marrow, tenant landholder near Willow Dale, six families driven off his land | mercenary_05_siege_support.json | Named client + threat for the stronghold assault | No bible basis - local colour |
| Merchant Voss and his daughter Petra, held twice for ransom by the Bandit Hideout crew | mercenary_06_hostage_rescue.json | Named hostage + escalating threat + deadline | No bible basis - local colour |
| Recruits Denna, Oskar, Petrik, Ythan under player command | mercenary_07_command_trial.json, reused in mercenary_12_legendary_battle.json | Step 3 directive: name the recruits, be honest some may not return; Denna/Oskar reused later as continuity | No bible basis - local colour |
| Corporal Dain Wexley, the Iron Company traitor, in debt to a Dalhurst moneylender since before he enlisted | mercenary_09_betrayal.json | Step 3 directive: give the traitor a name and a person's motive, not a plot device | No bible basis - local colour |
| Houses Corliss and Vantry, dispute over grazing uplands above Mill Brook (a dammed stream) | mercenary_10_noble_war.json | Step 3 directive: name the two houses and give each a distinct grievance | No bible basis - local colour. Deliberately placed in the uplands *above* Millbrook, not inside the hamlet itself, so it does not contradict millbrook_bandits.json / millbrook_elder.json's elder-run, noble-free hamlet. |
| Iron Company contract to defend Mill Brook funded by a standing Dalhurst grain-buyers' arrangement (since Mill Brook itself can't afford Company rates) | mercenary_11_monster_battalion.json | Explains how an impoverished hamlet affords a mercenary company, without contradicting Bram's established poverty | No bible basis - local colour. The "forty-one people, one mill, nine-man militia who are also the harvest" facts themselves are reused verbatim from millbrook_bandits.json / millbrook_elder.json, not invented. |
| Steele became Captain fifteen years ago after Hadrian Iron's death; worn down after the Crossroads battle, wants a trusted second | mercenary_13_second_command.json | Giver motive for the capstone duel | Reuses captain_roderick_steele.json dialogue facts (became_captain node) rather than inventing new ones. |
| Horace's ledger records his real payroll and tax debts (not just "a ledger") | thieves_01_light_fingers.json | Gives the theft target a concrete, small stake per the bar's "name a specific thing" rule | No bible basis - local colour |
| Marcus the blacksmith given a wife, two children, and a forge; framed because he delivered hinges near the jeweler's row and owed the jeweler for scrap | thieves_02_plant_evidence.json | Explicit Step 4 directive: give Marcus a family and a shop, make the frame-up's cost concrete | No bible basis - local colour |
| Garrett's 200-gold debt explained as a lie about "ship repairs," spent on drink instead (reused from raven_thief_contact.json dialogue, not invented fresh) | thieves_04_debt_collection.json | Grounds the debt in a reason already established elsewhere in the game | Reused from raven_thief_contact.json dialogue (quest_04_story node), not new invention |
| Lord Ashford's letters explicitly named as proof of slave trafficking in the description (previously only in the decorative moral_choice block) | thieves_05_blackmail.json | Moves an existing fact from an unwired decorative field into the actual deliverable prose | Already present in the file's own moral_choice block - relocated, not invented |
| Magistrate Holt, named magistrate holding the royal decree | thieves_10_government_job.json | The magistrate was unnamed generic prose; naming him matches lady_nightshade.json's established (but nameless) magistrate character | No bible basis - local colour |
| The royal decree's actual content (crown seizes Guild assets, arrests members without trial) moved into the main description | thieves_10_government_job.json | Previously the "threat" only existed in an unwired moral_choice block; the audit specifically flagged this as the threat that "cannot land" | Already present in the file's own moral_choice block - relocated, not invented |
| Guild coffers strained by the cost of stealing the royal decree (bribed guards, a burned contact, abandoned safehouses), motivating the vault job | thieves_11_impossible_vault.json | Gives "the Guildmaster believes you can" a concrete reason tied to the preceding quest in the chain rather than legend for its own sake | No bible basis - local colour, but deliberately chained to thieves_10's established events rather than invented independently |

No soulstone-undercurrent touchpoints in this batch (none of these 24 quest ids appear in `docs/design/quest_web.md`'s touchpoint table), and none were added.


### Temples of Chronos, Gaela and Morthane (37 quests)

- The Hollis family (Elder Moor farmers, grain failed to sprout) · `gaela_09_famine_threat.json` · audit named this quest's exact failure ("three towns investigated, none characterised, nobody starves") - needed one named household per town · no bible basis - local colour, parallel to the already-established farmer_edda thread from gaela_01-03
- Tam (sick boy in Thornfield, healer running out of remedies) · `gaela_08_seed_of_life.json` · audit: "no sick person is written" · no bible basis - local colour
- Osk and two tenement neighbours (Dalhurst dockworkers, sick, facing eviction) · `gaela_seed_of_life.json` (root duplicate of gaela_08) · needed a distinct townsman's-angle patient set so the duplicate pair reads as two different sicknesses, not one file twice · no bible basis - local colour
- A tanner family, three unburied dead west of Crossroads, abandoned by their traveling party when fever hit · `morthane_01_last_rites.json` · audit: "who they were and why nobody came for them IS the quest" - the file had unburied dead nobody buried and no identity · no bible basis - local colour, written to fit Morthane's doctrine that rites are owed regardless of who the dead were
- A Millbrook shepherd's flock as his entire livelihood (no wool, no mutton, no breeding stock if lost) · `gaela_bonus_shepherd_quest.json` · audit: "the shepherd's livelihood is the obvious stake and is unstated" · no bible basis - local colour
- Dalhurst autumn festival cancelled the previous two years, now resuming · `gaela_bonus_bountiful_harvest.json` · audit: "gathers for a festival that is never held" · no bible basis - local colour
- A Millbrook boatman (grain-barge ferryman, unnamed) reporting thinning cargo along his route · `gaela_blight.json` (root duplicate of gaela_06) · needed a distinct townsman's-angle giver-frame for the duplicate pair (temple copy already uses a devotee-led investigation naming an abandoned smallholding) · no bible basis - local colour
- An abandoned smallholding at Willow Dale's edge, family salted their soil and moved to Dalhurst · `gaela_06_blight_source.json` · audit: "no victim named" · no bible basis - local colour
- A widow on Cooper's Row, Dalhurst, hearing her dead husband's footsteps three nights running · `morthane_restless_soul.json` (root duplicate of morthane_02) · needed the townsman's-grief angle distinct from the temple copy's doctrinal-distinction framing · no bible basis - local colour
- Two lay brothers of the Dalhurst Morthane temple who died on grave duty during the undead incursion · `morthane_cycle_broken.json` · audit: "a massive undead incursion... with no settlement written into it" - needed a concrete cost · no bible basis - local colour
- Father Aldwin as Aberdeen's last remaining priest of Chronos (colleagues already dead) · `aberdeens_blessing.json` · audit gave no specific stake beyond a generic relic-recovery; needed to explain why the relic matters to him personally · no bible basis - local colour; Father Aldwin's name/id already existed in the file, only his backstory is new
- The lich aspirant's motive stated as ordinary fear of death rather than unstated villainy · `morthane_07_lich_rumor.json` · audit: "no reason given for wanting it" · no bible basis - local colour, consistent with Morthane doctrine (condemns undeath regardless of the sympathetic reason behind it)
- The rebirth ritual's real failure rate (priest has performed it twice, lost one celebrant) · `morthane_08_rebirth_ritual.json` · audit: "no stake, no chance for it to go wrong" · no bible basis - local colour
- Crossroads' watch line and Thornfield's cemetery-keeper as concrete stakes in the undead-wave defense · `morthane_09_undead_army.json` · audit: "neither town has a person in it" · no bible basis - local colour

## Soulstone touchpoint (per docs/design/quest_web.md, touchpoint 8)

Written into `data/quests/temple/morthane/morthane_03_cemetery_duty.json` description only, per the quest_web brief: grave robbers left rings, coin and plate but took the small stones set into the grave-boards; four short scratches cut into the cemetery gate post, close together, like a tally that stopped at four. Never named, never explained, priest is furious about desecration and not curious about the economics. Not repeated in `temple_undead_menace.json`, which overlaps the same premise (Dalhurst cemetery, not Thornfield) but carries no soulstone detail, per the brief's instruction not to duplicate it.

## Duplicates deliberately differentiated (notes recorded in each file)

- `chronos_03_late_delivery.json` (temple, Thornfield mill wheel) / `temple_prophecy_chronos.json` (root, internal Chronist-order standing)
- `gaela_06_blight_source.json` (temple, Willow Dale smallholding, devotee investigation) / `gaela_blight.json` (root, Millbrook boatman's report)
- `gaela_08_seed_of_life.json` (temple, Tam's plague in Thornfield) / `gaela_seed_of_life.json` (root, Osk's tenement sickness in Dalhurst)
- `morthane_02_restless_spirit.json` (temple, doctrinal distinction between lingering soul and undeath) / `morthane_restless_soul.json` (root, the widow's grief)
- `morthane_03_cemetery_duty.json` (Thornfield cemetery, soulstone touchpoint) overlaps `temple_undead_menace.json` (Dalhurst cemetery) - not an exact duplicate, no detail repeated


### Towns and standalone (31 quests)

| What | Where | Why | Bible basis |
|---|---|---|---|
| Aldous Fenn, woodsman mauled by wolves | tharins_wolf_problem.json | Named victim for the trust-test wolf quest, distinct from logging_troubles' dead woodsmen | No bible basis - local colour |
| Corin Talbot, dead woodsman with a wife and unfinished quota | logging_troubles.json | Named one of the two dead woodsmen the original description left abstract | No bible basis - local colour |
| Old Yarrow, farmer who lost four sheep to a latch-opening wolf | wolf_pack_menace.json | Named victim distinguishing this pack (farms, south Thornfield) from eastern_wolves (loggers, east) | No bible basis - local colour |
| Eastern cut/den encroachment as cause of eastern_wolves' aggression | eastern_wolves.json | Distinct cause from wolf_pack_menace and tharins_wolf_problem per spec's instruction to make the three wolf quests different problems | No bible basis - local colour |
| Sage Brennan's shaking hands (aging) | tutorial_alchemy.json | Giver motive for teaching a stranger, per spec | No bible basis - local colour |
| Martha's thin winter stores / short-handedness | tutorial_cooking.json | Giver motive for teaching a stranger, per spec | No bible basis - local colour |
| Grom's backlog of repairs, one smith for the camp | tutorial_crafting.json | Giver motive for teaching a stranger, per spec | No bible basis - local colour |
| Merrow's Kiss and two missing brothers | ghost_ship_rumors.json / harbor_ghost_ship.json | Named victims/stake for the ghost-ship two-parter | No bible basis - local colour |
| Larton's stores estimated at ~6 weeks for a few hundred people | starving_south.json | Concrete stake, small numbers per voice spec | No bible basis - local colour |
| Aberdeen down to ~1 month of stores | aberdeen_relief.json | Concrete stake, small numbers per voice spec | No bible basis - local colour |
| Larton/Aberdeen four quests read as one regional crisis (blight + blockade + bandit warehouse seizure + goblin-blocked road) | starving_south.json, aberdeen_relief.json, supply_line_crisis.json, retake_harbor.json | Spec's explicit instruction to cross-reference the cluster into one situation from four desks | No bible basis - local colour; ghost_pirate_investigation (already-shipped blockade) used as the root cause tying it together |
| Ambassador Liraethel's treaty content: elven road access + elven law over elven people in human courts | elven_ambassador.json | Gave the treaty concrete stakes without touching the elixir, the missing king, or the elf claimant/son (all bible [OPEN]) | Bible: "elves not fond of humans generally" - treaty framed as easing that friction, not resolving succession/elixir |
| Willow Dale seals failing "days, not weeks", threat reaching farms outside Dalhurst | keepers_initiation.json | Stated consequence per audit; matches aldric_vane_keepers.json's own "villages disappear" line | Built on existing dialogue file's own claims, not new invention beyond a timeframe |
| keepers_test finding: fake job postings, a labor-trafficking racket across three towns | keepers_test.json | Audit required the finding be stated; this is a plain, non-supernatural read consistent with "Keepers work unseen" | No bible basis - local colour |
| Oswald Pell, injured carter | bandit_trouble.json | Named victim for a bounty-board quest with no other voice | No bible basis - local colour |
| Old Pell, fisherman who won't go back on the water | lake_creature.json | Named victim/stake | No bible basis - local colour |
| Borin Stonehammer's message content, stated only in outline (goblins past the passes, Kazan-Dun needs aid) | dwarf_messenger.json | Gave the letter stakes without naming the dwarf king or resolving the kazan_dun_* succession arc | Bible: goblin siege of the dwarf hold; deliberately left agnostic on who holds the gate to avoid contradicting kazan_dun_02/03/04 |

## Soulstone touchpoints (per docs/design/quest_web.md - not new invention, executing the brief's exact assigned details)

| Quest | Detail written | Row |
|---|---|---|
| missing_miner.json | Erik's claim worked over carefully; tools/stake left; four scratches on the shaft post | Row 9 |
| willow_dale_investigation.json | Manifest tallies except "one case, sealed, no description"; merchant won't discuss it | Row 10 |
| sailors_debt.json (touchpoint only) | Brennan's unexplained fortnight-old money; buyer wasn't the payer | Row 11 |
| whalers_debt.json (touchpoint only) | Selene's debt cleared in one lump three weeks back; won't say what she sold or to whom | Row 12 |

No new NPC ids, item ids, faction ids, or enemy ids were introduced anywhere in this batch. All names above are prose-only characters inside description/objective text, not data references. No `choice_consequences` entries were added; no objectives were added or removed; no bible `[OPEN]` was resolved.


---

## Living World v1 — schedules (8/2)

A schedule is an invention about somebody's life: it says what hour a person
gets up, where they eat and whether they drink. None of it is in the bible,
because the bible does not describe anybody's Tuesday. The rules the schedules
obey are the same two as everything else here — modest, and plausible for the
trade the quest pass already gave them.

**The trades are not invented.** Every archetype below was named by a display
name or an npc_id that already existed: "Grom the Smith" is a smith, "Hamish
Roke" is the man behind the inn's counter, "Watch-Captain Osbert Dunmoor" keeps
a captain's hours. Where the name said nothing, the record says `townsfolk` —
ordinary hours in an ordinary place — rather than guessing a life.

| What | Where | Why it was needed | What it is built on |
|---|---|---|---|
| Twenty-two trades' working days, in hours | `data/schedules/archetypes/*.json` | "The NPCs should be living inside this world" needs an hour-by-hour answer for every person; without one a town is a diorama | Each trade's own name, already on the NPC. No new trades were introduced |
| Shopkeepers shut for an hour at noon and go to the tavern | `shopkeeper.json` | Gives the market a rhythm a player can notice without locking anything: the keeper is still talkable, just not selling | Local colour |
| Innkeepers work until 02:00 and sleep 03:00–09:00 | `innkeeper.json` | The one trade whose day is inverted, so the tavern is the only lit door at midnight | Local colour |
| One watchman per town works the night rota | `night_watch.json`; `guard_elder_moor_1`, `guard_dalhurst_1` | A town at 03:00 that is simply empty is not alive either. Someone has to be awake | The camp already has "one watchman, one captain" in Osbert Dunmoor's own line |
| Elder Moor's ambient population keep a logger's hours | `scripts/levels/elder_moor.gd` | Elder Moor is a logging camp; its people are the camp's people | The level's own comment: "loggers, workers - no nobles/gladiators" |
| Each town's leisure station is its own tavern or fire | `data/npc_schedules.json`, `LEISURE_LOCAL` in three level scripts | Evening has to happen somewhere, and inventing a new building would be art | Measured: Elder Moor's is Martha's cook fire, Dalhurst's is the Gilded Grog, Thornfield's and Millbrook's are their innkeepers' own positions |
| Borin Stonehammer and Ilsabet Corr keep no working hours | `data/npc_schedules.json` (`beggar`) | A courier off his feet with a broken leg and a dying woman laid beside a shrine do not go to work. `beggar` is the archetype for "no post to keep" | Both characters' own written situations |
| Every NPC's home is `interior: true` at their own work position | `data/npc_schedules.json` | No interiors are modelled, so "went home" means "left the world". Marking the door rather than inventing a house keeps it honest and needs no art | ART RULE — route around, do not build |

**Deliberately NOT invented:** who lives with whom (RECON's households are a v2
item and need buildings first); what anybody does on a feast day or a market
day; any reason for a schedule beyond the trade. No NPC was given a family, a
grievance, or a destination outside their own town.

**Not invention, measurement:** every station position is where the level
script actually puts that NPC, read by booting the scene
(`tools/probes/_probe_npc_census.gd`). Nothing was placed by hand and nothing was moved.

---

## The reactive layer's lines (8/2)

209 lines of dialogue written for `data/dialogue/pools/reactions.json` and
`reaction_greetings.json`. **All 209 are invention** — no bible line dictates
what a Thornfield merchant says to a man with a bounty on him — so they are
recorded here as a class, with the constraints every one of them was written
under.

| What | Where | Why it was needed | What it is built on |
|---|---|---|---|
| 177 reaction topic answers, 5 archetypes x 8 states | `data/dialogue/pools/reactions.json` | "NPCs will remember and know you and react to your choices" (Caleb, 8/2). Without written lines the reactive machinery has nothing to say | The states themselves, all of which already existed: `player_is_bandit_boss`, `kazan_dun_helped`, `kazan_dun_fallen`, CrimeManager bounties, FlagManager devotee bonds, faction standing, guild rank, `caught_lying_<npc_id>` |
| 32 reaction greetings | `data/dialogue/pools/reaction_greetings.json` | The greeting is the only line the player hears without asking, so it is where a reaction is *felt* rather than looked up | The same eight states |
| Merchants price fear, guards go cold, crooks warm up, priests keep the door open | across both files | Four readings of the same fact is what makes a town feel populated rather than polled | The archetypes' own existing voices in `personal.json` and `career_topics.json` |

**Constraints every line was held to, and they are the point:**

* **Nothing is named that does not exist.** All 209 pass THE GROUNDING LAW. No
  new place, no new person, no new item, no new faction, no new god.
* **Quests are never named by hand.** `{quest_title}` resolves at speak-time
  from quest data. A hand-written title becomes a lie the day the quest is
  renamed, and outlives the quest's deletion.
* **The soulstone thread stays unnamed.** Not one reaction line mentions
  soulstones, a buyer, a pattern, or four scratches. `docs/design/quest_web.md`
  rule 1 holds: the connection is the player's to make.
* **No bible `[OPEN]` is narrowed.** Nothing here says where the elven lands
  are, what the king did for the elves, what feeding a dwarf king to Skarrag
  does, or whether the Tegnar are an invasion. The Kazan-Dun reactions describe
  a hold that held or a hold that fell, and nothing about the mechanism.
* **The dwarf king's own name is never spoken** in any of them, only "a king",
  because the adopted names are Caleb's to overrule and a reaction line is a
  poor place to entrench one.

**Deliberately NOT invented:** any reaction to Act II content — the claimant,
the capital, the undead continent, the missing king. Those are Act II's and his.

## Fifty-odd villagers who were already named (8/2)

THE GROUNDING LAW's first run found 133 proper nouns in shipped prose that
resolved to nothing. Almost all were **people** — carters, captains, farmers and
harbourmasters named in quest descriptions written before the law existed.

**These are not new inventions; they are old ones, made true.** Their given
names and surnames were added to `data/npc_names.json`, which is the vocabulary
the world generates townspeople from — so a generated villager can now actually
be called Torben or Fenna, and the prose that names them is describing a name
this culture uses. Nothing was written into a quest that was not already there.

Ten residual references — a siege fought before the game begins, a boat already
on the harbour bottom, a tome off a restricted shelf, four Arcane Circle board
reagents with no `ItemData` — are recorded in `data/lore_only_whitelist.json`
under `offscreen`, each with the file that says it. **Four of those are a real
gap, not lore:** the research board asks for Shadowroot, Glowcap, Moonpetals and
Moonweave, and none of them is an item the player can carry.

## The terseness pass (8/2)

The pass that followed Caleb's first real playtest cut prose; it invented almost
nothing. Two things are new and both are mechanism, not fiction:

| What | Where | Why it was needed | Bible basis |
|---|---|---|---|
| `dwarf_letter_delivered` — a flag raised when `dwarf_messenger` completes | `data/quests/dwarf_messenger.json` `on_complete_flags`, read by `rumor_kazandun_goblins` in `data/dialogue/pools/rumors.json` | Stage 1 of the Kazan-Dun rumour ladder has to be able to stay vague until somebody has been to the gate. Nothing else reads it and it gates no quest. | none needed — a bookkeeping flag, no proper noun, nothing said out loud |
| `rumor_dwarves_south_road` — one ambient rumour line | `data/dialogue/pools/rumors.json` | The ladder's stage 1: "dwarves begging for help in the south", named by Caleb as the shape it should take. Contains no proper noun at all. | the bible's siege — dwarves under pressure, seeking outside hands |

The offer-gate `dwarf_messenger.prerequisites = ["logging_troubles"]` is not an
invention: both quests already existed and neither's fiction changed.

See `docs/design/quest_terseness_law.md` and `docs/design/kazan_dun_ladder.md`.
