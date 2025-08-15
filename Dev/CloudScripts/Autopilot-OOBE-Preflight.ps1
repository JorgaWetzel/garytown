# Autopilot-OOBE-Preflight.ps1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ErrorActionPreference = 'Stop'
$LogFile = 'C:\Windows\Temp\AutopilotPreflight.log'

function Write-Log($msg) {
    try { "$(Get-Date -Format s) $msg" | Out-File -FilePath $LogFile -Append -Encoding utf8 } catch {}
}

# ---------- Cleanup Helpers ----------
function Remove-FileQuiet {
    param([Parameter(Mandatory)][string] $Path)
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

# ---------- Hochwertige Audio-Ausgabe ----------
function Get-PreferredGermanVoiceName {
    try {
        $oneCoreKey = 'HKLM:\SOFTWARE\Microsoft\Speech_OneCore\Voices\Tokens'
        if (Test-Path $oneCoreKey) {
            $tokens = Get-ChildItem $oneCoreKey -ErrorAction Stop
            $pref = @('Katja','Stefan','Hedda','Michael','Hanna')
            foreach ($p in $pref) { $hit = $tokens | Where-Object { $_.PSChildName -match $p }; if ($hit) { return $hit.PSChildName } }
            if ($tokens) { return $tokens[0].PSChildName }
        }
    } catch {}
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $synth  = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $voices = $synth.GetInstalledVoices() | ForEach-Object { $_.VoiceInfo } |
                  Where-Object { $_.Culture -and $_.Culture.Name -like 'de-*' }
        $pref   = @('Katja','Stefan','Hedda','Michael','Hanna')
        foreach ($p in $pref) { $v = $voices | Where-Object { $_.Name -like "*$p*" } | Select-Object -First 1; if ($v) { return $v.Name } }
        if ($voices) { return $voices[0].Name }
    } catch {}
    return $null
}
function Speak-HighQuality {
    param([Parameter(Mandatory)][string] $Text, [int] $Rate = 0, [int] $Volume = 100)
    try {
        Add-Type -AssemblyName System.Speech -ErrorAction Stop
        $voiceName = Get-PreferredGermanVoiceName
        $tts = New-Object System.Speech.Synthesis.SpeechSynthesizer
        $tts.Rate = $Rate; $tts.Volume = $Volume
        if ($voiceName) { $tts.SelectVoice($voiceName) }
        $tts.Speak($Text)
        $tts.Dispose()
        return $true
    } catch { return $false }
}
function Play-SuccessChime {
    try {
        # A-Dur Dreiklang + kurzer Abschluss-Ping
        [console]::beep(440,150); [console]::beep(554,150); [console]::beep(659,200)
        Start-Sleep -Milliseconds 120
        [console]::beep(880,180)
        return $true
    } catch { return $false }
}

try {
    Write-Log "Start OOBE-Preflight"

    # ---------- Functions3.ps1 laden (nur Hash-Weg) ----------
    $fxUrl = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Functions3.ps1'
    $fx    = Invoke-WebRequest -UseBasicParsing -Uri $fxUrl
    Invoke-Expression $fx.Content
    Write-Log "Functions3 geladen"

    # ---------- GraphApp.json Quelle (kein Z:\ im Full OS) ----------
    if (-not $env:GRAPHAPP_JSON_PATH) {
        if (Test-Path 'C:\ProgramData\GraphApp.json')      { $env:GRAPHAPP_JSON_PATH = 'C:\ProgramData\GraphApp.json' }
        elseif (Test-Path 'C:\Windows\Temp\GraphApp.json') { $env:GRAPHAPP_JSON_PATH = 'C:\Windows\Temp\GraphApp.json' }
    }
    Write-Log ("GRAPHAPP_JSON_PATH={0}" -f ($env:GRAPHAPP_JSON_PATH ?? '<not set>'))

    # ---------- Preflight ausfuehren (nur HW-Hash) ----------
    $res = Invoke-IntuneAutopilotPreflight -StopOnBlock:$false
    Write-Log ("Code={0} Message={1}" -f $res.Code, $res.Message)

    # ---------- Credentials/Tools VOR sichtbarer Aktion bereinigen ----------
    Clear-GraphSecrets
    Cleanup-Tools
    Write-Log "Secrets & Tools bereinigt"

    # ---------- Sichtbare/hoerbare Reaktion ----------
    switch ($res.Code) {
        808 {
            New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Force | Out-Null
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'legalnoticecaption' -Value 'AUTOPILOT BLOCKIERT'
            Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'legalnoticetext' -Value "Dieses Geraet ist in einem anderen Microsoft Intune Tenant registriert (Code 808). Lieferung stoppen."
            Speak-HighQuality "Achtung. Dieses Geraet ist in einem anderen Tenant registriert. Lieferung stoppen." | Out-Null
            shutdown.exe /s /t 25 /c "AUTOPILOT 808: Geraet in ANDEREM Tenant registriert. Lieferung STOPP."
            exit 23
        }
        806 {
            Speak-HighQuality "Hinweis. Dieses Geraet ist bereits in diesem Tenant registriert." | Out-Null
            shutdown.exe /s /t 25 /c "AUTOPILOT 806: Geraet bereits in DIESEM Tenant registriert."
            exit 23
        }
        0 {
            # Erfolgston + kurzer Sprach-Hint, OOBE laeuft weiter
            Play-SuccessChime | Out-Null
            Speak-HighQuality "Ausrollen erfolgreich. Geraet ist bereit." -Rate 0 -Volume 100 | Out-Null
            exit 0
        }
        default {
            Speak-HighQuality ("Autopilot Pruefung fehlgeschlagen. {0}" -f $res.Message) | Out-Null
            shutdown.exe /s /t 25 /c ("AUTOPILOT Fehler: {0}" -f $res.Message)
            exit 23
        }
    }
}
catch {
    $em = $_ | Out-String
    Write-Log ("FATAL: {0}" -f $em)
    # Sichtbarer Not-Stop (damit die Linie nicht blind weiterfaehrt)
    try {
        shutdown.exe /s /t 25 /c ("AUTOPILOT Fehler: {0}" -f ($_.Exception.Message))
    } catch {}
    exit 23
}
