"""The Mech's FPV attack drones (CoopFPV, CoopFPVGuided): a cheap, mass-made racing quad carrying a warhead, smaller
than the Spy Drone and plainly less advanced (the user, 2026-10-30: "a military, economically feasible FPV drone. Their
whole job is to get destroyed", "mass produced, like cheap munitions", built into the Mech's system but not nanite-made).
A bare carbon X frame on standoffs, four motors with two-blade props (spun in the mesh's frames, a faint blur disc over
each), a battery strapped on top, a camera at the nose, a stub antenna, an RPG-style shaped charge taped and zip-tied
under it, a light at its tail (skin 2: red; the lead's green, FPVLightLead: CoopFPV).

Frame: x forward, y left, z up; game units (about 2 cm); the drone's middle at the origin: about 14.5 across its prop
tips (28 cm; the Spy Drone is 24 units). Written mirrored into the game's left-handed frame (y to the right), wound back,
as the cannon is.

  python -I tools/mech_drone.py preview [outdir]   (default build/mech/drone: skins, OBJ, views through Blender)
"""
import math, os, subprocess, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_bake
from mech_parts import Part, face_size, shelf_pack

ARM = 4.05                  # motor centres at (+-ARM, +-ARM): 23 cm motor to motor, a five-inch quad
PROP_R, PROP_Z = 3.2, 1.42  # the props' radius and height
FRAMES = 6                  # the props' turn: a two-blade prop looks the same after half a turn, 30 degrees a frame
SHARED = ("prop", "bell", "stator", "standoff", "tie", "lens", "antenna", "fuse", "led")   # one small cell each
SHEET = {"disc": 1, "led": 2}                                                             # else skin 0
TRANSLUCENT = ("disc",)
MOTORS = [(sx * ARM, sy * ARM, (1 if sx * sy > 0 else -1)) for sx in (1, -1) for sy in (1, -1)]   # (x, y, spin way)


def unit(v):
    v = np.asarray(v, float)
    return v / (np.linalg.norm(v) + 1e-12)


