<# 
    Gary Blok & Mike Terrill
    KB5025885 Remediation Script
    Part 2 of 4
#>

function Set-PendingUpdate {
    # Set the registry key to indicate a pending update
    $RebootRequiredPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"
    if (-not (Test-Path $RebootRequiredPath)) {New-Item -Path $RebootRequiredPath -Force | Out-Null}
    # Create a value to indicate a pending update
    New-ItemProperty -Path $RebootRequiredPath -Name "UpdatePending" -Value 1 -PropertyType DWord -Force | Out-Null

    # Set the orchestrator key to 15
    $OrchestratorPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator"
    if (-not (Test-Path $OrchestratorPath)) {New-Item -Path $OrchestratorPath -Force | Out-Null}
    $Values = get-item -Path $OrchestratorPath
    if (($Null -eq $Values.GetValue('ShutdownFlyoutOptions')) -or ($Values.GetValue('ShutdownFlyoutOptions') -eq 0)){
        New-ItemProperty -Path $OrchestratorPath -Name "ShutdownFlyoutOptions" -Value 10 -PropertyType DWord -Force | Out-Null
    }
    if (($Null -eq $Values.GetValue('EnhancedShutdownEnabled')) -or ($Values.GetValue('EnhancedShutdownEnabled') -eq 0)){
        New-ItemProperty -Path $OrchestratorPath -Name "EnhancedShutdownEnabled" -Value 1 -PropertyType DWord -Force | Out-Null
    }

    $RebootDowntimePath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\RebootDowntime"
    if (-not (Test-Path $RebootDowntimePath)) {New-Item -Path $RebootDowntimePath -Force | Out-Null}
    $Values = get-item -Path $RebootDowntimePath
    if (($Null -eq $Values.GetValue('DowntimeEstimateHigh')) -or ($Values.GetValue('DowntimeEstimateHigh') -eq 0)){
        New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateHigh" -Value 1 -PropertyType DWord -Force | Out-Null
    }
    if (($Null -eq $Values.GetValue('DowntimeEstimateLow')) -or ($Values.GetValue('DowntimeEstimateLow') -eq 0)){
        New-ItemProperty -Path $RebootDowntimePath -Name "DowntimeEstimateLow" -Value 1 -PropertyType DWord -Force | Out-Null
    }
}


#Test if Remediation is applicable
#Region Applicability
$CurrentOSInfo = Get-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
$Build = $CurrentOSInfo.GetValue('CurrentBuild')
[int]$UBR = $CurrentOSInfo.GetValue('UBR')

#July 2024 UBRs
$JulyPatch = @('19045.4651','22621.3880','22631.3880','26100.1150','26120.1')
$MatchedPatch = $JulyPatch | Where-Object {$_ -match $Build}
if ($null -eq $MatchedPatch){
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    exit 5
}
[int]$MatchedUBR = $MatchedPatch.split(".")[1]

if ($UBR -ge $MatchedUBR){
    #$OSSupported = $true
}
else {
    #$OSSupported = $false
    Write-Output "The OS ($Build.$UBR) is not supported for this remediation."
    exit 5
}
if (Confirm-SecureBootUEFI -ErrorAction SilentlyContinue) {
    #This is required for remediation to work
}
else {
    Write-Output "Secure Boot is not enabled."
    exit 4
}
#endregion Applicability



$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediation\KB5025885'

#TimeStamp when Remediation last Ran
$DetectionTime = Get-Date -Format "yyyyMMddHHmmss"
New-ItemProperty -Path $RemediationRegPath -Name "Step34LastRemediationTime" -Value $DetectionTime -PropertyType String -Force | Out-Null


