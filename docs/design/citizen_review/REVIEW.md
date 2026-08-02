# Citizen masters — refinement pass (2026-08-02, Wyrm)

Second pass over the four PSX citizen masters, built headless from RECON's
`us_base_v3.blend`. **They are now EXPORTED**: four GLBs live in
`assets/models/citizens/glb/` and each one has been reimported and asserted.

- Blend: `assets/characters/citizens/src/citizens_master.blend`
- Exports: `assets/models/citizens/glb/citizen_{man,woman,boy,girl}.glb`
- Build scripts: `tools/citizens/01`–`09` (each re-runnable from the stage before it)
- Renders: this folder

**The stage files moved.** They now sit under `assets/models/citizens/src/`,
which carries the `.gdignore`. They used to sit one level up, and that
`.gdignore` would have hidden `glb/` from Godot too — a `.gdignore` hides every
subdirectory beneath it, so the exports would have been invisible to the engine
that needs them.

---

## What changed in this pass

| # | Task | Outcome |
|---|---|---|
| 1 | Trousers | Rebuilt as continuous hip→ankle tubes with one knee seam and an ankle flare. 96 → **80 tris/pair** |
| 2 | Hair | All 7 styles rebuilt with real silhouettes, 48–76 tris each; new close-up review sheet |
| 3 | Skirt deformation | **Found a real defect and fixed it** — see below |
| 4 | Face atlas | RECON hand-packed wins. Head split into its own mesh; layout restructured to 8×4 |
| 5 | EQ pass | Adults only: forearms ×1.16, hands ×1.22, boots ×1.20, perpendicular to the bone axis |
| 6 | Export | Four GLBs, validated by headless reimport |
| 7 | Renders | All refreshed, plus `citizen_hair_wall.png` and `citizen_skirt_walk.png` |

---

## THE ATLAS CONVENTION — what Caleb paints to

**Ruling: the RECON hand-packed format wins over the 10×7 grid.** The grid is
gone. What replaced it is the layout that RECON's own bake script can read.

```
256 x 256 PNG        8 columns x 4 rows  =  32 face cells
cell                 32 px wide, 64 px tall
  rows  0..47        FACE rect  (32 x 48)   <- the head mesh, and NOTHING else
  rows 48..63        SKIN patch (32 x 16)   <- body, hands, feet, neck
cell stride (uv1_offset) = (0.125, 0.25)
```

Three rules for painting it:

1. **The face rect is the top three-quarters of a cell; the skin patch is the
   bottom quarter.** The skin patch must be a flat swatch of the same tone the
   face's neck ends on — every vertex below the jaw samples one pixel of it.
2. **The leftmost 4 and rightmost 4 columns of the face rect are the BACK of the
   head.** The head UV is a front-planar wrap, so rear-facing verts collapse
   onto those edge columns. Paint scalp there, never features.
3. **The layout is resolution-independent.** A 512² or 1024² atlas needs no UV
   change at all, as long as it stays 8 columns × 4 rows and the cell stays
   three-quarters face over one-quarter skin. Only the pixel counts double.

**Why this shape and not a nicer one.** `RECONgame/tools/bake_us_faces.py`
finds a character's face rect by clustering the UV centroids of every polygon
on a mesh whose *name* contains `head` carrying a *material* whose name contains
`face`, then rejects the result if the rect is under 16 px or over 25% of either
atlas axis. Two things follow, and both are now structural:

- **The head is its own object, `citizen_head`.** With head and body fused, the
  flat skin patch is by far the denser cluster (358 body tris against 44 head
  tris), the script resolves a 1×1 px rect and skips the character entirely.
- **The cell is 32×64, not larger.** Measured on the shipped GLBs, the face rect
  comes out **31×39 px** — inside the script's [16, 64] window at 256², and it
  stays inside at 512² and 1024².

`04_build_masters.py` and `09_validate_glb.py` both run that exact clustering
and fail the build if it stops resolving. It is asserted, not hoped for.

**What Caleb loses:** 32 faces per atlas instead of 70. A 512² atlas at the same
grid gives 32 faces at 64×96 px each, which is the trade worth taking.

