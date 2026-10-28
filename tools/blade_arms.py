"""The arms that hold the arm blades in their owner's view (CoopMechBlade), ours and built to be seen up close. (The body's
own forearms, tried first, were its far-off low-poly sleeves and mitten hands: the user called them "absolute garbage",
2026-10-27.) A mechanical forearm with segmented armour on top and a blade housing along it, a wrist joint, a closed
fist (palm, knuckle guards, curled fingers, a thumb across them), and the blade, a diamond in section with a point, out
of the housing's mouth over the fist. One model; each class paints it (mech_storm's kit, mech_bake's materials):

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

N = 12                                          # sides round the forearm
WRIST = 13.0                                    # where the forearm's armour ends
MOUTH = 13.9                                    # the housing's mouth: the blade comes out here
BLADE = dict(x1=26.0, tip=2.8, half=0.6, thick=0.13, z=1.72)
SHEETS = {"core": 0, "plate": 0, "housing": 0, "joint": 0, "slot": 0}     # else 1 (the hand, the blade)


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


def rrect(cy, cz, hy, hz, c):
    """A rounded (chamfered) rectangle's 8 corners (y, z)."""
    return [(cy + hy, cz - hz + c), (cy + hy, cz + hz - c), (cy + hy - c, cz + hz), (cy - hy + c, cz + hz),
            (cy - hy, cz + hz - c), (cy - hy, cz - hz + c), (cy - hy + c, cz - hz), (cy + hy - c, cz - hz)]


def obox(p, a, b, hv, hw, up, region, c=0.12, caps=True):
    """A chamfered box from point a to point b, hv across (perpendicular to up) and hw along up (half sizes)."""
    a, b = np.asarray(a, float), np.asarray(b, float)
    u = unit(b - a)
    w = unit(np.asarray(up, float) - (np.asarray(up, float) @ u) * u)
    v = np.cross(w, u)
    sec = rrect(0, 0, hv, hw, min(c, hv * 0.45, hw * 0.45))
    S = [np.array([o + s * v + t * w for s, t in sec]) for o in (a, b)]
    loft(p, S, region, (region, region) if caps else (None, None))


def band(p, x0, x1, r0, r1, a0, a1, thick, region, steps=6, zc=0.0):
    """A curved plate over the forearm from x0 to x1: the arc a0..a1 at radii r0 (ry, rz) at x0, r1 at x1, thick."""
    def arc(x, r, grow):
        return np.array([[x, (r[0] + grow) * math.cos(a0 + (a1 - a0) * i / steps),
                          zc + (r[1] + grow) * math.sin(a0 + (a1 - a0) * i / steps)] for i in range(steps + 1)])
    O0, O1, I0, I1 = arc(x0, r0, thick), arc(x1, r1, thick), arc(x0, r0, 0.0), arc(x1, r1, 0.0)
    for i in range(steps):
        rad = np.array([0.0, math.cos(a0 + (a1 - a0) * (i + 0.5) / steps), math.sin(a0 + (a1 - a0) * (i + 0.5) / steps)])
        face(p, [O0[i], O0[i + 1], O1[i + 1], O1[i]], rad, region)
        face(p, [I0[i], I0[i + 1], I1[i + 1], I1[i]], -rad, region)
        face(p, [O0[i], O0[i + 1], I0[i + 1], I0[i]], np.array([-1.0, 0, 0]), region)
        face(p, [O1[i], O1[i + 1], I1[i + 1], I1[i]], np.array([1.0, 0, 0]), region)
    for k, sgn in ((0, -1), (steps, 1)):
        tan = sgn * np.array([0.0, -math.sin(a0 + (a1 - a0) * k / steps), math.cos(a0 + (a1 - a0) * k / steps)])
        face(p, [O0[k], O1[k], I1[k], I0[k]], tan, region)


def radii(x):
    """The forearm's (ry, rz) along it: broad by the elbow, slimmer to the wrist."""
    xs = [0.0, 3.0, 7.0, 10.5, WRIST]
    ry = [2.05, 2.1, 1.95, 1.72, 1.52]
    rz = [1.85, 1.9, 1.72, 1.52, 1.34]
    return float(np.interp(x, xs, ry)), float(np.interp(x, xs, rz))


