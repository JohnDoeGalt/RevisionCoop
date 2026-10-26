# Host and Join end to end through the launcher's relay, on one PC with one Steam account:
# RevCoopFake.exe (src/relay/build.bat fake) is the launcher with Steam played by the two relays
# (UDP between them, the lobby a file). The host's launcher in -HostNet hosts with a scenario on
# its URL; a friend's launcher in -JoinNet (best in another mode) joins lobby 5001: the lobby's
# version check, the joiner taking the host's mode, both games through the relay (map changes
# too). What the launchers change in the two folders is put back after.
#   powershell -NoProfile -File tools/run_relay_test.ps1 [-Scenario travel] [-Map 01_NYC_UNATCOIsland]
#              [-HostNet CoopNet] [-JoinNet CoopNetC] [-Seconds 300]
param([string]$Scenario = "travel", [string]$Map = "01_NYC_UNATCOIsland", [string]$HostNet = "CoopNet",
	[string]$JoinNet = "CoopNetC", [int]$Seconds = 300)
$ErrorActionPreference = "Stop"
$rev = "C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision"
$fake = Join-Path (Split-Path $PSScriptRoot -Parent) "src\relay\RevCoopFake.exe"
if (-not (Test-Path $fake)) { throw "build src\relay\RevCoopFake.exe first (src\relay\build.bat fake)" }
. (Join-Path $PSScriptRoot "desktop_helpers.ps1")
$nets = [ordered]@{ host = (Join-Path $rev $HostNet); join = (Join-Path $rev $JoinNet) }
$logs = @{ host = "RelayHost.log"; join = "RelayJoin.log" }
$files = @("RevNet.ini", "RevNetUser.ini", "Modes\settings.txt")
$bak = Join-Path $env:TEMP "RevNetRelayTest"
New-Item -ItemType Directory -Force $bak | Out-Null
foreach ($k in $nets.Keys) { foreach ($f in $files) { $p = Join-Path $nets[$k] $f; if (Test-Path $p) { Copy-Item $p (Join-Path $bak ("{0}_{1}" -f $k, ($f -replace '\\', '_'))) -Force } } }
function FirstPath($net) { ((Get-Content (Join-Path $net "RevNet.ini")) -match '^Paths=' | Select-Object -First 1) }
$joinBefore = FirstPath $nets.join
$relays = @()
$joinAfter = ""
try {
	$wait = (Get-Date).AddMinutes(30)                       # someone's game in front: wait for it
	while ((Test-FullscreenForeground) -and (Get-Date) -lt $wait) { Start-Sleep -Seconds 30 }
	if (Test-FullscreenForeground) { throw "a fullscreen program stayed in front: not testing" }
	foreach ($k in $nets.Keys) {
		$n = $nets[$k]
		(Get-Content (Join-Path $n "RevNet.ini")) -replace '^StartupFullscreen=.*$', 'StartupFullscreen=False' | Set-Content (Join-Path $n "RevNet.ini") -Encoding Default
		Remove-Item (Join-Path $n $logs[$k]), (Join-Path $n "Running.ini") -ErrorAction SilentlyContinue
		Copy-Item $fake (Join-Path $n "Relay\RevCoopFake.exe") -Force
	}
	$env:REVCOOP_FAKE_ME = "1001"
	$relays += Start-NoActivate (Join-Path $nets.host "Relay\RevCoopFake.exe") "host $Map --game-args -log=$($logs.host) --url-extra ?CoopTest=$Scenario" (Join-Path $nets.host "Relay")
	# The joiner once the host listens on the map (its status window is titled "<level>: <map> (n players)").
	$until = (Get-Date).AddSeconds(180)
	do {
		Start-Sleep -Seconds 2
		$hostGame = Get-CimInstance Win32_Process -Filter "Name='Revision.exe'" | Where-Object { $_.CommandLine -match [regex]::Escape($logs.host) } | Select-Object -First 1
		$up = $hostGame -and ([Desk]::WindowTitles([int]$hostGame.ProcessId) -match ": $Map \(")
	} until ($up -or (Get-Date) -gt $until)
	if (-not $up) { throw "the host's game did not come up on $Map" }
	Write-Output "host: hosting $Map through its relay"
	Start-Sleep -Seconds 10
	$env:REVCOOP_FAKE_ME = "1002"
	$relays += Start-NoActivate (Join-Path $nets.join "Relay\RevCoopFake.exe") "join 5001 --game-args -log=$($logs.join)" (Join-Path $nets.join "Relay")
	Start-Sleep -Seconds 20
	$joinAfter = FirstPath $nets.join
	# Until the scenario ends (its games quit) or time runs out.
	$until = (Get-Date).AddSeconds($Seconds)
	while ((Get-Date) -lt $until -and @(Get-Process Revision -ErrorAction SilentlyContinue).Count -gt 0) { Start-Sleep -Seconds 5 }
}
finally {
	Get-Process Revision -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
	Start-Sleep -Seconds 6
	Get-Process Revision -ErrorAction SilentlyContinue | Stop-Process -Force
	foreach ($r in $relays) { if (-not $r.HasExited) { $r.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 2; if (-not $r.HasExited) { $r.Kill() } } }
	$out = Join-Path (Split-Path $PSScriptRoot -Parent) "build\suite"
	New-Item -ItemType Directory -Force $out | Out-Null
	$text = @{}
	foreach ($k in $nets.Keys) {
		$p = Join-Path $nets[$k] $logs[$k]
		$text[$k] = if (Test-Path $p) { Copy-Item $p (Join-Path $out "relay_$($logs[$k])") -Force; Get-Content $p -Raw } else { "" }
		Remove-Item $p, (Join-Path $nets[$k] "Running.ini"), (Join-Path $nets[$k] "Relay\RevCoopFake.exe") -ErrorAction SilentlyContinue
		foreach ($f in $files) { $b = Join-Path $bak ("{0}_{1}" -f $k, ($f -replace '\\', '_')); if (Test-Path $b) { Copy-Item $b (Join-Path $nets[$k] $f) -Force } }
	}
	Remove-Item Env:REVCOOP_FAKE_ME -ErrorAction SilentlyContinue
	$done = $text.host -match "RevNetTest: done $Scenario"
	$joined = ($text.join -match "Browse: 127\.0\.0\.1:\d+") -and ($text.host -match "FakeJoiner")
	$crit = ([regex]::Matches($text.host + $text.join, '(?m)^Critical')).Count
	$followed = $joinAfter -and ($joinAfter -ne $joinBefore -or $joinBefore -eq (FirstPath $nets.host))
	Write-Output ("joiner's mode: first package path '{0}' -> '{1}' (host's '{2}')" -f $joinBefore, $joinAfter, (FirstPath $nets.host))
	Write-Output ("host log: done {0}, joiner came in through the relay {1}, critical {2}" -f $done, $joined, $crit)
	Write-Output $(if ($done -and $joined -and $crit -eq 0 -and $followed) { "PASS relay $Scenario" } else { "FAIL relay $Scenario" })
}
