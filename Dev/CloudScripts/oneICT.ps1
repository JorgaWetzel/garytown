<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'oneICT.ps1'
$ScriptVersion = '02.10.2024'

#region functions
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#endregion

Set-ExecutionPolicy Bypass -Force

#WinPE Stuff
if ($env:SystemDrive -eq 'X:') {
    Write-Host -ForegroundColor Green "Starting win11.oneict.ch"
    iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/win11.ps1)
    
    #Create Custom SetupComplete
    $ScriptsPath = "C:\Windows\Setup\Scripts"
    $PSFilePath = "$ScriptsPath\SetupComplete.ps1"
    $CmdFilePath = "$ScriptsPath\SetupComplete.cmd"
    
    # Stelle sicher, dass die SetupComplete.ps1 existiert
    if (!(Test-Path -Path $PSFilePath)) {
        New-Item -Path $PSFilePath -ItemType File -Force
    }
    # Füge den grundlegenden Inhalt zur SetupComplete.ps1 hinzu, wenn nicht schon vorhanden
    
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

    $null = Stop-Transcript -ErrorAction Ignore
    restart-computer
}

#region OOBE
if ($env:SystemDrive -ne 'X:') {
    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDOOBE.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

    Set-SetupCompleteCreateStart
    
    Set-ExecutionPolicy Bypass -Force
    #Setup Post Actions Scheduled Task
    #iex (irm "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/PostActionsTask.ps1")
    
    #Add Functions
    iex (irm functions.garytown.com)
        
    # Write-Host -ForegroundColor Gray "**Running Test**" 
    # iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/test.ps1)
    iex (irm test.garytown.com)
      
    # Write-Host -ForegroundColor Gray "**Setting Default Profile Personal Preferences**" 
    Set-DefaultProfilePersonalPref

    # setup RunOnce to execute provisioning.ps1 script
    Write-Host -ForegroundColor Gray "**Running Set-RunOnceScript Script**"
    Set-RunOnceScript
   
    #Try to prevent crap from auto installing
    Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
    #Disable-CloudContent
    
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
       
    # Setup oneICT Chocolatey Framework
    Write-Host -ForegroundColor Gray "**Running Chocolatey Framework**"
    Set-Chocolatey


    #Set-OSDCloudUnattendAuditMode
    #Set-OSDCloudUnattendAuditModeAutopilot

    Write-Host -ForegroundColor Gray "**Completed  oneICT.ps1 script**" 
    $null = Stop-Transcript -ErrorAction Ignore
}
#endregion

#region Windows
if ($WindowsPhase -eq 'Windows') {
$null = Stop-Transcript -ErrorAction Ignore
}
