# Customer Install Guide

Step-by-step instructions for installing the DJI Drone Control4 Server at a customer site.

**Audience:** Field technician with basic Windows administration skills.

**Estimated time:** 30-45 minutes total (most is automated; you wait while it works).

---

## Before You Arrive at the Customer Site

### Required Information from Customer

Gather this in advance:

- [ ] Customer name and site address
- [ ] LAN network details:
  - Server's intended IP address
  - LAN subnet (e.g., 10.0.0.0/16 or 192.168.1.0/24)
- [ ] Drone home position (where the dock or launch point will be):
  - Latitude (decimal degrees, e.g., 40.7608)
  - Longitude (decimal degrees, e.g., -111.8910)
  - You can get these from Google Maps by right-clicking the location
- [ ] Geofence radius (how far drone can fly from home, default 500 meters)
- [ ] Control4 controller IP address (for driver configuration later)

### Required Hardware

- [ ] Windows server or always-on Windows PC (10/11 Pro or Windows Server)
- [ ] Minimum specs: 4 CPU cores, 8GB RAM, 50GB free disk
- [ ] DJI Matrice 4TD drone (or compatible)
- [ ] DJI RC Plus 2 controller
- [ ] DJI Dock 3 (or similar) — optional but recommended
- [ ] USB-C cable, ideally with 65W+ PD charger
- [ ] Ethernet cable for the server (not Wi-Fi)

### Required on Build Machine (Yours)

- [ ] Latest installer .exe (download from GitHub Releases)
- [ ] This install guide on a phone or laptop for reference

---

## Step 1 — Prepare the Server (5 min)

### 1.1 Install Node.js

The installer requires Node.js to be installed first.

1. On the customer's server, open a browser
2. Navigate to https://nodejs.org/
3. Download the **LTS** version (left download button, not "Current")
4. Run the installer
5. Accept all defaults
6. Reboot if prompted

Verify after install:
- Open PowerShell as administrator
- Run `node --version` — should show a version number like `v20.x.x`
- Run `npm --version` — should show a version number

If either command says "not recognized," the PATH didn't update. Try restarting PowerShell, or re-install Node.js.

### 1.2 Set Static IP (or DHCP Reservation)

The drone server needs a predictable IP address. Do ONE of:

**Option A — Static IP (recommended for dedicated server):**
1. Settings → Network → Ethernet → IP assignment → Edit
2. Switch to Manual, IPv4 on
3. Enter the IP, subnet mask, gateway, DNS
4. Save

