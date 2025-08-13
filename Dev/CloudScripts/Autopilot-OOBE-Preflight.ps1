# Läuft im Full-OS (SYSTEM), hat also vollen Zugriff auf MDM/WMI -> HW-Hash verfügbar.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Functions3.ps1 laden (dein Repo)
$functionsUrl = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions3.ps1'
$functions = Invoke-WebRequest -UseBasicParsing -Uri $functionsUrl -ErrorAction Stop
$null = Invoke-Expression $functions.Content

# Graph-Creds-Quelle (anpassen, wenn du woanders ablegst)
$env:GRAPHAPP_JSON_PATH = 'Z:\OSDCloud\GraphApp.json'  # oder C:\ProgramData\GraphApp.json

# Nur der Hash-Weg, KEIN Serien-Fallback
$res = Invoke-AutopilotProbeImport   # bewusst: ohne -AllowSerialFallback

# Loggen
$log = "C:\Windows\Temp\AutopilotPreflight.log"
"$(Get-Date -Format s) Code=$($res.Code) Message=$($res.Message)" | Out-File -FilePath $log -Append -Encoding utf8

switch ($res.Code) {
    808 {
        # BLOCK: Gerät ist in einem ANDEREN Tenant registriert -> sofort runterfahren
        # Cleanup hat Functions3 bereits gemacht.
        shutdown.exe /s /t 15 /c "Autopilot 808: Geraet ist in anderem Tenant registriert. Lieferung STOPP."
        exit 23
    }
    806 {
        # Bereits in deinem Tenant – je nach Policy: stoppen oder weiter
        shutdown.exe /s /t 15 /c "Autopilot 806: Geraet bereits im Quarantaene-Tenant registriert."
        exit 23
    }
    0 {
        # OK: nicht woanders registriert -> still weiter in OOBE
        exit 0
    }
    default {
        # Unerwarteter Fehler: vorsichtshalber stoppen (oder: weiterlaufen lassen – deine Entscheidung)
        shutdown.exe /s /t 15 /c "Autopilot Preflight Fehler: $($res.Message)"
        exit 23
    }
}
