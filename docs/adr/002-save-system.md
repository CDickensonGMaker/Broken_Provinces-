# ADR-002: Save System Architecture

**Status:** Accepted
**Date:** 2026-05-25
**Deciders:** Technical Director, Lead Programmer

---

## Context

The game requires a robust save system that preserves all player progress, world state, and game settings across sessions. The system must handle:

1. **Multiple Save Slots** - Manual saves for different playthroughs
2. **Autosave** - Periodic and on-exit saves
3. **Version Migration** - Forward compatibility as game evolves
4. **Large State** - Inventory, quests, discoveries, flags, NPC states
5. **Quick Save/Load** - Convenient F5/F9 bindings

---

## Decision

Implement a **JSON-based save system with versioned structure**:

### Core Configuration

```gdscript
SAVE_DIR = "user://saves/"
SAVE_FILE_PREFIX = "save_"
SAVE_FILE_EXT = ".sav"
MAX_SAVE_SLOTS = 10
SAVE_VERSION = 5  # Increment when structure changes
```

### Slot Allocation

| Slots | Purpose |
|-------|---------|
| 0-7 | Manual saves |
| 8 | 30-second periodic autosave |
| 9 | Exit/menu close autosave |

### Save Data Structure

```
SaveData
├── version: int
├── timestamp: float
├── datetime_string: String
├── game_version: String
├── player: PlayerSaveData
│   ├── name, level, class
│   ├── current_hp, max_hp
│   ├── stats, skills, abilities
│   └── known_spells, active_effects
├── inventory: InventorySaveData
│   ├── items: Array[{id, quantity, quality}]
│   ├── gold: int
│   └── equipment: Dictionary
├── world: WorldSaveData
│   ├── current_scene: String
│   ├── player_position: Vector3
│   ├── current_cell: Vector2i
│   ├── discovered_cells: Dictionary
│   ├── discovered_locations: Dictionary
│   ├── world_flags: Dictionary
│   └── dungeon_states: Dictionary
├── quests: QuestSaveData
│   ├── active_quests: Dictionary
│   ├── completed_quests: Array
│   └── tracked_quest_id: String
├── time_data: TimeData
│   ├── day, hour, minute
│   └── total_play_time
├── crime_data: CrimeData
│   └── bounty_per_region: Dictionary
├── dialogue_data: DialogueSaveData
│   └── flags: Dictionary
├── faction_data: FactionSaveData
│   └── reputations: Dictionary
├── morality_data: MoralitySaveData
│   └── morality_score: int
└── audio_settings: Dictionary
```

### Version Migration

When loading older saves:

```gdscript
func _migrate_save_data(data: Dictionary, from_version: int) -> Dictionary:
    if from_version < 2:
        # v1 -> v2: Add CellStreamer fields
        data["world"]["current_cell"] = Vector2i.ZERO
    if from_version < 3:
        # v2 -> v3: Add faction/morality
        data["faction_data"] = {}
        data["morality_data"] = {"score": 50}
    # ... etc for each version
    data["version"] = SAVE_VERSION
    return data
```

### Autosave Behavior

**Periodic (30 seconds):**
- Only saves during active gameplay
- Skips if player dead, game paused, or scene loading
- Uses slot 8

**Exit Autosave:**
- Triggers on WM_CLOSE_REQUEST notification
- Wrapped in error handling to prevent crash
- Uses slot 9

### Quick Save/Load

- **F5** - Quick save to slot 0
- **F9** - Quick load from slot 0
- Blocked during scene transitions

---

## Consequences

### Positive

1. **Human Readable** - JSON format allows debugging
2. **Forward Compatible** - Version migration handles updates
3. **Comprehensive** - All game state preserved
4. **Multiple Strategies** - Manual + autosave options
5. **Quick Access** - F5/F9 for convenience

### Negative

1. **File Size** - JSON not as compact as binary
2. **Parse Time** - Large saves take longer to parse
3. **Complexity** - Many subsystems contribute data
4. **Migration Burden** - Each version needs migration code

