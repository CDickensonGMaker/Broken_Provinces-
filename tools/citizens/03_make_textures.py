"""Stage 03 - generate the placeholder textures the citizen masters are UV'd against.

Three PNGs, all nearest-neighbour PSX stock, all tiny:
  citizen_face_atlas_placeholder.png  256x256, an 8x4 grid of 32x64 cells.
      Cell rows 0-47 are the FACE rect (the head mesh alone samples it), rows
      48-63 the flat SKIN patch (body, hands, feet), so one uv1_offset slides
      face and skin together and a mismatch is impossible.
  citizen_garb_palette_placeholder.png 512x512, a 4x4 grid of 128 px GARB PAGES,
      four 64 px zones per page (vest, pants, sleeves, extra). A garment variant
      is a uv1_offset into this atlas exactly as a face is - one mesh, sixteen
      colourways, zero extra triangles (docs/design/EQ_TECHNIQUE.md).
  citizen_hair_palette_placeholder.png 32x32, four flat hair colour strips.

Caleb replaces the face atlas with real painted faces later; the CELL GRID is
the contract, not the pixels, and it is resolution-independent - 512 or 1024
square works with the same UVs as long as the grid stays 8x4 and the cell stays
three-quarters face over one-quarter skin.

Run: blender -b --factory-startup --python tools/citizens/03_make_textures.py
"""
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, TEX_FACE, TEX_GARB, TEX_HAIR, ATLAS_COLS,
                            ATLAS_ROWS, ATLAS_SIZE, CELL_W, CELL_H, FACE_ROWS,
                            GARB_ATLAS_SIZE, GARB_PAGE_PX, GARB_ZONE_PX,
                            GARB_STRIDE, GARB_PAGES as GARB_PAGE_COUNT,
                            garb_page_origin_px, garb_page_uv_offset,
                            ensure_dirs, banner)

SKIN_TONES = [
    (0.94, 0.78, 0.66), (0.88, 0.71, 0.57), (0.82, 0.64, 0.50),
    (0.75, 0.57, 0.44), (0.66, 0.49, 0.37), (0.56, 0.41, 0.30),
    (0.45, 0.32, 0.24), (0.34, 0.24, 0.18),
]

