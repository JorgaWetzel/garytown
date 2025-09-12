# Caritas.ps1 – nur Konfig, dann lokaler Start aus D:\OSDCloud\OS\, Index 1
Import-Module OSD -Force

Write-Host "[Caritas] Online-Config geladen" -ForegroundColor Cyan

# --- HIER deine Konfigs (Registry, ODT, Autopilot, Branding, etc.) ---
# ... nichts starten, nichts downloaden ...
# ----------------------------------------------------------------------

# Jetzt garantiert lokal installieren (findet D:\OSDCloud\OS\*.wim)
Start-OSDCloud -ImageFile 'D:\OSDCloud\OS\Win11_24H2_MUI.wim' -ImageIndex 1 -ZTI -Restart

