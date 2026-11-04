"""Kit nests, riffed off the KR-7 modular rack (tools/nest_concept.py mod). The user, 2026-11-03: "This is pretty much
perfect... throw in the bio battery cells... so even its power supply is scalable... riff off of this design... 5 separate
designs with the same... 6 images"; "use the BioCells models, like, verbatim". Then, on those riffs: the rack and the
vertical cells "are supposed to be the same thing... one has the walls on it and one doesn't" (the rack the cheaper,
non-hardened one; the cells modular and hardened, and stackable); kits held "grabbed by the tail", in a new pose, "the
drone is literally facing vertically... the props facing straight up, and it just shoots straight up really fast"; the
lockers hardened one by one, for launching indoors, a cell and a console in the sill; the pads "the absolute cheapest";
the carousel the dearest, its cameras "on at all points in time", a camera and a launcher at once; the field case the
man-portable vertical launcher; a cell to a kit for the pads and the lockers ("1-to-1"), the rest as they were.

Power in every design is the game's own bioelectric cell (DeusExItems BioCell, its own skin, unchanged), face-out so its
gauge shows. Kits are always mounted level, as they fly, held by the tail in a gimbal arm on a box's solid back wall.
The designs, cheapest first, six views each (one module; scaling; free-standing; on a wall; on the game's own van;
launching):

  LP-1 Perch    pads: single landing tiles, a kit and a cell each; cheap scattered pickets (rooftops, ledges, alleys)
  MR-3 Trellis  the rack: the shared box, open, kits out of the front; a cell bank that grows with it; a mass swarm from
                secure bases
  SL-4 Warden   lockers: hardened one by one, a shutter, a cell and a console in the sill; corridors and security desks,
                physically secure and tamper resistant, the console the way in
  FC-5 Valise   field case: two kits in foam, cells in its lid, fold-out legs; carried by squads (lootable), or a player's
                own portable nest
  VC-6 Quiver   vertical cells: the rack's box in armour; three stacked make one tube, out of its top one at a time; on a
                wall, the hive format, out of the front; hardened against weather and attack (bases, ships, subs)
  WC-9 Argus    carousel: tiers of six kits round a core of cells, cameras always on; crown-jewel sites only

  python -I tools/nest_riffs.py build <outdir, absolute>   (Blender writes renders relative to itself otherwise)
  blender -b --factory-startup --python tools/flykit_render.py -- <outdir>/spec.json <outdir>/render
  python -I tools/nest_riffs.py sheet [outdir]      (a sheet per design, and an overview)

Frame: x forward, y left, z up; game units (about 1.9 cm).
"""
import json, math, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from mech_parts import Part
from sensor_concept import eye, game_obj, moved, write_obj
from nest_concept import BW, TH, arm, claw, kit_obj, kr_vehicle_frame, obj_bounds, place, rot_z
from nest_skin import write_tex

X, Y, Z = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)
CP = 9.6                                                # cells' pitch in a bank (a cell is 8.7 square, 1.9 thick)
LO = HI = 0.0                                           # the kit's lowest and highest points (set by build)
TAILP = np.zeros(3)                                     # the kit's tail, where an arm holds it (set by build)

def unit(v):
    v = np.asarray(v, float)
    return v / np.linalg.norm(v)


def rot(axis, deg):
    """A turn of deg about axis (right-handed)."""
    k, a = unit(axis), math.radians(deg)
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + math.sin(a) * K + (1 - math.cos(a)) * K @ K


def facing(n, up=Z):
    """A turn taking a cell's gauge face (its +z) to n, its +y as near up as it goes."""
    n, up = unit(n), unit(up)
    if abs(np.dot(n, up)) > 0.99:
        up = unit(X)
    a = unit(np.cross(up, n))
    return np.stack([a, np.cross(n, a), n], 1)


def bx(p, c, size, reg=("hull", "panel")):
    """An axis-aligned box."""
    p.box(np.asarray(c, float), X, Y, Z, size, reg if isinstance(reg, tuple) else (reg, reg))


def plate(p, c, n, w, h, text):
    """A nameplate facing n (level), w wide and h tall: its face takes a plate of its own (nest_skin)."""
    n = unit(n)
    p.box(np.asarray(c, float), n, np.cross(Z, n), np.array(Z), (0.08, w, h), ("duct", "plate:" + text))


def hang(tip):
    return np.asarray(tip, float) - [0, 0, HI]


def sit(at):
    return np.asarray(at, float) - [0, 0, LO]


# ---- the game's bio cell, verbatim -------------------------------------------------------------------------------
_CELL = []


def cell_mesh():
    if not _CELL:
        flykit.PACKAGES["DeusExItems"] = os.path.join(flykit.REV, "System", "DeusExItems.u")
        flykit.PAYLOADS["_cell"] = ("DeusExItems", "BioCell", 1.0, {}, (0, 0, 0))
        _CELL.append(flykit.payload("_cell"))
    return _CELL[0]


def cells_obj(cells, out, tag):
    """Bio cells (the game's mesh and skin) as one OBJ: cells = [(R, t)], a cell turned by R, its middle at t."""
    from PIL import Image
    V, tris, uvs, tnames, tex = cell_mesh()
    mtl = os.path.join(out, "cells_%s.mtl" % tag)
    with open(mtl, "w") as f:
        for name, img in tex.items():
            Image.fromarray(img).save(os.path.join(out, "%s.png" % name))
            f.write("newmtl t_%s\nKd 1 1 1\nmap_Kd %s.png\n\n" % (name, name))
    path = os.path.join(out, "cells_%s.obj" % tag)
    with open(path, "w") as f:
        f.write("mtllib %s\n" % os.path.basename(mtl))
        base = k = 0
        for R, t in cells:
            for v in V @ np.asarray(R).T + np.asarray(t, float):
                f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
            for (a, b, c), uv, tn in zip(tris, uvs, tnames):
                for u in uv:
                    f.write("vt %.5f %.5f\n" % u)
                f.write("usemtl t_%s\nf %d/%d %d/%d %d/%d\n" % (tn, base + a + 1, k + 1, base + b + 1, k + 2, base + c + 1, k + 3))
                k += 3
            base += len(V)
    return path


def cell_bank(p, cells, face, n, cols, rows, up=Z, depth=2.4):
    """Bio cells face-out (normal n) in a grid, clipped top and bottom, on a housing whose face is centred at face."""
    R = facing(n, up)
    u, v, n = R[:, 0], R[:, 1], R[:, 2]
    face = np.asarray(face, float)
    W, H = cols * CP + 1.4, rows * CP + 1.4
    p.box(face - n * depth / 2, n, u, v, (depth, W, H), ("hull", "panel"))
    for i in range(cols):
        for j in range(rows):
            q = face + u * (i - (cols - 1) / 2) * CP + v * (j - (rows - 1) / 2) * CP
            cells.append((R, q + n * 0.95))
            for s in (1, -1):
                p.box(q + v * s * 4.55 + n * 1.0, n, u, v, (2.0, 2.6, 0.5), ("steel", "steel"))
    p.box(face + u * (W / 2 - 0.9) + v * (H / 2 - 0.5) + n * 0.03, n, u, v, (0.06, 0.8, 0.5), ("light", "light"))
    return W, H


