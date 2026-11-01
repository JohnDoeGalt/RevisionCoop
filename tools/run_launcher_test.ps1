# Live test of the launcher (CoopNet\Relay\RevCoop.exe) through its real window: pick the
# "Assault rifle" entry, Host a new game, then check settings.txt, RevNet.ini and the game's log
# (the game must start a co-op game, with or without the rifle rework as picked). Steam must be
# running. What it touches (RevNet.ini, RevNetUser.ini, Modes\settings.txt) is put back after;
# the game runs windowed and is closed.
#   powershell -NoProfile -File tools/run_launcher_test.ps1 [-Rifle 0|1] [-Agent 0|1|2] [-NetName CoopNet]
#   -Rifle 0: "7.62 battle rifle, select fire" (RifleRework=1); 1: "The mode's own" (RifleRework=0)
#   -Agent (optional) "You play as": 0 JC's kind, 1 the Mech, 2 the Light Mech: RevNetUser.ini's
#   Agent and the class the host plays as (the game's log) must follow.
#   -Difficulty (optional) 0..4, 4 "Custom (set in game)": the game must start with custom difficulty
#   (with -UrlExtra "?CustomAuto=A" the game goes through Revision's screens by itself).
#   -Switch (optional) 0..7: switched in the "Options..." menu (its keys posted to the menu): settings.txt's
#   Switches and RevNet.ini's [Revision.RevGameInfo] and [RevNet.CoopGameInfo] keys must follow.
param([int]$Rifle = 1, [int]$Agent = -1, [string]$NetName = "CoopNet", [int]$Wait = 50, [int]$Difficulty = -1, [int]$Switch = -1, [string]$UrlExtra = "")
$switchKeys = @("bNewSkillSystem", "bBioModAugTracking", "bBioModNoReticleForScopedWeapons", "bShifterEnableRandomInventory",
	"bShifterEnableOverpoweredUniqueWeapons", "bShifterEnableMiniRocketLauncher", "bShifterEnabledShotgunAmmoPacking", "bShifterEnableWeaponModRateOfFire")
