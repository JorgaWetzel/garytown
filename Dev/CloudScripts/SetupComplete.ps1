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


Write-Host "**Taskbar Layout"
# Show packagedAppId for Windows store apps:
# Get-AppxPackage | select @{n='name';e={"$($_.PackageFamilyName)!app"}} | ?{$_.name -like "**"}

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


# *** Konfigurationsskripte für Browser herunterladen und ausführen ***
Write-Host "*** Konfigurationsskripte für Browser herunterladen und ausführen ***"
$provisioning = [System.IO.DirectoryInfo]"$env:UserProfile\Documents\OSDCloud\provisioning"
$urls = @(
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_brave.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_chrome.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_edge.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_firefox.ps1"
)

# *** Sicherstellen, dass das Verzeichnis existiert ***
Write-Host "*** Sicherstellen, dass das Verzeichnis existiert ***"
if (-not (Test-Path $provisioning)) {
    Write-Host "Erstelle Verzeichnis für Provisioning..."
    New-Item -ItemType Directory -Path $provisioning -Force
} else {
    Write-Host "Provisioning-Verzeichnis existiert bereits."
}

# *** Herunterladen und Ausführen der Konfigurationsskripte ***
Write-Host "*** Herunterladen und Ausführen der Konfigurationsskripte ***"
foreach ($url in $urls) {
    $scriptName = [System.IO.Path]::GetFileName($url)
    $scriptPath = Join-Path -Path $provisioning -ChildPath $scriptName
    
    # Herunterladen, wenn das Skript noch nicht existiert
    if (-not (Test-Path $scriptPath)) {
        Write-Host "Herunterladen von $url ..."
        Invoke-WebRequest -Uri $url -OutFile $scriptPath
    } else {
        Write-Host "$scriptName existiert bereits."
    }
    
    # Ausführen des Skripts
    Write-Host "Ausführen von $scriptName ..."
    . $scriptPath
}

# Set Microsoft Edge as Default Browser and other Defaults
# DISM /Online /Export-DefaultAppAssociations:DefaultAssociations.xml
[System.IO.FileInfo]$DefaultAssociationsConfiguration = "$($env:ProgramData)\provisioning\DefaultAssociationsConfiguration.xml"

# Sicherstellen, dass das Verzeichnis existiert
if(!$DefaultAssociationsConfiguration.Directory.Exists){
    $DefaultAssociationsConfiguration.Directory.Create()
}

# XML-Datei mit den gewünschten Dateityp- und Protokollzuweisungen erstellen
'<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".htm" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier=".html" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier=".mht" ProgId="MSEdgeMHT" ApplicationName="Microsoft Edge" />
  <Association Identifier=".mhtml" ProgId="MSEdgeMHT" ApplicationName="Microsoft Edge" />
  <Association Identifier=".oxps" ProgId="Windows.XPSReachViewer" ApplicationName="XPS Viewer" />
  <Association Identifier=".pdf" ProgId="Acrobat.Document.DC" ApplicationName="Adobe Acrobat" />
  <Association Identifier=".svg" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier=".tif" ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".tiff" ProgId="PhotoViewer.FileAssoc.Tiff" ApplicationName="Windows Photo Viewer" />
  <Association Identifier=".url" ProgId="InternetShortcut" ApplicationName="Internet Explorer" />
  <Association Identifier=".wsb" ProgId="Windows.Sandbox" ApplicationName="Windows Sandbox" />
  <Association Identifier=".xht" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier=".xhtml" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier=".xps" ProgId="Windows.XPSReachViewer" ApplicationName="XPS Viewer" />
  <Association Identifier=".zip" ProgId="CompressedFolder" ApplicationName="Windows Explorer" />
  <Association Identifier="ftp" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="http" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="https" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="mailto" ProgId="Outlook.URL.mailto.15" ApplicationName="Outlook" />
  <Association Identifier="microsoft-edge" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="microsoft-edge-holographic" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="ms-xbl-3d8b930f" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
  <Association Identifier="read" ProgId="MSEdgeHTM" ApplicationName="Microsoft Edge" />
</DefaultAssociations>' | Out-File $DefaultAssociationsConfiguration.FullName -Encoding utf8 -Force

# Registry-Einstellungen für die Default App Associations konfigurieren
$settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Windows\System"
    Value = $DefaultAssociationsConfiguration.FullName
    Name  = "DefaultAssociationsConfiguration"
} | group Path

foreach($setting in $settings){
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    $setting.Group | %{
        $registry.SetValue($_.name, $_.value)
    }
    $registry.Dispose()
}


