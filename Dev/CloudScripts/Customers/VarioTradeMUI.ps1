# 99-Deployment.ps1  â€“  StartNet-Hook, minimal

Import-Module OSD -Force

iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# ======================================================================
# Konfiguration â€“ HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
# $DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
# $MapDrive    = 'Z'                              # gewÃ¼nschter LaufwerksÂ­buchstabe
# $UserName    = 'Jorga'                          # DomÃ¤nen- oder lokaler User
# $PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)


$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z'                               # gewÃ¼nschter LaufwerksÂ­buchstabe
$UserName    = 'VARIODEPLOY\Administrator'       # DomÃ¤nen- oder lokaler User
$PlainPwd    = '12Monate'                        # Passwort (Klartext)
$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'
# ======================================================================
# Ab hier nichts mehr Ã¤ndern
# ======================================================================

# AnmeldeÂ­daten vorbereiten
$SecurePwd = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
$Cred      = New-Object System.Management.Automation.PSCredential ($UserName,$SecurePwd)

# Share verbinden
if (-not (Get-PSDrive -Name $MapDrive -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $MapDrive `
                -PSProvider FileSystem `
                -Root $DeployShare `
                -Credential $Cred `
                -ErrorAction Stop
}


# --- OSDCloud-Variablen setzen ----------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5     # ggf. anpassen
    ClearDiskConfirm  = $false
    ZTI               = $true
    UpdateOS          = $false      # Keine kumulativen Windows-Updates
    UpdateDrivers     = $false      # Microsoft-Treiber­updates AUS
}


# =====================================================================
# HP-DriverPack  Universeller Fallback-Algorithmus (reine Console)
# =====================================================================
# -----------------------------------------------------------------
#  HP-DriverPack  –  zuerst OSDCloud, dann CMSL-Fallback
# -----------------------------------------------------------------
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -notmatch 'HP') {
    Write-Host 'Kein HP-Gerät – DriverPack-Suche übersprungen.' -fg Yellow
}
else {
    # --- mögliche IDs --------------------------------------------
    $ids = @(
        (Get-CimInstance Win32_ComputerSystemProduct).Version
        (Get-CimInstance Win32_ComputerSystem).SystemSKUNumber
    ) | Where-Object { $_ } | Select-Object -Unique

    $osV  = 'Windows 11','Windows 10'
    $relV = '24H2','23H2','22H2','21H2'
    $dp   = $null

    # --- 1) Cloud-Katalog testen ---------------------------------
    foreach ($id in $ids) {
        foreach ($os in $osV) {
            foreach ($rel in $relV) {
                $dp = Get-OSDCloudDriverPack -Product $id `
                        -OSVersion $os -OSReleaseID $rel `
                        -EA SilentlyContinue
                if ($dp) {
                    Write-Host "Treffer Cloud: $($dp.Name)" -fg Green
                    break 3
                }
            }
        }
    }

    # --- 2) CMSL-Fallback, wenn noch nichts gefunden -------------
    if (-not $dp) {
        Write-Host 'Starte CMSL-Fallback …' -fg Cyan

        # Modul sicherstellen
        if (-not (Get-Module HPCMSL)) { Install-Module HPCMSL -Force -Scope CurrentUser }

        foreach ($id in $ids) {
            $dp = Get-HPDriverPackLatest -Platform $id -ErrorAction SilentlyContinue
            if ($dp) {
                Write-Host "Treffer CMSL : $($dp.SoftPaqID)  $($dp.Name)" -fg Green
                break
            }
        }
    }

    # --- 3) Ergebnis zum OSD-Hash --------------------------------
    if ($dp) {
        $Global:MyOSDCloud.DriverPackName = $dp.Name  # oder $dp.SoftPaqID+'.cab'
        $Global:MyOSDCloud.HPTPMUpdate  = $true
        $Global:MyOSDCloud.HPBIOSUpdate = $true
        $Global:MyOSDCloud.HPIAALL      = $true
    }
    else {
        Write-Warning '>> Auch CMSL fand kein DriverPack! <<'
    }
}


# --- Deployment ausfÃ¼hren ---------------------------------------------
Invoke-OSDCloud

# --- SpÃ¤tphase + Neustart ---------------------------------------------
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
