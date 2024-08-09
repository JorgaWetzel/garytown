# *** Festlegen von Pfad und Name der geplanten Aufgabe und des Skripts ***
Write-Host "*** Festlegen von Pfad und Name der geplanten Aufgabe und des Skripts ***"
$RegistryPath = "HKCU:\SOFTWARE\OSDCloud"  # Verwendung von HKEY_CURRENT_USER für benutzerspezifische Einstellungen
$ScriptPath = "$env:UserProfile\Documents\OSDCloud\PostActionsUser.ps1"  # Benutzerzugänglicher Pfad
$ScheduledTaskName = 'OSDCloudPostActionUser'
$ExecutionFlag = "PostActionExecutedUser"

# *** Sicherstellen, dass der Pfad existiert ***
Write-Host "*** Sicherstellen, dass der Pfad existiert ***"
if (!(Test-Path -Path ($ScriptPath | split-path))) {
    Write-Host "Pfad existiert nicht, erstelle Pfad..."
    New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Pfad existiert bereits."
}

# *** Erstellen des Registry-Eintrags, falls dieser noch nicht existiert ***
Write-Host "*** Erstellen des Registry-Eintrags, falls dieser noch nicht existiert ***"
if (-not (Test-Path $RegistryPath)) {
    Write-Host "Registry-Eintrag existiert nicht, erstelle Eintrag..."
    New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
} else {
    Write-Host "Registry-Eintrag existiert bereits."
}

# *** Erstellen einer geplanten Aufgabe, die das Skript bei der Anmeldung ausführt ***
Write-Host "*** Erstellen einer geplanten Aufgabe, die das Skript bei der Anmeldung ausführt ***"
$action = (New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath")
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal $env:USERNAME
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
Register-ScheduledTask $ScheduledTaskName -InputObject $task
Write-Host "Geplante Aufgabe wurde erstellt."

# *** Zweites Skript, das bei Benutzeranmeldung ausgeführt wird ***
Write-Host "*** Zweites Skript, das bei Benutzeranmeldung ausgeführt wird ***"
$PostActionScript = @'
# *** Transkript erstellen ***
$Transcript = "PostActionsUser.log"
$TranscriptPath = "C:\OSDCloud\Logs"
if (-not (Test-Path $TranscriptPath)) {
    Write-Host "Erstelle Transkript-Verzeichnis..."
    New-Item -ItemType Directory -Path $TranscriptPath -Force | Out-Null
} else {
    Write-Host "Transkript-Verzeichnis existiert bereits."
}
$null = Start-Transcript -Path (Join-Path $TranscriptPath $Transcript) -ErrorAction Ignore

# *** Überprüfen, ob die PostAction bereits ausgeführt wurde ***
$RegistryPath = "HKCU:\SOFTWARE\OSDCloud"
$ExecutionFlag = "PostActionExecuted"

if (-not (Test-Path -Path $RegistryPath)) {
    Write-Host "Erstelle Registry-Pfad..."
    New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
}

$Executed = Get-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -ErrorAction SilentlyContinue
if ($Executed -ne $null -and $Executed.$ExecutionFlag -eq $true) {
    Write-Output "PostActions wurden bereits für diesen Benutzer ausgeführt."
    Exit
}

# *** Warten auf den Desktop-Explorer (explorer.exe) ***
Write-Host "*** Warten auf den Desktop-Explorer (explorer.exe) ***"
while (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Write-Host "Warten, bis der Desktop vollständig geladen ist..."
    Start-Sleep -Seconds 30
}

# *** Lader der Funktionen ***
Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)

# *** Transkript für das PostAction-Skript erstellen ***
Write-Host "*** Transkript für das PostAction-Skript erstellen ***"
$Transcript = "PostActionsUser.log"
$TranscriptPath = "C:\OSDCloud\Logs"
if (-not (Test-Path $TranscriptPath)) {
    Write-Host "Erstelle Transkript-Verzeichnis..."
    New-Item -ItemType Directory -Path $TranscriptPath -Force | Out-Null
}
$null = Start-Transcript -Path (Join-Path $TranscriptPath $Transcript) -ErrorAction Ignore

# *** Pfade zu den Anwendungen überprüfen ***
Write-Host "*** Pfade zu den Anwendungen überprüfen ***"
$OutlookPath = "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE"
$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$FirefoxPath = "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"

# *** Warten, bis OUTLOOK.EXE existiert ***
Write-Host "*** Warten, bis OUTLOOK.EXE existiert ***"
while (-not (Test-Path $OutlookPath)) {
    Write-Host "Warten auf OUTLOOK.EXE..."
    Start-Sleep -Seconds 30
}

