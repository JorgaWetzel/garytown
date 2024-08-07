$ScriptName = 'functions.oneict.ch'
$ScriptVersion = '10.04.2024'
Set-ExecutionPolicy Bypass -Force

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"

Write-Host -ForegroundColor Green "[+] Function Set-DefaultProfilePersonalPrefOneICT"
function Set-DefaultProfilePersonalPrefOneICT {
    # Set Default User Profile to MY PERSONAL preferences.
    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" # Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" # PowerShell Path

    # Ensure registry is unloaded before loading
    if (Test-Path -Path $VirtualRegistryPath_software) {
        reg unload $VirtualRegistryPath_defaultuser | Out-Null
        Start-Sleep -Seconds 1
    }
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    # Registry settings for user experience
    # Enable file operations details
    Write-Host "Enable file operations details..."
    $registryPath = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager"

    # Überprüfen, ob der Pfad existiert, und falls nicht, erstellen
    if (-not (Test-Path $registryPath)) {
      New-Item -Path $registryPath -Force
    }
    Set-ItemProperty -Path $registryPath -Name "EnthusiastMode" -Value 1 -Type DWORD

    # Enable known file extensions
    Write-Host "Enable known file extensions..."
    $registryPath = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    Set-ItemProperty -Path $registryPath -Name "HideFileExt" -Value 0 -Type DWORD

    # Set ZeroConfigExchange
    Write-Host "Enable ZeroConfigExchange..."
    REG ADD "$VirtualRegistryPath_software\Microsoft\Office\16.0\Outlook\AutoDiscover" /v ZeroConfigExchange /t REG_DWORD /d 1 /f

    Write-Host -ForegroundColor Green "Disabling Application suggestions..."
    $cdmPath = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    $settings = @(
        "ContentDeliveryAllowed",
        "OemPreInstalledAppsEnabled",
        "PreInstalledAppsEnabled",
        "PreInstalledAppsEverEnabled",
        "SilentInstalledAppsEnabled",
        "SubscribedContent-338387Enabled",
        "SubscribedContent-338388Enabled",
        "SubscribedContent-338389Enabled",
        "SubscribedContent-353698Enabled",
        "SystemPaneSuggestionsEnabled"
    )

    foreach ($setting in $settings) {
        Set-ItemProperty -Path $cdmPath -Name $setting -Value 0 -Type DWORD
    }

    Write-Host -ForegroundColor Green "Disabling Feedback..."
    $feedbackPath = "$VirtualRegistryPath_software\Microsoft\Siuf\Rules"
    if (!(Test-Path $feedbackPath)) {
        New-Item -Path $feedbackPath -Force | Out-Null
    }
    Set-ItemProperty -Path $feedbackPath -Name "NumberOfSIUFInPeriod" -Value 0 -Type DWORD

    Write-Host -ForegroundColor Green "Disabling Tailored Experiences..."
    $cloudContentPath = "$VirtualRegistryPath_software\Policies\Microsoft\Windows\CloudContent"
    if (!(Test-Path $cloudContentPath)) {
        New-Item -Path $cloudContentPath -Force | Out-Null
    }


Write-Host -ForegroundColor Green "Showing file operations details..."
If (!(Test-Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager")) {
    New-Item -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Force | Out-Null
}
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\OperationStatusManager" -Name "EnthusiastMode" -Value 1 -Type DWORD

Write-Host -ForegroundColor Green "Hiding Task View button..."
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0 -Type DWORD

Write-Host -ForegroundColor Green "Hiding People icon..."
If (!(Test-Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People")) {
    New-Item -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Force | Out-Null
}
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People" -Name "PeopleBand" -Value 0 -Type DWORD

Write-Host -ForegroundColor Green "Changing default Explorer view to This PC..."
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -Type DWORD

Write-Host -ForegroundColor Green "Disable News and Interests"
Set-ItemProperty -Path "$VirtualRegistryPath_software\Policies\Microsoft\Windows\Windows Feeds" -Name "EnableFeeds" -Value 0 -Type DWORD

# Remove "News and Interest" from taskbar
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Feeds" -Name "ShellFeedsTaskbarViewMode" -Value 2 -Type DWORD

# Remove "Meet Now" button from taskbar
If (!(Test-Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Policies\Explorer")) {
    New-Item -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Force | Out-Null
}
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "HideSCAMeetNow" -Value 1 -Type DWORD

Write-Host -ForegroundColor Green "Disabling Action Center..."
If (!(Test-Path "$VirtualRegistryPath_software\Policies\Microsoft\Windows\Explorer")) {
    New-Item -Path "$VirtualRegistryPath_software\Policies\Microsoft\Windows\Explorer" -Force | Out-Null
}
Set-ItemProperty -Path "$VirtualRegistryPath_software\Policies\Microsoft\Windows\Explorer" -Name "DisableNotificationCenter" -Value 1 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\PushNotifications" -Name "ToastEnabled" -Value 0 -Type DWORD
Write-Host -ForegroundColor Green "Disabled Action Center"

Write-Host -ForegroundColor Green "Adjusting visual effects for performance..."
Set-ItemProperty -Path "$VirtualRegistryPath_software\Control Panel\Desktop" -Name "DragFullWindows" -Value "0" -Type String
Set-ItemProperty -Path "$VirtualRegistryPath_software\Control Panel\Desktop" -Name "MenuShowDelay" -Value "200" -Type String
Set-ItemProperty -Path "$VirtualRegistryPath_software\Control Panel\Desktop" -Name "UserPreferencesMask" -Value ([byte[]](144,18,3,128,16,0,0,0)) -Type Binary
Set-ItemProperty -Path "$VirtualRegistryPath_software\Control Panel\Desktop\WindowMetrics" -Name "MinAnimate" -Value "0" -Type String
Set-ItemProperty -Path "$VirtualRegistryPath_software\Control Panel\Keyboard" -Name "KeyboardDelay" -Value 0 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewAlphaSelect" -Value 0 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ListviewShadow" -Value 0 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "TaskbarAnimations" -Value 0 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" -Name "VisualFXSetting" -Value 3 -Type DWORD
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\DWM" -Name "EnableAeroPeek" -Value 0 -Type DWORD
Write-Host -ForegroundColor Green "Adjusted visual effects for performance"
$ResultText.text += "`r`nAdjusted VFX for performance"

Write-Host -ForegroundColor Green "Showing tray icons..."
Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer" -Name "EnableAutoTray" -Value 0 -Type DWORD

# Finish by unloading the registry
Start-Sleep -Seconds 1
reg unload $VirtualRegistryPath_defaultuser | Out-Null
}

Write-Host -ForegroundColor Green "[+] Function Set-MachineSettingsOneICT"
function Set-MachineSettingsOneICT {
    #Set Default Machine Settings

# Windows will tell you exactly what it is doing when it is shutting down or is booting...
Write-Host -ForegroundColor Green "[+] Boot and shutdownVerboseStatus "
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\policies\system" /v "VerboseStatus" /t REG_DWORD /d "1" /f

#EDGE
Write-Host -ForegroundColor Green "[+] Edge Disable First Run wizard"
REG ADD  "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "PersonalizationReportingEnabled" /t REG_DWORD /d 0 /f
REG ADD  "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "ShowRecommendationsEnabled" /t REG_DWORD /d 0 /f
REG ADD  "HKLM\SOFTWARE\Policies\Microsoft\Edge" /v "HideFirstRunExperience" /t REG_DWORD /d 1 /f

Write-Host -ForegroundColor Green "[+] Edge Set Search Engine and Start Page"
# Define search engines as JSON
$searchEngines = @(
    @{ keyword = "duck"; name = "duckduckgo.com"; search_url = "https://duckduckgo.com/?q={searchTerms}" },
    @{ keyword = "bing"; name = "bing.com"; search_url = "https://www.bing.com/search?q={searchTerms}" },
    @{ is_default = $true; keyword = "google"; name = "google.ch"; search_url = "https://www.google.ch/search?q={searchTerms}" }
) | ConvertTo-Json -Compress

# Define settings for Microsoft Edge
$edgeSettings = @(
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Edge"; Name = "ManagedSearchEngines"; Value = $searchEngines },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Edge"; Name = "RestoreOnStartup"; Value = 4 },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Edge\RestoreOnStartupURLs"; Name = 1; Value = "https://google.ch" },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Edge\RestoreOnStartupURLs"; Name = 2; Value = "https://www.oneict.ch/" },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Edge"; Name = "FavoritesBarEnabled"; Value = 1 }
)

# Function to apply settings to registry
function Apply-EdgeSettings {
    param ([PSCustomObject[]]$Settings)

    foreach ($setting in $Settings) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
        if ($null -eq $registry) {
            $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Path, $true)
        }
        $registry.SetValue($setting.Name, $setting.Value)
        $registry.Dispose()
    }
}

# Apply settings
Apply-EdgeSettings -Settings $edgeSettings

# Funktion zum Erstellen oder Abrufen eines Registrierungsschlüssels
function Get-OrCreateRegistryKey($path) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path, $true)
    if ($null -eq $registry) {
        $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($path, $true)
    }
    return $registry
}

