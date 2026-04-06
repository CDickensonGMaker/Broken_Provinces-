# Town Editor & Dungeon Layout Maker Plan

## Overview

Two new editor tools integrated with the existing World Forge system:

1. **Town Editor** - Visual tool for placing buildings, NPCs, merchants, and props in towns
2. **Dungeon Layout Maker** - Visual tool for designing seamless dungeon room layouts

Both tools run as Godot editor plugins, accessible from the World Forge toolbar or standalone.

---

## PART 1: TOWN EDITOR

### Current State Analysis

**Existing Systems:**
- `TownGenerator` (scripts/generation/town_generator.gd) - Procedural generation only
- `WorldForgeDock` - World map editor with POI placement
- Hand-crafted town scenes exist (Elder Moor, Thornfield, etc.)
- Building blocks: CSGBox3D for structures, CivilianNPC/GuardNPC classes, Merchant class

**What's Missing:**
- No visual placement tool for buildings
- No way to edit existing town scenes with a GUI
- No connection between World Forge POIs and town editing
- Manual scene editing required for all customization

### Town Editor Requirements

1. **Placement Palette** - Drag and drop elements:
   - Buildings (house, shop, inn, temple, blacksmith, etc.)
   - NPCs (civilian, guard, merchant, quest giver)
   - Props (barrel, crate, bench, torch, well, cart)
   - Functional (spawn point, fast travel shrine, bounty board, door)
   - Zones (shop interaction area, rest area)
   - **Custom 3D Models** (.glb, .gltf, .tscn) - Browse and place any model

2. **Building Customization:**
   - Size (width, height, depth sliders)
   - Roof style (flat, sloped, peaked)
   - Material/color
   - Shop type assignment
   - Lock difficulty for doors

3. **NPC Configuration:**
   - NPC type selection
   - Name assignment
   - Patrol points
   - Dialogue/quest assignment
   - Merchant inventory type

4. **Integration:**
   - Open from World Forge (click POI → "Edit Town")
   - Create new town scene from POI
   - Save/load town layouts
   - Preview mode (walk around as player)

### Town Editor File Structure

```
addons/town_editor/
├── town_editor_plugin.gd       # EditorPlugin entry point
├── town_editor_dock.gd         # Main UI panel
├── town_editor_canvas.gd       # 3D viewport with placement
├── town_editor_data.gd         # Data structures
├── town_editor_palette.gd      # Element palette UI
├── town_editor_inspector.gd    # Selected object properties
└── placeable_elements/
    ├── te_building.gd          # Building placement wrapper
    ├── te_npc.gd               # NPC placement wrapper
    ├── te_prop.gd              # Prop placement wrapper
    └── te_functional.gd        # Spawn points, doors, etc.
```

### Town Editor Implementation Phases

#### Phase 1: Core Editor Framework
1. Create `town_editor_plugin.gd` - Toolbar button, popup window
2. Create `town_editor_dock.gd` - Main UI with:
   - 3D viewport (SubViewport + Camera3D)
   - Element palette (left panel)
   - Inspector panel (right panel)
   - Toolbar (save, load, preview, export)
3. Create `town_editor_canvas.gd` - Handle 3D placement:
   - Mouse raycast to ground plane
   - Ghost preview of selected element
   - Click to place
   - Drag to move placed elements
   - Delete key to remove

#### Phase 2: Element Palette
1. Create palette categories:
   - Buildings
   - NPCs
   - Props
   - Functional
2. Each element has:
   - Icon/preview
   - Default properties
   - Placement constraints (ground only, wall mount, etc.)
3. Quick-place vs custom-place modes

#### Phase 3: Building System
1. `te_building.gd` - Wrapper that creates CSG geometry
2. Building types from `TownGenerator`:
   - house, inn, general_store, blacksmith, temple
   - magic_shop, armorer, jeweler, guild_hall
