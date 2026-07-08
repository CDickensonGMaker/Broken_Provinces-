# Performance Engineer Analysis: Desert Region Lag

**War Room Session — Broken Provinces desert performance audit**
**Analyst:** Performance Engineer
**Date:** 2026-07-08
**Complaint:** Severe lag when players reach the desert/sandy areas of the open world. Dev has never profiled these areas.

---

## 0. Where the desert actually is (context for everything below)

Two desert zones exist in `GRID_DATA` (`scripts/data/world_grid.gd:148-192`):

1. **Western Shore strip** — column 2 of every northern row (`"W","W","D",...`, rows 0-19). A 1-cell-wide desert ribbon with open WATER on its west edge for its entire length. Elder Moor-relative x = -10.
2. **Tenger Desert** — rows 32-39 (Elder Moor-relative y = 24..31). A large contiguous region **wedged between ocean (W) on the west and mountains (B/H) on the east/south** (`world_grid.gd:184-191`).

Both zones share one structural property no forest/plains cell has: **almost every desert cell touches at least one impassable edge (water or mountain), and deep-desert cells touch 2-3.** This matters because impassable edges are where the generators dump enormous amounts of extra geometry (see H1).

Also relevant: `WorldGrid.to_wilderness_biome()` maps `Biome.DESERT -> 1 (PLAINS)` (`world_grid.gd:940`), so desert cells run the PLAINS generation path in `WildernessRoom`. The `WildernessRoom.Biome.DESERT` enum value (`wilderness_room.gd:21`) and the `EnhancedTerrain` DESERT dune preset (`scripts/terrain/enhanced_terrain.gd:23, 97-103`) are **dead code — unreachable via streaming**. Desert is not "denser vegetation" than forest (plains spawns *fewer* trees); the lag comes from boundaries, enemies, and transparency, not cacti.

---

## 1. Root-cause hypotheses, ranked by likelihood

### H1 (VERY HIGH): Boundary-content explosion on impassable edges — desert cells generate 3-10x the nodes of interior cells

Every cell edge bordering BLOCKED or WATER terrain triggers **two independent generators** that both dump content:

**Per BLOCKED (mountain) edge:**
- `wilderness_room.gd:2542-2565` `_spawn_mountain_wall()`: `int(100/5)+1 = 21` mountain blocks. Each block (`_create_mountain_block`, `wilderness_room.gd:2764-2819`) = MeshInstance3D + **a brand-new `StandardMaterial3D` per block** + StaticBody3D + CollisionShape3D (~4 nodes, 1 unique material).
- `wilderness_room.gd:2721-2760` `_spawn_mountain_edge_rocks()`: **15-25 clusters × 3-7 rocks = 45-175 `HarvestableRock` nodes per edge** (each a StaticBody3D with mesh + collision, `scripts/world/harvestable_rock.gd:3`).
- `cell_streamer.gd:663-705` `_create_boundary_wall()`: 8 CSG cliff segments, each with **its own `StandardMaterial3D` created inside the loop** (`cell_streamer.gd:679`), each with `use_collision = true` (separate physics body per segment).

**Per WATER edge:**
- `wilderness_room.gd:2569-2593` `_spawn_water_boundary()`: 13 water plane segments, each a MeshInstance3D with **its own alpha-transparent material** (`_create_water_segment`, `wilderness_room.gd:2597-2618`).
- `wilderness_room.gd:2622-2662` `_spawn_coastal_decorations()`: 8-15 clusters × 2-4 = 16-60 rock/driftwood nodes, each with its own new material.
- `cell_streamer.gd:601-661`: 6 CSG coastal rocks + invisible collision wall.
- `cell_streamer.gd:708-779` `_add_coastal_decoration()`: **a 300×300-unit alpha-transparent CSGBox3D water plane** per water edge (see H2).

**The math:** a deep Tenger Desert cell with 2 mountain edges + 1 water edge gains roughly **250-700 extra nodes and 100-400 unique materials** on top of its normal biome content. A Greenwood forest cell surrounded by forest gains **zero**. With LOAD_RADIUS=1 (9 cells loaded, `cell_streamer.gd:23`), the desert can hold several thousand extra nodes vs. the starting area. Every unique `StandardMaterial3D.new()` breaks batching → hundreds of extra draw calls.

**Why the dev never saw it:** the starting Greenwood is interior forest — no impassable edges anywhere near the roads the dev tested.

