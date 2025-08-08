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
$DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z:'                              # gewünschter Laufwerks­buchstabe
$UserName    = 'Jorga'                          # Domänen- oder lokaler User
$PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)


#$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
#$MapDrive    = 'Z:'                               # gewünschter Laufwerks­buchstabe
#$UserName    = 'VARIODEPLOY\Administrator'       # Domänen- oder lokaler User
#$PlainPwd    = '12Monate'                        # Passwort (Klartext)

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
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#Enable HPIA | Update HP BIOS | Update HP TPM
 if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    if ($Product -ne '83B2' -or $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
    #{$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true #In Test 
    #Set HP BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}


#write variables to console
Write-Output $Global:MyOSDCloud


# --- Deployment ---------------------------------------------
Invoke-OSDCloud

# Set-OSDCloudUnattendAuditMode

# Initialize-OSDCloudStartnetUpdate

# --- Cache HP DriverPack to Z: and enable HPIA fallback if no pack found -------
try {
    # Try to identify the newest HP SoftPaq (sp*.exe) downloaded by OSD/HP CMSL
    $spExe = $null

    # Prefer filename reported by MyOSDCloud (if available)
    if ($Global:MyOSDCloud -and $Global:MyOSDCloud.DriverPackName) {
        $cand = Join-Path 'C:\Drivers' $Global:MyOSDCloud.DriverPackName
        if (Test-Path $cand) { $spExe = Get-Item $cand }
    }

    # Otherwise, search common locations
    if (-not $spExe) {
        $spExe = Get-ChildItem -Path 'C:\Drivers','C:\OSDCloud\DriverPacks\HP','D:\OSDCloud\DriverPacks\HP' `
                 -Filter 'sp*.exe' -Recurse -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }

    if ($spExe) {
        # Cache to Z:\ if present
        if (Test-Path 'Z:\') {
            $cacheRoot = 'Z:\OSDCloud\DriverPacks\HP'
            if (!(Test-Path $cacheRoot)) { New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null }
            $dest = Join-Path $cacheRoot $spExe.Name
            Copy-Item $spExe.FullName $dest -Force
            Write-Host "DriverPack cached to: $dest" -ForegroundColor Cyan
        } else {
            Write-Host "Z:\ not present – skipping cache." -ForegroundColor Yellow
        }
    } else {
        Write-Warning "No HP DriverPack (sp*.exe) found – scheduling HPIA fallback at FirstBoot."

        # Write a SetupComplete.cmd to run HPIA at first boot
        $scriptRoot = 'C:\Windows\Setup\Scripts'
        $hpiaRoot   = 'C:\Drivers\HPIA'
        New-Item -ItemType Directory -Path $scriptRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $hpiaRoot   -Force | Out-Null

        $setupCmd = @'
@echo off
:: HPIA fallback: download via PowerShell & run silent driver install
powershell -ExecutionPolicy Bypass -NoProfile -Command ^
  "$ErrorActionPreference='Stop'; ^
    try { Import-Module HPCMSL -ErrorAction Stop } catch { Install-Module HPCMSL -Force -Scope AllUsers -AllowClobber }; ^
    $sp = Get-SoftpaqList -Category Manageability | Where-Object { $_.Name -match 'HP Image Assistant' } | Sort-Object ReleaseDate -Descending | Select-Object -First 1; ^
    if (-not $sp) { throw 'HPIA softpaq not found via HPCMSL' }; ^
    $dest = 'C:\\Drivers\\HPIA'; New-Item -ItemType Directory -Force -Path $dest | Out-Null; ^
    Save-Softpaq -Id $sp.Id -Destination $dest -Overwrite; ^
    $spPath = Join-Path $dest ($sp.Id + '.exe'); ^
    Start-Process $spPath -ArgumentList '/s','/e','/f', (Join-Path $dest 'bin') -Wait; ^
    $hpia = Get-ChildItem (Join-Path $dest 'bin') -Filter 'HPImageAssistant*.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1; ^
    if ($hpia) { Start-Process $hpia.FullName -ArgumentList '/Operation:Analyze','/Category:Driver','/Action:Install','/Silent','/NoReboot' -Wait } ^
    else { Write-Error 'HPImageAssistant.exe not found after extraction' } ^
  "

exit /b 0
'@

        Set-Content -Path (Join-Path $scriptRoot 'SetupComplete.cmd') -Value $setupCmd -Encoding Ascii
    }
} catch {
    Write-Warning "Caching/HPIA-fallback block failed: $($_.Exception.Message)"
}
# -------------------------------------------------------------------------------

Restart-Computer -Force