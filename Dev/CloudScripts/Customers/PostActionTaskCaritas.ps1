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
		
	# --- Ende Administrator-Sektion ---

    # Setup oneICT Chocolatey Framework
    Write-Host -ForegroundColor Gray "**Running Chocolatey Framework**"
    Set-Chocolatey

    $env:Path += ";C:\ProgramData\chocolatey\bin"

    
    # Installation von Chocolatey-Software
    Write-Host -ForegroundColor Green "Office wird installiert"
    choco.exe upgrade office365business --params "/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE" -y --no-progress --ignore-checksums

    Write-Host -ForegroundColor Green "Standard Apps werden installiert"
    $packages = "adobereader","microsoft-teams-new-bootstrapper"
    $packages | ForEach-Object {
        choco upgrade $_ -y --no-progress --ignore-checksums
    }


    # Prevent Outlook (new) and Dev Home from installing
	$Keys = @(
	  'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate',
	  'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate',
	  'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\*Update'
	)
	foreach ($k in $Keys) {
		if (Test-Path $k) { Remove-Item $k -Recurse -Force }
	}

    # Disable Windows Hello
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f
    reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork" /v DisablePostLogonProvisioning /t REG_DWORD /d 0 /f  

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
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" />
        <taskbar:DesktopApp DesktopApplicationLinkPath="C:\Program Files\Microsoft Office\root\Office16\ONENOTE.EXE" />
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


    # Get-AppxPackage | select @{n='name';e={"$($_.PackageFamilyName)!app"}} | ?{$_.name -like "**"}
    # Import-StartLayout
    $apps = 
    "Microsoft.Windows.Explorer",
    "Microsoft.Windows.ControlPanel",
    "Microsoft.WindowsCalculator_8wekyb3d8bbwe!app",
    "Microsoft.Paint_8wekyb3d8bbwe!app",
    "Microsoft.ScreenSketch_8wekyb3d8bbwe!app",
    "Microsoft.MicrosoftEdge.Stable_8wekyb3d8bbwe!app",
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

# Prevent Outlook new and Dev Home from installing for new users
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" | %{
    ri $_ -force
}

# Systemweites Standarddateiformat für Office auf Office Open XML setzen
$officeRegistryPath = "HKLM:\SOFTWARE\Microsoft\Office\Common"

# Sicherstellen, dass der Registry-Pfad existiert
if (-not (Test-Path $officeRegistryPath)) {
    New-Item -Path $officeRegistryPath -Force | Out-Null
}
# Registry-Wert für Standarddateiformate auf "Office Open XML-Formate" setzen
Set-ItemProperty -Path $officeRegistryPath -Name "DefaultSaveFormat" -Value "OfficeOpenXML"


# Configure power settings
# Disable sleep, hibernate and monitor standby on AC
"powercfg /x -monitor-timeout-ac 0",
"powercfg /x -standby-timeout-ac 0",
"powercfg /x -hibernate-timeout-ac 0" | % {
    cmd /c $_
}


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

# Datei schreiben
Set-Content -Path $ScriptPath -Value $PostActionScript -Force -Encoding UTF8

# Skript jetzt sofort ausführen
& $ScriptPath   # oder:  Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" -WindowStyle Hidden -Wait
