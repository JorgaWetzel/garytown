<#
    VarioTradeMUI.ps1
    • WinPE-Skript für Zero-Touch-Deployment via OSDCloud
    • Kopiert WIM vom MDT-Share, injiziert HP-DriverPack, aktiviert optionale HP-Tools
#>

# -----------------------------------------------------------
# 0)   BASIS-PARAMETER – HIER ANPASSEN
# -----------------------------------------------------------
$SharePath = '\\10.10.100.100\Daten'          # MDT-Freigabe
$MountDrive = 'Z'                             # Laufwerksbuchstabe
$UserName   = 'VARIODEPLOY\Administrator'
$PlainPwd   = '12Monate'

$WimName    = 'Win11_24H2_MUI.wim'
$OSVersion  = 'Windows 11'                    # ValidateSet: "Windows 11" / "Windows 10"
$OSReleaseID= '24H2'
$ImageIndex = 5                               # gewünschten Index eintragen

# -----------------------------------------------------------
# 1)   SHARE MOUNTEN
# -----------------------------------------------------------
if (-not (Get-PSDrive -Name $MountDrive -EA SilentlyContinue)) {
    $Secure = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
    $Cred   = [pscredential]::new($UserName,$Secure)

    New-PSDrive -Name $MountDrive -PSProvider FileSystem -Root $SharePath `
                -Credential $Cred -EA Stop

    Write-Host "Share gemappt: $($MountDrive): $SharePath" -ForegroundColor Cyan 
}

# -----------------------------------------------------------
# 2)   WIM KOPIEREN
# -----------------------------------------------------------
$SrcWim  = Join-Path ("$MountDrive:`\") "OSDCloud\OS\$WimName"    # Passe Pfad an, falls WIM im Root liegt
$DestDir = 'C:\OSDCloud\OS'

if (-not (Test-Path $SrcWim)) { throw "WIM $WimName nicht auf $SharePath gefunden." }
if (-not (Test-Path $DestDir)) { New-Item -ItemType Directory -Path $DestDir | Out-Null }

robocopy (Split-Path $SrcWim) $DestDir $WimName /njh /njs /xo /r:0 /w:0 | Out-Null

# -----------------------------------------------------------
# 3)   OSDCLOUD-HASH FÜLLEN
# -----------------------------------------------------------
$WimFull = Join-Path $DestDir $WimName
$Global:MyOSDCloud = @{
    ImageFileFullName = $WimFull
    ImageFileItem     = Get-Item $WimFull
    ImageFileName     = $WimName
    OSImageIndex      = $ImageIndex
    ClearDiskConfirm  = $false
    ZTI               = $true
}

# -----------------------------------------------------------
# 4)   HP-DRIVERPACK & FIRMWARE (optional)
# -----------------------------------------------------------
if ((Get-CimInstance Win32_ComputerSystem).Manufacturer -match 'HP') {

    # DriverPack
    $Product = (Get-CimInstance Win32_ComputerSystemProduct).Version
    $DP = Get-OSDCloudDriverPack -Product $Product `
          -OSVersion $OSVersion -OSReleaseID $OSReleaseID
    if ($DP) { $Global:MyOSDCloud.DriverPackName = $DP.Name }

    # Firmware-Optionen
    $Global:MyOSDCloud.HPTPMUpdate  = $true    # TPM-FW flashen
    $Global:MyOSDCloud.HPBIOSUpdate = $true    # BIOS flashen
    $Global:MyOSDCloud.HPIAALL      = $true    # HPIA voll
}

# -----------------------------------------------------------
# 5)   DEPLOYMENT STARTEN
# -----------------------------------------------------------
Invoke-OSDCloud                # führt Partitionierung + Apply WIM aus

# -----------------------------------------------------------
# 6)   SPÄTPHASE & NEUSTART
# -----------------------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