# *** Warten, bis Chrome.exe existiert ***
Write-Host "*** Warten, bis Chrome.exe existiert ***"
while (-not (Test-Path $ChromePath)) {
    Write-Host "Warten auf Chrome.exe..."
    Start-Sleep -Seconds 30
}

# *** Warten, bis Firefox.lnk existiert ***
Write-Host "*** Warten, bis Firefox.lnk existiert ***"
while (-not (Test-Path $FirefoxPath)) {
    Write-Host "Warten auf Firefox.lnk..."
    Start-Sleep -Seconds 30
}


# *** syspin herunterladen und Verknüpfungen anheften ***
Write-Host "*** syspin herunterladen und Verknüpfungen anheften ***"
$url32 = 'http://www.technosys.net/download.aspx?file=syspin.exe'
$output = "$env:TEMP\syspin.exe"
Invoke-WebRequest -Uri $url32 -OutFile $output

Write-Host "*** Verknüpfungen an die Taskleiste und Startmenü anheften ***"
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\WINWORD.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\EXCEL.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Microsoft Office\root\Office16\POWERPNT.EXE" 5386
& "$env:TEMP\syspin.exe" "C:\Program Files\Google\Chrome\Application\chrome.exe" 5386

& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Word.lnk" 51201
& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Excel.lnk" 51201
& "$env:TEMP\syspin.exe" "$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Firefox.lnk" 51201

# *** Entfernen unerwünschter Apps von der Taskleiste ***
Write-Host "*** Entfernen unerwünschter Apps von der Taskleiste ***"
function Remove-AppFromTaskbar($appname) {
    Write-Host "Entfernen von $appname von der Taskleiste ..."
    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object { $_.Name -eq $appname }).Verbs() | Where-Object { $_.Name.replace('&', '') -match 'Unpin from taskbar' -or $_.Name.replace('&','') -match 'Von Taskleiste lösen'} | ForEach-Object { $_.DoIt(); $exec = $true }
}

# Remove-AppFromTaskbar 'HP Support Assistant'
# Remove-AppFromTaskbar 'Microsoft Teams'
Remove-AppFromTaskbar 'Microsoft Store'

<#
# *** UserFTA Konfiguration herunterladen und installieren ***
Write-Host "*** UserFTA Konfiguration herunterladen und installieren ***"
$zielVerzeichnis = "C:\OSDCloud\UserFTA"
if (-not (Test-Path -Path $zielVerzeichnis)) {
    Write-Host "Erstelle Zielverzeichnis für UserFTA..."
    New-Item -ItemType Directory -Path $zielVerzeichnis -Force
} else {
    Write-Host "Zielverzeichnis für UserFTA existiert bereits."
}
$dateiUrl = "https://github.com/JorgaWetzel/garytown/raw/master/Dev/CloudScripts/UserFTA.zip"
$speicherPfad = "$zielVerzeichnis\UserFTA.zip"
Invoke-WebRequest -Uri $dateiUrl -OutFile $speicherPfad
Expand-Archive -Path $speicherPfad -DestinationPath $zielVerzeichnis -Force
$installSkriptPfad = "$zielVerzeichnis\install.ps1"

if (Test-Path -Path $installSkriptPfad) {
    Write-Host "Installiere UserFTA..."
    & $installSkriptPfad
} else {
    Write-Error "Das Installationsskript wurde nicht gefunden."
}
#>

# *** Ausführen von Winget-Befehlen ***
Write-Host "*** Ausführen von Winget-Befehlen ***"
Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion (WindowsPhase Phase)"

# powershell Invoke-Expression -Command (Invoke-RestMethod -Uri pwsh.live)
osdcloud-InstallWinGet
if (Get-Command 'WinGet' -ErrorAction SilentlyContinue) {
    Write-Host -ForegroundColor Green '[+] winget upgrade --all --accept-source-agreements --accept-package-agreements'
    Write-Host -ForegroundColor Green '[+] winget install company portal (unternehmenbsportal)'
    winget install --id "9WZDNCRFJ3PZ" --exact --source msstore --accept-package-agreements --accept-source-agreements
}

# *** Setzen des Ausführungsflags in der Registry ***
Write-Host "*** Setzen des Ausführungsflags in der Registry ***"
New-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -PropertyType DWORD -Value 1 -Force | Out-Null
Write-Host "Ausführungsflag wurde gesetzt."

# *** Transkript beenden ***
Write-Host "*** Transkript beenden ***"
Stop-Transcript
'@

# *** Skript in Datei speichern ***
Write-Host "*** Skript in Datei speichern ***"
$PostActionScript | Out-File -FilePath $ScriptPath -Force

# *** Transkript beenden ***
Write-Host "*** Transkript beenden ***"
Stop-Transcript
