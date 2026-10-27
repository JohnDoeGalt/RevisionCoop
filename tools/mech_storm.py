"""The Mech's arm gun (its Arm Cannon), the user's design (2026-10-26): a Metal Storm gun that rides behind
the right shoulder blade; drawn, it slides down the back of the arm on a rail under the forearm, then spins
forward about a pivot at the wrist like a cowboy spinning his gun (muzzle down, forward, then up and over)
and locks on top of the hand. Its magazine is a brick on its back: to reload, the left hand pulls the brick
off and sets a new one on.

Our own design, built from boxes and prisms at the Mech's own scale (a game unit is about 2 cm). The gun: a
slender dark slate barrel block, longer than it is wide (about 5 cm square, 16 cm long), out of the top of
the wrist and over the back of the hand; five bores as a die shows (NINE: 3 x 3), the brass nose of each
bore's next round showing, yellow and black chevrons at the muzzle, a hazard mark, a blue light; the olive
brick behind it with a handle and a blue round counter; a yoke from the barrel block down to the wrist's
pin, and the pin's trunnions. (The Mech's arms in its view are the body's own: mech_parts.arm_mesh.) Three
512 skins, painted from the 3D surface.

Frame: x forward along the forearm (the elbow at 0, the wrist at WRIST), y to its left, z up; the forearm's
axis is the x axis. Game units, as on the body's forearm (14.25 long, about 3.2 thick). Built and painted
deployed; every other pose is a rigid move of groups from there.

  python -I tools/mech_storm.py preview [outdir] [9]     (default build/mech/storm: skins, OBJs, a sheet via
                                                        Blender; 9: nine barrels, into outdir/nine)
"""
import math, os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_bake
from mech_parts import Part, face_size, shelf_pack

WRIST = 13.8                                   # the forearm's armour ends here (the body's forearm: 14.25)
PIVOT = (14.1, 0.0)                            # (x, z) the gun spins about (a lateral pin through the wrist)
CASS = dict(x0=12.6, x1=20.6, h=1.3, c=0.22, z=4.0)  # the barrel block (deployed): slender, square in section
BRICK = dict(x0=8.8, x1=12.6, y=1.5, z0=2.7, z1=5.3)   # the magazine on the barrel block's back
RIM, RECESS = 0.22, 0.25                       # the muzzle's rim; how far the bore plate is set in
GRID, BORE = 3, 0.22                           # the bore plate's 3 x 3 cells; a bore's radius (about 9 mm across)
NINE = tuple((i, j) for i in range(3) for j in range(3))   # the bored cells: nine, or
FIVE = ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2))            # five, as a die shows five (the user's latest)
DICE = FIVE
BORE_DEPTH, NOSE = 1.0, 0.4                    # a bore's depth; a round's nose
GRAB = np.array([10.7, 0.4, 7.9])              # the left fist's centre, on the brick's handle
SHARED = ("bore", "cap", "nose")               # regions sharing one texture cell each
SHEET = {"casing": 0, "chevron": 0, "brick": 1}   # three skins (else 2): byte UVs, so each skin's
                                                 # 256 steps go further
FIRST = ("gun", "brick", "mount")              # what the Mech sees (StormView; its arms: StormArm)
THIRD = ("gun", "brick", "mount")              # on the body's own forearm while held (BarrettCannon)
BACK = ("gun", "brick")                        # behind the shoulder blade otherwise


def oriented(sec):
    """A 2D polygon counter-clockwise."""
    a = sum(p[0] * q[1] - q[0] * p[1] for p, q in zip(sec, sec[1:] + sec[:1]))
    return sec if a > 0 else sec[::-1]


AXES = {"x": (np.array([0, 1, 0.]), np.array([0, 0, 1.]), np.array([1, 0, 0.])),
        "y": (np.array([0, 0, 1.]), np.array([1, 0, 0.]), np.array([0, 1, 0.])),
        "z": (np.array([1, 0, 0.]), np.array([0, 1, 0.]), np.array([0, 0, 1.]))}


