"""Stage 09 - reimport every exported GLB into a scratch scene and assert.

A log line is a claim; this re-reads the file that will actually ship. For each
GLB: one armature of 41 Mixamo bones, the expected mesh inventory, the three
contract material names, every mesh skinned to that armature, and the face rect
still measurable by RECON's bake_us_faces.py. Nothing is written to disk.

Run: blender -b --factory-startup --python tools/citizens/09_validate_glb.py
"""
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (GLB_DIR, GLB_NAME, MASTERS, MAT_FACE, MAT_GARB,
                            MAT_HAIR, ATLAS_SIZE, GARB_STRIDE, banner, tri_count)

EXPECT_BONES = 41

BASE = {"citizen_body", "citizen_head"}
GARB = {"garb_vest_plain", "garb_robe", "garb_pants", "garb_sleeve_long",
        "garb_sleeve_rolled", "garb_sleeve_none", "garb_apron", "garb_hood"}

# Meshes that must NOT come back. garb_vest_laced was a 4-quad strip on a vest
# that already had that silhouette; it is a painted page now, and a stale stage
# file must not be able to reintroduce it (EQ_TECHNIQUE sec 3.D).
FORBIDDEN = {"garb_vest_laced"}
MALE_HAIR = {"hair_short_crop", "hair_side_part", "hair_shaggy"}
FEMALE_HAIR = {"hair_long_straight", "hair_long_braid", "hair_bun", "hair_shoulder"}


def expected(master):
    female = master in ("WOMAN", "GIRL")
    names = set(BASE) | set(GARB) | (FEMALE_HAIR if female else MALE_HAIR)
    if female:
        names.add("garb_skirt")
    return names


def base_name(n):
    """glTF import may suffix a duplicate name with .001; the contract is the stem."""
    return n.split(".")[0]


def face_rect(head):
    uvl = head.data.uv_layers[0]
    cents = []
    for p in head.data.polygons:
        us = [uvl.data[li].uv[0] for li in p.loop_indices]
        vs = [uvl.data[li].uv[1] for li in p.loop_indices]
        cents.append((sum(us) / len(us), sum(vs) / len(vs)))
    best, best_n = None, -1
    for cu, cv in cents:
        n = sum(1 for u, v in cents if abs(u - cu) < 0.09 and abs(v - cv) < 0.11)
        if n > best_n:
            best, best_n = (cu, cv), n
    inl = [(u, v) for u, v in cents
           if abs(u - best[0]) < 0.09 and abs(v - best[1]) < 0.11]
    x0 = int(min(u for u, _ in inl) * ATLAS_SIZE)
    x1 = int(max(u for u, _ in inl) * ATLAS_SIZE) + 1
    y0 = int(min(v for _, v in inl) * ATLAS_SIZE)
    y1 = int(max(v for _, v in inl) * ATLAS_SIZE) + 1
    return x1 - x0, y1 - y0, len(inl), len(cents)


def validate(master):
    path = os.path.join(GLB_DIR, GLB_NAME[master])
    assert os.path.exists(path), "missing export: %s" % path
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)

    rigs = [o for o in bpy.data.objects if o.type == 'ARMATURE']
    assert len(rigs) == 1, "%s carries %d armatures" % (master, len(rigs))
    rig = rigs[0]
    bones = sorted(b.name for b in rig.data.bones)
    assert len(bones) == EXPECT_BONES, \
        "%s bone count %d, expected %d" % (master, len(bones), EXPECT_BONES)
    assert all(b.startswith("mixamorig:") for b in bones), \
        "%s has non-Mixamo bone names: %s" % (
            master, [b for b in bones if not b.startswith("mixamorig:")])

    # Blender 5's glTF importer spawns an "Icosphere" and hands it to the leaf
    # bones as a custom display shape. It is viewport furniture, it is in no
    # exported file, and it is not part of the inventory.
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o.parent is rig]
    shapes = {pb.custom_shape for pb in rig.pose.bones if pb.custom_shape}
    strays = [o for o in bpy.data.objects
              if o.type == 'MESH' and o not in meshes and o not in shapes]
    assert not strays, "%s imported unaccounted meshes: %s" % (
        master, [o.name for o in strays])
    got = {base_name(o.name) for o in meshes}
    want = expected(master)
    assert got == want, ("%s mesh inventory mismatch\n  missing: %s\n  extra:   %s"
                         % (master, sorted(want - got), sorted(got - want)))
    back = got & FORBIDDEN
    assert not back, \
        "%s: %s came back through a stale stage file" % (master, sorted(back))

    mats = set()
    tris = 0
    garb_checked = 0
    for ob in meshes:
        tris += tri_count(ob)
        assert len(ob.data.materials) == 1, \
            "%s/%s carries %d materials" % (master, ob.name, len(ob.data.materials))
        mats.add(base_name(ob.data.materials[0].name))
        assert any(m.type == 'ARMATURE' and m.object is rig for m in ob.modifiers), \
            "%s/%s is not skinned to the armature" % (master, ob.name)
        assert ob.vertex_groups, "%s/%s lost its weights" % (master, ob.name)
        assert ob.data.uv_layers, "%s/%s lost its UVs" % (master, ob.name)

        # THE PAGE-0 LAW, re-read off the file that ships. The dresser slides
        # garb a whole page at runtime; UVs that straddle a boundary smear two
        # outfits together and look like a shader bug for a week.
        if base_name(ob.name).startswith("garb_"):
            uvl = ob.data.uv_layers[0]
            us = [uvl.data[li].uv[0] for p in ob.data.polygons for li in p.loop_indices]
            vs = [uvl.data[li].uv[1] for p in ob.data.polygons for li in p.loop_indices]
            assert min(us) >= 0.0 and min(vs) >= 0.0, \
                "%s/%s has negative UVs" % (master, ob.name)
            assert max(us) < GARB_STRIDE and max(vs) < GARB_STRIDE, \
                "%s/%s leaves garb page 0: max u=%.4f v=%.4f (stride %.2f)" \
                % (master, ob.name, max(us), max(vs), GARB_STRIDE)
            garb_checked += 1

    assert garb_checked, "%s exported no garb meshes" % master
    assert mats == {MAT_FACE, MAT_GARB, MAT_HAIR}, \
        "%s materials are %s, expected the three contract names" % (master, sorted(mats))

    head = next(o for o in meshes if base_name(o.name) == "citizen_head")
    tw, th, inl, tot = face_rect(head)
    assert inl == tot, "%s face polys no longer cluster (%d/%d)" % (master, inl, tot)
    assert 16 <= tw <= ATLAS_SIZE * 0.25 and 16 <= th <= ATLAS_SIZE * 0.25, \
        "%s face rect %dx%d is outside bake_us_faces.py's window" % (master, tw, th)

    print("OK %-6s %-18s meshes=%-2d tris=%-4d bones=%d garb_page0=%d mats=%s face_rect=%dx%d"
          % (master, GLB_NAME[master], len(meshes), tris, len(bones),
             garb_checked, ",".join(sorted(mats)), tw, th))
    for ob in sorted(meshes, key=lambda o: o.name):
        print("     %-22s tris=%-4d verts=%-4d mat=%s"
              % (base_name(ob.name), tri_count(ob), len(ob.data.vertices),
                 base_name(ob.data.materials[0].name)))


def main():
    banner("STAGE 09 - GLB validation (reimport, assert, write nothing)")
    for m in MASTERS:
        validate(m)
    print("STAGE09_OK")


main()