# Funktion zum Anwenden von Registrierungseinstellungen
function Set-RegistrySettings($settings) {
    foreach ($setting in $settings) {
        $registry = Get-OrCreateRegistryKey($setting.Path)
        $registry.SetValue($setting.Name, $setting.Value)
        $registry.Dispose()
    }
}

Write-Host -ForegroundColor Green "[+] Set Default App Associations"
# Exportieren der Standard-App-Assoziationen und Schreiben der XML-Konfiguration
$defaultAssociationsPath = "$env:ProgramData\provisioning\DefaultAssociationsConfiguration.xml"
if (-Not (Test-Path $defaultAssociationsPath)) {
   New-Item $defaultAssociationsPath -Force -ItemType File
}

$defaultAssociationsXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<DefaultAssociations>
  <Association Identifier=".htm" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".html" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="http" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier="https" ProgId="ChromeHTML" ApplicationName="Google Chrome" />
  <Association Identifier=".pdf" ProgId="Acrobat.Document.DC" ApplicationName="Adobe Acrobat" />
  <Association Identifier="mailto" ProgId="Outlook.URL.mailto.15" ApplicationName="Outlook" />
</DefaultAssociations>
'@
$defaultAssociationsXml | Out-File $defaultAssociationsPath -Encoding UTF8 -Force

Write-Host -ForegroundColor Green "[+] Set Google Chrome Setting"
# Allgemeine Einstellungen für Google Chrome
$chromeSettings = @(
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "HomepageLocation"; Value = "https://google.ch" },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "NewTabPageLocation"; Value = "https://www.oneict.ch/" },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "HomepageIsNewTabPage"; Value = 0 },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "ShowHomeButton"; Value = 1 },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "BookmarkBarEnabled"; Value = 1 },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "DefaultSearchProviderEnabled"; Value = 1 },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Google\Chrome"; Name = "DefaultSearchProviderSearchURL"; Value = "https://google.ch/?q={searchTerms}" },
    [PSCustomObject]@{ Path = "SOFTWARE\Policies\Microsoft\Windows\System"; Name = "DefaultAssociationsConfiguration"; Value = $defaultAssociationsPath }
)

