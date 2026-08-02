# ADR-001: Cell-Based World Streaming

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** Technical Director, Lead Programmer

---

## Context

The game requires a large open world (~800 cells) that players can explore seamlessly. Traditional approaches of loading entire world maps or using discrete zone transitions each have significant drawbacks.

### Requirements

1. **Seamless Exploration** - No loading screens between wilderness areas
2. **Memory Efficiency** - Cannot load entire 20x40 cell world at once
3. **Floating Point Precision** - Must handle player movement far from origin
4. **Hand-Crafted + Procedural** - Support both custom scenes and generated content
5. **Performance** - Maintain 60 FPS while streaming

### Inspirations

- **Daggerfall** - Original cell-based streaming (8x8 cells loaded around player)
- **Skyrim** - Seamless worldspace with cell boundaries

---

## Decision

Implement a **Daggerfall-style cell streaming system** with the following architecture:

### Core Components

1. **CellStreamer** (Autoload) - Loads/unloads cells around player
2. **WorldGrid** (Autoload) - Single source of truth for world data
3. **PlayerGPS** (Autoload) - Tracks player position and discoveries

### Cell Configuration

```
CELL_SIZE = 100 world units
LOAD_RADIUS = 1 cell (3x3 grid around player = 9 cells max)
UNLOAD_RADIUS = 2 cells (unload when 2+ cells away)
```

### Streaming Behavior

1. Player walks continuously - no teleportation at boundaries
2. When player crosses cell boundary:
   - CellStreamer detects via `world_to_cell()` conversion
   - Loads adjacent cells that aren't loaded
   - Unloads distant cells beyond UNLOAD_RADIUS
   - Notifies PlayerGPS of cell change
3. Main scene cell is registered and never unloaded

### Floating Origin

To prevent floating point precision issues far from origin:

```
ORIGIN_SHIFT_THRESHOLD = 2000 world units
When player exceeds threshold:
  - Shift all loaded cells toward origin
  - Shift player toward origin
  - Track cumulative offset in world_offset
  - Emit origin_shifted signal for entities
```

### Scene Type Handling

| Cell Type | Detection | Handling |
|-----------|-----------|----------|
| Hand-crafted | `scene_path` in CellInfo | Load scene, strip Player/HUD/lights |
| Procedural wilderness | Empty scene_path, no location | Generate via WildernessRoom |
| Procedural town | Location type but no scene | Generate via TownGenerator |
| Main scene | Registered via `register_main_scene_cell()` | Never unloaded |

### Lighting Management

Hand-crafted scenes loaded as streaming cells must have lighting stripped:
- DirectionalLight3D, WorldEnvironment removed
- Only main scene owns global lighting
- Prevents light doubling at boundaries

### Door Stripping

ZoneDoors stripped from streaming cells:
- Players navigate via walking, not doors
- Doors only work in non-streaming context

---

## Consequences

### Positive

1. **True Seamless World** - Players walk freely without loading screens
2. **Memory Bounded** - Maximum 9 cells loaded at once
3. **Precision Safe** - Floating origin prevents jitter far from start
4. **Flexible Content** - Hand-crafted and procedural cells coexist
5. **Deterministic** - World seed ensures consistent procedural content

### Negative

1. **Complexity** - Scene stripping logic is intricate
2. **Testing** - Hard to test all boundary crossing scenarios
3. **Save/Load** - Must preserve cell states and discoveries
4. **Performance Spikes** - Loading multiple cells at once can hitch

### Mitigations

- Scene stripping runs in deferred callbacks to ensure completeness
- Pending free tracking prevents race conditions
- External cell registration handles pre-existing main scenes

---

## Alternatives Considered

### Alternative 1: Zone Transitions with Loading Screens

**Approach:** Traditional area loading with explicit transitions

**Rejected Because:**
- Breaks immersion with loading screens
- Doesn't match Daggerfall/Skyrim inspiration
- Less exploration-friendly

### Alternative 2: Entire World in Memory

**Approach:** Load all cells at startup

**Rejected Because:**
- Memory requirements too high (~800 cells)
- Long initial load times
- Wastes resources on unvisited areas

### Alternative 3: LOD-Based Streaming

**Approach:** Keep distant cells loaded at lower detail

**Rejected Because:**
- Complexity not justified for PS1 aesthetic
- Billboard sprites don't need LOD
- Cell size already limits view distance

### Alternative 4: Async Background Loading

**Approach:** Load cells on background thread

**Considered For Future:**
- Godot 4's ResourceLoader supports threaded loading
- Current synchronous loading is acceptable
- May revisit if hitching becomes problematic

---

## Implementation Details

### CellStreamer API

| Method | Description |
|--------|-------------|
| `start_streaming(coords)` | Begin streaming from cell |
| `stop_streaming()` | Stop and unload all cells |
| `pause_streaming()` | Pause without unloading |
| `resume_streaming()` | Resume after pause |
| `register_main_scene_cell(coords, node)` | Register never-unloaded cell |
| `teleport_to_cell(coords, pos)` | Fast travel support |
| `is_cell_loaded(coords)` | Check cell state |

### Signals

| Signal | When |
|--------|------|
| `cell_loaded(coords)` | Cell finishes loading |
| `cell_unloaded(coords)` | Cell removed |
| `streaming_paused` | Entering interior |
| `streaming_resumed` | Exiting interior |
| `origin_shifted(shift)` | Floating origin moved |

### Integration Points

- **WildernessRoom** - Procedural cell generation
- **TownGenerator** - Procedural settlement generation
- **WorldGrid** - Cell metadata and scene paths
- **PlayerGPS** - Discovery tracking on cell entry
- **SceneManager** - Region tracking for UI
- **QuestManager** - Location reached notifications

---

## Files

| File | Purpose |
|------|---------|
| `scripts/world/streaming/cell_streamer.gd` | Core streaming logic |
| `scripts/core/world_grid.gd` | World data and locations |
| `scripts/world/streaming/player_gps.gd` | Position tracking |
| `scripts/generation/wilderness/wilderness_room.gd` | Procedural terrain |
| `scripts/generation/towns/town_generator.gd` | Procedural towns |

---

## References

- [Daggerfall Unity - World Streaming](https://github.com/Interkarma/daggerfall-unity)
- [Skyrim Creation Kit - Cell Basics](https://ck.uesp.net/wiki/Cells)
- [Godot 4 - World Partitioning Discussion](https://godotengine.org/article/why-isnt-godot-an-ecs-based-game-engine/)
