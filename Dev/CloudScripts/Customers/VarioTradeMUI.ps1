# 99-Deployment.ps1  –  StartNet-Hook, minimal

Import-Module OSD -Force

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
$Manufacturer = (Get-CimInstance Win32_ComputerSystem).Manufacturer
if ($Manufacturer -match 'HP') {

    # Produkt- und Modell-Infos aus WMI
    $Product = (Get-CimInstance Win32_ComputerSystemProduct).Version
    $Model   = (Get-CimInstance Win32_ComputerSystem).Model

    # Passendes DriverPack ermitteln
    $DriverPack = Get-OSDCloudDriverPack -Product $Product `
                                         -OSVersion $OSVersion `
                                         -OSReleaseID $OSReleaseID

    if ($DriverPack) {
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
        # Immer das aktuellste CMSL-Paket verwenden (offline-fähig)
        $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true
    }

    # HPIA / BIOS / TPM nur wenn das Gerät es unterstützt
    if (Test-HPIASupport) {
        $Global:MyOSDCloud.HPTPMUpdate   = $true
        $Global:MyOSDCloud.HPBIOSUpdate  = $true

        if ($HPBiosSkipZBook -and ($Product -ne '83B2' -or $Model -notmatch 'zbook')) {
            $Global:MyOSDCloud.HPIAALL = $true
        }

        # BIOS-Settings optional anpassen
        try {
            iex (irm 'https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1')
            Manage-HPBiosSettings -SetSettings
        } catch {
            Write-Warning "Manage-HPBiosSettings konnte nicht ausgeführt werden: $_"
        }
    }
}

# --- Deployment ausführen ---------------------------------------------
Invoke-OSDCloud

# --- Spätphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
