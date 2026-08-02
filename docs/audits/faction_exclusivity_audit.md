# Factions, devotion and the lockout web — audit 2026-08-02

*Wyrm. Two questions from Caleb: "the faction system was a little wonky", and
"I had made notes before that certain things can lock you out of other
things — if you go too far into devotion of one temple it'll soft lock you out
of the other ones." Everything below was **run**, not read:
`tools/check_faction_loop.tscn`, 585 checks.*

---

## The headline

**114 of 236 quests have never paid their faction reputation.** Not a gating
problem, not a design problem — `complete_quest()` threw an exception at the
item reward and aborted before it reached the reputation on the next line. The
quest still wrote itself COMPLETED, because the state is set before the rewards
are paid, so nothing ever looked wrong.

Two spellings of the same reward exist in the content:

```json
"items": ["farmers_blessing_charm"]              // 114 quests
"items": [{"id": "rope", "quantity": 2}]         //  13 quests
```

The code read every entry as `item["id"]`. On a String that throws, and in
GDScript a throw aborts the *function* — so for those 114 quests the reward
pass stopped dead and never reached **faction reputation, followers,
soulstones, titles, area unlocks, lore, or `next_quest` chaining**.

Measured: completing `gaela_03_protect_harvest` headless left Millbrook at 0.
It pays 25. It is 50 now (25 direct, the rest cascade).

This is why the faction system felt wonky. Roughly half the game's quests were
not connected to it.

Same crash sat in three reward-*preview* sites (`guard_npc.gd`,
`quest_giver.gd`, `merchant.gd`) — the "you will receive…" line a player reads
before accepting was truncated for the same 114 quests.

Fixed: `QuestManager.normalize_reward_items()` reads both shapes, and is static
so all four sites share it. Both `faction_reputation` amounts are now
`int()`-coerced — Godot's JSON parser returns every number as a float, and
`var amount: int = <float>` is the same aborting throw one line further down.

---

## FOCUS 1 — the faction loop, link by link

Every link exercised through the API a player's actions reach.
`tools/check_faction_loop.tscn`, 585 checks, green.

| # | Link | Before | After |
|---|---|---|---|
| L1 | quest `faction_reputation` reward → FactionManager | **BROKEN** — 114 quests silently paid nothing | fixed, verified |
| L2 | cascade to allies / enemies / parent / children | worked | verified |
| L2b | every id in a cascade list names a real faction | **19 dead ids** across 11 factions | 7 fixed, 4 recorded (below) |
| L3 | dialogue `REPUTATION` condition reads it | worked (once L1 fed it) | verified |
| L4 | GuildRankManager counts the quest off its reward | worked | verified |
| L5 | reputation + quest count → promotion | worked | verified |
| L6 | promotion writes the rank flag dialogue gates on | worked | verified |
| L7 | ongoing-effects ticker moves reputation on a day change | worked | verified |
| L8 | the eight factions authored 8/1 load and are reachable | worked | verified |
| L9 | bandit chair + hostility + `<faction>_hunting_player` world fact | worked | verified |
| L10 | devotion lockout | **did not exist** | built (below) |

### The eight factions created 8/1 — verdict: sound

`merchant_guild`, `common_folk`, `nobility`, `hunters_guild`, `scholars_guild`,
`shadowed_hand_cult`, `aberdeen`, `larton`. All eight load, all have rank
ladders whose top rung sits at or under the reputation ceiling, and all eight
are moved by at least one real quest. Their cascade relationships read
sensibly. **Every faction in the game except `elves_anti_human` is moved by at
least one quest** — that one is the only faction nothing can change.

### `FactionManager.reset()` did not reset

`reset()` cleared `player_reputations`, then `_initialize_player_reputations()`
immediately restored every value from `GameManager.player_data`, which
`_sync_to_player_data()` had been mirroring all along. Both callers are
new-game paths (`save_manager.gd:2092`, `game_systems.gd:683`), so a second
character could start already Honored with somebody the first one had pleased.
Fixed: the mirror is cleared first.

