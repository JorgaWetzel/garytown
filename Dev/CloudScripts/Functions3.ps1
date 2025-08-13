# Functions3.ps1 (OOBE Edition) – nur HW-Hash, kein Serial-Fallback
Set-StrictMode -Version Latest

$script:AutopilotCommunityScriptName = "get-windowsautopilotinfocommunity.ps1"
$script:AutopilotCommunityScriptUrl  = "https://raw.githubusercontent.com/andrew-s-taylor/WindowsAutopilotInfo/main/Community%20Version/get-windowsautopilotinfocommunity.ps1"
$script:DefaultScriptFolder          = "C:\Windows\Temp\OSDCloud"

function Use-GetWindowsAutopilotInfo {
    if (-not (Test-Path -LiteralPath $script:DefaultScriptFolder)) {
        New-Item -ItemType Directory -Path $script:DefaultScriptFolder -Force | Out-Null
    }
    $dest = Join-Path $script:DefaultScriptFolder $script:AutopilotCommunityScriptName
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $script:AutopilotCommunityScriptUrl -OutFile $dest -ErrorAction Stop
        . $dest
        return $true
    } catch {
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        Write-Host "Download von get-windowsautopilotinfocommunity.ps1 fehlgeschlagen: $msg" -ForegroundColor Yellow
        return $false
    }
}

function Get-GraphConfig {
    param(
        [string[]] $CandidatePaths = @(
            $env:GRAPHAPP_JSON_PATH,          # bevorzugt: env-Var zeigt auf lokalen Pfad
            "C:\ProgramData\GraphApp.json",   # temporaer abgelegt (wird danach geloescht)
            "C:\Windows\Temp\GraphApp.json"   # optionaler Fallback
        )
    )
    foreach ($p in $CandidatePaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-Path -LiteralPath $p) {
            try {
                $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
                $cfg = ConvertFrom-Json -InputObject $raw
                if ($cfg -is [System.Collections.IEnumerable]) { if ($cfg.Count -ge 1) { return $cfg[0] } } else { return $cfg }
            } catch {}
        }
    }
    if ($env:GRAPH_TENANT_ID -and $env:GRAPH_CLIENT_ID -and $env:GRAPH_CLIENT_SECRET) {
        return [pscustomobject]@{ tenantId=$env:GRAPH_TENANT_ID; clientId=$env:GRAPH_CLIENT_ID; clientSecret=$env:GRAPH_CLIENT_SECRET }
    }
    return $null
}

function Get-GraphToken {
    param([Parameter(Mandatory)] [string] $TenantId,
          [Parameter(Mandatory)] [string] $ClientId,
          [Parameter(Mandatory)] [string] $ClientSecret)
    $body = @{ client_id=$ClientId; scope="https://graph.microsoft.com/.default"; client_secret=$ClientSecret; grant_type="client_credentials" }
    try { (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body -ErrorAction Stop).access_token }
    catch {
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        Write-Host "Tokenbeschaffung fehlgeschlagen: $msg" -ForegroundColor Yellow
        return $null
    }
}

function Get-HardwareHashBase64 {
    # Im Full-OS ist der MDM-Provider da; Check bleibt drin, um sauber zu loggen.
    $mdmOk = $false
    try { $null = Get-CimInstance -Namespace 'root\cimv2\mdm\dmmap' -ClassName 'MDM_DevDetail_Ext01' -ErrorAction Stop; $mdmOk = $true } catch {}
    if (-not $mdmOk) { Write-Host "MDM/WMI-Provider fehlt – HW-Hash nicht verfuegbar." -ForegroundColor Yellow; return $null }

    if (-not (Use-GetWindowsAutopilotInfo)) { return $null }
    try {
        if (Get-Command Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue) {
            $info = Get-WindowsAutopilotInfo -OutputObject -ErrorAction Stop
            if ($info -and $info.HardwareHash) { return $info.HardwareHash }
        }
    } catch {
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        Write-Host "Hardware Hash nicht ermittelbar: $msg" -ForegroundColor Yellow
    }
    return $null
}

