# Chronos Quest Chain - Implementation Guide

## Quick Start

This guide provides step-by-step instructions for implementing the Chronos quest chain in Catacombs of Gore.

---

## Phase 1: Core Quest Integration (Priority 1)

### Step 1.1: Verify Quest Loader
Ensure `QuestManager` can load quests from `data/quests/temple/chronos/` directory.

```gdscript
# In quest_manager.gd or equivalent loader
var chronos_quests := [
    "chronos_01_first_vision",
    "chronos_02_hourglasses",
    "chronos_03_late_delivery",
    "chronos_04_false_prophet",
    "chronos_05_devotion_choice",
    "chronos_06_temporal_echo",
    "chronos_07_paradox",
    "chronos_08_prophet_training",
    "chronos_09_timeline_threat",
    "chronos_10_eternal_vigil",
    "chronos_repeatable_visions"
]

for quest_id in chronos_quests:
    var path := "res://data/quests/temple/chronos/%s.json" % quest_id
    load_quest_from_json(path)
```

### Step 1.2: Register Faction
Add `church_of_chronos` as a sub-faction of `church_of_three`.

```gdscript
# In faction_manager.gd initialization
register_faction("church_of_chronos", "Church of Chronos", "church_of_three")
```

### Step 1.3: Flag System Integration
Ensure FlagManager can handle new flags:
- `chronos_devotee`
- `chronos_path_declined`
- `millbrook_seer_exposed`
- `millbrook_seer_genuine`
- `paradox_stone_destroyed`
- `paradox_stone_harnessed`

---

## Phase 2: NPC Creation (Priority 1)

### NPC 2.1: Priest of Chronos (Existing)
**ID:** `priest_chronos_dalhurst`
**Location:** Dalhurst Temple (left of altar)
**Status:** Should already exist - VERIFY spawn and dialogue

**Dialogue Topics to Add:**
- Initial greeting (offer Quest 1)
- Quest progression dialogues for quests 1-10
- Repeatable quest dialogue (Quest 11)
- Devotion ritual dialogue (Quest 5) ⭐ CRITICAL

**Sample Devotion Dialogue:**
```
Priest: "You have walked the path with dedication, [Player]. The Timekeeper
has shown me visions of your future - if you choose to embrace it. I ask you
now: Will you dedicate yourself to Chronos? To see the world through the lens
of time, fate, and inevitability? This is not a choice to make lightly."

Choice 1: "I accept. I will become a Devotee of Chronos."
  → Sets chronos_devotee flag
  → Grants Chronos Amulet
  → +50 church_of_chronos
  → Priest: "Then the path is open to you, Acolyte of Time..."

Choice 2: "I cannot commit to one path alone."
  → Sets chronos_path_declined flag
  → Quest chain ends
  → Priest: "I understand. The Timekeeper reveals all in time..."
```

---

### NPC 2.2: High Chronist (Thornfield)
**ID:** `high_chronist_thornfield`
**Location:** Thornfield (temple or shrine)
**Status:** CREATE NEW NPC

**Purpose:** Receives prophecy in Quest 3, minor role

**Dialogue:**
```
Initial: "Greetings, traveler. How may the Temple of Time serve you?"

Quest 3 Turn-in: "Ah, the sealed prophecy from Dalhurst! You have done well
to bring this swiftly. The visions within... troubling, but necessary.
Chronos reveals what must be known."
```

**Spawn in Thornfield:**
```gdscript
var priest := CivilianNPC.spawn_civilian(
    thornfield_npcs,
    Vector3(305, 0, -195),  # Near temple/shrine area
    "high_chronist_thornfield",
    "High Chronist",
    preload("res://assets/sprites/npcs/priest_male.png"),  # Use priest sprite
    5, 1, 0.0384
)
priest.archetype = "priest"
```

---

### NPC 2.3: False Prophet (Millbrook)
**ID:** `false_prophet_millbrook`
**Location:** Millbrook (town square or market)
**Status:** CREATE NEW NPC

**Purpose:** Investigation target in Quest 4, has branching dialogue

**Dialogue Trees:**
1. **Initial Investigation** - Player asks about visions
2. **Skill Check Branch** - Persuasion or Intuition check
3. **Outcome A: Exposed** - Player calls out fraud, confrontation
4. **Outcome B: Accepted** - Player believes there's genuine gift

