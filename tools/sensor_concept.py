"""Concept art for the mobile sensor (docs/FLY_KITS.md; the user, 2026-11-03: "a throwable sensor of some kind... stick to
a wall and then work as an allied camera... it doesn't need to be particularly useful on its own... so that we have an
idea of, oh, this is the thing that you attach to" a fly kit): three designs in the FK-7's own retro-future palette
(tools/flykit.py COLOURS), beside the game's own grenades and security camera (Revision's HDTP LAM, EMP, gas and
scramble grenades; DeusExDeco's SecurityCamera), each alone, stuck to a wall, and clamped under the FK-7 (a sensor kit:
flykit.kit, seat, clamps telescope to it as to any payload). Flat colours on the sensors: a look, not a skin.

  python -I tools/sensor_concept.py build [outdir]   (default build/mech/sensor: the OBJs and render spec.json)
  blender -b --factory-startup --python tools/flykit_render.py -- <outdir>/spec.json <outdir>/render
  python -I tools/sensor_concept.py sheet [outdir]   (<outdir>/sensor_concepts.png: the renders, labelled)
  python -I tools/sensor_concept.py d [outdir], dsheet [outdir]   (the 20 mm form iterated: VARIANTS; rendered as above)

Frame: x forward, y left, z up; game units (about 1.9 cm).
"""
import math, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from mech_parts import Part

C = dict(flykit.COLOURS, steel=(0.55, 0.56, 0.58), wall=(0.42, 0.42, 0.44), glass=(0.03, 0.05, 0.09))
GLOSSY = ("lens", "glass", "light")
DESIGNS = [("A", "Dome puck", "a squat disc under a fisheye dome; sticks flat by its bond pad"),
           ("B", "Dome canister", "grenade-shaped, the dome on its end, a whip antenna"),
           ("C", "Dome stalk", "a low base holding the dome up on a fixed stalk, to see over a ledge"),
           ("D", "20 mm form", "the 20 mm round's body, 15% bigger, the dome for its nose; beside the game's own 20 mm")]
R20 = 1.15          # D: the 20 mm round's size (tools/flykit.py ROUND20: 6.1 long, 3.6 across) scaled up


def dome(p, c, r, region, n=20, rings=6):
    """A hemisphere (its open side down) of radius r on centre c."""
    c = np.asarray(c, float)
    pts = lambda k: [c + np.array([r * math.cos(math.pi / 2 * k / rings) * math.cos(2 * math.pi * j / n),
                                   r * math.cos(math.pi / 2 * k / rings) * math.sin(2 * math.pi * j / n),
                                   r * math.sin(math.pi / 2 * k / rings)]) for j in range(n)]
    for k in range(rings):
        a, b = pts(k), pts(k + 1)
        for j in range(n):
            q = (j + 1) % n
            if k == rings - 1:
                p.add_tri(a[j], a[q], b[0] * 0 + c + np.array([0, 0, r]), region)
            else:
                p.add_quad(a[j], a[q], b[q], b[j], region)


def eye_dome(p, c, r):
    """The sensor's eye: a fixed fisheye dome of radius r on centre c (open side down), its amber seat ring and a dark
    collar under it. In lore one ultra-high-definition sensor sees all round at once and zooms digitally on any region:
    nothing on it turns."""
    c = np.asarray(c, float)
    p.prism(c - [0, 0, 0.35], c, (1, 0, 0), r * 1.08, 24, "duct", None, None)            # the collar
    p.prism(c, c + [0, 0, 0.14], (1, 0, 0), r * 1.1, 24, "rim", None, None)             # the seat ring
    dome(p, c + [0, 0, 0.14], r, "glass", n=28, rings=9)


def puck():
    p = Part("puck")
    p.prism((0, 0, -0.15), (0, 0, 0), (1, 0, 0), 2.6, 24, "pad", "pad", None)            # the bond pad
    p.prism((0, 0, 0), (0, 0, 1.4), (1, 0, 0), 3.2, 24, "hull", "hull", None)
    p.prism((0, 0, 0.8), (0, 0, 1.0), (1, 0, 0), 3.26, 24, "band", None, None)          # a grip band
    p.prism((0, 0, 1.4), (0, 0, 1.75), (1, 0, 0), 3.2, 24, "panel", None, "panel", radius_end=2.7)
    eye_dome(p, (0, 0, 2.1), 2.0)
    for k in range(3):                                                                   # three status lights
        a = 2 * math.pi * k / 3 + 0.5
        p.box((3.0 * math.cos(a), 3.0 * math.sin(a), 1.1), (math.cos(a), math.sin(a), 0), (-math.sin(a), math.cos(a), 0),
              (0, 0, 1), (0.3, 0.42, 0.2), ("light", "light"))
    return p


