# Installs Deus Ex: Revision Co-op (RevNet) into <Deus Ex>\Revision\CoopNet.
# Nothing outside that folder is changed (plus a desktop shortcut). Run through Install.bat.
param([string]$DeusEx = "", [switch]$NoShortcut)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Stop-Install($msg) { Write-Host "`n$msg" -ForegroundColor Red; exit 1 }

# Replaces whole [sections] of ini $To with the same sections of ini $From (where present).
function Copy-IniSections($From, $To, $Sections) {
	if (-not (Test-Path $From)) { return $false }
	$src = @{}; $cur = $null
	foreach ($l in Get-Content $From) {
		if ($l -match '^\[(.+)\]\s*$') { $cur = $Matches[1]; if ($Sections -contains $cur) { $src[$cur] = @() } }
		elseif ($cur -and $src.ContainsKey($cur) -and $l.Trim()) { $src[$cur] += $l }
	}
	if ($src.Count -eq 0) { return $false }
	$out = New-Object System.Collections.Generic.List[string]; $skip = $false
	foreach ($l in Get-Content $To) {
		if ($l -match '^\[(.+)\]\s*$') {
			$skip = $src.ContainsKey($Matches[1])
			$out.Add($l)
			if ($skip) { foreach ($s in $src[$Matches[1]]) { $out.Add($s) }; $out.Add("") }
			continue
		}
		if (-not $skip) { $out.Add($l) }
	}
	Set-Content $To $out -Encoding Default
	return $true
}

function Find-DeusEx {
	$steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
	$libs = @()
	foreach ($root in @($steam, "${env:ProgramFiles(x86)}\Steam", "$env:ProgramFiles\Steam")) {
		if (-not $root) { continue }
		$libs += $root
		$vdf = Join-Path $root "steamapps\libraryfolders.vdf"
		if (Test-Path $vdf) {
			foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
		}
	}
	foreach ($lib in ($libs | Select-Object -Unique)) {
		$dx = Join-Path $lib "steamapps\common\Deus Ex"
		if (Test-Path (Join-Path $dx "Revision\System\Revision.u")) { return $dx }
	}
	return $null
}

Write-Host "Deus Ex: Revision Co-op installer" -ForegroundColor Green

Step "Finding Deus Ex: Revision"
if (-not $DeusEx) { $DeusEx = Find-DeusEx }
if (-not $DeusEx) {
	Start-Process "steam://install/397550"
	Stop-Install "Deus Ex: Revision is not installed. Steam is opening its install page: install it (free with Deus Ex GOTY), then run Install.bat again."
}
$rev = Join-Path $DeusEx "Revision"
$revSys = Join-Path $rev "System"
$sys = Join-Path $DeusEx "System"
if (-not (Test-Path (Join-Path $sys "Core.u"))) {
	Start-Process "steam://install/6910"
	Stop-Install "Deus Ex: Revision needs the Deus Ex: Game of the Year Edition files, which are not installed. Steam is opening its install page: install it into the same Steam library, then run Install.bat again."
}
Write-Host "Found $DeusEx"
$net = Join-Path $rev "CoopNet"
$pay = Join-Path $here "CoopNet"

# Co-op runs Revision's own code: a different Revision version may still work, but this
# release was tested with these files.
$changed = @()
foreach ($l in Get-Content (Join-Path $here "versions.txt")) {
	$f, $size = $l -split '\|'
	$p = Join-Path $rev $f
	if (-not (Test-Path $p) -or (Get-Item $p).Length -ne [long]$size) { $changed += $f }
}
if ($changed.Count -gt 0) {
	Write-Host "Note: your Revision files differ from the version this release was tested with ($(($changed | Select-Object -First 3) -join ', ')). It will probably still work; if co-op doesn't start, look for a newer Revision Co-op release." -ForegroundColor Yellow
}

Step "Installing into $net"
New-Item -ItemType Directory -Force $net, (Join-Path $net "Modes"), (Join-Path $net "Relay") | Out-Null
# Revision's engine, run from a sibling of its System folder (so its ..\ paths are the same):
# Deus Ex's DLLs as fallbacks (other renderers), then Revision's.
Copy-Item (Join-Path $sys "*.dll"), (Join-Path $sys "*.int") $net -Force
Copy-Item (Join-Path $revSys "*.dll"), (Join-Path $revSys "*.int") $net -Force
Copy-Item (Join-Path $revSys "Revision.exe") $net -Force
# In the working directory: keeps Revision from restarting itself through Steam without our arguments.
Set-Content (Join-Path $net "steam_appid.txt") "397550" -NoNewline -Encoding Ascii
Copy-Item (Join-Path $pay "RevNet.u") $net -Force

# The ini: the release's, with the player's display and sound settings (from the co-op ini being
# replaced, else from Revision's).
$display = @("WinDrv.WindowsClient", "D3D9Drv.D3D9RenderDevice", "D3DDrv.D3DRenderDevice", "OpenGLDrv.OpenGLRenderDevice", "RGalaxy.GalaxyAudioSubsystem", "ALAudio.ALAudioSubsystem")
$ini = Join-Path $net "RevNet.ini"
$oldIni = Join-Path $net "RevNet.ini.previous"
if (Test-Path $ini) { Copy-Item $ini $oldIni -Force }
Copy-Item (Join-Path $pay "RevNet.ini"), (Join-Path $pay "RevNetDefault.ini"), (Join-Path $pay "RevNetDefUser.ini") $net -Force
if (Copy-IniSections $oldIni $ini $display) { Write-Host "Kept your display and sound settings." }
elseif (Copy-IniSections (Join-Path $revSys "Revision.ini") $ini $display) { Write-Host "Using your Revision display and sound settings." }
Remove-Item $oldIni -ErrorAction SilentlyContinue
Copy-Item (Join-Path $pay "Modes\*.mode") (Join-Path $net "Modes") -Force

# Controls: the player's own Revision key bindings (first install only), at broadband net speed
# (the default modem speed takes minutes to send a Revision map to a client).
$user = Join-Path $net "RevNetUser.ini"
if (-not (Test-Path $user)) {
	$mine = Join-Path $revSys "RevisionUser.ini"
	if (Test-Path $mine) { Copy-Item $mine $user; Write-Host "Using your Revision key bindings." }
	else { Copy-Item (Join-Path $net "RevNetDefUser.ini") $user }
}
(Get-Content $user) -replace '^NetSpeed=.*', 'NetSpeed=20000' | Set-Content $user -Encoding Default

# The Steam launcher (host, join, continue): its own steam_api.dll and AppID 480 (Steam's
# networking test app, which any Steam account can use).
Copy-Item (Join-Path $here "Relay\*") (Join-Path $net "Relay") -Force

$old = Join-Path $rev "Coop"
if (Test-Path (Join-Path $old "HX.exe")) {
	Write-Host "The older Revision Co-op (0.1, based on HX) in $old is replaced by this one; Uninstall.bat removes both." -ForegroundColor Yellow
}

if (-not $NoShortcut) {
	Step "Creating the desktop shortcut"
	$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Revision Co-op.lnk"
	$s = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk)
	$s.TargetPath = Join-Path $net "Relay\RevCoop.exe"
	$s.WorkingDirectory = Join-Path $net "Relay"
	$s.IconLocation = (Join-Path $revSys "Revision.exe") + ",0"
	$s.Description = "Deus Ex: Revision co-op"
	$s.Save()
}

Write-Host "`nDone. Open 'Revision Co-op' on your desktop to host or join." -ForegroundColor Green
Write-Host "Your friends need the same install (their game takes the host's gameplay mode by itself). Steam must be running."
