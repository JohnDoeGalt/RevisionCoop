"""The Barrett-line Mech's own parts (docs/MECH_CLASS.md, phase 3): geometry, anchors on the game
body, a bake of every frame, and the files the game's importer reads.

Each part is rigid and rides a frame made from three of the body's vertices (anchors): its
vertices are stored in that frame's local coordinates (bindings.json), so any PC can rebuild
the frames from its own copy of the body (tools/mech_art.py, the installer).

  python -I tools/mech_parts.py build [outdir]      (default build/mech/art)
"""
import json, math, os, struct, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art
import mech_bake
from mech_art import bake, frame_of, norm

REST = 32           # BreatheLight's first frame: standing, arms down
TEX = 256           # texture size (UVs are texel coordinates)

class Part:
    def __init__(self, name, mesh="BarrettParts"):
        self.name, self.mesh = name, mesh
        self.faces = []          # (corners: 3 or 4 points, material)
        self.cells = []          # each face's atlas cell (u0, v0, u1, v1), from layout_atlas
        self.verts, self.tris = [], []   # after finalize: tris (a, b, c, uv_a, uv_b, uv_c)

    def add_quad(self, a, b, c, d, region):
        """A quad a-b-c-d (outward normal by the right-hand rule) in material region."""
        self.faces.append(([np.array(x, float) for x in (a, b, c, d)], region))

    def add_tri(self, a, b, c, region):
        self.faces.append(([np.array(x, float) for x in (a, b, c)], region))

    def finalize(self):
        """Vertices and triangles with each face's own cell (s along a-b: u; t along a-d or a-c: -v)."""
        self.verts, self.tris = [], []
        for (pts, region), (u0, v0, u1, v1) in zip(self.faces, self.cells):
            i = len(self.verts)
            self.verts += pts
            if len(pts) == 4:
                uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
                self.tris.append((i, i + 1, i + 2, uv[0], uv[1], uv[2]))
                self.tris.append((i, i + 2, i + 3, uv[0], uv[2], uv[3]))
            else:
                self.tris.append((i, i + 1, i + 2, (u0, v1), (u1, v1), (u0, v0)))

    def facing(self, a, b, c, d, toward, region):
        """A quad turned so its normal points along toward."""
        if np.dot(np.cross(b - a, d - a), toward) < 0:
            a, b, c, d = a, d, c, b
        self.add_quad(a, b, c, d, region)

    def shell(self, O, I, region, inside):
        """A curved plate between two grids of points (rings x points round): O its outer face, I its
        inner one, edges closed."""
        J, K = len(O) - 1, len(O[0]) - 1
        for j in range(J):
            for k in range(K):
                self.facing(O[j][k], O[j][k + 1], O[j + 1][k + 1], O[j + 1][k], O[j][k] - I[j][k], region)
                self.facing(I[j][k], I[j][k + 1], I[j + 1][k + 1], I[j + 1][k], I[j][k] - O[j][k], inside)
        for j, j2 in ((0, 1), (J, J - 1)):
            for k in range(K):
                self.facing(O[j][k], O[j][k + 1], I[j][k + 1], I[j][k], O[j][k] - O[j2][k], region)
        for k, k2 in ((0, 1), (K, K - 1)):
            for j in range(J):
                self.facing(O[j][k], O[j + 1][k], I[j + 1][k], I[j][k], O[j][k] - O[j][k2], region)

    def box(self, centre, u, v, w, size, regions):
        """A box: axes u (length), v, w; size (lu, lv, lw); regions for (sides, ends)."""
        c = np.array(centre, float)
        hu, hv, hw = np.array(u) * size[0] / 2, np.array(v) * size[1] / 2, np.array(w) * size[2] / 2
        p = {(i, j, k): c + i * hu + j * hv + k * hw for i in (-1, 1) for j in (-1, 1) for k in (-1, 1)}
        side, end = regions
        # Faces with outward normals (u x v = w for a right-handed frame).
        self.add_quad(p[-1, -1, 1], p[1, -1, 1], p[1, 1, 1], p[-1, 1, 1], side)      # +w
        self.add_quad(p[-1, 1, -1], p[1, 1, -1], p[1, -1, -1], p[-1, -1, -1], side)  # -w
        self.add_quad(p[-1, 1, 1], p[1, 1, 1], p[1, 1, -1], p[-1, 1, -1], side)      # +v
        self.add_quad(p[-1, -1, -1], p[1, -1, -1], p[1, -1, 1], p[-1, -1, 1], side)  # -v
        self.add_quad(p[1, -1, -1], p[1, 1, -1], p[1, 1, 1], p[1, -1, 1], end)       # +u
        self.add_quad(p[-1, -1, 1], p[-1, 1, 1], p[-1, 1, -1], p[-1, -1, -1], end)   # -u

    def prism(self, start, end, v, radius, sides, region, cap_start, cap_end, radius_end=None):
        """A prism (or tapered prism) from start to end around the axis; v: the first side's direction."""
        a, b = np.array(start, float), np.array(end, float)
        u = norm(b - a)
        v = norm(np.array(v, float) - np.dot(v, u) * u)
        w = np.cross(u, v)
        r2 = radius if radius_end is None else radius_end
        ring = lambda c, r, k: c + r * (math.cos(2 * math.pi * k / sides) * v + math.sin(2 * math.pi * k / sides) * w)
        for k in range(sides):
            p0, p1 = ring(a, radius, k), ring(a, radius, k + 1)
            q0, q1 = ring(b, r2, k), ring(b, r2, k + 1)
            self.add_quad(p0, p1, q1, q0, region)
        if cap_start:
            for k in range(sides):
                self.add_tri(a, ring(a, radius, k + 1), ring(a, radius, k), cap_start)
        if cap_end:
            for k in range(sides):
                self.add_tri(b, ring(b, r2, k), ring(b, r2, k + 1), cap_end)