def prism(p, sec, a0, a1, axis, side, caps=(None, None), inward=False):
    """sec (2D, convex, in the plane of axis's e1, e2) from a0 to a1 along axis: sides, then caps (a0, a1)."""
    e1, e2, ax = AXES[axis]
    sec = oriented([tuple(s) for s in sec])
    P = lambda a, s: a * ax + s[0] * e1 + s[1] * e2
    n = len(sec)
    for k in range(n):
        s, t = sec[k], sec[(k + 1) % n]
        if inward:
            p.add_quad(P(a0, s), P(a1, s), P(a1, t), P(a0, t), side)
        else:
            p.add_quad(P(a0, t), P(a1, t), P(a1, s), P(a0, s), side)
    if caps[1]:
        for k in range(1, n - 1):
            p.add_tri(P(a1, sec[0]), P(a1, sec[k]), P(a1, sec[k + 1]), caps[1])
    if caps[0]:
        for k in range(1, n - 1):
            p.add_tri(P(a0, sec[0]), P(a0, sec[k + 1]), P(a0, sec[k]), caps[0])


def block(p, lo, hi, region, ends=None):
    """An axis-aligned box from lo to hi (x is its length: ends are the +-x faces)."""
    sec = [(lo[1], lo[2]), (hi[1], lo[2]), (hi[1], hi[2]), (lo[1], hi[2])]
    prism(p, sec, lo[0], hi[0], "x", region, (ends or region, ends or region))


def chamfered(y, z0, z1, c):
    return [(y - c, z0), (y, z0 + c), (y, z1 - c), (y - c, z1), (-y + c, z1), (-y, z1 - c), (-y, z0 + c), (-y + c, z0)]


def tag(p, group):
    """The faces added since the last tag belong to group (gun, brick, mount)."""
    p.groups += [group] * (len(p.faces) - len(p.groups))


def bores():
    """The bores' centres (y, z) on the muzzle, and the cell size."""
    r = CASS["h"] - RIM
    cell = 2 * r / GRID
    return [(-r + cell * (i + 0.5), CASS["z"] - r + cell * (j + 0.5)) for i, j in DICE], cell


# ---- the poses, from the deployed pose (what is built, painted and finalized).

def spin(P, deg):
    """Points of the gun turned by deg about the wrist's pin, the cowboy's way round: 180 takes it from on
    top of the hand, muzzle forward, to under the forearm, muzzle back; on the way back its muzzle swings
    down, forward and up over the hand."""
    a = math.radians(deg)
    x, z = P[:, 0] - PIVOT[0], P[:, 2] - PIVOT[1]
    Q = P.copy()
    Q[:, 0] = PIVOT[0] + x * math.cos(a) + z * math.sin(a)
    Q[:, 2] = PIVOT[1] - x * math.sin(a) + z * math.cos(a)
    return Q


OFF = np.array([-12.0, 20.0, -28.0])           # the left hand (and a thrown brick) out of sight


def pose(P, groups, turn=0.0, slide=0.0, brick=(0, 0, 0), lhand=None, kick=0.0):
    """Points P (n, 3) with their groups, from the deployed pose: the gun turned by turn degrees (spin) and
    slid slide units along the forearm, kick units of recoil; the brick moved by brick on top of that; the
    left hand moved by lhand from the brick's handle (default: out of sight)."""
    Q = P.copy()
    g = np.asarray(groups)
    for name in ("gun", "brick"):
        m = g == name
        Q[m] = spin(P[m], turn)
        Q[m, 0] += slide - kick
    Q[g == "brick"] += np.asarray(brick, float)
    Q[g == "lhand"] += OFF if lhand is None else np.asarray(lhand, float)
    return Q


