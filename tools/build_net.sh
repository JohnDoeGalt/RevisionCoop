#!/bin/sh
# Build RevNet.u (Revision-native co-op) with HCC make in the dev folder (CoopNet, or
# $NETNAME), against Revision's own packages. Needs tools/setup_net.sh first.
# Output: build/net/RevNet.u (and the dev folder's RevNet.u).
# HCC compiles from <Revision>\RevNet\Classes, shared by every dev folder: one build at a
# time (lock directory).
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
REV="${REV:-/c/Program Files (x86)/Steam/steamapps/common/Deus Ex/Revision}"
NET="$REV/${NETNAME:-CoopNet}"
LOCK="$REV/RevNet.buildlock"

waited=0
until mkdir "$LOCK" 2>/dev/null; do
	sleep 2
	waited=$((waited + 2))
	# A build takes well under a minute: an older lock is left over from a killed one.
	if [ $waited -ge 300 ]; then rmdir "$LOCK" 2>/dev/null || true; waited=0; fi
done
trap 'rm -rf "$REV/RevNet"; rmdir "$LOCK" 2>/dev/null || true' EXIT

rm -rf "$REV/RevNet"
mkdir -p "$REV/RevNet/Classes"
cp "$here/src/RevNet/Classes/"*.uc "$REV/RevNet/Classes/"
rm -f "$NET/RevNet.u"
cd "$NET"
./HCC.exe make -log=BuildNet.log >/dev/null 2>&1 || true
if [ ! -f RevNet.u ]; then
	grep -E "^Error|Critical: [A-Z][a-z]|error" BuildNet.log | grep -v -E "appError|Guid" | head -30
	echo "BUILD FAILED"
	exit 1
fi
grep -E "Warning.*RevNet" BuildNet.log | head -10 || true
mkdir -p "$here/build/net"
cp RevNet.u "$here/build/net/"
echo "built $here/build/net/RevNet.u"
