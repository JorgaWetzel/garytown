$ScriptName = 'oneICT.ps1'
$ScriptVersion = '08.08.2024'
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
    OSBuild = "23H2"
    OSEdition = "Pro"
    OSLanguage = "de-DE"
    OSLicense = "Retail"
    ZTI = $true
    Firmware = $false
}
Start-OSDCloud @Params

$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
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

$DriverPack = Get-OSDCloudDriverPack -Product $Product -OSVersion $OSVersion -OSReleaseID $OSReleaseID

if ($DriverPack){
    $Global:MyOSDCloud.DriverPackName = $DriverPack.Name
}

#Enable HPIA | Update HP BIOS | Update HP TPM
 if (Test-HPIASupport){
    #$Global:MyOSDCloud.DevMode = [bool]$True
    $Global:MyOSDCloud.HPTPMUpdate = [bool]$True
    if ($Product -ne '83B2' -or $Model -notmatch "zbook"){$Global:MyOSDCloud.HPIAALL = [bool]$true} #I've had issues with this device and HPIA
    #{$Global:MyOSDCloud.HPIAALL = [bool]$true}
    $Global:MyOSDCloud.HPBIOSUpdate = [bool]$true
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = [bool]$true #In Test 
    #Set HP BIOS Settings to what I want:
    iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)
    Manage-HPBiosSettings -SetSettings
}

#write variables to console
Write-Output $Global:MyOSDCloud

#=======================================================================
#   Unattend.xml
#=======================================================================

$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <LocalIntranetSites>*.internal.loc</LocalIntranetSites>
            <Home_Page>https://www.google.ch</Home_Page>
            <DisableFirstRunWizard>true</DisableFirstRunWizard>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>W. Europe Standard Time</TimeZone>
            <RegisteredOrganization>Zander Tools</RegisteredOrganization>
            <RegisteredOwner>Zander Tools</RegisteredOwner>
        </component>
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0807:00000807</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UserLocale>de-CH</UserLocale>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>OSDCloud Specialize</Description>
                    <Path>Powershell -ExecutionPolicy Bypass -Command Invoke-OSDSpecialize -Verbose</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
        <component name="Microsoft-Windows-TPM-Tasks" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ClearTpm>1</ClearTpm>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>false</HideOnlineAccountScreens>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
                <UnattendEnableRetailDemo>false</UnattendEnableRetailDemo>
            </OOBE>
        </component>
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Reseal>
                <Mode>Audit</Mode>
                <ForceShutdownNow>false</ForceShutdownNow>
            </Reseal>
        </component>
    </settings>
    <settings pass="auditUser">
        <component name="Microsoft-Windows-Deployment" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" 
            xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" 
            xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Set ExecutionPolicy RemoteSigned</Description>
                    <Path>PowerShell -WindowStyle Hidden -Command "Set-ExecutionPolicy RemoteSigned -Force"</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
    <cpi:offlineImage cpi:source="catalog://nuc1/dw10x/sources/install_windows 10 enterprise.clg" 
        xmlns:cpi="urn:schemas-microsoft-com:cpi" />
</unattend>
'@

$PantherUnattendPath = 'C:\Windows\Panther\'
if (-NOT (Test-Path $PantherUnattendPath)) {
    New-Item -Path $PantherUnattendPath -ItemType Directory -Force | Out-Null
}
$AuditUnattendPath = Join-Path $PantherUnattendPath 'Invoke-OSDSpecialize.xml'

Write-Host -ForegroundColor Cyan "Set Unattend.xml at $AuditUnattendPath"
$UnattendXml | Out-File -FilePath $AuditUnattendPath -Encoding utf8

Write-Host -ForegroundColor Cyan 'Use-WindowsUnattend'
Use-WindowsUnattend -Path 'C:\' -UnattendPath $AuditUnattendPath -Verbose

#================================================
#  [PostOS] OOBE CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"

# Ensure the directories exist
$osdCloudDir = 'C:\OSDCloud\Scripts\SetupComplete'
$windowsSetupDir = 'C:\Windows\Setup\Scripts'

# Download and create scripts
# Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/SetupComplete.ps1 | Out-File -FilePath "$osdCloudDir\SetupComplete.ps1" -Encoding ascii -Force
# Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/provisioning.ps1 | Out-File -FilePath "$windowsSetupDir\provisioning.ps1" -Encoding ascii -Force
# Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/startlayout.xml | Out-File -FilePath "$windowsSetupDir\startlayout.xml" -Encoding ascii -Force

# Create the OOBE CMD command line
$OOBECMD = @'
@echo off
Start /Wait PowerShell -NoL -C Invoke-WebPSScript https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/SetupComplete.ps1
# Start /Wait PowerShell -NoL -C Invoke-WebPSScript https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Set-KeyboardLanguage.ps1
Start /Wait PowerShell -NoL -C Invoke-WebPSScript https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Customers/PostActionTaskHutter.ps1
# Start /Wait PowerShell -NoL -C Invoke-WebPSScript https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/PostActionUser.ps1
# Start /Wait PowerShell -NoL -C Import-StartLayout -LayoutPath C:\Windows\Setup\Scripts\startlayout.xml -MountPath C:\

REM start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\Windows\Setup\Scripts\provisioning.ps1
REM reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce" /v "execute_provisioning" /t REG_SZ /d "cmd /c powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\provisioning.ps1" /f
REM add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OOBE" /v "DisablePrivacyExperience" /t REG_DWORD /d 1 /f
REM start /wait powershell.exe -NoL -ExecutionPolicy Bypass -F C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1 
exit 
'@

$OOBECMD | Out-File -FilePath "$osdCloudDir\SetupComplete.cmd" -Encoding ascii -Force


#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 5 seconds!"
Start-Sleep -Seconds 5
wpeutil reboot
