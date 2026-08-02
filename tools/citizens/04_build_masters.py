"""Stage 04 - the four citizen masters.

MAN    = the appended base body, de-geared, unchanged in shape (rest pose untouched).
WOMAN  = clone of MAN reshaped on the SAME adult rig (narrower chest/shoulders,
         wider hips, PSX-subtle chest form).
BOY    = MAN clone shrunk onto a CLONED child rig (65% uniform), head scaled
         back up so it reads as a child, not a small adult.
GIRL   = same child rig, woman-leaning silhouette at child scale.

Bone names are never renamed or restructured - the child rig is a clone with
identical names, so the Mixamo library retargets 1:1.

Every body carries ONE material (face_atlas_mat) and is UV'd into atlas cell
(0,0): head+neck into the face sub-rect, hands and the rest of the skin into the
flat skin patch under it. Sliding uv1_offset by one cell moves face and skin
together - mismatch is impossible.

Run: blender -b --factory-startup --python tools/citizens/04_build_masters.py
Out: assets/models/citizens/_stage04_masters.blend
"""
import bpy
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, TEX_FACE, MAT_FACE, ATLAS_COLS, ATLAS_ROWS,
                            open_stage, save_blend, purge, tri_count, banner,
                            report_floaters, get_or_make_image_material,
                            armature_bind, island_count)

ATLAS_SIZE = 256
CELL_W = ATLAS_SIZE // ATLAS_COLS
CELL_H = ATLAS_SIZE // ATLAS_ROWS

CHILD_SCALE = 0.65
CHILD_HEAD_REGAIN = 1.32

HEAD_GROUPS = {"mixamorig:Head", "mixamorig:HeadTop_End", "mixamorig:Neck"}
HAND_GROUPS = set()
for side in ("Left", "Right"):
    HAND_GROUPS.add("mixamorig:%sHand" % side)
    for f in ("Thumb", "Index"):
        for i in (1, 2, 3, 4):
            HAND_GROUPS.add("mixamorig:%sHand%s%d" % (side, f, i))
ARM_GROUPS = set()
for side in ("Left", "Right"):
    ARM_GROUPS |= {"mixamorig:%sArm" % side, "mixamorig:%sForeArm" % side,
                   "mixamorig:%sShoulder" % side}
ARM_GROUPS |= HAND_GROUPS


# --------------------------------------------------------------------------- #
# helpers
# --------------------------------------------------------------------------- #

def dominant_groups(ob):
    """vertex index -> name of its heaviest vertex group."""
    names = {vg.index: vg.name for vg in ob.vertex_groups}
    out = {}
    for v in ob.data.vertices:
        best = None
        for g in v.groups:
            if best is None or g.weight > best.weight:
                best = g
        out[v.index] = names.get(best.group) if best else None
    return out


def verts_in(ob, groups):
    dom = dominant_groups(ob)
    return [i for i, n in dom.items() if n in groups]


def scale_x(ob, indices, factor):
    for i in indices:
        ob.data.vertices[i].co.x *= factor


def offset_inboard(ob, indices, amount):
    """Move verts toward the body centreline without changing limb length."""
    for i in indices:
        co = ob.data.vertices[i].co
        if co.x > 0:
            co.x -= amount
        elif co.x < 0:
            co.x += amount


def duplicate_mesh_object(src, new_name, collection):
    ob = src.copy()
    ob.data = src.data.copy()
    ob.name = new_name
    ob.data.name = new_name + "_mesh"
    collection.objects.link(ob)
    return ob


def get_collection(name):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(col)
    return col


def move_to_collection(ob, col):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    col.objects.link(ob)


# --------------------------------------------------------------------------- #
# UV: one atlas cell per citizen, face on top, skin patch below
# --------------------------------------------------------------------------- #

def uv_body_into_cell(ob, col=0, row=0):
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0]

    u0 = (col * CELL_W) / ATLAS_SIZE
    u1 = ((col + 1) * CELL_W - 1) / ATLAS_SIZE
    # image rows are top-origin; UV v is bottom-origin
    def v_of(px_row):
        return 1.0 - (row * CELL_H + px_row) / ATLAS_SIZE

    v_face_top = v_of(1)
    v_face_bot = v_of(23)
    v_skin = v_of(30)
    u_skin = (col * CELL_W + 12.5) / ATLAS_SIZE

    head_idx = set(verts_in(ob, HEAD_GROUPS))
    if not head_idx:
        raise AssertionError("%s has no head verts" % ob.name)
    zs = [me.vertices[i].co.z for i in head_idx]
    xs = [abs(me.vertices[i].co.x) for i in head_idx]
    ys = [me.vertices[i].co.y for i in head_idx]
    z_bot, z_top = min(zs), max(zs)
    half_w = max(xs) or 1.0
    back_y = (min(ys) + max(ys)) * 0.5

    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            if vi in head_idx:
                co = me.vertices[vi].co
                zn = min(1.0, max(0.0, (co.z - z_bot) / max(1e-6, z_top - z_bot)))
                if co.y > back_y:                      # back of head -> edge columns
                    u = u0 + 0.0015 if co.x < 0 else u1 - 0.0015
                else:
                    xn = min(1.0, max(0.0, co.x / (2.0 * half_w) + 0.5))
                    u = u0 + xn * (u1 - u0)
                uv.data[li].uv = (u, v_face_bot + zn * (v_face_top - v_face_bot))
            else:
                # hands, limbs, torso, feet: the flat skin patch of the SAME cell
                uv.data[li].uv = (u_skin, v_skin)
    me.update()
    return len(head_idx)


