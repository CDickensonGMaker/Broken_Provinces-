# Terrain Engine Retrofit — CoG track (2026-08-01)
*Source engine: `C:\Users\caleb\RECONgame\terrain\` (READ-ONLY — it is the standalone TerrainEngine + ~60 fix commits; port THIS, not `C:\Users\caleb\TerrainEngine\`). Companion plan: `BP_RTS_Dark_Shadows\TERRAIN_PORT_PLAN_2026-08-01.md`. Scout findings summarized inline.*

## Goal
Biome-driven random terrain in the open world: 8 European-styled profiles — **winter, woodlands, grasslands, desert + rocky-mountain variant of each** — generated per wilderness cell, using existing CoG art (plus scripted recolors for the two missing ground tiles).

## Key scout facts
- Zero 4.6/4.7-only APIs in the engine; 4.5-safe. Typed dicts only in comments.
- CoG already has a partial port: `scripts/world/terrain/enhanced_terrain.gd` (455 ln, "Based on TerrainEngine"). The seam is proven and narrow:
  - `wilderness_room.gd:540 _create_heightmap_terrain()` → `EnhancedTerrain.generate(cell_x, cell_z, biome, material, blend_edges) -> {node, heights}` + `get_height_at()` readback (:605).
  - **`cell_streamer.gd` needs ZERO changes** (100m cells, 3×3 ring, floating origin keyed off WorldGrid cell coords).
- Do NOT port RECON's TerrainManager chunk streaming — CoG's CellStreamer stays the streamer. Port the **generator core + relief normalization + TerrainConfig height authority + terrain_zoning classifier + edge blending**, and optionally the tree-cover LOD mechanism.
- RECON fixes that matter here: TerrainConfig single height authority (`terrain/core/terrain_config.gd`), relief normalization w/ percentile span clamp (`terrain_engine.gd:18-26` — fixes flat-topped mountains), deterministic per-seed everything (ADR-010), `terrain_zoning.gd` as THE classifier pattern (extend to 8 biomes here).

## Phases (commit + headless-boot-verify each; Godot 4.5 binary at `C:\Users\caleb\_tools\godot45\`)
1. **Port the generator core** into `res://terrain/` (terrain_engine.gd, terrain_config.gd, heightmap_storage.gd, terrain_zoning.gd + whatever they minimally need; remap `res://` paths; add needed WorldConfig constants into TerrainConfig rather than a new autoload). Keep CoG's existing autoload count in mind — prefer static/class_name over new singletons where possible.
2. **Rewire the seam**: rebuild `enhanced_terrain.gd`'s interior on the ported generator, keeping its exact two-function contract so wilderness_room/cell_streamer don't change. Preserve/verify cross-cell edge blending (adjacent cells must stitch seamlessly — this is the #1 regression risk).
3. **8-biome plumbing**: widen `WorldGrid.Biome` (world_grid.gd:22), remove the lossy `to_wilderness_biome()` collapse (:933 — DESERT/COAST→PLAINS), widen `WildernessRoom.Biome` (wilderness_room.gd:21), add 8 presets to `HEIGHT_SETTINGS`/`BIOME_PRESETS` (enhanced_terrain.gd:16/31) — rocky variants = same biome palette, mountain-preset relief. **Save compatibility: append enum values, never reorder existing ones.**
4. **Biome texturing**: fix `wilderness_room.gd:2034 _get_floor_texture()` (currently ignores biome entirely) + sync `CellStreamer._get_biome_floor_texture()` (:476). Asset map: grasslands=`plains_floor1-3.png`, woodlands=`leaves_full/half.png`, rocky=`rockhill_floor1-3.png` + `Cliff_01/02.obj`; **winter + desert tiles don't exist** — generate them by scripted recolor (Python/PIL) of plains/rockhill tiles into `assets/textures/environment/floors/` (`winter_floor1-3.png`, `desert_floor1-3.png`), 64², palette-shift not photo-source (art storage law). Winter tree anchor: `fir_001.fbx`; desert: `cactus_001.fbx` + rocks.
5. **Vegetation per biome**: density/species tables per biome using existing tree pack (36 FBX trees, 8 bushes at `assets\sprites\environment\trees\tree_pack_1.1\...`), billboards (green_tree/autumn_tree/barren_bush), zoning-driven placement, deterministic per cell seed.
6. **Random world assignment**: biome assignment over the world map from seeded noise (temperature/moisture two-noise pick of the 4 bases; mountain-mask noise flips to rocky variant), replacing/extending WorldGrid's current biome source so the world genuinely varies winter→desert across regions, European latitudinal feel (winter north, desert south is fine).

## Verification
- Real `--headless --quit` boot per phase with the 4.5 binary ONLY.
- A probe script (`tools/probes/terrain_probe.gd`): generate one cell of each of the 8 biomes headless, assert height range within preset relief, assert edge continuity between two adjacent cells (max seam delta < 0.01), assert same-seed determinism. Run it per phase.
- Caleb's eye gate tonight: walk cell boundaries (seam check), visit each biome via debug teleport, old saves still load.

## Out of scope
Water/hydrology port (CoG has no water solve today — don't add), craters/DamageSystem, fog of war, RECON's chunk streaming, new hand-authored art.
