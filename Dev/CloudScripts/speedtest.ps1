<#
.SYNOPSIS
	Downloads and runs the Speedtest.net CLI client.
.DESCRIPTION
	Downloads and runs the Speedtest.net CLI client.

Designed to use with short URL to make it easy to remember.
.EXAMPLE
	speedtest.ps1
.PARAMETER Version
    Displays the version of the script.
.PARAMETER Help
    Displays the full help information for the script.
.NOTES
	Version      : 0.9
	Created by   : Akos Bakos
                   KUDOS goes to Asheroto for the original script (https://github.com/asheroto/speedtest)
#>
param (
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$ScriptArgs
)

#region Helper Functions
function Write-DarkGrayDate {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [System.String]
        $Message
    )
    if ($Message) {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) $Message"
    }
    else {
        Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
    }
}
function Write-DarkGrayHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $Message
    )
    Write-Host -ForegroundColor DarkGray $Message
}
function Write-DarkGrayLine {
    [CmdletBinding()]
    param ()
    Write-Host -ForegroundColor DarkGray "========================================================================="
}
function Write-SectionHeader {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, Position=0)]
        [System.String]
        $Message
    )
    Write-DarkGrayLine
    Write-DarkGrayDate
    Write-Host -ForegroundColor Cyan $Message
}
function Write-SectionSuccess {
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [System.String]
        $Message = 'Success!'
    )
    Write-DarkGrayDate
    Write-Host -ForegroundColor Green $Message
}
#endregion

#Versions
$ProgressPreference = 'SilentlyContinue' # Suppress progress bar (makes downloading super fast)
$ConfirmPreference = 'None' # Suppress confirmation prompts

#Display version if -Version is specified
if ($Version.IsPresent) {
    $CurrentVersion
    exit 0
}

#Display full help if -Help is specified
if ($Help) {
    Get-Help -Name $MyInvocation.MyCommand.Source -Full
    exit 0
}

#Display $PSVersionTable and Get-Host if -Verbose is specified
if ($PSBoundParameters.ContainsKey('Verbose') -and $PSBoundParameters['Verbose']) {
    $PSVersionTable
    Get-Host
}

#region Scrape the webpage to get the download link
function Get-SpeedTestDownloadLink {
    $url = "https://www.speedtest.net/apps/cli"
    $webContent = Invoke-WebRequest -Uri $url -UseBasicParsing
    if ($webContent.Content -match 'href="(https://install\.speedtest\.net/app/cli/ookla-speedtest-[\d\.]+-win64\.zip)"') {
        return $matches[1]
    } else {
        Write-Output "Unable to find the win64 zip download link."
        return $null
    }
}
#endregion

#region Download and extract the zip file
function Download-SpeedTestZip {
    param (
        [string]$downloadLink,
        [string]$destination
    )
    Invoke-WebRequest -Uri $downloadLink -OutFile $destination -UseBasicParsing
}

function Extract-Zip {
    param (
        [string]$zipPath,
        [string]$destination
    )
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $destination)
}
#endregion

#region Run the speedtest executable
function Run-SpeedTest {
    param (
        [string]$executablePath,
        [array]$arguments
    )

    # Check if '--accept-license' is already in arguments
    if (-not ($arguments -contains "--accept-license")) {
        $arguments += "--accept-license"
    }

    # Check if '--accept-gdpr' is already in arguments
    if (-not ($arguments -contains "--accept-gdpr")) {
        $arguments += "--accept-gdpr"
    }

    $Result = & $executablePath $arguments

    return $Result
}
#endregion

#region Cleanup
function Remove-File {
    param (
        [string]$Path
    )
    try {
        if (Test-Path -Path $Path) {
            Remove-Item -Path $Path -Recurse -ErrorAction Stop
        }
    } catch {
        Write-Debug "Unable to remove item: $_"
    }
}

function Remove-Files {
    param(
        [string]$zipPath,
        [string]$folderPath
    )
    Remove-File -Path $zipPath
    Remove-File -Path $folderPath
}
#endregion

#region Main Script
try {
    $tempFolder = $env:TEMP
    $zipFilePath = Join-Path $tempFolder "speedtest-win64.zip"
    $extractFolderPath = Join-Path $tempFolder "speedtest-win64"

    Remove-Files -zipPath $zipFilePath -folderPath $extractFolderPath

    $downloadLink = Get-SpeedTestDownloadLink
    Write-SectionHeader "Downloading SpeedTest CLI"
    Download-SpeedTestZip -downloadLink $downloadLink -destination $zipFilePath

    Write-SectionHeader "Extracting Zip File"
    Extract-Zip -zipPath $zipFilePath -destination $extractFolderPath

    $executablePath = Join-Path $extractFolderPath "speedtest.exe"
    Write-SectionHeader "Running SpeedTest"
    $Result = Run-SpeedTest -executablePath $executablePath -arguments $ScriptArgs

    $DownloadSpeed = [regex]::match(($Result | where-object { $_ -like "*Download:*" }).trim(), '[0-9]+\.?[0-9]*').value
    $UploadSpeed = [regex]::match(($Result | where-object { $_ -like "*Upload:*" }).trim(), '[0-9]+\.?[0-9]*').value
    #$ISP = ($Result | where-object { $_ -like "*ISP:*" }).trim().split(":")[1].trim()
    #$server = ($Result | where-object { $_ -like "*Server:*" }).trim().split(":")[1].trim()
    $SpeedTestURL = ($Result | where-object { $_ -like "*Result URL:*" }).trim().split(" ")[2].trim()

    Write-DarkGrayLine
    Write-Host -ForegroundColor Green "Download: $DownloadSpeed Mbps"
    Write-Host -ForegroundColor Green "Upload: $UploadSpeed Mbps"
    Write-Host -ForegroundColor Green "Result URL: $SpeedTestURL"

    $WiFiSignal = (netsh wlan show interfaces) -Match '^\s+Signal' -Replace '^\s+Signal\s+:\s+',''
    if ($WiFiSignal) {
        Write-Host -ForegroundColor Green "WiFi Signal: $WiFiSignal"
    } else {
        Write-Host -ForegroundColor Green "Wired installation"
    }

    Write-SectionHeader "Cleaning up"
    Remove-Files -zipPath $zipFilePath -folderPath $extractFolderPath

    Write-SectionSuccess "Done"
} catch {
    Write-Error "An error occurred: $_"
}
#endregion
