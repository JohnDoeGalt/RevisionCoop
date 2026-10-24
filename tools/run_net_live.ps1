# Revision-native co-op live run: Revision.exe listen host + N clients on this PC (minimized,
# muted, waits while another program is fullscreen), for a fixed time, then collects the logs.
#   powershell -NoProfile -File tools/run_net_live.ps1 [-Map 01_NYC_UNATCOIsland] [-Clients 1] [-Seconds 240] [-Extra "?..."]
param(
	[string]$Rev = "${env:ProgramFiles(x86)}\Steam\steamapps\common\Deus Ex\Revision",
	[string]$Map = "01_NYC_UNATCOIsland",
	[string]$GameClass = "RevNet.CoopGameInfo",
	[int]$Clients = 1,
	[int]$Seconds = 240,
	[int]$Port = 7790,
	[string]$Extra = "",
	[string]$NetName = "CoopNet",  # dev folder (tools/setup_net.sh NETNAME)
	[int]$ClientGap = 3,           # seconds between the clients' starts
	[switch]$SameName,             # every client is Tester1 (one coming back while its old self is still in)
	[switch]$Visible,              # the host's window shown (not minimized, still no focus): for screenshots ("shot")
	[string]$Renderer = "",        # e.g. OpenGLDrv.OpenGLRenderDevice: its "shot" is the game's own frame, also on a locked screen
	[string]$HostAgent = "",       # the host's class (CoopLaunch.Agent): Mech, else JC's kind
	[string]$ClientAgent = ""      # every client's class
)
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "desktop_helpers.ps1")
$sys = Join-Path $Rev "System"
$net = Join-Path $Rev $NetName
$exe = Join-Path $net "Revision.exe"   # copy in CoopNet (tools/setup_net.sh)
$mute = Join-Path $PSScriptRoot "mute_process.ps1"

$waitUntil = (Get-Date).AddHours(6)
while ((Test-FullscreenForeground) -and (Get-Date) -lt $waitUntil) { Start-Sleep -Seconds 60 }

