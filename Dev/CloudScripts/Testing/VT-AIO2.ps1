# --- Win11-Style Auswahlmenü für WinPE / OSDCloud ---------------------------------

# WPF braucht STA – ggf. im STA-Modus neu starten
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
  Start-Process powershell -ArgumentList "-sta -ExecutionPolicy Bypass -NoLogo -NoProfile -File `"$PSCommandPath`"" -Wait
  exit
}

# WPF laden, sonst Fallback auf Konsole
$wpfOK = $true
try { Add-Type -AssemblyName PresentationFramework,PresentationCore } catch { $wpfOK = $false }


# ---------- Aktionen ----------
function Start-EraserAndMail {
  # Empfänger erfragen
  try { Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop } catch {}
  $to = [Microsoft.VisualBasic.Interaction]::InputBox("E-Mail-Adresse des Empfängers:","KillDisk Report","")

  # KillDisk starten und warten
  $kd = 'X:\OSDCloud\Config\Bootdisk\KillDisk.exe'
  if (-not (Test-Path $kd)) { throw "KillDisk nicht gefunden: $kd" }
  $proc = Start-Process -FilePath $kd -WorkingDirectory (Split-Path $kd) -ArgumentList '-wa','-bm','em=1' -PassThru
  $proc.WaitForExit()

  # PDF & Logs
  $pdf = Get-ChildItem 'X:\OSDCloud\Config\Bootdisk' -Filter 'Certificate*.pdf' -File |
         Sort-Object LastWriteTime -Desc | Select-Object -First 1
  $att = @()
  if ($pdf) { $att += $pdf.FullName }
  'X:\OSDCloud\logs\Win32_BaseBoard.txt',
  'X:\OSDCloud\logs\Win32_BIOS.txt',
  'X:\OSDCloud\logs\Win32_ComputerSystem.txt',
  'X:\OSDCloud\logs\Win32_DiskDrive.txt',
  'X:\OSDCloud\logs\Win32_Processor.txt' | % { if (Test-Path $_) { $att += $_ } }

  if ([string]::IsNullOrWhiteSpace($to)) { throw "Kein Empfänger." }
  if ($att.Count -eq 0) { throw "Keine Anhänge gefunden." }

  # Mail (UTF-8) via O365
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $smtp = New-Object System.Net.Mail.SmtpClient('smtp.office365.com',587)
  $smtp.EnableSsl = $true
  $smtp.Credentials = New-Object System.Net.NetworkCredential('service@variotrade.ch','W/046330626595ol')

  $mail = New-Object System.Net.Mail.MailMessage
  $mail.From = 'service@variotrade.ch'
  $mail.To.Add($to)
  $mail.Subject = 'Löschzertifikat – Systembereinigung durch VarioTrade'
  $mail.SubjectEncoding = [Text.Encoding]::UTF8
  $mail.Body = "VarioTrade hat das System erfolgreich gelöscht. Im Anhang finden Sie das Löschzertifikat sowie Hardwareinformationen."
  $mail.BodyEncoding = [Text.Encoding]::UTF8
  foreach($a in $att){ $mail.Attachments.Add($a) }
  $smtp.Send($mail); $mail.Dispose()
}

function Start-InstallWin11 {
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $url = 'https://raw.githubusercontent.com/JorgaWetzel/garytown/master/Dev/CloudScripts/Customers/Caritas.ps1'
    $dst = 'X:\OSDCloud\Scripts\Caritas.ps1'
    New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $dst -UseBasicParsing
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoLogo -NoProfile -File `"$dst`"" -Wait
  }
  catch {
    try { Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue } catch {}
    [System.Windows.MessageBox]::Show("Download/Start fehlgeschlagen:`n$($_.Exception.Message)","Fehler") | Out-Null
  }
}


# --- GUI laden (robust) ---
# --- GUI laden (STA-Block & Add-Type wie besprochen beibehalten) ---
Add-Type -AssemblyName PresentationFramework,PresentationCore

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="VarioTrade – Service Portal" Width="520" Height="320"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#F3F3F3">
  <Grid Margin="24">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
    </Grid.RowDefinitions>

    <StackPanel Orientation="Vertical" Margin="0,0,0,16">
      <TextBlock Text="Aktion wählen" FontFamily="Segoe UI" FontSize="24" FontWeight="SemiBold"/>
      <TextBlock Text="Bitte wählen Sie eine der folgenden Optionen." FontFamily="Segoe UI" FontSize="12" Foreground="#555"/>
    </StackPanel>

    <UniformGrid Grid.Row="1" Rows="2" Columns="1">
      <Button x:Name="btnErase" Margin="0,0,0,12" Height="90" FontFamily="Segoe UI" FontSize="18" Background="White" BorderBrush="#D0D0D0" BorderThickness="1">
        <StackPanel Orientation="Vertical" Margin="8">
          <TextBlock Text="1 · System löschen &amp; Zertifikat per E-Mail" FontWeight="SemiBold"/>
          <TextBlock Text="KillDisk ausführen und Report versenden" FontSize="12" Foreground="#666"/>
        </StackPanel>
      </Button>
      <Button x:Name="btnInstall" Height="90" FontFamily="Segoe UI" FontSize="18" Background="White" BorderBrush="#D0D0D0" BorderThickness="1">
        <StackPanel Orientation="Vertical" Margin="8">
          <TextBlock Text="2 · Windows 11 Pro installieren" FontWeight="SemiBold"/>
          <TextBlock Text="Caritas.ps1 starten (Download von GitHub)" FontSize="12" Foreground="#666"/>
        </StackPanel>
      </Button>
    </UniformGrid>
  </Grid>
</Window>
'@

# XAML direkt parsen (ohne [xml]-Cast)
try {
  $win = [Windows.Markup.XamlReader]::Parse($xaml)
} catch {
  Write-Host "XAML-Fehler: $($_.Exception.Message)" -ForegroundColor Red
  $win = $null
}

if ($win) {
  ($win.FindName('btnErase')).Add_Click({
    $win.Close()
    try { Start-EraserAndMail } catch { [System.Windows.MessageBox]::Show($_.Exception.Message,'Fehler') | Out-Null }
  })
  ($win.FindName('btnInstall')).Add_Click({
    $win.Close()
    try { Start-InstallWin11 } catch { [System.Windows.MessageBox]::Show($_.Exception.Message,'Fehler') | Out-Null }
  })
  $win.ShowDialog() | Out-Null
} else {
  Write-Host "`nVarioTrade – Service Portal" -ForegroundColor Cyan
  Write-Host "1) System löschen & E-Mail"
  Write-Host "2) Windows 11 Pro installieren"
  switch (Read-Host "Auswahl") { '1' { Start-EraserAndMail }; '2' { Start-InstallWin11 } default { 'Abbruch' } }
}
