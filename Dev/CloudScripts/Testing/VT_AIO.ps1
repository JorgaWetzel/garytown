# Empfänger erfragen
try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}
$to = [Microsoft.VisualBasic.Interaction]::InputBox("E-Mail-Adresse des Empfängers:","KillDisk Report","")

# KillDisk starten und warten
$kd = 'X:\OSDCloud\Config\Bootdisk\KillDisk.exe'
if (-not (Test-Path $kd)) { throw "KillDisk nicht gefunden: $kd" }
$proc = Start-Process -FilePath $kd -WorkingDirectory (Split-Path $kd) -ArgumentList '-wa','-bm','em=1' -PassThru
$proc.WaitForExit()

# PDF & Logs einsammeln
$pdf = Get-ChildItem 'X:\OSDCloud\Config\Bootdisk' -Filter 'Certificate*.pdf' -File |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1
$att = @()
if ($pdf) { $att += $pdf.FullName }
'X:\OSDCloud\logs\Win32_BaseBoard.txt',
'X:\OSDCloud\logs\Win32_BIOS.txt',
'X:\OSDCloud\logs\Win32_ComputerSystem.txt',
'X:\OSDCloud\logs\Win32_DiskDrive.txt',
'X:\OSDCloud\logs\Win32_Processor.txt' | ForEach-Object { if (Test-Path $_) { $att += $_ } }

# O365-Verbindung vorbereiten
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$smtp = New-Object System.Net.Mail.SmtpClient('smtp.office365.com',587)
$smtp.EnableSsl = $true
$smtp.Credentials = New-Object System.Net.NetworkCredential('service@variotrade.ch','W/046330626595ol')

# UTF-8 Mail erzeugen
$mail = New-Object System.Net.Mail.MailMessage
$mail.From = 'service@variotrade.ch'
$mail.To.Add($to)
$mail.Subject = 'Löschzertifikat – Systembereinigung durch VarioTrade'
$mail.SubjectEncoding = [System.Text.Encoding]::UTF8
$mail.Body = "VarioTrade hat das System erfolgreich gelöscht. Im Anhang finden Sie das Löschzertifikat sowie Hardwareinformationen."
$mail.BodyEncoding = [System.Text.Encoding]::UTF8
foreach($a in $att){$mail.Attachments.Add($a)}

# Mail senden
$smtp.Send($mail)
$mail.Dispose()
