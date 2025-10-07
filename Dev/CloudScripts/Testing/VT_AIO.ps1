# Empfänger erfragen
try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}
$to = [Microsoft.VisualBasic.Interaction]::InputBox("E-Mail-Adresse des Empfängers:","KillDisk Report","")

# KillDisk starten und warten bis Ende
$proc = Start-Process 'X:\OSDCloud\Config\Bootdisk\KillDisk.exe' -ArgumentList '-wa','-bm','em=1' -PassThru
$proc.WaitForExit()

# PDFs einsammeln (Objekt behalten, dann .FullName nehmen)
$pdf = Get-ChildItem 'X:\OSDCloud\Config\Bootdisk' -Filter 'Certificate*.pdf' -File |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Attachments zusammenstellen
$att = @()
if ($pdf) { $att += $pdf.FullName }
'X:\OSDCloud\logs\Win32_BaseBoard.txt',
'X:\OSDCloud\logs\Win32_BIOS.txt',
'X:\OSDCloud\logs\Win32_ComputerSystem.txt',
'X:\OSDCloud\logs\Win32_DiskDrive.txt',
'X:\OSDCloud\logs\Win32_Processor.txt' | ForEach-Object { if (Test-Path $_) { $att += $_ } }

# Mail nur senden, wenn Empfänger & mind. ein Anhang vorhanden
if ([string]::IsNullOrWhiteSpace($to)) { throw "Kein Empfänger." }
if ($att.Count -eq 0) { throw "Keine Anhänge gefunden." }

# O365 Versand
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$cred = New-Object pscredential('service@variotrade.ch',(ConvertTo-SecureString 'W/046330626595ol' -AsPlainText -Force))

Send-MailMessage -From 'service@variotrade.ch' -To $to `
  -Subject 'Löschzertifikat – Systembereinigung durch VarioTrade' `
  -Body 'VarioTrade hat das System erfolgreich gelöscht. Im Anhang finden Sie das Löschzertifikat sowie Hardwareinformationen.' `
  -Attachments $att -SmtpServer 'smtp.office365.com' -Port 587 -UseSsl -Credential $cred
