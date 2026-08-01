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

*(filled in as step 23 lands)*

---

## Step 24 — Second showcase + faction spread

*(filled in as step 24 lands)*
