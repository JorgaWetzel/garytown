# start-autopilotoobe.osdcloud.ch
$Title = "Start-AutopilotOOBE"
$host.UI.RawUI.WindowTitle = $Title
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

$env:APPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Roaming"
$env:LOCALAPPDATA = "C:\Windows\System32\Config\SystemProfile\AppData\Local"
$Env:PSModulePath = $env:PSModulePath + ";C:\Program Files\WindowsPowerShell\Scripts"
$env:Path = $env:Path + ";C:\Program Files\WindowsPowerShell\Scripts"

[CmdletBinding()]
param()
#region Initialize

#Start the Transcript
$Transcript = "$((Get-Date).ToString('yyyy-MM-dd-HHmmss'))-OSDCloud.log"
$null = Start-Transcript -Path (Join-Path "$env:SystemRoot\Temp" $Transcript) -ErrorAction Ignore

#=================================================
#   oobeCloud Settings
#=================================================
$Global:oobeCloud = @{
    oobeSetDisplay = $true
    oobeSetRegionLanguage = $true
    oobeSetDateTime = $true
    oobeRegisterAutopilot = $false
    oobeRegisterAutopilotCommand = 'Get-WindowsAutopilotInfo -Online -GroupTag Demo -Assign'
    oobeRemoveAppxPackage = $true
    oobeRemoveAppxPackageName = 'CommunicationsApps','OfficeHub','People','Skype','Solitaire','Xbox','ZuneMusic','ZuneVideo'
    oobeAddCapability = $true
    oobeAddCapabilityName = 'GroupPolicy','ServerManager','VolumeActivation'
    oobeUpdateDrivers = $true
    oobeUpdateWindows = $true
    oobeRestartComputer = $true
    oobeStopComputer = $false
}

