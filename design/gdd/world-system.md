# World System GDD

**Version:** 1.0
**Last Updated:** 2026-05-25
**Status:** Implemented

---

## 1. Overview

The world system defines the game's open world structure using a Daggerfall-inspired cell-based grid. The world is divided into 100x100 unit cells that stream around the player for seamless exploration. Elder Moor serves as the coordinate origin (0,0).

**Core Files:**
- `scripts/data/world_grid.gd` - World data and coordinate system
- `scripts/autoload/player_gps.gd` - Player position tracking
- `scripts/autoload/cell_streamer.gd` - Cell loading/unloading

---

## 2. Player Fantasy

Players explore a vast, seamless world without loading screens. Discovering new locations feels rewarding, and the map gradually reveals as they adventure. The world has history—roads connect settlements, dungeons hide in the wilderness, and different biomes create varied gameplay.

---

## 3. Coordinate System

### 3.1 Elder Moor Origin

All coordinates are **Elder Moor-relative**:
- **Elder Moor = (0, 0)** - The starting location
- **X increases East**, **Y increases South**
- Grid bounds: (-12, -8) to (7, 31)

### 3.2 Grid to World Conversion

```
World X = Grid X × 100
World Z = Grid Y × 100
```

Example: Thornfield at Grid (3, -2) = World position (300, 0, -200)

### 3.3 Cell Size

Each cell is **100 × 100 world units** (matches CELL_SIZE constant).

---

## 4. Terrain Types

| Terrain | Code | Color | Passable | Biome |
|---------|------|-------|----------|-------|
| BLOCKED | B | #3a3a3a | No | Mountains |
| HIGHLANDS | H | #6a6a5a | Yes | Rocky |
| FOREST | F | #3d6b30 | Yes | Forest |
| WATER | W | #38578a | No | Coast |
| COAST | C | #3e5e3e | Yes | Coast |
| SWAMP | S | #2e4a28 | Yes | Swamp |
| ROAD | R | #7a6545 | Yes | Plains |
| POI | P | #6a5a2a | Yes | Plains |
| DESERT | D | #a89840 | Yes | Desert |

---

## 5. Biome Types

Biomes determine procedural terrain generation and enemy spawns:

| Biome | Description |
|-------|-------------|
| FOREST | Dense trees, forest creatures |
| PLAINS | Open grassland, varied enemies |
| SWAMP | Murky water, undead, disease |
| HILLS | Rolling terrain, bandits |
| ROCKY | Elevated terrain, cliffs |
| MOUNTAINS | Impassable peaks |
| COAST | Beach terrain, pirates |
| UNDEAD | Corrupted areas, undead enemies |
| HORDE | Goblin territory |
| DESERT | Sandy dunes, Tenger enemies |

---

## 6. Location Types

| Type | Description | Map Marker |
|------|-------------|------------|
| NONE | Wilderness | None |
| VILLAGE | Small settlement | Small circle |
| TOWN | Medium settlement | Medium circle |
| CITY | Large settlement | Large circle |
| CAPITAL | Major city | Star marker |
| DUNGEON | Adventure location | Skull icon |
| LANDMARK | Point of interest | Diamond |
| BRIDGE | Road crossing | Bridge icon |
| OUTPOST | Military post | Shield icon |
| BLOCKED | Impassable | None |

---

## 7. CellInfo Structure

Each cell contains:

```
CellInfo
├── terrain: Terrain
├── biome: Biome
├── location_type: LocationType
├── location_id: String
├── location_name: String
├── region_name: String
├── passable: bool
├── discovered: bool
├── dungeon_discovered: bool
├── is_road: bool
├── scene_path: String (hand-crafted scene, empty = procedural)
├── scene_size: Vector2 (dimensions for large scenes)
├── danger_level: int (1-10)
├── description: String
└── wip: bool (work-in-progress, hidden from UI)
```

---

## 8. Regions

| Region | Location | Terrain |
|--------|----------|---------|
| Western Shore | Columns 0-2 | Water, Coast |
| Elder Moor | Around (0, 0) | Forest, Plains |
| The Greenwood | Central default | Mixed Forest |
| Eastern Highlands | East edge | Rocky, Highlands |
| Southern Forest | South | Dense Forest |
| Iron Mountains | North/edges | Blocked Mountains |
| Tenger Desert | Far South | Desert |
| Southern Bay | Southwest | Water, Coast |

---

## 9. Key Locations

### Starting Area

| Location | Coords | Type | Description |
|----------|--------|------|-------------|
| Elder Moor | (0, 0) | Landmark | Starting location |
| Dalhurst | (-8, -2) | Town | Western trade hub |
| Thornfield | (3, -2) | Town | Eastern town |
| Millbrook | (-7, 4) | Town | Lakeside town |
| Crossroads | (-5, -2) | Dungeon | Cultist ruins |

