$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath   = "$env:ProgramData\OSDCloud\PostActions.ps1"

if (!(Test-Path -Path ($ScriptPath | Split-Path))) {
    New-Item -Path ($ScriptPath | Split-Path) -ItemType Directory -Force | Out-Null
}

# Schreibe das PostActionScript in die Datei
$PostActionScript = @'

$ScheduledTaskName = "OSDCloudPostAction"
$ScriptPath        = "$env:ProgramData\OSDCloud\PostActions.ps1"

# Überprüfe, ob der Task existiert; falls nicht, erstelle ihn (AtStartup)
if (!(Get-ScheduledTask -TaskName $ScheduledTaskName -ErrorAction SilentlyContinue)) {
    $action    = New-ScheduledTaskAction  -Execute "powershell.exe" `
                 -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -WindowStyle Hidden"
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable `
                 -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    $principal = New-ScheduledTaskPrincipal "NT AUTHORITY\SYSTEM" -RunLevel Highest
    Register-ScheduledTask -TaskName $ScheduledTaskName -Action $action -Trigger $trigger `
                           -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
}

try {
    # ------------------------------------------------------------
    # Transkript & Netzwerk-Warteschleife
    # ------------------------------------------------------------
    $Transcript = "PostActions.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

    $ProgressPreference_bk = $ProgressPreference
    $ProgressPreference    = "SilentlyContinue"
    do {
        if (-not (Test-NetConnection 8.8.8.8 -InformationLevel Quiet)) {
            cls; "Warte auf die Internetverbindung" | Out-Host
            Start-Sleep 5
        }
    } until (Test-NetConnection 8.8.8.8 -InformationLevel Quiet)
    $ProgressPreference = $ProgressPreference_bk

    # ------------------------------------------------------------
    # FUNCTIONS & CHOCOLATEY-FRAMEWORK
    # ------------------------------------------------------------
	iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
	iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)

	if (-not $env:ChocolateyInstall) {
		$env:ChocolateyInstall = [Environment]::GetEnvironmentVariable('ChocolateyInstall','Machine')
		if (-not $env:ChocolateyInstall) { throw "ChocolateyInstall ist nicht gesetzt." }
	}
	$env:PATH = "$env:ChocolateyInstall\bin;$env:PATH"
	$choco = Join-Path $env:ChocolateyInstall 'choco.exe'

	Write-Host -ForegroundColor Gray "**Add Cutomer Chocolatey Repository**"
	$ErrorActionPreference = 'Stop'
	# (die zweite Zuweisung an $choco ist doppelt; kann bleiben, ist aber nicht noetig)
	#$choco   = Join-Path $env:ChocolateyInstall 'choco.exe'
	$srcName = 'SRbach'
	$srcUrl  = 'https://chocoserver:8443/repository/SRbach/'
	$srcUser = 'SRbach'
	$srcPass = 'TF2annC4sM4hMvMojT3RWQrAe'

	Write-Host -ForegroundColor Gray 'Add Customer Chocolatey Repository'
	& $choco source add -n=$srcName -s="$srcUrl" --user="$srcUser" --password="$srcPass" --priority=2 --allowselfservice
	
    # ------------------------------------------------------------
    # SOFTWARE-INSTALLATIONEN
    # ------------------------------------------------------------
    Write-Host -ForegroundColor Green "Office wird installiert"
    choco upgrade office365business --params "/exclude:Access Groove Lync Publisher Bing /language:de-DE /eula:FALSE" `
                 -y --no-progress --ignore-checksums

    Write-Host -ForegroundColor Green "Standard Apps werden installiert"
    $packages = @(
        "googlechrome","microsoft-teams-new-bootstrapper","vlc","hpsupportassistant",
		"onedrive","imagemate5","microsoft-windows-terminal","VoicesTrainer1","VoicesTrainer2","voices-3-trainer","onenote","onedrive"
    )
    $packages | ForEach-Object { choco upgrade $_ -y --no-progress --ignore-checksums }

    # ------------------------------------------------------------
    # Windows-Komponenten sperren (Outlook/Dev Home)
    # ------------------------------------------------------------
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate",
    "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\OutlookUpdate",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Orchestrator\UScheduler\DevHomeUpdate" |
        ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }

    # ------------------------------------------------------------
    # TASKBAR- & START-LAYOUT, SHORTCUTS, POWER, FOLDERS 
    # (Restlicher Inhalt unverndert)
    # ------------------------------------------------------------
    # ... (dein ganzer bestehender Code bleibt hier unangetastet) ...
    # ------------------------------------------------------------

    # Windows Updates
    Write-Host -ForegroundColor Gray "**Running Microsoft Defender Updates**"
    Update-DefenderStack
    Write-Host -ForegroundColor Gray "**Running Microsoft Windows Updates**"
    Start-WindowsUpdate
    Write-Host -ForegroundColor Gray "**Running Microsoft Driver Updates**"
    Start-WindowsUpdateDriver
    # Erfolgreich bis hier -> Task entfernen
    Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false -ErrorAction SilentlyContinue
}
catch {
    Write-Error $_   # Task bleibt erhalten; Skript luft beim nächsten Start erneut
}
finally {
    # Transkript schließen (falls noch aktiv) und Task immer lschen
    Stop-Transcript -ErrorAction SilentlyContinue
}
'@

# Schreibe das eingebettete Skript auf die Platte
$PostActionScript | Out-File -FilePath $ScriptPath -Force -Encoding UTF8

# Fhre es einmalig sofort aus
& $ScriptPath
