# Caritas.ps1 – PS 5.1, OS vom USB (D:\), Index 1, HP-DriverPacks erlaubt

Import-Module OSD -Force
Write-Host "[Caritas] Loaded OK – using local WIM on D:" -ForegroundColor Cyan

$WimPath = 'D:\OSDCloud\OS\Win11_24H2_MUI.wim'
if (-not (Test-Path $WimPath)) {
    Write-Error "[Caritas] WIM nicht gefunden: $WimPath"
    Write-Host  "Ist der Stick als D:\ gemountet? Liegt das WIM unter \OSDCloud\OS\ ?"
    pause
    exit 1
}

# >>> Hier DEINE Online-Konfigs (Registry, ODT, Autopilot, Branding, etc.) <<<
# Wichtig: KEIN Start-OSDCloud an dieser Stelle!

# Zwingend lokal installieren – kein Download möglich, weil -ImageFile gesetzt.
Invoke-OSDCloud `
    -ImageFile  $WimPath `
    -ImageIndex 1 `
    -OSLanguage 'de-de' `
    -Restart
