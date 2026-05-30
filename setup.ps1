# Claude Code Notifier - One-click setup
# Copies scripts to ~/.claude/, registers claude-focus:// protocol, configures hooks, creates desktop shortcut

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = "$env:USERPROFILE\.claude"

# Source scripts (in the project directory)
$srcNotify = Join-Path $scriptDir "notify.ps1"
$srcFocus  = Join-Path $scriptDir "focus-claude.ps1"
$srcTogglePs1 = Join-Path $scriptDir "toggle.ps1"
$srcToggleVbs = Join-Path $scriptDir "toggle-notifier.vbs"

# Destinations (in ~/.claude/)
$destNotify    = Join-Path $claudeDir "notify.ps1"
$destFocus     = Join-Path $claudeDir "focus-claude.ps1"
$destTogglePs1 = Join-Path $claudeDir "toggle-notifier.ps1"
$destToggleVbs = Join-Path $claudeDir "toggle-notifier.vbs"
$vbsLauncher   = Join-Path $claudeDir "focus-claude.vbs"

Write-Host "=== Claude Code Notifier Setup ==="

# 1. Copy scripts to ~/.claude/
Write-Host "[1/4] Copying scripts to ~/.claude/..."
Copy-Item $srcNotify    $destNotify    -Force
Copy-Item $srcFocus     $destFocus     -Force
Copy-Item $srcTogglePs1 $destTogglePs1 -Force
Copy-Item $srcToggleVbs $destToggleVbs -Force
Write-Host "  notify.ps1, focus-claude.ps1, toggle-notifier.ps1, toggle-notifier.vbs copied"

# 2. Create focus-claude.vbs (no console flash when toast is clicked)
Write-Host "[2/4] Creating VBS launcher for protocol handler..."
@"
Dim shell : Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """"$destFocus"""", 0, False
Set shell = Nothing
"@ | Out-File -FilePath $vbsLauncher -Encoding ASCII -Force
Write-Host "  focus-claude.vbs created"

# 3. Register claude-focus:// protocol -> wscript.exe (no console window)
Write-Host "[3/4] Registering claude-focus:// protocol..."
$regPath = "HKCU:\SOFTWARE\Classes\claude-focus"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Claude Focus Protocol" -Type String
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value "" -Type String
$cmdPath = "$regPath\shell\open\command"
New-Item -Path $cmdPath -Force | Out-Null
Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value "wscript.exe `"$vbsLauncher`"" -Type String
Write-Host "  Protocol registered: claude-focus:// -> wscript -> focus-claude.vbs"

# 4. Configure Claude Code hooks
Write-Host "[4/4] Configuring Claude Code hooks..."
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
} else {
    $settings = @{}
}

if (-not $settings.hooks) { $settings.hooks = @{} }

$hookCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$destNotify`""

# Stop hook: task completed
$settings.hooks.Stop = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Title 'Claude 已完成' -Message '请打开 Claude 窗口查看回复'"
        shell = "powershell"
        async = $true
    })
})

# PermissionRequest hook: needs confirmation
$settings.hooks.PermissionRequest = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Title 'Claude 需要确认' -Message '请打开 Claude 窗口确认操作'"
        shell = "powershell"
        async = $true
    })
})

# Notification hook: system notification
$settings.hooks.Notification = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Title 'Claude 需要确认' -Message '请打开 Claude 窗口确认操作'"
        shell = "powershell"
    })
})

# UserPromptSubmit hook: clear pending flag so next pause can notify again
$settings.hooks.UserPromptSubmit = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Action clear"
        shell = "powershell"
        async = $true
    })
})

$settings | ConvertTo-Json -Depth 5 | Set-Content $settingsPath -Encoding UTF8
Write-Host "  Hooks configured: Stop, PermissionRequest, Notification, UserPromptSubmit"

# 5. Create desktop shortcut for toggle
Write-Host ""
Write-Host "Creating desktop shortcut for toggle..."
$wsh = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut("$env:USERPROFILE\Desktop\Claude通知开关.lnk")
$shortcut.TargetPath = "C:\Windows\System32\wscript.exe"
$shortcut.Arguments = "`"$destToggleVbs`""
$shortcut.IconLocation = "C:\Windows\System32\shell32.dll,14"
$shortcut.Save()
Write-Host "  Shortcut created: $env:USERPROFILE\Desktop\Claude通知开关.lnk"

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host "Usage:"
Write-Host "  - Claude will now notify you on task completion or permission requests"
Write-Host "  - Click the toast notification to jump back to Claude"
Write-Host "  - Double-click 'Claude通知开关' on desktop to toggle notifications on/off"
