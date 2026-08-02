# The tools, in plain words

Seven tools live in the Godot editor. This says what each is for, how to open
it, and gives one worked example you can follow start to finish.

**They all live behind one button.** Open the project in Godot 4.7 and look at
the toolbar along the top: there is a dropdown labelled **Level Editors**.
Everything is in it.

```
Level Editors ▾
  World Forge          the land, and where places are
  Town Editor          a settlement, and the day its people keep
  Dungeon Editor       a dungeon's rooms
  ─────────
  NPC Composer         a named person: who they are, what they know
  NPC Ideas            a scratchpad for people you have not written yet
  Quest Ideas          a scratchpad for quests you have not written yet
  Quest Authoring      a real quest, checked as you type
  ─────────
  Close All
```

**One rule above all of them.** These tools write files that the game reads and
the validator checks. Before you commit anything they wrote:

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_all_checks.ps1
```

Errors must be **0**, and the warning count must not have gone up.

---

## Which tool do I want?

| I want to... | Tool |
|---|---|
| move a coastline, put a mountain range in, freeze a valley | World Forge |
| decide a new town exists and where it is | World Forge, then `world_grid.gd` |
| lay out the buildings in a town | Town Editor |
| decide where a shopkeeper sleeps and when the shop opens | Town Editor |
| see the town at three in the morning | Town Editor, Day preview |
| write a quest | Quest Authoring |
| create a named person with dialogue topics | NPC Composer |
| jot an idea down before you know what it is | NPC Ideas / Quest Ideas |
| build a dungeon's floorplan | Dungeon Editor |

---

## 1. World Forge - the land

**What it is for.** Painting the world map: what terrain is where, where the
roads run, and (rarely) forcing a biome the climate would not have chosen.

**How to open it.** Level Editors → World Forge.

**The one thing to understand.** *The map owns the land. `world_grid.gd` owns
the places.* Painting a town symbol on the map does not create a town. A place
exists because it has a row in `LOCATIONS` inside
`scripts/data/world_grid.gd` - which is where its id, its coordinates, its
scene, its size and its WIP flag live. The POI layer in World Forge is there so
you can see where those places are while you paint around them.

The map is saved to `res://data/world/world_forge_map.json`, in the
repository, and `WorldGrid` reads that exact file. If it is not there, the land
comes from `GRID_DATA` in the same script instead.

**The red rectangle is the edge of the world.** Everything greyed out beyond it
is a cell the game will never build. The canvas is deliberately bigger than the
world so you can sketch, but nothing outside the red line is real. (This matters:
before 8/2 there was no line, and 3296 painted cells had been put outside it.)

### Five steps: put a frozen valley in the northern hills

1. Open World Forge. Press **Center** so Elder Moor (0,0) is in the middle.
2. Click the **Terrain** tab, choose **Hill**, set the brush to **3x3**, and
   paint a few cells inside the red rectangle in the north.
3. Click the **Biome** tab and choose **WINTER**. Paint the same cells. They
   get a diagonal white stroke, which means *this cell was decided by hand.*
   Every unpainted cell is still decided by the climate model.
4. Press **Check map**. The status line counts anything the game would refuse.
   It should say the map is clean.
5. Press **Save map**, then run `tools/run_all_checks.ps1`.

### The buttons

| Button | What it does |
|---|---|
| **Save map** | writes `data/world/world_forge_map.json`, and tells you anything the game would refuse |
| **Reload map** | throws away unsaved edits and re-reads that file |
| **Check map** | counts cells past the edge, POIs `LOCATIONS` does not declare, POIs with no scene |
| **Clear All** | empties every layer |
| **Reload from WorldGrid** | rebuilds the canvas from `GRID_DATA` and `LOCATIONS` - the repository's own world |
| **Sync POIs** | adds a marker for every place in `LOCATIONS` the map is missing |
| **Import legacy map** | reads the pre-8/2 `user://world_forge_map.json`, if you still have one. It is not the world until you press Save map |
| **Edit Town / Edit Dungeon** | opens the selected place in the Town or Dungeon editor |

### Adding a new place to the world

World Forge cannot do this alone, on purpose. A place with a name and nothing
behind it is what THE GROUNDING LAW forbids. The order is:

1. add a row to `LOCATIONS` in `scripts/data/world_grid.gd` - `id`, `name`,
   `x`, `y`, `type`, `description`;
2. if it has a hand-built level, add `id -> scene path` to `LOCATION_SCENES`;
3. in World Forge, press **Sync POIs**; it appears, with its scene already
   attached.

Skip step 1 and **Check map** will name the place and tell you it is not in the
world.

---

## 2. Town Editor - a settlement, and its people's day

