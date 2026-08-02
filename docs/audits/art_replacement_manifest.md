# Art replacement manifest

The ART RULE (Caleb, 8/1 evening): agents never hand-repair a broken model or
sprite. They route around it — repoint to a working asset, drop a plain
placeholder, or skip the cosmetic part — keep the *code path* correct, and log
the asset here. Caleb replaces art through his own workflow.

Columns: **asset** · **what's wrong** · **where it's used** · **suggested
replacement class**.

| Asset | What's wrong | Where it's used | Suggested replacement |
|---|---|---|---|
| `assets/textures/sky/moon.png` | **Routed around 8/1.** Was missing; every outdoor level logged `Resource file not found` on boot. A 64×64 placeholder now exists: a flat disc in four hard-stepped bands with four maria, no gradient. It is a stand-in, not art | `scripts/world/day_night_cycle.gd`, all outdoor scenes | A real moon at 64×64, PS1 palette, ideally with a phase strip |
| `assets/sprites/enemies/undead/skeleton_warrior.png` | File never existed. King's Watch asked for it at 4×4 and Mosshall Tombs at 8×12 — two different frame counts for one absent sheet, so neither was ever seen. Repointed 8/1 to `skeleton_walking.png` (8×1), the sheet the zoo and dungeon spawner already agree on | `kings_watch.gd`, `mosshall_tombs.gd`, `sunken_crypt.gd` | Nothing needed unless a distinct armoured skeleton is wanted, in which case an 8×1 sheet matching `skeleton_walking.png` |
| `assets/sprites/enemies/undead/vampire_lord_alt.png` | File never existed; the tomb/crypt boss drew nothing. Repointed 8/1 to `vampirelord_walking.png` (5×1). Note the folder holds two unrelated vampire sets at different resolutions — `vampire_lord_*` at 431×96 and `vampirelord_*` at 247×55 | `mosshall_tombs.gd`, `sunken_crypt.gd` | A boss-distinct vampire sheet; also worth collapsing the two vampire sets into one |
| `assets/sprites/legacy/props/monastery/monastary_altar1.png.png` | Saved with a doubled extension. Code asked for the sensible name and got nothing, so the Dalhurst altar drew untextured. Repointed 8/1 to the real doubled name rather than renaming the asset | `dalhurst.gd` | Rename the file to a single `.png` and repoint back |
| `assets/sprites/legacy/enemies/goblins/goblin_warboss_walking.png` | 514×150 — not divisible into whole frames at any sane count, and 514 is not a power of two. `data/enemies/goblin_warboss.tres` already points away from it, at `goblin_sword.png` | Nothing, currently. Skarrag the Devourer spawns in `kazan_dun_level_5.gd` on the generic goblin sprite instead | A boss-scale goblin sheet at 4×1 or 4×4, power-of-two, matching the goblin palette |
| `assets/sprites/legacy/enemies/goblins/goblin_warboss_dying.png` | Same family as above; unreferenced | Nothing | Death row of the sheet above |
| `assets/sprites/legacy/enemies/goblins/goblin_archer_Fixed.png` | Duplicate of `goblin_archer.png` with a hand-fix suffix. The dungeon loot config referenced it at `assets/sprites/goblin_archer_Fixed.png` — the wrong folder — so goblin archers in generated dungeons drew nothing. Repointed 8/1 to `goblin_archer.png`; the `_Fixed` copy is now referenced by nothing at all | Was `scripts/generation/dungeons/dungeon_loot_config.gd`, now nothing | Delete one, or fold the fix into `goblin_archer.png` |
| `assets/world/nature/Cliff_01.obj`, `Cliff_02.obj` | Both name a `Cliff_01.mtl` / `Cliff_02.mtl` that was never shipped alongside them, so the meshes import untextured. Routed around 8/1: the cliff spawner overrides with one shared triplanar material over `impass_rock.png` rather than repairing the .obj | `scripts/generation/wilderness/wilderness_room.gd` (`_create_cliff`), all rocky biomes | Ship the .mtl and its texture, or re-export with the material embedded |
| `assets/textures/environment/floors/leaves_full.png`, `leaves_half.png` | Not broken — moved. Three call sites still pointed at the old `assets/sprites/environment/ground/` path and produced **1,607 boot errors**, by far the loudest thing in the log. Repointed 8/1 | `elder_moor.gd`, `elder_moor.tscn`, `thornfield.gd` | None |
| **Placeholder geometry — `QuestInteractable`** | Not broken; deliberately plain. Every quest object added in steps 14/23 (`kd_thurgans_pyre`, `kd_regents_roll`, `kd_pit_floor_remains`, `kd_gallery_props`, `kd_soulstone_parley`, the Millbrook camp objects) draws an untinted box with a prompt | `scripts/world/interactables/quest_interactable.gd`, Kazan-Dun levels 1/4/5, Millbrook bandit camp | Props: a pyre, a lectern with a roll, a drag-marked pit floor, timber props, a stone stack, a war chest. Swap the mesh in one place and every instance inherits it |

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

