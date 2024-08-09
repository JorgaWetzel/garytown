[CmdletBinding()]
param()
#region Initialize

#Start the Transcript
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-SetupComplete.log"
$null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

#region functions
iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#endregion


# Execute functions
Step-KeyboardLanguage
# Step-oobeExecutionPolicy
# Step-oobePackageManagement
# Step-oobeTrustPSGallery
# Step-oobeSetDisplay
Step-oobeSetRegionLanguage
Step-oobeSetDateTime
#Step-oobeRegisterAutopilot
#Step-EmbeddedProductKey
#Step-oobeRemoveAppxPackage
#Step-oobeAddCapability
#Step-oobeUpdateDrivers
# Step-oobeUpdateWindows
# Invoke-Webhook
# Step-oobeStopComputer
#=================================================

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

#Windows Updates
#Write-Host -ForegroundColor Gray "**Running Defender Updates**"
#Update-DefenderStack
#Write-Host -ForegroundColor Gray "**Running Windows Updates**"
#Start-WindowsUpdate
#Write-Host -ForegroundColor Gray "**Running Driver Updates**"
#Start-WindowsUpdateDriver

#osdcloud-HPIAExecute

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

'
Stop-Transcript