**What it is for.** Placing buildings, NPCs, props and functional things
(chests, doors, shrines, beds) in a town - and giving each NPC a day.

**How to open it.** Level Editors → Town Editor. Or pick a settlement from the
**Load:** dropdown in its toolbar, which imports the existing scene.

**Two files come out of it.** *Save* writes a `.json` layout you can reopen and
keep editing. *Export .tscn* writes the scene the game actually streams, with
every NPC, prop and functional turned into a `Marker3D` carrying the metadata
`TownSpawner` reads. Export writes the `.json` too, so they stay together.

### Giving an NPC a day

Select a placed NPC. In the inspector on the right there is a section called
**Their day**.

1. **Trade** - pick one. The list is read off `data/schedules/archetypes/`, so
   every entry is a trade that exists. A shopkeeper opens after breakfast,
   shuts for an hour at noon, and drinks at seven; a guard is on his post from
   before the shops open until after they shut; a night watch is awake when
   everyone else is not. Hover an entry to read its day.
2. **Stand the NPC where they sleep** (drag them there) and press
   **Set home here**. If the room behind that door is not modelled, tick
   **indoors (absent)** first - it means the NPC is simply not in the world
   while the schedule has them there, which is honest, and much better than
   putting a body inside a wall.
3. **Stand them at their post** and press **Set work here**.
4. **Stand them at the tavern bench** and press **Set leisure here** - tick
   **sitting** first if they sit.
5. Press **Write schedules**.

The readout under the buttons says what is set and what is not, and warns you
about the two things the validator will reject: a record with no **work**
station, and a quest giver nobody can reach between 09:00 and 17:00.

**Coordinates.** You never do this conversion yourself. Stations are stored
scene-local, exactly like every other element; **Write schedules** turns them
into the absolute world coordinates `NPCScheduler` reads
(`cell_to_world(cell) + local`). This is why the layout must know which cell it
is in - load it from the **Load:** dropdown, or from World Forge, and it does.

**Write schedules touches only this town.** The other hundred records in
`data/npc_schedules.json` belong to towns that are not open and are left alone.

### Day preview - the hour scrub

Tick **Day preview** in the toolbar and drag the slider.

Every scheduled NPC moves to where they stand at that hour. Anyone whose
station is indoors disappears, because that is what the game does. The label
reads out how many are outside, how many are indoors, and what they are all
doing:

```
03:00  -  2 out, 14 indoors  (2 work, 14 sleep)
13:00  -  15 out, 1 indoors  (9 work, 4 eat, 2 idle)
```

Nothing is saved. Untick and everyone goes back where you placed them.

**This is the eye test.** A town whose three in the morning looks like its one
in the afternoon has a clock, not a life.

### Five steps: a hamlet with three residents

1. Level Editors → Town Editor → **New**. Set the settlement type to
   **Hamlet**.
2. From the **Buildings** palette place an inn and two houses. Left click
   places; **R** and **Q** rotate; **Del** deletes.
3. From the **NPCs** palette place three people. Select each and give it an
   **NPC ID** in the inspector - lower case with underscores, unique.
4. For each: pick a trade, then set home / work / leisure as above.
5. **Write schedules**, then **Export .tscn**, then run
   `tools/run_all_checks.ps1`.

---

## 3. Quest Authoring - a quest, checked as you type

**What it is for.** Writing a real quest into `data/quests/`. The engine loads
that directory on every boot; the validator checks it on every commit.

**How to open it.** Level Editors → Quest Authoring.

**This replaces the Scripted Event Editor**, which is gone. That tool wrote
`data/events/*.json`, a directory that does not exist, in a format no script in
the project reads. It was never explainable because it never did anything.

**The right-hand column is the point of the tool.** Every id you type is looked
up against what is actually on disk - NPCs, items, enemies, factions, and the
quests already written - as you type it. A red row is a name the player could be
sent after that leads nowhere, which is the thing the validator fails commits
on. Press **Rescan registries** after adding an NPC in another tool.

### The fields that need explaining

**OR group.** Objectives sharing a group id are different answers to the same
problem. Settling any one settles the group, and the journal marks the rest
*"settled another way"* - the player did not do them, and does not owe them.
Leave the field empty for an objective that stands alone.

**World condition.** A small piece of JSON. If it already holds when the quest
is offered, that objective completes immediately - the *"you already did this,
here's your money"* moment. If every objective pre-completes, the quest
completes on offer.

```json
{"flag": "bandit_camp_cleared"}
{"flag": "kazan_dun_state", "equals": "fallen"}
{"any": [{"flag": "a"}, {"flag": "b"}]}
{"not": {"world_modification": "mountain_pass"}}
```

