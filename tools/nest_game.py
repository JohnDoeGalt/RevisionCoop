"""The Corvane nests' pieces as the game's meshes (plan docs/superpowers/plans/2026-11-04-kit-nests.md, Task 1), built by
tools/nest_riffs.py's functions. Their skins are the game's own textures by reference (the actors' MultiSkins: Revision's
RevTex panels, the base game's metals, as tools/nest_skin.py chose them), each face split at its texture's repeats so its
byte UVs cover one repeat, so no texture of the game's is shipped; only our own art (the nameplates, rubber, copper, the
Burr's skin) goes into RevNetMech. The bio cells are the game's own BioCell, placed as decorations (nests.json "cells");
a kit's place is "kits" (the kit's middle, as the FK-7's mesh is made about).

  game(out): the meshes (out/Models), our textures (out/Textures), out/nests.json; returns the #exec lines.
  python -I tools/nest_game.py preview <outdir>: each piece back as OBJ with its split faces (for tools/flykit_render.py).
"""
import json, math, os, sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import flykit, mech_bake, mech_parts
import nest_riffs as R
import nest_skin as S
import sensor_concept as SC
from mech_parts import Part

M = np.diag([1.0, -1.0, 1.0])                          # the tools' frame to the game's (y to the right)
GLOW = 0.55                                             # the actors' ScaleGlow (the user: "the colors are too bright")


def ref(region):
    """A region's skin: the game's own texture ("Package.Texture"), or ours ("RevNetMech.<Name>"). (In the game the
    lighter panels share the hull's: a mesh has 8 skins, the Trellis's box would need 9.)"""
    region = {"panel": "hull", "page2": "page", "band": "duct"}.get(region, region)
    if region.startswith("face:"):
        for pkg in S.FACES:
            try:
                S.game_texture(pkg, region[5:])
                return "%s.%s" % (os.path.basename(pkg), region[5:])
            except Exception:
                continue
    if region in S.SOURCES:
        return "%s.%s" % (os.path.basename(S.SOURCES[region][0]), S.SOURCES[region][1])
    if region in S.WHOLE:
        return "%s.%s" % (os.path.basename(S.WHOLE[region][0]), S.WHOLE[region][1])
    if region.startswith("plate:"):
        return "RevNetMech.NestPlate" + "".join(w.capitalize() for w in S.slug(region[6:]).split("_"))
    return "RevNetMech.Nest" + region.capitalize()


def clip(poly, k, value, keep_ge):
    """poly [(position, uv)] kept where uv[k] >= value (keep_ge) or <= value."""
    out, sg = [], 1.0 if keep_ge else -1.0
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        da, db = (a[1][k] - value) * sg, (b[1][k] - value) * sg
        if da >= 0:
            out.append(a)
        if (da >= 0) != (db >= 0):
            t = da / (da - db)
            out.append((a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1])))
    return out


def split(P, region):
    """A face's pieces, each inside one repeat of its texture: [[(position, uv in 0..1)]]."""
    P = np.asarray(P, float)
    uv = np.array(S.face_uv(P, region), float)
    poly = [(P[i], uv[i]) for i in range(len(P))]
    if S.whole(region):
        return [poly]
    out = []
    for i in range(int(math.floor(uv[:, 0].min() + 1e-6)), int(math.ceil(uv[:, 0].max() - 1e-6))):
        pu = clip(clip(poly, 0, i, True), 0, i + 1, False)
        if len(pu) < 3:
            continue
        for j in range(int(math.floor(uv[:, 1].min() + 1e-6)), int(math.ceil(uv[:, 1].max() - 1e-6))):
            pv = clip(clip(pu, 1, j, True), 1, j + 1, False)
            if len(pv) < 3:
                continue
            Q = np.array([q for q, _ in pv])
            if np.linalg.norm(np.cross(Q[1] - Q[0], Q[-1] - Q[0])) < 1e-6 and len(pv) == 3:
                continue
            out.append([(q, w - [i, j]) for q, w in pv])
    return out or [poly]


def ue_rot(W):
    """A turn (columns: the mesh's own x, y, z in the game's frame) as the game's pitch, yaw, roll (65536 a turn)."""
    X, Yv, Zv = W[:, 0], W[:, 1], W[:, 2]
    pitch, yaw, roll = math.asin(float(np.clip(X[2], -1, 1))), math.atan2(X[1], X[0]), math.atan2(-Yv[2], Zv[2])
    return [int(round(a * 32768 / math.pi)) for a in (pitch, yaw, roll)]


