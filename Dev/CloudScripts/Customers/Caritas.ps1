$ScriptName = 'Caritas.ps1'
$ScriptVersion = '12.09.2025'
Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

function Ensure-TSEnv {
    # Statt: if ($global:TSEnv) { return }
    if (Get-Variable -Name TSEnv -Scope Global -ErrorAction SilentlyContinue) { return }

    try {
        $global:TSEnv = New-Object -ComObject Microsoft.SMS.TSEnvironment
        return
    } catch {}

    Add-Type -Language CSharp @"
using System;
public class FakeTSEnv {
  public string Value(string name) { return Environment.GetEnvironmentVariable(name); }
  public void Value(string name, string value) { Environment.SetEnvironmentVariable(name, value); }
}
"@
    $global:TSEnv = New-Object FakeTSEnv

    if (-not $env:_SMSTSLogPath) { $env:_SMSTSLogPath = "X:\Windows\Temp" }
    if (-not $env:SMSTSLogPath)  { $env:SMSTSLogPath  = "X:\Windows\Temp" }
}

# BIOS/TPM Update und Settings für HP


# Optionale BIOS-/TPM-Updates beibehalten
Ensure-TSEnv

# Dein Block bleibt aktiv – jetzt ohne Fehler:
if (Test-HPIASupport){
    $Global:MyOSDCloud.HPTPMUpdate  = $true
    $Global:MyOSDCloud.HPBIOSUpdate = $true
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

#write variables to console
Write-Output $Global:MyOSDCloud


$Global:MyOSDCloud.BitLockerEnable = $true
$Global:MyOSDCloud.UpdateOS      = $false
$Global:MyOSDCloud.UpdateDrivers = $false

Import-Module OSD -Force
$wim = 'D:\OSDCloud\OS\Win11_24H2_MUI.wim'

$Global:MyOSDCloud = @{
  ImageFileFullName = $wim
  ImageFileItem     = Get-Item $wim
  ImageFileName     = [IO.Path]::GetFileName($wim)
  OSImageIndex      = 1
  ZTI               = $true
  ClearDiskConfirm  = $false
  UpdateOS          = $false
  UpdateDrivers     = $false
}

Invoke-OSDCloud

#write variables to console
Write-Output $Global:MyOSDCloud

#================================================
#  [PostOS] AutopilotOOBE Configuration Staging
#================================================
Write-Host -ForegroundColor Green "Define Computername:"
$Serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
$TargetComputername = $Serial.Substring(4,8)

$AssignedComputerName = "CAR-$TargetComputername"
Write-Host -ForegroundColor Red $AssignedComputerName
Write-Host ""


#================================================
#  [PostOS] OOBE CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Set-KeyboardLanguage.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\keyboard.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Install-EmbeddedProductKey.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\productkey.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/PostActionTaskCaritas.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionTask.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/SetupComplete.ps1 | Out-File -FilePath 'C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1' -Encoding ascii -Force


$OOBECMD = @'
@echo off
REM Planen der Ausführung der Skripte nach dem nächsten Neustart
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\keyboard.ps1
exit
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  [PostOS] SetupComplete CMD Command Line OSDCloud
#================================================

$osdCloudDir = 'C:\OSDCloud\Scripts\SetupComplete'
# Create the OOBE CMD command line
$OOBECMD = @'
@echo off
# CALL %Windir%\Setup\Scripts\DeCompile.exe
# DEL /F /Q %Windir%\Setup\Scripts\DeCompile.exe >nul
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\productkey.ps1
# start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\keyboard.ps1
# start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\autopilotprereq.ps1
# start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\autopilotoobe.ps1
CALL powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\PostActionTask.ps1
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1
exit 
'@

$OOBECMD | Out-File -FilePath "$osdCloudDir\SetupComplete.cmd" -Encoding ascii -Force

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