### Wave B backlog, stage 4 - hostage placement (grey-box)

Seven hostages are now placed. Their **sprites already exist** and are correct
(`assets/sprites/npcs/civilians/Hostages/`) - what is grey-box is the
*position*: a mark on the floor in the room the quest means, with no cage, no
altar dressing, no rope and no cell around them.

| Hostage | Scene | Placed at | What the room needs |
|---|---|---|---|
| `hostage_merchant_daughter` | `bandit_camp_north` | (-9, 1, 6) | A tied-up mark, a tent or a cart to be held behind |
| `hostage_soldier` | `bandit_camp_south` | (-10, 1, 7) | Same, plus stripped kit on the ground |
| `kidnapped_merchant` | `bandit_hideout_level_1` | (-6, 1.2, -16) | The quest calls it a "hostage cell". There is no cell |
| `hostage_woodsman` | `bandit_hideout_level_2` | (-7, 0, 6) | Boss lair corner |
| `hostage_wizard_apprentice` | `cult_hideout` | (4, 0, -8) | The cultists are draining him - a ritual frame, chalk, candles |
| `hostage_missing_child` | `cultist_temple` | (0, 1, -6) | A locked room |
| `hostage_sacrifice_victim` | `cultist_temple_2` | (0, 0.2, -6) | She is on the stone when you arrive. There is no stone |

## Sound events (8/1 batch 4, filled 8/2)

`AudioManager.EVENTS` names ~117 sounds. 49 real .wav files exist, all of them
one directory below `assets/audio/sfx/` where the table was pointing, so until
batch 4 **no hit, death, menu, item, door or footstep sound had ever played**
and nothing crashed to say so. Batch 4 repointed the loader at the real files
and gave the events with no asset a declared stand-in where an honest one
exists (`AudioManager.EVENT_SUBSTITUTES`). **32 events had no asset and no
honest stand-in and stayed silent.**

**8/2: they were synthesised.** `tools/build/gen_audio.py` writes procedural
placeholders into `assets/audio/generated/` and nowhere else - it cannot reach
a real recording, and the gate
(`tools/check_audio_events.tscn`) fails if a wired variant path leaves that
directory. `AudioManager.MISSING_SFX` is now **empty**.

### THE PLACEHOLDER-CLASS RULE

Everything under `assets/audio/generated/` is **PLACEHOLDER-CLASS**: written by
a synthesiser, PS1-era on purpose (22050 Hz, mono, deliberately crunchy), and
Caleb may replace any of it.

**Replacing one takes no code change.** `resolve_event_path()` checks the
event's *own* asset before it checks `EVENT_VARIANTS`, so dropping a real file
at the path in the `EVENTS` column retires its placeholder the moment it lands.
The wiring survives replacement because the event name never moves.

Regenerate the whole set with `python tools/build/gen_audio.py all` (needs numpy and
ffmpeg). It is deterministic - the same seeds give the same files.

