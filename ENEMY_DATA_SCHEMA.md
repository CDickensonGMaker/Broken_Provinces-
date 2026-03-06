# Enemy Data Schema Reference

**Purpose:** Complete field documentation for .tres EnemyData resource files

**Location:** C:\Users\caleb\CatacombsOfGore\data\enemies\

**Schema Version:** 1.0 (GDScript class: EnemyData)

---

## REQUIRED FIELDS (Must have for enemy to function)

### Identity
```tres
id = "unique_identifier"              # Must be unique, no spaces (e.g., "human_bandit")
display_name = "Display Name"          # For UI display
description = "Long description"       # For Codex/journal
```

### Stats
```tres
level = 5                               # Base enemy level (1-100)
min_level = 3                           # Minimum level scaling
max_level = 15                          # Maximum level scaling
max_hp = 40                             # Hit points at base level
armor_value = 10                        # Defense rating
movement_speed = 4.0                    # Walk speed (units/sec)
turn_speed = 5.0                        # Rotation speed
```

### Attributes (for scaling damage/skills)
```tres
grit = 5                                # Strength stat (affects melee damage)
agility = 5                             # Dexterity stat (affects ranged, dodge)
will = 4                                # Willpower stat (mental resistance)
knowledge = 3                           # Intelligence stat (unused, reserved)
```

### Combat Configuration
```tres
behavior = 0                            # Behavior type (enum BehaviorMode)
faction = 6                             # Faction ID (affects hostility, loot type)
aggro_range = 14.0                      # How far to detect player
attack_range = 2.2                      # Melee attack range
preferred_distance = 2.0                # Preferred combat distance
flee_hp_threshold = 0.2                 # Flee when HP below 20%
is_boss = false                         # Whether this is a boss encounter
```

### Attacks
```tres
attacks = Array[ExtResource("2")]([SubResource("1"), SubResource("2")])
                                        # Array of EnemyAttackData resources
can_block = true                        # Can block incoming damage
block_chance = 0.25                     # Probability of blocking
```

### Resistances (0.0 = normal, >0 = resistant, <0 = weak)
```tres
stagger_resistance = 0.1                # Resistance to being knocked down
fire_resistance = 0.0
frost_resistance = 0.0
lightning_resistance = 0.0
poison_resistance = 0.0
necrotic_resistance = 0.0
physical_resistance = 0.1
fire_weakness = 0.0
frost_weakness = 0.0
lightning_weakness = 0.0
holy_weakness = 0.0
```

### Loot Configuration
```tres
loot_table_av = 3                       # Armor value for loot tables
gold_drop = Array[int]([25, 80])        # [min, max] gold to drop
drop_table = {                          # Dictionary of item_id: probability
  "health_potion": 0.2,
  "lockpick": 0.15,
  "repair_kit": 0.1
}
xp_reward = 75                          # XP given for kill
```

### Sprites (REQUIRED for rendering)
```tres
sprite_path = "res://assets/sprites/enemies/human_bandit.png"
                                        # Path to sprite texture
sprite_hframes = 4                      # Horizontal frame count
sprite_vframes = 2                      # Vertical frame count
sprite_pixel_size = 0.025               # World scale of sprite
attack_sprite_path = ""                 # Optional separate attack sprite
attack_hframes = 4
attack_vframes = 2
```

### Audio (Optional)
```tres
idle_sounds = Array[String]([])         # Idle ambient sounds
attack_sounds = Array[String]([])       # Attack sounds
hurt_sounds = Array[String]([])         # Damage sounds
death_sounds = Array[String]([])        # Death sounds
```

### Special Properties
```tres
scale = 1.0                             # Size multiplier
icon_path = "res://assets/sprites/enemies/human_bandit.png"
                                        # Codex/UI icon (recommended)
scene_path = ""                         # Hand-crafted scene (empty for procedural)
causes_horror = false                   # Triggers horror checks
horror_difficulty = 10                  # DC for horror checks
```

---

## FIELD DESCRIPTIONS

### id (String)
Unique identifier for this enemy type. Used in:
- Drop tables
- Quest objectives
- Encounter definitions
- World Lexicon

**Rules:**
- Must be lowercase with underscores (snake_case)
- No spaces or special characters
- Examples: "human_bandit", "giant_rat", "vampire_lord"

### level (int)
Base level of the enemy. Used for:
- Stat scaling calculations
- XP reward calculations
- Loot tier determination

**Range:** 1-100
**Scaling Formula:** `effective_level = base_level + zone_danger * 2`

### attacks (Array[EnemyAttackData])
Array of attack definitions. Each defines:
- Damage (dice roll: [count, sides, bonus])
- Cooldown and animation timing
- Range, AoE radius, projectile data
- Conditions (poison, stagger, knockback)

