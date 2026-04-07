# Quest Implementation Plan

## Overview
This document outlines the implementation requirements for ~110 new quests across 4 guilds, 3 temples, wizard training, and Keepers expansion.

---

# PHASE 1: CORE SYSTEMS (Required for ALL quests)

## 1.1 Quest Flag System Enhancement
**Priority:** CRITICAL
**Effort:** 1-2 days

Current `FlagManager` needs to support:
- Devotee flags (`chronos_devotee`, `gaela_devotee`, `morthane_devotee`)
- Guild rank flags (`adventurers_elite`, `thieves_burglar`, etc.)
- Quest prerequisite checking based on flags

**Files to modify:**
- `scripts/autoload/flag_manager.gd`
- `scripts/autoload/quest_manager.gd`

---

## 1.2 Faction Sub-System
**Priority:** CRITICAL
**Effort:** 1 day

Add sub-factions under `church_of_three`:
- `church_of_chronos`
- `church_of_gaela`
- `church_of_morthane`

Add new guild factions:
- `iron_company`
- `arcane_circle`

**Files to modify:**
- `scripts/autoload/faction_manager.gd`
- `data/factions/` (create faction definition files)

---

# PHASE 2: NPC & DIALOGUE INFRASTRUCTURE

## 2.1 New Guild Leader NPCs

### Captain Roderick Steele (Iron Company)
**Location:** Iron Hall, Dalhurst
**Sprite Needed:** YES - `captain_roderick_steele.png`
- Grizzled veteran, scarred face, steel-gray hair
- Heavy armor, military bearing
- 32x64, 5-frame idle

### Archmage Elara Moonweave (Arcane Circle)
**Location:** The Athenaeum, Dalhurst
**Sprite Needed:** YES - `archmage_elara.png`
- Elegant elven woman, silver hair
- Ornate robes, magical staff
- 32x64, 5-frame idle

### Supporting NPCs (sprites needed)
| NPC | Location | Sprite |
|-----|----------|--------|
| Katrina Steelwind | Dalhurst Guild | `katrina_steelwind.png` - Female warrior |
| Red Mara | Dalhurst (thieves) | `red_mara.png` - Rival thief leader |
| Guild Mastermind | Dalhurst (thieves) | `guild_mastermind.png` - Hooded figure |
| High Chronist | Thornfield | `high_chronist.png` - Elder priest |
| Malachai the Profane | Crossroads ruins | `malachai_profane.png` - Cult leader |

**Total New NPC Sprites:** 7

---

## 2.2 New Buildings/Interiors (3D Scenes)

### Iron Hall (Mercenary HQ)
**Location:** Dalhurst
**Scene:** `scenes/interiors/iron_hall.tscn`
**Assets Needed:**
- Military barracks interior
- Training dummies
- Weapon racks
- Contract board
- Captain's office area

### The Athenaeum (Mage Guild)
**Location:** Dalhurst
**Scene:** `scenes/interiors/athenaeum.tscn`
**Assets Needed:**
- Library with bookshelves
- Magical artifacts on display
- Enchanting table
- Council chamber
- Restricted section (locked door)

### Temple Expansion (Elder Moor)
**Modify existing:** `scenes/levels/elder_moor.tscn`
**Add:**
- Three distinct altar areas (Chronos, Gaela, Morthane)
- Meditation shrine for Chronos visions
- Garden area for Gaela
- Crypt entrance for Morthane

---

# PHASE 3: SCRIPTED EVENT SYSTEMS

## 3.1 NPC Escort System
**Priority:** HIGH
**Effort:** 2-3 days
**Quests Using:** Adventurers 3, Mercenary 4

**Implementation:**
```gdscript
class_name EscortNPC extends CivilianNPC

signal escort_arrived(destination)
signal escort_died()

var follow_target: Node3D
var destination_marker: Node3D
var follow_distance: float = 3.0

func start_escort(player: Node3D, dest: Node3D) -> void:
    follow_target = player
    destination_marker = dest
    # Enable follow AI
```

