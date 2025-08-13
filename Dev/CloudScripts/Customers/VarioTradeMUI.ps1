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

$functionsUrl = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions3.ps1'
iex (Invoke-WebRequest -UseBasicParsing -Uri $functionsUrl).Content

#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# ======================================================================
# Automatische Konfiguration basierend auf IP-Bereich (WinPE-tauglich)
# ======================================================================

# Aktuelle IP-Adresse aus ipconfig holen
$CurrentIP = (ipconfig | Select-String "IPv4" | ForEach-Object {
    ($_ -split ":")[-1].Trim()
} | Where-Object { $_ -match "^10\.10\.100\.|^192\.168\.2\." } | Select-Object -First 1)

if ($CurrentIP -match '^10\.10\.100\.') {
    # Konfiguration für 10.10.100.x
    $DeployShare = '\\10.10.100.100\Daten'
    $MapDrive    = 'Z:'
    $UserName    = 'Jorga'
    $PlainPwd    = 'Dont4getme'
}
elseif ($CurrentIP -match '^192\.168\.2\.') {
    # Konfiguration für 192.168.2.x
    $DeployShare = '\\192.168.2.15\DeploymentShare$'
    $MapDrive    = 'Z:'
    $UserName    = 'VARIODEPLOY\Administrator'
    $PlainPwd    = '12Monate'
}
else {
    Write-Host "Keine passende IP-Konfiguration gefunden!" -ForegroundColor Red
    return
}

$SrcWim = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'

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

# ---- Automatische Vorpruefung vor Deployment ----
if ($CurrentIP -match '^10\.10\.100\.') {
	
# --- Post OS-Apply: OOBE-Preflight sicher ins Ziel-OS schreiben ---
try {
    $ss = 'C:\Windows\Setup\Scripts'
    New-Item -ItemType Directory -Path $ss -Force | Out-Null

    # SetupComplete.cmd
    @'
@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%SystemRoot%\Setup\Scripts\Autopilot-OOBE-Preflight.ps1"
exit /b 0
'@ | Set-Content -Path "$ss\SetupComplete.cmd" -Encoding Ascii

    # Autopilot-OOBE-Preflight.ps1 (aus Repo ziehen)
    $preUrl = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Autopilot-OOBE-Preflight.ps1'
    Invoke-WebRequest -UseBasicParsing -Uri $preUrl -OutFile "$ss\Autopilot-OOBE-Preflight.ps1"

    # Optional: falls du GraphApp.json temporaer lokal brauchst (wird im Preflight wieder geloescht)
    $gp = 'C:\ProgramData\GraphApp.json'
    if (-not (Test-Path $gp) -and (Test-Path 'Z:\OSDCloud\GraphApp.json')) {
        Copy-Item 'Z:\OSDCloud\GraphApp.json' $gp -Force
    }

    Write-Host -ForegroundColor Green "[VarioTradeMUI] OOBE-Preflight hinterlegt."
}
catch {
    Write-Host -ForegroundColor Yellow "[VarioTradeMUI] OOBE-Preflight Hinterlegung fehlgeschlagen: $($_.Exception.Message)"
}           
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

# ---------------- Driver package first, HPIA as fallback --------------------
if ($DriverPack){
    Write-Host -ForegroundColor Cyan "Driver pack located – applying driver pack only."
    $Global:MyOSDCloud.DriverPackName      = $DriverPack.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true   # Driver-Pack aktiv
    $Global:MyOSDCloud.HPIAALL             = [bool]$false     # HPIA deaktivieren
	if ($Product -ne '83B2' -or $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
}
else{
    Write-Host -ForegroundColor Yellow "No driver pack found – falling back to HPIA."
    if (Test-HPIASupport){ $Global:MyOSDCloud.HPIAALL = [bool]$true }
}

# Optionale BIOS-/TPM-Updates beibehalten
function Ensure-TSEnv {
    if ($global:TSEnv) { return }
    try { $global:TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment; return } catch {}
    Add-Type -Language CSharp @"
using System;
public class FakeTSEnv {
  public string Value(string name) { return Environment.GetEnvironmentVariable(name); }
  public void Value(string name, string value) { Environment.SetEnvironmentVariable(name, value); }
}
"@
    $global:TSEnv = New-Object FakeTSEnv
    if (-not $env:_SMSTSLogPath) { $env:_SMSTSLogPath = "X:\Windows\Temp" }
    if (-not $env:SMSTSLogPath)  { $env:SMSTSLogPath  = "X:\Windows\Temp" }
}
Ensure-TSEnv

# Dein Block bleibt aktiv – jetzt ohne Fehler:
if (Test-HPIASupport){
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true
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
