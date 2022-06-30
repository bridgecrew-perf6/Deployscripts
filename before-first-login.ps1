Function InstallDatto {
$Platform="merlot"
$SiteID="4e21349e-7e6c-4ef2-a019-9549adfd2687" 
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
Set-ExecutionPolicy -Force -ExecutionPolicy unrestricted
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module WingetTools -force
Import-Module WingetTools
Install-WinGet

winget install -e --id Mozilla.Firefox.ESR ---accept-package-agreements --accept-source-agreements --silent
winget install -e --id mcmilk.7zip-zstd --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements --silent

InstallDatto

Write-Host "Restoring key"
# Set Windows Activation Key from UEFI
$licensingService = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService"
if ($key = $licensingService.OA3xOriginalProductKey) {
	Write-Host "Product Key: $licensingService.OA3xOriginalProductKey"
	$licensingService.InstallProductKey($key) | Out-Null
} else {
	Write-Host "Windows Activation Key not found."
}