def blade(p, root, tip, ax, out):
    """A flat blade from root to tip (its flat facing out), a pointed end."""
    side = norm(np.cross(ax, out))
    for a0, a1, h0, h1 in ((root, tip - ax * 1.6, 0.55, 0.55), (tip - ax * 1.6, tip, 0.55, 0.0)):
        p.add_quad(a0 - side * h0 + out * 0.15, a1 - side * h1 + out * 0.15, a1 + side * h1 + out * 0.15, a0 + side * h0 + out * 0.15, "steel")
        p.add_quad(a0 + side * h0 - out * 0.15, a1 + side * h1 - out * 0.15, a1 - side * h1 - out * 0.15, a0 - side * h0 - out * 0.15, "steel")


def landmarks(F):
    """Body points in the rest frame (game units): elbows, wrists, shoulders, chin."""
    R = F[REST]
    segs = mech_art.segments(F, 0.35)
    rarm = [g for g in segs if 0 in g][0]     # the weapon triangle is in the right hand
    larm = [g for g in segs if 14 in g][0]

    def mean_z(group, lo, hi):
        pts = R[[i for i in group if lo < R[i, 2] < hi]]
        return pts.mean(axis=0)
    L = dict(r_elbow=mean_z(rarm, 3, 9), r_wrist=mean_z(rarm, -7, -3),
             l_elbow=mean_z(larm, 3, 9), l_wrist=mean_z(larm, -7, -3))
    head = [i for i in range(len(R)) if R[i, 2] > 28.5]
    H = R[head]
    low = H[H[:, 2] < 32]
    L["chin"] = low[np.argmin(low[:, 1])]
    L["rarm"], L["larm"], L["head"] = rarm, larm, head
    return L


