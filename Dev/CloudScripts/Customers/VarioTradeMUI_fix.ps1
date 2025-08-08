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
# --- We want: DriverPack first, HPIA only as fallback; no MU Catalog drivers/firmware ---
if ($DriverPack) {
    Write-Host -ForegroundColor Cyan "Driver pack located – use DriverPack only; HPIA disabled (fallback only)."
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true
    $Global:MyOSDCloud.HPIAALL = [bool]$false
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$false
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$false
} else {
    Write-Host -ForegroundColor Yellow "No DriverPack found – enable HPIA as fallback."
    if (Test-HPIASupport){ $Global:MyOSDCloud.HPIAALL = [bool]$true }
}

# (Optional/no-op if not used by the module) prevent pulling from Microsoft Update Catalog
$Global:MyOSDCloud.MsUpCatDrivers = [bool]$false
$Global:MyOSDCloud.MsUpCatFirmware = [bool]$false

# Ensure HP BIOS settings function is available if later needed
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)



#write variables to console
Write-Output $Global:MyOSDCloud


# --- Deployment ---------------------------------------------
Invoke-OSDCloud

# --- Cache the downloaded DriverPack to Z: (if present) and extract without 7-Zip ---
try {
    $CacheRoot = "Z:\OSDCloud\DriverPacks\HP"
    $spExe = Get-ChildItem -Path "C:\Drivers" -Filter "sp*.exe" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($spExe) {
        if (Test-Path "Z:\") { New-Item -Path $CacheRoot -ItemType Directory -Force | Out-Null
            Copy-Item -Path $spExe.FullName -Destination (Join-Path $CacheRoot $spExe.Name) -Force
            Write-Host -ForegroundColor Green "Cached $($spExe.Name) to $CacheRoot"
        }
        $extractDir = Join-Path "C:\Drivers" $spExe.BaseName
        if (!(Test-Path $extractDir)) {
            Write-Host -ForegroundColor DarkCyan "Extracting $($spExe.Name) with SoftPaq switches to $extractDir"
            Start-Process -FilePath $spExe.FullName -ArgumentList "/s","/e","/f",$extractDir -Wait
        }
    }
} catch { Write-Warning $_ }

# Harden Windows to not offer driver updates via Windows Update
$scPath = "C:\Windows\Setup\Scripts\SetupComplete.ps1"
New-Item -ItemType Directory -Path (Split-Path $scPath) -Force | Out-Null
Add-Content -Path $scPath -Value @'
New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Force | Out-Null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name ExcludeWUDriversInQualityUpdate -Type DWord -Value 1
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching" -Name SearchOrderConfig -Type DWord -Value 0
'@
Restart-Computer -Force