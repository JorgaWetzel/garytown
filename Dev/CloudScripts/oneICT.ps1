<#
Loads Functions
Creates Setup Complete Files
#>

$ScriptName = 'hope.garytown.com'
$ScriptVersion = '14.03.2024'

iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions.ps1)
#region functions

function Use-WindowsUnattend.specialize {
    [CmdletBinding()]
    param (
        [string]$AutopilotSwitches
    )
#https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-deployment-runsynchronous
$UnattendXml = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
<settings pass="specialize">
<component name="Microsoft-Windows-IE-InternetExplorer" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <LocalIntranetSites>*.internal.loc</LocalIntranetSites>
    <Home_Page>https://www.google.ch</Home_Page>
    <DisableFirstRunWizard>true</DisableFirstRunWizard>
</component>
<component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <TimeZone>W. Europe Standard Time</TimeZone>
    <RegisteredOrganization></RegisteredOrganization>
    <RegisteredOwner>Administrator</RegisteredOwner>
</component>
<component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
    <InputLocale>0807:00000807</InputLocale>
    <SystemLocale>en-US</SystemLocale>
    <UserLocale>de-CH</UserLocale>
</component>
</settings>
</unattend>
'@
    #=================================================
    #	Block
    #=================================================
    #Block-WinOS
    #Block-WindowsVersionNe10
    #Block-PowerShellVersionLt5
    #=================================================
    #   Specialize.cmd
    #=================================================
    Write-Verbose "Adding C:\Windows\Setup\Scripts\Specialize.cmd"

    if (-NOT (Test-Path 'C:\Windows\Setup\Scripts')) {
        New-Item -Path 'C:\Windows\Setup\Scripts' -ItemType Directory -Force | Out-Null
    }

$Specialize = @'

'@

    $Specialize | Out-File -FilePath 'C:\Windows\Setup\Scripts\Specialize.cmd' -Encoding ascii -Width 2000 -Force
    #=================================================
    #	Panther Unattend.xml
    #=================================================
    $Panther = 'C:\Windows\Panther'
    $UnattendPath = "$Panther\Specialize.xml"

    if (-NOT (Test-Path $Panther)) {
        New-Item -Path $Panther -ItemType Directory -Force | Out-Null
    }

    Write-Verbose -Verbose "Setting Specialize.xml at $UnattendPath"
    $UnattendXml | Out-File -FilePath $UnattendPath -Encoding utf8 -Width 2000 -Force
    #=================================================
    #	Use-WindowsUnattend
    #=================================================
    Write-Verbose -Verbose "Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath"
    Use-WindowsUnattend -Path 'C:\' -UnattendPath $UnattendPath -Verbose
    
    #Write-Verbose -Verbose "Copy-PSModuleToFolder -Name OSD to C:\Program Files\WindowsPowerShell\Modules"
    #Copy-PSModuleToFolder -Name OSD -Destination 'C:\Program Files\WindowsPowerShell\Modules'

    # Notepad 'C:\Windows\Setup\Scripts\Specialize.cmd'
    #=================================================
}


Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion ($WindowsPhase Phase)"

Set-ExecutionPolicy Bypass -Force

#WinPE Stuff
if ($env:SystemDrive -eq 'X:') {
    Write-Host -ForegroundColor Green "Starting win11.garytown.com"
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
    Add-Content -Path $PSFilePath "Write-Output 'Starting SetupComplete HOPE Script Process'"
    Add-Content -Path $PSFilePath "Write-Output 'iex (irm hope.garytown.com)'"
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

    Use-WindowsUnattend.specialize
}    
    # restart-computer
}

#Non-WinPE
if ($env:SystemDrive -ne 'X:') {
    #Start the Transcript
    $Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDOOBE.log"
    $null = Start-Transcript -Path (Join-Path "C:\OSDCloud\Logs" $Transcript) -ErrorAction Ignore
    #Remove Personal Teams
    Write-Host -ForegroundColor Gray "**Removing Default Chat Tool**" 
    try {
        iex (irm https://raw.githubusercontent.com/suazione/CodeDump/main/Set-ConfigureChatAutoInstall.ps1)
    }
    catch {}
    # Add Hope PDF to Desktop
    Write-Host -ForegroundColor Gray "**Adding HOPE PDF to Desktop**" 
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "https://raw.githubusercontent.com/gwblok/garytown/85ad154fa2964ea4757a458dc5c91aea5bf483c6/HopeForUsedComputers/Hope%20for%20Used%20Computers%20PDF.pdf" -OutFile "C:\Users\Public\Desktop\Hope For Used Computers.pdf"
    }
    catch {}

    #Set DO
    #Set-DOPoliciesGPORegistry
    
    #Write-Host -ForegroundColor Gray "**Running Test.garytown.com**" 
    #iex (irm raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/test.ps1)
     
    #Set Time Zone to Automatic Update
    # Write-Host -ForegroundColor Gray "**Setting Time Zone for Auto Update**" 
    Enable-AutoZimeZoneUpdate
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
    Write-Host -ForegroundColor Gray "**Running Debloat Script**" 
    iex (irm https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Debloat.ps1)

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
    # disable privacy experience
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/provisioning.ps1"
    $destinationFolder = "C:\Windows\Setup\Scripts"
    $destinationPath = Join-Path -Path $destinationFolder -ChildPath "provisioning.ps1"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    
    $settings = @(
        [PSCustomObject]@{
            Path  = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            Name  = "execute_provisioning"
            Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\provisioning.ps1"
        },
        [PSCustomObject]@{
            Path  = "SOFTWARE\Policies\Microsoft\Windows\OOBE"
            Name  = "DisablePrivacyExperience"
            Value = 1
        }
    ) | Group-Object Path
    
    foreach ($setting in $settings) {
        # Öffne den angegebenen Registrierungsschlüssel (oder erstelle ihn, falls er nicht existiert)
        $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
        if ($null -eq $registry) {
            $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
        }
        # Setze die Werte für den Registrierungsschlüssel basierend auf den Gruppenobjektdaten
        foreach ($item in $setting.Group) {
            $registry.SetValue($item.Name, $item.Value)
        }
        $registry.Dispose()
    }

    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$ENV:ALLUSERSPROFILE\chocolatey\bin", "Machine")
    C:\ProgramData\chocolatey\bin\choco.exe install chocolatey-core.extension -y --no-progress --ignore-checksums
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'oneICT'" --source="'https://chocoserver:8443/repository/ChocolateyInternal/'" --allow-self-service --user="'chocolatey'" --password="'wVGULoJGh1mxbRpChJQV'" --priority=1
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'Chocolatey'" --source="'https://chocolatey.org/api/v2/'" --allow-self-service --priority=2
    # C:\ProgramData\chocolatey\bin\choco.exe install chocolateygui -y --source="'oneICT'" --no-progress
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowGlobalConfirmation
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowEmptyChecksums
    
    $manufacturer = (gwmi win32_computersystem).Manufacturer
    "Das ist ein $manufacturer PC"
    
    if ($manufacturer -match "VMware"){
    Write-Host "Installing VMware tools..."
    C:\ProgramData\chocolatey\bin\choco.exe install vmware-tools -y --no-progress --ignore-checksums
    }
    
    # add tcp rout to oneICT Server
    Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "195.49.62.108 chocoserver"

    Write-Host -ForegroundColor Gray "**Completed Hope.garytown.com sub script**" 
    $null = Stop-Transcript -ErrorAction Ignore

}
