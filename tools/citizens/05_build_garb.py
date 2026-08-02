"""Stage 05 - garb variant meshes, one set per master, visibility-toggled.

Every piece is generated from the master's OWN measured silhouette (vertex
groups pick torso/leg/arm verts, so arms never pollute a torso measurement) and
takes its skin weights from the nearest body vertex - the body's weights are
already correct, so nothing is hand-weighted except the skirt, which is
deliberately weighted to the thighs so it swings instead of splitting.

Naming contract (the runtime dresser toggles on the prefix):
    garb_vest_plain_<MASTER>   garb_vest_laced_<MASTER>
    garb_pants_<MASTER>        garb_skirt_<MASTER>      (woman/girl only)
    garb_sleeve_long_<MASTER>  garb_sleeve_rolled_<MASTER>  garb_sleeve_none_<MASTER>
    garb_apron_<MASTER>        garb_hood_<MASTER>
The trailing _<MASTER> exists only because Blender object names are file-global;
it is stripped at export, when each master becomes its own GLB.

Run: blender -b --factory-startup --python tools/citizens/05_build_garb.py
Out: assets/models/citizens/_stage05_garb.blend
"""
import bpy
import math
import os
import sys
from mathutils import Vector, kdtree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, TEX_GARB, MAT_GARB, MASTERS, open_stage,
                            save_blend, purge, tri_count, banner, report_floaters,
                            get_or_make_image_material, armature_bind,
                            new_mesh_object, flat_uv, island_count)

# garb palette zones as UV rects on the 64x64 placeholder (u0, v0, u1, v1)
ZONE = {
    "vest":    (0.02, 0.52, 0.48, 0.98),
    "pants":   (0.52, 0.52, 0.98, 0.98),
    "sleeves": (0.02, 0.02, 0.48, 0.48),
    "extra":   (0.52, 0.02, 0.98, 0.48),
}

HEAD_GROUPS = {"mixamorig:Head", "mixamorig:HeadTop_End", "mixamorig:Neck"}
ARM_GROUPS = set()
for _s in ("Left", "Right"):
    ARM_GROUPS |= {"mixamorig:%sArm" % _s, "mixamorig:%sForeArm" % _s,
                   "mixamorig:%sShoulder" % _s, "mixamorig:%sHand" % _s}
    for _f in ("Thumb", "Index"):
        for _i in (1, 2, 3, 4):
            ARM_GROUPS.add("mixamorig:%sHand%s%d" % (_s, _f, _i))
LEG_GROUPS = set()
for _s in ("Left", "Right"):
    LEG_GROUPS |= {"mixamorig:%sUpLeg" % _s, "mixamorig:%sLeg" % _s,
                   "mixamorig:%sFoot" % _s, "mixamorig:%sToeBase" % _s,
                   "mixamorig:%sToe_End" % _s}


# --------------------------------------------------------------------------- #
# measuring the body (never guess - the memory law)
# --------------------------------------------------------------------------- #

def dominant_map(ob):
    names = {vg.index: vg.name for vg in ob.vertex_groups}
    out = {}
    for v in ob.data.vertices:
        best = None
        for g in v.groups:
            if best is None or g.weight > best.weight:
                best = g
        out[v.index] = names.get(best.group) if best else None
    return out


class Body:
    """Measurements for one master. The head is a SEPARATE object since stage 04
    (the atlas ruling), so head_profile reads it and `height` is the taller of
    the two - the body alone stops at the neck."""

    def __init__(self, ob, head_ob):
        self.ob = ob
        self.head_ob = head_ob
        self.dom = dominant_map(ob)
        self.co = [v.co.copy() for v in ob.data.vertices]
        self.head_co = [v.co.copy() for v in head_ob.data.vertices]
        self.height = max(max(c.z for c in self.co),
                          max(c.z for c in self.head_co))
        self.torso = [i for i, n in self.dom.items()
                      if n not in ARM_GROUPS and n not in HEAD_GROUPS
                      and n not in LEG_GROUPS]
        self.legs = {s: [i for i, n in self.dom.items()
                         if n and n.startswith("mixamorig:%s" % s) and n in LEG_GROUPS]
                     for s in ("Left", "Right")}

    def band(self, idxs, z, window):
        picked = [self.co[i] for i in idxs if abs(self.co[i].z - z) <= window]
        if not picked:
            # widen until something is found; the base mesh is sparse by design
            w = window
            while not picked and w < self.height:
                w *= 1.6
                picked = [self.co[i] for i in idxs if abs(self.co[i].z - z) <= w]
        return picked

    def torso_profile(self, z):
        p = self.band(self.torso, z, 0.06 * self.height)
        rx = max(abs(c.x) for c in p)
        y0 = min(c.y for c in p)
        y1 = max(c.y for c in p)
        return rx, (y0 + y1) * 0.5, (y1 - y0) * 0.5

    def leg_profile(self, side, z):
        p = self.band(self.legs[side], z, 0.06 * self.height)
        xs = [c.x for c in p]
        cx = (min(xs) + max(xs)) * 0.5
        rx = max(1e-3, (max(xs) - min(xs)) * 0.5)
        y0 = min(c.y for c in p)
        y1 = max(c.y for c in p)
        return cx, rx, (y0 + y1) * 0.5, max(1e-3, (y1 - y0) * 0.5)

    def head_profile(self):
        p = self.head_co
        return (max(abs(c.x) for c in p),
                (min(c.y for c in p) + max(c.y for c in p)) * 0.5,
                (max(c.y for c in p) - min(c.y for c in p)) * 0.5,
                min(c.z for c in p), max(c.z for c in p))


