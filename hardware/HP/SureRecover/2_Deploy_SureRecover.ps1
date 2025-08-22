# =====================================================================
# 2_Deploy_SureRecover.ps1 – auf dem HP Zielgerät ausführen
# =====================================================================
# Erwartet: 4 Payload-Dateien (SPEKPayload.dat, SPSKPayload.dat, AgentPayload.dat, OSImagePayload.dat)
#           im Ordner C:\Service\SureRecover\Payloads

Import-Module HPCMSL
Import-Module HP.Firmware -Force

$SureRecoverRoot = "C:\Service\SureRecover"
$PayloadDir      = "$SureRecoverRoot\Payloads"

$SPEKPath  = Join-Path $PayloadDir 'SPEKPayload.dat'
$SPSKPath  = Join-Path $PayloadDir 'SPSKPayload.dat'
$AgentPath = Join-Path $PayloadDir 'AgentPayload.dat'
$OSPath    = Join-Path $PayloadDir 'OSImagePayload.dat'

$missing = @()
foreach ($p in @($SPEKPath,$SPSKPath,$AgentPath,$OSPath)) {
  if (!(Test-Path $p)) { $missing += $p }
}
if ($missing.Count) {
  throw "Folgende Payload-Dateien fehlen:`n - " + ($missing -join "`n - ")
}

Write-Host ">> Provisioniere Endorsement Key..."
Set-HPSecurePlatformPayload -PayloadFile $SPEKPath

Write-Host ">> Provisioniere Signing Key..."
Set-HPSecurePlatformPayload -PayloadFile $SPSKPath

Write-Host ">> Setze Sure Recover AGENT..."
Set-HPSecurePlatformPayload -PayloadFile $AgentPath

Write-Host ">> Setze Sure Recover OS..."
Set-HPSecurePlatformPayload -PayloadFile $OSPath

Write-Host "`n=== Secure Platform State ==="
Get-HPSecurePlatformState
Write-Host "`n=== Sure Recover State (All) ==="
Get-HPSureRecoverState -All

Write-Host "`nHinweis: Bei Erst-Provisionierung ist eine BIOS-/PPI-Bestätigung am Gerät erforderlich."
