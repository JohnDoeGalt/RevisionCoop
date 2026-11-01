"""A Deus Ex (Revision) map's level into Blender (the user, 2026-10-30: "put it on an actual map in the game, somewhere
with good lighting"): its built BSP (the level's largest Model: Points, Vectors, Nodes, Surfs, Verts, as UE1's
UModel::Serialize writes them) as a textured OBJ, each surface's texture from its package (8-bit with its palette, or
DXT1, or RGBA8), and its lights (the light actors: where, how bright, their colour and reach) and zones' ambient as
JSON, for tools/flykit_render.py to light it the map's own way.
  python -I tools/ue1map.py <map name, e.g. 00_Training> [out dir]       (default build/maps/<map>)
"""
import glob, json, math, os, struct, sys
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ue1mesh
from ue1mesh import Reader

REV = os.environ.get("REV", r"C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision")
SEARCH = [os.path.join(REV, "Textures"), os.path.join(REV, "System"), os.path.join(REV, "HDTP", "Textures"),
          os.path.join(REV, "HDTP", "System"), os.path.join(REV, "..", "Textures"), os.path.join(REV, "..", "System")]
PF_INVISIBLE, PF_MASKED, PF_TRANSLUCENT, PF_MODULATED, PF_FAKEBACKDROP, PF_UNLIT, PF_PORTAL = \
    0x1, 0x2, 0x4, 0x40, 0x80, 0x400000, 0x4000000
_pkgs = {}


def package(name, here=None):
    """A package by name (the map's own for MyLevel), from Revision's folders first."""
    if name in ("MyLevel", None):
        return here
    if name not in _pkgs:
        for d in SEARCH:
            for ext in (".utx", ".u"):
                p = os.path.join(d, name + ext)
                if os.path.exists(p):
                    _pkgs[name] = ue1mesh.Package(p)
                    break
            if name in _pkgs:
                break
        else:
            _pkgs[name] = None
    return _pkgs[name]


def ref(pkg, i):
    """An object reference: (its name, its package's name: None for one of pkg's own)."""
    if i > 0:
        return pkg.exports[i - 1]["name"], None
    imp = pkg.imports[-i - 1]
    name, o, outer = imp[3], imp[2], None
    while o < 0:
        outer = pkg.imports[-o - 1]
        o = outer[2]
    return name, outer[3] if outer else None


def props(pkg, r):
    """An object's tagged properties up to "None": {name: raw bytes}, a bool's {name: True/False} (its value is the tag's
    array bit, no data follows), object references as compact indices."""
    out = {}
    while True:
        name = pkg.names[r.ci()]
        if name == "None":
            return out
        info = r.u8()
        typ, sc, arr = info & 0x0F, (info >> 4) & 7, info & 0x80
        if typ == 10:
            r.ci()                                              # (the struct's name)
        size = {0: 1, 1: 2, 2: 4, 3: 12, 4: 16}.get(sc)
        if size is None:
            size = r.u8() if sc == 5 else r.u16() if sc == 6 else r.u32()
        if typ == 3:
            out[name] = bool(arr)
            continue
        if arr:                                                 # (an array's element: keyed name[i])
            b = r.u8()
            i = b
            if b & 0x80:
                i = ((b & 0x7F) << 8) | r.u8() if not b & 0x40 else ((b & 0x3F) << 24) | (r.u8() << 16) | r.u16()
            name = "%s[%d]" % (name, i)
        out[name] = Reader(pkg.d, r.p).ci() if typ == 5 else pkg.d[r.p:r.p + size]
        r.p += size


