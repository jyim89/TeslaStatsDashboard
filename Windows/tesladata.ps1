$settingsFile = "settings.js"
$logFile = Join-Path $PSScriptRoot "RetrieveDataError-$(Get-Date -f yyyyMMddHHmmss).log"

function log([string] $message) {
    $dateString = (Get-Date).ToString("yyyy-MM-dd HH:mm:ssZ")
    $line = "$dateString | $message"
    Write-Host $message
    if($logFile) {
        $message | Out-File $logFile -Append -Encoding Unicode
    }
}

function RetrieveData($filePath) {
    try {
        $rawData = Get-Content $filePath -Raw
        $stripBeginning = $rawData.Substring($rawData.IndexOf("=") + 1)
        if ((!$filePath.Contains($settingsFile)) -and ($stripBeginning.IndexOf("[") -lt 0)) {
            $stripBeginning = "[$stripBeginning]"
        }
        return $stripBeginning | ConvertFrom-Json
    }
    catch {
        log("ERROR 2002: Failed to retreive data from $filePath. $_")
        exit 2002
    }
}

function WriteData($data, $name, $filePath) {
    try {
        $dataAsJson = $data | ConvertTo-Json
        Set-Content $filePath -Value "var $name = $dataAsJson"
    }
    catch {
        log("ERROR: 2003: failed to write data to $filePath. $_")
        exit 2003
    }
}

function GetFilePath($checkPath) {
    if ($checkPath.contains(":")) {
        return $checkPath
    }
    elseif (Test-Path (Join-Path $PSScriptRoot $checkPath)) {
        return Join-Path $PSScriptRoot $checkPath
    }

    log("ERROR 2001: Could not find file $checkPath")
    exit 2001
}

function Login {
    try {
        Write-Host("Logging in using Tesla credentials")
        $teslaLoginParams = @{email="$($settings.LoginEmail)";password="$($settings.LoginPassword)";client_secret="$($settings.ClientSecret)";client_id="$($settings.ClientId)";grant_type="password"}
        $loginResponse = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.AuthApi)" -Method POST -Body $teslaLoginParams
        Write-Host($settings.getType())
        $settings.AccessToken = $loginResponse.access_token
        WriteData $settings "settings" (GetFilePath $settingsFile)
        return $($loginResponse.access_token)
    }
    catch {
        log("ERROR 3001: Login failure. StatusCode: $($_.Exception.Response.StatusCode.value__). Description: $($_.Exception.Response.StatusDescription). $_")
        exit 3001
    }
}

function AwakeCheck($vehicleId) {
    try {
        $lastAwakeTimeField = "$($vehicleId)_LastAwakeTime"
        $lastRecordedTimeField = "$($vehicleId)_LastRecordedTime"
        $allowSleepField = "$($vehicleId)_AllowSleep"
        $vehiclePing = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$vehicleId" -Method GET -Headers $accessHeader

        $currTimestamp = [Math]::Truncate((New-TimeSpan -Start (Get-Date "01/01/1970") -End ((Get-Date).ToUniversalTime())).TotalSeconds)
    
        if (($vehiclePing.response.state -eq "asleep") -and (!$vehiclePing.response.in_service)) {
            Write-Host "Gets here 1"
            $settings.$allowSleepField = $false
            $currTimestamp = [Math]::Truncate((New-TimeSpan -Start (Get-Date "01/01/1970") -End ((Get-Date).ToUniversalTime())).TotalSeconds)        

            if ([int]$currTimestamp -ge [int]$settings.$lastAwakeTimeField + [int]$settings.ForceWakeInterval) {
                Write-Host "Gets here 5"
                Write-Host "Forcing $($vehiclePing.response.display_name) to wake"

                $timer = [Diagnostics.Stopwatch]::StartNew()
                while(($vehiclePing.response.state -eq "asleep") -and ($timer.Elapsed.TotalSeconds -lt $settings.WakeTimeout)) {
                    Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$vehicleId/wake_up" -Method POST -Headers $accessHeader
                    Start-Sleep -s 5
                    $vehiclePing = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$vehicleId" -Method GET -Headers $accessHeader
                }

                $timer.Stop()
                if ($vehiclePing.response.state -eq "asleep") {
                    log ("ERROR 1003: timeout hit while waking $($vehiclePing.response.display_name)")
                    exit 1003
                }

                $settings.$lastAwakeTimeField = $currTimestamp
            }            
        }
        elseif ($settings.$allowSleepField -and ($vehiclePing.response.state -ne "asleep")) {
            if ([int]$currTimestamp -lt [int]$settings.$lastRecordedTimeField + [int]$settings.ForceWakeInterval) {
                Write-Host "Gets here 2"
                Write-Host "Preventing gathering of data to allow vehicle to sleep"
                return $false
            }

            log("WARNING 4010: It is possible $($vehiclePing.display_name) has not slept in several hours. Possible reasoning is Sentry Mode is enabled. Check WakeData.js for more logs.")
        }        

        if ($vehiclePing.response.state -eq "asleep") {
            Write-Host "Gets here 3"
            Write-Host "Vehicle is asleep and data cannot be collected"
        }
        return ($vehiclePing.response.state -ne "asleep")
    }
    catch {
        log("ERROR 1004: Failed awake check. $_")
        exit 1004
    }
}

