"""Shared helpers for the Broken Provinces citizen build (headless Blender only)."""
import bpy
import bmesh
import math
import os

SRC_BLEND = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"
PROJECT = r"C:\Users\caleb\CatacombsOfGore"
CITIZENS = os.path.join(PROJECT, "assets", "models", "citizens")
# Blends and their placeholder textures live under src/, which carries the
# .gdignore. glb/ must stay outside it or Godot never sees the exports - a
# .gdignore hides every subdirectory beneath it too.
STAGE = os.path.join(CITIZENS, "src")
GLB_DIR = os.path.join(CITIZENS, "glb")
REVIEW = os.path.join(PROJECT, "docs", "design", "citizen_review")
MASTER = os.path.join(STAGE, "citizens_master.blend")

MASTERS = ("MAN", "WOMAN", "BOY", "GIRL")
GLB_NAME = {"MAN": "citizen_man.glb", "WOMAN": "citizen_woman.glb",
            "BOY": "citizen_boy.glb", "GIRL": "citizen_girl.glb"}

# material names - contract with the runtime dresser
MAT_FACE = "face_atlas_mat"
MAT_GARB = "garb_mat"
MAT_HAIR = "hair_mat"

TEX_FACE = "citizen_face_atlas_placeholder.png"
TEX_GARB = "citizen_garb_palette_placeholder.png"
TEX_HAIR = "citizen_hair_palette_placeholder.png"

# --------------------------------------------------------------------------- #
# THE ATLAS CONTRACT (ruled 2026-08-02: RECON hand-packed wins over the grid)
#
# 256x256, 8 columns x 4 rows = 32 cells of 32x64 px. Within a cell, top-origin:
#     rows  0..47  FACE rect (32x48) - the head mesh, and only the head mesh
#     rows 48..63  SKIN patch (32x16) - body, hands, feet
# The head is its own object so RECONgame/tools/bake_us_faces.py can measure the
# face rect the way it measures a grunt's: cluster the UV centroids of every
# poly on a mesh named *head* carrying a material named *face*. With head and
# body fused, the flat skin patch is the denser cluster and the bake resolves a
# 1x1 px rect and skips. The face rect is also inside that script's plausibility
# window (>=16 px, <=25% of each atlas axis) at 256, 512 or 1024 square.
# --------------------------------------------------------------------------- #
ATLAS_SIZE = 256
ATLAS_COLS = 8
ATLAS_ROWS = 4
CELL_W = ATLAS_SIZE // ATLAS_COLS      # 32
CELL_H = ATLAS_SIZE // ATLAS_ROWS      # 64
FACE_ROWS = 48                         # top of the cell
SKIN_ROWS = CELL_H - FACE_ROWS         # 16

# --------------------------------------------------------------------------- #
# THE GARB ATLAS CONTRACT (docs/design/EQ_TECHNIQUE.md sec 3.B)
#
# 512x512, 4 columns x 4 rows = 16 GARB PAGES of 128x128 px. Within a page,
# four zones of 64x64, page-local and TOP-ORIGIN:
#     (0,0)   VEST     the torso garment, front and back (robe samples it too)
#     (64,0)  PANTS    trousers AND skirt
#     (0,64)  SLEEVES  both arms
#     (64,64) EXTRA    apron and hood
#
# A page is a uv1_offset of (col*0.25, prow*0.25) exactly as a face cell is a
# uv1_offset of (col*0.125, row*0.25). PAGE 0 IS THE BOTTOM-LEFT of the image,
# and prow counts UP, because v is bottom-origin and the meshes are UV'd into
# page 0 at v < 0.25. Draw the pages any other way round and a townsman wearing
# page 5 samples the page nobody painted.
#
# Resolution-independent: 1024 square gives 128 px zones and needs no UV change,
# as long as it stays 4x4 pages of four quadrants.
# --------------------------------------------------------------------------- #
GARB_ATLAS_SIZE = 512
GARB_COLS = 4
GARB_ROWS = 4
GARB_PAGE_PX = GARB_ATLAS_SIZE // GARB_COLS        # 128
GARB_ZONE_PX = GARB_PAGE_PX // 2                   # 64
GARB_STRIDE = 1.0 / GARB_COLS                      # 0.25
GARB_PAGES = GARB_COLS * GARB_ROWS                 # 16

# Zone UV rects INSIDE PAGE 0, (u0, v0, u1, v1). The 0.005 inset is 2.56 px at
# 512 - the seam rule from the painting guide, so nearest sampling a fraction
# off never picks up the neighbouring garment.
GARB_INSET = 0.005
GARB_ZONE_UV = {
    "vest":    (0.005, 0.130, 0.120, 0.245),
    "pants":   (0.130, 0.130, 0.245, 0.245),
    "sleeves": (0.005, 0.005, 0.120, 0.120),
    "extra":   (0.130, 0.005, 0.245, 0.120),
}


def garb_page_origin_px(page):
    """Top-origin pixel corner of a garb page. Page 0 is BOTTOM-left."""
    col = page % GARB_COLS
    prow = page // GARB_COLS
    return col * GARB_PAGE_PX, (GARB_ROWS - 1 - prow) * GARB_PAGE_PX


