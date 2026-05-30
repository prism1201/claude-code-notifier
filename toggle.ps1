# Toggle Claude Code desktop notifications on/off
$sentinel = "$env:USERPROFILE\.claude\notifier-disabled"

if (Test-Path $sentinel) {
    Remove-Item $sentinel -Force
    $state = "ON"
} else {
    New-Item $sentinel -ItemType File -Force | Out-Null
    $state = "OFF"
}

# Show a quick toast to confirm the toggle
$toastXml = @"
<toast duration="short">
  <visual>
    <binding template="ToastGeneric">
      <text>Claude 通知已$state</text>
    </binding>
  </visual>
</toast>
"@

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom, ContentType = WindowsRuntime] | Out-Null

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml($toastXml)
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)

try {
    $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ClaudeCode.Notifier')
    $notifier.Show($toast)
} catch {
    try {
        $notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe')
        $notifier.Show($toast)
    } catch {}
}
