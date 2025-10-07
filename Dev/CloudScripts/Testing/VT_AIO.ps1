# E-Mail in Dialog abfragen (Fallback: Read-Host wenn Dialog nicht verfügbar)
try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}
$to = $null
$to = [Microsoft.VisualBasic.Interaction]::InputBox("E-Mail-Adresse des Empfängers:","KillDisk Report","")

# KillDisk starten und warten bis Ende
$proc = Start-Process 'X:\Bootdisk\KillDisk.exe' -ArgumentList '-wa','-bm','em=1' -PassThru
$proc.WaitForExit()

# PDFs einsammeln
$pdfFile = Get-ChildItem -Path "X:\OSDCloud\Config\Bootdisk\" -Filter Certificate*.pdf -File | Select-Object -Expand FullName
$att=@($pdfFile.FullName); 'X:\OSDCloud\logs\Win32_BaseBoard.txt','X:\OSDCloud\logs\Win32_BIOS.txt','X:\OSDCloud\logs\Win32_ComputerSystem.txt','X:\OSDCloud\logs\Win32_DiskDrive.txt','X:\OSDCloud\logs\Win32_Processor.txt'|%{if(Test-Path $_){$att+=$_}}

# TLS 1.2 für O365 erzwingen
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# O365-Credentials
$cred = New-Object System.Management.Automation.PSCredential(
    'service@variotrade.ch',
    (ConvertTo-SecureString 'W/046330626595ol' -AsPlainText -Force)
)

# Mail senden
Send-MailMessage -From 'service@variotrade.ch' -To $to -Subject 'Löschzertifikat – Systembereinigung durch VarioTrade' -Body `
"Das System wurde von VarioTrade erfolgreich gelöscht. 
Im Anhang finden Sie das Löschzertifikat sowie die relevanten Hardware-Informationen." `
-Attachments $att -SmtpServer 'smtp.office365.com' -Port 587 -UseSsl -Credential $cred