function Invoke-AutopilotProbeImport {
    # Nur Hash-Weg. Ergebnis: 0|806|808|21|22|25
    $cfg = Get-GraphConfig
    if (-not $cfg) { return [pscustomobject]@{ Success=$false; Code=22; Message="Keine Graph-Credentials (GraphApp.json/ENV) gefunden." } }
    $token = Get-GraphToken -TenantId $cfg.tenantId -ClientId $cfg.clientId -ClientSecret $cfg.clientSecret
    if (-not $token) { return [pscustomobject]@{ Success=$false; Code=22; Message="Tokenbeschaffung fehlgeschlagen." } }

    $serial = try { (Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber } catch {}
    if ($serial) { $serial = $serial.Trim() } else { $serial = "" }

    $hashB64 = Get-HardwareHashBase64
    if (-not $hashB64) { return [pscustomobject]@{ Success=$false; Code=21; Message="Hardware Hash nicht ermittelbar." } }

    $importId = [guid]::NewGuid().Guid
    $headers  = @{ Authorization="Bearer $token"; "Content-Type"="application/json" }
    $payload  = @{
        importedWindowsAutopilotDeviceIdentities = @(@{ serialNumber=$serial; hardwareIdentifier=[Convert]::FromBase64String($hashB64); importId=$importId })
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/import" -Headers $headers -Body $payload -ErrorAction Stop | Out-Null
    } catch {
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) { $msg = $_.ErrorDetails.Message }
        if ($msg -match "ZtdDeviceAssignedToOtherTenant|808") { return [pscustomobject]@{ Success=$false; Code=808; Message="Geraet ist bereits in einem ANDEREN Tenant registriert (808)." } }
        if ($msg -match "ZtdDeviceAlreadyAssigned|806")      { return [pscustomobject]@{ Success=$false; Code=806; Message="Geraet ist bereits in DIESEM Tenant registriert (806)." } }
        return [pscustomobject]@{ Success=$false; Code=25; Message="Import-Fehler: $msg" }
    }

    Start-Sleep -Seconds 5

    # Cleanup – v1.0 by serial
    try {
        if ($serial) {
            $filterSerial = $serial.Replace("'", "''")
            $wadp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '{0}'" -f $filterSerial) -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop
            if ($wadp.PSObject.Properties.Name -contains 'value') {
                foreach ($d in $wadp.value) { try { Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($d.id)" -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop | Out-Null } catch {} }
            }
        }
    } catch {}

    # Cleanup – beta by importId
    try {
        $imp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities?`$filter=importId eq '{0}'" -f $importId) -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop
        if ($imp.PSObject.Properties.Name -contains 'value') {
            foreach ($i in $imp.value) { try { Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($i.id)" -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop | Out-Null } catch {} }
        }
    } catch {}

    return [pscustomobject]@{ Success=$true; Code=0; Message="Probe-Import moeglich, kein fremder Tenant. Cleanup erledigt." }
}

function Invoke-IntuneAutopilotPreflight {
    param([switch] $StopOnBlock)
    $res = Invoke-AutopilotProbeImport
    switch ($res.Code) {
        0   { Write-Host $res.Message -ForegroundColor Green }
        806 { Write-Host $res.Message -ForegroundColor Red }
        808 { Write-Host $res.Message -ForegroundColor Red }
        21  { Write-Host $res.Message -ForegroundColor Yellow }
        22  { Write-Host $res.Message -ForegroundColor Yellow }
        25  { Write-Host $res.Message -ForegroundColor Yellow }
        default { Write-Host $res.Message -ForegroundColor Yellow }
    }
    if ($StopOnBlock -and ($res.Code -in 806,808,21,22,25)) { exit 23 }
    return $res
}
