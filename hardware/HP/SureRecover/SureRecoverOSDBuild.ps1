# ── 0. Einmalig: Module holen ──────────────────────────────────────────
Install-Module OSD      -Scope AllUsers -Force                      # OSDCloud
Install-Module HPCMSL   -Scope AllUsers -Force -AcceptLicense       # HP BIOS Tools
Get-HPSureRecoverState -All

# ── 1. Workspace anlegen ──────────────────────────────────────────────
Import-Module OSD
New-OSDCloudTemplate  -SetInputLocale '0807:00000807'

$OSDCloudWorkspace = "C:\Service\OSDCloudSureStart"
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace

# ── 2. WinPE aufbauen  (fügt PowerShell + Netz-Treiber + WLAN) ────────
#    -CloudDriver *  holt automatisch den Intel-AX201-WLAN-Treiber,
#      der im 1040 G7 verbaut ist.

Edit-OSDCloudWinPE -CloudDriver HP,USB,WiFi -PSModuleInstall HPCMSL -StartOSDCloudGUI #-Verbose


# ── 3. Agent-WIM exportieren & maximal komprimieren ───────────────────
$src  = 'C:\Service\OSDCloudSureStart\Media\sources\boot.wim'
$dest = 'C:\Service\SureRecover\SRAgent\osdcloud.wim'
New-Item 'C:\Service\SureRecover\SRAgent' -ItemType Directory -Force | Out-Null
dism /Export-Image /SourceImageFile:$src /SourceIndex:1 `
                   /DestinationImageFile:$dest /Compress:max

# ── 4. Smoke-Test in Hyper-V / USB  (optional) ────────────────────────
# (vor Sure-Recover-Integration einmal lokal booten)


New-HPSureRecoverManifest  -Path C:\SureRecover\SRAgent `
                           -Output C:\SureRecover\SRAgent\recovery.mft
New-HPSureRecoverSignature -Manifest recovery.mft `
                           -SigningCert .\AgentKey.pem `
                           -Output   C:\SureRecover\SRAgent\recovery.sig
