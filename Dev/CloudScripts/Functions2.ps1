$ScriptName = 'functions.oneict.ch'
$ScriptVersion = '10.04.2024'
Set-ExecutionPolicy Bypass -Force

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Set-DefaultProfilePersonalPref"
function Set-DefaultProfilePersonalPref {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    if (Test-Path -Path $VirtualRegistryPath_software){
        reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
        Start-Sleep 1
    }
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    #TaskBar Left / Hide Chat / Hide Widgets / Hide TaskView
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    New-ItemProperty -Path $Path -Name "TaskbarAl" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarMn" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarDa" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ShowTaskViewButton" -Value 0 -PropertyType Dword -Force | Out-Null

    #Disable Content Delivery
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-ItemProperty -Path $Path -Name "SystemPaneSuggestionsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SubscribedContentEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SoftLandingEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SilentInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "PreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "OemPreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "FeatureManagementEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ContentDeliveryAllowed" -Value 0 -PropertyType Dword -Force | Out-Null

    #Enable Location for Auto Time Zone
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path $Path -Name "Value" -Value Allow -PropertyType String -Force | Out-Null
    Start-Sleep -s 1
    reg unload $VirtualRegistryPath_defaultuser | Out-Null
}

Write-Host -ForegroundColor Green "[+] Function Install-Nuget"
function Install-Nuget {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $NuGetClientSourceURL = 'https://nuget.org/nuget.exe'
        $NuGetExeName = 'NuGet.exe'
        $PSGetProgramDataPath = Join-Path -Path $env:ProgramData -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetProgramDataPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
    
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
    
        $PSGetAppLocalPath = Join-Path -Path $env:LOCALAPPDATA -ChildPath 'Microsoft\Windows\PowerShell\PowerShellGet\'
        $nugetExeBasePath = $PSGetAppLocalPath
        $nugetExeFilePath = Join-Path -Path $nugetExeBasePath -ChildPath $NuGetExeName
        if (-not (Test-Path -Path $nugetExeFilePath)) {
            if (-not (Test-Path -Path $nugetExeBasePath)) {
                $null = New-Item -Path $nugetExeBasePath -ItemType Directory -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
            }
            Write-Host -ForegroundColor Yellow "[-] Downloading NuGet to $nugetExeFilePath"
            $null = Invoke-WebRequest -UseBasicParsing -Uri $NuGetClientSourceURL -OutFile $nugetExeFilePath
        }
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
    }
    else {
        if (Test-Path "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget\2.8.5.208\Microsoft.PackageManagement.NuGetProvider.dll") {
            #Write-Host -ForegroundColor Green "[+] Nuget 2.8.5.208+"
        }
        else {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider NuGet -MinimumVersion 2.8.5.201"
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope AllUsers | Out-Null
        }
        $InstalledModule = Get-PackageProvider -Name NuGet | Where-Object {$_.Version -ge '2.8.5.201'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] NuGet $([string]$InstalledModule.Version)"
        }
    }
}
Write-Host -ForegroundColor Green "[+] Function Install-PackageManagement"
function Install-PackageManagement {
    [CmdletBinding()]
    param ()
    if ($WindowsPhase -eq 'WinPE') {
        $InstalledModule = Import-Module PackageManagement -PassThru -ErrorAction Ignore
        if (-not $InstalledModule) {
            Write-Host -ForegroundColor Yellow "[-] Install PackageManagement 1.4.8.1"
            $PackageManagementURL = "https://psg-prod-eastus.azureedge.net/packages/packagemanagement.1.4.8.1.nupkg"
            Invoke-WebRequest -UseBasicParsing -Uri $PackageManagementURL -OutFile "$env:TEMP\packagemanagement.1.4.8.1.zip"
            $null = New-Item -Path "$env:TEMP\1.4.8.1" -ItemType Directory -Force
            Expand-Archive -Path "$env:TEMP\packagemanagement.1.4.8.1.zip" -DestinationPath "$env:TEMP\1.4.8.1"
            $null = New-Item -Path "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement" -ItemType Directory -ErrorAction SilentlyContinue
            Move-Item -Path "$env:TEMP\1.4.8.1" -Destination "$env:ProgramFiles\WindowsPowerShell\Modules\PackageManagement\1.4.8.1"
            Import-Module PackageManagement -Force -Scope Global
        }
    }
    else {
        $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-PackageProvider PowerShellGet -MinimumVersion 2.2.5"
            Install-PackageProvider -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Scope AllUsers | Out-Null
            Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        }
    
        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if (-not ($InstalledModule)) {
            Write-Host -ForegroundColor Yellow "[-] Install-Module PackageManagement -MinimumVersion 1.4.8.1"
            Install-Module -Name PackageManagement -MinimumVersion 1.4.8.1 -Force -Confirm:$false -Source PSGallery -Scope AllUsers
            Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 5
        }
    
        Import-Module PackageManagement -Force -Scope Global -ErrorAction SilentlyContinue
        $InstalledModule = Get-Module -Name PackageManagement -ListAvailable | Where-Object {$_.Version -ge '1.4.8.1'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PackageManagement $([string]$InstalledModule.Version)"
        }
        Import-Module PowerShellGet -Force -Scope Global -ErrorAction SilentlyContinue
        $InstalledModule = Get-PackageProvider -Name PowerShellGet | Where-Object {$_.Version -ge '2.2.5'} | Sort-Object Version -Descending | Select-Object -First 1
        if ($InstalledModule) {
            Write-Host -ForegroundColor Green "[+] PowerShellGet $([string]$InstalledModule.Version)"
        }
    }
}
Write-Host -ForegroundColor Green "[+] Install-CMTrace"
function Install-CMTrace {

    <#
    Gary Blok - @gwblok - GARYTOWN.COM
    .Synopsis
      Proactive Remediation for CMTrace to be on endpoint

     .Description
      Creates Generic Shortcut in Start Menu
    #>
    $AppName = "CMTrace"
    $FileName = "CMTrace.exe"
    $InstallPath = "$env:windir\system32"
    $URL = "https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/CMTrace.exe"
    $AppPath = "$InstallPath\$FileName"
    $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"

    if ($env:SystemDrive -eq "C:"){ 
        Function New-AppIcon {
            param(
            [string]$SourceExePath = "$env:windir\system32\control.exe",
            [string]$ArgumentsToSourceExe,
            [string]$ShortCutName = "AppName"

            )
            #Build ShortCut Information

            $ShortCutFolderPath = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
            $DestinationPath = "$ShortCutFolderPath\$($ShortCutName).lnk"
            Write-Output "Shortcut Creation Path: $DestinationPath"

            if ($ArgumentsToSourceExe){
                Write-Output "Shortcut = $SourceExePath -$($ArgumentsToSourceExe)"
            }
            Else {
                Write-Output "Shortcut = $SourceExePath"
            }
    

            #Create Shortcut
            $WshShell = New-Object -comObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($DestinationPath)
            $Shortcut.IconLocation = "$SourceExePath, 0"
            $Shortcut.TargetPath = $SourceExePath
            if ($ArgumentsToSourceExe){$Shortcut.Arguments = $ArgumentsToSourceExe}
            $Shortcut.Save()

            Write-Output "Shortcut Created"
        }

        if (!(Test-Path -Path $AppPath)){
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to $InstallPath"
            Copy-Item -Path $env:TEMP\$FileName -Destination $InstallPath -Force
            #Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
            if (Test-Path -Path $AppPath){
                Write-Output "Successfully Installed File"
                New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
            }
            else{Write-Output "Failed Extract"; exit 255}
        }
        else {
            Write-Output "$AppName Already Installed"
        }


        if (!(Test-Path "$ShortCutFolderPath\$($AppName).lnk")){
            New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
        }
    }
    else {
        if (!(Test-Path -Path $AppPath)){
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to $InstallPath"
            Copy-Item -Path $env:TEMP\$FileName -Destination $InstallPath -Force
            #Expand-Archive -Path $env:TEMP\$FileName -DestinationPath $ExpandPath -Force
            if (Test-Path -Path $AppPath){
                Write-Output "Successfully Installed File"
                New-AppIcon -SourceExePath $AppPath -ShortCutName $AppName 
            }
            else{Write-Output "Failed Install"; exit 255}
        }
        else {
            Write-Output "$AppName already installed here: $AppPath"
        }
        if (Test-Path "C:\Windows\System32\$FileName"){
            Write-Output "$AppName already installed here: C:\Windows\System32\$FileName"
        }
        else{
            Write-Output "$AppName Not Found, Starting Remediation"
            #Download & Extract to System32
            Write-Output "Downloading $URL"
            Invoke-WebRequest -UseBasicParsing -Uri $URL -OutFile $env:TEMP\$FileName
            if (Test-Path -Path $env:TEMP\$FileName){Write-Output "Successfully Downloaded"}
            else{Write-Output "Failed Downloaded"; exit 255}
            Write-Output "Starting Copy of $AppName to C:\Windows\System32\$FileName"
            Copy-Item -Path $env:TEMP\$FileName -Destination "C:\Windows\System32\$FileName" -Force
            if (Test-Path -Path "C:\Windows\System32\$FileName"){
                Write-Output "Successfully Installed File"
            }
            else{Write-Output "Failed Install"; exit 255}
               
        }
    }
}
Write-Host -ForegroundColor Green "[+] Function Invoke-UpdateScanMethodMSStore"
Function Invoke-UpdateScanMethodMSStore {
    try {
        $AppMan01 = Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01'
        try {
            Get-CimInstance -Namespace 'Root\cimv2\mdm\dmmap' -ClassName 'MDM_EnterpriseModernAppManagement_AppManagement01'| Invoke-CimMethod -MethodName UpdateScanMethod | Out-Null
        }
        catch {
            Write-Output "Failed to trigger Updates"
        }
    }
    catch{
        Write-Output "Failed to get CimInstance"
    }
}

