$PackageName = "UserFTA"
$Version = "1"


$Path_oneICT = "$ENV:LOCALAPPDATA\_MEM"
Start-Transcript -Path "$Path_oneICT\Log\$PackageName-install.log" -Force

try{
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
    Start-Process -FilePath "$scriptPath\SetUserFTA.exe" -ArgumentList "$scriptPath\FTA.txt" -Wait
    New-Item -Path "$Path_oneICT\Validation\$PackageName" -ItemType "file" -Force -Value $Version
}catch{
    Write-Host "_____________________________________________________________________"
    Write-Host "ERROR"
    Write-Host "$_"
    Write-Host "_____________________________________________________________________"
}

Stop-Transcript



<#
Write-Output "::group::Setup Chrome"
$SetUserFTAPath = Resolve-Path '.\packages\cli-e2e\entrypoints\utils\SetUserFTA\SetUserFTA.exe'
Start-Process -FilePath $SetUserFTAPath -ArgumentList ' http ChromeHTML' -PassThru | Wait-Process
Start-Process -FilePath $SetUserFTAPath -ArgumentList ' https ChromeHTML' -PassThru | Wait-Process
Start-Process -FilePath $SetUserFTAPath -ArgumentList '.htm ChromeHTML' -PassThru | Wait-Process
Start-Process -FilePath $SetUserFTAPath -ArgumentList '.html ChromeHTML' -PassThru | Wait-Process
#>

# https://www.winhelponline.com/blog/set-default-browser-file-associations-command-line-windows-10/
# https://github.com/DanysysTeam/PS-SFTA/tree/22a32292e576afc976a1167d92b50741ef523066