def build():
    """The gun on top of the hand and the wrist's trunnions; the faces' groups in p.groups. (The Mech's
    arms in its view are the body's own: mech_parts.arm_mesh, StormArm.)"""
    p = Part("storm", mesh="StormGun")
    p.groups = []
    X = lambda x, yz: np.array([x, yz[0], yz[1]])
    h, c, x0, x1, zc = CASS["h"], CASS["c"], CASS["x0"], CASS["x1"], CASS["z"]
    # The barrel block: a chamfered square box, the chevron band round its muzzle end.
    prism(p, chamfered(h, zc - h, zc + h, c), x0, x1, "x", "casing", ("casing", None))
    prism(p, chamfered(h + 0.06, zc - h - 0.06, zc + h + 0.06, c), x1 - 1.6, x1 - 0.9, "x", "chevron")
    # The muzzle: a rim in to the recess, its walls, the bore plate (a 3 x 3 grid, DICE's cells bored).
    r = h - RIM
    O = oriented(chamfered(h, zc - h, zc + h, c))
    I = [(r, zc - r), (r, zc + r), (-r, zc + r), (-r, zc - r)]
    def corner(o):
        return min(range(4), key=lambda k: (o[0] - I[k][0]) ** 2 + (o[1] - I[k][1]) ** 2)
    for k in range(len(O)):
        o0, o1 = O[k], O[(k + 1) % len(O)]
        i0, i1 = corner(o0), corner(o1)
        if i0 == i1:
            p.add_tri(X(x1, I[i0]), X(x1, o0), X(x1, o1), "frame")
        else:
            p.add_quad(X(x1, I[i0]), X(x1, o0), X(x1, o1), X(x1, I[i1]), "frame")
    face_x = x1 - RECESS
    prism(p, I, face_x, x1, "x", "recess", inward=True)
    cell = 2 * r / GRID
    ang = [k * math.pi / 4 for k in range(8)]
    for i in range(GRID):
        for j in range(GRID):
            cy, cz = -r + cell * (i + 0.5), zc - r + cell * (j + 0.5)
            hc = cell / 2
            if (i, j) not in DICE:
                p.add_quad(X(face_x, (cy - hc, cz - hc)), X(face_x, (cy + hc, cz - hc)),
                           X(face_x, (cy + hc, cz + hc)), X(face_x, (cy - hc, cz + hc)), "face")
                continue
            oct_ = [(cy + BORE * math.cos(a), cz + BORE * math.sin(a)) for a in ang]
            sq = [(cy + hc * np.sign(round(math.cos(a), 6)), cz + hc * np.sign(round(math.sin(a), 6))) for a in ang]
            for k in range(8):
                q = (k + 1) % 8
                p.add_quad(X(face_x, oct_[k]), X(face_x, sq[k]), X(face_x, sq[q]), X(face_x, oct_[q]), "face")
            back = face_x - BORE_DEPTH
            prism(p, oct_, back, face_x, "x", "bore", ("cap", None), inward=True)
            tip = np.array([back + 0.1 + NOSE, cy, cz])
            base = [X(back + 0.1, (cy + 0.88 * BORE * math.cos(a), cz + 0.88 * BORE * math.sin(a))) for a in ang]
            for k in range(8):
                p.add_tri(base[k], base[(k + 1) % 8], tip, "nose")
    # The muzzle as one flat face, the bores painted on (the far-off copies, THIRD and BACK).
    p.add_quad(X(face_x, (-r, zc - r)), X(face_x, (r, zc - r)), X(face_x, (r, zc + r)), X(face_x, (-r, zc + r)), "muzzle")
    # Under it: a spine, and the yoke down to the wrist's pin (outside the trunnions).
    block(p, (12.2, -1.1, 2.3), (14.8, 1.1, zc - h), "frame")
    block(p, (13.4, -3.0, 2.3), (14.8, 3.0, 2.7), "frame")
    for s in (1, -1):
        lo, hi = sorted((s * 2.6, s * 3.0))
        block(p, (13.4, lo, -0.8), (14.8, hi, 2.3), "frame")
    tag(p, "gun")
    # The brick: a big box on the barrel block's back, a handle on top.
    b = BRICK
    prism(p, chamfered(b["y"], b["z0"], b["z1"], 0.35), b["x0"], b["x1"], "x", "brick", ("brick", "brick"))
    for x in (b["x0"] + 0.8, b["x1"] - 1.2):
        block(p, (x, -0.4, b["z1"]), (x + 0.4, 0.4, b["z1"] + 0.7), "frame")
    block(p, (b["x0"] + 0.8, -0.4, b["z1"] + 0.7), (b["x1"] - 0.8, 0.4, b["z1"] + 1.05), "frame")
    tag(p, "brick")
    # The wrist's trunnions (the pin's bearings): on the body's own arm too.
    for s in (1, -1):
        lo, hi = sorted((s * 2.0, s * 2.6))
        block(p, (PIVOT[0] - 0.7, lo, PIVOT[1] - 0.7), (PIVOT[0] + 0.7, hi, PIVOT[1] + 0.7), "frame")
    tag(p, "mount")
    return p


