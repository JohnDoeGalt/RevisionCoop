"""The Mech's arm gun (its Arm Cannon), the user's design (2026-10-26): a Metal Storm gun that rides behind
the right shoulder blade; drawn, it slides down the back of the arm on a rail under the forearm, then spins
forward about a pivot at the wrist like a cowboy spinning his gun (muzzle down, forward, then up and over)
and locks on top of the hand. Its magazine is a brick on its back: to reload, the left hand pulls the brick
off and sets a new one on.

Our own design, built from boxes and prisms at the Mech's own scale (a game unit is about 2 cm). The gun: a
slender dark slate barrel block, longer than it is wide (about 5 cm square, 16 cm long), out of the top of
the wrist and over the back of the hand; nine bores, 3 x 3 (FIVE: as a die shows), the brass nose of each
bore's next round showing, yellow and black chevrons at the muzzle, a hazard mark, a blue light; the olive
brick behind it with a handle and a blue round counter; under the block's back a low saddle shaped to the top of the
forearm and the wrist, the gun seated into the arm like a piece of its armour (the user, 2026-10-29: the yoke and
trunnions that held it, "the giant clamp thing just looks wrong... more sleek and low profile"); the pin it spins about
is inside the wrist, unseen. (In its view it rides the Mech's own gauntlet: view_mesh, tools/blade_arms.py.) Three
512 skins, painted from the 3D surface.

Frame: x forward along the forearm (the elbow at 0, the wrist at WRIST), y to its left, z up; the forearm's
axis is the x axis. Game units, as on the body's forearm (14.25 long, about 3.2 thick). Built and painted
deployed; every other pose is a rigid move of groups from there.

  python -I tools/mech_storm.py preview [outdir] [5]     (default build/mech/storm: skins, OBJs, a sheet via
                                                        Blender; 5: five barrels, into outdir/five)
"""
import math, os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_bake
from mech_parts import Part, face_size, shelf_pack

WRIST = 13.8                                   # the forearm's armour ends here (the body's forearm: 14.25)
PIVOT = (14.1, 0.0)                            # (x, z) the gun spins about (a lateral pin through the wrist)
# The barrel block (deployed): slender, square in section, its underside down on the back of the hand (the
# hand's top: 1.6), dipping into the wrist (2.7): low over its mount, for less leverage in the recoil (the
# user's ask, 2026-10-26: "practically attached to his forearm"; it may clip a little).
CASS = dict(x0=12.6, x1=20.6, h=1.3, c=0.22, z=3.0)
BRICK = dict(x0=8.8, x1=12.6, y=1.5, z0=1.7, z1=4.3)   # the magazine on the barrel block's back
RIM, RECESS = 0.22, 0.25                       # the muzzle's rim; how far the bore plate is set in
GRID, BORE = 3, 0.22                           # the bore plate's 3 x 3 cells; a bore's radius (about 9 mm across)
NINE = tuple((i, j) for i in range(3) for j in range(3))   # the bored cells: nine (the user's latest, 2026-10-29), or
FIVE = ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2))            # five, as a die shows five
DICE = NINE
BORE_DEPTH, NOSE = 1.0, 0.4                    # a bore's depth; a round's nose
BREECH, STUB = 0.45, 0.3                       # how far the barrels stand out of the block's back; their outer radius
SADDLE = dict(x0=12.4, x1=14.6, half=0.36, out=0.2)   # the saddle under the block's back: along the forearm, half its
                                                 # angle across the arm's top, how far out of the arm's surface (its plates)
MOUNT = (1.5, 0.26)     # where it is posed, the gun (its brick, its pin) moved back along the forearm and up: 3 cm
                        # back, off the wrist joint (the user, 2026-10-29: "not mounted over the arm joint"; the
                        # muzzle about over the knuckles), up as far as the brick then clears the plates (built and
                        # painted where it was: the numbers here and in the paint are as built)
GRAB = np.array([10.7, 0.4, BRICK["z1"] + 2.6])  # the left fist's centre, on the brick's handle
SHARED = ("bore", "cap", "nose", "grip")       # regions sharing one texture cell each
SMOOTH = ("grip",)                             # regions shaded round in the game (their faces share vertices)
SHEET = {"casing": 0, "chevron": 0, "brick": 1}   # three skins (else 2): byte UVs, so each skin's
                                                 # 256 steps go further
FIRST = ("gun", "brick", "mount")              # what the Mech sees (StormView, with its gauntlets: view_mesh)
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


def face(p, pts, out, region):
    """A face whose normal points along out (its corners reordered if not)."""
    P = [np.asarray(x, float) for x in pts]
    n = np.cross(P[1] - P[0], P[2] - P[0]) if len(P) == 3 else np.cross(P[2] - P[0], P[3] - P[1])
    if n @ np.asarray(out, float) < 0:
        P = P[::-1]
    (p.add_quad if len(P) == 4 else p.add_tri)(*P, region)


