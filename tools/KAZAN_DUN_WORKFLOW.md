# Kazan-Dun Blender Workflow

## Overview

This workflow allows you to:
1. Export existing Godot CSG geometry to GLB files
2. Open and edit in Blender
3. Re-import improved models back to Godot

## Step 1: Export from Godot

### Option A: Run the Export Tool Scene (Recommended)

1. Open Godot project
2. Open `tools/csg_export_tool.tscn`
3. Press F6 to run the scene
4. Press the appropriate key:
   - **SPACE** - Export rooms only (24 files)
   - **L** - Export levels only (11 files)
   - **A** - Export ALL (35 files)
5. Wait for export to complete
6. Files are saved to `res://exports/kazan_dun/`

### Option B: Manual Export (Single Scene)

1. Open a Kazan-Dun scene (e.g., `kd_throne_room.tscn`)
2. Select CSG root nodes one at a time
3. Menu: **CSG → Bake Mesh**
4. Select all MeshInstance3D nodes
5. Menu: **Scene → Export As... → GLTF 2.0**

## Step 2: Import to Blender

1. Open Blender
2. **File → Import → glTF 2.0**
3. Navigate to `CatacombsOfGore/exports/kazan_dun/rooms/` or `/levels/`
4. Select the GLB file(s) you want to edit

### Blender Settings for PS1 Aesthetic

When working in Blender, keep these constraints:
- **Low poly** - 8-30 faces per object
- **Hard edges** - No smooth shading on architectural elements
- **UV mapping** - Simple box/planar projection
- **Textures** - 64x64 or 128x128 max

## Step 3: Edit in Blender

### Common Tasks

**Improve geometry:**
- Add bevels to harsh edges
- Create proper doorway arches
- Add decorative trim

**Add detail pieces:**
- Runic carvings
- Wall sconces
- Architectural details

**Fix scale issues:**
- Godot uses 1 unit = 1 meter
- Verify Blender is set to Metric units

**Organize hierarchy:**
- Group related meshes
- Use consistent naming (pillar_01, pillar_02, etc.)

## Step 4: Export from Blender

1. Select all objects to export
2. **File → Export → glTF 2.0 (.glb)**
3. Settings:
   - Format: GLB (binary)
   - Include: Selected Objects
   - Transform: +Y Up (Godot default)
   - Geometry: Apply Modifiers
   - Materials: Export
4. Save to `CatacombsOfGore/assets/models/dwarven/` (organized by type)

## Step 5: Import to Godot

### For Individual Props/Set Pieces

1. Drag GLB file into Godot's FileSystem
2. Double-click to configure import settings:
   - Meshes: Generate Collisions (if needed)
   - Materials: Import
3. Use as `PackedScene` or extract meshes

### For Room Replacements

1. Import the edited GLB
2. Open the original room scene (e.g., `kd_throne_room.tscn`)
3. Replace CSG nodes with MeshInstance3D referencing the new mesh
4. Adjust positions as needed
5. Re-add collision shapes manually or use trimesh collision

## File Locations

```
CatacombsOfGore/
├── exports/
│   └── kazan_dun/
│       ├── rooms/          # Exported room GLBs
│       │   ├── kd_throne_room.glb
│       │   ├── kd_forge_main.glb
│       │   └── ...
│       └── levels/         # Exported level GLBs
│           ├── kazan_dun_level_1.glb
│           └── ...
├── assets/
│   └── models/
│       └── dwarven/        # Re-imported improved models
│           ├── structural/
│           ├── props/
│           └── furniture/
└── scenes/
    └── rooms/
        └── kazan_dun/      # Original room scenes (will reference new models)
```

## Set Piece Strategy

Rather than editing entire rooms, consider extracting and improving individual elements:

### Priority Set Pieces

1. **Ornate Pillar** - Used in throne room, feast hall, forge
2. **Stone Brazier** - Used everywhere for lighting
3. **Doorway Arch** - Consistent door frames
4. **Dwarven Throne** - Throne room centerpiece
5. **Forge Equipment** - Anvil, furnace, quench tank
6. **Feast Table** - Long wooden table with benches

### Workflow for Set Pieces

1. Export a room that contains the element
2. In Blender, delete everything except the piece you want
3. Improve that piece
4. Export as standalone GLB
5. Import to Godot as reusable scene
6. Replace all instances in Godot scenes

## Tips

- **Work incrementally** - Don't try to redo everything at once
- **Test often** - Import back to Godot frequently to check scale/appearance
- **Keep originals** - The export tool doesn't modify original scenes
- **Consistent scale** - All pieces should use the same scale reference
- **Name clearly** - Use descriptive names: `pillar_dwarven_ornate_01.glb`
