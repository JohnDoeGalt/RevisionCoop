"""The arms that hold the arm blades in their owner's view (CoopMechBlade), ours and built to be seen up close. (The body's
own forearms, tried first, were its far-off low-poly sleeves and mitten hands: the user called them "absolute garbage",
2026-10-27.) Machine-made, organic in shape (the user, 2026-10-29: "still... made out of machine", but "a more organic
shape and less industrial"): a muscled forearm (surface) sheathed in domed scale plates (shell), a teardrop blade
housing, a rounded collar at the wrist, a rounded fist under a ridged plate, fingers and a thumb of jointed tapered
segments with metal collars; shaded round in the game (SMOOTH: blade_view.shared welds them). The blade, a diamond in
section with a point, comes out of the housing's mouth over the fist. One model; each class paints it (mech_storm's kit, mech_bake's materials):

- Jensen   the Light Mech: Adam Jensen's black prosthetics (Mankind Divided), glossy, gold seams (Human Revolution)
- Mech     the Mech: the nanosuit's gauntlets (the user's sheet), matte black hex armour, gunmetal plates, blue lights

Frame: the right forearm's: x from the elbow (0) to past the fist, y to its left, z up (the back of the hand: palm
down); game units (about 2 cm). The left arm is its mirror. tools/blade_view.py poses them in the view.

  python -I tools/blade_arms.py preview [Mech|Jensen] [outdir]     (default build/mech/arms: skins, OBJ, a sheet)
"""
import math, os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_bake
from mech_parts import Part, face_size, shelf_pack

N = 16                                          # sides round the forearm
WRIST = 13.0                                    # where the forearm's armour ends
MOUTH = 13.9                                    # the housing's mouth: the blade comes out here
BLADE = dict(x1=26.0, tip=2.8, half=0.6, thick=0.13, z=1.72)
SHEETS = {"core": 0, "plate": 0, "rim": 0, "housing": 0, "joint": 0, "slot": 0}   # else 1 (the hand, the blade)
SMOOTH = ("core", "plate", "housing", "joint", "hand", "finger", "hinge")   # shaded round in the game


def unit(v):
    return v / (np.linalg.norm(v) + 1e-12)


def face(p, pts, out, region):
    """A face whose normal points along out (its corners reordered if not)."""
    P = [np.asarray(x, float) for x in pts]
    n = np.cross(P[1] - P[0], P[2] - P[0]) if len(P) == 3 else np.cross(P[2] - P[0], P[3] - P[1])
    if n @ out < 0:
        P = P[::-1]
    (p.add_quad if len(P) == 4 else p.add_tri)(*P, region)


def ring(x, ry, rz, zc=0.0, n=N, a0=0.0, a1=2 * math.pi, closed=True):
    """Points round an ellipse at x (angle 0 at +y, going up over the top)."""
    k = n if closed else n - 1
    return np.array([[x, ry * math.cos(a0 + (a1 - a0) * i / k), zc + rz * math.sin(a0 + (a1 - a0) * i / k)] for i in range(n)])


def loft(p, secs, region, caps=(None, None)):
    """Closed convex sections (each (n, 3)) joined in order; their ends capped (fans from their centres)."""
    for A, B in zip(secs, secs[1:]):
        c = (A.mean(0) + B.mean(0)) / 2
        for i in range(len(A)):
            j = (i + 1) % len(A)
            q = [A[i], A[j], B[j], B[i]]
            face(p, q, np.mean(q, 0) - c, region)
    for S, cap, d in ((secs[0], caps[0], secs[0].mean(0) - secs[1].mean(0)), (secs[-1], caps[1], secs[-1].mean(0) - secs[-2].mean(0))):
        if cap:
            c = S.mean(0)
            for i in range(len(S)):
                face(p, [c, S[i], S[(i + 1) % len(S)]], d, cap)


def superellipse(c, u, v, hu, hv, e=2.6, n=12):
    """Points round a rounded-square section about c in the plane (u, v): half sizes hu, hv, exponent e."""
    out = []
    for i in range(n):
        t = 2 * math.pi * i / n
        cu, cv = math.cos(t), math.sin(t)
        out.append(c + u * hu * math.copysign(abs(cu) ** (2 / e), cu) + v * hv * math.copysign(abs(cv) ** (2 / e), cv))
    return np.array(out)


