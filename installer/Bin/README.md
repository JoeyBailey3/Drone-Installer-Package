# Binary Files Required

This folder is intentionally empty in the source. Before compiling the installer,
download these third-party binaries and place them in the matching subfolders:

## FFmpeg → Bin/ffmpeg/
Download "release essentials" Windows build from:
https://www.gyan.dev/ffmpeg/builds/

Extract so that Bin/ffmpeg/bin/ffmpeg.exe exists.

## scrcpy → Bin/scrcpy/
Latest Windows release from:
https://github.com/Genymobile/scrcpy/releases

Extract so that Bin/scrcpy/scrcpy.exe exists.

## Android Platform Tools (ADB) → Bin/platform-tools/
Download Windows zip from:
https://developer.android.com/tools/releases/platform-tools

Extract so that Bin/platform-tools/adb.exe exists.

## MediaMTX → Bin/mediamtx/
Windows AMD64 zip from:
https://github.com/bluenviron/mediamtx/releases

Extract so that Bin/mediamtx/mediamtx.exe exists.

## NSSM → Bin/nssm/
Download from https://nssm.cc/download (or https://github.com/kirillkovalenko/nssm if down)

Extract so that Bin/nssm/win64/nssm.exe exists.

After all binaries are in place, the installer can be compiled.