---

## Masters

| Master | Rig | Bones | Height | Body | Head | Total tris | Material |
|---|---|---|---|---|---|---|---|
| MAN | `PSXRig` | 41 | 1.800 m | 358 | 44 | 402 | `face_atlas_mat` |
| WOMAN | `PSXRig` (shared) | 41 | 1.800 m | 358 | 44 | 402 | `face_atlas_mat` |
| BOY | `PSXRig_child` | 41 | 1.218 m | 358 | 44 | 402 | `face_atlas_mat` |
| GIRL | `PSXRig_child` (shared) | 41 | 1.218 m | 358 | 44 | 402 | `face_atlas_mat` |

Body and head are two objects on ONE material, so `uv1_offset` slides face and
skin together and a mismatch stays impossible. The **neck stays on the body** —
leaving it on the head made the face rect span jaw-to-collarbone, which put the
mouth on the throat and dropped every hair style's brow ring over the eyes.
Both defects were visible in the first render of the hair sheet and are the
reason that sheet now exists.

### The EQ pass (adults only)

Forearms, hands and boots are thickened **perpendicular to their own bone axis**,
so nothing got longer — 80 verts moved per adult. The children were cloned
before the pass and are untouched, per the brief.

---

## THE GARB ATLAS CONVENTION — what Caleb paints to

The second thing he paints, and the one that changes the crowd fastest. Same
shape as the face convention above, and binding in the same way.

```
512 x 512 PNG        4 columns x 4 rows  =  16 GARB PAGES
page                 128 x 128 px
  within a page, four zones of 64 x 64, TOP-ORIGIN:
    (0,0)   VEST      the torso garment — the robe samples this zone too
    (64,0)  PANTS     trousers AND skirt
    (0,64)  SLEEVES   both arms
    (64,64) EXTRA     apron and hood
page stride (uv1_offset) = (0.25, 0.25)
```

**PAGE 0 IS THE BOTTOM-LEFT and the page row counts UP.** `v` is bottom-origin
and every garment is UV'd into page 0 at `v < 0.25`, so page 4 is the row above
page 0, not below it. Paint the grid the other way round and a townsman wearing
page 5 samples the page nobody painted. Stages 05, 08 and 09 all assert the
page-0 law on the meshes; nothing asserts which way *you* painted the grid.

| Page | Colourway | Page | Colourway |
|---|---|---|---|
| 0 | commoner grey | 8 | **Chronos grey** |
| 1 | labourer linen | 9 | **Gaela green** |
| 2 | merchant wine | 10 | **Morthane black** |
| 3 | guard slate | 11 | russet |
| 4 | faded blue | 12 | ash |
| 5 | dun brown | 13 | ochre |
| 6 | moss | 14 | slate violet |
| 7 | bleached | 15 | sand |

Pages 4–7 and 11–15 are **neutral variants, not blanks** — an NPC whose trade
is not in `CitizenDresser.ARCHETYPE_PAGE` draws one of them on his seed.

Five rules for painting a zone, and the first one is the whole recipe:

1. **Light on top, mid in the middle, dark at the hem, hard edges between.**
   Upper 40% the lightest values, middle 35% the largest flat block in one hue,
   lower 25% the hem and belt band — the darkest. It reads as a lit cylinder at
   12 pixels and it is exactly what a 32×32 EQ chest texture does.
2. **One light, always: from above and slightly front-left.** Never re-decide it
   per page. A single inconsistent page makes the crowd look wrong and nobody
   can say why.
3. **Paint the occlusion, not the object.** The dark line under a belt, in an
   armpit, under a hood's brim. Worth more than the belt itself.
4. **Keep it desaturated and mid-value.** The dresser multiplies one of 14 dyes
   over the page. A page painted saturated crimson can only ever be crimson; a
   page painted in warm greys becomes fourteen. This is the rule the whole
   system rests on.
5. **Leave 2 px of the correct colour inside every zone boundary.** Nearest
   filtering plus a UV a fraction off samples the neighbouring garment, and it
   looks like a shader bug for a week.