3. Properties:
   - dimensions (width, height, depth)
   - roof_type (flat, sloped)
   - material_preset (wood, stone, brick)
   - shop_type (for merchant buildings)
   - has_interior (future: interior scene link)

#### Phase 4: NPC System
1. `te_npc.gd` - Wrapper for NPC placement
2. NPC types:
   - civilian (with gender/sprite selection)
   - guard (with patrol radius)
   - merchant (with shop type)
   - quest_giver (with quest ID)
   - innkeeper
3. Properties:
   - npc_name
   - sprite_path
   - patrol_points (array of Vector3)
   - dialogue_id
   - merchant_type

#### Phase 5: World Forge Integration
1. Add "Edit Town" button to POI panel in World Forge
2. When clicked:
   - If scene_path exists: Load existing scene
   - If empty: Create new town scene from template
3. Auto-set scene_path in POI data after saving
4. Sync location_id between World Forge and town scene

#### Phase 6: Save/Export System
1. Save as .tscn file with proper node hierarchy:
   ```
   TownRoot (Node3D)
   ├── Ground
   ├── Buildings/
   │   ├── Building_0
   │   └── ...
   ├── NPCs/
   │   ├── Civilian_0
   │   └── ...
   ├── Props/
   ├── SpawnPoints/
   └── Doors/
   ```
2. Export metadata for runtime use
3. Preview mode: Instance scene and add player controller

---

## PART 2: DUNGEON LAYOUT MAKER

### Current State Analysis

**Existing Systems:**
- `DungeonGenerator` - Grid-based procedural generation
- `DungeonRoom` - Room instance class
- `RoomTemplate` - Resource defining room properties
- Grid size: 15.0 units per cell
- Rooms connect via doors at cardinal directions

**What's Missing:**
- No visual layout editor
- No way to manually design dungeon layouts
- Room templates created in code only
- No preview of room connections

### Dungeon Layout Requirements

1. **Grid-Based Canvas:**
   - 2D top-down view of dungeon
   - Grid cells represent room positions
   - Drag rooms onto grid
   - Visual connection lines between rooms

2. **Room Palette:**
   - Entrance rooms
   - Corridor rooms
   - Combat rooms
   - Treasure rooms
   - Boss rooms
   - Quest rooms
   - Empty/transition rooms

3. **Room Configuration:**
   - Dimensions (width, depth, height)
   - Door positions (N/S/E/W)
   - Enemy spawn count
   - Loot tier
   - Special features (rest spot, portal)

4. **Connection System:**
   - Automatic door alignment
   - Corridor generation for gaps
   - Validation (all rooms reachable)
   - No floor gaps (seamless)

5. **Preview/Export:**
   - 3D preview mode
   - Export to .tscn
   - Export room templates as .tres

### Dungeon Layout File Structure

```
addons/dungeon_editor/
├── dungeon_editor_plugin.gd    # EditorPlugin entry point
├── dungeon_editor_dock.gd      # Main UI panel
├── dungeon_editor_canvas.gd    # 2D grid canvas
├── dungeon_editor_3d.gd        # 3D preview viewport
├── dungeon_editor_data.gd      # Data structures
├── dungeon_room_palette.gd     # Room type palette
└── room_templates/
    ├── de_entrance.gd
    ├── de_combat.gd
    ├── de_treasure.gd
    └── de_boss.gd
```

### Dungeon Layout Implementation Phases

#### Phase 1: Core Grid Editor
1. Create `dungeon_editor_plugin.gd` - Toolbar button, popup window
2. Create `dungeon_editor_dock.gd` - Main UI with:
   - 2D grid canvas (left, larger)
   - Room palette (right sidebar)
   - Room inspector (right sidebar, below palette)
   - Toolbar (new, save, load, preview, export)
3. Create `dungeon_editor_canvas.gd`:
   - Draw grid (15x15 unit cells)
   - Pan/zoom controls
   - Room placement via drag-drop
   - Room selection and movement
   - Connection line drawing