function Step-KeyboardLanguage {

    Write-Host -ForegroundColor Green "Set keyboard language to de-CH"
    Start-Sleep -Seconds 5
    
    $LanguageList = Get-WinUserLanguageList
    
    $LanguageList.Add("de-CH")
    Set-WinUserLanguageList $LanguageList -Force | Out-Null
    
    Start-Sleep -Seconds 5
    
    $LanguageList = Get-WinUserLanguageList
    $LanguageList.Remove(($LanguageList | Where-Object LanguageTag -like 'en-US'))
    Set-WinUserLanguageList $LanguageList -Force | Out-Null
}
function Step-oobeSetDisplay {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetDisplay -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Verify the Display Resolution and Scale is set properly'
        Start-Process 'ms-settings:display' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
}
function Step-oobeSetRegionLanguage {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetRegionLanguage -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Verify the Language, Region, and Keyboard are set properly'
        Start-Process 'ms-settings:regionlanguage' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
}
function Step-oobeSetDateTime {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeSetDateTime -eq $true)) {
        Write-Host -ForegroundColor Yellow 'Verify the Date and Time is set properly including the Time Zone'
        Write-Host -ForegroundColor Yellow 'If this is not configured properly, Certificates and Domain Join may fail'
        Start-Process 'ms-settings:dateandtime' | Out-Null
        $ProcessId = (Get-Process -Name 'SystemSettings').Id
        if ($ProcessId) {
            Wait-Process $ProcessId
        }
    }
}
function Step-oobeExecutionPolicy {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        if ((Get-ExecutionPolicy) -ne 'RemoteSigned') {
            Write-Host -ForegroundColor Cyan 'Set-ExecutionPolicy RemoteSigned'
            Set-ExecutionPolicy RemoteSigned -Force
        }
    }
}
function Step-oobePackageManagement {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        if (Get-Module -Name PowerShellGet -ListAvailable | Where-Object {$_.Version -ge '2.2.5'}) {
            Write-Host -ForegroundColor Cyan 'PowerShellGet 2.2.5 or greater is installed'
        }
        else {
            Write-Host -ForegroundColor Cyan 'Install-Package PackageManagement,PowerShellGet'
            Install-Package -Name PowerShellGet -MinimumVersion 2.2.5 -Force -Confirm:$false -Source PSGallery | Out-Null
    
            Write-Host -ForegroundColor Cyan 'Import-Module PackageManagement,PowerShellGet'
            Import-Module PackageManagement,PowerShellGet -Force
        }
    }
}
function Step-oobeTrustPSGallery {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $PSRepository = Get-PSRepository -Name PSGallery
        if ($PSRepository)
        {
            if ($PSRepository.InstallationPolicy -ne 'Trusted')
            {
                Write-Host -ForegroundColor Cyan 'Set-PSRepository PSGallery Trusted'
                Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
            }
        }
    }
}
function Step-oobeInstallModuleAutopilot {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Module AzureAD,Microsoft.Graph.Intune,WindowsAutopilotIntune'
            Install-Module WindowsAutopilotIntune -Force
        }
    }
}
function Step-oobeInstallModuleAzureAd {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Import-Module AzureAD -PassThru -ErrorAction Ignore
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Module AzureAD'
            Install-Module AzureAD -Force
        }
    }
}
function Step-oobeInstallScriptAutopilot {
    [CmdletBinding()]
    param ()
    if ($env:UserName -eq 'defaultuser0') {
        $Requirement = Get-InstalledScript -Name Get-WindowsAutoPilotInfo -ErrorAction SilentlyContinue
        if (-not $Requirement)
        {
            Write-Host -ForegroundColor Cyan 'Install-Script Get-WindowsAutoPilotInfo'
            Install-Script -Name Get-WindowsAutoPilotInfo -Force
        }
    }
}
function Step-oobeRegisterAutopilot {
    [CmdletBinding()]
    param (
        [System.String]
        $Command
    )
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRegisterAutopilot -eq $true)) {
        Step-oobeInstallModuleAutopilot
        Step-oobeInstallModuleAzureAd
        Step-oobeInstallScriptAutopilot

        Write-Host -ForegroundColor Cyan 'Registering Device in Autopilot in new PowerShell window ' -NoNewline
        $AutopilotProcess = Start-Process PowerShell.exe -ArgumentList "-Command $Command" -PassThru
        Write-Host -ForegroundColor Green "(Process Id $($AutopilotProcess.Id))"
        Return $AutopilotProcess
    }
}
function Step-oobeRemoveAppxPackage {
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRemoveAppxPackage -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Removing Appx Packages'
        foreach ($Item in $Global:oobeCloud.oobeRemoveAppxPackageName) {
            if (Get-Command Get-AppxProvisionedPackage) {
                Get-AppxProvisionedPackage -Online | Where-Object {$_.DisplayName -Match $Item} | ForEach-Object {
                    Write-Host -ForegroundColor DarkGray $_.DisplayName
                    if ((Get-Command Remove-AppxProvisionedPackage).Parameters.ContainsKey('AllUsers')) {
                        Try
                        {
                            $null = Remove-AppxProvisionedPackage -Online -AllUsers -PackageName $_.PackageName
                        }
                        Catch
                        {
                            Write-Warning "AllUsers Appx Provisioned Package $($_.PackageName) did not remove successfully"
                        }
                    }
                    else {
                        Try
                        {
                            $null = Remove-AppxProvisionedPackage -Online -PackageName $_.PackageName
                        }
                        Catch
                        {
                            Write-Warning "Appx Provisioned Package $($_.PackageName) did not remove successfully"
                        }
                    }
                }
            }
        }
    }
}
function Step-oobeAddCapability {
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeAddCapability -eq $true)) {
        Write-Host -ForegroundColor Cyan "Add-WindowsCapability"
        foreach ($Item in $Global:oobeCloud.oobeAddCapabilityName) {
            $WindowsCapability = Get-WindowsCapability -Online -Name "*$Item*" -ErrorAction SilentlyContinue | Where-Object {$_.State -ne 'Installed'}
            if ($WindowsCapability) {
                foreach ($Capability in $WindowsCapability) {
                    Write-Host -ForegroundColor DarkGray $Capability.DisplayName
                    $Capability | Add-WindowsCapability -Online | Out-Null
                }
            }
        }
    }
}
function Step-oobeUpdateDrivers {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeUpdateDrivers -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Updating Windows Drivers'
        if (!(Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore)) {
            try {
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate -Force
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Driver Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            Start-Process PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -UpdateType Driver -AcceptAll -IgnoreReboot" -Wait
        }
    }
}
function Step-oobeUpdateWindows {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeUpdateWindows -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Updating Windows'
        if (!(Get-Module PSWindowsUpdate -ListAvailable)) {
            try {
                Install-Module PSWindowsUpdate -Force
                Import-Module PSWindowsUpdate -Force
            }
            catch {
                Write-Warning 'Unable to install PSWindowsUpdate Windows Updates'
            }
        }
        if (Get-Module PSWindowsUpdate -ListAvailable -ErrorAction Ignore) {
            #Write-Host -ForegroundColor DarkCyan 'Add-WUServiceManager -MicrosoftUpdate -Confirm:$false'
            Add-WUServiceManager -MicrosoftUpdate -Confirm:$false | Out-Null
            #Write-Host -ForegroundColor DarkCyan 'Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot'
            #Install-WindowsUpdate -UpdateType Software -AcceptAll -IgnoreReboot -NotTitle 'Malicious'
            #Write-Host -ForegroundColor DarkCyan 'Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot'
            Start-Process PowerShell.exe -ArgumentList "-Command Install-WindowsUpdate -MicrosoftUpdate -AcceptAll -IgnoreReboot -NotTitle 'Preview' -NotKBArticleID 'KB890830','KB5005463','KB4481252'" -Wait
        }
    }
}
function Invoke-Webhook {
    $BiosSerialNumber = Get-MyBiosSerialNumber
    $ComputerManufacturer = Get-MyComputerManufacturer
    $ComputerModel = Get-MyComputerModel
    
    $URI = 'https://XXXX.webhook.office.com/webhookb2/YYYY'
    $JSON = @{
        "@type"    = "MessageCard"
        "@context" = "<http://schema.org/extensions>"
        "title"    = 'OSDCloud Information'
        "text"     = "The following client has been successfully deployed:<br>
                    BIOS Serial Number: **$($BiosSerialNumber)**<br>
                    Computer Manufacturer: **$($ComputerManufacturer)**<br>
                    Computer Model: **$($ComputerModel)**"
        } | ConvertTo-JSON
        
        $Params = @{
        "URI"         = $URI
        "Method"      = 'POST'
        "Body"        = $JSON
        "ContentType" = 'application/json'
        }
        Invoke-RestMethod @Params | Out-Null
}

