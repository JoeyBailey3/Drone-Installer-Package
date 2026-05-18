# Changelog

All notable changes to the Drone Installer Package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Planned
- Auto-update mechanism
- Code-signed installer
- Telemetry integration via DJI Cloud API
- Software RTH and Land via Cloud API
- Autonomous patrol mission execution

## [1.0.0] - 2026-05-18

### Added
- Initial release
- GitHub Actions build pipeline (auto-compile on tag push)
- Inno Setup installer with customer configuration wizard
- Drone Command API (port 3000) with 21 endpoints
- WebSocket MJPEG broadcaster for iOS WKWebView compatibility (port 8091)
- MediaMTX stream relay with HLS/RTSP/WebRTC outputs
- Windows service installation via NSSM (DroneAPI, MediaMTX, WSBroadcaster)
- Auto-start services on boot
- Firewall rule configuration scoped to customer LAN subnet
- Health check script
- Customer install guide
- Troubleshooting guide
- Release process documentation
- Patrol/goto endpoint stubs (ready for Cloud API integration)
- Geofencing validation for fly_to and patrol endpoints

### Known Issues
- Software RTH not available — must use hardware button on controller
- Software Land not available — must use hardware button on controller
- Autonomous flight commands return stub responses until Cloud API integration
- Installer is not code-signed — may trigger antivirus warnings
- Manual Node.js LTS installation required before running installer
- scrcpy + FFmpeg capture must be started after login (not service-wrapped)
