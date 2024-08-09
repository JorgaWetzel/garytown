$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath = "$env:ProgramData\OSDCloud\PostActions.ps1"
$ScheduledTaskName = 'OSDCloudPostAction'

if (!(Test-Path -Path ($ScriptPath | split-path))) {
    New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath -WindowStyle Normal"
$trigger = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
$principal = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
Register-ScheduledTask $ScheduledTaskName -InputObject $task -User SYSTEM

# Script That Runs:
$PostActionScript = @'

# Start the Transcript
$Transcript = "PostActions.log"
$null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

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
Write-Host -ForegroundColor Green "Office wird installiert"
choco.exe install office365business --params "'/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE'" -y --no-progress --ignore-checksums --force

Write-Host -ForegroundColor Green "Standart Apps werden installiert"
$packages = "TeamViewer","googlechrome","firefox","adobereader","microsoft-teams-new-bootstrapper","7zip.install","vlc","jre8","powertoys","onedrive","Pdf24","vcredist140","zoom","notepadplusplus.install","onenote","onedrive"
$packages | %{
    choco install $_ -y --no-progress --ignore-checksums
}

# osdcloud-InstallPwsh
# Write-Host -ForegroundColor Green "[+] pwsh.osdcloud.com Complete"
# osdcloud-UpdateDefenderStack
# osdcloud-NetFX


#Windows Updates
Write-Host -ForegroundColor Gray "**Running Defender Updates**"
Update-DefenderStack
Write-Host -ForegroundColor Gray "**Running Windows Updates**"
Start-WindowsUpdate
Write-Host -ForegroundColor Gray "**Running Driver Updates**"
Start-WindowsUpdateDriver

#HP Driver Updates
osdcloud-HPIAExecute

REM RD C:\OSDCloud\OS /S /Q
REM RD C:\Drivers /S /Q

# Remove Desktop Shortcuts
$Shortcuts2Remove = "Google Chrome.lnk", "VLC media player.lnk", "Adobe Acrobat.lnk", "VLC media player.lnk", "Firefox.lnk", "PDFCreator.lnk", "TeamViewer.lnk", "Microsoft Edge.lnk", "FileMaker Pro.lnk", "Google Earth.lnk", "LayOut 2023.lnk", "LibreOffice 7.4.lnk", "PDFCreator.lnk", "PDF-XChange Editor.lnk", "PDF-XChange Editor.lnk", "SIA-Reader.lnk", "SIA-Reader.lnk", "Solibri.lnk", "SonicWall NetExtender.lnk", "Style Builder.lnk", "VLC media player.lnk", "Zoom.lnk", "Spotify.lnk", "SEH UTN Manager.lnk", "SketchUp 2023.lnk", "Easy Product Finder 2.lnk", "Google Earth Pro.lnk", "Revit 2022 (AirTop1).lnk", "liNear CAD 22 (AirTop1).lnk", "AutoCAD 2022 (AirTop1).lnk", "Abmelden (AirTop1).lnk" 
$DesktopPaths = @("C:\Users\*\Desktop\*", "C:\Users\*\*\Desktop\*")  # Mehrere Pfade als Array
try {
    foreach ($DesktopPath in $DesktopPaths) {
        $ShortcutsOnClient = Get-ChildItem $DesktopPath
        foreach ($shortcut in $Shortcuts2Remove) {
            $($ShortcutsOnClient | Where-Object -FilterScript {$_.Name -like "$($shortcut.Split('.')[0])*"}) | Remove-Item -Force
        }
    }
    Write-Host "Unwanted shortcut(s) removed."
} catch {
    Write-Error "Error removing shortcut(s)"
}

$null = Stop-Transcript -ErrorAction Ignore

# Lösche den geplanten Task, damit das Skript nicht erneut ausgeführt wird
Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false
'@

$PostActionScript | Out-File -FilePath $ScriptPath -Force
