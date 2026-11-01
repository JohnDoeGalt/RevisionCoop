"""The fly kit (docs/FLY_KITS.md; the user, 2026-10-30): a cheap, factory-made guidance-and-flight kit strapped to an
explosive from the Mech's inventory: two ducted fans side by side, a moulded spine with a sensor nose, a cradle under it
that clamps the payload; retro-future (gunmetal and slate, amber lights, hazard rims), about a hand across. The payloads
are the game's own meshes and skins (DeusExItems: LAMPickup, Rocket, HECannister20mm), read out of the game's package.

Frame: x forward, y left, z up; game units (about 2 cm). The payload hangs under the spine, along x.

  python -I tools/flykit.py concept [outdir]    (default build/mech/flykit: one OBJ per payload, its skins, for a look)
"""
import math, os, struct, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_bake
import ue1mesh
from mech_parts import Part

REV = os.environ.get("REV", r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision")
PACKAGES = {"HDTPItems": os.path.join(REV, "HDTP", "System", "HDTPItems.u"),
            "DeusExItems": os.path.join(REV, "System", "DeusExItems.u")}
SPINE = dict(length=7.0, width=2.6, height=1.7, z=0.4)
DUCT = dict(y=4.3, r_out=2.45, r_in=2.1, h=1.5, z=0.55, cant=8.0)
SCALE = 1.2                 # the body built at these sizes, then a fifth bigger
NAME = "FK-7  FLY KIT"      # its maker's name, stencilled on its sides (and the preview's title: the user, "sick af")
STUDIO = (0.80, 0.81, 0.83)  # the kit shown alone: a flat light grey backdrop (the user: "a solid color", not the floor)
TITLE, LINE = "FK-7 Fly Kit", "the Mech's drone kit, in flight"     # the preview's title card (tools/flykit_video.py)
COLOURS = {"hull": (0.24, 0.26, 0.29), "panel": (0.32, 0.34, 0.38), "duct": (0.16, 0.17, 0.19), "rim": (0.86, 0.66, 0.1),
           "rimdark": (0.08, 0.08, 0.08), "rotor": (0.12, 0.12, 0.13), "hub": (0.55, 0.56, 0.58), "lens": (0.05, 0.08, 0.14),
           "light": (1.0, 0.62, 0.12), "jaw": (0.2, 0.21, 0.23), "latch": (0.75, 0.22, 0.1), "band": (0.1, 0.1, 0.11),
           "pad": (0.55, 0.36, 0.16)}
# The payloads as Revision draws them with HDTP on (the user's: bHDTP_ALL=1; its Facelift: LAM, Rocket, HECannister20mm):
# package, mesh, draw scale (the projectile's), skins put over the mesh's own (by slot: the LAM lit, as Facelift sets
# MultiSkins[1]), and how it lies under the kit (degrees about x, then y, then z, after the mirror).
PAYLOADS = {"LAM": ("HDTPItems", "HDTPLAMPickup", 1.0, {1: "HDTPLAMTex0"}, (90, 0, 90)),
            "GEP rocket": ("HDTPItems", "HDTPRocket", 0.25, {}, (0, 0, -90)),       # (its point forward)
            "20 mm HE": ("HDTPItems", "HDTPHECannister", 1.0, {}, (0, 0, 0))}       # (a cased telescoped round, flat
                                                                                 # ends; ROUND20: a rounded one, if wanted)
# The 20 mm round on a kit, ours (the user, 2026-10-30: "round the end... that's how normal grenade launcher grenades
# work"; the game's, HDTP's too, is a plain cylinder, flown side-on): turned on a lathe, the size of the game's (6.1
# long, 3.6 across): a bevelled base, the body, an ogive from there into a small rounded fuze tip. (x along it, r.)
ROUND20 = [(-3.05, 0.0), (-3.05, 1.62), (-2.97, 1.76), (-2.9, 1.8), (0.6, 1.8)] + \
          [(0.6 + 2.15 * k / 8, 1.8 * math.sqrt(max(0.0, 1 - (2.15 * k / 8 / 2.45) ** 2))) for k in range(1, 9)] + \
          [(2.86, 0.74), (2.96, 0.56), (3.02, 0.32), (3.05, 0.0)]
_pkgs = {}


def lathe(profile, sides=16):
    """A solid turned about the x axis from profile [(x, r)...] (r 0 at its ends: closed there): (vertices, triangles)."""
    V, rings = [], []
    for x, r in profile:
        if r <= 1e-6:
            rings.append([len(V)])
            V.append((x, 0.0, 0.0))
        else:
            rings.append(list(range(len(V), len(V) + sides)))
            V += [(x, r * math.cos(2 * math.pi * k / sides), r * math.sin(2 * math.pi * k / sides)) for k in range(sides)]
    tris = []
    for a, b in zip(rings, rings[1:]):
        if len(a) == 1:
            tris += [(a[0], b[(k + 1) % sides], b[k]) for k in range(sides)]
        elif len(b) == 1:
            tris += [(a[k], a[(k + 1) % sides], b[0]) for k in range(sides)]
        else:
            for k in range(sides):
                j = (k + 1) % sides
                tris += [(a[k], a[j], b[j]), (a[k], b[j], b[k])]
    return np.array(V), tris


def package(name):
    if name not in _pkgs:
        _pkgs[name] = ue1mesh.Package(PACKAGES[name])
    return _pkgs[name]


def texture(pkg, i):
    """A mesh's texture (an object reference in pkg): (its name, RGB pixels), from pkg or the package it is imported from."""
    if i > 0:
        name, src = pkg.exports[i - 1]["name"], pkg
    else:
        imp = pkg.imports[-i - 1]
        name, o = imp[3], imp[2]
        while o < 0:
            outer = pkg.imports[-o - 1]
            o = outer[2]
        src = package(outer[3]) if outer[3] in PACKAGES else pkg
    return name, pixels(src, name)


def pixels(pkg, name):
    w, h, data, pal = pkg.read_texture(name)
    return np.array(pal, np.uint8)[np.frombuffer(data[:w * h], np.uint8)].reshape(h, w, 3)


def unit(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v) + 1e-12)


def rot(deg, axis):
    a = math.radians(deg)
    c, s = math.cos(a), math.sin(a)
    if axis == "x":
        return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    if axis == "y":
        return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


# ---- the payload, out of the game's package
def payload(name):
    """(vertices in the kit's frame, centred; triangles (a, b, c); per-corner UVs (0-1); per-triangle texture names,
    the textures {name: RGB array})."""
    pkgname, mesh, scale, skins, (rx, ry, rz) = PAYLOADS[name]
    if pkgname == "lathe":                                       # ours (repainted: no UVs or skins of the game's)
        V, tris = lathe(globals()[mesh])
        return V - (V.max(0) + V.min(0)) / 2, tris, [], [], {}
    pkg = package(pkgname)
    m = pkg.read_mesh(mesh)
    F = np.array(pkg.frames(m)[0], float)
    V = (F - np.array(m["origin"])) * np.array(m["scale"]) * scale
    V[:, 1] *= -1                                        # the game's frame is left-handed: y to the right
    V = V @ (rot(rz, "z") @ rot(ry, "y") @ rot(rx, "x")).T
    V -= (V.max(0) + V.min(0)) / 2
    texnames, tex = [], {}
    for slot, t in enumerate(m["textures"]):
        if slot in skins:
            tname, img = skins[slot], pixels(pkg, skins[slot])
        else:
            tname, img = texture(pkg, t)
        texnames.append(tname)
        tex[tname] = img
    tris, uvs, tnames = [], [], []
    for w0, w1, w2, mat in m["faces"]:
        corners = [m["wedges"][w] for w in (w0, w1, w2)]
        _, tidx = m["materials"][mat]
        tname = texnames[tidx] if tidx < len(texnames) else texnames[0]
        th, tw = tex[tname].shape[:2]
        tris.append((corners[0][0], corners[2][0], corners[1][0]))      # (wound back for the mirror)
        uvs.append([(corners[k][1] / 256.0, 1 - corners[k][2] / 256.0) for k in (0, 2, 1)])   # (byte UVs: the whole skin)
        tnames.append(tname)
    return V, tris, uvs, tnames, tex


