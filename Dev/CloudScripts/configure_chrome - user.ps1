# Skript zum Setzen von Registry-Einstellungen für Google Chrome im Benutzerkontext.

$chrome_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxPromptEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxAdMeasurementEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxAdTopicsEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxSiteEnabledAdsEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "DefaultNotificationsSetting"
    Value = 2
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    Name  = "1"
    Value = "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist"
    Name  = "2"
    Value = "oldceeleldhonbafppcapldpdifcinji" # Grammatik
}

# Setzen der Registry-Einträge im Benutzerkontext
foreach ($setting in $chrome_settings) {
    $registry = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Path, $true)
    if ($registry -eq $null) {
        $registry = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($setting.Path, $true)
    }
    $registry.SetValue($setting.Name, $setting.Value)
    $registry.Dispose()
}
