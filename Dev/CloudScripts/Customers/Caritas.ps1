# Caritas.ps1 (PowerShell 5.1–kompatibel) - GUI + Fallback auf lokale MUI-WIM
# Version: 2025-09-16

# ----------------------------
# Helper-Funktionen (müssen VOR dem Aufruf stehen)
# ----------------------------

function Get-OsdUsbRoot {
    try {
        $candidates = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
            $root = Join-Path $_.Root 'OSDCloud\OS'
            if (Test-Path $root) { $_.Root.TrimEnd('\') }
        }

        # Bevorzuge Wechseldatenträger
        $removable = @(Get-WmiObject Win32_LogicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DriveType -eq 2 } | Select-Object -Expand DeviceID)
        $pick = $candidates | Sort-Object { if ($removable -contains $_) { 0 } else { 1 } } | Select-Object -First 1
        if (-not $pick) { throw "Kein Laufwerk mit 'OSDCloud\\OS' gefunden." }
        return $pick
    } catch {
        throw $_
    }
}

function Get-LocalWims {
    param([Parameter(Mandatory=$true)][string]$UsbRoot)
    $osPath = Join-Path $UsbRoot 'OSDCloud\OS'
    Get-ChildItem -Path $osPath -Filter *.wim -File -Recurse -ErrorAction SilentlyContinue
}

function Get-FirstValidIndex {
    param([Parameter(Mandatory=$true)][string]$WimPath)
    try {
        $imgs = Get-WindowsImage -ImagePath $WimPath -ErrorAction Stop
        $img = $imgs | Where-Object { $_.ImageIndex -eq 1 } | Select-Object -First 1
        if (-not $img) { $img = $imgs | Select-Object -First 1 }
        return $img
    } catch {
        return $null
    }
}

# ----------------------------
# Start: Import Modul / Basiskonfig
# ----------------------------
try { Import-Module OSD -Force -ErrorAction Stop } catch { Write-Host -ForegroundColor Yellow "OSD-Modul nicht vorab importiert: $($_.Exception.Message)" }

# Für Logging
$Host.UI.RawUI.WindowTitle = "Caritas OSDCloud (PS 5.1 kompatibel)"

# Lokale Einstellungen wie im Template
$TemplateName = 'Win11MUI'
$InputLocale  = '0807:00000807'
$Language     = 'de-de'
$AllIntl      = 'de-de'

# ----------------------------
# GUI-Start + Fallback
# ----------------------------
try {
    $usbRoot = Get-OsdUsbRoot
    Write-Host -ForegroundColor Cyan "OSD USB Root: $usbRoot"

    # 1) GUI versuchen – listet Images aus USB, wenn sie unter \OSDCloud\OS liegen.
    Write-Host -ForegroundColor Green "Starte OSDCloudGUI (Quelle: USB, Template: $TemplateName)"
    try {
        Start-OSDCloudGUI -OSDSources USB -Template $TemplateName
        Write-Host -ForegroundColor Yellow "GUI beendet. Falls keine Installation erfolgte, Fallback aktiv."
    } catch {
        Write-Host -ForegroundColor Yellow "GUI konnte nicht gestartet werden: $($_.Exception.Message). Fallback wird genutzt."
    }

    # 2) Fallback: Lokale WIM(s) suchen und direkt installieren
    $wims = Get-LocalWims -UsbRoot $usbRoot
    if (-not $wims -or $wims.Count -eq 0) { throw "Keine *.wim unter $usbRoot\OSDCloud\OS gefunden." }

    # Optional: Konkrete Datei erzwingen (hier nur als Beispiel auskommentiert):
    # $wim = $wims | Where-Object { $_.Name -eq 'Win11_24H2_MUI.wim' } | Select-Object -First 1
    $wim = $wims | Select-Object -First 1

    $img = Get-FirstValidIndex -WimPath $wim.FullName
    if (-not $img) { throw "Konnte keine Image-Infos aus $($wim.FullName) lesen." }

    Write-Host -ForegroundColor Green "Nutze WIM: $($wim.Name) | Index: $($img.ImageIndex) | Name: $($img.ImageName)"

    # MyOSDCloud vorbereiten
    $Global:MyOSDCloud = @{
        ImageFileFullName = $wim.FullName
        ImageFileItem     = Get-Item $wim.FullName
        ImageFileName     = [IO.Path]::GetFileName($wim.FullName)
        OSImageIndex      = [int]$img.ImageIndex
        ZTI               = $true
        ClearDiskConfirm  = $false
        UpdateOS          = $false
        UpdateDrivers     = $false
        SetInputLocale    = $InputLocale
        Language          = $Language
        SetAllIntl        = $AllIntl
    }

    Invoke-OSDCloud
    Write-Output $Global:MyOSDCloud
}
catch {
    Write-Host -ForegroundColor Red "Fehler im GUI/Fallback-Flow: $($_.Exception.Message)"
    throw
}

# ----------------------------
# Nachgelagerte Schritte (Platzhalter) – hier kannst du OOBE/Autopilot etc. anhängen
# ----------------------------
# Write-Host -ForegroundColor Green "Post-Install Schritte hier ergänzen…"