def dxt1(data, w, h):
    """DXT1 blocks to RGBA."""
    out = np.zeros((h, w, 4), np.uint8)
    b = np.frombuffer(data[:max(1, w // 4) * max(1, h // 4) * 8], np.uint8).reshape(-1, 8)
    c0 = b[:, 0].astype(np.uint32) | (b[:, 1].astype(np.uint32) << 8)
    c1 = b[:, 2].astype(np.uint32) | (b[:, 3].astype(np.uint32) << 8)
    rgb = lambda c: np.stack([((c >> 11) & 31) * 255 // 31, ((c >> 5) & 63) * 255 // 63, (c & 31) * 255 // 31], -1)
    p0, p1 = rgb(c0).astype(np.float32), rgb(c1).astype(np.float32)
    four = c0 > c1
    pal = np.stack([p0, p1, np.where(four[:, None], (2 * p0 + p1) / 3, (p0 + p1) / 2),
                    np.where(four[:, None], (p0 + 2 * p1) / 3, 0)], 1)
    alpha = np.stack([np.full(len(b), 255), np.full(len(b), 255), np.full(len(b), 255),
                      np.where(four, 255, 0)], 1)
    bits = b[:, 4].astype(np.uint32) | (b[:, 5].astype(np.uint32) << 8) | (b[:, 6].astype(np.uint32) << 16) | \
        (b[:, 7].astype(np.uint32) << 24)
    bw = max(1, w // 4)
    for k in range(16):
        idx = (bits >> (2 * k)) & 3
        px = np.take_along_axis(pal, idx[:, None, None].repeat(3, 2), 1)[:, 0]
        a = np.take_along_axis(alpha, idx[:, None], 1)[:, 0]
        y, x = k // 4, k % 4
        blk = np.arange(len(b))
        out[(blk // bw) * 4 + y, (blk % bw) * 4 + x] = np.concatenate([px, a[:, None]], 1).astype(np.uint8)
    return out


def texture(pkg, name):
    """A texture's first mip as RGBA (P8 with its palette: colour 0 clear when masked; DXT1; RGBA8)."""
    e = pkg.find(name, "Texture")
    if e is None:
        return None
    r = Reader(pkg.d, e["off"])
    tp = props(pkg, r)
    fmt = tp["Format"][0] if isinstance(tp.get("Format"), bytes) else 0
    r.ci()
    n = pkg.lazy_count(r)
    data = pkg.d[r.p:r.p + n]
    r.p += n
    w, h = r.i32(), r.i32()
    if fmt == 3:
        return dxt1(data, w, h)
    if fmt == 5:
        a = np.frombuffer(data[:w * h * 4], np.uint8).reshape(h, w, 4)
        return a[..., [2, 1, 0, 3]].copy()
    pe = pkg.exports[tp["Palette"] - 1]
    pr = Reader(pkg.d, pe["off"])
    props(pkg, pr)
    pal = np.array([[pkg.d[pr.p + 4 * i + j] for j in range(3)] for i in range(pr.ci())], np.uint8)
    idx = np.frombuffer(data[:w * h], np.uint8).reshape(h, w)
    rgba = np.dstack([pal[idx], np.full((h, w), 255, np.uint8)])
    if tp.get("bMasked") or tuple(pal[0]) == (255, 0, 255):
        rgba[idx == 0, 3] = 0
    return rgba


class Map:
    def __init__(self, name):
        self.name = name
        self.pkg = ue1mesh.Package(os.path.join(REV, "Maps", name + ".dx"))
        pkg = self.pkg
        e = max((e for e in pkg.exports if pkg.class_name(e["cls"]) == "Model"), key=lambda e: e["size"])
        r = Reader(pkg.d, e["off"])
        pkg.skip_props(r)
        r.p += 25 + 16                                          # UPrimitive: BoundingBox, BoundingSphere
        vec = lambda: struct.unpack_from("<3f", pkg.d, r.p) and (r.f32(), r.f32(), r.f32())
        self.vectors = np.array([vec() for _ in range(r.ci())])
        self.points = np.array([vec() for _ in range(r.ci())])
        self.nodes = []
        for _ in range(r.ci()):
            r.p += 16 + 8 + 1                                   # Plane, ZoneMask, NodeFlags
            pool, surf = r.ci(), r.ci()
            for _ in range(5):
                r.ci()                                          # iBack, iFront, iPlane, iCollisionBound, iRenderBound
            r.p += 2                                            # iZone[2]
            nv = r.u8()
            r.p += 8                                            # iLeaf[2]
            self.nodes.append((pool, surf, nv))
        self.surfs = []
        for _ in range(r.ci()):
            tex = r.ci()
            flags = r.u32()
            base, normal, tu, tv = r.ci(), r.ci(), r.ci(), r.ci()
            r.ci(); r.ci()                                      # iLightMap, iBrushPoly
            pu, pv = r.i16(), r.i16()
            r.ci()                                              # Actor
            self.surfs.append(dict(tex=tex, flags=flags, base=base, normal=normal, u=tu, v=tv, pan=(pu, pv)))
        self.verts = [(r.ci(), r.ci())[0] for _ in range(r.ci())]
        lo, hi = self.points.min(0), self.points.max(0)
        print("%s: %d points, %d nodes, %d surfaces; %.0f x %.0f x %.0f units" % (
            name, len(self.points), len(self.nodes), len(self.surfs), *(hi - lo)))

    def write(self, out):
        """<out>/<map>.obj (+ .mtl, the textures as PNG): every drawn polygon, y mirrored (UE1 is left-handed)."""
        from PIL import Image
        os.makedirs(out, exist_ok=True)
        pkg, mats, made = self.pkg, {}, {}
        obj = os.path.join(out, self.name + ".obj")
        with open(obj, "w") as f:
            f.write("mtllib %s.mtl\n" % self.name)
            nv = nt = 0
            for pool, si, n in self.nodes:
                if n < 3 or si < 0 or si >= len(self.surfs):
                    continue
                s = self.surfs[si]
                if s["flags"] & (PF_INVISIBLE | PF_PORTAL | PF_FAKEBACKDROP):   # (the sky box: the sky is drawn instead)
                    continue
                key = s["tex"]
                if key not in mats:
                    name, pk = ref(pkg, key) if key else ("none", None)
                    src = package(pk, pkg) if key else None
                    img = texture(src, name) if src else None
                    if img is None:
                        img = np.full((16, 16, 4), 128, np.uint8)
                    mname = "t%d_%s" % (len(mats), name)
                    Image.fromarray(img, "RGBA").save(os.path.join(out, mname + ".png"))
                    mats[key] = (mname, img.shape[1], img.shape[0])
                mname, W, H = mats[key]
                made[mname] = s["flags"]
                P = self.points[[self.verts[pool + k] for k in range(n)]]
                base, U, V = self.points[s["base"]], self.vectors[s["u"]], self.vectors[s["v"]]
                for p in P[::-1]:                               # (wound back for the mirror)
                    f.write("v %.3f %.3f %.3f\n" % (p[0], p[2], p[1]))   # (x, z up, -(-y): Blender's OBJ y up)
                    d = p - base
                    f.write("vt %.5f %.5f\n" % ((d @ U + s["pan"][0]) / W, -(d @ V + s["pan"][1]) / H))
                f.write("usemtl %s\nf %s\n" % (mname, " ".join("%d/%d" % (nv + k + 1, nt + k + 1) for k in range(n))))
                nv += n
                nt += n
        with open(os.path.join(out, self.name + ".mtl"), "w") as f:
            for mname, flags in made.items():
                f.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\n" % (mname, mname))
                if flags & PF_MASKED:
                    f.write("map_d %s.png\n" % mname)
                f.write("\n")
        print("%s: %d materials" % (obj, len(made)))
        return obj

    def lights(self):
        """The light actors (any with a light: its class a Light, or LightType set): where (Blender's frame), its
        brightness (0-255), hue, saturation (255: white) and radius (UE1: 25 x (LightRadius + 1) units)."""
        pkg, out, ambient = self.pkg, [], []
        for e in pkg.exports:
            cls = pkg.class_name(e["cls"])
            if cls in ("Model", "Texture", "Palette", "Polys", "Level", "Sound", "Brush"):
                continue
            try:
                r = Reader(pkg.d, e["off"])
                if e["flags"] & 0x02000000:                     # RF_HasStack: the actor's state frame first
                    node = r.ci()
                    r.ci()
                    r.p += 8 + 4                                # ProbeMask, LatentAction
                    if node:
                        r.ci()
                pr = props(pkg, r)
            except Exception:
                continue
            light = "light" in cls.lower() or "LightType" in pr
            if "Location" not in pr or not light and "AmbientBrightness" not in pr:
                continue
            loc = struct.unpack("<3f", pr["Location"][:12])
            b = lambda k, d: pr[k][0] if isinstance(pr.get(k), bytes) and pr[k] else d
            if "AmbientBrightness" in pr:
                ambient.append(dict(brightness=b("AmbientBrightness", 0), hue=b("AmbientHue", 0),
                                    saturation=b("AmbientSaturation", 255)))
            if light and b("LightType", 1) != 0:
                out.append(dict(at=[loc[0], -loc[1], loc[2]], brightness=b("LightBrightness", 64), hue=b("LightHue", 0),
                                saturation=b("LightSaturation", 255), radius=25.0 * (b("LightRadius", 64) + 1),
                                cls=cls))
        return out, ambient


    def actor_props(self, e):
        r = Reader(self.pkg.d, e["off"])
        if e["flags"] & 0x02000000:                             # RF_HasStack: the actor's state frame first
            node = r.ci()
            r.ci()
            r.p += 8 + 4
            if node:
                r.ci()
        return props(self.pkg, r)

    def write_actors(self, out, skip=()):
        """<out>/<map>_actors.obj: every mesh actor (its class's mesh, skins and scale, as the game has them:
        HCC.exe RevNet.CoopExplosiveFacts' look lines; the actor's own location, rotation, scale and skins over them),
        posed as its mesh's first frame."""
        import subprocess
        from PIL import Image
        pkg, found = self.pkg, []
        for e in pkg.exports:
            cls = pkg.class_name(e["cls"])
            if cls in skip or cls in ("Model", "Texture", "Palette", "Polys", "Level", "Sound", "Brush", "Light"):
                continue
            try:
                pr = self.actor_props(e)
            except Exception:
                continue
            if "Location" not in pr or pr.get("bHidden"):
                continue
            imp = pkg.imports[-e["cls"] - 1] if e["cls"] < 0 else None
            pk = pkg.imports[-imp[2] - 1][3] if imp and imp[2] < 0 else "DeusEx"
            found.append((pk + "." + cls, pr))
        classes = sorted(set(c for c, _ in found))
        looks = {}
        net = os.path.join(REV, "CoopNet")
        for k in range(0, len(classes), 8):                     # (8 a call: HCC truncates long command lines)
            subprocess.run([os.path.join(net, "HCC.exe"), "RevNet.CoopExplosiveFacts"] + classes[k:k + 8] + ["-log=look_map.log"],
                           cwd=net, capture_output=True)
            for line in open(os.path.join(net, "look_map.log"), errors="replace"):
                if "look:" in line:
                    w = line.split("look:")[1].split()
                    looks[w[0]] = dict(mesh=w[2], scale=float(w[4]), skins=w[10:18], skin=w[21], hidden=w[23] == "True")
        os.makedirs(out, exist_ok=True)
        obj = os.path.join(out, self.name + "_actors.obj")
        meshes, mats, n_act = {}, {}, 0
        with open(obj, "w") as f, open(obj[:-4] + ".mtl", "w") as mt:
            f.write("mtllib %s\n" % os.path.basename(obj[:-4] + ".mtl"))
            nv = nt = 0
            for c, pr in found:
                look = looks.get(c)
                if not look or look["hidden"] or look["mesh"] == "None":
                    continue
                mpk, mname = look["mesh"].split(".")[0], look["mesh"].split(".")[-1]
                if look["mesh"] not in meshes:
                    src = package(mpk, pkg)
                    try:
                        m = src.read_mesh(mname)
                        V = np.array(src.frames(m)[0], float)[m.get("special_verts", 0):]
                        meshes[look["mesh"]] = (src, m, (V - np.array(m["origin"])) * np.array(m["scale"]))
                    except Exception as x:
                        print("no mesh", look["mesh"], x)
                        meshes[look["mesh"]] = None
                if not meshes[look["mesh"]] or "faces" not in meshes[look["mesh"]][1]:
                    continue
                src, m, V = meshes[look["mesh"]]
                loc = np.array(struct.unpack("<3f", pr["Location"][:12]))
                rot = struct.unpack("<3i", pr["Rotation"][:12]) if "Rotation" in pr else (0, 0, 0)
                ds = struct.unpack("<f", pr["DrawScale"][:4])[0] if "DrawScale" in pr else look["scale"]
                P = (rotator(rot) @ (rotator(m["rot_origin"]) @ V.T)).T * ds + loc
                slots = []
                for t in range(max(8, len(m["textures"]))):
                    if "MultiSkins[%d]" % t in pr or (t == 0 and "MultiSkins" in pr):
                        tn = ref(pkg, pr["MultiSkins[%d]" % t if t else "MultiSkins"])
                    elif t < 8 and look["skins"][t] != "None":
                        tn = tuple(reversed(look["skins"][t].split(".", 1))) if "." in look["skins"][t] else (look["skins"][t], None)
                        tn = (look["skins"][t].split(".")[-1], look["skins"][t].split(".")[0])
                    elif t < len(m["textures"]) and m["textures"][t]:
                        tn = ref(src, m["textures"][t])
                        tn = (tn[0], tn[1] or mpk)
                    else:
                        tn = None
                    slots.append(tn)
                for v in P:
                    f.write("v %.3f %.3f %.3f\n" % (v[0], v[2], v[1]))
                for w0, w1, w2, mat in m["faces"]:
                    _, slot = m["materials"][mat]
                    tn = slots[slot] if slot < len(slots) else None
                    if tn is None or tn[0] in ("PinkMaskTex",):
                        continue
                    key = "%s.%s" % (tn[1], tn[0])
                    if key not in mats:
                        img = texture(package(tn[1], pkg) or src, tn[0])
                        if img is None:
                            mats[key] = None
                        else:
                            mats[key] = "a%d_%s" % (len(mats), tn[0])
                            Image.fromarray(img, "RGBA").save(os.path.join(out, mats[key] + ".png"))
                            mt.write("newmtl %s\nKd 1 1 1\nmap_Kd %s.png\n%s\n" % (
                                mats[key], mats[key], "map_d %s.png\n" % mats[key] if (img[..., 3] < 128).any() else ""))
                    if mats[key] is None:
                        continue
                    c = [m["wedges"][w] for w in (w0, w1, w2)]
                    for _, u, vv in c:
                        f.write("vt %.5f %.5f\n" % (u / 256.0, 1 - vv / 256.0))
                    f.write("usemtl %s\nf %d/%d %d/%d %d/%d\n" % (mats[key], nv + c[0][0] + 1, nt + 1, nv + c[1][0] + 1,
                                                              nt + 2, nv + c[2][0] + 1, nt + 3))
                    nt += 3
                nv += len(P)
                n_act += 1
        print("%s: %d actors, %d meshes, %d skins" % (obj, n_act, sum(1 for v in meshes.values() if v), len(mats)))
        return obj


def rotator(r):
    """A UE1 rotator (pitch, yaw, roll; 65536 a turn) as a matrix on column vectors (the game's own frame)."""
    p, y, rl = (a * 2 * math.pi / 65536 for a in r)
    sp, cp, sy, cy, sr, cr = math.sin(p), math.cos(p), math.sin(y), math.cos(y), math.sin(rl), math.cos(rl)
    X = [cp * cy, cp * sy, sp]
    Y = [sr * sp * cy - cr * sy, sr * sp * sy + cr * cy, -sr * cp]
    Z = [-(cr * sp * cy + sr * sy), cy * sr - cr * sp * sy, cr * cp]
    return np.array([X, Y, Z]).T


if __name__ == "__main__":
    name = sys.argv[1]
    out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join("build", "maps", name))
    m = Map(name)
    path = m.write(out)
    lights, ambient = m.lights()
    actors = m.write_actors(out, skip=("Terrorist", "UNATCOTroop", "ThugMale2"))      # (its people: not ours)
    json.dump(dict(obj=path, actors=actors, lights=lights, ambient=ambient, lo=m.points.min(0).tolist(), hi=m.points.max(0).tolist()),
              open(os.path.join(out, name + ".json"), "w"), indent=1)
    print("%d lights, %d ambient zones" % (len(lights), len(ambient)))
