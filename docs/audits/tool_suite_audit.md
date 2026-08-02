# The in-editor tool suite, measured against the world it edits

**Date:** 2026-08-02
**Method:** every addon script read end to end; every one parse-loaded headless
under Godot 4.7; every data contract diffed against the live schema; the world
map Caleb has actually authored opened and counted cell by cell.

**Baseline before any change** (`tools/run_all_checks.ps1`):
`validate_content Errors: 0 Warnings: 160`, all 16 check scenes PASS.
**Every one of the 18 addon scripts parses clean in 4.7.** Nothing here is
broken in the way a stack trace is broken. The rot is entirely semantic: tools
that run, look like they worked, and write into a contract the world stopped
speaking.

---

## 1. The estate

| Addon | Registered as | What it edits | Where the output goes | Verdict |
|---|---|---|---|---|
| `addons/world_forge` | **its own plugin** (`plugin.cfg`, enabled) **and again** inside `level_editors` | the world grid: terrain / road / POI layers on a 64x64 canvas | `user://world_forge_map.json` | **runs, and silently rewrites the game's world** - see §2 |
| `addons/level_editors` | plugin (enabled) - umbrella menu | nothing itself; hosts the other six | - | works; is the duplicate-registration source |
| `addons/level_editors/town_editor` | has a `plugin.cfg` that **nothing enables**; reached only through the umbrella | town layouts: buildings, NPCs, props, functionals -> `.json` layout + exported `.tscn` | wherever the file dialog is pointed | works; knows nothing about the living world |
| `addons/dungeon_editor` | **its own plugin** (bottom panel) **and again** inside `level_editors` | 20x20 painted dungeon grid | dungeon layout json | works; duplicated |
| `addons/authoring_tools/npc_composer` | no `plugin.cfg` at all; umbrella only | `data/npcs/*.tres` + `data/npc_profiles/` | real, live data | works |
| `addons/authoring_tools/dialogue_editor` | same | `data/blueprints/{npcs,quests}/` | **notes for a human**, not game data | works as designed; the design is a notepad |
| `addons/authoring_tools/event_editor` | same | `data/events/*.json` | **a directory that does not exist, in a format no runtime reads** | **inert. This is the "script tool".** See §4 |

`addons/authoring_tools` has no `plugin.cfg`. It is not a plugin. It is four
docks that exist only because `level_editors_plugin.gd` preloads them by path.
That is not a bug, but it is why nothing about them is discoverable.

**Duplicate registration is real.** `project.godot`'s `editor_plugins` enables
`dungeon_editor`, `level_editors` and `world_forge`. `level_editors` builds its
own World Forge window and its own Dungeon Editor window. So World Forge exists
twice in one editor session, as two docks over two `MapState`s, and whichever
one Caleb typed into last is the one that wins the next Export. Two editors,
one file, no warning.

---

## 2. World Forge: what it was, what the new world did to it

### 2a. What it edits

A 64x64 painted grid with the editor origin at (32,32), three layers -
`terrain` (11 values), `road` (5), `poi` (14) - plus a `poi_data` dictionary of
name / type / notes / scene_path / layout_path / location_id per POI cell.

### 2b. The one that matters: the map is not in the repository

`EXPORT_PATH := "user://world_forge_map.json"`.

That file exists on this machine, at
`AppData/Roaming/Godot/app_userdata/Broken Provinces/world_forge_map.json`.
It is **4096 painted cells and 56 POIs** of real authored work. It is not in
git. The validator has never read it. No other machine has it. An exported
`.exe` on a playtester's PC does not have it.

**And it is not an overlay. It replaces the world.**

```gdscript
static func initialize() -> void:
    ...
    if _load_from_forge_map():
        _forge_map_loaded = true
        return          # <- LOCATIONS, LOCATION_SCENES, ROAD_CONNECTIONS,
                        #    scene_size, wip, is_start: never applied
```

So the game Caleb plays and the game in the repository are two different games,
and have been for as long as that file has existed. Measured:

| | repository world | the world on this machine |
|---|---|---|
| source | `world_grid.gd` `GRID_DATA` + `LOCATIONS` | `user://world_forge_map.json` |
| cells built | 800 (20 x 40) | **4096** |
| cells outside `GRID_MIN..GRID_MAX` | 0 | **3296** |
| locations | 60-odd, each with a scene, a size, a WIP flag | 56 POIs, **28 of them with no scene at all** |

### 2c. The four consequences, each measured

**(i) 3296 painted cells are thrown away, or worse, kept.**
`_load_from_forge_map()` writes a `CellInfo` for every painted cell including
x -32..31 / y -32..31, but `is_in_bounds()` still answers for -12..7 / -8..31.
Callers that check bounds first see a 20x40 world; callers that call
`get_cell()` directly see a 64x64 one. Two disagreeing worlds inside one
process. Meanwhile `WorldForgeImporter.apply_to_world_grid()` - which runs
*again*, separately, from its own autoload `_ready()` - does check bounds, and
drops the same 3296 cells on the floor without a word.

