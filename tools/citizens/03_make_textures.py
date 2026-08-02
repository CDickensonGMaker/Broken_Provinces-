"""Stage 03 - generate the placeholder textures the citizen masters are UV'd against.

Three PNGs, all nearest-neighbour PSX stock, all tiny:
  citizen_face_atlas_placeholder.png  256x256, a 10x7 grid of 25x36 cells.
      Each cell = one citizen's skin+face pixels. Top of the cell is the face
      (eye/brow/mouth blocks), bottom is the flat skin patch the rest of the
      body samples, so head/neck/hands/limbs slide together on one uv1_offset.
  citizen_garb_palette_placeholder.png 64x64, four flat zones (vest, pants,
      sleeves, apron/hood) so a colour variant is a palette swap.
  citizen_hair_palette_placeholder.png 32x32, four flat hair colour strips.

Caleb replaces the face atlas with real painted faces later; the CELL GRID is
the contract, not the pixels.

Run: blender -b --factory-startup --python tools/citizens/03_make_textures.py
"""
import bpy
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from citizen_common import (STAGE, TEX_FACE, TEX_GARB, TEX_HAIR, ATLAS_COLS,
                            ATLAS_ROWS, ensure_dirs, banner)

ATLAS_SIZE = 256
CELL_W = ATLAS_SIZE // ATLAS_COLS      # 25
CELL_H = ATLAS_SIZE // ATLAS_ROWS      # 36

SKIN_TONES = [
    (0.94, 0.78, 0.66), (0.89, 0.72, 0.58), (0.84, 0.66, 0.52),
    (0.78, 0.60, 0.46), (0.70, 0.53, 0.40), (0.62, 0.46, 0.34),
    (0.53, 0.38, 0.28), (0.44, 0.31, 0.23), (0.36, 0.25, 0.18),
    (0.28, 0.19, 0.14),
]

GARB_ZONES = [
    ("vest", (0.42, 0.32, 0.22)),
    ("pants", (0.30, 0.28, 0.26)),
    ("sleeves", (0.62, 0.55, 0.42)),
    ("apron_hood", (0.52, 0.48, 0.40)),
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
    """Cell layout, top-origin, 25x36:
        rows  0..23  FACE  (head/neck/hands sample here)
        rows 24..35  SKIN  (flat patch every other body vert samples)
    """
    c.rect(cx, cy, cx + CELL_W, cy + CELL_H, tone)
    # hair/brow band across the crown
    c.rect(cx, cy, cx + CELL_W, cy + 4, shade(tone, 0.35))
    # eyes - variant slides them a pixel and changes the whites
    ey = 9 + (variant % 3)
    c.rect(cx + 4, cy + ey, cx + 9, cy + ey + 3, (0.92, 0.90, 0.86))
    c.rect(cx + 16, cy + ey, cx + 21, cy + ey + 3, (0.92, 0.90, 0.86))
    c.rect(cx + 6, cy + ey + 1, cx + 8, cy + ey + 3, shade(tone, 0.18))
    c.rect(cx + 18, cy + ey + 1, cx + 20, cy + ey + 3, shade(tone, 0.18))
    # brow
    c.rect(cx + 4, cy + ey - 2, cx + 9, cy + ey - 1, shade(tone, 0.30))
    c.rect(cx + 16, cy + ey - 2, cx + 21, cy + ey - 1, shade(tone, 0.30))
    # nose shadow
    c.rect(cx + 11, cy + ey + 3, cx + 14, cy + ey + 6, shade(tone, 0.80))
    # mouth
    my = ey + 9
    c.rect(cx + 8, cy + my, cx + 17, cy + my + 2, shade(tone, 0.55))
    # jaw shading so the head reads as rounded at PSX distance
    c.rect(cx, cy + 20, cx + 2, cy + 24, shade(tone, 0.82))
    c.rect(cx + CELL_W - 2, cy + 20, cx + CELL_W, cy + 24, shade(tone, 0.82))
    # flat skin patch for the body
    c.rect(cx, cy + 24, cx + CELL_W, cy + CELL_H, tone)


def build_face_atlas(path):
    c = Canvas(ATLAS_SIZE, ATLAS_SIZE, (0.0, 0.0, 0.0, 1.0))
    n = 0
    for row in range(ATLAS_ROWS):
        for col in range(ATLAS_COLS):
            draw_face_cell(c, col * CELL_W, row * CELL_H,
                           SKIN_TONES[col], row)
            n += 1
    print("face atlas: %d cells of %dx%d px" % (n, CELL_W, CELL_H))
    c.save(TEX_FACE, path)


def build_garb_palette(path):
    c = Canvas(64, 64, (0.0, 0.0, 0.0, 1.0))
    for i, (name, rgb) in enumerate(GARB_ZONES):
        x0 = (i % 2) * 32
        y0 = (i // 2) * 32
        c.rect(x0, y0, x0 + 32, y0 + 32, rgb)
        # a darker stripe per zone so seams/orientation are visible in review
        c.rect(x0, y0, x0 + 32, y0 + 3, shade(rgb, 0.65))
        c.rect(x0, y0 + 16, x0 + 32, y0 + 18, shade(rgb, 1.25))
        print("  garb zone %-10s uv rect (%d,%d)-(%d,%d)" % (name, x0, y0, x0 + 32, y0 + 32))
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
    build_garb_palette(os.path.join(STAGE, TEX_GARB))
    build_hair_palette(os.path.join(STAGE, TEX_HAIR))
    print("STAGE03_OK")


main()
