
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



$SecureBootRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot'
$SecureBootKey = Get-Item -Path $SecureBootRegPath
$SecureBootRegValue = $SecureBootKey.GetValue("AvailableUpdates")
$RemediationRegPath = 'HKLM:\SOFTWARE\Remediation\KB5025885'
if (Test-Path -Path $RemediationRegPath){
    $Key = Get-Item -Path $RemediationRegPath
    $Step3Success = ($Key).GetValue('Step3Success')
    $Step3Set0x80 = ($Key).GetValue('Step3Set0x80') 
}
else{
    New-Item -Path $RemediationRegPath -Force -ItemType Directory | Out-Null
}
$Last9Reboots = (Get-WinEvent -LogName System -MaxEvents 10 -FilterXPath "*[System[EventID=6005]]" | Select-Object -Property TimeCreated).TimeCreated
[datetime]$SecondToLastReboot = $Last9Reboots | Select-Object -First 2 | Select-Object -Last 1

if ($null -ne $Step2Set0x100){
    #Convert $Step1Set0x40 into Datetime
    $Step3Set0x80 = [System.DateTime]::ParseExact($Step3Set0x80, "yyyyMMddHHmmss", $null)
}
else{
    $Step3Set0x80 = Get-Date
}
$CountOfRebootsSinceRemediation = ($Last9Reboots | Where-Object {$_ -gt $Step3Set0x80}).Count

if ($null -ne $Step3Success){
    if ($Step3Success -eq 1){
        $Step3Success = $true
    }
    else {
        $Step3Success = $false
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
#If all 3 steps are complete, remediation is not needed, exit 


#If we detect steps are done, and we stamped the registry, we can assume the reboots are complete and we're good
if ($Step1Success -eq $true -and $Step1Complete -eq $true -and $Step2Success -eq $true -and $Step2Complete -eq $true-and $Step3Success -eq $true -and $Step3Complete -eq $true){
    Write-Output "Step 3 Complete | SBKey: $SecureBootRegValue"
    exit 0
}
#If Steps 1 & 2 are complete, and we're on reboot 2, all is well, exit 0
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $CountOfRebootsSinceRemediation -ge 2){
    Write-Output "Step 3 Complete | SBKey: $SecureBootRegValue"
    if ($Null -eq $Step2Success){
        New-ItemProperty -Path $RemediationRegPath -Name  "Step3Success" -PropertyType dword -Value 1 -Force | Out-Null
    }
    exit 0
}
#If Steps 1 & 2 are complete, and we're on less than 2 reboots, we probably need another reboot.
if ($Step1Complete -eq $true -and $Step2Complete -eq $true -and $Step3Complete -eq $true -and $CountOfRebootsSinceRemediation -lt 2){
    Write-Output "Step 1 2 & 3 Complete, but Reboot less than 2: Needs Remediation (another reboot) | SBKey: $SecureBootRegValue"
    exit 1
}
#if Step 1 not complete, this is a dependency on a different remediation to finish, exit 2
if ($Step1Complete -ne $true){
    Write-Output "Dependency not complete | Step 1 - 2023 Cert Not Found in DB: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 2
}
#If Step 2 is not complete, remediation is needed, exit 1
if ($Step2Complete -ne $true){
    Write-Output "Dependency not complete | Step 2 - Boot Manager Not Updated: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 2
}
if ($Step3Complete -ne $true){
    Write-Output "Step 3 - Applying the DBX update: Needs Remediation | SBKey: $SecureBootRegValue"
    exit 1
}
#endregion Remediation
    