$agentKeys = @("", "Mech", "LightMech")
$agentLogs = @("", "is a Mech", "is a Light Mech")
$ErrorActionPreference = "Stop"
$net = Join-Path "C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision" $NetName
. (Join-Path $PSScriptRoot "desktop_helpers.ps1")
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
Add-Type 'using System; using System.Runtime.InteropServices; public static class LaunchU { [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, int m, IntPtr w, IntPtr l); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, int m, IntPtr w, IntPtr l); [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string c, string t); }'
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
	$launchArgs = "--game-args -log=LauncherTest.log"
	if ($UrlExtra) { $launchArgs += " --url-extra $UrlExtra" }
	$launcher = Start-NoActivate (Join-Path $net "Relay\RevCoop.exe") $launchArgs (Join-Path $net "Relay") -Visible
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
	function Pick($id, $want) {
		$hc = [IntPtr](Ctl $id).Current.NativeWindowHandle
		$cur = [int][LaunchU]::SendMessage($hc, 0x147, [IntPtr]::Zero, [IntPtr]::Zero)      # CB_GETCURSEL
		while ($cur -ne $want) {
			$vk = if ($want -gt $cur) { 0x28 } else { 0x26 }                                 # VK_DOWN / VK_UP
			[LaunchU]::SendMessage($hc, 0x100, [IntPtr]$vk, [IntPtr]::Zero) | Out-Null
			[LaunchU]::SendMessage($hc, 0x101, [IntPtr]$vk, [IntPtr]::Zero) | Out-Null
			$next = [int][LaunchU]::SendMessage($hc, 0x147, [IntPtr]::Zero, [IntPtr]::Zero)
			if ($next -eq $cur) { throw "the combo $id did not move" }
			$cur = $next
		}
	}
	Pick 117 $Rifle
	if ($Agent -ge 0) { Pick 116 $Agent; Write-Output ("plays as '{0}'" -f (Ctl 116).Current.Name) }
	if ($Difficulty -ge 0) { Pick 104 $Difficulty; Write-Output ("difficulty '{0}'" -f (Ctl 104).Current.Name) }
	$switchWant = $null
	if ($Switch -ge 0) {
		$before = [int](((Get-Content (Join-Path $net "Modes\settings.txt")) -match '^Switches=') -replace 'Switches=', '' | Select-Object -First 1)
		if (-not ((Get-Content (Join-Path $net "Modes\settings.txt")) -match '^Switches=')) { $before = 255 }
		# The menu is modal (TrackPopupMenu): posted, not sent; then its own keys.
		[LaunchU]::PostMessage([IntPtr](Ctl 118).Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # BM_CLICK
		$until = (Get-Date).AddSeconds(5)
		do { Start-Sleep -Milliseconds 200; $menu = [LaunchU]::FindWindow("#32768", $null) } until ($menu -ne [IntPtr]::Zero -or (Get-Date) -gt $until)
		if ($menu -eq [IntPtr]::Zero) { throw "the Options menu did not open" }
		for ($i = 0; $i -le $Switch; $i++) { [LaunchU]::PostMessage($menu, 0x100, [IntPtr]0x28, [IntPtr]::Zero) | Out-Null; Start-Sleep -Milliseconds 100 }   # VK_DOWN
		[LaunchU]::PostMessage($menu, 0x100, [IntPtr]0x0D, [IntPtr]::Zero) | Out-Null                                                                      # VK_RETURN
		Start-Sleep -Seconds 1
		$after = [int](((Get-Content (Join-Path $net "Modes\settings.txt")) -match '^Switches=') -replace 'Switches=', '' | Select-Object -First 1)
		$switchWant = if ((($after -shr $Switch) -band 1) -eq 1) { "True" } else { "False" }
		Write-Output ("switches {0} -> {1} ({2} now {3})" -f $before, $after, $switchKeys[$Switch], $switchWant)
		if (($before -bxor $after) -ne (1 -shl $Switch)) { throw "the menu switched something else" }
	}
	Start-Sleep -Seconds 1
	$saved = (Get-Content (Join-Path $net "Modes\settings.txt")) -match '^Rifle='
	Write-Output ("picked '{0}'; settings.txt {1}" -f (Ctl 117).Current.Name, $(if ($saved) { $saved } else { "(unchanged)" }))
	[LaunchU]::SendMessage([IntPtr]$hostBtn.Current.NativeWindowHandle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) | Out-Null   # BM_CLICK
	Start-Sleep -Seconds 3
	$rework = ((Get-Content (Join-Path $net "RevNet.ini")) -match '^RifleRework=') -join ","
	Write-Output "RevNet.ini $rework"
	$switchLines = ""
	if ($switchWant) {
		$switchLines = ((Get-Content (Join-Path $net "RevNet.ini")) -match "^$($switchKeys[$Switch])=") -join ","
		Write-Output "RevNet.ini $switchLines"
	}
	$agentLine = ((Get-Content (Join-Path $net "RevNetUser.ini")) -match '^Agent=') -join ","
	if ($Agent -ge 0) { Write-Output "RevNetUser.ini $agentLine" }
	Start-Sleep -Seconds $Wait
	Write-Output ("launcher: '{0}'" -f (Ctl 114).Current.Name)
}
finally {
	Get-Process Revision -ErrorAction SilentlyContinue | ForEach-Object { $_.CloseMainWindow() | Out-Null }
	Start-Sleep -Seconds 6
	Get-Process Revision -ErrorAction SilentlyContinue | Stop-Process -Force
	if ($launcher -and -not $launcher.HasExited) { $launcher.CloseMainWindow() | Out-Null; Start-Sleep -Seconds 3; if (-not $launcher.HasExited) { $launcher.Kill() } }
	$lines = @()
	if (Test-Path $log) { $lines = @(Get-Content $log | Where-Object { $_ -match 'RevNet: co-op game True|RevNet: assault rifle|Critical|is a (Light )?Mech|custom difficulty (True|False)|customdiff menu page' }) }
	$lines | Select-Object -First 5
	$coop = @($lines | Where-Object { $_ -match 'co-op game True' }).Count -gt 0
	$reworked = @($lines | Where-Object { $_ -match 'assault rifle' }).Count -gt 0   # (not $rifle: PowerShell names ignore case)
	$ok = $coop -and ($reworked -eq ($Rifle -eq 0)) -and ($rework -eq "RifleRework=$(1 - $Rifle)")
	if ($Agent -ge 0) {
		$classed = @($lines | Where-Object { $_ -match 'is a (Light )?Mech' })
		$asPicked = if ($Agent -eq 0) { $classed.Count -eq 0 } else { @($classed | Where-Object { $_ -match "$($agentLogs[$Agent])`$" }).Count -gt 0 }
		$ok = $ok -and ($agentLine -eq "Agent=$($agentKeys[$Agent])") -and $asPicked
	}
	if ($Difficulty -ge 0) {
		$custom = @($lines | Where-Object { $_ -match 'custom difficulty True' }).Count -gt 0
		$ok = $ok -and ($custom -eq ($Difficulty -eq 4))
		Write-Output ("custom difficulty in the game: {0}" -f $custom)
	}
	if ($switchWant) { $ok = $ok -and ($switchLines -eq ("{0}={1},{0}={1}" -f $switchKeys[$Switch], $switchWant)) }
	foreach ($f in $files) { $b = Join-Path $bak ($f -replace '\\', '_'); if (Test-Path $b) { Copy-Item $b (Join-Path $net $f) -Force } }
	Remove-Item $log, (Join-Path $net "Running.ini") -ErrorAction SilentlyContinue
	if (-not $coop) { Write-Output "the game logged no co-op start (a Steam error dialog, Recovery Mode?)" }
	Write-Output $(if ($ok) { "PASS launcher rifle=$Rifle agent=$Agent" } else { "FAIL launcher rifle=$Rifle agent=$Agent" })
}