def handle(p):
    """The brick's carry handle (the user, 2026-10-29: "more smooth and less boxy, more ergonomically shaped"): an
    arch of oval section swept over the brick, flatter on top where the hand closes, its feet flaring into the brick
    and sunk a little into it, three shallow finger grooves under the grip. The grip's middle stays where the left
    fist takes it in the reload (HANDLE: x 10.7, its centreline z1 + 0.88). Its faces share their vertices in the
    game mesh (SMOOTH), so the game shades it round."""
    z1 = BRICK["z1"]
    cx, half, top = 10.7, 1.08, 0.88                 # the arch: middle, half span, its centreline's height
    ts = np.linspace(-np.pi / 2, np.pi / 2, 21)
    ring = 10
    def centre(t):
        return np.array([cx + half * np.sin(t), 0.0, z1 - 0.08 + (top + 0.08) * np.cos(t) ** 0.55])
    rings = []
    for t in ts:
        P = centre(t)
        T = mech_bake.unit(centre(min(t + 0.01, np.pi / 2)) - centre(max(t - 0.01, -np.pi / 2)))
        N = np.cross(T, np.array([0.0, 1.0, 0.0]))   # in the arch's plane, away from the brick
        if N[2] < 0 and abs(t) < 1.2:
            N = -N
        foot = np.clip((abs(t) - 1.05) / 0.52, 0, 1) ** 2
        wy, hn = 0.34 * (1 + 0.4 * foot), 0.17 * (1 + 0.6 * foot)
        u = (P[0] - cx) / 0.62                       # the grip's span: three grooves for the fingers, underneath
        groove = 0.035 * np.sin(1.5 * np.pi * (u + 1)) ** 2 if abs(u) <= 1 else 0.0
        pts = []
        for k in range(ring):
            f = 2 * np.pi * k / ring
            s = np.sin(f)
            off = (hn - groove) * s if s < 0 else hn * s
            pts.append(P + np.array([0.0, 1.0, 0.0]) * wy * np.cos(f) + N * off)
        rings.append((P, pts))
    for (P0, r0), (P1, r1) in zip(rings, rings[1:]):
        for k in range(ring):
            q = (k + 1) % ring
            mid = (r0[k] + r0[q] + r1[k] + r1[q]) / 4
            face(p, [r0[k], r0[q], r1[q], r1[k]], mid - (P0 + P1) / 2, "grip")


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


ROLL_CLEAR = (0.85, 0.5)  # how far out from the arm the gun swings as it rolls round it: at the side, and under it


def rolled(Q, deg):
    """Points rolled deg about the forearm's axis (x), the outside way (the right arm's: 90 puts the top at its right,
    180 under it), swung out from the arm as they go so the gun clears the hand's edge and the plates."""
    a = math.radians(deg)
    y, z = Q[:, 1].copy(), Q[:, 2].copy()
    R = Q.copy()
    R[:, 1] = y * math.cos(a) - z * math.sin(a)
    R[:, 2] = y * math.sin(a) + z * math.cos(a)
    out = ROLL_CLEAR[0] * abs(math.sin(a)) + ROLL_CLEAR[1] * max(0.0, -math.cos(a))
    R[:, 1] += out * -math.sin(a)       # (along the way the gun's top now faces: out from the arm)
    R[:, 2] += out * math.cos(a)
    return R


def pose(P, groups, turn=0.0, slide=0.0, brick=(0, 0, 0), lhand=None, kick=0.0, roll=0.0):
    """Points P (n, 3) with their groups, from the deployed pose: the gun turned by turn degrees (spin) and
    slid slide units along the forearm, kick units of recoil; the brick moved by brick on top of that; the
    left hand moved by lhand from the brick's handle (default: out of sight). All of it where it is mounted
    (MOUNT); the gun and the brick rolled roll degrees round the forearm (rolled: the draw)."""
    Q = P.copy()
    g = np.asarray(groups)
    mount = np.array([-MOUNT[0], 0.0, MOUNT[1]])
    for name in ("gun", "brick"):
        m = g == name
        Q[m] = spin(P[m], turn) + mount
        if roll:
            Q[m] = rolled(Q[m], roll)
        Q[m, 0] += slide - kick
    Q[g == "brick"] += np.asarray(brick, float)
    Q[g == "lhand"] += OFF if lhand is None else np.asarray(lhand, float) + mount
    return Q


