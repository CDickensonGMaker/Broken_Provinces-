# Catacombs of Gore - Editor Plugin Guide

This guide covers all the editor plugins available for creating content in Catacombs of Gore.

---

## Accessing the Editors

All editors are accessed through the **Level Editors** dropdown menu in the Godot editor toolbar.

Click the "Level Editors" button to see the menu with options:
- World Forge
- Town Editor
- Dungeon Editor
- NPC Composer
- Dialogue Editor
- Quest Builder
- Event Editor

---

## Level Editors

### World Forge

**Purpose:** Design the game world map with terrain, roads, and points of interest (POIs).

**Opening:** Level Editors > World Forge

**Layout:**
- **Left/Center:** Canvas showing the world grid
- **Right:** Tools panel with layer tabs (Terrain, Road, POI)

**Basic Workflow:**
1. Select the **Terrain** tab to paint terrain types
2. Click a terrain brush (forest, swamp, desert, etc.)
3. Paint on the canvas by clicking/dragging
4. Switch to **Road** tab to draw roads
5. Switch to **POI** tab to place locations

**Terrain Types:**
| Type | Description |
|------|-------------|
| Forest | Wooded areas |
| Swamp | Marshy wetlands |
| Desert | Sandy/arid regions |
| Hill | Elevated terrain |
| Plains | Open grasslands |
| Mountain | Impassable peaks |
| Ocean | Open water (impassable) |
| River | Waterways |

**POI Types:**
| Type | Description |
|------|-------------|
| Village | Small settlement |
| Town | Medium settlement |
| City | Large settlement |
| Capital | Major city with districts |
| Dungeon | Underground area |
| Landmark | Point of interest |
| Outpost | Small outpost/camp |

**POI Properties:**
- **Name:** Display name
- **Type:** Settlement/dungeon type
- **Position:** World coordinates (use arrow buttons to move)
- **Notes:** Description text
- **Scene:** Path to the .tscn scene file
- **Layout:** Path to the layout data file
- **ID:** Unique location identifier

**Buttons:**
- **Export JSON:** Save map data to user://world_forge_map.json
- **Import JSON:** Load previously saved map data
- **Apply to Game:** Export and apply changes
- **Sync POIs:** Import missing POIs from WorldGrid.gd
- **Reload from WorldGrid:** Reset to hardcoded WorldGrid data

**Tips:**
- Use mouse wheel to zoom
- Middle-click and drag to pan
- Double-click a POI to select and edit it
- Use the eraser toggle to remove painted cells

---

### Town Editor

**Purpose:** Design town/settlement layouts with buildings, NPCs, and props.

**Opening:** Level Editors > Town Editor

**Layout:**
- **Left:** Palette panel with tabs (Buildings, NPCs, Props, Functional, Models)
- **Center:** 3D viewport showing the town
- **Right:** Inspector panel for selected element

**Basic Workflow:**
1. Select a **Settlement Type** (hamlet, village, town, city, capital)
2. Click a building/NPC/prop in the palette
3. Click in the 3D viewport to place it
4. Use the Inspector to adjust position, rotation, scale
5. Save the layout as JSON

**Palette Tabs:**
- **Buildings:** Houses, inns, shops, temples, etc.
- **NPCs:** Civilians, guards, merchants, etc.
- **Props:** Barrels, crates, benches, torches, etc.
- **Functional:** Spawn points, doors, chests, shrines
- **Models:** Browse custom 3D models

**Settlement Types:**
| Type | Grid Size | Description |
|------|-----------|-------------|
| Hamlet | 64x64 | Tiny settlement |
| Village | 128x128 | Small village |
| Town | 192x192 | Medium town |
| City | 256x256 | Large city |
| Capital | 384x384 | Major capital (multi-district) |

**Inspector Fields:**
- **Name:** Element name
- **Position X/Y/Z:** World position
- **Rotation Y:** Horizontal rotation (degrees)
- **Scale:** Uniform scale

**Buttons:**
- **New:** Create a new town
- **Open:** Load existing town layout
- **Save / Save As:** Save current layout
- **Export .tscn:** Export as Godot scene file
- **Clear All:** Remove all placed elements

**Tips:**
- Elements snap to a grid automatically
- WASD to move camera, mouse to look around in viewport
- Delete Selected removes the currently selected element

---

### Dungeon Editor

**Purpose:** Design dungeon floor plans using a block-based system (Daggerfall-style).

**Opening:** Level Editors > Dungeon Editor

**Layout:**
- **Left:** Sidebar with file controls, settings, block palette, inspector
- **Center:** 2D canvas showing the dungeon floor plan

**Basic Workflow:**
1. Click **New** to create a new dungeon
2. Set the dungeon **Name** and **Theme**
3. Select a block type from the **Block Palette**
4. Click on the grid to place blocks
5. Select placed blocks to adjust rotation
6. Click **Validate** to check for connection errors
7. **Save** or **Export** when done