# ---- the kit
def ring(c, r, n, a0=0.0):
    return [c + r * np.array([math.cos(a0 + 2 * math.pi * k / n), math.sin(a0 + 2 * math.pi * k / n), 0]) for k in range(n)]


def duct(p, centre, cant):
    """A ducted fan: its shell (outside, inside, top and bottom lips, the top lip in hazard stripes), five rotor blades
    on a hub, three stator vanes to the wall; canted forward by cant degrees."""
    R = rot(-cant, "y")
    c = np.asarray(centre, float)
    j0 = len(p.faces)                                            # (the whole duct tilts on its pylon: p.ducts)
    n = 20
    zb, zt = -DUCT["h"] / 2, DUCT["h"] / 2
    ob = ring(np.array([0, 0, zb]), DUCT["r_out"], n)
    ot = ring(np.array([0, 0, zt]), DUCT["r_out"], n)
    ib = ring(np.array([0, 0, zb]), DUCT["r_in"], n)
    it = ring(np.array([0, 0, zt]), DUCT["r_in"], n)
    P = lambda q: c + R @ q
    for k in range(n):
        j = (k + 1) % n
        p.add_quad(P(ob[k]), P(ob[j]), P(ot[j]), P(ot[k]), "duct")
        p.add_quad(P(ib[j]), P(ib[k]), P(it[k]), P(it[j]), "duct")
        p.add_quad(P(ot[k]), P(ot[j]), P(it[j]), P(it[k]), "rim" if k % 2 else "rimdark")
        p.add_quad(P(ib[k]), P(ib[j]), P(ob[j]), P(ob[k]), "duct")
    hub = np.array([0, 0, 0.15])
    i0 = len(p.faces)                                            # (the blades and hub spin: p.spins)
    for k in range(5):
        a = 2 * math.pi * k / 5
        d = np.array([math.cos(a), math.sin(a), 0])
        side = np.array([-d[1], d[0], 0])
        tilt = np.array([0, 0, 0.12])
        q0, q1 = hub + d * 0.4, hub + d * (DUCT["r_in"] - 0.08)
        p.add_quad(P(q0 - side * 0.32 - tilt), P(q1 - side * 0.22 - tilt), P(q1 + side * 0.22 + tilt), P(q0 + side * 0.32 + tilt), "rotor")
        p.add_quad(P(q0 + side * 0.32 + tilt), P(q1 + side * 0.22 + tilt), P(q1 - side * 0.22 - tilt), P(q0 - side * 0.32 - tilt), "rotor")
    hb, ht = ring(np.array([0, 0, -0.35]), 0.42, 8), ring(np.array([0, 0, 0.4]), 0.42, 8)
    for k in range(8):
        j = (k + 1) % 8
        p.add_quad(P(hb[k]), P(hb[j]), P(ht[j]), P(ht[k]), "hub")
        p.add_tri(P(np.array([0, 0, 0.5])), P(ht[k]), P(ht[j]), "hub")
    # Its turn (the two fans opposite ways, as twin rotors do): its faces, its centre, its axis, its way.
    p.spins = getattr(p, "spins", []) + [(i0, len(p.faces), c, R @ np.array([0, 0, 1.0]), 1 if c[1] > 0 else -1)]
    # The blur over the blades (translucent in the game: dark is clear), a disc at their plane.
    rr = DUCT["r_in"] - 0.06
    for k in range(20):
        a0, a1 = 2 * math.pi * k / 20, 2 * math.pi * (k + 1) / 20
        e0 = np.array([rr * math.cos(a0), rr * math.sin(a0), 0.2])
        e1 = np.array([rr * math.cos(a1), rr * math.sin(a1), 0.2])
        p.add_tri(P(np.array([0, 0, 0.2])), P(e0), P(e1), "blur")
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        d = np.array([math.cos(a), math.sin(a), 0])
        q0, q1 = np.array([0, 0, -0.5]) + d * 0.38, np.array([0, 0, -0.5]) + d * DUCT["r_in"]
        up = np.array([0, 0, 0.18])
        p.add_quad(P(q0 - up), P(q1 - up), P(q1 + up), P(q0 + up), "duct")
        p.add_quad(P(q0 + up), P(q1 + up), P(q1 - up), P(q0 - up), "duct")
    p.ducts = getattr(p, "ducts", []) + [(j0, len(p.faces), c, 1 if c[1] > 0 else -1)]


def chamfer_box(p, lo, hi, c, region, top_region=None):
    """A box with its four long top and bottom edges chamfered by c (x is its length)."""
    (x0, y0, z0), (x1, y1, z1) = lo, hi
    sec = [(y0 + c, z0), (y1 - c, z0), (y1, z0 + c), (y1, z1 - c), (y1 - c, z1), (y0 + c, z1), (y0, z1 - c), (y0, z0 + c)]
    n = len(sec)
    P = lambda x, s: np.array([x, s[0], s[1]])
    for k in range(n):
        s, t = sec[k], sec[(k + 1) % n]
        reg = top_region if (top_region and s[1] == z1 and t[1] == z1) else region
        p.add_quad(P(x0, t), P(x1, t), P(x1, s), P(x0, s), reg)
    for k in range(1, n - 1):
        p.add_tri(P(x1, sec[0]), P(x1, sec[k]), P(x1, sec[k + 1]), region)
        p.add_tri(P(x0, sec[0]), P(x0, sec[k + 1]), P(x0, sec[k]), region)


def kit(pay_box):
    """The kit's faces (Part, regions COLOURS) for a payload whose box (centred at the origin) is pay_box (size)."""
    p = Part("flykit", mesh="FlyKit")
    L, W, H, Z = SPINE["length"], SPINE["width"], SPINE["height"], SPINE["z"]
    chamfer_box(p, (-L / 2, -W / 2, Z - H / 2), (L / 2, W / 2, Z + H / 2), 0.35, "hull", "panel")
    # The sensor nose: a short drum, its lens, an amber ring round it.
    X = np.array([1.0, 0, 0])
    p.prism((L / 2, 0, Z), (L / 2 + 0.7, 0, Z), (0, 0, 1), 0.72, 12, "hull", None, None)
    p.prism((L / 2 + 0.7, 0, Z), (L / 2 + 0.78, 0, Z), (0, 0, 1), 0.72, 12, "light", None, None)
    p.prism((L / 2 + 0.78, 0, Z), (L / 2 + 0.82, 0, Z), (0, 0, 1), 0.5, 12, "lens", None, "lens")
    # The status light on top, a tail fin.
    p.box((-0.6, 0, Z + H / 2 + 0.08), X, (0, 1, 0), (0, 0, 1), (0.8, 0.5, 0.16), ("light", "light"))
    p.box((-L / 2 + 0.6, 0, Z + H / 2 + 0.55), X, (0, 1, 0), (0, 0, 1), (1.0, 0.16, 1.1), ("hull", "hull"))
    # Pylons out to the ducts.
    for sy in (1, -1):
        p.box((0, sy * (W / 2 + (DUCT["y"] - DUCT["r_out"] - W / 2) / 2 + 0.1), DUCT["z"]), X, (0, 1, 0), (0, 0, 1),
              (1.3, DUCT["y"] - DUCT["r_out"] - W / 2 + 0.4, 0.42), ("hull", "hull"))
        duct(p, (0, sy * DUCT["y"], DUCT["z"]), DUCT["cant"])
    # The whole body a fifth bigger (the user, 2026-10-30: "maybe make the fly kit a little bigger... 20% bigger").
    p.faces = [([q * SCALE for q in pts], region) for pts, region in p.faces]
    p.spins = [(i0, i1, c * SCALE, ax, way) for i0, i1, c, ax, way in p.spins]
    p.ducts = [(j0, j1, c * SCALE, way) for j0, j1, c, way in p.ducts]
    return p, (Z - H / 2) * SCALE


