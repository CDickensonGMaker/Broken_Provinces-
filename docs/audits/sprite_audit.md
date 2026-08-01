# NPC Sprite Audit

Every NPC sprite sheet in the game, measured off the PNG rather than read off a
comment. 55 sheets, 63 registry configurations.

Re-run it after touching any sprite or any `h_frames`:

```
_tools\godot45\Godot_v4.5-stable_win64_console.exe --headless --path . res://tools/check_sprites.tscn
```

## The standard

A billboard sprite's world height is `pixel_size * frame_height`, and until now
nothing checked that. Every call site carried a hand-computed `pixel_size` with
the frame height it assumed written beside it in a comment - which held right up
until an artist handed over a 128px sheet instead of a 96px one, at which point
the same number silently made a man three and a quarter metres tall.

So state the height, measure the frame:

```gdscript
pixel_size = BillboardSprite.humanoid_pixel_size(texture.get_height())
```

| Constant | Value | Meaning |
|---|---|---|
| `HUMANOID_FRAME_HEIGHT_M` | 2.4576 | `0.0256 x 96` - the existing civilian look, not a new decision |
| `DWARF_FRAME_HEIGHT_M` | 1.8528 | `0.0193 x 96` - the existing dwarf look |
| `REFERENCE_FRAME_HEIGHT` | 96 | What every civilian sheet is drawn at |

The drawn figure is shorter than the frame - these sheets carry headroom - so
2.46m of frame reads as a villager about a head above the player's eyeline,
which is how the game has always looked.

## How the sheets were counted

Poses are separated by fully transparent columns. The audit reads per-column
alpha coverage off each PNG and finds the gutters, then cross-checks against
even division of the sheet width. Where the two agree, the count is certain.
Where a sheet has no gutters at all, or its poses are unevenly spaced, it is
listed below as a judgement call rather than guessed at.

## Fixed - certain

| Sprite | Size | Was | Now | What the player saw |
|---|---|---|---|---|
| `civilians/wizard_mage.png` | 277x96 | h=1 | **h=4** | Four wizards smeared into one 7m-wide poster. The documented bug. |
| `dwarves/dwarf_2.png` | 266x96 | h=1 | **h=4** | Same, for every dwarf guard. |
| `dwarves/dwarf_3.png` | 266x96 | h=1 | **h=4** | Same, for warriors, refugees and the wounded. |
| `dwarves/dwarf_molten2.png` | 266x96 | h=1 | **h=4** | Same, for forge workers. |
| `merchants/Innkeeper_man.png` | 240x96 | h=1 | **h=4** | Same, behind the bar. |
| `merchants/magic_shop_worker.png` | 130x96 | h=1 | **h=3** | Same, in the magic shop. |
| `named/spock.png` | 84x96 | h=1 | **h=2** | Both poses at once. |
| `named/thornfield_leader.png` | 139x96 | h=5 | **h=2** | 139 does not divide by 5; frames drifted by 28px, so most of them showed the wrong half of the wrong pose. |
| `data/npcs/aldric_vane.tres` | 48x96 | h=8 | **h=1** | A 6px-wide sliver of a man. |
| `data/npcs/bram_ashford.tres` | 48x96 | h=4 | **h=1** | A 12px sliver. |
| `data/npcs/greta_wolfsbane.tres` | 48x96 | h=4 | **h=1** | A 12px sliver. |
| `data/npcs/elric_thornwood.tres` | 139x96 | h=4 | **h=2** | Wrong halves. |
| `data/npcs/old_yoren.tres` | 142x96 | h=4 | **h=2** | Wrong halves. |
| `data/companions/apprentice_lyris.tres` | 277x96 | h=1 | **h=4** | The wizard smear again, as a companion. |

### Scale

| Who | Sheet | Was | Was standing | Now |
|---|---|---|---|---|
| `blacksmith`, `grom_the_smith` | 498x170 | 0.0256 | **4.35m** | 0.0145 |
| `aldric_vane` | 362x128 | 0.0256 | **3.28m** | 0.0192 |
| `martha_cook` | 392x128 | 0.0256 | **3.28m** | 0.0192 |
| `thornfield_leader`, `millbrook_elder` | 184x127 | 0.0256 | **3.25m** | 0.0194 |
| `elder_vorn_thornfield` | 139x96 | 0.0384 | **3.69m** | 0.0256 |
| `tharin_ironbeard` | 70x70 | 0.0193 | **1.35m** | 0.0265 |
| Innkeeper (both) | 240/266x96 | 0.0234 / 0.0378 | 2.25m / **3.63m** | 0.0256 |
| Arena innkeeper | 266x96 | 0.0378 | **3.63m** | 0.0256 |

