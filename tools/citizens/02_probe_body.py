"""Stage 02 (read-only probe) - measure Base_Human so reshaping is measured, not guessed.

Run: blender -b --factory-startup --python tools/citizens/02_probe_body.py
"""
import bpy
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import open_stage, tri_count, banner


def main():
    banner("STAGE 02 - measure base body")
    open_stage("_stage01_base.blend")
    body = bpy.data.objects["Base_Human"]
    rig = bpy.data.objects["PSXRig"]
    me = body.data

    print("body world matrix scale=%s" % (body.matrix_world.to_scale(),))
    print("rig world matrix scale=%s" % (rig.matrix_world.to_scale(),))
    print("tris=%d verts=%d dims=%.3f %.3f %.3f" % (
        tri_count(body), len(me.vertices), *body.dimensions))

    gi_to_name = {vg.index: vg.name for vg in body.vertex_groups}
    print("--- VERTEX GROUPS: count / bbox in object space ---")
    per = {}
    for v in me.vertices:
        best = None
        for g in v.groups:
            if best is None or g.weight > best.weight:
                best = g
        if best is None:
            per.setdefault("<none>", []).append(v.co)
        else:
            per.setdefault(gi_to_name.get(best.group, "?"), []).append(v.co)
    for name in sorted(per, key=lambda n: -len(per[n])):
        cos = per[name]
        xs = [c.x for c in cos]
        ys = [c.y for c in cos]
        zs = [c.z for c in cos]
        print("  VG %-28s n=%-4d x[%6.3f %6.3f] y[%6.3f %6.3f] z[%6.3f %6.3f]" %
              (name, len(cos), min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))

    print("--- Z BANDS (vert counts by height, 0.1m bands) ---")
    zs = [v.co.z for v in me.vertices]
    zmin, zmax = min(zs), max(zs)
    band = 0.1
    z = zmin
    while z < zmax:
        n = sum(1 for c in zs if z <= c < z + band)
        wid = [abs(v.co.x) for v in me.vertices if z <= v.co.z < z + band]
        print("  z %5.2f-%5.2f n=%-4d max|x|=%.3f" % (z, z + band, n, max(wid) if wid else 0))
        z += band

    print("--- BONE HEADS (rest, object space of rig) ---")
    for b in rig.data.bones:
        if any(k in b.name for k in ("Hips", "Spine", "Neck", "Head", "Shoulder",
                                     "Arm", "Hand", "UpLeg", "Leg", "Foot")) \
                and "Thumb" not in b.name and "Index" not in b.name:
            print("  %-28s head=%7.3f %7.3f %7.3f  len=%.3f" %
                  (b.name, b.head_local.x, b.head_local.y, b.head_local.z, b.length))
    print("PROBE02_DONE")


main()
