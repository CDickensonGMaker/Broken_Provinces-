# Broken Provinces — Master Art Guide & Tracker (v2 — PSX 3D)
*2026-08-02, Wyrm. **v2 REWRITE per Caleb's pivot ruling: the game becomes a PSX 3D RPG — full 3D characters, not billboards.** The 2D pipeline was a skill-gap compromise; the skill now exists (the RECON stack). Every character item below is a MODEL, not a sheet. Existing sprites serve as placeholders until their model lands, then phase out (art rule: never repair a billboard). The wave lists below are unchanged — only the medium changed. Companion docs: `docs/audits/art_replacement_manifest.md`, `docs/audits/sprite_audit.md` (now legacy-2D reference).*

## THE VISUAL NORTH STAR (Caleb, 8/2): **EVERQUEST (1999)**
NPCs should look like EverQuest characters: chunky low-poly proportions, painted-on clothing detail over simple geometry, big readable silhouettes, faces mostly texture. When a modeling choice is ambiguous, ask "what would classic EQ do" — geometry for silhouette, texture for everything else. This slightly relaxes pure-PSX austerity: EQ bodies carry a bit more form than PS1, and that's the intent.

## THE SPEC (every character model — non-negotiable)
- **PSX fidelity:** low-poly (300–800 tris for humanoids, boss-class up to ~1,500), single 128² or 256² texture per character, palette-limited hand-painted look, nearest-neighbor filtering, no normal maps. Vertex-lit look; affine/jitter comes from the game's existing PS1 shaders.
- **Rig: the PSX humanoid rig, Mixamo-compatible bone names** — the RECON PSXRig discipline. Mixamo clips are DROP-IN (no retarget). NEVER rename or restructure bones on any variant rig.
- **Scale anchors (unchanged in meters):** humanoid 2.46 m eye-consistent scale class → real ~1.8 m model; dwarf ~1.4 m; Khan-class ~2.4 m+. Scale is set on the MODEL at export, never fudged per-instance.
- **Export:** GLB via `blender -b` batch scripts only (the RECON export law); one master GLB per race/sex + garb variants as visibility-toggled meshes IN the master (not separate files) + per-variant props (hats etc.) as socketed GLBs with the stock item as placement datum.
- **Animation set per character class:** civilians — idle, walk, sit, sleep, work-generic, talk; combat — + attack ×2, hurt, death, block-pose. Source: Mixamo (drop-in) + RECON's 19 CC0 clips + RECON civilian clips (walk/idle/sit/sleep are setting-agnostic). Clips live in a shared library; characters share the library (one skeleton = one library).

