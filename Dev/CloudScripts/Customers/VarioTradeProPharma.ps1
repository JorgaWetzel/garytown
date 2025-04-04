$ScriptName = 'VarioTrade.ps1'
$ScriptVersion = '04.04.2025'
iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom functions from OSDCloud

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

#================================================
#  [PreOS] Create unattended.xml for Region and Language Settings
#================================================
Write-Host -ForegroundColor Green "Creating unattended.xml for region and language settings"

$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0807:00000807</InputLocale>
            <SystemLocale>de-CH</SystemLocale>
            <UILanguage>de-DE</UILanguage>
            <UserLocale>de-CH</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <TimeZone>W. Europe Standard Time</TimeZone>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalAccountScreen>true</HideLocalAccountScreen>
                <HideOnlineAccountScreen>true</HideOnlineAccountScreen>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
                <SkipMachineOOBE>true</SkipMachineOOBE>
                <SkipUserOOBE>true</SkipUserOOBE>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>ProPharma</Name>
                        <Group>Administrators</Group>
                        <Password>
                            <Value></Value>
                            <PlainText>true</PlainText>
                        </Password>
                        <DisplayName>ProPharma</DisplayName>
                        <Description>ProPharma Benutzer</Description>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Password>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
                <LogonCount>1</LogonCount>
                <Username>ProPharma</Username>
            </AutoLogon>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0807:00000807</InputLocale>
            <SystemLocale>de-CH</SystemLocale>
            <UILanguage>de-DE</UILanguage>
            <UserLocale>de-CH</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <AdministratorPassword>
                    <Value></Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
        </component>
    </settings>
</unattend>
'@

# Verzeichnis für unattended.xml erstellen (C:\Windows\Panther)
$PantherDir = "C:\Windows\Panther"
if (-not (Test-Path $PantherDir)) {
    New-Item -Path $PantherDir -ItemType Directory -Force
}

# unattended.xml in C:\Windows\Panther speichern
$UnattendPath = "$PantherDir\unattended.xml"
$UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Force
Write-Host -ForegroundColor Green "unattended.xml created at $UnattendPath"

#=======================================================================
#   [OS] Params and Start-OSDCloud
#=======================================================================
$Product = (Get-MyComputerProduct)
$Model = (Get-MyComputerModel)
$Manufacturer = (Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer
$OSVersion = 'Windows 11' #Used to Determine Driver Pack
$OSReleaseID = '23H2' #Used to Determine Driver Pack
$OSName = 'Windows 11 23H2 x64'
$OSEdition = 'Pro'
$OSActivation = 'Retail'
$OSLanguage = 'de-DE'
$OSImageIndex = '8'

# Set OSDCloud Vars
$Global:MyOSDCloud = [ordered]@{
    Restart = [bool]$False
    RecoveryPartition = [bool]$true
    OEMActivation = [bool]$True
    WindowsUpdate = [bool]$true
    WindowsUpdateDrivers = [bool]$False
    WindowsDefenderUpdate = [bool]$False
    SetTimeZone = [bool]$True  # Zeitzone automatisch setzen
    ClearDiskConfirm = [bool]$False
    ShutdownSetupComplete = [bool]$False
    SyncMSUpCatDriverUSB = [bool]$true
    CheckSHA1 = [bool]$true
    SkipAutopilot = [bool]$true  # Autopilot überspringen, falls nicht benötigt
    SkipOOBE = [bool]$true       # OOBE-Interaktionen überspringen
    SetGeoID = "211"             # GeoID für die Schweiz (211 = Schweiz)
    SetKeyboardLanguage = "de-CH" # Tastatursprache auf Deutsch (Schweiz)
}

# Netzwerkadapter deaktivieren, um Microsoft-Anmeldung zu überspringen
Write-Host -ForegroundColor Green "Disabling network adapters to skip Microsoft account prompt..."
Get-NetAdapter | Disable-NetAdapter -Confirm:$false

# Start-OSDCloud ohne -Unattend-Parameter
Start-OSDCloud -OSName $OSName -OSEdition $OSEdition -OSActivation $OSActivation -OSLanguage $OSLanguage -ZTI -Firmware:$false

# Netzwerkadapter wieder aktivieren
Write-Host -ForegroundColor Green "Re-enabling network adapters..."
Get-NetAdapter | Enable-NetAdapter -Confirm:$false

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

#================================================
#  [PostOS] Create Disable-Administrator.ps1
#================================================
Write-Host -ForegroundColor Green "Creating Disable-Administrator.ps1 to disable the Administrator account"

$DisableAdminScript = @'
# Disable-Administrator.ps1
Write-Host "Disabling Administrator account..."
$adminAccount = Get-LocalUser -Name "Administrator"
if ($adminAccount) {
    Disable-LocalUser -Name "Administrator"
    Write-Host "Administrator account has been disabled."
} else {
    Write-Host "Administrator account not found."
}
'@

# Verzeichnis für SetupComplete-Skripte
$SetupCompleteDir = "C:\OSDCloud\Scripts\SetupComplete"
if (-not (Test-Path $SetupCompleteDir)) {
    New-Item -Path $SetupCompleteDir -ItemType Directory -Force
}

# Disable-Administrator.ps1 speichern
$DisableAdminPath = "$SetupCompleteDir\Disable-Administrator.ps1"
$DisableAdminScript | Out-File -FilePath $DisableAdminPath -Encoding ascii -Force
Write-Host -ForegroundColor Green "Disable-Administrator.ps1 created at $DisableAdminPath"

#================================================
#  [PostOS] OOBE CMD Command Line
#================================================
Write-Host -ForegroundColor Green "Downloading and creating script for OOBE phase"
#Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Set-KeyboardLanguage.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\keyboard.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Install-EmbeddedProductKey.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\productkey.ps1' -Encoding ascii -Force
# Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/Customers/PostActionTaskRaumanzug.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionTask.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/SetupComplete.ps1 | Out-File -FilePath 'C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1' -Encoding ascii -Force
Invoke-RestMethod https://raw.githubusercontent.com/JorgaWetzel/garytown/refs/heads/master/Dev/CloudScripts/PostActionUser.ps1 | Out-File -FilePath 'C:\Windows\Setup\scripts\PostActionUser.ps1' -Encoding ascii -Force

$OOBECMD = @'
@echo off
REM Planen der Ausführung der Skripte nach dem nächsten Neustart
#start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\keyboard.ps1
exit
'@
$OOBECMD | Out-File -FilePath 'C:\Windows\Setup\Scripts\oobe.cmd' -Encoding ascii -Force

#================================================
#  [PostOS] SetupComplete CMD Command Line OSDCloud
#================================================
$osdCloudDir = 'C:\OSDCloud\Scripts\SetupComplete'
# Create the SetupComplete CMD command line
$OOBECMD = @'
@echo off
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\productkey.ps1
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1
start /wait powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\OSDCloud\Scripts\SetupComplete\Disable-Administrator.ps1
# call powershell.exe -NoLogo -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\PostActionTask.ps1
exit
'@

$OOBECMD | Out-File -FilePath "$osdCloudDir\SetupComplete.cmd" -Encoding ascii -Force

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 20 seconds!"
Start-Sleep -Seconds 20
wpeutil reboot