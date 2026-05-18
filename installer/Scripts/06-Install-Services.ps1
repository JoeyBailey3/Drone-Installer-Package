# ============================================================================
# Install Windows Services via NSSM
# ----------------------------------------------------------------------------
# Wraps the headless backend services so they auto-start on boot:
#   - DroneAPI         (Node.js drone command API)
#   - MediaMTX         (stream relay)
#   - WSBroadcaster    (WebSocket MJPEG for iOS)
#
# Does NOT wrap scrcpy or the gdigrab FFmpeg — those need the Windows
# desktop session and must be started after login (via Task Scheduler in
# a separate script, or manually).
# ============================================================================

param(
    [string]$InstallPath = "C:\DroneServer"
)

$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

$nssm = Join-Path $InstallPath "bin\nssm\win64\nssm.exe"
if (-not (Test-Path $nssm)) {
    # Try alternate location
    $nssm = Join-Path $InstallPath "bin\nssm\nssm.exe"
}
if (-not (Test-Path $nssm)) {
    Write-Log "NSSM not found at $nssm" "ERROR"
    exit 1
}

# Resolve node.exe — assumes Node.js is installed in PATH
$node = (Get-Command node -ErrorAction SilentlyContinue).Source
if (-not $node) {
    Write-Log "node.exe not found in PATH. Install Node.js LTS first." "ERROR"
    exit 1
}

function Install-DroneService {
    param(
        [string]$Name,
        [string]$ExePath,
        [string]$Arguments,
        [string]$WorkingDir,
        [string]$DisplayName,
        [string]$Description
    )
    
    Write-Log "Installing service: $Name"
    
    # Remove if exists
    $existing = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($existing) {
        if ($existing.Status -eq "Running") {
            Write-Log "Stopping existing service $Name"
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        Write-Log "Removing existing service $Name"
        & $nssm remove $Name confirm | Out-Null
        Start-Sleep -Seconds 1
    }
    
    # Install
    & $nssm install $Name $ExePath $Arguments | Out-Null
    & $nssm set $Name AppDirectory $WorkingDir | Out-Null
    & $nssm set $Name DisplayName $DisplayName | Out-Null
    & $nssm set $Name Description $Description | Out-Null
    & $nssm set $Name Start SERVICE_AUTO_START | Out-Null
    
    # Log output
    $logDir = Join-Path $InstallPath "logs"
    if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
    & $nssm set $Name AppStdout (Join-Path $logDir "$Name-stdout.log") | Out-Null
    & $nssm set $Name AppStderr (Join-Path $logDir "$Name-stderr.log") | Out-Null
    & $nssm set $Name AppRotateFiles 1 | Out-Null
    & $nssm set $Name AppRotateBytes 10485760 | Out-Null  # 10 MB
    
    # Restart policy
    & $nssm set $Name AppExit Default Restart | Out-Null
    & $nssm set $Name AppRestartDelay 5000 | Out-Null  # 5 second delay between restarts
    
    Write-Log "Service $Name installed"
}

# ----- Drone API -----
Install-DroneService `
    -Name "DroneAPI" `
    -ExePath $node `
    -Arguments "server.js" `
    -WorkingDir (Join-Path $InstallPath "drone-api") `
    -DisplayName "DJI Drone Command API" `
    -Description "HTTP API for sending commands to DJI controller via ADB"

# ----- MediaMTX -----
$mediamtxExe = Join-Path $InstallPath "bin\mediamtx\mediamtx.exe"
$mediamtxDir = Join-Path $InstallPath "bin\mediamtx"
Install-DroneService `
    -Name "MediaMTX" `
    -ExePath $mediamtxExe `
    -Arguments "mediamtx.yml" `
    -WorkingDir $mediamtxDir `
    -DisplayName "DJI Drone MediaMTX Stream Relay" `
    -Description "RTSP/HLS/WebRTC stream relay server"

# ----- WebSocket Broadcaster -----
Install-DroneService `
    -Name "WSBroadcaster" `
    -ExePath $node `
    -Arguments "ws-broadcaster.js" `
    -WorkingDir (Join-Path $InstallPath "ws-broadcaster") `
    -DisplayName "DJI Drone WebSocket MJPEG Broadcaster" `
    -Description "WebSocket video streaming for iOS WKWebView compatibility"

Write-Log ""
Write-Log "All services installed. Starting them now..."

foreach ($svc in @("MediaMTX", "DroneAPI", "WSBroadcaster")) {
    try {
        Start-Service -Name $svc
        Write-Log "Started $svc" "OK"
    } catch {
        Write-Log "Failed to start ${svc}: $_" "ERROR"
    }
}

Write-Log ""
Write-Log "NOTE: scrcpy and FFmpeg capture must be started manually after login." "WARN"
Write-Log "Run DroneServerStart.bat from the desktop to start them." "WARN"