**Sample Dialogue:**
```
Seer: "Ah, another seeker of truth! Come, sit. The visions flow through me
like water through time itself. For a small donation, I can reveal what
Chronos has shown me..."

Choice 1: [Persuasion DC 12] "You're a fraud. I can see right through you."
  → Success: Seer confesses, sets millbrook_seer_exposed
  → Failure: Seer becomes hostile or refuses to speak

Choice 2: [Intuition DC 12] "Tell me more about your visions."
  → Success: Detect genuine flickers of foresight, sets millbrook_seer_genuine
  → Failure: Can't tell if real or fake, must choose
```

**Spawn in Millbrook:**
```gdscript
var seer := CivilianNPC.spawn_civilian(
    millbrook_npcs,
    Vector3(-685, 0, 395),  # Town square
    "false_prophet_millbrook",
    "Traveling Seer",
    preload("res://assets/sprites/npcs/wizard_old.png"),  # Mystic appearance
    5, 1, 0.0384
)
seer.archetype = "civilian"
```

---

### NPC 2.4: Temporal Echo Trigger (Willow Dale)
**ID:** `temporal_echo_trigger`
**Location:** Willow Dale Ruins
**Status:** CREATE INTERACTABLE OBJECT

**Purpose:** Triggers vision cutscene in Quest 6

**Implementation:**
```gdscript
# Create as StaticBody3D or Area3D
class_name TemporalEchoShrine
extends StaticBody3D

signal vision_triggered

func interact() -> void:
    if QuestManager.is_quest_active("chronos_06_temporal_echo"):
        if QuestManager.is_objective_active("chronos_06_temporal_echo", "witness_vision"):
            trigger_vision()

func trigger_vision() -> void:
    # Play cutscene/dialogue showing Willow Dale's fall
    emit_signal("vision_triggered")
    QuestManager.complete_objective("chronos_06_temporal_echo", "witness_vision")
```

**Spawn in Willow Dale:**
```gdscript
var shrine := TemporalEchoShrine.new()
shrine.position = Vector3(-485, 0, -485)  # Center of ruins
willow_dale.add_child(shrine)
```

---

## Phase 3: Enemy Creation (Priority 2)

### Enemy 3.1: Temporal Guardian
**File:** `data/enemies/temporal_guardian.tres`
**Type:** Spectral humanoid
**Level:** 18-22
**Used In:** Quest 6 (3x), Quest 10 (6x corrupted variant)

**Stats:**
```gdscript
# EnemyData resource
enemy_id = "temporal_guardian"
display_name = "Temporal Guardian"
max_health = 120
damage = 25
armor = 15
xp_reward = 180
faction = 0  # Neutral/hostile
loot_tier = "UNCOMMON"

# Abilities
can_phase_shift = true  # Brief invulnerability
temporal_slow_chance = 0.3  # 30% to slow player on hit
```

**Sprite:** Ghostly/spectral humanoid with blue/white temporal aura

---

### Enemy 3.2: Time Aberration
**File:** `data/enemies/time_aberration.tres`
**Type:** Twisted creature (multi-headed wolf or phasing bandit)
**Level:** 24-28
**Used In:** Quest 9 (5x)

**Stats:**
```gdscript
enemy_id = "time_aberration"
display_name = "Time Aberration"
max_health = 150
damage = 30
armor = 18
xp_reward = 250
faction = 0
loot_tier = "RARE"

# Abilities
unpredictable_movement = true  # Erratic AI pattern
duplicate_attack_chance = 0.25  # Attacks twice in one swing
```

**Sprite:** Distorted/glitchy creature with multiple overlapping frames

---

### Enemy 3.3: Temporal Rift Guardian (Boss)
**File:** `data/enemies/temporal_rift_guardian.tres`
**Type:** Major boss
**Level:** 30
**Used In:** Quest 9 (boss encounter)

**Stats:**
```gdscript
enemy_id = "temporal_rift_guardian"
display_name = "Rift Guardian"
max_health = 500
damage = 45
armor = 25
xp_reward = 600
faction = 0
loot_tier = "EPIC"

# Boss abilities
aoe_temporal_burst = true  # Area attack
time_rewind_self = true  # Heals by rewinding damage
summon_aberrations = true  # Spawns 2 aberrations at 50% HP
```

---

