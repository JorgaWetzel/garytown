$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath = "$env:ProgramData\OSDCloud\PostActions.ps1"

if (!(Test-Path -Path ($ScriptPath | Split-Path))) {
    New-Item -Path ($ScriptPath | Split-Path) -ItemType Directory -Force | Out-Null
}

# Schreibe das PostActionScript in die Datei
$PostActionScript = @'

$ScheduledTaskName = 'OSDCloudPostAction'
$ScriptPath = "$env:ProgramData\OSDCloud\PostActions.ps1"

# Überprüfe, ob der geplante Task existiert; falls nicht, erstelle ihn für den Start bei Systemstart
if (!(Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue)) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -WindowStyle Hidden"
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    $principal = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
    Register-ScheduledTask $ScheduledTaskName -InputObject $task -User SYSTEM
}

try {
    # Start des Transkripts
    $Transcript = "PostActions.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

    # Warte auf Netzwerk
    $ProgressPreference_bk = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    do {
        $ping = Test-NetConnection '8.8.8.8' -InformationLevel Quiet
        if (!$ping) {
            cls
            'Warte auf die Internetverbindung' | Out-Host
            Start-Sleep -Seconds 5
        }
    } while (!$ping)
    $ProgressPreference = $ProgressPreference_bk

    #region functions
    iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
    iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
    #endregion

    # Setup oneICT Chocolatey Framework
    Write-Host -ForegroundColor Gray "**Running Chocolatey Framework**"
    Set-Chocolatey

    # Installation von Chocolatey-Software
    Write-Host -ForegroundColor Green "Office wird installiert"
    choco.exe upgrade office365business --params "/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE" -y --no-progress --ignore-checksums

    Write-Host -ForegroundColor Green "Standard Apps werden installiert"
    $packages = "TeamViewer","googlechrome","firefox","adobereader","microsoft-teams-new-bootstrapper","7zip.install","vlc","jre8","powertoys","onedrive","Pdf24","vcredist140","zoom","notepadplusplus.install","onenote","onedrive"
    $packages | ForEach-Object {
        choco upgrade $_ -y --no-progress --ignore-checksums
    }

    # Prevent Outlook (new) and Dev Home from installing
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" | %{
        Remove-Item $_ -Force -ErrorAction SilentlyContinue
    }

    

    Write-Host "**Taskbar Layout**"
    # Show packagedAppId for Windows store apps:
    # Get-AppxPackage | select @{n='name';e={"$($_.PackageFamilyName)!app"}} | ?{$_.name -like "**"}

    $taskbar_layout = @"
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
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.Windows.Explorer" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" />
        <taskbar:DesktopApp DesktopApplicationID="Microsoft.OutlookForWindows_8wekyb3d8bbwe!app" />
        <taskbar:DesktopApp DesktopApplicationID="MSTeams_8wekyb3d8bbwe!app" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE" />
      </taskbar:TaskbarPinList>
    </defaultlayout:TaskbarLayout>
  </CustomTaskbarLayoutCollection>
