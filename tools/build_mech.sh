#!/bin/sh
# Build RevNetMech.u (the Mech's own parts: docs/MECH_CLASS.md, phase 3) with HCC make in the dev
# folder (CoopNet, or $NETNAME) from build/mech/art (tools/mech_parts.py, tools/mech_bake.py, tools/mech_face.py).
# Output: build/mech/RevNetMech.u. This full build holds frames baked from this PC's game body:
# it is never shipped (the release carries a template the installer fills in on each PC).
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
REV="${REV:-/c/Program Files (x86)/Steam/steamapps/common/Deus Ex/Revision}"
NET="$REV/${NETNAME:-CoopNet}"
LOCK="$REV/RevNet.buildlock"
ART="$here/build/mech/art"

until mkdir "$LOCK" 2>/dev/null; do sleep 2; done
trap 'rm -rf "$REV/RevNetMech"; rmdir "$LOCK" 2>/dev/null || true' EXIT

rm -rf "$REV/RevNetMech"
mkdir -p "$REV/RevNetMech"
cp -r "$ART/Classes" "$ART/Models" "$ART/Textures" "$REV/RevNetMech/"
sed 's/^EditPackages=RevNet$/EditPackages=RevNet\nEditPackages=RevNetMech/' "$NET/RevNet.ini" > "$NET/MechBuild.ini"
rm -f "$NET/RevNetMech.u"
cd "$NET"
./HCC.exe make ini=MechBuild.ini -log=BuildMech.log >/dev/null 2>&1 || true
if [ ! -f RevNetMech.u ]; then
	grep -E "^Error|Critical: [A-Z][a-z]|error|Warning" BuildMech.log | grep -v -E "appError|Guid" | head -30
	echo "BUILD FAILED"
	exit 1
fi
grep -E "Warning|mesh|Mesh" BuildMech.log | grep -v "RevNet.u" | head -10 || true
mkdir -p "$here/build/mech"
cp RevNetMech.u "$here/build/mech/"
echo "built $here/build/mech/RevNetMech.u"