# --------------------------------------------------------------------------- #
# THE SIXTEEN GARB PAGES
#
# Every page is a COLOURWAY, not a garment: the same four meshes at a different
# uv1_offset. Each entry is (label, vest, pants, sleeves, extra) in base RGB.
#
# All of them are painted DESATURATED and MID-VALUE on purpose (EQ_TECHNIQUE
# sec 2, "Corollary - tint multiplies everything"). The dresser multiplies a
# per-citizen dye over the page; a page painted saturated crimson can only ever
# be crimson, a page painted in warm greys becomes sixteen dyes. Hue separates
# the men from each other, value separates them from the ground - so nothing
# here is darker than the earth they walk on except Morthane's black.
#
# Pages 4-7 and 11-15 are neutral variants: real, distinguishable colourways
# with no archetype claim on them yet, which is what the seeded fallback range
# draws from. They are NOT blanks.
# --------------------------------------------------------------------------- #
GARB_PAGES = [
    # 0-3: the four archetypes with the most bodies in the world
    ("commoner grey",  (0.50, 0.49, 0.47), (0.40, 0.39, 0.38), (0.58, 0.57, 0.54), (0.54, 0.53, 0.50)),
    ("labourer linen", (0.53, 0.45, 0.33), (0.38, 0.33, 0.27), (0.62, 0.55, 0.43), (0.57, 0.51, 0.40)),
    ("merchant wine",  (0.47, 0.35, 0.37), (0.35, 0.30, 0.33), (0.56, 0.47, 0.46), (0.52, 0.43, 0.42)),
    ("guard slate",    (0.40, 0.44, 0.50), (0.33, 0.33, 0.36), (0.47, 0.42, 0.36), (0.39, 0.38, 0.37)),
    # 4-7: neutral variants
    ("faded blue",     (0.41, 0.46, 0.49), (0.34, 0.36, 0.38), (0.53, 0.56, 0.57), (0.47, 0.50, 0.51)),
    ("dun brown",      (0.46, 0.40, 0.32), (0.35, 0.31, 0.26), (0.55, 0.49, 0.40), (0.50, 0.45, 0.37)),
    ("moss",           (0.43, 0.47, 0.37), (0.33, 0.36, 0.30), (0.53, 0.56, 0.45), (0.48, 0.51, 0.41)),
    ("bleached",       (0.60, 0.58, 0.54), (0.47, 0.46, 0.44), (0.66, 0.64, 0.60), (0.62, 0.60, 0.56)),
    # 8-10: the three priesthoods - EQ's robe slots, restated
    ("chronos grey",   (0.54, 0.54, 0.56), (0.44, 0.44, 0.47), (0.60, 0.60, 0.62), (0.49, 0.49, 0.52)),
    ("gaela green",    (0.40, 0.48, 0.36), (0.32, 0.39, 0.30), (0.47, 0.55, 0.43), (0.44, 0.52, 0.40)),
    ("morthane black", (0.24, 0.23, 0.26), (0.20, 0.19, 0.22), (0.30, 0.29, 0.32), (0.27, 0.26, 0.29)),
    # 11-15: neutral variants
    ("russet",         (0.50, 0.38, 0.31), (0.38, 0.30, 0.26), (0.58, 0.47, 0.39), (0.54, 0.44, 0.36)),
    ("ash",            (0.44, 0.43, 0.43), (0.35, 0.34, 0.34), (0.54, 0.53, 0.52), (0.49, 0.48, 0.47)),
    ("ochre",          (0.55, 0.48, 0.32), (0.42, 0.37, 0.26), (0.63, 0.56, 0.40), (0.59, 0.52, 0.37)),
    ("slate violet",   (0.42, 0.39, 0.47), (0.33, 0.31, 0.38), (0.51, 0.48, 0.56), (0.47, 0.44, 0.52)),
    ("sand",           (0.58, 0.53, 0.44), (0.45, 0.41, 0.34), (0.65, 0.60, 0.51), (0.61, 0.56, 0.47)),
]

HAIR_COLORS = [
    (0.14, 0.11, 0.09), (0.34, 0.22, 0.12),
    (0.58, 0.44, 0.22), (0.66, 0.64, 0.60),
]


class Canvas:
    def __init__(self, w, h, bg=(0.0, 0.0, 0.0, 0.0)):
        self.w, self.h = w, h
        self.px = [0.0] * (w * h * 4)
        for i in range(w * h):
            self.px[i * 4:i * 4 + 4] = list(bg)

    def set(self, x, y, rgb, a=1.0):
        """y is TOP-origin; Blender stores bottom-origin, converted here."""
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        by = self.h - 1 - y
        i = (by * self.w + x) * 4
        self.px[i:i + 4] = [rgb[0], rgb[1], rgb[2], a]

    def rect(self, x0, y0, x1, y1, rgb, a=1.0):
        for y in range(y0, y1):
            for x in range(x0, x1):
                self.set(x, y, rgb, a)

    def save(self, name, path):
        img = bpy.data.images.get(name)
        if img:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(name, self.w, self.h, alpha=True)
        img.pixels = self.px
        img.file_format = 'PNG'
        img.filepath_raw = path
        img.save()
        bpy.data.images.remove(img)
        print("WROTE %s (%dx%d, %.1f KB)" %
              (path, self.w, self.h, os.path.getsize(path) / 1024.0))


def shade(rgb, k):
    return (max(0.0, min(1.0, rgb[0] * k)),
            max(0.0, min(1.0, rgb[1] * k)),
            max(0.0, min(1.0, rgb[2] * k)))


