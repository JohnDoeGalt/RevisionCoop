"""Kit nest riffs on the KR-7 modular rack (tools/nest_concept.py mod). The user, 2026-11-03: "This is pretty much
perfect... I like the attached power supply... Maybe throw in the bio battery cells... that's the implied battery source...
so even its power supply is scalable... riff off of this design, do some weird stuff... 5 separate designs with the same...
6 images of the same design in different uses"; then "use the BioCells models, like, verbatim".

Power in every design is the game's own bioelectric cell (DeusExItems BioCell, its own skin, unchanged), banked face-out
so its gauge shows: more kits, more cells. Six designs, six views each (one module; scaling; free-standing; on a wall; on
the game's own van; launching):

  KR-7  the modular rack, its power module now a bank of bio cells, as tall as the rack
  KL-7  lockers: the rack's module boxed in armour, a roll-up shutter, two cells in its sill
  KC-7  carousel: tiers of six kits hanging round a core faced with cells, stacked on a tripod
  KV-7  vertical cells: kits upright in tubes that launch straight up, a cell set in each lid
  KP-7  pads: landing tiles that join edge to edge, a kit sitting on each, two cells in each tile
  KF-7  field case: a hard case for two kits, cells strapped in its lid, fold-out legs

  python -I tools/nest_riffs.py build [outdir]      (default build/mech/riffs)
  blender -b --factory-startup --python tools/flykit_render.py -- <outdir>/spec.json <outdir>/render   (absolute paths)
  python -I tools/nest_riffs.py sheet [outdir]      (a sheet per design, and an overview)

Frame: x forward, y left, z up; game units (about 1.9 cm).
"""
import json, math, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit
from mech_parts import Part
from sensor_concept import eye, game_obj, moved, write_obj
from nest_concept import (BW, DP, TH, arm, claw, hazard_strip, kit_obj, kr_feet, kr_grid, kr_vehicle_frame,
                          kr_wall_mount, obj_bounds, place, rot_z)

X, Y, Z = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)
CP = 9.6                                                # cells' pitch in a bank (a cell is 8.7 square, 1.9 thick)
LO = HI = 0.0                                           # the kit's lowest and highest points (set by build)


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
    slots += [(R @ np.asarray(o) + t, y + deg) for o, y in qs]


def knee(p, y, z, reach):
    """A knee brace at y under a shelf whose underside is at z, reaching out from the wall (x = 0)."""
    bx(p, (0.3, y, z - 7.0), (0.6, 3.0, 15.0), "duct")
    bx(p, (reach / 2, y, z - 0.6), (reach, 1.4, 1.2))
    p.prism((0.6, y, z - 13.0), (reach - 2.0, y, z - 1.2), Y, 0.6, 8, "steel", None, None)


def van_cam(V):
    cx, cy, roof = V
    return (cx, cy, roof * 0.65), 500, 62, 24


