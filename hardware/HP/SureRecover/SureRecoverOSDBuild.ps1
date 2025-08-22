# ---------------- 0. Vorbereitung: Module & Pfade ----------------
# Importiere das HP Client Management Script Library (CMSL) Modul 
# (Stelle sicher, dass HPCMSL installiert ist, z.B. v1.8.2)
Import-Module HPCMSL
Import-Module HP.Firmware -Force

# Basisverzeichnisse und Parameter definieren
$SureRecoverRoot = "C:\SureRecover"            # Basisordner für Sure Recover Dateien
$OSName         = "Win11"                      # Name/Version des OS-Images (für Ordner und URL)
$OSImageDir     = "$SureRecoverRoot\OSImages\$OSName"
$AgentDir       = "$SureRecoverRoot\SRAgent"
$CertDir        = "$SureRecoverRoot\Certificates"
$PayloadDir     = "$SureRecoverRoot\Payloads"
# Azure Blob Storage URLs (öffentlicher Zugriff vorausgesetzt)
$AzureBaseURL   = "https://<youraccount>.blob.core.windows.net/public"   # <--- ANPASSEN
$OSImageURL     = "$AzureBaseURL/OSImages/$OSName/Custom.mft"           # URL zur OS-Manifestdatei
$AgentURL       = "$AzureBaseURL/SRAgent"                               # URL zum Agent-Verzeichnis (Manifest dort)

# Workspace für temporäre Dateien und Logs (optional)
New-Item -Path $OSImageDir -ItemType Directory -Force | Out-Null
New-Item -Path $AgentDir  -ItemType Directory -Force | Out-Null
New-Item -Path $CertDir   -ItemType Directory -Force | Out-Null
New-Item -Path $PayloadDir -ItemType Directory -Force | Out-Null

# ---------------- 1. Optional: Sure Recover Agent erstellen (WinPE) ----------------
# Hinweis: Falls ein HP-Standard-Agent (SoftPaq) genutzt werden soll, diesen Schritt überspringen 
# und stattdessen die SoftPaq-Dateien ins $AgentDir kopieren.
# Hier: Mit OSDCloud einen WinPE mit HPCMSL und Treibern bauen.
New-OSDCloudTemplate -SetInputLocale '0807:00000807'   # z.B. Deutsch(Schweiz) Tastaturlayout
$OSDCloudWorkspace = "$SureRecoverRoot\OSDCloud_Workspace"
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace
# WinPE bauen mit HP Cloud-Treibern, USB, WiFi und HPCMSL-Modul vorinstalliert
Edit-OSDCloudWinPE -CloudDriver HP,USB,WiFi -PSModuleInstall HPCMSL

# Exportiere den erzeugten WinPE WIM und komprimiere ihn maximal 
$srcWim  = "$OSDCloudWorkspace\Media\sources\boot.wim"
$destWim = "$AgentDir\osdcloud.wim"
dism /Export-Image /SourceImageFile:$srcWim /SourceIndex:1 /DestinationImageFile:$destWim /Compress:max

# ---------------- 2. Windows-Installations-Image vorbereiten (Split + Manifest) ----------------
# Hinweis: Falls die .swm, .mft und .sig bereits extern erstellt wurden, kann dieser Abschnitt übersprungen werden.
# Splitte Install.wim in 64MB Teile (.swm) und erstelle Manifest und Signatur.
$SourceInstallWim = "<PFAD-ZUM-INSTALL.WIM>"   # <--- ANPASSEN: Pfad zum benutzerdefinierten Windows WIM
$splitName = "$OSName.swm"   # Basisname der SWM-Dateien ("Win11.swm", "Win112.swm", ...)
dism /Split-Image /ImageFile:"$SourceInstallWim" /SwmFile:"$OSImageDir\$splitName" /FileSize:64