### Dungeons

| Location | Coords | Type | Description |
|----------|--------|------|-------------|
| Willow Dale | (-5, -5) | Dungeon | Crystal Hearts puzzle |
| Bandit Hideout | (1, -4) | Dungeon | Bandit cave |
| Kazer-Dun Entrance | (-5, 9) | Dungeon | Dwarf hold (north) |
| Sunken Crypts | (-3, 2) | Dungeon | Waterlogged tomb |
| Bloodsand Arena | (0, 3) | Landmark | Gladiator arena |

### Southern Territories (Boat Access)

| Location | Coords | Type | Description |
|----------|--------|------|-------------|
| Larton | (-5, 20) | Town | Starving port town |
| Aberdeen | (-5, 15) | Town | Trade town cut off |
| Duncaster | (-1, 22) | Village | Mountain mining |
| East Hollow | (0, 26) | Village | Frontier settlement |
| Tenger Camp | (0, 29) | Outpost | Desert nomads |
| Elven City (Silvanost) | (-11, 14) | City | Ancient elven city |

### Future Expansion (WIP)

| Location | Coords | Type | Status |
|----------|--------|------|--------|
| Falkenhaften | (7, -9) | Capital | WIP |
| Pirate Stronghold | (-10, 18) | Dungeon | WIP |
| Border Wars Graveyard | (4, 23) | Dungeon | WIP |

---

## 10. Road Network

Roads connect settlements and provide safe(r) travel:

### Main Roads

1. **East-West Road** (Row -2): Dalhurst ↔ Crossroads ↔ Thornfield
2. **North-South Road** (Column -5): Willow Dale ↔ Crossroads ↔ Kazer-Dun
3. **Coastal Road**: Aberdeen ↔ Larton

### Spurs

- Crossroads ↔ Millbrook
- Elder Moor ↔ Bloodsand Arena
- Bandit Hideout spur from main road

### Road Properties

- Roads are marked with `is_road: true` in CellInfo
- Road terrain type provides Plains biome
- Reduced danger levels on roads
- Road cells always passable

---

## 11. Scene Mapping

Hand-crafted scenes override procedural generation:

```gdscript
const LOCATION_SCENES: Dictionary = {
    "elder_moor": "res://scenes/levels/elder_moor.tscn",
    "dalhurst": "res://scenes/levels/dalhurst.tscn",
    "thornfield": "res://scenes/levels/thornfield.tscn",
    ...
}
```

### Scene Size Override

Large scenes can span multiple cell sizes:

```gdscript
{"id": "elder_moor", "scene_size": [242, 219]}  # 242x219 world units
{"id": "dalhurst", "scene_size": [160, 172]}
```

---

## 12. Player GPS System

### Position Tracking

```gdscript
var current_cell: Vector2i          # Current grid position
var previous_cell: Vector2i         # Last cell
var current_region: String          # Current region name
var current_location_id: String     # Current location (empty = wilderness)
```

### Discovery System

When player enters new cell:
1. Cell marked as discovered
2. Location discovered if present
3. Region change detected
4. Discovery XP awarded

### Discovery XP

| Location Type | XP |
|---------------|-----|
| Capital | 100 |
| City | 75 |
| Town | 50 |
| Dungeon | 50 |
| Village | 35 |
| Outpost | 30 |
| Landmark | 25 |
| Bridge | 25 |

---

## 13. Signals

### PlayerGPS Signals

| Signal | Parameters | When |
|--------|------------|------|
| `cell_changed` | old_cell, new_cell | Player crosses cell boundary |
| `location_discovered` | location_id, name | New location found |
| `region_changed` | old_region, new_region | Entered new region |
| `cell_revealed` | coords | Cell added to map |

---

## 14. WorldGrid API

### Cell Access

| Function | Returns | Description |
|----------|---------|-------------|
| `get_cell(coords)` | CellInfo | Get cell data |
| `is_passable(coords)` | bool | Can player walk here |
| `is_road(coords)` | bool | Is this a road cell |
| `is_in_bounds(coords)` | bool | Valid coordinates |

### Coordinate Conversion

| Function | Returns | Description |
|----------|---------|-------------|
| `cell_to_world(coords)` | Vector3 | Grid to 3D position |
| `world_to_cell(pos)` | Vector2i | 3D position to grid |

### Location Lookup

| Function | Returns | Description |
|----------|---------|-------------|
| `get_location_coords(id)` | Vector2i | Get coords by location ID |
| `get_location_info(id)` | Dictionary | Get full location data |
| `find_locations_by_type(type)` | Array | All locations of type |

