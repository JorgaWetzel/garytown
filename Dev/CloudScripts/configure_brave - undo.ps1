# Skript zum Entfernen von Registry-Einstellungen für Brave, die von einem vorherigen Skript gesetzt wurden.

$brave_settings = 
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveRewardsDisabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveVPNDisabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "BraveWalletDisabled"
},
[PSCustomObject]@{
    Path  = "SOFTWARE\Policies\BraveSoftware\Brave"
    Name  = "TorDisabled"
}

# Entfernen der Registry-Einträge
foreach ($setting in $brave_settings) {
    $registry = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($setting.Path, $true)
    if ($registry -ne $null) {
        $registry.DeleteValue($setting.Name, $false) 2>$null
        $registry.Dispose()
    }
}

# Entfernen leerer Registry-Schlüssel, wenn nötig
$policyPath = "SOFTWARE\Policies\BraveSoftware\Brave"
$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($policyPath, $true)
if ($key -ne $null -and $key.GetValueNames().Count -eq 0 -and $key.GetSubKeyNames().Count -eq 0) {
    [Microsoft.Win32.Registry]::LocalMachine.DeleteSubKey($policyPath, $false)
}