| Event | What it is | Generated placeholder | Variants | What a real one would be |
|---|---|---|---|---|
| `player_attack` | The player's swing through empty air | `sfx/combat/player_attack_*.wav` | 3 | A cloth/steel whoosh |
| `enemy_attack` | A generic enemy swing | `sfx/combat/enemy_attack_*.wav` | 3 | A coarser swing whoosh |
| `miss` | A melee swing that connects with nothing | `sfx/combat/miss_*.wav` | 2 | Same family as `player_attack` |
| `projectile_miss` | An arrow going past | `sfx/combat/projectile_miss_*.wav` | 2 | A passing whoosh with real doppler |
| `enemy_spawn` | An enemy appearing | `sfx/combat/enemy_spawn.wav` | 1 | A low swell, or nothing |
| `player_stagger` | Player staggered by a hit | `sfx/voice/player_hurt_*.wav` | 3 | A recorded grunt plus a stumble |
| `enemy_stagger` | Enemy staggered | `sfx/voice/enemy_hurt_*.wav` | 3 | A recorded grunt |
| `player_death` | The player dying | `sfx/voice/player_death.wav` | 1 | One long human death cry |
| `enemy_death` | A humanoid NPC dying | `sfx/voice/enemy_death_*.wav`, `sfx/voice/death_exhale_*.wav` | 5 | Two or three human death cries |
| `player_heal` | Healing landing on the player | `sfx/ui/player_heal.wav` | 1 | A warm rising chime |
| `player_level_up` | Level threshold crossed | `sfx/ui/player_level_up.wav` | 1 | A short fanfare |
| `quest_fail` | A quest failing | `sfx/ui/quest_fail.wav` | 1 | A falling two-note sting |
| `item_drop` | Dropping an item | `sfx/items/item_drop_*.wav` | 2 | A soft thud |
| `item_equip` / `item_unequip` | Putting gear on and taking it off | `sfx/items/item_equip.wav`, `item_unequip.wav` | 1 each | Leather and buckle |
| `item_break` | Durability reaching zero | `sfx/items/item_break.wav` | 1 | A snap |
| `spell_fail` | A failed cast | `sfx/magic/spell_fail.wav` | 1 | A dead fizzle |
| `spell_impact` | A spell landing | `sfx/magic/spell_impact_*.wav` | 2 | Per school ideally; one generic will do |
| `door_open` / `door_close` | Doors | `sfx/world/door_open_*.wav`, `door_close_*.wav` | 2 each | Wood on stone |
| `door_locked` | A locked door refusing | `sfx/world/door_locked.wav` | 1 | A rattle |
| `door_unlock` | A lock giving | `sfx/world/door_unlock.wav` | 1 | A click and a rattle |
| `lever_pull` | Levers and switches | `sfx/world/lever_pull.wav` | 1 | A ratchet |
| `secret_found` | A hidden chest or secret wall revealing | `sfx/world/secret_found.wav` | 1 | A short reveal sting |
| `trap_trigger` | A trap firing | `sfx/world/trap_trigger.wav` | 1 | A snap and a whoosh |
| `torch_extinguish` | A torch going out | `sfx/world/torch_extinguish.wav` | 1 | A wet snuff |
| `effect_poison`, `effect_burn`, `effect_freeze`, `effect_stun`, `effect_bleed`, `effect_cure` | The six condition applications, and the only feedback that a condition landed | `sfx/effects/effect_*.wav` | 1 each | Six short stingers |
| `footstep_stone`, `footstep_wood`, `footstep_grass`, `footstep_water`, `footstep_metal`, `footstep_dirt` | Footsteps per surface | `sfx/footsteps/footstep_<surface>_*.wav` | 4 each | Recorded steps per material |

Footsteps are the one row here that was not silent: all six surfaces played the
one real generic footstep through `EVENT_SUBSTITUTES`. Those six substitute
lines are gone, replaced by shaped per-material placeholders with four variants
each. **The real file is untouched** and still answers `footstep_generic`.

**Substitutes still standing in** (these do play, and are real recordings, but
they are not the sound the game is asking for): hits, blocks, parries and crits
play the sword clanks; every menu sound, quest notification and save plays the
accept click; `item_pickup` plays a bush rustle and `gold_pickup` a glass
clink; `chest_open` plays blacksmith tongs; `enemy_alert` and `enemy_aggro`
play the monster growls; `projectile_fire` the bow and `projectile_explode` the
musket; `spell_cast` the chant. **These were deliberately left alone** - a real
recording standing in for a neighbouring event beats a synthesised one at the
exact name, and none of them is silent.

### Biome ambience (8/1: no assets at all - synthesised 8/2)

`scripts/world/ambient_soundscape.gd` wanted 7 biomes x day/night x 3 layers =
36 loops under `assets/audio/ambient/`. That directory never existed; the real
one is `assets/audio/Ambiance/` and holds four files (a town murmur, a port
city, a ruins ambience, two arena beds), none of them a biome bed. **Biome
ambience had never made a sound, and the class was instantiated by nothing.**

Both halves are fixed. Fifteen synthesised beds now fill the BASE layer of
eight biomes across day and night, and `AudioManager` owns the one
`AmbientSoundscape` instance, feeding it the player's cell biome from
`PlayerGPS` and the hour from `GameManager`.

All PLACEHOLDER-CLASS. 62-second seamless loops (the last four seconds are
crossfaded over the first, so there is no click at the loop point), Ogg
Vorbis at 40 kbit mono, RMS-matched to -33 dBFS so no biome is louder than
another. Regenerate with `python tools/build/gen_audio.py ambience`.

| Bed | Layers synthesised | What a real one would be |
|---|---|---|
| `ambience/forest_day.ogg` | wind through a slow double LFO, leaf rustle on gusts, sparse randomised birdsong | Field recording, woodland, morning |
| `ambience/forest_night.ogg` | darker wind, crickets, insect stridulation, one distant owl-shaped call | Woodland, night |
| `ambience/road_day.ogg` | open grassland wind, thinner birdsong, day insects | Meadow / open road |
| `ambience/road_night.ogg` | low wind, crickets | Meadow, night |
| `ambience/highlands_day.ogg` | harsher wind with a resonant whistle, almost no birds | Exposed hillside |
| `ambience/highlands_night.ogg` | colder, more whistle | Exposed hillside, night |
| `ambience/swamp_day.ogg` | thick low wind, frog croaks, drips, wet insects | Marsh |
| `ambience/swamp_night.ogg` | more frogs, more drips, dense insects | Marsh, night |
| `ambience/coast_day.ogg` | overlapping wave swells, sea wind, gull-shaped calls | Shingle beach |
| `ambience/coast_night.ogg` | waves and wind, no birds | Beach, night |
| `ambience/desert_day.ogg` | dry high wind, very sparse | Open desert |
| `ambience/desert_night.ogg` | lower wind, cold insects | Desert, night |
| `ambience/winter_day.ogg` | the harshest wind bed, nothing else alive | Snow, open ground |
| `ambience/winter_night.ogg` | harsher again | Snow, night |
| `ambience/caves_drips.ogg` | subsonic room tone and reverbed drips | Cave drips |

