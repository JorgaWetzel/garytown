# Skript zum Entfernen von Registry-Einstellungen für Mozilla Firefox, die von einem vorherigen Skript gesetzt wurden.

$firefox_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Locked"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Search"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Highlights"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Pocket"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Snippets"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "SponsoredPocket"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "SponsoredTopSites"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "TopSites"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "NoDefaultBookmarks"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisablePocket"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "OverrideFirstRunPage"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisableFirefoxAccounts"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisableProfileImport"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
    Name  = "1"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DontCheckDefaultBrowser"
}

# Entfernen der Registry-Einträge
foreach ($setting in $firefox_settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
    if ($registry -ne $null) {
        $registry.DeleteValue($setting.Name, $false) 2>$null
        $registry.Dispose()
    }
}

# Entfernen leerer Registry-Schlüssel, wenn nötig
$policyPaths = @(
    "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome",
    "SOFTWARE\Policies\Mozilla\Firefox",
    "SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
)

foreach ($path in $policyPaths) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path, $true)
    if ($key -ne $null -and $key.GetValueNames().Count -eq 0 -and $key.GetSubKeyNames().Count -eq 0) {
        [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKey($path, $false)
    }
}
