# The terseness law

*Style ruling, 2026-08-02, from Caleb's first real playtest of the 8/2 quest
pass.*

> "The quests word-vomit too much information — I'm allowed to see behind the
> screen of the game more than I want."

The 8/2 rewrite gave every quest a threat and a story, which it needed. It also
gave every quest a paragraph explaining itself, which it did not. This document
is the correction. It binds every quest in `data/quests/` and every dialogue
intro line that offers one.

---

## The law

A quest's `description` **is** the journal entry — `validate_content.gd` scans
it as player-facing prose and the journal UI prints it whole. So one field has
to be two things at once, and the law is written for both.

1. **Length.** `description` is at most **three short sentences, 45 words**.
   Each objective `description` is at most **twelve words**, one clause,
   imperative or plain statement.

2. **Voice.** The description is what the **giver** said and what the player
   wrote down after. It contains only what that person knows, fears and wants.
   No narrator stands behind them.

3. **No structure talk.** Never explain the quest's shape. Not "this is your
   last test before Apprentice", not "three errands in", not "you may resolve
   this in several ways", not "this choice will affect". The rewards screen and
   the objective list already say what the player is owed and what to do.

4. **No lore the giver would not say.** A logging boss does not narrate the
   history of the alliance. A guard captain does not recite the province's
   trade routes. If a fact is not in this person's mouth on this day, it is not
   in the description.

5. **Mystery over completeness.** Keep the stakes; cut the explanation. A good
   entry implies more than it states. When a sentence's only job is to make
   sure the player understood, delete it.

6. **The soulstone touchpoints stay whisper-weight.** `quest_web.md` lists
   twelve. Each is **one clause** inside prose about something else — never a
   sentence of its own, never the last sentence of a paragraph, never explained.
   All four rules in that document still bind. The thread has no name.

7. **`notes` is not player-facing.** Designer reasoning, the touchpoint record
   and the `[OPEN]` boundaries live there and are not subject to the word
   budget. Do not move cut prose from `description` into `notes` unless it is
   reasoning a future author needs.

---

## Dialogue

An NPC offering a quest is **a person asking for help**, 2–4 sentences. Not a
briefing. The same rules 2–5 apply to the offer node's `text`.

Where a quest giver's base (non-reactive) dialogue is generic filler, give them
one or two lines of texture that only they would say, consistent with their
manifest row. This is not a licence for a global depth pass.

---

## Worked example

`mage_03_reagent_gathering`, before — 92 words, third-person, explains the
Circle's finances, the player's rank track and the shape of the errand:

> The Athenaeum's reagent stock is thinner than it should be. Elara says only,
> tightly, that the stone-cutter the Circle has always bought from won't sell to
> them anymore — somebody else is paying triple and taking the whole cut, and
> she is not going to explain that to a Novice. Whatever the reason, the Circle
> still needs what it needs, so a Novice goes into Elder Moor's woods with a
> basket and does by hand what used to arrive already cut. This is your last
> test before Apprentice: come back with all of it.

After — 34 words, Elara's voice, touchpoint intact as a single clause, nothing
about ranks or tests:

> Our cutter will not sell to the Circle anymore. Someone pays him triple and
> takes the whole cut, and I will not discuss it further. Take a basket to the
> Elder Moor woods.

Objective, before: *"Bring everything back to Elara and let her stop counting
coppers for a day"*. After: *"Bring the reagents to Elara"*.

---

## Rumour-first pacing

The starting hamlet does not offer remote major arcs. Caleb met a Kazan-Dun
courier and heard about goblins in his first minutes.

**Nothing gates access.** The player may walk to any region at any hour and the
world-reacts consequences fire exactly as they always did. Only the **offer** is
paced, and only with data the quest loader already reads: `prerequisites` (quest
ids) and `flag_prerequisites` (flags raised by `on_complete_flags`).

The ladder has three stages:

| Stage | What it is | Where it lives |
|---|---|---|
| 1 | Ambient rumour. A line in a conversation pool. No quest, no marker, no name for the trouble. | `data/dialogue/pools/rumors.json`, `local_news.json` |
| 2 | A pointed rumour or letter that puts **one line** in the journal. Local giver, local ask. | a short quest in the starting region |
| 3 | The arc itself, offered at the region's edge or by its refugees. | the region's own givers |

See `docs/design/kazan_dun_ladder.md` for the built example.