def turned_in(p, cells, slots, build, deg, t):
    """What build(part, cells) makes (and its kits), turned deg about z and moved by t, into p."""
    q, qc = Part("sub"), []
    qs = build(q, qc)
    R, t = rot_z(deg), np.asarray(t, float)
    p.faces += moved(q, R, t).faces
    cells += [(R @ Rc, R @ np.asarray(tc) + t) for Rc, tc in qc]
    slots += [(R @ np.asarray(s[0]) + t, s[1] + deg) + tuple(s[2:]) for s in qs]


def knee(p, y, z, reach):
    """A knee brace at y under a shelf whose underside is at z, reaching out from the wall (x = 0)."""
    bx(p, (0.3, y, z - 7.0), (0.6, 3.0, 15.0), "duct")
    bx(p, (reach / 2, y, z - 0.6), (reach, 1.4, 1.2))
    p.prism((0.6, y, z - 13.0), (reach - 2.0, y, z - 1.2), Y, 0.6, 8, "steel", None, None)


def van_cam(V):
    cx, cy, roof = V
    return (cx, cy, roof * 0.65), 500, 62, 24


# ---- the shared box: KR-7 open, KV-7 hardened -----------------------------------------------------------------------
# One box with a solid back wall, a gimbal arm on it holding a kit by its tail, the kit always level, as it flies (the
# user: "the back is always the same solid piece where the arm is mounted"; "think of the mounting arm... to be like a
# gimbal... it's gonna be mounted normally... the gimbal's gonna be holding it from a different position so that you can
# launch multiple ones sequentially"). The open rack's kits go out of the front. The armoured boxes stack three high into
# one tube, their kits going straight up out of its top one at a time, top first, each arm folding flat up its wall once
# its kit has gone so the kits below can climb through: cheaper a kit, but only one at a time, loaded in order, and the
# bottom one out only after the two above it (which then go back in). On a wall in the hive format, a box on its side
# (its back wall down), the gimbal holds its kit level, nose out, and it goes straight out of the front.
VD = 16.0                                               # the box's depth (BW wide, TH tall)
FLY = 18.0                                              # how far above a tube's top a launched kit is shown
HIVE = np.array([[0, 0, 1], [0, -1, 0], [1, 0, 0]], float)   # a box on its side: its top out of the wall, its back wall down


def seg(p, a, b, r, region):
    a, b = np.asarray(a, float), np.asarray(b, float)
    d = b - a
    p.prism(a, b, Z if abs(d[2]) < 0.7 * np.linalg.norm(d) else X, r, 8, region, None, None)


def tail_grip(p, at):
    """The arm's hand: a wrist behind the kit's tail, two fingers either side of its spine's end."""
    at = np.asarray(at, float)
    p.prism(at - [1.4, 0, 0], at - [0.3, 0, 0], Z, 1.0, 8, "duct", "duct", "duct")
    for s in (1, -1):
        bx(p, at + [0.6, s * 1.9, 0], (2.4, 0.4, 1.4), "steel")


def gimbal(p, mount, T, folded=False):
    """The grab arm: from its mount on the back wall, a boom to a gimbal (a yoke and its pin) holding the kit's tail at T,
    the kit level; folded flat up the back wall (the box clear) when folded."""
    mount, T = np.asarray(mount, float), np.asarray(T, float)
    E, W = T - [2.4, 0, 0], T - [1.4, 0, 0]
    bx(p, mount, (1.4, 3.4, 3.4), "duct")
    if folded:
        seg(p, mount, mount + [0.4, 0, 4.0], 0.5, "steel")
        for s in (1, -1):
            bx(p, mount + [0.4, s * 1.5, 4.6], (1.6, 0.4, 1.6), "duct")
        return
    seg(p, mount, E, 0.5, "steel")
    seg(p, E, W, 0.5, "steel")
    for s in (1, -1):
        bx(p, W + [0.2, s * 1.5, 0], (1.6, 0.4, 1.6), "duct")
    p.prism(W + [0.3, -1.8, 0], W + [0.3, 1.8, 0], Z, 0.35, 8, "steel", "steel", "steel")
    tail_grip(p, T)


def frame(p, cells, o, hard=False, cut=False):
    """The box (BW wide, VD deep, TH tall; open top and bottom, so boxes stack into one tube): posts, rails, stacking
    pins, a solid back wall where the arm mounts; open (KR-7: couplers, lights), or armoured (KV-7: walls all round, a bio
    cell in its front panel; cut, the front cut away to show inside)."""
    o = np.asarray(o, float)
    hx, hy = VD / 2 - 0.6, BW / 2 - 0.6
    for sx in (1, -1):
        for sy in (1, -1):
            bx(p, o + [sx * hx, sy * hy, TH / 2], (1.2, 1.2, TH), "rack")
            p.prism(o + [sx * hx, sy * hy, TH], o + [sx * hx, sy * hy, TH + 0.5], X, 0.35, 6, "steel", None, "steel")
        for z in (0.6, TH - 0.6):
            bx(p, o + [sx * hx, 0, z], (1.2, BW - 2.4, 1.2), "rail")
    for sy in (1, -1):
        for z in (0.6, TH - 0.6):
            bx(p, o + [0, sy * hy, z], (VD - 2.4, 1.2, 1.2), "rail")
    bx(p, o + [-(VD / 2 - 0.7), 0, TH / 2], (0.8, BW - 1.2, TH - 1.2))                # the back wall
    if hard:
        for sy in (1, -1):
            bx(p, o + [0, sy * (BW / 2 - 0.7), TH / 2], (VD - 1.2, 0.8, TH - 1.2))
            bx(p, o + [0, sy * (BW / 2 - 0.28), TH * 0.62], (3.4, 0.06, 1.8), "pad")
        bx(p, o + [-(VD / 2 - 1.2), 0, TH / 2], (0.2, BW - 3.0, TH - 3.0), "band")
        if not cut:
            bx(p, o + [VD / 2 - 0.7, 0, TH / 2], (0.8, BW - 1.2, TH - 1.2))
            cell_bank(p, cells, o + [VD / 2 + 1.0, 0, TH / 2 - 0.8], X, 1, 1, depth=1.2)
            bx(p, o + [VD / 2 + 0.06, BW / 2 - 2.0, TH - 2.0], (0.1, 1.0, 0.6), "light")
            plate(p, o + [VD / 2 - 0.25, 0, 13.75], X, 9.0, 0.9, "VC-6 QUIVER")
    else:
        for sy in (1, -1):
            bx(p, o + [0, sy * (BW / 2 - 0.35), TH * 0.62], (5.0, 0.7, 3.2), "duct")
            bx(p, o + [0, sy * (BW / 2 + 0.02), TH * 0.62], (3.4, 0.06, 1.8), "pad")
        bx(p, o + [VD / 2 - 0.55, BW / 2 - 3.0, TH - 0.6], (0.12, 2.0, 0.6), "light")
        plate(p, o + [VD / 2 + 0.04, -BW / 2 + 5.5, TH - 0.6], X, 7.0, 1.1, "MR-3 TRELLIS")


