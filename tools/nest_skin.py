"""Skins for the kit nests out of Revision's own textures (the user, 2026-11-03: "all the nests need textures"; then "you
didn't give them new textures that fit better with Revision"; "leave out the hazard stripes"). Each material region
takes a texture from the game as installed: Revision's own RevTex packages (DXT1, decoded here; its Area 51 clean-room
metal panels, its control panel, its orange glass light, its terminal screen, Bob Page's white panelling) and the base
game's metals that Revision's maps use (8-bit). Tiling ones are laid on each face by planar projection, repeating over
their own world size; "whole" ones (a light, a screen, "face:<texture>", a "plate:<text>" nameplate) fill their face.
Rubber, copper contacts and the red key are painted here (the game has none to suit).

  write_tex(part, path, out): the part as OBJ + MTL, the textures it uses written into out as PNG.
"""
import math, os, re

import numpy as np

import flykit, ue1mesh
from sensor_concept import C, GLOSSY

DX = os.path.dirname(flykit.REV)                        # the game's own folder (Revision's is inside it)
A51, MISC, METAL = "Revision/Textures/RevTexA51", "Revision/Textures/RevTexMisc", "Textures/CoreTexMetal"
# region: (package, texture, (world units it repeats over across, up), tone (the user: "too bright"), turned: its length
# along a face rather than up it). The shared box's posts and rails wear the game's own storage rack (the user:
# "shouldn't we use the rack texture for the racks?"): its upright (racksides), its slotted shelf edge (metalshelf_a).
SOURCES = {"hull": (A51, "ClenCntrlPanl_1A", (40.0, 40.0), 0.5, False),
           "panel": (A51, "ClenCntrlPanl_2A", (40.0, 40.0), 0.55, False),
           "page": (A51, "BPagePanl_LaytA_Wall", (44.0, 44.0), 0.5, False),
           "page2": (A51, "BPagePanl_LaytB_Wall", (44.0, 44.0), 0.5, False),
           "duct": (METAL, "ShipGrayMetal_A", (16.0, 16.0), 1.0, False),
           "steel": (METAL, "Galvanzd", (16.0, 16.0), 0.8, False),
           "rim": (METAL, "IronYeloPlain_A", (12.0, 12.0), 0.75, False),
           "rack": (METAL, "racksides", (1.2, 4.8), 1.0, False),
           "rail": (METAL, "metalshelf_a", (1.2, 4.8), 1.0, True)}
WHOLE = {"light": (A51, "OrangeLight_D", 1.0), "glass": (MISC, "CC_terminal2", 0.9)}
FACE_TONE = 0.8
FACES = (A51, MISC, METAL)                             # where "face:<name>" looks
TILE = 10.0                                             # the painted tiles' repeat
N = 256
_pk = {}