def spun(p, deg):
    """The kit's faces with each fan's blades and hub turned deg degrees its own way about its axis."""
    faces = list(p.faces)
    for i0, i1, c, ax, way in p.spins:
        a = math.radians(deg * way)
        K = np.array([[0, -ax[2], ax[1]], [ax[2], 0, -ax[0]], [-ax[1], ax[0], 0]])
        Rm = np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K          # (Rodrigues)
        for i in range(i0, i1):
            pts, region = faces[i]
            faces[i] = ([c + Rm @ (q - c) for q in pts], region)
    return faces


def blur_skin(S=256):
    """The fans' blur (RGBA: additive in the game, alpha for a look): clear at the hub, faint streaks out to a soft rim."""
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x + 0.5 - S / 2, y + 0.5 - S / 2) / (S / 2)
    a = np.arctan2(y + 0.5 - S / 2, x + 0.5 - S / 2)
    streak = 0.75 + 0.25 * np.cos(5 * a + 9 * r) ** 2
    v = np.clip((r - 0.22) / 0.5, 0, 1) ** 1.3 * np.clip((1.0 - r) / 0.06, 0, 1) * streak
    rgb = np.stack([v * 150, v * 150, v * 155], -1)
    return np.concatenate([rgb, (v * 150)[..., None]], -1).astype(np.uint8)


def section(V, tris, x):
    """The payload cut across at x: the points where its triangles' edges cross the plane."""
    pts = []
    for t in tris:
        for i, j in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
            a, b = V[i], V[j]
            if (a[0] - x) * (b[0] - x) <= 0 and a[0] != b[0]:
                pts.append(a + (b - a) * (x - a[0]) / (b[0] - a[0]))
    return np.array(pts)


CLAMP = dict(strut=0.75, bar=0.32, jaw=1.5, thick=0.24, depth=0.75, pad=0.12)
# Every clamp the same (the user, 2026-10-30: "the clamps should always have the same dimensions... telescopic going
# outward... not the actual gripping part going downward"): a strut down from the spine, a crossbar, two jaws down from
# its ends, each with an electro-bonding pad at its tip (lore: docs/FLY_KITS.md). Only the crossbar telescopes, out to
# the payload's width where the pads meet it.


def clamp_xs(V):
    L = SPINE["length"] * SCALE
    reach = min(L / 2 - 0.9, np.ptp(V[:, 0]) / 2 - 0.6)
    return (-reach * 0.75, reach * 0.75)


def seat(V, tris, under):
    """The payload moved up or down so its top under the clamps meets the crossbars' undersides."""
    top = max(section(V, tris, x)[:, 2].max() for x in clamp_xs(V))
    return V + np.array([0, 0, under - CLAMP["strut"] - CLAMP["bar"] - top])


def closest(P, A, B, C):
    """The closest point to P on each triangle (A, B, C: n x 3), Ericson's regions, all at once."""
    ab, ac, ap = B - A, C - A, P - A
    d1, d2 = (ab * ap).sum(1), (ac * ap).sum(1)
    bp = P - B
    d3, d4 = (ab * bp).sum(1), (ac * bp).sum(1)
    cp = P - C
    d5, d6 = (ab * cp).sum(1), (ac * cp).sum(1)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    den = va + vb + vc
    den = np.where(np.abs(den) < 1e-12, 1e-12, den)
    Q = A + ab * (vb / den)[:, None] + ac * (vc / den)[:, None]                       # inside the face
    e = lambda num, d: (num / np.where(np.abs(d) < 1e-12, 1e-12, d))[:, None]
    Q = np.where(((va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0))[:, None], B + (C - B) * e(d4 - d3, (d4 - d3) + (d5 - d6)), Q)
    Q = np.where(((vb <= 0) & (d2 >= 0) & (d6 <= 0))[:, None], A + ac * e(d2, d2 - d6), Q)
    Q = np.where(((d6 >= 0) & (d5 <= d6))[:, None], C, Q)
    Q = np.where(((vc <= 0) & (d1 >= 0) & (d3 <= 0))[:, None], A + ab * e(d1, d1 - d3), Q)
    Q = np.where(((d3 >= 0) & (d4 <= d3))[:, None], B, Q)
    Q = np.where(((d1 <= 0) & (d2 <= 0))[:, None], A, Q)
    return Q


def touch(P, V, tris):
    """The payload's surface point nearest P, and the distance to it (less than 0: P inside, by its side)."""
    T = np.array(tris)
    Q = closest(P, V[T[:, 0]], V[T[:, 1]], V[T[:, 2]])
    k = np.argmin(((Q - P) ** 2).sum(1))
    d = np.linalg.norm(P - Q[k])
    return Q[k], (d if abs(P[1]) >= abs(Q[k][1]) else -d)


def clamps(p, V, under, tris):
    """The two clamps onto the payload (its vertices V, seated); nothing under it. Each jaw ends in a ball joint and a
    pad that swivels flat onto the payload (the user, 2026-10-30: the pads "parallel with any surface that they're
    touching... the derivative of that surface"): the crossbar telescopes until the joint is a pad's thickness and a
    joint's off the surface, so the pad faces along the line from the surface's nearest point to the joint, which is
    its normal there (the pad tangent to it), on the flat LAM and the round rocket alike."""
    X, Y, Z = np.eye(3)
    c = CLAMP
    zbar = under - c["strut"] - c["bar"] / 2
    ztip = zbar - c["bar"] / 2 - c["jaw"]
    off = c["pad"] + 0.12                                             # the pad, then the joint, off the surface
    for x in clamp_xs(V):
        lo, hi = 0.0, np.abs(V[:, 1]).max() + 2.0                     # the jaws' reach out (each side the same)
        for _ in range(40):
            r = (lo + hi) / 2
            if touch(np.array([x, r, ztip]), V, tris)[1] < off:
                lo = r
            else:
                hi = r
        r = hi
        p.box((x, 0, under - c["strut"] / 2 + 0.03), X, Y, Z, (0.6, 0.7, c["strut"] + 0.06), ("jaw", "jaw"))      # strut
        p.box((x, 0, zbar), X, Y, Z, (c["depth"], 2 * r + c["thick"], c["bar"]), ("jaw", "jaw"))                  # crossbar
        for sy in (1, -1):
            tip = np.array([x, sy * r, ztip])
            p.box((x, sy * r, (zbar + ztip) / 2), X, Y, Z, (c["depth"], c["thick"], zbar - ztip), ("jaw", "jaw"))  # jaw
            q, _ = touch(tip, V, tris)
            n = unit(tip - q)                                         # the surface's normal at the pad
            u = unit(X - (X @ n) * n)
            p.box(tip - n * 0.06, u, np.cross(n, u), n, (0.24, 0.24, 0.24), ("jaw", "jaw"))                      # joint
            p.box(q + n * c["pad"] / 2, u, np.cross(n, u), n, (c["depth"] * 0.9, 0.62, c["pad"]), ("pad", "pad"))  # pad
        p.box((x + 0.48, r + c["thick"] / 2 + 0.08, zbar - 0.35), X, Y, Z, (0.22, 0.16, 0.5), ("latch", "latch"))