# Installiere Google Chrome-Erweiterungen
$extensions = @('oldceeleldhonbafppcapldpdifcinji')
$extensionKeyPath = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
$extensionRegistry = Get-OrCreateRegistryKey($extensionKeyPath)
foreach ($extension in $extensions) {
    $values = $extensionRegistry.GetValueNames().ForEach({$extensionRegistry.GetValue($_)})
    if ($extension -notin $values) {
        $maximum = $extensionRegistry.GetValueNames().Where({$_ -match "\d"}) | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
        $maximum += 1
        $extensionRegistry.SetValue($maximum, $extension)
    }
}
$extensionRegistry.Dispose()

# Anwenden der Chrome-Einstellungen
Set-RegistrySettings $chromeSettings

#Set F8 to boot to Safe Mode
Write-Host -ForegroundColor Green "Setting boot menu to legacy"
bcdedit /set "{current}" bootmenupolicy legacy

#Set Percentage for System Protection
Write-Host -ForegroundColor Green "Setting size for system restore"
vssadmin resize shadowstorage /for=C: /on=C: /maxsize=5%

#Configure over provisioning for SSD
Write-Host -ForegroundColor Green "Configure Over Provisioning via TRIM"
fsutil behavior set DisableDeleteNotify 0

# Enable system restore on C:\
Write-Host -ForegroundColor Green "Enabling system restore..."
Enable-ComputerRestore -Drive "$env:SystemDrive"

#Force Restore point to not skip
REG ADD "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /V "SystemRestorePointCreationFrequency" /T REG_DWORD /D 0 /F

#Disable sleep timers and create a restore point just in case
Checkpoint-Computer -Description "RestorePointInitalSetup" -RestorePointType "MODIFY_SETTINGS"

#Disable LLMNR
Write-Host -ForegroundColor Green "Disabling LLMNR"
REG ADD  "HKLM\Software\policies\Microsoft\Windows NT\DNSClient"
REG ADD  "HKLM\Software\policies\Microsoft\Windows NT\DNSClient" /v " EnableMulticas" /t REG_DWORD /d "0" /f

#Disable NBT-NS
Write-Host -ForegroundColor Green "Disabling NBT-NS"
$regkey = "HKLM:SYSTEM\CurrentControlSet\services\NetBT\Parameters\Interfaces"
Get-ChildItem $regkey |foreach { Set-ItemProperty -Path "$regkey\$($_.pschildname)" -Name NetbiosOptions -Value 2 -Verbose}

Write-Host -ForegroundColor Green "Enabling SMB signing as always"
#Enable SMB signing as 'always'
$Parameters = @{
    RequireSecuritySignature = $True
    EnableSecuritySignature = $True
    EncryptData = $True
    Confirm = $false
}
Set-SmbServerConfiguration @Parameters

#Set Group Policy options
Write-Host -ForegroundColor Green "Setting Password Policy:"
Write-Host -ForegroundColor Green "Password History:10 `nMaximum Password Age:Unlimited `nMinimum Password Age:0 `nMinimum Password Length: 12 `nMust Meet Complexity Requirements"
##Enforce password history
net accounts /uniquepw:5
##Set maximum password age
net accounts /maxpwage:unlimited
## Set minimum password age 0
net accounts /minpwage:0
#Set minimum password length 8
net accounts /minpwlen: 8
##Set must meet complexity requirements
<# This part is a bit weird. It does the following:
Exports the GPO config to root of C:
Edits one line to enable Password Complexity
Imports itself into GPO
Deletes the exported file
#>
secedit /export /cfg c:\secpol.cfg
(GC C:\secpol.cfg) -Replace "PasswordComplexity = 0","PasswordComplexity = 1" | Out-File C:\secpol.cfg
secedit /configure /db c:\windows\security\local.sdb /cfg c:\secpol.cfg /areas SECURITYPOLICY
Remove-Item C:\secpol.cfg -Force

##Set lockout threshold
Write-Host -ForegroundColor Green "Setting Account Security Policy:"
Write-Host -ForegroundColor Green "Account Lockout Threshold: 5 `nAccount Lockout Duration: 30 minutes `nAccount Lockout Counter Restet: 30 minutes"
net accounts /lockoutthreshold:5
##Set account lockout duration
net accounts /lockoutduration:30
#Reset acccount lockout counter
net accounts /lockoutwindow:30

#Enable screen saver
<#
Write-Host -ForegroundColor Green "Further Hardening:"
Write-Host -ForegroundColor Green "`nScreen Saver Enabled `nScreen Saver Timeout: 15 minutes `nSpecific Screen Saver Set `nPassword Protected Screen Saver `nSceen Saver Cannot Be Changed"
REG DEL "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaveActive /f
#Set screen saver timeout 900
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaveTimeOut /t REG_SZ /d 900 /f
#Set specific screensaver scrnsave.scr
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop" /v SCRNSAVE.EXE /t REG_SZ /d C:\Windows\system32\scrnsave.scr /f
#Password protect the screen saver enabled
REG ADD "HKLM:\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 1 /f
#Prevent changing the screen saver enabled
REG ADD "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v NoDispScrSavPage \t REG_DWORD /d 1 /f

#Enable RDP
Write-Host -ForegroundColor Green "Enable RDP"
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f
netsh advfirewall firewall set rule group="remote desktop" new enable=yes
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server'-name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"


Write-Host  -ForegroundColor Green "Running OO Shutup with Recommended Settings"
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/cole-bermudez/Windows-Deployment/main/ooshutup10.cfg" -Outfile "C:\Support\Scripts\ooshutup10.cfg"
Invoke-WebRequest -Uri "https://dl5.oo-software.com/files/ooshutup10/OOSU10.exe" -outFile "C:\Support\Scripts\OOSU10.exe"
cd C:\Support\Scripts
./OOSU10.exe ooshutup10.cfg /quiet
#>

