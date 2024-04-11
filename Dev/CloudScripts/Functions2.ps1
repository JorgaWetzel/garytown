CT$ScriptName = 'functions.oneict.ch'
$ScriptVersion = '10.04.2024'
Set-ExecutionPolicy Bypass -Force

Write-Host -ForegroundColor Green "[+] $ScriptName $ScriptVersion"
#endregion

Write-Host -ForegroundColor Green "[+] Function Set-DefaultProfilePersonalPrefOneICT"
function Set-DefaultProfilePersonalPrefOneICT {
    #Set Default User Profile to MY PERSONAL preferences.

    $REG_defaultuser = "c:\users\default\ntuser.dat"
    $VirtualRegistryPath_defaultuser = "HKLM\DefUser" #Load Command
    $VirtualRegistryPath_software = "HKLM:\DefUser\Software" #PowerShell Path

    if (Test-Path -Path $VirtualRegistryPath_software){
        reg unload $VirtualRegistryPath_defaultuser | Out-Null # Just in case...
        Start-Sleep 1
    }
    reg load $VirtualRegistryPath_defaultuser $REG_defaultuser | Out-Null

    # Disabling Bing Search in Start Menu, Disabling Cortana
    $Path = "$VirtualRegistryPath_software\Microsoft\Windows\CurrentVersion\Search"
    New-ItemProperty -Path $Path -Name "BingSearchEnabled" -Type DWord -Value 0 -Force | Out-Null
    New-ItemProperty -Path $Path -Name "CortanaConsent" -Type DWord -Value 0 - Force | Out-Null
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Force | Out-Null
    

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


    Write-Host -ForegroundColor Green "[+] Function Set-Chocolatey"
    function Set-Chocolatey {
    # add tcp rout to oneICT Server
    Add-Content -Path "C:\Windows\System32\drivers\etc\hosts" -Value "195.49.62.108 chocoserver"
    
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$ENV:ALLUSERSPROFILE\chocolatey\bin", "Machine")
    C:\ProgramData\chocolatey\bin\choco.exe install chocolatey-core.extension -y --no-progress --ignore-checksums
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'oneICT'" --source="'https://chocoserver:8443/repository/ChocolateyInternal/'" --allow-self-service --user="'chocolatey'" --password="'wVGULoJGh1mxbRpChJQV'" --priority=1
    C:\ProgramData\chocolatey\bin\choco.exe source add --name="'Chocolatey'" --source="'https://chocolatey.org/api/v2/'" --allow-self-service --priority=2
    # C:\ProgramData\chocolatey\bin\choco.exe install chocolateygui -y --source="'oneICT'" --no-progress
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowGlobalConfirmation
    C:\ProgramData\chocolatey\bin\choco.exe feature enable -n allowEmptyChecksums
    
    $manufacturer = (gwmi win32_computersystem).Manufacturer
    "Das ist ein $manufacturer PC"
    
    if ($manufacturer -match "VMware"){
    Write-Host "Installing VMware tools..."
    C:\ProgramData\chocolatey\bin\choco.exe install vmware-tools -y --no-progress --ignore-checksums
    }

    # Zertifikat
    $url = "https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/choclatey.cer"
    $tempPath = "$env:TEMP\choclatey.cer"
    Invoke-WebRequest -Uri $url -OutFile $tempPath
    # Öffnen des Zertifikatspeichers für "TrustedPeople" unter "LocalMachine"
    $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPeople", "LocalMachine")
    $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($tempPath)
    $certStore.Add($cert)
    $certStore.Close()
    Remove-Item -Path $tempPath
    Write-Host "Das Zertifikat wurde erfolgreich zu TrustedPeople unter LocalMachine hinzugefügt."
    }

    Write-Host -ForegroundColor Green "[+] Function DisableIPv6"
    function DisableIPv6 {
    # Disabling IPv6
    write-host ""
    write-host "Disabling IPv6 ..." -ForegroundColor green
    write-host ""
    Disable-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6'
    write-host "============IPv6 Status============" -ForegroundColor Magenta
    get-NetAdapterBinding -Name '*' -ComponentID 'ms_tcpip6' | format-table -AutoSize -Property Name, Enabled 
    
    Write-Host -ForegroundColor Gray "**Completed oneICT sub script**"
    $null = Stop-Transcript -ErrorAction Ignore
    }
