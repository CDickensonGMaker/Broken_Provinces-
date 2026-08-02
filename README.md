# Broken Provinces: The Empty Throne

A PS1-style open world action RPG built in Godot 4.7, inspired by classic dark fantasy games. (Formerly developed under the working title *Catacombs of Gore*.)

## Game Overview

**Broken Provinces: The Empty Throne** is a retro-styled action RPG that combines the exploration of Elder Scrolls games with the brutal combat of Souls-likes, wrapped in a nostalgic PS1 visual aesthetic.

### Key Features

- **PS1 Visual Style**: Low-poly models, billboard sprites, vertex jitter, affine texture mapping
- **Open World Exploration**: Hex-based world map with procedural and hand-crafted content
- **TTRPG-Inspired Combat**: Dice-based damage calculations, critical hits, skill checks
- **Deep NPC Conversations**: Topic-based dialogue system with reputation effects
- **Procedural Dungeons**: Generated dungeon layouts with room templates
- **Quest System**: Main storylines and procedural bounties
- **Crime & Consequence**: Guards, bounties, faction reputation

## Technical Details

- **Engine**: Godot 4.7
- **Language**: GDScript (strict typing)
- **Rendering**: Forward+ with custom PS1 shaders
- **Resolution**: 640x480 (window scaled to 1280x960)

## Project Structure

```
CatacombsOfGore/
├── assets/           # Art, by type
│   ├── characters/   # Citizen models
│   ├── world/        # Buildings, caves, props, terrain, nature
│   ├── weapons/      # Weapon models
│   ├── audio/        # music/ ambience/ sfx/ generated/
│   ├── textures/     # materials/ shaders/ ui/
│   └── sprites/legacy/   # Billboard sprites - being phased out
├── data/             # Game content (.tres and JSON)
│   ├── quests/  items/  weapons/  armor/  enemies/  npcs/
│   ├── dialogue/     # trees/ resources/ pools/ - one tree, was three
│   └── towns/        # Town Editor layouts
├── docs/             # adr/ gdd/ design/ audits/ lore/
├── scenes/
│   ├── levels/       # The 51 hand-authored places
│   ├── characters/   # Player, enemy base, NPC instances
│   ├── world/        # Interactables, stations, structures
│   ├── effects/      # Projectiles and VFX
│   ├── generation/   # Caves, dungeons, rooms, wilderness
│   └── ui/           # Screens
├── scripts/
│   ├── core/         # Services every domain depends on
│   ├── world/        # streaming/ terrain/ interactables/ props/
│   ├── characters/   # player/ npcs/ enemies/ visuals/ ai/
│   ├── systems/      # quests/ factions/ combat/ economy/ dialogue/
│   │                 # crime/ travel/ events/ puzzles/
│   ├── generation/   # towns/ dungeons/ wilderness/ rooms/
│   ├── levels/       # One script per hand-authored place
│   ├── ui/           # Screens, panels, HUD
│   └── data/         # Resource subclasses
├── tools/            # Headless gates - run_all_checks.ps1 is the session gate
├── dev/              # Hand-run harnesses and editors
└── addons/           # Editor plugins
```

The layout, the reasoning behind it, and the complete old -> new map are in
[docs/design/PROJECT_LAYOUT.md](docs/design/PROJECT_LAYOUT.md).

## Core Systems

### Combat
- Real-time melee and ranged combat
- Hitbox/hurtbox collision system
- Status effects and damage types
- Equipment affects stats and abilities

### World
- Hex-based overworld navigation
- Wilderness encounters
- Towns with services (shops, temples, guilds)
- Procedural dungeon generation

### NPCs
- Billboard sprites with 8-directional facing
- Topic-based conversation system
- Memory of past interactions
- Guards with crime response

### Progression
- Level-based character advancement
- Multiple skills (combat, magic, social)
- Equipment crafting and upgrading
- Faction reputation

## Inspirations

- **Skyrim / Elder Scrolls** - Open world, guilds, dialogue
- **Dark Souls / Elden Ring** - Combat feel, difficulty
- **Fallout: New Vegas** - Faction reputation, skill checks
- **King's Field** - PS1 first-person dungeon crawling
- **Tenchu** - Stealth mechanics
- **Final Fantasy 7/8/9** - Story structure

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Camera |
| LMB | Light Attack |
| RMB | Heavy Attack |
| Q | Block |
| Space | Jump |
| Shift | Sprint |
| Ctrl | Dodge |
| E | Interact |
| F | Lock-on |
| Tab | Menu |
| Esc | Pause |
| 1-0 | Hotbar |

## Development Status

**Currently in Development**

The game is being actively developed. Current focus areas:
- NPC visual consistency
- Quest system refinement
- World map population
- Combat balancing

## License

All rights reserved. This code is shared for educational purposes.

## Credits

Developed using **Godot Engine 4.5**
AI-assisted development with **Claude (Anthropic)**
