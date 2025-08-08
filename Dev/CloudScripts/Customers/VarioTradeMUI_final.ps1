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

# ---------------- Driver package first, HPIA as fallback --------------------
if ($DriverPack){
    Write-Host -ForegroundColor Cyan "Driver pack located – applying driver pack only."
    $Global:MyOSDCloud.DriverPackName      = $DriverPack.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true   # Driver-Pack aktiv
    $Global:MyOSDCloud.HPIAALL             = [bool]$false     # HPIA deaktivieren

    # Cache in Z:\OSDCloud\DriverPacks\HP
    $cacheDir = "Z:\OSDCloud\DriverPacks\HP"
    if (!(Test-Path $cacheDir)){ New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $destFile = Join-Path $cacheDir $DriverPack.Name
    if (!(Test-Path $destFile)){ Copy-Item -Path $DriverPack.FullName -Destination $destFile -Force }
}
else{
    Write-Host -ForegroundColor Yellow "No driver pack found – falling back to HPIA."
    if (Test-HPIASupport){ $Global:MyOSDCloud.HPIAALL = [bool]$true }
}

# Optionale BIOS-/TPM-Updates beibehalten
if (Test-HPIASupport){
    $Global:MyOSDCloud.HPTPMUpdate  = [bool]$true
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

# --- Deployment ---------------------------------------------
Invoke-OSDCloud
# --- Post Invoke-OSDCloud: ensure Z:\ cache of DriverPack and SetupComplete shutdown ---
try {
    # map info: assume Z: already mapped earlier by net use in script
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

    # Create SetupComplete to force OOBE shutdown using your 99-varo-shutdown.ps1
    $setupDir = 'C:\Windows\Setup\Scripts'
    New-Item -ItemType Directory -Path $setupDir -Force | Out-Null
    $shutdownPs1 = Join-Path $setupDir '99-varo-shutdown.ps1'
    try {
        Invoke-RestMethod 'https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Customers/99-varo-shutdown.ps1' | Out-File -FilePath $shutdownPs1 -Encoding ascii -Force
        Write-Host -ForegroundColor Green "[VarioTradeMUI] Wrote $shutdownPs1"
    } catch {
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Failed to download 99-varo-shutdown.ps1: $($_.Exception.Message)"
    }
    $scmd = @'
@echo off
echo [%date% %time%] Running 99-varo-shutdown.ps1 >> C:\Windows\Temp\varo-shutdown.log
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Windows\Setup\Scripts\99-varo-shutdown.ps1"
exit /b 0
'@
    $scPath = Join-Path $setupDir 'SetupComplete.cmd'
    $scmd | Out-File -FilePath $scPath -Encoding ascii -Force
    Write-Host -ForegroundColor Green "[VarioTradeMUI] Wrote $scPath"
} catch {
    Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Post-Invoke cache/SetupComplete block failed: $($_.Exception.Message)"
}

# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force