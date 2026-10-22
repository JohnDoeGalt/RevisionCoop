#!/bin/sh
# Revision-native co-op (no HX): dev folder <Deus Ex>\Revision\CoopNet next to Revision's
# System folder, with HCC.exe (a UCC build, for `make` and headless servers through
# Engine.ServerCommandlet), Revision's DLLs and an ini with Revision's own package order.
# Usage: tools/setup_net.sh [mode]   (Revision | Vanilla | Shifter | Biomod | HR)
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
DX="${DX:-/c/Program Files (x86)/Steam/steamapps/common/Deus Ex}"
REV="$DX/Revision"
DL="${DL:-$HOME/RevisionCoop/downloads}"
# NETNAME: another dev folder (and package path in its ini), for parallel work.
export NETNAME="${NETNAME:-CoopNet}"
NET="$REV/$NETNAME"
mode=${1:-Revision}

mkdir -p "$NET"
rm -f "$NET/"*.dll "$NET/"*.int
cp "$DX/System/"*.dll "$DX/System/"*.int "$NET/"   # Editor.dll/.int (make) and fallbacks
cp "$REV/System/"*.dll "$REV/System/"*.int "$NET/"
# Revision's launcher takes INI= as a bare name in its own folder: run a copy from here
# (a sibling of System, so Revision's ..\ paths resolve the same). steam_appid.txt in the
# working directory keeps it from relaunching itself through Steam without our arguments.
cp "$REV/System/Revision.exe" "$NET/"
printf '397550' > "$NET/steam_appid.txt"
tmp=$(mktemp -d)
unzip -qo "$DL/HX-0.9.89.4.zip" System/HCC.exe -d "$tmp"
cp "$tmp/System/HCC.exe" "$NET/"
rm -rf "$tmp"
[ -f "$here/build/net/RevNet.u" ] && cp "$here/build/net/RevNet."* "$NET/"
python -I "$here/tools/make_net_ini.py" "$REV/System/RevisionDefault.ini" "$mode" "$NET/RevNet.ini" "$NET/Modes"
# The Steam relay in its own folder: its steam_api.dll (newer than Revision's) and AppID 480.
mkdir -p "$NET/Relay"
# (RevCoop.exe is built by src/relay/build.bat: not in a fresh checkout; tests don't need it.)
[ -f "$here/src/relay/RevCoop.exe" ] && cp "$here/src/relay/RevCoop.exe" "$NET/Relay/"
cp "$DL/coop/HXCoop/steam_api.dll" "$NET/Relay/"
printf '480' > "$NET/Relay/steam_appid.txt"
cp "$NET/RevNet.ini" "$NET/RevNetDefault.ini"
# HCC.exe: use RevNet.ini/RevNetUser.ini; "server" = the stock dedicated server commandlet.
printf '[General]\r\nGame=RevNet\r\n[CommandletAliases]\r\nserver=Engine.ServerCommandlet\r\n' > "$NET/HCC.ini"
# Client net speed: broadband, see make_net_ini.py.
sed 's/^NetSpeed=.*/NetSpeed=20000/' "$REV/System/RevisionDefUser.ini" > "$NET/RevNetDefUser.ini"
[ -f "$NET/RevNetUser.ini" ] || cp "$NET/RevNetDefUser.ini" "$NET/RevNetUser.ini"
sed -i 's/^NetSpeed=.*/NetSpeed=20000/' "$NET/RevNetUser.ini"
echo "installed to $NET ($mode)"