if (Test-Path -Path $RemediationRegPath){
    $Key = Get-Item -Path $RemediationRegPath
    $Step34Success = ($Key).GetValue('Step34Success')
    $Step34Set0x280 = ($Key).GetValue('Step34Set0x280') 
}
else{
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
$Last9Reboots = (Get-WinEvent -LogName System -MaxEvents 10 -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated).TimeCreated
[datetime]$SecondToLastReboot = $Last9Reboots | Select-Object -First 2 | Select-Object -Last 1

if ($null -ne $Step34Set0x280){
    #Convert $Step1Set0x40 into Datetime
    $Step34Set0x280 = [System.DateTime]::ParseExact($Step34Set0x280, "yyyyMMddHHmmss", $null)
}
else{
    $Step34Set0x280 = Get-Date
    New-ItemProperty -Path $RemediationRegPath -Name "Step34Set0x280" -PropertyType string -Value $DetectionTime -Force | Out-Null
}
$CountOfRebootsSinceRemediation = ($Last9Reboots | Where-Object {$_ -gt $Step34Set0x280}).Count

if ($null -ne $Step34Success){
    if ($Step34Success -eq 1){
        $Step34Success = $true
    }
    else {
        $Step34Success = $false
    }
}

#region Test if Remediation is already applied for each Step
#Test: Applying the DB update
$Step1Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI db).bytes) -match 'Windows UEFI CA 2023'

#Test: Updating the boot manager
$Volume = Get-Volume | Where-Object {$_.FileSystemType -eq "FAT32" -and $_.DriveType -eq "Fixed"}
$SystemDisk = Get-Disk | Where-Object {$_.IsSystem -eq $true}
$SystemPartition = Get-Partition -DiskNumber $SystemDisk.DiskNumber | Where-Object {$_.IsSystem -eq $true}  
$SystemVolume = $Volume | Where-Object {$_.UniqueId -match $SystemPartition.Guid}
$FilePath = "$($SystemVolume.Path)\EFI\Microsoft\Boot\bootmgfw.efi"
$CertCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
$CertCollection.Import($FilePath, $null, 'DefaultKeySet')
If ($CertCollection.Subject -like "*Windows UEFI CA 2023*") {$Step2Complete = $true}
else {$Step2Complete = $false}

#Test: Applying the DBX update
$Step3Complete = [System.Text.Encoding]::ASCII.GetString((Get-SecureBootUEFI dbx).bytes) -match 'Microsoft Windows Production PCA 2011'

#endregion Test if Remediation is already applied for each Step

#region Remediation


#If Steps 1 & 2 are complete, and we're on reboot 2, all is well, exit 0
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $CountOfRebootsSinceRemediation -ge 2){
    Write-Output "Step 3/4 Complete | SBKey: $SecureBootRegValue"
    if ($Null -eq $Step34Success){
        New-ItemProperty -Path $RemediationRegPath -Name  "Step34Success" -PropertyType dword -Value 1 -Force | Out-Null
    }
    exit 0
}
#If Steps 1 & 2 are complete, and we're on less than 2 reboots, we probably need another reboot.
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $CountOfRebootsSinceRemediation -lt 2){
    Write-Output "Step 1 2 3 & 4 Complete, but Reboot less than 2: Needs Remediation (another reboot) | SBKey: $SecureBootRegValue"
    Set-PendingUpdate
    exit 0
}
#if Step 1 not complete, this is a dependency on a different remediation to finish, exit 2
if ($Step1Complete -ne $true){
    Write-Output "Dependency not complete | Step 1 - 2023 Cert Not Found in DB: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 2
}
if ($Step2Complete -ne $true){
    Write-Output "Dependency not complete | Step 2 - Boot Manager Not Updated: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 2
}
#If Step 2 is not complete, remediation is needed, exit 1
if ($Step3Complete -ne $true){
    New-ItemProperty -Path $SecureBootRegPath -Name "AvailableUpdates" -PropertyType dword -Value 0x280 -Force
    Write-Output "Step 34 - Update DBX & SVN Required: Set AvailableUpdates from $SecureBootRegValue to 0x280"
    Set-PendingUpdate
    exit 0
}

#endregion Remediation
    
