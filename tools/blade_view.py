"""The arm blades as their owner sees them (CoopMechBlade), for each class: its blade arms (tools/blade_arms.py: ours,
built to be seen up close, painted for the class), posed in the view. The right arm leads from the lower right, its
blade toward the middle; the left waits lower in its corner. Drawn, both come up and the blades slide out of their
housings past the fists; three cuts (Attack: a slash from the right; Attack2: from the left; Attack3: a thrust with
both), each lasting as the combat knife's does with its HandToHandAttack notify at its middle, when it lands; put away,
the blades slide back in and the arms drop. The same blades others see on it slide out in steps (STAGES, staged).

Frames: the arm's (blade_arms: x from the elbow, y to its left, z up); the eye's (x ahead, y left, z up, the eye at the
origin); the view's (as mech_storm: X ahead, Y right, Z up, K view units to a game unit, 256 raw units to one).
"""
import math, os

import numpy as np

from mech_art import norm
import blade_arms
import mech_storm

K = mech_storm.K

# An arm's place and turn in the eye's frame, as seen from its own side: the elbow ahead, out to its side (lateral),
# up; pitch lifts the forearm, yaw turns it in towards the middle, roll turns its top (the blade's side) from up in
# towards the middle (degrees); ext: how far the blade is out (0 in its housing, 1 out).
GUARD = np.array([4.0, 9.0, -9.0, 22.0, 15.0, 18.0, 1.0])          # the right: the fist low right, the blade in
REST_L = np.array([4.0, 11.0, -12.0, 18.0, 12.0, 22.0, 1.0])         # the left: lower, out in its corner
LOW = np.array([2.0, 11.0, -22.0, -25.0, 8.0, 0.0, 0.0])


