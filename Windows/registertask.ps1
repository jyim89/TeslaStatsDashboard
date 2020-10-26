$psPath = (Get-Command powershell).Path

## Register data gathering task
$scriptPath = Join-Path $PSScriptRoot "tesladata.ps1" -Resolve
$action = New-ScheduledTaskAction -Execute $psPath -Argument "-File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId "System" -LogonType ServiceAccount -RunLevel Highest

$settingsParams = @{
    MultipleInstances = "IgnoreNew"
    StartWhenAvailable = $true
    WakeToRun = $true
}
$settings = New-ScheduledTaskSettingsSet @settingsParams

$taskParams = @{
    TaskName = "Tesla Data Collection"
    Description = "Collects data for your vehicle"
    Action = $action
    Trigger = $trigger
    Principal = $principal
    Settings = $settings
}

$task = Register-ScheduledTask @taskParams

## Register data backup task
$scriptPath = Join-Path $PSScriptRoot "databackup.ps1" -Resolve
$action = New-ScheduledTaskAction -Execute $psPath -Argument "-File `"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Days 1)
$principal = New-ScheduledTaskPrincipal -UserId "System" -LogonType ServiceAccount -RunLevel Highest

$settingsParams = @{
    MultipleInstances = "IgnoreNew"
    StartWhenAvailable = $true
    WakeToRun = $true
}
$settings = New-ScheduledTaskSettingsSet @settingsParams

$taskParams = @{
    TaskName = "Tesla Data Backup"
    Description = "Backs up data for your vehicle"
    Action = $action
    Trigger = $trigger
    Principal = $principal
    Settings = $settings
}

$task = Register-ScheduledTask @taskParams