def build_parts(L, T):
    """The parts of the nanosuit (the user's character art), in rest-frame game units, placed on the
    body's surface (T: its rest-frame triangles); each with the body region its anchors come from."""
    parts = []
    X, Y, Z = np.eye(3)

    def front(x, z):
        return -40 + mech_art.ray(T, (x, -40, z), (0, 1, 0))

    def back(x, z):
        return 40 - mech_art.ray(T, (x, 40, z), (0, -1, 0))

    # The vest's 3D gear (the vest itself is painted on the body): panels over the chest, a row of
    # mag pouches across the belly, each with its flap.
    p = Part("carrier")
    for side in (1, -1):
        x = side * 3.4
        y = min(front(x, 19.5), front(x * 1.4, 19.5)) - 0.5
        n = norm(np.array([side * 0.3, -1, 0]))
        u = np.cross(Z, n) * -side
        p.box(np.array([x, y, 19.5]), u, n, Z * side, (6.4, 0.8, 8.6), ("vest", "vest"))
    for x in (-5.1, -1.7, 1.7, 5.1):
        y = front(x, 9.0)
        p.box(np.array([x, y - 1.05, 9.0]), X, -Y, -Z, (3.1, 1.9, 4.6), ("pouch", "pouch"))
        p.box(np.array([x, y - 1.15, 11.6]), X, -Y, -Z, (3.3, 2.15, 0.7), ("strap", "strap"))
    p.anchor = dict(group="torso", zmin=6, zmax=26)
    parts.append(p)

    # Layered shoulder armour: two curved bands round each deltoid (the upper one over the lower,
    # its top tipped up over the shoulder), bound to the upper arm.
    for side, name in ((1, "r"), (-1, "l")):
        S0, E, _ = mech_bake.ARMS[side]
        ax = norm(E - S0)
        out = norm(side * X - np.dot(side * X, ax) * ax)
        bk = np.cross(ax, out) * side                           # round the arm toward its back
        p = Part("shoulder_" + name)
        for alongs, tips, gap, spread in (((-1.6, -0.4, 1.0, 2.6, 3.8), (50, 30, 10, 0, 0), 0.45, 100),
                                          ((3.2, 4.6, 6.0), (0, 0, 0), 0.3, 90)):
            O, I = [], []
            for a_, tip in zip(alongs, tips):
                c, t = S0 + ax * a_, math.radians(tip)
                ring_o, ring_i = [], []
                for th in np.radians(np.linspace(-spread, spread, 9)):
                    d = norm((math.cos(th) * out + math.sin(th) * bk) * math.cos(t) - ax * math.sin(t))
                    hit = mech_art.ray(T, c + d * 10, -d)
                    r = 10 - hit if hit is not None else 2.0     # the outermost surface on that line
                    ring_o.append(c + d * (r + gap))
                    ring_i.append(c + d * (r + gap - 0.3))
                O.append(ring_o)
                I.append(ring_i)
            p.shell(O, I, "plate", "dark")
        p.anchor = dict(group="uarm_" + name)
        parts.append(p)

    # Knee pads.
    for side, name in ((1, "r"), (-1, "l")):
        x = side * 4.6
        p = Part("knee_" + name)
        p.box(np.array([x, front(x, -23.4) - 0.4, -23.4]), X, -Y, -Z, (3.0, 0.9, 3.8), ("plate", "plate"))
        p.anchor = dict(group="knee_" + name)
        parts.append(p)

    # Pouches on the belt at the hips.
    p = Part("belt_pouches")
    for side in (1, -1):
        p.box(np.array([side * 7.6, -3.4, 1.2]), X, -Y, -Z, (2.6, 2.4, 3.4), ("pouch", "pouch"))
    p.anchor = dict(group="torso", zmin=0, zmax=14)
    parts.append(p)

    # The spine module: a slim plate down the back with the light (its ring is painted above it).
    p = Part("spine")
    lo, hi = np.array([0, back(0, 8.0) + 0.45, 8.0]), np.array([0, back(0, 22.6) + 0.45, 22.6])
    u = norm(hi - lo)
    p.box((lo + hi) / 2, u, X, np.cross(u, X), (np.linalg.norm(hi - lo), 2.0, 0.7), ("plate", "plate"))
    off = np.cross(u, X) * 0.42
    p.box((lo + hi) / 2 + off, u, X, np.cross(u, X), (np.linalg.norm(hi - lo) - 2.0, 0.42, 0.1), ("light", "light"))
    p.anchor = dict(group="torso", zmin=6, zmax=26)
    parts.append(p)

    # The arm cannon out over the right hand (BarrettCannon): black plating, a blue light ring,
    # a steel muzzle, a drum under it.
    e, w = L["r_elbow"], L["r_wrist"]
    ax = norm(w - e)
    out = X
    p = Part("cannon", mesh="BarrettCannon")
    c0, c1 = e + ax * 1.0 + out * 0.5, w + ax * 5.5 + out * 0.5
    p.prism(c0, c1, out, 2.9, 8, "plate", "plate", None)
    p.prism(c1, c1 + ax * 0.6, out, 2.9, 8, "light", None, None, radius_end=2.6)
    p.prism(c1 + ax * 0.6, c1 + ax * 1.6, out, 2.6, 8, "plate", None, None, radius_end=2.0)
    p.prism(c1 + ax * 1.6, c1 + ax * 4.6, out, 1.5, 8, "steel", None, "dark")
    p.box(w + ax * 2.0 - Y * 3.0 + out * 1.0, ax, -Y, np.cross(ax, -Y), (4.2, 2.0, 2.4), ("plate", "plate"))
    p.box((e + w) / 2 + out * 3.2, ax, out, np.cross(ax, out), (6.0, 0.25, 0.5), ("light", "light"))
    p.anchor = dict(group="rarm", zmin=-8, zmax=8)
    parts.append(p)

    # Blades past both fists while the blades are held (BarrettBlade).
    p = Part("blade_r", mesh="BarrettBlade")
    blade(p, (e + w) / 2 - Y * 2.6 - ax * 1.0, w + ax * 8.5 - Y * 2.6, ax, -Y)
    p.anchor = dict(group="rarm", zmin=-8, zmax=8)
    parts.append(p)
    e, w = L["l_elbow"], L["l_wrist"]
    ax = norm(w - e)
    p = Part("blade_l", mesh="BarrettBlade")
    blade(p, (e + w) / 2 - X * 2.6 - ax * 1.0, w + ax * 8.5 - X * 2.6, ax, -X)
    p.anchor = dict(group="larm", zmin=-8, zmax=8)
    parts.append(p)
    return parts


