Function InstallDatto {
$Platform="merlot"
$SiteID="606f312f-98da-4c31-9400-287eca4da446" 
If (Get-Service CagService -ErrorAction SilentlyContinue) {Write-Output "Datto RMM Agent already installed on this device" ; exit} 
# Download the Agent
$AgentURL="https://$Platform.centrastage.net/csm/profile/downloadAgent/$SiteID" 
$DownloadStart=Get-Date 
Write-Output "Starting Agent download at $(Get-Date -Format HH:mm) from $AgentURL"
try {[Net.ServicePointManager]::SecurityProtocol=[Enum]::ToObject([Net.SecurityProtocolType],3072)}
catch {Write-Output "Cannot download Agent due to invalid security protocol. The`r`nfollowing security protocols are installed and available:`r`n$([enum]::GetNames([Net.SecurityProtocolType]))`r`nAgent download requires at least TLS 1.2 to succeed.`r`nPlease install TLS 1.2 and rerun the script." ; exit 1}
try {(New-Object System.Net.WebClient).DownloadFile($AgentURL, "$env:TEMP\DRMMSetup.exe")} 
catch {$host.ui.WriteErrorLine("Agent installer download failed. Exit message:`r`n$_") ; exit 1} 
Write-Output "Agent download completed in $((Get-Date).Subtract($DownloadStart).Seconds) seconds`r`n`r`n" 
# Install the Agent
$InstallStart=Get-Date 
Write-Output "Starting Agent install to target site at $(Get-Date -Format HH:mm)..." 
& "$env:TEMP\DRMMSetup.exe" | Out-Null 
Write-Output "Agent install completed at $(Get-Date -Format HH:mm) in $((Get-Date).Subtract($InstallStart).Seconds) seconds."
Remove-Item "$env:TEMP\DRMMSetup.exe" -Force
}

Function Install-WinGet {
    #Install the latest package from GitHub
    [cmdletbinding(SupportsShouldProcess)]
    [alias("iwg")]
    [OutputType("None")]
    [OutputType("Microsoft.Windows.Appx.PackageManager.Commands.AppxPackage")]
    Param(
        [Parameter(HelpMessage = "Display the AppxPackage after installation.")]
        [switch]$Passthru
    )

    Write-Verbose "[$((Get-Date).TimeofDay)] Starting $($myinvocation.mycommand)"

    if ($PSVersionTable.PSVersion.Major -eq 7) {
        Write-Warning "This command does not work in PowerShell 7. You must install in Windows PowerShell."
        return
    }

    #test for requirement
    $Requirement = Get-AppPackage "Microsoft.DesktopAppInstaller"
    if (-Not $requirement) {
        Write-Verbose "Installing Desktop App Installer requirement"
        Try {
            Add-AppxPackage -Path "https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx" -erroraction Stop
        }
        Catch {
            Throw $_
        }
    }

    $uri = "https://api.github.com/repos/microsoft/winget-cli/releases"

    Try {
        Write-Verbose "[$((Get-Date).TimeofDay)] Getting information from $uri"
        $get = Invoke-RestMethod -uri $uri -Method Get -ErrorAction stop

        Write-Verbose "[$((Get-Date).TimeofDay)] getting latest release"
        #$data = $get | Select-Object -first 1
        $data = $get[0].assets | Where-Object name -Match 'msixbundle'

        $appx = $data.browser_download_url
        #$data.assets[0].browser_download_url
        Write-Verbose "[$((Get-Date).TimeofDay)] $appx"
        If ($pscmdlet.ShouldProcess($appx, "Downloading asset")) {
            $file = Join-Path -path $env:temp -ChildPath $data.name

            Write-Verbose "[$((Get-Date).TimeofDay)] Saving to $file"
            Invoke-WebRequest -Uri $appx -UseBasicParsing -DisableKeepAlive -OutFile $file

            Write-Verbose "[$((Get-Date).TimeofDay)] Adding Appx Package"
            Add-AppxPackage -Path $file -ErrorAction Stop

            if ($passthru) {
                Get-AppxPackage microsoft.desktopAppInstaller
            }
        }
    } #Try
    Catch {
        Write-Verbose "[$((Get-Date).TimeofDay)] There was an error."
        Throw $_
    }
    Write-Verbose "[$((Get-Date).TimeofDay)] Ending $($myinvocation.mycommand)"
}

Install-WinGet
winget install -e --id Mozilla.Firefox.ESR;winget install -e --id mcmilk.7zip-zstd;winget install -e --id Adobe.Acrobat.Reader.64-bit;winget install -e --id Google.Chrome --accept-package-agreements

InstallDatto

Write-Host "Restoring key"

$runOnceRegistryPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce"

# Set Windows Activation Key from UEFI
$licensingService = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService"
if ($key = $licensingService.OA3xOriginalProductKey) {
	Write-Host "Product Key: $licensingService.OA3xOriginalProductKey"
	$licensingService.InstallProductKey($key) | Out-Null
} else {
	Write-Host "Windows Activation Key not found."
}