Write-Host  -ForegroundColor Green "Disabling Telemetry..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Type DWord -Value 0
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Application Experience\ProgramDataUpdater" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Autochk\Proxy" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\Consolidator" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip" | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector" | Out-Null
    Write-Host  -ForegroundColor Green "Disabling Wi-Fi Sense..."
    If (!(Test-Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting")) {
        New-Item -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting" -Name "Value" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots" -Name "Value" -Type DWord -Value 0
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableWindowsConsumerFeatures" -Type DWord -Value 1
    Write-Host  -ForegroundColor Green "Disabling Activity History..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableActivityFeed" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "PublishUserActivities" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "UploadUserActivities" -Type DWord -Value 0
    # Keep Location Tracking commented out if you want the ability to locate your device
    Write-Host  -ForegroundColor Green "Disabling Location Tracking..."
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -Type String -Value "Deny"
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}" -Name "SensorPermissionState" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration" -Name "Status" -Type DWord -Value 0
    Write-Host  -ForegroundColor Green "Disabling automatic Maps updates..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\Maps" -Name "AutoUpdateEnabled" -Type DWord -Value 0
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "DoNotShowFeedbackNotifications" -Type DWord -Value 1
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClient" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload" -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" -Name "DisableTailoredExperiencesWithDiagnosticData" -Type DWord -Value 1
    Write-Host  -ForegroundColor Green "Disabling Advertising ID..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" -Name "DisabledByGroupPolicy" -Type DWord -Value 1
    Write-Host  -ForegroundColor Green "Disabling Error reporting..."
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting" -Name "Disabled" -Type DWord -Value 1
    Disable-ScheduledTask -TaskName "Microsoft\Windows\Windows Error Reporting\QueueReporting" | Out-Null
    Write-Host  -ForegroundColor Green "Restricting Windows Update P2P only to local network..."
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" -Name "DODownloadMode" -Type DWord -Value 1
    Write-Host  -ForegroundColor Green "Stopping and disabling Diagnostics Tracking Service..."
    Stop-Service "DiagTrack" -WarningAction SilentlyContinue
    Set-Service "DiagTrack" -StartupType Disabled
    Write-Host  -ForegroundColor Green "Stopping and disabling WAP Push Service..."
    Stop-Service "dmwappushservice" -WarningAction SilentlyContinue
    Set-Service "dmwappushservice" -StartupType Disabled
    Write-Host  -ForegroundColor Green "Stopping and disabling Home Groups services..."
    # Stop-Service "HomeGroupListener" -WarningAction SilentlyContinue
    # Set-Service "HomeGroupListener" -StartupType Disabled
    Stop-Service "HomeGroupProvider" -WarningAction SilentlyContinue
    Set-Service "HomeGroupProvider" -StartupType Disabled
    Write-Host  -ForegroundColor Green "Disabling Remote Assistance..."
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance" -Name "fAllowToGetHelp" -Type DWord -Value 0
    Write-Host  -ForegroundColor Green "Disabling Storage Sense..."
    Remove-Item -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" -Recurse -ErrorAction SilentlyContinue
    Write-Host -ForegroundColor Green "Stopping and disabling Superfetch service..."
    Stop-Service "SysMain" -WarningAction SilentlyContinue
    Set-Service "SysMain" -StartupType Disabled
    Write-Host  -ForegroundColor Green "Disabling Hibernation..."
    Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Session Manager\Power" -Name "HibernteEnabled" -Type Dword -Value 0
    If (!(Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings")) {
        New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowHibernateOption" -Type Dword -Value 0

    Write-Host  -ForegroundColor Green "Hiding 3D Objects icon from This PC..."
    Remove-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" -Recurse -ErrorAction SilentlyContinue

    # Network Tweaks
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters" -Name "IRPStackSize" -Type DWord -Value 20

    # Group svchost.exe processes
    $ram = (Get-CimInstance -ClassName Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum).Sum / 1kb
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control" -Name "SvcHostSplitThresholdInKB" -Type DWord -Value $ram -Force

    Write-Host  -ForegroundColor Green "Installing Windows Media Player..."
	Enable-WindowsOptionalFeature -Online -FeatureName "WindowsMediaPlayer" -NoRestart -WarningAction SilentlyContinue | Out-Null

    Write-Host  -ForegroundColor Green "Removing AutoLogger file and restricting directory..."
    $autoLoggerDir = "$env:PROGRAMDATA\Microsoft\Diagnosis\ETLLogs\AutoLogger"
    If (Test-Path "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl") {
        Remove-Item "$autoLoggerDir\AutoLogger-Diagtrack-Listener.etl"
    }
    icacls $autoLoggerDir /deny SYSTEM:`(OI`)`(CI`)F | Out-Null

    Write-Host  -ForegroundColor Green "Stopping and disabling Diagnostics Tracking Service..."
    Stop-Service "DiagTrack"
    Set-Service "DiagTrack" -StartupType Disabled

    Write-Host -ForegroundColor Green "Showing known file extensions..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Type DWord -Value 0

    # Service tweaks to Manual 

    $services = @(
    "diagnosticshub.standardcollector.service"     # Microsoft (R) Diagnostics Hub Standard Collector Service
    "DiagTrack"                                    # Diagnostics Tracking Service
    "DPS"
    "dmwappushservice"                             # WAP Push Message Routing Service (see known issues)
    "lfsvc"                                        # Geolocation Service
    "MapsBroker"                                   # Downloaded Maps Manager
    "NetTcpPortSharing"                            # Net.Tcp Port Sharing Service
    "RemoteAccess"                                 # Routing and Remote Access
    "RemoteRegistry"                               # Remote Registry
    "SharedAccess"                                 # Internet Connection Sharing (ICS)
    "TrkWks"                                       # Distributed Link Tracking Client
    #"WbioSrvc"                                     # Windows Biometric Service (required for Fingerprint reader / facial detection)
    #"WlanSvc"                                      # WLAN AutoConfig
    "WMPNetworkSvc"                                # Windows Media Player Network Sharing Service
    #"wscsvc"                                       # Windows Security Center Service
    #"WSearch"                                      # Windows Search
    "XblAuthManager"                               # Xbox Live Auth Manager
    "XblGameSave"                                  # Xbox Live Game Save Service
    "XboxNetApiSvc"                                # Xbox Live Networking Service
    "XboxGipSvc"                                   #Disables Xbox Accessory Management Service
    "ndu"                                          # Windows Network Data Usage Monitor
    "WerSvc"                                       #disables windows error reporting
    #"Spooler"                                      #Disables your printer
    "Fax"                                          #Disables fax
    "fhsvc"                                        #Disables fax histroy
    "gupdate"                                      #Disables google update
    "gupdatem"                                     #Disable another google update
    "stisvc"                                       #Disables Windows Image Acquisition (WIA)
    "AJRouter"                                     #Disables (needed for AllJoyn Router Service)
    "MSDTC"                                        # Disables Distributed Transaction Coordinator
    "WpcMonSvc"                                    #Disables Parental Controls
    #"PhoneSvc"                                     #Disables Phone Service(Manages the telephony state on the device)
    "PrintNotify"                                  #Disables Windows printer notifications and extentions
    "PcaSvc"                                       #Disables Program Compatibility Assistant Service
    "WPDBusEnum"                                   #Disables Portable Device Enumerator Service
    #"LicenseManager"                               #Disable LicenseManager(Windows store may not work properly)
    "seclogon"                                     #Disables  Secondary Logon(disables other credentials only password will work)
    "SysMain"                                      #Disables sysmain
    "lmhosts"                                      #Disables TCP/IP NetBIOS Helper
    "wisvc"                                        #Disables Windows Insider program(Windows Insider will not work)
    "FontCache"                                    #Disables Windows font cache
    "RetailDemo"                                   #Disables RetailDemo whic is often used when showing your device
    "ALG"                                          # Disables Application Layer Gateway Service(Provides support for 3rd party protocol plug-ins for Internet Connection Sharing)
    #"BFE"                                         #Disables Base Filtering Engine (BFE) (is a service that manages firewall and Internet Protocol security)
    #"BrokerInfrastructure"                         #Disables Windows infrastructure service that controls which background tasks can run on the system.
    "SCardSvr"                                      #Disables Windows smart card
    #"EntAppSvc"                                     #Disables enterprise application management.
    #"BthAvctpSvc"                                   #Disables AVCTP service (if you use  Bluetooth Audio Device or Wireless Headphones. then don't disable this)
    #"FrameServer"                                   #Disables Windows Camera Frame Server(this allows multiple clients to access video frames from camera devices.)
    "Browser"                                       #Disables computer browser
    "BthAvctpSvc"                                   #AVCTP service (This is Audio Video Control Transport Protocol service.)
    #"BDESVC"                                        #Disables bitlocker
    "iphlpsvc"                                      #Disables ipv6 but most websites don't use ipv6 they use ipv4     
    #"edgeupdate"                                    # Disables one of edge update service  
    #"MicrosoftEdgeElevationService"                 # Disables one of edge  service 
    #"edgeupdatem"                                   # disbales another one of update service (disables edgeupdatem)                          
    "SEMgrSvc"                                      #Disables Payments and NFC/SE Manager (Manages payments and Near Field Communication (NFC) based secure elements)
    #"PNRPsvc"                                      # Disables peer Name Resolution Protocol ( some peer-to-peer and collaborative applications, such as Remote Assistance, may not function, Discord will still work)
    #"p2psvc"                                       # Disbales Peer Name Resolution Protocol(nables multi-party communication using Peer-to-Peer Grouping.  If disabled, some applications, such as HomeGroup, may not function. Discord will still work)
    #"p2pimsvc"                                     # Disables Peer Networking Identity Manager (Peer-to-Peer Grouping services may not function, and some applications, such as HomeGroup and Remote Assistance, may not function correctly.Discord will still work)
    "PerfHost"                                      #Disables  remote users and 64-bit processes to query performance .
    "BcastDVRUserService_48486de"                   #Disables GameDVR and Broadcast   is used for Game Recordings and Live Broadcasts
    "CaptureService_48486de"                        #Disables ptional screen capture functionality for applications that call the Windows.Graphics.Capture API.  
    "cbdhsvc_48486de"                               #Disables   cbdhsvc_48486de (clipboard service it disables)
    #"BluetoothUserService_48486de"                  #disbales BluetoothUserService_48486de (The Bluetooth user service supports proper functionality of Bluetooth features relevant to each user session.)
    "WpnService"                                    #Disables WpnService (Push Notifications may not work )
    #"StorSvc"                                       #Disables StorSvc (usb external hard drive will not be reconised by windows)
    "RtkBtManServ"                                  #Disables Realtek Bluetooth Device Manager Service
    "QWAVE"                                         #Disables Quality Windows Audio Video Experience (audio and video might sound worse)
     #Hp services
    "HPAppHelperCap"
    "HPDiagsCap"
    "HPNetworkCap"
    "HPSysInfoCap"
    "HpTouchpointAnalyticsService"
    #hyper-v services
     "HvHost"                          
    "vmickvpexchange"
    "vmicguestinterface"
    "vmicshutdown"
    "vmicheartbeat"
    "vmicvmsession"
    "vmicrdv"
    "vmictimesync" 
    # Services which cannot be disabled
    #"WdNisSvc"
)

foreach ($service in $services) {
    #-ErrorAction SilentlyContinue is so it doesn't write an error to stdout if a service doesn't exist

    Write-Host  -ForegroundColor Green "Setting $service StartupType to Manual"
    Get-Service -Name $service -ErrorAction SilentlyContinue | Set-Service -StartupType Manual
}

Write-Host  -ForegroundColor Green "Disabling Bing Search in Start Menu..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "BingSearchEnabled" -Type DWord -Value 0
    Write-Host  -ForegroundColor Green "Disabling Cortana"
    Set-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" -Name "CortanaConsent" -Type DWord -Value 0
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
    }
    Write-Host  -ForegroundColor Green "Hiding Search Box / Button..."
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Type DWord -Value 0


