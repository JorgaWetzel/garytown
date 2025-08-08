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

$DeployShare = '\\192.168.2.16\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                               # gewünschter Laufwerks­buchstabe
$UserName    = 'Administrator'                    # Domänen- oder lokaler User
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

    # --- SetupComplete (dein vorhandener Weg) ---
    try {
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
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] SetupComplete creation failed: $($_.Exception.Message)"
    }

    # --- NEU: Nur-PostAction-Variante mit Zeit-Log ---
    try {
        $postDir = 'C:\OSDCloud\Scripts\PostAction'
        New-Item -ItemType Directory -Path $postDir -Force | Out-Null

        $VarioPostAction = @'
# ===== VarioTrade PostAction: Beep + Shutdown =====
try { New-Item -ItemType Directory -Path ''C:\Windows\Temp'' -Force | Out-Null } catch {}
$logFile = ''C:\Windows\Temp\varo-shutdown.log''

Add-Content -Path $logFile -Value ("[START] $(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') - PostAction gestartet")

# Doppel-Beep: Console.Beep (funktioniert oft auch ohne Audioservice), mit WAV-Fallback
try {
    [console]::Beep(880,180); Start-Sleep -Milliseconds 120; [console]::Beep(1200,240)
} catch {
    try {
        $wav = [IO.Path]::Combine($env:TEMP,''vbeep.wav'')
        [IO.File]::WriteAllBytes($wav, [Convert]::FromBase64String(
        ''UklGRsQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQcAAAAA////AP///wD///8A////AP///wD///8A''))
        Add-Type -AssemblyName System.Windows.Forms
        (New-Object System.Media.SoundPlayer $wav).PlaySync()
        Remove-Item $wav -ErrorAction SilentlyContinue
    } catch {}
}

# Marker + Shutdown
New-Item -Path ''C:\Windows\Temp\varo.postaction.ran'' -ItemType File -Force | Out-Null
Add-Content -Path $logFile -Value ("[END] $(Get-Date -Format ''yyyy-MM-dd HH:mm:ss'') - Shutdown eingeleitet")
Start-Sleep -Seconds 2
Start-Process -FilePath "shutdown.exe" -ArgumentList "/s /t 3 /f" -WindowStyle Hidden
# ===== end VarioTrade PostAction =====
'@

        $paFile = Join-Path $postDir '99-varo-shutdown.ps1'
        $VarioPostAction | Out-File -FilePath $paFile -Encoding ascii -Force
        Write-Host -ForegroundColor Green "[VarioTradeMUI] PostAction erstellt: $paFile"
    } catch {
        Write-Host -ForegroundColor Yellow "[VarioTradeMUI] PostAction konnte nicht erstellt werden: $($_.Exception.Message)"
    }
}

# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