def build():
    """The right arm with its blade; each face's group in p.groups ("arm", "blade")."""
    p = Part("bladearm", mesh="BladeArm")
    p.groups = []
    # The forearm's core, the segmented plates over its top and under it, the wrist's joint.
    xs = [0.0, 3.0, 7.0, 10.5, WRIST]
    loft(p, [ring(x, *radii(x)) for x in xs], "core", ("slot", None))
    for x0, x1 in ((0.5, 4.4), (4.7, 8.6), (8.9, 12.7)):
        band(p, x0, x1, radii(x0), radii(x1), math.radians(22), math.radians(158), 0.2, "plate")
    band(p, 2.5, 11.5, radii(2.5), radii(11.5), math.radians(205), math.radians(335), 0.16, "plate", steps=5)
    loft(p, [ring(x, 1.48, 1.3, n=N) for x in (12.6, 13.9)], "joint")
    loft(p, [ring(x, 1.62, 1.44, n=N) for x in (12.9, 13.3)], "joint")
    # The blade's housing along the top, sloping with the forearm, its mouth over the wrist.
    top0, top1 = radii(5.0)[1] + 0.2, radii(13.0)[1] + 0.2
    H = [np.array([[x, y, z] for y, z in rrect(0.0, zc, 0.68, 0.42, 0.16)]) for x, zc in ((5.0, top0 + 0.22), (MOUTH, BLADE["z"]))]
    loft(p, H, "housing", ("housing", None))
    face(p, H[1][[0, 2, 4, 6]], np.array([1.0, 0, 0]), "housing")                  # its mouth (the slot painted)
    # The fist, palm down: the hand's block, four knuckle guards, the fingers curled under, the thumb across.
    loft(p, [np.array([[x, y, z] for y, z in rrect(0.05, -0.2, hy, hz, 0.45)]) for x, hy, hz in
             ((13.3, 1.7, 1.08), (15.2, 2.08, 1.12), (16.9, 2.15, 1.02))], "hand", ("hand", "hand"))
    up = np.array([0.0, 0, 1])
    fingers = [(1.55, 0.0), (0.53, 0.15), (-0.5, 0.05), (-1.48, -0.3)]           # (y, set forward) index .. little
    for y, fwd in fingers:
        s = 0.9 if y < -1 else 1.0
        obox(p, (16.6 + fwd, y, 0.42), (17.7 + fwd, y, 0.42), 0.43 * s, 0.5 * s, up, "knuckle", c=0.16)
        obox(p, (17.35 + fwd, y, 0.6), (17.6 + fwd, y, -1.05), 0.41 * s, 0.42 * s, np.array([1.0, 0, 0]), "finger")
        obox(p, (17.75 + fwd, y, -1.42), (16.35 + fwd, y, -1.42), 0.4 * s, 0.4 * s, up, "finger")
    obox(p, (14.6, 2.05, -0.5), (16.6, 2.2, -1.1), 0.5, 0.45, up, "finger")       # the thumb, then across the fingers
    obox(p, (16.9, 2.05, -1.3), (18.15, 0.55, -1.5), 0.42, 0.4, up, "finger")
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


def paint(cls, region, pos, n, ao, edge, mats):
    """(points (k, 3), the face's normal, occlusion (k,), distance to the face's edge (k,)) -> colours (k, 3)."""
    k = len(pos)
    nn = np.repeat(n[None], k, 0)
    if region in ("core", "plate", "joint", "housing"):
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
    if cls == "Jensen":
        # Glossy black shells, gold seams at their edges; a faint hex in the plates; a gold line along the housing.
        base = {"core": 26.0, "plate": 20.0, "housing": 16.0, "hand": 22.0, "knuckle": 18.0, "finger": 24.0}[region]
        carbon = mech_bake.triplanar(mats["carbon"], pos, nn, 10).mean(-1) / 128.0
        col = np.array([[1.0, 0.98, 0.96]]) * (base * (0.85 + 0.25 * carbon))[:, None]
        if region == "plate":
            e = mech_bake.hex_edge(pos[:, 0], np.arctan2(pos[:, 2], pos[:, 1]) * 1.8, 0.7)
            col = col * (1 + 0.6 * mech_bake.line(e, 0.05))[:, None]
        seam = {"plate": 0.07, "knuckle": 0.05, "hand": 0.05, "housing": 0.0, "core": 0.0, "finger": 0.0}[region]
        if seam:
            g = mech_bake.line(edge - seam, 0.035)
            col = col * (1 - g)[:, None] + GOLD[None] * g[:, None]
        if region == "housing":
            g = mech_bake.line(pos[:, 1], 0.06) * (n[2] > 0.5)
            col = col * (1 - g)[:, None] + GOLD[None] * g[:, None]
        col = col * (0.55 + 0.45 * np.clip(edge / 0.03, 0, 1))[:, None]
        return mech_bake.lit(col, nn, ao, gloss=95, power=48)
    # The Mech: the nanosuit's matte black hex (core, hand, fingers), gunmetal armour (plates, housing, knuckles), a
    # blue light along the housing.
    if region in ("core", "hand", "finger"):
        e = mech_bake.hex_edge(pos[:, 0], np.arctan2(pos[:, 2], pos[:, 1]) * 1.8 if region == "core" else pos[:, 1], 0.55)
        col = np.array([[0.9, 0.96, 1.06]]) * 40.0 * (1 - 0.55 * mech_bake.line(e, 0.05))[:, None]
    else:
        g = mech_bake.triplanar(mats["gunmetal"], pos, nn, 28).mean(-1) / 128.0
        col = np.array([[0.86, 0.95, 1.1]]) * (62.0 * (0.8 + 0.3 * g))[:, None]
        if region == "plate":
            bolt = np.hypot(np.mod(pos[:, 0] + 0.5, 3.9) - 0.5, np.abs(np.arctan2(pos[:, 2], pos[:, 1]) - math.pi / 2) * 2.0 - 1.5) < 0.12
            col = np.where(bolt[:, None], col * 1.6, col)
        if region == "housing":
            g = mech_bake.line(np.abs(pos[:, 1]) - 0.5, 0.05) * (abs(n[1]) > 0.5)
            col = col * (1 - g)[:, None] + mech_bake.LIGHT[None] * g[:, None]
    col = col * (0.5 + 0.5 * np.clip(edge / 0.035, 0, 1))[:, None]
    return mech_bake.lit(col, nn, ao, gloss=70, power=24)


def bake(p, cls, sheet, out_png, A=1024, S=512):
    """One skin: every face's cell painted from its 3D surface (paint), occlusion from the model."""
    from PIL import Image
    mats = {k: mech_bake.material(k, blur=0.8) for k in ("gunmetal", "steel", "carbon")}
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