### H2 (HIGH): Transparent overdraw + z-fighting from stacked water planes

Along any coast (and the desert is almost all coast) the following alpha-transparent surfaces coexist at nearly the same height:

| Surface | Y | Size | Source |
|---|---|---|---|
| CellStreamer coastal plane | -0.5 | **300 × 300 units** (extends across 3 cells of coast) | `cell_streamer.gd:713, 745, 756-776` |
| Water cell's own plane | -0.5 | 100 × 100 | `wilderness_room.gd:392-408` `_create_water_cell()` |
| WildernessRoom water segments | -0.3 | 13 × (10×8) per edge | `wilderness_room.gd:2581, 2597-2618` |

Each loaded coastal cell adds its own 300-unit plane, and they **overlap each other and the water cells' planes at identical Y = -0.5** → guaranteed z-fighting plus 4-8 layers of full-screen alpha blending when the player looks toward the sea. Transparent geometry is not occluded, not batched (unique materials each), and fog (`fog_depth_end` = 15-30 units) does **not** cull it — the GPU still shades all 300 units of each plane. On the west-facing Tenger coast this alone can halve the frame rate on weak GPUs.

### H3 (HIGH): Enemy count ~5-7x over budget — the "20 per zone" budget is enforced per CELL, not per world

- Danger level = `clampi(1 + (|x|+|y|)/3, 1, 10)` (`world_grid.gd:697-700`). Tenger Desert distance is 24-31 → **danger 9-10 everywhere**.
- `wilderness_room.gd:2081-2100` `_spawn_enemies()`: count = `(4..10) + min(danger-1, 6)` = **10-16 enemies per cell**; the `mini(scaled_max, 20)` at line 2098 caps a *single cell*, not the world.
- 9 cells loaded simultaneously → **~90-144 active enemies** vs. the CLAUDE.md budget of "Max active enemies per zone: 20".
- On top of that, `EncounterManager` force-checks on **every cell crossing** (`encounter_manager.gd:274-277`) plus every 30 s (`:14`), with desert biome multiplier 1.3 (`:39`), night ×1.5, and hordes of 8-15 (`:23-25`). Encounter spawns have **no global active-enemy cap** (`_spawn_encounter_enemies`, `encounter_manager.gd:735-773` — nothing counts existing enemies).
- Mitigation that saves the CPU (and hides the bug near home): `enemy_base.gd:543-555` has a good LOD (skip all AI beyond 60 units, ¼-rate beyond 30). So of ~140 enemies maybe 15-30 are fully simulated — but **all** of them keep a CharacterBody3D + collision shape + animated Sprite3D + per-frame `_physics_process` preamble (validity check + distance, `enemy_base.gd:514-541`), and all their sprites/shadows are render objects.
- Why the starting area is fine: cells covered by Elder Moor's 242×219 hand-crafted scene **skip enemy spawning entirely** (`wilderness_room.gd:271-274, 296-297`; `world_grid.gd:1012-1053`). The desert has zero hand-crafted coverage, plus max danger, plus tier-4 exotics (wyvern/basilisk/abomination, `wilderness_room.gd:2277-2298`).

### H4 (MEDIUM): Synchronous cell generation hitch on every boundary crossing

`CellStreamer._load_cell()` → `_generate_procedural_cell()` → `WildernessRoom.generate()` runs **entirely on the main thread in one frame** (`cell_streamer.gd:196-265, 358-382`). Crossing a boundary loads up to 3 new cells in the same frame. A desert cell builds 700-1700 nodes including dozens of `CSGBox3D`/`CSGCylinder3D` (ruins `wilderness_room.gd:1249-1372`, roads `:613-711`, cliff walls `cell_streamer.gd:671-705`, ground `wilderness_room.gd:510-536`) — CSG meshes are recomputed at tree-enter, which is the single most expensive per-node instantiation in Godot. Result: a visible hitch every 100 units traveled, much worse in desert because the cells are 3-5x bigger in node count (H1). The `mini(danger)` enemy loop also loads `.tres` + textures (cached, but EnemyData resources still instantiate).

### H5 (MEDIUM): Per-instance material allocation breaks batching everywhere, desert worst