def ease(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def span(t, a, b):
    return ease((t - a) / (b - a))


def keys(t, ks):
    """The pose at t between key poses [(t0, pose0), (t1, pose1), ...], eased in each step."""
    for (t0, p0), (t1, p1) in zip(ks, ks[1:]):
        if t <= t1:
            return p0 + (p1 - p0) * span(t, t0, t1)
    return ks[-1][1]


def pose(base=GUARD, **kw):
    """base with some of its values changed (x, lateral, z, pitch, yaw, roll, ext)."""
    p = base.copy()
    for k, v in kw.items():
        p["x lateral z pitch yaw roll ext".split().index(k)] = v
    return p


def drawn(t, base):
    """Up from below; the blade slides out (a little past, then home: a jolt as it locks)."""
    p = LOW + (base - LOW) * span(t, 0.0, 0.5)
    p[6] = 1.07 * span(t, 0.4, 0.72) - 0.07 * span(t, 0.72, 1.0)
    p[0] -= 0.5 * math.sin(math.pi * span(t, 0.68, 0.9))
    return p


def put_away(t, base):
    p = base + (LOW - base) * span(t, 0.35, 1.0)
    p[6] = 1.0 - span(t, 0.0, 0.4)
    return p


def breathe(t, base, depth=1.0, phase=0.0):
    a = math.sin(2 * math.pi * t + phase)
    return pose(base, z=base[2] + 0.25 * depth * a, pitch=base[3] + 1.2 * depth * a)


# A slash from its own side across to the other (wound up out to its side, the blade's edge leading); the other arm
# drawn in; a thrust.
WIND = pose(x=2.5, lateral=13.0, z=-7.0, pitch=18, yaw=-28, roll=75)
THROUGH = pose(x=8.0, lateral=-1.0, z=-8.5, pitch=10, yaw=62, roll=75)
BRACED = pose(REST_L, x=6.0, z=-17.5, yaw=10)
PULLED = pose(x=1.5, pitch=18, yaw=10)
THRUST = pose(x=10.0, lateral=7.0, z=-8.0, pitch=10, yaw=10, roll=15)


def slash(t, base):
    return keys(t, [(0.0, base), (0.25, pose(WIND)), (0.62, pose(THROUGH)), (1.0, base)])


def other(t, base):
    return keys(t, [(0.0, base), (0.3, pose(base, x=base[0] - 2.0, z=base[2] - 4.5, yaw=base[4] - 6)), (1.0, base)])


def thrust(t, base):
    return keys(t, [(0.0, base), (0.3, pose(PULLED, lateral=base[1], z=base[2])), (0.55, pose(THRUST, lateral=base[1] - 3.0)), (1.0, base)])


# The sequences the knife's code plays (DeusExWeapon), lasting as the knife's do (its view model's: Select 0.43 s,
# Attack 0.36, Attack2 0.55, Attack3 0.4, Down 0.5); the cuts' notify at their middle, as the knife's.
# (name, frames, rate, poses of t in 0-1, notify time)
SEQS = [("Still", 1, 1, lambda t: {"r": GUARD, "l": REST_L}, None),
        ("Select", 13, 30, lambda t: {"r": drawn(t, GUARD), "l": drawn(t, REST_L)}, None),
        ("Down", 15, 30, lambda t: {"r": put_away(t, GUARD), "l": put_away(t, REST_L)}, None),
        ("Idle1", 12, 8, lambda t: {"r": breathe(t, GUARD), "l": breathe(t, REST_L, phase=0.6)}, None),
        ("Idle2", 16, 8, lambda t: {"r": pose(roll=GUARD[5] + 28 * math.sin(math.pi * t) ** 2, yaw=GUARD[4] + 4 * math.sin(math.pi * t)),
                                     "l": breathe(t, REST_L, 0.6)}, None),
        ("Idle3", 12, 8, lambda t: {"r": pose(yaw=GUARD[4] + 3 * math.sin(2 * math.pi * t)),
                                     "l": pose(REST_L, yaw=REST_L[4] - 3 * math.sin(2 * math.pi * t))}, None),
        ("Attack", 11, 30, lambda t: {"r": slash(t, GUARD), "l": other(t, REST_L)}, 0.5),
        ("Attack2", 16, 29, lambda t: {"r": other(t, GUARD), "l": slash(t, REST_L)}, 0.5),
        ("Attack3", 12, 30, lambda t: {"r": thrust(t, GUARD), "l": thrust(t, REST_L)}, 0.5)]


def placed(p, s):
    """A pose's arm frame in the eye's: (its axes as columns, the elbow). s: +1 the right arm, -1 the left."""
    x, lat, z, pitch, yaw, roll = p[:6]
    a, b, r = math.radians(pitch), math.radians(yaw) * s, math.radians(roll)
    d = np.array([math.cos(a) * math.cos(b), math.cos(a) * math.sin(b), math.sin(a)])
    up = norm(np.array([0.0, 0, 1]) - d[2] * d)
    inward = s * norm(np.cross(up, d))
    zz = math.cos(r) * up + math.sin(r) * inward
    return np.stack([d, np.cross(zz, d), zz], 1), np.array([x, -s * lat, z])


def view_mesh(p):
    """A class's view of its blades: (frames (n, verts, 3) in the view's frame, triangles, skins, sequences). p: the
    finalized blade arm (blade_arms.made); the right arm as built, the left its mirror; the blade group slides."""
    V, G, tris, skins = shared(p)
    blade = np.array([g == "blade" for g in G])
    sides = (("r", 1, V), ("l", -1, V * np.array([1.0, -1, 1])))
    frames = []
    for name, n, rate, f, _ in SEQS:
        for k in range(n):
            pp = f(k / max(1, n - 1))
            out = []
            for side, s, P in sides:
                Q = P.copy()
                ext = max(pp[side][6], 0.002)
                Q[blade, 0] = blade_arms.MOUTH + (Q[blade, 0] - blade_arms.MOUTH) * ext
                R, E = placed(pp[side], s)
                out.append((Q @ R.T + E) * np.array([K, -K, K]))
            frames.append(np.concatenate(out))
    # The right arm through one mirror (the view's), the left through two (its own and the view's).
    nv = len(V)
    vtris = [(a, c, b, ua, uc, ub) for a, b, c, ua, ub, uc in tris] + [(a + nv, b + nv, c + nv, ua, ub, uc) for a, b, c, ua, ub, uc in tris]
    return np.array(frames), vtris, skins + skins, seqs()


def shared(p, drop=()):
    """The finalized arm's vertices, each once where position, face and group agree (UVs are per triangle corner in
    a game mesh), their groups, its triangles and their skins; but not the faces of the regions in drop."""
    tr = [r for (pts, r) in p.faces for _ in range(len(pts) - 2)]
    ts = [s for (pts, _), s in zip(p.faces, p.sheets) for _ in range(len(pts) - 2)]
    vg = [g for (pts, _), g in zip(p.faces, p.groups) for _ in pts]
    V, G, index, tris, skins = [], [], {}, [], []
    for t, r, s in zip(p.tris, tr, ts):
        if r in drop:
            continue
        skins.append(s)
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
    return np.array(V), G, tris, skins


def seqs():
    out, start = [], 0
    for name, n, rate, _, notify in SEQS:
        out.append((name, start, n, rate, notify))
        start += n
    return out


def build(cls, art):
    """A class's view mesh (<cls>BladeView) and its skins (<cls>Arm1, 2) into the art folder; their import lines
    (the textures', imported before any mesh uses them: the arm cannon's view wears the Mech's too; the mesh's)."""
    from mech_bake import save_pcx
    p = blade_arms.made()
    texs = []
    for s in (0, 1):
        name = "%sArm%d" % (cls, s + 1)
        im = blade_arms.bake(p, cls, s, os.path.join(art, "Textures", name + ".png"))
        save_pcx(np.asarray(im, float), os.path.join(art, "Textures", name + ".pcx"))
        texs.append(name)
    frames, tris, skins, _ = view_mesh(p)
    from mech_parts import write_a3d, write_d3d
    name = cls + "BladeView"
    write_d3d(os.path.join(art, "Models", name + "_d.3d"), frames.shape[1], tris, skins)
    write_a3d(os.path.join(art, "Models", name + "_a.3d"), np.rint(frames * 256).astype(np.int16))
    print("%s: %d verts, %d tris, %d frames" % (name, frames.shape[1], len(tris), frames.shape[0]))
    return ["#exec TEXTURE IMPORT NAME=%s FILE=Textures\\%s.pcx GROUP=Skins" % (t, t) for t in texs], uc_lines(name, texs)


def uc_lines(name, texs):
    """The view mesh's import (in the view's frame, 256 raw units to one), the cuts' notifies."""
    total = sum(q[1] for q in SEQS)
    lines = ["#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (name, name, name),
             "#exec MESH ORIGIN MESH=%s X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0" % name,
             "#exec MESH SEQUENCE MESH=%s SEQ=All STARTFRAME=0 NUMFRAMES=%d RATE=30" % (name, total)]
    for seq, start, n, rate, notify in seqs():
        lines.append("#exec MESH SEQUENCE MESH=%s SEQ=%s STARTFRAME=%d NUMFRAMES=%d RATE=%g" % (name, seq, start, n, rate))
        if notify is not None:
            lines.append("#exec MESH NOTIFY MESH=%s SEQ=%s TIME=%g FUNCTION=HandToHandAttack" % (name, seq, notify))
    lines.append("#exec MESHMAP SCALE MESHMAP=%s X=0.00390625 Y=0.00390625 Z=0.00390625" % name)
    lines += ["#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=%d TEXTURE=%s" % (name, k, t) for k, t in enumerate(texs)]
    return lines + [""]


# On others' screens the blades slide out in steps (CoopMechParts.Stages): each step's mesh the parts with the blades
# this far out past the wrist.
STAGES = (0.35, 0.7)


def staged(P, e, w, ext):
    """A blade's points (the body's frame) with its part past the wrist ext of the way out, along the forearm."""
    ax = norm(w - e)
    wrist = float(np.linalg.norm(w - e))
    along = (np.asarray(P) - e) @ ax
    return np.asarray(P) + np.outer(np.where(along > wrist, (ext - 1) * (along - wrist), 0.0), ax)


def steel_texture(path, size=256):
    """Brushed steel, a bright edge along one side of each face (a blade's cell is the whole texture)."""
    from mech_bake import save_pcx
    v = np.arange(size)[:, None] / size
    rng = np.random.default_rng(7)
    streaks = rng.normal(0, 1, (1, size)).repeat(size, 0)
    base = 78 + 10 * streaks + 26 * (1 - v)
    edge = np.clip(1 - np.abs(v - 0.03) / 0.04, 0, 1)
    img = np.stack([base * 0.95, base, base * 1.06], -1) * (1 - edge[..., None]) + np.array([225.0, 230, 238]) * edge[..., None]
    save_pcx(np.clip(img, 0, 255), path)
