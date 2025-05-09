# 99-Deployment.ps1  –  StartNet-Hook, minimal

Import-Module OSD -Force

# ======================================================================
# Konfiguration – HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
$DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z'                              # gewünschter Laufwerks­buchstabe
$UserName    = 'Jorga'                          # Domänen- oder lokaler User
$PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)

# $DeployShare = '\\192.168.2.15\DeploymentShare$'     # UNC-Pfad zum Deployment-Share
# $MapDrive    = 'Z'                               # gewünschter Laufwerks­buchstabe
# $UserName    = 'VARIODEPLOY\Administrator'       # Domänen- oder lokaler User
# $PlainPwd    = '12Monate'                        # Passwort (Klartext)

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


# --- WIM kopieren ------------------------------------------------------
#$WimName = 'Win11_24H2_MUI.wim'
#$SrcWim  = "Z:\OSDCloud\OS\$WimName"
#$DestDir = 'C:\OSDCloud\OS'

#if (-not (Test-Path $SrcWim)) { throw "WIM $WimName nicht auf $share gefunden." }
#if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir | Out-Null }

#robocopy (Split-Path $SrcWim) $DestDir $WimName /njh /njs /xo /r:0 /w:0 | Out-Null


# Quelle direkt auf Z:\ zeigen
$SrcWim = "Z:\OSDCloud\OS\Win11_24H2_MUI.wim"

# --- OSDCloud-Variablen setzen ----------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $WimName
    ImageFileName     = $WimName
    OSImageIndex      = 5     # ggf. anpassen
    ClearDiskConfirm  = $false
    ZTI               = $true
}

# --- Deployment ausführen ---------------------------------------------
Invoke-OSDCloud

# --- Spätphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