def held(p, o, folded=False):
    """A box's arm and where its kit sits: level in the middle, facing the front, its tail in the gimbal (the kit's origin)."""
    o = np.asarray(o, float)
    K = o + [1.5, 0, 8.3]
    T = K + TAILP
    gimbal(p, [o[0] - VD / 2 + 1.5, 0, T[2]], T, folded)
    return K


def cap(p, top, state, lid_deg=-105.0):
    """A tube's cap, hinged at the back of its top: "closed" or "open"."""
    lid_ = Part("cap")
    bx(lid_, top + [0, 0, 0.6], (VD, BW, 1.2), ("panel", "hull"))
    bx(lid_, top + [VD / 2 - 1.5, 0, 1.5], (1.0, 6.0, 0.6), "rim")
    R = np.eye(3) if state == "closed" else rot(Y, lid_deg)
    hinge = top + [-VD / 2, 0, 0.6]
    p.faces += moved(lid_, R, hinge - R @ hinge).faces


def column(p, cells, o, n, kits=None, cap_="closed", cut=False):
    """n armoured boxes stacked into one tube on its floor plate, a cap on top, a kit level in each; they launch top
    first, each straight up the tube and out of its top. kits, a box each from the bottom: "held"; a height it has
    climbed above its place (its arm folded); "fly" (out, FLY above the top); None (gone)."""
    o = np.asarray(o, float)
    kits = kits or ["held"] * n
    bx(p, o + [0, 0, 0.3], (VD - 1.2, BW - 1.2, 0.6), "duct")
    top = o + [0, 0, n * (TH + 0.5)]
    s = []
    for j in range(n):
        k, m = kits[j], o + [0, 0, j * (TH + 0.5)]
        frame(p, cells, m, True, cut)
        K = held(p, m, folded=k != "held")
        if k == "held":
            s.append((K, 0.0))
        elif k == "fly":
            s.append((np.array([K[0], K[1], top[2] + FLY]), 0.0))
        elif k is not None:
            s.append((K + [0, 0, k], 0.0))
    if cap_:
        cap(p, top, cap_)
    return s


GOING = lambda n: ["held"] * (n - 2) + [TH + 6.0, "fly"]   # a tube launching: its top kit out, the next climbing after it


def rack_grid(p, cells, o, nx, nz, gone=()):
    """The open rack: nx by nz boxes, a kit level in each on its gimbal; gone: those let go, out of the front."""
    s, o = [], np.asarray(o, float)
    for i in range(nx):
        for j in range(nz):
            m = o + [0, (i - (nx - 1) / 2) * BW, j * (TH + 0.5)]
            frame(p, cells, m)
            K = held(p, m)
            s.append((K + ([26.0, 0, -2.0] if i * nz + j in gone else [0, 0, 0]), 0.0))
    return s


