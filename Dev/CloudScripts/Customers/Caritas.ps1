# Caritas.ps1 – OS offline vom USB (hart: D:\OSDCloud\OS\Win11_24H2_MUI.wim), Index 1
# HP-DriverPacks sind erwuenscht -> keine "None"-Flags setzen

Import-Module OSD -Force

$WimPath = 'D:\OSDCloud\OS\Win11_24H2_MUI.wim'
if (-not (Test-Path $WimPath)) {
    Write-Error "WIM nicht gefunden: $WimPath"
    Write-Host  "Bitte pruefen: Ist der Stick als D:\ gemountet? Liegt das WIM unter \OSDCloud\OS\ ?"
    pause
    exit 1
}

# Optional: sicherstellen, dass der Hersteller erkannt wird (fuer HP-DriverPacks)
# (OSDCloud erkennt das normalerweise automatisch und zieht HP-Packs online)
try { $null = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { }

# **Deterministischer Start ueber die Engine:**
# -> Explizites ImageFile + Index 1 erzwingen; so gibt es keinen OS-Download.
Invoke-OSDCloud `
    -ImageFile  $WimPath `
    -ImageIndex 1 `
    -OSLanguage 'de-de' `
    -Restart
