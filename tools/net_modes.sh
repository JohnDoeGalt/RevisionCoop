#!/bin/sh
# Does RevNet load and boot a co-op game under each gameplay mode's DeusEx.u?
# Headless (tools/net_smoke.sh) on the given map. Usage: tools/net_modes.sh [map] [secs]
here=$(cd "$(dirname "$0")/.." && pwd)
NET="${NET:-/c/Program Files (x86)/Steam/steamapps/common/Deus Ex/Revision/CoopNet}"
map=${1:-01_NYC_UNATCOIsland}; secs=${2:-45}
for mode in Revision Vanilla Shifter Biomod HR; do
	sh "$here/tools/setup_net.sh" "$mode" >/dev/null
	sh "$here/tools/net_smoke.sh" "$map" RevNet.CoopGameInfo "$secs" >/dev/null 2>&1
	log="$NET/Net_$map.log"
	echo "$mode: $(grep -c '^Critical' "$log") critical, map loaded: $(grep -c "Browse: $map" "$log"), mission: $(grep -o "Spawned new mission script '[^']*'" "$log" | tail -1), DeusEx from: $(grep -o -m1 'Loading: Package DeusEx$' "$log" | head -1)"
done
sh "$here/tools/setup_net.sh" Revision >/dev/null
