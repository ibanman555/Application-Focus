# Application Focus – persistent, hidden Windows helper.
# Reads one JSON command per line and writes one JSON response per line.
# Only enumerates and activates EXISTING top-level windows; never starts target apps.
$ErrorActionPreference = 'Stop'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;

public static class FocusWindows {
    private delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lparam);
    [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr hwnd, StringBuilder text, int maxCount);
    [DllImport("user32.dll")] private static extern int GetWindowTextLength(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint pid);
    [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool ShowWindowAsync(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] private static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint fromThread, uint toThread, bool attach);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    [DllImport("dwmapi.dll")] private static extern int DwmGetWindowAttribute(IntPtr hwnd, int attribute, out int value, int cbSize);

    public class WindowRecord {
        public long hwnd { get; set; }
        public int pid { get; set; }
        public string exe { get; set; }
        public string title { get; set; }
    }

    public static List<WindowRecord> Enumerate() {
        List<WindowRecord> result = new List<WindowRecord>();
        // EnumWindows returns windows in current desktop's Z-order (front first).
        EnumWindows(delegate(IntPtr hwnd, IntPtr unused) {
            if (!IsWindowVisible(hwnd)) return true;
            int length = GetWindowTextLength(hwnd);
            if (length < 1) return true;
            int cloaked = 0;
            try {
                if (DwmGetWindowAttribute(hwnd, 14, out cloaked, 4) == 0 && cloaked != 0) return true;
            } catch { /* DWM optional */ }
            StringBuilder sb = new StringBuilder(Math.Min(length + 2, 4096));
            if (GetWindowText(hwnd, sb, sb.Capacity) < 1) return true;
            uint pid;
            GetWindowThreadProcessId(hwnd, out pid);
            if (pid == 0) return true;
            string exe;
            try {
                using (Process process = Process.GetProcessById((int)pid)) {
                    exe = process.ProcessName + ".exe";
                }
            } catch { return true; }
            result.Add(new WindowRecord { hwnd = hwnd.ToInt64(), pid = (int)pid, exe = exe, title = sb.ToString() });
            return true;
        }, IntPtr.Zero);
        return result;
    }

    private static bool WildcardMatches(string candidate, string pattern) {
        // Case-insensitive '*'/'?' glob; allows names with or without '.exe'.
        if (string.IsNullOrWhiteSpace(pattern)) return false;
        pattern = pattern.Trim();
        if (!pattern.Contains("*") && !pattern.Contains("?") && !pattern.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            pattern += ".exe";
        string regex = "^" + System.Text.RegularExpressions.Regex.Escape(pattern)
            .Replace("\\*", ".*").Replace("\\?", ".") + "$";
        return System.Text.RegularExpressions.Regex.IsMatch(candidate, regex,
            System.Text.RegularExpressions.RegexOptions.IgnoreCase |
            System.Text.RegularExpressions.RegexOptions.CultureInvariant);
    }

    public static WindowRecord Find(string exeName, string titleContains) {
        if (string.IsNullOrWhiteSpace(exeName)) return null;
        foreach (WindowRecord entry in Enumerate()) {
            if (!WildcardMatches(entry.exe, exeName)) continue;
            if (!string.IsNullOrWhiteSpace(titleContains) &&
                entry.title.IndexOf(titleContains.Trim(), StringComparison.OrdinalIgnoreCase) < 0) continue;
            return entry;
        }
        return null;
    }

    public static bool Focus(WindowRecord entry) {
        if (entry == null) return false;
        IntPtr hwnd = new IntPtr(entry.hwnd);
        if (IsIconic(hwnd)) ShowWindowAsync(hwnd, 9 /* SW_RESTORE */);
        if (GetForegroundWindow() == hwnd) return true;

        // Windows may reject background SetForegroundWindow calls. Attach to the
        // interactive foreground queue for the duration of the activation only.
        IntPtr foreground = GetForegroundWindow();
        uint fgPid;
        uint foregroundThread = foreground == IntPtr.Zero ? 0 : GetWindowThreadProcessId(foreground, out fgPid);
        uint targetPid;
        uint targetThread = GetWindowThreadProcessId(hwnd, out targetPid);
        uint ourThread = GetCurrentThreadId();
        bool attachedForeground = false;
        bool attachedTarget = false;
        try {
            if (foregroundThread != 0 && foregroundThread != ourThread)
                attachedForeground = AttachThreadInput(ourThread, foregroundThread, true);
            if (targetThread != 0 && targetThread != ourThread && targetThread != foregroundThread)
                attachedTarget = AttachThreadInput(ourThread, targetThread, true);
            BringWindowToTop(hwnd);
            SetForegroundWindow(hwnd);
        } finally {
            if (attachedTarget) AttachThreadInput(ourThread, targetThread, false);
            if (attachedForeground) AttachThreadInput(ourThread, foregroundThread, false);
        }
        Thread.Sleep(45);
        if (GetForegroundWindow() == hwnd) return true;
        // Second non-launch fallback; the shell can sometimes activate when the
        // foreground rules prevent an ordinary API call.
        try {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType != null) {
                object shell = Activator.CreateInstance(shellType);
                shellType.InvokeMember("AppActivate", System.Reflection.BindingFlags.InvokeMethod,
                    null, shell, new object[] { entry.pid });
                Marshal.ReleaseComObject(shell);
            }
        } catch { /* not all environments permit shell activation */ }
        Thread.Sleep(35);
        IntPtr active = GetForegroundWindow();
        if (active == hwnd) return true;
        uint activePid;
        GetWindowThreadProcessId(active, out activePid);
        return activePid == (uint)entry.pid; // another window of the same application
    }
}
'@

while ($null -ne ($line = [Console]::ReadLine())) {
    try {
        $request = ConvertFrom-Json -InputObject $line -ErrorAction Stop
        $id = [string]$request.id
        switch ([string]$request.op) {
            'list' {
                $windows = @([FocusWindows]::Enumerate() | Select-Object exe,title)
                $response = @{ id = $id; ok = $true; windows = $windows }
            }
            'focus' {
                $exe = [string]$request.exe
                $title = [string]$request.title
                $window = [FocusWindows]::Find($exe, $title)
                if ($null -eq $window) {
                    $response = @{ id = $id; ok = $false; reason = 'not-running' }
                } else {
                    $success = [FocusWindows]::Focus($window)
                    $response = @{ id = $id; ok = $success; reason = $(if ($success) { 'focused' } else { 'windows-denied-focus' }); title = $window.title }
                }
            }
            default {
                $response = @{ id = $id; ok = $false; reason = 'unknown-command' }
            }
        }
        [Console]::Out.WriteLine((ConvertTo-Json -InputObject $response -Compress -Depth 4))
        [Console]::Out.Flush()
    } catch {
        $response = @{ id = $(if ($null -ne $request) { [string]$request.id } else { '' }); ok = $false; reason = 'error'; message = [string]$_.Exception.Message }
        [Console]::Out.WriteLine((ConvertTo-Json -InputObject $response -Compress -Depth 4))
        [Console]::Out.Flush()
    }
}
