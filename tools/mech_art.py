"""The Mech's own body parts (docs/MECH_CLASS.md, phase 3), on a game body's animation.

Reads the game's packages on this PC. The release ships RevNetMech.template (the parts with
their frames left empty) and bindings.json; the installer fills the frames in from the
player's own body (Install-RevNet.ps1 does what fill does here).
  python -I tools/mech_art.py base <out.obj> [frame]             a body frame as OBJ (game units)
  python -I tools/mech_art.py segments [tol]                     the body's rigid parts
  python -I tools/mech_art.py template <full.u> <out.template>   empty the frames (and bounds)
  python -I tools/mech_art.py fill <template> <bindings.json> <out.u> [DeusExCharacters.u]
"""
import json, os, struct, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue1mesh

REV = os.environ.get("REV", r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision")
BODY_PACKAGE = os.path.join(REV, "System", "DeusExCharacters.u")
BODY = "GM_DressShirt_B"


def load_body():
    pkg = ue1mesh.Package(BODY_PACKAGE)
    m = pkg.read_mesh(BODY)
    return pkg, m


def to_game(m, v):
    """Raw mesh vertex -> game units (before the mesh's rotation)."""
    s, o = m["scale"], m["origin"]
    return ((v[0] - o[0]) * s[0], (v[1] - o[1]) * s[1], (v[2] - o[2]) * s[2])


def write_obj(path, m, frame_verts):
    with open(path, "w") as f:
        f.write("# %s frame, game units\n" % BODY)
        for v in frame_verts:
            f.write("v %.4f %.4f %.4f\n" % to_game(m, v))
        for w in m["wedges"]:
            f.write("vt %.5f %.5f\n" % (w[1] / 255.0, 1 - w[2] / 255.0))
        mats = {}
        for i, face in enumerate(m["faces"]):
            mats.setdefault(face[3], []).append(face)
        for mi, faces in sorted(mats.items()):
            f.write("g mat%d_tex%d\n" % (mi, m["materials"][mi][1]))
            for a, b, c, _ in faces:
                # A wedge's vertex counts from after the weapon triangle's (the first in a frame).
                va, vb, vc = (m["wedges"][k][0] + m["special_verts"] + 1 for k in (a, b, c))
                f.write("f %d/%d %d/%d %d/%d\n" % (va, a + 1, vb, b + 1, vc, c + 1))


def game_frames(pkg, m):
    """All frames as a numpy array (frames, verts, 3) in game units."""
    import numpy as np
    raw = np.frombuffer(pkg.d, dtype="<i2", count=m["anim_frames"] * m["frame_verts"] * 4, offset=m["verts_off"])
    raw = raw.reshape(m["anim_frames"], m["frame_verts"], 4)[:, :, :3].astype(np.float64)
    return (raw - np.array(m["origin"])) * np.array(m["scale"])


def norm(v):
    import numpy as np
    return v / np.linalg.norm(v)


def frame_of(A, B, C):
    """An orthonormal frame from three points: origin A, rows e1 (A to B), e2, n."""
    import numpy as np
    e1 = norm(B - A)
    n = norm(np.cross(B - A, C - A))
    e2 = np.cross(n, e1)
    return A, np.array([e1, e2, n])


def bake(F, parts, nverts):
    """Every frame of a parts mesh: each part on its anchors' frame (game units)."""
    import numpy as np
    baked = np.zeros((F.shape[0], nverts, 3))
    for b in parts:
        i, j, k = b["anchors"]
        loc = np.array(b["local"])
        for f in range(F.shape[0]):
            o, M = frame_of(F[f, i], F[f, j], F[f, k])
            baked[f, b["first"]:b["first"] + b["count"]] = o + loc @ M
    return baked


# A template's bounds: one box and sphere for every frame (raw units; the engine culls with them).
BOX = struct.pack("<6fB", -16000, -16000, -1000, 16000, 16000, 27000, 1)
SPHERE = struct.pack("<4f", 0, 0, 13000, 22000)


WHOLE = ("StormView",)      # meshes made here with no game data in them (tools/mech_storm.py): kept whole
FROM_BODY = ("StormArm",)   # the body's own faces (mech_parts.arm_mesh): their triangles emptied too


def template(full, out):
    pkg = ue1mesh.Package(full)
    d = bytearray(pkg.d)
    for e in pkg.exports:
        if pkg.class_name(e["cls"]) != "Mesh" or e["name"] in WHOLE:
            continue
        m = pkg.read_mesh(e["name"])
        d[m["verts_off"]:m["verts_off"] + m["verts_count"] * 8] = bytes(m["verts_count"] * 8)
        if e["name"] in FROM_BODY:
            d[m["tris_off"]:m["tris_off"] + m["tris_count"] * 20] = bytes(m["tris_count"] * 20)
        for off in (m["prim_bounds"], m["mesh_bounds"]):
            d[off:off + 41] = BOX + SPHERE
        off, n = m["boxes"]
        d[off:off + 25 * n] = BOX * n
        off, n = m["spheres"]
        d[off:off + 16 * n] = SPHERE * n
        print("emptied", e["name"], m["verts_count"], "vertices")
    open(out, "wb").write(bytes(d))


def fill(template_path, bindings, out, body_package=None):
    """The parts' frames from this PC's own body (what the installer does)."""
    import numpy as np
    B = json.load(open(bindings))
    pkg = ue1mesh.Package(body_package or BODY_PACKAGE)
    m = pkg.read_mesh(B["body"])
    if (m["frame_verts"], m["anim_frames"]) != (B["frame_verts"], B["frames"]) or list(m["scale"]) != B["scale"] or list(m["origin"]) != B["origin"]:
        raise ValueError("this game's %s differs from the one the parts were made for" % B["body"])
    F = game_frames(pkg, m)
    t = ue1mesh.Package(template_path)
    d = bytearray(t.d)
    for name, mb in B["meshes"].items():
        tm = t.read_mesh(name)
        if tm["verts_count"] != B["frames"] * mb["verts"]:
            raise ValueError("template mesh %s has %d vertices" % (name, tm["verts_count"]))
        raw = np.rint(bake(F, mb["parts"], mb["verts"]) / np.array(m["scale"]) + np.array(m["origin"])).astype("<i2")
        out4 = np.zeros(raw.shape[:2] + (4,), "<i2")
        out4[:, :, :3] = raw
        d[tm["verts_off"]:tm["verts_off"] + out4.nbytes] = out4.tobytes()
    if "arm" in B:
        fill_arm(B["arm"], F, m, t, d)
    open(out, "wb").write(bytes(d))
    print("filled", out)


def fill_arm(A, F, bm, t, d):
    """The Mech's own arms in its view (StormArm, mech_parts.arm_mesh) from this PC's body: its triangles (the
    body's faces: each corner's vertex and UV from its wedge, the face's skin) and its frames (frame A["frame"]'s
    vertices through each frame's maps, summed in MechParts.cs's order)."""
    import numpy as np
    tm = t.read_mesh(A["mesh"])
    sv = bm["special_verts"]
    index = {v: i for i, v in enumerate(A["verts"])}
    tris = bytearray()
    for fi in A["faces"]:
        f = bm["faces"][fi]
        w = [bm["wedges"][k] for k in f[:3]]
        tris += struct.pack("<3H6BIi", index[w[0][0] + sv], index[w[1][0] + sv], index[w[2][0] + sv],
                            w[0][1], w[0][2], w[1][1], w[1][2], w[2][1], w[2][2], 0, bm["materials"][f[3]][1])
    if len(tris) != tm["tris_count"] * 20 or tm["verts_count"] != len(A["xforms"]) * len(A["verts"]):
        raise ValueError("template mesh %s doesn't match its bindings" % A["mesh"])
    d[tm["tris_off"]:tm["tris_off"] + len(tris)] = tris
    P = F[A["frame"]][A["verts"]]
    g = np.array(A["groups"])
    out = np.zeros((len(A["xforms"]), len(P), 4), "<i2")
    for f, per in enumerate(A["xforms"]):
        M = np.array(per)[g]
        for a in range(3):
            pos = ((M[:, 4 * a] * P[:, 0] + M[:, 4 * a + 1] * P[:, 1]) + M[:, 4 * a + 2] * P[:, 2]) + M[:, 4 * a + 3]
            out[f, :, a] = np.rint(pos * 256)
    d[tm["verts_off"]:tm["verts_off"] + out.nbytes] = out.tobytes()


def triangles(m, V):
    """The body's triangles (n, 3, 3) from one frame's vertices V (game units)."""
    import numpy as np
    sv = m["special_verts"]
    idx = [[m["wedges"][k][0] + sv for k in f[:3]] for f in m["faces"]]
    return np.asarray(V)[np.array(idx)]


def ray(T, origin, direction):
    """Distance along the ray to the nearest triangle of T (None if it misses)."""
    import numpy as np
    o, d = np.asarray(origin, float), np.asarray(direction, float)
    e1, e2 = T[:, 1] - T[:, 0], T[:, 2] - T[:, 0]
    p = np.cross(d, e2)
    det = (e1 * p).sum(1)
    ok = np.abs(det) > 1e-9
    inv = np.where(ok, 1 / np.where(ok, det, 1), 0)
    s = o - T[:, 0]
    u = (s * p).sum(1) * inv
    q = np.cross(s, e1)
    v = (d * q).sum(1) * inv
    t = (e2 * q).sum(1) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    return float(t[hit].min()) if hit.any() else None


def segments(F, tol):
    """Groups of vertices that keep their distances in every frame (the body's rigid parts)."""
    import numpy as np
    d = np.linalg.norm(F[:, :, None, :] - F[:, None, :, :], axis=3)  # frames, n, n
    spread = d.std(axis=0)
    n = F.shape[1]
    parent = list(range(n))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for i, j in zip(*np.nonzero(np.triu(spread < tol, 1))):
        parent[root(i)] = root(j)
    groups = {}
    for i in range(n):
        groups.setdefault(root(i), []).append(i)
    return sorted(groups.values(), key=len, reverse=True)


def main():
    cmd = sys.argv[1]
    if cmd == "template":
        template(sys.argv[2], sys.argv[3])
        return
    if cmd == "fill":
        fill(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5] if len(sys.argv) > 5 else None)
        return
    if cmd == "segments":
        import numpy as np
        pkg, m = load_body()
        F = game_frames(pkg, m)
        tol = float(sys.argv[2]) if len(sys.argv) > 2 else 0.2
        for g in segments(F, tol):
            if len(g) < 3:
                continue
            c = F[32, g].mean(axis=0)
            print("%3d verts at (%6.1f %6.1f %6.1f)  e.g. %s" % (len(g), c[0], c[1], c[2], g[:8]))
        return
    if cmd == "base":
        pkg, m = load_body()
        frame = int(sys.argv[3]) if len(sys.argv) > 3 else 0
        frames = pkg.frames(m)
        write_obj(sys.argv[2], m, frames[frame])
        print("wrote", sys.argv[2], "frame", frame, "of", len(frames))


if __name__ == "__main__":
    main()