def dxt1(data, w, h):
    """A DXT1 (S3TC) image's pixels."""
    b = np.frombuffer(data[:w * h // 2], np.uint8).reshape(-1, 8)
    c = b[:, :4].copy().view("<u2")

    def rgb(v):
        return np.stack([((v >> 11) & 31) * 255 // 31, ((v >> 5) & 63) * 255 // 63, (v & 31) * 255 // 31], -1).astype(float)
    c0, c1 = rgb(c[:, 0]), rgb(c[:, 1])
    four = (c[:, 0] > c[:, 1])[:, None]
    pal = np.stack([c0, c1, np.where(four, (2 * c0 + c1) / 3, (c0 + c1) / 2), np.where(four, (c0 + 2 * c1) / 3, 0)], 1)
    idx = b[:, 4:].copy().view("<u4")[:, 0]
    px = np.stack([(idx >> (2 * k)) & 3 for k in range(16)], 1)
    blocks = np.take_along_axis(pal, px[..., None].repeat(3, -1), 1).reshape(h // 4, w // 4, 4, 4, 3)
    return blocks.transpose(0, 2, 1, 3, 4).reshape(h, w, 3).astype(np.uint8)


def game_texture(pkg, name):
    """A texture out of the game's packages (pkg relative to the game's folder, no extension): RGB pixels, its top mip."""
    if pkg not in _pk:
        _pk[pkg] = ue1mesh.Package(os.path.join(DX, pkg + ".utx"))
    p = _pk[pkg]
    e = p.find(name, "Texture")
    r = ue1mesh.Reader(p.d, e["off"])
    props = p.object_props(r)
    r.ci()
    n = p.lazy_count(r)
    data = p.d[r.p:r.p + n]
    r.p += n
    w, h = r.i32(), r.i32()
    if props.get("Format", b"\x00")[:1] == b"\x03":
        return dxt1(data, w, h)
    pe = p.exports[props["Palette"] - 1]
    pr = ue1mesh.Reader(p.d, pe["off"])
    p.object_props(pr)
    pal = [tuple(p.d[pr.p + 4 * i + j] for j in range(3)) for i in range(pr.ci())]
    return np.array(pal, np.uint8)[np.frombuffer(data[:w * h], np.uint8)].reshape(h, w, 3)


def find_face(name):
    for pkg in FACES:
        try:
            return game_texture(pkg, name)
        except Exception:
            continue
    raise KeyError(name)


def painted(region, seed=7):
    """The few regions the game has nothing to suit: rubber, copper contacts, the red key."""
    rng = np.random.default_rng(seed)
    n = rng.random((N, N, 1))
    if region == "band":
        return np.array([30.0, 30, 33]) * (0.85 + 0.15 * n)
    if region == "pad":
        on = ((np.arange(N) / N * 16) % 1 < 0.55)[None, :, None]
        return np.where(on, flykit.COPPER * 1.2, flykit.COPPER * 0.55) * (0.9 + 0.1 * n)
    return np.array(C.get(region, (0.3, 0.3, 0.3))) * 255 * (0.9 + 0.1 * n)


def slug(s):
    return re.sub(r"[^a-z0-9]+", "_", s.lower()).strip("_")


def region_png(out, r):
    """The texture for region r as PNG in out (once)."""
    from PIL import Image
    path = os.path.join(out, "nest_%s.png" % slug(r))
    if os.path.exists(path):
        return path
    if r.startswith("plate:"):
        return plate_png(out, r[6:])
    if r.startswith("face:"):
        a = (find_face(r[5:]) * FACE_TONE).astype(np.uint8)
    elif r in SOURCES:
        a = (game_texture(*SOURCES[r][:2]) * SOURCES[r][3]).astype(np.uint8)
    elif r in WHOLE:
        a = (game_texture(*WHOLE[r][:2]) * WHOLE[r][2]).astype(np.uint8)
    else:
        a = np.clip(painted(r), 0, 255).astype(np.uint8)
    Image.fromarray(a, "RGB").save(path)
    return path


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
    a = np.asarray(im, float) * (0.9 + 0.1 * np.random.default_rng(len(text)).random((H, W, 1)))
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGB").save(path)
    return path


def whole(r):
    return r.startswith("plate:") or r.startswith("face:") or r in WHOLE


def face_uv(P, region):
    """A face's UVs by planar projection (level faces: x across, y up the texture; upright ones: across as a viewer facing
    it reads, up as up), in its texture's repeats; a whole one fills its face."""
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
    if whole(region):
        return list(zip((u - u.min()) / max(np.ptp(u), 1e-6), (v - v.min()) / max(np.ptp(v), 1e-6)))
    (ru, rv), turned = (SOURCES[region][2], SOURCES[region][4]) if region in SOURCES else ((TILE, TILE), False)
    return list(zip(v / ru, u / rv)) if turned else list(zip(u / ru, v / rv))


def write_tex(p, path, out):
    """The part as OBJ + MTL with its regions' textures laid on (Blender's OBJ frame: y up)."""
    mtl = path[:-4] + ".mtl"
    used = sorted({r for _, r in p.faces})
    with open(mtl, "w") as f:
        for r in used:
            f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s\n" % (slug(r), os.path.basename(region_png(out, r))))
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
