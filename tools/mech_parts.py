"""The Barrett-line Mech's own parts (docs/MECH_CLASS.md, phase 3): geometry, anchors on the game
body, a bake of every frame, and the files the game's importer reads.

Each part is rigid and rides a frame made from three of the body's vertices (anchors): its
vertices are stored in that frame's local coordinates (bindings.json), so any PC can rebuild
the frames from its own copy of the body (tools/mech_art.py, the installer).

  python -I tools/mech_parts.py build [outdir]      (default build/mech/art)
"""
import copy, json, math, os, struct, sys

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

    # Knee pads on the knees (the legs' measured centre lines, mech_bake.LEGS), turned the way the
    # front of the knee faces: a pad and a raised cap.
    for side, name in ((1, "r"), (-1, "l")):
        cx, z = mech_bake.LEGS[side][1][0], -23.4
        u = norm(np.array([2.4, front(cx + 1.2, z) - front(cx - 1.2, z), 0.0]))   # across the knee
        v = np.cross(u, Z)                                                       # out of its front
        f = np.array([cx, front(cx, z), z])
        p = Part("knee_" + name)
        p.box(f + v * 0.35, u, v, np.cross(u, v), (3.8, 0.7, 4.4), ("armor", "armor"))
        p.box(f + v * 0.95, u, v, np.cross(u, v), (2.6, 0.5, 3.0), ("armor", "armor"))
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

    # (The arm cannon, BarrettCannon and BarrettCannonBack: storm_parts, tools/mech_storm.py.)
    return parts + blade_parts(L)


