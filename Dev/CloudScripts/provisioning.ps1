param(
    [switch]$first
)

$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-Provisioning.log"
$null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"
Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)

osdcloud-SetExecutionPolicy
osdcloud-SetPowerShellProfile
osdcloud-InstallPackageManagement
osdcloud-TrustPSGallery
osdcloud-InstallPowerShellModule -Name Pester
osdcloud-InstallPowerShellModule -Name PSReadLine
# osdcloud-InstallWinGet
    if (Get-Command 'WinGet' -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor Green '[+] winget upgrade --all --accept-source-agreements --accept-package-agreements'
	Write-Host -ForegroundColor Green '[+] winget install company portal (unternehmenbsportal)'
	winget install --id "9WZDNCRFJ3PZ" --exact --source msstore --accept-package-agreements --accept-source-agreements
        ## winget upgrade --all --accept-source-agreements --accept-package-agreements
	# $command = "winget install --id `"9WZDNCRFJ3PZ`" --exact --source msstore --accept-package-agreements --accept-source-agreements"
 	# $runOncePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
  	# $taskName = "InstallAppAtLogon"
   	# Set-ItemProperty -Path $runOncePath -Name $taskName -Value "cmd.exe /c powershell -Command $command" -Force
    }
# osdcloud-InstallPwsh
# Write-Host -ForegroundColor Green "[+] pwsh.osdcloud.com Complete"
#osdcloud-UpdateDefenderStack
#osdcloud-NetFX
#osdcloud-HPIAExecute

$usb_drive_name = 'USB Drive'

$provisioning = [System.IO.DirectoryInfo]"$($env:ProgramData)\provisioning"
$urls = @(
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_brave.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_chrome.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_edge.ps1",
    "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/configure_firefox.ps1"
)

# Stelle sicher, dass das Verzeichnis existiert
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


# wait for network
$ProgressPreference_bk = $ProgressPreference
$ProgressPreference = 'SilentlyContinue'
do {
    $ping = Test-NetConnection '8.8.8.8' -InformationLevel Quiet
    if (!$ping) {
        cls
        'Warte auf die Internetverbindung' | Out-Host
        sleep -s 5
    }
} while (!$ping)
$ProgressPreference = $ProgressPreference_bk

# Chocolatey software installation
$packages =
"adobereader",
"microsoft-teams-new-bootstrapper",
"googlechrome",
"7zip.install",
"firefox",
"vlc",
"jre8",
"powertoys",
"office365business",
"onedrive",
"Pdf24",
"TeamViewer",
"vcredist140",
"zoom",
"notepadplusplus.install"
"onenote"
"onedrive"
$packages | %{
	choco install $_ -y --no-progress --ignore-checksums
}

choco.exe install office365business --params "'/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE'" -y --no-progress --ignore-checksums

# Version=1

#  syspin ["file"] #### or syspin ["file"] "commandstring"
#  5386  : Pin to taskbar
#  5387  : Unpin from taskbar
#  51201 : Pin to start
#  51394 : Unpin to start
# Download syspin.exe
$url32   = 'http://www.technosys.net/download.aspx?file=syspin.exe'
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

Remove-AppFromTaskbar "Microsoft Store"
# Remove-AppFromTaskbar 'HP Support Assistant'
# Remove-AppFromTaskbar 'Microsoft Teams'
Remove-AppFromTaskbar 'Microsoft Store'


    do {
        "Availabe actions:",
        "   1 - Lokalen Admin erstellen",
        "   2 - Computername ändern",
        "   3 - Computer neu starten",
        "   4 - Programme installieren",
        "   0 - Skript schliessen" | Out-Host
        $selected = Read-Host "Eintrag auswaehlen"
        switch ($selected) {
            1 {
		$credential = Get-Credential -Message "Bitte geben Sie den Benutzernamen und das Passwort für den neuen lokalen Administrator an"
    		New-LocalUser -Name $credential.UserName -Password $credential.Password -PasswordNeverExpires:$true | Add-LocalGroupMember -Group "Administratoren"
    		break
            }
            2 {
                Read-Host "Computername eintragen" | select @{n = 'NewName'; e = { $_ } } | Rename-Computer
                break
            }
            3 {
                Restart-Computer
                break
            }
            4 {
                #irm https://raw.githubusercontent.com/JorgaWetzel/winutil/main/winutil.ps1 | iex
		irm https://raw.githubusercontent.com/ChrisTitusTech/winutil/main/winutil.ps1 | iex
                break
            }

            
        }
    }while ($selected -ne 0)

    # best place to add more actions
    Write-Host "Alles ist fertig." -ForegroundColor Green
    Read-Host
    

$null = Stop-Transcript -ErrorAction Ignore
