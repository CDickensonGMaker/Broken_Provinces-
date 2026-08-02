# Citizen masters — review pass (2026-08-02, Wyrm)

Four PSX citizen masters for Broken Provinces, built headless from RECON's
`us_base_v3.blend`. **Nothing has been exported.** GLB export waits on Caleb's
approval, per the standing rule.

- Blend: `assets/models/citizens/citizens_master.blend` (195 KB)
- Build scripts: `tools/citizens/01`–`07` (each re-runnable from the stage before it)
- Renders: this folder

## What the base append yielded

`Base_Human` from `C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend`
(source untouched, opened read-only). The whole `Collection` hierarchy was
appended — armature plus all 78 objects — then 76 gear/prop meshes were deleted,
leaving the rig and the bare body. **The gear was never fused into the body**:
`Base_Human` is a separate 402-tri mesh on a single material, with helmet,
webbing, rucksack, canteens and weapons as their own objects. No blockout
fallback was needed.

The rig came across with all **41 Mixamo bone names intact**
(`mixamorig:Hips` … `mixamorig:RightToe_End`). Nothing was renamed or
restructured, on either rig.

## Masters

| Master | Rig | Bones | Height | Body tris | Verts | Material |
|---|---|---|---|---|---|---|
| MAN | `PSXRig` | 41 | 1.800 m | 402 | 203 | `face_atlas_mat` |
| WOMAN | `PSXRig` (shared with MAN) | 41 | 1.800 m | 402 | 203 | `face_atlas_mat` |
| BOY | `PSXRig_child` | 41 | 1.218 m | 402 | 203 | `face_atlas_mat` |
| GIRL | `PSXRig_child` (shared with BOY) | 41 | 1.218 m | 402 | 203 | `face_atlas_mat` |

Two rigs, four masters. The child rig is a clone scaled to 65% with the head
chain given back 1.32× — child height lands at **0.677 of the adult**, with a
near-adult head, which is the big-head PSX read.

No shape keys, no subsurf, no modifiers but the armature. Every body is one
manifold island, zero loose or stray verts (asserted at every stage).

## Materials and textures

| Material | Texture | Size | Used by |
|---|---|---|---|
| `face_atlas_mat` | `citizen_face_atlas_placeholder.png` | 256×256 | the four bodies |
| `garb_mat` | `citizen_garb_palette_placeholder.png` | 64×64 | all 34 garb meshes |
| `hair_mat` | `citizen_hair_palette_placeholder.png` | 32×32 | all 14 hair meshes |

All three sample with `Closest` interpolation — nearest neighbour, no filtering.
Textures live beside the blend in `assets/models/citizens/`.

**The atlas contract.** 10 columns × 7 rows = 70 cells of **25×36 px** on a
256² image. Within a cell, image rows 0–23 are the face and rows 24–35 are the
flat skin patch. Head and neck UV into the face rect; hands, limbs, torso and
feet all UV into the skin patch **of the same cell**, so `uv1_offset` slides
face and skin together and a mismatch is impossible. Every master is currently
parked on cell (0, 0). Cell stride for the dresser is `(25/256, 36/256)` =
`(0.09766, 0.14063)`.

## Garb inventory (34 meshes)

Visibility-toggled meshes on the masters, hidden by default (`hide_render`), for
the dresser to enable by name prefix.

| Piece | tris | MAN | WOMAN | BOY | GIRL |
|---|---|---|---|---|---|
| `garb_vest_plain_*` | 60 | ✓ | ✓ | ✓ | ✓ |
| `garb_vest_laced_*` | 68 | ✓ | ✓ | ✓ | ✓ |
| `garb_pants_*` | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_skirt_*` | 68 | — | ✓ | — | ✓ |
| `garb_sleeve_long_*` | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_sleeve_rolled_*` | 96 | ✓ | ✓ | ✓ | ✓ |
| `garb_sleeve_none_*` | 48 | ✓ | ✓ | ✓ | ✓ |
| `garb_apron_*` | 14 | ✓ | ✓ | ✓ | ✓ |
| `garb_hood_*` | 86 | ✓ | ✓ | ✓ | ✓ |

Total garb: **2,392 tris across 34 meshes.** A fully dressed citizen
(body + vest + pants + sleeves + hair) runs roughly **660–700 tris**, inside the
300–800 humanoid budget with the body alone at 402.

Every piece is generated from that master's own measured silhouette, so the
child's garb is the child's, not a shrunk adult's. Weights are copied from the
nearest body vertex — the body's weights are already correct — except the skirt.

## Hair inventory (14 meshes)

Chunky slab/ring geometry, each on `hair_mat`, each weighted 100% to
`mixamorig:Head` and nothing else.