# ---- the kit's skins (the user, 2026-10-30: "at least on the detail level of the LAM", HDTP's 1024 x 512): two 1024
# skins (the body, pylons and clamps; the fans), every face its own cell, painted from its 3D surface: worn slate paint
# on gunmetal with engraved seams, screws, stencils, a caution label, a vent; composite ducts with hazard rims and
# warnings; blades with yellow tips; a machined hub; steel clamps with bolts, a red latch, copper electrode pads.
SKIN_SHEET = {"duct": 1, "rim": 1, "rimdark": 1, "rotor": 1, "hub": 1, "blur": 2}   # else skin 0 (2: the blur, its own)
SKIN = 1024
SLATE = np.array([62.0, 67.0, 74.0])
COMPOSITE = np.array([40.0, 42.0, 46.0])
AMBER = np.array([255.0, 168.0, 48.0])
COPPER = np.array([186.0, 116.0, 56.0])
SEAMS = (-2.9, -1.05, 1.15, 3.0)                 # the spine's panel seams (x, scaled)
_FONTS = {}


def stencil(text, r, u, height, bold=False):
    """Where text is (centred on r = u = 0, height tall, reading along r): a mask, from a TrueType face (crisp at 1024)."""
    from PIL import Image, ImageDraw, ImageFont
    key = (text, bold)
    if key not in _FONTS:
        font = ImageFont.truetype(r"C:\Windows\Fonts\bahnschrift.ttf", 64)
        w = int(ImageDraw.Draw(Image.new("L", (1, 1))).textlength(text, font=font)) + 8
        im = Image.new("L", (w, 80), 0)
        ImageDraw.Draw(im).text((4, 2), text, fill=255, font=font, stroke_width=2 if bold else 0, stroke_fill=255)
        _FONTS[key] = np.asarray(im) > 110
    m = _FONTS[key]
    H, W = m.shape
    px = np.floor((r / height + W / H / 2) * H).astype(int)
    py = np.floor((0.5 - u / height) * H).astype(int)
    ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
    return ok & m[np.clip(py, 0, H - 1), np.clip(px, 0, W - 1)]


def layout_kit(p):
    """Each kit face its own cell in its skin's 256-unit UV square (byte UVs: 4 texels a unit at 1024)."""
    from mech_parts import face_size, shelf_pack
    p.sheets = [SKIN_SHEET.get(r, 0) for _, r in p.faces]
    p.cells = [None] * len(p.faces)
    dens = []
    for s in (0, 1):
        own = [k for k in range(len(p.faces)) if p.sheets[k] == s]
        density = 40.0
        while True:
            rects = [(max(2, int(round(face_size(p.faces[k][0])[0] * density))),
                      max(2, int(round(face_size(p.faces[k][0])[1] * density)))) for k in own]
            placed = shelf_pack(rects, 255)
            if placed:
                break
            density *= 0.95
        for k, (x, y, w, h) in zip(own, placed):
            p.cells[k] = (x, y, x + w, y + h)
        dens.append(density * SKIN / 256)
    return dens


def duct_axis(pos):
    """For points of a duct: its centre (the nearer of the two) and their angle round it."""
    sy = np.sign(pos[..., 1])
    cy = sy * DUCT["y"] * SCALE
    return cy, np.arctan2(pos[..., 1] - cy, pos[..., 0])