def build():
    """The gun on top of the hand, seated in its saddle; the faces' groups in p.groups. (The Mech's gauntlets in
    its view: gauntlets.)"""
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
    # The breech: the nine barrels through the block and out of its back, where the brick feeds them, a round's
    # brass base in each (seen when the brick is off to reload: the user, 2026-10-29: the brick should connect
    # "directly to the barrels instead of just to empty space"). Inside the brick while it is on.
    back = x0 - BREECH
    for cy, cz in bores()[0]:
        outer = [(cy + STUB * math.cos(a), cz + STUB * math.sin(a)) for a in ang]
        inner = [(cy + BORE * math.cos(a), cz + BORE * math.sin(a)) for a in ang]
        base = [(cy + 0.86 * BORE * math.cos(a), cz + 0.86 * BORE * math.sin(a)) for a in ang]
        axis = np.array([back, cy, cz])
        for k in range(8):
            q = (k + 1) % 8
            mid = X(back, ((outer[k][0] + outer[q][0]) / 2, (outer[k][1] + outer[q][1]) / 2))
            face(p, [X(back, outer[k]), X(x0, outer[k]), X(x0, outer[q]), X(back, outer[q])], mid - axis, "barrel")
            face(p, [X(back, inner[k]), X(back, inner[q]), X(back, outer[q]), X(back, outer[k])], np.array([-1.0, 0, 0]), "barrel")
            face(p, [X(back, inner[k]), X(back + BORE_DEPTH, inner[k]), X(back + BORE_DEPTH, inner[q]), X(back, inner[q])],
                 axis - mid, "bore")
            face(p, [X(back + 0.3, (cy, cz)), X(back + 0.3, base[k]), X(back + 0.3, base[q])], np.array([-1.0, 0, 0]), "nose")
    # Under it, the saddle: a low shoe from the block's underside down onto the top of the forearm and the wrist,
    # shaped to them (blade_arms.surface, out past their plates); its top under the block and the brick, its
    # underside on the arm; its side walls, low, under the block's sides, all that shows.
    import blade_arms
    zb = zc - h
    sd = SADDLE
    xs, vs = np.linspace(sd["x0"], sd["x1"], 7), np.linspace(-1, 1, 7)

    def under(x, v):     # (the arm where the saddle is posed: MOUNT)
        q = blade_arms.surface(x - MOUNT[0] - GAUNTLET_X, math.pi / 2 + v * sd["half"])
        rad = np.array([0.0, q[1], q[2]])
        q = q + rad / np.linalg.norm(rad) * sd["out"]
        return np.array([x, q[1], min(q[2] - MOUNT[1], zb - 0.02)])
    B = [[under(x, v) for v in vs] for x in xs]
    T = [[np.array([b[0], b[1], zb]) for b in row] for row in B]
    last = len(vs) - 1
    for i in range(len(xs) - 1):
        for j in range(last):
            q = [B[i][j], B[i][j + 1], B[i + 1][j + 1], B[i + 1][j]]
            m = np.mean(q, 0)
            face(p, q, -np.array([0.0, m[1], m[2]]), "frame")
        for j in (0, last):
            face(p, [B[i][j], B[i + 1][j], T[i + 1][j], T[i][j]], np.array([0.0, B[i][j][1], 0.0]), "frame")
    for i, sx in ((0, -1.0), (len(xs) - 1, 1.0)):
        for j in range(last):
            face(p, [B[i][j], B[i][j + 1], T[i][j + 1], T[i][j]], np.array([sx, 0.0, 0.0]), "frame")
    tag(p, "gun")
    # The brick: a big box on the barrel block's back, a handle on top.
    b = BRICK
    prism(p, chamfered(b["y"], b["z0"], b["z1"], 0.35), b["x0"], b["x1"], "x", "brick", ("brick", "brick"))
    handle(p)
    tag(p, "brick")
    tag(p, "mount")     # (none now: the pin is inside the wrist)
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


# ---- paint. Colours 0-255: the Mech's palette. Sizes in game units. Matched to the game's own weapon skins (the
# user, 2026-10-29: "more similar to the textures in the actual base game"): HDTP's are dark, nearly grey gunmetal
# (luma 10/50/90%: about 18/40/80, saturation under 0.18) with strong grit, scratches, dirt in the grooves, worn
# edges and painted bevels; the cannon's first skins were clean, brighter and flatter (build/tmp/tex_stats.py).
CASING = np.array([60.0, 63.0, 67.0])           # dark gunmetal, barely blue
OLIVE = np.array([74.0, 76.0, 62.0])            # the brick: drab, as the plasma rifle's body
FACEPLATE = np.array([30.0, 31.0, 34.0])
BRASS = np.array([170.0, 132.0, 70.0])
STEEL = np.array([150.0, 156.0, 162.0])
HAZARD = np.array([200.0, 158.0, 46.0])         # warning yellow, dulled
INK = np.array([22.0, 22.0, 24.0])
WORN = np.array([126.0, 128.0, 130.0])          # bare metal where paint is chipped or scratched


def wear(pos, n, mats, scale=22.0):
    """The grunge swatch at each texel (tools/grunge.py, from three sides): dirt 0-1, grain and scratches about 0."""
    g = mech_bake.triplanar(mats["grunge"], pos, np.broadcast_to(n, pos.shape), scale)
    return g[..., 0:1], g[..., 1:2] - 0.5, g[..., 2:3] - 0.5


def weathered(col, pos, n, mats, edge, painted, seed):
    """Grit, dirt blotches, scratches (bright: bare metal through paint; dark: pits) and, on painted parts, paint
    chipped off at the edges."""
    dirt, grain, scr = wear(pos, n, mats)
    col = col * (1 + 1.0 * grain) * (1 - 0.5 * dirt)
    bare = np.clip((scr - 0.06) * 4.0, 0, 1) * (0.5 if painted else 0.32)
    col = col + (WORN - col) * bare
    col = col * (1 + np.clip(scr + 0.12, -0.5, 0) * 1.6)
    if painted:                                 # paint worn through to the metal along the edges, in patches
        chip = (hashn(pos, 3.0, seed)[..., None] > 0.62) & (edge < 0.05 + 0.04 * hashn(pos, 9.0, seed + 1)[..., None])
        col = np.where(chip, WORN * (0.7 + 0.3 * grain), col)
    return col


