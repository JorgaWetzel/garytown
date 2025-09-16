# ---------------- GUI + Fallback (ohne Funktionen, PS 5.1) ----------------

try { Import-Module OSD -Force -ErrorAction Stop } catch { Write-Host -ForegroundColor Yellow "OSD Modul: $($_.Exception.Message)" }

$TemplateName      = 'Win11MUI'
$PreferredWimName  = ''   # optional: z.B. 'Win11_24H2_MUI.wim'

# USB-Root finden: nehme Laufwerke mit \OSDCloud\OS, bevorzuge Wechseldatentraeger
$removable = @(Get-WmiObject Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 } | Select-Object -Expand DeviceID)
$usbRoot = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $r = $_.Root.TrimEnd('\')
    if (Test-Path (Join-Path $r 'OSDCloud\OS')) { $r }
} | Sort-Object { if ($removable -contains $_) { 0 } else { 1 } } | Select-Object -First 1

if (-not $usbRoot) { throw "Kein Laufwerk mit 'OSDCloud\OS' gefunden." }
Write-Host -ForegroundColor Cyan "OSD USB Root: $usbRoot"

# 1) Erst GUI probieren
try {
    Start-OSDCloudGUI -OSDSources USB -Template $TemplateName
    Write-Host -ForegroundColor Yellow "GUI beendet. Fallback wird genutzt, falls nichts ausgefuehrt wurde."
} catch {
    Write-Host -ForegroundColor Yellow "GUI konnte nicht starten: $($_.Exception.Message)"
}

# 2) Fallback: lokale WIM suchen und direkt installieren
$osPath = Join-Path $usbRoot 'OSDCloud\OS'
$wims = Get-ChildItem -Path $osPath -Filter *.wim -File -Recurse -ErrorAction SilentlyContinue
if (-not $wims -or $wims.Count -eq 0) { throw "Keine *.wim unter $osPath gefunden." }

$wim = if ($PreferredWimName) { $wims | Where-Object { $_.Name -ieq $PreferredWimName } | Select-Object -First 1 } else { $null }
if (-not $wim) { $wim = $wims | Select-Object -First 1 }

try {
    $imgs = Get-WindowsImage -ImagePath $wim.FullName -ErrorAction Stop
    $img  = $imgs | Where-Object { $_.ImageIndex -eq 1 } | Select-Object -First 1
    if (-not $img) { $img = $imgs | Select-Object -First 1 }
} catch { $img = $null }

if (-not $img) { throw "Konnte keine Image-Infos aus $($wim.FullName) lesen." }

Write-Host -ForegroundColor Green "Nutze WIM: $($wim.Name) | Index: $($img.ImageIndex) | Name: $($img.ImageName)"

$Global:MyOSDCloud = @{
    ImageFileFullName = $wim.FullName
    ImageFileItem     = Get-Item $wim.FullName
    ImageFileName     = [IO.Path]::GetFileName($wim.FullName)
    OSImageIndex      = [int]$img.ImageIndex
    ZTI               = $true
    ClearDiskConfirm  = $false
    UpdateOS          = $false
    UpdateDrivers     = $false
    SetInputLocale    = '0807:00000807'
    Language          = 'de-de'
    SetAllIntl        = 'de-de'
}

Invoke-OSDCloud
Write-Output $Global:MyOSDCloud

# ---------------- Ende GUI + Fallback --------------------------------------