## Retrieve settings and data
Write-Host("Retrieving Settings and Data")
$settings = RetrieveData (GetFilePath $settingsFile)
$wakeData = RetrieveData (GetFilePath $settings.WakeDataFile)
$vehicleData = RetrieveData (GetFilePath $settings.VehicleDataFile)
$batteryData = RetrieveData (GetFilePath $settings.BatteryDataFile)
$chargingData = RetrieveData (GetFilePath $settings.ChargingDataFile)
$drivingData = RetrieveData (GetFilePath $settings.DrivingDataFile)

## Retrieve Access_Token
if (![string]::IsNullOrEmpty($settings.AccessToken)) {
    Write-Host("Checking validity of Access_Token")
    try {
        $accessHeader = @{Authorization="Bearer $($settings.AccessToken)"}
        Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)" -Method GET -Headers $accessHeader
        Write-Host "Token success"
    }
    catch {
        Write-Host "Cached access token is invalid"
        $accessHeader = @{Authorization="Bearer $(Login)"}
    }
}
else {
    $accessHeader = @{Authorization="Bearer $(Login)"}
}

## Retrieve Vehicles under account
try {
    $productListReponse = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)" -Method GET -Headers $accessHeader
    $vehicles= @()
    $productListReponse.response | % {
        $vehicle = New-Object PSObject
        $vehicle | Add-Member -MemberType NoteProperty -Name Id -Value $_.id
        $vehicle | Add-Member -MemberType NoteProperty -Name Vid -Value $_.vehicle_id
        $vehicle | Add-Member -MemberType NoteProperty -Name Vin -Value $_.vin
        $vehicle | Add-Member -MemberType NoteProperty -Name VehicleName -Value $_.display_name
        $vehicle | Add-Member -MemberType NoteProperty -Name InService -Value $_.in_service

        Write-Host "Found vehicle $($_.display_name)"
        $vehicleAwakeCheck = New-Object PSObject
        $timestampDate = (Get-Date).ToUniversalTime()
        $timestamp = [Math]::Truncate((New-TimeSpan -Start (Get-Date "01/01/1970") -End $timestampDate).TotalSeconds)
        $vehicleAwakeCheck | Add-Member -MemberType NoteProperty -Name DateTimeUTC -Value "$timestampDate"
        $vehicleAwakeCheck | Add-Member -MemberType NoteProperty -Name Id -Value $_.id
        $vehicleAwakeCheck | Add-Member -MemberType NoteProperty -Name VehicleName -Value $_.display_name
        $vehicleAwakeCheck | Add-Member -MemberType NoteProperty -Name State -Value $_.state

        if (($settings.PSobject.Properties.Name -notcontains "$($_.id)_LastAwakeTime")) {
            $settings | Add-Member -MemberType NoteProperty -Name "$($_.id)_LastAwakeTime" -Value 0
            $settings | Add-Member -MemberType NoteProperty -Name "$($_.id)_LastRecordedTime" -Value 0
            $settings | Add-Member -MemberType NoteProperty -Name "$($_.id)_AllowSleep" -Value $false
        }

        if ($_.state -ne "asleep") {
            $lastAwakeTimeField = "$($_.id)_LastAwakeTime"
            $settings.$lastAwakeTimeField = $timestamp
        }
        
        $vehicles += $vehicle
        $wakeData += $vehicleAwakeCheck
    }

    if ($vehicles.Length -le 0) {
        log ("ERROR 1002: No vehicles were found under your account")
        exit 1002
    }

    WriteData $vehicles "Vehicles" (GetFilePath $settings.VehiclesFile)
    WriteData $wakeData "WakeData" (GetFilePath $settings.WakeDataFile)
}
catch {
    log("ERROR 1001: Could not retrieve vehicles list. $_")
    exit 1001
}

