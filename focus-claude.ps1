# Find and focus the Claude Code terminal window (never browsers)
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinAPI {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
}
"@

$targetHwnd = [IntPtr]::Zero
$targetTitle = ""

# Only look at TERMINAL processes, never browsers
$termNames = @('WindowsTerminal', 'wt', 'cmd', 'powershell', 'pwsh', 'conhost')
$terms = Get-Process -ErrorAction SilentlyContinue | Where-Object {
    $termNames -contains $_.ProcessName -and $_.MainWindowHandle -ne 0
}

# Pick the terminal whose title contains Claude, or fallback to any terminal
$claudeTerm = $terms | Where-Object { $_.MainWindowTitle -match 'claude|Claude Code' } | Select-Object -First 1
if (-not $claudeTerm) { $claudeTerm = $terms | Select-Object -First 1 }

if ($claudeTerm) {
    $targetHwnd = $claudeTerm.MainWindowHandle
    $targetTitle = $claudeTerm.MainWindowTitle
}

if ($targetHwnd -ne [IntPtr]::Zero) {
    if ([WinAPI]::IsIconic($targetHwnd)) {
        [WinAPI]::ShowWindow($targetHwnd, 9) | Out-Null
    }
    $fgHwnd = [WinAPI]::GetForegroundWindow()
    $fgTid = 0
    $targetTid = 0
    [WinAPI]::GetWindowThreadProcessId($fgHwnd, [ref]$fgTid) | Out-Null
    [WinAPI]::GetWindowThreadProcessId($targetHwnd, [ref]$targetTid) | Out-Null
    if ($fgTid -ne $targetTid) {
        [WinAPI]::AttachThreadInput($targetTid, $fgTid, $true) | Out-Null
    }
    [WinAPI]::SetForegroundWindow($targetHwnd) | Out-Null
    if ($fgTid -ne $targetTid) {
        [WinAPI]::AttachThreadInput($targetTid, $fgTid, $false) | Out-Null
    }
    Write-Host "Focused: $targetTitle"
} else {
    Write-Host "No terminal window found"
}
