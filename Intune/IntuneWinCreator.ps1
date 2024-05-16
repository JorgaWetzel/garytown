#Gary Blok
#Build CMClient App Intune Installer
$IntuneAppRootPath = "C:\IntuneApps"

#Path to App Folder you want to Convert
$SourceAppPath = "C:\IntuneApps\Sources\WorkElevate\WorkElevateStub"
$OutputAppPath = $SourceAppPath.Replace("Sources","Output")

$IntuneUtilFolderPath = "$IntuneAppRootPath\Microsoft-Win32-Content-Prep-Tool"
$IntuneUtilPath = "$IntuneUtilFolderPath\IntuneWinAppUtil.exe"
$IntuneUtilURL = "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe"
#https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/blob/master/IntuneWinAppUtil.exe




#Test Folder Structure and Build if needed
if (!(Test-Path -Path $OutputAppPath)){
    New-item -Path $OutputAppPath -ItemType Directory -Force | Out-Null
    Write-Host "Created $OutputAppPath" -ForegroundColor Green
}

if (!(Test-Path -Path $IntuneUtilFolderPath)){
    New-item -Path $IntuneUtilFolderPath -ItemType Directory -Force | Out-Null
    Write-Host "Created $IntuneUtilFolderPath" -ForegroundColor Green
}
if (!(Test-Path -Path $IntuneUtilPath)){
    Invoke-WebRequest -UseBasicParsing -Uri $IntuneUtilURL -OutFile $IntuneUtilPath
    Write-Host "Downloaded IntuneWinAppUtil.exe to $IntuneUtilPath" -ForegroundColor Green
}


$App = get-item -Path $SourceAppPath

$SetupEXE = Get-ChildItem -Path $App.FullName -Filter *.exe
if (!($SetupEXE)){$SetupEXE = Get-ChildItem -Path $App.FullName -Filter *.msi}
$SetupFolder = $App.FullName
#$CreateIntuneApp = Start-Process -FilePath $IntuneUtilPath -ArgumentList "-c $SetupFolder -s $SetupEXEPath -o $OutPutPath -q" -Wait -PassThru
Write-Host "Starting Intune Package Creation" -ForegroundColor Green
& $IntuneUtilPath -c $SetupFolder -s $SetupEXE -o $OutputAppPath -q

Write-Host "Finished App for Intune: $OutputAppPath" -ForegroundColor Green
