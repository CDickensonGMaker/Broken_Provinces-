# Broken Provinces — Master Art Guide & Tracker
*2026-08-02, Wyrm, from a full inventory of the repo + manifests. This is THE tracking doc for all art production — check items off as they land, and keep it honest: an unchecked box is a fact, not a failure. Companion docs: `docs/audits/art_replacement_manifest.md` (broken/routed assets), `docs/audits/sprite_audit.md` (measured spec reality).*

## THE SPEC (every new sheet follows this — non-negotiable)
- **Frame: 48×96 px** (the house format — CLAUDE.md's old 32×64 table is dead). Larger characters scale the FRAME (e.g. 64×128 ogre-class, 96×160 Khan-class) but keep the ratio discipline.
- **Poses left-to-right with a fully transparent gutter column between each** — `check_sprites.tscn` finds poses by alpha gutters and cross-checks even division. Sheet width MUST divide evenly by pose count. (The unfixable sheets — dwarf_1, lady_in_red — are the ones that broke this.)
- **Pose counts:** minimum 2 (idle sway), standard **5** (idle/walk cycle), combat NPCs add attack/hurt rows as separate sheets (the guard front/back/attack convention).
- Scale is DERIVED in code (`BillboardSprite.humanoid_pixel_size(frame_height)`, anchor 2.4576 m @ 96 px; dwarves 1.8528 m) — never hand-pick pixel_size again.
- PS1 palette discipline: limited hand-picked palette per race (see Randomizer §), nearest-neighbor, no anti-aliasing.

## THE PIPELINE (build once, feeds every wave)
**Port RECON's dormant sprite pipeline — it's complete and character-grade, retained on disk after ADR-001:**
`RECONgame\tools\unit_registry.py` (unit→rig/mesh/actions table) → `build_sprite_stage.py` (stage .blend with SpriteRig+SpriteCam) → `render_sprite_sheets.py` (batch: 8 dirs × every action, EEVEE ortho, transparent, frame cache, **metadata sidecar: ground_row + m_per_px + fps/loop**) → `assemble_sheets.py` (24-color palette quantize, strips + JSON manifest).
CoG adaptation: 1 direction (billboards) or 2 (front/back for guards), 48×96 output, per-race palettes, and the metadata sidecar kills the pixel_size guesswork forever. CoG's own `dev\tools\sprite_sheet_generator.gd` is a prop-swinger — ignore it for characters.

## THE RANDOMIZER (design ratified from RECON's grunt_dresser)
RECON's four laws, ported to the Blender side of the sprite pipeline:
1. **Face+skin are the same pixels** — head/neck/hands UV'd into ONE atlas cell sharing ONE material; slide `uv1_offset` and they move together (mismatched skin becomes impossible). `merge_face_skin_material.py` is the enforcing step.
2. **Match materials by texture identity, not name** (names drift; the 7/29 black-head bug).
3. **Duplicate the material per instance** or every villager rerolls the same face ("a fireteam of octuplets").
4. **Capability gating that WARNS when it degrades** — a variant that can't apply says so by name, once.
CoG build: PSX humanoid master + face/skin atlas (10×7 grid) + garb variants (mesh visibility toggles: hood, apron, pack, hat — the "helmet" pattern with the stock item as placement datum) + per-race palette swap → batch-render through the pipeline → dozens of distinct 48×96 townsfolk per master. Deterministic per-npc_id seed (RECON: `name.hash()` — same man, same face, every session).
**Build order: pipeline first, randomizer second, THEN the human wave** — hand-drawing 55 townsfolk without it is the trap.

## RIG RECIPES PER RACE (the dwarf/goblin worry, answered)
- **Dwarf:** CLONE the PSX humanoid rig; in edit mode shorten thigh/shin/spine segments (~75% height → 1.85 m anchor already exists in code); keep head + hands near full size (oversized extremities ARE the stocky read); re-fit mesh; **never rename or restructure bones** — the whole animation library then retargets 1:1 (clone-don't-rebuild law).
- **Goblin:** don't touch the rig — a hunched REST-POSE OFFSET layer on the human rig + goblin mesh/palette. At 48×96 the render forgives everything else.
- **Elf:** human rig unchanged; slender mesh + palette. Cheapest wave.
- **Tegnar:** the ONLY genuinely new skeleton (8-ft bear-men + horses). Correctly last. The horse can come from a quadruped base; the rider uses a stretched clone of the humanoid rig (lengthen, don't restructure).

---

# WAVE 1 — HUMANS (the big one: ~55 characters resolve to TWO fallback sheets today)
*Everything below currently renders as `man_civilian.png` or `lady_in_red.png` unless noted. Priority order is the manifest's: market → robed → labourer → officer → old-woman.*

### Townsfolk archetype sheets (randomizer output — each = master + variants)
- [ ] Merchant/market male + female (stall apron, coin belt)
- [ ] Priest/robed set (3 gods: Chronos grey, Gaela green, Morthane black — palette variants of one robe master)
- [ ] Labourer set: shepherd, fisherman, carter, stallhand (garb toggles on one master)
- [ ] Officer set: watch-captain ×2 towns, sergeant (front/back/attack rows)
- [ ] Old-woman set: 3 widows + goodwife
- [ ] Beggar, clerk, herbwife, magistrate (Wave B cast, one master + garb)
- [ ] Noble male + female (Falkenhaften/Act II ready)
- [ ] Never-drawn worker rows (6 folders don't exist on disk): miner, fisherman, lumberjack, dockworker → `workers/`; sailor deckhand, sailor captain, reformed pirate → `sailors/`; harbor master, caravan guard → `authority/`
- [ ] Guild leaders: thieves_guild_master (Lady Nightshade deserves her own sheet), keepers_leader → `guild/`

### Named uniques (quest-critical, each a distinct sheet)
- [ ] Guard Captain Halden · [ ] Guildmaster Vorn · [ ] Master Edric Vayle · [ ] Shadowmaster Vex · [ ] Red Mara · [ ] Elder Bram · [ ] Corla Vane (Millbrook boss) · [ ] Quartermaster Pell · [ ] Magistrate Thornbury · [ ] Miriam Goldtongue
- [ ] **The Drowned Man — a GHOST drawn as a townsman**: needs transparency/tint/glow treatment (shader tint may cover it — test before drawing)

### Human enemies
- [ ] Bandit variety: 5 enemy types share `human_bandit_alt.png` — need 2-3 more sheets (bandit_leader + bounty_hunter have EMPTY sprite_path)
- [ ] Cultist variety: all 4 share `cultist_red.png` incl. the named boss Malachai — boss sheet + 1 variant
- [ ] Arena gladiators: ALL 6 EMPTY (novice/veteran/champion/legend + Krag + Bloodfang) — 2 base sheets + 2 boss sheets minimum; the arena works now, it deserves faces
- [ ] `dark_general` has idle+attack+death — model for others; `rival_mercenary`, `pirate_captain/seadog` variants

# WAVE 2 — DWARVES (generics EXIST; the named cast doesn't use them)
- [ ] **Morgrim Ironvein** (regent — currently a human sheet) · [ ] **Vurka Stonebrand** (thane) · [ ] **Dwalki Runeglass** (loremaster) · [ ] Gate Warden Borik
- [ ] Fix/redraw the 3 broken generics: `dwarf_1` (no gutters), `molten1`/`molten3` (unresolvable frame counts) — REDRAW per spec, don't repair (art rule)
- [ ] Dwarf king Thurgan's BODY (a corpse prop/sprite — the Kazan-Dun quest centerpiece, currently grey-box)
- [ ] Kazan-Dun quest interactables: pyre, muster-roll lectern (grey boxes today)

# WAVE 3 — ELVES (zero files exist)
- [ ] Base 4: elf_male_civilian, elf_female_civilian, elf_guard, elf_mage → create `elves/`
- [ ] Named: elf_diplomat_silvana, elven_elder_witness, elven_ambassador (LORE_ONLY until bible [OPEN]s resolve — don't draw Sylvaine/Corwin until Caleb rules their look; they appear NOWHERE in data yet, Act II)

# WAVE 4 — GOBLINS + TEGNAR
### Goblins
- [ ] **Skarrag the Devourer** boss sheet (the warboss currently wears the generic goblin sprite; the old warboss PNG is 514×150 — unusable, redraw at spec)
- [ ] Goblin shaman (+ optional totem prop)
### Tegnar (enemy sheets exist as `tenger/tegner_*` — the typo is load-bearing, keep it)
- [ ] **Khan Toghrul** — the manifest's worst offender: an 8-ft bear-man on a huge horse currently drawn as a Dalhurst shopkeeper. Non-humanoid frame (96×160-class)
- [ ] Bridge troll **Gurm** (currently a townsman; troll/ogre enemy sheet may adapt)
- [ ] Camp NPCs ×3: tenger_elder (+Makhar), tenger_trader, tenger_scout → create `tengers/`
- [ ] Empty enemy rows: tenger_raider, tenger_shaman, tenger_warlord

# BEASTS & UNDEAD (no wave — fill as needed)
- [ ] Empty sprite_paths: boar, deer, vampire_lord, undead_lord_malthor, planar_entity, temporal_guardian, timeless_one
- [ ] 43 of 64 enemies have no ATTACK sprite — decide the standard (attack sheet per enemy vs flash-frame) before drawing any

# NON-CHARACTER ART DEBT (from the manifests)
- [ ] Real moon.png (placeholder disc shipping) · [ ] QuestInteractable props: pyre, lectern, pit floor, timber, stone stack, war chest · [ ] 33 SFX with no asset (list in check_audio_events MISSING_SFX) · [ ] Biome ambience: 7 biomes × day/night loops (0 of ~36 exist) · [ ] menu music wav
- [ ] Hostage ROOM DRESSING (7 rooms grey-boxed; the hostage sprites themselves are fine)

# OPEN SCALE RULINGS (Caleb)
- Companion heights spread 1.84–3.69 m on identical sheets · gormund_pitmaster at 3.84 m vs 2.46 m gladiators · attack-sprite standard (above)
