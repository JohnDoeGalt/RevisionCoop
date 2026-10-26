"""Revision-quality skins for the Mech's body (original art): every texel is painted from where it
lies on the body (its 3D point and normal in the standing frame): materials (generated swatches in
art/mech/materials) projected from three sides (arms: around the arm, so the synthetic muscle runs
along it), ambient occlusion baked from the body and the always-drawn parts, a soft key light, and
seams, stitches and wear drawn in body space.

  python -I tools/mech_bake.py <outdir> [preview.png]      BarrettSuit, BarrettLegs (512x512)
"""
import os, sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mech_art

REST = 32
S = 512
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MATS = os.path.join(HERE, "art", "mech", "materials")


def material(name, size=512, blur=1.2):
    """A swatch, softened to about the size of a skin texel (no moire where it is sampled)."""
    from PIL import ImageFilter
    im = Image.open(os.path.join(MATS, name + ".jpg")).convert("RGB").resize((size, size), Image.LANCZOS)
    return np.asarray(im.filter(ImageFilter.GaussianBlur(blur)), float)


def mirror(t, n):
    """Ping-pong wrap of texel coordinates (no seams between tiles)."""
    t = np.mod(t, 2 * n)
    return np.where(t >= n, 2 * n - 1 - t, t)


def tex(img, u, v):
    h, w, _ = img.shape
    return img[mirror(np.floor(v).astype(int), h), mirror(np.floor(u).astype(int), w)]


def triplanar(img, pos, nrm, scale, sharp=4.0):
    """img projected onto the body from three axes, blended by the normal (scale: texels per unit)."""
    w = np.abs(nrm) ** sharp
    w /= w.sum(-1, keepdims=True) + 1e-9
    x, y, z = pos[..., 0] * scale, pos[..., 1] * scale, pos[..., 2] * scale
    return (tex(img, y, -z) * w[..., 0:1] + tex(img, x, -z) * w[..., 1:2] + tex(img, x, y) * w[..., 2:3])


def vertex_normals(V, T):
    n = np.zeros_like(V)
    fn = np.cross(V[T[:, 1]] - V[T[:, 0]], V[T[:, 2]] - V[T[:, 0]])
    for k in range(3):
        np.add.at(n, T[:, k], fn)
    return n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)


def vertex_ao(V, N, occluders, rays=48, reach=9.0, seed=3):
    """Per vertex: the share of hemisphere rays (up to reach units) that escape the occluders."""
    rng = np.random.default_rng(seed)
    d = rng.normal(size=(rays, 3))
    d /= np.linalg.norm(d, axis=1, keepdims=True)
    A, B, C = occluders[:, 0], occluders[:, 1], occluders[:, 2]
    e1, e2 = B - A, C - A
    vis = np.zeros(len(V))
    for i in range(len(V)):
        dirs = d * np.sign(d @ N[i])[:, None]                  # into the hemisphere of the normal
        o = V[i] + N[i] * 0.15
        p = np.cross(dirs[:, None, :], e2[None])               # rays x tris
        det = (e1[None] * p).sum(-1)
        ok = np.abs(det) > 1e-9
        inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
        s = o - A
        u = (s[None] * p).sum(-1) * inv
        q = np.cross(s, e1)
        v = (dirs[:, None, :] * q[None]).sum(-1) * inv
        t = (e2 * q).sum(-1)[None] * inv
        hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0.02) & (t < reach)
        vis[i] = 1 - hit.any(1).mean()
    return vis


