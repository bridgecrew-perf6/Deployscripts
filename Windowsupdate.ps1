# Install Nuget PackageProvider
if (-Not (Get-PackageProvider -Name NuGet)) {
    Write-Host "Install Nuget PackageProvider"
    Install-PackageProvider -Name NuGet -Confirm:$false -Force | Out-Null
}

Install-Module WingetTools -force
Import-Module WingetTools
Install-WinGet

winget install -e --id Mozilla.Firefox.ESR ---accept-package-agreements --accept-source-agreements --silent
winget install -e --id mcmilk.7zip-zstd --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Adobe.Acrobat.Reader.64-bit --accept-package-agreements --accept-source-agreements --silent
winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements --silent

# Install WindowsUpdate Module
if (-Not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Host "Install WindowsUpdate Module"
    Install-Module PSWindowsUpdate -Confirm:$false -Force | Out-Null
}

# Check is busy
while ((Get-WUInstallerStatus).IsBusy) {
    Write-Host "Windows Update installer is busy, wait..."
    Start-Sleep -s 10
}

# Install available Windows Updates
Write-Host "Start installation system updates..."
Write-Host "This job will be automatically canceled if it takes longer than 15 minutes to complete"
import-module pswindowsupdate
$updateJobTimeoutSeconds = 900

$code = {
    if ((Get-WindowsUpdate -Verbose).Count -gt 0) {
        try {
            $status = Get-WindowsUpdate -Install -AcceptAll -Confirm:$false
            if (($status | Where Result -eq "Installed").Length -gt 0)
            {
                Restart-Computer -Force
                return
            }
            
            if ((Test-PendingReboot).IsRebootPending) {
                Restart-Computer -Force
                return
            }
        } catch {
            Write-Host "Error:`r`n $_.Exception.Message"
            Restart-Computer -Force
        }
    }
}

$updateJob = Start-Job -ScriptBlock $code
if (Wait-Job $updateJob -Timeout $updateJobTimeoutSeconds) { 
    Receive-Job $updateJob
} else {
    Write-Host "Timeout exceeded"
    Receive-Job $updateJob
    Start-Sleep -s 10
}
Remove-Job -force $updateJob
