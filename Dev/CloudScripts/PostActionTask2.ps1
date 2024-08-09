$RegistryPath = "HKLM:\SOFTWARE\OSDCloud"
$ScriptPath = "$env:ProgramData\OSDCloud\PostActions.ps1"
$ScheduledTaskName = 'OSDCloudPostAction'
$ExecutionFlag = "PostActionExecuted"

if (!(Test-Path -Path ($ScriptPath | split-path))) {
    New-Item -Path ($ScriptPath | split-path) -ItemType Directory -Force | Out-Null
}
New-Item -Path $RegistryPath -ItemType Directory -Force | Out-Null

# Überprüfen, ob das Skript bereits ausgeführt wurde
if ((Get-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -ErrorAction SilentlyContinue).$ExecutionFlag -ne 1) {
    New-ItemProperty -Path $RegistryPath -Name "TriggerPostActions" -PropertyType dword -Value 1 | Out-Null

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File $ScriptPath -WindowStyle Normal"
    $trigger = New-ScheduledTaskTrigger -AtLogon
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -RunOnlyIfNetworkAvailable -ExecutionTimeLimit (New-TimeSpan -Hours 1)
    $principal = New-ScheduledTaskPrincipal "NT Authority\System" -RunLevel Highest
    $task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Description "OSDCloud Post Action" -Principal $principal
    Register-ScheduledTask $ScheduledTaskName -InputObject $task -User SYSTEM

    # Script That Runs:
    $PostActionScript = @'

    # Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-PostActions.log"
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

    Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"
    Invoke-Expression -Command (Invoke-RestMethod -Uri functions.osdcloud.com)

    osdcloud-SetExecutionPolicy
    osdcloud-SetPowerShellProfile
    osdcloud-InstallPackageManagement
    osdcloud-TrustPSGallery
    osdcloud-InstallPowerShellModule -Name Pester
    osdcloud-InstallPowerShellModule -Name PSReadLine
    # powershell Invoke-Expression -Command (Invoke-RestMethod -Uri pwsh.live)
    osdcloud-InstallWinGet
    if (Get-Command 'WinGet' -ErrorAction SilentlyContinue) {
        Write-Host -ForegroundColor Green '[+] winget upgrade --all --accept-source-agreements --accept-package-agreements'
        Write-Host -ForegroundColor Green '[+] winget install company portal (unternehmenbsportal)'
        winget install --id "9WZDNCRFJ3PZ" --exact --source msstore --accept-package-agreements --accept-source-agreements
    }

    # osdcloud-InstallPwsh
    # Write-Host -ForegroundColor Green "[+] pwsh.osdcloud.com Complete"
    # osdcloud-UpdateDefenderStack
    # osdcloud-NetFX
    osdcloud-HPIAExecute

    # Chocolatey software installation
    choco.exe install office365business --params "'/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE'" -y --no-progress --ignore-checksums

    $packages = "TeamViewer","adobereader","microsoft-teams-new-bootstrapper","googlechrome","7zip.install","firefox","vlc","jre8","powertoys","onedrive","Pdf24","vcredist140","zoom","notepadplusplus.install","onenote","onedrive"
    $packages | %{
        choco install $_ -y --no-progress --ignore-checksums
    }

    $null = Stop-Transcript -ErrorAction Ignore

    # Set the flag so that the script won't run again
    Set-ItemProperty -Path $RegistryPath -Name $ExecutionFlag -Value 1 -Force

    # Lösche den geplanten Task, damit das Skript nicht erneut ausgeführt wird
    Unregister-ScheduledTask -TaskName $ScheduledTaskName -Confirm:$false
    '@

    $PostActionScript | Out-File -FilePath $ScriptPath -Force
}