def frame_power(p, cells, o, nz):
    """The rack's power module, a box's footprint, nz tiers tall: bio cells two across, as many high as it stands."""
    o = np.asarray(o, float)
    h = nz * (TH + 0.5) - 0.5
    flykit.chamfer_box(p, tuple(o + [-VD / 2, -BW / 2, 0]), tuple(o + [VD / 2, BW / 2, h]), 0.5, "hull", "panel")
    rows = max(1, int((h - 5.0) // CP))
    cell_bank(p, cells, o + [VD / 2 + 1.0, 0, 2.0 + (rows * CP + 1.4) / 2], X, 2, rows)
    plate(p, o + [VD / 2 + 0.04, 0, 1.0], X, 9.0, 1.0, "MR-3 CELL BANK")
    p.prism(o + [0, 0, h], o + [0, 0, h + 1.6], X, 1.0, 10, "light", None, "light")
    p.prism(o + [-VD / 2 + 2, BW / 2 - 3, h], o + [-VD / 2 + 2, BW / 2 - 3, h + 24], X, 0.9, 10, "duct", None, None)


def feet(p, o, width, depth=VD):
    """A base: a beam under the boxes, splayed feet with pads."""
    o = np.asarray(o, float)
    bx(p, o + [0, 0, 1.6], (depth + 1, width, 1.6), "duct")
    for y in np.linspace(-width / 2 + 2, width / 2 - 2, max(2, int(width // BW) + 1)):
        bx(p, o + [0, y, 0.5], (depth + 8, 2.2, 1.0))
        for sx in (1, -1):
            p.prism(o + [sx * (depth / 2 + 3.4), y, 0], o + [sx * (depth / 2 + 3.4), y, -0.4], X, 1.4, 8, "band", "band", None)


def skids(p, width):
    for x in (-VD / 2 + 2, VD / 2 - 2):
        bx(p, (x, 0, 1.0), (3.0, width + 6, 2.0), "duct")


def rack(p, cells, y0, nx, nz, gone=(), base=True):
    """The open rack, nx by nz from y0, a power module at its end, on feet: its kits."""
    zb = 2.4 if base else 0.0
    if base:
        feet(p, (0, y0 + (nx + 1) * BW / 2, 0), (nx + 1) * BW)
    s = rack_grid(p, cells, (0, y0 + nx * BW / 2, zb), nx, nz, gone)
    frame_power(p, cells, (0, y0 + nx * BW + BW / 2, zb), nz)
    return s


def tubes(p, cells, y0, nx, nz, kits={}, caps={}, cut=(), z0=0.0):
    """nx tubes nz boxes high from y0, at z0: their kits."""
    s = []
    for i in range(nx):
        s += column(p, cells, (0, y0 + (i + 0.5) * BW, z0), nz, kits.get(i), caps.get(i, "closed"), i in cut)
    return s


def wall_mount(p, n, top, bottom, back, depth, hooks=True):
    """On a wall (x = 0): a rail above n boxes (a hook over each), a knee brace under every joint."""
    width = n * BW
    bx(p, (1.2, 0, top + 2.6), (2.4, width + 6, 3.6))
    for k in range(n if hooks else 0):
        y = -width / 2 + (k + 0.5) * BW
        bx(p, ((back + 1.6) / 2, y, top + 0.4), (back + 1.6, 3.0, 0.8), "duct")
        bx(p, (back + 1.4, y, top - 0.2), (0.4, 3.0, 2.0), "duct")
    for y in [-width / 2 + 0.8] + [-width / 2 + k * BW for k in range(1, n)] + [width / 2 - 0.8]:
        knee(p, y, bottom, back + depth)


def hive_cell(p, cells, t, go=False):
    """The hive format: one armoured box on its side on a wall, its top (the cap) out of the wall, its back wall down;
    the gimbal on that wall holds its kit level, nose out (go: the cap down, the kit on its way out of the front)."""
    t = np.asarray(t, float)
    q, qc = Part("cell"), []
    frame(q, qc, (0, 0, 0), True)
    bx(q, (0, 0, 0.3), (VD - 1.2, BW - 1.2, 0.6), "duct")
    cap(q, np.array([0, 0, TH + 0.5]), "open" if go else "closed", -90.0)
    p.faces += moved(q, HIVE, t).faces
    cells += [(HIVE @ Rc, HIVE @ np.asarray(tc) + t) for Rc, tc in qc]
    floor_z = t[2] - VD / 2 + 1.1
    K = t + [8.5, 0, -0.7]
    T = K + TAILP
    gimbal(p, [T[0] - 2.4, 0, floor_z + 0.7], T)
    return [(K + ([16.0, 0, 0] if go else [0, 0, 0]), 0.0)] if go else []


def kr_one(p, c):
    return rack(p, c, -BW, 1, 1, base=False), ((0, 0, 9), 74, 30, 18)


def kr_scale(p, c):
    s, y = [], -105.0
    for nx, nz in ((1, 1), (2, 1), (3, 2)):
        s += rack(p, c, y, nx, nz)
        y += (nx + 1) * BW + 10
    return s, ((0, 14, 18), 350, 22, 12)


def kr_free(p, c):
    return rack(p, c, -2 * BW, 3, 2), ((4, 0, 18), 138, 30, 16)


def kr_wall(p, c):
    back, bottom = 0.6, 28.0
    s = rack_grid(p, c, (back + VD / 2, -BW / 2, bottom), 4, 1)
    frame_power(p, c, (back + VD / 2, 2 * BW, bottom), 1)
    wall_mount(p, 5, bottom + TH, bottom, back, VD)
    return s, ((12, 0, 32), 155, 36, 10)


def kr_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 5 * BW + 6, 2 * VD + 6)
    s = []

    def row(q, qc):
        r = rack_grid(q, qc, (0, -BW / 2, roof + 2.6), 4, 1)
        frame_power(q, qc, (0, 2 * BW, roof + 2.6), 1)
        return r
    for k in (1, -1):
        turned_in(p, c, s, row, 90 * k, (cx, cy + k * (VD / 2 + 0.3), 0))
    return s, van_cam(V)


def kr_launch(p, c):
    return rack(p, c, -2 * BW, 3, 2, gone=(1,)), ((10, 0, 18), 150, 28, 14)


def kv_one(p, c):
    return column(p, c, (0, 0, 0), 1, [12.0], "open"), ((2, 0, 13), 88, 30, 28)


def kv_scale(p, c):
    s, y = [], -70.0
    for nx, nz, kits, caps in ((1, 1, {}, {}), (1, 2, {0: GOING(2)}, {0: "open"}), (3, 3, {1: GOING(3)}, {1: "open"})):
        feet(p, (0, y + nx * BW / 2, 0), nx * BW)
        s += tubes(p, c, y, nx, nz, kits, caps, z0=2.4)
        y += nx * BW + 14
    return s, ((0, 10, 26), 300, 22, 12)


def kv_free(p, c):
    skids(p, 3 * BW)
    return tubes(p, c, -1.5 * BW, 3, 3, {0: GOING(3)}, {0: "open"}, z0=2.0), ((6, 0, 30), 175, 30, 14)


def kv_wall(p, c):
    s, base = [], 22.0
    bx(p, (0.3, 0, base + 1.5 * (VD + 0.5)), (0.6, 3 * BW + 4, 3 * (VD + 0.5) + 4))
    for i in range(3):
        for j in range(3):
            s += hive_cell(p, c, (0.6, (i - 1) * BW, base + VD / 2 + j * (VD + 0.5)), (i, j) == (1, 1))
    for y in (-1.5 * BW + 0.8, -0.5 * BW, 0.5 * BW, 1.5 * BW - 0.8):
        knee(p, y, base, TH + 2.0)
    return s, ((16, 0, 48), 185, 34, 10)


def kv_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 3 * BW + 6, 2 * VD + 6)
    s = []

    def row(q, qc):
        r = []
        for i in range(3):
            r += column(q, qc, (0, (i - 1) * BW, roof + 2.6), 1, ["fly"] if i == 1 else None, "open" if i == 1 else "closed")
        return r
    for k in (1, -1):
        turned_in(p, c, s, row, 90 * k, (cx, cy + k * (VD / 2 + 0.3), 0))
    return s, van_cam(V)


def kv_launch(p, c):
    skids(p, 2 * BW)
    return tubes(p, c, -BW, 2, 3, {1: GOING(3)}, {1: "open"}, cut=(1,), z0=2.0), ((4, 0, 36), 185, 28, 12)


# ---- KL-7: lockers --------------------------------------------------------------------------------------------------
LW, LD, LH, SILL = 22.0, 16.0, 33.0, 12.0


def console(p, c):
    """A console on a sill: Revision's own control panel (a keypad, a screen) on its housing."""
    p.box(np.asarray(c, float) + [0.6, 0, 0], X, Y, Z, (1.2, 9.4, 10.0), ("duct", "face:ClenCntrlPanl_4A"))


def locker(p, cells, o, open_=False):
    """The rack's module boxed in armour: a roll-up shutter over its front; a bio cell (the viewer's left) and a console
    (the right) in its sill."""
    o = np.asarray(o, float)
    for s in (1, -1):
        bx(p, o + [0, s * (LW / 2 - 0.5), LH / 2], (LD, 1.0, LH))
        bx(p, o + [0, s * (LW / 2 + 0.02), 22.0], (4.0, 0.06, 2.4), "pad")
        for sx in (1, -1):
            bx(p, o + [sx * (LD / 2 - 0.6), s * (LW / 2 - 0.6), LH / 2], (1.3, 1.3, LH + 0.1), "duct")
            p.prism(o + [sx * (LD / 2 - 0.6), s * (LW / 2 - 0.6), LH + 0.05], o + [sx * (LD / 2 - 0.6), s * (LW / 2 - 0.6), LH + 0.55],
                    X, 0.35, 6, "steel", None, "steel")
    bx(p, o + [-(LD / 2 - 0.5), 0, LH / 2], (1.0, LW, LH))
    bx(p, o + [-(LD / 2 - 1.1), 0, (LH + SILL) / 2], (0.2, LW - 2, LH - SILL - 2), "band")
    bx(p, o + [0, 0, LH - 0.5], (LD, LW, 1.0))
    bx(p, o + [0, 0, SILL], (LD, LW, 1.0))
    bx(p, o + [LD / 2 - 0.5, 0, SILL / 2], (1.0, LW, SILL))
    bx(p, o + [LD / 2 - 0.5, 0, LH - 1.6], (1.0, LW, 2.2))
    cell_bank(p, cells, o + [LD / 2 + 1.0, -LW / 4, SILL / 2], X, 1, 1)
    console(p, o + [LD / 2, LW / 4, SILL / 2])
    plate(p, o + [0, LW / 2 + 0.04, LH - 6.0], Y, 8.0, 1.6, "SL-4 WARDEN")
    if open_:
        p.prism(o + [LD / 2 - 2.0, -(LW / 2 - 1.0), LH - 4.2], o + [LD / 2 - 2.0, LW / 2 - 1.0, LH - 4.2], Z, 1.5, 10, "panel",
                "duct", "duct")
        tip = o + [1.0, 0, LH - 5.6]
        arm(p, o + [1.0, 0, LH - 1.0], [tip])
        claw(p, tip)
        return [(hang(tip), 0.0)]
    for z in np.arange(SILL + 1.1, LH - 2.7, 1.25):
        bx(p, o + [LD / 2 - 0.3, 0, z], (0.5, LW - 2.0, 1.1), "panel")
    return []


def lockers(p, cells, o, nx, nz, opened=()):
    s = []
    for i in range(nx):
        for j in range(nz):
            s += locker(p, cells, np.asarray(o, float) + [0, (i - (nx - 1) / 2) * LW, j * (LH + 0.5)], i * nz + j in opened)
    return s


def plinth(p, y, width, depth):
    bx(p, (0, y, 1.0), (depth + 4, width + 2, 2.0), "duct")


def kl_one(p, c):
    return locker(p, c, (0, 0, 0), True), ((0, 0, 15), 86, 30, 14)


def kl_scale(p, c):
    s, y = [], -78.0
    for nx, nz, op in ((1, 1, (0,)), (2, 1, (1,)), (3, 2, (1, 4))):
        w = nx * LW
        plinth(p, y + w / 2, w, LD)
        s += lockers(p, c, (0, y + w / 2, 2.0), nx, nz, op)
        y += w + 12
    return s, ((0, 0, 26), 260, 22, 12)


def kl_free(p, c):
    plinth(p, 0, 4 * LW, LD)
    s = lockers(p, c, (0, 0, 2.0), 4, 2, (1, 4))
    p.prism((-LD / 2 + 2, 2 * LW - 3, 2 * LH + 3), (-LD / 2 + 2, 2 * LW - 3, 2 * LH + 22), X, 0.9, 10, "duct", None, None)
    p.prism((-LD / 2 + 2, 2 * LW - 3, 2 * LH + 22), (-LD / 2 + 2, 2 * LW - 3, 2 * LH + 24), X, 1.2, 10, "light", None, "light")
    return s, ((0, 0, 34), 195, 30, 12)


def kl_wall(p, c):
    bottom = 22.0
    s = lockers(p, c, (0.6 + LD / 2, 0, bottom), 3, 2, (2, 5))
    top = bottom + 2 * (LH + 0.5)
    bx(p, (1.2, 0, top + 2.4), (2.4, 3 * LW + 6, 3.6))
    for y in (-1.5 * LW + 0.8, -0.5 * LW, 0.5 * LW, 1.5 * LW - 0.8):
        knee(p, y, bottom, LD + 0.6)
    return s, ((10, 0, 50), 195, 36, 10)


def kl_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 3 * LW + 6, 2 * LD + 6)
    s = []
    for k in (1, -1):
        turned_in(p, c, s, lambda q, qc: lockers(q, qc, (0, 0, roof + 2.6), 3, 1, (1,)), 90 * k, (cx, cy + k * (LD / 2 + 0.3), 0))
    return s, van_cam(V)


# ---- KC-7: carousel ---------------------------------------------------------------------------------------------------
TT, RK = 22.0, 20.0                                     # a tier's height, the kits' radius
ANG6 = [30.0 + 60 * k for k in range(6)]


def paged(p, n0):
    """The faces from n0 on in Bob Page's white panelling (the Argus guards the crown jewels: MJ12's own sites)."""
    p.faces[n0:] = [(pts, {"hull": "page", "panel": "page2"}.get(r, r)) for pts, r in p.faces[n0:]]


def carousel_tier(p, cells, o, angles, core=True):
    """Kits hanging on arms round a hub, facing out; the core under the hub faced with bio cells on all four sides."""
    n0 = len(p.faces)
    o = np.asarray(o, float)
    if core:
        bx(p, o + [0, 0, TT / 2], (12.0, 12.0, TT))
        for a in (0, 90, 180, 270):
            n = rot_z(a) @ np.array(X)
            cell_bank(p, cells, o + n * 7.0 + [0, 0, 8.0], n, 1, 1)
        p.prism(o, o + [0, 0, 1.6], X, 8.5, 8, "duct", "duct", "duct")
        p.prism(o + [0, 0, TT - 2.6], o + [0, 0, TT - 0.6], X, 9.0, 6, "duct", "duct", "duct")
    else:
        bx(p, o + [4.75, 0, TT - 1.6], (9.5, 18.0, 2.0), "duct")
    s = []
    for a in angles:
        d = rot_z(a) @ np.array(X)
        tip = o + d * RK + [0, 0, TT - 4.5]
        arm(p, o + d * 7.5 + [0, 0, TT - 1.6], [o + d * 14.0 + [0, 0, TT - 0.6], tip])
        claw(p, tip)
        p.box(o + d * 14.0 + [0, 0, TT + 0.1], d, np.cross(Z, d), Z, (0.8, 0.8, 0.4), ("light", "light"))
        s.append((hang(tip), a))
    paged(p, n0)
    return s


def tripod(p, o, h=10.0):
    n0 = len(p.faces)
    o = np.asarray(o, float)
    bx(p, o + [0, 0, h / 2], (14.0, 14.0, h))
    plate(p, o + [7.04, 0, h - 4.5], X, 10.0, 1.4, "WC-9 ARGUS")
    for a in (90, 210, 330):
        d = rot_z(a) @ np.array(X)
        foot = o + d * 26 + [0, 0, 0.6]
        p.prism(o + d * 5 + [0, 0, h * 0.6], foot, Z, 1.0, 8, "steel", None, None)
        p.prism(foot - [0, 0, 0.6], foot + [0, 0, 0.6], X, 2.0, 8, "band", "band", "band")
    paged(p, n0)


def carousel(p, cells, o, tiers):
    o = np.asarray(o, float)
    tripod(p, o)
    s = []
    for j in range(tiers):
        s += carousel_tier(p, cells, o + [0, 0, 10 + j * TT], ANG6)
    top = o + [0, 0, 10 + tiers * TT]
    p.prism(top, top + [0, 0, 2.0], X, 1.6, 10, "duct", None, "duct")
    p.prism(top + [0, 0, 2.0], top + [0, 0, 3.6], X, 1.2, 10, "light", None, "light")
    return s


def kc_one(p, c):
    return carousel(p, c, (0, 0, 0), 1), ((0, 0, 22), 108, 30, 18)


def kc_scale(p, c):
    s = []
    for y, n in ((-75, 1), (0, 2), (75, 3)):
        s += carousel(p, c, (0, y, 0), n)
    return s, ((0, 0, 40), 320, 20, 10)


def kc_free(p, c):
    return carousel(p, c, (0, 0, 0), 2), ((0, 0, 34), 150, 30, 12)


def kc_wall(p, c):
    bx(p, (0.5, 0, 52), (1.0, 50, 2 * TT + 16))
    s = []
    for j in range(2):
        o = np.array([1.0, 0, 30 + j * TT])
        cell_bank(p, c, o + [3.4, 0, 8.0], X, 2, 1)
        s += carousel_tier(p, c, o, [-60.0, 0.0, 60.0], core=False)
    p.prism((1.2, 22, 10), (1.2, 22, 100), X, 0.9, 10, "duct", None, None)
    return s, ((12, 0, 46), 165, 38, 10)


def kc_van(p, c, V):
    cx, cy, roof = V
    s = []
    for dx in (-60, 60):
        o = np.array([cx + dx, cy, roof])
        bx(p, o + [0, 0, 1.2], (30.0, 30.0, 2.4), "duct")
        s += carousel_tier(p, c, o + [0, 0, 2.4], ANG6)
        p.prism(o + [0, 0, 2.4 + TT], o + [0, 0, 4.0 + TT], X, 1.2, 10, "light", None, "light")
    return s, van_cam(V)


# ---- KP-7: pads -----------------------------------------------------------------------------------------------------
PX, PY, PT = 24.0, 22.0, 2.6


def pad(p, cells, o):
    """A landing tile: a kit sitting on its cradle inside corner marks, a bio cell set face-up behind it."""
    o = np.asarray(o, float)
    flykit.chamfer_box(p, tuple(o + [-PX / 2, -PY / 2, 0]), tuple(o + [PX / 2, PY / 2, PT]), 0.6, "hull", "panel")
    cell_bank(p, cells, o + [-6.4, 0, PT + 0.6], Z, 1, 1, up=X, depth=1.2)
    for sx in (1, -1):
        for sy in (1, -1):
            c = o + [4.5 + sx * 6.0, sy * 9.0, PT + 0.03]
            bx(p, c + [0, -sy * 1.0, 0], (0.5, 2.5, 0.06), "rim")
            bx(p, c + [-sx * 1.0, 0, 0], (2.5, 0.5, 0.06), "rim")
    p.prism(o + [4.5, 0, PT], o + [4.5, 0, PT + 1.0], X, 2.2, 10, "duct", None, "duct")
    for a in (0, 120, 240):
        d = rot_z(a) @ np.array(X)
        p.box(o + [4.5, 0, PT + 1.2] + d * 2.5, d, np.cross(Z, d), Z, (0.6, 1.0, 1.6), ("steel", "steel"))
    for s in (1, -1):
        bx(p, o + [0, s * (PY / 2 + 0.02), PT / 2], (5.0, 0.06, 1.4), "pad")
    bx(p, o + [PX / 2 + 0.03, 7.0, PT / 2], (0.06, 2.0, 0.6), "light")
    plate(p, o + [PX / 2 + 0.04, -4.0, PT / 2], X, 9.0, 1.1, "LP-1 PERCH")
    return [(sit(o + [4.5, 0, PT + 1.0]), 0.0)]


def pads(p, cells, o, nx, ny):
    s, o = [], np.asarray(o, float)
    for i in range(nx):
        for j in range(ny):
            s += pad(p, cells, o + [((nx - 1) / 2 - i) * PX, (j - (ny - 1) / 2) * PY, 0])
    return s


def pad_tower(p, cells, o, tiers=3, wide=3):
    """Decks of tiles stepping up and back like bleachers, so every kit has open sky above it."""
    s, o = [], np.asarray(o, float)
    for k in range(tiers):
        z, x = 4.0 + 16.0 * k, -PX * k
        bx(p, o + [x, 0, z - 0.8], (PX, wide * PY + 2, 1.6), "duct")
        for sx in (1, -1):
            for sy in (1, -1):
                bx(p, o + [x + sx * (PX / 2 - 1), sy * (wide * PY / 2), (z - 1.6) / 2], (1.6, 1.6, z - 1.6))
        s += pads(p, cells, o + [x, 0, z], 1, wide)
    top = o + [-PX * (tiers - 1), wide * PY / 2 + 2, 0]
    p.prism(top, top + [0, 0, 4.0 + 16.0 * tiers + 12], X, 0.9, 10, "duct", None, None)
    p.prism(top + [0, 0, 4.0 + 16.0 * tiers + 12], top + [0, 0, 4.0 + 16.0 * tiers + 14], X, 1.2, 10, "light", None, "light")
    return s


def kp_one(p, c):
    return pad(p, c, (0, 0, 0)), ((2, 0, 4), 60, 35, 30)


def kp_scale(p, c):
    s, y = [], -73.0
    for nx, ny in ((1, 1), (1, 2), (3, 3)):
        s += pads(p, c, (0, y + ny * PY / 2, 0), nx, ny)
        y += ny * PY + 14
    return s, ((0, 14, 4), 265, 25, 30)


def kp_free(p, c):
    return pad_tower(p, c, (0, 0, 0)), ((-24, 0, 20), 190, 30, 20)


def kp_wall(p, c):
    s = []
    for y, z in ((-36, 14), (-12, 28), (12, 42), (36, 56)):
        o = np.array([0.6 + PX / 2, y, z])
        s += pad(p, c, o)
        for sy in (1, -1):
            knee(p, y + sy * (PY / 2 - 1.5), z, PX + 0.6)
    p.prism((1.2, -48, 8), (1.2, -48, 90), X, 0.9, 10, "duct", None, None)
    return s, ((14, 0, 40), 185, 36, 12)


def kp_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 5 * PX + 6, 2 * PY + 6)
    return pads(p, c, (cx, cy, roof + 2.6), 5, 2), van_cam(V)


# ---- KF-7: field case -------------------------------------------------------------------------------------------------
CX, CY, CB, CL = 20.0, 38.0, 8.0, 4.0                  # depth, width, its base's height, its lid's


def case(p, cells, o, open_=True, lid_deg=-100.0, strap=False):
    """A hard case for two kits in foam; three bio cells strapped inside its lid; latches, handles, bumpers."""
    o = np.asarray(o, float)
    flykit.chamfer_box(p, tuple(o + [-CX / 2, -CY / 2, 0]), tuple(o + [CX / 2, CY / 2, CB]), 0.8, "hull", "panel")
    bx(p, o + [0, 0, CB - 0.3], (CX - 2.4, CY - 2.4, 0.7), "band")
    for s in (1, -1):
        bx(p, o + [0, s * (CY / 2 + 1.0), CB * 0.65], (7.0, 0.7, 0.8), "duct")
        for dx in (-3.2, 3.2):
            bx(p, o + [dx, s * (CY / 2 + 0.5), CB * 0.65], (0.8, 1.2, 0.8), "duct")
        bx(p, o + [CX / 2 + 0.25, s * 11.0, CB - 1.0], (0.5, 2.6, 2.2), "rim")
        bx(p, o + [0, s * (CY / 2 + 0.02), CB * 0.3], (4.0, 0.06, 1.6), "pad")
        for sx in (1, -1):
            bx(p, o + [sx * (CX / 2 - 0.7), s * (CY / 2 - 0.7), CB / 2], (1.8, 1.8, CB + 0.2), "band")
    bx(p, o + [CX / 2 + 0.06, -15.0, CB * 0.4], (0.1, 1.2, 0.6), "light")
    plate(p, o + [CX / 2 + 0.05, 0, CB * 0.45], X, 12.0, 1.8, "FC-5 VALISE")
    lid, lc = Part("lid"), []
    flykit.chamfer_box(lid, tuple(o + [-CX / 2, -CY / 2, CB]), tuple(o + [CX / 2, CY / 2, CB + CL]), 0.8, "hull", "panel")
    for s in (1, -1):
        for sx in (1, -1):
            bx(lid, o + [sx * (CX / 2 - 0.7), s * (CY / 2 - 0.7), CB + CL / 2], (1.8, 1.8, CL + 0.2), "band")
    cell_bank(lid, lc, o + [0, 0, CB], -np.array(Z), 3, 1, up=X, depth=1.0)
    bx(lid, o + [3.8, 0, CB - 2.05], (1.0, 3 * CP + 2, 0.15), "band")
    if not open_:
        p.faces += lid.faces
        if strap:
            for dy in (-8.0, 8.0):
                bx(p, o + [0, dy, CB + CL + 0.1], (CX + 0.6, 2.0, 0.2), "band")
        return []
    hinge = o + [-CX / 2, 0, CB]
    R = rot(Y, lid_deg)
    t = hinge - R @ hinge
    p.faces += moved(lid, R, t).faces
    cells += [(R @ Rc, R @ np.asarray(tc) + t) for Rc, tc in lc]
    return [(sit(o + [0, s * 9.2, CB - 3.0]), 0.0) for s in (1, -1)]


def case_legs(p, o, h):
    """Fold-out legs: the case's base h above o."""
    o = np.asarray(o, float)
    for sy in (1, -1):
        mids = []
        for sx in (1, -1):
            top = o + [sx * (CX / 2 - 2.0), sy * (CY / 2 - 2.5), h + 0.4]
            foot = o + [sx * (CX / 2 + 2.5), sy * (CY / 2 + 1.0), 0.6]
            p.prism(top, foot, X, 0.7, 8, "steel", None, None)
            bx(p, top, (1.6, 1.6, 1.2), "duct")
            bx(p, foot - [0, 0, 0.3], (2.4, 2.4, 0.6), "band")
            mids.append(foot + 0.45 * (top - foot))
        p.prism(mids[0], mids[1], Z, 0.4, 6, "steel", None, None)


def kf_one(p, c):
    return case(p, c, (0, 0, 0)), ((0, 0, 10), 102, 28, 22)


def kf_scale(p, c):
    s = case(p, c, (0, -90, 0))
    for dy in (-19.2, 19.2):
        s += case(p, c, (0, -32 + dy, 0))
    for j in range(3):
        for dy in (-19.2, 19.2):
            s += case(p, c, (0, 58 + dy, j * (CB + CL + 0.4)), open_=j == 2)
    return s, ((0, 12, 14), 335, 22, 20)


def kf_free(p, c):
    s, h = [], 20.0
    for y in (-40.0, 0.0, 40.0):
        case_legs(p, (0, y, 0), h)
        s += case(p, c, (0, y, h))
    return s, ((0, 0, 26), 185, 30, 18)


def kf_wall(p, c):
    s = []
    for y, z in ((-42, 20), (0, 38), (42, 56)):
        s += case(p, c, (0.6 + CX / 2, y, z), lid_deg=-85.0)
        for sy in (1, -1):
            knee(p, y + sy * (CY / 2 - 4), z, CX + 0.6)
    p.prism((1.2, -64, 8), (1.2, -64, 96), X, 0.9, 10, "duct", None, None)
    return s, ((14, 0, 44), 205, 36, 12)


def kf_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 4 * (CX + 2) + 6, 2 * (CY + 1) + 6)
    s = []
    for i in range(4):
        for j in range(2):
            o = (cx + (i - 1.5) * (CX + 2), cy + (j - 0.5) * (CY + 1), roof + 2.6)
            s += case(p, c, o, open_=(i, j) in ((1, 1), (2, 0)), strap=True)
    return s, van_cam(V)


