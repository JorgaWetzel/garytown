# 99-Deployment.ps1  â€“  StartNet-Hook, minimal

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
# Konfiguration â€“ HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
# $DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
# $MapDrive    = 'Z'                              # gewÃ¼nschter LaufwerksÂ­buchstabe
# $UserName    = 'Jorga'                          # DomÃ¤nen- oder lokaler User
# $PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)


$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z'                               # gewÃ¼nschter LaufwerksÂ­buchstabe
$UserName    = 'VARIODEPLOY\Administrator'       # DomÃ¤nen- oder lokaler User
$PlainPwd    = '12Monate'                        # Passwort (Klartext)
$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'
# ======================================================================
# Ab hier nichts mehr Ã¤ndern
# ======================================================================

# AnmeldeÂ­daten vorbereiten
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
    UpdateDrivers     = $false      # Microsoft-Treiber­updates AUS
}


# =====================================================================
# HP-DriverPack  Universeller Fallback-Algorithmus (reine Console)
# =====================================================================
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -notmatch 'HP') {
    Write-Warning 'Kein HP-Gerät – DriverPack-Suche übersprungen.'
    return
}

# ---------- 1) Geräte-Kennung ermitteln --------------------------------
$Product = (Get-CimInstance Win32_ComputerSystemProduct).Version
if (-not $Product) {
    $Product = $cs.SystemSKUNumber
    Write-Host ("Version leer – benutze SKU  : {0}" -f $Product) -ForegroundColor Yellow
} else {
    Write-Host ("Product-Version gefunden     : {0}" -f $Product)
}

# ---------- 2) Suchmatrix anlegen --------------------------------------
$osList   = @('Windows 11','Windows 10')     # Reihenfolge wichtig!
$relList  = @('24H2','23H2','22H2','21H2')   # fallbackt bis 21H2 zurück
$found    = $null

# ---------- 3) DriverPack-Schleife -------------------------------------
foreach ($os in $osList) {
    foreach ($rel in $relList) {

        $dp = Get-OSDCloudDriverPack -Product $Product `
                                      -OSVersion   $os `
                                      -OSReleaseID $rel `
                                      -ErrorAction SilentlyContinue

        if ($dp) {
            $found = $dp
            Write-Host ("Treffer => {0}  |  {1}  {2}" -f $dp.Name,$os,$rel) -ForegroundColor Green
            break
        } else {
            Write-Host ("Kein Pack für {0}  {1}" -f $os,$rel) -ForegroundColor DarkGray
        }
    }
    if ($found) { break }
}

# ---------- 4) Ergebnis verarbeiten ------------------------------------
if ($found) {
    $Global:MyOSDCloud.DriverPackName = $found.Name
    # Firmware/BIOS optional aktivieren
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true
    $Global:MyOSDCloud.HPIAALL      = $true
} else {
    Write-Warning '>> Endgültig kein HP-DriverPack gefunden! <<'
}


# --- Deployment ausfÃ¼hren ---------------------------------------------
Invoke-OSDCloud

# --- SpÃ¤tphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