# Manifest-Datei (.mft) für das OS-Image erzeugen
$mftFileOS = "$OSImageDir\Custom.mft"
$sigFileOS = "$OSImageDir\Custom.sig"
# Entferne evtl. existierende alte Manifest/Signatur
Remove-Item -Path $mftFileOS -ErrorAction SilentlyContinue
Remove-Item -Path $sigFileOS -ErrorAction SilentlyContinue
# Header schreiben (mft_version=1 für OS, image_version kann z.B. Datum oder Build-Nummer sein)
$mft_versionOS = 1
$image_versionOS = (Get-Date -Format 'yy.MM.dd')   # z.B. "25.08.06" für 6. August 2025
$headerOS = "mft_version=$mft_versionOS, image_version=$image_versionOS"
Out-File -Encoding UTF8 -NoNewline -FilePath $mftFileOS -InputObject $headerOS

# Dateien im OS-Image-Verzeichnis auflisten und nach natürlicher Reihenfolge sortieren
$FilesOS = Get-ChildItem -Path $OSImageDir -File
$ToNatural = { [regex]::Replace($_, '\d+\..+$', { $args[0].Value.PadLeft(50) }) }
$FilesOS = $FilesOS | Sort-Object { $ToNatural.Invoke($_.Name) }

# Hash, Pfad und Größe jeder Datei ins Manifest schreiben
foreach ($file in $FilesOS) {
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLower()
    $relativePath = $file.Name  # da alle im selben Verzeichnis sind
    $size = $file.Length
    $line = "$hash $relativePath $size"
    Out-File -Encoding UTF8 -FilePath $mftFileOS -InputObject $line -Append
}
# Sicherstellen, dass die Datei als UTF8 ohne BOM gespeichert wird:
$contentOS = Get-Content $mftFileOS -Encoding UTF8
[System.IO.File]::WriteAllLines($mftFileOS, $contentOS, (New-Object System.Text.UTF8Encoding $False))

# Manifest-Datei für den Recovery Agent (WinPE) erzeugen
$mftFileAgent = "$AgentDir\recovery.mft"
$sigFileAgent = "$AgentDir\recovery.sig"
Remove-Item -Path $mftFileAgent -ErrorAction SilentlyContinue
Remove-Item -Path $sigFileAgent -ErrorAction SilentlyContinue
# Header für Agent-Manifest (mft_version=20, image_version kann Versionsnummer des Agents sein)
$mft_versionAgent = 20
$image_versionAgent = "1"   # z.B. "1" oder Buildnummer des WinPE, hier trivial 1
$headerAgent = "mft_version=$mft_versionAgent, image_version=$image_versionAgent"
Out-File -Encoding UTF8 -NoNewline -FilePath $mftFileAgent -InputObject $headerAgent

$FilesAgent = Get-ChildItem -Path $AgentDir -File
$FilesAgent = $FilesAgent | Sort-Object { $ToNatural.Invoke($_.Name) }
foreach ($file in $FilesAgent) {
    $hash = (Get-FileHash -Algorithm SHA256 -Path $file.FullName).Hash.ToLower()
    $relativePath = $file.Name
    $size = $file.Length
    Out-File -Encoding UTF8 -FilePath $mftFileAgent -InputObject "$hash $relativePath $size" -Append
}
$contentAgent = Get-Content $mftFileAgent -Encoding UTF8
[System.IO.File]::WriteAllLines($mftFileAgent, $contentAgent, (New-Object System.Text.UTF8Encoding $False))

# ---------------- 3. Zertifikate und Schlüssel erzeugen (OpenSSL) ----------------
# Voraussetzung: OpenSSL ist installiert (z.B. in C:\Program Files\OpenSSL-Win64)
# Setze OpenSSL-Umgebung, damit legacy Algorithmen verfügbar sind (für 3DES-Verschlüsselung in PFX)
$env:OPENSSL_CONF = "$([System.IO.Path]::Combine($env:ProgramFiles, 'OpenSSL-Win64', 'bin', 'openssl.cfg'))"
$env:OPENSSL_MODULES = "$([System.IO.Path]::Combine($env:ProgramFiles, 'OpenSSL-Win64', 'lib', 'ossl-modules'))"
Set-Location "$([System.IO.Path]::Combine($env:ProgramFiles, 'OpenSSL-Win64', 'bin'))"
if(-not (Test-Path $env:OPENSSL_MODULES\legacy.dll)) {
    Write-Warning "OpenSSL Legacy-Modul (legacy.dll) nicht gefunden. PFX-Erstellung könnte fehlschlagen."
}

