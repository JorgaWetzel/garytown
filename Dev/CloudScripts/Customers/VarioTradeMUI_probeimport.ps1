

# ============================================================
# Autopilot 'Probe-Import' Check (kein dauerhaftes Registrieren)
# ============================================================
# Idee: Wir fragen Microsoft "wuerde ich dieses Geraet registrieren duerfen?"
# Technisch gibt es keinen Dry-Run. Daher machen wir einen kurzen Import-Versuch
# in einen Quarantaene-Tenant und Raeumen SOFORT wieder auf.
# - Wenn Fehler 808 (ZtdDeviceAssignedToOtherTenant): Geraet ist anderswo registriert -> STOP
# - Wenn Fehler 806 (ZtdDeviceAlreadyAssigned): schon in DIESEM Tenant -> STOP
# - Wenn Import gelingt: wir loeschen sofort jeden erzeugten Eintrag wieder.
# Hinweis: Ohne Tenant/App-Credentials ist diese Pruefung nicht moeglich.

function Get-GraphConfig {
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
                if ($cfg -isnot [System.Collections.IEnumerable]) { $cfg = @($cfg) }
                if ($cfg.Count -gt 0) { return $cfg[0] } # wir nehmen den ersten Eintrag
            } catch {}
        }
    }
    # ENV Fallback
    if ($env:GRAPH_TENANT_ID -and $env:GRAPH_CLIENT_ID -and $env:GRAPH_CLIENT_SECRET) {
        return [pscustomobject]@{
            tenantId    = $env:GRAPH_TENANT_ID
            clientId    = $env:GRAPH_CLIENT_ID
            clientSecret= $env:GRAPH_CLIENT_SECRET
        }
    }
    return $null
}

