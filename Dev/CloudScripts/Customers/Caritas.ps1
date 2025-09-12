# Caritas.ps1 – Online-Config, OS offline vom USB (fest: D:\), Index 1, HP-DriverPacks erlaubt
Import-Module OSD -Force

# 1) Fester Pfad auf D:\
$WimPath = 'D:\OSDCloud\OS\Win11_24H2_MUI.wim'
if (-not (Test-Path $WimPath)) {
    Write-Error "Win11_24H2_MUI.wim nicht gefunden: $WimPath"
    Write-Host "Kontrolliere, ob der Stick als D:\ gemountet ist und die Datei unter \OSDCloud\OS\ liegt."
    pause
    exit 1
}

# 2) Globales OSDCloud-Hashtable initialisieren (PS 5.1 – kein ??)
if (-not (Get-Variable -Name OSDCloud -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name OSDCloud -Scope Global -Value @{}
}
if ($Global:OSDCloud -isnot [hashtable]) { $Global:OSDCloud = @{} }

# 3) Offline-Image + Index fest vorgeben
$Global:OSDCloud.ImageFileOffline = $WimPath   # <- lokales WIM von D:\
$Global:OSDCloud.ImageIndex       = 1          # <- WinPro auf Index 1
$Global:OSDCloud.OSLanguage       = 'de-de'

# WICHTIG: Keine "None"-Flags setzen -> HP-DriverPacks bleiben aktiv (online)
# (also NICHT DriverPackName='None' und NICHT EnableSpecializeDriverPack=$false)

# 4) Start (ruft intern Invoke-OSDCloud); ZTI + Reboot
Start-OSDCloud -ZTI -Restart