# 3.1 Secure Platform Signing Key (SK) erzeugen - privater Schlüssel & selbstsigniertes Zertifikat
$SKKeyFile   = "$CertDir\SureRecoverSigning.key"
$SKCertFile  = "$CertDir\SureRecoverSigning.crt"
$SKPfxFile   = "$CertDir\SureRecoverSigning.pfx"
$SKPassword  = "Just4OSDCloud!"    # Passwort für den Signing-Key-PFX  <--- ANPASSEN
# (Passwort sicher aufbewahren; benötigt zum Erzeugen der Payloads)

# 1) Private Key generieren (4096-bit RSA)
Write-Host "Generating Signing Key..." 
& openssl genrsa -out "$SKKeyFile" 4096
# 2) Selbstsigniertes X.509-Zertifikat erstellen (gültig 10 Jahre)
& openssl req -new -x509 -key "$SKKeyFile" -out "$SKCertFile" -days 3650 -subj "/CN=HP Sure Recover Signing"
# 3) In passwortgeschützte PFX-Datei exportieren
& openssl pkcs12 -export -out "$SKPfxFile" -inkey "$SKKeyFile" -in "$SKCertFile" -passout pass:$SKPassword

# (Optional) Signing-Zertifikat prüfen
& openssl x509 -in "$SKCertFile" -noout -text | Select-String "CN="

# 3.2 Secure Platform Endorsement Key (EK) erzeugen - privater Schlüssel & Zertifikat
$EKKeyFile   = "$CertDir\SecurePlatformEndorsement.key"
$EKCertFile  = "$CertDir\SecurePlatformEndorsement.crt"
$EKPfxFile   = "$CertDir\SecurePlatformEndorsement.pfx"
$EKPassword  = "Just4OSDCloud!"   # Passwort für den Endorsement-Key-PFX (kann gleich sein)  <--- ANPASSEN

Write-Host "Generating Endorsement Key..." 
# Private Key generieren (4096-bit RSA) & selbstsigniertes Zertifikat erstellen & in PFX exportieren (legacy)
& openssl genrsa -out "$EKKeyFile" 4096
& openssl req -new -x509 -key "$EKKeyFile" -out "$EKCertFile" -days 3650 -subj "/CN=Secure Platform - Endorsement Key"
& openssl pkcs12 -export -legacy -inkey "$EKKeyFile" -in "$EKCertFile" -name "HP Secure Platform Key Endorsement Certificate" -out "$EKPfxFile" -passout pass:$EKPassword

# (Optional) Endorsement-Zertifikat prüfen
& openssl x509 -in "$EKCertFile" -noout -text | Select-String "CN="

# 3.3 Signieren der Manifest-Dateien mit dem Signing Key
Write-Host "Signing manifest files..."
# Hinweis: OpenSSL kann den PFX direkt verwenden, wenn Passwort über -passin gegeben wird.
# Alternativ könnte man auch den zuvor generierten .key nutzen.
& openssl dgst -sha256 -sign "$SKKeyFile" -out "$sigFileOS" -passin pass:$SKPassword "$mftFileOS"
& openssl dgst -sha256 -sign "$SKKeyFile" -out "$sigFileAgent" -passin pass:$SKPassword "$mftFileAgent"
# (Falls obiger Befehl fehlschlägt, ggf. PFX -> PEM Key extrahieren und dann signieren:
#  openssl pkcs12 -in $SKPfxFile -nocerts -nodes -passin pass:$SKPassword -out sk_private.pem
#  openssl dgst -sha256 -sign sk_private.pem -out ... )

# ---------------- 4. Payload-Dateien erzeugen (HP CMSL) ----------------
[UInt16]$Version = 1   # Startwert für die Provisionierungs-Versionen
# Hinweis: Falls schon Sure Recover Einstellungen existieren, muss Version höher sein als der aktuelle Wert.
# Im Zweifel per (Get-CimInstance -ClassName HP_BIOSSetting -Namespace root\hp\InstrumentedBIOS | 
#    Where-Object Name -like 'OS Recovery * Version').Value prüfen.

