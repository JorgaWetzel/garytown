# 99-Deployment.ps1  –  StartNet-Hook, minimal

Import-Module OSD -Force

iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

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
# $DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
# $MapDrive    = 'Z'                              # gewünschter Laufwerks­buchstabe
# $UserName    = 'Jorga'                          # Domänen- oder lokaler User
# $PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)


$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z'                               # gewünschter Laufwerks­buchstabe
$UserName    = 'VARIODEPLOY\Administrator'       # Domänen- oder lokaler User
$PlainPwd    = '12Monate'                        # Passwort (Klartext)
$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'
# ======================================================================
# Ab hier nichts mehr ändern
# ======================================================================

# Anmelde­daten vorbereiten
$SecurePwd = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
$Cred      = New-Object System.Management.Automation.PSCredential ($UserName,$SecurePwd)

# Share verbinden
if (-not (Get-PSDrive -Name $MapDrive -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $MapDrive `
                -PSProvider FileSystem `
                -Root $DeployShare `
                -Credential $Cred `
                -ErrorAction Stop
}


# --- OSDCloud-Variablen setzen ----------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5     # ggf. anpassen
    ClearDiskConfirm  = $false
    ZTI               = $true
    UpdateOS          = $false      # Keine kumulativen Windows-Updates
    UpdateDrivers     = $false      # Microsoft-Treiber�updates AUS
}


# -----------------------------------------------------------
# HP-DriverPack  (SKU-Fallback + 22H2-Fallback)
# -----------------------------------------------------------
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -match 'HP') {

    $Product = (Get-CimInstance Win32_ComputerSystemProduct).Version
    if (-not $Product) {
        $Product = $cs.SystemSKUNumber
        Write-Host "Version leer � nehme SKU: $Product" -ForegroundColor Yellow
    }

    $OSVersion = 'Windows 11'
    $OSReleaseID = '24H2'

    function Find-Pack {
        param($Prod,$Rel)
        Get-OSDCloudDriverPack -Product $Prod -OSVersion $OSVersion -OSReleaseID $Rel `
                               -ErrorAction SilentlyContinue
    }

    $dp = Find-Pack $Product $OSReleaseID
    if (-not $dp) {
        Write-Host "Kein Pack f�r 24H2, versuche 22H2 ..." -ForegroundColor DarkYellow
        $dp = Find-Pack $Product '22H2'
    }

    if ($dp) {
        Write-Host "Gefunden: $($dp.Name)" -ForegroundColor Green
        $Global:MyOSDCloud.DriverPackName = $dp.Name
    }
    else {
        Write-Warning '>> HP-DriverPack weiterhin nicht gefunden! <<'
    }

    # Firmware-Optionen
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true
    $Global:MyOSDCloud.HPIAALL      = $true
}
else {
    Write-Host "Kein HP-Ger�t � DriverPack-Suche �bersprungen."
}


# --- Deployment ausführen ---------------------------------------------
Invoke-OSDCloud

# --- Spätphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
