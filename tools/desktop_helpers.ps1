# Helpers so live tests don't disturb whoever uses the PC (dot-source it):
#   Test-FullscreenForeground  - is another program fullscreen in the foreground (a game)?
#   Start-NoActivate <exe> <args> <dir>  - start a process minimized without taking focus
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class Desk {
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
	[StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
	public struct STARTUPINFO {
		public int cb; public string lpReserved, lpDesktop, lpTitle;
		public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
		public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
	}
	[StructLayout(LayoutKind.Sequential)] public struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }

	[DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
	[DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
	[DllImport("user32.dll")] static extern int GetSystemMetrics(int i);
	[DllImport("user32.dll")] static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
	[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
	static extern bool CreateProcess(string app, string cmd, IntPtr pa, IntPtr ta, bool inherit, int flags, IntPtr env, string dir, ref STARTUPINFO si, out PROCESS_INFORMATION pi);
	[DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
	// (A hidden desktop via CreateDesktop would be ideal, but UE1 hangs at "Init: Mouse" there.)

	// Process id of a foreground window that covers the whole primary screen, else 0.
	public static int FullscreenForegroundPid() {
		IntPtr h = GetForegroundWindow(); RECT r;
		if (h == IntPtr.Zero || !GetWindowRect(h, out r)) return 0;
		if (r.L > 0 || r.T > 0 || r.R < GetSystemMetrics(0) || r.B < GetSystemMetrics(1)) return 0;
		int pid; GetWindowThreadProcessId(h, out pid); return pid;
	}

	// STARTF_USESHOWWINDOW + SW_SHOWMINNOACTIVE.
	public static int StartNoActivate(string exe, string args, string dir) {
		var si = new STARTUPINFO(); si.cb = Marshal.SizeOf(si); si.dwFlags = 1; si.wShowWindow = 7;
		PROCESS_INFORMATION pi;
		if (!CreateProcess(exe, "\"" + exe + "\" " + args, IntPtr.Zero, IntPtr.Zero, false, 0, IntPtr.Zero, dir, ref si, out pi)) return 0;
		CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return pi.dwProcessId;
	}
}
"@

function Test-FullscreenForeground {
	$id = [Desk]::FullscreenForegroundPid()
	if ($id -eq 0) { return $false }
	$p = Get-Process -Id $id -ErrorAction SilentlyContinue
	# The desktop itself and our own test games don't count.
	return ($p -and $p.ProcessName -notin @("explorer", "HX", "ShellExperienceHost", "SearchHost", "LockApp"))
}

function Start-NoActivate($Exe, $Arguments, $Dir) {
	$id = [Desk]::StartNoActivate($Exe, $Arguments, $Dir)
	if ($id -eq 0) { throw "could not start $Exe" }
	return Get-Process -Id $id
}
