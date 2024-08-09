Start-Transcript -Path "C:\OSDCloud\Logs\UserFTA.txt" -Force
Start-Process -FilePath "C:\OSDCloud\UserFTA\SetUserFTA.exe" -ArgumentList "C:\OSDCloud\UserFTA\FTA.txt" -Wait
# Export Settings
# & "C:\OSDCloud\UserFTA\GetUserFTA.exe" > "C:\OSDCloud\UserFTA\NewFTA.txt"
Stop-Transcript