Write-Host -ForegroundColor Green "[+] Function Set-LatestUpdatesASAPEnabled"
function Set-LatestUpdatesASAPEnabled {
    Write-Host "Enable 'Get the latest updates as soon as they’re available' Reg Value" -ForegroundColor DarkGray
    if ($env:SystemDrive -eq 'X:') {
        $WindowsPhase = 'WinPE'
    }
    if ($WindowsPhase -eq 'WinPE'){
        Invoke-Exe reg load HKLM\TempSOFTWARE "C:\Windows\System32\Config\SOFTWARE"
        Invoke-Exe reg add HKLM\TempSOFTWARE\Microsoft\WindowsUpdate\UX\Settings /V IsContinuousInnovationOptedIn /T REG_DWORD /D 1 /F
        Invoke-Exe reg unload HKLM\TempSOFTWARE
    }
    else {
        Invoke-Exe reg add HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings /V IsContinuousInnovationOptedIn /T REG_DWORD /D 1 /F
    }
}
Write-Host -ForegroundColor Green "[+] Function Set-APEnterprise"
function Set-APEnterprise {
    Install-Nuget
    Install-PackageManagement
    Install-script -name Get-WindowsAutoPilotInfo -Force
    Set-ExecutionPolicy Bypass -Force
    Get-WindowsAutopilotInfo -Online -GroupTag Enterprise -Assign
}