# --------------------------------------------------------------------------- #
# shape work
# --------------------------------------------------------------------------- #

def reshape_female(ob, hips=1.16, chest_narrow=0.90, waist=0.92,
                   thigh=1.06, bust=0.022, arm_inboard=0.015):
    dom = dominant_groups(ob)

    def idx(*names):
        return [i for i, n in dom.items() if n in names]

    scale_x(ob, idx("mixamorig:Spine2"), chest_narrow)
    scale_x(ob, idx("mixamorig:Spine1"), (chest_narrow + 1.0) * 0.5)
    scale_x(ob, idx("mixamorig:Spine"), waist)
    scale_x(ob, idx("mixamorig:Hips"), hips)
    scale_x(ob, idx("mixamorig:LeftUpLeg", "mixamorig:RightUpLeg"), thigh)
    offset_inboard(ob, [i for i, n in dom.items() if n in ARM_GROUPS], arm_inboard)

    if bust:
        # PSX-subtle: a forward nudge on the chest ring, front faces only
        for i in idx("mixamorig:Spine1", "mixamorig:Spine2"):
            co = ob.data.vertices[i].co
            if co.y < 0.0 and abs(co.x) < 0.16 and 1.30 < co.z < 1.48:
                co.y -= bust
    ob.data.update()


def shrink_to_child(ob, scale=CHILD_SCALE, head_regain=CHILD_HEAD_REGAIN):
    """Uniform shrink, then give the head back so the child reads as a child."""
    head_idx = set(verts_in(ob, HEAD_GROUPS))
    for v in ob.data.vertices:
        v.co *= scale
    zs = [ob.data.vertices[i].co.z for i in head_idx]
    pivot_z = min(zs)
    for i in head_idx:
        co = ob.data.vertices[i].co
        co.x *= head_regain
        co.y *= head_regain
        co.z = pivot_z + (co.z - pivot_z) * head_regain
    ob.data.update()
    return max(v.co.z for v in ob.data.vertices)


def clone_child_rig(adult_rig, name="PSXRig_child", scale=CHILD_SCALE,
                    head_regain=CHILD_HEAD_REGAIN):
    rig = adult_rig.copy()
    rig.data = adult_rig.data.copy()
    rig.name = name
    rig.data.name = name + "_arm"
    bpy.context.scene.collection.objects.link(rig)
    rig.hide_viewport = False
    rig.hide_set(False)
    adult_rig.hide_viewport = False
    adult_rig.hide_set(False)

    bpy.context.view_layer.objects.active = rig
    for ob in bpy.context.selected_objects:
        ob.select_set(False)
    rig.select_set(True)

    # Scale the OBJECT and bake it. Walking edit_bones and multiplying head/tail
    # by hand corrupts a connected chain - setting a child's head drags the
    # parent's tail, so the result depends on iteration order. That produced a
    # child rig whose arm bones were nowhere near the arms, and the sleeves
    # built from those bones ballooned to twice the child's width.
    rig.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

    bpy.ops.object.mode_set(mode='EDIT')
    ebs = rig.data.edit_bones
    head_eb = ebs.get("mixamorig:Head")
    top_eb = ebs.get("mixamorig:HeadTop_End")
    assert head_eb is not None and top_eb is not None, "head chain missing on clone"
    top_vec = (top_eb.tail - top_eb.head) * head_regain
    base = head_eb.head.copy()
    head_eb.tail = base + (head_eb.tail - base) * head_regain
    top_eb.head = head_eb.tail.copy()
    top_eb.tail = top_eb.head + top_vec
    names = sorted(eb.name for eb in ebs)
    bpy.ops.object.mode_set(mode='OBJECT')

    adult_names = sorted(b.name for b in adult_rig.data.bones)
    assert names == adult_names, "child rig bone names drifted from the adult rig"

    # the geometry guard the first attempt lacked
    for b in adult_rig.data.bones:
        if b.name in ("mixamorig:Head", "mixamorig:HeadTop_End"):
            continue
        want = b.head_local * scale
        got = rig.data.bones[b.name].head_local
        assert (want - got).length < 1e-4, \
            "child bone %s at %s, expected %s" % (b.name, tuple(got), tuple(want))
    rig.data.pose_position = 'REST'
    return rig


