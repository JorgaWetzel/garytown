$ScriptName = 'Caritas.ps1'
$ScriptVersion = '12.09.2025'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

# BIOS/TPM Update und Settings für HP
if (Get-Command Test-HPIASupport -ErrorAction SilentlyContinue) {
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true

    # Script von Garytown laden (enthält Manage-HPBiosSettings)
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)

    # Settings anwenden
    Manage-HPBiosSettings -SetSettings
}

Import-Module OSD -Force
$wim = 'D:\OSDCloud\OS\Win11_24H2_MUI.wim'

$Global:MyOSDCloud = @{
  ImageFileFullName = $wim
  ImageFileItem     = Get-Item $wim
  ImageFileName     = [IO.Path]::GetFileName($wim)
  OSImageIndex      = 1
  ZTI               = $true
  ClearDiskConfirm  = $false
  UpdateOS          = $false
  UpdateDrivers     = $false
}

Invoke-OSDCloud
