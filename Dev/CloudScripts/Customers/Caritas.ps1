# Caritas.ps1 – Online-Config, OS offline vom USB, Index fix = 1 (PS 5.1 kompatibel)

# Modul sicher laden (WinPE hat OSD bereits, Force schadet nicht)
Import-Module OSD -Force

# 1) WIM auf dem Stick finden (D:–Z:, \OSDCloud\OS\)
$wim = $null
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $p = Join-Path $_.Name 'OSDCloud\OS\Win11_24H2_MUI.wim'
    if (Test-Path $p) { $wim = Get-Item $p }
}
if (-not $wim) {
    Write-Error "Win11_24H2_MUI.wim nicht gefunden unter *:\OSDCloud\OS\"
    pause
    exit 1
}

# 2) Globales OSDCloud-Hashtable PS 5.1-konform vorbereiten (kein '??')
if (-not (Get-Variable -Name OSDCloud -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name OSDCloud -Scope Global -Value @{}
}
if ($Global:OSDCloud -isnot [hashtable]) { $Global:OSDCloud = @{} }

# 3) Offline-Image & feste Auswahl setzen
#    Diese Werte werden von Start-/Invoke-OSDCloud ausgewertet.
$Global:OSDCloud.ImageFileOffline = $wim.FullName   # lokales WIM erzwingen
$Global:OSDCloud.ImageIndex       = 1               # fix: Index 1 (WinPro)
$Global:OSDCloud.OSLanguage       = 'de-de'

# Optional strikt offline bleiben:
# $Global:OSDCloud.DriverPackName = 'None'
# $Global:OSDCloud.EnableSpecializeDriverPack = $false

# 4) Start (Frontend), ruft intern Invoke-OSDCloud mit obigen Variablen
Start-OSDCloud -ZTI -Restart