# Get-AppxPackage | select @{n='name';e={"$($_.PackageFamilyName)!app"}} | ?{$_.name -like "**"}
# Import-StartLayout
$apps = 
"Microsoft.Windows.Explorer",
"Microsoft.Windows.ControlPanel",
"Microsoft.WindowsCalculator_8wekyb3d8bbwe!app",
"Microsoft.Paint_8wekyb3d8bbwe!app",
"Microsoft.ScreenSketch_8wekyb3d8bbwe!app ",
"Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe!app",
"C:\Program Files\Mozilla Firefox\firefox.exe",
"C:\Program Files\Google\Chrome\Application\chrome.exe",
"C:\Program Files\Microsoft Office\Office16\OUTLOOK.EXE",
"C:\Program Files\Microsoft Office\Office16\WINWORD.EXE",
"C:\Program Files\Microsoft Office\Office16\EXCEL.EXE",
"C:\Program Files\Microsoft Office\Office16\POWERPNT.EXE",
"MicrosoftTeams_8wekyb3d8bbwe!app",
"Microsoft.YourPhone_8wekyb3d8bbwe!app",
"Microsoft.MicrosoftStickyNotes_8wekyb3d8bbwe!app"
$start_pins = @{
    pinnedList = foreach ($app in $apps) {
        if ($app -match "\w:\\") {
            @{
                desktopAppLink = $app
            }
        }
        elseif ($app -match "Microsoft\.Windows\.") {
            @{
                desktopAppId = $app
            }
        }
        else {
            @{
                packagedAppId = $app
            }
        }
    }
} | ConvertTo-Json -Compress

$settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\PolicyManager\current\device\Start"
    Value = $start_pins
    #Value = '{ "pinnedList": [] }' # only for remove everything
    Name  = "ConfigureStartPins"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\PolicyManager\current\device\Start"
    Value = 1
    Name  = "ConfigureStartPins_ProviderSet"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\PolicyManager\current\device\Start"
    Value = "B5292708-1619-419B-9923-E5D9F3925E71"
    Name  = "ConfigureStartPins_WinningProvider"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\PolicyManager\providers\B5292708-1619-419B-9923-E5D9F3925E71\default\Device\Start"
    Value = $start_pins
    #Value = '{ "pinnedList": [] }' # only for remove everything
    Name  = "ConfigureStartPins"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Microsoft\PolicyManager\providers\B5292708-1619-419B-9923-E5D9F3925E71\default\Device\Start"
    Value = 1
    Name  = "ConfigureStartPins_LastWrite"
} | group Path

foreach ($setting in $settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
    }
    $setting.Group | % {
        $registry.SetValue($_.name, $_.value)
    }
    $registry.Dispose()
}

# Zeitzone konfigurieren
Get-TimeZone -ListAvailable | ?{$_.DisplayName -like "*Zürich*"} | Set-TimeZone

# Regionale Einstellungen / Gebietsschema / Tastaturlayout konfigurieren
# Schweizerdeutsch
$region = "de-CH"

Set-Culture $region
Set-WinSystemLocale $region
Set-WinUserLanguageList $region, "de-ch" -force -wa silentlycontinue
Set-WinHomeLocation 19

# Regionale Einstellungen für neue Benutzerkonten und Willkommensbildschirm kopieren
Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

# Configure power settings
# Disable sleep, hibernate and monitor standby on AC
"powercfg /x -monitor-timeout-ac 0",
"powercfg /x -standby-timeout-ac 0",
"powercfg /x -hibernate-timeout-ac 0" | % {
    cmd /c $_
}

$app_packages = 
"Microsoft.WindowsCamera",
"Clipchamp.Clipchamp",
"Microsoft.WindowsAlarms",
"Microsoft.549981C3F5F10", # Cortana
"Microsoft.WindowsFeedbackHub",
"microsoft.windowscommunicationsapps",
"Microsoft.WindowsMaps",
"Microsoft.ZuneMusic",
"Microsoft.BingNews",
"Microsoft.Todos",
"Microsoft.ZuneVideo",
"Microsoft.MicrosoftOfficeHub",
"Microsoft.OutlookForWindows",
"Microsoft.People",
"Microsoft.PowerAutomateDesktop",
"MicrosoftCorporationII.QuickAssist",
"Microsoft.MicrosoftSolitaireCollection",
"Microsoft.WindowsSoundRecorder",
"Microsoft.MicrosoftStickyNotes",
"Microsoft.BingWeather",
"Microsoft.Xbox.TCUI",
"Microsoft.GamingApp"

Get-AppxProvisionedPackage -Online | ?{$_.DisplayName -in $app_packages} | Remove-AppxProvisionedPackage -Online -AllUser

# Prevent Outlook (new) and Dev Home from installing
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" | %{
    ri $_ -force
}

Stop-Transcript

