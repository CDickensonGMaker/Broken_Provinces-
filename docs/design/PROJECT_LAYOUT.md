# Project layout

*Written 2026-08-02, ahead of the clean-room reorganisation it describes.*

Caleb twice proposed restarting Broken Provinces from scratch, both times naming
file organisation as the reason. The ruling was: no restart. Instead, move the
project into the folder structure a fresh project would have been given on day
one, and delete everything that would not have made the cut.

This document is the map. It is the answer to "where did X go".

---

## The principles

1. **A folder name is a claim about what is inside it.** `scripts/autoload/`
   was not a domain, it was a deployment detail — forty-four files whose only
   shared property was a line in `project.godot`. `scripts/levels/`,
   `scripts/world/`, `scripts/npcs/` and `scripts/generation/` all held NPCs.
   Directories now name what the code *is*, and `project.godot` remains the
   index of which of them happen to be autoloaded.

2. **Two levels of nesting, rarely three.** Deep trees hide things as
   effectively as flat ones.

3. **A singleton directory is noise.** `scripts/vfx/` held one file.
   `scripts/lighting/` held one file. `scenes/summons/`, `scenes/structures/`,
   `scenes/puzzles/`, `scenes/vfx/`, `scenes/player/`, `scenes/enemies/` each
   held one or two. They are gone, folded into the domain they belong to.

4. **Migration status is visible in the tree.** The project is mid-pivot from
   billboard sprites to models. Every sprite now lives under
   `assets/sprites/legacy/`, so the size of the remaining job is legible from
   `ls` rather than from a document.

5. **Names do not contain spaces or capitals.** `scenes/levels/town editor
   towns/`, `assets/audio/background music/` and `assets/audio/Ambiance/` all
   broke tooling that assumed otherwise, at least once each.

6. **Keeping is cheaper than being wrong.** Where a move buys tidiness and costs
   a large reference surface, the move was not made. `scripts/data/` stayed
   exactly where it is: 601 `.tres` files name those scripts in their
   `ext_resource` lines, the directory is already coherent, and renaming it to
   `scripts/resources/` would have bought one word.

---

## The shape

```
scripts/
  core/             game/save/scene/world state, flags, audio, UI, dice, RNG,
                    the world grid and the loot tables. The services every
                    other directory depends on and that belong to no domain.
  world/            the world you walk around in
    streaming/      cell streamer, GPS, cell edges, cave manager, world forge
    terrain/        generation config, biome palette, zoning, the terrain mesh
    interactables/  everything the player can press E on
    props/          things that are only scenery
  characters/
    player/         controller, camera, first-person arms, held weapon, torch
    npcs/           every person who is not the player or an enemy
    enemies/        enemy base, spawner, summons
    visuals/        the body: billboards, rigs, the citizen dresser
    ai/             schedules, followers, companions, escorts, wander
  systems/          the rules, one directory per rule set
    quests/  factions/  combat/  economy/  dialogue/
    crime/   travel/    events/   puzzles/
  generation/       code that builds space at runtime
    towns/  dungeons/  wilderness/  rooms/
  levels/           one script per hand-authored place; content, not systems
  ui/               screens, panels, HUD
  data/             Resource subclasses. Unchanged - see principle 6.

scenes/
  levels/           the 51 hand-authored places. Untouched: this is the boot
                    sweep's denominator and it must stay comparable.
  characters/       player, enemy base, NPC instances, summons
  world/            interactables, stations, structures, the boat
  effects/          projectiles, muzzle smoke, explosions
  generation/       caves/ kazan_dun/ dungeons/ dungeon_rooms/ wilderness/
                    entrances/ puzzles/ towns/
  ui/               screens

data/
  quests/  items/  weapons/  armor/  enemies/  npcs/  factions/  spells/
  spell_effects/  enchantments/  blueprints/  schedules/  followers/
  companions/  encounters/  travel/  lore/  world/  npc_profiles/  recipes/
  projectiles/      was resources/projectiles/ - data, so it lives in data/
  towns/            was scenes/levels/"town editor towns"/ - JSON, not scenes
  dialogue/         one tree, was three
    trees/          the authored dialogue trees (JSON), companions/ inside
    resources/      the DialogueData .tres files (was data/dialogues/)
    pools/          the conversation pools (was data/conversation_pools/)

assets/
  characters/       citizens and the waves that follow them
  world/            buildings/ caves/ dwarven/ props/ terrain/ nature/
  weapons/          melee/ ranged/ musket/
  audio/            music/ ambience/ sfx/ generated/
  textures/  materials/  shaders/  ui/
  sprites/legacy/   ALL billboard sprites. Being phased out; the path says so.

tools/              headless gates. Run by hooks and by run_all_checks.ps1.
  check_*.gd/.tscn  the probes
  probes/           scratch instruments that never gate
  build/            content generators and CSG exporters
  fixtures/  hooks/  citizens/
dev/                human-facing, hand-run
  harnesses/        test scenes and their scripts, together
  editors/          the zoo, the item zoo, the viewmodel editors
  tools/            editor-side scripts
docs/               adr/ gdd/ design/ audits/ lore/
addons/             untouched. Plugin paths are fragile and already work.
production/         war room records. Untouched.
```

