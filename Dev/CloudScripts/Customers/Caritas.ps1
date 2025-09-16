# --- NEU: kleine Hilfsfunktionen --------------------------------------------

function Get-OsdUsbRoot {
    # Finde Laufwerke, die \OSDCloud\OS enthalten (USB oder Festplatte)
    $candidates = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $root = Join-Path $_.Root 'OSDCloud\OS'
        if (Test-Path $root) { $_.Root.TrimEnd('\') }
    }
    # Bevorzuge Wechseldatentraeger
    $removable = Get-WmiObject Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 } | Select-Object -Expand DeviceID -ErrorAction SilentlyContinue
    $pick = $candidates | Sort-Object { if ($removable -contains $_) { 0 } else { 1 } } | Select-Object -First 1
    if (-not $pick) { throw "Kein OSDCloud\OS Ordner gefunden." }
    return $pick
}

function Get-LocalWims($usbRoot) {
    $osPath = Join-Path $usbRoot 'OSDCloud\OS'
    Get-ChildItem -Path $osPath -Filter *.wim -File -Recurse -ErrorAction SilentlyContinue
}

function Get-FirstValidIndex($wimPath) {
    try {
        $imgs = Get-WindowsImage -ImagePath $wimPath -ErrorAction Stop
        # Nimm Index 1, wenn vorhanden; sonst den ersten gueltigen
        ($imgs | Where-Object { $_.ImageIndex -eq 1 } | Select-Object -First 1) `
            ?? ($imgs | Select-Object -First 1)
    } catch {
        $null
    }
}

# --- DEIN BEREITS VORHANDENER CODE (gekürzt) --------------------------------
# Import-Module OSD -Force  # Falls noch nicht vorhanden, unten nochmal

# --- NEU: GUI-Modus mit Fallback --------------------------------------------
try {
    Import-Module OSD -Force

    $usbRoot = Get-OsdUsbRoot
    Write-Host -ForegroundColor Cyan "OSD USB Root: $usbRoot"

    # 1) Erstmal das GUI mit USB als Quelle starten
    #    Das GUI listet lokale WIMs, wenn sie unter \OSDCloud\OS liegen.
    #    Optional: Template vorgeben, damit Sprache/Locale gesetzt sind.
    $templateName = 'Win11MUI'  # du hast es mit New-OSDCloudTemplate erzeugt
    Write-Host -ForegroundColor Green "Starte OSDCloudGUI (Quelle: USB, Template: $templateName)"
    Start-OSDCloudGUI -OSDSources USB -Template $templateName

    # Wenn das GUI sauber laeuft, kommt es hier meist gar nicht mehr hin,
    # weil der Installationsfluss uebernimmt. Falls der Benutzer das GUI schliesst
    # oder die WIM nicht gelistet war, nutzen wir den Fallback unten.

    Write-Host -ForegroundColor Yellow "GUI wurde beendet oder hat nichts ausgefuehrt. Fallback auf direkte WIM-Installation."

    # 2) Fallback: lokale WIM(s) finden und direkt verwenden
    $wims = Get-LocalWims -usbRoot $usbRoot
    if (-not $wims) { throw "Keine WIM im Ordner $usbRoot\OSDCloud\OS gefunden." }

    # Falls du eine konkrete Datei willst, kannst du hier filtern:
    # $wim = $wims | Where-Object Name -eq 'Win11_24H2_MUI_de-de.wim' | Select-Object -First 1
    $wim = $wims | Select-Object -First 1

    $img = Get-FirstValidIndex -wimPath $wim.FullName
    if (-not $img) { throw "Konnte keine Image-Infos aus $($wim.FullName) lesen." }

    Write-Host -ForegroundColor Green "Nutze WIM: $($wim.Name) | Index: $($img.ImageIndex) | Name: $($img.ImageName)"

    # Globale MyOSDCloud-Map setzen wie in deinem Script
    $Global:MyOSDCloud = @{
        ImageFileFullName = $wim.FullName
        ImageFileItem     = Get-Item $wim.FullName
        ImageFileName     = [IO.Path]::GetFileName($wim.FullName)
        OSImageIndex      = [int]$img.ImageIndex
        ZTI               = $true          # Zero Touch, wenn du willst; fuer interaktive Schritte ggf. $false
        ClearDiskConfirm  = $false
        UpdateOS          = $false
        UpdateDrivers     = $false
    }

    # Sprache/Locale wie in deiner Template-Erstellung
    $Global:MyOSDCloud.SetInputLocale = '0807:00000807'
    $Global:MyOSDCloud.Language       = 'de-de'
    $Global:MyOSDCloud.SetAllIntl     = 'de-de'

    # Jetzt installieren
    Invoke-OSDCloud
    Write-Output $Global:MyOSDCloud
}
catch {
    Write-Host -ForegroundColor Red "Fehler im GUI/Fallback-Flow: $($_.Exception.Message)"
    throw
}
