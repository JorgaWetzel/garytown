CT$ScriptName = 'functions.oneict.ch'
$ScriptVersion = '10.04.2024'
Set-ExecutionPolicy Bypass -Force

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Set-DefaultProfilePersonalPrefOneICT"
function Set-DefaultProfilePersonalPref {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    if (Test-Path -Path $VirtualRegistryPath_software){
        reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
        Start-Sleep 1
    }
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    #TaskBar Left / Hide Chat / Hide Widgets / Hide TaskView
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    New-ItemProperty -Path $Path -Name "TaskbarAl" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarMn" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "TaskbarDa" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ShowTaskViewButton" -Value 0 -PropertyType Dword -Force | Out-Null

    #Disable Content Delivery
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    New-ItemProperty -Path $Path -Name "SystemPaneSuggestionsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SubscribedContentEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SoftLandingEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "SilentInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "PreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "OemPreInstalledAppsEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "FeatureManagementEnabled" -Value 0 -PropertyType Dword -Force | Out-Null
    New-ItemProperty -Path $Path -Name "ContentDeliveryAllowed" -Value 0 -PropertyType Dword -Force | Out-Null

    #Enable Location for Auto Time Zone
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    New-ItemProperty -Path $Path -Name "Value" -Value Allow -PropertyType String -Force | Out-Null
    Start-Sleep -s 1
    reg unload $VirtualRegistryPath_defaultuser | Out-Null
}


Write-Host -ForegroundColor Green "[+] Function Set-RunOnceScript"
function Set-RunOnceScript {
    # setup RunOnce to execute provisioning.ps1 script
    # disable privacy experience
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/provisioning.ps1"
    $destinationFolder = "C:\Windows\Setup\Scripts"
    $destinationPath = Join-Path -Path $destinationFolder -ChildPath "provisioning.ps1"
    Invoke-WebRequest -Uri $url -OutFile $destinationPath
    
    $settings = @(
        [PSCustomObject]@{
            Path  = "SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"
            Name  = "execute_provisioning"
            Value = "cmd /c powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\provisioning.ps1"
        },
        [PSCustomObject]@{
            Path  = "SOFTWARE\Policies\Microsoft\Windows\OOBE"
            Name  = "DisablePrivacyExperience"
            Value = 1
        }
    ) | Group-Object Path
    
    foreach ($setting in $settings) {
        # Öffne den angegebenen Registrierungsschlüssel (oder erstelle ihn, falls er nicht existiert)
        $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Name, $true)
        if ($null -eq $registry) {
            $registry = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($setting.Name, $true)
        }
        # Setze die Werte für den Registrierungsschlüssel basierend auf den Gruppenobjektdaten
        foreach ($item in $setting.Group) {
            $registry.SetValue($item.Name, $item.Value)
        }
        $registry.Dispose()
    }
    }
    