`StandardMaterial3D.new()` is called per prop instance in at least: `_create_mountain_block` (`wilderness_room.gd:2780`), `_create_water_segment` (`:2608`), `_create_coastal_rock` (`:2676`), `_create_driftwood` (`:2699`), CellStreamer cliff segments (`cell_streamer.gd:679`), coastal decoration (`:720-729`), ground per cell (`wilderness_room.gd:523`), plus every ruin/road material. Identical-looking materials that could be `static`/`const` shared instances are instead hundreds of unique materials → no instance batching, hundreds of draw calls. Desert cells have by far the most of these (all boundary props).

### H6 (LOW-MEDIUM): Broken desert encounter table spams warnings and wastes rolls

`ENCOUNTER_TABLES["desert"]` references `giant_scorpion`, `snake`, `sand_wurm` (`encounter_manager.gd:109-114`) — **none exist in `ENEMY_SPAWN_CONFIG`** (`:134-196`). 60% of desert encounter rolls hit `push_warning` (`:747`) and silently fail. `push_warning` on every trigger is measurable in debug builds (console I/O) and hides real errors; not a primary lag cause but a bug regardless.

### H7 (LOW — largely ruled out): Floating origin / float precision

Tenger Desert sits 2400-3100 world units out; `ORIGIN_SHIFT_THRESHOLD = 2000` (`cell_streamer.gd:28`) triggers a shift before precision becomes a problem (float32 is fine to ~10k). The shift itself moves all loaded cells + emits `origin_shifted` (`:151-166`) — a one-frame spike when it happens, but not sustained lag. **Not the root cause**, though the spawn-position-desync recovery path in `enemy_base.gd:518-527` prints per-enemy log lines when shifts desync — with 140 enemies that `print` storm can itself hitch the frame; worth watching in the profiler.

### H8 (LOW): ~50-110 individual Sprite3D props per cell (grass/trees) with no MultiMesh

PLAINS path spawns 28-38 grass + 3-8 trees + 10-20 bushes + `_spawn_ground_props` adds another 23-45 sprites (`wilderness_room.gd:716-748, 1394-1400`). Universal across biomes (forest is worse), so not desert-specific — but it consumes the baseline frame budget that the desert's extra load then blows through.

---

## 2. Fixes, ranked by impact ÷ effort

| # | Fix | Impact | Effort | Detail |
|---|---|---|---|---|
| 1 | **Global enemy budget** | Very high | Low | In `_spawn_enemies()` and `EncounterManager._spawn_encounter_enemies()`, count `get_tree().get_nodes_in_group("enemies")` and clamp so world total ≤ 20-30. Optionally: only spawn enemies in the active cell + orthogonal neighbors, not diagonals. |
| 2 | **Gut the boundary rock spam** | Very high | Low | `_spawn_mountain_edge_rocks`: 15-25 clusters → 3-5; harvestable rocks per edge 45-175 → ~10. Pure constant changes at `wilderness_room.gd:2724, 2744`. |
| 3 | **One water plane per coast, shared material** | High | Low | Delete `_spawn_water_boundary`'s 13 segments (the CellStreamer coastal plane already covers it); make `_add_coastal_decoration` skip when the adjacent water cell is loaded (its own plane exists), or Y-offset planes by 0.02 steps to kill z-fighting; shrink 300-unit extent to fog range (~40 units). One `static` water material for everything. |
| 4 | **Shared static materials** | High | Low | Replace all per-instance `StandardMaterial3D.new()` in boundary/prop creation with `static var` shared materials (mountain, water, sand, coastal rock, driftwood, cliff). Restores batching; mostly mechanical edits. |
| 5 | **Merge mountain walls** | High | Medium | Replace 21 blocks + 8 CSG cliff segments per edge with 1 MultiMeshInstance3D (or one ArrayMesh) + one long BoxShape3D collider. Do the same for CellStreamer `_create_boundary_wall`. |
| 6 | **MultiMesh grass/rocks/driftwood** | Medium | Medium | Convert non-interactive decorative props (grass sprites can stay; coastal rocks/driftwood/mountain blocks are ideal MultiMesh candidates). |
| 7 | **Stage cell generation over frames** | Medium | Medium | Split `WildernessRoom.generate()` into phases (ground → props → boundaries → enemies) executed one per frame via `call_deferred`/awaited ticks; kills the boundary-crossing hitch. |
| 8 | **Replace CSG with MeshInstance3D** | Medium | Medium | Ruins, roads, cliff walls, ground boxes: swap CSGBox3D/CSGCylinder3D for BoxMesh/CylinderMesh + StaticBody3D. Eliminates CSG rebuild cost at load. |
| 9 | **Fix desert encounter configs** | Low (perf) / High (content) | Low | Add `giant_scorpion`, `snake`, `sand_wurm` to `ENEMY_SPAWN_CONFIG` or remove from the desert table. Also fixes 60% of desert encounters silently failing. |
| 10 | **Wire up real DESERT biome** | Cosmetic + minor perf | Medium | Map `WorldGrid.Biome.DESERT` → `WildernessRoom.Biome.DESERT` (5) instead of PLAINS, give it sparse desert prop counts (fewer sprites than plains), use the already-written EnhancedTerrain dune preset. Removes dead code, gives the desert an identity, and slightly reduces prop count. |

