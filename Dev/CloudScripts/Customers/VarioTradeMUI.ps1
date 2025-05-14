# 99-Deployment.ps1  –  StartNet-Hook, minimal

Import-Module OSD -Force

Write-Host -ForegroundColor DarkGray "$((Get-Date).ToString('yyyy-MM-dd-HHmmss')) " -NoNewline
Write-Host -ForegroundColor Green "PSCloudScript at functions.osdcloud.com"
Invoke-Expression (Invoke-RestMethod -Uri functions.osdcloud.com)

iex (irm functions.garytown.com) #Add custom functions used in Script Hosting in GitHub
iex (irm functions.osdcloud.com) #Add custom fucntions from OSDCloud

#Transport Layer Security (TLS) 1.2
Write-Host -ForegroundColor Green "Transport Layer Security (TLS) 1.2"
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
#[System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials

#================================================
#   [PreOS] Update Module
#================================================
if ((Get-MyComputerModel) -match 'Virtual') {
    Write-Host  -ForegroundColor Green "Setting Display Resolution to 1600x"
    Set-DisRes 1600
}

# ======================================================================
# Konfiguration – HIER NUR BEI BEDARF ANPASSEN
# ======================================================================
$DeployShare = '\\10.10.100.100\Daten'          # UNC-Pfad zum Deployment-Share
$MapDrive    = 'Z'                              # gewünschter Laufwerks­buchstabe
$UserName    = 'Jorga'                          # Domänen- oder lokaler User
$PlainPwd    = 'Dont4getme'                     # Passwort (Klartext)


#$DeployShare = '\\192.168.2.15\DeploymentShare$' # UNC-Pfad zum Deployment-Share
#$MapDrive    = 'Z'                               # gewünschter Laufwerks­buchstabe
#$UserName    = 'VARIODEPLOY\Administrator'       # Domänen- oder lokaler User
#$PlainPwd    = '12Monate'                        # Passwort (Klartext)

$SrcWim 	 = 'Z:\OSDCloud\OS\Win11_24H2_MUI.wim'

# Anmelde­daten vorbereiten
$SecurePwd = ConvertTo-SecureString $PlainPwd -AsPlainText -Force
$Cred      = New-Object System.Management.Automation.PSCredential ($UserName,$SecurePwd)

# Share verbinden
if (-not (Get-PSDrive -Name $MapDrive -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $MapDrive `
                -PSProvider FileSystem `
                -Root $DeployShare `
                -Credential $Cred `
                -ErrorAction Stop
}


# --- OSDCloud-Variablen setzen ----------------------------------------
$Global:MyOSDCloud = @{
    ImageFileFullName = $SrcWim
    ImageFileItem     = Get-Item $SrcWim
    ImageFileName     = 'Win11_24H2_MUI.wim'
    OSImageIndex      = 5   
    ClearDiskConfirm  = $false
    ZTI               = $true
	Firmware          = $false
    UpdateOS          = $false     
    UpdateDrivers     = $false      
}


# -------------------------------------------------
# HP section one compact block
# -------------------------------------------------
if ($cs.Manufacturer -match 'HP') {

    # --- OSDCloud flags ---------------------------------
    $Global:MyOSDCloud.HPCMSLDriverPackLatest = $true  # auto-download SoftPaq
    $Global:MyOSDCloud.HPTPMUpdate            = $true  # TPM firmware update
    $Global:MyOSDCloud.HPBIOSUpdate           = $true  # BIOS update
    $Global:MyOSDCloud.HPIAALL                = $true  # run HPIA –ALL

    Write-Host 'HP CMSL auto driver pack (latest) enabled.' -fg Green

    # --- optional BIOS setting script -------------------
    try {
        Invoke-WebRequest `
            -Uri 'https://raw.githubusercontent.com/gwblok/garytown/master/OSD/CloudOSD/Manage-HPBiosSettings.ps1' `
            -UseBasicParsing -OutFile "$env:TEMP\Manage-HPBiosSettings.ps1"
        . "$env:TEMP\Manage-HPBiosSettings.ps1"
        Manage-HPBiosSettings -SetSettings
        Write-Host 'HP BIOS settings applied.' -fg Green
    }
    catch {
        Write-Warning "Manage-HPBiosSettings could not run: $_"
    }
}
#write variables to console
Write-Output $Global:MyOSDCloud


# --- Deployment ---------------------------------------------
Invoke-OSDCloud

Initialize-OSDCloudStartnetUpdate
Restart-Computer -Force