# ---- the designs, their views, the sheets ------------------------------------------------------------------------------
VIEWS = ("one", "scale", "free", "wall", "van", "launch")
DESIGNS = [  # tag, name, line, its place in the line-up, its views
    ("LP-1", "Perch", "the cheapest: single landing tiles, a kit and a cell each, dotted on rooftops, ledges and alleys by low-budget outfits",
     "cheap scattered pickets",
     dict(one=kp_one, scale=kp_scale, free=kp_free, wall=kp_wall, van=kp_van, launch=(7, (0, 0, 32), ((-24, 0, 32), 205, 30, 16)),
          caps=("one tile: a kit on its cradle, a cell behind it", "scalable: one, two, three by three",
                "free-standing: decks stepping up and back, open sky above each", "wall-mounted: ledges climbing the wall",
                "vehicle-mounted: two by five tiles on the roof", "launching: straight up off its tile"))),
    ("MR-3", "Trellis", "cheap and modular: the open rack, kits level on gimbal arms; the most kits for the money, a mass swarm from secure bases",
     "a mass swarm, secure bases",
     dict(one=kr_one, scale=kr_scale, free=kr_free, wall=kr_wall, van=kr_van, launch=kr_launch,
          caps=("one box and its cell pack: a kit level in its gimbal arm", "scalable: the cell bank grows with the rack",
                "free-standing: three by two on feet", "wall-mounted: four and a cell pack, on the rail",
                "vehicle-mounted: two rows of four, back to back", "launching: let go, straight out of the front"))),
    ("SL-4", "Warden", "physically secure, tamper resistant: hardened lockers for corridors and security desks; the console is the way in",
     "indoors, tamper resistant",
     dict(one=kl_one, scale=kl_scale, free=kl_free, wall=kl_wall, van=kl_van, launch=(0, (24, 0, -3), ((10, 0, 34), 195, 28, 12)),
          caps=("one locker, open: a kit on its claw; a cell and a console", "scalable: one, two, three by two (a cell each)",
                "free-standing: four by two on a plinth, two open", "wall-mounted: three by two, rail above, braces below",
                "vehicle-mounted: two rows of three, back to back", "launching: out from under the shutter"))),
    ("VC-6", "Quiver", "hardened against weather and attack: bases that expect a fight, ships, subs; three stacked make one tube, out of its top",
     "hardened: weather and attack",
     dict(one=kv_one, scale=kv_scale, free=kv_free, wall=kv_wall, van=kv_van, launch=kv_launch,
          caps=("one box, its cap open: the kit going up out of the top", "scalable: boxes stack into one tube, a cap on top",
                "free-standing: three tubes three high, one launching", "wall-mounted, the hive format: on their sides, out of the front",
                "on the riot van: two rows of three, capped", "cutaway: three kits level in one tube; top one first, the next after it"))),
    ("FC-5", "Valise", "the man-portable launcher: carried by squads and elite troops (lootable), or a player's own portable nest",
     "man-portable: squads, players",
     dict(one=kf_one, scale=kf_scale, free=kf_free, wall=kf_wall, van=kf_van, launch=(2, (0, 0, 30), ((0, 0, 30), 195, 30, 16)),
          caps=("one case, open: two kits in foam, cells in the lid", "scalable: one, two latched, a stack of six",
                "free-standing: three on their fold-out legs", "wall-mounted: cases on braced brackets, lids up",
                "vehicle-mounted: eight strapped on the roof, two open", "launching: straight up out of its case"))),
    ("WC-9", "Argus", "the dearest, crown-jewel sites only: six kits a tier, every camera always on; it sees you and launches the same second",
     "crown jewels, always watching",
     dict(one=kc_one, scale=kc_scale, free=kc_free, wall=kc_wall, van=kc_van, launch=(11, (28, 0, 4), ((10, 0, 36), 170, 30, 12)),
          caps=("one tier on its tripod: six kits watching, four cells in the core", "scalable: one, two, three tiers",
                "free-standing: two tiers, a beacon on top", "wall-mounted: half tiers on a wall plate, cells between",
                "vehicle-mounted: two tiers on the roof, kits all round", "launching: the one that saw you, gone"))),
]