**(ii) 23 of the 56 places Caleb painted do not exist in the game.**
Out of bounds, therefore never built by the importer:

> bandit_camp_desert, bandit_camp_eastern_road, bandit_camp_north,
> bandit_camp_tundra_east, bandit_camp_tundra_west, bloodsand_arena,
> cultist_temple_north, east_hollow, elven_city, falkenhaften,
> goblin_camp_eastern_hills, goblin_camp_tundra, kings_watch,
> pirate_camp_island, pirate_stronghold, pola_perron, rotherhine,
> ruined_temple_eastern, ruined_temple_frost, ruined_temple_island,
> ruined_temple_swamp, smuggler_cove, whalers_abyss

Five of those - `bloodsand_arena`, `east_hollow`, `elven_city`,
`whalers_abyss`, `pirate_stronghold` - have hand-built scenes sitting in
`scenes/levels/`. They are unreachable because the map that places them puts
them past the edge of the world.

**(iii) Hand-crafted levels stop loading.**
`LOCATION_SCENES` is the canonical id -> scene table and the forge path never
consults it; a POI's scene comes only from whatever string is sitting in that
POI's `scene_path` field. 28 of the 56 carry `""`. `CellStreamer` reads
`cell.scene_path`, finds nothing, and generates a procedural town instead. The
same path also loses `scene_size`, so `is_covered_by_scene()` believes every
town is exactly one cell, and loses `wip`, so unfinished places show on the map
and in fast travel.

**(iv) Dalhurst moved, and its entire population stayed behind.**
`world_grid.gd` puts Dalhurst at (-8,-2). The forge map puts it at (-10,-2).
Every Dalhurst record in `data/npc_schedules.json` names `"cell": [-8,-2]`, and
`validate_content._check_schedules` measures station positions against that
cell. On this machine the town label is two cells west of the town's people.

**(v) Half the world is in two places at once.**

This is the finding that replaces the one an earlier draft of this document
made, and it is worth saying which. That draft claimed eleven of the map's POIs
were phantoms - names with nothing behind them, invisible to the grounding lint
because it reads `world_grid.gd` as source text. **Measured against `LOCATIONS`,
that is wrong: all 56 forge POIs are declared.** The lint was not being routed
around.

What is true is worse. **27 of the 56 places sit at a different cell in the
forge map than `world_grid.gd` says they do**, and because the forge path
returned before `LOCATIONS` ran, the map won:

| place | `world_grid.gd` | forge map |
|---|---|---|
| dalhurst | (-8, -2) | (-10, -2) |
| bloodsand_arena | (0, 3) | (-28, 29) |
| elven_city | (-11, 14) | (-28, 15) |
| larton | (-5, 20) | (-9, 15) |
| duncaster | (-1, 22) | (2, 13) |
| pirate_stronghold | (-10, 18) | (-16, 15) |
| smuggler_cove | (-15, 8) | (28, 10) |
| kings_watch | (5, -7) | (16, -4) |
| rotherhine | (6, -4) | (17, -13) |
| pola_perron | (3, -5) | (14, 7) |
| falkenhaften | (7, -9) | (26, -18) |
| ... 16 more | | |

Every quest that names a region, every fast-travel destination, every schedule
station that names a cell, and every `is_covered_by_scene()` answer was
computed against one of those two tables while the map drew the other.

The 28 POIs carrying no `scene_path` remain a real problem, and it is a
different one: `LOCATION_SCENES` has entries for most of them, and the forge
path never read it.

### 2d. The climate model

The climate model is `WorldGrid.biome_for_cell(coords, terrain)`: latitude 0.85
+ simplex 0.15 for temperature, a second simplex for moisture, a third as a
mountain mask, classified WINTER / DESERT / FOREST / PLAINS and flipped to a
ROCKY_ variant on highlands or high mountain noise. It is well-built and it is
not the thing that is broken.

Two ways the tools damage it:

- `WorldForgeImporter.apply_to_world_grid()` writes `cell.terrain` and **never
  writes `cell.biome`.** Paint a cell desert, apply it, and the cell is desert
  terrain wearing forest biome: forest floor textures, forest trees, forest
  tree density, because `BiomePalette` and `TerrainGenerator` are keyed on
  biome, not terrain.
- World Forge cannot express biome at all. Its 11 terrain values collapse onto
  9 `Terrain` enum values which collapse onto whatever the climate function
  decides. `WINTER`, `ROCKY_FOREST`, `ROCKY_PLAINS`, `ROCKY_WINTER`,
  `ROCKY_DESERT`, `UNDEAD`, `HORDE` are unreachable from the tool. A painter
  who wants a frozen valley at a warm latitude has no way to ask for one.

### 2e. Dead controls