Fixes 1-4 are an afternoon of work and should recover the bulk of the lost frame time.

**Tradeoffs to name:** #1 makes the far world less densely hostile (danger fantasy reduced — mitigate by spawning reinforcement waves on combat); #2/#3 reduce visual density of coasts/mountain edges; #5/#6 make boundary rocks non-harvestable unless kept as separate sparse interactables (keep ~10 harvestable, MultiMesh the rest as decoration).

---

## 3. Verification / profiling plan

1. **Baseline vs. desert A/B:** from a dev build, `CellStreamer.teleport_to_cell(Vector2i(3, -2))` (Thornfield forest, baseline) then `teleport_to_cell(Vector2i(0, 29))` (Tenger Camp) and `teleport_to_cell(Vector2i(-7, 26))` (coastal desert). Record with Godot's profiler (Debugger → Profiler + Visual Profiler) for 30 s each.
2. **Renderer counters:** log `Performance.get_monitor()` for `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, plus `OBJECT_NODE_COUNT`, `PHYSICS_3D_ACTIVE_OBJECTS`, `TIME_PHYSICS_PROCESS`. Expectation if H1/H2 are right: draw calls and objects 3-6x higher in desert; if H3 is right: physics/process time scales with `get_nodes_in_group("enemies").size()` (log it — expect ~90-144 in desert vs. <20 at start).
3. **Bisection toggles:** add temporary flags to skip (a) `_spawn_mountain_edge_rocks`, (b) `_add_coastal_decoration` + `_spawn_water_boundary`, (c) `_spawn_enemies`. Measure FPS delta per toggle in the same desert spot — this attributes the lag precisely among H1/H2/H3 in three runs.
4. **Overdraw check:** run with `--debug` and set viewport debug draw to Overdraw (or `RenderingServer.viewport_set_debug_draw(..., VIEWPORT_DEBUG_DRAW_OVERDRAW)`) while facing the sea from a desert coast cell. Stacked bright red = H2 confirmed. Also look for shimmering z-fighting at the waterline.
5. **Hitch check:** with the Visual Profiler running, walk across desert cell boundaries; a >100 ms frame on crossing confirms H4. Compare with a forest boundary crossing.
6. **Console watch:** stderr for `[EncounterManager] No spawn config for enemy type: giant_scorpion/snake/sand_wurm` (H6) and `[AI] ... RECOVERY: spawn_position was broken` storms after origin shifts (H7 print spam).
7. **Regression gate after fixes:** desert FPS within 15% of forest FPS on the same machine; enemy group count ≤ 30; draw calls in desert ≤ 1.5x forest.

---

## 4. Key file references

- `scripts/data/world_grid.gd` — :148-192 grid layout (desert wedged between W and B), :697-700 danger formula, :933-942 DESERT→PLAINS mapping
- `scripts/autoload/cell_streamer.gd` — :23-24 load radius, :566-705 boundary walls (unique material per cliff segment :679), :708-779 300-unit transparent coastal plane
- `scripts/generation/wilderness_room.gd` — :2081-2100 enemy scaling (per-cell cap only), :2456-2504 boundary props, :2542-2565 mountain wall (21 blocks), :2721-2760 rock cluster explosion (45-175/edge), :2569-2662 water boundary + coastal decorations, :2764-2819 per-block materials
- `scripts/enemies/enemy_base.gd` — :514-555 AI LOD (good; keep), :518-527 recovery print spam
- `scripts/autoload/encounter_manager.gd` — :14 30 s checks, :23-25 hordes, :39 desert multiplier, :109-114 broken desert table, :735-773 no global cap
- `scripts/terrain/enhanced_terrain.gd` — :23, :97-103 unused DESERT dune preset (dead code)
