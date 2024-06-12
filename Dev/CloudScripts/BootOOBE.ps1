Set-Location $PSScriptRoot
get-process sysprep -ea SilentlyContinue | stop-process -Force -ErrorAction SilentlyContinue

# Turns Off Windows Hello Requirement for Office Business
# reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork" /v Enabled /t REG_DWORD /d 0 /f
# reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\PassportForWork" /v DisablePostLogonProvisioning /t REG_DWORD /d 0 /f  

# Disable UAC
# ADD HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System /v EnableLUA /t REG_DWORD /d 0 /f

#Cleanup
Remove-Item C:\Windows\Panther\unattend.xml -Force -ea SilentlyContinue
Remove-Item C:\Windows\Setup\Scripts\init.ps1 -Recurse -Force -ea SilentlyContinue #Prevent loop after OOBE
Rename-Item C:\Windows\Setup\Scripts\init2.ps1 init.ps1 -ea SilentlyContinue #Run Cleanup after OOBE

# net user Wksadmin Passw0rd /ADD
# net localgroup "Administratoren" /add Wksadmin
# WMIC USERACCOUNT WHERE "Name='Wksadmin'" SET PasswordExpires=FALSE

get-process sysprep -ea SilentlyContinue | stop-process -Force -ErrorAction SilentlyContinue
Start-Sleep 2
&C:\Windows\System32\Sysprep\sysprep.exe /oobe /reboot /unattend:c:\windows\system32\sysprep\unattend.xml
exit(0)