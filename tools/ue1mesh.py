"""Reads Unreal Engine 1 packages (Deus Ex) and their vertex meshes (Mesh, LodMesh).

Used to fit the Mech's own parts to a game body at build time, and as the reference for the
install-time builder (the game's data never ships: each PC reads its own copy).

  python -I tools/ue1mesh.py info  <package.u> <MeshName>
  python -I tools/ue1mesh.py list  <package.u> [ClassName]
"""
import struct, sys

RF_HasStack = 0x02000000


class Reader:
    def __init__(self, data, pos=0):
        self.d, self.p = data, pos

    def u8(self):
        v = self.d[self.p]; self.p += 1; return v

    def u16(self):
        v = struct.unpack_from("<H", self.d, self.p)[0]; self.p += 2; return v

    def i16(self):
        v = struct.unpack_from("<h", self.d, self.p)[0]; self.p += 2; return v

    def i32(self):
        v = struct.unpack_from("<i", self.d, self.p)[0]; self.p += 4; return v

    def u32(self):
        v = struct.unpack_from("<I", self.d, self.p)[0]; self.p += 4; return v

    def f32(self):
        v = struct.unpack_from("<f", self.d, self.p)[0]; self.p += 4; return v

    def vec(self):
        v = struct.unpack_from("<3f", self.d, self.p); self.p += 12; return v

    def ci(self):
        """FCompactIndex."""
        b = self.u8()
        neg, v = b & 0x80, b & 0x3F
        if b & 0x40:
            shift = 6
            while True:
                b = self.u8()
                v |= (b & 0x7F) << shift
                shift += 7
                if not b & 0x80:
                    break
        return -v if neg else v


