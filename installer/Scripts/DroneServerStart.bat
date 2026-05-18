@echo off
REM ============================================================================
REM DJI Drone Server - Start All Services
REM ----------------------------------------------------------------------------
REM Starts the complete server stack. Use this after login to bring everything
REM online. The Windows services (DroneAPI, MediaMTX, WSBroadcaster) should
REM already be running if installed with auto-start. This script handles the
REM desktop-session-dependent parts (scrcpy + FFmpeg capture).
REM ============================================================================

setlocal
set INSTALL_DIR=%~dp0

echo.
echo ====================================================================
echo   DJI Drone Server - Starting
echo ====================================================================
echo.

REM Step 1: Verify ADB connection
echo [1/4] Verifying ADB connection to drone controller...
"%INSTALL_DIR%bin\platform-tools\adb.exe" devices
if errorlevel 1 (
    echo ERROR: ADB failed. Is the controller plugged in and authorized?
    pause
    exit /b 1
)
"%INSTALL_DIR%bin\platform-tools\adb.exe" shell svc power stayon true
echo.

REM Step 2: Start backend services (in case any are stopped)
echo [2/4] Starting backend Windows services...
net start DroneAPI >nul 2>&1
net start MediaMTX >nul 2>&1
net start WSBroadcaster >nul 2>&1
echo Backend services started (or already running).
echo.

REM Step 3: Start scrcpy
echo [3/4] Starting scrcpy controller mirror...
start "Drone Controller Mirror" "%INSTALL_DIR%bin\scrcpy\scrcpy.exe" --no-audio -n --window-title "DroneFeed" --max-size 1920 --render-driver=software
timeout /t 5 /nobreak >nul
echo scrcpy started. Make sure DroneFeed window is visible (not minimized).
echo.

REM Step 4: Start FFmpeg capture
echo [4/4] Starting FFmpeg video capture pipeline...
start "Drone FFmpeg Capture" "%INSTALL_DIR%bin\ffmpeg\bin\ffmpeg.exe" -f gdigrab -framerate 30 -i title=DroneFeed -c:v libx264 -profile:v baseline -level 3.1 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 30 -keyint_min 30 -bf 0 -sc_threshold 0 -refs 1 -x264opts no-scenecut -f rtsp -rtsp_transport tcp rtsp://localhost:8554/standard_clean
timeout /t 3 /nobreak >nul

echo.
echo ====================================================================
echo   Startup complete
echo ====================================================================
echo.
echo Backend services running:
echo   - DroneAPI         (port 3000)
echo   - MediaMTX         (ports 8554/8888/8889/9997)
echo   - WSBroadcaster    (port 8091)
echo.
echo Desktop pipeline:
echo   - scrcpy           (DroneFeed window)
echo   - FFmpeg capture   (publishing to MediaMTX)
echo.
echo IMPORTANT: Keep the scrcpy and FFmpeg windows open and visible.
echo            Do not minimize the DroneFeed window.
echo.
echo Run DroneServerHealthCheck.bat to verify everything is healthy.
echo.
pause