_LABELS = {}


def label(text, r, u, height):
    """Where a stencil of text is (centred on r = u = 0, height tall, reading along r): a mask."""
    from PIL import Image, ImageDraw, ImageFont
    if text not in _LABELS:
        font = ImageFont.load_default()
        w = int(ImageDraw.Draw(Image.new("L", (1, 1))).textlength(text, font=font)) + 2
        im = Image.new("L", (w, 12), 0)
        ImageDraw.Draw(im).text((1, 0), text, fill=255, font=font)
        _LABELS[text] = np.asarray(im) > 100
    m = _LABELS[text]
    H, W = m.shape
    px = np.floor((r / height + W / H / 2) * H).astype(int)
    py = np.floor((0.5 - u / height) * H).astype(int)
    ok = (px >= 0) & (px < W) & (py >= 0) & (py < H)
    return ok & m[np.clip(py, 0, H - 1), np.clip(px, 0, W - 1)]


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
        col = np.where(plate[..., None], np.array([40.0, 41, 44]), col)
        col = np.where(label("MS-9 STORM", r, u - 0.06, 0.13)[..., None], np.array([150.0, 152, 154]), col)
        col = np.where(label("9x7.62 CL", r, u + 0.09, 0.11)[..., None], np.array([120.0, 122, 124]), col)
        strip = (pos[..., 0] > 13.6) & (pos[..., 0] < 18.6) & (np.abs(pos[..., 2] - (zc - h + 0.32)) < 0.07)
        col = np.where(strip[..., None], mech_bake.LIGHT, col)
    return col


def tinted(col, rl):
    """The relief's colours: raised plates a little lighter, slots and holes dark inside."""
    if rl is None:
        return col
    _, dark, plate = rl
    return col * (1 + 0.22 * plate) * (1 - 0.75 * dark)


# ---- painted relief: the detail the game's weapon skins paint onto flat faces (the user, 2026-10-29: Revision's skins
# "give the models themselves depth and detail"; these "look really dull... not intricate"). Each kind of face has a
# height map in its own plane (game units: a along the gun, b across it), made of recessed panels, raised plates, slots,
# ports, ribs, screws; the slopes are lit by the bake's key light, so they read carved and raised, as HDTP's do.

def _smooth(x, w):
    t = np.clip(x / w, 0, 1)
    return t * t * (3 - 2 * t)


def sd_box(a, b, ca, cb, ha, hb, r=0.0):
    """Signed distance to a rounded rectangle (negative inside)."""
    qa = np.abs(a - ca) - (ha - r)
    qb = np.abs(b - cb) - (hb - r)
    return np.hypot(np.maximum(qa, 0), np.maximum(qb, 0)) + np.minimum(np.maximum(qa, qb), 0) - r


def sd_capsule(a, b, a0, b0, a1, b1, r):
    """Signed distance to a pill (a slot) from (a0, b0) to (a1, b1), r its half width."""
    pa, pb, da, db = a - a0, b - b0, a1 - a0, b1 - b0
    t = np.clip((pa * da + pb * db) / (da * da + db * db), 0, 1)
    return np.hypot(pa - t * da, pb - t * db) - r


class Relief:
    """A height map built up shape by shape, with where the dark interiors and the raised plates are."""

    def __init__(self, a):
        self.H = np.zeros_like(a)
        self.dark = np.zeros_like(a)
        self.plate = np.zeros_like(a)

    def recess(self, d, depth=0.035, bevel=0.035, dark=0.0):
        k = _smooth(-d, bevel)
        self.H = self.H - depth * k
        self.dark = np.maximum(self.dark, dark * k)

    def raise_(self, d, height=0.03, bevel=0.03, plate=1.0):
        k = _smooth(-d, bevel)
        self.H = self.H + height * k
        self.plate = np.maximum(self.plate, plate * k)

    def screw(self, a, b, ca, cb, R=0.08):
        r = np.hypot(a - ca, b - cb)
        self.H = self.H + 0.024 * np.sqrt(np.clip(1 - (r / R) ** 2, 0, 1))
        slot = (np.abs((a - ca) - (b - cb)) < 0.016) & (r < 0.75 * R)
        self.dark = np.maximum(self.dark, 0.55 * slot)