def frame_of(a, b, up):
    """Unit axes (u along a to b, v, w ~ up) of a segment."""
    u = unit(np.asarray(b, float) - np.asarray(a, float))
    up = np.asarray(up, float)
    w = up - (up @ u) * u
    if np.linalg.norm(w) < 1e-6:
        w = np.array([1.0, 0, 0]) - u[0] * u
    w = unit(w)
    return u, np.cross(w, u), w


def capsule(p, a, b, r0, r1, region, n=8, up=(0, 0, 1), rounds=(True, True)):
    """A tapered rod from a to b (radii r0, r1) with rounded ends: a finger's segment."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    u, v, w = frame_of(a, b, up)
    rings = []
    if rounds[0]:
        rings += [(a - u * r0 * 0.72, r0 * 0.42), (a - u * r0 * 0.36, r0 * 0.84)]
    rings += [(a, r0), ((a + b) / 2, (r0 + r1) / 2), (b, r1)]
    if rounds[1]:
        rings += [(b + u * r1 * 0.36, r1 * 0.84), (b + u * r1 * 0.72, r1 * 0.42)]
    secs = [np.array([c + r * (math.cos(2 * math.pi * k / n) * v + math.sin(2 * math.pi * k / n) * w) for k in range(n)])
            for c, r in rings]
    loft(p, secs, region, (region, region))


def ang(t):
    return (t + math.pi) % (2 * math.pi) - math.pi


def radii(x):
    """The forearm's (ry, rz) along it: broad by the elbow, slimmer and flatter to the wrist."""
    xs = [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 11.5, WRIST]
    ry = [2.0, 2.12, 2.08, 1.95, 1.8, 1.66, 1.57, 1.5]
    rz = [1.82, 1.92, 1.86, 1.72, 1.56, 1.41, 1.31, 1.24]
    return float(np.interp(x, xs, ry)), float(np.interp(x, xs, rz))


def surface(x, th):
    """A point of the forearm's skin at x and angle th (0 at +y, up over the top): the ellipse of radii(x) swelled by
    the muscles, the extensors over the top toward the thumb's side and the flexors underneath, both strongest near
    the elbow and gone by the wrist."""
    ry, rz = radii(x)
    m = 1 + 0.11 * math.exp(-((x - 3.2) / 3.2) ** 2) * math.exp(-(ang(th - 1.3) / 0.75) ** 2) \
          + 0.09 * math.exp(-((x - 4.2) / 3.6) ** 2) * math.exp(-(ang(th - 4.55) / 0.9) ** 2)
    return np.array([x, ry * m * math.cos(th), rz * m * math.sin(th)])


PLATES = []                                     # the armour's shells: (x0, x1, centre angle, half width at 0 and 1, scallop)


def shell(p, x0, x1, thc, half0, half1, thick, scallop=0.35, nx=10, na=8):
    """A domed plate over the forearm's skin, shaped as a sheath over the muscle: from x0 to x1, centred at angle thc,
    half0 to half1 radians wide, its ends arched (the leading edge, toward the wrist, a point), its edges a lip of a
    third of its thickness; recorded in PLATES for the paint."""
    PLATES.append((x0, x1, thc, half0, half1, scallop))
    def at(u, v, lift):
        x = (x0 + 0.25 * scallop * v * v) * (1 - u) + (x1 - scallop * v * v) * u
        half = half0 + (half1 - half0) * u
        th = thc + v * half
        s = surface(x, th)
        rad = unit(np.array([0.0, s[1], s[2]]))
        prof = 0.34 + 0.66 * math.sqrt(max(0.0, 1 - abs(v) ** 6)) * math.sqrt(max(0.0, 1 - abs(2 * u - 1) ** 8))
        return s + rad * (thick * prof * lift + 0.01)
    us = np.linspace(0, 1, nx + 1)
    vs = np.linspace(-1, 1, na + 1)
    G = [[at(u, v, 1.0) for v in vs] for u in us]
    B = [[at(u, v, 0.0) for v in vs] for u in us]
    for i in range(nx):
        for j in range(na):
            q = [G[i][j], G[i][j + 1], G[i + 1][j + 1], G[i + 1][j]]
            m = np.mean(q, 0)
            face(p, q, m - np.array([m[0], 0, 0]), "plate")
    edges = [(G[i][0], G[i + 1][0], B[i + 1][0], B[i][0]) for i in range(nx)] \
        + [(G[i][na], G[i + 1][na], B[i + 1][na], B[i][na]) for i in range(nx)] \
        + [(G[0][j], G[0][j + 1], B[0][j + 1], B[0][j]) for j in range(na)] \
        + [(G[nx][j], G[nx][j + 1], B[nx][j + 1], B[nx][j]) for j in range(na)]
    centre = at(0.5, 0.0, 0.5)
    for q in edges:
        m = np.mean(q, 0)
        face(p, list(q), m - centre, "rim")