class Package:
    def __init__(self, path):
        self.path = path
        self.d = open(path, "rb").read()
        r = Reader(self.d)
        tag = r.u32()
        if tag != 0x9E2A83C1:
            raise ValueError("not an Unreal package: " + path)
        self.version, self.licensee = r.u16(), r.u16()
        self.flags = r.u32()
        nc, no, ec, eo, ic, io = (r.u32() for _ in range(6))
        self.names = []
        r.p = no
        for _ in range(nc):
            if self.version >= 64:
                n = r.ci(); s = self.d[r.p:r.p + n - 1].decode("latin-1"); r.p += n
            else:
                e = self.d.index(b"\0", r.p); s = self.d[r.p:e].decode("latin-1"); r.p = e + 1
            r.u32()
            self.names.append(s)
        self.imports = []
        r.p = io
        for _ in range(ic):
            cp, cn, pk, on = r.ci(), r.ci(), r.i32(), r.ci()
            self.imports.append((self.names[cp], self.names[cn], pk, self.names[on]))
        self.exports = []
        r.p = eo
        for _ in range(ec):
            cls, sup, pk, on, fl, size = r.ci(), r.ci(), r.i32(), r.ci(), r.u32(), r.ci()
            off = r.ci() if size > 0 else 0
            self.exports.append(dict(cls=cls, sup=sup, pkg=pk, name=self.names[on], flags=fl, size=size, off=off))

    def class_name(self, ref):
        if ref < 0:
            return self.imports[-ref - 1][3]
        if ref > 0:
            return self.exports[ref - 1]["name"]
        return "Class"

    def find(self, name, cls=None):
        for e in self.exports:
            if e["name"].lower() == name.lower() and (cls is None or self.class_name(e["cls"]).lower() == cls.lower()):
                return e
        return None

    def skip_props(self, r):
        """Skips an object's tagged properties (up to "None")."""
        while True:
            n = r.ci()
            if self.names[n] == "None":
                return
            info = r.u8()
            typ, sc, arr = info & 0x0F, (info >> 4) & 7, info & 0x80
            if typ == 10:
                r.ci()  # struct name
            size = {0: 1, 1: 2, 2: 4, 3: 12, 4: 16}.get(sc)
            if size is None:
                size = r.u8() if sc == 5 else r.u16() if sc == 6 else r.u32()
            if arr and typ != 3:
                b = r.u8()
                if b & 0x80:
                    r.p += 1 if not b & 0x40 else 3
            r.p += size

    def lazy_count(self, r):
        """TLazyArray header: a skip position (version > 61), then the count."""
        if self.version > 61:
            r.i32()
        return r.ci()

    def read_mesh(self, name):
        """A Mesh or LodMesh export: its arrays and their file offsets."""
        e = self.find(name)
        if e is None:
            raise KeyError(name)
        cls = self.class_name(e["cls"])
        r = Reader(self.d, e["off"])
        if e["flags"] & RF_HasStack:
            raise ValueError("mesh with a state frame")
        self.skip_props(r)
        m = dict(name=name, cls=cls, export=e)
        m["prim_bounds"] = r.p
        r.p += 25 + 16  # UPrimitive: BoundingBox, BoundingSphere
        # Verts: Deus Ex stores 16-bit X, Y, Z (and a pad) per vertex.
        m["verts_hdr"] = r.p
        n = self.lazy_count(r)
        m["verts_off"], m["verts_count"] = r.p, n
        r.p += n * 8
        n = self.lazy_count(r); m["tris_off"], m["tris_count"] = r.p, n; r.p += n * 20
        seqs = []
        for _ in range(r.ci()):
            sn, grp, start, cnt = self.names[r.ci()], self.names[r.ci()], r.i32(), r.i32()
            notifies = [(r.f32(), self.names[r.ci()]) for _ in range(r.ci())]
            seqs.append(dict(name=sn, group=grp, start=start, frames=cnt, notifies=notifies, rate=r.f32()))
        m["seqs"] = seqs
        n = self.lazy_count(r); r.p += n * 8         # Connects
        m["mesh_bounds"] = r.p
        r.p += 25 + 16                                # BoundingBox, BoundingSphere
        n = self.lazy_count(r); r.p += n * 4         # VertLinks
        m["textures"] = [r.ci() for _ in range(r.ci())]
        n = r.ci(); m["boxes"] = (r.p, n); r.p += n * 25      # BoundingBoxes
        n = r.ci(); m["spheres"] = (r.p, n); r.p += n * 16    # BoundingSpheres
        m["frame_verts"], m["anim_frames"] = r.i32(), r.i32()
        m["and_flags"], m["or_flags"] = r.u32(), r.u32()
        m["scale"], m["origin"] = r.vec(), r.vec()
        m["rot_origin"] = (r.i32(), r.i32(), r.i32())
        r.i32(); r.i32()                              # CurPoly, CurVertex
        if self.version == 65:
            r.f32()                                   # TextureLOD
        elif self.version >= 66:
            n = r.ci(); r.p += n * 4                  # TextureLOD, one per texture
        if cls == "LodMesh":
            m["collapse_points"] = [r.u16() for _ in range(r.ci())]
            n = r.ci(); r.p += n * 2                  # FaceLevel
            m["faces"] = [(r.u16(), r.u16(), r.u16(), r.u16()) for _ in range(r.ci())]
            n = r.ci(); r.p += n * 2                  # CollapseWedgeThus
            m["wedges"] = [(r.u16(), r.u8(), r.u8()) for _ in range(r.ci())]
            m["materials"] = [(r.u32(), r.i32()) for _ in range(r.ci())]
            m["special_faces"] = [(r.u16(), r.u16(), r.u16(), r.u16()) for _ in range(r.ci())]
            m["model_verts"], m["special_verts"] = r.i32(), r.i32()
            m["scale_max"] = r.f32()
            r.f32(); r.f32(); r.i32(); r.f32(); r.f32()  # LOD tuning
            m["remap_anim_verts"] = [r.u16() for _ in range(r.ci())]
            m["old_frame_verts"] = r.i32()
        m["end"], m["export_end"] = r.p, e["off"] + e["size"]
        return m

    def object_props(self, r):
        """An object's tagged properties up to "None": {name: raw bytes} (object refs as compact indices)."""
        props = {}
        while True:
            n = r.ci()
            name = self.names[n]
            if name == "None":
                return props
            info = r.u8()
            typ, sc, arr = info & 0x0F, (info >> 4) & 7, info & 0x80
            if typ == 10:
                r.ci()
            size = {0: 1, 1: 2, 2: 4, 3: 12, 4: 16}.get(sc)
            if size is None:
                size = r.u8() if sc == 5 else r.u16() if sc == 6 else r.u32()
            if arr and typ != 3:
                b = r.u8()
                if b & 0x80:
                    r.p += 1 if not b & 0x40 else 3
            if typ == 5:   # object: a compact index
                start = r.p
                props[name] = Reader(self.d, start).ci()
            else:
                props[name] = self.d[r.p:r.p + size]
            r.p += size

    def read_texture(self, name):
        """An 8-bit texture's first mip: (width, height, pixel indices, palette [(r, g, b)])."""
        e = self.find(name, "Texture")
        r = Reader(self.d, e["off"])
        props = self.object_props(r)
        r.ci()                                   # mip count
        n = self.lazy_count(r)
        data = self.d[r.p:r.p + n]
        r.p += n
        w, h = r.i32(), r.i32()
        pal_ref = props["Palette"]
        pe = self.exports[pal_ref - 1]
        pr = Reader(self.d, pe["off"])
        self.object_props(pr)
        cols = [tuple(self.d[pr.p + 4 * i + j] for j in range(3)) for i in range(pr.ci())]
        return w, h, data, cols

    def frames(self, m):
        """Every frame's vertices as (x, y, z) in mesh units: frames x frame_verts."""
        fv, out = m["frame_verts"], []
        base = m["verts_off"]
        for f in range(m["anim_frames"]):
            row = struct.unpack_from("<%dh" % (fv * 4), self.d, base + f * fv * 8)
            out.append([(row[i * 4], row[i * 4 + 1], row[i * 4 + 2]) for i in range(fv)])
        return out


def main():
    cmd, path = sys.argv[1], sys.argv[2]
    pkg = Package(path)
    if cmd == "list":
        want = sys.argv[3].lower() if len(sys.argv) > 3 else None
        for e in pkg.exports:
            c = pkg.class_name(e["cls"])
            if want is None or c.lower() == want:
                print(c, e["name"], e["size"])
    elif cmd == "info":
        m = pkg.read_mesh(sys.argv[3])
        print("package version", pkg.version, "licensee", pkg.licensee)
        for k in ("cls", "verts_count", "tris_count", "frame_verts", "anim_frames", "scale", "origin", "rot_origin",
                  "model_verts", "special_verts", "scale_max", "old_frame_verts"):
            print(k, m.get(k))
        print("faces", len(m.get("faces", [])), "wedges", len(m.get("wedges", [])), "materials", m.get("materials"),
              "special faces", m.get("special_faces"))
        print("textures", [pkg.class_name(t) if t else None for t in m["textures"]])
        print("parsed to", m["end"], "export ends", m["export_end"], "OK" if m["end"] == m["export_end"] else "MISMATCH")
        print("sequences", len(m["seqs"]), [(s["name"], s["start"], s["frames"]) for s in m["seqs"]][:200])


if __name__ == "__main__":
    main()