#### Phase 2: Room System
1. `DungeonEditorRoom` class:
   ```gdscript
   var grid_position: Vector2i
   var room_type: String  # entrance, combat, treasure, boss, etc.
   var dimensions: Vector3i  # width, depth, height in grid units
   var doors: Dictionary  # direction -> bool (N, S, E, W)
   var template_override: RoomTemplate  # Custom settings
   ```
2. Default room templates per type
3. Room type determines:
   - Default size
   - Door configuration
   - Enemy/loot settings

#### Phase 3: Connection System (Seamless Floors)
1. **Auto-Connect Algorithm:**
   - When room placed adjacent to another:
     - Check if doors align
     - If gap exists, auto-generate corridor room
     - Corridor dimensions match gap exactly

2. **Seamless Floor Rules:**
   - All adjacent rooms MUST have matching floor heights
   - Door widths must match at connection points
   - No gaps > 0 units between room floors

3. **Validation:**
   - BFS from entrance to verify all rooms reachable
   - Check for floating rooms (no connections)
   - Verify no overlapping rooms

#### Phase 4: Room Inspector
1. Select room to edit properties:
   - Dimensions (constrained by grid neighbors)
   - Door enable/disable per direction
   - Enemy count (min/max)
   - Enemy types (dropdown of available enemies)
   - Loot tier
   - Special features toggles
2. Changes reflected in canvas immediately

#### Phase 5: 3D Preview
1. `dungeon_editor_3d.gd` - SubViewport with 3D scene
2. Generate preview using `DungeonRoom` class
3. Fly camera to explore
4. Toggle: Show/hide enemies, show/hide loot
5. Real-time update as layout changes

#### Phase 6: Export System
1. **Export to Scene (.tscn):**
   - Generate complete dungeon scene
   - Uses existing `DungeonRoom` geometry generation
   - Proper node hierarchy
   - Navigation region setup

2. **Export Room Templates (.tres):**
   - Save custom room configurations
   - Reusable in procedural generator

3. **Save/Load Layout (.json):**
   - Save layout for future editing
   - Layout file format:
     ```json
     {
       "dungeon_id": "crypt_01",
       "grid_size": 15.0,
       "rooms": [
         {
           "grid_pos": [0, 0],
           "type": "entrance",
           "doors": {"N": true, "S": false, "E": true, "W": false}
         }
       ]
     }
     ```

---

## PART 3: INTEGRATION WITH WORLD FORGE

### Unified Workflow

1. **World Forge** - Paint world terrain, place POIs
2. **Click POI** → Options appear:
   - "Edit Town" (for settlement POIs) → Opens Town Editor
   - "Edit Dungeon" (for dungeon POIs) → Opens Dungeon Layout Maker
3. **Save** → Scene path auto-set in POI data
4. **Export JSON** → All POIs have valid scene references

### Shared Components

```
addons/shared_editor/
├── editor_viewport_3d.gd      # Reusable 3D viewport component
├── editor_palette_base.gd     # Base class for element palettes
├── editor_inspector_base.gd   # Base class for inspectors
└── editor_file_utils.gd       # Save/load/export utilities
```

---

## IMPLEMENTATION ORDER (PARALLEL BUILD)

Both editors built together since they share World Forge POI integration.

### Sprint 1: Shared Foundation + Plugin Skeletons
- [x] Phase 1.1: Shared editor components (viewport, palette base, inspector base)
  - Created: `addons/level_editors/shared/editor_data.gd`
  - Created: `addons/level_editors/shared/editor_3d_viewport.gd`
  - Created: `addons/level_editors/shared/model_browser.gd`
- [x] Phase 1.2: Town Editor plugin skeleton + popup window
  - Created: `addons/level_editors/town_editor/plugin.cfg`
  - Created: `addons/level_editors/town_editor/town_editor_plugin.gd`
  - Created: `addons/level_editors/town_editor/town_editor_dock.gd`
