# Functions3.ps1
# ============================================================
# OSDCloud/WinPE Preflight-Check (OEM/Refurb)
# Ziel: Vor Deployment pruefen, ob ein Geraet bereits in einem anderen Tenant
#       fuer Windows Autopilot registriert ist. Ohne globale Abfrage -> Probe-Import
#       in Quarantaene-Tenant + sofortiges Cleanup. Optionaler Fallback per Seriennummer.
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
  Laedt IMMER die Community-Version (Andrew Taylor) und dot-sourct sie.
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
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        Write-Host "Download fehlgeschlagen: $msg" -ForegroundColor Red
        return $false
    }
}

function Get-Serial {
<#
.SYNOPSIS
  Liefert eine bereinigte Seriennummer (Trim) oder $null.
.DESCRIPTION
  Probiert CIM, dann WMI, dann IdentifyingNumber.
  Filtert bekannte Platzhalter ("To be filled by O.E.M.", "Default string", usw.).
#>
    $candidates = @()
    try { $candidates += (Get-CimInstance -ClassName Win32_BIOS -ErrorAction Stop).SerialNumber } catch {}
    try { $candidates += (Get-WmiObject -Class Win32_BIOS -ErrorAction Stop).SerialNumber } catch {}
    try { $candidates += (Get-WmiObject -Class Win32_ComputerSystemProduct -ErrorAction Stop).IdentifyingNumber } catch {}

    foreach ($raw in $candidates) {
        if (-not $raw) { continue }
        $s = "$raw".Trim()
        if (-not $s) { continue }
        # Filter ungueltige/Platzhalter-Seriennummern
        $bad = @(
            '^to be filled', '^default string$', '^system serial number$', '^none$', '^not applicable$', '^n/?a$',
            '^serial$', '^unknown$', '^unspecified$', '^oem$', '^o\.e\.m\.$', '^\*+$', '^0+$', '^123456', '^\s+$'
        )
        $isBad = $false
        foreach ($b in $bad) { if ($s -imatch $b) { $isBad = $true; break } }
        if (-not $isBad) { return $s }
    }
    return $null
}

function Get-GraphConfig {
<#
.SYNOPSIS
  Laedt die Graph App-Credentials (Tenant/Client/Secret).
.DESCRIPTION
  Sucht JSON an typischen Pfaden inkl. Z:\ und ENV:GRAPHAPP_JSON_PATH,
  faellt sonst auf ENV-Creds (GRAPH_TENANT_ID/CLIENT_ID/CLIENT_SECRET) zurueck.
#>
    param(
        [string[]] $CandidatePaths = @(
            $env:GRAPHAPP_JSON_PATH,
            "$PSScriptRoot\GraphApp.json",
            "X:\OSDCloud\GraphApp.json",
            "X:\OSDCloud\Scripts\GraphApp.json",
            "X:\GraphApp.json",
            "Z:\OSDCloud\GraphApp.json",
            "Z:\OSDCloud\Scripts\GraphApp.json",
            "Z:\GraphApp.json"
        )
    )

    foreach ($p in $CandidatePaths) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        if (Test-Path -LiteralPath $p) {
            try {
                $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
                $cfg = ConvertFrom-Json -InputObject $raw
                if ($cfg -is [System.Collections.IEnumerable]) {
                    if ($cfg.Count -ge 1) { return $cfg[0] }
                } else {
                    return $cfg
                }
            } catch {
                $em = $_.Exception.Message
                if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
                    $em = $_.ErrorDetails.Message
                }
                Write-Host "Konnte GraphApp.json nicht lesen ($p): $em" -ForegroundColor Yellow
            }
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
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        Write-Host "Tokenbeschaffung fehlgeschlagen: $msg" -ForegroundColor Yellow
        return $null
    }
}

function Get-HardwareHashBase64 {
<#
.SYNOPSIS
  Liefert den Windows Autopilot Hardware Hash (Base64) via Community Script.
.DESCRIPTION
  WinPE hat oft keinen MDM-Provider -> Script wirft Fehler. Wir fangen das ab.
#>
    if (-not (Use-GetWindowsAutopilotInfo)) { return $null }

    try {
        if (Get-Command Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue) {
            $info = Get-WindowsAutopilotInfo -OutputObject -ErrorAction Stop
            if ($null -ne $info -and $info.HardwareHash) { return $info.HardwareHash }
        }
    } catch {
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        Write-Host "Hardware Hash via Community-Script nicht ermittelbar: $msg" -ForegroundColor Yellow
    }
    return $null
}

# ---- Kleinhelper fuer robuste Graph-GETs ----
function Invoke-GraphGet {
    param(
        [Parameter(Mandatory)] [string] $Url,
        [Parameter(Mandatory)] [hashtable] $Headers
    )
    try {
        $r = Invoke-RestMethod -Method Get -Uri $Url -Headers $Headers -ErrorAction Stop
        return $r
    } catch {
        $status = $null; $msg = $null
        if ($_.Exception -and $_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode.value__ } catch {}
        }
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        if (-not $msg) { $msg = $_.Exception.Message }
        return @{ __error = $true; status = $status; message = $msg }
    }
}

