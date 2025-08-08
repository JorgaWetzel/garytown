# ================================================================
# VarioTradeMUI.ps1 (All-in-One)
# - Z: Mapping
# - DriverPack cache to Z:\OSDCloud\DriverPacks\HP
# - HPIA fallback with ZBook exception
# - Quiet-on-error Flag (controls Splash suppression)
# - Append Beep + Shutdown to final OSDCloud SetupComplete and PostAction
# - Keep external function imports
# ================================================================

# -------- CONFIG: set your share & credentials (or leave if already mapped earlier) --------
$Global:VT_ZDrive = 'Z:'
$Global:VT_ZUNC   = '\\SERVER\Share\OSDCloud'    # TODO: replace with your UNC
$Global:VT_ZUser  = 'Jorga'                # TODO: replace with your user
$Global:VT_ZPass  = 'Dont4getme'                  # TODO: replace with your password
$Global:VT_Cache  = 'Z:\OSDCloud\DriverPacks\HP'
# ------------------------------------------------------------------------------------------

# -------- Logging --------
$Global:VT_Log = 'C:\Windows\Temp\VarioTradeMUI.log'
function Write-VTLog {
    param([string]$Message, [ConsoleColor]$Color = 'White')
    try {
        $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Write-Host -ForegroundColor $Color "[VarioTradeMUI] $Message"
        Add-Content -LiteralPath $Global:VT_Log -Value "$ts $Message"
    } catch {}
}

# -------- Import functions (as in your original script) --------
try { iex (irm functions.garytown.com) } catch { Write-VTLog "functions.garytown.com load failed: $($_.Exception.Message)" Yellow }
try { iex (irm functions.osdcloud.com) } catch { Write-VTLog "functions.osdcloud.com load failed: $($_.Exception.Message)" Yellow }

# -------- Quiet-on-error Flag (Splash suppression) --------
$Global:VarioQuietFlagDir  = "X:\OSDCloud\Flags"
$Global:VarioQuietFlagFile = Join-Path $Global:VarioQuietFlagDir "SilentSplashOff.txt"
function Set-QuietSplash {
    try {
        if (!(Test-Path $Global:VarioQuietFlagDir)) {
            New-Item -ItemType Directory -Path $Global:VarioQuietFlagDir -Force | Out-Null
        }
        New-Item -Path $Global:VarioQuietFlagFile -ItemType File -Force | Out-Null
        Write-VTLog "QuietSplash Flag gesetzt – Splash wird beim nächsten Start übersprungen." Yellow
    } catch {
        Write-VTLog "Konnte QuietSplash Flag nicht setzen: $($_.Exception.Message)" Yellow
    }
}

# -------- Helper: Map Z: with retries (no-op if already mapped) --------
function Mount-Z {
    param([string]$Drive = $Global:VT_ZDrive, [string]$UNC = $Global:VT_ZUNC, [string]$User = $Global:VT_ZUser, [string]$Pass = $Global:VT_ZPass, [int]$Retries = 3)
    if (Test-Path $Drive) { Write-VTLog "Drive $Drive already present."; return $true }
    for ($i=1; $i -le $Retries; $i++) {
        try {
            cmd /c "net use $Drive /delete /y" | Out-Null 2>&1
            $cmd = "net use $Drive `"$UNC`" `"$Pass`" /USER:`"$User`" /PERSISTENT:NO"
            Write-VTLog "Mapping $Drive to $UNC (try $i/$Retries)..."
            cmd /c $cmd | Out-Null 2>&1
            Start-Sleep -Seconds 2
            if (Test-Path $Drive) { Write-VTLog "Mapped $Drive to $UNC" Green; return $true }
        } catch {
            Write-VTLog "Map try $i failed: $($_.Exception.Message)" Yellow
        }
    }
    Write-VTLog "Failed to map $Drive to $UNC after $Retries tries." Yellow
    return $false
}

# Ensure Z: (only if UNC configured)
if ($Global:VT_ZUNC -and $Global:VT_ZUNC -like "\\*") { [void](Mount-Z) }

# -------- Driver Pack decision + HPIA fallback with ZBook exception --------
# Expect $DriverPack possibly set by OSDCloud/HPCMSL. Also look for local sp*.exe if not.
$LocalDriverPack = $null
if ($DriverPack -and ($DriverPack.PSObject.Properties.Name -contains 'FullName') -and (Test-Path $DriverPack.FullName)) {
    $LocalDriverPack = Get-Item -LiteralPath $DriverPack.FullName -ErrorAction SilentlyContinue
    Write-VTLog "DriverPack object provided: $($LocalDriverPack.FullName)"
} else {
    $LocalDriverPack = Get-ChildItem 'C:\Drivers' -Filter sp*.exe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($LocalDriverPack) { Write-VTLog "Found local DriverPack: $($LocalDriverPack.FullName)" } else { Write-VTLog "No local DriverPack found under C:\Drivers" Yellow }
}

