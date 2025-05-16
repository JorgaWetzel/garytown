#Load Dell EMPS
Clear-Host

Write-Host "Loading Dell EMPS module..." -ForegroundColor Green
Write-Host 'iex (irm dell.garytown.com)' -ForegroundColor Cyan

iex (irm dell.garytown.com)

#Basics (To use on a different Model (Platform), use the -Platform parameter and product code for that platfrom
Write-Host -ForegroundColor Magenta "Building Demos ver 25.4.21.12.39..... please wait...."
#Build Samples to display properly later
$Example1 = Get-DellDeviceDetails
$Example2 = Get-DellDeviceDetails -ModelLike "7520"
$Example3 = Get-DellDeviceDetails -SystemSKUNumber 0D15
$Example4 = Get-DellDeviceDetails -ModelLike "pro" | Where-Object {$_.RTSDate -match "2025"}
$Example5 = Get-DellDeviceDriverPack
$Example6 = Get-DellDeviceDriverPack -SystemSKUNumber 0D4F -OSVer Windows11
$Example7 = Get-DellBIOSUpdates
#$Example8 = Get-DellBIOSUpdates -Check -Verbose
$Example9 = Get-DellBIOSUpdates -SystemSKUNumber 066B
$Example10 = Get-DellBIOSUpdates -SystemSKUNumber 066B -Latest

Write-Host "Press any key to continue..." -ForegroundColor Green
Read-Host
Write-Host "Lets Run Several and see what they respond with" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DellDeviceDetails" -ForegroundColor Green
Read-Host
Write-Output $Example1 | Out-Host
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -ModelLike "7520"' -ForegroundColor Cyan
Read-Host
Write-Output $Example2 | Out-Host
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -SystemSKUNumber 0D15' -ForegroundColor Cyan
Read-Host
Write-Output $Example3 | Out-Host
Write-Host ""
Read-Host
Write-Host 'Get-DellDeviceDetails -ModelLike "pro" | Where-Object {$_.RTSDate -match "2025"}' -ForegroundColor Cyan
Read-Host
Write-Output $Example4 | Out-Host
Write-Host ""
Read-Host
Write-Host "Get-DellDeviceDriverPack" -ForegroundColor Green
Read-Host
Write-Output $Example5 | Out-Host
Write-Host ""
Write-Host 'Get-DellDeviceDriverPack -SystemSKUNumber 0D4F -OSVer Windows11' -ForegroundColor Cyan
Read-Host
Write-Output $Example6 | Out-Host
Write-Host ""
Read-Host
Write-Host "Lets move on to BIOS Updates" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DellBIOSUpdates" -ForegroundColor Green
Read-Host
Write-Output $Example7 | Out-Host
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -Check -Verbose' -ForegroundColor Cyan
Read-Host
Get-DellBIOSUpdates -Check -Verbose
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -DownloadPath c:\drivers' -ForegroundColor Cyan
Read-Host
Get-DellBIOSUpdates -DownloadPath c:\drivers
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -Flash' -ForegroundColor Cyan
#Get-DellBIOSUpdates -Flash
Write-Host "Another time perhaps" -ForegroundColor Magenta
Read-Host  
Write-Host 'Get-DellBIOSUpdates -SystemSKUNumber 066B' -ForegroundColor Cyan
Read-Host
Write-Output $Example9 | Out-Host
Write-Host ""
Read-Host
Write-Host 'Get-DellBIOSUpdates -SystemSKUNumber 066B -Latest' -ForegroundColor Cyan
Read-Host
Write-Output $Example10 | Out-Host
Read-Host
Write-Host "Lets move on to Dell Command Update" -ForegroundColor Magenta
Write-Host ""
Read-Host
Write-Host "Get-DCUAppUpdates -Latest" -ForegroundColor Green
Read-Host
Get-DCUAppUpdates -Latest
Write-Host ""
Read-Host
Write-Host 'Get-DCUAppUpdates -Install' -ForegroundColor Cyan
Read-Host
Get-DCUAppUpdates -Install
Write-Host ""
Read-Host
Write-Host "Get-DCUVersion" -ForegroundColor Green
Read-Host
Get-DCUVersion
Write-Host ""
Read-Host
Write-Host "Get-DCUInstallDetails" -ForegroundColor Green
Read-Host
Get-DCUInstallDetails
Write-Host ""
Read-Host
Write-Host "Manual Demo of Set-DCUSettings" -ForegroundColor Magenta
Write-Host "Then Launch DCU and show the settings" -ForegroundColor Cyan
Write-Host "Manual Demo of Invoke-DCU" -ForegroundColor Magenta