def canister():
    p = Part("canister")
    p.prism((0, 0, -0.12), (0, 0, 0), (1, 0, 0), 1.6, 16, "pad", "pad", None)
    p.prism((0, 0, 0), (0, 0, 4.6), (1, 0, 0), 1.9, 16, "hull", "hull", None)
    for z in (0.9, 1.5, 2.1):                                                            # grip ribs
        p.prism((0, 0, z), (0, 0, z + 0.28), (1, 0, 0), 1.98, 16, "band", None, None)
    p.prism((0, 0, 3.6), (0, 0, 3.75), (1, 0, 0), 1.95, 16, "light", None, None)         # the status ring
    p.prism((0, 0, 4.6), (0, 0, 4.95), (1, 0, 0), 1.9, 16, "panel", None, "panel", radius_end=1.7)
    eye_dome(p, (0, 0, 5.3), 1.55)
    p.prism((2.05, 0, 2.6), (2.05, 0, 6.6), (1, 0, 0), 0.11, 8, "rimdark", None, "rimdark")   # the whip antenna, up its side
    p.box((2.05, 0, 6.65), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.3, 0.3, 0.2), ("light", "light"))
    p.box((1.97, 0, 2.7), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.25, 0.4, 0.4), ("duct", "duct"))          # its foot
    return p


def periscope():
    p = Part("stalk")
    p.box((0, 0, -0.07), (1, 0, 0), (0, 1, 0), (0, 0, 1), (4.6, 4.6, 0.14), ("pad", "pad"))
    flykit.chamfer_box(p, (-2.6, -2.6, 0), (2.6, 2.6, 1.3), 0.35, "hull", "panel")
    for s in (1, -1):                                                                    # amber edge stripes
        p.box((0, s * 2.62, 0.65), (1, 0, 0), (0, 1, 0), (0, 0, 1), (4.6, 0.06, 0.26), ("rim", "rim"))
    p.prism((0, 0, 1.3), (0, 0, 4.6), (1, 0, 0), 0.55, 12, "steel", None, None)          # the fixed stalk
    p.prism((0, 0, 1.3), (0, 0, 1.9), (1, 0, 0), 0.9, 12, "duct", None, "duct")          # its foot
    eye_dome(p, (0, 0, 4.95), 1.45)
    for s in (1, -1):
        p.box((2.2, s * 1.6, 1.32), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.3, 0.42, 0.14), ("light", "light"))
    return p


def round20():
    """The 20 mm round's form (the user, 2026-11-03: "the form factor of the 20 millimeter... maybe a little bit
    bigger"): ROUND20's bevelled base and body, R20 bigger, along z, the fixed dome where its ogive and fuze were."""
    s, r = R20, 1.8 * R20
    p = Part("round20")
    p.prism((0, 0, -0.1), (0, 0, 0), (1, 0, 0), r * 0.8, 20, "pad", "pad", None)        # the bond pad, on its base
    p.prism((0, 0, 0), (0, 0, 0.15 * s), (1, 0, 0), r * 0.9, 20, "hull", "hull", None, radius_end=r)   # the base bevel
    p.prism((0, 0, 0.15 * s), (0, 0, 3.65 * s), (1, 0, 0), r, 20, "hull", None, None)
    p.prism((0, 0, 0.7 * s), (0, 0, 1.15 * s), (1, 0, 0), r * 1.03, 20, "band", None, None)   # a driving band
    p.prism((0, 0, 2.5 * s), (0, 0, 2.62 * s), (1, 0, 0), r * 1.02, 20, "light", None, None)  # the status ring
    p.prism((0, 0, 3.65 * s), (0, 0, 3.95 * s), (1, 0, 0), r, 20, "panel", None, "panel", radius_end=r * 0.9)
    eye_dome(p, (0, 0, 3.95 * s + 0.35), r * 0.86)
    return p


def rot_y(deg):
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rot_x(deg):
    a = math.radians(deg)
    return np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])


def moved(p, R=np.eye(3), t=(0, 0, 0)):
    q = Part(p.name)
    q.faces = [([R @ v + np.asarray(t, float) for v in pts], reg) for pts, reg in p.faces]
    return q


def write_obj(p, path):
    """A part as OBJ, flat colours by region (Blender's OBJ frame: y up)."""
    mtl = path[:-4] + ".mtl"
    used = sorted({r for _, r in p.faces})
    with open(mtl, "w") as f:
        for r in used:
            f.write("newmtl %s\nKd %.4f %.4f %.4f\n" % ((r,) + tuple(c ** 2.2 for c in C[r])))     # (the palette is sRGB)
            f.write("Ks 0.9 0.9 0.9\nNs 600\n\n" if r in GLOSSY else "Ks 0.25 0.25 0.25\nNs 60\n\n")
            if r == "light":
                f.write("Ke 1.0 0.62 0.12\n\n")
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        n = 0
        for pts, r in p.faces:
            for v in pts:
                f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
            f.write("usemtl %s\nf %s\n" % (r, " ".join(str(n + k + 1) for k in range(len(pts)))))
            n += len(pts)
    return path


def mesh(p):
    """(V, tris) of a part, centred: for the kit's clamps."""
    V, tris = [], []
    for pts, _ in p.faces:
        i = len(V)
        V += [np.asarray(v, float) for v in pts]
        tris += [(i, i + 1, i + 2)] if len(pts) == 3 else [(i, i + 1, i + 2), (i, i + 2, i + 3)]
    V = np.array(V)
    return V, tris