### Where the autoloads went

`core/` is not "the autoloads". A domain autoload lives with its domain, and
`project.godot` is the index of which scripts are autoloaded. The split:

| New home | Autoloads |
|---|---|
| `scripts/core/` | GameManager, SaveManager, SceneManager, WorldState, FlagManager, GameSystems, ActorRegistry, UIManager, PostProcess, AudioManager, StatsTracker, DiceManager, WorldGrid, LootTables |
| `scripts/world/streaming/` | CellStreamer, PlayerGPS, WorldForgeImporter, CaveManager |
| `scripts/world/` | WeatherManager |
| `scripts/systems/quests/` | QuestManager, JournalManager, CodexManager |
| `scripts/systems/factions/` | FactionManager, GuildRankManager, MoralityManager, TakeoverManager |
| `scripts/systems/combat/` | CombatManager |
| `scripts/systems/economy/` | InventoryManager, CraftingManager, EnchantmentManager, SoulstoneEconomy, SpellCreator |
| `scripts/systems/dialogue/` | DialogueManager, ConversationSystem |
| `scripts/systems/crime/` | CrimeManager, BountyManager |
| `scripts/systems/travel/` | BoatTravelManager, FastTravelManager |
| `scripts/systems/events/` | EncounterManager, TournamentManager, DuelManager, RestManager |
| `scripts/characters/ai/` | NPCScheduler, FollowerManager, CompanionManager, EscortManager |

`WorldGrid` and `LootTables` were the clearest case of principle 1: two
autoloads living in `scripts/data/` because they also declare data shapes.

---

## The complete old -> new map

The machine-readable map is `tools/layout_rules.json`; the expansion of it into
2185 individual file moves is `tools/layout_moves.tsv`, and the 139 deletions
are `tools/layout_deletes.tsv`. Both are committed, so this is auditable rather
than assertable.

Read `layout_rules.json` top to bottom: rules are applied in order and the first
match wins, so a file rule always precedes the directory rule that would
otherwise sweep it up.

### Directory-level summary

