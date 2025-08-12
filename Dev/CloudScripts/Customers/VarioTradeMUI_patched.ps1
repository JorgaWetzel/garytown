# 99-Deployment.ps1    StartNet-Hook, minimal
# ==== Quiet-on-error flag (controls Splash suppression in WinPE) ====
$Global:VarioQuietFlagDir  = "X:\OSDCloud\Flags"
$Global:VarioQuietFlagFile = Join-Path $Global:VarioQuietFlagDir "SilentSplashOff.txt"
function Set-QuietSplash {
    try {
        if (!(Test-Path $Global:VarioQuietFlagDir)) {
            New-Item -ItemType Directory -Path $Global:VarioQuietFlagDir -Force | Out-Null
        }
        New-Item -Path $Global:VarioQuietFlagFile -ItemType File -Force | Out-Null
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] QuietSplash Flag gesetzt  Splash wird beim nchsten Start bersprungen."
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
# Konfiguration  HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
<#
$DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                              # gewnschter Laufwerksbuchstabe
$UserName    = 'Jorga'                          # Domnen- oder lokaler User
$PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)
#>

$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                               # gewnschter Laufwerksbuchstabe
$UserName    = 'VARIODEPLOY\Administrator'                    # Domnen- oder lokaler User
$PlainPwd    = '12Monate'                         # Passwort (Klartext)

$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'

# Anmeldedaten vorbereiten
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

# ---------------- Driver package first, HPIA as fallback (robust) --------------------
# Nach ALLEN CMSL/OSDCloud-Versuchen prfen wir REAL, ob ein SoftPaq vorhanden ist:
function Test-HPSoftPaqPresent {
    param([string]$Path = 'C:\Drivers')
    try {
        $sp = Get-ChildItem -Path $Path -Filter 'sp*.exe' -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -gt 50MB } | Select-Object -First 1
        return $sp
    } catch { return $null }
}

$DriverPack = Test-HPSoftPaqPresent -Path 'C:\Drivers'  # < ersetzt die alte Quelle fr $DriverPack

if ($DriverPack) {
    Write-Host -ForegroundColor Cyan "Driver pack located  applying driver pack only."
    $Global:MyOSDCloud.DriverPackName          = $DriverPack.Name             # echtes File
    $Global:MyOSDCloud.HPCMSLDriverPackLatest  = $true                        # Pack aktiv
    $Global:MyOSDCloud.HPIAALL                 = $false                       # HPIA aus

    # Optional: Cache auf dein Medium (nur wenn vorhanden)
    $cacheDir = "Z:\OSDCloud\DriverPacks\HP"
    if (Test-Path 'Z:\') {
        if (!(Test-Path $cacheDir)){ New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        $destFile = Join-Path $cacheDir $DriverPack.Name
        if (!(Test-Path $destFile)){ Copy-Item -Path $DriverPack.FullName -Destination $destFile -Force }
    }
}
else {
    Write-Host -ForegroundColor Yellow "No driver pack found  falling back to HPIA."
    # KEIN String "None", KEIN abhngiges Test-HPIASupport: wir setzen klar das Flag
    $Global:MyOSDCloud.DriverPackName         = $null
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $false
    $Global:MyOSDCloud.HPIAALL                = $true
}
 
#Set HP BIOS Settings to what I want:
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
Manage-HPBiosSettings -SetSettings


#write variables to console
Write-Output $Global:MyOSDCloud

# --- Deployment ---------------------------------------------
try {
    Invoke-OSDCloud

# ================= Robust DriverPack presence check & Fallback Flag (BEGIN) =================
function Test-HPSoftPaqPresent {
    param([string]$Path = 'C:\Drivers')
    try {
        $sp = Get-ChildItem -Path $Path -Filter 'sp*.exe' -ErrorAction SilentlyContinue |
              Where-Object { $_.Length -gt 50MB } | Select-Object -First 1
        return $sp
    } catch { return $null }
}

# After all CMSL/OSDCloud attempts, decide deterministically if HPIA must run:
$DriverPackSp = Test-HPSoftPaqPresent -Path 'C:\Drivers'
if ($DriverPackSp) {
    Write-Host -ForegroundColor Cyan "Driver pack located – applying driver pack only: $($DriverPackSp.Name)"
    $Global:MyOSDCloud.DriverPackName         = $DriverPackSp.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true
    $Global:MyOSDCloud.HPIAALL                = $false
} else {
    Write-Host -ForegroundColor Yellow "No driver pack found – falling back to HPIA."
    $Global:MyOSDCloud.DriverPackName         = $null
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $false
    $Global:MyOSDCloud.HPIAALL                = $true
}
# ================= Robust DriverPack presence check & Fallback Flag (END) =================


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


# ================= Create SetupComplete.cmd with conditional HPIA (BEGIN) =================
try {
    $setupScripts = 'C:\Windows\Setup\Scripts'
    $newSetupComplete = Join-Path $setupScripts 'SetupComplete.cmd'
    New-Item -ItemType Directory -Force -Path $setupScripts | Out-Null

    $lines = @()
    $lines += '@echo off'
    $lines += 'setlocal'

    if ($Global:MyOSDCloud.HPIAALL) {
        $lines += 'set LOG=C:\HPIA\Logs'
        $lines += 'set REP=C:\HPIA\Reports'
        $lines += 'set SP=C:\HPIA\SPs'
        $lines += 'mkdir %LOG% 2>NUL & mkdir %REP% 2>NUL & mkdir %SP% 2=NUL'
        $lines += 'echo [%DATE% %TIME%] HPIA-Fallback aktiv >> %LOG%\HPIA.log'

        # Download HPIA on the fly (no pre-staging required)
        $lines += 'powershell -NoP -EP Bypass -Command "Try { iwr -UseBasicParsing ''https://hpia.hpcloud.hp.com/downloads/HPImageAssistant.exe'' -OutFile ''C:\HPIA\HPImageAssistant.exe'' -ErrorAction Stop } Catch { exit 1 }"'
        $lines += 'if not exist C:\HPIA\HPImageAssistant.exe exit /b 1'

        # Analyze + Install (Drivers only), silent, with report/cache
        $lines += '"C:\HPIA\HPImageAssistant.exe" /Operation:Analyze /Action:Install /Category:Drivers /Silent /ReportFolder %REP% /SoftPaqDownloadFolder %SP%'
        $lines += 'set EC=%ERRORLEVEL%'
        $lines += 'echo [%DATE% %TIME%] HPIA ExitCode %EC%>> %LOG%\HPIA.log'
        $lines += 'if %EC% EQU 0 shutdown /r /t 5 /c "Treiberinstallation (HPIA) abgeschlossen"'
    } else {
        # Optional: install SoftPaqs silently if present
        $lines += 'for %%S in (C:\Drivers\sp*.exe) do ('
        $lines += '  echo Installiere %%S ...'
        $lines += '  "%%S" /s /e /f C:\Drivers\Extract 2>nul'
        $lines += ')'
    }

    $lines += 'endlocal'
    Set-Content -Path $newSetupComplete -Value ($lines -join "`r`n") -Encoding ASCII
    Write-Host "[OSD] Wrote $newSetupComplete (HPIA-Fallback aktiviert: $($Global:MyOSDCloud.HPIAALL))"
} catch {
    Write-Warning "[OSD] SetupComplete creation failed: $($_.Exception.Message)"
}
# ================= Create SetupComplete.cmd with conditional HPIA (END) =================

Restart-Computer -Force
