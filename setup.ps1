# Claude Code Notifier - One-click setup
# Registers claude-focus:// protocol + configures Claude Code hooks

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$focusScript = Join-Path $scriptDir "focus-claude.ps1"
$notifyScript = Join-Path $scriptDir "notify.ps1"
$vbsLauncher = Join-Path $scriptDir "focus-claude.vbs"

# 1. Create VBS launcher (no console flash when toast is clicked)
@"
Dim shell : Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""$focusScript""", 0, False
Set shell = Nothing
"@ | Out-File -FilePath $vbsLauncher -Encoding ASCII -Force

# 2. Register claude-focus:// protocol -> wscript.exe (no console window)
$regPath = "HKCU:\SOFTWARE\Classes\claude-focus"
New-Item -Path $regPath -Force | Out-Null
Set-ItemProperty -Path $regPath -Name "(Default)" -Value "URL:Claude Focus Protocol" -Type String
Set-ItemProperty -Path $regPath -Name "URL Protocol" -Value "" -Type String
$cmdPath = "$regPath\shell\open\command"
New-Item -Path $cmdPath -Force | Out-Null
Set-ItemProperty -Path $cmdPath -Name "(Default)" -Value "wscript.exe `"$vbsLauncher`"" -Type String

# 3. Configure Claude Code hooks
$settingsPath = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsPath) {
    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json
} else {
    $settings = @{}
}

if (-not $settings.hooks) { $settings.hooks = @{} }

$hookCmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$notifyScript`""

$settings.hooks.Stop = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Title 'Claude finished' -Message 'Click to view Claude response'"
        shell = "powershell"
        async = $true
    })
})

$settings.hooks.PermissionRequest = @(@{
    matcher = ""
    hooks = @(@{
        type = "command"
        command = "$hookCmd -Title 'Claude needs confirmation' -Message 'Click to open Claude window'"
        shell = "powershell"
        async = $true
    })
})

$settings | ConvertTo-Json -Depth 5 | Set-Content $settingsPath

Write-Host "=== Claude Code Notifier Setup Complete ==="
Write-Host "Protocol claude-focus:// registered (no-flash via wscript)"
Write-Host "Hooks configured: Stop, PermissionRequest"
Write-Host "Settings: $settingsPath"
