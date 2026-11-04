"""Painted skins for the kit nests (the user, 2026-11-03: "all the nests need textures"). A tileable texture for each
material region (Corvane's slate paint in panels, its composite, steel, rubber, hazard amber, copper contacts, a screen,
lit amber), painted the base game's way (panel seams with a lip, rivets, chipped edges, grime streaks), laid on each face
by planar projection, so any nest made of boxes and prisms takes them as it is. The tiles repeat seamlessly (their
noise is periodic), so they would serve the game's own meshes too. A nameplate face (region "plate:<text>") gets a
plate of its own: CORVANE ORDNANCE over the model's name.

  write_tex(part, path, out): the part as OBJ + MTL, its tiles and plates written into out.
"""
import math, os, re

import numpy as np

import flykit, mech_storm
from sensor_concept import C, GLOSSY

N = 256                                                 # a tile's texels
TILE = 10.0                                             # world units a tile covers (about 19 cm): 25.6 texels a unit
U, V = np.meshgrid((np.arange(N) + 0.5) / N, 1 - (np.arange(N) + 0.5) / N)   # (row 0 the top: v up the image)


def pnoise(seed, octaves=((2, 1.0), (4, 0.5), (8, 0.25), (16, 0.12)), kx=1, ky=1):
    """Tileable noise on the unit square, -1..1: random-phase waves of whole-number frequencies (kx, ky stretch them)."""
    rng = np.random.default_rng(seed)
    out = np.zeros((N, N))
    for f, a in octaves:
        for _ in range(6):
            fx, fy = (int(x) for x in rng.integers(-f, f + 1, 2))
            if fx == 0 and fy == 0:
                continue
            out += a * np.cos(2 * math.pi * (fx * kx * U + fy * ky * V) + rng.uniform(0, 2 * math.pi))
    return out / (np.abs(out).max() + 1e-9)


def painted(base, seed, panels, inset=False):
    """Corvane's slate paint: panels with seams (a light lip above each), rivets at their corners, chipped edges showing
    bare metal, grime streaking down from each seam."""
    base = np.asarray(base, float)
    col = base * (0.88 + 0.07 * pnoise(seed))[..., None]
    P = N / panels
    lu, lv = (U * N) % P, (V * N) % P                   # texels into the panel from its left, its bottom
    du, dv = np.minimum(lu, P - lu), np.minimum(lv, P - lv)
    streak = pnoise(seed + 1, ((8, 1.0), (16, 0.6), (32, 0.3)), kx=1, ky=0)
    grime = np.clip(lv / P * 1.6 + 0.25 * streak, 0, 1)  # dirt gathers low in each panel, streaked
    col = col * (0.8 + 0.2 * grime)[..., None]
    chips = (pnoise(seed + 2, ((16, 1.0), (32, 0.7), (64, 0.4))) > 0.5) & ((du < 7) | (dv < 7))
    col = np.where(chips[..., None], np.array([132.0, 134, 136]) * (0.9 + 0.1 * pnoise(seed + 3))[..., None], col)
    if inset:                                           # a recessed panel: a second line inside the seam
        ring = (np.abs(np.minimum(du, dv) - 11) < 0.8)
        col = np.where(ring[..., None], col * 0.6, col)
    col = np.where(((dv >= 1.3) & (dv < 2.6) & (lv < P / 2))[..., None], col * 1.2, col)
    col = np.where(((du < 1.3) | (dv < 1.3))[..., None], col * 0.34, col)
    rr = np.full(U.shape, 99.0)
    for cu in (6.0, P - 6.0):
        for cv in (6.0, P - 6.0):
            rr = np.minimum(rr, np.hypot(lu - cu, lv - cv))
    col = np.where((rr < 2.6)[..., None], col * 0.45, col)
    col = np.where((rr < 1.5)[..., None], np.array([150.0, 152, 154]), col)
    return col


def tile(region, seed=7):
    """A region's tile (RGB, 0-255)."""
    n = pnoise(seed + 40)
    if region == "hull":
        return painted(flykit.SLATE, seed, 2)
    if region == "panel":
        return painted(flykit.SLATE * 1.14, seed + 10, 1, inset=True)
    if region == "duct":                                # matte composite: a fine weave
        w = np.sin(2 * math.pi * (16 * U + 16 * V)) * np.sin(2 * math.pi * (16 * U - 16 * V))
        return flykit.COMPOSITE * (0.86 + 0.08 * w + 0.06 * n)[..., None]
    if region == "steel":                               # brushed steel
        b = pnoise(seed + 41, ((16, 1.0), (32, 0.7), (64, 0.5)), kx=0, ky=1)
        return mech_storm.STEEL * (0.84 + 0.1 * b + 0.05 * n)[..., None]
    if region == "band":                                # rubber
        return np.array([30.0, 30, 33]) * (0.85 + 0.15 * n)[..., None]
    if region == "rim":                                 # hazard amber, worn through to dark metal at the chips
        col = mech_storm.HAZARD * (0.88 + 0.08 * n)[..., None]
        chips = pnoise(seed + 42, ((16, 1.0), (32, 0.7), (64, 0.5))) > 0.62
        return np.where(chips[..., None], np.array([58.0, 58, 60]), col)
    if region == "pad":                                 # copper contacts, interleaved traces
        on = (U * 16) % 1 < 0.55
        return np.where(on[..., None], flykit.COPPER * 1.2, flykit.COPPER * 0.55) * (0.9 + 0.1 * n)[..., None]
    if region == "glass":                               # a dark screen, faint scan lines
        col = np.array([14.0, 18, 26]) * (1.0 + 0.4 * V)[..., None]
        return np.where(((np.arange(N) % 3) == 0)[:, None, None], col * 0.75, col)
    if region == "light":
        return flykit.AMBER * (0.92 + 0.08 * n)[..., None]
    return np.array(C.get(region, (0.3, 0.3, 0.3))) * 255 * (0.9 + 0.1 * n)[..., None]