### Pathfinding

| Function | Returns | Description |
|----------|---------|-------------|
| `find_path(from, to)` | Array[Vector2i] | BFS pathfinding |
| `grid_distance(from, to)` | int | Manhattan distance |

### Discovery

| Function | Description |
|----------|-------------|
| `discover_cell(coords)` | Mark cell discovered |
| `is_discovered(coords)` | Check if discovered |
| `discover_all()` | Debug: reveal all |

---

## 15. PlayerGPS API

### Position

| Function | Description |
|----------|-------------|
| `update_cell(coords)` | Set current cell (auto-discover) |
| `set_position(coords, skip_discovery)` | Set position (for loads) |

### Discovery

| Function | Description |
|----------|-------------|
| `discover_cell(coords)` | Manually discover cell |
| `is_discovered(coords)` | Check cell discovery |
| `discover_location(location_id)` | Discover by ID |
| `is_location_discovered(id)` | Check location discovery |
| `get_discovered_locations()` | Get all discovered |
| `get_discovered_in_region(region)` | Filter by region |

### Distance

| Function | Description |
|----------|-------------|
| `get_distance_to(location_id)` | Grid distance from player |
| `get_distance_between(from, to)` | Distance between locations |

---

## 16. Danger Levels

Danger increases with distance from Elder Moor:

| Distance | Danger | Enemy Scaling |
|----------|--------|---------------|
| 0-2 cells | 1-2 | Weak enemies |
| 3-5 cells | 3-4 | Basic enemies |
| 6-8 cells | 5-6 | Moderate enemies |
| 9-12 cells | 7-8 | Dangerous enemies |
| 13+ cells | 9-10 | Elite enemies |

Danger affects:
- Enemy count per cell
- Enemy level range
- Loot quality
- Encounter difficulty

---

## 17. Edge Cases

### Impassable Terrain

- WATER cells: Require boat travel
- BLOCKED cells: Mountain walls, no passage
- Cell boundaries create invisible walls at impassable edges

### Large Scenes

Scenes larger than 100x100 must specify `scene_size`:
- CellStreamer adjusts loading radius
- Adjacent cells account for overlap

### WIP Locations

Locations with `wip: true`:
- Hidden from world map
- Not available for fast travel
- May have placeholder scenes

---

## 18. Integration Points

| System | Integration |
|--------|-------------|
| CellStreamer | Uses WorldGrid for cell data, PlayerGPS for position |
| FastTravelManager | Reads discovered locations from PlayerGPS |
| WorldMap (`scripts/ui/world_map.gd`) | Displays WorldGrid terrain and PlayerGPS discoveries |
| QuestManager | Uses location_id for objective targeting |
| WildernessRoom | Generates terrain based on biome from WorldGrid |
| CompassUI | Shows direction to locations using WorldGrid coords |

---

## 19. Save/Load Data

### PlayerGPS Save State

```gdscript
{
    "current_cell": Vector2i,
    "discovered_cells": Dictionary,  # coords -> timestamp
    "discovered_locations": Dictionary,  # id -> info
    "total_cells_traveled": int,
    "total_distance_traveled": int
}
```

### WorldGrid Save State

```gdscript
{
    "discovered_cells": Dictionary,  # coords -> bool
    "dungeon_discoveries": Dictionary  # dungeon_id -> bool
}
```

---

## 20. Dependencies

| File | Purpose |
|------|---------|
| world_grid.gd | Autoload with world data |
| player_gps.gd | Autoload for player position |
| cell_streamer.gd | Autoload for streaming |
| wilderness_room.gd | Procedural terrain generator |
| enhanced_terrain.gd | Terrain algorithms |
| world_map.gd | World map UI |

---

## 21. Tuning Knobs

| Parameter | Location | Default |
|-----------|----------|---------|
| Cell size | world_grid.gd:8 | 100.0 |
| Grid min | world_grid.gd:15 | (-12, -8) |
| Grid max | world_grid.gd:16 | (7, 31) |
| Discovery XP (capital) | player_gps.gd:170 | 100 |
| Discovery XP (dungeon) | player_gps.gd:178 | 50 |

---

## 22. Acceptance Criteria

- [ ] WorldGrid loads all location data correctly
- [ ] Coordinate conversions work both directions
- [ ] PlayerGPS tracks position accurately
- [ ] Cell discovery triggers XP and signals
- [ ] Region changes emit correct signals
- [ ] Roads connect settlements properly
- [ ] Pathfinding avoids impassable terrain
- [ ] WIP locations hidden from UI
- [ ] Save/load preserves discovery state
- [ ] Large scenes load correctly