function Test-AutopilotBySerial {
<#
.SYNOPSIS
  Robuster Fallback: prueft, ob Seriennummer bereits als Autopilot-Device existiert.
.DESCRIPTION
  Strategie:
   1) v1.0 + $filter (eq)
   2) beta + $filter (eq)
   3) Paged Listing (v1.0) + clientseitiges Filtern
  Gibt { Found, Matches } zurueck.
#>
    param(
        [Parameter(Mandatory)] [string] $Serial,
        [Parameter(Mandatory)] [string] $Token
    )

    if ([string]::IsNullOrWhiteSpace($Serial)) {
        return [pscustomobject]@{ Found = $false; Matches = 0 }
    }

    $filterSerial = $Serial.Replace("'", "''")
    $headers = @{ Authorization = "Bearer $Token" }

    # 1) v1.0 mit $filter
    $u1 = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '$filterSerial'"
    $r1 = Invoke-GraphGet -Url $u1 -Headers $headers
    if ($r1 -isnot [hashtable]) {
        $cnt = 0
        if ($r1.PSObject.Properties.Name -contains 'value') { $cnt = ($r1.value | Measure-Object).Count }
        return [pscustomobject]@{ Found = ($cnt -gt 0); Matches = $cnt }
    }
    if ($r1.__error -and $r1.status -ne 400) {
        Write-Host "Seriennummer-Abfrage v1.0 fehlgeschlagen ($($r1.status)): $($r1.message)" -ForegroundColor Yellow
        return [pscustomobject]@{ Found = $false; Matches = 0 }
    }

    # 2) beta mit $filter (wenn v1.0 400 wirft)
    $u2 = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '$filterSerial'"
    $r2 = Invoke-GraphGet -Url $u2 -Headers $headers
    if ($r2 -isnot [hashtable]) {
        $cnt = 0
        if ($r2.PSObject.Properties.Name -contains 'value') { $cnt = ($r2.value | Measure-Object).Count }
        return [pscustomobject]@{ Found = ($cnt -gt 0); Matches = $cnt }
    }
    if ($r2.__error -and $r2.status -ne 400) {
        Write-Host "Seriennummer-Abfrage beta fehlgeschlagen ($($r2.status)): $($r2.message)" -ForegroundColor Yellow
        return [pscustomobject]@{ Found = $false; Matches = 0 }
    }

    # 3) Paged Listing (v1.0) und local match (als letzte Instanz)
    Write-Host "Falle zur Sicherheit auf paged Listing + lokalen Vergleich zurueck..." -ForegroundColor Yellow
    $url = "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$top=999"
    $matches = 0
    while ($url) {
        $page = Invoke-GraphGet -Url $url -Headers $headers

        # Fehlerseite als Hashtable?
        if ($page -is [hashtable] -and $page.ContainsKey('__error') -and $page.__error) {
            Write-Host "Paged Listing fehlgeschlagen ($($page.status)): $($page.message)" -ForegroundColor Yellow
            break
        }

        # Ergebnisse verarbeiten, falls .value existiert
        if ($page.PSObject.Properties.Name -contains 'value') {
            foreach ($d in $page.value) {
                if (($d.serialNumber -as [string]) -and ($d.serialNumber -eq $Serial)) { $matches++ }
            }
        }

        # Paging: nur wenn @odata.nextLink vorhanden ist
        if ($page.PSObject.Properties.Name -contains '@odata.nextLink') {
            $url = $page.'@odata.nextLink'
        } else {
            $url = $null
        }
    }
    return [pscustomobject]@{ Found = ($matches -gt 0); Matches = $matches }
}

# -------------------------------
# HAUPTFUNKTIONEN
# -------------------------------

