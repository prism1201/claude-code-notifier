# Toggle Claude Code desktop notifications on/off
$sentinel = "$env:USERPROFILE\.claude\notifier-disabled"

if (Test-Path $sentinel) {
    Remove-Item $sentinel -Force
    $state = "已开启"
} else {
    New-Item $sentinel -ItemType File -Force | Out-Null
    $state = "已关闭"
}

# Explicitly set AppUserModelID — required for toast from hidden/non-StartMenu processes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TH {
    [DllImport("shell32.dll", SetLastError = true)]
    public static extern void SetCurrentProcessExplicitAppUserModelID([MarshalAs(UnmanagedType.LPWStr)] string AppID);
}
"@
[TH]::SetCurrentProcessExplicitAppUserModelID('ClaudeCode.Notifier')

# Show a quick toast to confirm the toggle
$toastXml = @"
<toast duration="short">
  <visual>
    <binding template="ToastGeneric">
      <text>Claude 通知$state</text>
    </binding>
  </visual>
</toast>
"@

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

$shown = $false
try {
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ClaudeCode.Notifier')
    $notifier.Show($toast)
    $shown = $true
} catch {
    try {
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe')
        $notifier.Show($toast)
        $shown = $true
    } catch {}
}

if ($shown) {
    Start-Sleep -Seconds 1
} else {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show("Claude 通知$state", 'Claude', [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
