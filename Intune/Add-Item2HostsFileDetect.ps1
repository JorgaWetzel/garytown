

#This Script will be used to add computer names & IPs to the hosts file
$Servers2Add = @(
    @{SERVERNAME = "2PSR210 " ; IPAddress = "192.168.20.25"}
    @{SERVERNAME = "2PSR210.2p.garytown.com" ; IPAddress = "192.168.20.25"}
    @{SERVERNAME = "2PStifleRMOM " ; IPAddress = "192.168.20.10"}
    @{SERVERNAME = "2PStifleRMOM.2p.garytown.com" ; IPAddress = "192.168.20.10"}
)


#Get IP Address and run if IP Address starts with 192.168.1
$IPAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.1.*" }).IPAddress
if (-not $IPAddress) {
    Write-Output "The script will not run because the IP address does not start with 192.168.1."
    exit
}
Write-Output "IP address starts with 192.168.1. Proceeding with the script..."


function Test-HostFileEntry{
    param (
        [string]$ServerName,
        [string]$IPAddress
    )

    $HostFilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    $HostFileEntry = "$ServerName   $IPAddress"
    
    # Check if the entry already exists in the hosts file
    if (Select-String -Path $HostFilePath -Pattern $ServerName) {

        Write-Output "Entry for $ServerName already exists in the hosts file."
        return $true
    } else {
        Write-Output "Entry for $ServerName does not exist in the hosts file."
        return $false
    }
}

# Loop through each server and add the entry to the hosts file
foreach ($Server in $Servers2Add) {
    $ServerName = $Server.SERVERNAME
    $IPAddress = $Server.IPAddress
    if ((Test-HostFileEntry -ServerName $ServerName -IPAddress $IPAddress) -eq $false) {
        Write-Output "Does not exist, Triggering Remediation"
        exit 1
    }
}
