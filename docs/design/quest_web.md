# The soulstone undercurrent

*Design brief, 2026-08-02. Stage 2 of the quest-quality pass. This document is
for the people writing quests. **Nothing in it may be said out loud in the
game.***

---

## What this is

Caleb's directive for the quest pass has two halves. The first is that every
quest needs a threat and a story. The second is *"a larger connection across
many quests that the player won't realize right away."*

This is that connection.

**Somebody is quietly buying up soulstones across the province.**

That is the entire thread. It is never a quest, never a questline, never a
revelation. It is a repeating detail in the corner of twelve otherwise unrelated
jobs, and a player who notices it has noticed it on their own.

## Why soulstones and not something invented

Three things already in canon make this the only honest choice:

1. **The bible.** The dwarves of Kazan-Dun hold a large stash of soulstones, and
   the goblin king wants them badly enough to be part of the reason the hold is
   under siege. Soulstones are already the thing in this world that somebody
   powerful is trying to accumulate.
2. **`SoulstoneEconomy`.** There are exactly **100 soulstones in the world**,
   tracked, owned, and registered by owner. A limited stock is what makes
   quiet accumulation *mean* something: every stone that goes into one pair of
   hands is a stone out of everybody else's. The economy autoload is the
   mechanical truth the fiction is riding on.
3. **They are power.** Enchanting runs on them. `noble_soulstone_request` already
   establishes that a lord will pay 500 gold for one and that keeping it from him
   carries a daily reputation debt. The world already treats them as worth
   ruining yourself over.

Nothing here invents a new substance, a new economy or a new faction.

## The four rules

These are hard.

1. **No quest names the thread.** No description, objective, note, dialogue line
   or journal entry says "someone is collecting soulstones", "a pattern", "a
   conspiracy" or any synonym. Every touchpoint is a fact about *that quest's*
   own business. The connection is the player's to make.
2. **The mastermind does not exist anywhere.** Not in a file, not in a note, not
   in a name-agnostic id. Who is buying, and why, is **`[OPEN]` and Caleb's** -
   a row has been added to `docs/audits/wave_b_dispositions.md`. Writing an
   answer here would be resolving his story for him, and the whole point of a
   thread laid this way is that it can pay off as anything he wants later: the
   goblin king's agents, an Arcane Circle magister, the claimant's household,
   Lord Baron Viktor's reach across the water, or the missing king himself.
3. **The goblin-king mechanism stays unexplained.** The bible's `[OPEN]` - what
   feeding a dwarf king to Skarrag alongside the soulstones actually *does* - is
   not touched, hinted at, or narrowed by anything in this brief. The Kazan-Dun
   arc's three contradictory theories remain the only word on it.
4. **It gates nothing and blocks nothing.** No touchpoint is an objective, a
   prerequisite, a flag, a condition or a reward. Not one line of quest *data*
   changes because of this thread - only prose. A player who never reads a
   description loses nothing but the texture. If this thread is ever deleted, the
   deletion is a text edit.

Rule 4 has a corollary worth stating plainly: **do not build a "collect the
clues" system.** No codex entries, no journal tab, no notification when the
player has seen four of them. The moment the game acknowledges the pattern, the
pattern stops being the player's discovery.

## The three tells

Twelve touchpoints, three recurring shapes. A player needs to see two of the same
shape before anything registers, and the shapes overlap so the third sighting is
the one that itches.

### Tell 1 - only the stone was taken

A theft where the valuable thing was left behind. Coin untouched in an open
chest. Gold ring returned with the setting empty. A crate manifest that balances
except for one small sealed case.

This is the loudest tell and it does most of the work, because it is the one that
makes no sense on its own terms: robbers do not leave money.

### Tell 2 - the buyer who pays triple

Never seen, never named, always at one remove. Pays three times the going rate.
Pays in new imperial coin. Buys through a third party who is himself hired.
Gives no house, no seal, no name. Asks for the whole cut, not a sample.

Two people in the province have sold something to this buyer and neither will say
what. That refusal *is* the characterisation - they are ashamed, or they were
paid for silence, or both, and the quest never presses them.

### Tell 3 - the mark

**Four short scratches, close together, like a tally that stopped at four.**

Cut into wood or stone near three incidents. Fresh. Small enough to miss. Never
remarked on by any NPC, never given a meaning, never repeated so often that it
reads as a designer's stamp. Three sightings, total - two is coincidence and five
is a puzzle.

## The twelve touchpoints

Exact quest ids. Each detail is a single clause or sentence inside prose that is
about something else.