**Block Types:**
| Category | Blocks |
|----------|--------|
| Rooms | Entrance, Room (small), Room (large), Boss, Treasure, Puzzle, Secret |
| Corridors | Straight, Corner, T-Junction, Crossroads |
| Vertical | Ramp, Shaft |

**Block Palette:**
- Click a block type to select it
- Click on the grid to place
- **Clear Selection** to deselect

**Inspector (when block selected):**
- Shows block type and grid position
- **Rotation:** 0/90/180/270 degrees
- **Connections:** Shows which directions connect
- **Delete Block:** Remove the selected block

**Dungeon Themes:**
| Theme | Description |
|-------|-------------|
| Crypt | Undead dungeon |
| Cave | Natural cavern |
| Ruins | Ancient ruins |
| Sewer | Underground sewers |
| Mine | Abandoned mine |
| Temple | Religious structure |
| Fortress | Military fortification |

**Validation:**
The validator checks:
- All rooms are connected
- Entrance room exists
- No orphaned blocks
- Connections match between adjacent blocks

**Buttons:**
- **New/Open/Save:** File operations
- **Export:** Generate .tscn scene file
- **Validate:** Check layout for errors
- **Quick Test (F5):** Export and run test scene

**Tips:**
- Blocks auto-connect based on their connection points
- Use different Y levels for multi-floor dungeons
- Ramps connect the current level to the level above

---

## Authoring Tools

### NPC Composer

**Purpose:** Create and configure NPC data files (.tres resources).

**Opening:** Level Editors > NPC Composer

**Layout:**
- **Left:** NPC browser tree
- **Center:** NPC properties editor
- **Right:** Sprite preview panel

**Basic Workflow:**
1. Click **+** to create a new NPC
2. Fill in basic info (ID, name, race, archetype)
3. Set location and faction
4. Configure sprite settings
5. Add dialogue topics
6. Set knowledge profile
7. **Save** the NPC resource

**NPC Properties:**
| Field | Description |
|-------|-------------|
| ID | Unique identifier (snake_case) |
| Display Name | Shown in-game |
| Race | Human, Dwarf, Elf, etc. |
| Archetype | civilian, merchant, guard, quest_giver, etc. |
| Location | Zone ID where NPC spawns |
| Faction | NPC's faction affiliation |
| Base Disposition | Starting relationship (-100 to 100) |
| Alignment | Good/Neutral/Evil |

**Sprite Settings:**
- **Sprite Path:** Path to the sprite sheet
- **H Frames / V Frames:** Sprite sheet dimensions
- **Preview:** Shows animated sprite preview

**Dialogue Topics:**
Add topics the NPC can discuss:
- LOCAL_NEWS, RUMORS, PERSONAL, DIRECTIONS
- TRADE, WEATHER, QUESTS, GOODBYE

**Knowledge Profile:**
- **Archetype:** Personality type for response selection
- **Personality Traits:** Character traits
- **Knowledge Tags:** What the NPC knows about
- **Speech Style:** How they talk

**Wandering:**
- **Wanders:** Toggle NPC movement
- **Wander Radius:** How far they roam

**Tips:**
- Save often - there's an unsaved changes indicator
- Preview updates in real-time as you change sprite settings
- The archetype affects which dialogue responses are used

---

### Dialogue Topic Editor

**Purpose:** Edit dialogue response pools for topic-based conversations.

**Opening:** Level Editors > Dialogue Editor

**Layout:**
- **Left:** Pool file browser
- **Center:** Response list
- **Right:** Response editor

**Basic Workflow:**
1. Select or create a response pool file
2. Click **+** to add a new response
3. Set the response ID, text, and topic
4. Configure disposition range and weight
5. Add required knowledge tags if needed
6. **Save** the pool

**Response Properties:**
| Field | Description |
|-------|-------------|
| Response ID | Unique identifier |
| Response Text | What the NPC says |
| Topic Type | Which topic triggers this response |
| Min/Max Disposition | Disposition range for selection |
| Weight | Selection probability |
| Auto-Log | Record in player's journal |

**Topic Types:**
- LOCAL_NEWS - Local area information
- RUMORS - Gossip and hearsay
- PERSONAL - About themselves
- DIRECTIONS - Navigation help
- TRADE - Commerce talk
- WEATHER - Weather discussion
- QUESTS - Quest/work opportunities
- GOODBYE - Farewell responses

**Conditional Fields:**
- **Personality Traits:** NPC must have these traits
- **Knowledge Tags:** NPC must know about these topics
- **Topics Unlocked:** New topics revealed after this response

**Tips:**
- Responses are selected based on NPC's disposition and knowledge
- Higher weight = more likely to be selected
- Use knowledge tags to create progressive dialogue

---

### Quest Builder

**Purpose:** Create quest chains with objectives and rewards.

**Opening:** Level Editors > Quest Builder

**Layout:**
- **Left:** Quest tree browser
- **Center:** Quest properties
- **Right:** Objectives list

**Basic Workflow:**
1. Click **+** to create a new quest
2. Set quest ID, title, and description
3. Configure giver NPC and turn-in target
4. Add objectives
5. Set rewards
6. Link to prerequisite/next quests
7. **Save** the quest

