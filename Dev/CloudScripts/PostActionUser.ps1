# *** Pfad und Name für das Hauptskript ***
$MainScriptPath = "$env:UserProfile\Documents\OSDCloud\PostActionsUser.ps1"  # Hauptskript
$ScheduledTaskName = 'OSDCloudPostActionUser'

# *** Hauptskript mit deinen Aktionen ***
$PostActionScript = @"
# *** Transkript erstellen ***
$Transcript = 'PostActionsUser.log'
$TranscriptPath = 'C:\OSDCloud\Logs'
if (-not (Test-Path $TranscriptPath)) {
    Write-Host 'Erstelle Transkript-Verzeichnis...'
    New-Item -ItemType Directory -Path $TranscriptPath -Force | Out-Null
} else {
    Write-Host 'Transkript-Verzeichnis existiert bereits.'
}
$null = Start-Transcript -Path (Join-Path $TranscriptPath $Transcript) -ErrorAction Ignore

# *** Überprüfen, ob die PostAction bereits ausgeführt wurde ***
$RegistryPath = 'HKCU:\SOFTWARE\OSDCloud'
$ExecutionFlag = 'PostActionExecutedUser'

if (-not (Test-Path -Path $RegistryPath)) {
    Write-Host 'Erstelle Registry-Pfad...'
    New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null
}

$Executed = Get-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -ErrorAction SilentlyContinue
if ($Executed -ne $null -and $Executed.$ExecutionFlag -eq \$true) {
    Write-Output 'PostActions wurden bereits für diesen Benutzer ausgeführt.'
    Exit
}

# *** Überprüfen von Anwendungen ***
Write-Host '*** Pfade zu den Anwendungen überprüfen ***'
$OutlookPath = 'C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE'
$ChromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$FirefoxPath = "\$env:ALLUSERSPROFILE\Microsoft\Windows\Start Menu\Programs\Firefox.lnk"

# *** Warten, bis OUTLOOK.EXE existiert ***
Write-Host '*** Warten, bis OUTLOOK.EXE existiert ***'
while (-not (Test-Path $OutlookPath)) {
    Write-Host 'Warten auf OUTLOOK.EXE...'
    Start-Sleep -Seconds 30
}

# *** Warten, bis Chrome.exe existiert ***
Write-Host '*** Warten, bis Chrome.exe existiert ***'
while (-not (Test-Path $ChromePath)) {
    Write-Host 'Warten auf Chrome.exe...'
    Start-Sleep -Seconds 30
}

# *** Warten, bis Firefox.lnk existiert ***
Write-Host '*** Warten, bis Firefox.lnk existiert ***'
while (-not (Test-Path $FirefoxPath)) {
    Write-Host 'Warten auf Firefox.lnk...'
    Start-Sleep -Seconds 30
}

# *** Entfernen unerwünschter Apps von der Taskleiste ***
Write-Host '*** Entfernen unerwünschter Apps von der Taskleiste ***'
function Remove-AppFromTaskbar(\$appname) {
    Write-Host "Entfernen von \$appname von der Taskleiste ..."
    ((New-Object -Com Shell.Application).NameSpace('shell:::{4234d49b-0245-4df3-b780-3893943456e1}').Items() | Where-Object { \$_.Name -eq \$appname }).Verbs() | Where-Object { \$_.Name.replace('&', '') -match 'Unpin from taskbar' -or \$_.Name.replace('&','') -match 'Von Taskleiste lösen'} | ForEach-Object { \$_.DoIt(); \$exec = \$true }
}

Remove-AppFromTaskbar 'Microsoft Store'

# *** Setzen des Ausführungsflags in der Registry ***
Write-Host '*** Setzen des Ausführungsflags in der Registry ***'
New-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -PropertyType DWORD -Value 1 -Force | Out-Null
Write-Host 'Ausführungsflag wurde gesetzt.'

# *** Transkript beenden ***
Write-Host '*** Transkript beenden ***'
Stop-Transcript
"@

# *** Speichern des Hauptskripts ***
$PostActionScript | Out-File -FilePath $MainScriptPath -Force

# *** Warte-Skript, das auf explorer.exe wartet und dann das Hauptskript ausführt ***
$WaitForExplorerScript = @"
# *** Warten auf explorer.exe ***
Write-Host '*** Warten auf explorer.exe ***'
while (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Write-Host 'Warten, bis der Desktop vollständig geladen ist...'
    Start-Sleep -Seconds 10
}

# *** Hauptskript ausführen ***
Write-Host 'explorer.exe ist gestartet. Hauptskript wird ausgeführt...'
Start-Process 'powershell.exe' -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"$MainScriptPath\"'
"@

# *** Speichern des Warte-Skripts ***
$WaitScriptPath = "$env:UserProfile\Documents\OSDCloud\WaitForExplorerAndRun.ps1"
$WaitForExplorerScript | Out-File -FilePath $WaitScriptPath -Force

# *** Erstellen einer geplanten Aufgabe, die das Warte-Skript bei der Anmeldung ausführt ***
Write-Host '*** Erstellen einer geplanten Aufgabe ***'
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $WaitScriptPath"
$trigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal $env:USERNAME
$task = New-ScheduledTask -Action $action -Trigger $trigger -Principal $principal
Register-ScheduledTask -TaskName $ScheduledTaskName -InputObject $task

Write-Host 'Geplante Aufgabe wurde erstellt und das Warte-Skript gespeichert.'