def paint_kit(region, pos, n, sx, ty, w, h, mats):
    """A kit face's colour at its texels (pos: their 3D points; n: its normal; sx, ty: across the face; w, h: its size)."""
    import mech_storm
    flat = np.ones(pos.shape[:-1] + (1,))
    nb = np.broadcast_to(n, pos.shape)
    edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
    metal = mech_bake.triplanar(mats["gunmetal"], pos, nb, 6).mean(-1, keepdims=True) / 128.0
    if region in ("hull", "panel"):
        col = (SLATE if region == "hull" else SLATE * 1.16) * (0.82 + 0.3 * metal)
        on_spine = (np.abs(pos[..., 1]) < 1.7) & (pos[..., 2] > 0)
        for xs in SEAMS:                                             # engraved seams, a light lip on one side
            d = pos[..., 0] - xs
            col = np.where((on_spine & (np.abs(d) < 0.03))[..., None], col * 0.35, col)
            col = np.where((on_spine & (d > 0.03) & (d < 0.06))[..., None], col * 1.25, col)
        if abs(float(n[1])) > 0.8 and region == "hull":              # the sides: screws by the seams, markings
            zc = SPINE["z"] * SCALE
            for xs in SEAMS:
                for zs in (zc + 0.68, zc - 0.68):
                    for dx in (-0.2, 0.2):
                        rr = np.hypot(pos[..., 0] - xs - dx, pos[..., 2] - zs)
                        col = np.where((rr < 0.09)[..., None], np.where((rr < 0.06)[..., None], col * 0.75, col * 0.4), col)
                        slot = (rr < 0.06) & (np.abs(pos[..., 2] - zs) < 0.012)
                        col = np.where(slot[..., None], col * 0.4, col)
            way = -1.0 if n[1] > 0 else 1.0                          # (reading left to right from that side)
            rx = lambda x0: way * (pos[..., 0] - x0)
            col = np.where(stencil(NAME, rx(2.05), pos[..., 2] - (zc + 0.22), 0.34, True)[..., None], np.array([214.0, 214, 206]), col)
            col = np.where(stencil("LOT 52-0318   MFD 03/2052", rx(2.05), pos[..., 2] - (zc - 0.2), 0.16)[..., None], np.array([180.0, 182, 176]), col)
            box = (np.abs(pos[..., 0] + 2.05) < 0.78) & (np.abs(pos[..., 2] - zc) < 0.3)
            col = np.where(box[..., None], mech_storm.HAZARD, col)
            col = np.where((box & stencil("LIVE ORDNANCE", rx(-2.05), pos[..., 2] - (zc + 0.08), 0.17, True))[..., None], mech_storm.INK, col)
            col = np.where((box & stencil("HANDLE WITH CARE", rx(-2.05), pos[..., 2] - (zc - 0.14), 0.12))[..., None], mech_storm.INK, col)
            if n[1] < 0:                                             # a barcode on the right side
                bars = (pos[..., 0] > 0.2) & (pos[..., 0] < 1.0) & (np.abs(pos[..., 2] - (zc - 0.48)) < 0.1)
                code = mech_storm.hashn(np.stack([pos[..., 0] * 7.0, flat[..., 0] * 3, flat[..., 0] * 5], -1), 1.0, 7) > 0.5
                col = np.where((bars & code)[..., None], mech_storm.INK, np.where(bars[..., None], np.array([200.0, 200, 194]), col))
        if region == "panel" and n[2] > 0.8:                        # the top: a vent and the light's bezel
            vent = (np.abs(pos[..., 0] - 1.2) < 1.0) & (np.abs(pos[..., 1]) < 0.62)
            slots = vent & (np.mod(pos[..., 0] - 0.2, 0.17) < 0.075)
            col = np.where(vent[..., None], col * 0.75, col)
            col = np.where(slots[..., None], np.array([12.0, 12, 14]), col)
            bez = (np.abs(pos[..., 0] + 0.72) < 0.62) & (np.abs(pos[..., 1]) < 0.42)
            col = np.where(bez[..., None], col * 0.6, col)
        return mech_storm.weathered(col, pos, n, mats, edge, True, 21)
    if region == "light":                                            # lit amber, brightest in its middle
        g = 1 - 0.35 * np.clip(np.minimum(np.minimum(sx, 1 - sx), np.minimum(ty, 1 - ty)) * -4 + 1, 0, 1)
        return AMBER * (0.8 + 0.25 * g)[..., None]
    if region == "lens":                                             # dark glass, an iris ring (no painted glint: the
        c = pos[..., 1:3] - np.array([0.0, SPINE["z"] * SCALE])     # user, 2026-10-30; the light makes its own)
        rr = np.hypot(c[..., 0], c[..., 1])
        col = np.array([10.0, 16, 30]) * flat * (1 + 0.6 * np.clip(1 - rr / 0.6, 0, 1))[..., None]
        return np.where(((rr > 0.32) & (rr < 0.37))[..., None], np.array([60.0, 90, 130]), col)
    if region == "duct":                                             # matte composite; moulded seams outside, a scuff in
        weave = mech_bake.triplanar(mats["carbon"], pos, nb, 10).mean(-1, keepdims=True) / 128.0
        col = COMPOSITE * (0.8 + 0.25 * weave)
        cy, ang = duct_axis(pos)
        rad = np.hypot(pos[..., 0], pos[..., 1] - cy)
        if rad.mean() > DUCT["r_out"] * SCALE - 0.1 and abs(float(n[2])) < 0.5:     # the outer shell (no warnings:
            zc = DUCT["z"] * SCALE                                                    # the user: quads carry none)
            seam = (np.abs(np.mod(ang, np.pi / 2) - np.pi / 4) < 0.012) | (np.abs(pos[..., 2] - zc) < 0.02)
            col = np.where(seam[..., None], col * 0.45, col)
            for k in range(8):                                       # screws along the moulding line: recessed, dark
                a = np.pi / 8 + k * np.pi / 4                        # (the user: bright ones read as white dots)
                d = np.hypot((ang - a + np.pi) % (2 * np.pi) - np.pi, (pos[..., 2] - zc) / (DUCT["r_out"] * SCALE))
                r = d * DUCT["r_out"] * SCALE
                col = np.where((r < 0.075)[..., None], np.where((r < 0.045)[..., None], col * 0.85, col * 0.4), col)
        elif rad.mean() < DUCT["r_in"] * SCALE + 0.1 and abs(float(n[2])) < 0.5:   # the inside: worn where blades sweep
            band = np.abs(pos[..., 2] - (DUCT["z"] * SCALE + 0.15)) < 0.12
            col = np.where(band[..., None], col * 1.6, col * 0.8)
        return mech_storm.weathered(col, pos, n, mats, edge, False, 22)
    if region in ("rim", "rimdark"):                                 # hazard chevrons round the lip, worn
        cy, ang = duct_axis(pos)
        rad = np.hypot(pos[..., 0], pos[..., 1] - cy)
        stripe = np.mod(ang * 16 / np.pi + rad * 3.0, 2) < 1
        col = np.where(stripe[..., None], mech_storm.HAZARD, mech_storm.INK * 1.3)
        return mech_storm.weathered(col, pos, n, mats, edge, True, 23)
    if region == "rotor":                                            # dark composite, yellow tips, a pale leading edge
        cy, _ = duct_axis(pos)
        rad = np.hypot(pos[..., 0], pos[..., 1] - cy) / (DUCT["r_in"] * SCALE)
        col = COMPOSITE * 0.8 * flat
        col = np.where((rad > 0.82)[..., None], mech_storm.HAZARD, col)
        return np.where((edge < 0.05) & (rad < 0.82)[..., None], col * 1.8, col)
    if region == "hub":                                              # machined: lathe rings, five bolts
        cy, ang = duct_axis(pos)
        rad = np.hypot(pos[..., 0], pos[..., 1] - cy)
        col = mech_storm.STEEL * (0.85 + 0.15 * np.sin(rad * 90))[..., None]
        for k in range(5):
            a = 2 * np.pi * k / 5
            bolt = np.hypot(pos[..., 0] - 0.28 * np.cos(a), pos[..., 1] - cy - 0.28 * np.sin(a)) < 0.055
            col = np.where(bolt[..., None], col * 0.45, col)
        return col
    if region == "jaw":                                              # dark steel, worn bright at the edges
        steel = mech_bake.triplanar(mats["steel"], pos, nb, 8).mean(-1, keepdims=True) / 128.0
        col = np.array([58.0, 60, 64]) * (0.75 + 0.4 * steel)
        col = np.where(edge < 0.03, col * 1.7, col)
        return mech_storm.weathered(col, pos, n, mats, edge, False, 24)
    if region == "latch":                                            # red, "PULL"
        col = np.array([168.0, 46, 30]) * flat
        return np.where(stencil("PULL", (pos[..., 2] - pos[..., 2].mean()) * 1.0, (pos[..., 0] - pos[..., 0].mean()), 0.12, True)[..., None],
                        np.array([235.0, 230, 220]), col)
    if region == "pad":                                              # copper, interleaved electrode traces, a border
        col = COPPER * flat
        comb = np.mod(sx * 18, 2) < 1
        tine = np.where(comb, ty > 0.12, ty < 0.88)
        col = np.where((np.mod(sx * 18, 1) < 0.55)[..., None] & tine[..., None], COPPER * 1.25, COPPER * 0.6)
        return np.where(edge < 0.04, np.array([40.0, 34, 30]), col)
    return np.array(COLOURS.get(region, (0.3, 0.3, 0.3))) * 255 * flat


def bake_kit(p, sheet, out_png):
    """One of the kit's skins: every face's cell painted from its 3D surface, darkened in its corners and recesses
    (occlusion), its edges catching a little light."""
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
    A = SKIN
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
    for (pts, region), cell, sh in zip(p.faces, p.cells, p.sheets):
        if sh != sheet:
            continue
        u0, v0, u1, v1 = cell
        P = np.array(pts)
        n = unit(np.cross(P[1] - P[0], P[-1] - P[0]))
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
        col = paint_kit(region, pos, n, sx, ty, w, h, mats)
        if region not in ("light", "lens"):
            col = col * (0.55 + 0.45 * np.clip(a3, 0, 1) ** 1.2)[..., None]
        ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
        img[ys[ok], xs[ok]] = col[ok]
        mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    im.save(out_png)
    return im