def face_size(pts):
    """A face's width (a to b) and height (a to d, or a to c for a triangle) in game units."""
    return np.linalg.norm(pts[1] - pts[0]), np.linalg.norm(pts[-1] - pts[0])


def shelf_pack(rects, size, pad=1):
    """Rectangles (w, h) into a size x size square, tallest first: [(x, y, w, h)] or None."""
    order = sorted(range(len(rects)), key=lambda i: -rects[i][1])
    out = [None] * len(rects)
    x = y = row = 0
    for i in order:
        w, h = rects[i]
        if x + w + pad > size:
            x, y, row = 0, y + row + pad, 0
        if y + h + pad > size or w + pad > size:
            return None
        out[i] = (x + pad, y + pad, w, h)
        x += w + pad
        row = max(row, h)
    return out


def layout_atlas(parts, density=7.0):
    """Every face its own cell in the 256-unit UV square, as large as fits (UV units per game unit)."""
    faces = [(p, k) for p in parts for k in range(len(p.faces))]
    while True:
        rects = []
        for p, k in faces:
            w, h = face_size(p.faces[k][0])
            rects.append((max(2, int(round(w * density))), max(2, int(round(h * density)))))
        placed = shelf_pack(rects, 255)
        if placed:
            break
        density *= 0.93
    for p in parts:
        p.cells = [None] * len(p.faces)
    for (p, k), (x, y, w, h) in zip(faces, placed):
        p.cells[k] = (x, y, x + w, y + h)
    return density