function Invoke-AutopilotProbeImport {
<#
.SYNOPSIS
  Prueft, ob eine Registrierung grundsaetzlich moeglich ist (ohne dauerhaft zu registrieren).
.PARAMETER AllowSerialFallback
  Aktiviert den schwaecheren Fallback ueber Seriennummer-Abfrage.
.CODES
    0   = Gruen (Probe-Import moeglich + Cleanup)
    806 = Bereits in DIESEM Tenant
    808 = Bereits in ANDEREM Tenant
    26  = Kein HW-Hash; Seriennummer nicht gefunden (schwaecheres Gruen)
    27  = Kein HW-Hash; Seriennummer gefunden (treat as block)
    21  = Keine SN/Hash ermittelbar / ungueltige SN
    22  = Keine Graph-Creds/Token
    25  = Sonstiger Import-Fehler
#>
    param([switch] $AllowSerialFallback)

    $cfg = Get-GraphConfig
    if (-not $cfg) {
        return [pscustomobject]@{ Success = $false; Code = 22; Message = "Keine Graph-Credentials (GraphApp.json/ENV) gefunden." }
    }

    $token = Get-GraphToken -TenantId $cfg.tenantId -ClientId $cfg.clientId -ClientSecret $cfg.clientSecret
    if (-not $token) {
        return [pscustomobject]@{ Success = $false; Code = 22; Message = "Tokenbeschaffung fehlgeschlagen." }
    }

    $serial = Get-Serial
    if (-not $serial) {
        return [pscustomobject]@{ Success = $false; Code = 21; Message = "Seriennummer nicht ermittelbar oder ungueltig." }
    }

    $hashB64 = Get-HardwareHashBase64

    if (-not $hashB64) {
        if ($AllowSerialFallback) {
            Write-Host "Fallback aktiv: Hardware Hash nicht verfuegbar – pruefe Seriennummer im Tenant (schwaecher)." -ForegroundColor Yellow
            $s = Test-AutopilotBySerial -Serial $serial -Token $token
            if ($s.Found) {
                return [pscustomobject]@{ Success = $false; Code = 27; Message = "Seriennummer ist bereits als Autopilot-Device im Tenant vorhanden (Fallback). BLOCK." }
            } else {
                return [pscustomobject]@{ Success = $true; Code = 26; Message = "Kein HW-Hash, Seriennummer nicht gefunden (Fallback). Weiter moeglich, aber schwaecher verifiziert." }
            }
        } else {
            return [pscustomobject]@{ Success = $false; Code = 21; Message = "Hardware Hash nicht ermittelbar." }
        }
    }

    # --- Regulaerer Probe-Import ---
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
        $msg = $_.Exception.Message
        if ($_.PSObject.Properties.Name -contains 'ErrorDetails' -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $msg = $_.ErrorDetails.Message
        }
        if ($msg -match "ZtdDeviceAssignedToOtherTenant|808") {
            return [pscustomobject]@{ Success = $false; Code = 808; Message = "Geraet ist bereits in einem anderen Tenant registriert (808)." }
        }
        if ($msg -match "ZtdDeviceAlreadyAssigned|806") {
            return [pscustomobject]@{ Success = $false; Code = 806; Message = "Geraet ist bereits in diesem Tenant registriert (806)." }
        }
        return [pscustomobject]@{ Success = $false; Code = 25; Message = "Import-Fehler: $msg" }
    }

    # kurze Materialisierung
    Start-Sleep -Seconds 5

    # Cleanup: windowsAutopilotDeviceIdentities (v1.0) nach SerialNumber
    try {
        $filterSerial = $serial.Replace("'", "''")
        $wadp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '{0}'" -f $filterSerial) -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
        if ($wadp.PSObject.Properties.Name -contains 'value') {
            foreach ($d in $wadp.value) {
                try {
                    Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($d.id)" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop | Out-Null
                } catch {}
            }
        }
    } catch {}

    # Cleanup: importedWindowsAutopilotDeviceIdentities (beta) via importId
    try {
        $imp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities?`$filter=importId eq '{0}'" -f $importId) -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop
        if ($imp.PSObject.Properties.Name -contains 'value') {
            foreach ($i in $imp.value) {
                try {
                    Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($i.id)" -Headers @{ Authorization = "Bearer $token" } -ErrorAction Stop | Out-Null
                } catch {}
            }
        }
    } catch {}

    return [pscustomobject]@{ Success = $true; Code = 0; Message = "Probe-Import moeglich, kein fremder Tenant. Cleanup erledigt." }
}

function Invoke-IntuneAutopilotPreflight {
<#
.SYNOPSIS
  Komfort-Wrapper fuer den Preflight-Check mit konsistenter Ausgabe/Exitcode.
#>
    param(
        [switch] $StopOnBlock,
        [switch] $AllowSerialFallback
    )
    $res = Invoke-AutopilotProbeImport -AllowSerialFallback:$AllowSerialFallback

    switch ($res.Code) {
        0   { Write-Host $res.Message -ForegroundColor Green }
        26  { Write-Host $res.Message -ForegroundColor Yellow }  # schwaches Gruen
        806 { Write-Host $res.Message -ForegroundColor Red }
        808 { Write-Host $res.Message -ForegroundColor Red }
        27  { Write-Host $res.Message -ForegroundColor Red }      # Fallback-Block
        21  { Write-Host $res.Message -ForegroundColor Yellow }
        22  { Write-Host $res.Message -ForegroundColor Yellow }
        25  { Write-Host $res.Message -ForegroundColor Yellow }
        default { Write-Host $res.Message -ForegroundColor Yellow }
    }

    if ($StopOnBlock -and ($res.Code -in 806,808,27,21,22,25)) {
        exit 23   # generischer Block-Exitcode fuer OEM-Flow
    }

    return $res
}

# EOF