def build():
    """The right arm with its blade; each face's group in p.groups ("arm", "blade"). Machine-made, organic in shape
    (the user, 2026-10-29: "they should still look like they're made out of machine... but the arms themselves should
    have a more organic shape and be less industrial"): a muscled forearm sheathed in domed scale plates, a teardrop
    housing, a rounded collar at the wrist, a rounded hand under a ridged plate, fingers of jointed tapered segments."""
    p = Part("bladearm", mesh="BladeArm")
    p.groups = []
    del PLATES[:]
    th = [2 * math.pi * i / N for i in range(N)]
    loft(p, [np.array([surface(x, t) for t in th]) for x in np.linspace(0.0, WRIST, 11)], "core", ("slot", None))
    # The armour: three overlapping scales over the extensors (the housing rides on them), a sheath under the flexors.
    shell(p, 0.5, 4.75, 1.38, 0.98, 0.9, 0.2)
    shell(p, 4.45, 8.75, 1.4, 0.88, 0.74, 0.19)
    shell(p, 8.45, 12.55, 1.42, 0.72, 0.5, 0.17)
    shell(p, 1.6, 11.7, 4.62, 0.78, 0.42, 0.14, scallop=0.5, nx=12)
    # The wrist's collar: rounded.
    loft(p, [ring(x, ry, rz) for x, ry, rz in ((12.45, 1.46, 1.24), (12.75, 1.57, 1.36), (13.05, 1.63, 1.43),
                                                (13.45, 1.61, 1.41), (13.8, 1.52, 1.31), (13.98, 1.44, 1.22))], "joint")
    # The blade's housing: a teardrop along the top, pointed behind, its mouth over the wrist.
    secs = []
    for x in np.linspace(4.3, MOUTH, 9):
        u = (x - 4.3) / (MOUTH - 4.3)
        s = math.sin(min(1.0, u * 1.7) * math.pi / 2)
        hh = max(0.04, 0.42 * s)
        base = surface(x, math.pi / 2)[2] + 0.23 + hh                  # on the scales...
        zc = base + (BLADE["z"] - base) * u ** 3                        # ...to the blade's height at the mouth
        secs.append(superellipse(np.array([x, 0.0, zc]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]),
                                 max(0.06, 0.68 * s), hh, 2.4, 10))
    loft(p, secs, "housing", ("housing", "housing"))
    # The hand, palm down: rounded, a plate over its back with a ridge to each knuckle.
    secs = [superellipse(np.array([x, 0.05, zc]), np.array([0, 1.0, 0]), np.array([0, 0, 1.0]), hy, hz, 3.0, 14)
            for x, hy, hz, zc in ((13.3, 1.62, 1.0, -0.16), (14.2, 1.88, 1.1, -0.18), (15.2, 2.06, 1.12, -0.2),
                                  (16.2, 2.12, 1.05, -0.2), (16.95, 2.04, 0.94, -0.2))]
    loft(p, secs, "hand", ("hand", "hand"))
    knuckles = (1.55, 0.53, -0.5, -1.48)
    def back(x, y, lift):
        hz = float(np.interp(x, (13.3, 14.2, 15.2, 16.2, 16.95), (1.0, 1.1, 1.12, 1.05, 0.94)))
        hy = float(np.interp(x, (13.3, 14.2, 15.2, 16.2, 16.95), (1.62, 1.88, 2.06, 2.12, 2.04)))
        t = min(1.0, abs(y - 0.05) / hy)
        z = -0.2 + hz * (1 - t ** 3.0) ** (1 / 3.0)
        ridge = sum(math.exp(-((y - k) / 0.2) ** 2) for k in knuckles) * min(1.0, max(0.0, (x - 14.4) / 2.0))
        return np.array([x, y, z + 0.01 + lift * (0.07 + 0.05 * ridge)])
    xs, ys = np.linspace(14.0, 16.85, 7), np.linspace(-1.75, 1.85, 9)
    G = [[back(x, y, 1.0) for y in ys] for x in xs]
    for i in range(len(xs) - 1):
        for j in range(len(ys) - 1):
            face(p, [G[i][j], G[i][j + 1], G[i + 1][j + 1], G[i + 1][j]], np.array([0, 0, 1.0]), "plate")
    for i in range(len(xs) - 1):
        for j in (0, len(ys) - 1):
            face(p, [G[i][j], G[i + 1][j], back(xs[i + 1], ys[j], 0.0), back(xs[i], ys[j], 0.0)],
                 np.array([0, 1.0 if j else -1.0, 0]), "rim")
    for i in (0, len(xs) - 1):
        for j in range(len(ys) - 1):
            face(p, [G[i][j], G[i][j + 1], back(xs[i], ys[j + 1], 0.0), back(xs[i], ys[j], 0.0)],
                 np.array([1.0 if i else -1.0, 0, 0]), "rim")
    # The fingers, curled under (index .. little), each three tapered segments, a metal collar at each joint; the thumb
    # across them.
    for y, fwd in ((1.55, 0.0), (0.53, 0.15), (-0.5, 0.05), (-1.48, -0.3)):
        s = 0.9 if y < -1 else 1.0
        J = [np.array(j) for j in ((16.7 + fwd, y, 0.35), (17.55 + fwd, y, 0.25), (17.72 + fwd, y, -1.05),
                                   (16.55 + fwd, y, -1.42))]
        R = [0.42 * s, 0.4 * s, 0.38 * s, 0.31 * s]
        for k in range(3):
            capsule(p, J[k], J[k + 1], R[k] * 0.97, R[k + 1] * 0.97, "finger", n=8, up=(0, 1, 0),
                    rounds=(k == 0, k == 2))
        for k in (1, 2):
            d = unit(J[k + 1] - J[k - 1])
            capsule(p, J[k] - d * 0.09, J[k] + d * 0.09, R[k] * 1.08, R[k] * 1.08, "hinge", n=8, up=(0, 1, 0),
                    rounds=(False, False))
    T = [np.array(t) for t in ((14.6, 2.0, -0.45), (16.75, 2.16, -1.18), (18.1, 0.62, -1.5))]
    capsule(p, T[0], T[1], 0.5, 0.45, "finger", n=8, up=(0, 0, 1), rounds=(True, False))
    capsule(p, T[1], T[2], 0.44, 0.36, "finger", n=8, up=(0, 0, 1), rounds=(False, True))
    d = unit(T[2] - T[0])
    capsule(p, T[1] - d * 0.1, T[1] + d * 0.1, 0.5, 0.5, "hinge", n=8, up=(0, 0, 1), rounds=(False, False))
    tag(p, "arm")
    # The blade: a flat diamond (its flats up and down, an edge each side), out of the mouth, a point.
    b = BLADE
    sec = lambda x, s: np.array([[x, 0.0, b["z"] + b["thick"] * s], [x, b["half"] * s, b["z"]],
                                 [x, 0.0, b["z"] - b["thick"] * s], [x, -b["half"] * s, b["z"]]])
    x2 = b["x1"] - b["tip"]
    S0, S1 = sec(MOUTH - 0.4, 1.0), sec(x2, 1.08)
    loft(p, [S0, S1], "blade")
    tip = np.array([b["x1"], -0.25, b["z"]])
    for i in range(4):
        q = [S1[i], S1[(i + 1) % 4], tip]
        face(p, q, np.mean(q, 0) - np.array([x2, 0, b["z"]]), "blade")
    tag(p, "blade")
    p.smooth = SMOOTH
    return p