### Enemy 3.4: Corrupted Temporal Guardian
**File:** `data/enemies/corrupted_temporal_guardian.tres`
**Type:** Enhanced spectral (corrupted variant)
**Level:** 32-35
**Used In:** Quest 10 (6x)

**Stats:**
```gdscript
enemy_id = "corrupted_temporal_guardian"
display_name = "Corrupted Guardian"
max_health = 180
damage = 35
armor = 20
xp_reward = 300
faction = 0
loot_tier = "RARE"

# Enhanced abilities
corruption_aura_damage = true  # Deals DoT to nearby player
phase_shift_aggressive = true  # More frequent phasing
```

---

### Enemy 3.5: The Timeless One (Epic Boss)
**File:** `data/enemies/the_timeless_one.tres`
**Type:** Ultimate boss
**Level:** 38
**Used In:** Quest 10 (final boss)

**Stats:**
```gdscript
enemy_id = "the_timeless_one"
display_name = "The Timeless One"
max_health = 1200
damage = 60
armor = 30
xp_reward = 1500
faction = 0
loot_tier = "LEGENDARY"

# Epic boss mechanics
immune_to_temporal_effects = true  # Cannot be slowed/frozen
reality_tear_attack = true  # Devastating AoE
phase_invulnerability = true  # Periodic invuln phases
summon_corrupted_guardians = true  # Spawns 2 at 70%, 40% HP
enrage_at_low_hp = true  # 25% HP increases attack speed
```

**Sprite:** Large, imposing figure with fractal/shifting appearance

---

## Phase 4: Item Creation (Priority 2)

### Quest Items (Temporary)

```gdscript
# All quest items should have consume_on_use = false, quest_item = true

1. timekeepers_token (Quest 1)
2. elder_moor_sand (Quest 2)
3. thornfield_sand (Quest 2)
4. willow_dale_sand (Quest 2)
5. sealed_time_prophecy (Quest 3)
6. paradox_stone (Quest 7)
7. chronos_sealing_stone (Quest 9, need 3)
```

### Reward Items (Permanent)

**Tier 1-2 Rewards:**
```gdscript
# minor_time_blessing - Consumable
item_id = "minor_time_blessing"
display_name = "Minor Time Blessing"
effect = "+10% movement speed for 10 minutes"
value = 25

# ceremonial_hourglass - Trinket
item_id = "ceremonial_hourglass"
display_name = "Ceremonial Hourglass"
effect = "Keepsake item (no mechanical effect)"
value = 50

# truth_seekers_pendant - Equipment
item_id = "truth_seekers_pendant"
display_name = "Truth Seeker's Pendant"
effect = "+2 Intuition"
value = 150
```

**Tier 3 Rewards:**
```gdscript
# chronos_amulet - Unique Equipment ⭐
item_id = "chronos_amulet"
display_name = "Chronos Amulet"
effect = "+3 Intuition, +5% dodge chance"
value = 500
unique = true

# time_touched_blade - Unique Weapon
item_id = "time_touched_blade"
display_name = "Time-Touched Blade"
damage = 35
effect = "20% chance to slow enemy on hit"
value = 600
unique = true

# prophets_circlet - Unique Headpiece
item_id = "prophets_circlet"
display_name = "Prophet's Circlet"
effect = "+4 Intuition, Prophet's Sight ability"
value = 750
unique = true
# Prophet's Sight: Occasionally reveals hints about hidden paths/quest outcomes
```

**Tier 4 Rewards:**
```gdscript
# timekeepers_aegis - Legendary Armor/Shield
item_id = "timekeepers_aegis"
display_name = "Timekeeper's Aegis"
armor = 50
effect = "Immune to time-based debuffs, +20% temporal resist"
value = 1500
rarity = "LEGENDARY"

# eternal_hourglass_fragment - Legendary Set Piece
item_id = "eternal_hourglass_fragment"
display_name = "Eternal Hourglass Fragment"
effect = "+5 to all stats, part of Champion of Chronos set"
value = 2000
rarity = "LEGENDARY"
set_piece = "champion_of_chronos_set"

# champions_mantle - Unique Cloak
item_id = "champions_mantle"
display_name = "Champion's Mantle"
effect = "+6 Intuition, Time Warp ability (active)"
value = 2500
unique = true
rarity = "LEGENDARY"
# Time Warp: Slow time for 5 seconds (60s cooldown)
```