def relief(region, kind, a, b):
    """The height map of one kind of face of a region at in-plane points (a, b)."""
    R = Relief(a)
    zc, h = CASS["z"], CASS["h"]
    if region == "casing" and kind == "side":                    # a = x (12.6-20.6), b = z (1.7-4.3)
        for s in (13.9, 18.95):                                  # the panel joints: grooves
            R.recess(np.abs(a - s) - 0.022, 0.03, 0.02, 0.4)
        R.recess(sd_box(a, b, 16.42, zc + 0.12, 2.32, 0.86, 0.14))                       # the main panel, set in
        R.recess(sd_box(a, b, 16.1, zc - h + 0.32, 2.55, 0.07, 0.05), 0.03, 0.02)        # the light's channel
        for k in range(4):                                       # vents
            bb = zc + 0.62 - 0.27 * k
            R.recess(sd_capsule(a, b, 14.45, bb, 15.2, bb, 0.07), 0.06, 0.03, 0.85)
        R.raise_(sd_box(a, b, 16.6, zc + 0.04, 0.82, 0.8, 0.07), 0.035, 0.03)            # the plate under the markings
        for ca in (15.9, 17.3):
            for cb in (zc - 0.64, zc + 0.72):
                R.screw(a, b, ca, cb)
        for (a0, b0, a1, b1) in ((17.6, zc + 0.8, 17.95, zc + 0.45), (17.95, zc + 0.45, 18.7, zc + 0.45),
                                 (17.6, zc - 0.55, 18.7, zc - 0.55)):          # cut lines
            R.recess(sd_capsule(a, b, a0, b0, a1, b1, 0.018), 0.025, 0.015, 0.5)
        R.recess(np.hypot(a - 18.25, b - (zc - 0.02)) - 0.2, 0.05, 0.03, 0.6)           # a round port...
        R.raise_(np.abs(np.hypot(a - 18.25, b - (zc - 0.02)) - 0.12) - 0.03, 0.03, 0.02, 0.5)   # ...its ring
        for k in range(5):                                       # a rivet column behind the first joint
            R.screw(a, b, 13.3, zc - 0.85 + 0.42 * k, 0.07)
        for ca in (19.95, 20.3):                                 # cooling holes at the muzzle end
            for k in range(5):
                R.recess(np.hypot(a - ca, b - (zc - 0.8 + 0.4 * k)) - 0.1, 0.06, 0.03, 0.9)
    elif region == "casing" and kind == "top":                   # a = x, b = y (+-1.3)
        for s in (13.9, 18.95):
            R.recess(np.abs(a - s) - 0.022, 0.03, 0.02, 0.4)
        rail = sd_box(a, b, 16.4, 0.0, 2.3, 0.4, 0.04)
        R.raise_(rail, 0.04, 0.025, 0.6)                         # a rail along the top...
        cut = (np.mod(a - 14.1, 0.32) < 0.13) & (rail < -0.05) & (np.abs(b) < 0.28)
        R.H = R.H - 0.03 * cut                                   # ...slotted across
        R.dark = np.maximum(R.dark, 0.35 * cut)
        vx = a - 13.2
        R.recess(np.where((np.abs(b) < 0.6) & (vx > 0) & (vx < 0.5), np.abs(np.mod(vx, 0.1) - 0.05) - 0.022, 1.0),
                 0.05, 0.015, 0.9)                               # the vent
        for ca in (12.95, 19.25):
            for cb in (-0.95, 0.95):
                R.screw(a, b, ca, cb, 0.07)
    elif region == "brick" and kind == "side":                   # a = x (8.8-12.6), b = z (1.7-4.3)
        b0, b1 = BRICK["z0"], BRICK["z1"]
        for k in range(4):                                       # ribs below the band
            bb = b0 + 0.3 + 0.55 * k
            if bb < b1 - 1.0:
                R.raise_(sd_box(a, b, 10.7, bb, 1.35, 0.08, 0.06), 0.03, 0.03, 0.3)
        R.raise_(sd_box(a, b, 10.7, b1 - 0.6, 1.95, 0.2, 0.03), 0.025, 0.02, 0.0)     # the band's strap
        for ca in (9.06, 12.34):                                 # corner brackets, screwed on
            R.raise_(sd_box(a, b, ca, (b0 + b1) / 2, 0.22, (b1 - b0) / 2 - 0.3, 0.05), 0.04, 0.03)
            for cb in (b0 + 0.55, b1 - 0.55):
                R.screw(a, b, ca, cb, 0.075)
    elif region == "brick" and kind == "top":                    # a = x, b = y (+-1.5)
        for ca in (BRICK["x0"] + 1.0, BRICK["x1"] - 1.0):        # plates under the handle's posts
            R.raise_(sd_box(a, b, ca, 0.0, 0.42, 0.62, 0.06), 0.035, 0.03)
            for sa in (-0.3, 0.3):
                for cb in (-0.48, 0.48):
                    R.screw(a, b, ca + sa, cb, 0.06)
        R.recess(sd_box(a, b, 10.7, 0.0, 0.62, 0.95, 0.08), 0.03, 0.03)      # a label panel between them
    elif region == "brick" and kind == "back":                   # a = y (+-1.5), b = z: the face the Mech sees most
        b0, b1 = BRICK["z0"], BRICK["z1"]
        R.recess(sd_box(a, b, 0.0, (b0 + b1) / 2, 1.18, (b1 - b0) / 2 - 0.28, 0.16))
        for i in (-1, 0, 1):                                     # the feed indicator: a disc for each of the nine barrels
            for j in (-1, 0, 1):
                ca, cb = 0.42 * i, (b0 + b1) / 2 - 0.1 + 0.42 * j
                R.raise_(np.hypot(a - ca, b - cb) - 0.15, 0.03, 0.025, 0.4)
                R.recess(np.hypot(a - ca, b - cb) - 0.07, 0.03, 0.02, 0.8)
        for ca in (-1.25, 1.25):
            for cb in (b0 + 0.3, b1 - 0.3):
                R.screw(a, b, ca, cb, 0.08)
    return R


