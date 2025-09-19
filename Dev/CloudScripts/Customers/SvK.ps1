$ScriptName = 'SvK.ps1'
$ScriptVersion = '19.09.2025'

Write-Host -ForegroundColor Green "$ScriptName $ScriptVersion"

if (-NOT (Test-Path 'X:\OSDCloud\Logs')) {
    New-Item -Path 'X:\OSDCloud\Logs' -ItemType Directory -Force -ErrorAction Stop | Out-Null
}

#Transport Layer Security (TLS) 1.2
Write-Host -ForegroundColor Green "Transport Layer Security (TLS) 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Start-OSDCloudLogic.log"
Start-Transcript -Path (Join-Path "X:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore | Out-Null

if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}


#================================================
Write-Host -ForegroundColor DarkGray "========================================================================="
Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Cyan "[PreOS] Update Module"
#================================================
# Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
# Install-Module OSD -Force

Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Green "Importing OSD PowerShell Module"
Import-Module OSD -Force

Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Green "PSCloudScript at functions.osdcloud.com"
Invoke-Expression (Invoke-RestMethod -Uri functions.osdcloud.com)

#region Helper Functions
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}
function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}
function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
}
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}
function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#endregion

#region PreOS Tasks
#=======================================================================
Write-SectionHeader "[PreOS] Define OSDCloud Global And Customer Parameters"
#=======================================================================
$Global:AutoPilot   = $null
$Global:AutoPilot   = [ordered]@{
    Development     = [bool]$true
    TestGroup       = [bool]$true
}
Write-SectionHeader "AutoPilot variables"
Write-Host ($Global:AutoPilot | Out-String)

$Global:MyOSDCloud = [ordered]@{
    MSCatalogFirmware   = [bool]$true
    HPBIOSUpdate        = [bool]$true
    #IsOnBattery        = [bool]$false
}
Write-SectionHeader "MyOSDCloud variables"
Write-Host ($Global:MyOSDCloud | Out-String)

if ($Global:OSDCloud.ApplyCatalogFirmware -eq $true) {
    #=======================================================================
    Write-SectionHeader "[PreOS] Prepare Firmware Tasks"
    #=======================================================================
    #Register-PSRepository -Default -Verbose
    osdcloud-TrustPSGallery -Verbose
    #Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -Verbose

    osdcloud-InstallPowerShellModule -Name 'MSCatalog'
    #Install-Module -Name MSCatalog -Force -Verbose -SkipPublisherCheck -AllowClobber -Repository PSGallery    
}

#endregion

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
    Firmware = $true
}
Start-OSDCloud @Params

#================================================
Write-SectionHeader "[PostOS] Define Autopilot Attributes"
#================================================
Write-DarkGrayHost "Define Computername"
$Serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
$lastFourChars = $serial.Substring($serial.Length - 4)
$AssignedComputerName = "SvK-2$lastFourChars"

# Device assignment
if ($Global:AutoPilot.TestGroup -eq $true){
    Write-DarkGrayHost "Adding device to DEV-Autopilot-Devices-Dynamic"
    $AddToGroup = "DEV-Intune Pilot Devices"

}
else {
    Write-DarkGrayHost "Adding device to DEV-Intune Pilot Devices"
    $AddToGroup = ""
}

Write-Host -ForegroundColor Yellow "Computername: $AssignedComputerName"
Write-Host -ForegroundColor Yellow "AddToGroup: $AddToGroup"

#================================================
Write-SectionHeader "[PostOS] AutopilotOOBE Configuration"
#================================================
Write-DarkGrayHost "Create C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json file"
$AutopilotOOBEJson = @"
{
        "AssignedComputerName" : "$AssignedComputerName",
        "AddToGroup":  "$AddToGroup",
        "Assign":  {
                    "IsPresent":  true
                },
        "GroupTag":  "$GroupTag",
        "Hidden":  [
                    "AddToGroup",
                    "AssignedUser",
                    "PostAction",
                    "GroupTag",
                    "Assign"
                ],
        "PostAction":  "Quit",
        "Run":  "NetworkingWireless",
        "Docs":  "https://google.ch/",
        "Title":  "Autopilot Manual Register"
    }
"@

If (!(Test-Path "C:\ProgramData\OSDeploy")) {
    New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
}
$AutopilotOOBEJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.AutopilotOOBE.json" -Encoding ascii -Force
#endregion

#region Specialize Tasks
#================================================
Write-SectionHeader "[PostOS] SetupComplete CMD Command Line"
#================================================
Write-DarkGrayHost "Cleanup SetupComplete Files from OSDCloud Module"
Get-ChildItem -Path 'C:\Windows\Setup\Scripts\SetupComplete*' -Recurse | Remove-Item -Force

#=================================================
Write-SectionHeader "[PostOS] Define Specialize Phase"
#=================================================
$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Start Autopilot Import & Assignment Process</Description>
                    <Path>PowerShell -ExecutionPolicy Bypass C:\Windows\Setup\scripts\autopilot.ps1</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <InputLocale>de-CH</InputLocale>
            <SystemLocale>de-DE</SystemLocale>
            <UILanguage>de-DE</UILanguage>
            <UserLocale>de-CH</UserLocale>
        </component>
    </settings>