The cave bed is the one exception to how these are wired: `Biome.CAVES` keeps
the **real** `Ambiance/ruins/ruins_creepy_ambience.wav` on its BASE layer and
the synthesised drips sit under it as ACCENT_1. A hand-made recording is never
displaced by a generated one.

Still wanted, and not synthesised: the ACCENT and WEATHER layers of every
biome. The layer scheme takes them the moment they exist - one line each in
`SOUNDSCAPES` - and the beds do not sound unfinished without them.

### Dialogue voice blips (new 8/2)

Nobody is voicing this game and nobody should pretend to. What the dialogue
had instead was nothing: text revealed one character at a time in total
silence, in both UIs.

24 synthesised **voice blips** now play under the reveal - the PS1 /
Banjo-Kazooie trick, a short pitched grain with a formant on it, one per six
revealed characters, at -16 dB. They are not speech and are not trying to be.

All PLACEHOLDER-CLASS. Four pitch classes, six variants each, ~3 KB apiece.

| Class | Voice | Archetypes that use it |
|---|---|---|
| `voice/blip_low_*.wav` | deep, sawtooth | guard, blacksmith, miner, beggar |
| `voice/blip_mid_*.wav` | mid, square | generic villager, farmer, merchant, innkeeper, hunter |
| `voice/blip_high_*.wav` | light, triangle | noble, thief, bard - and children, when there are any |
| `voice/blip_solemn_*.wav` | slow sine with a room around it | priest, scholar |

Where they fire: `conversation_ui.gd` and `dialogue_box.gd`, inside the
typewriter loop, gated on `AudioManager.BLIP_EVERY_CHARS`. Whitespace and
punctuation never trigger one, and holding the skip key suppresses them
entirely - at that reveal speed a blip per six characters is a buzz.

An NPC with no `NPCKnowledgeProfile` takes the mid voice, so a speaker with no
profile still sounds like a person rather than falling silent.

A real replacement is not "record voice acting" - it is a better blip set:
more variants per class, and a class per named NPC for the dozen characters
who carry the story.

### Stylised combat vocalisations (new 8/2)

Shipped with the one-shots above, listed here because they are the same
judgement call: `sfx/voice/player_hurt_*.wav` (3), `enemy_hurt_*.wav` (3),
`player_death.wav`, `enemy_death_*.wav` (3) and `death_exhale_*.wav` (2).

Detuned saws through two swept formant bands plus breath noise. **Stylised on
purpose, not attempted realism** - a synthesised human scream that is almost
convincing reads as broken, where an obviously stylised one reads as a
choice. If these are replaced, replace them with real recordings; do not try
to make the synthesis more lifelike.

### Music (new 8/2 - one bed)

| Track | Wired to | What it is |
|---|---|---|
| `music/dark_fantasy_drone.ogg` | `AudioManager.MUSIC["horror"]` | 2:24 loop. Detuned saw pads through a slow lowpass over Dm - Bb - Gm - A, sparse low bells on the chord roots, a breath of air over the top, tape wobble under everything. 56 kbit mono, 860 KB |

PLACEHOLDER-CLASS, like everything under `assets/audio/generated/`. Regenerate
with `python tools/build/gen_audio.py music`.

**It is not the menu music and must not become it.** The main menu already has
a real three-minute medieval-trumpets track and the law is that a real
recording is never displaced. `"horror"` is where the gap actually was:
`cult_hideout.gd` and `dalhurst_cemetery.gd` both ask for it, `MUSIC` had no
such key, and `play_zone_music()` falls through to **wilderness** for anything
it does not recognise - so the two most frightening places in the game were
playing walking music.

Zone music keys still asked for and still absent, all of them falling through
to the wilderness track: `mystic` (`athenaeum`), `boss` and `boss_fight` and
`victory` (`crossroads_ruins`). Zone *ambience* keys still absent, falling
through to the town murmur: `interior`, `dungeon`, `graveyard`. These are left
ungenerated deliberately - a wrong-but-real recording is a smaller lie than a
synthesised boss theme, and a boss theme is composition, not synthesis.