An empty condition is always false, so a typo can never hand out a free quest.

**Choice consequences.** What a branch actually does. Filed under the
objective's own id, so a `choice` objective's id *is* its choice id. Six keys
fire; anything else is documentation and the panel says so:

| Key | Effect |
|---|---|
| `flags_to_set` | the player's paperwork, on FlagManager |
| `world_flags_to_set` | facts about the world, on WorldState |
| `reputation_changes` | `{faction_id: amount}` |
| `unlock_follower` | a follower id |
| `spawn_enemy` | `"enemy_id@location_id"` |
| `items_given` | item ids |

### Five steps: a small delivery quest

1. Level Editors → Quest Authoring → **New quest**.
2. Fill in **Id** (`elder_moor_firewood`), **Title**, **Description**. Watch
   the right column: the id turns green when it is not already taken.
3. Set **Giver npc_id** to someone real. Red means no such NPC - fix it now,
   not after a headless run.
4. **Add objective**: id `gather_wood`, type `collect`, target an item id that
   resolves, count 5. Add a second: type `talk`, target the giver.
5. Set gold and XP, press **Save quest**, then run
   `tools/run_all_checks.ps1`. The validator checks the things only a booted
   game can - whether that giver is actually *spawned* in that region and awake
   at nine in the morning.

---

## 4. NPC Composer - a named person

**What it is for.** Creating and editing `data/npcs/*.tres` - a named NPC's id,
display name, race, archetype, faction, disposition, sprite, and the topics
they will talk about - and their knowledge profile in `data/npc_profiles/`.

**How to open it.** Level Editors → NPC Composer.

**Where they get a body.** The Composer writes who they *are*. The Town Editor
places them, out of the **Named NPCs** tab of its palette. The two are read in
that order: compose, then place, then give them a day.

**Where they get a 3D body.** One line in `data/character_models.json`:
`"npc_id": "citizen_man"`. That is the whole of flipping a character from a
billboard sprite to a 3D model; there is no per-character code.

### Five steps

1. Level Editors → NPC Composer → **New**.
2. Set the **NPC ID** (lower case, underscores) and **Display name**.
3. Pick a **race**, an **archetype** and a **faction**; set base disposition.
4. Set the sprite path and its frame counts. Wrong frame counts are the most
   common visual bug in this project - `tools/check_sprites.tscn` re-measures.
5. Save. Then open the Town Editor, find them under **Named NPCs**, place them,
   and give them a day.

---

## 5 and 6. NPC Ideas and Quest Ideas - the scratchpads

**What they are for.** Writing down an idea before you know what it is. WHO,
WHAT, WHERE, WHEN, in prose.

**How to open them.** Level Editors → NPC Ideas (Blueprint) / Quest Ideas
(Blueprint).

**Be clear about what they are.** They write `data/blueprints/`, which **the
game does not read**. A blueprint is a note to yourself or to an agent, and
turning one into a real quest means opening Quest Authoring and typing it in.
That is by design - it is where you write "a woman in Millbrook has lost
something and will not say what" before you know which item it is.

Ten quest blueprints are in there already.

---

## 7. Dungeon Editor - floorplans

**What it is for.** Painting a dungeon's rooms on a 20x20 grid and validating
that they connect: an entrance exists, every room is reachable from it, no
doorway opens onto nothing.

**How to open it.** Level Editors → Dungeon Editor.

**Note.** Dungeon *generation* at runtime goes through the SimpleDungeons addon
and `DungeonManager`. This editor is for hand-laid layouts.

### Five steps

1. Level Editors → Dungeon Editor. Name the dungeon.
2. Pick **Entrance** from the palette and click one cell.
3. Pick rooms and corridors and paint a path out from it. Leave
   **Auto-correct** ticked and it will fix the door flags between neighbours.
4. Press **Validate**. It fails on no entrance and on unreachable rooms, and
   warns about unconnected doorways and a missing boss room.
5. Press **Export**.

---

## Things that are true of all of them

**The status line at the bottom of each tool is the tool talking to you.** If a
button seems to have done nothing, read it - since 8/2 every refusal says why.

**Nothing writes outside the repository.** If a tool ever offers you a
`user://` path, that is a bug; it means the file it writes is invisible to git,
to the validator, and to every other machine. One tool did this for a long
time and it cost a whole authored world map.

**Two tools used to exist twice.** World Forge and the Dungeon Editor each
registered a second, separate copy of themselves next to the Level Editors
umbrella - two windows over two states writing one file. They stand down now,
so what you see in the dropdown is the only one.

**The full estate audit, with measurements, is in
`docs/audits/tool_suite_audit.md`.**