_cell0 = []


def cell_offset():
    """The game's BioCell's middle, from its own origin, in the game's frame (payload centres it; the game doesn't)."""
    if not _cell0:
        flykit.PACKAGES["DeusExItems"] = os.path.join(flykit.REV, "System", "DeusExItems.u")
        pkg = flykit.package("DeusExItems")
        m = pkg.read_mesh("BioCell")
        F = (np.array(pkg.frames(m)[0], float) - np.array(m["origin"])) * np.array(m["scale"])
        _cell0.append((F.max(0) + F.min(0)) / 2)
    return _cell0[0]


# ---- the pieces: (builder (part, cells) -> kits [(position, yaw)], pivot in the tools' frame) -------------------------
def _perch(p, c):
    return R.pad(p, c, (0, 0, 0))


def _trellis_box(p, c):
    R.frame(p, c, (0, 0, 0))
    return [(R.held(p, (0, 0, 0)), 0.0)]


def _shutter(p, c):
    for z in np.arange(R.SILL + 1.1, R.LH - 2.7, 1.25):
        R.bx(p, [R.LD / 2 - 0.3, 0, z], (0.5, R.LW - 2.0, 1.1), "panel")
    return []


def _quiver_box(p, c):
    R.frame(p, c, (0, 0, 0), True)
    return [(np.array([1.5, 0, 8.3]), 0.0)]


def _quiver_arm(p, c):
    T = np.array([1.5, 0, 8.3]) + R.TAILP
    R.gimbal(p, [-R.VD / 2 + 1.5, 0, T[2]], T)
    return []


def _lid(p, c):
    lid, lc = R.case_lid((0, 0, 0))
    p.faces += lid.faces
    c += lc
    return []


def _base(p, c):
    q, qc = Part("case"), []
    ks = R.case(q, qc, (0, 0, 0), open_=False)
    lid, _ = R.case_lid((0, 0, 0))
    n = len(lid.faces)
    p.faces += q.faces[:len(q.faces) - n]               # (the case closed, less its lid)
    return [(R.sit(np.array([0, s * 9.2, R.CB - 3.0])), 0.0) for s in (1, -1)]


PIECES = {
    "CorvanePerch": (_perch, (0, 0, 0)),
    "CorvaneTrellisBox": (_trellis_box, (0, 0, 0)),
    "CorvaneTrellisCells": (lambda p, c: R.frame_power(p, c, (0, 0, 0), 1) or [], (0, 0, 0)),
    "CorvaneFeet": (lambda p, c: R.feet(p, (0, 0, 0), R.BW) or [], (0, 0, 0)),
    "CorvaneWardenBody": (lambda p, c: R.locker(p, c, (0, 0, 0), True), (0, 0, 0)),
    "CorvaneWardenShutter": (_shutter, (R.LD / 2 - 0.3, 0, R.SILL + 1.1)),
    "CorvaneQuiverBox": (_quiver_box, (0, 0, 0)),
    "CorvaneQuiverArm": (_quiver_arm, None),            # (its shoulder: set from the kit's tail)
    "CorvaneQuiverCap": (lambda p, c: R.cap(p, np.zeros(3), "closed") or [], (-R.VD / 2, 0, 0.6)),
    "CorvaneQuiverBank": (lambda p, c: R.armoured_power(p, c, (0, 0, 0), 3) or [], (0, 0, 0)),
    "CorvaneQuiverFloor": (lambda p, c: R.bx(p, (0, 0, 0.3), (R.VD - 1.2, R.BW - 1.2, 0.6), "duct") or [], (0, 0, 0)),
    "CorvaneValiseBase": (_base, (0, 0, 0)),
    "CorvaneValiseLid": (_lid, (-R.CX / 2, 0, R.CB)),
    "CorvaneValiseLegs": (lambda p, c: R.case_legs(p, (0, 0, 0), 20.0) or [], (0, 0, 20.0)),
    "CorvaneArgusTier": (lambda p, c: R.carousel_tier(p, c, (0, 0, 0), R.ANG6), (0, 0, 0)),
    "CorvaneArgusTripod": (lambda p, c: R.tripod(p, (0, 0, 0)) or [], (0, 0, 0)),
    "CorvaneBurr": (None, None),                        # (tools/sensor_concept.py's D1, its own skin)
}