def layout(p):
    """Each face its cell in its skin's 256-unit UV square; the SHARED regions one small cell each."""
    p.cells = [None] * len(p.faces)
    p.sheets = [SHEET.get(r, 2) for _, r in p.faces]
    return [layout_sheet(p, s) for s in range(3)]


def layout_sheet(p, sheet, density=40.0):
    shared = {r: None for r in SHARED} if sheet == 2 else {}
    own = [k for k, (_, r) in enumerate(p.faces) if p.sheets[k] == sheet and r not in SHARED]
    while True:
        rects = [(max(2, int(round(face_size(p.faces[k][0])[0] * density))),
                  max(2, int(round(face_size(p.faces[k][0])[1] * density)))) for k in own]
        placed = shelf_pack(rects + [(8, 8)] * len(shared), 255)
        if placed:
            break
        density *= 0.96
    for k, (x, y, w, h) in zip(own, placed):
        p.cells[k] = (x, y, x + w, y + h)
    for r, (x, y, w, h) in zip(list(shared), placed[len(own):]):
        shared[r] = (x, y, x + w, y + h)
    for k, (_, r) in enumerate(p.faces):
        if r in shared:
            p.cells[k] = shared[r]
    return density


def per_tri(p, values):
    """A per-face list as per triangle (Part.finalize makes two of a quad, one of a triangle)."""
    return [v for (pts, _), v in zip(p.faces, values) for _ in range(len(pts) - 2)]


def per_vert(p, values):
    """A per-face list as per vertex (Part.finalize gives each face its own vertices, in order)."""
    return [v for (pts, _), v in zip(p.faces, values) for _ in pts]


def hazard_mask(r, u):
    """A warning triangle with a lightning bolt, centred on (0, 0), 2 across: 0 none, 1 yellow, 2 ink."""
    inside = (u > -0.8) & (u < 0.9 - 1.7 * np.abs(r)) & (np.abs(r) < 1.0)
    rim = inside & ~((u > -0.62) & (u < 0.62 - np.abs(r) * 1.7) & (np.abs(r) < 0.8))
    bolt = ((np.abs(r - 0.25 * u + 0.05) < 0.07) & (u > 0.0) & (u < 0.45)) \
        | ((np.abs(u) < 0.06) & (r > -0.1) & (r < 0.18)) \
        | ((np.abs(r - 0.25 * u - 0.1) < 0.07) & (u < 0.0) & (u > -0.45))
    return np.where(rim | (inside & bolt), 2, np.where(inside, 1, 0))




def hashn(pos, s, seed):
    """Value noise in [0, 1] at scale s."""
    q = pos * s
    i = np.floor(q)
    f = q - i
    f = f * f * (3 - 2 * f)
    def hh(o):
        v = (i + o) @ np.array([127.1, 311.7, 74.7]) + seed * 17.3
        return np.mod(np.sin(v) * 43758.5453, 1.0)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (f[..., 0] if dx else 1 - f[..., 0]) * (f[..., 1] if dy else 1 - f[..., 1]) * (f[..., 2] if dz else 1 - f[..., 2])
                out = out + w * hh(np.array([dx, dy, dz], float))
    return out


# ---- paint. Colours 0-255: the Mech's palette. Sizes in game units.
CASING = np.array([64.0, 69.0, 76.0])           # dark slate gunmetal
OLIVE = np.array([76.0, 80.0, 56.0])            # the brick
FACEPLATE = np.array([36.0, 38.0, 42.0])
BRASS = np.array([182.0, 140.0, 72.0])
STEEL = np.array([150.0, 156.0, 162.0])
HAZARD = np.array([226.0, 176.0, 38.0])
INK = np.array([22.0, 22.0, 24.0])