Write-Host -ForegroundColor Green "[+] Function Install-23H2EnablementPackage"
function Install-23H2EnablementPackage {
	Function Install-Update {
	    [CmdletBinding()]
	    Param (
	    [Parameter(Mandatory=$true)]
		$UpdatePath
	    )
	
	    $scratchdir = 'C:\OSDCloud\Temp'
	    if (!(Test-Path -Path $scratchdir)){
	        new-item -Path $scratchdir | Out-Null
	    }
	
	    if ($env:SystemDrive -eq "X:"){
	        $Process = "X:\Windows\system32\Dism.exe"
	        $DISMArg = "/Image:C:\ /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
	    }
	    else {
	        $Process = "C:\Windows\system32\Dism.exe"
	        $DISMArg = "/Online /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
	    }
	
	
	    Write-Output "Starting Process of $Process -ArgumentList $DismArg -Wait"
	    $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru
	    
	    return $DISM.ExitCode
	}
	
	
	$23H2EnablementCabURL = "https://raw.githubusercontent.com/gwblok/garytown/master/SoftwareUpdates/Windows11.0-kb5027397-x64.cab"
	Invoke-WebRequest -UseBasicParsing -Uri $23H2EnablementCabURL -OutFile "$env:TEMP\Windows11.0-kb5027397-x64.cab"
	
	if (Test-Path -Path "$env:TEMP\Windows11.0-kb5027397-x64.cab"){
	    Install-Update -UpdatePath "$env:TEMP\Windows11.0-kb5027397-x64.cab"
	}
}
Write-Host -ForegroundColor Green "[+] Function Install-BuildUpdatesFromOSCloudUSB - Coming to OSDCloud native in 21.11.XX"
function Install-BuildUpdatesFromOSCloudUSB {
    function Get-UBR {
        if ($env:SystemDrive -eq "X:"){
            $Info = DISM.exe /image:c:\ /Get-CurrentEdition
            $UBR = ($Info | Where-Object {$_ -match "Image Version"}).replace("Image Version: ","")
        }
        else {
            $Info = DISM.exe /online /Get-CurrentEdition
            $UBR = ($Info | Where-Object {$_ -match "Image Version"}).replace("Image Version: ","")
        }
        return $UBR
    }
    Function Install-Update {
        [CmdletBinding()]
        Param (
        [Parameter(Mandatory=$true)]
	    $UpdatePath
        )

        $scratchdir = 'C:\OSDCloud\Temp'
        if (!(Test-Path -Path $scratchdir)){
            new-item -Path $scratchdir | Out-Null
        }

        if ($env:SystemDrive -eq "X:"){
            $Process = "X:\Windows\system32\Dism.exe"
            $DISMArg = "/Image:C:\ /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
        }
        else {
            $Process = "C:\Windows\system32\Dism.exe"
            $DISMArg = "/Online /Add-Package /PackagePath:$UpdatePath /ScratchDir:$scratchdir /Quiet /NoRestart"
        }


        Write-Output "Starting Process of $Process -ArgumentList $DismArg -Wait"
        $DISM = Start-Process $Process -ArgumentList $DISMArg -Wait -PassThru
    
        return $DISM.ExitCode
    }
    $BuildNumber = (Get-UBR).split(".")[2]
    $OSDCloudUSB = Get-Volume.usb | Where-Object {($_.FileSystemLabel -match 'OSDCloud') -or ($_.FileSystemLabel -match 'BHIMAGE')} | Select-Object -First 1
    $UpdatesPath = "$($OSDCloudUSB.DriveLetter):\OSDCloud\OS\Updates"
    $MSUUpdates = Get-ChildItem -Path $UpdatesPath -Recurse | Where-Object {$_.Name -match ".msu" -or $_.Name -match ".cab"}
    $BuildUpdates = $MSUUpdates | Where-Object {$_.fullname -match "$BuildNumber"}

write-host "Looking for updates here: $UpdatesPath for Build: $BuildNumber"
    if ($BuildUpdates){
        Write-Output "Current OS UBR: $(Get-UBR)"
        Write-Host " Found thse Updates: "
        foreach ($Update in $BuildUpdates){
            $Update.FullName
        }
        Write-Host "Starting DISM Update Process"
        foreach ($Update in $BuildUpdates){
            Write-Host "Installing Update: $($Update.Name)"
            Install-Update -UpdatePath $Update.FullName
        }
        Write-Output "Current OS UBR: $(Get-UBR)"
    }
    else {
	write-host "No Updates found for $BuildNumber"
    }
}