def bake_atlas(parts, body_tris, out_pcx, A=1024):
    """The parts' texture: each face's cell painted from its 3D surface: material (art/mech/materials),
    occlusion from the body and the parts, a key light, worn edges, bolts, vents."""
    from PIL import Image
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel", "webbing", "carbon")}
    look = {"plate": ("suit", 1, 0), "vest": ("webbing", 1.1, 3), "strap": ("webbing", 1.0, 2),
            "pouch": ("webbing", 1.3, 4), "steel": ("steel", 0.8, 0), "dark": ("carbon", 0.35, 0),
            "light": (None, 1, 0), "gunmetal": ("gunmetal", 0.85, 0)}
    grey = ("vest", "strap", "pouch")                    # the webbing swatch without its olive
    # ("suit": mech_bake.nanosuit's procedural plating; None: a light)
    allf = [f for p in parts for f in p.faces]
    occ = np.concatenate([body_tris] + [np.array([pts[0], pts[1], pts[2]])[None] for pts, _ in allf]
                         + [np.array([pts[0], pts[2], pts[3]])[None] for pts, _ in allf if len(pts) == 4])
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
    rng = np.random.default_rng(11)
    for p in parts:
        for (pts, region), (u0, v0, u1, v1) in zip(p.faces, p.cells):
            P = np.array(pts)
            n = np.cross(P[1] - P[0], P[-1] - P[0])
            n /= np.linalg.norm(n) + 1e-9
            ao = mech_bake.vertex_ao(P, np.repeat(n[None], len(P), 0), occ, rays=40, reach=7.0)
            X0, Y0, X1, Y1 = int(u0 * k), int(v0 * k), int(u1 * k), int(v1 * k)
            xs, ys = np.meshgrid(np.arange(X0 - 2, X1 + 2), np.arange(Y0 - 2, Y1 + 2))
            sx = np.clip((xs + 0.5 - X0) / max(1, X1 - X0), 0, 1)
            ty = np.clip((Y1 - (ys + 0.5)) / max(1, Y1 - Y0), 0, 1)
            if len(P) == 4:
                pos = ((1 - sx) * (1 - ty))[..., None] * P[0] + (sx * (1 - ty))[..., None] * P[1] \
                    + (sx * ty)[..., None] * P[2] + ((1 - sx) * ty)[..., None] * P[3]
                a3 = (1 - sx) * (1 - ty) * ao[0] + sx * (1 - ty) * ao[1] + sx * ty * ao[2] + (1 - sx) * ty * ao[3]
                inside = np.ones_like(sx, bool)
            else:
                pos = P[0] + sx[..., None] * (P[1] - P[0]) + ty[..., None] * (P[2] - P[0])
                a3 = (1 - sx - ty) * ao[0] + sx * ao[1] + ty * ao[2]
                inside = sx + ty <= 1.02
            mname, mul, add = look[region]
            if mname is None:                                   # a light: no material, no shading
                ok = inside & (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
                img[ys[ok], xs[ok]] = mech_bake.LIGHT
                mask[ys[ok], xs[ok]] = True
                continue
            if region == "plate":                                  # the suit's own plating, lit
                col = mech_bake.nanosuit(pos.reshape(-1, 3), np.broadcast_to(n, pos.shape).reshape(-1, 3),
                                         a3.reshape(-1)).reshape(pos.shape)
            else:
                col = mech_bake.triplanar(mats[mname], pos, np.broadcast_to(n, pos.shape), 16) * mul + add
            if region in grey:
                col = col.mean(-1, keepdims=True) * np.array([0.95, 0.98, 1.04])
            if region == "vest":                                   # MOLLE rows, as on the painted vest
                r = np.mod((pos[..., 2] - 5.0) / 1.05, 1)
                col = np.where((r < 0.55)[..., None], col * 1.2, col) * (1 - 0.6 * mech_bake.line(r - 0.58, 0.08))[..., None]
            w, h = face_size(P)
            edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))
            if len(P) == 3:
                edge = np.minimum(edge, (1 - sx - ty) * min(w, h) * 0.7)
            wear = (edge > 0.06) & (edge < 0.28) & (rng.random(edge.shape) < 0.75) & (region != "plate")
            col = np.where(wear[..., None], col * 1.35 + 18, col)
            col *= (0.55 + 0.45 * np.clip(edge / 0.06, 0, 1))[..., None]          # the seam at the very edge
            if region == "vent":
                slot = (np.mod(sx * w * 2.2, 1) < 0.45) & (ty > 0.15) & (ty < 0.85)
                col = np.where(slot[..., None], col * 0.25, col)
            if region in ("plate",) and w > 4.0 and h > 4.0:                         # bolts in the corners
                for bs, bt in ((0.35, 0.35), (w - 0.35, 0.35), (0.35, h - 0.35), (w - 0.35, h - 0.35)):
                    d = np.hypot(sx * w - bs, ty * h - bt)
                    col = np.where((d < 0.16)[..., None], np.array([150.0, 150, 155]), col)
                    col = np.where(((d >= 0.16) & (d < 0.22))[..., None], col * 0.4, col)
            key = np.array([0.35, -0.55, 0.75]) / np.linalg.norm([0.35, -0.55, 0.75])
            if region != "plate":
                light = 0.6 + 0.5 * max(0.0, float(n @ key))
                col *= (light * (0.45 + 0.55 * np.clip(a3, 0, 1) ** 1.3))[..., None]
            ok = inside & (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
            img[ys[ok], xs[ok]] = col[ok]
            mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    return mech_bake.save_pcx(img, out_pcx)


def choose_anchors(F, candidates, centre):
    """Three of the body's vertices that keep their distances best, around the part."""
    R = F[REST]
    cand = sorted(candidates, key=lambda i: np.linalg.norm(R[i] - centre))[:28]
    best, best_score = None, None
    for a_ in range(len(cand)):
        for b_ in range(a_ + 1, len(cand)):
            for c_ in range(b_ + 1, len(cand)):
                i, j, k = cand[a_], cand[b_], cand[c_]
                area = np.linalg.norm(np.cross(R[j] - R[i], R[k] - R[i])) / 2
                if area < 3.0:
                    continue
                d = [np.linalg.norm(F[:, x] - F[:, y], axis=1) for x, y in ((i, j), (j, k), (i, k))]
                score = sum(x.std() for x in d) / math.sqrt(area)
                if best_score is None or score < best_score:
                    best, best_score = (i, j, k), score
    return best, best_score


def main():
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "art")
    pkg, m = mech_art.load_body()
    F = mech_art.game_frames(pkg, m)
    L = landmarks(F)
    R = F[REST]
    torso = [i for i in range(len(R)) if 6 < R[i, 2] < 27 and abs(R[i, 0]) < 9]
    groups = dict(rarm=L["rarm"], larm=L["larm"], head=L["head"], torso=torso)
    for side, sx in ((1, "r"), (-1, "l")):
        groups["shoulder_" + sx] = [i for i in range(len(R)) if 7 < side * R[i, 0] < 14 and 24 < R[i, 2] < 31]
        arm = L["rarm"] if side > 0 else L["larm"]
        groups["uarm_" + sx] = [i for i in arm if 13 < R[i, 2] < 25]
        groups["knee_" + sx] = [i for i in range(len(R)) if side * R[i, 0] > 1 and -29 < R[i, 2] < -18]
    parts = build_parts(L, mech_art.triangles(m, R))
    dens = layout_atlas(parts)
    for p in parts:
        p.finalize()
    print("atlas: %.2f UV units per game unit" % dens)

    meshes = {}
    for p in parts:
        P = np.array(p.verts)
        g = [i for i in groups[p.anchor["group"]] if p.anchor.get("zmin", -99) < R[i, 2] < p.anchor.get("zmax", 99)]
        (i, j, k), score = choose_anchors(F, g, P.mean(axis=0))
        o, M = frame_of(R[i], R[j], R[k])
        local = (P - o) @ M.T
        mesh = meshes.setdefault(p.mesh, dict(verts=[], tris=[], parts=[]))
        base = len(mesh["verts"])
        mesh["verts"] += list(P)
        mesh["tris"] += [(a + base, b + base, c + base, ua, ub, uc) for a, b, c, ua, ub, uc in p.tris]
        mesh["parts"].append(dict(part=p.name, anchors=[int(i), int(j), int(k)], first=base, count=len(P),
                                  local=[[round(float(x), 5) for x in v] for v in local]))
        print("%-14s %-13s %3d verts, %3d tris, anchors %s (score %.4f)" % (p.mesh, p.name, len(P), len(p.tris), (i, j, k), score))

    nf = F.shape[0]
    os.makedirs(os.path.join(out, "Models"), exist_ok=True)
    os.makedirs(os.path.join(out, "Classes"), exist_ok=True)
    out_bind = dict(body=mech_art.BODY, frame_verts=m["frame_verts"], frames=nf, rest=REST,
                    scale=m["scale"], origin=m["origin"], meshes={})
    previews = ((REST, "rest"), (5, "walk"), (40, "death"), (106, "attack"), (100 + 2, "shoot"))
    for name, mesh in meshes.items():
        baked = bake(F, mesh["parts"], len(mesh["verts"]))
        raw = np.rint(baked / np.array(m["scale"]) + np.array(m["origin"])).astype(np.int16)
        write_d3d(os.path.join(out, "Models", name + "_d.3d"), len(mesh["verts"]), mesh["tris"])
        write_a3d(os.path.join(out, "Models", name + "_a.3d"), raw)
        out_bind["meshes"][name] = dict(verts=len(mesh["verts"]), parts=mesh["parts"])
        for f, pose in previews:
            write_obj(os.path.join(out, "%s_%s.obj" % (name, pose)), baked[f], mesh["tris"])
        print("%s: %d verts, %d tris" % (name, len(mesh["verts"]), len(mesh["tris"])))
    for f, pose in previews:
        mech_art.write_obj(os.path.join(out, "body_%s.obj" % pose), m, pkg.frames(m)[f])
    write_uc(os.path.join(out, "Classes", "MechArt.uc"), m, list(meshes))
    os.makedirs(os.path.join(out, "Textures"), exist_ok=True)
    bake_atlas([p for p in parts if p.mesh == "BarrettParts"] + [p for p in parts if p.mesh != "BarrettParts"],
               mech_art.triangles(m, R), os.path.join(out, "Textures", "BarrettParts.pcx"))
    json.dump(out_bind, open(os.path.join(out, "bindings.json"), "w"), indent=1)
    print("frames", nf, "->", out)