def tag(p, group):
    p.groups += [group] * (len(p.faces) - len(p.groups))


def layout(p):
    """Each face its cell in its skin's 256-unit UV square: two skins (the forearm; the hand and the blade)."""
    p.cells = [None] * len(p.faces)
    p.sheets = [SHEETS.get(r, 1) for _, r in p.faces]
    for sheet in (0, 1):
        own = [k for k in range(len(p.faces)) if p.sheets[k] == sheet]
        density = 60.0
        while True:
            rects = [(max(2, int(round(face_size(p.faces[k][0])[0] * density))),
                      max(2, int(round(face_size(p.faces[k][0])[1] * density)))) for k in own]
            placed = shelf_pack(rects, 255)
            if placed:
                break
            density *= 0.96
        for k, (x, y, w, h) in zip(own, placed):
            p.cells[k] = (x, y, x + w, y + h)


# ---- paint: per texel, the face's 3D point, its normal, its edges; lit by mech_bake.lit (key light, gloss).
GOLD = np.array([196.0, 150.0, 72.0])
STEEL = np.array([168.0, 174.0, 182.0])


def edge_of(sx, ty, w, h):
    return np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))


def plate_edge(pos):
    """How near each point is to the rim of the forearm plate it lies on (PLATES): 0 at its middle, 1 at its rim."""
    th = np.arctan2(pos[:, 2], pos[:, 1])
    best = np.full(len(pos), 9.0)
    for x0, x1, thc, h0, h1, _ in PLATES:
        u = (pos[:, 0] - x0) / (x1 - x0)
        v = np.abs((th - thc + math.pi) % (2 * math.pi) - math.pi) / (h0 + (h1 - h0) * np.clip(u, 0, 1))
        e = np.maximum(v, np.abs(2 * u - 1))
        best = np.minimum(best, e)
    return best


