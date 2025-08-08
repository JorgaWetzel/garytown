
# ---------------- Driver package first, HPIA as fallback (with cache search) --------------------
$DriverPack = Get-OSDCloudDriverPack

# Falls kein DriverPack gefunden, im Cache auf Z: suchen
if (-not $DriverPack -and (Test-Path 'Z:\OSDCloud\DriverPacks\HP')) {
    $DriverPackPath = Get-ChildItem 'Z:\OSDCloud\DriverPacks\HP' -Filter *.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($DriverPackPath) {
        $DriverPack = [PSCustomObject]@{
            Name     = $DriverPackPath.Name
            FullName = $DriverPackPath.FullName
        }
    }
}

if ($DriverPack) {
    Write-Host -ForegroundColor Cyan 'Driver pack found - installing only driver pack.'
    $Global:MyOSDCloud.DriverPackName        = $DriverPack.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true    # Driver-Pack aktiv
    $Global:MyOSDCloud.HPIAALL               = $false   # HPIA deaktivieren

    # Paket im Cache auf Z: ablegen
    $cacheDir = 'Z:\OSDCloud\DriverPacks\HP'
    if (!(Test-Path $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
    $destFile = Join-Path $cacheDir $DriverPack.Name
    if (!(Test-Path $destFile)) { Copy-Item -Path $DriverPack.FullName -Destination $destFile -Force }
}
else {
    Write-Host -ForegroundColor Yellow 'No driver pack found - falling back to HPIA.'
    if (Test-HPIASupport) { $Global:MyOSDCloud.HPIAALL = $true }
}

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

# --- OSDCloud First-Boot: Erfolgston + sofortiges Shutdown --------------------
$autoDir = 'C:\OSDCloud\Automate\Startup'
New-Item -ItemType Directory -Path $autoDir -Force | Out-Null

$ps1 = @'
# 99-varo-shutdown.ps1  (läuft als System vor OOBE)
try {
    # 1) kurzer Erfolgston (MessageBeep, dann Beep-Fallback)
    $sig = '[DllImport("user32.dll")]public static extern bool MessageBeep(uint uType);'
    Add-Type -MemberDefinition $sig -Name U -Namespace Win32 -ErrorAction SilentlyContinue | Out-Null
    1..3 | ForEach-Object { [Win32.U]::MessageBeep(0x40) | Out-Null; Start-Sleep -Milliseconds 300 }
    try { [console]::beep(800,200); [console]::beep(1000,200) } catch {}

    # 2) Log und Shutdown
    Add-Content -Path 'C:\Windows\Temp\SetupComplete.log' -Value ("[{0}] Vario shutdown triggered" -f (Get-Date))
    Start-Process -FilePath 'shutdown.exe' -ArgumentList '/s','/t','0','/f' -WindowStyle Hidden
}
catch {
    Add-Content -Path 'C:\Windows\Temp\SetupComplete.log' -Value ("[{0}] Vario shutdown failed: {1}" -f (Get-Date), $_.Exception.Message)
}
'@

# Skript mit ASCII (kompatibel) schreiben; Name mit "99-" -> läuft als letztes
$scriptPath = Join-Path $autoDir '99-varo-shutdown.ps1'
Set-Content -Path $scriptPath -Value $ps1 -Encoding Ascii
# -----------------------------------------------------------------------------


# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force