- [x] Phase 1.3: Dungeon Editor plugin skeleton + popup window
  - Created: `addons/level_editors/dungeon_editor/plugin.cfg`
  - Created: `addons/level_editors/dungeon_editor/dungeon_editor_plugin.gd`
  - Created: `addons/level_editors/dungeon_editor/dungeon_editor_dock.gd`
- [ ] Phase 1.4: World Forge POI integration (Edit Town / Edit Dungeon buttons)

### Sprint 2: Core Canvases
- [ ] Phase 2.1: Town Editor 3D viewport with ground plane + camera controls
- [ ] Phase 2.2: Dungeon Editor 2D grid canvas with pan/zoom
- [ ] Phase 2.3: Custom 3D model browser panel (shared component)
- [ ] Phase 2.4: Basic placement system (click to place, drag to move)

### Sprint 3: Palettes & Placement
- [ ] Phase 3.1: Town Editor palette (buildings, props, NPCs)
- [ ] Phase 3.2: Dungeon Editor room palette (entrance, combat, treasure, boss)
- [ ] Phase 3.3: Custom model palette integration (both editors)
- [ ] Phase 3.4: Ghost preview + snap-to-grid

### Sprint 4: Inspectors & Configuration
- [ ] Phase 4.1: Town Editor inspector (building size, NPC config, model properties)
- [ ] Phase 4.2: Dungeon Editor inspector (room dimensions, doors, spawns)
- [ ] Phase 4.3: Custom model inspector (position, rotation, scale, collision)

### Sprint 5: Dungeon Connections & Validation
- [ ] Phase 5.1: Door configuration system
- [ ] Phase 5.2: Auto-corridor generation for gaps
- [ ] Phase 5.3: Seamless floor validation (no gaps)
- [ ] Phase 5.4: Reachability validation (all rooms connected)

### Sprint 6: Preview & Export
- [ ] Phase 6.1: Dungeon 3D preview viewport
- [ ] Phase 6.2: Town Editor save to .tscn
- [ ] Phase 6.3: Dungeon Editor export to .tscn
- [ ] Phase 6.4: Save/load layout files (.json)
- [ ] Phase 6.5: World Forge auto-set scene_path on save

---

## TECHNICAL NOTES

### Grid Alignment (Dungeon)
- Grid cell size: 15.0 world units (matches existing DungeonGenerator)
- Room dimensions must be multiples of grid size
- Door positions at cell boundaries
- Corridor width: 4.0 units (standard door width)

### Floor Seamlessness (Dungeon)
**Problem:** Gaps between rooms cause player to fall through

**Solution:**
1. All room floors extend to cell boundaries
2. Corridor floors overlap slightly with room floors (0.1 unit overlap)
3. Floor thickness: 1.0 unit minimum
4. Kill zone at Y=-3.0 as safety net

### Building Placement (Town)
- Snap to grid (optional, 2.0 unit grid)
- Rotation snap: 90° increments
- Collision detection: Prevent overlapping buildings
- Ground plane Y=0

### NPC Spawning (Town)
- NPCs saved as metadata, spawned at runtime
- Allows save/load to preserve NPC state
- Patrol paths saved as Vector3 arrays

### Custom 3D Model Support (Both Editors)
**Supported Formats:**
- `.glb` / `.gltf` - Blender exports, external models
- `.tscn` - Godot scenes (prefabs)
- `.obj` - Legacy support

**Workflow:**
1. "Add Custom Model" button in palette
2. File browser opens (filtered to supported formats)
3. Model loads as preview, follows mouse
4. Click to place, drag to reposition
5. Inspector shows: Position, Rotation, Scale, Collision toggle

**Model Browser Panel:**
- Scans `res://assets/models/` and subfolders
- Thumbnail preview grid
- Search/filter by name
- Recent models list
- Favorites system

