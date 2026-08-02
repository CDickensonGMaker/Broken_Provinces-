# Sprite Reference - Catacombs of Gore

This document lists all character sprites used in the game with their paths, frame configurations, and pixel sizes.

---

## NPCs (Friendly/Neutral)

### Named NPCs
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Martha Cook | `res://assets/sprites/legacy/npcs/martha_cook.png` | 4 | 1 | 0.0384 | Elder Moor cook |
| Tharin Ironbeard | `res://assets/sprites/legacy/npcs/tharin_ironbeard.png` | 5 | 1 | 0.0384 | Dwarf quest giver |
| Old Man Sage | `res://assets/sprites/legacy/npcs/old_man_sage.png` | 5 | 1 | 0.0384 | Sage NPC |
| Blacksmith | `res://assets/sprites/legacy/npcs/blacksmith.png` | 5 | 1 | 0.0384 | Town blacksmith |
| Thornfield Leader | `res://assets/sprites/legacy/npcs/thornfield_leader.png` | 5 | 1 | 0.0384 | Thornfield town leader |
| Aleric Vale | `res://assets/sprites/legacy/npcs/aleric_vale.png` | 5 | 1 | 0.0384 | Named NPC |
| Wizard | `res://assets/sprites/legacy/npcs/wizard.png` | 5 | 1 | 0.0134 | Magic shop owner |
| Spock (Lost Logician) | `res://assets/sprites/legacy/npcs/lost_logician.png` | 5 | 1 | 0.0384 | Easter egg |
| Conan Easter Egg | `res://assets/sprites/legacy/npcs/conan_easter_egg.png` | 5 | 1 | 0.0384 | Easter egg |

### Rows removed 2026-08-02

Every row naming `res://Sprite folders grab bag/` has been deleted from this
document, because the directory has been deleted from the project.

The table that stood here listed twenty-odd sprites under
`res://Sprite folders grab bag/`. That directory was deleted on 2026-08-02 and
the table was already fiction before that: not one of the filenames it named
existed in the folder, and the union of all fifty-two uids the folder actually
held greped to zero hits across the whole project. Nothing referenced any of
it. See `docs/design/PROJECT_LAYOUT.md`.

Generic civilian sprites in use live under `assets/sprites/legacy/npcs/`, and
`tools/check_sprites.tscn` measures them rather than trusting a table.

## Enemies

### Humanoid Enemies
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Human Bandit | `res://assets/sprites/legacy/enemies/human_bandit.png` | 3 | 4 | 0.0384 | Main bandit sprite |

### Undead
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Skeleton Shade | `res://assets/sprites/legacy/enemies/skeleton_shade.png` | 4 | 4 | 0.0384 | Common skeleton |
| Vampire Lord | `res://assets/sprites/legacy/enemies/vampire_lord.png` | 4 | 4 | 0.0384 | Boss enemy |

### Goblins
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Goblin Leader | `res://assets/sprites/legacy/enemies/goblin_leader.png` | 4 | 4 | 0.0384 | Elite goblin |
| Goblin Archer | `res://assets/sprites/legacy/enemies/goblin_archer.png` | 4 | 4 | 0.0384 | Ranged goblin |
| Goblin Warboss | `res://assets/sprites/legacy/enemies/goblin_warboss.png` | 4 | 4 | 0.0384 | Boss goblin |

### Beasts
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Wolf | `res://assets/sprites/legacy/enemies/wolf.png` | 4 | 4 | 0.0384 | Common wolf |

### Large/Boss Enemies
| Name | Path | H-Frames | V-Frames | Pixel Size | Notes |
|------|------|----------|----------|------------|-------|
| Ogre Monster | `res://assets/sprites/legacy/enemies/ogre_monster.png` | 4 | 4 | 0.0384 | Large humanoid |
| Tree Ent | `res://assets/sprites/legacy/enemies/tree_ent.png` | 4 | 4 | 0.0384 | Forest boss |
| Abomination | `res://assets/sprites/legacy/abomination.png` | 4 | 4 | 0.0384 | Horror enemy |