| Was | Is |
|---|---|
| `scripts/autoload/` | split across `core/`, `world/`, `systems/*`, `characters/ai/` (table above) |
| `scripts/world/` | `scripts/world/interactables/` (36), `characters/npcs/` (4), `world/props/` (1), `world/streaming/` (1), stayed (2) |
| `scripts/terrain/` | `scripts/world/terrain/` |
| `scripts/lighting/`, `scripts/props/` | `scripts/world/props/` |
| `scripts/audio/` | `scripts/world/ambient_soundscape.gd` |
| `scripts/player/` | `scripts/characters/player/` |
| `scripts/npcs/` | `scripts/characters/npcs/` |
| `scripts/enemies/`, `scripts/summons/` | `scripts/characters/enemies/` |
| `scripts/visuals/`, `scripts/components/billboard_sprite.gd` | `scripts/characters/visuals/` |
| `scripts/components/wander_behavior.gd` | `scripts/characters/ai/` |
| `scripts/combat/`, `scripts/vfx/` | `scripts/systems/combat/` |
| `scripts/dialogue/` | `scripts/systems/dialogue/` |
| `scripts/travel/` | `scripts/systems/travel/` |
| `scripts/puzzles/` | `scripts/systems/puzzles/` |
| `scripts/encounters/` | `scripts/systems/events/` |
| `scripts/systems/disposition_calculator.gd` | `scripts/systems/factions/` |
| `scripts/systems/log.gd` | `scripts/core/log.gd` |
| `scripts/generation/*town*` + `scripts/levels/town_spawner.gd` | `scripts/generation/towns/` |
| `scripts/generation/wilderness_*` | `scripts/generation/wilderness/` |
| `scripts/dungeons/` | `scripts/generation/dungeons/` |
| `scripts/rooms/` | `scripts/generation/rooms/` |
| `scripts/tools/`, `scripts/dungeons/tools/` | `dev/tools/` |
| `scripts/dev/`, `scenes/dev/`, `dev/dev/` | `dev/harnesses/` |
| `dev/{weapon_editor,unit_viewer,item_zoo,zoo}/` | `dev/editors/` |
| `tools/{_probe_*,cell_probe,terrain_probe,probe_npc_ids}` | `tools/probes/` |
| `tools/{csg_*,gen_*.py,make_biome_floor_tiles.py}` | `tools/build/` |
| `scenes/{player,enemies,npcs,summons}/` | `scenes/characters/` |
| `scenes/{vfx,combat}/` | `scenes/effects/` |
| `scenes/{interactables,structures,travel}/` | `scenes/world/` |
| `scenes/rooms/caves/`, `scenes/rooms/kazan_dun/` | `scenes/generation/{caves,kazan_dun}/` |
| `scenes/dungeons/rooms/` | `scenes/generation/dungeon_rooms/` |
| `scenes/{dungeons,wilderness,dungeon_entrances,puzzles,generation}/` | `scenes/generation/*` |
| `scenes/levels/town editor towns/` | `data/towns/` (+ its one scene to `scenes/generation/towns/`) |
| `data/dialogue/*.json` | `data/dialogue/trees/` |
| `data/dialogues/` | `data/dialogue/resources/` |
| `data/conversation_pools/` | `data/dialogue/pools/` |
| `data/quests/_future/` | `docs/design/future_quests/` |
| `resources/projectiles/` | `data/projectiles/` |
| `assets/models/citizens/` | `assets/characters/citizens/` |
| `assets/models/*` (everything else), `assets/meshes/` | `assets/world/*` |
| `assets/sprites/*` | `assets/sprites/legacy/*` |
| `assets/audio/background music/` | `assets/audio/music/` |
| `assets/audio/Ambiance/` | `assets/audio/ambience/` |
| `design/{adr,gdd}/` | `docs/{adr,gdd}/` |
| root `PLAN.md`, `ROADMAP.md`, `TODO_NEXT_SESSION.md`, `ENEMY_DATA_SCHEMA.md` | `docs/` |

---

## The deletions, with proof of death

Fossil law: when a thing is replaced, the old one goes. Git history preserves
every one of these; the point of deleting is that the tree stops lying about
what is live. Nothing was deleted on suspicion — each line below is a grep that
came back empty, including a grep for the file's **uid**, which is the check
that actually bites, because Godot resolves by uid first and a file can look
path-unreferenced while still being loaded.