def garb_page_uv_offset(page):
    """The uv1_offset the runtime dresser applies for a page. Mirrors
    CitizenDresser.garb_page_offset() in GDScript - the two must agree."""
    col = page % GARB_COLS
    prow = page // GARB_COLS
    return col * GARB_STRIDE, prow * GARB_STRIDE


def banner(msg):
    print("\n" + "=" * 70)
    print(msg)
    print("=" * 70)


def ensure_dirs():
    for d in (STAGE, REVIEW):
        os.makedirs(d, exist_ok=True)


def tri_count(ob):
    me = ob.data
    return sum(max(0, len(p.vertices) - 2) for p in me.polygons)


def purge():
    """Remove orphan datablocks. Disk is tight; nothing unused ships."""
    for _ in range(4):
        n = bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True,
                                           do_recursive=True)
        del n


def save_blend(path):
    ensure_dirs()
    purge()
    bpy.context.preferences.filepaths.save_version = 0  # never write .blend1
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True,
                                relative_remap=False)
    size = os.path.getsize(path) / 1024.0
    print("SAVED %s (%.0f KB)" % (path, size))


def open_stage(name):
    path = os.path.join(STAGE, name)
    assert os.path.exists(path), "missing stage file: %s" % path
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)


def report_floaters(ob, radius=3.0):
    """HUNT FLOATERS: loose islands or verts absurdly far from the object origin."""
    me = ob.data
    far = [v.index for v in me.vertices if v.co.length > radius]
    loose = [v.index for v in me.vertices
             if not any(v.index in p.vertices for p in me.polygons)] if len(me.polygons) else []
    # cheap loose-vert test via edge/face use
    used = set()
    for p in me.polygons:
        used.update(p.vertices)
    loose = [v.index for v in me.vertices if v.index not in used]
    print("  FLOATER CHECK %-24s far_verts=%d loose_verts=%d" % (ob.name, len(far), len(loose)))
    assert not far, "%s has %d verts beyond %.1fm of origin" % (ob.name, len(far), radius)
    assert not loose, "%s has %d loose verts" % (ob.name, len(loose))
    return True


def island_count(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    seen = set()
    islands = 0
    for v in bm.verts:
        if v.index in seen:
            continue
        islands += 1
        stack = [v]
        seen.add(v.index)
        while stack:
            cur = stack.pop()
            for e in cur.link_edges:
                o = e.other_vert(cur)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
    bm.free()
    return islands


def new_mesh_object(name, verts, faces, collection=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.validate()
    me.update()
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob


def flat_uv(ob, u0, v0, u1, v1):
    """Put every face of ob inside the given UV rectangle (crude planar box map)."""
    me = ob.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0]
    xs = [v.co.x for v in me.vertices]
    zs = [v.co.z for v in me.vertices]
    minx, maxx = min(xs), max(xs)
    minz, maxz = min(zs), max(zs)
    dx = (maxx - minx) or 1.0
    dz = (maxz - minz) or 1.0
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            co = me.vertices[vi].co
            fu = (co.x - minx) / dx
            fv = (co.z - minz) / dz
            uv.data[li].uv = (u0 + fu * (u1 - u0), v0 + fv * (v1 - v0))


def set_material(ob, mat):
    ob.data.materials.clear()
    ob.data.materials.append(mat)


def get_or_make_image_material(mat_name, image, alpha=False):
    mat = bpy.data.materials.get(mat_name)
    if mat is None:
        mat = bpy.data.materials.new(mat_name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfDiffuse")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = 'Closest'  # PSX: nearest neighbour, always
    tex.extension = 'CLIP' if alpha else 'REPEAT'
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    out.location = (300, 0)
    bsdf.location = (60, 0)
    tex.location = (-260, 0)
    return mat


def armature_bind(ob, rig):
    """Parent to the rig leaving the object's WORLD matrix at identity.

    The rig object carries a -90 X rotation (Mixamo Y-up); a naive parent keeps
    the mesh's own -90 basis as well and the duplicate ends up lying on its back.
    Zeroing the basis and cancelling the rig with the parent inverse makes every
    citizen mesh world-identity, which is also what the garb math assumes.
    """
    from mathutils import Matrix
    ob.parent = rig
    ob.matrix_basis = Matrix.Identity(4)
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    for m in list(ob.modifiers):
        if m.type == 'ARMATURE':
            ob.modifiers.remove(m)
    m = ob.modifiers.new("Armature", 'ARMATURE')
    m.object = rig


def weight_all_to_bone(ob, bone_name):
    vg = ob.vertex_groups.get(bone_name) or ob.vertex_groups.new(name=bone_name)
    vg.add([v.index for v in ob.data.vertices], 1.0, 'REPLACE')


def deg(x):
    return math.radians(x)


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


def unhide_all():
    for ob in bpy.data.objects:
        ob.hide_viewport = False
        ob.hide_render = False
        try:
            ob.hide_set(False)
        except RuntimeError:
            pass


def select_only(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.select_set(True)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]