def decals(pos, n, col):
    """The barrel block's markings, placed in 3D (right: the viewer's right, so never mirrored)."""
    up = np.array([0.0, 0.0, 1.0])
    h, zc, xm = CASS["h"], CASS["z"], 16.6
    for side in (1, -1):
        if float(n[1]) * side < 0.9:
            continue
        right = np.cross(-np.array([0.0, side, 0.0]), up)
        d = pos - np.array([xm, side * h, zc + 0.5])
        m = hazard_mask(d @ right / 0.45, d @ up / 0.45)
        col = np.where((m == 1)[..., None], HAZARD, np.where((m == 2)[..., None], INK, col))
        d = pos - np.array([xm, side * h, zc - 0.5])
        r, u = d @ right, d @ up
        plate = (np.abs(r) < 0.6) & (np.abs(u) < 0.22)
        col = np.where(plate[..., None], np.array([54.0, 56, 60]), col)
        txt = plate & (np.abs(u) < 0.15) & (np.mod(r * 6.0, 1) < 0.62) & (np.abs(r) < 0.58) & (np.abs(u - 0.05) > 0.03)
        col = np.where(txt[..., None], np.array([160.0, 162, 166]), col)
        strip = (pos[..., 0] > 13.6) & (pos[..., 0] < 18.6) & (np.abs(pos[..., 2] - (zc - h + 0.32)) < 0.07)
        col = np.where(strip[..., None], mech_bake.LIGHT, col)
    return col


def paint(region, pos, n, a3, sx, ty, w, h, mats):
    """A face's colour at its texels, before the edge line, light and occlusion."""
    flat = np.ones(pos.shape[:-1] + (1,))
    nb = np.broadcast_to(n, pos.shape)
    if region == "casing":
        grain = mech_bake.triplanar(mats["steel"], pos, nb, 24).mean(-1, keepdims=True) / 128.0
        col = CASING * (0.9 + 0.1 * grain)
        col = col * (1 - 0.1 * hashn(pos, 0.8, 1)[..., None])
        edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
        chip = (hashn(pos, 5.0, 2)[..., None] > 0.8) & (edge < 0.07)                      # a little worn bright
        col = np.where(chip, np.array([150.0, 154, 158]), col)
        return decals(pos, n, col)
    if region == "brick":                       # olive, ribbed sides, a yellow band, the round counter
        grain = mech_bake.triplanar(mats["steel"], pos, nb, 24).mean(-1, keepdims=True) / 128.0
        col = OLIVE * (0.9 + 0.1 * grain) * (1 - 0.08 * hashn(pos, 0.8, 5)[..., None])
        if abs(float(n[1])) > 0.9:
            rib = mech_bake.line(np.mod(pos[..., 2] - BRICK["z0"], 0.55) - 0.275, 0.04)
            col = col * (1 - 0.45 * rib * (pos[..., 2] < BRICK["z1"] - 1.0))[..., None]
            band = np.abs(pos[..., 2] - (BRICK["z1"] - 0.6)) < 0.18
            col = np.where(band[..., None], HAZARD * 0.92, col)
            if n[1] > 0.9:                      # the left side: nine blue cells, a round counter
                d = pos - np.array([10.7, BRICK["y"], BRICK["z0"] + 1.0])
                box = (np.abs(d[..., 0]) < 1.5) & (np.abs(d[..., 2]) < 0.3)
                col = np.where(box[..., None], np.array([18.0, 20, 24]), col)
                cell = box & (np.abs(d[..., 2]) < 0.22) & (np.mod((d[..., 0] + 1.5) * 3.0, 1) < 0.7) & (np.abs(d[..., 0]) < 1.42)
                col = np.where(cell[..., None], mech_bake.LIGHT, col)
        edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
        chip = (hashn(pos, 5.0, 6)[..., None] > 0.8) & (edge < 0.07)
        return np.where(chip, np.array([140.0, 140, 120]), col)
    if region == "chevron":
        stripe = np.mod(pos[..., 0] + pos[..., 1] + pos[..., 2], 0.6) < 0.3
        return np.where(stripe[..., None], HAZARD, INK)
    if region in ("frame", "recess"):
        g = mech_bake.triplanar(mats["gunmetal"], pos, nb, 32).mean(-1, keepdims=True)
        return g * (0.5 if region == "frame" else 0.3) * np.array([0.95, 0.98, 1.02])
    if region in ("face", "muzzle"):
        col = FACEPLATE * flat
        centres, _ = bores()
        best = np.full(pos.shape[:-1], 99.0)
        for cy, cz in centres:
            best = np.minimum(best, np.hypot(pos[..., 1] - cy, pos[..., 2] - cz))
        if region == "muzzle":                 # the bores painted: dark, a round's brass nose in each
            col = np.where((best < BORE)[..., None], np.array([16.0, 16, 18]), col)
            col = np.where((best < 0.11)[..., None], BRASS * (1.1 - 0.5 * best / 0.11)[..., None], col)
        ring = (best > BORE) & (best < BORE + 0.08)
        col = np.where(ring[..., None], STEEL * (0.8 + 0.2 * np.clip((best - BORE) / 0.08, 0, 1))[..., None], col)
        return np.where(((best >= BORE + 0.08) & (best < BORE + 0.11))[..., None], col * 0.5, col)
    if region == "bore":
        return np.array([30.0, 30, 33]) * (0.35 + 0.65 * sx)[..., None]       # darker towards the back
    if region == "cap":
        return np.array([10.0, 10, 11]) * flat
    if region == "nose":
        return BRASS * (0.7 + 0.3 * ty)[..., None]
    raise ValueError(region)