| # | Quest id | Questline | Town / place | The detail | Tell |
|---|---|---|---|---|---|
| 1 | `stolen_ledger_1` | Three-beat chains | Dalhurst | What the merchant actually fears losing is one leaf of the ledger: a sale recorded at three times worth, to an agent who paid in new imperial coin and named no house. | 2 |
| 2 | `stolen_ledger_2` | Three-beat chains | Sunken Crypts road | The chest the bandits abandoned still has its coin in it. Only paper is gone. Four short scratches on the lid, close together. | 1, 3 |
| 3 | `family_heirloom_2` | Three-beat chains | Crossroads | The grandmother's ring is in the chest. The gold is untouched and the setting is empty - the stone was prised out, carefully, by someone who wanted the stone. | 1 |
| 4 | `market_theft_2` | Three-beat chains | Millbrook | Every crate is recovered. The small locked case on the manifest is not among them, and the thief admits he was paid for the case and told to leave the rest. | 1 |
| 5 | `bounty_bandit_patrol` | Bounty board | Thornfield | The guard captain's own complaint: this crew was not working the road. They sat four days and moved on one wagon, and took one strongbox off it. | 1 |
| 6 | `guild_contract_bandits` | Adventurer's Guild | Dalhurst → Millbrook road | The captain's purse holds more than a road crew earns in a season, all of it new-struck and none of it Dalhurst mint. Nobody in the camp can say who hired them. | 2 |
| 7 | `mage_03_reagent_gathering` | Arcane Circle | Dalhurst | The reason a Novice is out picking herbs by hand: the Circle's stone-cutter has stopped selling to them. Somebody pays triple and takes the whole cut. | 2 |
| 8 | `morthane_03_cemetery_duty` | Temple of Morthane | Thornfield cemetery | The robbers left rings, coin and plate on the bodies. What they took were the small stones set into the grave-boards. Four scratches on the gate post. | 1, 3 |
| 9 | `missing_miner` | Towns | Aberdeen | Erik's claim has been worked over by somebody careful - his tools are still where he left them, his stake is still driven. Four scratches cut into the shaft post. | 1, 3 |
| 10 | `willow_dale_investigation` | Towns | Dalhurst | The caravan manifest tallies against the wreck, crate for crate, except one line: *one case, sealed, no description*. The merchant does not want to talk about that line. | 1 |
| 11 | `sailors_debt` | Towns | Dalhurst harbour | Brennan had money a fortnight ago and drank the whole of it. He did not steal it and he will not say who gave it to him, only that the man buying was not the man paying. | 2 |
| 12 | `whalers_debt` | Towns | Whaler's Abyss | Selene's debt to Miriam was cleared in one lump three weeks back and she lives exactly as she lived before. She sold something. She will not say what, and she will not say to whom. | 2 |

**Spread.** Seven questlines (three-beat chains, bounty board, Adventurer's
Guild, Arcane Circle, Temple of Morthane, and five standalone town quests) and
seven places (Dalhurst, Millbrook, Thornfield, Elder Moor's Crossroads road,
Aberdeen, Whaler's Abyss, the Sunken Crypts road). Dalhurst carries five of the
twelve, which is deliberate - it is the port and the hub, and a buyer working
through intermediaries would work through a port - but they sit in five
different questlines so no single conversation stacks them.

**Level spread.** Six of the twelve are in the earliest content a new character
sees (the chains, the bounty board, the guild's first contract). By design: the
tell has to be planted before the player is capable of chasing it, or the
discovery arrives already answered.

## What is deliberately absent

* **No thirteenth touchpoint at Kazan-Dun.** The dwarves' stash is canon and the
  goblins want it; connecting the province-wide buying to the siege would be an
  answer, and answers are Caleb's. The arc is left exactly as it is.
* **No touchpoint in the Keepers line.** The Keepers are the game's existing
  "secret order that notices things" and giving them a soulstone thread would put
  the pattern in an NPC's mouth, breaking rule 1. If Caleb ever wants the thread
  picked up by someone, they are the obvious candidates, and they are clean.
* **No touchpoint on `noble_soulstone_request`.** Lord Hakon buying a soulstone
  openly, for a named purpose, at a fair price, is the *control* - the honest
  transaction the other twelve are not. Touching it would blunt the contrast.
* **No count.** Nothing anywhere states how many stones have gone. A number is an
  answer.

## If Caleb wants to cash it in

The thread is built so that a single later quest can pick up any one of the
twelve threads and pull. Nothing needs to be retrofitted:

* Every touchpoint is prose in a quest that stands on its own.
* No flag, condition, item or NPC exists to be contradicted.
* The buyer has no gender, no race, no faction and no location on the page.
* The four-scratch mark has no meaning assigned, so it can be made to mean
  anything - a buyer's tally, a courier's route mark, a goblin count, a
  Circle sigil, or nothing at all and the player was pattern-matching on noise,
  which is also a legitimate answer in a game this grim.

The one thing that cannot be undone cheaply is the *volume*: twelve is chosen so
that a player on a second playthrough sees the shape and a player on a first
playthrough gets an itch. Adding a thirteenth and fourteenth in later content is
free. Adding forty would turn texture into a mechanic.