def build():
    """The drone's faces (Part) with each face's group: "body", or "prop0".."prop3" (spun about its motor)."""
    p = Part("drone", mesh="FPVDrone")
    groups = []

    def done(g):
        groups.extend([g] * (len(p.faces) - len(groups)))

    X, Y, Z = np.eye(3)
    # The frame: a bottom plate and four arms (5 mm carbon), a top plate on four aluminium standoffs.
    p.box((0, 0, 0), X, Y, Z, (3.6, 2.8, 0.3), ("carbon", "carbon"))
    for mx, my, _ in MOTORS:
        d = unit((mx, my, 0))
        n = np.cross(Z, d)
        p.box(d * 3.55 + np.array([0, 0, -0.01]), d, n, Z, (5.1, 0.95, 0.28), ("carbon", "carbon"))
    p.box((0.2, 0, 1.55), X, Y, Z, (3.4, 2.3, 0.2), ("carbon", "carbon"))
    for sx in (1, -1):
        for sy in (1, -1):
            p.prism((sx * 1.35, sy * 0.95, 0.15), (sx * 1.35, sy * 0.95, 1.45), X, 0.13, 4, "standoff", None, None)
    # The motors: a stator on the arm, a bell over it, a shaft and a nut.
    for mx, my, _ in MOTORS:
        p.prism((mx, my, 0.14), (mx, my, 0.75), X, 0.78, 10, "stator", None, "stator")
        p.prism((mx, my, 0.75), (mx, my, 1.2), X, 0.8, 10, "bell", None, "bell")
        p.prism((mx, my, 1.2), (mx, my, PROP_Z + 0.2), X, 0.2, 6, "fuse", None, "fuse")
    # The battery strapped on top (black wrap, a yellow label), two red straps round it and the top plate.
    p.box((-0.2, 0, 2.38), X, Y, Z, (4.4, 2.0, 1.45), ("battery", "battery"))
    for sx in (-1.3, 0.9):
        p.box((sx, 0, 2.15), X, Y, Z, (0.5, 2.12, 1.95), ("strap", "strap"))
    # The camera at the nose between the plates, tilted up, its lens out front.
    tilt = math.radians(22)
    f, u = np.array([math.cos(tilt), 0, math.sin(tilt)]), np.array([-math.sin(tilt), 0, math.cos(tilt)])
    cam = np.array([1.75, 0, 0.82])
    p.box(cam, f, Y, u, (0.95, 1.0, 0.95), ("camera", "camera"))
    p.prism(cam + f * 0.47, cam + f * 0.95, Y, 0.34, 8, "lens", None, "lens")
    # The antenna: a stub up and back from the tail.
    p.prism((-1.5, 0, 1.6), (-2.6, 0, 3.6), Y, 0.11, 5, "antenna", None, None)
    p.prism((-2.6, 0, 3.6), (-2.9, 0, 4.2), Y, 0.24, 6, "antenna", None, "antenna")
    # The tail light.
    p.box((-1.62, 0, 1.75), X, Y, Z, (0.3, 0.55, 0.22), ("led", "led"))
    # The warhead under it: an RPG-style shaped charge, nose forward, its piezo probe ahead; two bands of black tape round
    # it, white zip ties from them up to the frame.
    wz = -2.05
    p.prism((-2.8, 0, wz), (2.3, 0, wz), Z, 1.45, 12, "warhead", None, None)
    p.prism((2.3, 0, wz), (5.0, 0, wz), Z, 1.45, 12, "warhead", None, None, radius_end=0.42)
    p.prism((5.0, 0, wz), (6.3, 0, wz), Z, 0.2, 6, "fuse", None, "fuse")
    p.prism((-2.8, 0, wz), (-3.5, 0, wz), Z, 1.45, 12, "warhead", None, None, radius_end=0.75)
    p.prism((-3.5, 0, wz), (-4.3, 0, wz), Z, 0.62, 10, "tail", None, "tail")
    for x0 in (-1.9, 0.8):
        p.prism((x0, 0, wz), (x0 + 0.6, 0, wz), Z, 1.52, 12, "tape", None, None)
    for x0 in (-1.6, 1.1):
        for sy in (1, -1):
            p.box((x0, sy * 1.2, -0.62), X, Y, Z, (0.14, 0.12, 1.15), ("tie", "tie"))
    done("body")
    # The props: two blades each (a little pitched), and the blur disc over them.
    for k, (mx, my, way) in enumerate(MOTORS):
        c = np.array([mx, my, PROP_Z])
        for a in (0.0, math.pi):
            d = np.array([math.cos(a), math.sin(a), 0.0])
            n = np.cross(Z, d)
            pitch = math.radians(14) * way
            v = n * math.cos(pitch) + Z * math.sin(pitch)
            p.box(c + d * 1.78, d, v, np.cross(d, v), (2.85, 0.5, 0.07), ("prop", "prop"))
        p.prism(c, c + Z * 0.06, X, 0.32, 8, "prop", "prop", "prop")
        done("prop%d" % k)
        for j in range(16):
            a0, a1 = 2 * math.pi * j / 16, 2 * math.pi * (j + 1) / 16
            q0 = c + Z * 0.04 + PROP_R * np.array([math.cos(a0), math.sin(a0), 0])
            q1 = c + Z * 0.04 + PROP_R * np.array([math.cos(a1), math.sin(a1), 0])
            p.add_tri(c + Z * 0.04, q0, q1, "disc")
        done("disc%d" % k)
    p.groups = groups
    return p


def layout(p):
    """Each face its cell in skin 0's 256-unit UV square (the SHARED regions one small cell each); the discs and the
    light their own skins, mapped whole."""
    p.sheets = [SHEET.get(r, 0) for _, r in p.faces]
    shared = {r: None for r in SHARED if r not in SHEET}
    own = [k for k, (_, r) in enumerate(p.faces) if p.sheets[k] == 0 and r not in shared]
    density = 30.0
    while True:
        rects = [(max(2, int(round(face_size(p.faces[k][0])[0] * density))),
                  max(2, int(round(face_size(p.faces[k][0])[1] * density)))) for k in own]
        placed = shelf_pack(rects + [(10, 10)] * len(shared), 255)
        if placed:
            break
        density *= 0.95
    p.cells = [None] * len(p.faces)
    for k, (x, y, w, h) in zip(own, placed):
        p.cells[k] = (x, y, x + w, y + h)
    for r, (x, y, w, h) in zip(list(shared), placed[len(own):]):
        shared[r] = (x, y, x + w, y + h)
    for k, (_, r) in enumerate(p.faces):
        if r in shared:
            p.cells[k] = shared[r]
        elif r == "led":
            p.cells[k] = (0, 0, 255, 255)
    return density