**Minimum:** 1 attack required
**Maximum:** Typically 2-3 for regular enemies, 3-5 for bosses

### faction (Enum)
Controls:
- Enemy hostility toward other factions
- Loot type (humanoid gets weapons/gold, creatures get materials)
- Quest reputation changes

**Valid Values:**
- 0 = NEUTRAL
- 1 = GOBLINOID
- 2 = UNDEAD
- 3 = TENGER
- 4 = HUMAN_BANDIT
- 5 = BEAST
- 6 = PIRATE

**Humanoid Factions (carry weapons/gold):** 3, 4, 6
**Creature Factions (drop materials):** 1, 2, 5

### sprite_path (String)
**CRITICAL: Must exist and point to valid image file**

Path to sprite texture. Location examples:
- `res://assets/sprites/enemies/beasts/wolf.png`
- `res://assets/sprites/enemies/humanoid/human_bandit.png`
- `res://assets/sprites/enemies/goblins/goblin_soldier.png`

**Required for:** Visual rendering (without this, enemy is invisible)

### sprite_hframes, sprite_vframes (int)
Number of animation frames in the sprite sheet.

**Examples:**
- Single static frame: h=1, v=1
- Idle animation (4 poses): h=4, v=1
- Multiple animation rows: h=4, v=2

**Critical:** Must match actual sprite dimensions!
- If sprite is 160x64 and has 4 frames horizontally: h_frames = 4
- If sprite is 160x128 with 2 rows: v_frames = 2

### sprite_pixel_size (float)
Controls enemy size in 3D world.

**Typical Values:**
- 0.004 - Very small (insects, rats)
- 0.025 - Small creatures (goblins)
- 0.03 - Medium enemies (humanoids, wolves)
- 0.05 - Large creatures (ogres, bosses)

**Calculation:** `world_height = texture_height_pixels * sprite_pixel_size`
- Example: 64px sprite * 0.03 = 1.92m tall

### gold_drop (Array[int])
```tres
gold_drop = Array[int]([min, max])
```

Defines gold dropped as loot. Array must have exactly 2 values:
- Index 0: Minimum gold
- Index 1: Maximum gold

**Actual amount dropped:** Random between min and max
**Example:** `[25, 80]` drops 25-80 gold per kill

**Guidelines by level:**
- Level 1-5: [10, 30]
- Level 6-15: [25, 80]
- Level 16-25: [50, 200]
- Level 26+: [100, 400]

### drop_table (Dictionary)
```tres
drop_table = {
  "item_id": probability,
  "health_potion": 0.2,
  "lockpick": 0.15
}
```

Defines items dropped as loot.

**Probability Values:**
- 0.0-1.0 = chance per kill (0.2 = 20% chance)
- Probabilities are independent (not weighted)

**Humanoid Example (bandits, cultists):**
```tres
drop_table = {
  "health_potion": 0.2,
  "lockpick": 0.15,
  "repair_kit": 0.1
}
```

**Creature Example (wolves, rats):**
```tres
drop_table = {
  "wolf_pelt": 0.5,
  "wolf_fang": 0.3,
  "raw_meat": 0.4
}
```

### causes_horror (bool)
If true, player must make a horror check when encountering this enemy.

**Used for:** Undead, demons, abominations
**Check difficulty:** Set via `horror_difficulty` field

**Example (Vampire Lord):**
```tres
causes_horror = true
horror_difficulty = 18
```

Player rolls d10 + Will + Bravery against DC 18.

### guaranteed_drops (Array[String])
Items that are always dropped (100% chance).

**Use carefully:** Usually empty for combat balance

**Example:**
```tres
guaranteed_drops = Array[String](["boss_ring"])
```

---

## FIELD GROUPS (by category)

### Performance Optimization
- `level` - For LOD decisions
- `movement_speed` - Affects update frequency
- `aggro_range` - Culling distance

### Balance Tuning
- `max_hp`, `armor_value` - Survivability
- `grit`, `agility` - Damage output
- `attacks` - Combat pattern
- `flee_hp_threshold` - Difficulty perception

### Loot Economy
- `gold_drop` - Player gold income
- `drop_table` - Item availability
- `loot_table_av` - Tier selection
- `xp_reward` - Progression pacing

### Visual/Audio
- `sprite_path`, `sprite_hframes`, `sprite_vframes` - Rendering
- `scale` - Size adjustment
- `idle_sounds`, `attack_sounds`, etc. - Audio feedback
- `icon_path` - Codex display

---

## COMMON MISTAKES

### ❌ Missing sprite_path
```tres
# BAD - No sprite_path
id = "bandit"
display_name = "Bandit"
max_hp = 50

# GOOD - Has sprite_path
sprite_path = "res://assets/sprites/enemies/human_bandit.png"
sprite_hframes = 4
sprite_vframes = 1
```

