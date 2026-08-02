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
| **Thane Vurka Stonebrand** — leads the trial-by-combat side, holds the third gate, blunt and not certain she wins | `data/dialogue/kazan_dun_thane.json`, `scripts/levels/kazan_dun_level_1.gd` (`dwarf_thane_challenger`) | The bible names "the other side" but no person. A faction with no face cannot be argued with, and the succession choice is the arc's payload | "The other side: demands trial by combat... originally they wanted to fight *the child*, which is why the uncle stepped up" |
| **Loremaster Dwalki Runeglass** — keeps the funeral rites and the muster rolls | `data/dialogue/kazan_dun_loremaster.json`, `kazan_dun_level_1.gd` (`dwarf_loremaster`) | The bible makes the funeral rites the hinge of the whole arc ("cannot declare a new heir until the king's body receives proper funeral rites") without saying who performs them. Also the neutral turn-in for a choice between two rivals | "dwarves cannot declare a new heir until the king's body receives proper funeral rites" |
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
| **Hold-friend pricing**: dwarven traders take 25% off for a player who saved the hold (30% carrying the token), and add 15% if the hold fell | `scripts/world/merchant.gd` (`get_world_price_modifier`, new `faction_id` export) | "Rewards and unique interactions later down the road" needed a mechanical form that is not a quest. Hung off the world fact, not an inventory check, so it survives selling the token | "Help them → rewards and unique interactions later down the road" |
| **Durn Shieldbearer** — a Kazan-Dun hearth-guard the hold lends the player after the succession is settled. Tower shield, taunt, no conversation in him | `data/followers/durn_shieldbearer.json`, offer node in `data/dialogue/kazan_dun_loremaster.json` | The dwarf companion offer hook step 15 asks for. No dwarf follower existed — the nearest, Grimjaw, is a half-orc | Same "unique interactions later down the road" |
| 10 Kazan-Dun rumour lines, gated on the world facts: 4 for the fall, 3 for the hold standing, 3 for which way the succession went | `data/conversation_pools/rumors.json` | Design law #1: consequences surface later, through people talking, not through a notification | "the player hears about the fall from NPCs" |
| 5 elf-claimant rumour lines naming **Sylvaine** and **Corwin** — ungated, low weight, all hearsay, all contradictory in tone | `data/conversation_pools/rumors.json` | The claimant is Act I *chatter* and Act II *plot*. Nothing here confirms the boy is the king's son, nobody in Act I has met either of them, and no quest, flag or NPC references them | "sprinkled into Act I — NPCs talk about it in passing, nothing more"; the truth (the boy IS the king's son) is deliberately absent from every line |

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
| **Chief Corla Vane** — runs the crew, has a standing rule about the mill, argues in arithmetic rather than menace | `data/dialogue/millbrook_bandit_chief.json` | Four of the five roads are things you say to a person. The old quest had a nameless "bandit captain" who existed only as a kill count | Existing quest text: "I saw the bandit captain - scarred face, black cloak"; `bandit_boss.tres` |
| **Quartermaster Pell** — keeps the ledger, has written down four chiefs, none of them elected | `data/dialogue/millbrook_bandit_quartermaster.json` | The usurp road needs somebody to *say* the player is chief. A crew that keeps books is also why the takeover has an income to inherit | `bandits.tres` faction description: "shares of the take and a short memory for men who cost them money" |
| Elder Bram's careful non-answer, and the plain answer if you push him | `data/dialogue/millbrook_elder.json` | The quest's premise is a man who wants a thing done and does not want to have asked. It also makes all five turn-ins land differently on the same character | Existing NPC; existing quest premise |
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
| Vorn's four turn-in scenes, including the one where he writes "dispersed" on the contract and your name beside it | `data/dialogue/guildmaster_vorn.json` | The quest's meaning lives in his reaction, not in the reward table. He prefers the quiet execution and cannot say so; he knows you sold the contract and pays you anyway | His written voice in the existing tree |
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
(`scripts/npcs/townsfolk.gd`) — one call for the six things every resident needs.
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