def raster(m, R, slot, vattr):
    """Per texel (S x S): body point, normal (smooth), interpolated vertex attribute, coverage."""
    sv = m["special_verts"]
    pos = np.zeros((S, S, 3))
    nrm = np.zeros((S, S, 3))
    att = np.zeros((S, S))
    mask = np.zeros((S, S), bool)
    VN = vattr["normals"]
    VA = vattr["ao"]
    for face in m["faces"]:
        if m["materials"][face[3]][1] != slot:
            continue
        w = [m["wedges"][k] for k in face[:3]]
        idx = [x[0] + sv for x in w]
        P = R[idx]
        uv = np.array([(x[1] * S / 256.0, x[2] * S / 256.0) for x in w])
        x0, y0 = np.floor(uv.min(0)).astype(int)
        x1, y1 = np.ceil(uv.max(0)).astype(int)
        xs, ys = np.meshgrid(np.arange(max(0, x0), min(S, x1 + 1)), np.arange(max(0, y0), min(S, y1 + 1)))
        px, py = xs + 0.5, ys + 0.5
        (ax, ay), (bx, by), (cx, cy) = uv
        den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(den) < 1e-9:
            continue
        l0 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
        l1 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
        l2 = 1 - l0 - l1
        inside = (l0 >= -0.03) & (l1 >= -0.03) & (l2 >= -0.03)
        yy, xx = ys[inside], xs[inside]
        L = np.stack([l0[inside], l1[inside], l2[inside]], -1)
        pos[yy, xx] = L @ P
        n = L @ VN[idx]
        nrm[yy, xx] = n / (np.linalg.norm(n, axis=1, keepdims=True) + 1e-9)
        att[yy, xx] = L @ VA[idx]
        mask[yy, xx] = True
    return pos, nrm, att, mask