| Control | Why it does nothing |
|---|---|
| **Edit Town** / **Edit Dungeon** | `_get_level_editors_plugin()` walks `get_parent()` from the dock. The dock's parents are `Window` -> the editor's base control -> ... -> the editor root. An `EditorPlugin` is never in that chain. It returns `null` every time, and both buttons print "Level Editors plugin not found". |
| **Apply to Game** | is `Export JSON` with a different label. Nothing is applied; the status line says so in small print. |
| **Sync POIs** | works, but writes `poi_data` entries with no `world_x` / `world_y`, so every synced location then reads `(X: 0, Y: 0)` in the inspector and `(0, 0)` in the list. |
| grid size 16..256 | the world is 20x40 and the tool offers 256x256 with no indication of where the playable edge is. That is how 3296 cells got painted into nowhere. |

---

## 3. Town Editor: what it was, what "improved" has to mean

It is the healthiest tool in the estate and by a distance the largest (3736
lines). It really does place buildings, NPCs, named NPCs read from
`data/npcs/`, props and functionals; it snaps to grid and to building edges,
checks overlaps, previews ghosts, and exports a `.tscn` whose `NPCSpawns`,
`PropSpawns` and `FunctionalSpawns` markers carry exactly the metadata
`TownSpawner` reads. That contract is intact.

What the new world added and the tool never learned:

- **The living world.** `NPCScheduler` needs, per npc_id, an archetype naming a
  file in `data/schedules/archetypes/` and three stations - `home`, `work`,
  `leisure` - each with a `cell`, an absolute-world `pos`, a `facing`, and
  optionally `interior` / `sit`. 112 such records exist in
  `data/npc_schedules.json`. **All 112 were generated by a Python script from a
  headless census.** There has never been a way to author one by hand, so
  placing an NPC in the Town Editor gives you a body with no day.
- **World coordinates.** Element positions are scene-local. A station `pos` is
  absolute world space - `WorldGrid.cell_to_world(cell) + local`. Nothing in
  the tool performs that conversion, and `validate_content` fails a station
  whose `pos` falls outside its claimed cell, so a hand-written record made
  from what the tool shows you would fail the gate.
- `load_scene(path)` - the entry point World Forge calls - **is a stub that
  sets a status label and returns.**
- **Corrected 8/2 on a second read:** an earlier draft of this table claimed
  `_create_blank_from_settlement()` dropped the location's world coordinates.
  It does not. All three entry points - that one, `_import_existing_scene()`
  and `create_new_town()` - write `metadata.world_x` / `world_y`. The cell is
  known; nothing had ever used it.

---

## 4. The "script tool", identified

It is **the Scripted Event Editor**, `addons/authoring_tools/event_editor/`,
898 lines, three panels, a timeline, 23 action types.

Caleb never understood how it worked because **it does not work**, in the exact
sense that there is nothing for it to work on:

- it writes `res://data/events/*.json`; **`data/events/` does not exist** and
  the tool has never been used to completion;
- **no script anywhere in `scripts/`, `tools/` or `dev/` contains the string
  `data/events`.** There is no event runtime. There is no loader. There is no
  trigger. The 23 action types resolve to nothing;
- the file it would write has no schema anyone else agreed to, so even a
  correct file would be correct about nothing.

It is a timeline editor for a cutscene system this game does not have. It was
never explainable, because there was never anything to explain. It is removed,
and the slot it occupied on the menu is now the Quest Authoring panel - which
writes into `data/quests/`, a directory 236 real files deep, that the engine
reads on every boot and the validator checks on every commit.

The neighbouring Quest Blueprint editor is a different thing and stays: it
writes `data/blueprints/quests/`, which is honestly a notepad for handing an
idea to an agent, and 10 notes are in it.

---

## 5. What "improved" means, per tool

| Tool | Was | Now |
|---|---|---|
| **World Forge** | painted into `user://`, replaced the world wholesale, dropped 3296 cells and 23 places without a word, could not express biome, two dead buttons | canonical map lives in the repository; the playable edge is drawn on the canvas and painting past it is reported, not swallowed; location metadata (scene, size, WIP) still comes from `world_grid.gd` so hand-crafted levels keep loading; a biome layer that overrides the climate model per cell and defaults to it everywhere else; Edit Town / Edit Dungeon reach the plugin |
| **Town Editor** | laid out bodies | lays out bodies **and their day**: archetype + home/work/leisure stations per NPC, written into `data/npc_schedules.json` in absolute world coordinates, with an hour scrub that shows the town at 03:00 and at 13:00 before it is saved |
| **Dungeon Editor** | worked, registered twice | registered once |
| **NPC Composer** | worked | unchanged |
| **Blueprint editors** | worked, are notepads | unchanged, and the guide says they are notepads |
| **Scripted Event Editor** | inert | removed |
| **Quest Authoring** | did not exist | form over the real quest schema, ids checked against the live registries as they are typed |

Everything above is documented for a human in `docs/design/TOOLS_GUIDE.md`.
