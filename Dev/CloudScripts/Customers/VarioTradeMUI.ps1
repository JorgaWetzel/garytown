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
$DeployShare = '\\192.168.2.15\DeploymentShare$'
$MapDrive    = 'Z'
$UserName    = 'VARIODEPLOY\Administrator'
$PlainPwd    = '12Monate'

if (-not (Get-PSDrive -Name $MapDrive -ErrorAction SilentlyContinue)) {
    $Cred = [pscredential]::new(
        $UserName,
        (ConvertTo-SecureString $PlainPwd -AsPlainText -Force)
    )
    New-PSDrive -Name $MapDrive -PSProvider FileSystem -Root $DeployShare `
                -Credential $Cred -ErrorAction Stop
}

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
