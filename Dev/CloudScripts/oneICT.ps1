<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '14.03.2024'

iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#region functions

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"

Set-ExecutionPolicy Bypass -Force

#WinPE Stuff
if ($env:SystemDrive -eq 'X:') {
    Write-Host -ForegroundColor Green "Starting oneICT Deployment from Cloud Scripts"
    iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/win11.ps1)
    
    #Create Unattend.xml
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Unattend.xml"
    $destinationPath = "C:\Windows\Panther\unattend.xml"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath    
    # Notepad $destinationPath
    
    #Create Custom SetupComplete
    $ScriptsPath = "C:\Windows\Setup\Scripts"
    $PSFilePath = "$ScriptsPath\SetupComplete.ps1"
    $CmdFilePath = "$ScriptsPath\SetupComplete.cmd"
    
    # Stelle sicher, dass die SetupComplete.ps1 existiert
    if (!(Test-Path -Path $PSFilePath)) {
        New-Item -Path $PSFilePath -ItemType File -Force
    }
    # Füge den grundlegenden Inhalt zur SetupComplete.ps1 hinzu, wenn nicht schon vorhanden
    Add-Content -Path $PSFilePath "Write-Output 'Starting SetupComplete oneICT Script Process'"
    Add-Content -Path $PSFilePath "Write-Output 'iex (irm win11.oneict.ch)'"
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

#Non-WinPE
if ($env:SystemDrive -ne 'X:') {
    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDOOBE.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore

    <#
    #Remove Personal Teams
    Write-Host -ForegroundColor Gray "**Removing Default Chat Tool**" 
    try {
        iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    }
    catch {}
    #>

    # Delivery Optimization
    Write-Host -ForegroundColor Green "**Function Set-DOPoliciesGPORegistry**"
    Set-DOPoliciesGPORegistry
    
    #Write-Host -ForegroundColor Gray "**Running Test.garytown.com**" 
    #iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/test.ps1)
     
    #Set Time Zone to Automatic Update
    # Write-Host -ForegroundColor Gray "**Setting Time Zone for Auto Update**" 
    # Enable-AutoZimeZoneUpdate
    
    # Write-Host -ForegroundColor Gray "**Setting Default Profile Personal Preferences**" 
    Set-DefaultProfilePersonalPref
    # Set-DefaultProfilePersonalPrefOneICT
    
    #Try to prevent crap from auto installing
    Write-Host -ForegroundColor Gray "**Disabling Cloud Content**" 
    Disable-CloudContent
    
    #Set Win11 Bypasses
    Write-Host -ForegroundColor Gray "**Enabling Win11 Bypasses**" 
    Set-Win11ReqBypassRegValues
    
    #Windows Updates
    Write-Host -ForegroundColor Gray "**Running Defender Updates**"
    Update-DefenderStack
    Write-Host -ForegroundColor Gray "**Running Windows Updates**"
    Start-WindowsUpdate
    Write-Host -ForegroundColor Gray "**Running Driver Updates**"
    Start-WindowsUpdateDriver

    #HP Stuff
    # Write-Host -ForegroundColor Gray "**Running HP Client Management Script Library**"
    # Install-ModuleHPCMSL
    # Invoke-HPTPMDownload

    #Store Updates
    Write-Host -ForegroundColor Gray "**Running Winget Updates**"
    Write-Host -ForegroundColor Gray "Invoke-UpdateScanMethodMSStore"
    Invoke-UpdateScanMethodMSStore
    Write-Host -ForegroundColor Gray "winget upgrade --all --accept-package-agreements --accept-source-agreements"
    winget upgrade --all --accept-package-agreements --accept-source-agreements
    
    Write-Host -ForegroundColor Gray "**Running Disablking TCP IP v6*"
    DisableIPv6
    
    Write-Host -ForegroundColor Gray "**Running Chocolatey Script and Settings**"
    Set-Chocolatey

    Write-Host -ForegroundColor Gray "**Running RunOnce Script to install Default Apps**"
    Set-RunOnceScript

    #Modified Version of Andrew's Debloat Script
    Write-Host -ForegroundColor Gray "**Running Debloat Script**" 
    #iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Debloat.ps1)
    Invoke-Debloat

    #Set Time Zone
    Write-Host -ForegroundColor Gray "**Setting TimeZone based on IP**"
    Set-TimeZoneFromIP
    
}