**Collision Handling:**
- Auto-detect: Use model's existing collision if present
- Generate Trimesh: Create collision from mesh (for static props)
- Generate Convex: Simplified collision (for movable objects)
- None: No collision (decorative only)

**Model Properties (Inspector):**
```
- Path: res://assets/models/building_tower.glb
- Position: Vector3
- Rotation: Vector3 (degrees)
- Scale: Vector3 (uniform or per-axis)
- Collision Mode: [Auto | Trimesh | Convex | None]
- Cast Shadows: bool
- Material Override: (optional)
- Tags: Array[String] (for organization)
```

**Integration with GLBCollisionProcessor:**
- Use existing naming conventions for collision
- `_solid` suffix = collision
- `_nocol` suffix = no collision
- `_arch` suffix = passable (no collision)

---

## FILES TO CREATE

### Shared Components (Used by Both Editors)
1. `addons/level_editors/shared/editor_3d_viewport.gd` - Reusable 3D viewport with camera
2. `addons/level_editors/shared/editor_palette_base.gd` - Base class for element palettes
3. `addons/level_editors/shared/editor_inspector_base.gd` - Base class for inspectors
4. `addons/level_editors/shared/model_browser.gd` - Custom 3D model browser panel
5. `addons/level_editors/shared/placeable_model.gd` - Wrapper for custom .glb/.tscn models
6. `addons/level_editors/shared/editor_data.gd` - Shared data structures

### Town Editor
1. `addons/level_editors/town_editor/plugin.cfg`
2. `addons/level_editors/town_editor/town_editor_plugin.gd`
3. `addons/level_editors/town_editor/town_editor_dock.gd`
4. `addons/level_editors/town_editor/town_editor_canvas.gd`
5. `addons/level_editors/town_editor/town_editor_palette.gd`
6. `addons/level_editors/town_editor/town_editor_inspector.gd`
7. `addons/level_editors/town_editor/placeable/te_building.gd`
8. `addons/level_editors/town_editor/placeable/te_npc.gd`
9. `addons/level_editors/town_editor/placeable/te_prop.gd`

### Dungeon Editor
1. `addons/level_editors/dungeon_editor/plugin.cfg`
2. `addons/level_editors/dungeon_editor/dungeon_editor_plugin.gd`
3. `addons/level_editors/dungeon_editor/dungeon_editor_dock.gd`
4. `addons/level_editors/dungeon_editor/dungeon_editor_canvas.gd`
5. `addons/level_editors/dungeon_editor/dungeon_editor_3d.gd`
6. `addons/level_editors/dungeon_editor/dungeon_editor_room.gd`
7. `addons/level_editors/dungeon_editor/dungeon_editor_palette.gd`
8. `addons/level_editors/dungeon_editor/dungeon_editor_inspector.gd`

### Integration
1. Modify `addons/world_forge/world_forge_dock.gd` - Add Edit Town/Dungeon buttons to POI panel

---

## VALIDATION CHECKLIST

### Town Editor
- [ ] Can place buildings at arbitrary positions
- [ ] Can customize building size and type
- [ ] Can place NPCs with proper configuration
- [ ] Can save town as .tscn
- [ ] Can load and edit existing town scenes
- [ ] World Forge integration works

### Dungeon Editor
- [ ] Can place rooms on grid
- [ ] Rooms connect seamlessly (no floor gaps)
- [ ] Corridors auto-generate for gaps
- [ ] All rooms reachable from entrance
- [ ] 3D preview accurate
- [ ] Export to .tscn works
- [ ] Exported dungeon is playable

---

## NOTES

- Use existing CSG geometry approach from TownGenerator
- Reuse CivilianNPC/GuardNPC spawn methods
- Match DungeonGenerator's grid_size (15.0) exactly
- Both editors should work with PS1 aesthetic (low-poly, nearest filtering)
- Test on existing hand-crafted scenes to ensure compatibility