def bake(p, sheet, out_png, A=1024, S=512):
    """One of the gun's skins: every face's cell painted from its 3D surface, a soft key light, occlusion."""
    from PIL import Image
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel")}
    tris = []
    for pts, _ in p.faces:
        tris.append([pts[0], pts[1], pts[2]])
        if len(pts) == 4:
            tris.append([pts[0], pts[2], pts[3]])
    occ = np.array(tris)
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
    done = set()
    for (pts, region), (u0, v0, u1, v1), sh in zip(p.faces, p.cells, p.sheets):
        if sh != sheet:
            continue
        if region in SHARED:
            if region in done:
                continue
            done.add(region)
        P = np.array(pts)
        n = np.cross(P[1] - P[0], P[-1] - P[0])
        n /= np.linalg.norm(n) + 1e-9
        ao = np.ones(len(P)) if region in SHARED else mech_bake.vertex_ao(P, np.repeat(n[None], len(P), 0), occ, rays=32, reach=3.0)
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
        col = paint(region, pos, n, a3, sx, ty, w, h, mats)
        if region not in SHARED:
            edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))
            col = col * (0.6 + 0.4 * np.clip(edge / 0.035, 0, 1))[..., None]         # a dark line at each edge
            light = 0.72 + 0.4 * (np.clip(float(n @ mech_bake.KEY), -1, 1) * 0.5 + 0.5) ** 2
            col = col * (light * (0.55 + 0.45 * np.clip(a3, 0, 1) ** 1.2))[..., None]
        ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
        img[ys[ok], xs[ok]] = col[ok]
        mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").resize((S, S), Image.LANCZOS)
    im.save(out_png)
    return im


def made():
    """The gun built deployed, laid out and finalized: (part, UV densities)."""
    p = build()
    d = layout(p)
    p.finalize()
    return p, d


def mesh_of(p, groups, drop):
    """The finalized gun's triangles in groups (but not those of the regions in drop) as one mesh:
    (vertices in the deployed pose, their groups, triangles (a, b, c, uv_a, uv_b, uv_c), skins). Vertices
    shared where position, face and group agree (UVs are per triangle corner in a game mesh)."""
    tg, ts = per_tri(p, p.groups), per_tri(p, p.sheets)
    treg = per_tri(p, [r for _, r in p.faces])
    vg = per_vert(p, p.groups)
    V, G, index, tris, skins = [], [], {}, [], []
    for t, g, s, r in zip(p.tris, tg, ts, treg):
        if g not in groups or r in drop:
            continue
        P = [np.asarray(p.verts[i]) for i in t[:3]]
        n = np.cross(P[1] - P[0], P[2] - P[0])
        n = tuple(np.round(n / (np.linalg.norm(n) + 1e-12), 2))
        ids = []
        for i in t[:3]:
            key = (tuple(np.round(p.verts[i], 4)), n, vg[i])
            if key not in index:
                index[key] = len(V)
                V.append(np.asarray(p.verts[i], float))
                G.append(vg[i])
            ids.append(index[key])
        tris.append((ids[0], ids[1], ids[2], t[3], t[4], t[5]))
        skins.append(s)
    return np.array(V), G, tris, skins


def mirrored(tris):
    """Triangles wound the other way: for vertices put through a mirror (the game's frame is left-handed:
    the gun's y, its left, becomes the game's -Y), so they still face out."""
    return [(a, c, b, ua, uc, ub) for a, b, c, ua, ub, uc in tris]


