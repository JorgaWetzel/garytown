<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'oneICT.ps1'
$ScriptVersion = '24.05.2024'

iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#region functions

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"

Set-ExecutionPolicy Bypass -Force
if ($env:SystemDrive -eq 'X:') {
    $WindowsPhase = 'WinPE'
}
else {
    $ImageState = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State' -ErrorAction Ignore).ImageState
    if ($env:UserName -eq 'defaultuser0') {$WindowsPhase = 'OOBE'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_OOBE') {$WindowsPhase = 'Specialize'}
    elseif ($ImageState -eq 'IMAGE_STATE_SPECIALIZE_RESEAL_TO_AUDIT') {$WindowsPhase = 'AuditMode'}
    else {$WindowsPhase = 'Windows'}
}

#region WinPE
if ($WindowsPhase -eq 'WinPE') {
    Write-Host -ForegroundColor Green "Starting win11.oneict.ch"
    iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/win11.ps1)
    
    #Create Unattend.xml
    <#
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Unattend.xml"
    $destinationPath = "C:\Windows\Panther\unattend.xml"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    # Notepad $destinationPath
    #>
    
    #Create Custom SetupComplete
    $ScriptsPath = "C:\Windows\Setup\Scripts"
    $PSFilePath = "$ScriptsPath\SetupComplete.ps1"
    $CmdFilePath = "$ScriptsPath\SetupComplete.cmd"
    
    # Stelle sicher, dass die SetupComplete.ps1 existiert
    if (!(Test-Path -Path $PSFilePath)) {
        New-Item -Path $PSFilePath -ItemType File -Force
    }
    # Füge den grundlegenden Inhalt zur SetupComplete.ps1 hinzu, wenn nicht schon vorhanden
    Add-Content -Path $PSFilePath "Write-Output 'Starting SetupComplete HOPE Script Process'"
    Add-Content -Path $PSFilePath "Write-Output 'iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/oneICT.ps1)'"
    Add-Content -Path $PSFilePath 'iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/oneICT.ps1)'
    
    # Stelle sicher, dass die SetupComplete.cmd existiert und setze den Inhalt
    if (!(Test-Path -Path $CmdFilePath)) {
        New-Item -Path $CmdFilePath -ItemType File -Force
    }
    $cmdContent = "%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File $PSFilePath"
    Set-Content -Path $CmdFilePath -Value $cmdContent -Force
    
    # Bearbeite die SetupComplete.ps1, um "Stop-Transcript" und "Restart-Computer -Force" zu verschieben
    $psContent = Get-Content -Path $PSFilePath
    $transcriptLine = $psContent | Where-Object { $_ -match "Stop-Transcript" }
    $restartLine = $psContent | Where-Object { $_ -match "Restart-Computer -Force" }
if ($transcriptLine -ne $null -and $restartLine -ne $null) {
    # Entferne die Zeilen aus dem Originalinhalt
    $psContent = $psContent | Where-Object { $_ -notmatch "Stop-Transcript|Restart-Computer -Force" }
    # Füge die entfernten Inhalte und die spezifischen Zeilen am Ende hinzu
    #$psContent += "Write-Output 'Neuer zusätzlicher Inhalt'"
    #$psContent += "Write-Output 'Weiterer neuer Inhalt'"
    $psContent += $transcriptLine
    $psContent += $restartLine
    # Schreibe den neuen Inhalt zurück in die Datei
    Set-Content -Path $PSFilePath -Value $psContent
} else {
    # Nur hinzufügen, wenn die Zeilen nicht bereits vorhanden waren
    #Add-Content -Path $PSFilePath "Write-Output 'Neuer zusätzlicher Inhalt'"
    #Add-Content -Path $PSFilePath "Write-Output 'Weiterer neuer Inhalt'"
    Add-Content -Path $PSFilePath "Stop-Transcript"
    Add-Content -Path $PSFilePath "Restart-Computer -Force"
}    
    restart-computer

}

#region Specialize
if ($WindowsPhase -eq 'Specialize') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region AuditMode
if ($WindowsPhase -eq 'AuditMode') {
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region OOBE
if ($WindowsPhase -eq 'OOBE') {
    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDOOBE.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

    Set-ExecutionPolicy Bypass -Force
    #Setup Post Actions Scheduled Task
    iex (irm "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/PostActionsTask.ps1")
    
    #Add Functions
    iex (irm functions.garytown.com)
    #Remove Personal Teams
    Write-Host -ForegroundColor Gray "**Removing Default Chat Tool**" 
    try {
        iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    }
    catch {}
        
    Write-Host -ForegroundColor Gray "**Running Test**" 
    iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/test.ps1)
     
    # Write-Host -ForegroundColor Gray "**Setting Default Profile Personal Preferences**" 
    Set-DefaultProfilePersonalPref
    
    #Try to prevent crap from auto installing
    Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
    Disable-CloudContent
    
    #Set Win11 Bypasses
    Write-Host -ForegroundColor Gray "**Enabling Win11 Bypasses**" 
    Set-Win11ReqBypassRegValues
    
    #Windows Updates
    #Write-Host -ForegroundColor Gray "**Running Defender Updates**"
    #Update-DefenderStack
    #Write-Host -ForegroundColor Gray "**Running Windows Updates**"
    #Start-WindowsUpdate
    #Write-Host -ForegroundColor Gray "**Running Driver Updates**"
    #Start-WindowsUpdateDriver

    #Store Updates
    #Write-Host -ForegroundColor Gray "**Running Winget Updates**"
    #Write-Host -ForegroundColor Gray "Invoke-UpdateScanMethodMSStore"
    #Invoke-UpdateScanMethodMSStore
    #Write-Host -ForegroundColor Gray "winget upgrade --all --accept-package-agreements --accept-source-agreements"
    #winget upgrade --all --accept-package-agreements --accept-source-agreements

    #Modified Version of Andrew's Debloat Script
    #Write-Host -ForegroundColor Gray "**Running Debloat Script**" 
    #iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Debloat.ps1)

    #Set Time Zone
    # Write-Host -ForegroundColor Gray "**Setting TimeZone based on IP**"
    # Set-TimeZoneFromIP
    
    #Set OOBE Language
    Set-WinUILanguageOverride -Language de-CH
    Set-WinCultureFromLanguageListOptOut -OptOut $false
    Set-Culture -CultureInfo de-CH
    $InputMethod = '0807:00000807' # Das Layout für Deutsch (Schweiz)
    Set-WinUserLanguageList -LanguageList (New-WinUserLanguageList $InputMethod) -Force
    Set-WinSystemLocale -SystemLocale de-CH
        
    # setup RunOnce to execute provisioning.ps1 script
    Write-Host -ForegroundColor Gray "**Running Set-RunOnceScript Script**"
    Set-RunOnceScript
    
    # Setup oneICT Chocolatey Framework
    Write-Host -ForegroundColor Gray "**Running Chocolatey Framework**"
    Set-Chocolatey

    Write-Host -ForegroundColor Gray "**Completed  oneICT.ps1 script**" 

    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Windows
if ($WindowsPhase -eq 'Windows') {

}