# Test inis: windowed, small, silent, no first-run wizard.
function Write-TestIni($name) {
	(Get-Content (Join-Path $net "RevNet.ini")) -replace '^FirstRun=.*$','FirstRun=1100' `
		-replace '^(MusicVolume|SoundVolume|SpeechVolume)=.*$','$1=0' `
		-replace '^StartupFullscreen=.*$','StartupFullscreen=False' -replace '^Port=\d+$',"Port=$Port" `
		-replace '^CaptureMouse=.*$','CaptureMouse=False' `
		-replace '^WindowedViewportX=.*$','WindowedViewportX=640' -replace '^WindowedViewportY=.*$','WindowedViewportY=480' |
		ForEach-Object { if ($Renderer) { $_ -replace '^GameRenderDevice=.*$',"GameRenderDevice=$Renderer" } else { $_ } } |
		Set-Content (Join-Path $net $name)
}
# The URL to open goes into the user ini (CoopLaunch.AutoOpen): Revision's launcher ignores it
# on the command line.
function Write-UserIni($name, $playerName, $open, $agent, [switch]$IsHost) {
	# The host's [DefaultPlayer] Listen= puts ?Listen on every URL it opens, also the
	# one a saved game is loaded with (DeusEx builds that one from these defaults).
	$nameLine = if ($IsHost) { "Name=$playerName`r`nListen=" } else { "Name=$playerName" }
	$lines = (Get-Content (Join-Path $net "RevNetUser.ini")) -replace '^Name=.*$',$nameLine |
		Where-Object { $_ -notmatch '^\[RevNet\.CoopLaunch\]' -and $_ -notmatch '^AutoOpen=' -and $_ -notmatch "^Listen=" -and $_ -notmatch '^Agent=' }
	$lines + @("", "[RevNet.CoopLaunch]", "AutoOpen=$open", "Agent=$agent") | Set-Content (Join-Path $net $name)
}
Write-TestIni "NetHost.ini"
$url = "${Map}?Listen?Port=${Port}?Game=${GameClass}${Extra}"
Write-UserIni "NetHostUser.ini" "Host" $url $HostAgent -IsHost
$procs = @()
$hostLog = "NetHost.log"
Remove-Item (Join-Path $net $hostLog) -ErrorAction SilentlyContinue
# A game killed earlier leaves Running.ini: the next start would wait on UE1's
# "safe mode?" dialog, unseen (minimized), forever.
Remove-Item (Join-Path $net "Running.ini") -ErrorAction SilentlyContinue
# Working directory CoopNet: its steam_appid.txt stops Revision.exe from relaunching itself
# through Steam (which drops the arguments); it is a sibling of System, so ..\ paths still work.
# Ini and log files are in CoopNet (the exe folder).
$procs += Start-NoActivate $exe "INI=NetHost.ini USERINI=NetHostUser.ini -log=$hostLog" $net -Visible:$Visible
# Clients join once the host listens on the map (its log is locked while running: poll it shared).
function Read-Shared($path) {
	try { $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite'); $sr = New-Object IO.StreamReader($fs); $t = $sr.ReadToEnd(); $sr.Close(); return $t } catch { return "" }
}
$ready = (Get-Date).AddSeconds(180)
while ((Get-Date) -lt $ready -and (Read-Shared (Join-Path $net $hostLog)) -notmatch "Browse: ${Map}") { & $mute -Name Revision | Out-Null; Start-Sleep -Seconds 3 }
Start-Sleep -Seconds 15
for ($i = 1; $i -le $Clients; $i++) {
	Write-TestIni "NetClient$i.ini"
	$clientName = if ($SameName) { "Tester1" } else { "Tester$i" }
	Write-UserIni "NetClient${i}User.ini" $clientName "127.0.0.1:${Port}" $ClientAgent
	Remove-Item (Join-Path $net "NetClient$i.log") -ErrorAction SilentlyContinue
	$procs += Start-NoActivate $exe "INI=NetClient$i.ini USERINI=NetClient${i}User.ini -log=NetClient$i.log" $net
	Start-Sleep -Seconds $ClientGap
}
$end = (Get-Date).AddSeconds($Seconds)
while ((Get-Date) -lt $end -and @($procs | Where-Object { -not $_.HasExited }).Count -gt 0) {
	& $mute -Name Revision | Out-Null
	Start-Sleep -Seconds 10
}
# Close politely so the logs flush, then force.
foreach ($p in $procs) { if (-not $p.HasExited) { $p.CloseMainWindow() | Out-Null } }
Start-Sleep -Seconds 10
foreach ($p in $procs) { if (-not $p.HasExited) { $p.Kill(); Write-Output "killed pid $($p.Id) (did not close)" } }
foreach ($log in @($hostLog) + (1..$Clients | ForEach-Object { "NetClient$_.log" })) {
	$path = Join-Path $net $log
	if (-not (Test-Path $path)) { Write-Output "== $log missing"; continue }
	Write-Output "== $log ($((Get-Item $path).Length) bytes)"
	Get-Content $path | Where-Object { $_ -match 'Critical|General protection|Browse|Welcomed|Login|Join|mismatch|Failed to' } | Select-Object -First 25
	Get-Content $path | Where-Object { $_ -match 'RevNet' -and $_ -notmatch 'RevNetTest: (always relevant|other):' }
	# The most frequent script warnings, to spot new breakage.
	Get-Content $path | Where-Object { $_ -match '^ScriptWarning:|^Warning: .*(Accessed None|Function )' } |
		ForEach-Object { $_ -replace '\d+(\.\d+)?', '#' } | Group-Object | Sort-Object Count -Descending | Select-Object -First 8 |
		ForEach-Object { "  x$($_.Count) $($_.Name)" }
}
