# ============================================================================
# Verify Installation
# ----------------------------------------------------------------------------
# Sanity-checks the install by verifying all expected files exist.
# Does not test functionality - just file presence.
# ============================================================================

param(
    [string]$InstallPath = "C:\DroneServer"
)

$ErrorActionPreference = "Continue"
$errors = 0

function Test-RequiredFile {
    param([string]$Path, [string]$Description)
    if (Test-Path $Path) {
        Write-Host "  [OK]   $Description" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Description ($Path)" -ForegroundColor Red
        $script:errors++
    }
}

Write-Host ""
Write-Host "Verifying installation at: $InstallPath" -ForegroundColor Cyan
Write-Host ""

Write-Host "Checking binaries..."
Test-RequiredFile (Join-Path $InstallPath "bin\ffmpeg\bin\ffmpeg.exe") "FFmpeg"
Test-RequiredFile (Join-Path $InstallPath "bin\scrcpy\scrcpy.exe") "scrcpy"
Test-RequiredFile (Join-Path $InstallPath "bin\platform-tools\adb.exe") "ADB"
Test-RequiredFile (Join-Path $InstallPath "bin\mediamtx\mediamtx.exe") "MediaMTX"

Write-Host ""
Write-Host "Checking application code..."
Test-RequiredFile (Join-Path $InstallPath "drone-api\server.js") "Drone API server.js"
Test-RequiredFile (Join-Path $InstallPath "drone-api\package.json") "Drone API package.json"
Test-RequiredFile (Join-Path $InstallPath "drone-api\config.json") "Drone API config.json"
Test-RequiredFile (Join-Path $InstallPath "drone-api\commands.json") "Drone API commands.json"
Test-RequiredFile (Join-Path $InstallPath "ws-broadcaster\ws-broadcaster.js") "WebSocket broadcaster"
Test-RequiredFile (Join-Path $InstallPath "ws-broadcaster\package.json") "WS broadcaster package.json"

Write-Host ""
Write-Host "Checking dependencies..."
Test-RequiredFile (Join-Path $InstallPath "drone-api\node_modules") "Drone API node_modules"
Test-RequiredFile (Join-Path $InstallPath "ws-broadcaster\node_modules") "WS broadcaster node_modules"

Write-Host ""
Write-Host "Checking configuration..."
Test-RequiredFile (Join-Path $InstallPath "bin\mediamtx\mediamtx.yml") "MediaMTX config"
Test-RequiredFile (Join-Path $InstallPath "customer-config.ini") "Customer config"

Write-Host ""
Write-Host "Checking startup scripts..."
Test-RequiredFile (Join-Path $InstallPath "DroneServerStart.bat") "Start script"
Test-RequiredFile (Join-Path $InstallPath "DroneServerStop.bat") "Stop script"
Test-RequiredFile (Join-Path $InstallPath "DroneServerHealthCheck.bat") "Health check script"

Write-Host ""
if ($errors -eq 0) {
    Write-Host "Installation verification PASSED" -ForegroundColor Green
} else {
    Write-Host "Installation verification FAILED ($errors issues)" -ForegroundColor Red
}
Write-Host ""