**Choice-Based Rewards:**
```gdscript
# chronos_blessing_major - Consumable (Quest 7, destroy choice)
item_id = "chronos_blessing_major"
display_name = "Major Time Blessing"
effect = "+20% all stats for 30 minutes"
value = 200

# paradox_talisman - Equipment (Quest 7, harness choice)
item_id = "paradox_talisman"
display_name = "Paradox Talisman"
effect = "+10% crit chance, -5% max HP (unstable)"
value = 400
unique = true
# Powerful but has downside (reflects the risky choice)
```

---

## Phase 5: World Integration (Priority 3)

### Spawn Markers

**Quest 1: Crossroads**
```gdscript
# In crossroads.gd or spawn script
var chest := Chest.spawn_chest(
    self,
    Vector3(-485, 0, -185),
    "Ancient Shrine",
    false,  # Not locked
    0,
    false,
    "chronos_q1_token"
)
# Only spawns when quest is active via spawn_on_accept
```

**Quest 2: Three Locations**
```gdscript
# Elder Moor
var chest_em := Chest.spawn_chest(self, Vector3(15, 0, 20), "Time Shrine", false, 0, false, "chronos_q2_sand_em")

# Thornfield
var chest_th := Chest.spawn_chest(self, Vector3(310, 0, -190), "Hilltop Shrine", false, 0, false, "chronos_q2_sand_th")

# Willow Dale
var chest_wd := Chest.spawn_chest(self, Vector3(-485, 0, -485), "Ruined Shrine", false, 0, false, "chronos_q2_sand_wd")
```

**Quest 6: Willow Dale Temporal Guardians**
```gdscript
# Spawn 3 Temporal Guardians when quest is active
var guardian1 := EnemyBase.spawn_billboard_enemy(
    self,
    Vector3(-490, 0, -475),
    "res://data/enemies/temporal_guardian.tres",
    preload("res://assets/sprites/enemies/temporal_guardian.png"),
    4, 4
)

# Repeat for positions (-480, 0, -490) and (-475, 0, -480)
```

**Quest 9: Bandit Hideout Rift**
```gdscript
# Spawn 5 Time Aberrations and 1 Rift Guardian
# Spawn 3 Sealing Stone chests
# See FLOWCHART.txt for exact coordinates
```

**Quest 10: Kazer-Dun Shrine**
```gdscript
# Spawn 6 Corrupted Guardians and 1 Timeless One
# Create Eternal Hourglass interactable
# See FLOWCHART.txt for exact coordinates
```

---

### Puzzle Mechanics

**Quest 6: Temporal Echo**
Simple interactable - triggers cutscene when activated.

**Quest 7: Time Loop Puzzle**
Player must interact with 3-4 objects in a specific sequence at Crossroads. Wrong sequence resets the puzzle.

Example:
```gdscript
var correct_sequence := [1, 3, 2, 4]  # Object IDs
var player_sequence := []

func activate_object(object_id: int) -> void:
    player_sequence.append(object_id)

    if player_sequence.size() == correct_sequence.size():
        if player_sequence == correct_sequence:
            complete_puzzle()
        else:
            reset_puzzle()
```

**Quest 9: Sealing Ritual**
Player must place 3 Chronos Sealing Stones at ritual points around the rift, then activate central altar.

**Quest 10: Hourglass Restoration**
Multi-step ritual involving channeling temporal energy (could be simple activate-and-wait or more complex mini-game).

---

## Phase 6: Dialogue Writing (Priority 1)

### Critical Dialogues

**Quest 5: Devotion Choice** (HIGHEST PRIORITY)
This is the most important dialogue in the entire chain. Must be compelling and clear about consequences.

**Structure:**
1. Priest opens with reflection on player's journey
2. Explains what Devotion means (philosophical, not just mechanical)
3. Presents the choice clearly
4. Handles both outcomes gracefully

**Tone:** Serious, reverent, but not pressuring. Player must feel this is THEIR choice.

**Quest 4: False Prophet Investigation**
Two branching paths based on skill checks or player choice.

**Quest 11: Repeatable Visions**
Random selection from a pool of 10+ short visions for variety.

---

## Phase 7: Testing Plan

### Test Cases