The two innkeeper numbers were derived against frame heights of 105px and 65px.
Both sheets are 96px tall. Nobody had ever measured them.

### Broken sprite paths repaired

`aleric_vale.tres`, `blacksmith.tres`, `old_man_sage.tres` and
`tharin_ironbeard.tres` all pointed at `assets/sprites/npcs/<name>.png` when the
file lives in a subfolder. They were loading nothing.

## Left alone - your call, Caleb

| Sprite / entry | The question |
|---|---|
| `dwarves/dwarf_1.png` (h=5) | Five poses, no gutters between them at all. Even division reads clean at 5, so h=5 is probably right, but it cannot be proved off the image. |
| `dwarves/dwarf_2.png` (h=4) | Four poses confirmed, but at 63/62/63/69px - unevenly spaced. h=4 slices at 66.5 and clips a few pixels. Fixing it properly means repacking the sheet. |
| `dwarves/dwarf_molten1.png`, `dwarf_molten3.png` (h=1) | Same 266x96 size as the others, so almost certainly multi-pose, but neither has readable gutters. Left at 1 rather than guessed. |
| `merchants/Innkeeper_woman.png` (h=5) | 266px / 5 = 53.2. No clean gutters. 4 or 5, and only your eye can say. |
| `civilians/lady_in_red.png` (h=8) | Correct at 8, but 386/8 = 48.25 - each frame drifts a quarter pixel, so the last frames clip by about 1px. A 384px-wide sheet would be exact. |
| `gormund_pitmaster` (0.04, 3.84m) | Every other gladiator is 0.0256. A pit boss being half again as big reads deliberate. Confirm or drop it. |
| Companion sizes | On identical 48x96 sheets: `whisper` 1.84m, `red_mara` 2.46m, `sylva_swiftfoot` 2.69m, `sergeant_kira` 2.88m, `theron_the_bold`/`zephyr` 3.07m, `grimjaw` 3.69m. Some of that spread is clearly character; some of it looks like nobody chose. |
| `hostage_little_girl` (0.02, 1.92m) | Shorter than the adults, but not by much for a little girl. |
| `civilians/guard2_civilian.png` | Two content blocks on a 48x96 sheet - one figure with a detached prop, not two poses. h=1 is right; noted so it is not "fixed" later. |

## Registry entries with no art

Eighteen NPC rows point at sprites nobody has drawn. Not errors - planned
content - but they will spawn nothing if referenced:

elves (4): `elf_male_civilian`, `elf_female_civilian`, `elf_guard`, `elf_mage`
sailors (3): `sailor_deckhand`, `sailor_captain`, `pirate_reformed`
tengers (3): `tenger_elder`, `tenger_trader`, `tenger_scout_npc`
workers (4): `miner_npc`, `fisherman_npc`, `lumberjack_npc`, `dockworker_npc`
guild (2): `thieves_guild_master`, `keepers_leader`
other (2): `harbor_master`, `caravan_guard`

## Unreferenced sheets

`civilians/blacksmith.png` (281x96, 5 poses) is a smaller duplicate of
`merchants/blacksmith.png`. `civilians/seductress_civilian.png` (128x128) and
`seductress_civilian_back.png` are unused; the `_Front` variant is the one wired
up. `animals/cat_animiation.png` and `cow_animiation.png` are not in the
registry at all.

## Correction to CLAUDE.md

The NPC SPRITE SPECIFICATIONS section says humanoid sheets are 1x5, 160x64, with
`lady_in_red` at 160x48 and 5 frames. None of that is true of the art on disk.
The real house format is **48x96 per frame**, and the sheets run 1, 2, 3, 4, 5 or
8 poses wide depending on who drew them. `lady_in_red` is 386x96 with 8 poses and
was already correct in code.
