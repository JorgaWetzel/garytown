# E-Mail in Dialog abfragen (Fallback: Read-Host wenn Dialog nicht verfügbar)
try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}
$to = $null
$to = [Microsoft.VisualBasic.Interaction]::InputBox("E-Mail-Adresse des Empfängers:","KillDisk Report","")

# KillDisk starten
& "X:\OSDCloud\Config\Bootdisk\KillDisk.exe" -wa -bm em=1

# PDFs einsammeln
$files = Get-ChildItem -Path "X:\OSDCloud\Config\Bootdisk\" -Filter Certificate*.pdf -File | Select-Object -Expand FullName

# TLS 1.2 für O365 erzwingen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# O365-Credentials
$cred = New-Object System.Management.Automation.PSCredential(
    'service@variotrade.ch',
    (ConvertTo-SecureString 'W/046330626595ol' -AsPlainText -Force)
)

# Mail senden
Send-MailMessage -From 'service@variotrade.ch' -To $to -Subject 'KillDisk Report' -Body 'Im Anhang.' `
  -Attachments $files -SmtpServer 'smtp.office365.com' -Port 587 -UseSsl -Credential $cred
