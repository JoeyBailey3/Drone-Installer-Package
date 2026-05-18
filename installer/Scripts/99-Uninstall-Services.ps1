# ============================================================================
# Uninstall Windows Services
# ----------------------------------------------------------------------------
# Stops and removes all DJI Drone Server services. Called by the uninstaller.
# ============================================================================

param(
    [string]$InstallPath = "C:\DroneServer"
)

function Write-Log {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] $Message"
}

$nssm = Join-Path $InstallPath "bin\nssm\win64\nssm.exe"
if (-not (Test-Path $nssm)) {
    $nssm = Join-Path $InstallPath "bin\nssm\nssm.exe"
}

$services = @("DroneAPI", "MediaMTX", "WSBroadcaster")

foreach ($svc in $services) {
    $service = Get-Service -Name $svc -ErrorAction SilentlyContinue
    if ($service) {
        Write-Log "Stopping $svc"
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
        
        if (Test-Path $nssm) {
            Write-Log "Removing $svc"
            & $nssm remove $svc confirm 2>&1 | Out-Null
        } else {
            # Fallback if NSSM is already gone
            sc.exe delete $svc | Out-Null
        }
    }
}

Write-Log "Service uninstall complete"
