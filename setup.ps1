# Claude Code Notifier - One-click setup
# Copies scripts to ~/.claude/, registers claude-focus:// protocol, configures hooks

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claudeDir = "$env:USERPROFILE\.claude"

# Source scripts (in the project directory)
$srcNotify = Join-Path $scriptDir "notify.ps1"
$srcFocus  = Join-Path $scriptDir "focus-claude.ps1"

# Destinations (in ~/.claude/)
$destNotify  = Join-Path $claudeDir "notify.ps1"
$destFocus   = Join-Path $claudeDir "focus-claude.ps1"
$vbsLauncher = Join-Path $claudeDir "focus-claude.vbs"

Write-Host "=== Claude Code Notifier Setup ==="

# 1. Copy scripts to ~/.claude/
Write-Host "[1/3] Copying scripts to ~/.claude/..."
Copy-Item $srcNotify $destNotify -Force
Copy-Item $srcFocus  $destFocus  -Force
Write-Host "  notify.ps1, focus-claude.ps1 copied"

# 2. Create focus-claude.vbs (no console flash when toast is clicked)
Write-Host "[2/3] Creating VBS launcher for protocol handler..."
@"
Dim shell : Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """"$destFocus"""", 0, False
Set shell = Nothing
"@ | Out-File -FilePath $vbsLauncher -Encoding ASCII -Force
Write-Host "  focus-claude.vbs created"

# 3. Register claude-focus:// protocol -> wscript.exe (no console window)
Write-Host "[3/3] Registering claude-focus:// protocol + configuring hooks..."
$regPath = "HKCU:\SOFTWARE\Classes\claude-focus"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Claude Focus Protocol" -Type String
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value "" -Type String
$cmdPath = "$regPath\shell\open\command"
New-Item -Path $cmdPath -Force | Out-Null
Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value "wscript.exe `"$vbsLauncher`"" -Type String
Write-Host "  Protocol registered: claude-focus:// -> wscript -> focus-claude.vbs"

# 4. Configure Claude Code hooks
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

Write-Host ""
Write-Host "=== Setup Complete ==="
Write-Host "  - Claude will now notify you on task completion or permission requests"
Write-Host "  - Click the toast notification to jump back to Claude"