# ---- the Mech's own view (StormView): its vertices in the view's frame (the eye at the origin, X ahead,
# Y right, Z up; 256 raw units to one), every frame a pose of the gun and a move of the whole arm.
EYE, K = np.array([-1.0, 6.0, 5.5]), 2.0      # where the eye is, in the gun's frame (back, left and above it: its side and the arm show); the view's scale


def turned(P, about, pitch=0.0, yaw=0.0, roll=0.0):
    """Points turned about a point: pitch lifts +x towards +z, yaw turns +x towards +y (left), roll turns
    +z towards -y (degrees, in that order)."""
    Q = P - about
    a, b, c = (math.radians(v) for v in (pitch, yaw, roll))
    Q = np.stack([Q[:, 0] * math.cos(a) - Q[:, 2] * math.sin(a), Q[:, 1], Q[:, 0] * math.sin(a) + Q[:, 2] * math.cos(a)], 1)
    Q = np.stack([Q[:, 0] * math.cos(b) - Q[:, 1] * math.sin(b), Q[:, 0] * math.sin(b) + Q[:, 1] * math.cos(b), Q[:, 2]], 1)
    Q = np.stack([Q[:, 0], Q[:, 1] * math.cos(c) - Q[:, 2] * math.sin(c), Q[:, 1] * math.sin(c) + Q[:, 2] * math.cos(c)], 1)
    return Q + about


def in_view(V, G, arm=(0, 0, 0, 0, 0, 0), **kw):
    """One frame of the view: the gun posed (pose's keywords), the whole arm moved by arm (dx, dy, dz in
    the gun's frame, then pitch, yaw, roll about the elbow), into the view's frame."""
    P = pose(V, G, **kw)
    P = turned(P, np.zeros(3), *arm[3:]) + np.asarray(arm[:3], float)
    D = (P - EYE) * K
    D[:, 1] = -D[:, 1]
    return D


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def span(t, a, b):
    """Where t is between a and b, eased (0 before a, 1 after b)."""
    return ease((t - a) / (b - a))


PULLED = np.array([-2.5, 2.0, 2.6])            # the brick lifted off its seat in the left hand


def draw(t):
    """Select: the arm comes up; the gun slides in under the forearm, then spins over the hand; settles."""
    up = span(t, 0.0, 0.3)
    return dict(arm=(0, 0, -14 * (1 - up), -25 * (1 - up), 0, 0), slide=-22 * (1 - span(t, 0.1, 0.5)),
                turn=180 * (1 - span(t, 0.5, 0.85)), kick=0.4 * math.sin(math.pi * span(t, 0.85, 1.0)))


def reload_begin(t):
    """The arm tilts the brick to the left hand, which comes in, pulls the brick off and takes it away."""
    hand = OFF * (1 - span(t, 0.0, 0.35)) + PULLED * span(t, 0.35, 0.6) + OFF * span(t, 0.6, 1.0)
    brick = PULLED * span(t, 0.35, 0.6) + OFF * span(t, 0.6, 1.0)
    return dict(arm=(0, 0, 0, -4 * span(t, 0, 0.3), 0, -12 * span(t, 0, 0.3)), brick=brick, lhand=hand)


def reload_end(t):
    """The left hand brings a new brick, sets it on its seat (a jolt), and goes; the arm comes back."""
    held = OFF * (1 - span(t, 0.0, 0.55)) + PULLED * (span(t, 0.0, 0.55) - span(t, 0.55, 0.75))
    hand = held + OFF * span(t, 0.8, 1.0)
    back = span(t, 0.6, 1.0)
    return dict(arm=(0, 0, 0, -4 * (1 - back), 0, -12 * (1 - back)), brick=held, lhand=hand,
                kick=0.35 * math.sin(math.pi * span(t, 0.55, 0.8)))


# The sequences DeusExWeapon plays: (name, frames, rate, pose of t in 0-1).
SEQS = [("Still", 1, 1, lambda t: {}),
        ("Select", 14, 20, draw),
        ("Down", 10, 20, lambda t: draw(1 - t) if t < 1 else draw(0.0)),
        ("Idle1", 12, 6, lambda t: dict(arm=(0, 0, 0.15 * math.sin(2 * math.pi * t), 0.3 * math.sin(2 * math.pi * t), 0, 0))),
        ("Shoot", 4, 40, lambda t: dict(kick=0.5 * (1 - t), arm=(-0.6 * (1 - t), 0, 0, 1.5 * (1 - t), 0, 0))),
        ("ReloadBegin", 10, 16, reload_begin),
        ("Reload", 6, 8, lambda t: dict(arm=(0, 0, 0.1 * math.sin(2 * math.pi * t), -4, 0, -12), brick=OFF, lhand=OFF)),
        ("ReloadEnd", 10, 16, reload_end)]