| Deleted | Proof |
|---|---|
| `scripts/player/player.tscn` | A stub. All ~40 references in the tree point at `scenes/player/player.tscn`, a different and larger file. Its own uid `ce4ug0lflj8qp` greps to exactly one hit: its own header. Its sibling `.gd` files are live and were moved, not deleted. |
| `scripts/generation/daggerfall_terrain.gd` | `class_name DaggerfallTerrain` greps to its own declaration and one string literal inside itself. Its uid greps to its own `.uid` file. Its docstring claims `WildernessRoom` uses it; `wilderness_room.gd:530` calls `EnhancedTerrain.generate()`. The comment was the only thing making it look alive. |
| `archive/` (19 files) | 17 legacy quest JSONs — `QuestManager._load_quests_from_directory` walks `res://data/quests/` and nothing else. 1 orphaned script (`whaelers_drake.gd`, uid → 0 hits; named only in prose). 2 unused PNGs, uids → 0 hits. All 19 have git history. |
| `Sprite folders grab bag/` (52 PNG + 52 `.import`) | The union of all 52 uids, grepped across the whole tree and `.godot/`, returns 0 hits. The one document that names the folder (`assets/sprites/SPRITE_REFERENCE.md`) lists filenames that are not in it. |
| `Gameplay footage/` | Gitignored capture output. `project.godot`'s `movie_writer/movie_file` pointed into it and is repointed to `dev/recordings/`. |
| `scenes/levels/modular house blocks{, 1, 2}.glb` | Byte-identical (md5-verified) to the `assets/models/buildings/` copies. Their uids grep to 0 hits outside their own `.import` files. `willow_dale_UPDATED.glb`, in the same directory, IS referenced and was moved, not deleted. |
| `resources/projectiles/goblin_bolt.tres` | 0 hits by filename and by stem. Its header carries no `uid=` at all, so there is no uid path either. The other four projectiles in that directory are live and moved to `data/projectiles/`. |
| `README.txt`, `README broken provinces.txt` | Byte-identical to each other, referenced by nothing, superseded by `README.md`. |

### Kept, against the first instinct

- **`data/quests/_future/` (9 files) was moved, not deleted.** The brief called
  for deleting it once its live-quest conflicts were resolved. They are:
  `aberdeens_blessing.json` and `missing_miner.json`, the two forks that shadowed
  live quests, are already gone from the tree. But the nine files that remain are
  not fossils — they are unreleased quest designs with no live equivalent
  anywhere (`capital_intrigue`, `journey_to_kazandun`, `larton_famine`,
  `missing_surveyors`, `rat_problem`, `tenger_scouts`, `the_false_queen`,
  `the_imprisoned_king`, `the_kings_secret`). Deleting them would lose design,
  not remove a fossil. They move to `docs/design/future_quests/`, which achieves
  the actual goal — a staging directory that can no longer collide with the live
  quest loader — without burning nine unwritten quests.
- **`docs/audits/legacy/`** — nothing links it, but it is the audit record and
  costs nothing.
- **`dev/dev/`** — the doubled directory is gone, but its four test harnesses
  moved into `dev/harnesses/` rather than dying. They are hand-run, so no
  automated check would have missed them.
- **`scripts/data/`** — see principle 6.

---

## The gates that keep this true

`tools/check_no_broken_paths.tscn` is new and permanent. It reads every file in
the project that can carry a path, pulls out every `res://` literal, and demands
the target exist. It closes the failure class this migration created for good:
a reference that rotted and stayed invisible because the uid still resolved.

`tools/boot_sweep.ps1` is the 51-scene boot sweep, previously a scratch script
that lived in a temp folder and was rewritten by hand each time it was needed.
It now lives in the repo, writes a normalised class table, and can be diffed
run against run.

Old saves keep loading. `SaveManager` remaps every `res://` string it reads out
of a save file through the same old -> new table, unconditionally and
idempotently, on both of the two paths that parse a save. `check_fresh_boot`
carries a fixture written in the old layout and proves it.

## What this document does not cover

`scenes/levels/` was deliberately left alone beyond removing four misfiled
assets. It is 51 files whose names are already the place names, and it is the
denominator of the boot sweep; re-domaining it would have made the before/after
comparison meaningless for no gain.
