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
