# Caritas.ps1 – Online-Config, OS offline vom USB (Index = 1), HP-DriverPacks erlaubt
Import-Module OSD -Force

# 1) WIM auf dem Stick finden (D:–Z:, \OSDCloud\OS\)
$wim = $null
Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $p = "$($_.Root)OSDCloud\OS\Win11_24H2_MUI.wim"   # <-- .Root = "D:\"
    if (Test-Path $p) { $wim = Get-Item $p }
}
if (-not $wim) {
    # Fallback: erstes .wim in \OSDCloud\OS\
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $p = "$($_.Root)OSDCloud\OS\*.wim"
        Get-ChildItem $p -ErrorAction SilentlyContinue | Select-Object -First 1 -OutVariable w
    } | Out-Null
    if ($w -and ($w | Get-Member -Name FullName -MemberType NoteProperty,Property,ScriptProperty)) {
        $wim = $w
    }
}

if (-not $wim) {
    Write-Error "Win11_24H2_MUI.wim nicht gefunden unter *:\OSDCloud\OS\"
    pause
    exit 1
}

# 2) Globales OSDCloud-Hashtable initialisieren (PS 5.1)
if (-not (Get-Variable -Name OSDCloud -Scope Global -ErrorAction SilentlyContinue)) {
    Set-Variable -Name OSDCloud -Scope Global -Value @{}
}
if ($Global:OSDCloud -isnot [hashtable]) { $Global:OSDCloud = @{} }

# 3) Offline-Image fest vorgeben (Index = 1) – OS kommt vom Stick
$Global:OSDCloud.ImageFileOffline = $wim.FullName
$Global:OSDCloud.ImageIndex       = 1
$Global:OSDCloud.OSLanguage       = 'de-de'

# WICHTIG: Keine "None"-Flags setzen -> HP-DriverPacks bleiben erlaubt
# $Global:OSDCloud.DriverPackName             = 'None'            # <- NICHT setzen!
# $Global:OSDCloud.EnableSpecializeDriverPack = $false            # <- NICHT setzen!

# 4) Start (ruft intern Invoke-OSDCloud); ZTI + Reboot am Ende
Start-OSDCloud -ZTI -Restart
