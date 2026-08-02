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


def head_box(body):
    names = {vg.index: vg.name for vg in body.vertex_groups}
    cos = []
    for v in body.data.vertices:
        best = None
        for g in v.groups:
            if best is None or g.weight > best.weight:
                best = g
        if best is not None and names.get(best.group) in HEAD_GROUPS:
            cos.append(v.co)
    assert cos, "%s has no head verts" % body.name
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


def skull_cap(hx, cy, hr, z0, z1, brow=0.42, pad=1.10, sides=6):
    """A shell over the top of the skull; brow = how far down the front it sits."""
    span = z1 - z0
    rings = []
    for f, k in ((brow, 1.0), (0.72, 0.94), (0.94, 0.62)):
        rings.append(ring(0.0, cy, z0 + span * f, hx * pad * k,
                          max(hr, hx) * pad * k, sides, phase=math.pi / sides))
    return stitch(rings, sides, cap_top=True)


def curtain(hx, cy, hr, z_top, z_bot, back_only=True, pad=1.12, sides=6):
    """Slab hair hanging from the skull ring - the PS1 curtain."""
    top = ring(0.0, cy, z_top, hx * pad, max(hr, hx) * pad, sides, phase=math.pi / sides)
    bot = ring(0.0, cy + max(hr, hx) * 0.10, z_bot, hx * pad * 1.05,
               max(hr, hx) * pad * 1.05, sides, phase=math.pi / sides)
    verts = top + bot
    faces = []
    for i in range(sides):
        j = (i + 1) % sides
        # skip the face-front segment so the citizen keeps a face
        mid_y = (top[i].y + top[j].y) * 0.5
        if back_only and mid_y < cy:
            continue
        faces.append((i, j, sides + j, sides + i))
    return verts, faces


def braid(hx, cy, hr, z_top, z_bot, r):
    back_y = cy + max(hr, hx) * 0.95
    steps = 3
    verts, faces = [], []
    for k in range(steps + 1):
        t = k / steps
        z = z_top + (z_bot - z_top) * t
        rr = r * (1.0 - 0.45 * t)
        verts += [Vector((-rr, back_y - rr, z)), Vector((rr, back_y - rr, z)),
                  Vector((rr, back_y + rr, z)), Vector((-rr, back_y + rr, z))]
    for k in range(steps):
        a, b = k * 4, (k + 1) * 4
        for i in range(4):
            j = (i + 1) % 4
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def build_style(style, hx, cy, hr, z0, z1):
    span = z1 - z0
    if style == "short_crop":
        return skull_cap(hx, cy, hr, z0, z1, brow=0.52, pad=1.06)
    if style == "side_part":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.50, pad=1.08)
        w = hx * 0.55
        zt = z0 + span * 0.99
        zb = z0 + span * 0.80
        y0 = cy - max(hr, hx) * 1.05
        y1 = cy + max(hr, hx) * 0.55
        v = [Vector((-hx * 0.15, y0, zt)), Vector((w, y0, zt * 0.999),),
             Vector((w, y1, zt * 0.999)), Vector((-hx * 0.15, y1, zt)),
             Vector((-hx * 0.15, y0, zb)), Vector((w * 1.05, y0, zb)),
             Vector((w * 1.05, y1, zb)), Vector((-hx * 0.15, y1, zb))]
        f = [(0, 1, 2, 3), (0, 3, 7, 4), (1, 5, 6, 2), (0, 4, 5, 1), (3, 2, 6, 7)]
        return merge([cap, (v, f)])
    if style == "shaggy":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.46, pad=1.12)
        fringe = curtain(hx, cy, hr, z0 + span * 0.52, z0 + span * 0.20,
                         back_only=False, pad=1.14)
        return merge([cap, fringe])
    if style == "shoulder":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.48, pad=1.10)
        fall = curtain(hx, cy, hr, z0 + span * 0.55, z0 - span * 0.75, pad=1.14)
        return merge([cap, fall])
    if style == "long_straight":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.48, pad=1.10)
        fall = curtain(hx, cy, hr, z0 + span * 0.55, z0 - span * 2.10, pad=1.16)
        return merge([cap, fall])
    if style == "long_braid":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.50, pad=1.08)
        nape = curtain(hx, cy, hr, z0 + span * 0.55, z0 - span * 0.30, pad=1.12)
        tail = braid(hx, cy, hr, z0 - span * 0.20, z0 - span * 1.90, hx * 0.30)
        return merge([cap, nape, tail])
    if style == "bun":
        cap = skull_cap(hx, cy, hr, z0, z1, brow=0.54, pad=1.06)
        by = cy + max(hr, hx) * 1.05
        bz = z0 + span * 0.88
        r = hx * 0.46
        rings = [ring(0.0, by, bz - r, r * 0.6, r * 0.6, 6),
                 ring(0.0, by, bz, r, r, 6),
                 ring(0.0, by, bz + r, r * 0.6, r * 0.6, 6)]
        return merge([cap, stitch(rings, 6, cap_top=True)])
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
        rig = body.parent
        col = bpy.data.collections[master]
        hx, cy, hr, z0, z1 = head_box(body)
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
        assert 12 <= t <= 120, "%s outside the chunky-hair budget: %d" % (ob.name, t)
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

    for ob in bpy.data.objects:
        if ob.type == 'MESH':
            ob.hide_render = ob.name not in MASTERS
            ob.hide_viewport = False

    purge()
    save_blend(MASTER)
    print("STAGE06_OK")


main()