# ---- payloads repainted (the user, 2026-10-30: the GEP rocket and the 20 mm round "could use the same treatment, since
# they are normally not really seen in game"; the LAM keeps Revision's HDTP skin): their own 1024 skin, every triangle
# its own cell, painted from where it is along the round (t: 0 at its back, 1 at its nose).
REPAINT = ("GEP rocket", "20 mm HE")
OLIVE = np.array([82.0, 87.0, 60.0])
ROCKET_GREY = np.array([84.0, 89.0, 82.0])


def repaint_faces(V, tris):
    """The payload's triangles as faces (corners in the kit's frame), each its outward normal."""
    from mech_parts import Part
    q = Part("payload", mesh="FlyKitPayload")
    c = (V.max(0) + V.min(0)) / 2
    for a, b, cc in tris:
        P = [V[a], V[b], V[cc]]
        n = np.cross(P[1] - P[0], P[2] - P[0])
        g = sum(P) / 3
        out = g - c
        out[0] *= 0.15                                            # (outward is mostly round the long axis)
        if n @ out < 0:
            P = [P[0], P[2], P[1]]
        q.add_tri(*P, "round")
    return q


def paint_round(name, pos, n, t, sx, ty, w, h, mats, zc):
    import mech_storm
    flat = np.ones(pos.shape[:-1] + (1,))
    nb = np.broadcast_to(n, pos.shape)
    edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
    metal = mech_bake.triplanar(mats["gunmetal"], pos, nb, 6).mean(-1, keepdims=True) / 128.0
    side = abs(float(n[1])) > 0.8                                # (the side-most facets: one stencil a side, centred on the round)
    way = -1.0 if n[1] > 0 else 1.0
    if name == "GEP rocket":                                     # olive-grey, an HE band, a seeker nose, a sooty nozzle
        col = ROCKET_GREY * (0.82 + 0.3 * metal)
        for s in (0.3, 0.55):
            col = np.where((np.abs(t - s) < 0.004)[..., None], col * 0.4, col)
        col = np.where(((t > 0.70) & (t < 0.745))[..., None], mech_storm.HAZARD, col)
        col = np.where(((t > 0.68) & (t < 0.69))[..., None], mech_storm.INK, col)
        col = np.where((t > 0.82)[..., None], np.array([24.0, 26, 30]) * (0.9 + 0.3 * metal), col)
        col = np.where((t > 0.965)[..., None], np.array([30.0, 60, 95]), col)
        soot = np.clip((0.08 - t) / 0.08, 0, 1)[..., None]
        col = col * (1 - 0.75 * soot) + np.array([70.0, 40, 20]) * 0.4 * soot
        if side:
            x0 = pos[..., 0].min() if False else None
            mid = lambda tt: tt
            col = np.where(stencil("GEP-HE  RKT", way * (t - 0.44) * 21.6, pos[..., 2] - zc, 0.55, True)[..., None],
                           np.array([214.0, 214, 206]), col)
            col = np.where(stencil("LOT 2052-117   GUIDED", way * (t - 0.44) * 21.6, pos[..., 2] - zc - 0.62, 0.26)[..., None],
                           np.array([190.0, 190, 184]), col)
        return mech_storm.weathered(col, pos, n, mats, edge, True, 31)
    # the 20 mm round, cased telescoped (the user, 2026-10-30: "a completely telescopic 20mm grenade": the projectile
    # inside a plain cylinder, flat ends, the game's shape): an olive case, its lip by the front, an HE band and its
    # stencil; the front a yellow seal plug in a ring; the base (the cupped end) dark, a brass primer in its middle
    col = OLIVE * (0.82 + 0.3 * metal)
    col = np.where(((t > 0.6) & (t < 0.68))[..., None], mech_storm.HAZARD, col)
    col = np.where(((t > 0.93) & (t < 0.945))[..., None], col * 0.45, col)
    if float(n[0]) > 0.9:                                        # the front: a seal plug
        rr = np.hypot(pos[..., 1], pos[..., 2] - zc)
        col = np.where((rr < 1.25)[..., None], mech_storm.HAZARD * (0.85 + 0.25 * metal), col * 0.8)
        col = np.where(((rr > 1.25) & (rr < 1.36))[..., None], np.array([30.0, 30, 28]), col)
    base = (t < 0.04) | (float(n[0]) < -0.9)
    if base.any():                                               # the base: dark, a brass primer
        rr = np.hypot(pos[..., 1], pos[..., 2] - zc)
        col = np.where(base[..., None], np.array([58.0, 59, 62]) * (0.8 + 0.3 * metal), col)
        col = np.where((base & (rr < 0.38))[..., None], mech_storm.BRASS, col)
    if side:
        col = np.where(stencil("20MM HE  CT", way * (t - 0.4) * 6.1, pos[..., 2] - zc, 0.4, True)[..., None],
                       np.array([20.0, 20, 18]), col)
    return mech_storm.weathered(col, pos, n, mats, edge, True, 32)


ROUND_SKINS = {"GEP rocket": 2, "20 mm HE": 2}   # (each over two skins, back half and front half: at least as fine as the LAM)


def repaint(name, V, tris, out_pattern):
    """The payload's own skins (out_pattern % sheet): its faces with their cells and sheets."""
    from PIL import Image
    from mech_parts import face_size, shelf_pack
    q = repaint_faces(V, tris)
    x0, x1 = V[:, 0].min(), V[:, 0].max()
    zc = (V[:, 2].max() + V[:, 2].min()) / 2
    nsk = ROUND_SKINS[name]
    q.sheets = [min(nsk - 1, int(nsk * (sum(f[0])[0] / 3 - x0) / (x1 - x0))) for f in q.faces]
    q.cells = [None] * len(q.faces)
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal",)}
    mats["grunge"] = np.asarray(Image.open(os.path.join(mech_bake.MATS, "grunge.png")).convert("RGB"), float) / 255.0
    A = SKIN
    for s in range(nsk):
        own = [i for i in range(len(q.faces)) if q.sheets[i] == s]
        density = 60.0
        while True:
            rects = [(max(2, int(round(face_size(q.faces[i][0])[0] * density))),
                      max(2, int(round(face_size(q.faces[i][0])[1] * density)))) for i in own]
            placed = shelf_pack(rects, 255)
            if placed:
                break
            density *= 0.95
        for i, (x, y, w, h) in zip(own, placed):
            q.cells[i] = (x, y, x + w, y + h)
        img, mask, k = np.zeros((A, A, 3)), np.zeros((A, A), bool), A / 256.0
        for i in own:
            P = np.array(q.faces[i][0])
            u0, v0, u1, v1 = q.cells[i]
            n = unit(np.cross(P[1] - P[0], P[2] - P[0]))
            w, h = face_size(P)
            X0, Y0, X1, Y1 = int(u0 * k), int(v0 * k), int(u1 * k), int(v1 * k)
            xs, ys = np.meshgrid(np.arange(X0 - 2, X1 + 2), np.arange(Y0 - 2, Y1 + 2))
            sx = np.clip((xs + 0.5 - X0) / max(1, X1 - X0), 0, 1)
            ty = np.clip((Y1 - (ys + 0.5)) / max(1, Y1 - Y0), 0, 1)
            pos = P[0] + sx[..., None] * (P[1] - P[0]) + ty[..., None] * (P[2] - P[0])
            t = (pos[..., 0] - x0) / (x1 - x0)
            col = paint_round(name, pos, n, t, sx, ty, w, h, mats, zc)
            ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
            img[ys[ok], xs[ok]] = col[ok]
            mask[ys[ok], xs[ok]] = True
        img = mech_bake.bleed(img, mask, passes=4)
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").save(out_pattern % s)
        print("%s: repainted skin %d, %.0f texels a unit" % (name, s, density * A / 256))
    return q