def kitted(p, out, tag, cx=None):
    """The FK-7 clamped onto part p (centred, as it hangs under the kit; cx: the x of p held under the kit's middle,
    else its own middle): the kit's OBJ and the seated part's OBJ."""
    from PIL import Image
    V, tris = mesh(p)
    c = (V.max(0) + V.min(0)) / 2
    if cx is not None:
        c[0] = cx
    p = moved(p, t=-c)
    V = V - c
    k, under = flykit.kit(V.max(0) - V.min(0))
    S = flykit.seat(V, tris, under)
    flykit.clamps(k, S, under, tris)
    flykit.layout_kit(k)
    skins = []
    for s in (0, 1):
        skins.append("sk_%s_%d" % (tag, s))
        flykit.bake_kit(k, s, os.path.join(out, skins[s] + ".png"))
    Image.fromarray(flykit.blur_skin(), "RGBA").save(os.path.join(out, "flykit_blur.png"))
    mtl = os.path.join(out, "kit_%s.mtl" % tag)
    with open(mtl, "w") as f:
        for s in skins:
            f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (s, s))
        f.write("newmtl blur\nKd 1 1 1\nmap_Kd flykit_blur.png\nmap_d flykit_blur.png\n\n")
    st = dict(p=k, own=None, V=np.zeros((0, 3)), tris=[], uvs=[], tnames=[], skins=skins, mtl=mtl)
    a = flykit.obj(os.path.join(out, "kit_%s.obj" % tag), st)
    b = write_obj(moved(p, t=S[0] - V[0]), os.path.join(out, "kitload_%s.obj" % tag))
    global LAST_SEAT
    LAST_SEAT = S[0] - V[0] - c                         # (the part as given to its seat: tex_build's textured copy)
    return [a, b]


_texture = flykit.texture


def _safe_texture(pkg, i):
    """flykit.texture, or a flat grey for one in a package not at hand (the EMP grenade's sparks: Effects.u)."""
    try:
        return _texture(pkg, i)
    except Exception:
        return "missing%d" % (-i), np.full((8, 8, 3), 90, np.uint8)


flykit.texture = _safe_texture