def frames_of():
    """Each design's first frame number and its views."""
    n, out = 0, []
    for d in DESIGNS:
        views = d[4].get("views", VIEWS)
        out.append((n, views))
        n += len(views)
    return out


def build(out):
    global LO, HI, TAILP
    os.makedirs(out, exist_ok=True)
    st, LO, HI = kit_obj(out)
    P = np.array([q for pts, r in st["p"].faces for q in pts if r != "blur"])
    x0 = P[:, 0].min()
    TAILP = np.array([x0, 0.0, P[P[:, 0] < x0 + 0.6][:, 2].mean()])
    flykit.PACKAGES["DeusExDeco"] = os.path.join(flykit.REV, "System", "DeusExDeco.u")
    van = game_obj("DeusExDeco", "Van", 1.0, np.eye(3), (0, 0, 0), out, "van")
    vlo, vhi = obj_bounds(van)
    van = game_obj("DeusExDeco", "Van", 1.0, np.eye(3), (0, 0, -vlo[2]), out, "van")
    vlo, vhi = obj_bounds(van)
    V = ((vlo[0] + vhi[0]) / 2, (vlo[1] + vhi[1]) / 2, vhi[2])
    wall, floor_ = Part("wall"), Part("floor")
    bx(wall, (-0.3, 0, 40), (0.6, 260, 120), "wall")
    bx(floor_, (0, 0, -0.6), (400, 400, 0.4), "wall")
    wp, fp = write_obj(wall, os.path.join(out, "wall.obj")), write_obj(floor_, os.path.join(out, "floor.obj"))
    frames, states = [], []
    for tag, name, line, role, fn in DESIGNS:
        t = tag.replace("-", "").lower()
        for view in fn.get("views", VIEWS):
            p, cells = Part(t + view), []
            f = fn[view]
            if view == "van":
                slots, cam = f(p, cells, V)
                scene = [fp, van]
            elif callable(f):
                slots, cam = f(p, cells)
                scene = [wp, fp] if view == "wall" else [fp]
            else:                                       # (a launch: the free-standing view, one kit gone off)
                slots, _ = fn["free"](p, cells)
                k, off, cam = f
                o, y = slots[k][:2]
                slots[k] = (np.asarray(o) + rot_z(y) @ np.asarray(off, float), y) + tuple(slots[k][2:])
                scene = [fp]
            nm = "%s_%s" % (t, view)
            objs = scene + ([write_tex(p, os.path.join(out, nm + ".obj"), out)] if p.faces else [])
            if cells:
                objs.append(cells_obj(cells, out, nm))
            objs += [place(st, out, "%s_k%d" % (nm, k), o, yaw=y) for k, (o, y) in enumerate(slots)]
            look, dist, az, el = cam
            frames.append(objs)
            states.append(dict(eye=eye(look, dist, az, el), look=look, lens=50))
            print("%s %s: %d kits, %d cells" % (tag, view, len(slots), len(cells)))
    json.dump(dict(frames=frames, states=states, studio=flykit.STUDIO), open(os.path.join(out, "spec.json"), "w"))
    print("spec:", len(frames), "renders ->", os.path.join(out, "spec.json"))