Write-Host "Creating Secure Platform provisioning payloads..."
$SPEKPayload = "$PayloadDir\SPEKPayload.dat"      # Secure Platform Endorsement Key Provisioning Payload
$SPSKPayload = "$PayloadDir\SPSKPayload.dat"      # Secure Platform Signing Key Provisioning Payload
New-HPSecurePlatformEndorsementKeyProvisioningPayload -EndorsementKeyFile "$EKPfxFile" -EndorsementKeyPassword $EKPassword -OutputFile $SPEKPayload
New-HPSecurePlatformSigningKeyProvisioningPayload -EndorsementKeyFile "$EKPfxFile" -EndorsementKeyPassword $EKPassword `
    -SigningKeyFile "$SKPfxFile" -SigningKeyPassword $SKPassword -OutputFile $SPSKPayload

Write-Host "Creating Sure Recover image configuration payloads..."
$OSPayload   = "$PayloadDir\OSImagePayload.dat"
$AgentPayload = "$PayloadDir\AgentPayload.dat"
# OS-Payload (enthält OS-Manifest-URL und Zertifikat für OS-Image-Verification)
New-HPSureRecoverImageConfigurationPayload -Image OS -SigningKeyFile "$SKPfxFile" -SigningKeyPassword $SKPassword `
    -ImageCertificateFile "$SKPfxFile" -ImageCertificatePassword $SKPassword `
    -Url $OSImageURL -Version $Version -OutputFile $OSPayload
# Agent-Payload (enthält Agent-URL (Verzeichnis) und Zertifikat für Agent-Verification)
New-HPSureRecoverImageConfigurationPayload -Image Agent -SigningKeyFile "$SKPfxFile" -SigningKeyPassword $SKPassword `
    -ImageCertificateFile "$SKPfxFile" -ImageCertificatePassword $SKPassword `
    -Url $AgentURL -Version $Version -OutputFile $AgentPayload

# (Optional) Deprovisioning-Payloads erzeugen, um Sure Recover/SPM ggf. zurückzusetzen
$SRDeprovPayload = "$PayloadDir\SureRecoverDeprov.dat"
$SPMDeprovPayload = "$PayloadDir\SecurePlatformDeprov.dat"
New-HPSureRecoverDeprovisionPayload -SigningKeyFile "$SKPfxFile" -SigningKeyPassword $SKPassword -OutputFile $SRDeprovPayload
New-HPSecurePlatformDeprovisioningPayload -EndorsementKeyFile "$EKPfxFile" -EndorsementKeyPassword $EKPassword -OutputFile $SPMDeprovPayload

Write-Host "Payload files created under $PayloadDir."

# ---------------- 5. Payloads ins BIOS übertragen (Achtung: erfordert Admin und evtl. Neustart mit Bestätigung) ----------------
# Hinweis: Ab hier werden BIOS-Änderungen durchgeführt. Sicherstellen, dass das Gerät an ist und HP BIOS WMI bereit.
Write-Host "Applying payloads to BIOS (SPM provisioning and Sure Recover configuration)..."
# Schritt 5.1: Endorsement Key ins BIOS
Set-HPSecurePlatformPayload -PayloadFile $SPEKPayload
Write-Host "Endorsement Key Payload applied. (Bei erstem Mal BIOS-PIN-Eingabe erforderlich!)"
# Nach Anwendung des Endorsement-Key-Payloads kann ein Reboot mit Prompt nötig sein. 
# In automatisierten Szenarien müsste hier gewartet werden, bis der User bestätigt hat.

# Schritt 5.2: Signing Key ins BIOS
Set-HPSecurePlatformPayload -PayloadFile $SPSKPayload
Write-Host "Signing Key Payload applied."

# Schritt 5.3: (Optional) Sure Recover Agent konfigurieren
Set-HPSecurePlatformPayload -PayloadFile $AgentPayload
Write-Host "Agent Image Payload applied."

# Schritt 5.4: Sure Recover OS-Image konfigurieren
Set-HPSecurePlatformPayload -PayloadFile $OSPayload
Write-Host "OS Image Payload applied."

Write-Host "HP Sure Recover wurde erfolgreich konfiguriert. Bitte Gerät neu starten und im BIOS prüfen."
