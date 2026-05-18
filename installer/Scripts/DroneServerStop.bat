@echo off
REM ============================================================================
REM DJI Drone Server - Stop All Services
REM ============================================================================

setlocal

echo.
echo ====================================================================
echo   DJI Drone Server - Stopping
echo ====================================================================
echo.

echo Stopping desktop processes (scrcpy, FFmpeg)...
taskkill /F /IM scrcpy.exe 2>nul
taskkill /F /IM ffmpeg.exe 2>nul
echo.

echo Stopping Windows services...
net stop WSBroadcaster 2>nul
net stop DroneAPI 2>nul
net stop MediaMTX 2>nul
echo.

echo All services stopped.
echo.
pause
