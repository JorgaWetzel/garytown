<#
    99-Deployment.ps1  –  StartNet-Hook für OSDCloud (HP-Fallback + Share-WIM)
    ? WinPE lädt eigenes WIM von Netzwerk-Share
    ? Sucht HP-DriverPack:   OSDCloud-Katalog ? CMSL ? CAB/EXE-Fallback
    ? Keine Windows-/MS-Treiber-Updates
#>

# --------------------------------------------------------------------------------
#  0) Basis vorbereiten  (TLS 1.2, NuGet, PSRepository, Module)
# --------------------------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$env:HP_JAVA_DISABLE_DOWNLOAD_PROXY = 1          # Proxy-Autodetect ausschalten

if (-not (Get-PackageProvider NuGet -EA 0)) {
    Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Force
}
if (-not (Get-PSRepository PSGallery -EA 0)) { Register-PSRepository -Default }

Import-Module OSD -Force
iex (irm functions.garytown.com)      # optionale Helfer-Fkt.
iex (irm functions.osdcloud.com)

# --------------------------------------------------------------------------------
#  1) Netzwerk-Share verbinden
# --------------------------------------------------------------------------------
$DeployShare = '\\192.168.2.15\DeploymentShare$'
$MapDrive    = 'Z'
$UserName    = 'VARIODEPLOY\Administrator'
$PlainPwd    = '12Monate'

$SecurePwd = $PlainPwd | ConvertTo-SecureString -AsPlainText -Force
$Cred      = [pscredential]::new($UserName,$SecurePwd)

if (-not (Get-PSDrive -Name $MapDrive -EA 0)) {
    New-PSDrive -Name $MapDrive -PSProvider FileSystem -Root $DeployShare `
                -Credential $Cred -EA Stop | Out-Null
}

$SrcWim = "$MapDrive:\OSDCloud\OS\Win11_24H2_MUI.wim"

# --------------------------------------------------------------------------------
#  2) OSDCloud-Hash setzen  (keine MS-Updates)
# --------------------------------------------------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5            # ggf. anpassen
    ClearDiskConfirm  = $false
    ZTI               = $true
    UpdateOS          = $false       # kum. Updates AUS
    UpdateDrivers     = $false       # MS-Treiber AUS
}

# --------------------------------------------------------------------------------
#  3) HP-DriverPack   (OSDCloud ? CMSL ? CAB/EXE)
# --------------------------------------------------------------------------------
$cs   = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -match 'HP') {

    # Kandidaten-IDs
    $ids = @(
        (Get-CimInstance Win32_ComputerSystemProduct).Version
        $cs.SystemSKUNumber
    ) | Where-Object { $_ } | Select-Object -Unique

    $osVers  = 'Windows 11','Windows 10'
    $relVers = '24H2','23H2','22H2','21H2'
    $dp      = $null

    foreach ($id in $ids) {
        foreach ($os in $osVers) {
            foreach ($rel in $relVers) {
                $dp = Get-OSDCloudDriverPack -Product $id `
                         -OSVersion $os -OSReleaseID $rel -EA 0
                if ($dp) {
                    Write-Host "Treffer Cloud: $($dp.Name)" -fg Green
                    break 3
                }
            }
        }
    }

    # -- CMSL-Fallback -----------------------------------------------
    if (-not $dp) {
        Write-Host 'Starte CMSL-Fallback …' -fg Cyan

        if (-not (Get-Module -ListAvailable HPCMSL)) {
            Install-Module HPCMSL -AcceptLicense -AllowClobber -Force -Scope CurrentUser
            Import-Module HPCMSL -Force
        }

        foreach ($id in $ids) {
            $dp = Get-HPDriverPackLatest -Platform $id -EA 0
            if ($dp) {
                Write-Host "Treffer CMSL : $($dp.SoftPaqId) / $($dp.Name)" -fg Green
                break
            }
        }
    }

    # -- Pack registrieren (CAB bevorzugt) ---------------------------
    if ($dp) {
        $cabUrl  = $dp.Url -replace '\.exe$', '.cab'
        $cabName = "$($dp.SoftPaqId).cab"
        $localCab= "$MapDrive:\OSDCloud\DriverPack\$cabName"

        try {
            Invoke-WebRequest $cabUrl -OutFile $localCab -UseBasicParsing -EA Stop
            Write-Host "CAB gespeichert: $cabName"
            $Global:MyOSDCloud.DriverPackName = $cabName
        }
        catch {
            Write-Warning 'CAB nicht erreichbar – verwende EXE'
            $Global:MyOSDCloud.DriverPackName = "$($dp.SoftPaqId).exe"
        }

        $Global:MyOSDCloud.HPTPMUpdate  = $true
        $Global:MyOSDCloud.HPBIOSUpdate = $true
        $Global:MyOSDCloud.HPIAALL      = $true
    }
    else {
        Write-Warning '>> Kein HP-DriverPack verfügbar! <<'
    }
}
else {
    Write-Host 'Kein HP-Gerät – DriverPack-Suche übersprungen.' -fg Yellow
}

# --------------------------------------------------------------------------------
#  4) Deployment starten  +  Spätphase
# --------------------------------------------------------------------------------
Invoke-OSDCloud
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
