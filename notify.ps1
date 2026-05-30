param(
    [string]$Title = "Claude",
    [string]$Message = ""
)

$sentinel = "$env:USERPROFILE\.claude\notifier-disabled"
$dedupFile = "$env:USERPROFILE\.claude\.notifier-last"
$dedupSeconds = 5

# --- Disabled check ---
if (Test-Path $sentinel) { exit 0 }

# --- Dedup check ---
try {
    if (Test-Path $dedupFile) {
        $last = [datetime](Get-Content $dedupFile -Raw).Trim()
        if (((Get-Date) - $last).TotalSeconds -lt $dedupSeconds) { exit 0 }
    }
} catch {}
Get-Date -Format o | Out-File $dedupFile -Force

# --- Skip if Claude terminal is foreground ---
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
            $isTerminal = $fgProc.ProcessName -match 'WindowsTerminal|wt|cmd|powershell|pwsh|conhost'

            if ($isTerminal) {
                # Check 1: title contains Claude
                if ($fgTitle -match 'claude|Claude Code') { exit 0 }

                # Check 2: child process command line contains claude
                $children = Get-CimInstance Win32_Process -Filter "ParentProcessId=$wpid" -ErrorAction SilentlyContinue
                if ($children | Where-Object { $_.CommandLine -match 'claude' }) { exit 0 }
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
