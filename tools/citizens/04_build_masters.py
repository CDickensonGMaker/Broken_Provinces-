"""Stage 04 - the four citizen masters.

MAN    = the appended base body, de-geared, unchanged in shape (rest pose untouched).
WOMAN  = clone of MAN reshaped on the SAME adult rig (narrower chest/shoulders,
         wider hips, PSX-subtle chest form).
BOY    = MAN clone shrunk onto a CLONED child rig (65% uniform), head scaled
         back up so it reads as a child, not a small adult.
GIRL   = same child rig, woman-leaning silhouette at child scale.

Bone names are never renamed or restructured - the child rig is a clone with
identical names, so the Mixamo library retargets 1:1.

The head is SPLIT into its own object, <MASTER>_head, sharing face_atlas_mat
with the body. That split is the atlas ruling made structural: the head owns the
face rect of a cell and nothing else does, which is the only shape
RECONgame/tools/bake_us_faces.py can measure (it clusters the UV centroids of
polys on a mesh named *head* carrying a material named *face*). Body, hands and
feet sample the flat skin patch of the SAME cell, so one uv1_offset slides both
and a face/skin mismatch is impossible.

Run: blender -b --factory-startup --python tools/citizens/04_build_masters.py
Out: assets/models/citizens/src/_stage04_masters.blend
"""
import bmesh
import bpy
import os
import sys
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, TEX_FACE, MAT_FACE, ATLAS_SIZE, CELL_W,
                            CELL_H, FACE_ROWS,
                            open_stage, save_blend, purge, tri_count, banner,
                            report_floaters, get_or_make_image_material,
                            armature_bind, island_count, dominant_groups)

CHILD_SCALE = 0.65
CHILD_HEAD_REGAIN = 1.32

# EQ pass: the extremities carry the chunk. Perpendicular thickening about the
# limb's own bone axis, so nothing gets longer.
EQ_FOREARM = 1.16
EQ_HAND = 1.22
EQ_BOOT = 1.20

HEAD_GROUPS = {"mixamorig:Head", "mixamorig:HeadTop_End", "mixamorig:Neck"}
# The NECK stays on the body. It is skin, it samples the flat skin patch, and
# leaving it on the head made the face rect span jaw-to-collarbone: the mouth
# landed on the throat and every hair style's brow ring sat over the eyes.
SPLIT_GROUPS = {"mixamorig:Head", "mixamorig:HeadTop_End"}
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

FOOT_GROUPS = set()
for side in ("Left", "Right"):
    FOOT_GROUPS |= {"mixamorig:%sFoot" % side, "mixamorig:%sToeBase" % side,
                    "mixamorig:%sToe_End" % side}
FOREARM_GROUPS = {"mixamorig:LeftForeArm", "mixamorig:RightForeArm"}


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

def _cell_rects(col, row):
    """Face and skin rects of atlas cell (col,row) as UV bounds."""
    u0 = (col * CELL_W + 1.0) / ATLAS_SIZE
    u1 = ((col + 1) * CELL_W - 1.0) / ATLAS_SIZE

    def v_of(px_row):
        return 1.0 - (row * CELL_H + px_row) / ATLAS_SIZE

    return {
        "u0": u0, "u1": u1,
        "v_face_top": v_of(1.5),
        "v_face_bot": v_of(FACE_ROWS - 1.5),
        "u_skin": (col * CELL_W + CELL_W * 0.5) / ATLAS_SIZE,
        "v_skin": v_of(FACE_ROWS + (CELL_H - FACE_ROWS) * 0.5),
    }