# --------------------------------------------------------------------------- #

def main():
    banner("STAGE 04 - build MAN / WOMAN / BOY / GIRL")
    open_stage("_stage01_base.blend")

    adult_rig = bpy.data.objects["PSXRig"]
    body = bpy.data.objects["Base_Human"]

    # the face/skin material - one image, nearest neighbour, PSX stock
    img_path = os.path.join(STAGE, TEX_FACE)
    assert os.path.exists(img_path), "run 03_make_textures.py first"
    img = bpy.data.images.get(TEX_FACE)
    if img is None:
        img = bpy.data.images.load(img_path)
        img.name = TEX_FACE
    mat_face = get_or_make_image_material(MAT_FACE, img)

    # drop the RECON grunt material and its heavy textures
    for m in list(bpy.data.materials):
        if m is not mat_face:
            bpy.data.materials.remove(m)
    for i in list(bpy.data.images):
        if i is not img and i.name not in ("Render Result", "Viewer Node"):
            bpy.data.images.remove(i)

    col_rigs = get_collection("RIGS")
    move_to_collection(adult_rig, col_rigs)

    # --- MAN ------------------------------------------------------------- #
    body.name = "MAN"
    body.data.name = "MAN_mesh"
    col_man = get_collection("MAN")
    move_to_collection(body, col_man)
    man = body
    armature_bind(man, adult_rig)   # normalise to world identity like the rest

    # --- WOMAN ----------------------------------------------------------- #
    col_woman = get_collection("WOMAN")
    woman = duplicate_mesh_object(man, "WOMAN", col_woman)
    armature_bind(woman, adult_rig)
    reshape_female(woman)

    # --- child rig ------------------------------------------------------- #
    child_rig = clone_child_rig(adult_rig)
    move_to_collection(child_rig, col_rigs)

    # --- BOY ------------------------------------------------------------- #
    col_boy = get_collection("BOY")
    boy = duplicate_mesh_object(man, "BOY", col_boy)
    armature_bind(boy, child_rig)
    boy_h = shrink_to_child(boy)

    # --- GIRL ------------------------------------------------------------ #
    col_girl = get_collection("GIRL")
    girl = duplicate_mesh_object(man, "GIRL", col_girl)
    armature_bind(girl, child_rig)
    # a child silhouette, not a small woman: shoulders only, no bust, no hips
    reshape_female(girl, hips=1.02, chest_narrow=0.94, waist=0.96,
                   thigh=1.0, bust=0.0, arm_inboard=0.008)
    girl_h = shrink_to_child(girl)

    # --- material + UV for every master ---------------------------------- #
    for ob in (man, woman, boy, girl):
        ob.data.materials.clear()
        ob.data.materials.append(mat_face)
        n_head = uv_body_into_cell(ob, 0, 0)
        print("UV %-6s head/neck verts=%d -> face rect of atlas cell (0,0)" % (ob.name, n_head))

    # --- asserts --------------------------------------------------------- #
    print("--- MASTER REPORT ---")
    for ob, rig in ((man, adult_rig), (woman, adult_rig), (boy, child_rig), (girl, child_rig)):
        t = tri_count(ob)
        h = max(v.co.z for v in ob.data.vertices)
        print("  %-6s tris=%-4d verts=%-4d height=%.3fm rig=%-14s islands=%d mats=%s"
              % (ob.name, t, len(ob.data.vertices), h, rig.name,
                 island_count(ob), [m.name for m in ob.data.materials]))
        report_floaters(ob)
        assert 300 <= t <= 800, "%s tri budget violated: %d" % (ob.name, t)
        assert len(ob.data.materials) == 1, "%s must carry exactly one material" % ob.name
        assert ob.parent is rig, "%s not parented to %s" % (ob.name, rig.name)
        assert any(m.type == 'ARMATURE' and m.object is rig for m in ob.modifiers), \
            "%s lost its armature modifier" % ob.name
        assert not ob.data.shape_keys, "%s must have no shape keys" % ob.name
        assert not any(m.type == 'SUBSURF' for m in ob.modifiers), "%s has subsurf" % ob.name
        assert ob.matrix_world.is_identity, "%s world matrix is not identity" % ob.name

    adult_names = sorted(b.name for b in adult_rig.data.bones)
    child_names = sorted(b.name for b in child_rig.data.bones)
    assert adult_names == child_names, "child rig bone names differ from adult"
    assert all(n.startswith("mixamorig:") for n in adult_names), "non-Mixamo bone name present"
    print("  bones adult=%d child=%d (names identical)" % (len(adult_names), len(child_names)))

    man_h = max(v.co.z for v in man.data.vertices)
    print("  child/adult height ratio: BOY %.3f  GIRL %.3f" % (boy_h / man_h, girl_h / man_h))

    purge()
    save_blend(os.path.join(STAGE, "_stage04_masters.blend"))
    print("STAGE04_OK")


main()
