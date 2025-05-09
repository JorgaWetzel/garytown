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
}

# --------   HP-Spezifisches vorbereiten --------------------
$cs  = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -match 'HP') {

    # Pflicht-Variablen füllen
    $Product      = (Get-CimInstance Win32_ComputerSystemProduct).Version
    $OSVersion    = 'Windows 11'            # oder 'Windows 10'
    $OSReleaseID  = '24H2'                  # z. B. 22H2 / 24H2 …

    # DriverPack holen
    $DriverPack = Get-OSDCloudDriverPack `
                    -Product      $Product `
                    -OSVersion    $OSVersion `
                    -OSReleaseID  $OSReleaseID

    if ($DriverPack) { 
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name 
    }

    # Firmware-Optionen
    $Global:MyOSDCloud.HPTPMUpdate   = $true
    $Global:MyOSDCloud.HPBIOSUpdate  = $true
    $Global:MyOSDCloud.HPIAALL       = $true
}

# --- Deployment ausführen ---------------------------------------------
Invoke-OSDCloud

# --- Spätphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