def bleed(img, mask, passes=10):
    img, mask = img.copy(), mask.copy()
    for _ in range(passes):
        acc = np.zeros_like(img)
        cnt = np.zeros(mask.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sm = np.roll(mask, (dy, dx), (0, 1))
            si = np.roll(img, (dy, dx), (0, 1))
            add = sm & ~mask
            acc[add] += si[add]
            cnt[add] += 1
        fill = (cnt > 0) & ~mask
        img[fill] = acc[fill] / cnt[fill, None]
        mask = mask | fill
    return img


def line(d, width):
    """1 on a thin line where the signed distance d is near 0."""
    return np.clip(1 - np.abs(d) / width, 0, 1)


LIGHT = np.array([150.0, 205.0, 255.0])   # the suit's blue lights
KEY = np.array([0.25, -0.35, 0.9]) / np.linalg.norm([0.25, -0.35, 0.9])
HALF = np.array([0.35, -1.55, 0.9]) / np.linalg.norm([0.35, -1.55, 0.9])   # key and a front view


def unit(v):
    return v / (np.linalg.norm(v, axis=-1, keepdims=True) + 1e-9)


def mirrored(pos, nrm):
    """Points and normals folded into the body's right half: the skins share texels between the
    sides, so everything is painted (and lit) the same on both."""
    sgn = np.where(pos[..., 0] < 0, -1.0, 1.0)[..., None]
    f = np.concatenate([sgn, np.ones_like(sgn), np.ones_like(sgn)], -1)
    return pos * f, nrm * f


def _rand(g, seed):
    """Three floats in [0, 1) per integer lattice point (..., 3)."""
    g = g.astype(np.int64)
    h = (g[..., 0] * 73856093 + g[..., 1] * 19349663 + g[..., 2] * 83492791 + seed * 2654435) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return np.stack([h & 1023, (h >> 10) & 1023, (h >> 20) & 1023], -1) / 1024.0


def plates(q, cell, seed):
    """Voronoi plates in 3D (q: points (n, 3)): each point's distance to its plate's border, the
    direction to that border (unit) and a random value per plate."""
    q = q / cell
    g = np.floor(q)
    feats, cells = [], []
    best = np.full(len(q), np.inf)
    c1, k1 = np.zeros_like(q), np.zeros_like(q)
    for o in np.array(np.meshgrid((-1, 0, 1), (-1, 0, 1), (-1, 0, 1))).reshape(3, -1).T:
        f = g + o + 0.1 + 0.8 * _rand(g + o, seed)
        feats.append(f)
        d = ((q - f) ** 2).sum(-1)
        near = d < best
        best[near], c1[near], k1[near] = d[near], f[near], (g + o)[near]
    edge = np.full(len(q), np.inf)
    edir = np.zeros_like(q)
    for f in feats:
        v = f - c1
        L = np.linalg.norm(v, axis=-1)
        n = v / np.maximum(L, 1e-9)[:, None]
        e = np.where(L > 1e-6, (((c1 + f) / 2 - q) * n).sum(-1), np.inf)
        near = e < edge
        edge[near], edir[near] = e[near], n[near]
    return edge * cell, edir, _rand(k1, seed + 1)[:, 0]


def tilt(n, d, e, width, amount):
    """The normal tipped toward a plate's border within width of it: a bevel."""
    d = d - (d * n).sum(-1, keepdims=True) * n
    t = np.clip(1 - e / width, 0, 1) ** 1.5
    return unit(n + unit(d) * (t * amount)[:, None])


def lit(col, n, ao, gloss=110.0, power=30):
    """Colour under a soft key light (half-Lambert: what faces away stays readable; the game lights
    the model again), with baked occlusion and a gloss highlight."""
    lam = (np.clip(n @ KEY, -1, 1) * 0.5 + 0.5) ** 2
    occ = 0.5 + 0.5 * np.clip(ao, 0, 1) ** 1.3
    spec = np.clip(n @ HALF, 0, 1) ** power * gloss
    return (col * (0.55 + 0.6 * lam)[:, None] + spec[:, None] * np.array([0.85, 0.92, 1.0])) * occ[:, None]


COOL = np.array([0.88, 0.95, 1.08])        # the suit's blue-black
GUNMETAL = np.array([0.86, 0.95, 1.12])    # its accent plates and the armour pieces
OLIVE = np.array([1.0, 1.0, 0.84])         # the vest's warm olive-black


def nanosuit(pos, nrm, ao, base=44.0, big=3.2, fine=0.8, tint=COOL):
    """Per point (n, 3), body space: the suit's black plating, lit: large plates running along the
    body, each pillowed (it catches the key light across its face), a few gunmetal, finer segments
    in them, gloss."""
    q, n = mirrored(pos, nrm)
    s1, s2 = np.array([1.0, 1.0, 2.2]), np.array([1.0, 1.0, 1.25])
    e1, d1, v1 = plates(q / s1, big, 5)
    e2, d2, v2 = plates(q / s2, fine, 9)
    n = tilt(n, d1 / s1, e1, 0.9, 0.8)
    n = tilt(n, d2 / s2, e2, 0.1, 0.35)
    accent = v1 > 0.84
    tone = (base + 16 * (v1 - 0.5) + 6 * (v2 - 0.5)) * np.where(accent, 1.35, 1.0)
    col = tone[:, None] * np.where(accent[:, None], GUNMETAL, tint)
    col = col * (1 - 0.8 * line(e1, 0.07) - 0.3 * line(e2, 0.04))[:, None]
    return lit(col, n, ao)


def hex_edge(u, v, size):
    """Distance (in cells, 0 to 0.5) to the nearest edge of a hexagon grid in the plane (u, v)."""
    p = np.stack([u, v], -1) / size
    r = np.array([1.0, 1.7320508])
    a = np.mod(p, r) - r / 2
    b = np.mod(p - r / 2, r) - r / 2
    g = np.abs(np.where(((a * a).sum(-1) < (b * b).sum(-1))[:, None], a, b))
    return 0.5 - np.maximum(g @ np.array([0.5, 0.8660254]), g[:, 0])


def limb_plating(pos, nrm, ao, frame, base=42.0, size=0.95, panel=4.6, tint=COOL):
    """The suit on an arm or a leg (the sheet's segmented hex suit): hexagonal plates round it, each
    pillowed from its middle, a few gunmetal, in panels split by seams round the limb, gloss; in
    the folded (right) half. Where the hexes meet round the inside of the limb they may not line
    up (out of sight)."""
    along, ang, radius, a_hat, r_hat = frame
    _, n = mirrored(pos, nrm)
    t_hat = unit(np.cross(r_hat, a_hat))                     # round the limb, toward the back
    around = ang * np.maximum(radius, 1.0)
    p = np.stack([around, along], -1) / size
    r = np.array([1.0, 1.7320508])
    a = np.mod(p, r) - r / 2
    b = np.mod(p - r / 2, r) - r / 2
    g = np.where(((a * a).sum(-1) < (b * b).sum(-1))[:, None], a, b)      # from its hex's middle (cells)
    e = (0.5 - np.maximum(np.abs(g) @ np.array([0.5, 0.8660254]), np.abs(g[:, 0]))) * size
    n = unit(n + unit(g[:, 0:1] * t_hat + g[:, 1:2] * a_hat) * (np.clip(1 - e / (0.42 * size), 0, 1) ** 1.5 * 0.9)[:, None])
    pd = np.mod(along - panel / 2, panel)                    # the panel seams (off the line's ends), bevelled
    n = unit(n + a_hat * (np.where(pd > panel / 2, 1.0, -1.0) * np.clip(1 - np.minimum(pd, panel - pd) / 0.5, 0, 1) * 0.8)[:, None])
    v = _rand(np.floor((p - g) * 2 + 0.5).astype(np.int64)[:, [0, 1, 1]] * np.array([1, 1, 0]), 21)
    accent = v[:, 1] < 0.14
    tone = base * (0.84 + 0.32 * v[:, 0]) * np.where(accent, 1.45, 1.0)
    col = tone[:, None] * np.where(accent[:, None], GUNMETAL, tint)
    col = col * np.maximum(1 - 0.7 * line(e, 0.06) - 0.75 * line(np.minimum(pd, panel - pd), 0.09), 0.1)[:, None]
    return lit(col, n, ao)


def collar(pos, nrm, ao):
    """The armoured turtleneck: black ribs round the neck, each bevelled on top."""
    q, n = mirrored(pos, nrm)
    r = np.mod(q[:, 2] * 1.5, 1)                                   # 0 at a rib's bottom
    n = unit(n + np.array([0, 0, 1.0]) * np.clip((r - 0.7) / 0.3, 0, 1)[:, None] * 0.9
             - np.array([0, 0, 1.0]) * np.clip((0.25 - r) / 0.25, 0, 1)[:, None] * 0.6)
    col = np.full((len(q), 3), 40.0) * COOL
    col = col * (1 - 0.7 * (line(r, 0.08) + line(r - 1, 0.08)))[:, None]
    return lit(col, n, ao, gloss=90)


def cordura(mats, pos, nrm, ao, value=50.0, tint=OLIVE):
    """Matte nylon: the vest's olive-black (the belt's black)."""
    q, n = mirrored(pos, nrm)
    t = triplanar(mats["webbing"], q, n, 16).mean(-1)
    col = (t / 43.0 * value)[:, None] * tint
    lam = (np.clip(n @ KEY, -1, 1) * 0.5 + 0.5) ** 2
    occ = 0.5 + 0.5 * np.clip(ao, 0, 1) ** 1.3
    return col * ((0.6 + 0.55 * lam) * occ)[:, None]


def glow(img, d, core=0.2, halo=0.8):
    """A blue light strip where the distance d (units) is near 0: a bright core, a halo."""
    c = np.clip(1 - np.abs(d) / core, 0, 1) ** 0.5
    h = np.clip(1 - np.abs(d) / halo, 0, 1) ** 2 * 0.6
    img = img * (1 - h[:, None]) + (LIGHT * 0.6)[None, :] * h[:, None]
    return img * (1 - c[:, None]) + LIGHT[None, :] * c[:, None]


# The arms in the standing frame (game units: the centres of the body's arm vertices): over the
# shoulder (the upper arm's line carried on 4 units, so the shoulder cap has coordinates too),
# shoulder, elbow, wrist; +X the right arm. The elbows sit behind the line from shoulder to wrist.
def _over(s0, e, k=4.0):
    return s0 + (s0 - e) / np.linalg.norm(s0 - e) * k
_ARMS = {1: np.array([[14.0, 0.0, 24.0], [12.6, 0.3, 9.0], [10.8, -4.4, -3.4]]),
         -1: np.array([[-13.9, 1.5, 24.0], [-12.3, 2.6, 9.0], [-10.7, -3.1, -3.2]])}
ARMS = {s: np.vstack([_over(a[0], a[1]), a]) for s, a in _ARMS.items()}
SHOULDER = 4.0                                                   # along the arm: the shoulder joint
ELBOW = SHOULDER + float(np.linalg.norm(_ARMS[1][1] - _ARMS[1][0]))
# The legs (centres by height, from rays through the body): hip, knee, ankle. They splay out
# going down, the left a little more.
LEGS = {1: np.array([[5.4, -2.9, -6.0], [6.1, -2.9, -23.0], [6.8, 0.2, -42.0]]),
        -1: np.array([[-5.3, -3.0, -6.0], [-6.7, -3.2, -23.0], [-8.2, -0.2, -42.0]])}
KNEE = float(np.linalg.norm(LEGS[1][1] - LEGS[1][0]))
# The torso as one more limb: an upright centre line through it (the suit's hexes run round it).
TORSO = {1: np.array([[0.0, -1.0, 40.0], [0.0, -1.0, -8.0]]), -1: np.array([[0.0, -1.0, 40.0], [0.0, -1.0, -8.0]])}


def limb_frame(pos, limbs):
    """Per point on a limb (limbs: its centre line per side): the distance along it, the angle
    round it (0: the outside, +: toward the back, -pi/2: the front), the distance from the centre
    line, and the line's direction and the outward direction, folded into the right half."""
    n = len(pos)
    along, ang, radius = np.zeros(n), np.zeros(n), np.zeros(n)
    a_hat, r_hat = np.zeros((n, 3)), np.zeros((n, 3))
    for sign, pts in limbs.items():
        sel = np.sign(pos[:, 0]) == sign
        q = pos[sel]
        best = np.full(len(q), np.inf)
        al, rad, axis = np.zeros(len(q)), np.zeros((len(q), 3)), np.zeros((len(q), 3))
        start = 0.0
        for a0, a1 in zip(pts[:-1], pts[1:]):
            ax = a1 - a0
            L = np.linalg.norm(ax)
            t = np.clip(((q - a0) @ ax) / L ** 2, 0, 1)
            r = q - (a0 + t[:, None] * ax)
            d = np.linalg.norm(r, axis=1)
            near = d < best
            best[near], al[near], rad[near], axis[near] = d[near], start + t[near] * L, r[near], ax / L
            start += L
        f = np.array([sign, 1.0, 1.0])
        along[sel], radius[sel] = al, np.linalg.norm(rad, axis=1)
        ang[sel] = np.arctan2(rad[:, 1], rad[:, 0] * sign)
        a_hat[sel], r_hat[sel] = axis * f, unit(rad * f)
    return along, ang, radius, a_hat, r_hat


VEST_BOTTOM, VEST_SIDE, SPINE = 3.4, 9.8, 1.7


def vest_edge(x, y, z):
    """Signed distance (units) inside the vest's outline on the torso (< 0: outside it)."""
    ax, back = np.abs(x), y > -0.5
    top = np.where(ax < 3.3, np.where(back, 27.6, 28.7), np.where(ax < 7.2, 40.0, 21.5))
    d = np.minimum(np.minimum(z - VEST_BOTTOM, top - z), VEST_SIDE - ax)
    d = np.where((ax >= 3.3) & (ax < 7.2), np.minimum(d, np.minimum(ax - 3.3, 7.2 - ax) + (top - z > 4) * 9), d)
    return np.where(back, np.minimum(d, ax - SPINE), d)


def paint_vest(mats, pos, nrm, ao, d):
    """The tactical vest: cordura, MOLLE rows with bartacks, binding round its edge."""
    x, y, z = pos[:, 0], pos[:, 1], pos[:, 2]
    ax = np.abs(x)
    col = cordura(mats, pos, nrm, ao)
    molle = (z > 5.0) & (z < 16.5)
    r = np.mod((z - 5.0) / 1.05, 1)
    band = molle & (r < 0.55)
    col = np.where(band[:, None], col * 1.2, col)
    col = col * (1 - 0.65 * (molle * line(r - 0.58, 0.08)))[:, None]             # under each row
    tack = band & (np.abs(np.mod(ax / 1.5, 1) - 0.5) < 0.04)
    col = np.where(tack[:, None], col * 0.55, col)
    col = np.where((d < 0.35)[:, None], col * 1.3, col)                            # the binding
    col = col * (1 - 0.5 * line(d - 0.42, 0.05) * (np.mod((x + z) * 2.2, 1) < 0.6))[:, None]
    col = col * (1 - 0.75 * line(d, 0.09))[:, None]
    return col


def bake_suit(m, R, va, mats):
    """Slot 0: torso and arms: the nanosuit under the vest, the collar, the spine interface, the
    belt, blue lights down the arms."""
    pos, nrm, ao, mask = raster(m, R, 0, va)
    img = np.zeros((S, S, 3))
    P, N, A = pos[mask], nrm[mask], ao[mask]
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    ax = np.abs(x)
    col = limb_plating(P, N, A, limb_frame(P, TORSO), size=1.05)
    arm = ax > 10.5
    # Arms: plates in rows round them, elbow and wrist bands, lights down the outside.
    frame = limb_frame(P[arm], ARMS)
    along, ang = frame[0], frame[1]
    ac = limb_plating(P[arm], N[arm], A[arm], frame)
    # The shoulder armour (the sheet's layered plates): gunmetal bands over the outside of the
    # deltoid, the upper over the lower, a bevelled border.
    sh = (along < SHOULDER + 6.0) & (np.abs(ang) < 2.0)
    fs = tuple(f[sh] for f in frame)
    ac[sh] = limb_plating(P[arm][sh], N[arm][sh], A[arm][sh], fs, base=58.0, size=0.7, panel=3.3, tint=GUNMETAL)
    rim = np.minimum((2.0 - np.abs(ang[sh])) * frame[2][sh], SHOULDER + 6.0 - along[sh])
    ac[sh] = ac[sh] * (1 - 0.75 * line(rim, 0.12))[:, None]
    for c, w in ((ELBOW, 0.7), (SHOULDER + 23.2, 0.5)):
        band = np.abs(along - c) < w
        ac = np.where(band[:, None], ac * 0.7, ac)
        ac = ac * (1 - 0.6 * (line(along - c - w, 0.08) + line(along - c + w, 0.08)))[:, None]
    strip = ((along > SHOULDER + 6.6) & (along < SHOULDER + 13.6)) | ((along > SHOULDER + 16.8) & (along < SHOULDER + 22.2))
    ac[strip] = glow(ac[strip], ang[strip] * frame[2][strip], core=0.2, halo=0.75)
    col[arm] = ac
    # Torso: the vest over the suit, the spine channel at the back.
    d = vest_edge(x, y, z)
    vest = ~arm & (d > 0) & (z < 28.6)
    col[vest] = paint_vest(mats, P[vest], N[vest], A[vest], d[vest])
    back = ~arm & (y > -0.5)
    spine = back & (ax < SPINE) & (z > VEST_BOTTOM) & (z < 28.6)
    seg = np.mod(z[spine] / 1.5, 1)
    sn = unit(N[spine] + np.array([0, 0, 1.0]) * np.clip((seg - 0.75) / 0.25, 0, 1)[:, None])
    sc = np.full((spine.sum(), 3), 58.0) * GUNMETAL * (1 - 0.7 * line(seg, 0.08))[:, None]
    col[spine] = lit(sc, sn, A[spine], gloss=140)
    run = back & (z > 6) & (z < 23.0) & (ax < 0.9)
    col[run] = glow(col[run], ax[run], core=0.22, halo=0.9)
    ring = back & (np.abs(np.hypot(x, z - 24.4) - 1.25) < 0.7) & (ax < 2.2)
    col[ring] = glow(col[ring], np.abs(np.hypot(x[ring], z[ring] - 24.4) - 1.25), core=0.18, halo=0.6)
    # The collar round the neck's base only (the shoulders stay plated), the belt.
    neck = ~arm & (z > 28.0) & ((x / 4.6) ** 2 + ((y + 1.2) / 5.6) ** 2 < 1)
    col[neck] = collar(P[neck], N[neck], A[neck])
    belt = ~arm & (z < 3.2) & (z > 0.4) & (ax < 10.6)
    col[belt] = cordura(mats, P[belt], N[belt], A[belt], value=32, tint=COOL)
    col = col * (1 - 0.6 * ((ax < 10.6) * (line(z - 3.2, 0.08) + line(z - 0.4, 0.08))))[:, None]
    buckle = belt & (ax < 1.2) & (y < 0)
    col[buckle] = lit(np.full((buckle.sum(), 3), 96.0) * GUNMETAL, N[buckle], A[buckle], gloss=180)
    img[mask] = col
    return np.clip(bleed(img, mask), 0, 255)


def bake_legs(m, R, va, mats):
    """Slot 1: the hips, the legs plated in rows round them (a flex band behind each knee), blue
    lights down the outer thighs and the shins, combat boots."""
    pos, nrm, ao, mask = raster(m, R, 1, va)
    img = np.zeros((S, S, 3))
    P, N, A = pos[mask], nrm[mask], ao[mask]
    z = P[:, 2]
    col = limb_plating(P, N, A, limb_frame(P, TORSO), size=1.05)           # the hips
    frame = limb_frame(P, LEGS)
    along, ang, radius = frame[0], frame[1], frame[2]
    leg = z < -6
    col[leg] = limb_plating(P[leg], N[leg], A[leg], tuple(f[leg] for f in frame))
    flex = leg & (np.abs(along - KNEE) < 1.4) & (ang > 0.8)               # behind the knee
    rib = np.mod(along[flex] * 2.6, 1)
    col[flex] = cordura(mats, P[flex], N[flex], A[flex], value=30, tint=COOL) * (1 - 0.5 * line(rib, 0.2))[:, None]
    thigh = leg & (along > 2.5) & (along < 14.0)
    col[thigh] = glow(col[thigh], ang[thigh] * radius[thigh], core=0.18, halo=0.7)
    shin = (along > KNEE + 4.5) & (along < KNEE + 15.5)
    col[shin] = glow(col[shin], (ang[shin] + np.pi / 2) * radius[shin], core=0.17, halo=0.6)
    # Boots: black leather, a padded top, a grey rubber sole, laces down the front.
    boot = z < -41.5
    q, n = mirrored(P[boot], N[boot])
    lea = triplanar(mats["leather"], q, n, 14) * 1.25 + 4
    lea = np.where((z[boot] > -42.6)[:, None], lea * 0.8, lea)
    lea = np.where((z[boot] < -47.0)[:, None], np.full_like(lea, 48.0), lea)
    col[boot] = lit(lea, n, A[boot], gloss=60, power=18)
    col = col * (1 - 0.6 * (line(z + 41.5, 0.12) + line(z + 42.6, 0.08) + line(z + 47.0, 0.12)))[:, None]
    lace = boot & (z > -46.5) & (z < -43) & (np.mod(z * 2.2, 1) < 0.45) & (np.abs(ang + np.pi / 2) * radius < 0.9)
    col[lace] = col[lace] * 0.45 + 16
    img[mask] = col
    return np.clip(bleed(img, mask), 0, 255)


def body_attributes(m, R, extra_tris):
    """Vertex normals and occlusion of the body (occluded by itself and the parts)."""
    sv = m["special_verts"]
    T = np.array([[m["wedges"][k][0] + sv for k in f[:3]] for f in m["faces"]])
    N = vertex_normals(R, T)
    occ = np.concatenate([R[T], extra_tris]) if len(extra_tris) else R[T]
    return dict(normals=N, ao=vertex_ao(R, N, occ))


def save_pcx(img, path):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(path)
    return im


def parts_tris(art):
    """The always-drawn parts' triangles in the standing frame (art/BarrettParts_rest.obj)."""
    p = os.path.join(art, "BarrettParts_rest.obj")
    V, T = [], []
    for l in open(p):
        if l.startswith("v "):
            V.append([float(a) for a in l.split()[1:4]])
        elif l.startswith("f "):
            T.append([int(a) - 1 for a in l.split()[1:4]])
    V = np.array(V)
    return V[np.array(T)]


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    pkg, m = mech_art.load_body()
    R = mech_art.game_frames(pkg, m)[REST]
    art = os.path.join(HERE, "build", "mech", "art")
    va = body_attributes(m, R, parts_tris(art))
    mats = {k: material(k) for k in ("leather", "webbing")}
    suit = save_pcx(bake_suit(m, R, va, mats), os.path.join(out, "BarrettSuit.pcx"))
    legs = save_pcx(bake_legs(m, R, va, mats), os.path.join(out, "BarrettLegs.pcx"))
    np.save(os.path.join(art, "body_ao.npy"), va["ao"])
    if len(sys.argv) > 2:
        prev = Image.new("RGB", (S * 2 + 8, S), "white")
        prev.paste(suit, (0, 0))
        prev.paste(legs, (S + 8, 0))
        prev.save(sys.argv[2])
    print("wrote BarrettSuit.pcx, BarrettLegs.pcx (%dx%d) in %s" % (S, S, out))


if __name__ == "__main__":
    main()
