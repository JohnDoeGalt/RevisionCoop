"""The body's texture layout per skin slot: each triangle drawn into its UV space, coloured by
where it is on the body (front, back, sides, arms, legs), with outlines. A guide for painting
the Mech's own skins (tools/mech_bake.py).

  python -I tools/mech_uv.py <slot> <out.png> [size]
"""
import os, sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art

REST = 32


def region(c, n):
    """A name and colour for a triangle at centre c with normal n (body: +X right, -Y front)."""
    x, y, z = c
    if z > 29:
        return "head", (220, 200, 160)
    if abs(x) > 10.5 and z > -12:
        side = "right" if x > 0 else "left"
        upper = z > 6
        return ("%s %s arm" % (side, "upper" if upper else "lower"),
                ((230, 90, 90) if upper else (255, 160, 160)) if x > 0 else ((90, 90, 230) if upper else (160, 160, 255)))
    if z < -8:
        return ("leg front" if n[1] < 0 else "leg back"), ((90, 200, 90) if n[1] < 0 else (40, 120, 40))
    return ("front" if n[1] < 0 else "back"), ((240, 220, 80) if n[1] < 0 else (150, 120, 40))


def layout(slot, size=256):
    pkg, m = mech_art.load_body()
    R = mech_art.game_frames(pkg, m)[REST]
    sv = m["special_verts"]
    img = Image.new("RGB", (size, size), (20, 20, 22))
    d = ImageDraw.Draw(img)
    s = size / 256.0
    for face in m["faces"]:
        if m["materials"][face[3]][1] != slot:
            continue
        w = [m["wedges"][k] for k in face[:3]]
        P = np.array([R[x[0] + sv] for x in w])
        n = np.cross(P[1] - P[0], P[2] - P[0])
        name, col = region(P.mean(axis=0), n)
        pts = [(x[1] * s, x[2] * s) for x in w]
        d.polygon(pts, fill=col, outline=(0, 0, 0))
    return img


if __name__ == "__main__":
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    layout(int(sys.argv[1]), size).save(sys.argv[2])
    print("wrote", sys.argv[2])
