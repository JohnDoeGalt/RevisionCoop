#!/bin/sh
# Headless server running Revision's own code (CoopNet): Engine.ServerCommandlet through HCC.
# The server always starts on Revision's menu map (the map on HCC's command line doesn't
# reach RevGameEngine), so the game class comes from the ini and RevNet.CoopGameInfo
# travels to the map (?CoopStart / StartMap; here [RevNet.CoopGameInfo] StartMap in RevNet.ini).
# Usage: [NET=<dev folder>] [PORT=7830] tools/net_smoke.sh <map> <game class> <secs>
NET="${NET:-/c/Program Files (x86)/Steam/steamapps/common/Deus Ex/Revision/CoopNet}"
map=$1; game=$2; secs=${3:-20}
cd "$NET" || exit 1
log="Net_$map.log"
rm -f "$log"
sed -i -e "s/^DefaultServerGame=.*/DefaultServerGame=$game\r/" -e "s/^Port=.*/Port=${PORT:-7830}\r/" RevNet.ini
grep -q '^\[RevNet.CoopGameInfo\]' RevNet.ini || printf '\r\n[RevNet.CoopGameInfo]\r\nStartMap=\r\n' >> RevNet.ini
sed -i "s/^StartMap=.*/StartMap=$map\r/" RevNet.ini
timeout "$secs" ./HCC.exe server -log="$log" >/dev/null 2>&1
echo "exit=$? lines=$(wc -l < "$log") $(grep -m1 'Browse:' "$log")"
grep -E "^(Critical|Error|Warning|ScriptWarning|ScriptLog)|Accessed None|Failed" "$log" | sed -E 's/\(Function [^)]*\)//' | sort | uniq -c | sort -rn | head -${LINES_MAX:-30}