def draw_face_cell(c, cx, cy, tone, variant):
    """Cell layout, top-origin, 32x64:
        rows  0..47  FACE  (the head mesh, and nothing else, samples here)
        rows 48..63  SKIN  (flat patch the body/hands/feet sample)

    Columns 0-3 and 28-31 of the face rect are the BACK of the head: the head
    UV wrap sends rear-facing verts to the cell edges, so paint hair/scalp
    there, never features.
    """
    c.rect(cx, cy, cx + CELL_W, cy + CELL_H, tone)

    # back-of-head columns, left and right edge
    back = shade(tone, 0.42)
    c.rect(cx, cy, cx + 4, cy + FACE_ROWS, back)
    c.rect(cx + CELL_W - 4, cy, cx + CELL_W, cy + FACE_ROWS, back)
    # scalp band across the crown
    c.rect(cx, cy, cx + CELL_W, cy + 7, shade(tone, 0.34))

    ey = 15 + (variant % 3)
    # eyes
    c.rect(cx + 6, cy + ey, cx + 13, cy + ey + 4, (0.92, 0.90, 0.86))
    c.rect(cx + 19, cy + ey, cx + 26, cy + ey + 4, (0.92, 0.90, 0.86))
    c.rect(cx + 8, cy + ey + 1, cx + 11, cy + ey + 4, shade(tone, 0.16))
    c.rect(cx + 21, cy + ey + 1, cx + 24, cy + ey + 4, shade(tone, 0.16))
    # brow
    c.rect(cx + 6, cy + ey - 3, cx + 13, cy + ey - 1, shade(tone, 0.28))
    c.rect(cx + 19, cy + ey - 3, cx + 26, cy + ey - 1, shade(tone, 0.28))
    # nose
    c.rect(cx + 14, cy + ey + 4, cx + 18, cy + ey + 12, shade(tone, 0.80))
    # mouth
    my = ey + 17
    c.rect(cx + 11, cy + my, cx + 21, cy + my + 3, shade(tone, 0.52))
    # jaw / cheek shading so the head reads rounded at PSX distance
    c.rect(cx + 4, cy + FACE_ROWS - 9, cx + 7, cy + FACE_ROWS, shade(tone, 0.84))
    c.rect(cx + CELL_W - 7, cy + FACE_ROWS - 9, cx + CELL_W - 4, cy + FACE_ROWS,
           shade(tone, 0.84))

    # flat skin patch for the body - one solid tone, no detail, on purpose
    c.rect(cx, cy + FACE_ROWS, cx + CELL_W, cy + CELL_H, tone)


def build_face_atlas(path):
    c = Canvas(ATLAS_SIZE, ATLAS_SIZE, (0.0, 0.0, 0.0, 1.0))
    n = 0
    for row in range(ATLAS_ROWS):
        for col in range(ATLAS_COLS):
            draw_face_cell(c, col * CELL_W, row * CELL_H,
                           SKIN_TONES[col], row)
            n += 1
    print("face atlas: %d cells of %dx%d px (face rect %dx%d, skin patch %dx%d)"
          % (n, CELL_W, CELL_H, CELL_W, FACE_ROWS, CELL_W, CELL_H - FACE_ROWS))
    c.save(TEX_FACE, path)