def setup(work):
    """The kit's size and tail into nest_riffs (as its build does)."""
    st, R.LO, R.HI = R.kit_obj(work)
    P = np.array([q for pts, r in st["p"].faces for q in pts if r != "blur"])
    x0 = P[:, 0].min()
    R.TAILP = np.array([x0, 0.0, P[P[:, 0] < x0 + 0.6][:, 2].mean()])


def built(name):
    """A piece's part (in the tools' frame, about its pivot), its cells [(R, t)], its kits [(position, yaw)]."""
    fn, pivot = PIECES[name]
    p, c = Part(name), []
    kits = fn(p, c)
    if pivot is None:                                   # the Quiver's arm: about its shoulder
        T = np.array([1.5, 0, 8.3]) + R.TAILP
        pivot = (-R.VD / 2 + 1.5, 0, T[2])
    pv = np.asarray(pivot, float)
    p.faces = [([np.asarray(q, float) - pv for q in pts], r) for pts, r in p.faces]
    return p, [(Rc, np.asarray(tc) - pv) for Rc, tc in c], [(np.asarray(k[0], float) - pv, k[1]) for k in kits]


def own_textures(regions, tex):
    """Our own skins (rubber, copper, the red key, the nameplates) as PCX in tex: their names."""
    from PIL import Image
    names = {}
    for r in regions:
        rf = ref(r)
        if not rf.startswith("RevNetMech."):
            continue
        nm = rf.split(".", 1)[1]
        if nm not in names.values():
            png = S.region_png(tex, r)
            mech_bake.save_pcx(np.asarray(Image.open(png).convert("RGB"), float), os.path.join(tex, nm + ".pcx"))
        names[r] = nm
    return names


def mesh_lines(name, verts, tris, skins, own, out):
    """The mesh's files and its #exec lines (one frame; our own skins set on the mesh, the game's left to MultiSkins)."""
    Q = np.array(verts, float) @ M.T
    mech_parts.write_d3d(os.path.join(out, "Models", name + "_d.3d"), len(Q), [t[:6] for t in tris], [t[6] for t in tris],
                         [0] * len(tris))
    mech_parts.write_a3d(os.path.join(out, "Models", name + "_a.3d"), np.rint(Q[None] * 256).astype(np.int16))
    lines = ["#exec MESH IMPORT MESH=%s ANIVFILE=Models\\%s_a.3d DATAFILE=Models\\%s_d.3d X=0 Y=0 Z=0 MLOD=0" % (name, name, name),
             "#exec MESH ORIGIN MESH=%s X=0 Y=0 Z=0 PITCH=0 YAW=0 ROLL=0" % name,
             "#exec MESH SEQUENCE MESH=%s SEQ=All STARTFRAME=0 NUMFRAMES=1" % name,
             "#exec MESHMAP SCALE MESHMAP=%s X=0.00390625 Y=0.00390625 Z=0.00390625" % name]
    lines += ["#exec MESHMAP SETTEXTURE MESHMAP=%s NUM=%d TEXTURE=%s" % (name, k, own[k]) for k in sorted(own)]
    print("%s: %d verts, %d tris, %d skins" % (name, len(Q), len(tris), len(skins)))
    return lines


def piece(name, out, tex):
    """A nest piece's mesh: its #exec lines and its nests.json entry."""
    p, cells, kits = built(name)
    regions = sorted({r for _, r in p.faces})
    skins = []
    for r in regions:
        if ref(r) not in skins:
            skins.append(ref(r))
    assert len(skins) <= 8, (name, skins)
    names = own_textures(regions, tex)
    verts, tris = [], []
    for pts, r in p.faces:
        k = skins.index(ref(r))
        for poly in split(pts, r):
            i = len(verts)
            verts += [q for q, _ in poly]
            uv = [(int(np.clip(round(w[0] * 255), 0, 255)), int(np.clip(round((1 - w[1]) * 255), 0, 255))) for _, w in poly]
            for a in range(1, len(poly) - 1):
                tris.append((i, i + a + 1, i + a, uv[0], uv[a + 1], uv[a], k))     # (wound back for the mirror)
    own = {skins.index(ref(r)): names[r] for r in names}
    lines = mesh_lines(name, verts, [(a, b, c, ua, ub, uc) + (k,) for a, b, c, ua, ub, uc, k in tris], skins, own, out)
    c0 = cell_offset()
    cj = []
    for Rc, tc in cells:
        W = M @ np.asarray(Rc) @ M
        loc = M @ np.asarray(tc) - W @ c0
        cj.append([round(float(x), 3) for x in loc] + ue_rot(W))
    kj = [[round(float(x), 3) for x in M @ k[0]] + [round(-float(k[1]), 1)] for k in kits]
    return lines, dict(kits=kj, cells=cj, skins=skins, glow=0.5 if "page" in regions else GLOW)


