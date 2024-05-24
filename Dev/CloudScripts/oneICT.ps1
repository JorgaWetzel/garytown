<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'oneICT.ps1'
$ScriptVersion = '24.05.2024'

iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions2.ps1)
#region functions
function Set-SetupCompleteCreateStartHOPEonUSB {
    
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath

    if (!(Test-Path -Path $ScriptsPath)){New-Item -Path $ScriptsPath} 

    $RunScript = @(@{ Script = "SetupComplete"; BatFile = 'SetupComplete.cmd'; ps1file = 'SetupComplete.ps1';Type = 'Setup'; Path = "$ScriptsPath"})


    Write-Output "Creating $($RunScript.Script) Files"

    $BatFilePath = "$($RunScript.Path)\$($RunScript.batFile)"
    $PSFilePath = "$($RunScript.Path)\$($RunScript.ps1File)"
            
    #Create Batch File to Call PowerShell File
    if (Test-Path -Path $PSFilePath){
        copy-item $PSFilePath -Destination "$ScriptsPath\SetupComplete.ps1.bak"
    }        
    New-Item -Path $BatFilePath -ItemType File -Force
    $CustomActionContent = New-Object system.text.stringbuilder
    [void]$CustomActionContent.Append('%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy ByPass -File C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1')
    Add-Content -Path $BatFilePath -Value $CustomActionContent.ToString()

    #Create PowerShell File to do actions

    New-Item -Path $PSFilePath -ItemType File -Force
    Add-Content -Path $PSFilePath "Write-Output 'Starting SetupComplete oneICT Script Process'"
    Add-Content -Path $PSFilePath "Write-Output 'iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/oneICT.ps1)'"
    Add-Content -path $PSFilePath 'if ((Test-WebConnection) -ne $true){Write-error "No Internet, Sleeping 2 Minutes" ; start-sleep -seconds 120}'
    Add-Content -Path $PSFilePath 'iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/oneICT.ps1)'
    Add-Content -Path $PSFilePath "Stop-Transcript"
    Add-Content -Path $PSFilePath "Restart-Computer -Force"
}

Function Restore-SetupCompleteOriginal {
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $SetupCompletePath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\Config\Scripts\SetupComplete"
    $ScriptsPath = $SetupCompletePath
    if (Test-Path -Path "$ScriptsPath\SetupComplete.ps1.bak"){
        copy-item -Path "$ScriptsPath\SetupComplete.ps1.bak" -Destination "$ScriptsPath\SetupComplete.ps1"
    }
}
#endregion

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
    #Create Custom SetupComplete on USBDrive, this will get copied and run during SetupComplete Phase thanks to OSD Function: Set-SetupCompleteOSDCloudUSB
    Set-SetupCompleteCreateStartHOPEonUSB
    Write-Host -ForegroundColor Green "Starting win11.oneict.ch"
    iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/win11.ps1)

    Restore-SetupCompleteOriginal
    restart-computer
}

#region Specialize
if ($WindowsPhase -eq 'Specialize') {
    <#
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Unattend.xml"
    $destinationPath = "C:\Windows\Panther\unattend.xml"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    $null = Stop-Transcript -ErrorAction Ignore
    #>
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
    #iex (irm "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/PostActionsTask.ps1")
    
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
Write-Host "Installing Office 365 Business..."
C:\ProgramData\chocolatey\bin\choco.exe install office365business --params "'/exclude:Access Groove Lync Publisher /language:de-DE /eula:FALSE'" -y --no-progress --ignore-checksums
}