**Quest Properties:**
| Field | Description |
|-------|-------------|
| Quest ID | Unique identifier |
| Title | Display name |
| Description | Quest journal text |
| Main Quest | Part of main storyline |
| Quest Source | story, npc, bounty, guild, random |
| Giver NPC ID | Who gives the quest |
| Giver Region | Where to find them |
| Turn-in Type | How to complete (npc_specific, location, etc.) |
| Turn-in Target | NPC or location for completion |

**Objective Types:**
| Type | Description |
|------|-------------|
| kill | Defeat enemies |
| collect | Gather items |
| reach | Go to location |
| interact | Use an object |
| talk | Speak to NPC |
| escort | Protect NPC |

**Objective Properties:**
- **ID:** Objective identifier
- **Description:** Journal text
- **Target:** What to kill/collect/reach
- **Count:** How many needed
- **Optional:** Not required for completion

**Rewards:**
- **Gold:** Currency reward
- **XP:** Experience points
- **Items:** Item rewards (add via button)

**Quest Chains:**
- **Prerequisites:** Quests required first
- **Next Quest:** Auto-start on completion
- **Unlocks:** Other quests made available

**Tips:**
- Use Move Up/Down to reorder objectives
- Mark objectives as optional for bonus content
- Chain quests together for storylines

---

### Scripted Event Editor

**Purpose:** Create in-game cutscenes and triggered events.

**Opening:** Level Editors > Event Editor

**Layout:**
- **Left:** Event list
- **Center:** Timeline with event properties
- **Right:** Action editor

**Basic Workflow:**
1. Click **New** to create an event
2. Set event ID, description, and trigger
3. Click **Add Action** to build the timeline
4. Configure each action's parameters
5. Reorder actions with Up/Down buttons
6. **Save** the event

**Event Properties:**
| Field | Description |
|-------|-------------|
| Event ID | Unique identifier |
| Description | What this event does |
| Trigger | How the event starts |
| Trigger Value | Parameter for trigger |
| Auto-play | Start automatically |
| Once only | Play only once ever |

**Trigger Types:**
- manual - Called from code
- on_enter_zone - Player enters area
- on_interact - Player interacts with object
- on_quest_complete - Quest finished
- on_flag_set - Game flag becomes true
- on_time - At specific time of day

**Action Types:**
| Action | Description |
|--------|-------------|
| Show Dialogue | Display dialogue box |
| Move NPC | Move NPC to position |
| Spawn NPC | Create NPC at location |
| Despawn NPC | Remove NPC |
| Camera Pan | Move camera to target |
| Camera Shake | Screen shake effect |
| Play Sound | Sound effect |
| Play Music | Background music |
| Fade In/Out | Screen fade |
| Wait | Pause timeline |
| Set/Clear Flag | Modify game flags |
| Give/Take Item | Inventory changes |
| Give Gold | Currency reward |
| Give XP | Experience reward |
| Start/Complete Quest | Quest management |
| Teleport Player | Move player |
| Set Time | Change time of day |
| Spawn Enemy | Create enemy |
| Custom | Call custom script |

**Action Editor:**
- **Type:** Select action type
- **Delay:** Seconds before action executes
- **Parameters:** Varies by action type

**Tips:**
- Use delays to pace the event
- Wait actions pause the timeline
- Test events using the in-game debug menu

---

## File Locations

| Editor | Data Location |
|--------|---------------|
| World Forge | user://world_forge_map.json |
| Town Editor | res://data/layouts/*.json |
| Dungeon Editor | res://data/dungeons/*.json |
| NPC Composer | res://data/npcs/*.tres |
| Dialogue Editor | res://data/dialogue/pools/*.json |
| Quest Builder | res://data/quests/*.json |
| Event Editor | res://data/events/*.json |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| F5 | Quick Test (Dungeon Editor) |
| Ctrl+S | Save (when supported) |
| Delete | Delete selected element |
| Escape | Cancel current operation |
| Mouse Wheel | Zoom in/out |
| Middle Mouse | Pan view |

---

## Troubleshooting

**Plugin not showing in menu:**
- Ensure plugins are enabled in Project Settings > Plugins
- Restart the Godot editor

**Changes not saving:**
- Check file permissions
- Verify the data directory exists

**UI elements overlapping:**
- Resize the window
- Undock and re-dock the panel

**Validation errors in Dungeon Editor:**
- Ensure entrance room exists
- Check all blocks have valid connections
- Remove orphaned blocks

---

## Integration Notes

**World Forge + Town/Dungeon Editors:**
- Select a POI in World Forge
- Click "Edit Town" or "Edit Dungeon" button
- Layout path is automatically linked back

**Quest Builder + Dialogue Editor:**
- Create quest with giver NPC
- Add QUESTS topic to NPC in NPC Composer
- Dialogue responses can start quests via action

**Event Editor + Quest System:**
- Events can start/complete quests
- Use on_quest_complete trigger for cutscenes after quest completion