def game_obj(pkgname, mesh_name, scale, R, t, out, tag):
    """A game mesh (its own skins) as OBJ, turned by R and moved to t (its middle)."""
    from PIL import Image
    flykit.PAYLOADS["_ref"] = (pkgname, mesh_name, scale, {}, (0, 0, 0))
    V, tris, uvs, tnames, tex = flykit.payload("_ref")
    V = V @ R.T + np.asarray(t, float)
    mtl = os.path.join(out, "ref_%s.mtl" % tag)
    with open(mtl, "w") as f:
        for name, img in tex.items():
            Image.fromarray(img).save(os.path.join(out, "%s.png" % name))
            f.write("newmtl t_%s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (name, name))
    path = os.path.join(out, "ref_%s.obj" % tag)
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
        k = 0
        for (a, b, c), uv, tn in zip(tris, uvs, tnames):
            for u in uv:
                f.write("vt %.5f %.5f\n" % u)
            f.write("usemtl t_%s\nf %d/%d %d/%d %d/%d\n" % (tn, a + 1, k + 1, b + 1, k + 2, c + 1, k + 3))
            k += 3
    print("%s: %.1f x %.1f x %.1f units" % (tag, *(V.max(0) - V.min(0))))
    return path


def eye(look, dist, az, el):
    a, e = math.radians(az), math.radians(el)
    return [look[0] + dist * math.cos(e) * math.cos(a), look[1] + dist * math.cos(e) * math.sin(a), look[2] + dist * math.sin(e)]


def build(out):
    import json
    os.makedirs(out, exist_ok=True)
    REV = flykit.REV
    flykit.PACKAGES["DeusExDeco"] = os.path.join(REV, "System", "DeusExDeco.u")
    frames, states = [], []
    # The game's own: the HDTP grenades Revision draws, and a security camera.
    refs = [("HDTPItems", "HDTPLAMPickup", "lam"), ("HDTPItems", "HDTPEMPgrenadePickup", "emp"),
            ("HDTPItems", "HDTPGasgrenadePickup", "gas"), ("HDTPItems", "HDTPnanovirusgrenadePickup", "scramble")]
    objs = []
    for (pk, m, tag), y in zip(refs, (13.5, 4.5, -4.5, -13.5)):
        objs.append(game_obj(pk, m, 1.0, np.eye(3), (0, y, 0), out, tag))
    frames.append(objs)
    states.append(dict(eye=eye((0, 0, 0), 58, 14, 14), look=(0, 0, 0), lens=50))
    wall = Part("wall")
    wall.box((-0.35, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.4, 40, 40), ("wall", "wall"))
    wpath = write_obj(wall, os.path.join(out, "wall.obj"))
    for (tag, name, _), make in zip(DESIGNS, (puck, canister, periscope, round20)):
        p = make()
        V, _ = mesh(p)
        c = (V.max(0) + V.min(0)) / 2
        # Alone, a three-quarter look from above.
        objs = [write_obj(moved(p, t=-c - (0, 2.4 if tag == "D" else 0, 0)), os.path.join(out, "alone_%s.obj" % tag))]
        if tag == "D":                                      # beside the game's own 20 mm round, stood on its base
            objs.append(game_obj("HDTPItems", "HDTPHECannister", 1.0, rot_y(-90), (0, 3.4, -c[2] + 3.05), out, "r20"))
        frames.append(objs)
        states.append(dict(eye=eye((0, 0, 0), 17 if tag != "D" else 21, 30, 24), look=(0, 0, 0), lens=50))
        # Stuck to a wall by its pad (its -z against the wall at x = -0.15), looking out (+x).
        frames.append([wpath, write_obj(moved(p, rot_y(90)), os.path.join(out, "wall_%s.obj" % tag))])
        states.append(dict(eye=eye((2, 0, 0), 20, 35, 12), look=(2, 0, 0), lens=50))
        # Under the FK-7, each upside down: its dome looking down at the ground; D along the kit as a 20 mm round rides.
        R = rot_y(90) if tag == "D" else rot_x(180)
        frames.append(kitted(moved(p, R), out, tag))
        states.append(dict(eye=eye((0, 0, -1), 32, 32, 18), look=(0, 0, -1), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    im = lambda k: Image.open(os.path.join(rd, "r%04d.png" % k)).convert("RGB").resize((480, 360), Image.LANCZOS)
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    W = 480 * 3
    S = Image.new("RGB", (W, 120 + 360 + len(DESIGNS) * (60 + 360)), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Mobile sensor: concepts", fill=(240, 200, 120), font=font(40))
    d.text((24, 70), "The game's own grenades, for scale and style: LAM, EMP, gas, scramble (Revision's HDTP models)", fill=(200, 200, 205), font=font(22))
    ref = Image.open(os.path.join(rd, "r0000.png")).convert("RGB").resize((W, 360), Image.LANCZOS)
    S.paste(ref, (0, 110))
    y = 480
    for i, (tag, name, line) in enumerate(DESIGNS):
        d.text((24, y + 10), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(30))
        d.text((380, y + 18), line, fill=(200, 200, 205), font=font(20))
        for j in range(3):
            S.paste(im(1 + i * 3 + j), (j * 480, y + 60))
        for j, cap in enumerate(("alone", "stuck to a wall", "under the FK-7: a sensor kit")):
            d.text((j * 480 + 12, y + 60 + 330), cap, fill=(255, 255, 255), font=font(18))
        y += 420
    path = os.path.join(out, "sensor_concepts.png")
    S.save(path)
    print(path)


# ---- D, iterated (the user, 2026-11-03: "some iterations of the 20 millimeter one, maybe make it a little longer so that the
# clamps aren't touching the lens. Maybe adding some various details... a bunch of versions"). Each is longer than D (its
# body 60% longer: both clamps land on the body, the dome clear ahead of them, held under the kit by its body's middle)
# and carries its own details.
D_LONG = 1.6
VARIANTS = [("D1", "Long", "the 20 mm form lengthened: both clamps on the body, the dome clear"),
            ("D2", "Finned", "cooling fins round its tail, like a sensor that runs warm"),
            ("D3", "Hooded", "a short lens hood round the dome's base: sun and knocks"),
            ("D4", "Caged", "four thin ribs arching over the dome: a guard, nothing moves"),
            ("D5", "Hazard bands", "hazard stripes at the base, a status strip down one side"),
            ("D6", "Clamp flats", "copper landing plates where the clamps grip, a stencilled band")]
CLAMP_HALF = flykit.CLAMP["depth"] / 2 + flykit.CLAMP["thick"]     # a jaw's half width along the payload, about


def d_body(kind):
    """D lengthened, with kind's details (VARIANTS), stood on its base along z: (the part, its body length, the dome's
    centre height, the dome's radius)."""
    s, r = R20, 1.8 * R20
    B = 3.95 * s * D_LONG
    p = Part(kind)
    p.prism((0, 0, -0.1), (0, 0, 0), (1, 0, 0), r * 0.8, 20, "pad", "pad", None)
    p.prism((0, 0, 0), (0, 0, 0.15 * s), (1, 0, 0), r * 0.9, 20, "hull", "hull", None, radius_end=r)
    p.prism((0, 0, 0.15 * s), (0, 0, B - 0.35), (1, 0, 0), r, 20, "hull", None, None)
    p.prism((0, 0, 0.7 * s), (0, 0, 1.15 * s), (1, 0, 0), r * 1.03, 20, "band", None, None)       # the driving band
    p.prism((0, 0, B - 1.4), (0, 0, B - 1.28), (1, 0, 0), r * 1.02, 20, "light", None, None)      # the status ring
    p.prism((0, 0, B - 0.35), (0, 0, B), (1, 0, 0), r, 20, "panel", None, "panel", radius_end=r * 0.9)
    dc, dr = B + 0.35, r * 0.86
    eye_dome(p, (0, 0, dc), dr)
    mid = B / 2
    if kind == "D2":                                    # cooling fins round the tail
        for k in range(10):
            a = 2 * math.pi * k / 10
            d, tg = np.array([math.cos(a), math.sin(a), 0]), np.array([-math.sin(a), math.cos(a), 0])
            p.box(d * (r + 0.2) + [0, 0, 2.8], d, tg, (0, 0, 1), (0.42, 0.12, 1.8), ("duct", "duct"))
    elif kind == "D3":                                  # the lens hood
        p.prism((0, 0, dc - 0.05), (0, 0, dc + dr * 0.55), (1, 0, 0), dr * 1.16, 24, "duct", None, None)
        p.prism((0, 0, dc + dr * 0.55), (0, 0, dc + dr * 0.6), (1, 0, 0), dr * 1.16, 24, "rim", None, None, radius_end=dr * 1.05)
    elif kind == "D4":                                  # the cage over the dome
        R = dr * 1.12
        for k in range(4):
            a = math.pi / 4 + math.pi / 2 * k
            d = np.array([math.cos(a), math.sin(a), 0])
            pts = [np.array([0, 0, dc + 0.14]) + R * (math.cos(u) * d + math.sin(u) * np.array([0, 0, 1]))
                   for u in np.linspace(0, math.pi / 2, 7)]
            for q0, q1 in zip(pts, pts[1:]):
                p.prism(q0, q1, np.cross(d, (0, 0, 1)), 0.11, 6, "rimdark", "rimdark", "rimdark")
        p.prism((0, 0, dc + 0.14 + R - 0.08), (0, 0, dc + 0.14 + R + 0.12), (1, 0, 0), 0.28, 8, "rimdark", "rimdark", "rimdark")
    elif kind == "D5":                                  # hazard bands and a status strip
        for k in range(6):
            z0 = 1.5 * s + k * 0.32
            p.prism((0, 0, z0), (0, 0, z0 + 0.32), (1, 0, 0), r * 1.015, 20, "rim" if k % 2 == 0 else "band", None, None)
        p.box((0, -(r + 0.02), mid + 0.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.5, 0.1, 3.2), ("band", "band"))
        p.box((0, -(r + 0.07), mid + 0.6), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.22, 0.06, 2.9), ("light", "light"))
    elif kind == "D6":                                  # landing plates where the clamps grip, a stencilled band
        for zc in (mid - 2.475, mid + 2.475):
            for sy in (1, -1):
                p.box((0, sy * (r + 0.03), zc), (1, 0, 0), (0, 1, 0), (0, 0, 1), (1.4, 0.08, 1.1), ("pad", "pad"))
        p.prism((0, 0, mid - 0.45), (0, 0, mid + 0.45), (1, 0, 0), r * 1.01, 20, "band", None, None)
        for k in range(5):
            a = 2 * math.pi * k / 5 + 0.3
            d, tg = np.array([math.cos(a), math.sin(a), 0]), np.array([-math.sin(a), math.cos(a), 0])
            p.box(d * (r * 1.02) + [0, 0, mid], d, tg, (0, 0, 1), (0.05, 0.5, 0.5), ("rim", "rim"))
    return p, B, dc, dr


def d_iterations(out):
    """The D variants: each stood beside the game's 20 mm round, and under the FK-7 seen from the side (its clamps on
    the body, the dome clear: checked, printed)."""
    import json
    os.makedirs(out, exist_ok=True)
    r20 = game_obj("HDTPItems", "HDTPHECannister", 1.0, rot_y(-90), (0, 4.2, 3.05), out, "r20")
    frames, states = [], []
    for tag, name, _ in VARIANTS:
        p, B, dc, dr = d_body(tag)
        frames.append([write_obj(moved(p, t=(0, -2.6, 0)), os.path.join(out, "alone_%s.obj" % tag)), r20])
        states.append(dict(eye=eye((0, 0.6, 4.6), 24, 32, 18), look=(0, 0.6, 4.6), lens=50))
        q = moved(p, rot_y(90))                         # along the kit, the dome forward
        V, _ = mesh(q)
        xs = flykit.clamp_xs(V - [B / 2, 0, 0])
        print("%s: clamps at %.2f and %.2f from the body's middle; the dome's collar starts at %.2f: clear by %.2f" % (
            tag, xs[0], xs[1], dc - 0.35 - B / 2, dc - 0.35 - B / 2 - xs[1] - CLAMP_HALF))
        frames.append(kitted(q, out, tag, cx=B / 2))
        states.append(dict(eye=eye((1.2, 0, -1.5), 30, 62, 10), look=(1.2, 0, -1.5), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def d_sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 640, 480
    S = Image.new("RGB", (2 * tw, 90 + len(VARIANTS) * (56 + th)), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Mobile sensor: the 20 mm form, iterated", fill=(240, 200, 120), font=font(38))
    y = 90
    for i, (tag, name, line) in enumerate(VARIANTS):
        d.text((24, y + 10), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(28))
        d.text((300, y + 16), line, fill=(200, 200, 205), font=font(20))
        for j, cap in enumerate(("beside the game's 20 mm round", "under the FK-7, side on")):
            im = Image.open(os.path.join(rd, "r%04d.png" % (i * 2 + j))).convert("RGB").resize((tw, th), Image.LANCZOS)
            S.paste(im, (j * tw, y + 56))
            d.text((j * tw + 12, y + 56 + th - 30), cap, fill=(255, 255, 255), font=font(18))
        y += 56 + th
    path = os.path.join(out, "sensor_20mm_iterations.png")
    S.save(path)
    print(path)


# ---- D1 textured (the user, 2026-11-03, D1 chosen: "do some stuff to those textures... more like what we see in the base
# game"): one painted 1024 skin baked from its 3D surface as the FK-7's are (flykit.bake_kit's way: each face its own cell,
# occlusion, wear and chipped paint from mech_storm.weathered, stencils from flykit.stencil), in the kit's own gunmetal so
# the two read as one maker's: engraved seams and recessed screws, a copper driving band, the status ring lit, the
# collar matte composite, a machined seat ring, the dome smoked glass with the sensor's iris at its pole, the bond pad's
# copper electrode traces; its markings: the name, the lot, a caution by the dome, an ID plate and barcode on the far side.
import mech_bake
import mech_storm

TEX_NAME, TEX_LOT, TEX_WARN = "MS-3  MOBILE SENSOR", "LOT 52-0611   MFD 05/2052", "OPTICAL DOME - DO NOT OBSTRUCT"


def layout_one(p, A=1024):
    """Each face its own cell in one skin's 256-unit UV square (as flykit.layout_kit, one sheet)."""
    from mech_parts import face_size, shelf_pack
    density = 60.0
    while True:
        rects = [(max(2, int(round(face_size(pts)[0] * density))), max(2, int(round(face_size(pts)[1] * density))))
                 for pts, _ in p.faces]
        placed = shelf_pack(rects, 255)
        if placed:
            break
        density *= 0.95
    p.cells = [(x, y, x + w, y + h) for x, y, w, h in placed]
    return density * A / 256


def paint_sensor(region, pos, n, sx, ty, w, h, mats, geo):
    """A sensor face's colour at its texels (stood on its base along z; geo: its body length B, radius r, dome centre dc
    and radius dr)."""
    B, r, dc, dr = geo["B"], geo["r"], geo["dc"], geo["dr"]
    flat = np.ones(pos.shape[:-1] + (1,))
    nb = np.broadcast_to(n, pos.shape)
    edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
    z = pos[..., 2]
    ang = np.arctan2(pos[..., 1], pos[..., 0])
    metal = mech_bake.triplanar(mats["gunmetal"], pos, nb, 6).mean(-1, keepdims=True) / 128.0
    if region in ("hull", "panel"):
        col = (flykit.SLATE if region == "hull" else flykit.SLATE * 1.14) * (0.82 + 0.3 * metal)
        if region == "hull":
            for zs in geo["seams"]:                     # engraved seams round it, a light lip below each
                d = z - zs
                col = np.where((np.abs(d) < 0.03)[..., None], col * 0.35, col)
                col = np.where(((d < -0.03) & (d > -0.06))[..., None], col * 1.25, col)
                for k in range(4):                      # recessed screws by each seam
                    a = math.pi / 4 + k * math.pi / 2
                    rr = np.hypot(((ang - a + math.pi) % (2 * math.pi) - math.pi) * r, d - 0.24)
                    col = np.where((rr < 0.09)[..., None], np.where((rr < 0.055)[..., None], col * 0.8, col * 0.4), col)
                    col = np.where(((rr < 0.055) & (np.abs(d - 0.24) < 0.012))[..., None], col * 0.4, col)
            # The markings on its +y side, reading along it from the dome (left to right under the kit, from its side).
            up = ((ang - math.pi / 2 + math.pi) % (2 * math.pi) - math.pi) * r
            zc = geo["mid"]
            col = np.where(flykit.stencil(TEX_NAME, -(z - zc), up - 0.2, 0.36, True)[..., None], np.array([214.0, 214, 206]), col)
            col = np.where(flykit.stencil(TEX_LOT, -(z - zc), up + 0.26, 0.16)[..., None], np.array([180.0, 182, 176]), col)
            warn = (np.abs(z - (B - 0.95)) < 0.22) & (np.abs(up) < 1.25)
            col = np.where(warn[..., None], mech_storm.HAZARD, col)
            col = np.where((warn & flykit.stencil(TEX_WARN, -(z - (B - 0.95)), up, 0.15, True))[..., None], mech_storm.INK, col)
            # The far side (-y): a pale ID plate and a barcode.
            far = ((ang + math.pi / 2 + math.pi) % (2 * math.pi) - math.pi) * r
            plate = (np.abs(z - zc) < 0.95) & (np.abs(far) < 0.5)
            col = np.where(plate[..., None], np.array([196.0, 196, 188]), col)
            bars = plate & (np.abs(far + 0.12) < 0.2)
            code = mech_storm.hashn(np.stack([z * 7.0, flat[..., 0] * 3, flat[..., 0] * 5], -1), 1.0, 7) > 0.5
            col = np.where((bars & code)[..., None], mech_storm.INK, col)
            col = np.where((plate & flykit.stencil("MS3-0611", (z - zc) * -1, far - 0.3, 0.12, True))[..., None], mech_storm.INK, col)
        else:                                           # the shoulder: knurled
            knurl = (np.mod(ang * 24 / math.pi + z * 6, 1) < 0.5) ^ (np.mod(ang * 24 / math.pi - z * 6, 1) < 0.5)
            col = np.where(knurl[..., None], col * 0.82, col)
        return mech_storm.weathered(col, pos, n, mats, edge, True, 31)
    if region == "band":                                # the driving band: copper, lathe grooves, worn bright
        col = flykit.COPPER * (0.78 + 0.16 * np.sin(z * 140))[..., None] * (0.85 + 0.25 * metal)
        return mech_storm.weathered(col, pos, n, mats, edge, False, 32)
    if region == "light":                               # the status ring, lit amber
        return flykit.AMBER * (0.85 + 0.15 * np.cos(ang * 6))[..., None]
    if region == "duct":                                # the collar: matte composite, moulded seams
        weave = mech_bake.triplanar(mats["carbon"], pos, nb, 10).mean(-1, keepdims=True) / 128.0
        col = flykit.COMPOSITE * (0.8 + 0.25 * weave)
        seam = np.abs(np.mod(ang, math.pi / 2) - math.pi / 4) < 0.02
        return mech_storm.weathered(np.where(seam[..., None], col * 0.5, col), pos, n, mats, edge, False, 33)
    if region == "rim":                                 # the seat ring: machined steel, lathe rings
        rad = np.hypot(pos[..., 0], pos[..., 1])
        return mech_storm.STEEL * (0.8 + 0.2 * np.sin(rad * 120 + z * 80))[..., None]
    if region == "glass":                               # smoked glass; the sensor's iris at its pole, seen through it
        el = np.clip((z - dc) / dr, 0, 1)
        col = np.array([14.0, 18, 26]) * (0.9 + 0.5 * el)[..., None]
        pr = np.hypot(pos[..., 0], pos[..., 1]) / dr
        col = np.where((pr < 0.34)[..., None], np.array([8.0, 10, 16]), col)
        col = np.where(((pr > 0.34) & (pr < 0.4))[..., None], np.array([70.0, 96, 128]), col)
        col = np.where(((pr > 0.55) & (pr < 0.57))[..., None], np.array([40.0, 54, 70]), col)
        return col
    if region == "pad":                                 # copper, interleaved electrode traces, a border
        rad = np.hypot(pos[..., 0], pos[..., 1])
        comb = np.mod(pos[..., 0] * 3.0, 2) < 1
        tine = np.where(comb, pos[..., 1] > -rad * 0.8, pos[..., 1] < rad * 0.8)
        col = np.where((np.mod(pos[..., 0] * 3.0, 1) < 0.55)[..., None] & tine[..., None], flykit.COPPER * 1.25, flykit.COPPER * 0.6)
        return np.where((rad > r * 0.74)[..., None], np.array([40.0, 34, 30]), col)
    return np.array(C.get(region, (0.3, 0.3, 0.3))) * 255 * flat


def bake_sensor(p, geo, out_png, A=1024):
    """The sensor's skin (flykit.bake_kit's way, one sheet)."""
    from PIL import Image
    from mech_parts import face_size
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel", "carbon")}
    mats["grunge"] = np.asarray(Image.open(os.path.join(mech_bake.MATS, "grunge.png")).convert("RGB"), float) / 255.0
    occ = []
    for pts, _ in p.faces:
        occ.append([pts[0], pts[1], pts[2]])
        if len(pts) == 4:
            occ.append([pts[0], pts[2], pts[3]])
    occ = np.array(occ)
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
    for (pts, region), (u0, v0, u1, v1) in zip(p.faces, p.cells):
        P = np.array(pts)
        n = flykit.unit(np.cross(P[1] - P[0], P[-1] - P[0]))
        w, h = face_size(P)
        ao = mech_bake.vertex_ao(P, np.repeat(n[None], len(P), 0), occ, rays=16, reach=1.6) if w * h > 0.05 else np.ones(len(P))
        X0, Y0, X1, Y1 = int(u0 * k), int(v0 * k), int(u1 * k), int(v1 * k)
        xs, ys = np.meshgrid(np.arange(X0 - 2, X1 + 2), np.arange(Y0 - 2, Y1 + 2))
        sx = np.clip((xs + 0.5 - X0) / max(1, X1 - X0), 0, 1)
        ty = np.clip((Y1 - (ys + 0.5)) / max(1, Y1 - Y0), 0, 1)
        if len(P) == 4:
            pos = ((1 - sx) * (1 - ty))[..., None] * P[0] + (sx * (1 - ty))[..., None] * P[1] \
                + (sx * ty)[..., None] * P[2] + ((1 - sx) * ty)[..., None] * P[3]
            a3 = (1 - sx) * (1 - ty) * ao[0] + sx * (1 - ty) * ao[1] + sx * ty * ao[2] + (1 - sx) * ty * ao[3]
        else:
            pos = P[0] + sx[..., None] * (P[1] - P[0]) + ty[..., None] * (P[2] - P[0])
            a3 = (1 - sx - ty) * ao[0] + sx * ao[1] + ty * ao[2]
        col = paint_sensor(region, pos, n, sx, ty, w, h, mats, geo)
        if region not in ("light", "glass"):
            col = col * (0.55 + 0.45 * np.clip(a3, 0, 1) ** 1.2)[..., None]
        ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
        img[ys[ok], xs[ok]] = col[ok]
        mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(out_png)


def write_textured(p, path, skin, R=np.eye(3), t=(0, 0, 0)):
    """A laid-out, baked part as OBJ (its cells as UVs, flykit.obj's way), turned by R and moved by t."""
    mtl = path[:-4] + ".mtl"
    with open(mtl, "w") as f:
        f.write("newmtl skin\nKd 1 1 1\nmap_Kd %s\n\n" % os.path.basename(skin))
        f.write("newmtl glass\nKd 1 1 1\nmap_Kd %s\nKs 0.9 0.9 0.9\nNs 700\n\n" % os.path.basename(skin))
        f.write("newmtl light\nKd 1 1 1\nmap_Kd %s\nKe 1.0 0.62 0.12\n\n" % os.path.basename(skin))
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        n = 0
        for (pts, region), (u0, v0, u1, v1) in zip(p.faces, p.cells):
            uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)] if len(pts) == 4 else [(u0, v1), (u1, v1), (u0, v0)]
            for v in pts:
                w = R @ np.asarray(v, float) + np.asarray(t, float)
                f.write("v %.4f %.4f %.4f\n" % (w[0], w[2], -w[1]))
            for u in uv:
                f.write("vt %.5f %.5f\n" % (u[0] / 256.0, 1 - u[1] / 256.0))
            mat = "glass" if region == "glass" else ("light" if region == "light" else "skin")
            f.write("usemtl %s\nf %s\n" % (mat, " ".join("%d/%d" % (n + k + 1, n + k + 1) for k in range(len(pts)))))
            n += len(pts)
    return path


def tex_build(out):
    """D1 textured: its skin, and its renders' spec (hero, its markings close, beside the game's grenades and 20 mm
    round, under the FK-7 side on and from below in front, stuck to a wall)."""
    import json
    os.makedirs(out, exist_ok=True)
    p, B, dc, dr = d_body("D1")
    s = R20
    geo = dict(B=B, r=1.8 * R20, dc=dc, dr=dr, mid=B / 2, seams=(2.35, 5.05))
    dens = layout_one(p)
    skin = os.path.join(out, "MobileSensor.png")
    bake_sensor(p, geo, skin)
    print("skin %.0f texels a unit -> %s" % (dens, skin))
    frames, states = [], []
    frames.append([write_textured(p, os.path.join(out, "hero.obj"), skin, t=(0, 0, -B / 2))])
    states.append(dict(eye=eye((0, 0, 0.5), 21, 35, 20), look=(0, 0, 0.5), lens=50))
    frames.append([write_textured(p, os.path.join(out, "marks.obj"), skin, t=(0, 0, -B / 2))])
    states.append(dict(eye=eye((0, 0, 0), 15, 90, 4), look=(0, 0, 0), lens=50))
    refs = [game_obj("HDTPItems", "HDTPLAMPickup", 1.0, np.eye(3), (0, 11.0, 4.0), out, "lam"),
            game_obj("HDTPItems", "HDTPEMPgrenadePickup", 1.0, np.eye(3), (0, 5.4, 2.45), out, "emp"),
            game_obj("HDTPItems", "HDTPHECannister", 1.0, rot_y(-90), (0, -5.0, 3.05), out, "r20")]
    frames.append([write_textured(p, os.path.join(out, "lineup.obj"), skin, t=(0, 0.6, 0))] + refs)
    states.append(dict(eye=eye((0, 2.5, 4.0), 34, 24, 14), look=(0, 2.5, 4.0), lens=50))
    kit_obj = kitted(moved(p, rot_y(90)), out, "D1t", cx=B / 2)[0]
    tex_k = write_textured(p, os.path.join(out, "kit_sensor.obj"), skin, R=rot_y(90), t=LAST_SEAT)   # (as kitted seated it)
    frames.append([kit_obj, tex_k])
    states.append(dict(eye=eye((1.2, 0, -1.5), 30, 62, 10), look=(1.2, 0, -1.5), lens=50))
    frames.append([kit_obj, tex_k])
    states.append(dict(eye=eye((2.5, 0, -3.0), 26, 25, -18), look=(2.5, 0, -3.0), lens=50))
    wall = Part("wall")
    wall.box((-0.35, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1), (0.4, 40, 40), ("wall", "wall"))
    frames.append([write_obj(wall, os.path.join(out, "wall.obj")), write_textured(p, os.path.join(out, "onwall.obj"), skin, R=rot_y(90))])
    states.append(dict(eye=eye((4, 0, 0), 22, 40, 14), look=(4, 0, 0), lens=50))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def tex_sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 640, 480
    caps = ("D1, textured", "its markings, close", "beside the game's LAM, EMP grenade and 20 mm round",
            "under the FK-7, side on", "under the FK-7, from below in front", "stuck to a wall")
    S = Image.new("RGB", (2 * tw, 80 + 3 * th), (24, 26, 30))
    d = ImageDraw.Draw(S)
    d.text((24, 16), "Mobile sensor D1: painted skin", fill=(240, 200, 120), font=font(38))
    for i, cap in enumerate(caps):
        im = Image.open(os.path.join(rd, "r%04d.png" % i)).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = (i % 2) * tw, 80 + (i // 2) * th
        S.paste(im, (x, y))
        d.text((x + 12, y + th - 30), cap, fill=(255, 255, 255), font=font(18))
    path = os.path.join(out, "sensor_d1_textured.png")
    S.save(path)
    print(path)


if __name__ == "__main__":
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "sensor"))
    {"build": build, "sheet": sheet, "d": d_iterations, "dsheet": d_sheet, "tex": tex_build, "texsheet": tex_sheet}[sys.argv[1]](out)