def sheet(out):
    from PIL import Image, ImageDraw, ImageFont
    rd = os.path.join(out, "render")
    font = lambda s: ImageFont.truetype(os.path.join(os.environ.get("WINDIR", r"C:\Windows"), "Fonts", "segoeuib.ttf"), s)
    tw, th = 640, 480
    starts = frames_of()
    for (tag, name, line, role, fn), (n0, views) in zip(DESIGNS, starts):
        rows = (len(views) + 1) // 2
        S = Image.new("RGB", (2 * tw, 112 + rows * th), (24, 26, 30))
        d = ImageDraw.Draw(S)
        d.text((24, 12), "Kit nest: %s %s" % (tag, name) if tag != "FK-7" else "FK-7: the launch pose", fill=(240, 200, 120), font=font(38))
        d.text((24, 70), line, fill=(200, 200, 205), font=font(20 if len(line) < 110 else 17))
        for i, cap in enumerate(fn["caps"]):
            im = Image.open(os.path.join(rd, "r%04d.png" % (n0 + i))).convert("RGB").resize((tw, th), Image.LANCZOS)
            x, y = (i % 2) * tw, 112 + (i // 2) * th
            S.paste(im, (x, y))
            d.rectangle((x, y + th - 36, x + tw, y + th), fill=(24, 26, 30))
            d.text((x + 12, y + th - 30), cap, fill=(255, 255, 255), font=font(17))
        path = os.path.join(out, "riff_%s.png" % tag.replace("-", "").lower())
        S.save(path)
        print(path)
    nests = [(d, s) for d, s in zip(DESIGNS, starts) if d[0] != "FK-7"]
    O = Image.new("RGB", (3 * tw, 80 + 2 * (th + 44)), (24, 26, 30))
    d = ImageDraw.Draw(O)
    d.text((24, 16), "Corvane kit nests, cheapest first, all on the game's bio cells", fill=(240, 200, 120), font=font(38))
    for k, ((tag, name, line, role, fn), (n0, views)) in enumerate(nests):
        im = Image.open(os.path.join(rd, "r%04d.png" % (n0 + views.index("free")))).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = (k % 3) * tw, 80 + (k // 3) * (th + 44)
        d.text((x + 12, y + 6), "%s %s: %s" % (tag, name, role), fill=(240, 200, 120), font=font(24))
        O.paste(im, (x, y + 44))
    path = os.path.join(out, "riff_overview.png")
    O.save(path)
    print(path)


if __name__ == "__main__":
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "mech", "riffs")
    {"build": build, "sheet": sheet}[sys.argv[1]](out)
