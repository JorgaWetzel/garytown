# Skript zum Entfernen von Registry-Einstellungen, die von einem vorherigen Skript gesetzt wurden.

$chrome_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxPromptEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxAdMeasurementEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxAdTopicsEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "PrivacySandboxSiteEnabledAdsEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Google\Chrome"
    Name  = "DefaultNotificationsSetting"
},
[PSCustomObject]@{
    Path  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
    Name  = "1"
},
[PSCustomObject]@{
    Path  = "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
    Name  = "2"
}

# Entfernen der Registry-Einträge
foreach ($setting in $chrome_settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
    if ($registry -ne $null) {
        $registry.DeleteValue($setting.Name, $false) 2>$null
        $registry.Dispose()
    }
}

# Entfernen leerer Registry-Schlüssel, wenn nötig
$policyPaths = @(
    "SOFTWARE\Policies\Google\Chrome",
    "Software\Policies\Google\Chrome\ExtensionInstallForcelist"
)

foreach ($path in $policyPaths) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path, $true)
    if ($key -ne $null -and $key.GetValueNames().Count -eq 0 -and $key.GetSubKeyNames().Count -eq 0) {
        [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKey($path, $false)
    }
}
