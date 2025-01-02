# Skript zum Setzen von Registry-Einstellungen für Brave im Benutzerkontext.

$brave_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveRewardsDisabled"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveVPNDisabled"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveWalletDisabled"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "TorDisabled"
    Value = 1
}

# Setzen der Registry-Einträge im Benutzerkontext
foreach ($setting in $brave_settings) {
    $registry = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Path, $true)
    if ($registry -eq $null) {
        $registry = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($setting.Path, $true)
    }
    $registry.SetValue($setting.Name, $setting.Value)
    $registry.Dispose()
}