def draw_garb_zone(c, x0, y0, base):
    """One 64x64 garment zone, painted to the sec 4.2 recipe, top-origin:

        upper 40%   shoulders and chest - the LIGHTEST values (top light)
        middle 35%  the body of the garment, the largest flat block, one hue
        lower 25%   the hem and belt line - the DARKEST band, hard edge

    Plus the two things sec 4.3 says are worth more than the objects they imply:
    the contact shadow where the belt sits, and folds drawn as a dark line with
    a light line beside it. One light, from above and slightly front-LEFT, on
    every zone of every page - a single inconsistent page makes the whole crowd
    look wrong and nobody can say why.
    """
    z = GARB_ZONE_PX
    hi = shade(base, 1.22)
    lo = shade(base, 0.68)
    y_mid = y0 + int(z * 0.40)
    y_hem = y0 + int(z * 0.75)

    c.rect(x0, y0, x0 + z, y_mid, hi)                 # lit shoulders/chest
    c.rect(x0, y_mid, x0 + z, y_hem, base)            # the big flat block
    c.rect(x0, y_hem, x0 + z, y0 + z, lo)             # hem / belt band

    # the contact shadow UNDER the belt line - the darkest two pixels on the
    # zone, and the single mark that makes flat geometry read as form
    c.rect(x0, y_hem, x0 + z, y_hem + 2, shade(base, 0.42))
    # and the light catching the top edge of the belt
    c.rect(x0, y_hem - 1, x0 + z, y_hem, shade(base, 1.34))

    # two folds: one dark pixel-line, one light pixel-line beside it. Light is
    # front-left, so the lit side of a fold is its LEFT side.
    for fx in (int(z * 0.30), int(z * 0.66)):
        c.rect(x0 + fx, y0 + 3, x0 + fx + 1, y_hem, shade(base, 0.80))
        c.rect(x0 + fx - 1, y0 + 3, x0 + fx, y_hem, shade(base, 1.10))

    # the shoulder highlight, hard-edged, top-left where the light comes from
    c.rect(x0 + 2, y0, x0 + int(z * 0.42), y0 + 3, shade(base, 1.40))


def build_garb_atlas(path):
    """512x512, 4x4 pages of 128 px, four 64 px zones per page. Page 0 is the
    BOTTOM-left, because v is bottom-origin and the meshes are UV'd into page 0
    at v < 0.25 - see the GARB ATLAS CONTRACT in citizen_common.py."""
    c = Canvas(GARB_ATLAS_SIZE, GARB_ATLAS_SIZE, (0.0, 0.0, 0.0, 1.0))
    assert len(GARB_PAGES) == GARB_PAGE_COUNT, \
        "%d colourways for %d pages" % (len(GARB_PAGES), GARB_PAGE_COUNT)

    # page-local, top-origin: the zone order is the contract, not a preference
    zone_at = (("vest", 0, 0), ("pants", GARB_ZONE_PX, 0),
               ("sleeves", 0, GARB_ZONE_PX), ("extra", GARB_ZONE_PX, GARB_ZONE_PX))

    for page, entry in enumerate(GARB_PAGES):
        label = entry[0]
        px, py = garb_page_origin_px(page)
        uo, vo = garb_page_uv_offset(page)
        for (zname, zx, zy), base in zip(zone_at, entry[1:]):
            draw_garb_zone(c, px + zx, py + zy, base)
            del zname
        print("  page %-2d %-15s px=(%3d,%3d) uv1_offset=(%.3f, %.3f)"
              % (page, label, px, py, uo, vo))

    print("garb atlas: %d pages of %dx%d px, four %dx%d zones each, stride %.2f"
          % (GARB_PAGE_COUNT, GARB_PAGE_PX, GARB_PAGE_PX,
             GARB_ZONE_PX, GARB_ZONE_PX, GARB_STRIDE))
    c.save(TEX_GARB, path)


def build_hair_palette(path):
    c = Canvas(32, 32, (0.0, 0.0, 0.0, 1.0))
    for i, rgb in enumerate(HAIR_COLORS):
        c.rect(0, i * 8, 32, i * 8 + 8, rgb)
        c.rect(0, i * 8, 32, i * 8 + 2, shade(rgb, 1.4))
    c.save(TEX_HAIR, path)


def main():
    banner("STAGE 03 - placeholder textures")
    ensure_dirs()
    build_face_atlas(os.path.join(STAGE, TEX_FACE))
    build_garb_atlas(os.path.join(STAGE, TEX_GARB))
    build_hair_palette(os.path.join(STAGE, TEX_HAIR))
    print("STAGE03_OK")


main()
