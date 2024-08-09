# Pfad und Name der geplanten Aufgabe und des Skripts
$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath = "$env:ProgramData\OSDCloud\PostActionsUser.ps1"
$ScheduledTaskName = 'OSDCloudPostActionUser'

# Sicherstellen, dass der Pfad existiert
if (!(Test-Path -Path ($ScriptPath | split-path))) {
    New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null
}

# Registry-Eintrag erstellen
New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
New-ItemProperty -Path $RegistryPath -Name "TriggerPostActions" -PropertyType dword -Value 1 | Out-Null

# Geplante Aufgabe erstellen
$action = (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath")
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal "NT AUTHORITY\SYSTEM" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
Register-ScheduledTask $ScheduledTaskName -InputObject $task

# Zweites Skript, das bei Benutzeranmeldung ausgeführt wird
$PostActionScript = @'

# Warten, bis OUTLOOK.EXE existiert
$OutlookPath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
while (-not (Test-Path $OutlookPath)) {
    Start-Sleep -Seconds 30
}

$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"
$urls = @(
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_brave.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_chrome.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_edge.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_firefox.ps1"
)

# Sicherstellen, dass das Verzeichnis existiert
if (-not (Test-Path $provisioning)) {
    New-Item -ItemType Directory -Path $provisioning -Force
}

# Herunterladen und Ausführen der Konfigurationsskripte
foreach ($url in $urls) {
    $scriptName = [System.IO.Path]::GetFileName($url)
    $scriptPath = Join-Path -Path $provisioning -ChildPath $scriptName
    
    # Herunterladen, wenn das Skript noch nicht existiert
    if (-not (Test-Path $scriptPath)) {
        Invoke-WebRequest -Uri $url -OutFile $scriptPath
    }
    
    # Ausführen des Skripts
    . $scriptPath
}

# syspin ["file"] #### or syspin ["file"] "commandstring"
# 5386  : Pin to taskbar
# 5387  : Unpin from taskbar
# 51201 : Pin to start
# 51394 : Unpin to start
# Download syspin.exe
$url32 = 'http://www.technosys.net/download.aspx?file=syspin.exe'
$output = "$env:TEMP\syspin.exe"
Invoke-WebRequest -Uri $url32 -OutFile $output

# Pin the shortcut to the taskbar
# & "$env:TEMP\syspin.exe" "C:\Program Files\Google\Chrome\Application\chrome.exe" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Google\Chrome\Application\chrome.exe" 5386

& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Word.lnk" 51201
& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Excel.lnk" 51201
& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Firefox.lnk" 51201

function Remove-AppFromTaskbar($appname) {
    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object { $_.Name -eq $appname }).Verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from taskbar' -or $_.Name.replace('&','') -match 'Von Taskleiste lösen'} | ForEach-Object { $_.DoIt(); $exec = $true }
}

# Remove-AppFromTaskbar 'HP Support Assistant'
# Remove-AppFromTaskbar 'Microsoft Teams'
Remove-AppFromTaskbar 'Microsoft Store'

# Deaktivieren der geplanten Aufgabe nach der ersten Ausführung
Disable-ScheduledTask -TaskName $ScheduledTaskName
'@

# Skript in Datei speichern
$PostActionScript | Out-File -FilePath $ScriptPath -Force