function Get-GraphToken {
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

function Get-Serial { 
    try { 
        $s=(Get-CimInstance Win32_BIOS -ErrorAction Stop).SerialNumber 
        if ($s){ return $s.Trim() } 
    } catch {}
    try { 
        $s=(Get-WmiObject Win32_BIOS -ErrorAction Stop).SerialNumber
        if ($s){ return $s.Trim() } 
    } catch {}
    try {
        $s=(Get-WmiObject Win32_ComputerSystemProduct -ErrorAction Stop).IdentifyingNumber
        if ($s){ return $s.Trim() }
    } catch {}
    return $null
}

function Get-HardwareHashBase64 {
    # Erfordert Get-WindowsAutopilotInfo.ps1 im Suchpfad
    $candidates = @(
        "$PSScriptRoot\Get-WindowsAutopilotInfo.ps1",
        "X:\OSDCloud\Scripts\Get-WindowsAutopilotInfo.ps1",
        "X:\Get-WindowsAutopilotInfo.ps1"
    )
    foreach ($p in $candidates) {
        if (Test-Path -LiteralPath $p) {
            . $p
            break
        }
    }
    if (Get-Command Get-WindowsAutopilotInfo -ErrorAction SilentlyContinue) {
        $info = Get-WindowsAutopilotInfo -OutputObject -ErrorAction SilentlyContinue
        if ($null -ne $info -and $info.HardwareHash) { return $info.HardwareHash }
    }
    return $null
}

function Invoke-AutopilotProbeImport {
    # returns $true wenn NICHT fremd-registriert (Import moeglich war und wieder geloescht wurde)
    # returns $false wenn fremd-registriert (808/806) oder Fehler
    $cfg = Get-GraphConfig
    if (-not $cfg) {
        Write-Host "Keine GraphApp.json / ENV-Creds gefunden. Pruefung nicht moeglich." -ForegroundColor Yellow
        return $false
    }
    $token = Get-GraphToken -TenantId $cfg.tenantId -ClientId $cfg.clientId -ClientSecret $cfg.clientSecret
    if (-not $token) { return $false }

    $serial = Get-Serial
    if (-not $serial) {
        Write-Host "Seriennummer nicht ermittelbar. Abbruch." -ForegroundColor Yellow
        return $false
    }
    $hashB64 = Get-HardwareHashBase64
    if (-not $hashB64) {
        Write-Host "Hardware Hash nicht ermittelbar. Abbruch." -ForegroundColor Yellow
        return $false
    }

    $importId = [guid]::NewGuid().Guid
    $headers = @{ Authorization = "Bearer $token"; "Content-Type"="application/json" }
    $payload = @{
        importedWindowsAutopilotDeviceIdentities = @(
            @{
                serialNumber       = $serial
                hardwareIdentifier = [System.Convert]::FromBase64String($hashB64)
                importId           = $importId
            }
        )
    } | ConvertTo-Json -Depth 5

    try {
        $resp = Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/import" -Headers $headers -Body $payload -ErrorAction Stop
    } catch {
        $msg = $_.ErrorDetails.Message
        if ($msg -match "ZtdDeviceAssignedToOtherTenant|808") {
            Write-Host "BLOCKIERT: Dieses Geraet ist bereits in einem anderen Tenant registriert. (808)" -ForegroundColor Red
            return $false
        }
        if ($msg -match "ZtdDeviceAlreadyAssigned|806") {
            Write-Host "BLOCKIERT: Dieses Geraet ist bereits in diesem Tenant registriert. (806)" -ForegroundColor Red
            return $false
        }
        Write-Host "Import-Fehler: $msg" -ForegroundColor Yellow
        return $false
    }

    # Kurze Wartezeit, damit Server Eintraege materialisiert
    Start-Sleep -Seconds 5

    # Cleanup: alle WindowsAutopilotDeviceIdentities mit der Seriennummer entfernen
    try {
        $wadp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=serialNumber eq '{0}'" -f $serial.Replace("'","''")) -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop
        foreach ($d in $wadp.value) {
            Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/v1.0/deviceManagement/windowsAutopilotDeviceIdentities/$($d.id)" -Headers @{ Authorization="Bearer $token" } -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}

    # Cleanup: importedWindowsAutopilotDeviceIdentities via importId
    try {
        $imp = Invoke-RestMethod -Method Get -Uri ("https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities?`$filter=importId eq '{0}'" -f $importId) -Headers @{ Authorization="Bearer $token" } -ErrorAction Stop
        foreach ($i in $imp.value) {
            Invoke-RestMethod -Method Delete -Uri "https://graph.microsoft.com/beta/deviceManagement/importedWindowsAutopilotDeviceIdentities/$($i.id)" -Headers @{ Authorization="Bearer $token" } -ErrorAction SilentlyContinue | Out-Null
        }
    } catch {}

    Write-Host "Probe-Import war moeglich (kein fremder Tenant). Cleanup erledigt." -ForegroundColor Green
    return $true
}

# ---- Automatische Vorpruefung vor Deployment ----
try {
    $ok = Invoke-AutopilotProbeImport
    if (-not $ok) {
        Write-Host "Deployment ABGEBROCHEN." -ForegroundColor Red
        exit 23
    }
} catch {
    Write-Host "Vorpruefung fehlgeschlagen: $($_.Exception.Message). Deployment zur Sicherheit abgebrochen." -ForegroundColor Red
    exit 23
}
# ============================================================

# 99-Deployment.ps1  –  StartNet-Hook, minimal
# ==== Quiet-on-error flag (controls Splash suppression in WinPE) ====
$Global:VarioQuietFlagDir  = "X:\OSDCloud\Flags"
$Global:VarioQuietFlagFile = Join-Path $Global:VarioQuietFlagDir "SilentSplashOff.txt"
function Set-QuietSplash {
    try {
        if (!(Test-Path $Global:VarioQuietFlagDir)) {
            New-Item -ItemType Directory -Path $Global:VarioQuietFlagDir -Force | Out-Null
        }
        New-Item -Path $Global:VarioQuietFlagFile -ItemType File -Force | Out-Null
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] QuietSplash Flag gesetzt – Splash wird beim nächsten Start übersprungen."
    } catch {
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Konnte QuietSplash Flag nicht setzen: $($_.Exception.Message)"
    }
}
# ================================================================

Import-Module OSD -Force

Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
# Write-Host -ForegroundColor Green "PSCloudScript at functions.osdcloud.com"
# Invoke-Expression (Invoke-RestMethod -Uri functions.osdcloud.com)

iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

#Transport Layer Security (TLS) 1.2
Write-Host -ForegroundColor Green "Transport Layer Security (TLS) 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# ======================================================================
# Konfiguration – HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
<#
$DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                              # gewünschter Laufwerks­buchstabe
$UserName    = 'Jorga'                          # Domänen- oder lokaler User
$PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)
#>

$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                               # gewünschter Laufwerks­buchstabe
$UserName    = 'VARIODEPLOY\Administrator'                    # Domänen- oder lokaler User
$PlainPwd    = '12Monate'                         # Passwort (Klartext)

$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'

# Anmelde­daten vorbereiten
$SecurePwd = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
$Cred      = New-Object System.Management.Automation.PSCredential ($UserName,$SecurePwd)

# Share verbinden
if (-not (Test-Path -Path $MapDrive)){
	net use $MapDrive $DeployShare /user:$UserName $PlainPwd /persistent:no
}
if (-not (Test-Path -Path $MapDrive)) {
    Write-Host "Failed to Map Drive" -ForegroundColor Red
    return
} else {
    Write-Host "Mapped Drive $MapDrive to $DeployShare" -ForegroundColor Green
}

# ================================================================
#   OSDCloud-Variablen setzen
# ================================================================
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 1  
    ClearDiskConfirm  = $false
    ZTI               = $true
	Firmware          = $false
    UpdateOS          = $false     
    UpdateDrivers     = $false      
}