#Updating the OSD Module on the Offline OS from the one installed in WinPE - Used in testing to copy over updates not yet in the Gallery Module
Write-Host -ForegroundColor Green "[+] Function Update-OfflineOSDModuleFromWinPEVersion"
Function Update-OfflineOSDModuleFromWinPEVersion {
    #Update Files in Module that have been updated since last PowerShell Gallery Build (Testing Only)
    $ModulePath = (Get-ChildItem -Path "$($Env:ProgramFiles)\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
    import-module "$ModulePath\OSD.psd1" -Force

    #Used in Testing "Beta Gary Modules which I've updated on the USB Stick"
    $OfflineModulePath = (Get-ChildItem -Path "C:\Program Files\WindowsPowerShell\Modules\osd" | Where-Object {$_.Attributes -match "Directory"} | select -Last 1).fullname
    write-output "Updating $OfflineModulePath using $ModulePath"
    copy-item "$ModulePath\*" "$OfflineModulePath"  -Force -Recurse
}

#HP Dock Function
Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)

#HPIA Functions
Write-Host -ForegroundColor Green "[+] Function Get-HPIALatestVersion"
Write-Host -ForegroundColor Green "[+] Function Install-HPIA"
Write-Host -ForegroundColor Green "[+] Function Run-HPIA"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAXMLResult"
Write-Host -ForegroundColor Green "[+] Function Get-HPIAJSONResult"

iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/HPIA/HPIA-Functions.ps1)


#Install-ModuleHPCMSL
Write-Host -ForegroundColor Green "[+] Function Install-ModuleHPCMSL"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Install-ModuleHPCMSL.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-HPAnalyzer"
Write-Host -ForegroundColor Green "[+] Function Invoke-HPDriverUpdate"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/CMSL/Invoke-HPDriverUpdate.ps1)

Write-Host -ForegroundColor Green "[+] Function Get-HPDockUpdateDetails"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/hardware/HP/Docks/Function_Get-HPDockUpdateDetails.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-OSDCloudIPU"
iex (irm https://raw.githubusercontent.com/OSDeploy/OSD/master/Public/OSDCloudIPU/Invoke-OSDCloudIPU.ps1)

Write-Host -ForegroundColor Green "[+] Function Manage-HPBiosSettings"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1)

Write-Host -ForegroundColor Green "[+] Function Invoke-Debloat"
iex (irm https://raw.githubusercontent.com/gwblok/garytown/master/Dev/CloudScripts/Debloat.ps1)

Write-Host -ForegroundColor Green "[+] Function Set-ThisPC"
function Set-ThisPC {iex (irm https://raw.githubusercontent.com/gwblok/garytown/f64b267ba11c3a632ee0d19656875f93b715a989/OSD/CloudOSD/Set-ThisPC.ps1)}

if ((Get-CimInstance -ClassName Win32_ComputerSystem).Manufacturer -match "Lenovo"){
	Write-Host -ForegroundColor Green "[+] Function Install-LenovoDMM"
    function Install-LenovoDMM {
        $LenovoDMMURL = "https://download.lenovo.com/cdrt/tools/ldmm_1.0.0.zip"
        Invoke-WebRequest -UseBasicParsing -Uri $LenovoDMMURL -OutFile "$env:TEMP\ldmm.zip"
        Expand-Archive -Path "$env:TEMP\ldmm.zip" -DestinationPath "$env:ProgramFiles\WindowsPowerShell\Modules" -Force
        Import-Module LnvDeviceManagement -Force -Verbose
    }
}