#Security Windows Update
<#
 Write-Host  -ForegroundColor Green "Disabling driver offering through Windows Update..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata" -Name "PreventDeviceMetadataFromNetwork" -Type DWord -Value 1
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontPromptForWindowsUpdate" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DontSearchWindowsUpdate" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching" -Name "DriverUpdateWizardWuSearchEnabled" -Type DWord -Value 0
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -Name "ExcludeWUDriversInQualityUpdate" -Type DWord -Value 1
    Write-Host  -ForegroundColor Green "Disabling Windows Update automatic restart..."
    If (!(Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU")) {
        New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Force | Out-Null
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "NoAutoRebootWithLoggedOnUsers" -Type DWord -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" -Name "AUPowerManagement" -Type DWord -Value 0
    Write-Host  -ForegroundColor Green "Disabled driver offering through Windows Update"

#>


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

}


Write-Host -ForegroundColor Green "[+] Function Set-RunOnceScript"
function Set-RunOnceScript {
    # setup RunOnce to execute provisioning.ps1 script
    # disable privacy experience
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/provisioning.ps1"
    $destinationFolder = "C:\Windows\Setup\Scripts"
    $destinationPath = Join-Path -Path $destinationFolder -ChildPath "provisioning.ps1"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath

    $settings = @(
        [PSCustomObject]@{
            Path  = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            Name  = "execute_provisioning"
            Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\provisioning.ps1"
        },
        [PSCustomObject]@{
            Path  = "SOFTWARE\Policies\Microsoft\Windows\OOBE"
            Name  = "DisablePrivacyExperience"
            Value = 1
        }
    )

    foreach ($setting in $settings) {
        # Öffne den angegebenen Registrierungsschlüssel (oder erstelle ihn, falls er nicht existiert)
        $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
        if ($null -eq $registry) {
            $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Path)
        }
        # Setze die Werte für den Registrierungsschlüssel
        $registry.SetValue($setting.Name, $setting.Value)
        $registry.Close()
    }
}


    Write-Host -ForegroundColor Green "[+] Function Set-Chocolatey"
    function Set-Chocolatey {
    # add tcp rout to oneICT Server
    Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "195.49.62.108 chocoserver"
    
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    [Environment]::SetEnvironmentVariable("Path", $env:Path + "$ENV:ALLUSERSPROFILE\chocolatey\bin", "Machine")
    C:\ProgramData\chocolatey\bin\choco.exe install chocolatey-core.extension -y --no-progress --ignore-checksums
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'oneICT'" --source="'https://chocoserver:8443/repository/ChocolateyInternal/'" --allow-self-service --user="'chocolatey'" --password="'wVGULoJGh1mxbRpChJQV'" --priority=1
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'Chocolatey'" --source="'https://chocolatey.org/api/v2/'" --allow-self-service --priority=2
    # C:\ProgramData\chocolatey\bin\choco.exe install chocolateygui -y --source="'oneICT'" --no-progress
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowGlobalConfirmation
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowEmptyChecksums
    
    $manufacturer = (gwmi win32_computersystem).Manufacturer
    Write-Host "Das ist ein $manufacturer PC"
    
    if ($manufacturer -match "VMware") {
    Write-Host "Installing VMware tools..."
    C:\ProgramData\chocolatey\bin\choco.exe install vmware-tools -y --no-progress --ignore-checksums
    }

    # Zertifikat
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/choclatey.cer"
    $tempPath = "$env:TEMP\choclatey.cer"
    Invoke-WebRequest -Uri $url -OutFile $tempPath
    # Öffnen des Zertifikatspeichers für "TrustedPeople" unter "LocalMachine"
    $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
    $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($tempPath)
    $certStore.Add($cert)
    $certStore.Close()
    Remove-Item -Path $tempPath
    Write-Host "Das Zertifikat wurde erfolgreich zu TrustedPeople unter LocalMachine hinzugefuegt."

    # Scheduled Task for "choco upgrade -y"
    $schtaskName = "Chocolatey Upgrade All"
    $schtaskDescription = "Upgade der mit Chocolaty verwalteten Paketen. V$($Version)"
    $trigger1 = New-ScheduledTaskTrigger -AtStartup
    $trigger2 = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Wednesday -At 8pm
    $principal= New-ScheduledTaskPrincipal -UserId 'SYSTEM'
    $action = New-ScheduledTaskAction -Execute "C:\ProgramData\chocolatey\choco.exe" -Argument 'upgrade all -y'
    $settings= New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $schtaskName -Trigger $trigger1,$trigger2 -Action $action -Principal $principal -Settings $settings -Description $schtaskDescription -Force


    }

    Write-Host -ForegroundColor Green "[+] Function DisableIPv6"
    function DisableIPv6 {
    # Disabling IPv6
    write-host ""
    write-host "Disabling IPv6 ..." -ForegroundColor green
    write-host ""
    Disable-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6'
    # write-host "============IPv6 Status============" -ForegroundColor Magenta
    get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' | format-table -AutoSize -Property Name, Enabled 
    }

