# Removes Deus Ex: Revision Co-op: <Deus Ex>\Revision\CoopNet (with its co-op saves), the older
# HX-based <Deus Ex>\Revision\Coop if present, and the desktop shortcut. Revision itself is untouched.
$steam = (Get-ItemProperty "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
$libs = @($steam, "${env:ProgramFiles(x86)}\Steam")
$vdf = Join-Path $steam "steamapps\libraryfolders.vdf"
if ($steam -and (Test-Path $vdf)) {
	foreach ($m in [regex]::Matches((Get-Content $vdf -Raw), '"path"\s+"([^"]+)"')) { $libs += ($m.Groups[1].Value -replace '\\\\', '\') }
}
foreach ($lib in ($libs | Where-Object { $_ } | Select-Object -Unique)) {
	$rev = Join-Path $lib "steamapps\common\Deus Ex\Revision"
	$net = Join-Path $rev "CoopNet"
	if (Test-Path (Join-Path $net "RevNet.u")) { Write-Host "Removing $net"; Remove-Item $net -Recurse -Force }
	$old = Join-Path $rev "Coop"
	if (Test-Path (Join-Path $old "HX.exe")) { Write-Host "Removing $old"; Remove-Item $old -Recurse -Force }
}
$lnk = Join-Path ([Environment]::GetFolderPath("Desktop")) "Revision Co-op.lnk"
if (Test-Path $lnk) { Remove-Item $lnk }
Write-Host "Done."