def frames_of(P, group):
    """Points of one group (in the gun's frame, as deployed: "arm" moves with the arm, "lhand" as the left
    hand) in the view, frame by frame (SEQS): mech_parts.arm_mesh carries the body's own arms so."""
    G = [group] * len(P)
    return [in_view(P, G, **f(k / max(1, n - 1))) for _, n, _, f in SEQS for k in range(n)]


def view_mesh(p):
    """StormView: (frames (n, verts, 3) in the view's frame, triangles, skins, sequences (name, start, count, rate))."""
    V, G, tris, skins = mesh_of(p, FIRST, ("muzzle",))
    frames, seqs = [], []
    for name, n, rate, f in SEQS:
        seqs.append((name, len(frames), n, rate))
        for k in range(n):
            frames.append(in_view(V, G, **f(k / max(1, n - 1))))
    return np.array(frames), mirrored(tris), skins, seqs


def write_obj(p, path, mtl, texs, V=None, groups=FIRST):
    """The gun (vertices V, default as built) as an OBJ with its UVs and a material per skin, for previews."""
    V = p.verts if V is None else V
    sheets, tg = per_tri(p, p.sheets), per_tri(p, p.groups)
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % tuple(v))
        for t in p.tris:
            for uv in t[3:]:
                f.write("vt %.5f %.5f\n" % (uv[0] / 256.0, 1 - uv[1] / 256.0))
        for s in range(len(texs)):
            f.write("usemtl storm%d\n" % s)
            for k, t in enumerate(p.tris):
                if sheets[k] == s and tg[k] in groups:
                    f.write("f %d/%d %d/%d %d/%d\n" % (t[0] + 1, 3 * k + 1, t[1] + 1, 3 * k + 2, t[2] + 1, 3 * k + 3))
    open(mtl, "w").write("".join("newmtl storm%d\nKd 1 1 1\nmap_Kd %s\n\n" % (s, t) for s, t in enumerate(texs)))


# The preview's poses: on the hand; mid-spin; under the forearm, sliding in; the reload (brick off).
POSES = {"on": dict(), "spin": dict(turn=95.0), "under": dict(turn=180.0, slide=-5.0),
         "reload": dict(brick=(-2.5, 2.0, 2.6), lhand=(-2.5, 2.0, 2.6))}


def main():
    global DICE
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "storm")
    if len(sys.argv) > 3 and sys.argv[3] == "9":       # nine barrels (the user's other idea)
        DICE = NINE
        out = os.path.join(out, "nine")
    os.makedirs(out, exist_ok=True)
    p, d = made()
    print("arm gun: %d faces, %d verts, %d tris; UV units per game unit by skin: %s"
          % (len(p.faces), len(p.verts), len(p.tris), " ".join("%.2f" % x for x in d)))
    texs = ["StormGun%d.png" % (s + 1) for s in range(3)]
    for s, t in enumerate(texs):
        bake(p, s, os.path.join(out, t))
    vg = per_vert(p, p.groups)
    P = np.array(p.verts)
    for name, kw in POSES.items():
        write_obj(p, os.path.join(out, "storm_%s.obj" % name), os.path.join(out, "storm.mtl"), texs, pose(P, vg, **kw))
    if sys.argv[1] == "preview":
        here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        blender = os.environ.get("BLENDER", os.path.join(here, "build", "tools", "blender-4.2.23-windows-x64", "blender.exe"))
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender_storm.py")
        subprocess.run([blender, "-b", "--factory-startup", "--python", script, "--",
                        os.path.abspath(os.path.join(out, "storm_sheet.png"))]
                       + [os.path.abspath(os.path.join(out, "storm_%s.obj" % s)) for s in POSES],
                       check=True, stdout=subprocess.DEVNULL)
        print("sheet:", os.path.join(out, "storm_sheet.png"))


if __name__ == "__main__":
    main()
