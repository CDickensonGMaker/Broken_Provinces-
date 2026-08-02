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

### Wave B backlog residents (stage 2, 30 people)

Thirty named residents were added to Dalhurst, Mill Brook, Elder Moor,
Thornfield, Larton, Whaler's Abyss and the Willow Dale ruins, all drawn on the
same default quest-giver sheet. Nothing here is broken art - it is *absent* art,
and it is the largest single block of look-alike NPCs in the game. Priest,
beggar, shepherd, herbwife, clerk, sergeant and magistrate all read as the same
townsman today.

Highest-value sheets, in order: **a market/merchant sheet**, **a priest or
robed sheet**, **a labourer sheet** (shepherd, fisherman, carter, stallhand),
**an officer sheet** (two watch-captains and a sergeant), **an old-woman sheet**
(three widows and a goodwife).

| NPC id | Character | Currently drawn as |
|---|---|---|
| `dalhurst_merchant` | Corvin Ashford, market merchant | Default quest-giver sprite (8x2) |
| `dalhurst_scholar` | Lector Ysolde Bramwell, Athenaeum reading room | Default quest-giver sprite (8x2) |
| `dalhurst_witness` | Padraig, beggar in a doorway | Default quest-giver sprite (8x2) |
| `old_fisherman_dalhurst` | Old Ketch Dougal, Dalhurst quays | Default quest-giver sprite (8x2) |
| `widow_dalhurst` | Nerys Corrin, the ghost widow | Default quest-giver sprite (8x2) |
| `iron_company_veteran` | Sergeant Baird Holt, Iron Company | Default quest-giver sprite (8x2) |
| `guild_witness` | Kerenza Doyle, Adventurers Guild rank-and-file | Default quest-giver sprite (8x2) |
| `inside_contact` | Ivo Renn, clerk and Guild plant | Default quest-giver sprite (8x2) |
| `informant_crossroads` | Quillan the Ferret, informant | Default quest-giver sprite (8x2) |
| `millbrook_merchant` | Greta Vance, stallholder | Default quest-giver sprite (8x2) |
| `millbrook_witness` | Colm the Stallhand | Default quest-giver sprite (8x2) |
| `millbrook_priest` | Sister Rowena Ash, Gaela shrine | Default quest-giver sprite (8x2) |
| `millbrook_healer` | Sorcha Linn, herbwife | Default quest-giver sprite (8x2) |
| `millbrook_shepherd` | Tavish Moor, shepherd | Default quest-giver sprite (8x2) |
| `millbrook_innkeeper` | Hamish Roke, innkeep | Default quest-giver sprite (8x2) |
| `head_fisherman_millbrook` | Eamon Quist, head fisherman | Default quest-giver sprite (8x2) |
| `guard_captain_millbrook` | Watch-Captain Ingram Vell | Default quest-giver sprite (8x2) |
| `millbrook_widow` | Widow Hild Marrow | Default quest-giver sprite (8x2) |
| `millbrook_mother` | Goodwife Anwen Fell | Default quest-giver sprite (8x2) |
| `elder_moor_guard` | Watch-Captain Osbert Dunmoor | Default quest-giver sprite (8x2) |
| `elder_moor_old_woman` | Goodwife Hester Crow | Default quest-giver sprite (8x2) |
| `elder_moor_woodsmans_wife` | Bridget Hale | Default quest-giver sprite (8x2) |
| `thornfield_wizard` | Master Lavinia Wyke, Arcane Circle | Default quest-giver sprite (8x2) |
| `thornfield_innkeeper` | Godfrey Larke, innkeep | Default quest-giver sprite (8x2) |
| `thornfield_healer` | Nuala Birch, healer | Default quest-giver sprite (8x2) |
| `thornfield_farmer` | Struan Ryke, farmer | Default quest-giver sprite (8x2) |
| `trade_master_larton` | Trade Master Petra Halloran | Default quest-giver sprite (8x2) |
| `imperial_magistrate` | Magistrate Uther Craine | Default quest-giver sprite (8x2) |
| `whaelers_abyss_mayor` | Mayor Ysolde Kerr | Default quest-giver sprite (8x2) |
| `caravan_survivor` | Yoren the Carter, Willow Dale survivor | Default quest-giver sprite (8x2) |

### Wave B backlog, stage 3 (20 more, three of them badly wrong)

Same default sheet. Three of these are not human and read as townsfolk, which is
the worst of it:

* **Khan Toghrul** is an eight-foot bear-man on a huge horse per the bible, and
  currently looks like a Dalhurst shopkeeper standing in a desert camp.
* **Gurm the bridge troll** is a troll who talks, drawn as a man.
* **The Drowned Man** is a ghost the player finds in Dalhurst at night, drawn
  with no transparency, no tint and no glow.

| NPC id | Character | Currently drawn as |
|---|---|---|
| `merchant_talbot` | Talbot Ashe, escorted caravan merchant | Default quest-giver sprite (8x2) |
| `noble_hakon` | Lord Hakon Greyfell | Default quest-giver sprite (8x2) |
| `noble_client` | Lady Venetia Harrow | Default quest-giver sprite (8x2) |
| `enemy_commander` | Commander Roderic Brackmoor | Default quest-giver sprite (8x2) |
| `guild_traitor_adventurers` | Officer Malcolm Rede | Default quest-giver sprite (8x2) |
| `guild_traitor_thieves` | Sable Quint | Default quest-giver sprite (8x2) |
| `iron_company_traitor` | Corporal Nils Hark | Default quest-giver sprite (8x2) |
| `iron_blades_leader` | Captain Dane Ferrow, Iron Blades | Default quest-giver sprite (8x2) |
| `black_wolf_captain` | Captain Vashka Kolt, Black Wolves | Default quest-giver sprite (8x2) |
| `sailor_brennan` | Brennan Locke | Default quest-giver sprite (8x2) |
| `restless_ghost` | The Drowned Man - a GHOST drawn as a living townsman | Default quest-giver sprite (8x2) |
| `merchant_vrell` | Dorn Vrell | Default quest-giver sprite (8x2) |
| `false_prophet_millbrook` | Brother Wendel Pyke | Default quest-giver sprite (8x2) |
| `false_seer_thornfield` | Seer Ambrose Tine | Default quest-giver sprite (8x2) |
| `high_chronist_thornfield` | High Chronist Cassian Mere | Default quest-giver sprite (8x2) |
| `bridge_troll` | Gurm - a TROLL drawn as a human townsman | Default quest-giver sprite (8x2) |
| `tomas_informant` | Tomas Redd | Default quest-giver sprite (8x2) |
| `necromancer_valdris` | Valdris the necromancer | Default quest-giver sprite (8x2) |
| `dying_merchant_ilsabet` | Ilsabet Corr, dying merchant | Default quest-giver sprite (8x2) |
| `khan_toghrul` | Khan Toghrul - an eight-foot BEAR-MAN drawn as a human townsman | Default quest-giver sprite (8x2) |