def worn(col, pos, nn, mats, amount=1.0):
    """Grit, dirt and bright scratches from the grunge swatch (tools/grunge.py), as the Arm Cannon's metal."""
    g = mech_bake.triplanar(mats["grunge"], pos, nn, 22.0)
    dirt, grain, scr = g[:, 0:1], g[:, 1:2] - 0.5, g[:, 2:3] - 0.5
    col = col * (1 + 0.9 * amount * grain) * (1 - 0.35 * amount * dirt)
    return col + (np.array([[126.0, 128, 130]]) - col) * np.clip((scr - 0.06) * 4.0, 0, 1) * 0.35 * amount


def paint(cls, region, pos, n, ao, edge, mats):
    """(points (k, 3), the face's normal, occlusion (k,), distance to the face's edge (k,)) -> colours (k, 3)."""
    k = len(pos)
    nn = np.repeat(n[None], k, 0)
    if region == "rim":
        region = "plate"
        rim = True
    else:
        rim = False
    if region in ("core", "plate", "joint", "housing") and not rim:
        # Lit as the curved shell it stands for (round the forearm's axis), not as flat facets that each catch the
        # gloss whole (they showed as white panels): the face's normal bent toward the radial.
        rad = pos * np.array([0.0, 1, 1])
        rad /= np.linalg.norm(rad, axis=1, keepdims=True) + 1e-9
        facing = np.abs(rad @ n) > 0.5
        bent = 0.4 * nn + 0.6 * rad * np.sign(rad @ n)[:, None]
        nn = np.where(facing[:, None], bent / (np.linalg.norm(bent, axis=1, keepdims=True) + 1e-9), nn)
    if region == "blade":
        rim = np.clip(1 - np.abs(np.abs(pos[:, 1]) - 0.55) / 0.12, 0, 1)            # the bright edges
        fuller = mech_bake.line(np.abs(pos[:, 1]) - 0.18, 0.05) * (pos[:, 0] < BLADE["x1"] - 3.4)
        grain = mech_bake.triplanar(mats["steel"], pos, nn, 20).mean(-1) / 128.0
        col = STEEL[None] * (0.82 + 0.12 * grain)[:, None]
        col = col * (1 - 0.35 * fuller)[:, None] + (rim * 70)[:, None]
        return mech_bake.lit(col, nn, ao, gloss=150, power=24)
    if region == "slot":
        return np.repeat(np.array([[8.0, 8, 9]]), k, 0)
    if region == "joint":
        g = mech_bake.triplanar(mats["gunmetal"], pos, nn, 30).mean(-1) / 128.0
        ribs = mech_bake.line(np.mod(math.pi * 0 + np.arctan2(pos[:, 2], pos[:, 1]) * 4.0, 1.0) - 0.5, 0.18)
        col = np.array([[62.0, 64, 70]]) * (0.8 + 0.25 * g)[:, None] * (1 - 0.4 * ribs)[:, None]
        return mech_bake.lit(col, nn, ao, gloss=60)
    # A plate's rim, by its own shape (the shells' faces are a grid: their own edges are no edges): a lit lip and an
    # engraved line inside it; two screws near each forearm plate's back end. (The hand's plate: its middle.)
    if region == "plate" and not rim:
        e = np.where(pos[:, 0] > WRIST + 0.9, 0.5, plate_edge(pos))
        lip = np.clip((e - 0.82) / 0.12, 0, 1)
        groove = mech_bake.line(e - 0.7, 0.03)
        th, rr = np.arctan2(pos[:, 2], pos[:, 1]), np.hypot(pos[:, 1], pos[:, 2])
        screw = np.zeros(k, bool)
        for x0, x1, thc, h0, h1, _ in PLATES:
            for v in (-0.55, 0.55):
                da = ((th - (thc + v * h0) + math.pi) % (2 * math.pi) - math.pi) * rr
                screw |= np.hypot(pos[:, 0] - (x0 + 0.13 * (x1 - x0)), da) < 0.11
    if cls == "Jensen":
        # Glossy black shells, gold seams at their rims; a faint hex in the plates; gold joints; a gold line along the
        # housing.
        base = {"core": 26.0, "plate": 20.0, "housing": 16.0, "hand": 22.0, "finger": 24.0, "hinge": 22.0}[region]
        carbon = mech_bake.triplanar(mats["carbon"], pos, nn, 10).mean(-1) / 128.0
        col = np.array([[1.0, 0.98, 0.96]]) * (base * (0.85 + 0.25 * carbon))[:, None]
        if region == "plate" and not rim:
            h = mech_bake.hex_edge(pos[:, 0], np.arctan2(pos[:, 2], pos[:, 1]) * 1.8, 0.7)
            col = col * (1 + 0.6 * mech_bake.line(h, 0.05))[:, None]
            g = np.clip(groove + lip, 0, 1)
            col = col * (1 - g)[:, None] + GOLD[None] * g[:, None]
        if rim or region == "hinge":
            col = GOLD[None] * (0.55 + 0.25 * carbon)[:, None]
        if region == "housing":
            g = mech_bake.line(pos[:, 1], 0.06)
            col = col * (1 - g)[:, None] + GOLD[None] * g[:, None]
        return mech_bake.lit(col, nn, ao, gloss=95, power=48)
    # The Mech: the nanosuit's matte black hex (the muscle, the hand, the fingers), worn gunmetal armour (plates, the
    # housing, the joints' collars), a blue light along the housing.
    if region in ("core", "hand", "finger"):
        h = mech_bake.hex_edge(pos[:, 0], np.arctan2(pos[:, 2], pos[:, 1]) * 1.8 if region == "core" else pos[:, 1], 0.55)
        col = np.array([[0.9, 0.96, 1.06]]) * 40.0 * (1 - 0.55 * mech_bake.line(h, 0.05))[:, None]
        col = worn(col, pos, nn, mats, 0.5)
    else:
        g = mech_bake.triplanar(mats["gunmetal"], pos, nn, 28).mean(-1) / 128.0
        col = np.array([[0.86, 0.95, 1.1]]) * (62.0 * (0.8 + 0.3 * g))[:, None]
        if region == "plate" and not rim:
            col = col * (1 + 0.5 * lip)[:, None] * (1 - 0.5 * groove)[:, None]
            col = np.where(screw[:, None], col * 1.55, col)
        if region == "hinge":
            ribs = mech_bake.line(np.mod(np.arctan2(pos[:, 2], pos[:, 1]) * 3.0, 1.0) - 0.5, 0.15)
            col = col * 1.25 * (1 - 0.3 * ribs)[:, None]
        if region == "housing":
            g = mech_bake.line(np.abs(pos[:, 1]) - 0.42, 0.05) * (pos[:, 0] > 6.0)
            col = col * (1 - g)[:, None] + mech_bake.LIGHT[None] * g[:, None]
        col = worn(col, pos, nn, mats)
    if rim:
        col = col * (0.5 + 0.5 * np.clip(edge / 0.035, 0, 1))[:, None]
    return mech_bake.lit(col, nn, ao, gloss=70, power=24)