REGIONS = ("hull", "panel", "duct", "steel", "band", "rim", "pad", "glass", "light", "latch")


def tiles(out):
    """Each region's tile as PNG in out (once): {region: path}."""
    from PIL import Image
    paths = {}
    for r in REGIONS:
        path = os.path.join(out, "nest_%s.png" % r)
        if not os.path.exists(path):
            Image.fromarray(np.clip(tile(r), 0, 255).astype(np.uint8), "RGB").save(path)
        paths[r] = path
    return paths


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def plate_png(out, text):
    """A nameplate: CORVANE ORDNANCE over the model's name, stencilled on a dark plate with a worn border and rivets."""
    from PIL import Image, ImageDraw, ImageFont
    path = os.path.join(out, "plate_%s.png" % slug(text))
    if os.path.exists(path):
        return path
    W, H = 512, 128
    fonts = os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts")
    face = os.path.join(fonts, "bahnschrift.ttf") if os.path.exists(os.path.join(fonts, "bahnschrift.ttf")) else os.path.join(fonts, "segoeuib.ttf")
    im = Image.new("RGB", (W, H), (40, 42, 46))
    d = ImageDraw.Draw(im)
    d.rectangle((3, 3, W - 4, H - 4), outline=(150, 150, 146), width=4)
    for x, y in ((14, 14), (W - 15, 14), (14, H - 15), (W - 15, H - 15)):
        d.ellipse((x - 5, y - 5, x + 5, y + 5), fill=(120, 122, 124))
    small, big = ImageFont.truetype(face, 30), ImageFont.truetype(face, 56)
    d.text((W / 2, 34), "CORVANE ORDNANCE", fill=(206, 204, 194), font=small, anchor="mm")
    d.text((W / 2, 86), text, fill=(232, 230, 220), font=big, anchor="mm")
    a = np.asarray(im, float)
    rng = np.random.default_rng(len(text))
    a = a * (0.9 + 0.1 * rng.random((H, W, 1)))
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").save(path)
    return path


def face_uv(P, region):
    """A face's UVs by planar projection (level faces: x across, y up the texture; upright ones: across as a viewer facing
    it reads, up as up), in tiles; a plate's front face takes its whole plate."""
    nrm = np.cross(P[1] - P[0], P[-1] - P[0])
    if np.linalg.norm(nrm) < 1e-12:
        return [(0.0, 0.0)] * len(P)
    nrm = nrm / np.linalg.norm(nrm)
    if abs(nrm[2]) > 0.7:
        A, B = np.array([1.0, 0, 0]), np.array([0, 1.0, 0]) * np.sign(nrm[2])
    else:
        h = np.array([nrm[0], nrm[1], 0.0])
        h /= np.linalg.norm(h)
        A, B = np.cross([0, 0, 1.0], h), np.array([0, 0, 1.0])
    u, v = P @ A, P @ B
    if region.startswith("plate:"):
        return list(zip((u - u.min()) / max(np.ptp(u), 1e-6), (v - v.min()) / max(np.ptp(v), 1e-6)))
    return list(zip(u / TILE, v / TILE))


def write_tex(p, path, out):
    """The part as OBJ + MTL with its regions' tiles (and plates) laid on (Blender's OBJ frame: y up)."""
    tl = tiles(out)
    mtl = path[:-4] + ".mtl"
    used = sorted({r for _, r in p.faces})
    with open(mtl, "w") as f:
        for r in used:
            png = plate_png(out, r[6:]) if r.startswith("plate:") else tl.get(r)
            if png is None:
                f.write("newmtl %s\nKd %.4f %.4f %.4f\n\n" % ((slug(r),) + tuple(c ** 2.2 for c in C.get(r, (0.3, 0.3, 0.3)))))
                continue
            f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s\n" % (slug(r), os.path.basename(png)))
            f.write("Ks 0.9 0.9 0.9\nNs 600\n" if r in GLOSSY else "Ks 0.2 0.2 0.2\nNs 40\n")
            f.write("Ke 1.0 0.62 0.12\n\n" if r == "light" else "\n")
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        n = 0
        for pts, r in p.faces:
            P = np.asarray(pts, float)
            for q in P:
                f.write("v %.4f %.4f %.4f\n" % (q[0], q[2], -q[1]))
            for a, b in face_uv(P, r):
                f.write("vt %.5f %.5f\n" % (a, b))
            f.write("usemtl %s\nf %s\n" % (slug(r), " ".join("%d/%d" % (n + k + 1, n + k + 1) for k in range(len(P)))))
            n += len(P)
    return path
