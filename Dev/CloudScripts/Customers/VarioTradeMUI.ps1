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


# =====================================================================
# HP-DriverPack  Universeller Fallback-Algorithmus (reine Console)
# =====================================================================
# ---------- 1) m�gliche IDs sammeln ---------------------------
$ids = @(
    (Get-CimInstance Win32_ComputerSystemProduct).Version,
    (Get-CimInstance Win32_ComputerSystem).SystemSKUNumber,
    (Get-CimInstance Win32_BaseBoard).Product
) | Where-Object { $_ } | Select-Object -Unique

Write-Host "Pr�fe IDs: $($ids -join ', ')" -ForegroundColor Cyan

# ---------- 2) Fallback-Schleife ------------------------------
$osVers  = 'Windows 11','Windows 10'
$relVers = '24H2','23H2','22H2','21H2'
$found   = $null

foreach ($id in $ids) {
    foreach ($os in $osVers) {
        foreach ($rel in $relVers) {
            $dp = Get-OSDCloudDriverPack -Product $id `
                     -OSVersion $os -OSReleaseID $rel `
                     -EA SilentlyContinue
            if ($dp) {
                $found = $dp
                Write-Host ("Treffer: {0}  |  ID={1}  |  {2}  {3}" -f $dp.Name,$id,$os,$rel) -fg Green
                break 3      # aus allen Schleifen aussteigen
            } else {
                Write-Host ("kein Pack  ID={0}  {1} {2}" -f $id,$os,$rel) -fg DarkGray
            }
        }
    }
}

if ($found) {
    $Global:MyOSDCloud.DriverPackName = $found.Name
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true
    $Global:MyOSDCloud.HPIAALL      = $true
} else {
    Write-Warning '>> Endg�ltig kein HP-DriverPack gefunden! <<'
}

# --- Deployment ausführen ---------------------------------------------
Invoke-OSDCloud

# --- Spätphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
