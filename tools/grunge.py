"""A grunge swatch for the Mech's hard parts (original, generated from a seed): the wear the game's own
weapon skins carry (HDTP: gritty, scratched, dirty metal), as separate channels so a paint can use each.

  R  dirt: blotches at a few sizes (0 clean, 1 dirty)
  G  grain: fine grit around 0.5
  B  scratches: thin bright lines, mostly along the swatch's x (a gun's length), and pits (dark)

Tiles by mirroring (mech_bake.tex).   python -I tools/grunge.py [out.png]   (art/mech/materials/grunge.png)
"""
import os, sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 1024


def blotches(rng):
    """Value noise summed over octaves (16 to 256 px cells), stretched to 0-1."""
    out = np.zeros((N, N))
    amp = 1.0
    for cells in (4, 8, 16, 32, 64):
        g = rng.random((cells + 1, cells + 1))
        im = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
        out += amp * np.asarray(im, float) / 255.0
        amp *= 0.55
    out = (out - out.min()) / (out.max() - out.min())
    return np.clip((out - 0.35) / 0.5, 0, 1) ** 1.4          # mostly clean, dirty patches


def grain(rng):
    g = rng.normal(0.5, 0.18, (N, N))
    g = np.asarray(Image.fromarray(np.clip(g * 255, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7)), float)
    return g / 255.0


def scratches(rng):
    im = Image.new("L", (N, N), 128)
    d = ImageDraw.Draw(im)
    for _ in range(2600):                                       # fine, short, mostly along x
        x, y = rng.random(2) * N
        a = rng.normal(0.0, 0.3) if rng.random() < 0.8 else rng.random() * np.pi
        L = rng.uniform(3, 22)
        v = int(rng.uniform(145, 200))
        d.line([(x, y), (x + L * np.cos(a), y + L * np.sin(a))], fill=v, width=1)
    for _ in range(140):                                        # a few long, faint ones
        x, y = rng.random(2) * N
        a = rng.normal(0.0, 0.15)
        L = rng.uniform(30, 90)
        d.line([(x, y), (x + L * np.cos(a), y + L * np.sin(a))], fill=int(rng.uniform(140, 160)), width=1)
    for _ in range(300):                                        # pits and nicks: dark
        x, y = rng.random(2) * N
        r = rng.uniform(0.6, 1.8)
        d.ellipse([x - r, y - r, x + r, y + r], fill=int(rng.uniform(20, 80)))
    return np.asarray(im.filter(ImageFilter.GaussianBlur(0.6)), float) / 255.0


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "art", "mech", "materials", "grunge.png")
    rng = np.random.default_rng(7)
    rgb = np.stack([blotches(rng), grain(rng), scratches(rng)], -1)
    Image.fromarray(np.clip(rgb * 255, 0, 255).astype(np.uint8), "RGB").save(out)
    print(out)


if __name__ == "__main__":
    main()
