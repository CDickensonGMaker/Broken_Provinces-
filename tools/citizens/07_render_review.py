"""Stage 07 - review renders. EEVEE, flat light, transparent background, small.

  citizen_turnaround_<MASTER>.png  front / 3-quarter / side / back
  citizen_variant_wall.png         garb toggles and hair styles on man and woman
  citizen_scale_check.png          child beside adult

The masters are rest-pose, so a plain copy of the mesh data renders identically
to the rigged object - no evaluation, no armature, nothing to go stale.

Run: blender -b --factory-startup --python tools/citizens/07_render_review.py
"""
import bpy
import math
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import MASTER, REVIEW, MASTERS, ensure_dirs, banner, tri_count

SLOT_W = 0.95
ROW_H = 2.05


def clear_render_scene():
    for ob in list(bpy.data.objects):
        if ob.name.startswith("_rv_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    for c in list(bpy.data.curves):
        if c.name.startswith("_rv_"):
            bpy.data.curves.remove(c)


def stamp(names, x, z, rot_z=0.0, label=None):
    """Drop flat copies of the named objects into the review scene at a slot."""
    made = []
    for n in names:
        src = bpy.data.objects.get(n)
        assert src is not None, "missing object for review: %s" % n
        ob = bpy.data.objects.new("_rv_%s_%d" % (n, len(bpy.data.objects)), src.data)
        bpy.context.scene.collection.objects.link(ob)
        ob.rotation_euler = (0.0, 0.0, rot_z)
        ob.location = (x, 0.0, z)
        made.append(ob)
    if label:
        cu = bpy.data.curves.new("_rv_txt_%s" % label, type='FONT')
        cu.body = label
        cu.size = 0.055
        cu.align_x = 'CENTER'
        ob = bpy.data.objects.new("_rv_label_%s_%d" % (label, len(bpy.data.objects)), cu)
        bpy.context.scene.collection.objects.link(ob)
        ob.location = (x, -0.6, z - 0.16)
        ob.rotation_euler = (math.pi / 2, 0, 0)
        ink = bpy.data.materials.get("_rv_ink")
        if ink is None:
            ink = bpy.data.materials.new("_rv_ink")
            ink.use_nodes = True
            nt = ink.node_tree
            nt.nodes.clear()
            out = nt.nodes.new("ShaderNodeOutputMaterial")
            em = nt.nodes.new("ShaderNodeEmission")
            em.inputs[0].default_value = (0.05, 0.04, 0.04, 1.0)
            em.inputs[1].default_value = 1.0
            nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        cu.materials.append(ink)
        made.append(ob)
    return made


def setup_world():
    scene = bpy.context.scene
    for name in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'):
        try:
            scene.render.engine = name
            break
        except TypeError:
            continue
    print("render engine: %s" % scene.render.engine)
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.compression = 90
    if scene.world is None:
        scene.world = bpy.data.worlds.new("ReviewWorld")
    w = scene.world
    w.use_nodes = True
    bg = w.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (1.0, 1.0, 1.0, 1.0)
        bg.inputs[1].default_value = 0.85     # flat and shadowless, not blown out
    if hasattr(scene, "view_settings"):
        try:
            scene.view_settings.view_transform = 'Standard'
        except TypeError:
            pass


def camera_over(x0, x1, z0, z1, width, height, name="_rv_cam"):
    cam_data = bpy.data.cameras.new(name)
    cam_data.type = 'ORTHO'
    cx = (x0 + x1) * 0.5
    cz = (z0 + z1) * 0.5
    span_x = (x1 - x0)
    span_z = (z1 - z0)
    # ortho_scale always maps to the LONGER pixel axis, so both spans must be
    # converted into that axis before taking the max - getting this backwards
    # silently crops the top row off a portrait sheet.
    longest = float(max(width, height))
    cam_data.ortho_scale = max(span_x * longest / width,
                               span_z * longest / height) * 1.02
    cam = bpy.data.objects.new(name, cam_data)
    bpy.context.scene.collection.objects.link(cam)
    cam.location = (cx, -8.0, cz)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    bpy.context.scene.camera = cam
    scene = bpy.context.scene
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    return cam


def render_to(path):
    ensure_dirs()
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER %s (%.1f KB)" % (path, os.path.getsize(path) / 1024.0))


def hide_everything_real():
    for ob in bpy.data.objects:
        ob.hide_render = not ob.name.startswith("_rv_")


def turnaround(master):
    clear_render_scene()
    views = [(0.0, "front"), (math.radians(225), "3-quarter"),
             (math.radians(90), "side"), (math.radians(180), "back")]
    for i, (rot, label) in enumerate(views):
        stamp([master], i * SLOT_W, 0.0, rot, "%s %s" % (master.lower(), label))
    hide_everything_real()
    camera_over(-SLOT_W * 0.55, SLOT_W * 3.55, -0.30, 1.95, 512, 288)
    render_to(os.path.join(REVIEW, "citizen_turnaround_%s.png" % master))


GARB_SETS = {
    "MAN": [
        (["garb_vest_plain_MAN", "garb_pants_MAN", "garb_sleeve_long_MAN"], "vest+pants+long"),
        (["garb_vest_laced_MAN", "garb_pants_MAN", "garb_sleeve_rolled_MAN"], "laced+rolled"),
        (["garb_vest_plain_MAN", "garb_pants_MAN", "garb_sleeve_none_MAN",
          "garb_apron_MAN"], "apron+sleeveless"),
        (["garb_vest_plain_MAN", "garb_pants_MAN", "garb_hood_MAN"], "hood"),
    ],
    "WOMAN": [
        (["garb_vest_plain_WOMAN", "garb_pants_WOMAN", "garb_sleeve_long_WOMAN"], "vest+pants+long"),
        (["garb_vest_laced_WOMAN", "garb_skirt_WOMAN", "garb_sleeve_rolled_WOMAN"], "laced+skirt"),
        (["garb_vest_plain_WOMAN", "garb_skirt_WOMAN", "garb_sleeve_none_WOMAN",
          "garb_apron_WOMAN"], "apron+sleeveless"),
        (["garb_vest_plain_WOMAN", "garb_skirt_WOMAN", "garb_hood_WOMAN"], "hood"),
    ],
}

HAIR_SETS = {
    "MAN": ["hair_short_crop_MAN", "hair_side_part_MAN", "hair_shaggy_MAN"],
    "WOMAN": ["hair_long_straight_WOMAN", "hair_long_braid_WOMAN",
              "hair_bun_WOMAN", "hair_shoulder_WOMAN"],
}


def variant_wall():
    clear_render_scene()
    rows = []
    for master in ("MAN", "WOMAN"):
        rows.append([(([master] + names), lbl) for names, lbl in GARB_SETS[master]])
        rows.append([([master, h], h.rsplit("_", 1)[0].replace("hair_", ""))
                     for h in HAIR_SETS[master]])
    ncol = max(len(r) for r in rows)
    for ri, row in enumerate(rows):
        z = -ri * ROW_H
        for ci, (names, lbl) in enumerate(row):
            stamp(names, ci * SLOT_W, z, 0.0, lbl)
    hide_everything_real()
    camera_over(-SLOT_W * 0.55, SLOT_W * (ncol - 1) + SLOT_W * 0.55,
                -(len(rows) - 1) * ROW_H - 0.30, 1.95, 512, 640)
    render_to(os.path.join(REVIEW, "citizen_variant_wall.png"))


def scale_check():
    clear_render_scene()
    for i, m in enumerate(MASTERS):
        stamp([m], i * SLOT_W, 0.0, 0.0, m.lower())
    # and one dressed child beside one dressed adult, the read that matters
    stamp(["MAN", "garb_vest_plain_MAN", "garb_pants_MAN", "garb_sleeve_long_MAN",
           "hair_short_crop_MAN"], 4.6 * SLOT_W, 0.0, 0.0, "man dressed")
    stamp(["BOY", "garb_vest_plain_BOY", "garb_pants_BOY", "garb_sleeve_rolled_BOY",
           "hair_shaggy_BOY"], 5.5 * SLOT_W, 0.0, 0.0, "boy dressed")
    stamp(["WOMAN", "garb_vest_laced_WOMAN", "garb_skirt_WOMAN",
           "hair_long_braid_WOMAN"], 6.4 * SLOT_W, 0.0, 0.0, "woman dressed")
    stamp(["GIRL", "garb_vest_plain_GIRL", "garb_skirt_GIRL",
           "hair_bun_GIRL"], 7.3 * SLOT_W, 0.0, 0.0, "girl dressed")
    hide_everything_real()
    camera_over(-SLOT_W * 0.55, SLOT_W * 7.85, -0.30, 1.95, 512, 224)
    render_to(os.path.join(REVIEW, "citizen_scale_check.png"))


def inventory_dump():
    """Numbers for REVIEW.md, printed so the doc is never written from memory."""
    print("--- INVENTORY ---")
    for master in MASTERS:
        col = bpy.data.collections[master]
        body = bpy.data.objects[master]
        rig = body.parent
        print("INV_MASTER %s rig=%s bones=%d height=%.3f" %
              (master, rig.name, len(rig.data.bones),
               max(v.co.z for v in body.data.vertices)))
        for ob in sorted(col.objects, key=lambda o: o.name):
            print("INV_MESH %s|%s|%d|%d|%s" %
                  (master, ob.name, tri_count(ob), len(ob.data.vertices),
                   ob.data.materials[0].name if ob.data.materials else "-"))
    print("INV_MATERIALS %s" % ",".join(sorted(m.name for m in bpy.data.materials
                                               if not m.name.startswith("_rv_"))))


def main():
    banner("STAGE 07 - review renders")
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.open_mainfile(filepath=MASTER, load_ui=False)
    inventory_dump()
    setup_world()
    for m in MASTERS:
        turnaround(m)
    variant_wall()
    scale_check()
    print("STAGE07_OK")


main()