**Option B — DHCP Reservation (in customer's router):**
- Log into the router, find DHCP reservations
- Add a reservation for this server's MAC address to the desired IP

Verify the server has the right IP by running `ipconfig` in PowerShell.

### 1.3 Disable Sleep / Lock

The server must stay running. Disable sleep:

1. Settings → System → Power → Sleep → Never (on AC)
2. Settings → System → Power → Screen → Never (on AC, optional but recommended)
3. Settings → Personalization → Lock screen → Screen saver → Wait time = never

Don't disable user logon — we want the server to auto-login (covered in step 1.4).

### 1.4 Configure Auto-Login (optional but recommended)

For the desktop pipeline components (scrcpy, FFmpeg capture) to auto-start, the server needs a logged-in user session.

1. Press Win+R, type `netplwiz`, Enter
2. Uncheck "Users must enter a user name and password"
3. Click Apply
4. Enter the admin password to confirm

This makes the server auto-login on reboot.

---

## Step 2 — Run the Installer (5 min)

### 2.1 Transfer the Installer

Get the `.exe` onto the customer's server. Options:
- USB drive
- Network share
- OneDrive / Google Drive
- Email yourself a link

### 2.2 Run as Administrator

1. Find the `.exe` in File Explorer
2. **Right-click → Run as administrator**
3. If Windows shows a UAC warning, click "Yes"
4. If antivirus warns, you may need to allow it (the installer is unsigned for now)

### 2.3 Click Through the Wizard

The installer has these screens. Read each carefully.

**Welcome screen** — click Next

**License agreement** — read, accept, click Next

**Pre-install notes** — review prerequisites, click Next

**Install location** — usually leave default (`C:\DroneServer`), click Next

**Components/Options** — these checkboxes:
- ☑ Create start menu shortcut — leave checked
- ☑ Create desktop shortcut — your preference
- ☑ Auto-start services on boot — **important, leave checked**
- ☑ Open required firewall ports — **important, leave checked**

Click Next.

**Customer Configuration screen** — enter:
- **Customer / Site Name:** descriptive name (used in INSTALL-INFO.txt only, doesn't have to match anything)
- **Server LAN IP:** the IP you set in Step 1.2 (e.g., `10.0.40.10`)
- **Allowed LAN Subnet:** e.g., `10.0.0.0/16` (whatever covers Control4 + phones)
- **API Key:** leave blank for auto-generated (recommended) OR paste a 32-char hex string

Click Next.

**Drone Base & Geofence screen** — enter:
- **Base Latitude:** customer's home GPS (e.g., `40.7608`)
- **Base Longitude:** customer's home GPS (e.g., `-111.8910`)
- **Geofence Radius:** in meters, default 500

Click Next.

**Ready to Install** screen — click Install

### 2.4 Wait for Installation

The installer will:
- Copy files (~2 minutes)
- Run npm install for both Node services (~2 minutes)
- Configure customer values
- Open firewall ports
- Install Windows services

Total: 5-10 minutes. **Don't close the installer.**

### 2.5 Post-install Notes

When complete, the wizard shows post-install instructions. Read them.

The verification script runs automatically and confirms everything installed correctly.

Click Finish.

---

## Step 3 — Get the API Key (1 min)

The installer wrote your API key to a file. You'll need this for the Control4 driver later.

1. Navigate to `C:\DroneServer\`
2. Open `INSTALL-INFO.txt` in Notepad
3. Note the API Key value
4. Also note the stream URLs (you'll need them for Control4)

**KEEP THIS FILE SECURE.** Anyone with the API key can control the drone.

---

## Step 4 — Connect the DJI Controller (5 min)

### 4.1 Power on the Controller

Turn on the DJI RC Plus 2. Wait for it to fully boot (Pilot 2 should be accessible).

### 4.2 Plug in USB-C Cable

Connect the controller to the server via USB-C. Use the controller's USB-C port (left side), not USB-A.

If you need power AND data, the USB-C port handles both. Use a 65W+ PD charger if running for long sessions.

### 4.3 Authorize ADB

On the controller's touchscreen, you should see a popup: "Allow USB debugging?"

- Tap **Always allow from this computer**
- Tap **OK**

If you don't see this popup:
- On the controller: Settings → About → tap Build Number 7 times to enable Developer Options
- Settings → Developer Options → enable USB Debugging
- Disconnect/reconnect the USB cable

### 4.4 Verify Connection

On the server, open PowerShell and run:

```powershell
C:\DroneServer\bin\platform-tools\adb.exe devices
```

You should see:
```
List of devices attached
ABC1234567890   device
```

The "device" status (not "unauthorized") means it's connected and ready.

### 4.5 Open DJI Pilot 2

On the controller's screen, open DJI Pilot 2. Navigate to the camera/flight view.

The screen should show the drone's camera feed (assuming drone is powered on and connected).

**Leave the controller's screen on Pilot 2 in flight view.**

---

## Step 5 — Start the Server Stack (3 min)

### 5.1 Start Desktop Components

The Windows services (DroneAPI, MediaMTX, WSBroadcaster) auto-start on boot.

The desktop-dependent parts (scrcpy, FFmpeg capture) need to be started manually.

On the server desktop, double-click **DJI Drone Server Start** (or run `C:\DroneServer\DroneServerStart.bat`).

This will:
1. Verify ADB sees the controller
2. Start scrcpy (mirrors the controller screen to a window called "DroneFeed")
3. Start FFmpeg capture (captures the DroneFeed window and publishes to MediaMTX)

### 5.2 Verify DroneFeed Window

A window titled "DroneFeed" should appear, showing the controller's screen.

**CRITICAL:** Do NOT minimize this window. Move it to a corner of the desktop if it's in the way, but it must stay visible. If minimized, the video pipeline breaks.

If the DroneFeed window doesn't appear:
- Check the scrcpy console for errors
- Verify ADB connection (`adb devices`)
- Make sure Pilot 2 is open on the controller

### 5.3 Verify FFmpeg is Capturing

In the FFmpeg console window, you should see `frame= 1`, `frame= 30`, `frame= 60`, etc. — counting up.

If FFmpeg shows `capturing 0x0` errors, the DroneFeed window is minimized. Restore it.

### 5.4 Run Health Check

Double-click **DJI Drone Server Health Check** (or run `C:\DroneServer\DroneServerHealthCheck.bat`).

This runs a full diagnostic. You should see:
- 5 processes running (scrcpy, ffmpeg, mediamtx, node x2)
- Services in `RUNNING` state
- ADB connection healthy
- Drone API returning `{"status":"ok"}`
- Source pipeline `ready: true`
- All ports listening

If anything fails, see TROUBLESHOOTING.md.

---

## Step 6 — Configure Control4 Driver (10 min)

This step depends on the customer's existing Control4 setup. General process:

1. Open **Composer Pro** on your laptop, connect to the customer's Control4 controller
2. Add the **Drone Delivery driver** (your .c4z) to the project
3. Open the driver's properties and configure:
   - **API URL:** `http://<server_ip>:3000` (e.g., `http://10.0.40.10:3000`)
   - **API Key:** copy from `INSTALL-INFO.txt`
   - **Video URL (MJPEG/WebSocket):** `ws://<server_ip>:8091`
   - **Video URL (HLS, backup):** `http://<server_ip>:8888/standard_clean/index.m3u8`
   - **Video URL (WebRTC, backup):** `http://<server_ip>:8889/standard_clean/whep`
   - **Base Latitude:** match what you entered in installer
   - **Base Longitude:** match what you entered in installer
4. Refresh Navigators / Push to Director
5. On customer's phone: force-quit Control4 app, reopen

---

## Step 7 — Verify End-to-End (5 min)

### 7.1 Video Test

On the customer's phone, in the Control4 app:
- Navigate to the drone tile
- Live video should appear within 2-3 seconds
- Video should be smooth (around 20fps)

### 7.2 Camera Switching Test

In the Control4 app, try each camera button:
- Wide / Standard
- Thermal / IR
- Zoom

Each click should switch the camera mode within 1 second. Watch the video feed to confirm it switches.

### 7.3 Other Buttons

Test:
- Smart Follow toggle
- Drop marker
- Rangefinder (if visible)

### 7.4 Multi-Viewer Test

Open Control4 on a second device (another phone or touchscreen). Both should show video simultaneously.

If video works on one but not the other, the WebSocket broadcaster may be having multi-viewer issues — check logs.

---

## Step 8 — Customer Handoff (5 min)

### 8.1 Demonstrate Functionality

Show the customer:
- Live drone view in Control4
- How to switch cameras
- How to use the buttons
- Server location and how to identify it

### 8.2 Document for the Customer

Leave on the server desktop (or print):
- Server IP address
- Phone numbers for support
- Brief "what to do if it stops working" guide

### 8.3 Backup the INSTALL-INFO.txt

Save a copy of `C:\DroneServer\INSTALL-INFO.txt` to:
- Your secure password manager
- A backup customer record file

If the customer's server dies and they need a reinstall, you'll need this info.

### 8.4 Document the GPS Coordinates

If customer wants patrol routes later, you'll need real GPS coordinates from the property. Walk the property, capture coords for each waypoint, and document for the customer's record.

---

## What's Working After Install

Customer has access to:

- ✅ Live drone video in Control4 (inline, no popup)
- ✅ Camera switching (wide / thermal / zoom)
- ✅ Smart Follow tracking
- ✅ Drop marker
- ✅ Rangefinder
- ✅ Multi-device viewing simultaneously

## What's NOT in v1.0

Be transparent with the customer:

- ❌ Software RTH button (use hardware button on controller)
- ❌ Software emergency land (use hardware button on controller)
- ❌ Autonomous patrols (planned for v2 with Cloud API)
- ❌ Telemetry display (battery, GPS — planned for v2)

---

## Troubleshooting Quick Reference

If something doesn't work, check these in order:

1. **DroneFeed window is visible** (not minimized)
2. **Health Check shows all green** (run the .bat file)
3. **ADB shows controller** (`adb devices`)
4. **Phone is on same LAN** as server
5. **Firewall is allowing ports** to phone's subnet

See `TROUBLESHOOTING.md` for detailed diagnostics.

---

## Action After Install

Update your customer database with:
- Customer name, install date
- Server IP and credentials
- Hardware serials (drone, controller, dock)
- Any custom configuration

This makes future support 10x easier.