| Master | Styles | tris |
|---|---|---|
| MAN | `hair_short_crop` 28, `hair_side_part` 38, `hair_shaggy` 40 | bald = no mesh |
| BOY | `hair_short_crop` 28, `hair_side_part` 38, `hair_shaggy` 40 | bald = no mesh |
| WOMAN | `hair_long_straight` 36, `hair_long_braid` 56, `hair_bun` 56, `hair_shoulder` 36 | |
| GIRL | `hair_long_straight` 36, `hair_long_braid` 60, `hair_bun` 56, `hair_shoulder` 32 | |

**Hood compatibility: all 14 styles fit inside the hood shell** by measurement —
worst crown radius is the bun at 0.142 m against a hood inner radius of 0.204 m
(adult) and 0.122 m against 0.175 m (child). No style needs hiding under a hood.

## Renders in this folder

| File | Size | What |
|---|---|---|
| `citizen_turnaround_MAN.png` | 512×288 | front / 3-quarter / side / back |
| `citizen_turnaround_WOMAN.png` | 512×288 | same |
| `citizen_turnaround_BOY.png` | 512×288 | same |
| `citizen_turnaround_GIRL.png` | 512×288 | same |
| `citizen_variant_wall.png` | 512×640 | garb combos and hair styles, man and woman |
| `citizen_scale_check.png` | 512×224 | four masters nude, then four dressed |

EEVEE, flat shadowless world light, transparent background.

## Structural compromises — say so plainly

1. **MAN and WOMAN share one armature; BOY and GIRL share another.** That is
   what was asked for, and it means the woman's mesh is reshaped against bones
   that did not move. Her arms were shifted inboard 15 mm to follow the narrowed
   shoulders, so her upper-arm skinning is stretched by that much. At PSX scale
   it is invisible in the renders; it is still a real deviation.
2. **The children are proportioned like scaled adults below the neck.** Only the
   head was given back. Real child proportions (shorter limbs relative to torso,
   softer waist) were not modelled — the brief asked for a 65% clone with a big
   head, and that is what is there.
3. **The rest pose is the soldier's A-pose, untouched**, as instructed. The
   citizens stand like grunts until an animation plays.
4. **The face atlas is placeholder pixels, not placeholder layout.** The 10×7
   grid is the contract. Note that RECON's shipping atlas is 768×1056 with
   hand-measured, irregular face rects (`RECONgame/tools/face_uv.py`), *not* a
   uniform grid — so a real CoG atlas must be authored to the grid, or this
   UV pass must be redone to match whatever Caleb paints.
5. **The garb is procedural blocking, not sculpted clothing.** Tubes and rings
   fitted to measured body sections. It reads correctly at PSX distance and it
   is structurally right; it is not hand-crafted.

## What Caleb must eyeball before this can be exported

1. **Woman's proportions.** Shoulders 0.90×, waist 0.92×, hips 1.16×, thighs
   1.06×, and a 22 mm forward chest nudge. Is the read right, or too subtle /
   too much? Best seen in `citizen_turnaround_WOMAN.png` (side view carries the
   chest form).
2. **Skirt deformation.** `garb_skirt_WOMAN` and `garb_skirt_GIRL` are weighted
   Hips → both thighs, blended across the centreline so the cloth cannot tear
   open when the legs split. **Nothing has been animated yet** — this is the one
   claim in this document that a still render cannot prove. Drop a Mixamo walk
   on the woman and watch the hem before approving it.
3. **Child head ratio.** 1.32× head on a 0.65× body, giving 1.218 m total.
   Compare with the adults in `citizen_scale_check.png`. Too cartoonish, or not
   enough?
4. **Whether the hood should replace hair rather than coexist.** All styles
   measure as fitting, but a bun under a hood may still read wrong to the eye.
5. **The atlas layout question in compromise 4** — grid or hand-packed. This
   decides whether the head UVs stay as they are.
6. **Whether the men need a civilian silhouette pass at all.** The body is the
   soldier base with the gear removed and no reproportioning; it reads as a
   plain man in the renders.

## How to open and inspect

```
"C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" ^
  "C:\Users\caleb\CatacombsOfGore\assets\models\citizens\citizens_master.blend"
```

Four collections — `MAN`, `WOMAN`, `BOY`, `GIRL` — plus `RIGS` holding `PSXRig`
and `PSXRig_child`. Garb and hair meshes are visible in the viewport and hidden
in renders; toggle the camera icon per object to try a combination.

To rebuild any stage from scratch (each is idempotent, each writes the next
stage file, `.blend1` backups are disabled throughout):

```
cd C:\Users\caleb\CatacombsOfGore
blender -b --factory-startup --python tools\citizens\01_append_base.py
blender -b --factory-startup --python tools\citizens\03_make_textures.py
blender -b --factory-startup --python tools\citizens\04_build_masters.py
blender -b --factory-startup --python tools\citizens\05_build_garb.py
blender -b --factory-startup --python tools\citizens\06_build_hair.py
blender -b --factory-startup --python tools\citizens\07_render_review.py
```

`00_probe_source.py` and `02_probe_body.py` are read-only measuring tools; they
write nothing and are safe to run against the RECON source at any time.
