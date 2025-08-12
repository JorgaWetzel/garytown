# Functions3.ps1
# ============================================================
# Sammlung der Funktionen fuer OSDCloud/WinPE Preflight-Check
# Szenario: OEM/Refurbisher prueft vor Deployment,
#           ob ein Geraet bereits in einem anderen Tenant
#           fuer Windows Autopilot registriert ist.
# Methode:  "Probe-Import" in Quarantaene-Tenant mit sofortigem Cleanup.
# Hinweis:  Ein echter "Dry-Run" existiert bei Microsoft nicht.
# ============================================================

Set-StrictMode -Version Latest

# -------------------------------
# KONSTANTEN
# -------------------------------
$script:AutopilotCommunityScriptName = "get-windowsautopilotinfocommunity.ps1"
$script:AutopilotCommunityScriptUrl  = "https://raw.githubusercontent.com/andrew-s-taylor/WindowsAutopilotInfo/main/Community%20Version/get-windowsautopilotinfocommunity.ps1"
$script:DefaultScriptFolder          = "X:\OSDCloud\Scripts"

# -------------------------------
# HILFSFUNKTIONEN
# -------------------------------

function Use-GetWindowsAutopilotInfo {
<#
.SYNOPSIS
  Laedt IMMER die Community-Version von Andrew Taylor herunter und dot-sourct sie.

.DESCRIPTION
  Keine lokale Suche, kein Fallback. Immer frisch von GitHub laden.
  Speichert die Datei unter X:\OSDCloud\Scripts\get-windowsautopilotinfocommunity.ps1
  und dot-sourct sie, so dass Get-WindowsAutopilotInfo sofort verfuegbar ist.

.OUTPUTS
  [bool] True bei Erfolg, False bei Fehler.
#>
    if (-not (Test-Path -LiteralPath $script:DefaultScriptFolder)) {
        New-Item -ItemType Directory -Path $script:DefaultScriptFolder -Force | Out-Null
    }

    $dest = Join-Path $script:DefaultScriptFolder $script:AutopilotCommunityScriptName
    try {
        Write-Host "Lade $($script:AutopilotCommunityScriptName) aus Andrew Taylors Repo..." -ForegroundColor Yellow
        Invoke-WebRequest -UseBasicParsing -Uri $script:AutopilotCommunityScriptUrl -OutFile $dest -ErrorAction Stop
        . $dest
        return $true
    } catch {
        Write-Host "Download fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Get-Serial {
<#
.SYNOPSIS
  Liefert die Seriennummer des Geraets (Trim).

.OUTPUTS
  [string] oder $null
#>
    try {
        $s = (Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber
        if ($s) { return $s.Trim() }
    } catch {}
    try {
        $s = (Get-WmiObject -Class Win32_BIOS -ErrorAction Stop).SerialNumber
        if ($s) { return $s.Trim() }
    } catch {}
    try {
        $s = (Get-WmiObject -Class Win32_ComputerSystemProduct -ErrorAction Stop).IdentifyingNumber
        if ($s) { return $s.Trim() }
    } catch {}
    return $null
}

function Get-GraphConfig {
<#
.SYNOPSIS
  Laedt die Graph App-Credentials fuer den Quarantaene-Tenant.

.DESCRIPTION
  Sucht nach GraphApp.json in typischen Pfaden oder faellt auf ENV-Variablen zurueck:
    GRAPH_TENANT_ID, GRAPH_CLIENT_ID, GRAPH_CLIENT_SECRET

.OUTPUTS
  PSCustomObject mit tenantId, clientId, clientSecret
#>
    param(
        [string[]] $CandidatePaths = @(
            "$PSScriptRoot\GraphApp.json",
            "X:\OSDCloud\GraphApp.json",
            "X:\OSDCloud\Scripts\GraphApp.json",
            "X:\GraphApp.json"
        )
    )

    foreach ($p in $CandidatePaths) {
        if (Test-Path -LiteralPath $p) {
            try {
                $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
                $cfg = ConvertFrom-Json -InputObject $raw
                if ($cfg -is [System.Collections.IEnumerable]) {
                    if ($cfg.Count -ge 1) { return $cfg[0] }
                } else {
                    return $cfg
                }
            } catch {}
        }
    }

    if ($env:GRAPH_TENANT_ID -and $env:GRAPH_CLIENT_ID -and $env:GRAPH_CLIENT_SECRET) {
        return [pscustomobject]@{
            tenantId     = $env:GRAPH_TENANT_ID
            clientId     = $env:GRAPH_CLIENT_ID
            clientSecret = $env:GRAPH_CLIENT_SECRET
        }
    }

    return $null
}

function Get-GraphToken {
<#
.SYNOPSIS
  Holt ein OAuth2 Token fuer Microsoft Graph (Client Credentials).

.PARAMETER TenantId
.PARAMETER ClientId
.PARAMETER ClientSecret

.OUTPUTS
  [string] access_token oder $null
#>
    param(
        [Parameter(Mandatory)] [string] $TenantId,
        [Parameter(Mandatory)] [string] $ClientId,
        [Parameter(Mandatory)] [string] $ClientSecret
    )

    $body = @{
        client_id     = $ClientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $ClientSecret
        grant_type    = "client_credentials"
    }

    try {
        (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body -ErrorAction Stop).access_token
    } catch {
        Write-Host "Tokenbeschaffung fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

function Get-HardwareHashBase64 {
<#
.SYNOPSIS
  Liefert den Windows Autopilot Hardware Hash (Base64) via Community Script.

.OUTPUTS
  [string] Base64 oder $null
#>
    if (-not (Use-GetWindowsAutopilotInfo)) { return $null }

    try {
        if (Get-Command Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue) {
            $info = Get-WindowsAutopilotInfo -OutputObject -ErrorAction SilentlyContinue
            if ($null -ne $info -and $info.HardwareHash) { return $info.HardwareHash }
        }
    } catch {
        Write-Host "Ermittlung des Hardware Hash fehlgeschlagen: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    return $null
}

function Invoke-AutopilotProbeImport {
<#
.SYNOPSIS
  Prueft, ob eine Registrierung grundsaetzlich moeglich ist (ohne dauerhaft zu registrieren).

.DESCRIPTION
  Fuehrt einen kurzen Import-Versuch in den Quarantaene-Tenant aus (Graph beta import-Action),
  interpretiert 808/806-Fehler und fuehrt anschliessend sofortiges Cleanup durch.
  Ergebnis als Objekt mit Status/Code/Message.

.OUTPUTS
  PSCustomObject:
    Success  : [bool]  -> true = nicht fremd registriert
    Code     : [int]   -> 0, 806, 808, 21/22/25 fuer Fehlerpfade
    Message  : [string]
#>
    $cfg = Get-GraphConfig
    if (-not $cfg) {
        return [pscustomobject]@{ Success = $false; Code = 22; Message = "Keine Graph-Credentials (GraphApp.json oder ENV) gefunden." }
    }

    $token = Get-GraphToken -TenantId $cfg.tenantId -ClientId $cfg.clientId -ClientSecret $cfg.clientSecret
    if (-not $token) {
        return [pscustomobject]@{ Success = $false; Code = 22; Message = "Tokenbeschaffung fehlgeschlagen." }
    }

    $serial = Get-Serial
    if (-not $serial) {
        return [pscustomobject]@{ Success = $false; Code = 21; Message = "Seriennummer nicht ermittelbar." }
    }

    $hashB64 = Get-HardwareHashBase64
    if (-not $hashB64) {
        return [pscustomobject]@{ Success = $false; Code = 21; Message = "Hardware Hash nicht ermittelbar." }
    }

    $importId = [guid]::NewGuid().Guid
    $headers  = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
    $payload  = @{
        importedWindowsAutopilotDeviceIdentities = @(
            @{
                serialNumber       = $serial
                hardwareIdentifier = [System.Convert]::FromBase64String($hashB64)
                importId           = $importId
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/import" -Headers $headers -Body $payload -ErrorAction Stop | Out-Null
    } catch {
        $msg = $_.ErrorDetails.Message
        if ($msg -match "ZtdDeviceAssignedToOtherTenant|808") {
            return [pscustomobject]@{ Success = $false; Code = 808; Message = "Geraet ist bereits in einem anderen Tenant registriert (808)." }
        }
        if ($msg -match "ZtdDeviceAlreadyAssigned|806") {
            return [pscustomobject]@{ Success = $false; Code = 806; Message = "Geraet ist bereits in diesem Tenant registriert (806)." }
        }
        return [pscustomobject]@{ Success = $false; Code = 25; Message = "Import-Fehler: $msg" }
    }

    # Kurze Wartezeit fuer Server-Materialisierung
    Start-Sleep -Seconds 5

    # Cleanup: windowsAutopilotDeviceIdentities (v1.0) nach SerialNumber
    try {
        $filterSerial = $serial.Replace("'", "''")
        $wadp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '{0}'" -f $filterSerial) -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
        foreach ($d in $wadp.value) {
            try {
                Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($d.id)" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop | Out-Null
            } catch {}
        }
    } catch {}

    # Cleanup: importedWindowsAutopilotDeviceIdentities (beta) via importId
    try {
        $imp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities?`$filter=importId eq '{0}'" -f $importId) -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
        foreach ($i in $imp.value) {
            try {
                Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($i.id)" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop | Out-Null
            } catch {}
        }
    } catch {}

    return [pscustomobject]@{ Success = $true; Code = 0; Message = "Probe-Import moeglich, kein fremder Tenant. Cleanup erledigt." }
}

function Invoke-IntuneAutopilotPreflight {
<#
.SYNOPSIS
  Komfort-Wrapper fuer den Preflight-Check mit konsistenter Ausgabe.

.PARAMETER StopOnBlock
  Bricht den Prozess mit Exitcode ab, wenn das Geraet blockiert ist.

.OUTPUTS
  Gibt das Ergebnisobjekt (Success/Code/Message) zurueck.
#>
    param(
        [switch] $StopOnBlock
    )
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

    if ($StopOnBlock -and ($res.Code -in 806,808,21,22,25)) {
        # 23 = generischer Block-Exitcode fuer OEM-Flow
        exit 23
    }

    return $res
}

# ============================================================
# ENDE Functions3.ps1
# ============================================================