$vehicles | % {
    $isConsideredAwake = AwakeCheck $_.id
    if ($isConsideredAwake) {
        $lastRecordedTimeField = "$($_.id)_LastRecordedTime"
        $currTimestamp = [Math]::Truncate((New-TimeSpan -Start (Get-Date "01/01/1970") -End ((Get-Date).ToUniversalTime())).TotalSeconds)   
        $settings.$lastRecordedTimeField = $currTimestamp

        ## Retrieve battery information
        try {            
            $vehicleBatteryInfo = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$($_.id)/data_request/charge_state" -Method GET -Headers $accessHeader
            $vbi = $vehicleBatteryInfo.response
            $timestampDate = (Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($($vbi.timestamp)))
            $batteryInfo = New-Object PSObject
            $batteryInfo | Add-Member -MemberType NoteProperty -Name DateTimeUTC -Value "$timestampDate"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name Id -Value "$($_.id)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name VehicleName -Value "$($_.VehicleName)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name CurrentBatteryLevel -Value "$($vbi.battery_level)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name CurrentRatedBatteryRange -Value "$($vbi.battery_range)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name CurrentEstimatedBatteryRange -Value "$($vbi.est_battery_range)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name CurrentIdealBatteryRange -Value "$($vbi.ideal_battery_range)"
            $batteryInfo | Add-Member -MemberType NoteProperty -Name UsableBatteryLevel -Value "$($vbi.usable_battery_level)"

            $batteryData += $batteryInfo
        }
        catch {
            log("ERROR 1005: Failed to retrieve car battery information. $_")
            exit 1005
        }

        ## Retrieve driving information
        try {
            $VehicleDrivingInfo = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$($_.id)/data_request/drive_state" -Method GET -Headers $accessHeader
            $vdi = $VehicleDrivingInfo.response
            if (($vdi.speed -ne $null) -or ($vdi.power -ne 0)) {
                $timestampDate = (Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($($vdi.timestamp)))
                $drivingInfo = New-Object PSObject
                $drivingInfo | Add-Member -MemberType NoteProperty -Name DateTimeUTC -Value "$timestampDate"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name Id -Value "$($_.id)"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name VehicleName -Value "$($_.VehicleName)"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name Speed -Value "$($vdi.speed)"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name Power -Value "$($vdi.power)"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name Latitude -Value "$($vdi.latitude)"
                $drivingInfo | Add-Member -MemberType NoteProperty -Name Longitude -Value "$($vdi.longitude)"

                $drivingData += $drivingInfo
            }
        }
        catch {
            log("ERROR 1006: Failed to retrieve car driving information. $_")
            exit 1006
        }

        ## Retrieve charging information
        try {            
            if ($vbi.charging_state -ne "Disconnected") {
                $timestampDate = (Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($($vbi.timestamp)))
                $chargingInfo = New-Object PSObject
                $chargingInfo | Add-Member -MemberType NoteProperty -Name DateTimeUTC -Value "$timestampDate"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name Id -Value "$($_.id)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name VehicleName -Value "$($_.VehicleName)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeEnergyAdded -Value "$($vbi.charge_energy_added)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeIdealMilesAdded -Value "$($vbi.charge_miles_added_ideal)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeRatedMilesAdded -Value "$($vbi.charge_miles_added_rated)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeRangeRate -Value "$($vbi.charge_rate)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeCurrent -Value "$($vbi.charger_actual_current)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeKW -Value "$($vbi.charger_power)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeVoltage -Value "$($vbi.charger_voltage)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name MinutesToFullCharge -Value "$($vbi.minutes_to_full_charge)"
                $chargingInfo | Add-Member -MemberType NoteProperty -Name ChargeCoordinates -Value "$($vdi.latitude),$($vdi.longitude)"

                $chargingData += $chargingInfo
            }
        }
        catch {
            log("ERROR 1007: Failed to retrieve car charging information. $_")
            exit 1007
        }

        ## Retrieve vehicle information
        try {
            $VehicleInfo = Invoke-RestMethod -Uri "$($settings.ApiUrl)/$($settings.VehicleApi)/$($_.id)/data_request/vehicle_state" -Method GET -Headers $accessHeader
            $vi = $VehicleInfo.response
            $timestampDate = (Get-Date 01.01.1970)+([System.TimeSpan]::FromMilliseconds($($vi.timestamp)))
            $info = New-Object PSObject
            $info | Add-Member -MemberType NoteProperty -Name DateTimeUTC -Value "$timestampDate"
            $info | Add-Member -MemberType NoteProperty -Name Id -Value "$($_.id)"
            $info | Add-Member -MemberType NoteProperty -Name VehicleName -Value "$($_.VehicleName)"
            $info | Add-Member -MemberType NoteProperty -Name Odometer -Value "$($vi.odometer)"
            $info | Add-Member -MemberType NoteProperty -Name SoftwareVersion -Value "$($vi.car_version)"

            $vehicleData += $info
        }
        catch {
            log("ERROR 1008: Failed to retrieve vehicle information. $_")
            exit 1008
        }

        ## Allow car to sleep if user is away from car
        if (!$vi.is_user_present -and $vi.locked -and ($vbi.charging_state -eq "Disconnected") -and $isConsideredAwake)
        {
            $allowSleepField = "$($_.id)_AllowSleep"
            $settings.$allowSleepField = $true
        }
    }
}

## Write all data
WriteData $batteryData "BatteryData" (GetFilePath $settings.BatteryDataFile)
WriteData $chargingData "ChargingData" (GetFilePath $settings.ChargingDataFile)
WriteData $drivingData "DrivingData" (GetFilePath $settings.DrivingDataFile)
WriteData $vehicleData "VehicleData" (GetFilePath $settings.VehicleDataFile)
WriteData $settings "settings" (GetFilePath $settingsFile)