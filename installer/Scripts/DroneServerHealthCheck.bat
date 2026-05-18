@echo off
REM ============================================================================
REM DJI Drone Server - Health Check
REM ============================================================================

setlocal
set INSTALL_DIR=%~dp0

echo.
echo ====================================================================
echo   DJI Drone Server - Health Check
echo ====================================================================
echo.

echo --- Process Check ---
powershell -Command "Get-Process scrcpy, ffmpeg, mediamtx, node -ErrorAction SilentlyContinue | Format-Table Id, ProcessName, CPU -AutoSize"

echo --- Service Status ---
sc query DroneAPI | findstr STATE
sc query MediaMTX | findstr STATE
sc query WSBroadcaster | findstr STATE
echo.

echo --- ADB Connection ---
"%INSTALL_DIR%bin\platform-tools\adb.exe" devices
echo.

echo --- Drone API Health ---
curl -s http://localhost:3000/health
echo.
echo.

echo --- Video Source ---
curl -s "http://localhost:9997/v3/paths/get/standard_clean"
echo.
echo.

echo --- Listening Ports ---
netstat -an | findstr "LISTENING" | findstr ":3000 :8091 :8554 :8888 :8889 :9997"

echo.
pause