# ---- KR-7: the modular rack, cell powered --------------------------------------------------------------------------
def kr_cells(p, cells, o, nz):
    """The power module, a module's footprint, nz tiers tall: bio cells face-out two across, as many high as it stands."""
    o = np.asarray(o, float)
    h = nz * (TH + 0.5) - 0.5
    flykit.chamfer_box(p, tuple(o + [-DP / 2, -BW / 2, 0]), tuple(o + [DP / 2, BW / 2, h]), 0.5, "hull", "panel")
    rows = max(1, int((h - 5.0) // CP))
    cell_bank(p, cells, o + [DP / 2 + 1.0, 0, 2.0 + (rows * CP + 1.4) / 2], X, 2, rows)
    hazard_strip(p, o + [DP / 2 + 0.05, 0, h - 1.6], Y, Z, X, (BW - 3, 1.2, 0.08))
    p.prism(o + [0, 0, h], o + [0, 0, h + 1.6], X, 1.0, 10, "light", None, "light")
    p.prism(o + [-DP / 2 + 2, BW / 2 - 3, h], o + [-DP / 2 + 2, BW / 2 - 3, h + 24], X, 0.9, 10, "duct", None, None)


def kr_rack(p, cells, y0, nx, nz, feet=True, z0=0.0):
    W = (nx + 1) * BW
    zb = z0
    if feet:
        kr_feet(p, (0, y0 + W / 2, z0), W)
        zb += 2.4
    tips = kr_grid(p, (0, y0 + nx * BW / 2, zb), nx, nz)
    kr_cells(p, cells, (0, y0 + nx * BW + BW / 2, zb), nz)
    return [(hang(t), 0.0) for t in tips]


def kr_one(p, c):
    return kr_rack(p, c, -BW, 1, 1, feet=False), ((0, 0, 9), 66, 30, 16)


def kr_scale(p, c):
    s, y = [], -105.0
    for nx, nz in ((1, 1), (2, 1), (3, 2)):
        s += kr_rack(p, c, y, nx, nz)
        y += (nx + 1) * BW + 10
    return s, ((0, 14, 18), 345, 22, 12)


def kr_free(p, c):
    return kr_rack(p, c, -2 * BW, 3, 2), ((0, 0, 18), 125, 30, 14)


def kr_wall(p, c):
    back, bottom = 2.4, 28.0
    tips = kr_grid(p, (back + DP / 2, -BW / 2, bottom), 4, 1)
    kr_cells(p, c, (back + DP / 2, 2 * BW, bottom), 1)
    kr_wall_mount(p, 5, bottom + TH, bottom, back)
    return [(hang(t), 0.0) for t in tips], ((10, 0, 32), 150, 36, 10)


def kr_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 5 * BW + 6, 2 * DP + 6)
    s = []

    def row(q, qc):
        tips = kr_grid(q, (0, -BW / 2, roof + 2.6), 4, 1)
        kr_cells(q, qc, (0, 2 * BW, roof + 2.6), 1)
        return [(hang(t), 0.0) for t in tips]
    for k in (1, -1):
        turned_in(p, c, s, row, 90 * k, (cx, cy + k * (DP / 2 + 0.3), 0))
    return s, van_cam(V)


# ---- KL-7: lockers --------------------------------------------------------------------------------------------------
LW, LD, LH, SILL = 22.0, 16.0, 33.0, 12.0


def locker(p, cells, o, open_=False):
    """The rack's module boxed in armour: a roll-up shutter over its front, two bio cells in its sill."""
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
    cell_bank(p, cells, o + [LD / 2 + 1.0, 0, SILL / 2], X, 2, 1)
    hazard_strip(p, o + [LD / 2 + 0.05, 0, LH - 1.6], Y, Z, X, (LW - 4, 1.2, 0.08))
    bx(p, o + [LD / 2 + 0.05, LW / 2 - 1.6, SILL + 1.2], (0.1, 1.0, 0.6), "light")
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
    hazard_strip(p, (depth / 2 + 2.05, y, 1.0), Y, Z, X, (width - 2, 1.0, 0.08))


def kl_one(p, c):
    return locker(p, c, (0, 0, 0), True), ((0, 0, 16), 74, 30, 14)


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
    hazard_strip(p, (2.45, 0, top + 2.4), Y, Z, X, (3 * LW + 2, 1.2, 0.08))
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


def carousel_tier(p, cells, o, angles, core=True):
    """Kits hanging on arms round a hub, facing out; the core under the hub faced with bio cells on all four sides."""
    o = np.asarray(o, float)
    if core:
        bx(p, o + [0, 0, TT / 2], (12.0, 12.0, TT))
        for a in (0, 90, 180, 270):
            n = rot_z(a) @ np.array(X)
            cell_bank(p, cells, o + n * 7.0 + [0, 0, 8.0], n, 1, 1)
        p.prism(o, o + [0, 0, 1.6], X, 8.5, 8, "duct", "duct", "duct")
        p.prism(o + [0, 0, TT - 2.6], o + [0, 0, TT - 0.6], X, 9.0, 6, "duct", "duct", "duct")
        hazard_strip(p, o + [0, 0, TT - 0.55], X, Y, Z, (10.0, 1.4, 0.08))
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
    return s


def tripod(p, o, h=10.0):
    o = np.asarray(o, float)
    bx(p, o + [0, 0, h / 2], (14.0, 14.0, h))
    hazard_strip(p, o + [7.05, 0, h - 2], Y, Z, X, (12.0, 1.2, 0.08))
    for a in (90, 210, 330):
        d = rot_z(a) @ np.array(X)
        foot = o + d * 26 + [0, 0, 0.6]
        p.prism(o + d * 5 + [0, 0, h * 0.6], foot, Z, 1.0, 8, "steel", None, None)
        p.prism(foot - [0, 0, 0.6], foot + [0, 0, 0.6], X, 2.0, 8, "band", "band", "band")


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


# ---- KV-7: vertical cells -------------------------------------------------------------------------------------------
TW, VH = 21.0, 16.0


def vtube(p, cells, o, open_=False, lid_deg=-105.0):
    """A square tube, a kit sitting upright inside on a cradle; its lid hinged at the back, a bio cell set in the lid."""
    o = np.asarray(o, float)
    for s in (1, -1):
        bx(p, o + [0, s * (TW / 2 - 0.5), VH / 2], (TW, 1.0, VH))
        bx(p, o + [s * (TW / 2 - 0.5), 0, VH / 2], (1.0, TW - 2.0, VH))
        bx(p, o + [0, s * (TW / 2 + 0.02), VH * 0.5], (4.0, 0.06, 2.4), "pad")
        for sx in (1, -1):
            bx(p, o + [sx * (TW / 2 - 0.6), s * (TW / 2 - 0.6), VH / 2], (1.3, 1.3, VH + 0.1), "duct")
    bx(p, o + [0, 0, 1.0], (TW - 2, TW - 2, 2.0), "duct")
    lift = VH - 3.0 if open_ else 3.0                   # (its lid open, the kit lifted to the rim, ready to go)
    p.prism(o + [0, 0, 2.0], o + [0, 0, lift - 1.0], X, 1.0, 8, "steel", None, None)
    p.prism(o + [0, 0, lift - 1.0], o + [0, 0, lift], X, 2.4, 10, "duct", "duct", "duct")
    hazard_strip(p, o + [TW / 2 + 0.05, 0, VH - 1.5], Y, Z, X, (TW - 4, 1.0, 0.08))
    bx(p, o + [TW / 2 + 0.05, TW / 2 - 2.0, 2.0], (0.1, 1.0, 0.6), "light")
    lid, lc = Part("lid"), []
    bx(lid, o + [0, 0, VH + 0.6], (TW, TW, 1.2), ("panel", "hull"))
    cell_bank(lid, lc, o + [1.0, 0, VH + 2.4], Z, 1, 1, up=X, depth=1.2)
    bx(lid, o + [TW / 2 - 1.2, 0, VH + 1.5], (1.0, 6.0, 0.6), "rim")
    if not open_:
        p.faces += lid.faces
        cells += lc
        return []
    hinge = o + [-TW / 2, 0, VH + 0.6]
    R = rot(Y, lid_deg)
    t = hinge - R @ hinge
    p.faces += moved(lid, R, t).faces
    cells += [(R @ Rc, R @ np.asarray(tc) + t) for Rc, tc in lc]
    return [(sit(o + [0, 0, lift]), 0.0)]


def vblock(p, cells, o, nx, ny, opened=(), lid_deg=-105.0):
    s, o = [], np.asarray(o, float)
    for i in range(nx):
        for j in range(ny):
            s += vtube(p, cells, o + [((nx - 1) / 2 - i) * TW, (j - (ny - 1) / 2) * TW, 0], i * ny + j in opened, lid_deg)
    return s


def kv_one(p, c):
    return vtube(p, c, (0, 0, 0), True), ((0, 0, 12), 88, 30, 28)


def kv_scale(p, c):
    s, y = [], -77.0
    for nx, ny, op in ((1, 1, (0,)), (1, 2, (1,)), (3, 3, (0, 4, 8))):
        s += vblock(p, c, (0, y + ny * TW / 2, 0), nx, ny, op)
        y += ny * TW + 14
    return s, ((0, 0, 10), 260, 22, 28)


def kv_free(p, c):
    for x in (-TW / 2, TW / 2):
        bx(p, (x, 0, 1.0), (3.0, 3 * TW + 6, 2.0), "duct")
        for y in (-1.5 * TW - 3, 1.5 * TW + 3):
            hazard_strip(p, (x, y, 2.05), X, Y, Z, (2.8, 1.0, 0.08))
    s = vblock(p, c, (0, 0, 2.0), 2, 3, (1, 3))
    return s, ((0, 0, 12), 140, 30, 26)


def kv_wall(p, c):
    z = 40.0
    bx(p, (TW / 2 + 0.6, 0, z - 1.0), (TW + 1.2, 4 * TW + 2, 2.0))
    bx(p, (0.5, 0, z + VH / 2), (1.0, 4 * TW + 4, VH + 6))
    hazard_strip(p, (TW + 1.25, 0, z - 1.0), Y, Z, X, (4 * TW, 1.2, 0.08))
    for y in (-2 * TW + 1, -TW, 0, TW, 2 * TW - 1):
        knee(p, y, z - 2.0, TW + 1.2)
    s = vblock(p, c, (TW / 2 + 0.6, 0, z), 1, 4, (1, 2), lid_deg=-88.0)
    return s, ((12, 0, 40), 175, 34, 16)


def kv_van(p, c, V):
    cx, cy, roof = V
    kr_vehicle_frame(p, (cx, cy, roof), 5 * TW + 6, 2 * TW + 6)
    s = []
    for i in range(5):
        for j in range(2):
            s += vtube(p, c, (cx + (i - 2) * TW, cy + (j - 0.5) * TW, roof + 2.6), (i + j) % 2 == 0)
    return s, van_cam(V)


# ---- KP-7: pads -----------------------------------------------------------------------------------------------------
PX, PY, PT = 24.0, 22.0, 2.6


def pad(p, cells, o):
    """A landing tile: a kit sitting on its cradle inside corner marks, two bio cells set face-up behind it."""
    o = np.asarray(o, float)
    flykit.chamfer_box(p, tuple(o + [-PX / 2, -PY / 2, 0]), tuple(o + [PX / 2, PY / 2, PT]), 0.6, "hull", "panel")
    cell_bank(p, cells, o + [-6.4, 0, PT + 0.6], Z, 2, 1, up=X, depth=1.2)
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
        hazard_strip(p, o + [x + PX / 2 + 0.05, 0, z - 0.8], Y, Z, X, (wide * PY, 1.2, 0.08))
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
    lid, lc = Part("lid"), []
    flykit.chamfer_box(lid, tuple(o + [-CX / 2, -CY / 2, CB]), tuple(o + [CX / 2, CY / 2, CB + CL]), 0.8, "hull", "panel")
    for s in (1, -1):
        for sx in (1, -1):
            bx(lid, o + [sx * (CX / 2 - 0.7), s * (CY / 2 - 0.7), CB + CL / 2], (1.8, 1.8, CL + 0.2), "band")
    hazard_strip(lid, o + [CX / 2 + 0.05, 0, CB + CL / 2], Y, Z, X, (CY - 10, 1.0, 0.08))
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
DESIGNS = [
    ("KR-7", "modular rack", "the KR-7, its power module now a bank of the game's own bio cells that grows with the rack",
     dict(one=kr_one, scale=kr_scale, free=kr_free, wall=kr_wall, van=kr_van, launch=(1, (22, 0, -5), ((10, 0, 18), 130, 28, 12)),
          caps=("one module and its cell pack: two bio cells, face out", "scalable: the cell bank grows with the rack",
                "free-standing: three by two, six cells", "wall-mounted: four and a cell pack, on the rail",
                "vehicle-mounted: two rows of four, a cell pack each", "launching: one let go, flying out of the front"))),
    ("KL-7", "lockers", "the rack's module boxed in armour: a roll-up shutter, two bio cells in its sill, lockers that stack",
     dict(one=kl_one, scale=kl_scale, free=kl_free, wall=kl_wall, van=kl_van, launch=(0, (24, 0, -3), ((10, 0, 34), 170, 28, 12)),
          caps=("one locker, open: a kit on its claw, cells in the sill", "scalable: one, two, three by two (each its own cells)",
                "free-standing: four by two on a plinth, two open", "wall-mounted: three by two, rail above, braces below",
                "vehicle-mounted: two rows of three, back to back", "launching: out from under the shutter"))),
    ("KC-7", "carousel", "tiers of six kits hanging round a core faced with bio cells; tiers stack on a tripod",
     dict(one=kc_one, scale=kc_scale, free=kc_free, wall=kc_wall, van=kc_van, launch=(11, (28, 0, 4), ((10, 0, 36), 170, 30, 12)),
          caps=("one tier on its tripod: six kits, four cells in the core", "scalable: one, two, three tiers",
                "free-standing: two tiers, a beacon on top", "wall-mounted: half tiers on a wall plate, cells between",
                "vehicle-mounted: two tiers on the roof, kits all round", "launching: one let go, flying out"))),
    ("KV-7", "vertical cells", "kits upright in tubes, lids hinged back, a bio cell set in every lid; kits launch straight up",
     dict(one=kv_one, scale=kv_scale, free=kv_free, wall=kv_wall, van=kv_van, launch=(0, (0, 0, 30), ((0, 0, 22), 160, 30, 20)),
          caps=("one tube, its lid open, the kit lifted to the rim", "scalable: one, two, three by three",
                "free-standing: two by three on skids", "wall-mounted: four on a braced shelf",
                "vehicle-mounted: two by five, every other lid up", "launching: straight up out of its tube"))),
    ("KP-7", "pads", "landing tiles that join edge to edge, a kit sitting on each, two bio cells set face-up behind it",
     dict(one=kp_one, scale=kp_scale, free=kp_free, wall=kp_wall, van=kp_van, launch=(7, (0, 0, 32), ((-24, 0, 32), 205, 30, 16)),
          caps=("one tile: a kit on its cradle, two cells behind it", "scalable: one, two, three by three",
                "free-standing: decks stepping up and back, open sky above each", "wall-mounted: ledges climbing the wall",
                "vehicle-mounted: two by five tiles on the roof", "launching: straight up off its tile"))),
    ("KF-7", "field case", "a hard case for two kits in foam, three bio cells strapped in its lid, fold-out legs; cases latch and stack",
     dict(one=kf_one, scale=kf_scale, free=kf_free, wall=kf_wall, van=kf_van, launch=(2, (0, 0, 30), ((0, 0, 30), 195, 30, 16)),
          caps=("one case, open: two kits in foam, cells in the lid", "scalable: one, two latched, a stack of six",
                "free-standing: three on their fold-out legs", "wall-mounted: cases on braced brackets, lids up",
                "vehicle-mounted: eight strapped on the roof, two open", "launching: straight up out of its case"))),
]


def build(out):
    global LO, HI
    os.makedirs(out, exist_ok=True)
    st, LO, HI = kit_obj(out)
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
    for tag, name, line, fn in DESIGNS:
        t = tag.replace("-", "").lower()
        for view in VIEWS:
            p, cells = Part(t + view), []
            if view == "van":
                slots, cam = fn["van"](p, cells, V)
                scene = [fp, van]
            elif view == "launch":
                slots, _ = fn["free"](p, cells)
                k, off, cam = fn["launch"]
                o, y = slots[k]
                slots[k] = (np.asarray(o) + rot_z(y) @ np.asarray(off, float), y)
                scene = [fp]
            else:
                slots, cam = fn[view](p, cells)
                scene = [wp, fp] if view == "wall" else [fp]
            nm = "%s_%s" % (t, view)
            objs = scene + [write_obj(p, os.path.join(out, nm + ".obj"))]
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
    for n, (tag, name, line, fn) in enumerate(DESIGNS):
        S = Image.new("RGB", (2 * tw, 112 + 3 * th), (24, 26, 30))
        d = ImageDraw.Draw(S)
        d.text((24, 12), "Kit nest: %s %s" % (tag, name), fill=(240, 200, 120), font=font(38))
        d.text((24, 70), line, fill=(200, 200, 205), font=font(20))
        for i, cap in enumerate(fn["caps"]):
            im = Image.open(os.path.join(rd, "r%04d.png" % (n * 6 + i))).convert("RGB").resize((tw, th), Image.LANCZOS)
            x, y = (i % 2) * tw, 112 + (i // 2) * th
            S.paste(im, (x, y))
            d.rectangle((x, y + th - 36, x + tw, y + th), fill=(24, 26, 30))
            d.text((x + 12, y + th - 30), cap, fill=(255, 255, 255), font=font(17))
        path = os.path.join(out, "riff_%s.png" % tag.replace("-", "").lower())
        S.save(path)
        print(path)
    O = Image.new("RGB", (3 * tw, 80 + 2 * (th + 44)), (24, 26, 30))
    d = ImageDraw.Draw(O)
    d.text((24, 16), "Kit nests: the KR-7 and five riffs, all on the game's bio cells", fill=(240, 200, 120), font=font(38))
    for n, (tag, name, line, fn) in enumerate(DESIGNS):
        im = Image.open(os.path.join(rd, "r%04d.png" % (n * 6 + 2))).convert("RGB").resize((tw, th), Image.LANCZOS)
        x, y = (n % 3) * tw, 80 + (n // 3) * (th + 44)
        d.text((x + 12, y + 6), "%s  %s" % (tag, name), fill=(240, 200, 120), font=font(26))
        O.paste(im, (x, y + 44))
    path = os.path.join(out, "riff_overview.png")
    O.save(path)
    print(path)


if __name__ == "__main__":
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "mech", "riffs")
    {"build": build, "sheet": sheet}[sys.argv[1]](out)
