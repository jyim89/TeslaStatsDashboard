$backupPath = Join-Path $PSScriptRoot "databackup\$(Get-Date -f yyyyMMdd)"

if (!(test-path $backupPath))
{
    New-Item -ItemType Directory -Force -Path $backupPath
}

Copy-Item -Path (Join-Path $PSScriptRoot settings.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot BatteryData.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot ChargingData.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot DrivingData.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot VehicleData.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot WakeData.js) -Destination $backupPath
Copy-Item -Path (Join-Path $PSScriptRoot Vehicles.js) -Destination $backupPath