def bake(p, cls, sheet, out_png, A=1024, S=512):
    """One skin: every face's cell painted from its 3D surface (paint), occlusion from the model."""
    from PIL import Image
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel", "carbon")}
    mats["grunge"] = np.asarray(Image.open(os.path.join(mech_bake.MATS, "grunge.png")).convert("RGB"), float) / 255.0
    tris = []
    for pts, _ in p.faces:
        tris.append([pts[0], pts[1], pts[2]])
        if len(pts) == 4:
            tris.append([pts[0], pts[2], pts[3]])
    occ = np.array(tris)
    img, mask = np.zeros((A, A, 3)), np.zeros((A, A), bool)
    k = A / 256.0
    for (pts, region), (u0, v0, u1, v1), sh in zip(p.faces, p.cells, p.sheets):
        if sh != sheet:
            continue
        P = np.array(pts)
        n = unit(np.cross(P[1] - P[0], P[-1] - P[0]))
        ao = mech_bake.vertex_ao(P, np.repeat(n[None], len(P), 0), occ, rays=24, reach=2.5)
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
        w, h = face_size(P)
        col = paint(cls, region, pos.reshape(-1, 3), n, a3.reshape(-1), edge_of(sx, ty, w, h).reshape(-1), mats)
        col = col.reshape(pos.shape)
        ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
        img[ys[ok], xs[ok]] = col[ok]
        mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").resize((S, S), Image.LANCZOS)
    im.save(out_png)
    return im


