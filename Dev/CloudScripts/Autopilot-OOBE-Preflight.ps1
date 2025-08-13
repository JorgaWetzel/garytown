# Autopilot-OOBE-Preflight.ps1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'

function Remove-FileQuiet {
    param([Parameter(Mandatory)] [string] $Path)
    try {
        if (Test-Path -LiteralPath $Path) {
            try { Set-Content -LiteralPath $Path -Value '' -NoNewline -Encoding Ascii -ErrorAction SilentlyContinue } catch {}
            Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}
function Clear-GraphSecrets {
    try { [Environment]::SetEnvironmentVariable('GRAPHAPP_JSON_PATH', $null, 'Process') } catch {}
    try { [Environment]::SetEnvironmentVariable('GRAPHAPP_JSON_PATH', $null, 'Machine') } catch {}
    Remove-FileQuiet -Path 'C:\ProgramData\GraphApp.json'
    Remove-FileQuiet -Path 'C:\Windows\Temp\GraphApp.json'
}
function Cleanup-Tools {
    Remove-FileQuiet -Path 'C:\Windows\Temp\nircmd.zip'
    Remove-FileQuiet -Path 'C:\Windows\Temp\nircmdc.exe'
    Remove-FileQuiet -Path 'C:\Windows\Temp\nircmd.exe'
}
function Speak-IfPossible($text) {
    try {
        $nir = 'C:\Windows\Temp\nircmdc.exe'
        if (-not (Test-Path $nir)) {
            Invoke-WebRequest -UseBasicParsing -Uri 'https://www.nirsoft.net/utils/nircmd-x64.zip' -OutFile 'C:\Windows\Temp\nircmd.zip'
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [IO.Compression.ZipFile]::ExtractToDirectory('C:\Windows\Temp\nircmd.zip','C:\Windows\Temp')
            if (Test-Path 'C:\Windows\Temp\nircmdc.exe') { $nir = 'C:\Windows\Temp\nircmdc.exe' }
        }
        if (Test-Path $nir) { Start-Process -FilePath $nir -ArgumentList ('speak text "{0}" 0 100' -f $text) -WindowStyle Hidden }
    } catch {}
}

# Functions3 laden (nur Hash-Weg)
$fxUrl = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions3.ps1'
$fx = Invoke-WebRequest -UseBasicParsing -Uri $fxUrl
Invoke-Expression $fx.Content

# Quelle fuer GraphApp.json bestimmen (kein Z:\ im Full OS)
if (-not $env:GRAPHAPP_JSON_PATH) {
    if (Test-Path 'C:\ProgramData\GraphApp.json') { $env:GRAPHAPP_JSON_PATH = 'C:\ProgramData\GraphApp.json' }
    elseif (Test-Path 'C:\Windows\Temp\GraphApp.json') { $env:GRAPHAPP_JSON_PATH = 'C:\Windows\Temp\GraphApp.json' }
}

# Preflight ausfuehren (nur HW-Hash)
$res = Invoke-IntuneAutopilotPreflight -StopOnBlock:$false

# Credentials/Tools VOR sichtbarer Aktion bereinigen
Clear-GraphSecrets
Cleanup-Tools

# Log
$log = 'C:\Windows\Temp\AutopilotPreflight.log'
"$(Get-Date -Format s) Code=$($res.Code) Message=$($res.Message)" | Out-File -FilePath $log -Append -Encoding utf8

switch ($res.Code) {
    808 {
        New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force | Out-Null
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'legalnoticecaption' -Value 'AUTOPILOT BLOCKIERT'
        Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'legalnoticetext' -Value "Dieses Geraet ist in einem anderen Microsoft Intune Tenant registriert (Code 808). Lieferung stoppen."
        Speak-IfPossible "Achtung. Dieses Geraet ist in einem anderen Tenant registriert. Lieferung stoppen."
        shutdown.exe /s /t 25 /c "AUTOPILOT 808: Geraet in ANDEREM Tenant registriert. Lieferung STOPP."
        exit 23
    }
    806 {
        Speak-IfPossible "Hinweis. Dieses Geraet ist bereits in diesem Tenant registriert."
        shutdown.exe /s /t 25 /c "AUTOPILOT 806: Geraet bereits in DIESEM Tenant registriert."
        exit 23
    }
    0   { exit 0 }
    default {
        Speak-IfPossible ("Autopilot Pruefung fehlgeschlagen. {0}" -f $res.Message)
        shutdown.exe /s /t 25 /c ("AUTOPILOT Fehler: {0}" -f $res.Message)
        exit 23
    }
}