</unattend>
'@ 
# Get-OSDGather -Property IsWinPE
Block-WinOS

if (-NOT (Test-Path 'C:\Windows\Panther')) {
    New-Item -Path 'C:\Windows\Panther'-ItemType Directory -Force -ErrorAction Stop | Out-Null
}

$Panther = 'C:\Windows\Panther'
$UnattendPath = "$Panther\Unattend.xml"
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force

Write-DarkGrayHost "Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath"
Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath | Out-Null
#endregion

#region OOBE Tasks
#================================================
Write-SectionHeader "[PostOS] OOBE CMD Command Line"
#================================================
Write-DarkGrayHost "Downloading Scripts for OOBE and specialize phase"

Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Customers/AutopilotSvK.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\autopilot.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/OOBE.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Start-AutopilotOOBE.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\start-autopilotoobe.ps1 ' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/CleanUp.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\cleanup.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Customers/PostActionTaskSvK.ps1  | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionTask.ps1' -Encoding ascii -Force

#Invoke-RestMethod http://osdgather.osdcloud.ch | Out-File -FilePath 'C:\Windows\Setup\scripts\osdgather.ps1' -Encoding ascii -Force

$OOBEcmdTasks = @'
@echo off

REM Wait for Network 10 seconds
REM ping 127.0.0.1 -n 10 -w 1  >NUL 2>&1

REM Execute OOBE Tasks
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\oobe.ps1

REM Execute OOBE Tasks
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\start-autopilotoobe.ps1

REM Execute Post Action Skript
CALL powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\PostActionTask.ps1

REM Execute Cleanup Script
start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\cleanup.ps1

REM Below a PS session for debug and testing in system context, # when not needed 
REM start /wait powershell.exe -NoL -ExecutionPolicy Bypass

exit 
'@
$OOBEcmdTasks | Out-File -FilePath 'C:\Windows\Setup\scripts\oobe.cmd' -Encoding ascii -Force

Write-DarkGrayHost "Copying PFX file"
Copy-Item X:\OSDCloud\Config\Scripts C:\OSDCloud\ -Recurse -Force
#endregion

# Write-DarkGrayHost "Disabling Shift F10 in OOBE for security Reasons"
$Tagpath = "C:\Windows\Setup\Scripts\DisableCMDRequest.TAG"
New-Item -ItemType file -Force -Path $Tagpath | Out-Null
Write-DarkGrayHost "Shift F10 disabled now!"

#region Development
if ($Global:AutoPilot.Development -eq $true){
    #================================================
    Write-SectionHeader "[WINPE] DEVELOPMENT - Activate some debugging features"
    #================================================
    Write-DarkGrayHost "Enabling Shift+F10 in OOBE for security Reasons"
    $Tagpath = "C:\Windows\Setup\Scripts\DisableCMDRequest.TAG"
    Remove-Item -Force -Path $Tagpath | Out-Null
    Write-DarkGrayHost "Shift F10 enabled now!"

    Write-DarkGrayHost "Disable Cursor Suppression"
    #cmd.exe /c reg load HKLM\Offline c:\windows\system32\config\software & cmd.exe /c REG ADD "HKLM\Offline\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableCursorSuppression /t REG_DWORD /d 0 /f & cmd.exe /c reg unload HKLM\Offline
    Invoke-Exe cmd.exe -Arguments "/c reg load HKLM\Offline c:\windows\system32\config\software" | Out-Null
    New-ItemProperty -Path HKLM:\Offline\Microsoft\Windows\CurrentVersion\Policies\System -Name EnableCursorSuppression -Value 0 -Force | Out-Null
    #Invoke-Exe cmd.exe -Arguments "/c REG ADD 'HKLM\Offline\Microsoft\Windows\CurrentVersion\Policies\System' /v EnableCursorSuppression /t REG_DWORD /d 0 /f "
    Invoke-Exe cmd.exe -Arguments "/c reg unload HKLM\Offline" | Out-Null
}
#endregion


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


#=======================================================================	
Write-SectionHeader "Moving OSDCloud Logs to IntuneManagementExtension\Logs\OSD"	
#=======================================================================	
if (-NOT (Test-Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD')) {	
    New-Item -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -ItemType Directory -Force -ErrorAction Stop | Out-Null	
}	
Get-ChildItem -Path X:\OSDCloud\Logs\ | Copy-Item -Destination 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\OSD' -Force

if ($Global:AutoPilot.Development -eq $false){
    Write-DarkGrayHost "Restarting in 20 seconds!"
    Start-Sleep -Seconds 20

    wpeutil reboot

    Stop-Transcript | Out-Null
}
else {
    Write-DarkGrayHost "Development Mode - No reboot!"
	Start-Sleep -Seconds 20
	wpeutil reboot
    Stop-Transcript | Out-Null
}
