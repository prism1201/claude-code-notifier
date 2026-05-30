param(
    [string]$Title = "Claude",
    [string]$Message = "",
    [string]$EventType = ""
)

$sentinel = "$env:USERPROFILE\.claude\notifier-disabled"

# --- Disabled check ---
if (Test-Path $sentinel) { exit 0 }

# --- Per-event-type dedup (same event suppressed within 10s) ---
if ($EventType) {
    $lockFile = "$env:USERPROFILE\.claude\.notifier-lock-$EventType"
    try {
        if (Test-Path $lockFile) {
            $last = [datetime](Get-Content $lockFile -Raw).Trim()
            if (((Get-Date) - $last).TotalSeconds -lt 10) { exit 0 }
        }
    } catch {}
    Get-Date -Format o | Out-File $lockFile -Force
}

# --- Skip if a Claude terminal is already in foreground ---
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
public class NFG {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
}
"@
$fgHwnd = [NFG]::GetForegroundWindow()
$len = [NFG]::GetWindowTextLength($fgHwnd)
if ($len -gt 0) {
    $sb = New-Object System.Text.StringBuilder($len + 1)
    [NFG]::GetWindowText($fgHwnd, $sb, $sb.Capacity) | Out-Null
    $fgTitle = $sb.ToString()
    $wpid = [uint32]0
    [NFG]::GetWindowThreadProcessId($fgHwnd, [ref]$wpid) | Out-Null

    if ($wpid -gt 0) {
        try {
            $fgProc = Get-Process -Id $wpid -ErrorAction Stop

            if ($fgProc.ProcessName -match 'WindowsTerminal|wt|cmd|powershell|pwsh|conhost') {
                # Direct title match
                if ($fgTitle -match 'claude|Claude Code|Claude') { exit 0 }

                # Deep process tree check: any descendant has claude in command line
                $claudeProcs = @(Get-WmiObject Win32_Process -Filter "Name LIKE '%node%' OR Name LIKE '%claude%'" -ErrorAction SilentlyContinue |
                    Where-Object { $_.CommandLine -match 'claude' })
                foreach ($cp in $claudeProcs) {
                    $checkPid = $cp.ParentProcessId
                    while ($checkPid -gt 0) {
                        if ($checkPid -eq $wpid) { exit 0 }
                        $parent = Get-WmiObject Win32_Process -Filter "ProcessId=$checkPid" -ErrorAction SilentlyContinue
                        if (-not $parent) { break }
                        $checkPid = $parent.ParentProcessId
                    }
                }
            }
        } catch {}
    }
}

# --- Send toast ---
$toastXml = @"
<toast activationType="protocol" launch="claude-focus://focus" duration="long">
  <visual>
    <binding template="ToastGeneric">
      <text>$Title</text>
      <text>$Message</text>
    </binding>
  </visual>
</toast>
"@

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

$ids = @('ClaudeCode.Notifier', '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe')
$shown = $false

foreach ($id in $ids) {
    try {
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($id)
        $notifier.Show($toast)
        $shown = $true
        break
    } catch {}
}

if (-not $shown) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show($Message, $Title, [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
