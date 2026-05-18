# Drone Installer Package

Build system for the DJI Drone + Control4 server installer.

## What this is

This repository contains everything needed to produce a Windows `.exe` installer that deploys the complete DJI drone + Control4 integration server stack to a customer's machine.

## Quick start

### To install at a customer site (techs)
- See [docs/customer/INSTALL-GUIDE.md](docs/customer/INSTALL-GUIDE.md)
- Download the latest .exe from [Releases](../../releases)

### To release a new version (developers)
- See [docs/internal/RELEASE-PROCESS.md](docs/internal/RELEASE-PROCESS.md)

### To compile locally (advanced)
- See [installer/Docs/BUILD-INSTRUCTIONS.md](installer/Docs/BUILD-INSTRUCTIONS.md)

## Architecture

```
This repo
   │
   │ git tag v1.0.0 + push
   ▼
GitHub Actions
   │  - downloads FFmpeg, scrcpy, ADB, MediaMTX, NSSM
   │  - installs Inno Setup on a Windows runner
   │  - compiles installer/InnoSetup/DroneServerSetup.iss
   ▼
DroneServer-Setup-v1.0.0.exe
   │
   │ tech downloads from GitHub Releases
   ▼
Customer's Windows server
   │  - wizard collects customer-specific values
   │  - deploys binaries + code to C:\DroneServer
   │  - installs Windows services with NSSM
   │  - configures firewall
   ▼
Working drone server
```

## Repository structure

```
.
├── .github/
│   └── workflows/
│       └── build-installer.yml      # GitHub Actions build pipeline
├── installer/
│   ├── InnoSetup/
│   │   └── DroneServerSetup.iss     # The Inno Setup script
│   ├── Scripts/                     # PowerShell + .bat scripts deployed by installer
│   ├── Configs/                     # Config file templates
│   ├── Code/
│   │   ├── drone-api/               # Node.js Drone Command API source
│   │   └── ws-broadcaster/          # WebSocket MJPEG broadcaster source
│   ├── Docs/                        # Docs deployed with the installer
│   └── Bin/                         # Bundled binaries (downloaded by CI, gitignored)
└── docs/
    ├── customer/                    # Customer-facing docs (install guide, troubleshooting)
    └── internal/                    # Developer docs (release process, architecture)
```

## What ships in the installer

The compiled `.exe` (~250-350 MB) contains:

- **Application code:**
  - Drone Command API (Node.js)
  - WebSocket MJPEG broadcaster (Node.js)
- **Bundled binaries:**
  - FFmpeg (Windows build)
  - scrcpy (Android screen mirror)
  - Android Platform Tools (ADB)
  - MediaMTX (RTSP/HLS/WebRTC relay)
  - NSSM (service wrapper)
- **Install logic:**
  - Customer configuration wizard
  - Firewall rules setup
  - Windows service installation
  - Health verification

## Versioning

Semantic versioning: `MAJOR.MINOR.PATCH`

See [CHANGELOG.md](CHANGELOG.md) for release history.

## Status

Current version: v1.0.0 (pre-release)

**Working in v1.0.0:**
- Live drone video in Control4 (WebSocket, iOS-compatible)
- Camera switching (wide / thermal / zoom)
- ADB-based command execution
- Multi-viewer video streaming
- Auto-start Windows services

**Not in v1.0.0 (planned for future):**
- Software RTH / Emergency Land (waiting on Cloud API integration)
- Autonomous patrol routes (waiting on Cloud API)
- Drone telemetry display (waiting on Cloud API)
- Code-signed installer (purchase needed)

## License

Proprietary. See [installer/Docs/LICENSE.txt](installer/Docs/LICENSE.txt).

This software bundles third-party open-source components (FFmpeg, scrcpy, MediaMTX, etc.) — each is governed by its own license. License files for bundled components are included with the installer.

## Related repositories

- `Drone-Control4-Integration` — the underlying source code (drone-api, ws-broadcaster, control panel, Control4 driver)
- This repo — the build pipeline that turns that source into a distributable installer
