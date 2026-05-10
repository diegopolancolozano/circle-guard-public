# Run this ONCE as Administrator to register the cleanup as an automatic task
# It will run k8s-startup-cleanup.ps1 every time you log in to Windows

$scriptPath = Resolve-Path "$PSScriptRoot\k8s-startup-cleanup.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""

# Trigger: at user logon (Docker Desktop starts with Windows)
$trigger = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName "K8s-Startup-Cleanup" `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Force

Write-Host "Task registered. Will run automatically at every login." -ForegroundColor Green
