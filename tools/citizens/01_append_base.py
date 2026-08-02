"""Stage 01 - append the PSXRig hierarchy from RECON's us_base_v3 and strip military gear.

Source is READ-ONLY. We append the whole 'Collection' (armature + every mesh
parented to it) so no modifier or vertex group is orphaned, then delete the gear
meshes, keeping PSXRig + Base_Human.

Run:  blender -b --factory-startup --python tools/citizens/01_append_base.py
Out:  assets/models/citizens/_stage01_base.blend
"""
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (SRC_BLEND, STAGE, save_blend, purge, tri_count,
                            report_floaters, banner)

KEEP_MESHES = {"Base_Human"}
RIG_NAME = "PSXRig"


def wipe_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def append_collection():
    with bpy.data.libraries.load(SRC_BLEND, link=False) as (df, dt):
        assert "Collection" in df.collections, "source lost its 'Collection'"
        dt.collections = ["Collection"]
    col = dt.collections[0]
    bpy.context.scene.collection.children.link(col)
    return col


def main():
    banner("STAGE 01 - append base body")
    wipe_scene()
    col = append_collection()
    print("appended collection '%s' with %d objects" % (col.name, len(col.objects)))

    rig = bpy.data.objects.get(RIG_NAME)
    assert rig is not None and rig.type == 'ARMATURE', "PSXRig missing from append"
    print("rig bones=%d" % len(rig.data.bones))

    # strip everything that is not the rig or the bare body
    doomed = [ob for ob in list(bpy.data.objects)
              if ob is not rig and ob.name not in KEEP_MESHES]
    print("stripping %d gear/prop objects" % len(doomed))
    for ob in doomed:
        bpy.data.objects.remove(ob, do_unlink=True)

    body = bpy.data.objects.get("Base_Human")
    assert body is not None, "Base_Human did not survive the strip"
    assert body.parent is rig, "Base_Human lost its parent"
    assert any(m.type == 'ARMATURE' and m.object is rig for m in body.modifiers), \
        "Base_Human lost its armature modifier"

    # clear animation - masters are rest-pose only
    for ob in bpy.data.objects:
        ob.animation_data_clear()
    for act in list(bpy.data.actions):
        bpy.data.actions.remove(act)
    rig.data.pose_position = 'REST'

    purge()

    print("--- BONES (%d) ---" % len(rig.data.bones))
    for b in rig.data.bones:
        print("  BONE %-24s parent=%s" % (b.name, b.parent.name if b.parent else "-"))

    print("--- BODY ---")
    print("  tris=%d verts=%d" % (tri_count(body), len(body.data.vertices)))
    print("  dimensions=%.3f x %.3f x %.3f" % tuple(body.dimensions))
    print("  materials=%s" % [m.name if m else None for m in body.data.materials])
    print("  uv_layers=%s" % [u.name for u in body.data.uv_layers])
    print("  vgroups=%d" % len(body.vertex_groups))
    report_floaters(body)

    assert len(bpy.data.objects) == 2, "scene should hold exactly rig+body"
    save_blend(os.path.join(STAGE, "_stage01_base.blend"))
    print("STAGE01_OK")


main()