### Dead cascade ids

A dead id is silent — `_cascade_reputation` skips it, nothing warns — so the
relationship a writer authored simply does not exist.

**Fixed (7 files):** `cultists` → `shadowed_hand_cult`. It is the only cult
faction in the game, the name is a plain plural of it, and
`shadowed_hand_cult.enemies` already names `church_of_three`,
`church_of_morthane`, `the_keepers` and `town_guard` in return — the
relationship was authored from one side and never landed.

**Recorded, not repaired** — in `KNOWN_DEAD_CASCADE_IDS` in the check, so a
*new* dead id fails and a stale excuse also fails:

| id | named by | why not repaired |
|---|---|---|
| `undead` | 6 factions | used everywhere as an enemy *category* (spawners, loot, encounter tables), never as a political faction. There is no `undead.tres` and writing one is inventing a faction. **Needs a ruling.** |
| `the_crown` | `human_empire.allies` | names a part of itself; repointing at `human_empire` would make it list itself |
| `imperial_army` | `human_empire.allies`, `thieves_guild.enemies` | same |
| `the_witch` | `the_keepers.enemies` | names nothing anywhere in the repository |

### Relationships are one-way, and that is authored, not broken

`merchant_guild.enemies` contains `thieves_guild`; `thieves_guild.enemies` is
`["human_empire", "imperial_army"]` and does **not** contain `merchant_guild`.
Cascade only reads the *source* faction's list, so helping the merchants costs
you with the thieves, and robbing for the thieves costs you nothing with the
merchants. This is asymmetric across many pairs. It is a coherent design (not
all grudges are mutual) and it is also possibly an oversight. **Needs a
ruling** — see Tabled.

---

## FOCUS 2 — the devotion lockout

### What his notes actually said

**Caleb is right, and the notes are in the game's own dialogue rather than in
any design document.** All three priests state the rule out loud, each in his
own voice, and each has a written refusal for a rival's devotee:

> **Chronos** (`devotee_inquiry`): "becoming a devotee of one god means you
> cannot serve the others in the same way. The Three accept shared worship,
> but **deep devotion can only be given to one**."
>
> **Gaela**: "such dedication requires a whole heart. **You cannot serve
> another god with the same depth** while walking Gaela's path."
>
> **Morthane**: "**devotion is exclusive** — you cannot serve Morthane deeply
> while giving your soul to another."

And the refusals (`already_other_devotee` in each file):

> **Chronos**: "I sense the mark of another upon your soul… the path of
> Chronos's devotee is closed to you."
>
> **Gaela**: "you have already planted your roots in another's garden… the
> path of the Green Lady's devotee is not one you can walk while tending
> another garden."
>
> **Morthane**: "devotion can only be given once… the deepest mysteries of
> Morthane's path are not for you."

Note what the same speeches also say: **shallow service stays open to
everyone.** "You may always seek blessing here, offer prayers, and aid our
temple in its works." That is exactly Caleb's phrasing — *going too far* into
one temple is what closes the others. Introductory service does not.