def build(name, out):
    """The kit with this payload, laid out and painted (skins as PNG into out, an .mtl for them): its state."""
    from PIL import Image
    V, tris, uvs, tnames, tex = payload(name)
    size = V.max(0) - V.min(0)
    p, under = kit(size)
    V = seat(V, tris, under)
    clamps(p, V, under, tris)
    dens = layout_kit(p)
    slug = name.lower().replace(" ", "_")
    own = None
    if name in REPAINT:
        own = repaint(name, V, tris, os.path.join(out, "flykit_" + slug + "_payload%d.png"))
    skins = []
    for s in (0, 1):
        skins.append("flykit_%s_skin%d" % (slug, s))
        bake_kit(p, s, os.path.join(out, skins[s] + ".png"))
    Image.fromarray(blur_skin(), "RGBA").save(os.path.join(out, "flykit_blur.png"))
    mtl = os.path.join(out, "flykit_%s.mtl" % slug)
    with open(mtl, "w") as f:
        for s in skins:
            f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (s, s))
        f.write("newmtl blur\nKd 1 1 1\nmap_Kd flykit_blur.png\nmap_d flykit_blur.png\n\n")
        if own is not None:
            for s in range(ROUND_SKINS[name]):
                f.write("newmtl payload%d\nKd 1 1 1\nmap_Kd flykit_%s_payload%d.png\n\n" % (s, slug, s))
        else:
            for t, img in tex.items():
                Image.fromarray(img).save(os.path.join(out, t + ".png"))
                f.write("newmtl tex_%s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (t, t))
    print("%s: kit skins %.0f and %.0f texels a unit" % (name, *dens))
    span = np.ptp(np.array([q for pts, r in p.faces for q in pts if r != "blur"]), axis=0)
    print("%s: kit %.1f x %.1f x %.1f units (%.0f x %.0f cm), payload %.1f x %.1f x %.1f" % (
        name, *span, span[0] * 1.9, span[1] * 1.9, *size))
    return dict(name=name, p=p, own=own, V=V, tris=tris, uvs=uvs, tnames=tnames, skins=skins, slug=slug, mtl=mtl)


def obj(path, st, faces=None, body=None, blur=False):
    """The kit (faces: posed, else as built; body: a function over points moving it all, else none) as an OBJ; its fans'
    blur discs only with blur (they need a renderer with translucency)."""
    p, own, skins = st["p"], st["own"], st["skins"]
    faces = faces if faces is not None else p.faces
    B = body or (lambda q: q)
    o = lambda v: "v %.4f %.4f %.4f\n" % (lambda w: (w[0], w[2], -w[1]))(B(np.asarray(v)))   # (Blender's OBJ: y up)
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.relpath(st["mtl"], os.path.dirname(os.path.abspath(path))).replace("\\", "/"))
        n, nt = 0, 0
        for (pts, region), cell, s, (pts0, _) in zip(faces, p.cells, p.sheets, p.faces):
            if region == "blur":
                if not blur:
                    continue
                c = np.asarray(pts0[0])
                ax = unit(np.cross(pts0[1] - c, pts0[2] - c))
                e1 = unit(pts0[1] - c - ax * ((pts0[1] - c) @ ax))
                e2 = np.cross(ax, e1)
                rr = np.linalg.norm(pts0[1] - c)
                uv = [(0.5 + 0.5 * ((q - c) @ e1) / rr, 0.5 + 0.5 * ((q - c) @ e2) / rr) for q in pts0]
                mat = "blur"
            else:
                u0, v0, u1, v1 = cell
                uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)] if len(pts) == 4 else [(u0, v1), (u1, v1), (u0, v0)]
                uv = [(u / 256.0, 1 - v / 256.0) for u, v in uv]
                mat = skins[s]
            for q in pts:
                f.write(o(q))
            for u in uv:
                f.write("vt %.5f %.5f\n" % u)
            f.write("usemtl %s\nf %s\n" % (mat, " ".join("%d/%d" % (n + k + 1, nt + k + 1) for k in range(len(pts)))))
            n += len(pts)
            nt += len(pts)
        if own is not None:                                     # the payload in its own skin
            for (pts, _), (u0, v0, u1, v1), s in zip(own.faces, own.cells, own.sheets):
                for q in pts:
                    f.write(o(q))
                for u in ((u0, v1), (u1, v1), (u0, v0)):
                    f.write("vt %.5f %.5f\n" % (u[0] / 256.0, 1 - u[1] / 256.0))
                f.write("usemtl payload%d\nf %d/%d %d/%d %d/%d\n" % (s, n + 1, nt + 1, n + 2, nt + 2, n + 3, nt + 3))
                n += 3
                nt += 3
        else:                                                   # the game's own (the LAM: Revision's HDTP skin)
            base = n
            for v in st["V"]:
                f.write(o(v))
            k = nt
            for (a, b, c), uv, t in zip(st["tris"], st["uvs"], st["tnames"]):
                for u in uv:
                    f.write("vt %.5f %.5f\n" % u)
                f.write("usemtl tex_%s\nf %d/%d %d/%d %d/%d\n" % (t, base + a + 1, k + 1, base + b + 1, k + 2, base + c + 1, k + 3))
                k += 3
    return path


def write(name, out):
    """<out>/flykit_<name>.obj (+ .mtl, the kit's skins and the payload's as PNG): the kit with this payload."""
    st = build(name, out)
    return obj(os.path.join(out, "flykit_%s.obj" % st["slug"]), st)


# ---- in flight (the user, 2026-10-30: "the arms actuating depending on how you're having it turn... really twitchy,
# responsive movement... a default hovering animation"): in the game, cosmetic and each machine's own (the fans their own
# attached pieces, tilted by code from the kit's own replicated movement: no traffic, no desync); here a preview.
MOTION = [("hover", dict()), ("forward", dict(tilt=38, pitch=-12)), ("brake", dict(tilt=-24, pitch=6)),
          ("turn left", dict(spin=1)), ("turn right", dict(spin=-1)),
          ("strafe left", dict(roll=-13)), ("strafe right", dict(roll=13)), ("fly past", dict(tilt=40, pitch=-13, fly=1))]
# A turn (the user, 2026-10-30: "a very snappy, quick left and right spin... really small, really high torque"): snap
# half turns at SPIN_RATE degrees a second, SPIN_TIME long, starting SPIN_AT into the manoeuvre, stopped dead between;
# the fans tip apart hard to start each (with the turn's acceleration) and the other way to stop it.
SPIN_RATE, SPIN_TIME, SPIN_AT = 1000.0, 0.18, (0.35, 1.35)
STEP = 2.5                                      # seconds a manoeuvre (its caption read: the user's rule for videos)
INTRO, OUTRO = 4.5, 4.0                         # seconds hovering under the title; flying on under the end card (read)
# A fly-past at 100 mph (16 units a foot: 2347 units a second; the user, 2026-10-30: "a true 100 mile an hour flyby
# with the Doppler effect", a real FPV racer's speed, the drone's fast mode in game): from about 56 m out, past the
# preview's camera (FLY_CAM) FLY_MISS to its side and a little below, on out the far side, straight and nose first. The
# camera pans after it FLY_LAG behind, as a cameraman would (it runs about 13 degrees ahead of the middle as it passes,
# about 280 pixels across); each of its frames blends SHUTTER moments over half a frame (a film camera's 180 degree
# shutter), so the pass smears as a fast one filmed does (within FLY_BLUR of the camera: further out, a speck, one).
# It flies on away into the distance under the end card (the user: no hover after the fly-by).
FLY_CAM = np.array([23.5, -16.5, 9.8])
FLY_SPEED, FLY_MISS, FLY_LAG, SHUTTER, FLY_BLUR = 100 * 5280 / 3600 * 16, 80.0, 0.015, 12, 800.0
_d = np.array([FLY_CAM[0], FLY_CAM[1], 0.0]) / np.hypot(FLY_CAM[0], FLY_CAM[1])
FLY_DIR, FLY_SIDE = _d, np.array([-_d[1], _d[0], 0.0])


