Import-Module OSD -Force

Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Green "PSCloudScript at functions.osdcloud.com"
Invoke-Expression (Invoke-RestMethod -Uri functions.osdcloud.com)

iex (irm functions.garytown.com)    # Custom Funktionen
iex (irm functions.osdcloud.com)    # OSDCloud Funktionen

# Transport Layer Security (TLS) 1.2 aktivieren
Write-Host -ForegroundColor Green "Transport Layer Security (TLS) 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# ================================================================
#   [PreOS] Auflösung setzen bei VM
# ================================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# ================================================================
#   Konfiguration – hier bei Bedarf anpassen
# ================================================================
$DeployShare = '\\10.10.100.100\Daten'
$MapDrive    = 'Z:'
$UserName    = 'Jorga'
$PlainPwd    = 'Dont4getme'
$SrcWim      = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'


# Share verbinden
if (-not (Test-Path -Path $MapDrive)) {
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

$FoundDriverPack = $DriverSearchPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($null -ne $FoundDriverPack) {
    Write-Host "Lokales DriverPack gefunden: $FoundDriverPack"
    $Global:MyOSDCloud.DriverPackName = $FoundDriverPack
}

else {
    Write-Host "Kein lokales DriverPack gefunden – versuche Download über Get-OSDCloudDriverPack..."
    $DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

    if ($DriverPack) {
        Write-Host "Treiberpaket gefunden: $($DriverPack.Name)"
        $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
        # Optional: Caching für zukünftige Deployments
        $TargetPath = "Z:\OSDCloud\DriverPacks\HP\$DriverPackName"
        Copy-Item $DriverPack.Name $TargetPath -Force
    }
    else {
        Write-Warning "Kein DriverPack gefunden – aktiviere HPIA als Fallback"
        if (Test-HPIASupport) {
            $Global:MyOSDCloud.HPIAALL = $true
            $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true
        }
    }
}
# ================================================================
#   Optional: HPIA für BIOS / TPM / Settings (wenn unterstützt)
# ================================================================
$Model = Get-MyComputerModel
if (Test-HPIASupport) {
    $Global:MyOSDCloud.HPTPMUpdate = $true
    if ($Product -ne '83B2' -or $Model -notmatch "zbook") {
        $Global:MyOSDCloud.HPIAALL = $true
    }
    $Global:MyOSDCloud.HPBIOSUpdate = $true

    # BIOS Settings via Script setzen
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

# ================================================================
#   Deployment starten
# ================================================================
Write-Output $Global:MyOSDCloud
Invoke-OSDCloud

# Optional: Unattend Audit Mode oder Startnet Update
# Set-OSDCloudUnattendAuditMode
# Initialize-OSDCloudStartnetUpdate

Restart-Computer -Force