**Test 1: Full Orthodox Path**
- Complete quests 1-10 in order
- Choose "expose" in Quest 4
- Choose "accept devotion" in Quest 5
- Choose "destroy stone" in Quest 7
- Verify Champion title and reputation totals

**Test 2: Decline Devotion Path**
- Complete quests 1-5
- Choose "decline devotion" in Quest 5
- Verify quests 6-10 do NOT appear
- Verify can still worship at temple

**Test 3: Power-Seeker Path**
- Choose "accept seer" in Quest 4
- Choose "harness stone" in Quest 7
- Verify different dialogue/reputation outcomes

**Test 4: Save/Load**
- Save in middle of quest chain
- Load save
- Verify quest states and flags persist

**Test 5: Repeatable Quest**
- Complete main chain
- Complete Quest 11
- Verify 7-day cooldown
- Complete again after cooldown

---

## Phase 8: Balance Tuning

### Enemy Difficulty
- Temporal Guardians (Quest 6): Should be challenging but not impossible for level 18-22
- Rift Guardian (Quest 9): Tough boss, expect 2-3 deaths on first attempt
- The Timeless One (Quest 10): Epic difficulty, may require preparation and strategy

### Rewards
- Gold values are modest until late quests (reflects escalating importance)
- XP values scale smoothly from 200 → 2000
- Unique items should feel meaningful without being overpowered
- Legendary items (Quest 10) can be very powerful - this is endgame content

### Reputation
- Total +315 church_of_chronos reaches Exalted standing
- Should be highest possible rep with a single faction quest chain
- Other god quests (Gaela, Morthane) should offer comparable paths

---

## Implementation Priority Order

**Week 1: Foundation**
1. Verify quest loading and flag system
2. Create Priest of Chronos dialogue for Quest 5 (devotion choice)
3. Test quests 1-3 (should work with minimal setup)

**Week 2: Core Content**
4. Create False Prophet NPC and dialogue
5. Create High Chronist NPC
6. Implement Quest 4-5 fully

**Week 3: Devotee Content**
7. Create Temporal Guardian enemy
8. Implement Quest 6 (Temporal Echo)
9. Implement Quest 7 (Paradox Stone puzzle)
10. Implement Quest 8

**Week 4: Endgame**
11. Create all boss enemies
12. Implement Quest 9-10
13. Create all legendary items
14. Full chain testing

**Week 5: Polish**
15. Implement repeatable quest
16. Balance tuning
17. Bug fixes
18. Final playtesting

---

## Known Issues / Edge Cases

### Issue 1: Quest Chain Interruption
What if player starts Quest 3, then abandons the chain?
- Solution: Allow quest abandonment for quests 1-4, but NOT for Quest 5+

### Issue 2: Devotion After Other Gods
What if player is already devoted to Gaela or Morthane?
- Solution: Allow multi-devotion, but have Priest acknowledge it in dialogue

### Issue 3: Boss Too Hard
What if Timeless One is impossible for average players?
- Solution: Provide hints about recommended level/equipment in quest description

### Issue 4: Repeatable Quest Spam
What if players try to cheese the repeatable for infinite rep?
- Solution: 7-day cooldown + diminishing returns (rep drops to +1 after 10 completions)

---

## Files Reference

**Quest JSONs:**
- `C:\Users\caleb\CatacombsOfGore\data\quests\temple\chronos\chronos_01_first_vision.json`
- `chronos_02_hourglasses.json` through `chronos_10_eternal_vigil.json`
- `chronos_repeatable_visions.json`

**Documentation:**
- `README.md` - Full design document
- `QUEST_SUMMARY.md` - Quick reference
- `FLOWCHART.txt` - Visual quest flow
- `IMPLEMENTATION_GUIDE.md` - This file

**Future Files to Create:**
- `data/enemies/temporal_guardian.tres`
- `data/enemies/time_aberration.tres`
- `data/enemies/temporal_rift_guardian.tres`
- `data/enemies/corrupted_temporal_guardian.tres`
- `data/enemies/the_timeless_one.tres`
- `data/items/chronos_amulet.tres` (and all other items)
- `data/dialogue/priest_chronos_main.tres` (dialogue trees)

---

**Implementation Status:** Design Complete - Ready for Implementation
**Estimated Development Time:** 4-5 weeks
**Version:** 1.0
**Created:** 2026-04-06