**Resolution-independent**, like the face atlas: 1024² gives 128 px zones with
no UV change, as long as it stays 4×4 pages of four quadrants.

**Rule 5, automated.** `citizen_garb_wall.png` is one master × 16 pages × 3 dyes
and `citizen_garb_wall_12px.png` is the same grid with the figure at 12 px —
the size a townsman occupies across a market square. **Read the 12 px sheet
first.** At full size every page looks fine, which is why the full-size sheet is
the one that lies. If a citizen is not a silhouette plus two colour blocks at
12 px, the page has failed and the fix is bigger blocks and more value
contrast, never more detail.

---

## Garb inventory (34 meshes, 2,144 tris)

Every piece here changes the OUTLINE, which is the only thing a mesh is allowed
to be. Colour, laces, buckles, apron fronts and armour are *pages*.

| Piece | tris | was | MAN | WOMAN | BOY | GIRL |
|---|---|---|---|---|---|---|
| `garb_vest_plain` | 60 | 60 | ✓ | ✓ | ✓ | ✓ |
| `garb_robe` | **86** | — | ✓ | ✓ | ✓ | ✓ |
| `garb_pants` | **80** | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_skirt` | 68 | 68 | — | ✓ | — | ✓ |
| `garb_sleeve_long` | **72** | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_sleeve_rolled` | **72** | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_sleeve_none` | 48 | 48 | ✓ | ✓ | ✓ | ✓ |
| `garb_apron` | 14 | 14 | ✓ | ✓ | ✓ | ✓ |
| `garb_hood` | **70** | 86 | ✓ | ✓ | ✓ | ✓ |

**Trousers.** Each leg is now one continuous tube from hip to ankle with a
single seam loop at the knee, so it bends at the knee and nowhere else, and the
ankle ring is wider than the knee ring — that modest flare is the EQ chunk and
it is what stopped the leg reading as a pipe. The seat is a waist-to-crotch
taper whose bottom ring sits at the same height as the leg tops, so the three
parts read as one garment. The old version was a closed barrel plus two open
tubes with a step between them, which is exactly the leg-strap read.
Weights come from the nearest body vertex, so hip/thigh/shin fall out correctly.

Sleeves and hood lost a ring each to hold the dressed budget.

**`garb_vest_laced` was deleted (2026-08-02).** Its entire content was a 4-quad
strip down the chest of a vest that already had that silhouette — against the
sky it *was* the plain vest. 68 tris and one mesh per master buying nothing.
Laces are a painted page now. Stage 09 keeps it in a FORBIDDEN set so a stale
stage file cannot bring it back.

**`garb_robe` was added.** Shoulder to shin in one skirted tube, 86 tris, on all
four masters. It is the one silhouette paint cannot fake — priests of three
gods, cultists, mages, the Wave-5 lich/wight family — and EQ gave robes their
own seven texture slots for exactly that reason. It REPLACES vest + pants +
skirt, so a robed citizen is *cheaper* than a dressed one. Above the waist it
takes the body's own weights; below it takes the skirt's quadratic hips-to-thigh
ramp, and `citizen_robe_walk_MAN.png` is the proof it does not tear.

---

## Hair inventory (14 meshes, 880 tris)

| Style | MAN | BOY | WOMAN | GIRL | Silhouette |
|---|---|---|---|---|---|
| `hair_short_crop` | 48 | 48 | — | — | tight cap + front fringe band |
| `hair_side_part` | 52 | 56 | — | — | crown swept sideways + a wedge over one ear |
| `hair_shaggy` | 66 | 62 | — | — | cap + 3 jagged clump tiers |
| `hair_long_straight` | — | — | 70 | 70 | nape band + back plane to mid-back + 2 side curtains |
| `hair_long_braid` | — | — | 72 | 72 | nape band + 3-segment pinched tail tube |
| `hair_bun` | — | — | 76 | 76 | swept cap + knot blob at the crown |
| `hair_shoulder` | — | — | 58 | 54 | two stacked curtain bands to the shoulder |

All ride `mixamorig:Head` alone. Every style now anchors off the **jaw-to-crown**
span, where 0.62 is eye level and 0.74 the brow ridge; no cap ring is allowed
below ~0.70.

**Hood compatibility holds.** Worst crown radius is `hair_side_part` at 0.136 m
against a hood inner radius of 0.204 m (adult), and 0.117 m against 0.175 m
(child). All 14 styles measure as fitting; none needs hiding under a hood.
Whether a *bun* under a hood reads right to the eye is still Caleb's call —
`citizen_hair_wall.png` and the hood column of the variant wall are the evidence.

---

## Skirt deformation — the claim a still could not make

`citizen_skirt_walk.png` is six posed frames of the woman through a walk arc
(−30°, −16°, 0°, +16°, +30°, +14° on the thigh). The strip is generated by
posing six independent copies of the rig, not by faking it with mesh copies.

**The swing axis is measured, not assumed.** The arc is applied on the thigh's
local X, the toe's world displacement is read back, and the axis is swapped and
re-probed if the leg moved sideways instead of forward. It swings on local **Z**;
X moves the leg out to the side.

**It sheared, and the number said so before any eye did.** Max edge stretch
across the arc:

| | −30° | −16° | 0° | +16° | +30° | +14° | worst |
|---|---|---|---|---|---|---|---|
| **before** | 1.11 | 1.05 | 1.00 | 1.19 | **2.14** | 1.56 | **2.14** |
| **after** | 1.12 | 1.06 | 1.00 | 1.19 | 1.31 | 1.17 | **1.31** |

Two weights caused it and both are now derived rather than picked:

- **Leg share ramps as `t²`, capped at 0.50.** It was linear to 0.75, which put
  three-quarters of the hem on the thighs and let an edge across the centreline
  stretch 2.14× at a full stride.
- **The left/right blend spans the full hem half-width**, measured off the hem
  ring, instead of a hardcoded 0.167 m band. Two verts either side of the
  centreline can no longer take opposite rotations at full strength.

`07_render_review.py` asserts the worst stretch stays under 1.40, so this cannot
silently come back.

---

## Dressed tri counts (budget ≤ 700)

| Combination | tris |
|---|---|
| man — plain vest, trousers, long sleeves, crop | **662** |
| boy — plain vest, trousers, rolled sleeves, shaggy | **676** |
| woman — laced vest, skirt, long sleeves, braid | **682** |
| girl — plain vest, skirt, bun | **606** |

Heaviest possible adult (laced vest + trousers + long sleeves + bun) is **698**.
The renderer asserts ≤ 700 on every combination it draws.

---

## The exports

| GLB | meshes | tris (all variants) | bones | size |
|---|---|---|---|---|
| `citizen_man.glb` | 13 | 1,052 | 41 | 108 KB |
| `citizen_woman.glb` | 15 | 1,230 | 41 | 125 KB |
| `citizen_boy.glb` | 13 | 1,052 | 41 | 108 KB |
| `citizen_girl.glb` | 15 | 1,226 | 41 | 125 KB |

Object names inside a GLB drop the `_<MASTER>` suffix:
`citizen_body`, `citizen_head`, `garb_pants`, `hair_bun`, and so on. Materials
are exactly `face_atlas_mat`, `garb_mat`, `hair_mat` — asserted on reimport.

**Every variant mesh ships VISIBLE, and the runtime must hide what it does not
want.** glTF has no visibility flag: a mesh hidden in Blender either exports
visible or does not export at all. This is the RECON convention
(`RECONgame/scripts/visuals/grunt_dresser.gd:278`, `_set_visible_by_name`) and it
is why every one of the 13–15 meshes made it into the file. Until the dresser
runs, a spawned citizen wears **all** the garb at once — that is expected, not a
bug, but the dresser is now a hard requirement for the first spawn, not a
nicety.

`09_validate_glb.py` reimports each GLB into a scratch scene and asserts: one
armature, 41 bones all `mixamorig:`, the exact mesh inventory, one material per
mesh from the three contract names, every mesh skinned to the armature with
weights and UVs intact, and the face rect still clustering inside the bake
script's window. All four pass. (Blender 5's glTF *importer* spawns a stray
`Icosphere` and hands it to the leaf bones as a display shape — it is viewport
furniture, it is in no exported file, and the validator now says so by name
rather than tripping over it.)

---

## Renders in this folder

| File | Size | What |
|---|---|---|
| `citizen_turnaround_MAN.png` | 512×288 | front / 3-quarter / side / back |
| `citizen_turnaround_WOMAN.png` | 512×288 | same |
| `citizen_turnaround_BOY.png` | 512×288 | same |
| `citizen_turnaround_GIRL.png` | 512×288 | same |
| `citizen_variant_wall.png` | 512×640 | garb combos and hair styles, man and woman |
| `citizen_scale_check.png` | 512×224 | four masters nude, then four dressed |
| `citizen_hair_wall.png` | 768×340 | **new** — every hair style, head close-up, front and side |
| `citizen_skirt_walk.png` | 768×300 | **new** — the skirt through a walk arc |

EEVEE, flat shadowless world light, transparent background.

---

## Structural compromises — still true, said plainly

1. **MAN and WOMAN share one armature; BOY and GIRL share another.** The woman's
   mesh is reshaped against bones that did not move; her arms were shifted
   inboard 15 mm, so her upper-arm skinning is stretched by that much.
2. **The children are proportioned like scaled adults below the neck**, and the
   EQ pass deliberately skipped them, so their hands and boots stay slimmer than
   the adults'. The brief forbade re-proportioning them further.
3. **The rest pose is the soldier's A-pose, untouched.**
4. **The face atlas is placeholder pixels.** The cell grid above is the contract.
5. **The garb is procedural blocking, not sculpted clothing.**
6. **The head/body seam is a real seam.** Polys straddling the neck stayed on the
   body, so nothing has a hole, but the two objects are separate draw calls
   sharing one material. That is the price of the atlas ruling, and RECON pays
   it too.

## What Caleb still has to eyeball

1. **Woman's proportions** — shoulders 0.90×, waist 0.92×, hips 1.16×, thighs
   1.06×, 22 mm forward chest nudge. Best seen in the WOMAN turnaround side view.
2. **The EQ chunk level.** Forearm 1.16, hand 1.22, boot 1.20 — enough EverQuest,
   or push further? `citizen_scale_check.png` carries the adult/child comparison.
3. **Child head ratio** — 1.32× head on a 0.65× body, 1.218 m total.
4. **Hood over a bun.** Measured as fitting; the eye may still disagree.
5. **32 faces per atlas** instead of 70 — acceptable, or should the atlas go to
   512² for 64×96 px faces at the same grid? (No UV work either way.)

## How to rebuild

```
cd C:\Users\caleb\CatacombsOfGore
set B="C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
%B% -b --factory-startup --python tools\citizens\01_append_base.py
%B% -b --factory-startup --python tools\citizens\03_make_textures.py
%B% -b --factory-startup --python tools\citizens\04_build_masters.py
%B% -b --factory-startup --python tools\citizens\05_build_garb.py
%B% -b --factory-startup --python tools\citizens\06_build_hair.py
%B% -b --factory-startup --python tools\citizens\07_render_review.py
%B% -b --factory-startup --python tools\citizens\08_export_glb.py
%B% -b --factory-startup --python tools\citizens\09_validate_glb.py
```

`00_probe_source.py` and `02_probe_body.py` are read-only measuring tools; they
write nothing and are safe to run against the RECON source at any time.
Every stage is idempotent, writes the next stage file, and `.blend1` backups are
disabled throughout.

To open and inspect:

```
"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" ^
  "C:\Users\caleb\CatacombsOfGore\assets\models\citizens\src\citizens_master.blend"
```

Four collections — `MAN`, `WOMAN`, `BOY`, `GIRL` — plus `RIGS` holding `PSXRig`
and `PSXRig_child`. Garb and hair meshes are visible in the viewport and hidden
in renders; toggle the camera icon per object to try a combination.
