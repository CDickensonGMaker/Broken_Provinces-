# Art replacement manifest

The ART RULE (Caleb, 8/1 evening): agents never hand-repair a broken model or
sprite. They route around it — repoint to a working asset, drop a plain
placeholder, or skip the cosmetic part — keep the *code path* correct, and log
the asset here. Caleb replaces art through his own workflow.

Columns: **asset** · **what's wrong** · **where it's used** · **suggested
replacement class**.

| Asset | What's wrong | Where it's used | Suggested replacement |
|---|---|---|---|
| `assets/textures/sky/moon.png` | File does not exist. Every outdoor level logs `Resource file not found` on boot (reproduced booting `millbrook.tscn` and `kazan_dun_entrance.tscn` headless) | Sky/day-night material, all outdoor scenes | A 64×64 moon disc on transparent black, PS1 palette |
| `assets/sprites/enemies/goblins/goblin_warboss_walking.png` | 514×150 — not divisible into whole frames at any sane count, and 514 is not a power of two. `data/enemies/goblin_warboss.tres` already points away from it, at `goblin_sword.png` | Nothing, currently. Skarrag the Devourer spawns in `kazan_dun_level_5.gd` on the generic goblin sprite instead | A boss-scale goblin sheet at 4×1 or 4×4, power-of-two, matching the goblin palette |
| `assets/sprites/enemies/goblins/goblin_warboss_dying.png` | Same family as above; unreferenced | Nothing | Death row of the sheet above |
| `assets/sprites/enemies/goblins/goblin_archer_Fixed.png` | Duplicate of `goblin_archer.png` with a hand-fix suffix; nothing references it, so which one is correct is unknowable from the repo | Nothing | Delete one, or fold the fix into `goblin_archer.png` |
| **Placeholder geometry — `QuestInteractable`** | Not broken; deliberately plain. Every quest object added in steps 14/23 (`kd_thurgans_pyre`, `kd_regents_roll`, `kd_pit_floor_remains`, `kd_gallery_props`, `kd_soulstone_parley`, the Millbrook camp objects) draws an untinted box with a prompt | `scripts/world/quest_interactable.gd`, Kazan-Dun levels 1/4/5, Millbrook bandit camp | Props: a pyre, a lectern with a roll, a drag-marked pit floor, timber props, a stone stack, a war chest. Swap the mesh in one place and every instance inherits it |

## Sprite reuse for new NPCs (replacement candidates)

New NPCs reuse the existing default `QuestGiver` sprite rather than getting art
of their own. They read as generic townsfolk today and are the first candidates
for real portraits/sheets:

| NPC id | Character | Currently drawn as |
|---|---|---|
| `dwarf_regent` | Regent Morgrim Ironvein | Default quest-giver sprite (8×2) |
| `dwarf_thane_challenger` | Thane Vurka Stonebrand | Default quest-giver sprite (8×2) |
| `dwarf_loremaster` | Loremaster Dwalki Runeglass | Default quest-giver sprite (8×2) |
| `millbrook_bandit_chief` | Chief Corla Vane of the Millbrook crew | Default quest-giver sprite (8×2) |
| `millbrook_bandit_quartermaster` | Quartermaster Pell | Default quest-giver sprite (8×2) |

All five are dwarves or bandits standing in a hall or a camp; none of them read
as such at a glance. A dwarf sheet and a bandit sheet would cover the lot.