def bone_world(rig, name):
    return rig.matrix_world @ rig.data.bones[name].head_local


# --------------------------------------------------------------------------- #
# geometry primitives
# --------------------------------------------------------------------------- #

def ring(cx, cy, cz, rx, ry, sides, phase=0.0):
    out = []
    for i in range(sides):
        a = phase + 2.0 * math.pi * i / sides
        out.append(Vector((cx + rx * math.cos(a), cy + ry * math.sin(a), cz)))
    return out


def stitch(rings, sides, cap_top=False, cap_bottom=False):
    verts = []
    for r in rings:
        verts.extend(r)
    faces = []
    for k in range(len(rings) - 1):
        a = k * sides
        b = (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    if cap_bottom:
        faces.append(tuple(range(sides - 1, -1, -1)))
    if cap_top:
        off = (len(rings) - 1) * sides
        faces.append(tuple(off + i for i in range(sides)))
    return verts, faces


def tube_along(points, radii, sides):
    """Rings perpendicular to the path - used for sleeves along the arm bones."""
    verts = []
    faces = []
    n = len(points)
    for k in range(n):
        if k == 0:
            d = (points[1] - points[0])
        elif k == n - 1:
            d = (points[-1] - points[-2])
        else:
            d = (points[k + 1] - points[k - 1])
        d = d.normalized()
        up = Vector((0, 0, 1))
        if abs(d.dot(up)) > 0.95:
            up = Vector((0, 1, 0))
        u = d.cross(up).normalized()
        w = d.cross(u).normalized()
        for i in range(sides):
            a = 2.0 * math.pi * i / sides
            verts.append(points[k] + u * (radii[k] * math.cos(a))
                         + w * (radii[k] * math.sin(a)))
    for k in range(n - 1):
        a = k * sides
        b = (k + 1) * sides
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((a + i, a + j, b + j, b + i))
    return verts, faces


def merge(parts):
    verts = []
    faces = []
    for v, f in parts:
        off = len(verts)
        verts.extend(v)
        faces.extend(tuple(i + off for i in face) for face in f)
    return verts, faces


# --------------------------------------------------------------------------- #
# weighting
# --------------------------------------------------------------------------- #

def transfer_weights(garb, body):
    """Nearest-body-vertex weight copy. Reuses weights that are already right."""
    bco = [v.co for v in body.data.vertices]
    kd = kdtree.KDTree(len(bco))
    for i, c in enumerate(bco):
        kd.insert(c, i)
    kd.balance()
    names = {vg.index: vg.name for vg in body.vertex_groups}
    for n in names.values():
        if n not in garb.vertex_groups:
            garb.vertex_groups.new(name=n)
    for v in garb.data.vertices:
        _, idx, _ = kd.find(v.co)
        src = body.data.vertices[idx]
        total = sum(g.weight for g in src.groups) or 1.0
        for g in src.groups:
            garb.vertex_groups[names[g.group]].add([v.index], g.weight / total, 'REPLACE')


def weight_skirt(garb, top_z, hem_z, half_width=1.0):
    """PSX skirt: hips at the waist, blending into both thighs down the hem.

    Two numbers decide whether the cloth swings or tears, and both were MEASURED
    against the walk arc in stage 07 rather than guessed:

      leg share ramps as t*t, so only the last third of the skirt follows a
      thigh at all - a linear ramp put 75% of the hem on the legs and an edge
      across the centreline stretched 2.14x at a 30-degree stride.

      the left/right blend spans the FULL hem half-width, so two verts either
      side of the centreline never receive opposite rotations at full strength.
    """
    for n in ("mixamorig:Hips", "mixamorig:LeftUpLeg", "mixamorig:RightUpLeg"):
        if n not in garb.vertex_groups:
            garb.vertex_groups.new(name=n)
    hips = garb.vertex_groups["mixamorig:Hips"]
    lup = garb.vertex_groups["mixamorig:LeftUpLeg"]
    rup = garb.vertex_groups["mixamorig:RightUpLeg"]
    span = max(1e-6, top_z - hem_z)
    hw = max(1e-6, half_width)
    for v in garb.data.vertices:
        t = min(1.0, max(0.0, (top_z - v.co.z) / span))   # 0 at waist, 1 at hem
        legs = 0.50 * t * t
        w_hips = 1.0 - legs
        side = 0.5 + 0.5 * max(-1.0, min(1.0, v.co.x / hw))
        hips.add([v.index], w_hips, 'REPLACE')
        lup.add([v.index], legs * side, 'REPLACE')
        rup.add([v.index], legs * (1.0 - side), 'REPLACE')


# --------------------------------------------------------------------------- #
# the pieces
# --------------------------------------------------------------------------- #

def make_piece(name, verts, faces, mat, zone, rig, body, master, skirt=None,
               weight_src=None):
    ob = new_mesh_object("%s_%s" % (name, master), verts, faces)
    ob.data.materials.append(mat)
    flat_uv(ob, *ZONE[zone])
    armature_bind(ob, rig)
    if skirt is None:
        transfer_weights(ob, weight_src or body)
    else:
        weight_skirt(ob, *skirt)
    ob.hide_render = True          # variants ship hidden; the dresser enables one
    ob.hide_viewport = False
    return ob


def build_vest(b, laced):
    h = b.height
    z_hem = 0.50 * h
    z_waist = 0.635 * h
    z_chest = 0.755 * h
    z_shoulder = 0.845 * h
    sides = 8
    rings = []
    for z, pad in ((z_hem, 1.12), (z_waist, 1.10), (z_chest, 1.09), (z_shoulder, 1.06)):
        rx, cy, ry = b.torso_profile(z)
        rings.append(ring(0.0, cy, z, rx * pad, max(ry, rx * 0.55) * pad, sides))
    parts = [stitch(rings, sides, cap_top=True, cap_bottom=True)]
    if laced:
        rx, cy, ry = b.torso_profile(z_chest)
        y = cy - max(ry, rx * 0.55) * 1.14
        w = rx * 0.16
        strip = []
        sfaces = []
        steps = 4
        for k in range(steps + 1):
            z = z_hem + (z_shoulder - z_hem) * k / steps
            strip.append(Vector((-w, y, z)))
            strip.append(Vector((w, y, z)))
        for k in range(steps):
            a = k * 2
            sfaces.append((a, a + 1, a + 3, a + 2))
        parts.append((strip, sfaces))
    return merge(parts)


def build_pants(b):
    """Trousers, not leg-straps.

    Each leg is ONE continuous tube from the hip to the ankle with a single
    seam loop at the knee - three rings, so the tube bends at the knee and
    nowhere else. The ankle ring is wider than the knee: that flare is the EQ
    chunk, and it is what stops the leg reading as a pipe. The seat is a
    waist-to-crotch taper whose bottom ring sits at the same z as the leg tops,
    so the three pieces read as one garment instead of a barrel and two straps.
    Budget: 12 quads + 2 caps per leg, 8 quads + 1 cap for the seat.
    """
    h = b.height
    sides = 6
    z_hip = 0.545 * h
    z_knee = 0.290 * h
    z_ankle = 0.075 * h
    parts = []
    for side in ("Left", "Right"):
        rings = []
        for z, pad in ((z_hip, 1.18), (z_knee, 1.12), (z_ankle, 1.22)):
            cx, rx, cy, ry = b.leg_profile(side, z)
            rings.append(ring(cx, cy, z, rx * pad, max(ry, rx) * pad, sides))
        parts.append(stitch(rings, sides, cap_top=True, cap_bottom=True))

    seat_sides = 6
    rx_w, cy_w, ry_w = b.torso_profile(0.615 * h)
    rx_c, cy_c, ry_c = b.torso_profile(0.560 * h)
    waist = ring(0.0, cy_w, 0.625 * h, rx_w * 1.10, max(ry_w, rx_w * 0.6) * 1.10, seat_sides)
    crotch = ring(0.0, cy_c, z_hip, rx_c * 1.16, max(ry_c, rx_c * 0.6) * 1.16, seat_sides)
    parts.append(stitch([waist, crotch], seat_sides, cap_top=True))
    return merge(parts)


def build_skirt(b):
    h = b.height
    sides = 10
    z_top = 0.60 * h
    z_hem = 0.26 * h
    rx, cy, ry = b.torso_profile(z_top)
    rings = []
    steps = 3
    for k in range(steps + 1):
        t = k / steps
        z = z_top + (z_hem - z_top) * t
        flare = 1.10 + 0.85 * t
        rings.append(ring(0.0, cy, z, rx * flare, max(ry, rx * 0.6) * flare, sides))
    hem_half_width = max(abs(v.x) for v in rings[-1])
    return (merge([stitch(rings, sides, cap_top=True, cap_bottom=False)]),
            z_top, z_hem, hem_half_width)


def arm_path(rig, side, stop):
    """stop: 'wrist' | 'elbow' | 'shoulder'"""
    sh = bone_world(rig, "mixamorig:%sArm" % side)
    el = bone_world(rig, "mixamorig:%sForeArm" % side)
    wr = bone_world(rig, "mixamorig:%sHand" % side)
    if stop == "shoulder":
        return [sh, sh + (el - sh) * 0.28]
    if stop == "elbow":
        return [sh, sh + (el - sh) * 0.6, el + (wr - el) * 0.30]
    return [sh, sh + (el - sh) * 0.65, el, wr]


def arm_radius(b, side, p, d):
    """The arm's cross-section at p: perpendicular distance from the limb AXIS.

    Measuring plain distance-to-nearest-vert instead gives the distance ALONG
    the arm as well, which is much larger, and the sleeve balloons into a cone.
    """
    idxs = [i for i, n in b.dom.items()
            if n in ARM_GROUPS and n.startswith("mixamorig:%s" % side)]
    d = d.normalized()
    slab = 0.055 * b.height
    perp = []
    while not perp and slab < 0.4 * b.height:
        for i in idxs:
            v = b.co[i] - p
            along = v.dot(d)
            if abs(along) <= slab:
                perp.append((v - d * along).length)
        slab *= 1.6
    if not perp:
        return 0.028 * b.height
    return max(0.016 * b.height, max(perp))


def build_sleeve(b, rig, stop, cuff):
    parts = []
    for side in ("Left", "Right"):
        pts = arm_path(rig, side, stop)
        dirs = []
        for k in range(len(pts)):
            if k == 0:
                dirs.append(pts[1] - pts[0])
            elif k == len(pts) - 1:
                dirs.append(pts[-1] - pts[-2])
            else:
                dirs.append(pts[k + 1] - pts[k - 1])
        radii = [arm_radius(b, side, p, d) * 1.14 for p, d in zip(pts, dirs)]
        radii[0] *= 1.12                       # shoulder cap sits a little proud
        parts.append(tube_along(pts, radii, 6))
        if cuff:
            c = pts[-1]
            d = (pts[-1] - pts[-2]).normalized()
            parts.append(tube_along([c - d * 0.010 * b.height, c + d * 0.010 * b.height],
                                    [radii[-1] * 1.16, radii[-1] * 1.16], 6))
    return merge(parts)


def build_apron(b):
    h = b.height
    z_top = 0.62 * h
    z_bot = 0.30 * h
    rx, cy, ry = b.torso_profile(z_top)
    y = cy - max(ry, rx * 0.6) * 1.20
    verts = []
    faces = []
    steps = 3
    for k in range(steps + 1):
        t = k / steps
        z = z_top + (z_bot - z_top) * t
        w = rx * (0.72 + 0.35 * t)
        verts.append(Vector((-w, y - 0.004 * h * (1 - t), z)))
        verts.append(Vector((0.0, y - 0.012 * h, z)))
        verts.append(Vector((w, y - 0.004 * h * (1 - t), z)))
    for k in range(steps):
        a = k * 3
        faces.append((a, a + 1, a + 4, a + 3))
        faces.append((a + 1, a + 2, a + 5, a + 4))
    # bib + strap
    rx2, cy2, ry2 = b.torso_profile(0.76 * h)
    y2 = cy2 - max(ry2, rx2 * 0.6) * 1.16
    off = len(verts)
    bw = rx * 0.5
    verts += [Vector((-bw, y2, 0.78 * h)), Vector((bw, y2, 0.78 * h)),
              Vector((-bw, y, z_top)), Vector((bw, y, z_top))]
    faces.append((off, off + 1, off + 3, off + 2))
    return verts, faces


def build_hood(b):
    hx, hy, hr, hz0, hz1 = b.head_profile()
    sides = 8
    rings = []
    span = hz1 - hz0
    for f, pad in ((-0.16, 1.30), (0.30, 1.20), (0.86, 0.95), (1.02, 0.42)):
        z = hz0 + span * f
        rings.append(ring(0.0, hy + 0.02 * span, z, hx * pad, max(hr, hx) * pad, sides))
    verts, faces = stitch(rings, sides, cap_top=True, cap_bottom=False)
    # a shoulder drape so it reads as a hood, not a swim cap
    off = len(verts)
    drape = ring(0.0, hy, hz0 - span * 0.55, hx * 1.9, max(hr, hx) * 1.7, sides)
    verts.extend(drape)
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, off + j, off + i))
    return verts, faces