**Features:**
- NPC follows player at set distance
- Ambush trigger zones spawn enemies
- NPC can take damage (quest fails if dies)
- Arrival at destination completes objective

---

## 3.2 Timed Objective System
**Priority:** HIGH
**Effort:** 1-2 days
**Quests Using:** Chronos 3, Mercenary 6, Mage 8, Morthane 7

**Implementation:**
- Timer UI element (top of screen)
- Quest objective with `time_limit` field
- Failure state if timer expires
- Optional: time extensions from actions

**UI Asset Needed:** Timer bar graphic

---

## 3.3 NPC Duel System
**Priority:** HIGH
**Effort:** 2-3 days
**Quests Using:** Adventurers 13, Mercenary 13, Mage 13, Thieves 8

**Implementation:**
```gdscript
class_name DuelManager extends Node

signal duel_started(player, opponent)
signal duel_ended(winner, loser)

var is_duel_active: bool = false
var duel_opponent: EnemyBase
var is_lethal: bool = false  # Non-lethal for guild duels

func start_duel(opponent: EnemyBase, lethal: bool = false) -> void:
    is_duel_active = true
    is_lethal = lethal
    # Lock player in arena
    # Opponent uses special duel AI
```

**Features:**
- Arena boundary (can't leave during duel)
- Non-lethal mode (opponent yields at low HP)
- Victory/defeat outcomes
- Crowd reactions (optional)

**3D Scene Needed:** Duel arena area (can be part of guild halls)

---

## 3.4 Wave Defense System
**Priority:** HIGH
**Effort:** 2-3 days
**Quests Using:** Mercenary 11-12, Morthane 9, Keepers 4

**Implementation:**
```gdscript
class_name WaveSpawner extends Node3D

signal wave_started(wave_num)
signal wave_completed(wave_num)
signal all_waves_completed()

@export var waves: Array[WaveData]
@export var spawn_points: Array[Marker3D]

var current_wave: int = 0
var enemies_remaining: int = 0
```

**WaveData Resource:**
```gdscript
class_name WaveData extends Resource
@export var enemy_types: Array[String]
@export var enemy_counts: Array[int]
@export var spawn_delay: float = 1.0
@export var time_between_waves: float = 10.0
```

**UI Asset Needed:** Wave counter ("Wave 3/5")

---

## 3.5 Stealth Detection System
**Priority:** MEDIUM-HIGH
**Effort:** 3-4 days
**Quests Using:** All Thieves Guild quests, Keepers 1, 3

**Implementation:**
- Guard NPC with vision cone
- Alert states: Unaware → Suspicious → Alert → Combat
- Noise system (running = louder)
- Hide spots (shadows, containers)
- Detection meter UI

**Assets Needed:**
- Vision cone shader/texture
- Detection meter UI
- Alert indicator above guards

**New Enemy Type:** `guard_patrol.tres` - Non-hostile until alerted

---

## 3.6 Vision/Cutscene System
**Priority:** MEDIUM
**Effort:** 2-3 days
**Quests Using:** Chronos 1, 6, 8

**Implementation:**
- Fade to black/white
- Show pre-rendered or scripted scene
- Dialogue boxes for narration
- Return to gameplay

**Can use existing dialogue system with:**
- Full-screen background images
- Timed auto-advance
- No player choices during vision

**Assets Needed:**
- 3-5 vision background images (past events)
- Vision border/frame overlay

---

# PHASE 4: QUEST-SPECIFIC CONTENT

## 4.1 Dungeon Additions

### Willow Dale Depths
**Quests:** Adventurers 7, 12, Mage 6, Chronos 6
**Add to existing Willow Dale:**
- Deeper level with harder enemies
- Artifact chamber
- Ancient guardian boss room
- Time-touched area (for Chronos quests)

### Dalhurst Cemetery
**Quests:** Morthane 3, 9
**New Scene:** `scenes/levels/dalhurst_cemetery.tscn`
**Assets:**
- Graveyard tileset (tombstones, crypts, dead trees)
- Mausoleum entrance
- Necromantic totem interactable

### Cult Hideout
**Quests:** Keepers 1-4
**New Scene:** `scenes/levels/cult_hideout.tscn`
**Assets:**
- Cave/underground temple
- Dark altar
- Ritual circle
- Cult banners/symbols

### Crossroads Temple Ruins
**Quests:** Keepers 4
**New Scene:** `scenes/levels/crossroads_ruins.tscn`
**Assets:**
- Ruined temple structure
- Portal/summoning circle
- Boss arena

---

## 4.2 New Enemy Types

### Regular Enemies (sprites needed)
| Enemy | Type | Quests | Sprite |
|-------|------|--------|--------|
| Giant Spider | Beast | Adventurers (old quests) | `giant_spider.png` |
| Spider Queen | Boss | Guild contract | `spider_queen.png` |
| Wyvern/Drake | Boss | Adventurers 10 | `wyvern.png` |
| Temporal Guardian | Spectral | Chronos 9-10 | `temporal_guardian.png` |
| The Timeless One | Boss | Chronos 10 | `timeless_one.png` |
| Cultist | Humanoid | Keepers all | `cultist.png` (may exist) |
| Cult Leader | Boss | Keepers 4 | `malachai_profane.png` |
| Undead Lord Malthor | Boss | Morthane 10 | `undead_lord_malthor.png` |
| Shadow Circle Mage | Humanoid | Mage 9-12 | `shadow_mage.png` |
| Planar Entity | Monster | Mage 11 | `planar_entity.png` |
| Rival Mercenary | Humanoid | Mercenary 8 | `rival_mercenary.png` |
| Black Wolf Captain | Humanoid | Mercenary 8 | `black_wolf_captain.png` |

**Total New Enemy Sprites:** ~12

### Boss Stat Guidelines
| Boss | Level | HP | Armor | Special |
|------|-------|-----|-------|---------|
| Spider Queen | 20 | 500 | 15 | Web attack, summons spiders |
| Wyvern | 25 | 800 | 20 | Flight, fire breath |
| The Timeless One | 35 | 1500 | 30 | Time stop, phase shift |
| Undead Lord Malthor | 30 | 1200 | 25 | Raise dead, death aura |
| Malachai | 30 | 1000 | 20 | Dark magic, summon demons |

---

## 4.3 New Items

### Quest Items (no sprites needed - inventory icons)
- Sacred Sand (Chronos)
- Hourglass Fragment (Chronos)
- Moonpetal Flowers (Gaela)
- Sacred Spring Water (Gaela)
- Burial Incense (Morthane)
- Guild Tokens (all guilds)
- Cult Documents (Keepers)
- Stolen Ledgers (Thieves)
- Grimoire Pages (Wizard)

### Equipment Rewards (need inventory icons)
| Item | Type | Quest Reward |
|------|------|--------------|
| Chronos Amulet | Accessory | Chronos 5 |
| Gaela's Amulet | Accessory | Gaela 5 |
| Morthane's Amulet | Accessory | Morthane 5 |
| Elite Guild Seal | Accessory | Adventurers 9 |
| Master Thief Cloak | Armor | Thieves 13 |
| Iron Company Badge | Accessory | Mercenary 3 |
| Arcane Circle Robes | Armor | Mage 13 |
| Adept Robes | Armor | Wizard 6 |
| Champion's Mantle | Armor | Temple Champions |
| Time-Touched Blade | Weapon | Chronos 6 |
| Reaper's Blade | Weapon | Morthane 9 |
| Dragonscale Shield | Shield | Adventurers 10 |

---

# PHASE 5: DIALOGUE & NARRATIVE

## 5.1 Dialogue Files Needed

### Guild Leaders (full dialogue trees)
- `captain_roderick_steele.json` - All mercenary quest dialogue
- `archmage_elara.json` - All mage quest dialogue
- `guildmaster_vorn.json` - UPDATE for new adventurer quests
- `lady_nightshade.json` - UPDATE for new thieves quests

### Temple Priests (full dialogue trees)
- `priest_chronos.json` - All Chronos quest dialogue + devotee choice
- `priestess_gaela.json` - All Gaela quest dialogue + devotee choice
- `priest_morthane.json` - All Morthane quest dialogue + devotee choice

### Quest NPCs (partial dialogue)
- `high_chronist_thornfield.json`
- `katrina_steelwind.json`
- `red_mara.json`
- `malachai_profane.json`
- `necromancer_aeris.json` (moral grey NPC)

**Total Dialogue Files:** ~15 major, ~20 minor

---

# IMPLEMENTATION PRIORITY ORDER

## Sprint 1: Foundation (Week 1-2)
1. Flag system enhancement
2. Faction sub-system
3. Create guild leader NPCs (sprites + blueprints)
4. Basic guild hall scenes (Iron Hall, Athenaeum)

## Sprint 2: Core Systems (Week 3-4)
1. NPC Escort system
2. Timed objective system
3. NPC Duel system
4. Wave defense system

## Sprint 3: Temple Content (Week 5-6)
1. Temple area expansion in Elder Moor
2. All 3 temple quest chains (dialogue + testing)
3. Devotee flag system
4. Temple-specific enemies

## Sprint 4: Guild Content Part 1 (Week 7-8)
1. Adventurer's Guild full chain
2. Thieves Guild full chain
3. Stealth detection system
4. Heist planning UI

## Sprint 5: Guild Content Part 2 (Week 9-10)
1. Mercenary Guild full chain
2. Mage Guild full chain
3. Large battle system refinement
4. Magic specialization system

## Sprint 6: Supporting Content (Week 11-12)
1. Wizard Apprentice chain
2. Keepers expansion
3. All dungeon additions
4. Boss fights polish

## Sprint 7: Polish & Testing (Week 13-14)
1. Quest flow testing
2. Balance pass on rewards
3. Dialogue proofreading
4. Bug fixes

---

# ASSET CHECKLIST

## New NPC Sprites (7)
- [ ] captain_roderick_steele.png
- [ ] archmage_elara.png
- [ ] katrina_steelwind.png
- [ ] red_mara.png
- [ ] guild_mastermind.png
- [ ] high_chronist.png
- [ ] malachai_profane.png

## New Enemy Sprites (12)
- [ ] giant_spider.png
- [ ] spider_queen.png
- [ ] wyvern.png
- [ ] temporal_guardian.png
- [ ] timeless_one.png
- [ ] undead_lord_malthor.png
- [ ] shadow_mage.png
- [ ] planar_entity.png
- [ ] rival_mercenary.png
- [ ] black_wolf_captain.png
- [ ] guard_patrol.png
- [ ] cultist_elite.png

## New 3D Scenes (6)
- [ ] scenes/interiors/iron_hall.tscn
- [ ] scenes/interiors/athenaeum.tscn
- [ ] scenes/levels/dalhurst_cemetery.tscn
- [ ] scenes/levels/cult_hideout.tscn
- [ ] scenes/levels/crossroads_ruins.tscn
- [ ] scenes/levels/willow_dale_depths.tscn (or expand existing)

## UI Assets (4)
- [ ] Timer bar for timed objectives
- [ ] Wave counter display
- [ ] Detection meter (stealth)
- [ ] Vision border overlay

## Dialogue Files (35+)
- [ ] 4 guild leader full dialogues
- [ ] 3 temple priest full dialogues
- [ ] ~10 supporting NPC dialogues
- [ ] ~18 minor quest NPC dialogues

---

# NOTES

## Can Reuse Existing Assets
- Bandit sprites → Rival mercenaries (recolor)
- Skeleton sprites → Enhanced undead
- Cultist sprites → Cult variations
- Guard sprites → Patrol guards
- Dungeon tilesets → New dungeon scenes

## Systems That Already Exist
- Basic combat
- Quest tracking
- Dialogue system
- Faction reputation
- Skill checks in dialogue

## Systems Needing Enhancement
- Flag-gated quest prerequisites
- Sub-faction tracking
- NPC follow behavior
- Large enemy counts (performance)