# ================================================================
#   HP-Treiberpaket vorbereiten (mit lokalem Cache)
# ================================================================
$Product        = Get-MyComputerProduct
$OSVersion      = 'Windows 11'
$OSReleaseID    = '24H2'
$DriverPackName = "$Product-$OSVersion-$OSReleaseID.exe"
$DriverSearchPaths = @(
    "Z:\OSDCloud\DriverPacks\DISM\HP\$Product",
    "Z:\OSDCloud\DriverPacks\HP\$DriverPackName"
)

# --------   HP-Spezifisches vorbereiten --------------------
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2'     #Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#Enable HPIA | Update HP BIOS | Update HP TPM
if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    if ($Product -ne '83B2' -or $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA

    # If neither DriverPack nor HPIA is available, suppress Splash next boot to reveal errors
    try {
        $haveLocalDP = Test-Path 'C:\Drivers' -PathType Container -and @(Get-ChildItem 'C:\Drivers' -Filter sp*.exe -ErrorAction SilentlyContinue).Count -gt 0
        $hpiaSupported = $false
        try { $hpiaSupported = (Test-HPIASupport) } catch {}
        if (-not $haveLocalDP -and -not $hpiaSupported) {
            Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Kein DriverPack & kein HPIA verfügbar – setze QuietSplash Flag."
            Set-QuietSplash
        }
    } catch {}

    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true #In Test 
    #Set HP BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

#write variables to console
Write-Output $Global:MyOSDCloud

# --- Deployment ---------------------------------------------
try {
    Invoke-OSDCloud
}
catch {
    Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Invoke-OSDCloud failed: $($_.Exception.Message)"
    try { Set-QuietSplash } catch {}
}
finally {
    # --- Post Invoke-OSDCloud: Cache DriverPack nach Z:\ ---
    try {
        if (Test-Path 'Z:\') {
            $cacheDir = 'Z:\OSDCloud\DriverPacks\HP'
            if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
            # prefer explicit DriverPack if object exists and file on disk
            $dp = $null
            if ($DriverPack -and ($DriverPack.PSObject.Properties.Name -contains 'FullName') -and (Test-Path $DriverPack.FullName)) {
                $dp = Get-Item -LiteralPath $DriverPack.FullName -ErrorAction SilentlyContinue
            }
            if (-not $dp -and (Test-Path 'C:\Drivers')) {
                $dp = Get-ChildItem 'C:\Drivers' -Filter sp*.exe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            }
            if ($dp) {
                $dest = Join-Path $cacheDir $dp.Name
                if (!(Test-Path $dest)) {
                    Copy-Item -Path $dp.FullName -Destination $dest -Force
                    Write-Host -ForegroundColor Cyan "[VarioTradeMUI] Cached driver pack to $dest"
                } else {
                    Write-Host -ForegroundColor Green "[VarioTradeMUI] Driver pack already cached at $dest"
                }
            } else {
                Write-Host -ForegroundColor Yellow "[VarioTradeMUI] No sp*.exe found under C:\Drivers after Invoke-OSDCloud; skipping cache."
            }
        } else {
            Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Z:\ not available; skipping cache."
        }
    } catch {
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] DriverPack cache block failed: $($_.Exception.Message)"
    }
}

# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