def face_axes(n):
    """A face's plane axes (a, b) and its kind, by its normal; None for a slanted face (the chamfers)."""
    ax = np.abs(n)
    if ax[2] > 0.9:
        return np.array([1.0, 0, 0]), np.array([0, 1.0, 0]), "top" if n[2] > 0 else "bottom"
    if ax[1] > 0.9:
        return np.array([1.0, 0, 0]), np.array([0, 0, 1.0]), "side"
    if ax[0] > 0.9:
        return np.array([0, 1.0, 0]), np.array([0, 0, 1.0]), "back" if n[0] < 0 else "front"
    return None


def relief_light(region, pos, n):
    """A face's painted relief at its texels: (shade, dark, plate), or None. The slopes (by central differences) lit
    by the key light in the face's plane; recesses a little shaded at the bottom."""
    axes = face_axes(n)
    if axes is None:
        return None
    A, B, kind = axes
    a, b = pos @ A, pos @ B
    R = relief(region, kind, a, b)
    if not R.H.any() and not R.dark.any():
        return None
    e = 0.012
    Ha = (relief(region, kind, a + e, b).H - relief(region, kind, a - e, b).H) / (2 * e)
    Hb = (relief(region, kind, a, b + e).H - relief(region, kind, a, b - e).H) / (2 * e)
    La, Lb = float(mech_bake.KEY @ A), float(mech_bake.KEY @ B)
    shade = np.clip(1 - 2.2 * (Ha * La + Hb * Lb), 0.35, 1.9) * (1 - 0.35 * np.clip(-R.H / 0.06, 0, 1))
    return shade[..., None], R.dark[..., None], R.plate[..., None]


