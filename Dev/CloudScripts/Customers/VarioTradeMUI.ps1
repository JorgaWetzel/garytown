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

# ================================================================
#   OSDCloud-Variablen setzen
# ================================================================
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_25H2_MUI.wim'
    OSImageIndex      = 1  
    ClearDiskConfirm  = $false
    ZTI               = $true
	Firmware          = $false
    UpdateOS          = $false     
    UpdateDrivers     = $false 

    # --- Image / Installation ---
    # ImageFileFullName = 'Pfad zur WIM-Datei'
    # ImageFileItem     = Get-Item 'Pfad zur WIM'
    # ImageFileName     = 'Win11_25H2_MUI.wim'
    # OSImageIndex      = 1
    # Edition           = 'Enterprise'
    # Language          = 'de-CH'
    # TimeZone          = 'W. Europe Standard Time'
    # ClearDiskConfirm  = $false
    # ZTI               = $true

    # --- Firmware / Hardware ---
    # Firmware          = $true      # BIOS/Firmware-Update aktivieren
    # TPMUpdate         = $true      # TPM-Update aktivieren
    # SkipBitLocker     = $true      # BitLocker-Enable überspringen
    # DriverPackName    = 'HP EliteBook x360 G7'
    # DriverPackLatest  = $true      # immer neueste DriverPacks von OSDCloud
    # HPCMSLDriverPackLatest = $true # für HP: CMSL-Treiber immer aktuell

    # --- Windows Updates ---
    # UpdateOS          = $true      # Windows Quality Updates nach Deployment
    # UpdateDrivers     = $true      # Treiber über Windows Update
    # UpdateFirmware    = $true      # Firmware-Updates über Windows Update
    # UpdateMicrosoft365= $true      # Office/M365 Updates ziehen
    # UpdateDotNet      = $true      # .NET Updates über Windows Update
    # UpdateFeature     = $true      # Feature Updates (Versionssprung) zulassen
    # UpdateCumulative  = $true      # Cumulative Updates nach Deployment
    # UpdateSecurity    = $true      # Security Patches separat erzwingen

    # --- OOBE / Autopilot ---
    # SkipOOBE          = $true      # OOBE-Dialog überspringen
    # SkipAutopilot     = $true      # Autopilot-Registrierung deaktivieren
    # AutopilotJSON     = 'C:\OSDCloud\AutopilotProfile.json' 
    #                     # Profil explizit angeben (statt automatisch suchen)

    # --- Features / Optionen ---
    # InstallNetFX3     = $true      # .NET Framework 3.5 mitinstallieren
    # EnableWindowsStore= $true      # Windows Store aktivieren
    # RemoveBuiltInApps = $true      # Standard-Apps deinstallieren
    # EnableHyperV      = $true      # Hyper-V gleich aktivieren
    # EnableRSAT        = $true      # RSAT-Tools mitinstallieren
    # EnableWSL         = $true      # Windows Subsystem for Linux aktivieren
    # AddLanguages      = @('fr-CH','it-CH') # weitere Sprachen hinzufügen

    # --- WinPE / Setup ---
    # UpdateWinPE       = $true      # WinPE vorab aktualisieren
    # Wallpaper         = "$OSDCloudWorkspace\wallpaper.jpg"
    # SkipReboot        = $true      # Reboot am Ende unterdrücken (Testzwecke)	
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
    if ($Product -ne '895E' -or $Model -notmatch "z2mini"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
	
}
else{
    Write-Host -ForegroundColor Yellow "No driver pack found – falling back to HPIA."
    if (Test-HPIASupport){ $Global:MyOSDCloud.HPIAALL = [bool]$true }
}

# Optionale BIOS-/TPM-Updates beibehalten
function Ensure-TSEnv {
    # Statt: if ($global:TSEnv) { return }
    if (Get-Variable -Name TSEnv -Scope Global -ErrorAction SilentlyContinue) { return }

    try {
        $global:TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        return
    } catch {}

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

# ---- Automatische Vorpruefung vor Deployment ----
if ($CurrentIP -match '^10\.10\.100\.') {
	
# --- Post OS-Apply: GraphApp.json von Z:\ ins Ziel-OS kopieren (wird spaeter geloescht) ---
try {
    $src  = 'Z:\OSDCloud\GraphApp.json'
    $dest = 'C:\ProgramData\GraphApp.json'

    if (Test-Path -LiteralPath $src) {
        New-Item -ItemType Directory -Path (Split-Path -Path $dest) -Force | Out-Null
        Copy-Item -LiteralPath $src -Destination $dest -Force

        # ACLs: nur SYSTEM & BUILTIN\Administrators per SID
        $sidSystem = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-18'      # SYSTEM
        $sidAdmins = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-544'   # Builtin Admins

        $fs = New-Object System.Security.AccessControl.FileSecurity
        $fs.SetAccessRuleProtection($true, $false)  # Vererbung aus
        $fs.SetOwner($sidSystem)

        $ruleSystem = New-Object System.Security.AccessControl.FileSystemAccessRule($sidSystem, 'FullControl', 'Allow')
        $ruleAdmins = New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdmins, 'FullControl', 'Allow')
        $fs.AddAccessRule($ruleSystem)
        $fs.AddAccessRule($ruleAdmins)

        Set-Acl -LiteralPath $dest -AclObject $fs

        Write-Host -ForegroundColor Green "[VarioTradeMUI] GraphApp.json nach $dest kopiert (ACLs auf SYSTEM/Admins gesetzt)."
    } else {
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Quelle $src nicht gefunden – Preflight meldet sonst Code 22."
    }
}
catch {
    Write-Host -ForegroundColor Yellow "[VarioTradeMUI] Kopieren/ACL GraphApp.json fehlgeschlagen: $($_.Exception.Message)"
}

}


# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
