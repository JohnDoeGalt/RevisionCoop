"""Retarget imports of an Unreal Engine 1 package (Deus Ex, version 68) without touching its exports.

The edited file is the original bytes with header fields changed in place and a new name
table and import table appended at the end. That makes the edit expressible as a small
patch (expected hash, in-place byte edits, tail bytes) the PowerShell installer applies,
so Revision's files are never redistributed.

Retarget rules ("old.path -> new.path"): the import named by old.path keeps its class type
and gets new.path's outer and name. Missing outers are created: the first part as a
Core.Package import, the rest as Core.Class imports. Imports nested under a retargeted
import follow it.
"""
import hashlib, json, struct

HDR = '<IHHIIIIIII'


def read_ci(d, pos):
    b = d[pos]; pos += 1
    neg, v, shift = b & 0x80, b & 0x3F, 6
    if b & 0x40:
        while True:
            b = d[pos]; pos += 1
            v |= (b & 0x7F) << shift
            shift += 7
            if not b & 0x80:
                break
    return (-v if neg else v), pos


def write_ci(v):
    a = abs(v)
    out = bytearray([(0x80 if v < 0 else 0) | (a & 0x3F) | (0x40 if a >= 0x40 else 0)])
    a >>= 6
    while a:
        out.append((a & 0x7F) | (0x80 if a >= 0x80 else 0))
        a >>= 7
    return bytes(out)


class Package:
    def __init__(self, path):
        self.path = path
        self.data = open(path, 'rb').read()
        d = self.data
        tag, self.ver, _, _, nc, no, _, _, ic, io = struct.unpack_from(HDR, d)
        # 69: maps saved by Revision's editor; same tables, and Revision's Core.dll loads them.
        assert tag == 0x9E2A83C1 and self.ver in (68, 69), f'{path}: not a version 68/69 package'
        assert struct.unpack_from('<I', d, 52)[0] == 1, f'{path}: expected one generation'
        self.names, pos = [], no  # [(str, flags)]
        for _ in range(nc):
            n, pos = read_ci(d, pos)
            self.names.append((d[pos:pos + n - 1].decode('latin1'), struct.unpack_from('<I', d, pos + n)[0]))
            pos += n + 4
        self.imports, pos = [], io  # [[class_package, class_name, outer, object_name]] (name indices)
        for _ in range(ic):
            cp, pos = read_ci(d, pos)
            cn, pos = read_ci(d, pos)
            outer = struct.unpack_from('<i', d, pos)[0]; pos += 4
            on, pos = read_ci(d, pos)
            self.imports.append([cp, cn, outer, on])
        self.changed = False

    def name(self, s):
        for i, (n, _) in enumerate(self.names):
            if n.lower() == s.lower():
                return i
        self.names.append((s, 0x00070010))  # RF_TagExp|RF_LoadForClient|RF_LoadForServer|RF_LoadForEdit
        return len(self.names) - 1

    def path_of(self, i):
        parts = []
        while True:
            imp = self.imports[i]
            parts.append(self.names[imp[3]][0])
            if imp[2] >= 0:
                return '.'.join(reversed(parts))
            i = -imp[2] - 1

    def find(self, path):
        for i in range(len(self.imports)):
            if self.path_of(i).lower() == path.lower():
                return i
        return None

    def ensure_outer(self, parts):
        """Import index for the outer chain parts (created if missing); returns the int32 ref."""
        if not parts:
            return 0
        i = self.find('.'.join(parts))
        if i is None:
            outer = self.ensure_outer(parts[:-1])
            cls = 'Package' if len(parts) == 1 else 'Class'
            self.imports.append([self.name('Core'), self.name(cls), outer, self.name(parts[-1])])
            i = len(self.imports) - 1
        return -(i + 1)

    def retarget(self, old, new):
        i = self.find(old)
        if i is None:
            return False
        parts = new.split('.')
        self.imports[i][2] = self.ensure_outer(parts[:-1])
        self.imports[i][3] = self.name(parts[-1])
        self.changed = True
        return True

    def rename_package(self, old, new):
        """Rename top-level package imports (the linker loads every imported package)."""
        for imp in self.imports:
            if imp[2] == 0 and self.names[imp[3]][0].lower() == old.lower():
                imp[3] = self.name(new)
                self.changed = True

    def class_imports(self):
        """[(index, package, class name)] for imports of classes directly in a package."""
        out = []
        for i, (cp, cn, outer, on) in enumerate(self.imports):
            if self.names[cn][0] == 'Class' and outer < 0 and self.imports[-outer - 1][2] == 0:
                out.append((i, self.names[self.imports[-outer - 1][3]][0], self.names[on][0]))
        return out

    def patch(self):
        """(edits, tail): in-place header edits [(offset, bytes)] and bytes appended to the original."""
        d = self.data
        tail = bytearray()
        name_off = len(d)
        for s, flags in self.names:
            b = s.encode('latin1') + b'\0'
            tail += write_ci(len(b)) + b + struct.pack('<I', flags)
        import_off = len(d) + len(tail)
        for cp, cn, outer, on in self.imports:
            tail += write_ci(cp) + write_ci(cn) + struct.pack('<i', outer) + write_ci(on)
        edits = [(12, struct.pack('<II', len(self.names), name_off)),
                 (28, struct.pack('<II', len(self.imports), import_off)),
                 (60, struct.pack('<I', len(self.names)))]  # generation 0 name count
        return edits, bytes(tail)

    def save(self, out):
        edits, tail = self.patch()
        b = bytearray(self.data)
        for off, val in edits:
            b[off:off + len(val)] = val
        open(out, 'wb').write(bytes(b) + tail)

    def save_patch(self, out, src):
        """<out>.json (source, size, sha256, header edits) + <out>.tail (bytes to append)."""
        edits, tail = self.patch()
        json.dump({'src': src, 'size': len(self.data), 'sha256': hashlib.sha256(self.data).hexdigest().upper(),
                   'edits': [[o, v.hex()] for o, v in edits]}, open(out + '.json', 'w'), separators=(',', ':'))
        open(out + '.tail', 'wb').write(tail)


def apply_patch(patch_path, src_path, out_path):
    """Python twin of the installer's PowerShell patcher (used by the self-check)."""
    p = json.load(open(patch_path + '.json'))
    d = bytearray(open(src_path, 'rb').read())
    assert len(d) == p['size'] and hashlib.sha256(d).hexdigest().upper() == p['sha256'], f'{src_path}: unexpected version'
    for off, val in p['edits']:
        v = bytes.fromhex(val)
        d[off:off + len(v)] = v
    open(out_path, 'wb').write(bytes(d) + open(patch_path + '.tail', 'rb').read())


if __name__ == '__main__':
    # Self-check: round trip without changes keeps every name and import, and a retarget sticks.
    import sys, tempfile, os
    src = sys.argv[1]
    p = Package(src)
    names, imports = list(p.names), [list(i) for i in p.imports]
    with tempfile.TemporaryDirectory() as t:
        out = os.path.join(t, 'x.u')
        p.save(out)
        q = Package(out)
        assert q.names == names and q.imports == imports, 'round trip changed tables'
        first = p.path_of(p.class_imports()[0][0])
        assert p.retarget(first, 'RevCoopSelfTest.' + first.split('.')[-1])
        p.save_patch(os.path.join(t, 'x.rcpatch'), src)
        apply_patch(os.path.join(t, 'x.rcpatch'), src, out)
        r = Package(out)
        assert r.find('RevCoopSelfTest.' + first.split('.')[-1]) is not None
    print('ok', src, len(names), 'names', len(imports), 'imports')
