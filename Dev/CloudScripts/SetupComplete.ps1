[CmdletBinding()]
param()
#region Initialize

#Start the Transcript
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-SetupComplete.log"
$null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

#=================================================
#   oobeCloud Settings
#=================================================
$Global:oobeCloud = @{
    oobeSetDisplay = $false
    oobeSetRegionLanguage = $false
    oobeSetDateTime = $false
    oobeRegisterAutopilot = $false
    oobeRegisterAutopilotCommand = 'Get-WindowsAutopilotInfo -Online -GroupTag Demo -Assign'
    oobeRemoveAppxPackage = $false
    oobeRemoveAppxPackageName = 'Solitaire'
    oobeAddCapability = $false
    oobeAddCapabilityName = 'GroupPolicy','ServerManager','VolumeActivation'
    oobeUpdateDrivers = $true
    oobeUpdateWindows = $true
    oobeRestartComputer = $false
    EmbeddedProductKey = $false
    oobeStopComputer = $false
}

#region functions
iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#endregion


# Execute functions
# Step-KeyboardLanguage
# Step-oobeExecutionPolicy
# Step-oobePackageManagement
# Step-oobeTrustPSGallery
# Step-oobeSetDisplay
# Step-oobeSetRegionLanguage
# Step-oobeSetDateTime
# Step-oobeRegisterAutopilot
# Step-EmbeddedProductKey
# Step-oobeRemoveAppxPackage
# Step-oobeAddCapability
# Step-oobeUpdateDrivers
# Step-oobeUpdateWindows
# Invoke-Webhook
# Step-oobeRestartComputer
# Step-oobeStopComputer


# Write-Host -ForegroundColor Gray "**Setting Default Profile Personal Preferences**" 
Set-DefaultProfilePersonalPref

# setup RunOnce to execute provisioning.ps1 script
# Write-Host -ForegroundColor Gray "**Running Set-RunOnceScript Script**"
# Set-RunOnceScript

#Try to prevent crap from auto installing
#Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
#Disable-CloudContent

#Set Win11 Bypasses
Write-Host -ForegroundColor Gray "**Enabling Win11 Bypasses**" 
Set-Win11ReqBypassRegValues

#Store Updates
#Write-Host -ForegroundColor Gray "**Running Winget Updates**"
#Write-Host -ForegroundColor Gray "Invoke-UpdateScanMethodMSStore"
#Invoke-UpdateScanMethodMSStore
#Write-Host -ForegroundColor Gray "winget upgrade --all --accept-package-agreements --accept-source-agreements"
#winget upgrade --all --accept-package-agreements --accept-source-agreements

#Modified Version of Andrew's Debloat Script
#Write-Host -ForegroundColor Gray "**Running Debloat Script**" 
#iex (irm https://raw.githubusercontent.com/andrew-s-taylor/public/main/De-Bloat/RemoveBloat.ps1)

#Set Time Zone
# Write-Host -ForegroundColor Gray "**Setting TimeZone based on IP**"
# Set-TimeZoneFromIP
   
# Setup oneICT Chocolatey Framework
Write-Host -ForegroundColor Gray "**Running Chocolatey Framework**"
Set-Chocolatey

Write-Host "Setting Keyboard and Language to German (Switzerland) for Default User"
Set-DefaultUserLanguageAndKeyboard

Write-Host "**Installing Winget Stuff"
osdcloud-SetExecutionPolicy
osdcloud-SetPowerShellProfile
osdcloud-InstallPackageManagement
osdcloud-TrustPSGallery
osdcloud-InstallPowerShellModule -Name Pester
osdcloud-InstallPowerShellModule -Name PSReadLine

$taskbar_layout =
@"
<?xml version="1.0" encoding="utf-8"?>
<LayoutModificationTemplate
    xmlns="http://schemas.microsoft.com/Start/2014/LayoutModification"
    xmlns:defaultlayout="http://schemas.microsoft.com/Start/2014/FullDefaultLayout"
    xmlns:start="http://schemas.microsoft.com/Start/2014/StartLayout"
    xmlns:taskbar="http://schemas.microsoft.com/Start/2014/TaskbarLayout"
    Version="1">
  <CustomTaskbarLayoutCollection PinListPlacement="Replace">
    <defaultlayout:TaskbarLayout>
      <taskbar:TaskbarPinList>
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.WindowsTerminal_8wekyb3d8bbwe!app" />
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Google\Chrome\Application\chrome.exe" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
 </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

# prepare provisioning folder
[System.IO.FileInfo]$provisioning = "$($env:ProgramData)\provisioning\tasbar_layout.xml"
if (!$provisioning.Directory.Exists) {
    $provisioning.Directory.Create()
}

$taskbar_layout | Out-File $provisioning.FullName -Encoding utf8

$settings = [PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Value = $provisioning.FullName
    Name  = "StartLayoutFile"
    Type  = [Microsoft.Win32.RegistryValueKind]::ExpandString
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\Explorer"
    Value = 1
    Name  = "LockedStartLayout"
} | group Path

foreach ($setting in $settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    $setting.Group | % {
        if (!$_.Type) {
            $registry.SetValue($_.name, $_.value)
        }
        else {
            $registry.SetValue($_.name, $_.value, $_.type)
        }
    }
    $registry.Dispose()
}

Stop-Transcript

