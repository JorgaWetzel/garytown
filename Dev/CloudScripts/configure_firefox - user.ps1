# Skript zum Setzen von Registry-Einstellungen für Mozilla Firefox im Benutzerkontext.

$firefox_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Locked"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Search"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Highlights"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Pocket"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "Snippets"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "SponsoredPocket"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "SponsoredTopSites"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\FirefoxHome"
    Name  = "TopSites"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "NoDefaultBookmarks"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisablePocket"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "OverrideFirstRunPage"
    Value = ""
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisableFirefoxAccounts"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DisableProfileImport"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox\Extensions\Install"
    Name  = "1"
    Value = "https://addons.mozilla.org/firefox/downloads/file/4216633/ublock_origin-1.55.0.xpi"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Mozilla\Firefox"
    Name  = "DontCheckDefaultBrowser"
    Value = 1
}

# Setzen der Registry-Einträge im Benutzerkontext
foreach ($setting in $firefox_settings) {
    $registry = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Path, $true)
    if ($registry -eq $null) {
        $registry = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($setting.Path, $true)
    }
    $registry.SetValue($setting.Name, $setting.Value)
    $registry.Dispose()
}
