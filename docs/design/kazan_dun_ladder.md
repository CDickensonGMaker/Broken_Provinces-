# The Kazan-Dun rumour ladder

*Built 2026-08-02, from Caleb's first real playtest.*

> "Right away I ran into someone who gave me a Kazan-Dun quest and talking about
> goblins immediately."

He was right, and the fix is pacing, not deletion. **Nothing here gates access.**
The player may walk south on turn one, take the arc from the Gate Warden, and
every world-reacts consequence fires exactly as it always did. Only the **offer**
is paced.

---

## What he actually met

Borin Stonehammer sits by the Elder Moor camp fire from a cold start. He is
spawned by `scripts/levels/elder_moor.gd` with a one-quest list,
`["dwarf_messenger"]`, and that quest opened with ninety words that named the
goblin advance, the old human alliance, and what Kazan-Dun needs from it. The
first stranger a new character spoke to briefed him on a war four regions away.

## The ladder as built

| Stage | Who says it | Where | When |
|---|---|---|---|
| 1 | Any villager with the `dwarves` or `trade` knowledge tag, at disposition 30+ | anywhere, including Elder Moor | always |
| 2 | Borin Stonehammer | Elder Moor camp fire | after `tharins_message` |
| 3 | Gate Warden Borik | the gate at Kazer-Dun | always — the arc is never gated |

### Stage 1 — the ambient rumour

`data/dialogue/pools/rumors.json`. Vague on purpose: something is wrong in the
deep, and dwarves are on the road asking for hands. No goblins, no siege, no
king, no soulstones. One line is new:

> "Dwarves came up the south road asking for able hands. Not trading, not
> passing through — asking. They wouldn't say what for."
> — `rumor_dwarves_south_road`, ungated, no knowledge tag required

`rumor_kazandun_trouble` ("they've sealed their gates… something's wrong in the
deep") already carried the right weight and is unchanged.

`rumor_kazandun_goblins` — the specific one, goblins broken into the lower
tunnels — **now carries a condition**: `flag_set: dwarf_letter_delivered`. The
detail circulates once somebody has been to the gate and come back with it. A
player who never carries the letter still hears stage 1 and can still walk south
and find out first-hand, which is the better version of learning it anyway.

### Stage 2 — the letter

`dwarf_messenger` is the breadcrumb. It gains
`"prerequisites": ["tharins_message"]` — the player carries one letter to
Thornfield and back before a wounded dwarf hands a stranger the hold's seal.
That is the whole gate: one Elder Moor quest, from Elder Moor's own boss.

**It is not gated on `logging_troubles`,** which was the first choice and is a
wall: its `western_logging_camp`, `wolf_attack_site` and `dire_wolf_den`
targets exist nowhere in the project, so that quest cannot be completed and
anything behind it could never open. A gate is only a gate if its key exists.

Its description is now Borin's, and only Borin's:

> "My leg won't carry me another mile and this seal won't wait. Take it south to
> the gate at Kazer-Dun and put it in the warden's hand. Don't break it, and
> don't sell it."

(The `Kazer-Dun` spelling is this file's and `WorldGrid`'s
`kazer_dun_entrance`; reconciling it with `Kazan-Dun` elsewhere is a separate
job and was not done here.)

The alliance, the passes, the siege and what Kazan-Dun needs are gone — Borin
does not brief a courier on the politics of the thing he is refusing to explain.
And the fourth objective no longer reads *"Deal with the goblin patrol blocking
the path"*; it reads **"Clear whatever holds the pass."** The target is still
`goblin_soldier`. The player finds out what it is by meeting it.

On completion it raises `dwarf_letter_delivered`, which is stage 1's ramp and
nothing else. It gates no quest.

### Stage 3 — the arc

`kazan_dun_01_the_stair_holds` was **already** offered by `dwarf_gate_warden` in
`kazan_dun_entrance`, and the other three links chain off it. No change was
needed and none was made: the arc's own giver stands at the region's edge, which
is exactly where a stage-3 giver belongs. It stays ungated, because the arc is
the thing access must never be paced.

Turning in the letter puts the player in front of the Gate Warden with the arc
in his mouth. The ladder closes itself.

### What Elder Moor offers now

Measured by `tools/probes/quest_completion_sweep`, on a character who has done
nothing: **eighteen offers before, seventeen after.** The only quest that left
the cold-start list is `dwarf_messenger`. Everything else Elder Moor offered on
turn one it still offers on turn one - three tutorials, five bounties, three
chain openers, Tharin's first letter, the shrine errand, the logging trouble,
the arena introduction, Morthane's first rites and the undead menace.

---

## Why Borin was not moved

He is spawned in a `.gd` file, with his quest list as a constructor argument.
Moving him south, or giving him a second smaller quest, means editing
`scripts/levels/elder_moor.gd`, and this pass is content, not code. Gating the
offer achieves the same pacing from data alone.

**One loose end for whoever next opens that file:** Borin's
`no_quest_dialogue` — *"My leg will mend. The message will not wait. Carry it
well, and Kazan-Dun will remember you."* — was written for the state after the
quest was taken, and is now also what he says before it is offered. It reads as
a man who will not hand over the letter yet, which is close enough to be no
worse than what shipped, but it is not what it should say.

## What is deliberately unchanged

* **The bible's `[OPEN]`s.** Nothing here says what feeding a dwarf king to
  Skarrag alongside the soulstones does. The Loremaster still has three theories
  and still believes none of them.
* **The soulstone undercurrent is not touched.** `quest_web.md` places no
  thirteenth touchpoint at Kazan-Dun and this ladder adds none. The hold's stash
  is bible canon, spoken about openly by dwarves; the province-wide buying is a
  separate, unnamed thing, and the two are never joined on any page.
* **The arc's four quests keep every id, target, count, group and reward.** Only
  their prose was cut.