def burr(out, tex):
    """The SP-2 Burr: tools/sensor_concept.py's D1, its own painted skin."""
    from PIL import Image
    p, B, dc, dr = SC.d_body("D1")
    geo = dict(B=B, r=1.8 * SC.R20, dc=dc, dr=dr, mid=B / 2, seams=(2.35, 5.05))
    SC.layout_one(p)
    png = os.path.join(tex, "CorvaneBurrSkin.png")
    SC.bake_sensor(p, geo, png)
    mech_bake.save_pcx(np.asarray(Image.open(png).convert("RGB"), float), os.path.join(tex, "CorvaneBurrSkin.pcx"))
    pv = np.array([0, 0, B / 2])
    verts, tris = [], []
    for (pts, r), (u0, v0, u1, v1) in zip(p.faces, p.cells):
        i = len(verts)
        verts += [np.asarray(q, float) - pv for q in pts]
        uv = [(u0, v1), (u1, v1), (u1, v0), (u0, v0)] if len(pts) == 4 else [(u0, v1), (u1, v1), (u0, v0)]
        uv = [(int(round(a)), int(round(b))) for a, b in uv]
        for a, b, c in ([(0, 1, 2)] if len(pts) == 3 else [(0, 1, 2), (0, 2, 3)]):
            tris.append((i + a, i + c, i + b, uv[a], uv[c], uv[b], 0))
    lines = ["#exec TEXTURE IMPORT NAME=CorvaneBurrSkin FILE=Textures\\CorvaneBurrSkin.pcx GROUP=Skins"]
    lines += mesh_lines("CorvaneBurr", verts, tris, ["RevNetMech.CorvaneBurrSkin"], {0: "CorvaneBurrSkin"}, out)
    return lines, dict(kits=[], cells=[], skins=["RevNetMech.CorvaneBurrSkin"], glow=1.0)


def game(out):
    tex = os.path.join(out, "Textures")
    os.makedirs(tex, exist_ok=True)
    os.makedirs(os.path.join(out, "Models"), exist_ok=True)
    work = os.path.join(out, "nests")
    os.makedirs(work, exist_ok=True)
    setup(work)
    lines, J = ["", "// The Corvane kit nests (tools/nest_game.py, the user's designs): skins the game's own, by MultiSkins."], {}
    for name in PIECES:
        l, J[name] = burr(out, tex) if name == "CorvaneBurr" else piece(name, out, tex)
        lines += l
    imported = sorted({s.split(".", 1)[1] for e in J.values() for s in e["skins"] if s.startswith("RevNetMech.") and s != "RevNetMech.CorvaneBurrSkin"})
    lines[2:2] = ["#exec TEXTURE IMPORT NAME=%s FILE=Textures\\%s.pcx GROUP=Skins" % (n, n) for n in imported]
    json.dump(J, open(os.path.join(out, "nests.json"), "w"), indent=1)
    return lines


def preview(out):
    """Each piece back as OBJ (tools' frame) with its split faces, the regions' textures as nest_skin makes them."""
    os.makedirs(out, exist_ok=True)
    setup(out)
    for name in PIECES:
        if name == "CorvaneBurr":
            continue
        p, _, _ = built(name)
        path = os.path.join(out, name + ".obj")
        with open(path[:-4] + ".mtl", "w") as f:
            for r in sorted({r for _, r in p.faces}):
                f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s\n\n" % (S.slug(r), os.path.basename(S.region_png(out, r))))
        with open(path, "w") as f:
            f.write("mtllib %s.mtl\n" % name)
            n = 0
            for pts, r in p.faces:
                for poly in split(pts, r):
                    for q, _ in poly:
                        f.write("v %.4f %.4f %.4f\n" % (q[0], q[2], -q[1]))
                    for _, w in poly:
                        f.write("vt %.5f %.5f\n" % (w[0], w[1]))
                    f.write("usemtl %s\nf %s\n" % (S.slug(r), " ".join("%d/%d" % (n + k + 1, n + k + 1) for k in range(len(poly)))))
                    n += len(poly)
        print(path)


