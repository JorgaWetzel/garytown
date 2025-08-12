
function Get-DeviceAutopilotInfoFallback {
    param(
        [switch]$VerboseLog
    )
    $result = @{
        Success = $false
        Method = $null
        Data = $null
        Message = ""
    }

    try {
        if ($VerboseLog) { Write-Host "Trying standard Get-CimInstance method..." -ForegroundColor Cyan }
        $session = New-CimSession -ComputerName localhost
        $evDetail = Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -ClassName MDM_DevDetail_Ext01 -ErrorAction Stop
        $result.Success = $true
        $result.Method = "CIM"
        $result.Data = $evDetail
        $result.Message = "Hardware hash retrieved via CIM method."
        return $result
    } catch {
        if ($VerboseLog) { Write-Host "CIM method failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }

    # Try Andrew Taylors offline community script method
    try {
        if ($VerboseLog) { Write-Host "Trying Andrew Taylor's community offline method..." -ForegroundColor Cyan }
        $temp = Join-Path $env:TEMP "get-windowsautopilotinfocommunity.ps1"
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/andrew-s-taylor/WindowsAutopilotInfo/main/Community%20Version/get-windowsautopilotinfocommunity.ps1" -OutFile $temp -UseBasicParsing
        . $temp
        if (Get-Command Get-WindowsAutopilotInfoCommunity -ErrorAction SilentlyContinue) {
            $csv = Join-Path $env:TEMP "autopilotinfo.csv"
            Get-WindowsAutopilotInfoCommunity -OutputFile $csv -ErrorAction Stop
            if (Test-Path $csv) {
                $result.Success = $true
                $result.Method = "CommunityOffline"
                $result.Data = Get-Content $csv -Raw
                $result.Message = "Hardware hash retrieved via Andrew Taylor's offline method."
                return $result
            }
        }
    } catch {
        if ($VerboseLog) { Write-Host "Offline method failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }

    # Fallback: Serial number check
    try {
        if ($VerboseLog) { Write-Host "Falling back to serial number check..." -ForegroundColor Cyan }
        $serial = (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber
        $result.Success = $true
        $result.Method = "SerialNumber"
        $result.Data = $serial
        $result.Message = "Only serial number retrieved. Hash not available in WinPE."
        return $result
    } catch {
        $result.Message = "Unable to retrieve hardware hash or serial number."
        return $result
    }
}

function Invoke-IntuneAutopilotPreflight {
    param(
        [switch]$StopOnBlock
    )
    $info = Get-DeviceAutopilotInfoFallback -VerboseLog
    if (-not $info.Success) {
        Write-Host $info.Message -ForegroundColor Red
        if ($StopOnBlock) { exit 23 }
        return
    }

    Write-Host $info.Message -ForegroundColor Green
    if ($info.Method -eq "SerialNumber") {
        Write-Host "Warning: Only serial number check performed; this may yield false negatives." -ForegroundColor Yellow
    }
    # TODO: Integrate Graph API call here to check registration status
}