def blade_parts(L):
    """Blades past both fists while the blades are held (BarrettBlade)."""
    X, Y, Z = np.eye(3)
    out = []
    for s, sideways in (("r", -Y), ("l", -X)):
        e, w = L[s + "_elbow"], L[s + "_wrist"]
        ax = norm(w - e)
        p = Part("blade_" + s, mesh="BarrettBlade")
        blade(p, (e + w) / 2 + sideways * 2.6 - ax * 1.0, w + ax * 8.5 + sideways * 2.6, ax, sideways)
        p.anchor = dict(group=s + "arm", zmin=-8, zmax=8)
        out.append(p)
    return out


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
    occlusion from the body and the parts, a key light, seams, bolts, vents, snaps."""
    from PIL import Image
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel", "webbing", "carbon")}
    look = {"plate": ("suit", 1, 0), "armor": ("suit", 1, 0), "vest": ("webbing", 1.0, 2),
            "strap": ("webbing", 0.85, 1), "pouch": ("webbing", 1.1, 2), "steel": ("steel", 0.8, 0),
            "dark": ("carbon", 0.35, 0), "light": (None, 1, 0), "gunmetal": ("gunmetal", 0.85, 0)}
    grey = ("vest", "strap", "pouch")                    # the webbing swatch in the vest's olive-black
    suit = {"plate": (44.0, 3.2, 0.8, mech_bake.COOL), "armor": (60.0, 2.0, 0.6, mech_bake.GUNMETAL)}
    # ("suit": mech_bake.nanosuit's procedural plating, black or gunmetal; None: a light)
    allf = [f for p in parts for f in p.faces]
    occ = np.concatenate([body_tris] + [np.array([pts[0], pts[1], pts[2]])[None] for pts, _ in allf]
                         + [np.array([pts[0], pts[2], pts[3]])[None] for pts, _ in allf if len(pts) == 4])
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
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
            if region in suit:                                     # the suit's own plating, lit
                base, big, fine, tint = suit[region]
                col = mech_bake.nanosuit(pos.reshape(-1, 3), np.broadcast_to(n, pos.shape).reshape(-1, 3),
                                         a3.reshape(-1), base, big, fine, tint).reshape(pos.shape)
            else:
                col = mech_bake.triplanar(mats[mname], pos, np.broadcast_to(n, pos.shape), 16) * mul + add
            if region in grey:
                col = col.mean(-1, keepdims=True) * mech_bake.OLIVE
            if region == "vest":                                   # MOLLE rows, as on the painted vest
                r = np.mod((pos[..., 2] - 5.0) / 1.05, 1)
                col = np.where((r < 0.55)[..., None], col * 1.2, col) * (1 - 0.6 * mech_bake.line(r - 0.58, 0.08))[..., None]
                fw, fh = face_size(P)
                if fw > 4 and fh > 4:                              # a chest panel's face: a pocket flap, a velcro patch
                    v_ = ty * fh
                    col = np.where((v_ > fh * 0.62)[..., None], col * 0.92 + 3, col)
                    col = col * (1 - 0.6 * mech_bake.line(v_ - fh * 0.62, 0.1))[..., None] + 14 * mech_bake.line(v_ - fh * 0.62 - 0.14, 0.06)[..., None]
                    patch = (np.abs(sx * fw - fw / 2) < 1.6) & (np.abs(v_ - fh * 0.82) < 0.55)
                    col = np.where(patch[..., None], col * 0.7 + np.array([6.0, 6, 4]), col)
            w, h = face_size(P)
            edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))
            if len(P) == 3:
                edge = np.minimum(edge, (1 - sx - ty) * min(w, h) * 0.7)
            col *= (0.55 + 0.45 * np.clip(edge / 0.06, 0, 1))[..., None]          # the seam at the very edge
            if region == "strap" and w > 2.8 and h < 1.0:                          # a flap's steel snap
                snap = (np.abs(sx * w - w / 2) < 0.3) & (np.abs(ty * h - h / 2) < 0.18)
                col = np.where(snap[..., None], np.array([110.0, 118, 128]), col)
            if region == "vent":
                slot = (np.mod(sx * w * 2.2, 1) < 0.45) & (ty > 0.15) & (ty < 0.85)
                col = np.where(slot[..., None], col * 0.25, col)
            if region in ("plate",) and w > 4.0 and h > 4.0:                         # bolts in the corners
                for bs, bt in ((0.35, 0.35), (w - 0.35, 0.35), (0.35, h - 0.35), (w - 0.35, h - 0.35)):
                    d = np.hypot(sx * w - bs, ty * h - bt)
                    col = np.where((d < 0.16)[..., None], np.array([150.0, 150, 155]), col)
                    col = np.where(((d >= 0.16) & (d < 0.22))[..., None], col * 0.4, col)
            if region not in suit:                                 # as mech_bake.lit: soft key, occlusion
                light = 0.6 + 0.55 * (np.clip(float(n @ mech_bake.KEY), -1, 1) * 0.5 + 0.5) ** 2
                col *= (light * (0.5 + 0.5 * np.clip(a3, 0, 1) ** 1.3))[..., None]
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
        groups["knee_" + sx] = [i for i in range(len(R)) if side * R[i, 0] > 1 and -29 < R[i, 2] < -18]
    parts = build_parts(L, mech_art.triangles(m, R))
    dens = layout_atlas(parts)
    for p in parts:
        p.finalize()
    print("atlas: %.2f UV units per game unit" % dens)
    gun, view, arms = storm_parts(F, L, mech_art.triangles(m, R), m, os.path.join(out, "Textures"))
    # The blades in steps out of the forearms, for others' screens (CoopMechParts.Stages): BarrettBlade1, 2.
    import blade_view
    steps = []
    for k, ext in enumerate(blade_view.STAGES):
        for p in [p for p in parts if p.mesh == "BarrettBlade"]:
            q = copy.copy(p)
            q.mesh = "BarrettBlade%d" % (k + 1)
            q.verts = list(blade_view.staged(p.verts, L[p.name[-1] + "_elbow"], L[p.name[-1] + "_wrist"], ext))
            steps.append(q)

    meshes = {}
    for p in parts + gun + steps:
        P = np.array(p.verts)
        g = [i for i in groups[p.anchor["group"]] if p.anchor.get("zmin", -99) < R[i, 2] < p.anchor.get("zmax", 99)]
        (i, j, k), score = choose_anchors(F, g, P.mean(axis=0))
        o, M = frame_of(R[i], R[j], R[k])
        local = (P - o) @ M.T
        mesh = meshes.setdefault(p.mesh, dict(verts=[], tris=[], parts=[], skins=[]))
        base = len(mesh["verts"])
        mesh["verts"] += list(P)
        mesh["tris"] += [(a + base, b + base, c + base, ua, ub, uc) for a, b, c, ua, ub, uc in p.tris]
        mesh["skins"] += getattr(p, "skins", [0] * len(p.tris))
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
        write_d3d(os.path.join(out, "Models", name + "_d.3d"), len(mesh["verts"]), mesh["tris"], mesh["skins"])
        write_a3d(os.path.join(out, "Models", name + "_a.3d"), raw)
        out_bind["meshes"][name] = dict(verts=len(mesh["verts"]), parts=mesh["parts"])
        for f, pose in previews:
            write_obj(os.path.join(out, "%s_%s.obj" % (name, pose)), baked[f], mesh["tris"])
        print("%s: %d verts, %d tris" % (name, len(mesh["verts"]), len(mesh["tris"])))
    # The Mech's own view of its gun (no game data in it: kept whole in the release's template).
    frames, tris, skins, seqs = view
    write_d3d(os.path.join(out, "Models", "StormView_d.3d"), frames.shape[1], tris, skins)
    write_a3d(os.path.join(out, "Models", "StormView_a.3d"), np.rint(frames * 256).astype(np.int16))
    print("StormView: %d verts, %d tris, %d frames" % (frames.shape[1], len(tris), frames.shape[0]))
    # The Mech's own arms in its view: the body's (filled in at install from each PC's own body).
    out_bind["arms"] = []
    for name, (frames, tris, skins, bind) in (("StormArm", arms),):
        write_d3d(os.path.join(out, "Models", name + "_d.3d"), frames.shape[1], tris, skins)
        write_a3d(os.path.join(out, "Models", name + "_a.3d"), np.rint(frames * 256).astype(np.int16))
        out_bind["arms"].append(bind)
        print("%s: %d verts, %d tris (body faces), skins %s" % (name, frames.shape[1], len(tris), sorted(set(skins))))
    # Each class's own view of its blades (ours, kept whole, as StormView: tools/blade_arms.py, tools/blade_view.py).
    import blade_view
    blade_lines = blade_view.build("Mech", out) + blade_view.build("Jensen", out)
    for f, pose in previews:
        mech_art.write_obj(os.path.join(out, "body_%s.obj" % pose), m, pkg.frames(m)[f])
    write_uc(os.path.join(out, "Classes", "MechArt.uc"), m, list(meshes), seqs, blade_lines)
    os.makedirs(os.path.join(out, "Textures"), exist_ok=True)
    bake_atlas([p for p in parts if p.mesh == "BarrettParts"] + [p for p in parts if p.mesh != "BarrettParts"],
               mech_art.triangles(m, R), os.path.join(out, "Textures", "BarrettParts.pcx"))
    json.dump(out_bind, open(os.path.join(out, "bindings.json"), "w"), indent=1)
    print("frames", nf, "->", out)


def storm_parts(F, L, T, m, texdir):
    """The arm cannon (tools/mech_storm.py, the user's design): its three skins into texdir; the parts
    BarrettCannon (on top of the right hand, while it is held) and BarrettCannonBack (behind the right
    shoulder blade, muzzle down, otherwise); the Mech's own view of it, StormView (frames, triangles,
    skins, sequences); and of its own arms, StormArm (arm_mesh). Placed through a mirror (the game's frame
    is left-handed), so wound back."""
    import mech_storm
    p, _ = mech_storm.made()
    os.makedirs(texdir, exist_ok=True)
    for s in range(3):
        im = mech_storm.bake(p, s, os.path.join(texdir, "StormGun%d.png" % (s + 1)))
        mech_bake.save_pcx(np.asarray(im, float), os.path.join(texdir, "StormGun%d.pcx" % (s + 1)))
    detail = ("face", "bore", "cap", "nose")
    out = []

    def placed(name, mesh, groups, o, ax, up, anchor, shape=None):
        V, G, tris, skins = mech_storm.mesh_of(p, groups, detail)
        if shape:
            V = shape(V, G)
        left = -np.cross(up, ax)                    # the gun's left, as the game shows it
        q = Part(name, mesh=mesh)
        q.verts = list(o + V[:, :1] * ax + V[:, 1:2] * left + V[:, 2:3] * up)
        q.tris, q.skins, q.anchor = mech_storm.mirrored(tris), skins, anchor
        out.append(q)

    # On the right forearm (the gun's frame is the forearm's), its top the side that faces up as it shoots;
    # level as it shoots (the user's ask): the forearm points up in the Shoot frames, so the gun is turned
    # down by as much about the wrist's pin, then seated as low as it goes on the arm (the user's ask: low,
    # "practically attached to his forearm", "it can clip a little"): its underside sinks into the arm's
    # top by CLIP at most. (The forearm and hand move as one, so the arm in the rest frame is the arm in
    # every frame, in the gun's frame.)
    e, w, ax, up = forearm_frame(F, L)
    R = F[REST]
    ei = [i for i in L["rarm"] if 3 < R[i, 2] < 9]
    wi = [i for i in L["rarm"] if -7 < R[i, 2] < -3]
    rise = np.degrees(np.mean([math.asin(norm(F[f][wi].mean(0) - F[f][ei].mean(0))[2]) for f in range(100, 106)]))
    D = R[L["rarm"]] - e
    arm = np.stack([D @ ax, D @ -np.cross(up, ax), D @ up], -1)
    CLIP = 1.2
    C, B = mech_storm.CASS, mech_storm.BRICK

    def level(V, G):
        g = np.isin(np.asarray(G), ("gun", "brick"))
        V = V.copy()
        V[g] = mech_storm.spin(V[g], rise)
        sink = []                       # how far the arm's top is above the underside, at points along it
        for x0, x1, zb, hw in ((C["x0"], C["x1"], C["z"] - C["h"], C["h"]), (B["x0"], B["x1"], B["z0"], B["y"])):
            for x in np.linspace(x0, x1, 17):
                P = mech_storm.spin(np.array([[x, 0.0, zb]]), rise)[0]
                below = arm[(np.abs(arm[:, 0] - P[0]) < 1.0) & (np.abs(arm[:, 1]) < hw + 0.3)]
                if len(below):
                    sink.append(below[:, 2].max() - P[2])
        dz = max(sink) - CLIP
        V[g, 2] += dz
        print("cannon: turned down %.1f degrees to shoot level, raised %+.2f: into the arm %.2f at most, "
              "%.2f over the wrist" % (rise, dz, CLIP, -(sink[0] - dz)))
        return V
    placed("cannon", "BarrettCannon", mech_storm.THIRD, e, ax, up, dict(group="rarm", zmin=-8, zmax=8), level)
    # Behind the right shoulder blade: muzzle down, its underside (the yoke's side) on the back.
    x, z = 4.8, 15.0
    back = 40 - mech_art.ray(T, (x, 40, z), (0, -1, 0))
    centre = np.array([x, back, z])
    down, out_ = np.array([0.0, 0.0, -1.0]), np.array([0.0, 1.0, 0.0])
    gx, gz = (mech_storm.BRICK["x0"] + mech_storm.CASS["x1"]) / 2, mech_storm.CASS["z"] - mech_storm.CASS["h"]
    placed("cannon_back", "BarrettCannonBack", mech_storm.BACK, centre - gx * down - gz * out_, down, out_,
           dict(group="torso", zmin=8, zmax=24))
    return out, mech_storm.view_mesh(p), arm_mesh(F, L, m, mech_storm.frames_of)


SHOOT = 102         # a Shoot frame: the arms out, aiming
# The Mech's own arms in its view (arm_mesh): faces from this far along the forearm from the elbow on, and no
# farther from its axis than ARM_RADIUS. Its sleeve's faces run from the elbow's ring (along 0) to the wrist: 3.0
# kept the hands alone and the right arm looked cut off at the wrist (the user saw it); the elbow's and upper
# arm's faces also start at the ring but stand out 5 to 9 from the axis (build/tmp/arm_faces.py), and close to
# the eye they stood up across the view.
ARM_FROM, ARM_RADIUS = -0.5, 4.5


def forearm_faces(m, G, P, e, w):
    """The body's faces of a forearm and its hand (G: the arm's vertices, P: one frame's, e the elbow, w the wrist):
    from ARM_FROM along it, the body's skins (not its specials); those that start in its first half within
    ARM_RADIUS of its axis (the elbow's and upper arm's stand out farther; the hand's fingers, a little: at 4.6, five
    of the right hand's were left out and the glove showed a notch)."""
    sv = m["special_verts"]
    Gs = set(G)
    ax = norm(w - e)
    half = np.linalg.norm(w - e) / 2
    faces = []
    for fi, f in enumerate(m["faces"]):
        vs = [m["wedges"][k][0] + sv for k in f[:3]]
        D = P[vs] - e
        along = D @ ax
        if (m["materials"][f[3]][1] < 4 and all(v in Gs for v in vs) and along.min() > ARM_FROM
                and (along.min() > half or np.linalg.norm(D - np.outer(along, ax), axis=1).max() < ARM_RADIUS)):
            faces.append(fi)
    return faces


def arm_mesh(F, L, m, view):
    """StormArm, the Mech's own forearms and hands as it sees them (the user's ask: his own arm, not a
    model of one): the body's faces (the right forearm and hand; the left, for the reload), with the body's
    UVs and skins, its vertices in frame SHOOT carried into the view frame by frame (mech_storm.in_view:
    the right arm with the gun's arm, the left as the left hand). Built from each PC's own body at install
    (mech_art.fill, MechParts.cs): the release carries only the face numbers and each frame's transforms.
    Returns (frames, tris, skins, binding)."""
    import mech_storm
    R, S = F[REST], F[SHOOT]
    sv = m["special_verts"]
    up = np.array([0.0, 0.0, 1.0])
    picked, groups, xforms = [], [], []
    for name, gname in (("rarm", "arm"), ("larm", "lhand")):
        G = L[name]
        e = S[[i for i in G if 3 < R[i, 2] < 9]].mean(axis=0)            # as landmarks(), in frame SHOOT
        w = S[[i for i in G if -7 < R[i, 2] < -3]].mean(axis=0)
        ax = norm(w - e)
        u = norm(up - (up @ ax) * ax)                                      # it faces up as it shoots
        left = -np.cross(u, ax)
        picked.append(forearm_faces(m, G, S, e, w))
        # Body (frame SHOOT, game units) -> the gun's frame: this forearm's (the left one's carried to the
        # brick's handle as mech_storm's left hand), then the view, frame by frame: an affine map each.
        def to_gun(P, e=e, ax=ax, left=left, u=u, name=name, w=w):
            d = np.stack([(P - e) @ ax, (P - e) @ left, (P - e) @ u], -1)
            if name == "rarm":
                return d
            g = mech_storm.GRAB
            uu = norm(g - np.array([-2.0, 15.0, -7.0]))
            vv = norm(np.cross(np.array([0.0, 0.0, 1.0]), uu))
            ww = np.cross(uu, vv)
            held = np.array([np.linalg.norm(w - e) + 2.3, 0.0, -0.3])
            return g + (d - held) @ np.array([uu, vv, ww])
        basis = np.vstack([np.zeros(3), np.eye(3)])
        xf = []
        for P in view(to_gun(basis), gname):
            b = P[0]
            xf.append(np.hstack([(P[1:] - b).T, b[:, None]]))                # 3 x 4: [A | b]
        xforms.append(np.array(xf))
        groups.append(gname)
    # The vertices (each once), the triangles (the body's winding: through two mirrors, still facing out).
    order, index, tris, skins = [], {}, [], []
    for gi, faces in enumerate(picked):
        for fi in faces:
            f = m["faces"][fi]
            ids = []
            for k in f[:3]:
                v = m["wedges"][k][0] + sv
                if v not in index:
                    index[v] = len(order)
                    order.append((v, gi))
                ids.append(index[v])
            uv = [(m["wedges"][k][1], m["wedges"][k][2]) for k in f[:3]]
            tris.append((ids[0], ids[1], ids[2], uv[0], uv[1], uv[2]))
            skins.append(m["materials"][f[3]][1])
    # In skin order (the importer sorts a mesh's triangles so, keeping their order within a skin).
    sort = sorted(range(len(tris)), key=lambda i: skins[i])
    faces = [fi for faces in picked for fi in faces]
    tris, skins, faces = [tris[i] for i in sort], [skins[i] for i in sort], [faces[i] for i in sort]
    frames = arm_frames(S, order, np.stack(xforms, 1))
    binding = dict(mesh="StormArm", frame=SHOOT, verts=[v for v, _ in order], groups=[g for _, g in order],
                   faces=faces,
                   xforms=[[[float(x) for x in M.ravel()] for M in per] for per in np.stack(xforms, 1)])
    return frames, tris, skins, binding


def arm_frames(S, order, xforms):
    """The arm's frames (view units) from the body's frame-SHOOT vertices and each frame's maps (frames,
    groups, 3, 4); the sums in the order MechParts.cs does them (its bytes must match)."""
    P = S[[v for v, _ in order]]
    g = np.array([gi for _, gi in order])
    out = np.zeros((len(xforms), len(order), 3))
    for f, per in enumerate(xforms):
        M = per[g]                                                         # each vertex's map
        for a in range(3):
            out[f, :, a] = ((M[:, a, 0] * P[:, 0] + M[:, a, 1] * P[:, 1]) + M[:, a, 2] * P[:, 2]) + M[:, a, 3]
    return out


def forearm_frame(F, L):
    """The right forearm in the rest frame: elbow, wrist, its axis, and the side of it that faces up when
    the Mech shoots (frame SHOOT: the forearm's turn from the rest pose, by its vertices)."""
    e, w = L["r_elbow"], L["r_wrist"]
    ax = norm(w - e)
    R, S = F[REST], F[SHOOT]
    fore = [i for i in L["rarm"] if 0.05 < (R[i] - e) @ ax / np.linalg.norm(w - e) < 0.95]
    A, B = R[fore] - R[fore].mean(0), S[fore] - S[fore].mean(0)
    U, _, Vt = np.linalg.svd(A.T @ B)
    turn = (U @ np.diag([1, 1, np.sign(np.linalg.det(U @ Vt))]) @ Vt).T          # rest -> SHOOT
    up = turn.T @ np.array([0.0, 0.0, 1.0])
    return e, w, ax, norm(up - (up @ ax) * ax)


def write_d3d(path, nverts, tris, skins=None):
    with open(path, "wb") as f:
        f.write(struct.pack("<HHHH3I4I12s", len(tris), nverts, 0, 0, 0, 0, 0, 0, 0, 0, 0, b"\0" * 12))
        for k, (a, b, c, ua, ub, uc) in enumerate(tris):
            # Winding as built (outward by the right-hand rule): measured in the game. The last but one
            # byte: the triangle's skin (MESHMAP SETTEXTURE NUM).
            f.write(struct.pack("<3HBB6BBB", a, b, c, 0, 0, ua[0], ua[1], ub[0], ub[1], uc[0], uc[1],
                                skins[k] if skins else 0, 0))


def write_a3d(path, raw):
    nf, nv, _ = raw.shape
    with open(path, "wb") as f:
        f.write(struct.pack("<HH", nf, nv * 8))
        pad = np.zeros((nf, nv, 1), np.int16)
        f.write(np.concatenate([raw, pad], axis=2).astype("<i2").tobytes())


def write_uc(path, m, names, view_seqs, blade_lines):
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
             "#exec TEXTURE IMPORT NAME=BarrettFace FILE=Textures\\BarrettFace.pcx GROUP=Skins",
             "// The arm cannon's skins (tools/mech_storm.py).",
             "#exec TEXTURE IMPORT NAME=StormGun1 FILE=Textures\\StormGun1.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=StormGun2 FILE=Textures\\StormGun2.pcx GROUP=Skins",
             "#exec TEXTURE IMPORT NAME=StormGun3 FILE=Textures\\StormGun3.pcx GROUP=Skins",
             "// (The Light Mech's skins, Adam Jensen's look: JensenArt.uc, parsed before this.)",
             "",
             "// The Mech's own view of its arm cannon (CoopMechCannon): the eye at the origin, X ahead.",
             "#exec MESH IMPORT MESH=StormView ANIVFILE=Models\\StormView_a.3d DATAFILE=Models\\StormView_d.3d X=0 Y=0 Z=0 MLOD=0",
             "#exec MESH ORIGIN MESH=StormView X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0"]
    total = sum(q[2] for q in view_seqs)
    lines.append("#exec MESH SEQUENCE MESH=StormView SEQ=All STARTFRAME=0 NUMFRAMES=%d RATE=30" % total)
    for name, start, count, rate in view_seqs:
        lines.append("#exec MESH SEQUENCE MESH=StormView SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (name, start, count, rate))
    lines.append("#exec MESHMAP SCALE MESHMAP=StormView X=0.00390625 Y=0.00390625 Z=0.00390625")
    lines += ["#exec MESHMAP SETTEXTURE MESHMAP=StormView NUM=%d TEXTURE=StormGun%d" % (k, k + 1) for k in range(3)]
    lines += ["", "// Its own arms in that view (the body's, in its skins: CoopMechPlayer.MechSkin; drawn with it).",
              "#exec MESH IMPORT MESH=StormArm ANIVFILE=Models\\StormArm_a.3d DATAFILE=Models\\StormArm_d.3d X=0 Y=0 Z=0 MLOD=0",
              "#exec MESH ORIGIN MESH=StormArm X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0",
              "#exec MESH SEQUENCE MESH=StormArm SEQ=All STARTFRAME=0 NUMFRAMES=%d RATE=30" % total]
    for name, start, count, rate in view_seqs:
        lines.append("#exec MESH SEQUENCE MESH=StormArm SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (name, start, count, rate))
    lines.append("#exec MESHMAP SCALE MESHMAP=StormArm X=0.00390625 Y=0.00390625 Z=0.00390625")
    lines += ["#exec MESHMAP SETTEXTURE MESHMAP=StormArm NUM=%d TEXTURE=%s" % (k, t)
              for k, t in enumerate(("BarrettSuit", "BarrettLegs", "BarrettFace", "BarrettFace"))]
    lines += ["", "// Each class's own view of its arm blades: its blade arms (tools/blade_arms.py, tools/blade_view.py; CoopMechBlade)."]
    lines += blade_lines
    for n in names:
        lines += ["",
                  "#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (n, n, n),
                  "#exec MESH ORIGIN MESH=%s X=%d Y=%d Z=%d PITCH=%d YAW=%d ROLL=%d" % (
                      n, o[0], o[1], o[2], rot[0] * 256 // 65536, rot[1] * 256 // 65536, rot[2] * 256 // 65536)]
        for q in seqs:
            lines.append("#exec MESH SEQUENCE MESH=%s SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (
                n, q["name"], q["start"], q["frames"], q["rate"]))
        lines.append("#exec MESHMAP SCALE MESHMAP=%s X=%g Y=%g Z=%g" % ((n,) + tuple(s)))
        if n.startswith("BarrettCannon"):
            lines += ["#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=%d TEXTURE=StormGun%d" % (n, k, k + 1) for k in range(3)]
        else:
            lines.append("#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=0 TEXTURE=BarrettPartsTex" % n)
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