### Mitigations

- JSON pretty-printed only for debugging (could use compact)
- Migration code tested with sample saves
- Each manager responsible for its own data section

---

## Alternatives Considered

### Alternative 1: Binary Format

**Approach:** Use FileAccess binary methods

**Rejected Because:**
- Hard to debug corrupted saves
- Version migration more complex
- No benefit for current save sizes

### Alternative 2: Godot ConfigFile

**Approach:** Use ConfigFile for INI-style saves

**Rejected Because:**
- Poor support for nested structures
- No array support
- Limited type preservation

### Alternative 3: Resource Files

**Approach:** Save as .tres Resource files

**Rejected Because:**
- Godot version coupling
- Harder to manually inspect
- Less portable

### Alternative 4: SQLite Database

**Approach:** Store saves in SQLite

**Rejected Because:**
- Overkill for single-player RPG
- External dependency
- Harder to distribute save files

---

## Implementation Details

### Save Flow

1. `save_game(slot)` called
2. `_collect_save_data()` gathers all state
3. Each manager contributes via `_collect_*_data()` methods
4. `SaveData.to_dict()` serializes to Dictionary
5. `JSON.stringify()` converts to string
6. FileAccess writes to `user://saves/save_N.sav`

### Load Flow

1. `load_game(slot)` called
2. FileAccess reads JSON string
3. `JSON.parse()` creates Dictionary
4. Version check and migration if needed
5. `SaveData.from_dict()` deserializes
6. `_apply_save_data()` restores all managers
7. Scene change to saved scene with position

### Manager Integration

Each autoload manager implements:
- `_collect_*_data(save_data)` - Gather state
- Data restoration via `_apply_save_data()` calls

| Manager | Data Collected |
|---------|----------------|
| GameManager | Player stats, level, class |
| InventoryManager | Items, gold, equipment |
| QuestManager | Active/completed quests |
| DialogueManager | Dialogue flags |
| FactionManager | Faction reputations |
| MoralityManager | Morality score |
| CrimeManager | Regional bounties |
| PlayerGPS | Discoveries, position |
| DayNightManager | Time of day |
| AudioManager | Volume settings |

### Persistent World State

Some state persists outside the normal save:

| Data | Storage | Purpose |
|------|---------|---------|
| Dungeon seeds | `dungeon_seeds.cache` | Consistent procedural generation |
| Chest contents | `persistent_chest_contents` | Town storage |
| World flags | `world_flags` | Global state |

### Signals

| Signal | When |
|--------|------|
| `save_completed(slot)` | Save finished |
| `load_completed(slot)` | Load finished |
| `save_failed(slot, error)` | Save error |
| `load_failed(slot, error)` | Load error |

---

## Edge Cases

### Mid-Dialogue Save

- Dialogue state NOT saved
- Save during dialogue ends conversation
- Next load resumes outside dialogue

### Player Death

- Autosave blocked when player dead
- Prevents death loop on load

### Scene Transition

- Save blocked during `is_loading`
- Prevents corrupted position/scene state

### Invalid Save Data

- `save_data.is_valid()` check on load
- Failed validation emits `load_failed`

---

## Files

| File | Purpose |
|------|---------|
| `scripts/core/save_manager.gd` | Core save/load logic |
| `scripts/data/save_data.gd` | Save structure class |
| `scripts/data/save_sections/*.gd` | Section classes |

---

## Version History

| Version | Changes |
|---------|---------|
| 1 | Initial save structure |
| 2 | Added CellStreamer integration |
| 3 | Added MoralityManager, FactionManager |
| 4 | Added StatsTracker, JournalManager |
| 5 | Added SoulstoneEconomy |

---

## References

- [Godot FileAccess Documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html)
- [JSON Save Game Tutorial](https://docs.godotengine.org/en/stable/tutorials/io/saving_games.html)
