﻿# ── 0. Einmalig: Module holen ──────────────────────────────────────────
https://www.hp.com/us-en/solutions/client-management-solutions/download.html
hp-cmsl-1.8.2.exe --> installieren. 
Import-Module HPCMSL                 # lädt das Metamodul
Import-Module HP.Firmware -Force     # lädt die Firmware-Unterfunktionen
Get-Command -Module HP.Firmware *SureRecover* | Select Name

# ── 1. Workspace anlegen ──────────────────────────────────────────────
New-OSDCloudTemplate  -SetInputLocale '0807:00000807'
$OSDCloudWorkspace = "C:\Service\OSDCloudSureStart"
New-OSDCloudWorkspace -WorkspacePath $OSDCloudWorkspace
Edit-OSDCloudWinPE -CloudDriver HP,USB,WiFi -PSModuleInstall HPCMSL -StartOSDCloudGUI #-Verbose


# ── 3. Agent-WIM exportieren & maximal komprimieren ───────────────────
$src  = 'C:\Service\OSDCloudSureStart\Media\sources\boot.wim'
$dest = 'C:\Service\SureRecover\SRAgent\osdcloud.wim'
New-Item 'C:\Service\SureRecover\SRAgent' -ItemType Directory -Force | Out-Null
dism /Export-Image /SourceImageFile:$src /SourceIndex:1 `
                   /DestinationImageFile:$dest /Compress:max

Win64OpenSSL-3_5_0.msi -> installieren

# 1) Privaten Schlüssel erzeugen
openssl genrsa -out sk.key 4096
# 2) Selbstsigniertes X.509-Zertifikat (10 Jahre gültig)
openssl req -new -x509 -key sk.key -out sk.crt -days 3650 -subj "/CN=HP Sure Recover Signing"
# 3) In passwort­geschützte PFX-Datei exportieren
openssl pkcs12 -export -out sk.pfx -inkey sk.key -in sk.crt -password pass:Just4OSDCloud!
# Zertifikat OHNE Private Key extrahieren
openssl pkcs12 -in sk.pfx -clcerts -nokeys -out temp-cert.pem -passin pass:Just4OSDCloud!
# Nur den Public Key herausfiltern
openssl x509 -in temp-cert.pem -pubkey -noout > AgentPubKey.pem

# 2.1  Agent-Payload (OSDCloud-WinPE)
New-HPSureRecoverImageConfigurationPayload `
  -Image  Agent `
  -Url    'https://hpsr001.blob.core.windows.net/public' `
  -SigningKeyFile   .\sk.pfx `
  -SigningKeyPassword 'Just4OSDCloud!' `
  -PublicKeyFile    .\AgentPubKey.pem `
  -OutputFile       C:\Service\SureRecover\SRAgent\AgentPayload.bin


# 2.2  OS-Payload
New-HPSureRecoverImageConfigurationPayload `
   -Image OS `
   -Url "https://<blob>/OSImages/Win11" `
   -SigningKeyFile  .\sk.pfx `
   -SigningKeyPassword "<PW>" `
   -OutputFile      C:\SureRecover\Win11\OSPayload.bin