def paint(region, pos, n, a3, sx, ty, w, h, mats):
    """A face's colour at its texels, before the edge line, light and occlusion."""
    flat = np.ones(pos.shape[:-1] + (1,))
    nb = np.broadcast_to(n, pos.shape)
    edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
    rl = relief_light(region, pos, n) if region in ("casing", "brick", "frame") else None
    if region == "casing":                      # dark gunmetal, worn bright where hands and the brick rub
        col = tinted(CASING * (0.94 + 0.12 * hashn(pos, 0.8, 1)[..., None]), rl)
        col = decals(pos, n, col)
        if rl is not None:
            col = col * rl[0]
        col = weathered(col, pos, n, mats, edge, False, 2)
        if abs(float(n[1])) > 0.9:              # its blue light strip lit over the wear (a light doesn't weather)
            strip = (pos[..., 0] > 13.6) & (pos[..., 0] < 18.6) & (np.abs(pos[..., 2] - (CASS["z"] - CASS["h"] + 0.32)) < 0.07)
            col = np.where(strip[..., None], mech_bake.LIGHT, col)
        return col
    if region == "brick":                       # drab olive paint, ribbed sides, a yellow band, the round counter
        col = tinted(OLIVE * (0.94 + 0.12 * hashn(pos, 0.8, 5)[..., None]) * flat, rl)
        if abs(float(n[1])) > 0.9:
            band = np.abs(pos[..., 2] - (BRICK["z1"] - 0.6)) < 0.18
            col = np.where(band[..., None], HAZARD * 0.85, col)
            if n[1] > 0.9:                      # the left side: nine blue cells, a round counter
                d = pos - np.array([10.7, BRICK["y"], BRICK["z0"] + 1.0])
                box = (np.abs(d[..., 0]) < 1.5) & (np.abs(d[..., 2]) < 0.3)
                col = np.where(box[..., None], np.array([16.0, 17, 20]), col)
                cell = box & (np.abs(d[..., 2]) < 0.22) & (np.mod((d[..., 0] + 1.5) * 3.0, 1) < 0.7) & (np.abs(d[..., 0]) < 1.42)
            else:                               # the right side: its stencil
                d = pos - np.array([10.7, -BRICK["y"], BRICK["z0"] + 1.0])
                col = np.where(label("7.62 CASELESS 40", d[..., 0], d[..., 2], 0.2)[..., None], INK * 1.3, col)
        if rl is not None:
            col = col * rl[0]
        col = weathered(col, pos, n, mats, edge, True, 6)
        if n[1] > 0.9:                          # the counter's cells lit over the wear
            col = np.where(cell[..., None], mech_bake.LIGHT, col)
        return col
    if region == "chevron":                     # stencilled warning stripes, scuffed and dirty
        stripe = np.mod(pos[..., 0] + pos[..., 1] + pos[..., 2], 0.6) < 0.3
        return weathered(np.where(stripe[..., None], HAZARD * 0.8, INK * 1.6), pos, n, mats, edge, True, 9)
    if region in ("frame", "recess"):
        g = mech_bake.triplanar(mats["gunmetal"], pos, nb, 32).mean(-1, keepdims=True)
        col = tinted(g * (0.62 if region == "frame" else 0.34) * np.array([0.97, 0.99, 1.02]), rl)
        if rl is not None:
            col = col * rl[0]
        return weathered(col, pos, n, mats, edge, False, 11)
    if region == "barrel":                      # the barrels' ends out of the breech: worn steel, bright at the lip
        grain = mech_bake.triplanar(mats["steel"], pos, nb, 24).mean(-1, keepdims=True) / 128.0
        col = STEEL * (0.42 + 0.12 * grain)
        col = np.where((edge < 0.04) & (float(n[0]) < -0.9), STEEL * 0.85, col)
        return weathered(col, pos, n, mats, edge, False, 13)
    if region in ("face", "muzzle"):
        dirt, grain, _ = wear(pos, n, mats)
        col = FACEPLATE * (1 + 0.8 * grain) * (1 - 0.3 * dirt)
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
    if region == "grip":                        # the handle: rubberized, dark, a fine grit (one cell for all its faces)
        dirt, grain, _ = wear(pos, n, mats, 60.0)
        return np.array([44.0, 45.0, 48.0]) * (1 + 0.7 * grain) * (1 - 0.25 * dirt)
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
    mats["grunge"] = np.asarray(Image.open(os.path.join(mech_bake.MATS, "grunge.png")).convert("RGB"), float) / 255.0
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
            # A painted bevel at each edge, as the game's skins have: lit where the edge turns toward the key light,
            # shaded where it turns away, a thin dark seam at the very edge.
            U = mech_bake.unit(P[1] - P[0])
            V = mech_bake.unit(P[-1] - P[0])
            dist = np.stack([sx * w, (1 - sx) * w, ty * h, (1 - ty) * h], -1)
            near = dist.argmin(-1)
            outward = np.array([-U, U, -V, V])[near]
            dmin = dist.min(-1)
            if len(P) == 4:                     # (a triangle is part of a fanned cap: its inner edges are no edges)
                bev = np.clip(1 - dmin / 0.07, 0, 1) ** 1.5 * (outward @ mech_bake.KEY)
                col = col * (1 + 1.1 * bev)[..., None] * (0.5 + 0.5 * np.clip(dmin / 0.014, 0, 1))[..., None]
            light = 0.66 + 0.8 * (np.clip(float(n @ mech_bake.KEY), -1, 1) * 0.5 + 0.5) ** 2
            light = light * (0.88 + 0.2 * np.clip((pos[..., 2] + 1.5) / 6.5, 0, 1))      # lighter toward the top
            col = col * (light * (0.42 + 0.58 * np.clip(a3, 0, 1) ** 1.3))[..., None]  # dirt and shade in the grooves
            gloss = np.clip(float(n @ mech_bake.HALF), 0, 1) ** 6 * 0.35 * (0.6 + 0.4 * ty)   # a sheen, brighter up the face
            col = col * (1 + gloss)[..., None]
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
        n = None if r in SMOOTH else tuple(np.round(n / (np.linalg.norm(n) + 1e-12), 2))
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
# Y right, Z up; 256 raw units to one), every frame a pose of the gun and a move of the whole arm. The gun on the
# Mech's own gauntlet (tools/blade_arms.py, its paint), the arm placed as a gun is held in a shooter's view: low on
# the right, seen three-quarters from its left, the muzzle ahead. (Seen from just behind and above, as first built,
# the brick's back filled the view and the body's own forearm under it looked crude: the user wanted it "just as
# good" as the blades.)
K = 2.0                                        # the view's scale
BASE = (4.0, 9.5, -8.5, 8.0, 10.0, -12.0)      # the elbow ahead, out to the right, below; pitch, yaw in, roll its top in


def base_frame():
    """The arm's frame in the eye's (x ahead, y left, z up): its axes as columns, the elbow (as blade_view.placed)."""
    x, lat, z, pitch, yaw, roll = BASE
    a, b, r = (math.radians(v) for v in (pitch, yaw, roll))
    d = np.array([math.cos(a) * math.cos(b), math.cos(a) * math.sin(b), math.sin(a)])
    up = np.array([0.0, 0, 1]) - d[2] * d
    up /= np.linalg.norm(up)
    inward = np.cross(up, d)
    inward /= np.linalg.norm(inward)
    zz = math.cos(r) * up + math.sin(r) * inward
    return np.stack([d, np.cross(zz, d), zz], 1), np.array([x, -lat, z])


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
    R, E = base_frame()
    D = (P @ R.T + E) * K
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
    """Select: the arm comes up; the gun, upside down under the forearm, slides up the arm to its place, then rolls
    round the outside of the forearm onto its top (the user, 2026-10-29: "slide up the wrist, but then rotate around
    to the top of the forearm rather than flip over the hand... around the outside of the forearm"); settles."""
    up = span(t, 0.0, 0.3)
    return dict(arm=(0, 0, -14 * (1 - up), -25 * (1 - up), 0, 0), slide=-22 * (1 - span(t, 0.1, 0.5)),
                roll=180 * (1 - span(t, 0.5, 0.85)), kick=0.4 * math.sin(math.pi * span(t, 0.85, 1.0)))


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


