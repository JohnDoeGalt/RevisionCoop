# Mutes (or unmutes) every audio session of the named processes in the Windows volume
# mixer, e.g. the test games: powershell -File tools/mute_process.ps1 [-Name HX] [-Unmute]
# -WatchSeconds N: keep muting every 5 s until no such process is left or N seconds pass.
param([string]$Name = "HX", [switch]$Unmute, [int]$WatchSeconds = 0)
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
	int NotImpl1();
	[PreserveSig] int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
	[PreserveSig] int Activate(ref Guid iid, int dwClsCtx, IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
}
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 {
	int NotImpl1(); int NotImpl2();
	[PreserveSig] int GetSessionEnumerator(out IAudioSessionEnumerator SessionEnum);
}
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator {
	[PreserveSig] int GetCount(out int SessionCount);
	[PreserveSig] int GetSession(int SessionCount, out IAudioSessionControl2 Session);
}
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
	int NotImpl0(); int NotImpl1(); int NotImpl2(); int NotImpl3(); int NotImpl4(); int NotImpl5(); int NotImpl6(); int NotImpl7(); int NotImpl8();
	int NotImpl9(); int NotImpl10();
	[PreserveSig] int GetProcessId(out uint pRetVal);
}
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume {
	int NotImpl1(); int NotImpl2();
	[PreserveSig] int SetMute(bool bMute, ref Guid EventContext);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCom { }

public static class AppMute {
	public static int Set(int[] pids, bool mute) {
		var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCom();
		IMMDevice dev; en.GetDefaultAudioEndpoint(0, 1, out dev);
		var iid = typeof(IAudioSessionManager2).GUID; object o;
		dev.Activate(ref iid, 23, IntPtr.Zero, out o);
		IAudioSessionEnumerator sessions; ((IAudioSessionManager2)o).GetSessionEnumerator(out sessions);
		int count, done = 0; sessions.GetCount(out count);
		for (int i = 0; i < count; i++) {
			IAudioSessionControl2 s; sessions.GetSession(i, out s);
			uint pid; s.GetProcessId(out pid);
			if (Array.IndexOf(pids, (int)pid) < 0) continue;
			var g = Guid.Empty; ((ISimpleAudioVolume)s).SetMute(mute, ref g); done++;
		}
		return done;
	}
}
"@
$deadline = (Get-Date).AddSeconds($WatchSeconds)
do {
	$pids = @(Get-Process -Name $Name -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
	if ($pids.Count -eq 0) { Write-Output "no $Name processes"; exit 0 }
	$n = [AppMute]::Set($pids, -not $Unmute)
	Write-Output "$(if ($Unmute) {'unmuted'} else {'muted'}) $n audio session(s) of $($pids.Count) $Name process(es)"
	if ($WatchSeconds -gt 0) { Start-Sleep -Seconds 5 }
} while ((Get-Date) -lt $deadline)