# Each nest class (CoopNest's defaults): its mesh; whose kits and cells (and where from: an offset, or a part they ride);
# its parts (attached pieces: mesh, place); numbers of its own. Places in the game's frame from the class's pivot.
TH = R.TH + 0.5                                         # a Quiver box's height, stacked
CLASSES = {
    "CoopNestPerch": dict(mesh="CorvanePerch"),
    "CoopNestTrellis": dict(mesh="CorvaneTrellisBox"),
    "CoopNestTrellisCells": dict(mesh="CorvaneTrellisCells"),
    "CoopNestQuiverCells": dict(mesh="CorvaneQuiverBank"),
    "CoopNestQuiver": dict(mesh="CorvaneQuiverBox", parts=[("CorvaneQuiverFloor", None), ("CorvaneQuiverCap", None), ("CorvaneQuiverArm", None)],
                           extra=dict(BoxHeight=TH)),
    "CoopNestWarden": dict(mesh="CorvaneWardenBody", parts=[("CorvaneWardenShutter", None)]),
    "CoopNestArgus": dict(mesh="CorvaneArgusTripod", places="CorvaneArgusTier", offset=(0, 0, 10.0),
                          parts=[("CorvaneArgusTier", (0, 0, 10.0))], extra=dict(TierHeight=R.TT)),
    "CoopNestValise": dict(mesh="CorvaneValiseBase", cells="CorvaneValiseLid", parts=[("CorvaneValiseLid", None)]),
}


def pivot(piece):
    """A piece's pivot in the tools' frame (the Quiver's arm: its shoulder)."""
    fn, pv = PIECES[piece]
    if pv is None:
        T = np.array([1.5, 0, 8.3]) + R.TAILP
        pv = (-R.VD / 2 + 1.5, 0, T[2])
    return np.asarray(pv, float)


def props(art):
    """Each nest class's defaults between its "// nest_game: begin" and "end" lines, from art/nests.json."""
    setup(os.path.join(art, "nests"))
    J = json.load(open(os.path.join(art, "nests.json")))
    src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "RevNet", "Classes")
    vec = lambda v: "(X=%.3f,Y=%.3f,Z=%.3f)" % tuple(v)
    for cls, c in CLASSES.items():
        e = J[c["mesh"]]
        k, cl = J[c.get("places", c["mesh"])], J[c.get("cells", c.get("places", c["mesh"]))]
        off = np.asarray(c.get("offset", (0, 0, 0)), float) * [1, -1, 1]
        L = ['\tMeshName="RevNetMech.%s"' % c["mesh"]]
        L += ['\tSkinNames(%d)="%s"' % (i, s) for i, s in enumerate(e["skins"])]
        for i, (x, y, z, yaw) in enumerate(k["kits"]):
            L += ["\tKitAt(%d)=%s" % (i, vec(np.array([x, y, z]) + off)), "\tKitYaw(%d)=%d" % (i, int(round(yaw * 65536 / 360.0)))]
        L += ["\tnKits=%d" % len(k["kits"])]
        coff = off if "cells" not in c else np.zeros(3)  # (cells on a part: from its pivot)
        for i, (x, y, z, pi, ya, ro) in enumerate(cl["cells"]):
            L += ["\tCellAt(%d)=%s" % (i, vec(np.array([x, y, z]) + coff)), "\tCellRot(%d)=(Pitch=%d,Yaw=%d,Roll=%d)" % (i, pi, ya, ro)]
        L += ["\tnCells=%d" % len(cl["cells"])]
        for i, (piece, at) in enumerate(c.get("parts", [])):
            pv = pivot(piece) if at is None else np.asarray(at, float)
            L += ['\tPartMesh(%d)="RevNetMech.%s"' % (i, piece), "\tPartAt(%d)=%s" % (i, vec(pv * [1, -1, 1]))]
            L += ['\tPartSkin(%d)="%s"' % (i * 8 + j, s) for j, s in enumerate(J[piece]["skins"])]
        L += ["\tnParts=%d" % len(c.get("parts", []))]
        L += ["\t%s=%.3f" % (n, v) for n, v in c.get("extra", {}).items()]
        L += ["\tScaleGlow=%.2f" % e["glow"]]
        path = os.path.join(src, cls + ".uc")
        t = open(path, newline="").read()
        nl = "\r\n" if "\r\n" in t else "\n"
        a, b = t.index("\t// nest_game: begin"), t.index("\t// nest_game: end")
        t = t[:a] + "\t// nest_game: begin" + nl + nl.join(L) + nl + t[b:]
        open(path, "w", newline="").write(t)
        print("props", cls, "<-", c["mesh"])


if __name__ == "__main__":
    {"preview": preview, "props": props}[sys.argv[1]](sys.argv[2])