def write_d3d(path, nverts, tris):
    with open(path, "wb") as f:
        f.write(struct.pack("<HHHH3I4I12s", len(tris), nverts, 0, 0, 0, 0, 0, 0, 0, 0, 0, b"\0" * 12))
        for a, b, c, ua, ub, uc in tris:
            # Winding as built (outward by the right-hand rule): measured in the game.
            f.write(struct.pack("<3HBB6BBB", a, b, c, 0, 0, ua[0], ua[1], ub[0], ub[1], uc[0], uc[1], 0, 0))


def write_a3d(path, raw):
    nf, nv, _ = raw.shape
    with open(path, "wb") as f:
        f.write(struct.pack("<HH", nf, nv * 8))
        pad = np.zeros((nf, nv, 1), np.int16)
        f.write(np.concatenate([raw, pad], axis=2).astype("<i2").tobytes())


def write_uc(path, m, names):
    pkg, _ = mech_art.load_body()
    seqs = pkg.read_mesh(mech_art.BODY)["seqs"]
    s, o, rot = m["scale"], m["origin"], m["rot_origin"]
    lines = ["//=============================================================================",
             "// MechArt: the Barrett-line Mech's own parts (generated by tools/mech_parts.py).",
             "// Built on each PC from its own copy of the game's body (tools/mech_art.py).",
             "//=============================================================================",
             "class MechArt extends Object abstract;", "",
             "#exec TEXTURE IMPORT NAME=BarrettPartsTex FILE=Textures\\BarrettParts.pcx GROUP=Skins",
             "// The body's own skins (tools/mech_bake.py, tools/mech_face.py): CoopMechPlayer.MechSkin.",
             "#exec TEXTURE IMPORT NAME=BarrettSuit FILE=Textures\\BarrettSuit.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=BarrettLegs FILE=Textures\\BarrettLegs.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=BarrettFace FILE=Textures\\BarrettFace.pcx GROUP=Skins"]
    for n in names:
        lines += ["",
                  "#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (n, n, n),
                  "#exec MESH ORIGIN MESH=%s X=%d Y=%d Z=%d PITCH=%d YAW=%d ROLL=%d" % (
                      n, o[0], o[1], o[2], rot[0] * 256 // 65536, rot[1] * 256 // 65536, rot[2] * 256 // 65536)]
        for q in seqs:
            lines.append("#exec MESH SEQUENCE MESH=%s SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (
                n, q["name"], q["start"], q["frames"], q["rate"]))
        lines += ["#exec MESHMAP SCALE MESHMAP=%s X=%g Y=%g Z=%g" % ((n,) + tuple(s)),
                  "#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=0 TEXTURE=BarrettPartsTex" % n]
    open(path, "w", newline="\r\n").write("\n".join(lines) + "\n")


def write_obj(path, V, tris):
    with open(path, "w") as f:
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % tuple(v))
        for t in tris:
            f.write("f %d %d %d\n" % (t[0] + 1, t[1] + 1, t[2] + 1))


if __name__ == "__main__":
    if sys.argv[1] == "build":
        main()
