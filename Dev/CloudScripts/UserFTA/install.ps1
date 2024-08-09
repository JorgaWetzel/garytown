$PackageName = "UserFTA"

Start-Transcript -Path "C:\OSDCloud\Logs\$PackageName.txt" -Force

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
Start-Process -FilePath "$scriptPath\SetUserFTA.exe" -ArgumentList "$scriptPath\FTA.txt" -Wait

Stop-Transcript


