"""Generate the winter and desert ground tiles by palette-shifting existing tiles.

Usage: python tools/make_biome_floor_tiles.py

Reads assets/textures/environment/floors/plains_floor{1,2,3}.png (64x64) and writes
winter_floor{1,3}.png and desert_floor{1,2,3}.png beside them. winter_floor2 comes from
rockhill_floor2 so the set has one stonier variant, matching how the rockhill tiles read
under snow.

Luminance and per-pixel contrast are preserved; only the hue and saturation move, so the
tiles keep the hand-painted grain of the originals and stay 64x64.
"""

import colorsys
import os

from PIL import Image

FLOORS = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..", "assets", "textures", "environment", "floors",
)

# (source, output, target hue 0-1, target saturation, luminance gain, luminance lift)
RECIPES = [
    ("plains_floor1.png", "winter_floor1.png", 0.58, 0.07, 0.45, 0.55),
    ("rockhill_floor2.png", "winter_floor2.png", 0.60, 0.09, 0.50, 0.46),
    ("plains_floor3.png", "winter_floor3.png", 0.56, 0.06, 0.42, 0.58),
    ("plains_floor1.png", "desert_floor1.png", 0.105, 0.42, 0.85, 0.24),
    ("plains_floor2.png", "desert_floor2.png", 0.090, 0.46, 0.88, 0.20),
    ("plains_floor3.png", "desert_floor3.png", 0.115, 0.38, 0.82, 0.26),
]


def shift(src_name, dst_name, hue, sat, gain, lift):
    src = Image.open(os.path.join(FLOORS, src_name)).convert("RGBA")
    px = src.load()
    out = Image.new("RGBA", src.size)
    dst = out.load()

    for y in range(src.size[1]):
        for x in range(src.size[0]):
            r, g, b, a = px[x, y]
            _, lum, _ = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            lum = min(1.0, max(0.0, lum * gain + lift))
            nr, ng, nb = colorsys.hls_to_rgb(hue, lum, sat)
            dst[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)

    out.save(os.path.join(FLOORS, dst_name), optimize=True)
    size = os.path.getsize(os.path.join(FLOORS, dst_name))
    print("%s -> %s (%d bytes)" % (src_name, dst_name, size))


if __name__ == "__main__":
    for recipe in RECIPES:
        shift(*recipe)
