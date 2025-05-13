<#  99-Deployment.ps1  –  StartNet hook for OSDCloud (HP fallback + share WIM)

     • Maps Z: to a deployment share
     • Uses local WIM from share
     • Tries OSDCloud driver pack; if none, falls back to HP CMSL
     • No Windows Update, no Microsoft driver updates in WinPE
#>

# -------------------------------------------------------------
# 0) WinPE prereqs: TLS 1.2, NuGet, PSGallery
# -------------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if (-not (Get-PackageProvider NuGet -ErrorAction 0)) {
    Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -Force
}
if (-not (Get-PSRepository PSGallery -ErrorAction 0)) {
    Register-PSRepository -Default
}

Import-Module OSD -Force

# -------------------------------------------------------------
# 1) Map deployment share
# -------------------------------------------------------------
$DeployShare = '\\192.168.2.15\DeploymentShare$'
$MapDrive    = 'Z'
$UserName    = 'VARIODEPLOY\Administrator'
$PlainPwd    = '12Monate'

$SecurePwd = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
$Cred      = [pscredential]::new($UserName,$SecurePwd)

if (-not (Get-PSDrive -Name $MapDrive -ErrorAction 0)) {
    New-PSDrive -Name $MapDrive -PSProvider FileSystem `
                -Root $DeployShare -Credential $Cred -ErrorAction Stop | Out-Null
}

$SrcWim = "$MapDrive:\OSDCloud\OS\Win11_24H2_MUI.wim"

# -------------------------------------------------------------
# 2) OSDCloud hash (no Windows / MS driver updates)
# -------------------------------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5            # adjust if needed
    ClearDiskConfirm  = $false
    ZTI               = $true
    UpdateOS          = $false
    UpdateDrivers     = $false
}

# -------------------------------------------------------------
# 3) HP driver pack (OSDCloud -> CMSL -> CAB/EXE)
# -------------------------------------------------------------
$cs = Get-CimInstance Win32_ComputerSystem
if ($cs.Manufacturer -match 'HP') {

    # possible platform IDs
    $ids = @(
        (Get-CimInstance Win32_ComputerSystemProduct).Version
        $cs.SystemSKUNumber
    ) | Where-Object { $_ } | Select-Object -Unique

    $osList  = 'Windows 11','Windows 10'
    $relList = '24H2','23H2','22H2','21H2'
    $dp      = $null

    # 3.1  OSDCloud catalog
    foreach ($id in $ids) {
        foreach ($os in $osList) {
            foreach ($rel in $relList) {
                $dp = Get-OSDCloudDriverPack -Product $id `
                         -OSVersion $os -OSReleaseID $rel -ErrorAction 0
                if ($dp) {
                    Write-Host "Found in Cloud: $($dp.Name)" -ForegroundColor Green
                    break 3
                }
            }
        }
    }

    # 3.2  CMSL fallback
    if (-not $dp) {
        Write-Host 'Starting CMSL fallback ...' -ForegroundColor Cyan

        if (-not (Get-Module -ListAvailable HPCMSL)) {
            Install-Module HPCMSL -Scope CurrentUser -AcceptLicense `
                                  -AllowClobber -Force
            Import-Module HPCMSL -Force
        }

        foreach ($id in $ids) {
            $dp = Get-HPDriverPackLatest -Platform $id -ErrorAction 0
            if ($dp) {
                Write-Host "Found in CMSL : $($dp.SoftPaqId) / $($dp.Name)" `
                           -ForegroundColor Green
                break
            }
        }
    }

    # 3.3  Attach to hash
    if ($dp) {
        $cabUrl   = $dp.Url -replace '\.exe$','.cab'
        $cabName  = "$($dp.SoftPaqId).cab"
        $localCab = "$MapDrive:\OSDCloud\DriverPack\$cabName"

        try {
            Invoke-WebRequest $cabUrl -OutFile $localCab -UseBasicParsing -ErrorAction Stop
            Write-Host "CAB saved: $cabName"
            $Global:MyOSDCloud.DriverPackName = $cabName
        }
        catch {
            Write-Warning 'CAB not reachable, using EXE'
            $Global:MyOSDCloud.DriverPackName = "$($dp.SoftPaqId).exe"
        }

        $Global:MyOSDCloud.HPTPMUpdate  = $true
        $Global:MyOSDCloud.HPBIOSUpdate = $true
        $Global:MyOSDCloud.HPIAALL      = $true
    }
    else {
        Write-Warning 'No HP driver pack found.'
    }
}
else {
    Write-Host 'Non-HP device – driver pack search skipped.' -ForegroundColor Yellow
}

# -------------------------------------------------------------
# 4) Run deployment
# -------------------------------------------------------------
Invoke-OSDCloud
Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
