# Caritas.ps1 – Online-Config, OS offline vom USB, Index fix = 1
Import-Module OSD -Force

# WIM vom USB finden (D:–Z:, \OSDCloud\OS\)
$wim = Get-PSDrive -PSProvider FileSystem |
  ForEach-Object { Get-Item "$($_.Name):\OSDCloud\OS\Win11_24H2_MUI.wim" -ErrorAction SilentlyContinue } |
  Select-Object -First 1

if (-not $wim) {
  Write-Error "Win11_24H2_MUI.wim nicht gefunden unter *:\OSDCloud\OS\"
  pause
  exit 1
}

# Variablen fuer OSDCloud setzen (Frontend uebergibt sie an Invoke-OSDCloud)
$Global:OSDCloud = $Global:OSDCloud ?? @{}
$Global:OSDCloud.ImageFileItem = $wim              # lokales WIM
$Global:OSDCloud.ImageIndex    = 1                 # fix auf Index 1
$Global:OSDCloud.OSLanguage    = 'de-de'

# Optional: strikt offline bleiben
# $Global:OSDCloud.DriverPackName = 'None'
# $Global:OSDCloud.EnableSpecializeDriverPack = $false

# Start (Frontend), ruft intern Invoke-OSDCloud mit obigen Variablen
Start-OSDCloud -ZTI -Restart
