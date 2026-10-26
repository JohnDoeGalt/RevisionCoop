# Live test of the launcher (CoopNet\Relay\RevCoop.exe) through its real window: pick the
# "Assault rifle" entry, Host a new game, then check settings.txt, RevNet.ini and the game's log
# (the game must start a co-op game, with or without the rifle rework as picked). Steam must be
# running. What it touches (RevNet.ini, RevNetUser.ini, Modes\settings.txt) is put back after;
# the game runs windowed and is closed.
#   powershell -NoProfile -File tools/run_launcher_test.ps1 [-Rifle 0|1] [-NetName CoopNet]
#   -Rifle 0: "7.62 battle rifle, select fire" (RifleRework=1); 1: "The mode's own" (RifleRework=0)
param([int]$Rifle = 1, [string]$NetName = "CoopNet", [int]$Wait = 50)
$ErrorActionPreference = "Stop"
$net = Join-Path "C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision" $NetName
. (Join-Path $PSScriptRoot "desktop_helpers.ps1")
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type 'using System; using System.Runtime.InteropServices; public static class LaunchU { [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l); }'
$AE = [Windows.Automation.AutomationElement]
$files = @("RevNet.ini", "RevNetUser.ini", "Modes\settings.txt")
$bak = Join-Path $env:TEMP "RevNetLauncherTest"
New-Item -ItemType Directory -Force $bak | Out-Null
foreach ($f in $files) { $p = Join-Path $net $f; if (Test-Path $p) { Copy-Item $p (Join-Path $bak ($f -replace '\\', '_')) -Force } }
$log = Join-Path $net "LauncherTest.log"
$launcher = $null
$ok = $false
try {
	if (Test-FullscreenForeground) { throw "a fullscreen program is in front: not testing" }
	(Get-Content (Join-Path $net "RevNet.ini")) -replace '^StartupFullscreen=.*$', 'StartupFullscreen=False' | Set-Content (Join-Path $net "RevNet.ini") -Encoding Default
	Remove-Item $log, (Join-Path $net "Running.ini") -ErrorAction SilentlyContinue   # (a killed game's Running.ini: Recovery Mode)
	$launcher = Start-NoActivate (Join-Path $net "Relay\RevCoop.exe") "--game-args -log=LauncherTest.log" (Join-Path $net "Relay") -Visible
	$byPid = New-Object Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $launcher.Id)
	$until = (Get-Date).AddSeconds(30)
	do { Start-Sleep -Milliseconds 500; $win = $AE::RootElement.FindFirst([Windows.Automation.TreeScope]::Children, $byPid) } until ($win -or (Get-Date) -gt $until)
	if (-not $win) { throw "no launcher window" }
	# Its controls by id (revcoop_relay.c: ID_HOST 108, ID_STATUS 114, ID_LOG 115, ID_RIFLE 117). They
	# have no UI Automation patterns, so the user's own messages: arrow keys in the combo (it sends
	# CBN_SELCHANGE itself), BM_CLICK on Host.
	function Ctl($id) { $win.FindFirst([Windows.Automation.TreeScope]::Descendants, (New-Object Windows.Automation.PropertyCondition($AE::AutomationIdProperty, "$id"))) }
	$hostBtn = Ctl 108
	$until = (Get-Date).AddSeconds(60)
	while (-not $hostBtn.Current.IsEnabled -and (Get-Date) -lt $until) { Start-Sleep -Seconds 1 }
	if (-not $hostBtn.Current.IsEnabled) { throw "Host stays disabled (is Steam running?)" }
	$hc = [IntPtr](Ctl 117).Current.NativeWindowHandle
	$cur = [int][LaunchU]::SendMessage($hc, 0x147, [IntPtr]::Zero, [IntPtr]::Zero)          # CB_GETCURSEL
	while ($cur -ne $Rifle) {
		$vk = if ($Rifle -gt $cur) { 0x28 } else { 0x26 }                                     # VK_DOWN / VK_UP
		[LaunchU]::SendMessage($hc, 0x100, [IntPtr]$vk, [IntPtr]::Zero) | Out-Null
		[LaunchU]::SendMessage($hc, 0x101, [IntPtr]$vk, [IntPtr]::Zero) | Out-Null
		$next = [int][LaunchU]::SendMessage($hc, 0x147, [IntPtr]::Zero, [IntPtr]::Zero)
		if ($next -eq $cur) { throw "the rifle combo did not move" }
		$cur = $next
	}
	Start-Sleep -Seconds 1
	$saved = (Get-Content (Join-Path $net "Modes\settings.txt")) -match '^Rifle='
	Write-Output ("picked '{0}'; settings.txt {1}" -f (Ctl 117).Current.Name, $(if ($saved) { $saved } else { "(unchanged)" }))
	[LaunchU]::SendMessage([IntPtr]$hostBtn.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # BM_CLICK
	Start-Sleep -Seconds 3
	$rework = ((Get-Content (Join-Path $net "RevNet.ini")) -match '^RifleRework=') -join ","
	Write-Output "RevNet.ini $rework"
	Start-Sleep -Seconds $Wait
	Write-Output ("launcher: '{0}'" -f (Ctl 114).Current.Name)
}
finally {
	Get-Process Revision -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
	Start-Sleep -Seconds 6
	Get-Process Revision -ErrorAction SilentlyContinue | Stop-Process -Force
	if ($launcher -and -not $launcher.HasExited) { $launcher.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 3; if (-not $launcher.HasExited) { $launcher.Kill() } }
	$lines = @()
	if (Test-Path $log) { $lines = @(Get-Content $log | Where-Object { $_ -match 'RevNet: co-op game True|RevNet: assault rifle|Critical' }) }
	$lines | Select-Object -First 4
	$coop = @($lines | Where-Object { $_ -match 'co-op game True' }).Count -gt 0
	$reworked = @($lines | Where-Object { $_ -match 'assault rifle' }).Count -gt 0   # (not $rifle: PowerShell names ignore case)
	$ok = $coop -and ($reworked -eq ($Rifle -eq 0)) -and ($rework -eq "RifleRework=$(1 - $Rifle)")
	foreach ($f in $files) { $b = Join-Path $bak ($f -replace '\\', '_'); if (Test-Path $b) { Copy-Item $b (Join-Path $net $f) -Force } }
	Remove-Item $log, (Join-Path $net "Running.ini") -ErrorAction SilentlyContinue
	if (-not $coop) { Write-Output "the game logged no co-op start (a Steam error dialog, Recovery Mode?)" }
	Write-Output $(if ($ok) { "PASS launcher rifle=$Rifle" } else { "FAIL launcher rifle=$Rifle" })
}
