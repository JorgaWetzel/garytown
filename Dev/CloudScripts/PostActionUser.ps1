# Transkript erstellen
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PostActionsUser.log"
$TranscriptPath = "C:\OSDCloud\Logs"
if (-not (Test-Path $TranscriptPath)) {
    New-Item -ItemType Directory -Path $TranscriptPath -Force | Out-Null
}
$null = Start-Transcript -Path (Join-Path $TranscriptPath $Transcript) -ErrorAction Ignore

# Pfad und Name der geplanten Aufgabe und des Skripts
$RegistryPath = "HKCU:\SOFTWARE\OSDCloud"  # Verwendung von HKEY_CURRENT_USER für benutzerspezifische Einstellungen
$ScriptPath = "$env:UserProfile\Documents\OSDCloud\PostActionsUser.ps1"  # Benutzerzugänglicher Pfad
$ScheduledTaskName = 'OSDCloudPostActionUser'
$ExecutionFlag = "PostActionExecutedUser"

# Sicherstellen, dass der Pfad existiert
if (!(Test-Path -Path ($ScriptPath | split-path))) {
    New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null
}

# Registry-Eintrag erstellen, wenn er nicht existiert
if (-not (Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
}

# Geplante Aufgabe erstellen
$action = (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath")
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal $env:USERNAME
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
Register-ScheduledTask $ScheduledTaskName -InputObject $task

# Zweites Skript, das bei Benutzeranmeldung ausgeführt wird
$PostActionScript = @'

# Überprüfen, ob die PostAction bereits ausgeführt wurde
$RegistryPath = "HKCU:\SOFTWARE\OSDCloud"
$ExecutionFlag = "PostActionExecuted"

if (-not (Test-Path -Path $RegistryPath)) {
    New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
}

$Executed = Get-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -ErrorAction SilentlyContinue
if ($Executed -ne $null -and $Executed.$ExecutionFlag -eq $true) {
    Write-Output "PostActions wurden bereits für diesen Benutzer ausgeführt."
    Exit
}

# Transkript für das PostAction-Skript erstellen
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PostActionsUser.log"
$TranscriptPath = "C:\OSDCloud\Logs"
if (-not (Test-Path $TranscriptPath)) {
    New-Item -ItemType Directory -Path $TranscriptPath -Force | Out-Null
}
$null = Start-Transcript -Path (Join-Path $TranscriptPath $Transcript) -ErrorAction Ignore

iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)

Step-KeyboardLanguage

# Pfade zu den Anwendungen
$OutlookPath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$FirefoxPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"

# Warten, bis OUTLOOK.EXE existiert
while (-not (Test-Path $OutlookPath)) {
    Start-Sleep -Seconds 30
}

# Warten, bis Chrome.exe existiert
while (-not (Test-Path $ChromePath)) {
    Start-Sleep -Seconds 30
}

# Warten, bis Firefox.lnk existiert
while (-not (Test-Path $FirefoxPath)) {
    Start-Sleep -Seconds 30
}


$provisioning = [System.IO.DirectoryInfo]"$env:UserProfile\Documents\OSDCloud\provisioning"
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

# UserFTA
$zielVerzeichnis = "C:\OSDCloud\UserFTA"
if (-not (Test-Path -Path $zielVerzeichnis)) {
    New-Item -ItemType Directory -Path $zielVerzeichnis -Force
}
$dateiUrl = "https://github.com/JorgaWetzel/garytown/raw/master/Dev/CloudScripts/UserFTA.zip"
$speicherPfad = "$zielVerzeichnis\UserFTA.zip"
Invoke-WebRequest -Uri $dateiUrl -OutFile $speicherPfad
Expand-Archive -Path $speicherPfad -DestinationPath $zielVerzeichnis -Force
$installSkriptPfad = "$zielVerzeichnis\install.ps1"

if (Test-Path -Path $installSkriptPfad) {
    & $installSkriptPfad
} else {
    Write-Error "Das Installationsskript wurde nicht gefunden."
}

# Setzen des Ausführungsflags
New-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -PropertyType DWORD -Value 1 -Force | Out-Null

# Transkript beenden
Stop-Transcript

'@

# Skript in Datei speichern
$PostActionScript | Out-File -FilePath $ScriptPath -Force

# Transkript beenden
Stop-Transcript