# Activate HPCMSL DriverPack when we have one, disable HPIA. Else consider HPIA fallback.
if ($LocalDriverPack) {
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true
    $Global:MyOSDCloud.HPIAALL = $false
    try { $Global:MyOSDCloud.DriverPackName = $LocalDriverPack.Name } catch {}
    Write-VTLog "Using DriverPack only; HPIA disabled. ($($LocalDriverPack.Name))" Green
} else {
    Write-VTLog "No DriverPack – evaluating HPIA fallback..." Yellow
    $hpiaOk = $false
    try { $hpiaOk = (Test-HPIASupport) } catch {}
    # ZBook exception (as requested)
    $isZBookException = $false
    try {
        if (($Product -eq '83B2') -and ($Model -match 'zbook')) { $isZBookException = $true }
    } catch {}
    if ($hpiaOk -and -not $isZBookException) {
        $Global:MyOSDCloud.HPIAALL = $true
        Write-VTLog "HPIA enabled (fallback)." Cyan
    } else {
        $Global:MyOSDCloud.HPIAALL = $false
        Write-VTLog "HPIA NOT enabled (Support=$hpiaOk, ZBookException=$isZBookException) – will set Quiet flag." Yellow
        Set-QuietSplash
    }
}

# -------- Run OSDCloud with protective try/catch --------
try {
    Write-VTLog "Starting Invoke-OSDCloud..."
    Invoke-OSDCloud
    Write-VTLog "Invoke-OSDCloud finished."
} catch {
    Write-VTLog "Invoke-OSDCloud failed: $($_.Exception.Message)" Yellow
    try { Set-QuietSplash } catch {}
    throw
}

# -------- Post-Invoke: cache DriverPack to Z: and append SetupComplete tail --------
try {
    # Cache DriverPack to Z:
    if (Test-Path $Global:VT_ZDrive) {
        if (!(Test-Path $Global:VT_Cache)) { New-Item -ItemType Directory -Path $Global:VT_Cache -Force | Out-Null }
        $dp = $LocalDriverPack
        if (-not $dp) {
            $dp = Get-ChildItem 'C:\Drivers' -Filter sp*.exe -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if ($dp) {
            $dest = Join-Path $Global:VT_Cache $dp.Name
            try {
                Copy-Item -Path $dp.FullName -Destination $dest -Force
                Write-VTLog "Cached driver pack to $dest" Cyan
            } catch {
                Write-VTLog "Copy to $dest failed: $($_.Exception.Message)" Yellow
            }
        } else {
            Write-VTLog "No sp*.exe found after Invoke-OSDCloud; skipping cache." Yellow
        }
    } else {
        Write-VTLog "Z:\\ not available; skipping cache." Yellow
    }

    # Prepare Beep + Shutdown tail content
    $VarioTail = @'
# ===== VarioTrade: Beep + Shutdown (append) =====
try { New-Item -ItemType Directory -Path ''C:\Windows\Temp'' -Force | Out-Null } catch {}
Add-Content -Path ''C:\Windows\Temp\varo-shutdown.log'' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') SetupComplete: entering Vario tail"

# Beep: first Console.Beep (works without audiosrv), then optional tiny WAV fallback
try {
    [console]::Beep(880,180); Start-Sleep -Milliseconds 120; [console]::Beep(1200,240)
} catch {
    try {
        $wav = [IO.Path]::Combine($env:TEMP,''vbeep.wav'')
        [IO.File]::WriteAllBytes($wav, [Convert]::FromBase64String(
        ''UklGRsQAAABXQVZFZm10IBAAAAABAAEAESsAACJWAAACABAAZGF0YQcAAAAA////AP///wD///8A////AP///wD///8A''))
        Add-Type -AssemblyName System.Windows.Forms
        (New-Object System.Media.SoundPlayer $wav).PlaySync()
        Remove-Item $wav -ErrorAction SilentlyContinue
    } catch {}
}

# Marker & log
New-Item -Path ''C:\Windows\Temp\varo.setupcomplete.ran'' -ItemType File -Force | Out-Null
Add-Content -Path ''C:\Windows\Temp\varo-shutdown.log'' -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') SetupComplete: initiating shutdown"
Start-Sleep -Seconds 2
Start-Process -FilePath "shutdown.exe" -ArgumentList "/s /t 3 /f" -WindowStyle Hidden
# ===== end Vario =====
'@

    # Append to OSDCloud SetupComplete.ps1
    $oscPath = 'C:\OSDCloud\Scripts\SetupComplete\SetupComplete.ps1'
    if (Test-Path $oscPath) {
        Add-Content -Path $oscPath -Value $VarioTail
        Write-VTLog "Appended Vario tail to $oscPath" Green
    } else {
        Write-VTLog "OSDCloud SetupComplete.ps1 not found at $oscPath (will try PostAction only)." Yellow
    }

    # Safety net: also drop into PostAction if supported
    $postDir = 'C:\OSDCloud\Scripts\PostAction'
    New-Item -ItemType Directory -Path $postDir -Force | Out-Null
    $paFile = Join-Path $postDir '99-varo-shutdown.ps1'
    $VarioTail | Out-File -FilePath $paFile -Encoding ascii -Force
    Write-VTLog "Wrote PostAction: $paFile" Green

} catch {
    Write-VTLog "Post-Invoke cache/SetupComplete block failed: $($_.Exception.Message)" Yellow
}

# -------- END --------