def fly_at(e):
    """Where the fly-past is e seconds into it (by the camera half a manoeuvre in)."""
    return FLY_CAM + FLY_SIDE * FLY_MISS + FLY_DIR * (FLY_SPEED * (e - STEP / 2)) + np.array([0, 0, -8.0])


def tilted(faces, p, left, right):
    """The faces with each fan (its whole duct) turned fore or aft about its pylon (y) through its centre."""
    faces = list(faces)
    for j0, j1, c, way in p.ducts:
        a = math.radians(left if way > 0 else right)
        Rm = rot(a * 180 / math.pi, "y")
        for i in range(j0, j1):
            pts, region = faces[i]
            faces[i] = ([c + Rm @ (np.asarray(q) - c) for q in pts], region)
    return faces


def motion(name, out, fps=60):
    """Frames <out>/motion/f%04d.obj of the kit flying MOTION: its fans spinning (720 degrees a second), tilting together
    (forward, back) or apart (turning), the body pitching, rolling, turning, bobbing, all on stiff springs that
    overshoot a little (twitchy), with a fine jitter in the hover; the fly-past's frames each SHUTTER moments
    (f%04d_%d.obj); and the captions' times. It hovers INTRO seconds first (under the title) and OUTRO last (under the
    end card, the fly-past going on away): the picture never stands still under a card."""
    st = build(name, out)
    os.makedirs(os.path.join(out, "motion"), exist_ok=True)
    keys = ("tilt", "diff", "pitch", "roll", "yaw")
    pos = dict.fromkeys(keys, 0.0)
    vel = dict.fromkeys(keys, 0.0)
    heading = 0.0
    rng = np.random.default_rng(5)
    plan = [("", dict(), INTRO)] + [(label, want, STEP) for label, want in MOTION] + [("", MOTION[-1][1], OUTRO)]
    starts = np.cumsum([0.0] + [length for _, _, length in plan])
    n = int(round(starts[-1] * fps))
    jit = np.cumsum(rng.normal(size=(n + 1, 3)), 0)
    dt, k, d = 1.0 / fps, 700.0, 26.0                          # (a stiff spring, under-damped: it snaps and overshoots)
    paths, states, subs = [], [], []
    aim, fly0 = None, None
    for f in range(n):
        t = f * dt
        i = min(len(plan) - 1, int(np.searchsorted(starts, t, side="right")) - 1)
        label, want, length = plan[i]
        for key in keys:
            target = want.get(key, 0.0)
            if key == "yaw" and want.get("spin"):
                target = want["spin"] * SPIN_RATE * any(a <= t - starts[i] < a + SPIN_TIME for a in SPIN_AT)
            acc = k * (target - pos[key]) - d * vel[key]
            vel[key] += acc * dt
            pos[key] += vel[key] * dt
        heading += pos["yaw"] * dt                              # (yaw: a turn rate; its spring's speed, the turn's push)
        diff = pos["diff"] + max(-32.0, min(32.0, 0.0018 * vel["yaw"] + 0.008 * pos["yaw"]))
        j = (jit[f] - jit[max(0, f - 12)]) * 0.25               # (hover jitter: fast, small)
        bob = 0.22 * math.sin(2 * math.pi * 1.3 * t)
        left = pos["tilt"] + diff + j[0] * 1.5
        right = pos["tilt"] - diff + j[1] * 1.5
        Rb = rot(heading, "z") @ rot(pos["roll"] + j[2], "x") @ rot(pos["pitch"], "y")
        at = np.array([0.0, 0.0, bob])
        shots = [(t, at, [0.0, 0.0, 0.5])]                     # (when, where, the camera's look)
        if want.get("fly"):                                     # the fly-past (the camera pans after it)
            heading = math.degrees(math.atan2(FLY_DIR[1], FLY_DIR[0]))                  # (nose first)
            Rb = rot(heading, "z") @ rot(pos["roll"] + j[2], "x") @ rot(pos["pitch"], "y")
            shots = []
            fly0 = starts[i] if fly0 is None else fly0          # (from the first of its manoeuvres: it goes on after)
            for q in range(2 * SHUTTER):                        # (followed in steps of 1/24 frame; the first half shot)
                ts = t + q * dt / (2 * SHUTTER)
                where = at + fly_at(ts - fly0)
                to = (where - FLY_CAM) / np.linalg.norm(where - FLY_CAM)
                aim = to if aim is None else aim + (to - aim) * (1 - math.exp(-dt / (2 * SHUTTER) / FLY_LAG))
                aim = aim / np.linalg.norm(aim)
                if q < SHUTTER:
                    shots.append((ts, where, [float(v) for v in FLY_CAM + aim * 100.0]))
            if np.linalg.norm(shots[0][1] - FLY_CAM) > FLY_BLUR:
                shots = shots[:1]
            at = shots[0][1]
        else:
            aim, fly0 = None, None
        faces = tilted(spun(st["p"], 720.0 * t), st["p"], left, right)
        frame = []
        for q, (ts, where, look) in enumerate(shots):
            body = lambda v, Rb=Rb, where=where: Rb @ v + where
            fq = faces if q == 0 else tilted(spun(st["p"], 720.0 * ts), st["p"], left, right)
            name_q = "f%04d.obj" % f if len(shots) == 1 else "f%04d_%d.obj" % (f, q)
            frame.append(dict(obj=obj(os.path.join(out, "motion", name_q), st, fq, body, blur=True), look=look))
        paths.append(frame[0]["obj"])
        subs.append(frame if len(frame) > 1 else None)
        states.append(dict(throttle=min(1.0, (abs(pos["tilt"]) + abs(diff) + abs(pos["roll"]) * 0.8) / 28.0),
                           at=[float(v) for v in at], look=shots[0][2]))
    caps = [(float(starts[i]), float(starts[i + 1]), label) for i, (label, _, _) in enumerate(plan) if label]
    return paths, caps, states, subs


def main():
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "flykit"))
    os.makedirs(out, exist_ok=True)
    if sys.argv[1] == "motion":                 # python -I tools/flykit.py motion [outdir] [payload]: frames, captions
        import json
        paths, caps, states, subs = motion(sys.argv[3] if len(sys.argv) > 3 else "LAM", out)
        json.dump(dict(frames=paths, captions=caps, fps=60, states=states, subs=subs, title=TITLE, line=LINE, studio=STUDIO,
                       outro=len(paths) / 60.0 - OUTRO),
                  open(os.path.join(out, "motion", "motion.json"), "w"))
        print("motion:", len(paths), "frames")
        return
    for name in PAYLOADS:
        write(name, out)


if __name__ == "__main__":
    main()