### ❌ Wrong gold_drop format
```tres
# BAD - String instead of int array
gold_drop = "25-80"

# BAD - Array with 3 values
gold_drop = Array[int]([25, 50, 80])

# GOOD - Int array with exactly 2 values
gold_drop = Array[int]([25, 80])
```

### ❌ Missing required fields
```tres
# BAD - Missing level, max_hp, attacks
id = "enemy"
display_name = "Enemy"

# GOOD - All required fields present
id = "enemy"
level = 5
max_hp = 50
attacks = Array[ExtResource("2")]([SubResource("1")])
```

### ❌ Mismatched frame counts
```tres
# BAD - Sprite has 4 frames but code says 1
sprite_path = "res://assets/sprites/enemies/wolf.png"  # Actually 4 frames
sprite_hframes = 1
sprite_vframes = 1

# GOOD - Matches actual sprite
sprite_path = "res://assets/sprites/enemies/wolf.png"
sprite_hframes = 4
sprite_vframes = 1
```

### ❌ Unscaled sprite_pixel_size
```tres
# BAD - Sprite will be microscopic
sprite_pixel_size = 0.001

# BAD - Sprite will be giant
sprite_pixel_size = 0.5

# GOOD - Scaled to reasonable size
sprite_pixel_size = 0.03
```

---

## AUDIT CHECKLIST

When reviewing an enemy .tres file, verify:

- [ ] `id` field exists and is unique (no spaces)
- [ ] `display_name` and `description` are filled
- [ ] `level`, `min_level`, `max_level` are set
- [ ] `max_hp` is appropriate for level
- [ ] `attacks` array has at least 1 attack
- [ ] `sprite_path` exists and points to valid file
- [ ] `sprite_hframes` and `sprite_vframes` match actual sprite dimensions
- [ ] `sprite_pixel_size` makes enemy visible size (0.01-0.05 range)
- [ ] `faction` is set to valid value (0-6)
- [ ] `gold_drop` is Array[int] with exactly 2 values
- [ ] `drop_table` uses correct syntax (Dictionary with string keys, float values)
- [ ] `stagger_resistance` is 0-1 range (not negative)
- [ ] `is_boss` flag is true for bosses only
- [ ] `icon_path` is set for UI display (optional but recommended)
- [ ] No typos in field names

---

## EXAMPLE: Complete Enemy Definition

```tres
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/enemy_data.gd" id="1"]
[ext_resource type="Script" path="res://scripts/data/enemy_attack_data.gd" id="2"]

[sub_resource type="Resource" id="1"]
script = ExtResource("2")
id = "example_attack"
display_name = "Example Attack"
damage = Array[int]([2, 6, 2])
damage_type = 0
cooldown = 1.5
range_distance = 2.0
stagger_power = 0.5
weight = 1.0

[resource]
script = ExtResource("1")
id = "example_enemy"
display_name = "Example Enemy"
description = "An example enemy for documentation"
level = 5
min_level = 3
max_level = 15
max_hp = 45
armor_value = 8
movement_speed = 4.0
turn_speed = 5.0
grit = 5
agility = 5
will = 4
knowledge = 2
behavior = 0
faction = 4
aggro_range = 14.0
attack_range = 2.2
preferred_distance = 2.0
flee_hp_threshold = 0.2
is_boss = false
attacks = Array[ExtResource("2")]([SubResource("1")])
can_block = false
block_chance = 0.2
stagger_resistance = 0.1
fire_resistance = 0.0
frost_resistance = 0.0
lightning_resistance = 0.0
poison_resistance = 0.0
necrotic_resistance = 0.0
physical_resistance = 0.1
fire_weakness = 0.0
frost_weakness = 0.0
lightning_weakness = 0.0
holy_weakness = 0.0
causes_horror = false
horror_difficulty = 10
loot_table_av = 3
gold_drop = Array[int]([25, 80])
guaranteed_drops = Array[String]([])
drop_table = {
  "health_potion": 0.2,
  "lockpick": 0.15,
  "repair_kit": 0.1
}
xp_reward = 75
scene_path = ""
icon_path = "res://assets/sprites/enemies/example.png"
scale = 1.0
sprite_path = "res://assets/sprites/enemies/example.png"
attack_sprite_path = ""
sprite_hframes = 4
sprite_vframes = 1
attack_hframes = 4
attack_vframes = 1
sprite_pixel_size = 0.03
idle_sounds = Array[String]([])
attack_sounds = Array[String]([])
hurt_sounds = Array[String]([])
death_sounds = Array[String]([])
```

---

*For more information, see enemy_data.gd in scripts/data/*
