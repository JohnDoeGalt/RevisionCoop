"""Does RevNet.u (built against Revision's packages) find everything it imports in each
gameplay mode's own packages (<Revision>\\<mode>\\*.u: DeusEx, RevisionMission)?

A missing import (a property, a function a Super call or override links to, a class)
makes the whole package fail to load in that mode (measured: Vanilla, DeusExNote.textSource).
Calls by name and signatures aren't imports: build against the mode for those
(tools/setup_net.sh <mode>, tools/build_net.sh).

Usage: python -I tools/check_modes.py <RevNet.u> [<Revision dir>]
"""
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.dont_write_bytecode = True  # (tools/__pycache__ is in git)
from ue1edit import HDR, Package, read_ci

MODES = ('Vanilla', 'Shifter', 'Biomod', 'HR')


def exports(path):
    """{lower-case path inside the package: class name} of a package's exports."""
    d = open(path, 'rb').read()
    _, _, _, _, nc, no, ec, eo, _, _ = struct.unpack_from(HDR, d)
    names, pos = [], no
    for _ in range(nc):
        n, pos = read_ci(d, pos)
        names.append(d[pos:pos + n - 1].decode('latin1'))
        pos += n + 4
    rows, pos = [], eo
    for _ in range(ec):
        cls, pos = read_ci(d, pos)
        _, pos = read_ci(d, pos)  # super
        outer = struct.unpack_from('<i', d, pos)[0]
        name, pos = read_ci(d, pos + 4)
        size, pos = read_ci(d, pos + 4)  # after the flags
        if size:
            _, pos = read_ci(d, pos)
        rows.append((cls, outer, names[name]))
    pkg = Package(path)

    def full(i):
        parts = []
        while i:
            parts.append(rows[i - 1][2])
            i = rows[i - 1][1]
        return '.'.join(reversed(parts)).lower()

    def class_name(r):
        return pkg.names[pkg.imports[-r - 1][3]][0] if r < 0 else rows[r - 1][2] if r > 0 else 'Class'
    return {full(i + 1): class_name(r[0]) for i, r in enumerate(rows)}


def main():
    rev = sys.argv[2] if len(sys.argv) > 2 else r'C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision'
    pkg = Package(sys.argv[1])
    imports = [(pkg.path_of(i).split('.'), pkg.names[imp[1]][0]) for i, imp in enumerate(pkg.imports)]
    bad = 0
    for mode in MODES:
        folder = os.path.join(rev, mode)
        for f in sorted(os.listdir(folder)):
            if not f.lower().endswith('.u'):
                continue
            have = exports(os.path.join(folder, f))
            for path, cls in imports:
                if path[0].lower() != f[:-2].lower() or len(path) < 2:
                    continue
                key = '.'.join(path[1:]).lower()
                if key not in have:
                    print(f'{mode}: missing {cls} {".".join(path)}')
                    bad += 1
                elif have[key] != cls:
                    print(f'{mode}: {".".join(path)} is a {have[key]}, not a {cls}')
                    bad += 1
    print(f'{bad} problems' if bad else f'all imports found in {", ".join(MODES)}')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
