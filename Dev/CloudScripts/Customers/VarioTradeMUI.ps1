# 99-Deployment.ps1  –  StartNet-Hook, minimal

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

#========================================================
#   Netzwerkfreigabe verbinden
#========================================================

$DeployShare = '\\10.10.100.100\Daten'
$MapDrive    = 'Z:'
$UserName    = 'Jorga'
$PlainPwd    = 'Dont4getme'
$SrcWim      = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'


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
}

# --------   HP‑spezifisches vorbereiten --------------------
$Product = (Get-HPDeviceProductID).ProductID
$Model   = (Get-HPDeviceProductID).ProductName


# --- Treiber‑Logik ---------------------------------------------
# 1) Versuche immer zuerst das passende Driver‑Pack via CMSL
# 2) Falls KEIN Driver‑Pack vorhanden ist, verwende HPIA als Fallback

$OSVersion   = 'Windows 11'    # Used to Determine Driver Pack
$OSReleaseID = '24H2'         # Used to Determine Driver Pack
$DriverPack  = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack) {
    # Driver‑Pack gefunden – nur dieses installieren
    $Global:MyOSDCloud.DriverPackName         = $DriverPack.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true
    $Global:MyOSDCloud.HPIAALL                = [bool]$false
} else {
    # Kein Driver‑Pack – HPIA als Fallback benutzen, falls unterstützt
    if (Test-HPIASupport) {
        $Global:MyOSDCloud.HPIAALL = [bool]$true
    }
}

# ---------- Paket auf Laufwerk Z: cachen ------------------------
$CacheRoot = 'Z:\OSDCloud\DriverPacks\HP'
if (-not (Test-Path $CacheRoot)) { New-Item -Path $CacheRoot -ItemType Directory -Force | Out-Null }

if ($DriverPack) {
    $LocalDriverPack = Join-Path 'C:\Drivers' $DriverPack.Name
    if (Test-Path $LocalDriverPack) {
        Copy-Item -Path $LocalDriverPack -Destination $CacheRoot -Force
    }
}
# ----------------------------------------------------------------

# --- Deployment ---------------------------------------------
Invoke-OSDCloud

# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