</LayoutModificationTemplate>
"@

    # Prepare provisioning folder
    #$provisioningFile = [System.IO.FileInfo]"$($env:ProgramData)\provisioning\taskbar_layout.xml"
    $provisioning = [System.IO.FileInfo]"$($env:ProgramData)\provisioning\taskbar_layout.xml"


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
$provisioning = [System.IO.DirectoryInfo]"C:\OSDCloud\Scripts"

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
    $currentScriptPath = Join-Path -Path $provisioning -ChildPath $scriptName

    # Herunterladen, wenn das Skript noch nicht existiert
    if (-not (Test-Path $currentScriptPath)) {
        Write-Host "Herunterladen von $url ..."
        Invoke-WebRequest -Uri $url -OutFile $currentScriptPath
    } else {
        Write-Host "$scriptName existiert bereits."
    }

    # Ausführen des Skripts
    Write-Host "Ausführen von $scriptName ..."
    . $currentScriptPath
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
    "Microsoft.ScreenSketch_8wekyb3d8bbwe!app",
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

    # Remove Desktop Shortcuts
    $Shortcuts2Remove = "Google Chrome.lnk", "VLC media player.lnk", "Adobe Acrobat.lnk", "Firefox.lnk", "PDFCreator.lnk", "TeamViewer.lnk", "Microsoft Edge.lnk", "FileMaker Pro.lnk", "Google Earth.lnk", "LayOut 2023.lnk", "LibreOffice 7.4.lnk", "PDF-XChange Editor.lnk", "SIA-Reader.lnk", "Solibri.lnk", "SonicWall NetExtender.lnk", "Style Builder.lnk", "Zoom.lnk", "Spotify.lnk", "SEH UTN Manager.lnk", "SketchUp 2023.lnk", "Easy Product Finder 2.lnk", "Google Earth Pro.lnk", "Revit 2022 (AirTop1).lnk", "liNear CAD 22 (AirTop1).lnk", "AutoCAD 2022 (AirTop1).lnk", "Abmelden (AirTop1).lnk" 
    $DesktopPaths = @("C:\Users\*\Desktop\*", "C:\Users\*\*\Desktop\*")  # Mehrere Pfade als Array
    try {
        foreach ($DesktopPath in $DesktopPaths) {
            $ShortcutsOnClient = Get-ChildItem $DesktopPath -ErrorAction SilentlyContinue
            foreach ($shortcut in $Shortcuts2Remove) {
                $($ShortcutsOnClient | Where-Object -FilterScript {$_.Name -like "$($shortcut.Split('.')[0])*"}) | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
        Write-Host "Unwanted shortcut(s) removed."
    } catch {
        Write-Error "Error removing shortcut(s)"
    }


# Define the folder paths
$parentFolder = "C:\Program Files\oneICT\EndpointManager"
$folder1 = "$parentFolder\Data"
$folder2 = "$parentFolder\Log"
$folder3 = "C:\Service"

# Create the folders if they do not exist
New-Item -Path $folder1 -ItemType Directory -Force | Out-Null
New-Item -Path $folder2 -ItemType Directory -Force | Out-Null
New-Item -Path $folder3 -ItemType Directory -Force | Out-Null

# Define the permission rule for Everyone
$aclParent = Get-Acl $parentFolder
$acl1 = Get-Acl $folder1
$acl2 = Get-Acl $folder2
$acl3 = Get-Acl $folder3

$everyone = [System.Security.Principal.NTAccount]"Jeder"
$rights = [System.Security.AccessControl.FileSystemRights]::FullControl
$inheritance = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit, [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
$propagation = [System.Security.AccessControl.PropagationFlags]::None
$accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($everyone, $rights, $inheritance, $propagation, [System.Security.AccessControl.AccessControlType]::Allow)

# Add the rule to the ACL of the parent folder and subfolders
$aclParent.AddAccessRule($accessRule)
$acl1.AddAccessRule($accessRule)
$acl2.AddAccessRule($accessRule)
$acl3.AddAccessRule($accessRule)

# Apply the updated ACL to the parent folder and subfolders
Set-Acl -Path $parentFolder -AclObject $aclParent
Set-Acl -Path $folder1 -AclObject $acl1
Set-Acl -Path $folder2 -AclObject $acl2
Set-Acl -Path $folder3 -AclObject $acl3


    # HP Driver Updates
    # Write-Host -ForegroundColor Gray "**Running HP Image Assistant Driver & Firmware Updates**"
    # osdcloud-HPIAExecute

    # Windows Updates
    Write-Host -ForegroundColor Gray "**Running Microsoft Defender Updates**"
    Update-DefenderStack
    Write-Host -ForegroundColor Gray "**Running Microsoft Windows Updates**"
    Start-WindowsUpdate
    Write-Host -ForegroundColor Gray "**Running Microsoft Driver Updates**"
    Start-WindowsUpdateDriver

    # Entfernen von Verzeichnissen
    # cmd /c "RD C:\OSDCloud\OS /S /Q"
    # cmd /c "RD C:\Drivers /S /Q"

    # Beende das Transkript
    $null = Stop-Transcript -ErrorAction Ignore

    # Lösche den geplanten Task, damit das Skript nicht erneut ausgeführt wird
    Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false
}
catch {
    # Fehlerbehandlung
    Write-Error $_
    # Der geplante Task bleibt erhalten und das Skript wird beim nächsten Start erneut ausgeführt
}
'@

$PostActionScript | Out-File -FilePath $ScriptPath -Force -Encoding UTF8

# Führe das Skript sofort aus
& $ScriptPath
