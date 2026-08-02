"""Probe a .blend read-only: objects, hierarchy, meshes, tris, armatures, bones, materials.

Run: blender -b --factory-startup --python tools/citizens/00_probe_source.py -- <blend> [<out.txt>]
Never writes to the probed file.
"""
import bpy
import sys

DEFAULT = r"C:\Users\caleb\RECONgame\assets\us\characters\us_base_v3.blend"


def argv_after_dashes():
    if "--" in sys.argv:
        return sys.argv[sys.argv.index("--") + 1:]
    return []


def main():
    args = argv_after_dashes()
    src = args[0] if args else DEFAULT
    out = args[1] if len(args) > 1 else None
    lines = []

    def p(s):
        lines.append(s)
        print(s)

    bpy.ops.wm.open_mainfile(filepath=src, load_ui=False)
    p("=== FILE: %s ===" % src)
    p("objects=%d meshes=%d armatures=%d materials=%d actions=%d collections=%d"
      % (len(bpy.data.objects), len(bpy.data.meshes), len(bpy.data.armatures),
         len(bpy.data.materials), len(bpy.data.actions), len(bpy.data.collections)))

    p("--- ARMATURES ---")
    for ob in bpy.data.objects:
        if ob.type == 'ARMATURE':
            arm = ob.data
            p("ARM obj=%-28s data=%-24s bones=%d users=%d" %
              (ob.name, arm.name, len(arm.bones), arm.users))

    p("--- MESH OBJECTS (name | tris | verts | parent | modifiers | materials | collections) ---")
    rows = []
    for ob in bpy.data.objects:
        if ob.type != 'MESH':
            continue
        me = ob.data
        tris = sum(max(0, len(poly.vertices) - 2) for poly in me.polygons)
        mods = ",".join(m.type for m in ob.modifiers) or "-"
        mats = ",".join(m.name if m else "None" for m in me.materials) or "-"
        cols = ",".join(c.name for c in ob.users_collection) or "-"
        par = ob.parent.name if ob.parent else "-"
        rows.append((tris, ob.name, len(me.vertices), par, mods, mats, cols))
    rows.sort(reverse=True)
    for tris, name, nv, par, mods, mats, cols in rows:
        p("MESH %-34s tris=%-6d v=%-6d parent=%-22s mods=%-14s mats=%s | col=%s"
          % (name, tris, nv, par, mods, mats, cols))
    p("TOTAL_MESH_OBJECTS=%d TOTAL_TRIS=%d" % (len(rows), sum(r[0] for r in rows)))

    p("--- COLLECTIONS ---")
    for c in bpy.data.collections:
        p("COL %-28s objects=%d children=%d" % (c.name, len(c.objects), len(c.children)))

    if out:
        with open(out, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
    print("PROBE_DONE")


main()
