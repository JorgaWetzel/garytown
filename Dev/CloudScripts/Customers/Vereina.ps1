#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

#Write-Host -ForegroundColor Green "Updating OSD PowerShell Module"
#Install-Module OSD -Force

#Write-Host  -ForegroundColor Green "Importing OSD PowerShell Module"
#Import-Module OSD -Force   

# https://github.com/gvillant/OSDCloud/blob/main/Labws1.ps1#L137

#=======================================================================
#   [OS] Params and Start-OSDCloud
#=======================================================================
$Params = @{
    OSVersion = "Windows 11"
    OSBuild = "24H2"
    OSEdition = "Pro"
    OSLanguage = "de-de"
    OSLicense = "Retail"
    ZTI = $true
    Firmware = $true
    SkipODT = $true
}
Start-OSDCloud @Params


#=================================================
#	Copy PSModule
#=================================================
Write-Verbose -Verbose "Copy-PSModuleToFolder -Name OSD to C:\Program Files\WindowsPowerShell\Modules"
Copy-PSModuleToFolder -Name OSD -Destination 'C:\Program Files\WindowsPowerShell\Modules'

#================================================
#  [PostOS] Download OEM Direcotry Structure
#================================================
function Install-OOBEFiles {
    $user = 'oneict'
    $pass = 'ca228ffca20d54e486aa7d16a2881caa'
    $pair = "$($user):$($pass)"
    $encodedCreds = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($pair))
    $basicAuthValue = "Basic $encodedCreds"
    $Headers = @{
        Authorization = $basicAuthValue
    }
    
    # current Direcotry
    # $toolsDir  = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
    
    #region " Adding registry values
    # Log generation
    $Log = @{
        Path    = "$env:windir\SoftwareDistribution\ChocolateyOneICT.log"
        Append  = $true
        Force   = $true
        Confirm = $false
        Verbose = $true
     }
    Start-Transcript @Log
    
    # current Direcotry
    # $toolsDir  = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
    
    ## Result object initialization
    [psObject]$Result = @()
    ## Certificate variables
    [array]$cerStores =@('TrustedPeople')
    #[array]$cerStores =@('Root','TrustedPublisher')
    [string]$cerStringBase64 = '
        MIIDHjCCAgagAwIBAgIQRizTpDRlhoFD4U+UNY252zANBgkqhkiG9w0BAQsFADAW
        MRQwEgYDVQQDDAtjaG9jb3NlcnZlcjAeFw0yMTAzMjYwODQwMTFaFw0zMTAzMjYw
        ODUwMTFaMBYxFDASBgNVBAMMC2Nob2Nvc2VydmVyMIIBIjANBgkqhkiG9w0BAQEF
        AAOCAQ8AMIIBCgKCAQEA4itTLVCBZzGArFtfd1wvq6EVnlnYxg3NGuooCu1K5GmB
        RgmtBcznLAIeuNCnJPCALHAgFLZ2cAtMCqxa4X7cYa7ojQWlbc6H7Jt7Dy8tvKit
        +Xb4yILVrgL5YQAKrYG+5CRs1gYe8eTp4Laa2ZS4mMAyoK23bL6943rx973DgIs4
        H1WcccldjPu20flStSGOMKXrJIWnsSvNkZDEcHVGhNsPEjwLnqdl7RltIBnxWg6L
        XYck8WPfXy/t/6f60WP3f3rphDWGe14szPrJyWVfNA3l9iEM9p8LYGe0w/2PpJyW
        0Qx36PiqPYn8kxg7QPolzc8+t6EqvYXDfuLD0XNkqQIDAQABo2gwZjAOBgNVHQ8B
        Af8EBAMCBaAwHQYDVR0lBBYwFAYIKwYBBQUHAwIGCCsGAQUFBwMBMBYGA1UdEQQP
        MA2CC2Nob2Nvc2VydmVyMB0GA1UdDgQWBBS5pq0yR7ODHDKEBIIzatiWi5mIWjAN
        BgkqhkiG9w0BAQsFAAOCAQEApuwaG95LukG/ADRSyoiOKoRBfT6MRp5DO81cBtpP
        E1jFyVruLVdx0TpdzDqSDRLphtRBV5oq2/zpnmalSwgdXHaLIe7lk8+0MMazLaAZ
        twjgwlb5mhV5BoPjTAx81Fzqc+OIfs05VV/7XzcTGyl0XUNd4eHDOD8CeCZOAi5X
        Gb+QRAinEL+LwR6vCb2bPVkBAWXBAxkvEkGC1XNTItJBw/UuVSnTXHa8vzrzIki0
        PNCZibGVfGzPAoZ8lgNSzafQ906JUvj40TU2/zU3bYv8p0PjNGxbLwHoIs0CWEns
        90ET2O53719uoXf4UT4xJy967gGVwJxVRJER7IDiIjB9ig==
    '
        #region Function Add-Certificate
        Function Add-Certificate {
            [CmdletBinding()]
            Param (
                [Parameter(Mandatory=$true,Position=0)]
                [Alias('cString')]
                [string]$cerStringBase64,
                [Parameter(Mandatory=$false,Position=1)]
                [Alias('cLocation')]
                [string]$cerStoreLocation = 'LocalMachine',
                [Parameter(Mandatory=$true,Position=2)]
                [Alias('cStore')]
                [string]$cerStoreName
            )
    
            ## Create certificate store object
            $cerStore = New-Object System.Security.Cryptography.X509Certificates.X509Store $cerStoreName, $cerStoreLocation -ErrorAction 'Stop'
    
            ## Open the certificate store as Read/Write
            $cerStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    
            ## Convert the base64 string
            $certByteArray = [System.Convert]::FromBase64String($cerStringBase64)
    
            ## Create new certificate object
            $Certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ErrorAction 'Stop'
    
            ## Add certificate to the store
            $Certificate.Import($certByteArray)
            $cerStore.Add($Certificate)
    
            ## Close the certificate store
            $cerStore.Close()
        }
    
        ## Cycle specified certificate stores and add the specified certificate
        ForEach ($cerStore in $cerStores) {
            Try {
                Add-Certificate -cerStringBase64 $cerStringBase64 -cerStoreName $cerStore -ErrorAction 'Stop'
    
                #  Create the Result Props
                $ResultProps = [ordered]@{
                    'Store' = $cerStore
                    'Status'  = 'Add Certificate - Success!'
                }
    
                #  Adding ResultProps hash table to result object
                $Result += New-Object 'PSObject' -Property $ResultProps
            }
            Catch {
    
                #  Create the Result Props
                $ResultProps = [ordered]@{
                    'Store' = $cerStore
                    'Status'  = 'Add Certificate - Failed!'
                    'Error' = $_
                }
    
                #  Adding ResultProps hash table to result object
                $Result += New-Object 'PSObject' -Property $ResultProps
            }
        }
    
        ## Error handling. If we don't write a stdError when the script fails SCCM will return 'Compliant' because the
        ## Discovery script does not run again after the Remediation script
        If ($Error.Count -ne 0) {
    
            #  Return result object as an error removing table header for cleaner reporting
            $host.ui.WriteErrorLine($($Result | Format-Table -HideTableHeaders | Out-String))
        }
        Else {
    
            #  Return result object removing table header for cleaner reporting
            Write-Output -InputObject $($Result | Format-Table -HideTableHeaders | Out-String)
        }
    
        Add-Content $ENV:WinDir\System32\Drivers\etc\hosts "## oneICT chocolatey repo"
        Add-Content $ENV:WinDir\System32\Drivers\etc\hosts "195.49.62.108 chocoserver"
    
    Write-Verbose "Downloading OEM" -Verbose
    $uri = "https://chocoserver:8443/repository/oneict/Vereina/VereinaOEM.zip"
    $PackageName = $uri.Substring($uri.LastIndexOf("/") + 1)
    Invoke-WebRequest -Uri $uri -OutFile "C:\Windows\Temp\$PackageName" -Headers $Headers
    Expand-Archive -Force -Path C:\Windows\Temp\$PackageName -DestinationPath C:\
    # Remove-Item c:\
    # Move-Item -Path $Source\Applications\ -Destination $Target -Force
    }
    Install-OOBEFiles

    #================================================
    #  [PostOS] OOBEDeploy Configuration
    #================================================
    Write-Host -ForegroundColor Cyan "Create C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json"
    $OOBEDeployJson = @'
    {
        "Autopilot":  {
                        "IsPresent":  false
                    },
        "RemoveAppx":  [
                        "Microsoft.549981C3F5F10",
                            "Microsoft.BingWeather",
                            "Microsoft.GetHelp",
                            "Microsoft.Getstarted",
                            "Microsoft.Microsoft3DViewer",
                            "Microsoft.MicrosoftOfficeHub",
                            "Microsoft.MicrosoftSolitaireCollection",
                            "Microsoft.MixedReality.Portal",
                            "Microsoft.Office.OneNote",
                            "Microsoft.People",
                            "Microsoft.SkypeApp",
                            "Microsoft.Wallet",
                            "Microsoft.WindowsCamera",
                            "microsoft.windowscommunicationsapps",
                            "Microsoft.WindowsFeedbackHub",
                            "Microsoft.WindowsMaps",
                            "Microsoft.Xbox.TCUI",
                            "Microsoft.XboxApp",
                            "Microsoft.XboxGameOverlay",
                            "Microsoft.XboxGamingOverlay",
                            "Microsoft.XboxIdentityProvider",
                            "Microsoft.XboxSpeechToTextOverlay",
                            "Microsoft.YourPhone",
                            "Microsoft.ZuneMusic",
                            "Microsoft.ZuneVideo"
                    ],
        "UpdateDrivers":  {
                            "IsPresent":  true
                        },
        "UpdateWindows":  {
                            "IsPresent":  true
                        }
    }
'@
    If (!(Test-Path "C:\ProgramData\OSDeploy")) {
        New-Item "C:\ProgramData\OSDeploy" -ItemType Directory -Force | Out-Null
    }
    $OOBEDeployJson | Out-File -FilePath "C:\ProgramData\OSDeploy\OSDeploy.OOBEDeploy.json" -Encoding ascii -Force

#=======================================================================
#   Restart-Computer
#=======================================================================
Write-Host  -ForegroundColor Green "Restarting in 5 seconds!"
Start-Sleep -Seconds 5
wpeutil reboot
