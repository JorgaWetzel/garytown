$ScriptName = 'oneICT.ps1'
$ScriptVersion = '02.10.2024'
iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

<#
Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
Install-Module OSD -Force

Write-Host  -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force   
#>

#=======================================================================
#   [OS] Params and Start-OSDCloud
#=======================================================================
#Used to Determine Driver Pack
$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "24H2"
    OSEdition = "Pro"
    OSLanguage = "de-DE"
    OSLicense = "Retail"
    ZTI = $true
    Firmware = $false
}
# Start-OSDCloud @Params

$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 24H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'de-de'
$OSImageIndex =  '8'

# Full List https://github.com/OSDeploy/OSD/blob/06d544f0bff26b560e19676582d273e1c229cfac/Public/OSDCloud.ps1#L521
#Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$False
    WindowsDefenderUpdate = [bool]$False
    SetTimeZone = [bool]$False
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$False
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
}

# Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage
# Start-OSDCloudGUI
# Start-OSDCloudGUIDev


# --------   HP-Spezifisches vorbereiten --------------------
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '24H2'     #Used to Determine Driver Pack
$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

# ---------------- Driver package first, HPIA as fallback --------------------
if ($DriverPack){
    Write-Host -ForegroundColor Cyan "Driver pack located – applying driver pack only."
    $Global:MyOSDCloud.DriverPackName      = $DriverPack.Name
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true   # Driver-Pack aktiv
    $Global:MyOSDCloud.HPIAALL             = [bool]$false     # HPIA deaktivieren
	if ($Product -ne '83B2' -or $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
    if ($Product -ne '895E' -or $Model -notmatch "z2mini"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
	
}
else{
    Write-Host -ForegroundColor Yellow "No driver pack found – falling back to HPIA."
    if (Test-HPIASupport){ $Global:MyOSDCloud.HPIAALL = [bool]$true }
}

# Optionale BIOS-/TPM-Updates beibehalten
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

#================================================
#  [PostOS] AutopilotOOBE Configuration Staging
#================================================
Write-Host -ForegroundColor Green "Define Computername:"
$Serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
$TargetComputername = $Serial.Substring(4,8)

$AssignedComputerName = "PC-$TargetComputername"
Write-Host -ForegroundColor Red $AssignedComputerName
Write-Host ""

Write-Host -ForegroundColor Green "Create C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json"
$AutopilotOOBEJson = @"
{
    "AssignedComputerName" : "$AssignedComputerName",
    "AddToGroup":  "DEV-WIN-Standard",
    "Assign":  {
                   "IsPresent":  true
               },
    "GroupTag":  "DEV-WIN-Standard",
    "Hidden":  [
                   "AddToGroup",
                   "AssignedUser",
                   "PostAction",
                   "GroupTag",
                   "Assign"
               ],
    "PostAction":  "Quit",
    "Run":  "NetworkingWireless",
    "Docs":  "https://oneict.ch/",
    "Title":  "oneICT Autopilot Registrierung"
}
"@

If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$AutopilotOOBEJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json" -Encoding ascii -Force

#================================================
#  [PostOS] OOBE CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Set-KeyboardLanguage.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\keyboard.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Install-EmbeddedProductKey.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\productkey.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/PostActionTaskBuechweidVerwaltung.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionTask.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/SetupComplete.ps1 | Out-File -FilePath 'C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1' -Encoding ascii -Force
# Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/PostActionUser.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionUser.ps1' -Encoding ascii -Force

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
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\productkey.ps1
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1 
call powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\PostActionTask.ps1
exit 
'@

$OOBECMD | Out-File -FilePath "$osdCloudDir\SetupComplete.cmd" -Encoding ascii -Force


#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot
