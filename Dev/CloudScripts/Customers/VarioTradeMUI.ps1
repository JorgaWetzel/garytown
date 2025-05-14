<#
    99-Deployment.ps1 – StartNet-Hook (WinPE)
    =====================================================
    • Installiert ein Multi-Lang-Image mit OSDCloud
    • Erzwingt danach Audit-Mode
    • Legt oobe.cmd an, um in Audit alles zu tun
    =====================================================
#>

Import-Module OSD -Force

# -------------------------------------------------------------------
# 1.  Netzshare einbinden (bleibt wie bei dir)
# -------------------------------------------------------------------
$DeployShare = '\\10.10.100.100\Daten'
$MapDrive    = 'Z'
$UserName    = 'Jorga'
$PlainPwd    = 'Dont4getme'

# ---------- Netzwerk initialisieren (WinPE braucht das manchmal) ----
wpeutil InitializeNetwork              # stellt sicher, dass die NICs geladen sind

function New-PSDriveRetry {
    param(
        [string]       $Name,
        [string]       $Path,
        [pscredential] $Credential,
        [int]          $Retries      = 5,   # max. Versuche
        [int]          $DelaySeconds = 5    # Pause zwischen den Versuchen
    )
    for ($i = 1; $i -le $Retries; $i++) {
        try {
            if (-not (Get-PSDrive -Name $Name -ErrorAction SilentlyContinue)) {
                New-PSDrive -Name $Name `
                            -PSProvider FileSystem `
                            -Root $Path `
                            -Credential $Credential `
                            -ErrorAction Stop | Out-Null
            }
            Write-Host "[$i/$Retries] Netzlaufwerk $Name: erfolgreich gemappt." -fg Green
            return $true                         # fertig
        }
        catch {
            Write-Warning "[$i/$Retries] Mapping fehlgeschlagen: $_"
            if ($i -lt $Retries) { Start-Sleep -Seconds $DelaySeconds }
        }
    }
    throw "Mapping von $Path nach $Name: nach $Retries Versuchen aufgegeben."
}

# ---------- Share verbinden  ----------------------------------------
$Cred = [pscredential]::new(
        $UserName,
        (ConvertTo-SecureString $PlainPwd -AsPlainText -Force)
)

New-PSDriveRetry -Name $MapDrive `
                 -Path $DeployShare `
                 -Credential $Cred `
                 -Retries 5 `
                 -DelaySeconds 5

# -------------------------------------------------------------------
# 2.  OSDCloud-Konfiguration                       *** WICHTIG ***
# -------------------------------------------------------------------
# →  OSImageIndex NICHT mehr fest auf Deutsch stellen!
# →  Nimm den Index, der als Basis EN-US (oder neutral) enthält
# →  oder lass ihn weg und OSDCloud wählt interaktiv.
$SrcWim = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'

$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5           
    ClearDiskConfirm  = $false
    ZTI               = $true
    Firmware          = $false
    UpdateOS          = $false
    UpdateDrivers     = $false
}

# -------------------------------------------------------------------
# 3.  Windows installieren
# -------------------------------------------------------------------
Invoke-OSDCloud          # formatiert, wendet WIM Index 1 an, kopiert Boot-Files

# -------------------------------------------------------------------
# 4.  Offline-Windows-Laufwerk ermitteln
#     (OSDCloud nennt es meist "$env:OSDCloudOSDrive")
# -------------------------------------------------------------------
$OSDrive = $env:OSDCloudOSDrive
if (-not $OSDrive) {  $OSDrive = 'C:' }   # Fallback – meist korrekt

# -------------------------------------------------------------------
# 5.  Audit-Mode-Unattend erst JETZT ablegen, damit sie die frische
#     Installation erreicht (Set-OSDCloudUnattendAuditMode schreibt
#     standardmäßig in <Windows>\Panther)
# -------------------------------------------------------------------
Set-OSDCloudUnattendAuditMode -WindowsDirectory "$OSDrive\Windows"

# -------------------------------------------------------------------
# 6.  oobe.cmd anlegen (wird in Audit ausgeführt)
# -------------------------------------------------------------------
$oobe = @'
@echo off
REM ========= HP Treiber & Firmware im Audit-Mode =========

REM PowerShell einmal ohne Profil starten
powershell.exe -NoLogo -ExecutionPolicy Bypass -Command ^
    "Install-Module HP.ClientManagement -Force -Scope AllUsers"

powershell.exe -NoLogo -ExecutionPolicy Bypass -Command ^
    "Import-Module HP.ClientManagement; `n` +
     New-HPDriverPack -Os Win11 -OSVer 24H2 -Path C:\Drivers"

powershell.exe -NoLogo -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath C:\Drivers\Install.cmd -Wait"

powershell.exe -NoLogo -ExecutionPolicy Bypass -Command ^
    "Get-HPBIOSUpdates -Flash -BitLocker Ignore -Force"

REM ========= System wieder versiegeln =========
%WINDIR%\System32\Sysprep\Sysprep.exe /generalize /oobe /shutdown
'@

$dest = "$OSDrive\Windows\Setup\Scripts"
New-Item -ItemType Directory -Path $dest -Force | Out-Null
$oobe | Set-Content -Path (Join-Path $dest 'oobe.cmd') -Encoding ASCII

# -------------------------------------------------------------------
# 7.  Neustart – danach läuft Audit-Mode & dein oobe.cmd
# -------------------------------------------------------------------
Restart-Computer -Force