function Step-oobeRestartComputer {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeRestartComputer -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Build Complete!'
        Write-Warning 'Device will restart in 30 seconds.  Press Ctrl + C to cancel'
        Stop-Transcript
        Start-Sleep -Seconds 30
        Restart-Computer
    }
}
function Step-oobeStopComputer {
    [CmdletBinding()]
    param ()
    if (($env:UserName -eq 'defaultuser0') -and ($Global:oobeCloud.oobeStopComputer -eq $true)) {
        Write-Host -ForegroundColor Cyan 'Build Complete!'
        Write-Warning 'Device will shutdown in 30 seconds. Press Ctrl + C to cancel'
        Stop-Transcript
        Start-Sleep -Seconds 30
        Stop-Computer
    }
}
#endregion

# Execute functions
#Step-KeyboardLanguage
#Step-oobeExecutionPolicy
#Step-oobePackageManagement
#Step-oobeTrustPSGallery
Step-oobeSetDisplay
#Step-oobeSetRegionLanguage
#Step-oobeSetDateTime
#Step-oobeRegisterAutopilot
#Step-oobeRemoveAppxPackage
#Step-oobeAddCapability
#Step-oobeUpdateDrivers
#Step-oobeUpdateWindows
#Invoke-Webhook
#Step-oobeRestartComputer
#Step-oobeStopComputer
#=================================================

Start-AutopilotOOBE