def finalize(p):
    """Vertices and triangles (a, b, c, uv_a, uv_b, uv_c) as Part.finalize, but a disc's by where its corners are
    round its motor (its skin a ring, 128 + 127 r)."""
    p.verts, p.tris, p.tri_faces = [], [], []
    for f, ((pts, region), cell) in enumerate(zip(p.faces, p.cells)):
        i = len(p.verts)
        p.verts += pts
        if region == "disc":
            c = pts[0]
            uv = [(int(round(128 + 127 * (q[0] - c[0]) / PROP_R)), int(round(128 - 127 * (q[1] - c[1]) / PROP_R))) for q in pts]
            p.tris.append((i, i + 1, i + 2, uv[0], uv[1], uv[2]))
            p.tri_faces.append(f)
            continue
        u0, v0, u1, v1 = cell
        if len(pts) == 4:
            uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)]
            p.tris += [(i, i + 1, i + 2, uv[0], uv[1], uv[2]), (i, i + 2, i + 3, uv[0], uv[2], uv[3])]
            p.tri_faces += [f, f]
        else:
            p.tris.append((i, i + 1, i + 2, (u0, v1), (u1, v1), (u0, v0)))
            p.tri_faces.append(f)


# ---- paint
CARBON = np.array([34.0, 34, 37])
OLIVE = np.array([78.0, 84, 54])
YELLOW = np.array([196.0, 160, 40])
RED = np.array([150.0, 34, 30])


def paint(region, pos, n, sx, ty, w, h):
    flat = np.ones(pos.shape[:-1] + (1,))
    edge = np.minimum(np.minimum(sx * w, (1 - sx) * w), np.minimum(ty * h, (1 - ty) * h))[..., None]
    if region == "carbon":                      # a twill weave, a sheen, the cut edges paler
        q = np.floor(pos[..., 0] * 7) + np.floor(pos[..., 1] * 7)
        weave = np.where((np.mod(q, 4) < 2)[..., None], 1.12, 0.9)
        col = CARBON * weave
        return np.where(edge < 0.06, col * 1.6, col)
    if region == "battery":                     # black wrap, a yellow band with its rating
        col = np.array([24.0, 24, 26]) * flat
        if abs(float(n[2])) < 0.5:
            band = np.abs(pos[..., 2] - 2.35) < 0.32
            col = np.where(band[..., None], YELLOW, col)
            text = band & (np.mod(np.floor(pos[..., 0] * 9) + np.floor(pos[..., 2] * 9), 3) == 0) & (np.abs(pos[..., 0] + 0.2) < 1.4)
            col = np.where(text[..., None], np.array([20.0, 20, 20]), col)
        return col
    if region == "strap":                       # red velcro, a coarse grain
        g = 0.85 + 0.3 * np.mod(np.floor(pos[..., 0] * 18) + np.floor(pos[..., 1] * 18) + np.floor(pos[..., 2] * 18), 2)
        return RED * g[..., None]
    if region == "camera":
        return np.array([22.0, 22, 24]) * flat
    if region == "warhead":                     # drab olive, a yellow band by the nose, a stencil, worn edges
        col = OLIVE * flat
        band = (pos[..., 0] > 1.6) & (pos[..., 0] < 2.1)
        col = np.where(band[..., None], YELLOW * 0.8, col)
        sten = (pos[..., 0] > -1.2) & (pos[..., 0] < 0.6) & (np.abs(pos[..., 2] + 2.05) < 0.28) & (pos[..., 1] > 0.9) \
            & (np.mod(np.floor(pos[..., 0] * 8), 2) == 0)
        col = np.where(sten[..., None], np.array([22.0, 22, 18]), col)
        return np.where(edge < 0.05, col * 1.35, col)
    if region == "tail":
        return np.array([60.0, 62, 44]) * flat
    if region == "tape":                        # black electrical tape, a little shine
        return np.array([18.0, 18, 20]) * (1 + 0.25 * np.clip(ty, 0, 1))[..., None]
    if region == "tie":
        return np.array([214.0, 212, 200]) * flat
    if region == "prop":
        return np.array([38.0, 38, 40]) * flat
    if region == "stator":
        return np.array([28.0, 28, 30]) * flat
    if region == "bell":
        return np.array([70.0, 70, 76]) * flat
    if region == "standoff":
        return np.array([150.0, 150, 156]) * flat
    if region == "fuse":
        return np.array([128.0, 128, 132]) * flat
    if region == "lens":
        return np.array([16.0, 22, 34]) * flat
    if region == "antenna":
        return np.array([20.0, 20, 22]) * flat
    raise ValueError(region)