### Dark General (Multi-sprite Boss)
| Animation | Path | H-Frames | V-Frames | Notes |
|-----------|------|----------|----------|-------|
| Idle | `res://assets/sprites/legacy/enemies/dark_general_idle.png` | ? | ? | Standing |
| Attack | `res://assets/sprites/legacy/enemies/dark_general_attack.png` | ? | ? | Attack anim |
| Death | `res://assets/sprites/legacy/enemies/dark_general_death.png` | ? | ? | Death anim |

---

## Environment Sprites

### Trees
| Name | Path | Notes |
|------|------|-------|
| Green Tree 1 | `res://assets/sprites/legacy/environment/trees/green_tree1.png` | Forest tree |
| Green Tree 2 | `res://assets/sprites/legacy/environment/trees/green_tree2.png` | Forest tree |
| Green Tree 3 | `res://assets/sprites/legacy/environment/trees/green_tree3.png` | Forest tree |
| Green Sap Tree 1 | `res://assets/sprites/legacy/environment/trees/green_sap_tree1.png` | Harvestable |
| Green Sap Tree 2 | `res://assets/sprites/legacy/environment/trees/green_sap_tree2.png` | Harvestable |
| Chopped Tree | `res://assets/sprites/legacy/environment/trees/chopped_tree.png` | Stump |
| Swamp Willow | `res://assets/sprites/legacy/environment/trees/swamp_willow.png` | Swamp tree |

### Ground Textures
| Name | Path | Notes |
|------|------|-------|

### Dungeon Textures
| Name | Path | Notes |
|------|------|-------|

### Props/Decorations
| Name | Path | Notes |
|------|------|-------|
| Torch Animated | `res://assets/sprites/legacy/props/torch_animated.png` | Flickering torch (ACTIVE) |
| Sword Statue 1-3 | `res://assets/sprites/legacy/decorations/sword_statueX.png` | Statues |

### Shop Signs
| Name | Path |
|------|------|

---

## World Objects

| Name | Path | Notes |
|------|------|-------|
| Rock | `res://assets/sprites/legacy/world/rock.png` | Harvestable |
| Iron Vein | `res://assets/sprites/legacy/world/iron_vein.png` | Mining node |
| Silver Vein | `res://assets/sprites/legacy/world/silver_vein.png` | Mining node |
| Gold Vein | `res://assets/sprites/legacy/world/gold_vein.png` | Mining node |
| Crashed Ship | `res://assets/sprites/legacy/world/crashed_ship.png` | Easter egg |
| Blue Flower | `res://assets/sprites/legacy/items/blue_flower.png` | Harvestable |

---

## Standard Frame Configurations

### NPCs (1x5 Layout - Standard)
```
[Fr1][Fr2][Fr3][Fr4][Fr5]
  5 frames, 1 row
  h_frames = 5, v_frames = 1
```

### Enemies (4x4 or 3x4 Layout - Directional)
```
4x4 Layout:
[Idle1][Idle2][Idle3][Idle4]  <- Row 0: Idle/South
[Walk1][Walk2][Walk3][Walk4]  <- Row 1: Walk/West
[Atk1 ][Atk2 ][Atk3 ][Atk4 ]  <- Row 2: Attack/North
[Hurt1][Hurt2][Die1 ][Die2 ]  <- Row 3: Hurt+Death/East

h_frames = 4, v_frames = 4

3x4 Layout:
h_frames = 3, v_frames = 4
```

### Standard Pixel Sizes
| NPC Type | pixel_size |
|----------|-----------|
| Standard Humanoid | 0.0384 |
| Man Civilian | 0.0518 |
| Wizard/Small | 0.0134 |
| Barmaid | 0.0326 |
| Lady in Red | 0.0182 |
| Merchant (single) | 0.0115 |

---

## TODO: Missing Sprite Info
Many sprites from "Sprite folders grab bag" need their frame counts documented.
Open each file to determine h_frames and v_frames, then update this document.
