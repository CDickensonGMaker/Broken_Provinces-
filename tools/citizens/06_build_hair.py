"""Stage 06 - the hair library, and the final citizens_master.blend.

Hair is chunky PS1 geometry (slabs and stacked rings, never strands), each style
a separate mesh riding the head bone, on its own small palette material so a
colour variant is a texture-offset swap.

    men / boys : hair_short_crop, hair_side_part, hair_shaggy   (bald = no mesh)
    women/girls: hair_long_straight, hair_long_braid, hair_bun, hair_shoulder

Every style is measured against the hood's inner shell and reported as
hood-compatible or not - a bun under a hood is a modelling decision, not an
accident, so it is stated rather than silently fixed.

Run: blender -b --factory-startup --python tools/citizens/06_build_hair.py
Out: assets/models/citizens/citizens_master.blend
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, MASTER, TEX_HAIR, MAT_HAIR, MASTERS, open_stage,
                            save_blend, purge, tri_count, banner, report_floaters,
                            get_or_make_image_material, armature_bind,
                            new_mesh_object, flat_uv, weight_all_to_bone,
                            island_count)

HEAD_BONE = "mixamorig:Head"
HEAD_GROUPS = {"mixamorig:Head", "mixamorig:HeadTop_End"}

MALE_STYLES = ("short_crop", "side_part", "shaggy")
FEMALE_STYLES = ("long_straight", "long_braid", "bun", "shoulder")

HAIR_UV = (0.05, 0.80, 0.95, 0.95)   # top strip of the 32x32 hair palette


def head_box(head_ob):
    """The head is its own object since stage 04, so this is just its bounds."""
    cos = [v.co for v in head_ob.data.vertices]
    assert cos, "%s has no verts" % head_ob.name
    hx = max(abs(c.x) for c in cos)
    y0 = min(c.y for c in cos)
    y1 = max(c.y for c in cos)
    z0 = min(c.z for c in cos)
    z1 = max(c.z for c in cos)
    return hx, (y0 + y1) * 0.5, (y1 - y0) * 0.5, z0, z1


def ring(cx, cy, cz, rx, ry, sides, phase=0.0):
    return [Vector((cx + rx * math.cos(phase + 2 * math.pi * i / sides),
                    cy + ry * math.sin(phase + 2 * math.pi * i / sides), cz))
            for i in range(sides)]


def stitch(rings, sides, cap_top=False):
    verts = []
    for r in rings:
        verts.extend(r)
    faces = []
    for k in range(len(rings) - 1):
        a, b = k * sides, (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    if cap_top:
        off = (len(rings) - 1) * sides
        faces.append(tuple(off + i for i in range(sides)))
    return verts, faces


def compact(verts, faces):
    """Drop verts no face uses. The curtain deliberately omits its front panel,
    which would otherwise leave loose verts - exactly what the floater hunt
    catches, so it is fixed at the source instead of asserted around."""
    used = sorted({i for f in faces for i in f})
    remap = {old: new for new, old in enumerate(used)}
    return [verts[i] for i in used], [tuple(remap[i] for i in f) for f in faces]


def merge(parts):
    verts, faces = [], []
    for v, f in parts:
        off = len(verts)
        verts.extend(v)
        faces.extend(tuple(i + off for i in fc) for fc in f)
    return verts, faces


CAP_SIDES = 8


def skull_cap(hx, cy, hr, z0, z1, brow=0.42, pad=1.10, sides=CAP_SIDES,
              lean_x=0.0):
    """A shell over the top of the skull; brow = how far down the front it sits.
    lean_x sweeps the crown sideways - the whole trick behind a side part."""
    span = z1 - z0
    rings = []
    mid = brow + (0.96 - brow) * 0.5
    for f, k in ((brow, 1.0), (mid, 0.94), (0.96, 0.62)):
        r = ring(0.0, cy, z0 + span * f, hx * pad * k,
                 max(hr, hx) * pad * k, sides, phase=math.pi / sides)
        if lean_x:
            shift = lean_x * hx * (f - brow) / max(1e-6, 0.94 - brow)
            r = [Vector((v.x + shift, v.y, v.z)) for v in r]
        rings.append(r)
    return stitch(rings, sides, cap_top=True)


def band(hx, cy, hr, z_top, z_bot, pad_top=1.12, pad_bot=1.16,
         sides=CAP_SIDES, keep="back", jag=0.0):
    """One hanging band of slab hair off the skull ring.

    keep: 'back' (drop the two front segments so the face survives), 'front'
    (a fringe), or 'all'. jag lifts alternate bottom verts so the hem reads as
    torn clumps rather than a hoop.
    """
    top = ring(0.0, cy, z_top, hx * pad_top, max(hr, hx) * pad_top, sides,
               phase=math.pi / sides)
    bot = ring(0.0, cy, z_bot, hx * pad_bot, max(hr, hx) * pad_bot, sides,
               phase=math.pi / sides)
    if jag:
        bot = [Vector((v.x, v.y, v.z + (jag if i % 2 else 0.0)))
               for i, v in enumerate(bot)]
    verts = top + bot
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        mid_y = (top[i].y + top[j].y) * 0.5
        if keep == "back" and mid_y < cy:
            continue
        if keep == "front" and mid_y > cy:
            continue
        faces.append((i, j, sides + j, sides + i))
    return verts, faces


def back_plane(hx, cy, hr, z_top, z_bot, cols=3, rows=3, width=1.0):
    """A flat slab down the back of the head - the long-straight backbone."""
    y = cy + max(hr, hx) * 1.06
    w = hx * width
    verts, faces = [], []
    for r in range(rows + 1):
        t = r / rows
        z = z_top + (z_bot - z_top) * t
        for c in range(cols + 1):
            u = -w + 2.0 * w * c / cols
            verts.append(Vector((u, y + max(hr, hx) * 0.06 * t, z)))
    for r in range(rows):
        for c in range(cols):
            a = r * (cols + 1) + c
            b = (r + 1) * (cols + 1) + c
            faces.append((a, a + 1, b + 1, b))
    return verts, faces


def side_curtain(hx, cy, hr, z_top, z_bot, sign, width=0.34):
    """A single flat curtain beside the jaw, mirrored by `sign`."""
    x = sign * hx * 1.06
    y0 = cy - max(hr, hx) * width
    y1 = cy + max(hr, hx) * 1.02
    verts = [Vector((x, y0, z_top)), Vector((x, y1, z_top)),
             Vector((x * 1.04, y1, z_bot)), Vector((x * 1.04, y0, z_bot))]
    faces = [(0, 1, 2, 3)]
    return verts, faces


def braid_tail(hx, cy, hr, z_top, z_bot, r, segments=4):
    """A segmented tube - each segment pinched, so it reads as a plait."""
    back_y = cy + max(hr, hx) * 1.00
    verts, faces = [], []
    for k in range(segments + 1):
        t = k / segments
        z = z_top + (z_bot - z_top) * t
        rr = r * (1.0 - 0.40 * t) * (0.72 if k % 2 else 1.0)
        verts += [Vector((-rr, back_y - rr, z)), Vector((rr, back_y - rr, z)),
                  Vector((rr, back_y + rr, z)), Vector((-rr, back_y + rr, z))]
    for k in range(segments):
        a, b = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def blob(cx, cy, cz, r, sides=6):
    rings = [ring(cx, cy, cz - r * 0.9, r * 0.55, r * 0.55, sides),
             ring(cx, cy, cz, r, r, sides),
             ring(cx, cy, cz + r * 0.9, r * 0.55, r * 0.55, sides)]
    v, f = stitch(rings, sides, cap_top=True)
    f = list(f) + [tuple(range(sides - 1, -1, -1))]
    return v, f


def build_style(style, hx, cy, hr, z0, z1):
    """EQ chunk: every style has to own a silhouette from across the street.

    z0 is the JAW and z1 the crown, so a fraction of 0.62 is roughly eye level
    and 0.74 the brow ridge. No cap ring may sit below ~0.70 or the citizen
    loses his eyes - which is exactly what the first pass did.
    """
    span = z1 - z0

    if style == "short_crop":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.76, pad=1.05)
        fringe = band(hx, cy, hr, z0 + span * 0.80, z0 + span * 0.70,
                      pad_top=1.06, pad_bot=1.10, keep="front")
        return merge([cap, fringe])

    if style == "side_part":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.74, pad=1.09, lean_x=0.34)
        sweep = band(hx, cy, hr, z0 + span * 0.96, z0 + span * 0.78,
                     pad_top=1.14, pad_bot=1.02, keep="front")
        # the heavy side of the part: a wedge over one ear
        y0 = cy - max(hr, hx) * 0.95
        y1 = cy + max(hr, hx) * 0.85
        zt = z0 + span * 0.92
        zb = z0 + span * 0.62
        x = hx * 1.10
        wedge = ([Vector((x * 0.30, y0, zt)), Vector((x, y0, zt)),
                  Vector((x, y1, zt)), Vector((x * 0.30, y1, zt)),
                  Vector((x * 0.55, y0, zb)), Vector((x * 1.06, y0, zb)),
                  Vector((x * 1.06, y1, zb)), Vector((x * 0.55, y1, zb))],
                 [(0, 1, 2, 3), (1, 5, 6, 2), (0, 4, 5, 1), (3, 2, 6, 7)])
        return merge([cap, sweep, wedge])

    if style == "shaggy":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.72, pad=1.13)
        tiers = []
        for k, (zt, zb, pt, pb) in enumerate((
                (0.80, 0.66, 1.14, 1.20),
                (0.70, 0.48, 1.18, 1.24),
                (0.54, 0.26, 1.20, 1.16))):
            tiers.append(band(hx, cy, hr, z0 + span * zt, z0 + span * zb,
                              pad_top=pt, pad_bot=pb, sides=6,
                              keep="all" if k == 0 else "back",
                              jag=span * (0.10 if k < 2 else 0.07)))
        return merge([cap] + tiers)

    if style == "shoulder":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.74, pad=1.10)
        upper = band(hx, cy, hr, z0 + span * 0.74, z0 - span * 0.15, pad_bot=1.16)
        lower = band(hx, cy, hr, z0 - span * 0.15, z0 - span * 1.05,
                     pad_top=1.16, pad_bot=1.18)
        return merge([cap, upper, lower])

    if style == "long_straight":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.74, pad=1.10)
        nape = band(hx, cy, hr, z0 + span * 0.74, z0 - span * 0.05, pad_bot=1.16)
        plane = back_plane(hx, cy, hr, z0 - span * 0.02, z0 - span * 2.60,
                           cols=3, rows=3, width=1.06)
        left = side_curtain(hx, cy, hr, z0 + span * 0.62, z0 - span * 1.50, -1)
        right = side_curtain(hx, cy, hr, z0 + span * 0.62, z0 - span * 1.50, 1)
        return merge([cap, nape, plane, left, right])

    if style == "long_braid":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.76, pad=1.08)
        nape = band(hx, cy, hr, z0 + span * 0.76, z0 - span * 0.30, pad_bot=1.10)
        tail = braid_tail(hx, cy, hr, z0 - span * 0.20, z0 - span * 2.40,
                          hx * 0.34, segments=3)
        return merge([cap, nape, tail])

    if style == "bun":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.80, pad=1.06, lean_x=0.14)
        sweep = band(hx, cy, hr, z0 + span * 0.84, z0 + span * 0.62,
                     pad_top=1.08, pad_bot=1.04, keep="back")
        knot = blob(0.0, cy + max(hr, hx) * 1.02, z0 + span * 0.92, hx * 0.42)
        return merge([cap, sweep, knot])

    raise AssertionError("unknown hair style %s" % style)


def hood_inner_radius(master):
    hood = bpy.data.objects.get("garb_hood_%s" % master)
    if hood is None:
        return None
    return max(Vector((v.co.x, v.co.y, 0)).length for v in hood.data.vertices)


def main():
    banner("STAGE 06 - hair library + master file")
    open_stage("_stage05_garb.blend")

    img_path = os.path.join(STAGE, TEX_HAIR)
    assert os.path.exists(img_path), "run 03_make_textures.py first"
    img = bpy.data.images.get(TEX_HAIR) or bpy.data.images.load(img_path)
    img.name = TEX_HAIR
    mat = get_or_make_image_material(MAT_HAIR, img)

    made = []
    compat = []
    for master in MASTERS:
        body = bpy.data.objects[master]
        head_ob = bpy.data.objects["%s_head" % master]
        rig = body.parent
        col = bpy.data.collections[master]
        hx, cy, hr, z0, z1 = head_box(head_ob)
        hood_r = hood_inner_radius(master)
        styles = FEMALE_STYLES if master in ("WOMAN", "GIRL") else MALE_STYLES

        for style in styles:
            verts, faces = compact(*build_style(style, hx, cy, hr, z0, z1))
            ob = new_mesh_object("hair_%s_%s" % (style, master), verts, faces)
            ob.data.materials.append(mat)
            flat_uv(ob, *HAIR_UV)
            armature_bind(ob, rig)
            weight_all_to_bone(ob, HEAD_BONE)
            ob.hide_render = True
            for c in list(ob.users_collection):
                c.objects.unlink(ob)
            col.objects.link(ob)
            made.append(ob)

            # hood-compatible check: does the style fit inside the hood shell?
            crown = [v.co for v in ob.data.vertices if v.co.z > z0 + (z1 - z0) * 0.35]
            worst = max(Vector((c.x, c.y - cy, 0)).length for c in crown) if crown else 0.0
            fits = hood_r is not None and worst <= hood_r * 0.97
            compat.append((ob.name, worst, hood_r, fits))

    print("--- HAIR REPORT ---")
    for ob in made:
        t = tri_count(ob)
        print("  %-30s tris=%-4d verts=%-4d islands=%d" %
              (ob.name, t, len(ob.data.vertices), island_count(ob)))
        report_floaters(ob, radius=3.0)
        assert 40 <= t <= 100, "%s outside the chunky-hair budget: %d" % (ob.name, t)
        assert len(ob.data.materials) == 1 and ob.data.materials[0].name == MAT_HAIR
        assert list(ob.vertex_groups.keys()) == [HEAD_BONE], \
            "%s must ride the head bone alone" % ob.name

    print("--- HOOD COMPATIBILITY ---")
    for name, worst, hood_r, fits in compat:
        print("  %-30s crown_radius=%.4f hood_inner=%.4f  %s" %
              (name, worst, hood_r or -1, "FITS" if fits else "CLIPS - hide under hood"))

    # ---- final master file ------------------------------------------------ #
    print("--- MASTER FILE INVENTORY ---")
    for master in MASTERS:
        col = bpy.data.collections[master]
        names = sorted(o.name for o in col.objects)
        print("  %-6s %d objects" % (master, len(names)))
        for n in names:
            print("      %s" % n)
    print("  materials: %s" % sorted(m.name for m in bpy.data.materials))
    print("  images:    %s" % sorted(i.name for i in bpy.data.images
                                     if i.name not in ("Render Result", "Viewer Node")))

    keep_lit = set(MASTERS) | {"%s_head" % m for m in MASTERS}
    for ob in bpy.data.objects:
        if ob.type == 'MESH':
            ob.hide_render = ob.name not in keep_lit
            ob.hide_viewport = False

    purge()
    save_blend(MASTER)
    print("STAGE06_OK")


main()