def made():
    p = build()
    layout(p)
    p.finalize()
    return p


def write_obj(p, path, mtl, texs, V=None):
    V = p.verts if V is None else V
    sheets = [s for (pts, _), s in zip(p.faces, p.sheets) for _ in range(len(pts) - 2)]
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % tuple(v))
        for t in p.tris:
            for uv in t[3:]:
                f.write("vt %.5f %.5f\n" % (uv[0] / 256.0, 1 - uv[1] / 256.0))
        for s in range(len(texs)):
            f.write("usemtl arm%d\n" % s)
            for k, t in enumerate(p.tris):
                if sheets[k] == s:
                    f.write("f %d/%d %d/%d %d/%d\n" % (t[0] + 1, 3 * k + 1, t[1] + 1, 3 * k + 2, t[2] + 1, 3 * k + 3))
    open(mtl, "w").write("".join("newmtl arm%d\nKd 1 1 1\nmap_Kd %s\n\n" % (s, t) for s, t in enumerate(texs)))


def main():
    if sys.argv[1] == "preview":
        cls = sys.argv[2] if len(sys.argv) > 2 else "Jensen"
        out = os.path.abspath(sys.argv[3] if len(sys.argv) > 3 else os.path.join("build", "mech", "arms"))
        os.makedirs(out, exist_ok=True)
        p = made()
        texs = []
        for s in (0, 1):
            name = "%sArm%d.png" % (cls, s + 1)
            bake(p, cls, s, os.path.join(out, name))
            texs.append(name)
        obj = os.path.join(out, cls + "_arm.obj")
        write_obj(p, obj, os.path.join(out, cls + "_arm.mtl"), texs)
        print("%s arm: %d faces, %d tris" % (cls, len(p.faces), len(p.tris)))
        blender = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "tools", "blender-4.2.23-windows-x64", "blender.exe")
        subprocess.run([blender, "-b", "--factory-startup", "--python", os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender_arm.py"),
                        "--", os.path.join(out, cls + "_sheet.png"), obj], check=True, stdout=subprocess.DEVNULL)
        print("sheet", os.path.join(out, cls + "_sheet.png"))


if __name__ == "__main__":
    main()