<#
Function Get-WindowsAutoPilotInfo {

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory=$False,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True,Position=0)][alias("DNSHostName","ComputerName","Computer")] [String[]] $Name = @("localhost"),
        [Parameter(Mandatory=$False)] [String] $OutputFile = "", 
        [Parameter(Mandatory=$False)] [String] $GroupTag = "",
        [Parameter(Mandatory=$False)] [String] $AssignedUser = "",
        [Parameter(Mandatory=$False)] [Switch] $Append = $false,
        [Parameter(Mandatory=$False)] [System.Management.Automation.PSCredential] $Credential = $null,
        [Parameter(Mandatory=$False)] [Switch] $Partner = $false,
        [Parameter(Mandatory=$False)] [Switch] $Force = $false,
        [Parameter(Mandatory=$True,ParameterSetName = 'Online')] [Switch] $Online = $false,
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $TenantId = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppId = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AppSecret = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AddToGroup = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [String] $AssignedComputerName = "",
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Assign = $false, 
        [Parameter(Mandatory=$False,ParameterSetName = 'Online')] [Switch] $Reboot = $false
    )

    Begin
    {
        # Initialize empty list
        $computers = @()

        # If online, make sure we are able to authenticate
        if ($Online) {

            # Get NuGet
            $provider = Get-PackageProvider NuGet -ErrorAction Ignore
            if (-not $provider) {
                Write-Host "Installing provider NuGet"
                Find-PackageProvider -Name NuGet -ForceBootstrap -IncludeDependencies
            }
            
            # Get WindowsAutopilotIntune module (and dependencies)
            $module = Import-Module WindowsAutopilotIntune -PassThru -ErrorAction Ignore
            if (-not $module) {
                Write-Host "Installing module WindowsAutopilotIntune"
                Install-Module WindowsAutopilotIntune -Force
            }
            Import-Module WindowsAutopilotIntune -Scope Global

            # Get Azure AD if needed
            if ($AddToGroup)
            {
                $module = Import-Module AzureAD -PassThru -ErrorAction Ignore
                if (-not $module)
                {
                    Write-Host "Installing module AzureAD"
                    Install-Module AzureAD -Force
                }
            }

            # Connect
            if ($AppId -ne "")
            {
                $graph = Connect-MSGraphApp -Tenant $TenantId -AppId $AppId -AppSecret $AppSecret
                Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
            }
            else {
                $graph = Connect-MSGraph
                Write-Host "Connected to Intune tenant $($graph.TenantId)"
                if ($AddToGroup)
                {
                    $aadId = Connect-AzureAD -AccountId $graph.UPN
                    Write-Host "Connected to Azure AD tenant $($aadId.TenantId)"
                }
            }

            # Force the output to a file
            if ($OutputFile -eq "")
            {
                $OutputFile = "$($env:TEMP)\autopilot.csv"
            } 
        }
    }

    Process
    {
        foreach ($comp in $Name)
        {
            $bad = $false

            # Get a CIM session
            if ($comp -eq "localhost") {
                $session = New-CimSession
            }
            else
            {
                $session = New-CimSession -ComputerName $comp -Credential $Credential
            }

            # Get the common properties.
            Write-Verbose "Checking $comp"
            $serial = (Get-CimInstance -CimSession $session -Class Win32_BIOS).SerialNumber

            # Get the hash (if available)
            $devDetail = (Get-CimInstance -CimSession $session -Namespace root/cimv2/mdm/dmmap -Class MDM_DevDetail_Ext01 -Filter "InstanceID='Ext' AND ParentID='./DevDetail'")
            if ($devDetail -and (-not $Force))
            {
                $hash = $devDetail.DeviceHardwareData
            }
            else
            {
                $bad = $true
                $hash = ""
            }

            # If the hash isn't available, get the make and model
            if ($bad -or $Force)
            {
                $cs = Get-CimInstance -CimSession $session -Class Win32_ComputerSystem
                $make = $cs.Manufacturer.Trim()
                $model = $cs.Model.Trim()
                if ($Partner)
                {
                    $bad = $false
                }
            }
            else
            {
                $make = ""
                $model = ""
            }

            # Getting the PKID is generally problematic for anyone other than OEMs, so let's skip it here
            $product = ""

            # Depending on the format requested, create the necessary object
            if ($Partner)
            {
                # Create a pipeline object
                $c = New-Object psobject -Property @{
                    "Device Serial Number" = $serial
                    "Windows Product ID" = $product
                    "Hardware Hash" = $hash
                    "Manufacturer name" = $make
                    "Device model" = $model
                }
                # From spec:
                # "Manufacturer Name" = $make
                # "Device Name" = $model

            }
            else
            {
                # Create a pipeline object
                $c = New-Object psobject -Property @{
                    "Device Serial Number" = $serial
                    "Windows Product ID" = $product
                    "Hardware Hash" = $hash
                }
                
                if ($GroupTag -ne "")
                {
                    Add-Member -InputObject $c -NotePropertyName "Group Tag" -NotePropertyValue $GroupTag
                }
                if ($AssignedUser -ne "")
                {
                    Add-Member -InputObject $c -NotePropertyName "Assigned User" -NotePropertyValue $AssignedUser
                }
            }

            # Write the object to the pipeline or array
            if ($bad)
            {
                # Report an error when the hash isn't available
                Write-Error -Message "Unable to retrieve device hardware data (hash) from computer $comp" -Category DeviceError
            }
            elseif ($OutputFile -eq "")
            {
                $c
            }
            else
            {
                $computers += $c
                Write-Host "Gathered details for device with serial number: $serial"
            }

            Remove-CimSession $session
        }
    }

    End
    {
        if ($OutputFile -ne "")
        {
            if ($Append)
            {
                if (Test-Path $OutputFile)
                {
                    $computers += Import-CSV -Path $OutputFile
                }
            }
            if ($Partner)
            {
                $computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Manufacturer name", "Device model" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            elseif ($AssignedUser -ne "")
            {
                $computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag", "Assigned User" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            elseif ($GroupTag -ne "")
            {
                $computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash", "Group Tag" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
            else
            {
                $computers | Select-Object "Device Serial Number", "Windows Product ID", "Hardware Hash" | ConvertTo-CSV -NoTypeInformation | % {$_ -replace '"',''} | Out-File $OutputFile
            }
        }
        if ($Online)
        {
            # Add the devices
            $importStart = Get-Date
            $imported = @()
            $computers | % {
                $imported += Add-AutopilotImportedDevice -serialNumber $_.'Device Serial Number' -hardwareIdentifier $_.'Hardware Hash' -groupTag $_.'Group Tag' -assignedUser $_.'Assigned User'
            }

            # Wait until the devices have been imported
            $processingCount = 1
            while ($processingCount -gt 0)
            {
                $current = @()
                $processingCount = 0
                $imported | % {
                    $device = Get-AutopilotImportedDevice -id $_.id
                    if ($device.state.deviceImportStatus -eq "unknown") {
                        $processingCount = $processingCount + 1
                    }
                    $current += $device
                }
                $deviceCount = $imported.Length
                Write-Host "Waiting for $processingCount of $deviceCount to be imported"
                if ($processingCount -gt 0){
                    Start-Sleep 30
                }
            }
            $importDuration = (Get-Date) - $importStart
            $importSeconds = [Math]::Ceiling($importDuration.TotalSeconds)
            $successCount = 0
            $current | % {
                Write-Host "$($device.serialNumber): $($device.state.deviceImportStatus) $($device.state.deviceErrorCode) $($device.state.deviceErrorName)"
                if ($device.state.deviceImportStatus -eq "complete") {
                    $successCount = $successCount + 1
                }
            }
            Write-Host "$successCount devices imported successfully. Elapsed time to complete import: $importSeconds seconds"
            
            # Wait until the devices can be found in Intune (should sync automatically)
            $syncStart = Get-Date
            $processingCount = 1
            while ($processingCount -gt 0)
            {
                $autopilotDevices = @()
                $processingCount = 0
                $current | % {
                    if ($device.state.deviceImportStatus -eq "complete") {
                        $device = Get-AutopilotDevice -id $_.state.deviceRegistrationId
                        if (-not $device) {
                            $processingCount = $processingCount + 1
                        }
                        $autopilotDevices += $device
                    }    
                }
                $deviceCount = $autopilotDevices.Length
                Write-Host "Waiting for $processingCount of $deviceCount to be synced"
                if ($processingCount -gt 0){
                    Start-Sleep 30
                }
            }
            $syncDuration = (Get-Date) - $syncStart
            $syncSeconds = [Math]::Ceiling($syncDuration.TotalSeconds)
            Write-Host "All devices synced. Elapsed time to complete sync: $syncSeconds seconds"

            # Add the device to the specified AAD group
            if ($AddToGroup)
            {
                $aadGroup = Get-AzureADGroup -Filter "DisplayName eq '$AddToGroup'"
                if ($aadGroup)
                {
                    $autopilotDevices | % {
                        $aadDevice = Get-AzureADDevice -ObjectId "deviceid_$($_.azureActiveDirectoryDeviceId)"
                        if ($aadDevice) {
                            Write-Host "Adding device $($_.serialNumber) to group $AddToGroup"
                            Add-AzureADGroupMember -ObjectId $aadGroup.ObjectId -RefObjectId $aadDevice.ObjectId
                        }
                        else {
                            Write-Error "Unable to find Azure AD device with ID $($_.azureActiveDirectoryDeviceId)"
                        }
                    }
                    Write-Host "Added devices to group '$AddToGroup' ($($aadGroup.ObjectId))"
                }
                else {
                    Write-Error "Unable to find group $AddToGroup"
                }
            }

            # Assign the computer name
            if ($AssignedComputerName -ne "")
            {
                $autopilotDevices | % {
                    Set-AutopilotDevice -Id $_.Id -displayName $AssignedComputerName
                }
            }

            # Wait for assignment (if specified)
            if ($Assign)
            {
                $assignStart = Get-Date
                $processingCount = 1
                while ($processingCount -gt 0)
                {
                    $processingCount = 0
                    $autopilotDevices | % {
                        $device = Get-AutopilotDevice -id $_.id -Expand
                        if (-not ($device.deploymentProfileAssignmentStatus.StartsWith("assigned"))) {
                            $processingCount = $processingCount + 1
                        }
                    }
                    $deviceCount = $autopilotDevices.Length
                    Write-Host "Waiting for $processingCount of $deviceCount to be assigned"
                    if ($processingCount -gt 0){
                        Start-Sleep 30
                    }    
                }
                $assignDuration = (Get-Date) - $assignStart
                $assignSeconds = [Math]::Ceiling($assignDuration.TotalSeconds)
                Write-Host "Profiles assigned to all devices. Elapsed time to complete assignment: $assignSeconds seconds"    
                if ($Reboot)
                {
                    Restart-Computer -Force
                }
            }
        }
    }
}
#>
