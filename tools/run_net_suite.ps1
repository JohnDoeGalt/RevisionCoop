# Every live scenario (CoopTest<Name>) in turn through tools/run_net_live.ps1, each with the
# options it needs; one line each: the scenario ran to its end ("done"), no Critical error in any
# log, the client(s) joined. Logs are kept in build/suite/<Name>_*.log for the measurements
# (docs/TEST_MATRIX.md has what each should show).
#   powershell -NoProfile -File tools/run_net_suite.ps1 [-Only Save,Rifle] [-NetName CoopNet]
# Left out: Crawl (the whole campaign, hours: run it alone), the screenshot scenarios (Gallery,
# Look, MechLook) and the helpers (Kit, Probe).
param([string[]]$Only = @(), [string]$NetName = "CoopNet")
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })   # (-File hands "a,b" over as one string)
$here = Split-Path $PSScriptRoot -Parent
$net = Join-Path "C:\Program Files (x86)\Steam\steamapps\common\Deus Ex\Revision" $NetName
$out = Join-Path $here "build\suite"
New-Item -ItemType Directory -Force $out | Out-Null
$suite = [ordered]@{
	basic = @("-Seconds", 95); world = @("-Seconds", 120); travel = @("-Seconds", 200, "-ClientAgent", "Mech")
	AugSave = @("-Seconds", 150); Augs = @("-Seconds", 200); Body = @("-Seconds", 200); Cannon = @("-Seconds", 120, "-ClientAgent", "Mech")
	Capture = @("-Map", "04_NYC_Hotel", "-Seconds", 220); Carry = @("-Seconds", 180); Death = @("-Seconds", 300)
	Drones = @("-Seconds", 90, "-ClientAgent", "Mech"); Devices = @("-Seconds", 200); Doors = @("-Seconds", 240); Hazards = @("-Seconds", 240); Heal = @("-Seconds", 200)
	Items = @("-Seconds", 600); Leave = @("-Seconds", 220); LightMech = @("-Seconds", 200, "-ClientAgent", "LightMech"); Mech = @("-Seconds", 160, "-ClientAgent", "Mech")
	MechTree = @("-Seconds", 300, "-ClientAgent", "Mech"); Mission = @("-Seconds", 600); NPC = @("-Seconds", 240, "-Url", "?Difficulty=3")
	Progress = @("-Seconds", 240); Quake = @("-Map", "09_NYC_Ship", "-Seconds", 200); Rejoin = @("-Seconds", 70)
	Revisit = @("-Seconds", 260); Rifle = @("-Seconds", 200); Save = @("-Seconds", 200); Talk = @("-Seconds", 160)
	Throw = @("-Seconds", 200); Twin = @("-Seconds", 180, "-Clients", 2, "-SameName", "-ClientGap", 25)
	UI = @("-Seconds", 300); Weapons = @("-Seconds", 420)
	Security = @("-Seconds", 90); CustomDiff = @("-Seconds", 320, "-Url", "?CustomDifficulty=True?CustomAuto=A")
	FlyKit = @("-Seconds", 120, "-ClientAgent", "Mech")
}
$pass = 0; $fail = 0
foreach ($name in $suite.Keys) {
	if ($Only.Count -and $name -notin $Only) { continue }
	$a = @($suite[$name])
	$extra = "?CoopTest=$name"
	$i = [Array]::IndexOf($a, "-Url")
	if ($i -ge 0) { $extra += $a[$i + 1]; $a = @($a[0..($i - 1)]) + @($a | Select-Object -Skip ($i + 2)) }
	$clients = 1
	$j = [Array]::IndexOf($a, "-Clients"); if ($j -ge 0) { $clients = [int]$a[$j + 1] }
	$t0 = Get-Date
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "run_net_live.ps1") -NetName $NetName @a -Extra $extra | Out-Null
	$secs = [int]((Get-Date) - $t0).TotalSeconds
	$logs = @("NetHost.log") + (1..$clients | ForEach-Object { "NetClient$_.log" })
	$crit = 0
	foreach ($l in $logs) {
		$p = Join-Path $net $l
		if (Test-Path $p) {
			Copy-Item $p (Join-Path $out ("{0}_{1}" -f $name, $l)) -Force
			$crit += @(Select-String -Path $p -Pattern '^Critical|General protection fault' -SimpleMatch:$false).Count
		}
	}
	$hostLog = Join-Path $out "${name}_NetHost.log"
	$done = (Test-Path $hostLog) -and [bool](Select-String -Path $hostLog -Pattern "RevNetTest: done $name" -SimpleMatch -Quiet)
	$joined = @(Get-ChildItem (Join-Path $out "${name}_NetClient*.log") -ErrorAction SilentlyContinue | Where-Object { Select-String -Path $_.FullName -Pattern 'Browse: 127.0.0.1' -SimpleMatch -Quiet }).Count
	$ok = $done -and $crit -eq 0 -and $joined -ge $clients
	if ($ok) { $pass++ } else { $fail++ }
	Write-Output ("{0,-4} {1,-9} done {2,-5} critical {3} clients joined {4}/{5}  {6} s" -f $(if ($ok) { "PASS" } else { "FAIL" }), $name, $done, $crit, $joined, $clients, $secs)
}
Write-Output "suite: $pass passed, $fail failed (logs in $out)"
