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

### 2g. Enemy stats (76 warnings)

`goblin_king`, `arena_champion_tier1`, `lich_aspirant_valdris`,
`temporal_rift_guardian`, `rival_commander` and friends. Each needs HP, armour,
damage, a level for the loot tier, a faction and a sprite. Deliberately left as
warnings rather than guessed at — this is a balance pass, and
`balance-reviewer` should own it.

### 2h. Choice branches nobody can reach (74 warnings)

Was 107, then 70 after step 24, now 74 because stage 3 and 5 made two more
quests reachable enough to notice. Twenty-seven quests still carry branch data
no dialogue node fires. The per-quest reasons are tabled in
`docs/audits/invention_manifest.md` under "Tabled — 27 quests". Several of them
unblocked in this pass, because their turn-in NPCs now exist: `sailors_debt`,
`whalers_debt`, `fish_fraud`, `noble_soulstone_request`, `morthane_necromancer`,
`wizard_stolen_pages` and the three `morthane_*` quests whose giver now has a
tree to hang nodes on. That is the cheapest next wave of content work.

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
