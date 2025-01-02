# Skript zum Setzen von Registry-Einstellungen für Microsoft Edge im Benutzerkontext.

$edge_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "PinBrowserEssentialsToolbarButton"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "ImportFavorites"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "ManagedSearchEngines"
    Value = "{"is_default":true,"keyword":"google","name":"google.com","search_url":"https://www.google.ch/search?q={searchTerms}"}"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "SplitScreenEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "HideFirstRunExperience"
    Value = 1
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "EdgeShoppingAssistantEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "PersonalizationReportingEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "HubsSidebarEnabled"
    Value = 0
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "EdgeCollectionsEnabled"
    Value = 0
}

# Setzen der Registry-Einträge im Benutzerkontext
foreach ($setting in $edge_settings) {
    $registry = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($setting.Path, $true)
    if ($registry -eq $null) {
        $registry = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($setting.Path, $true)
    }
    $registry.SetValue($setting.Name, $setting.Value)
    $registry.Dispose()
}