## THE MIGRATION (dual-support law — the game stays playable at every commit)
**Phase 0 — BUILT, 2026-08-02.** `CharacterVisual` (`scripts/visuals/character_visual.gd`) is one interface behind CivilianNPC (`scripts/world/civilian_npc.gd:_create_visual`) and QuestGiver (`scripts/npcs/quest_giver.gd:_create_visual`), which between them are every named and ambient townsperson: `set_action` · `set_moving` · `set_facing` · `play_attack/hurt/death` · `set_talking` · `set_tint`. Two implementations — `BillboardVisual` (wraps today's BillboardSprite; the default and a measured no-op) and `RiggedVisual` (a citizen GLB, dressed at runtime). `NPCScheduler.place_for_hour` hands the living-world action to whichever body is there. The flip is ONE data field: `data/character_models.json` maps npc_id → master, absent = billboard, no code change per character. Gate: `tools/check_character_visual.tscn`.
- *EnemyBase has not adopted it yet.* The interface carries `play_attack/hurt/death` for it and nothing in it is CivilianNPC-shaped, but the adoption is not written.
- *The masters ship with no clips*, so RiggedVisual poses the skeleton in code: an A-pose rest correction that drops the arms, a breathing idle, and a measured walk (stride 0.70 m, foot lift 0.14 m). Every axis and sign is solved off the rig at attach — these exports keep Blender's frame inside `Skeleton3D` (up is −Z, the body faces +Y) and face world **+Z**, not Godot's −Z. The whole fallback retires itself the moment `assets/models/citizens/clips/PSXRig.res` exists.
**Phase 1 (Caleb's Blender + agent staging): the fantasy PSX masters.** Male + female human civilian base on the PSXRig — THE two most leveraged models in the project (they carry ~55 characters via the dresser). Then the shared animation library wired.
**Phases 2-5: the waves below, in order.** Each wave = master(s) + dresser variants + named uniques.

## THE RANDOMIZER (RECON's grunt_dresser, now used DIRECTLY — no sprite rendering step)
This is the piece that makes 3D *cheaper* than 2D ever was: the dresser runs at RUNTIME in Godot, exactly like RECON.
1. **Face+skin are the same pixels** — head/neck/hands UV'd into ONE atlas cell sharing ONE material; `uv1_offset` slides both together (mismatch impossible). `merge_face_skin_material.py` ports as-is.
2. **Match materials by texture identity, not name** (the 7/29 black-head bug).
3. **Duplicate the material per instance** ("a fireteam of octuplets" otherwise).
4. **Capability gating that WARNS when it degrades**, once per unit.
CoG build: **face/skin atlas (8×4 = 32 faces) + GARB ATLAS PAGES AND DYES, with mesh toggles for silhouette only.** Deterministic per-npc_id seed: same villager, same face, same clothes, every session, forever. **One male + one female master ⇒ the entire human townsfolk population.**

5. **Colour is the variation; geometry is the silhouette.** Two citizens must differ in palette before they differ in polygons. This line used to read "garb visibility toggles + palette variants", and the "palette variants" were fiction: `_shared_garb` was one material for the entire game, so all our variety was in mesh toggles and none in texture — the exact opposite of the EQ technique (`docs/design/EQ_TECHNIQUE.md`, verified 8/2). A garment variant is now a `uv1_offset` into a 4×4-page garb atlas, exactly as a face is: **the archetype picks the page (16), the seed picks the dye (14, in two slots)**, and a new NPC "look" costs one texture page and zero triangles.
6. **A mesh toggle is only allowed where the OUTLINE changes.** The test is: does it break the silhouette against the sky? Hood, skirt-vs-trousers, sleeve length, robe, hats — geometry. Laces, buttons, belts, apron fronts, armour plates, trim, dirt, rank insignia — paint. `garb_vest_laced` was deleted under this rule and `garb_robe` added under it.
**Build order: Phase 0 abstraction → masters → dresser → waves.** Modeling 55 individual townsfolk is the trap; two masters + the dresser is the road.

## RIG RECIPES PER RACE (the dwarf/goblin worry, answered)
- **Dwarf:** CLONE the PSX humanoid rig; in edit mode shorten thigh/shin/spine segments (~75% height → 1.85 m anchor already exists in code); keep head + hands near full size (oversized extremities ARE the stocky read); re-fit mesh; **never rename or restructure bones** — the whole animation library then retargets 1:1 (clone-don't-rebuild law).
- **Goblin:** don't touch the rig — a hunched REST-POSE OFFSET layer on the human rig + goblin mesh/palette. At 48×96 the render forgives everything else.
- **Elf:** human rig unchanged; slender mesh + palette. Cheapest wave.
- **Tegnar:** the ONLY genuinely new skeleton (8-ft bear-men + horses). Correctly last. The horse can come from a quadruped base; the rider uses a stretched clone of the humanoid rig (lengthen, don't restructure).

---

# WAVE 1 — HUMANS (the big one: ~55 characters resolve to TWO fallback sheets today)
*Everything below currently renders as `man_civilian.png` or `lady_in_red.png` unless noted. Priority order is the manifest's: market → robed → labourer → officer → old-woman.*

### Townsfolk archetype sheets (randomizer output — each is now a PAGE, not a sheet)
*Since 8/2 these are pages in the garb atlas, and the meshes for all of them already exist. What is outstanding is Caleb painting the page, not building anything. `citizen_garb_wall_12px.png` is the acceptance test.*
- [ ] Merchant/market male + female — **page 2**; apron mesh exists, the coin belt is paint
- [x] Priest/robed set (3 gods) — **pages 8/9/10**, wired: `CitizenDresser.DEITY_PAGE` reads the god off the npc_id, and `garb_robe` is the one robe master. Placeholder colourways ship; the painting is Caleb's
- [ ] Labourer set: shepherd, fisherman, carter, stallhand — **page 1**, all four already map to it
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

# WAVE 5 — UNDEAD & FANTASY TROPES (Caleb, 8/2: "skeletons and zombies etc, all the fantasy tropes")
The cheap secret: most tropes ride the EXISTING humanoid rig — same bones, new mesh, full animation library free.
- [ ] **Skeleton** — bone mesh on the human rig (the single best rig-reuse in fantasy; EQ's skeletons are the reference). Covers skeleton_warrior/shade + the 6 arena "gladiator" undead potential
- [ ] **Zombie** — human base mesh, decayed variant + shamble texture; rest-pose slump layer (the goblin-hunch trick)
- [ ] **Ghoul / drowned dead** — zombie palette + waterlogged variant
- [ ] **Ghost** (The Drowned Man, ghost pirates) — human/citizen mesh + transparency/fresnel shader, no new geometry
- [ ] **Vampire lord + Isolde-class royals** — dressed citizen masters + noble garb + palette (they're PEOPLE — the dresser does these)
- [ ] **Cultist** — citizen master + robe garb toggle (may not need a model at all)
- [ ] Later tropes on the same trick: wight/lich (skeleton + robes), draugr-class (zombie + armor garb)
- [ ] **Horse** (mount/pack animal + the Tegnar's huge horses at scale-up) — source: Quaternius CC0 animated pack (Horse + White Horse, walk/run/idle/death clips included; fbx/gltf; quaternius.com / quaternius.itch.io/lowpoly-animated-animals / poly.pizza Animated Animal Pack). Restyle toward EQ chunk after import.

# BEASTS & UNDEAD SPRITES (legacy 2D — placeholder-only now, fill only if a model is far off)
- [ ] Empty sprite_paths: boar, deer, vampire_lord, undead_lord_malthor, planar_entity, temporal_guardian, timeless_one
- [ ] 43 of 64 enemies have no ATTACK sprite — decide the standard (attack sheet per enemy vs flash-frame) before drawing any

# NON-CHARACTER ART DEBT (from the manifests)
- [ ] Real moon.png (placeholder disc shipping) · [ ] QuestInteractable props: pyre, lectern, pit floor, timber, stone stack, war chest · [ ] 33 SFX with no asset (list in check_audio_events MISSING_SFX) · [ ] Biome ambience: 7 biomes × day/night loops (0 of ~36 exist) · [ ] menu music wav
- [ ] Hostage ROOM DRESSING (7 rooms grey-boxed; the hostage sprites themselves are fine)

# OPEN SCALE RULINGS (Caleb)
- Companion heights spread 1.84–3.69 m on identical sheets · gormund_pitmaster at 3.84 m vs 2.46 m gladiators · attack-sprite standard (above)
