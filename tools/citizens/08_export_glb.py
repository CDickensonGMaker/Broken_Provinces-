"""Stage 08 - export one GLB per master into assets/models/citizens/glb/.

Each GLB carries its rig, the body, the head, and EVERY garb and hair variant
as separate meshes. Nothing is left out and nothing is hidden: glTF has no
visibility flag, so a mesh hidden in Blender either exports visible or does not
export at all. The RECON convention is the one that works - ship every variant
visible and let the runtime dresser hide what it does not want
(`grunt_dresser._set_visible_by_name`, RECONgame/scripts/visuals/grunt_dresser.gd:278).

The trailing _<MASTER> suffix is stripped here, because Blender object names are
file-global and glTF node names are not:

    MAN            -> citizen_body
    MAN_head       -> citizen_head      (the *head* substring is load-bearing:
                                         RECON's bake_us_faces.py finds the face
                                         mesh by that name)
    garb_pants_MAN -> garb_pants
    hair_bun_MAN   -> hair_bun

Run: blender -b --factory-startup --python tools/citizens/08_export_glb.py
Out: assets/models/citizens/glb/citizen_{man,woman,boy,girl}.glb
"""
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (MASTER, GLB_DIR, GLB_NAME, MASTERS, MAT_FACE,
                            MAT_GARB, MAT_HAIR, GARB_STRIDE, banner, tri_count,
                            unhide_all, select_only)

BODY_NAME = "citizen_body"
HEAD_NAME = "citizen_head"


def assert_garb_on_page_zero(objects):
    """Every garb mesh's UVs must fall inside PAGE 0 of the garb atlas.

    The dresser slides garb by a whole page at runtime. A garment whose UVs
    straddle a page boundary smears two outfits together the moment it moves,
    and on screen that reads as a texture bug rather than the UV bug it is - so
    it is asserted on the way OUT, on the meshes that are actually being
    written, not only on the ones stage 05 happened to build.
    """
    checked = 0
    for ob in objects:
        if not ob.name.startswith("garb_") or ob.type != 'MESH':
            continue
        assert ob.data.uv_layers, "%s has no UVs" % ob.name
        uvl = ob.data.uv_layers[0]
        us = [uvl.data[li].uv[0] for p in ob.data.polygons for li in p.loop_indices]
        vs = [uvl.data[li].uv[1] for p in ob.data.polygons for li in p.loop_indices]
        assert min(us) >= 0.0 and min(vs) >= 0.0, \
            "%s has negative UVs (u=%.4f v=%.4f)" % (ob.name, min(us), min(vs))
        assert max(us) < GARB_STRIDE and max(vs) < GARB_STRIDE, \
            "%s leaves page 0: max u=%.4f v=%.4f, stride %.2f" \
            % (ob.name, max(us), max(vs), GARB_STRIDE)
        checked += 1
    assert checked, "no garb meshes found to check"
    return checked


def assert_mesh_inventory(objects):
    """The deleted mesh stays deleted and the new one is actually there.

    Stage 05 can be re-run, but a stale `_stage05_garb.blend` or a hand-edited
    master could put garb_vest_laced back without anybody noticing until a
    citizen wore two vests. The export is the last place to catch it.
    """
    names = {ob.name for ob in objects}
    assert "garb_vest_laced" not in names, \
        "garb_vest_laced is in the export - it is a Rule-3 violation and a page now"
    assert "garb_robe" in names, "garb_robe is missing from the export"


def export_one(master):
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.open_mainfile(filepath=MASTER, load_ui=False)

    keep = bpy.data.collections[master]
    keep_objs = list(keep.objects)
    rig = bpy.data.objects[master].parent
    assert rig is not None and rig.type == 'ARMATURE', "%s has no rig" % master

    # everything that is not this master or its rig goes
    survivors = set(o.name for o in keep_objs) | {rig.name}
    for ob in list(bpy.data.objects):
        if ob.name not in survivors:
            bpy.data.objects.remove(ob, do_unlink=True)

    suffix = "_%s" % master
    for ob in keep_objs:
        if ob.name == master:
            ob.name = BODY_NAME
        elif ob.name == master + "_head":
            ob.name = HEAD_NAME
        elif ob.name.endswith(suffix):
            ob.name = ob.name[:-len(suffix)]
        ob.data.name = ob.name + "_mesh"

    assert_mesh_inventory(keep_objs)
    pages = assert_garb_on_page_zero(keep_objs)

    unhide_all()
    rig.data.pose_position = 'REST'
    select_only([rig] + keep_objs)
    selected = [o for o in bpy.data.objects if o.select_get()]
    assert len(selected) == len(keep_objs) + 1, \
        "%s: %d of %d objects would not select" % (master, len(selected),
                                                   len(keep_objs) + 1)

    os.makedirs(GLB_DIR, exist_ok=True)
    out = os.path.join(GLB_DIR, GLB_NAME[master])
    bpy.ops.export_scene.gltf(
        filepath=out,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=False,
        export_skins=True,
        export_morph=False,
        export_materials='EXPORT',
        export_cameras=False,
        export_lights=False,
        export_draco_mesh_compression_enable=False,
        export_extras=True,
    )
    tris = sum(tri_count(o) for o in keep_objs if o.type == 'MESH')
    print("EXPORT %-16s %-22s meshes=%d tris=%d bones=%d garb_on_page0=%d %.1f KB"
          % (master, GLB_NAME[master], len(keep_objs), tris,
             len(rig.data.bones), pages, os.path.getsize(out) / 1024.0))
    print("       materials: %s"
          % sorted({m.name for o in keep_objs for m in o.data.materials}))
    return out


def main():
    banner("STAGE 08 - GLB export")
    assert os.path.exists(MASTER), "run 06_build_hair.py first"
    for m in MASTERS:
        export_one(m)
    for name in ("face_atlas_mat", "garb_mat", "hair_mat"):
        assert name in (MAT_FACE, MAT_GARB, MAT_HAIR)
    print("STAGE08_OK")


main()