Write-Host -ForegroundColor Green "[+] Step-KeyboardLanguage"
function Step-KeyboardLanguage {

    Write-Host "Setting Keyboard and Language to German (Switzerland)"

    Set-WinUILanguageOverride -Language "de-CH"
    Set-WinUserLanguageList -LanguageList "de-CH" -Force
    Set-WinSystemLocale -SystemLocale "de-CH"
    Set-WinHomeLocation -GeoId 19  # 19 corresponds to Switzerland
    Set-Culture -CultureInfo "de-CH"

    $languageList = New-WinUserLanguageList -Language "de-CH"
    Set-WinUserLanguageList $languageList -Force

    Set-WinUILanguageOverride -Language "de-CH"
    Set-WinDefaultInputMethodOverride -InputTip "0407:00000807"  # Swiss German Keyboard
}

Write-Host -ForegroundColor Green "[+] Step-oobeSetDisplay"
function Step-oobeSetDisplay {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetDisplay -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Verify the Display Resolution and Scale is set properly'
        Start-Process 'ms-settings:display' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeSetRegionLanguage"
function Step-oobeSetRegionLanguage {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetRegionLanguage -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Setting Region Language to de-CH'
        Set-WinSystemLocale de-CH
        Set-WinHomeLocation -GeoId 19  # 19 corresponds to Switzerland
        Set-Culture de-CH
        Set-WinUserLanguageList de-CH -Force
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeSetDateTime"
function Step-oobeSetDateTime {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetDateTime -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Setting time zone to W. Europe Standard Time'
        Write-Host -ForegroundColor Yellow 'If this is not configured properly, Certificates and Domain Join may fail'
        Set-TimeZone -Name 'W. Europe Standard Time' -PassThru
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeExecutionPolicy"
function Step-oobeExecutionPolicy {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        if ((Get-ExecutionPolicy) -ne 'RemoteSigned') {
            Write-Host -ForegroundColor Cyan 'Set-ExecutionPolicy RemoteSigned'
            Set-ExecutionPolicy RemoteSigned -Force
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobePackageManagement"
function Step-oobePackageManagement {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        if (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'}) {
            Write-Host -ForegroundColor Cyan 'PowerShellGet 2.2.5 or greater is installed'
        }
        else {
            Write-Host -ForegroundColor Cyan 'Install-Package PackageManagement,PowerShellGet'
            Install-Package -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Confirm:$false -Source PSGallery | Out-Null
    
            Write-Host -ForegroundColor Cyan 'Import-Module PackageManagement,PowerShellGet'
            Import-Module PackageManagement,PowerShellGet -Force
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeTrustPSGallery"
function Step-oobeTrustPSGallery {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $PSRepository = Get-PSRepository -Name PSGallery
        if ($PSRepository)
        {
            if ($PSRepository.InstallationPolicy -ne 'Trusted')
            {
                Write-Host -ForegroundColor Cyan 'Set-PSRepository PSGallery Trusted'
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeInstallModuleAutopilot"
function Step-oobeInstallModuleAutopilot {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Module AzureAD,Microsoft.Graph.Intune,WindowsAutopilotIntune'
            Install-Module WindowsAutopilotIntune -Force
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeInstallModuleAzureAd"
function Step-oobeInstallModuleAzureAd {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Import-Module AzureAD -PassThru -ErrorAction Ignore
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Module AzureAD'
            Install-Module AzureAD -Force
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeInstallScriptAutopilot"
function Step-oobeInstallScriptAutopilot {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Get-InstalledScript -Name Get-WindowsAutoPilotInfo -ErrorAction SilentlyContinue
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Script Get-WindowsAutoPilotInfo'
            Install-Script -Name Get-WindowsAutoPilotInfo -Force
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeRegisterAutopilot"
function Step-oobeRegisterAutopilot {
    [CmdletBinding()]
    param (
        [System.String]
        $Command
    )
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRegisterAutopilot -eq $true)) {
        Step-oobeInstallModuleAutopilot
        Step-oobeInstallModuleAzureAd
        Step-oobeInstallScriptAutopilot

        Write-Host -ForegroundColor Cyan 'Registering Device in Autopilot in new PowerShell window ' -NoNewline
        $AutopilotProcess = Start-Process PowerShell.exe -ArgumentList "-Command $Command" -PassThru
        Write-Host -ForegroundColor Green "(Process Id $($AutopilotProcess.Id))"
        Return $AutopilotProcess
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeRemoveAppxPackage"
function Step-oobeRemoveAppxPackage {
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRemoveAppxPackage -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Removing Appx Packages'
        foreach ($Item in $Global:oobeCloud.oobeRemoveAppxPackageName) {
            if (Get-Command Get-AppxProvisionedPackage) {
                Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -Match $Item} | ForEach-Object {
                    Write-Host -ForegroundColor DarkGray $_.DisplayName
                    if ((Get-Command Remove-AppxProvisionedPackage).Parameters.ContainsKey('AllUsers')) {
                        Try
                        {
                            $null = Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $_.PackageName
                        }
                        Catch
                        {
                            Write-Warning "AllUsers Appx Provisioned Package $($_.PackageName) did not remove successfully"
                        }
                    }
                    else {
                        Try
                        {
                            $null = Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName
                        }
                        Catch
                        {
                            Write-Warning "Appx Provisioned Package $($_.PackageName) did not remove successfully"
                        }
                    }
                }
            }
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeAddCapability"
function Step-oobeAddCapability {
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeAddCapability -eq $true)) {
        Write-Host -ForegroundColor Cyan "Add-WindowsCapability"
        foreach ($Item in $Global:oobeCloud.oobeAddCapabilityName) {
            $WindowsCapability = Get-WindowsCapability -Online -Name "*$Item*" -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'}
            if ($WindowsCapability) {
                foreach ($Capability in $WindowsCapability) {
                    Write-Host -ForegroundColor DarkGray $Capability.DisplayName
                    $Capability | Add-WindowsCapability -Online | Out-Null
                }
            }
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeUpdateDrivers"
function Step-oobeUpdateDrivers {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeUpdateDrivers -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Updating Windows Drivers'
        if (!(Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore)) {
            try {
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate -Force
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Driver Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            Start-Process PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot" -Wait
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeUpdateWindows"
function Step-oobeUpdateWindows {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeUpdateWindows -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Updating Windows'
        if (!(Get-Module PSWindowsUpdate -ListAvailable)) {
            try {
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate -Force
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Windows Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            #Write-Host -ForegroundColor DarkCyan 'Add-WUServiceManager -MicrosoftUpdate -Confirm:$false'
            Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
            #Write-Host -ForegroundColor DarkCyan 'Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot'
            #Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot -NotTitle 'Malicious'
            #Write-Host -ForegroundColor DarkCyan 'Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot'
            Start-Process PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -NotTitle 'Preview' -NotKBArticleID 'KB890830','KB5005463','KB4481252'" -Wait
        }
    }
}

Write-Host -ForegroundColor Green "[+] Invoke-Webhook"
function Invoke-Webhook {
    $BiosSerialNumber = Get-MyBiosSerialNumber
    $ComputerManufacturer = Get-MyComputerManufacturer
    $ComputerModel = Get-MyComputerModel
    
    $URI = 'https://XXXX.webhook.office.com/webhookb2/YYYY'
    $JSON = @{
        "@type"    = "MessageCard"
        "@context" = "<http://schema.org/extensions>"
        "title"    = 'OSDCloud Information'
        "text"     = "The following client has been successfully deployed:<br>
                    BIOS Serial Number: **$($BiosSerialNumber)**<br>
                    Computer Manufacturer: **$($ComputerManufacturer)**<br>
                    Computer Model: **$($ComputerModel)**"
        } | ConvertTo-JSON
        
        $Params = @{
        "URI"         = $URI
        "Method"      = 'POST'
        "Body"        = $JSON
        "ContentType" = 'application/json'
        }
        Invoke-RestMethod @Params | Out-Null
}

Write-Host -ForegroundColor Green "[+] Step-oobeRestartComputer"
function Step-oobeRestartComputer {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRestartComputer -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Build Complete!'
        Write-Warning 'Device will restart in 30 seconds.  Press Ctrl + C to cancel'
        Stop-Transcript
        Start-Sleep -Seconds 30
        Restart-Computer
    }
}

Write-Host -ForegroundColor Green "[+] Step-EmbeddedProductKey"
function Step-EmbeddedProductKey {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.EmbeddedProductKey -eq $true)) {
        Write-Host -ForegroundColor Green "Get embedded product key"
        $Key = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey
        If ($Key) {
            Write-Host -ForegroundColor Green "Installing embedded product key"
            Invoke-Command -ScriptBlock {& 'cscript.exe' "$env:windir\system32\slmgr.vbs" '/ipk' "$($Key)"}
            Start-Sleep -Seconds 5

            Write-Host -ForegroundColor Green "Activating embedded product key"
            Invoke-Command -ScriptBlock {& 'cscript.exe' "$env:windir\system32\slmgr.vbs" '/ato'}
            Start-Sleep -Seconds 5
        }
        Else {
            Write-Host -ForegroundColor Red 'No embedded product key found.'
        }
    }
}

Write-Host -ForegroundColor Green "[+] Step-oobeStopComputer"
function Step-oobeStopComputer {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeStopComputer -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Build Complete!'
        Write-Warning 'Device will shutdown in 30 seconds. Press Ctrl + C to cancel'
        Stop-Transcript
        Start-Sleep -Seconds 30
        Stop-Computer
    }
}

Write-Host -ForegroundColor Green "[+] Set-DefaultUserLanguageAndKeyboard"
function Set-DefaultUserLanguageAndKeyboard {
    # Pfad zur ntuser.dat des Default Users
    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" # Virtueller Registrierungspfad
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" # PowerShell Pfad

    # Sicherstellen, dass der Registry Hive nicht bereits geladen ist
    if (Test-Path -Path $VirtualRegistryPath_software) {
        reg unload $VirtualRegistryPath_defaultuser | Out-Null
        Start-Sleep -Seconds 1
    }
    
    # Laden des Default User Registry Hive
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    # Sprache und Tastaturlayout setzen
    Write-Host "Setting Keyboard and Language to German (Switzerland) for Default User"
    
    # Set-WinUILanguageOverride und andere Cmdlets direkt funktionieren nicht im Kontext des Default User Registry Hive,
    # aber du kannst die entsprechenden Registrierungswerte manuell setzen.

    Set-ItemProperty -Path "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\RunOnce" `
                     -Name "SetLanguageAndKeyboard" `
                     -Value 'powershell -command "& {Set-WinUILanguageOverride -Language \"de-CH\"; Set-WinUserLanguageList -LanguageList \"de-CH\" -Force; Set-WinSystemLocale -SystemLocale \"de-CH\"; Set-WinHomeLocation -GeoId 19; Set-Culture -CultureInfo \"de-CH\"; Set-WinUILanguageOverride -Language \"de-CH\"; Set-WinDefaultInputMethodOverride -InputTip \"0407:00000807\"}"'

    # Registry Hive entladen
    reg unload $VirtualRegistryPath_defaultuser | Out-Null

    Write-Host "Default User Language and Keyboard settings have been set."
}