def bake(p, out_png, A=512, S=256):
    """Skin 0: each face's cell painted from its 3D surface, lit by a key light, darker underneath."""
    from PIL import Image
    img = np.zeros((A, A, 3))
    mask = np.zeros((A, A), bool)
    k = A / 256.0
    done = set()
    for (pts, region), cell, sh in zip(p.faces, p.cells, p.sheets):
        if sh != 0:
            continue
        if region in SHARED:
            if region in done:
                continue
            done.add(region)
        u0, v0, u1, v1 = cell
        P = np.array(pts)
        nrm = unit(np.cross(P[1] - P[0], P[-1] - P[0]))
        X0, Y0, X1, Y1 = int(u0 * k), int(v0 * k), int(u1 * k), int(v1 * k)
        xs, ys = np.meshgrid(np.arange(X0 - 2, X1 + 2), np.arange(Y0 - 2, Y1 + 2))
        sx = np.clip((xs + 0.5 - X0) / max(1, X1 - X0), 0, 1)
        ty = np.clip((Y1 - (ys + 0.5)) / max(1, Y1 - Y0), 0, 1)
        if len(P) == 4:
            pos = ((1 - sx) * (1 - ty))[..., None] * P[0] + (sx * (1 - ty))[..., None] * P[1] \
                + (sx * ty)[..., None] * P[2] + ((1 - sx) * ty)[..., None] * P[3]
        else:
            pos = P[0] + sx[..., None] * (P[1] - P[0]) + ty[..., None] * (P[2] - P[0])
        w, h = face_size(P)
        col = paint(region, pos, nrm, sx, ty, w, h)
        if region not in SHARED:
            light = 0.62 + 0.75 * (np.clip(float(nrm @ mech_bake.KEY), -1, 1) * 0.5 + 0.5) ** 2
            col = col * light * (0.82 + 0.18 * np.clip((pos[..., 2] + 3.5) / 7.5, 0, 1))[..., None]
        ok = (ys >= 0) & (ys < A) & (xs >= 0) & (xs < A)
        img[ys[ok], xs[ok]] = col[ok]
        mask[ys[ok], xs[ok]] = True
    img = mech_bake.bleed(img, mask, passes=4)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").resize((S, S), Image.LANCZOS)
    im.save(out_png)
    return im


def disc_skin(S=64):
    """The props' blur (additive: black is clear): faint at the hub, a soft ring toward the tips, a few streaks."""
    y, x = np.mgrid[0:S, 0:S]
    r = np.hypot(x + 0.5 - S / 2, y + 0.5 - S / 2) / (S / 2)
    a = np.arctan2(y + 0.5 - S / 2, x + 0.5 - S / 2)
    v = np.clip((r - 0.15) / 0.6, 0, 1) ** 1.5 * np.clip((1.0 - r) / 0.08, 0, 1)
    v = v * (0.8 + 0.2 * np.cos(4 * a)) * 46
    return np.repeat(v[..., None], 3, -1)


def solid(rgb, S=16):
    return np.ones((S, S, 3)) * np.array(rgb, float)


def frames(p):
    """The vertices in each of the props' FRAMES (each prop spun its own way about its motor), the game's frame."""
    V = np.array(p.verts, float)
    owner = []
    for f in range(len(p.faces)):
        owner += [p.groups[f]] * len(p.faces[f][0])
    owner = np.array(owner)
    out = []
    for fr in range(FRAMES):
        Q = V.copy()
        for k, (mx, my, way) in enumerate(MOTORS):
            m = owner == "prop%d" % k
            a = way * math.pi * fr / FRAMES
            dx, dy = Q[m, 0] - mx, Q[m, 1] - my
            Q[m, 0] = mx + dx * math.cos(a) - dy * math.sin(a)
            Q[m, 1] = my + dx * math.sin(a) + dy * math.cos(a)
        Q[:, 1] *= -1                       # into the game's frame: y to the right
        out.append(Q)
    return np.array(out)


def made():
    p = build()
    layout(p)
    finalize(p)
    return p