# --------------------------------------------------------------------------- #

def main():
    banner("STAGE 05 - garb variants")
    open_stage("_stage04_masters.blend")

    img_path = os.path.join(STAGE, TEX_GARB)
    assert os.path.exists(img_path), "run 03_make_textures.py first"
    img = bpy.data.images.get(TEX_GARB) or bpy.data.images.load(img_path)
    img.name = TEX_GARB
    mat = get_or_make_image_material(MAT_GARB, img)

    made = []
    for master in MASTERS:
        body = bpy.data.objects[master]
        head_ob = bpy.data.objects["%s_head" % master]
        assert body.matrix_world.is_identity, "%s is not at identity; garb math assumes it" % master
        rig = body.parent
        b = Body(body, head_ob)
        col = bpy.data.collections[master]
        female = master in ("WOMAN", "GIRL")

        pieces = []
        v, f = build_vest(b, laced=False)
        pieces.append(make_piece("garb_vest_plain", v, f, mat, "vest", rig, body, master))
        v, f = build_vest(b, laced=True)
        pieces.append(make_piece("garb_vest_laced", v, f, mat, "vest", rig, body, master))

        v, f = build_pants(b)
        pieces.append(make_piece("garb_pants", v, f, mat, "pants", rig, body, master))

        if female:
            (v, f), z_top, z_hem, hem_hw = build_skirt(b)
            pieces.append(make_piece("garb_skirt", v, f, mat, "pants", rig, body,
                                     master, skirt=(z_top, z_hem, hem_hw)))

        v, f = build_sleeve(b, rig, "wrist", cuff=False)
        pieces.append(make_piece("garb_sleeve_long", v, f, mat, "sleeves", rig, body, master))
        v, f = build_sleeve(b, rig, "elbow", cuff=True)
        pieces.append(make_piece("garb_sleeve_rolled", v, f, mat, "sleeves", rig, body, master))
        v, f = build_sleeve(b, rig, "shoulder", cuff=True)
        pieces.append(make_piece("garb_sleeve_none", v, f, mat, "sleeves", rig, body, master))

        v, f = build_apron(b)
        pieces.append(make_piece("garb_apron", v, f, mat, "extra", rig, body, master))
        # the hood rides the skull, so its weights come from the HEAD object -
        # nearest-vertex against the (now headless) body would hand it the neck
        v, f = build_hood(b)
        pieces.append(make_piece("garb_hood", v, f, mat, "extra", rig, body, master,
                                 weight_src=head_ob))

        for ob in pieces:
            for c in list(ob.users_collection):
                c.objects.unlink(ob)
            col.objects.link(ob)
        made.extend(pieces)
        print("  %-6s %d garb meshes" % (master, len(pieces)))

    print("--- GARB REPORT ---")
    total = 0
    for ob in made:
        t = tri_count(ob)
        total += t
        print("  %-28s tris=%-4d verts=%-4d islands=%d vgroups=%d"
              % (ob.name, t, len(ob.data.vertices), island_count(ob), len(ob.vertex_groups)))
        report_floaters(ob, radius=3.0)
        assert t <= 800, "%s over PSX budget: %d tris" % (ob.name, t)
        if ob.name.startswith("garb_pants"):
            assert t <= 120, "%s over the trouser budget: %d tris" % (ob.name, t)
        assert len(ob.data.materials) == 1 and ob.data.materials[0].name == MAT_GARB
        assert ob.vertex_groups, "%s has no weights" % ob.name
    print("  garb meshes=%d total tris=%d" % (len(made), total))

    purge()
    save_blend(os.path.join(STAGE, "_stage05_garb.blend"))
    print("STAGE05_OK")


main()