def uv_head_into_face_rect(ob, col=0, row=0):
    """Front-planar wrap of the whole head object into the cell's FACE rect.

    Rear-facing verts collapse onto the rect's edge columns, which is why the
    atlas contract reserves those columns for scalp and never for features.
    """
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0]
    r = _cell_rects(col, row)

    zs = [v.co.z for v in me.vertices]
    xs = [abs(v.co.x) for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    z_bot, z_top = min(zs), max(zs)
    half_w = max(xs) or 1.0
    back_y = (min(ys) + max(ys)) * 0.5

    for poly in me.polygons:
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            zn = min(1.0, max(0.0, (co.z - z_bot) / max(1e-6, z_top - z_bot)))
            if co.y > back_y:
                u = r["u0"] if co.x < 0 else r["u1"]
            else:
                xn = min(1.0, max(0.0, co.x / (2.0 * half_w) + 0.5))
                u = r["u0"] + xn * (r["u1"] - r["u0"])
            uv.data[li].uv = (u, r["v_face_bot"] + zn * (r["v_face_top"] - r["v_face_bot"]))
    me.update()


def uv_body_into_skin_patch(ob, col=0, row=0):
    """Everything below the neck samples one flat pixel of the cell's skin patch."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0]
    r = _cell_rects(col, row)
    for poly in me.polygons:
        for li in poly.loop_indices:
            uv.data[li].uv = (r["u_skin"], r["v_skin"])
    me.update()


# --------------------------------------------------------------------------- #
# head split - the atlas ruling made structural
# --------------------------------------------------------------------------- #

def split_head(body, collection):
    """Move the all-head polys of `body` into a new <name>_head object.

    Polys that straddle the neck seam stay on the BODY, so the head object is
    open at its base and the body closes it - no hole either way. Both objects
    keep the full vertex-group list and their weights, so deformation is
    untouched.
    """
    head_idx = set(verts_in(body, SPLIT_GROUPS))
    assert head_idx, "%s has no head verts" % body.name

    head = body.copy()
    head.data = body.data.copy()
    head.name = body.name + "_head"
    head.data.name = head.name + "_mesh"
    collection.objects.link(head)

    def cull(ob, keep_head):
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        bm.verts.ensure_lookup_table()
        doomed = [f for f in bm.faces
                  if all(v.index in head_idx for v in f.verts) != keep_head]
        bmesh.ops.delete(bm, geom=doomed, context='FACES')
        loose = [v for v in bm.verts if not v.link_faces]
        if loose:
            bmesh.ops.delete(bm, geom=loose, context='VERTS')
        bm.to_mesh(ob.data)
        bm.free()
        ob.data.update()

    cull(head, True)
    cull(body, False)
    assert len(head.data.polygons), "%s head split produced no faces" % body.name
    return head


# --------------------------------------------------------------------------- #
# the EQ pass - chunk lives in the extremities
# --------------------------------------------------------------------------- #

def thicken_about_axis(ob, indices, p, d, factor):
    """Push verts away from a bone's axis without changing anything along it."""
    d = d.normalized()
    for i in indices:
        co = ob.data.vertices[i].co
        v = co - p
        along = d * v.dot(d)
        out = p + along + (v - along) * factor
        co[0], co[1], co[2] = out.x, out.y, out.z


def eq_chunk_pass(ob, rig):
    """EverQuest read: broader forearms, blockier hands, heavier boots."""
    dom = dominant_groups(ob)
    bones = rig.data.bones
    mw = rig.matrix_world      # the rig carries Mixamo's -90 X; mesh space is world
    moved = 0
    for side in ("Left", "Right"):
        pairs = (
            ({"mixamorig:%sForeArm" % side},
             "mixamorig:%sForeArm" % side, "mixamorig:%sHand" % side, EQ_FOREARM),
            ({"mixamorig:%sHand" % side} |
             {"mixamorig:%sHand%s%d" % (side, f, i)
              for f in ("Thumb", "Index") for i in (1, 2, 3, 4)},
             "mixamorig:%sHand" % side, "mixamorig:%sHandIndex1" % side, EQ_HAND),
            ({"mixamorig:%sFoot" % side, "mixamorig:%sToeBase" % side,
              "mixamorig:%sToe_End" % side},
             "mixamorig:%sFoot" % side, "mixamorig:%sToeBase" % side, EQ_BOOT),
        )
        for groups, b0, b1, factor in pairs:
            idx = [i for i, n in dom.items() if n in groups]
            if not idx or b0 not in bones or b1 not in bones:
                continue
            p = mw @ bones[b0].head_local
            d = (mw @ bones[b1].head_local) - p
            if d.length < 1e-6:
                d = (mw @ bones[b0].tail_local) - p
            thicken_about_axis(ob, idx, p, d, factor)
            moved += len(idx)
    ob.data.update()
    return moved


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

    # --- EQ pass, ADULTS ONLY -------------------------------------------- #
    # The children are clones taken above, so they keep the plain silhouette:
    # the brief forbids re-proportioning them beyond the 65% clone.
    for ob in (man, woman):
        n = eq_chunk_pass(ob, adult_rig)
        print("EQ %-6s thickened %d extremity verts "
              "(forearm x%.2f, hand x%.2f, boot x%.2f)"
              % (ob.name, n, EQ_FOREARM, EQ_HAND, EQ_BOOT))

    # --- head split + material + UV for every master ---------------------- #
    heads = {}
    for ob, rig, col in ((man, adult_rig, col_man), (woman, adult_rig, col_woman),
                         (boy, child_rig, col_boy), (girl, child_rig, col_girl)):
        head = split_head(ob, col)
        armature_bind(head, rig)
        heads[ob.name] = head
        for m in (ob, head):
            m.data.materials.clear()
            m.data.materials.append(mat_face)
        uv_head_into_face_rect(head, 0, 0)
        uv_body_into_skin_patch(ob, 0, 0)
        print("SPLIT %-6s body tris=%d  head '%s' tris=%d"
              % (ob.name, tri_count(ob), head.name, tri_count(head)))

    # --- asserts --------------------------------------------------------- #
    print("--- MASTER REPORT ---")
    for ob, rig in ((man, adult_rig), (woman, adult_rig), (boy, child_rig), (girl, child_rig)):
        head = heads[ob.name]
        t = tri_count(ob) + tri_count(head)
        h = max(v.co.z for v in head.data.vertices)
        print("  %-6s tris=%-4d (body %d + head %d) verts=%-4d height=%.3fm "
              "rig=%-14s islands=%d mats=%s"
              % (ob.name, t, tri_count(ob), tri_count(head),
                 len(ob.data.vertices) + len(head.data.vertices), h, rig.name,
                 island_count(ob), [m.name for m in ob.data.materials]))
        assert 300 <= t <= 800, "%s tri budget violated: %d" % (ob.name, t)
        for m in (ob, head):
            report_floaters(m)
            assert len(m.data.materials) == 1 and m.data.materials[0].name == MAT_FACE, \
                "%s must carry exactly face_atlas_mat" % m.name
            assert m.parent is rig, "%s not parented to %s" % (m.name, rig.name)
            assert any(x.type == 'ARMATURE' and x.object is rig for x in m.modifiers), \
                "%s lost its armature modifier" % m.name
            assert not m.data.shape_keys, "%s must have no shape keys" % m.name
            assert not any(x.type == 'SUBSURF' for x in m.modifiers), "%s has subsurf" % m.name
            assert m.matrix_world.is_identity, "%s world matrix is not identity" % m.name
            assert m.vertex_groups, "%s lost its weights" % m.name

    # the bake-script contract, checked here rather than trusted
    print("--- FACE RECT (as bake_us_faces.py would measure it) ---")
    for ob in (man, woman, boy, girl):
        head = heads[ob.name]
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
        x0, x1 = int(min(u for u, _ in inl) * ATLAS_SIZE), int(max(u for u, _ in inl) * ATLAS_SIZE) + 1
        y0, y1 = int(min(v for _, v in inl) * ATLAS_SIZE), int(max(v for _, v in inl) * ATLAS_SIZE) + 1
        tw, th = x1 - x0, y1 - y0
        print("  %-12s rect x %d-%d y %d-%d = %dx%d px  inliers %d/%d"
              % (head.name, x0, x1, y0, y1, tw, th, len(inl), len(cents)))
        assert len(inl) == len(cents), \
            "%s face polys did not cluster into one rect (%d/%d)" % (head.name, len(inl), len(cents))
        assert tw >= 16 and th >= 16, "%s face rect too small for the bake: %dx%d" % (head.name, tw, th)
        assert tw <= ATLAS_SIZE * 0.25 and th <= ATLAS_SIZE * 0.25, \
            "%s face rect too big for the bake: %dx%d" % (head.name, tw, th)

    adult_names = sorted(b.name for b in adult_rig.data.bones)
    child_names = sorted(b.name for b in child_rig.data.bones)
    assert adult_names == child_names, "child rig bone names differ from adult"
    assert all(n.startswith("mixamorig:") for n in adult_names), "non-Mixamo bone name present"
    print("  bones adult=%d child=%d (names identical)" % (len(adult_names), len(child_names)))

    man_h = max(v.co.z for v in heads["MAN"].data.vertices)
    print("  child/adult height ratio: BOY %.3f  GIRL %.3f" % (boy_h / man_h, girl_h / man_h))

    purge()
    save_blend(os.path.join(STAGE, "_stage04_masters.blend"))
    print("STAGE04_OK")


main()
