param(
    [string]$Title = "Claude",
    [string]$Message = "",
    [string]$Action = "send"  # "send" or "clear"
)

$sentinel = "$env:USERPROFILE\.claude\notifier-disabled"
$pendingLock = "$env:USERPROFILE\.claude\.notifier-pending"

# --- Clear action: UserPromptSubmit calls this to reset the pending flag ---
if ($Action -eq "clear") {
    Remove-Item $pendingLock -Force -ErrorAction SilentlyContinue
    exit 0
}

# --- Disabled check ---
if (Test-Path $sentinel) { exit 0 }

# --- Pending check: if a notification was already sent since last user input, skip ---
if (Test-Path $pendingLock) { exit 0 }

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
                if ($fgTitle -match 'claude|Claude Code|Claude') { exit 0 }

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

# --- Set pending lock to prevent duplicate notifications for this pause ---
New-Item $pendingLock -ItemType File -Force | Out-Null

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