def hopper(t):
    """A dry gun's first brick seated (CoopMechCannon's hopper: its rounds stripped into the gun with StormHopper's
    whirr and clinks): the gun shivers along the forearm as the feed runs, the brick rattling on its seat; still at
    the end (then ReloadBegin takes the empty brick off)."""
    on = span(t, 0.05, 0.15) * (1 - span(t, 0.82, 0.95))
    return dict(kick=0.05 * math.sin(2 * math.pi * 7 * t) * on, brick=(0.0, 0.0, 0.035 * math.sin(2 * math.pi * 11 * t) * on))


# The sequences DeusExWeapon plays: (name, frames, rate, pose of t in 0-1).
SEQS = [("Still", 1, 1, lambda t: {}),
        ("Select", 14, 20, draw),
        ("Down", 10, 20, lambda t: draw(1 - t) if t < 1 else draw(0.0)),
        ("Idle1", 12, 6, lambda t: dict(arm=(0, 0, 0.15 * math.sin(2 * math.pi * t), 0.3 * math.sin(2 * math.pi * t), 0, 0))),
        ("Shoot", 4, 40, lambda t: dict(kick=0.5 * (1 - t), arm=(-0.6 * (1 - t), 0, 0, 1.5 * (1 - t), 0, 0))),
        ("ReloadBegin", 10, 16, reload_begin),
        ("Reload", 6, 8, lambda t: dict(arm=(0, 0, 0.1 * math.sin(2 * math.pi * t), -4, 0, -12), brick=OFF, lhand=OFF)),
        ("ReloadEnd", 10, 16, reload_end),
        ("Hopper", 16, 16, hopper)]


GAUNTLET_X = 0.85                     # the gauntlet's wrist joint (blade_arms: 12.6-13.9) onto the gun's pin (PIVOT)
HANDLE = np.array([10.7, 0.0, BRICK["z1"] + 0.88])     # the brick's handle, its middle
IN_FIST = np.array([17.2, 0.0, -1.3])                    # where a handle goes through the gauntlet's curled fingers
REACH = np.array([0.35, -0.8, 0.5])                      # the left forearm's way to the handle: up from the lower left


def gauntlets():
    """The Mech's own forearms and hands as it holds the gun (blade_arms' blade arm without its blade and housing,
    the Mech's paint, skins 3 and 4): the right under the gun, its wrist on the pin; the left on the brick's handle
    (group lhand: out of sight but for the reload). (vertices, groups, triangles, skins), wound as built."""
    import blade_arms, blade_view
    a = blade_arms.made()
    A, _, tris, skins = blade_view.shared(a, drop=("blade", "housing", "portin") + blade_arms.UPPER_REGIONS)   # (the hatch shut, flush;
                                                                    # the upper arm off: the gun's view poses the forearm alone)
    right = A + np.array([GAUNTLET_X, 0.0, 0.0])
    u = REACH / np.linalg.norm(REACH)
    w = np.array([0.0, 0, 1]) - u[2] * u
    w /= np.linalg.norm(w)
    left = HANDLE + (A * np.array([1.0, -1, 1]) - IN_FIST) @ np.stack([u, np.cross(w, u), w], 1).T
    n = len(A)
    V = np.concatenate([right, left])
    G = ["arm"] * n + ["lhand"] * n
    T = tris + [(i + n, k + n, j + n, ui, uk, uj) for i, j, k, ui, uj, uk in tris]     # the left a mirror: wound back
    return V, G, T, [s + 3 for s in skins] * 2


def view_mesh(p):
    """StormView: (frames (n, verts, 3) in the view's frame, triangles, skins, sequences (name, start, count, rate)):
    the gun and the Mech's own gauntlets."""
    V, G, tris, skins = mesh_of(p, FIRST, ("muzzle",))
    AV, AG, atris, askins = gauntlets()
    n = len(V)
    V = np.concatenate([V, AV])
    G = list(G) + AG
    tris = tris + [(i + n, j + n, k + n, ui, uj, uk) for i, j, k, ui, uj, uk in atris]
    skins = list(skins) + askins
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
    if len(sys.argv) > 3 and sys.argv[3] == "5":       # five barrels, as a die shows (the user's earlier choice)
        DICE = FIVE
        out = os.path.join(out, "five")
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
        blender = os.environ.get("BLENDER", "blender")
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "blender_storm.py")
        subprocess.run([blender, "-b", "--factory-startup", "--python", script, "--",
                        os.path.abspath(os.path.join(out, "storm_sheet.png"))]
                       + [os.path.abspath(os.path.join(out, "storm_%s.obj" % s)) for s in POSES],
                       check=True, stdout=subprocess.DEVNULL)
        print("sheet:", os.path.join(out, "storm_sheet.png"))


if __name__ == "__main__":
    main()