def write(out):
    """FPVDrone into out (Models, Textures) for tools/mech_parts.py; its import lines."""
    import mech_parts
    p = made()
    tex = os.path.join(out, "Textures")
    os.makedirs(tex, exist_ok=True)
    os.makedirs(os.path.join(out, "Models"), exist_ok=True)
    im = bake(p, os.path.join(tex, "FPVDrone.png"))
    mech_bake.save_pcx(np.asarray(im, float), os.path.join(tex, "FPVDrone.pcx"))
    mech_bake.save_pcx(disc_skin(), os.path.join(tex, "FPVDisc.pcx"))
    mech_bake.save_pcx(solid((255, 44, 30)), os.path.join(tex, "FPVLight.pcx"))
    mech_bake.save_pcx(solid((50, 255, 90)), os.path.join(tex, "FPVLightLead.pcx"))
    F = frames(p)
    tris = [(a, c, b, ua, uc, ub) for a, b, c, ua, ub, uc in p.tris]       # wound back for the mirror
    skins = [p.sheets[f] for f in p.tri_faces]
    types = [2 if p.faces[f][1] in TRANSLUCENT else 0 for f in p.tri_faces]
    mech_parts.write_d3d(os.path.join(out, "Models", "FPVDrone_d.3d"), F.shape[1], tris, skins, types)
    mech_parts.write_a3d(os.path.join(out, "Models", "FPVDrone_a.3d"), np.rint(F * 256).astype(np.int16))
    print("FPVDrone: %d verts, %d tris, %d frames" % (F.shape[1], len(tris), F.shape[0]))
    return ["",
            "// The FPV drones' own quad (tools/mech_drone.py; CoopFPV, CoopFPVGuided): the props spun in Fly.",
            "#exec TEXTURE IMPORT NAME=FPVDrone FILE=Textures\\FPVDrone.pcx GROUP=Skins",
            "#exec TEXTURE IMPORT NAME=FPVDisc FILE=Textures\\FPVDisc.pcx GROUP=Skins",
            "#exec TEXTURE IMPORT NAME=FPVLight FILE=Textures\\FPVLight.pcx GROUP=Skins",
            "#exec TEXTURE IMPORT NAME=FPVLightLead FILE=Textures\\FPVLightLead.pcx GROUP=Skins",
            "#exec MESH IMPORT MESH=FPVDrone ANIVFILE=Models\\FPVDrone_a.3d DATAFILE=Models\\FPVDrone_d.3d X=0 Y=0 Z=0 MLOD=0",
            "#exec MESH ORIGIN MESH=FPVDrone X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0",
            "#exec MESH SEQUENCE MESH=FPVDrone SEQ=All STARTFRAME=0 NUMFRAMES=%d RATE=60" % FRAMES,
            "#exec MESH SEQUENCE MESH=FPVDrone SEQ=Fly STARTFRAME=0 NUMFRAMES=%d RATE=60" % FRAMES,
            "#exec MESHMAP SCALE MESHMAP=FPVDrone X=0.00390625 Y=0.00390625 Z=0.00390625",
            "#exec MESHMAP SETTEXTURE MESHMAP=FPVDrone NUM=0 TEXTURE=FPVDrone",
            "#exec MESHMAP SETTEXTURE MESHMAP=FPVDrone NUM=1 TEXTURE=FPVDisc",
            "#exec MESHMAP SETTEXTURE MESHMAP=FPVDrone NUM=2 TEXTURE=FPVLight"]


def write_obj(p, path, V=None):
    """An OBJ (y as built) with its skin 0 for a look in Blender; the discs left out."""
    V = np.array(p.verts if V is None else V, float)
    mtl = path[:-4] + ".mtl"
    with open(mtl, "w") as f:
        f.write("newmtl skin\nKd 1 1 1\nmap_Kd FPVDrone.png\n")
    with open(path, "w") as f:
        f.write("mtllib %s\nusemtl skin\n" % os.path.basename(mtl))
        for v in V:
            f.write("v %.4f %.4f %.4f\n" % (v[0], v[2], -v[1]))
        n = 0
        for (a, b, c, ua, ub, uc), fi in zip(p.tris, p.tri_faces):
            if p.faces[fi][1] == "disc":
                continue
            for u in (ua, ub, uc):
                f.write("vt %.5f %.5f\n" % (u[0] / 256.0, 1 - u[1] / 256.0))
            f.write("f %d/%d %d/%d %d/%d\n" % (a + 1, n + 1, b + 1, n + 2, c + 1, n + 3))
            n += 3


def main():
    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "mech", "drone")
    os.makedirs(out, exist_ok=True)
    p = made()
    bake(p, os.path.join(out, "FPVDrone.png"))
    write_obj(p, os.path.join(out, "fpv_drone.obj"))
    V = np.array(p.verts)
    print("FPVDrone: %d faces, %d verts, %d tris; size x %.1f y %.1f z %.1f" % (
        len(p.faces), len(V), len(p.tris), *(V.max(0) - V.min(0))))


if __name__ == "__main__":
    main()
