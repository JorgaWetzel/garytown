# Skript zum Entfernen von Registry-Einstellungen für Microsoft Edge, die von einem vorherigen Skript gesetzt wurden.

$edge_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "PinBrowserEssentialsToolbarButton"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "ImportFavorites"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "ManagedSearchEngines"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "SplitScreenEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "HideFirstRunExperience"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "EdgeShoppingAssistantEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "PersonalizationReportingEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "HubsSidebarEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "EdgeCollectionsEnabled"
},
[PSCustomObject]@{ 
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "NewTabPageHideDefaultTopSites"
},
[PSCustomObject]@{ 
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "NewTabPageAllowedBackgroundTypes"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "NewTabPageAppLauncherEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge"
    Name  = "NewTabPageContentEnabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    Name  = "1"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
    Name  = "2"
}

# Entfernen der Registry-Einträge
foreach ($setting in $edge_settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
    if ($registry -ne $null) {
        $registry.DeleteValue($setting.Name, $false) 2>$null
        $registry.Dispose()
    }
}

# Entfernen leerer Registry-Schlüssel, wenn nötig
$policyPaths = @(
    "SOFTWARE\Policies\Microsoft\Edge",
    "SOFTWARE\Policies\Microsoft\Edge\ExtensionInstallForcelist"
)

foreach ($path in $policyPaths) {
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($path, $true)
    if ($key -ne $null -and $key.GetValueNames().Count -eq 0 -and $key.GetSubKeyNames().Count -eq 0) {
        [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKey($path, $false)
    }
}