**The three temple `README.md`s say the opposite** ("Does NOT lock out other
temple quests", "Allow multi-devotion"). They are agent-generated design docs,
uniformly formatted, bulk-added in a single commit. **The dialogue is the
older, in-voice, player-facing statement and it is taken as canon here.** The
READMEs should be corrected or overruled — his call.

### The threshold is determinate, and was not invented

The rule needs no numeric devotion metric, and there is none in the game. The
metric is **the devotee flag**, binary, set at quest 5 / the ritual dialogue.
"Too far" = has taken the bond with one god. That boundary is stated by the
content itself, so nothing here is a guess.

`docs/gdd/quest-system.md:216-224` documents the `forbidden_flags` quest
field — and uses **`["gaela_devotee", "morthane_devotee"]` as its worked
example.** The engine reads it (`quest_manager.gd:776, 2163`). Somebody
reached for exactly this and never wired it to content.

### What existed vs what was built

**Existed:** the speeches, the refusal nodes, the greeting choice that routes a
rival's devotee to `already_other_devotee`, the `forbidden_flags` engine
support, and `FlagManager.become_devotee()` — which clears the other two flags
and **has zero callers**; the dialogue uses raw `set_flag`, which does not.

**Did not exist:** any gate at all on the quest side. Quests are offered
through `ConversationSystem` → `QuestManager.is_quest_available()`, which reads
`prerequisites`, `flag_prerequisites` and `forbidden_flags`. The temple chains
used **only** `prerequisites` (the previous quest id). So:

1. A devotee of Gaela could walk to the Chronos priest, take the whole Chronos
   chain through the QUESTS topic, and end up **devoted to two gods**. The
   refusal dialogue was never reached, because it sits on a different door.
2. **Declining devotion unlocked the devotee-only content anyway.** Quests 6-10
   required *completing quest 5*, not *accepting* at quest 5.

**The smoking gun:** the Chronos chain 6-10 and its repeatable *did* author the
gate — under the key **`flags_required`**, which nothing in the engine reads.
The field the engine reads is `flag_prerequisites`. So the gate was written,
has never fired, and Gaela and Morthane never got even that far.

```json
"flags_required": ["chronos_devotee"]        // authored, never read
"flag_prerequisites": ["chronos_devotee"]    // what the engine reads
```

**Built (22 quests):** every bond quest — the devotion choice and everything
past it — now carries

```json
"forbidden_flags": ["<other god>_devotee", "<other god>_devotee"],
"flag_prerequisites": ["<own god>_devotee"]     // except the choice itself
```

The devotion choice keeps no `flag_prerequisites` (it *is* the choice) but does
forbid the other two. Quests 1-4 are untouched: open service stays open, as all
three priests promise. `gaela_bonus_shepherd_quest` was deliberately left
ungated — its prerequisite is quest 3 and its giver is `millbrook_shepherd`,
not the priest, so it is open service too.

The player is told. `already_other_devotee` is real, written content in each
priest's voice, and it is now the only door that opens.

### One seam worth knowing about

The devotee flag is set in exactly one place: the `devotee_confirmation` node
in each priest's dialogue. The quest's own `choice_consequences` block — which
also names the flag — is never applied, because nothing calls
`apply_choice_consequence` for these quests (only the Millbrook camp and
`QuestInteractable` call it at all).

So the bond is taken by **doing the ritual in conversation**, and quest 5 is
the paperwork beside it. Both are required for quest 6: the quest via
`prerequisites`, the flag via `flag_prerequisites`. That is coherent and it is
how it now behaves — but it means a player who completes quest 5's two `talk`
objectives without ever walking the `devotee_inquiry` branch has finished the
quest and not taken the bond. The priest will still offer the ritual, so it is
recoverable rather than a soft-lock. Worth an eye during his playthrough.

---

## FOCUS 3 — claimed but not in the game (new finds)

| Find | Evidence | Status |
|---|---|---|
| **114/236 quests never paid any reward past `items`** | above | **FIXED** |
| **`flags_required`** — 6 Chronos quests gate on a key nothing reads | `chronos_06`…`10`, `chronos_repeatable` | **FIXED** (renamed) |
| **`FactionManager.reset()` did not reset** | `faction_manager.gd:729` | **FIXED** |
| **19 dead cascade ids** | 11 faction `.tres` | 7 fixed, 4 recorded |
| `on_complete_flags` (22 quests), `rank_required` (14), `flags_set` (14), `unlocks_quests` (6), `xp_bonus`/`gold_bonus`/`reward_bonus` (12), `is_tutorial` (3), `is_repeatable` (3), `detection_consequences` (3), `optional_objectives`/`choice_paths`/`time_pressure`/`phases` (2 each) | authored in ≥2 quest files, **zero consumers** in `scripts/` | tabled — each needs a call on wire-or-delete |
| **`moral_choice` blocks are decorative** in 4 live thieves quests | `thieves_02`, `_04`, `_05`, `_10` carry `good_option`/`evil_option` with no `choice_consequences`; two siblings were migrated, these four were not | tabled |
| **Blessings advertised by all three priests do not exist** | every "seek blessing here / pray at any altar" choice has `actions: []`; the only real blessing is the one-time devotee quest item | tabled — content promise with no mechanic |
| **Thieves Guild capstone `rank_benefits` is fiction** | `guild_vault_access`, `command_authority`, `share_of_all_guild_jobs`, `personal_safehouse` — zero hits in `scripts/` | tabled |
| **Deception failure has no consequence** | `quest_interactable.gd:130` says so in a comment; CLAUDE.md's TODO is **still true**, not stale | tabled |
| **Intuition / Endurance consumers don't exist** | CLAUDE.md claims enemy radar ("15 units + 5 per level"), trap detection, stamina, fall damage, jump height. Both skills appear only in stat-map and display-name switches | tabled — doc claims a design that was never wired past the generic roll |
| **README claims a "hex-based world map"** | the world is a square `Vector2i` grid; zero `hex` hits in any world script | tabled — doc fix |
| **`get_quest_data()` only reads `res://data/quests/<id>.json`** | flat path only, so every quest in a subdirectory (temple, guild) falls through to a 4-field stub | tabled — cosmetic today, a trap later |
| **Morthane's priest is split in two** | `priest_morthane_elder_moor` gives all 11 quests and is spawned with `null` dialogue; `priest_morthane_dalhurst` has the dialogue (and the devotion ritual) and gives no quests | tabled — needs a ruling, see below |

---

## Needs Caleb's ruling

1. **The temple READMEs contradict the priests.** The dialogue says devotion is
   exclusive; the three `README.md`s say it is not. The dialogue was taken as
   canon and the lockout is now wired. Confirm — and if confirmed, the READMEs
   should be corrected so the next agent doesn't undo it.
2. **Can a devotee ever change gods?** Chronos's `devotee_regret` node exists
   and the refusal calls the bond "a sacred bond that cannot be undone".
   `FlagManager.become_devotee()` would silently switch. Nothing calls it.
   Permanent, or is there a road back?
3. **Should serving one god *cost* standing with the others?** The three
   churches are `neutrals` of each other — zero cascade either way. Nothing was
   invented here because no note fixes a magnitude. Reciprocal penalty, or does
   exclusion alone carry it?
4. **`undead` as a political faction** — six factions name it as an enemy and
   it does not exist. Create it, or strip the references?
5. **One-way faction relationships** — helping the merchants costs you with the
   thieves, but robbing for the thieves costs you nothing with the merchants.
   Intended asymmetry, or should relationships be reciprocal?
6. **Morthane's two priests** — one has the quests, the other has the voice.
   Merge, or give the Elder Moor priest the dialogue too? Today the Morthane
   devotion ritual is only reachable in Dalhurst.
7. **The dead authored fields** (`on_complete_flags`, `rank_required`,
   `flags_set`, and the rest) — wire or delete, per field.
8. **`elves_anti_human`** — the only faction no quest can move.

---

## The gate

`tools/check_faction_loop.tscn` — 585 checks, the fourteenth gate. It proves
the quest → reputation → cascade → gate → rank → flag loop end to end, and that
deep devotion to one temple closes the other two while shallow service to all
three stays open.

```powershell
& $godot47 --headless --path . res://tools/check_faction_loop.tscn
```

**Nothing here was played.** The lockout is proven to fire headlessly; whether
being refused by two priests *reads* as meaningful rather than as a wall is a
thing only Caleb can say.
