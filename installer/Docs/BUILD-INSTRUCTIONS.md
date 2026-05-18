# Building the DJI Drone Server Installer

Step-by-step guide to compile the Inno Setup project into a redistributable `.exe` installer.

## What you'll produce

A single file: `DroneServer-Setup-v1.0.0.exe` (approximately 250-350 MB depending on binary sizes).

Customers run this on their server, click through the wizard, and have a fully configured drone server in 5-10 minutes.

## Prerequisites on YOUR build machine

You need these one-time installs on whatever computer you use to build the installer:

### 1. Inno Setup (the installer compiler)
- Download from: https://jrsoftware.org/isdl.php
- Get the latest stable (currently 6.x)
- Install with default options
- Takes 5 minutes

### 2. The binaries to bundle

You need to gather copies of all the third-party binaries we use. Put them in the `Bin/` folder of the installer project:

```
Bin/
├── ffmpeg/
│   ├── bin/
│   │   ├── ffmpeg.exe
│   │   ├── ffprobe.exe
│   │   └── ffplay.exe
│   └── (other ffmpeg files)
├── scrcpy/
│   ├── scrcpy.exe
│   ├── scrcpy-server
│   ├── adb.exe (scrcpy includes one)
│   └── (DLLs)
├── platform-tools/
│   ├── adb.exe
│   ├── AdbWinApi.dll
│   ├── AdbWinUsbApi.dll
│   └── (other platform-tools files)
├── mediamtx/
│   ├── mediamtx.exe
│   └── LICENSE
└── nssm/
    └── win64/
        └── nssm.exe
```

**Where to get them:**

| Tool | Download URL |
|---|---|
| FFmpeg (Windows, full build) | https://www.gyan.dev/ffmpeg/builds/ (get "release essentials") |
| scrcpy | https://github.com/Genymobile/scrcpy/releases |
| Android Platform Tools (ADB) | https://developer.android.com/tools/releases/platform-tools |
| MediaMTX | https://github.com/bluenviron/mediamtx/releases |
| NSSM | https://nssm.cc/download (or https://github.com/kirillkovalenko/nssm if main is down) |

Download each, extract, and copy the contents into the matching `Bin/` subfolder.

### 3. Your application code

Copy these from your working server into the `Code/` folder of the installer project:

```
Code/
├── drone-api/
│   ├── server.js          (the latest version)
│   ├── commands.json
│   ├── package.json
│   └── (DO NOT include node_modules — installer runs npm install)
└── ws-broadcaster/
    ├── ws-broadcaster.js
    ├── package.json
    └── (DO NOT include node_modules)
```

**Important:** Do NOT include `node_modules/` folders — the installer runs `npm install` after deploying, which downloads fresh deps. Including node_modules would bloat the installer and could include OS-specific compiled bits.

## The build process

### Step 1: Verify everything is in place

Your project folder should look like this:

```
DroneServerInstaller/
├── InnoSetup/
│   └── DroneServerSetup.iss          # The compiler script
├── Scripts/
│   ├── 02-Configure-Firewall.ps1
│   ├── 04-Configure-Customer.ps1
│   ├── 05-Test-Installation.ps1
│   ├── 06-Install-Services.ps1
│   ├── 99-Uninstall-Services.ps1
│   ├── DroneServerStart.bat
│   ├── DroneServerStop.bat
│   └── DroneServerHealthCheck.bat
├── Configs/
│   ├── mediamtx.yml.template
│   ├── config.json.template
│   └── patrols.json.template
├── Code/
│   ├── drone-api/
│   └── ws-broadcaster/
├── Bin/
│   ├── ffmpeg/
│   ├── scrcpy/
│   ├── platform-tools/
│   ├── mediamtx/
│   └── nssm/
└── Docs/
    ├── README.md
    ├── BEFORE.txt
    ├── AFTER.txt
    ├── LICENSE.txt
    ├── TROUBLESHOOTING.md
    └── PLAYBOOK.md
```

### Step 2: Open Inno Setup Compiler

- Start menu → Inno Setup → Inno Setup Compiler

### Step 3: Open the .iss script

- File → Open → navigate to `InnoSetup/DroneServerSetup.iss`

### Step 4: Compile

- Press **F9** (or Build → Compile)
- Watch the bottom panel for compile progress
- First compile takes 2-5 minutes (compressing all the bundled binaries)

### Step 5: Find your output

- After successful compile, look in `InnoSetup/Output/` 
- You'll find `DroneServer-Setup-v1.0.0.exe`
- That's your distributable installer

## Testing the installer

**Before sending to a customer**, test the installer on a fresh test environment:

1. **Set up a Windows VM** (Hyper-V, VMware, VirtualBox — anything)
2. Make sure the VM has:
   - Windows 10/11 Pro or Windows Server
   - Node.js LTS installed (https://nodejs.org)
   - At least 4GB RAM and 5GB free disk space
3. Copy your `.exe` to the VM
4. Run it as administrator
5. Click through the wizard:
   - Choose install path (default `C:\DroneServer`)
   - Enter test customer info (any values)
   - Enter test GPS coords (any valid lat/lon)
   - Let it install
6. After install, check:
   - `C:\DroneServer\` directory has all files
   - Services are installed (Get-Service DroneAPI, MediaMTX, WSBroadcaster)
   - `C:\DroneServer\INSTALL-INFO.txt` has the API key
   - Health check script runs without errors

If anything fails, fix it and recompile.

## Customer install workflow

What the customer (or your tech) does:

1. **Receive the installer .exe** (you email it, share via your file server, etc.)
2. **Right-click → Run as Administrator**
3. **Read the welcome screen, click Next**
4. **Choose install location** (usually leave default)
5. **Choose options:**
   - ☑ Create start menu shortcut
   - ☑ Auto-start services on boot
   - ☑ Open required firewall ports
6. **Enter customer info:**
   - Customer name (for reference)
   - Server LAN IP
   - LAN subnet
   - API key (leave blank for auto-generate)
7. **Enter GPS info:**
   - Drone base latitude / longitude
   - Geofence radius (default 500m)
8. **Click Install** — wait 3-5 minutes
9. **After install:** the wizard runs verification automatically
10. **Manual steps after install:**
    - Plug in the DJI controller via USB-C
    - Authorize ADB on the controller (RSA fingerprint popup)
    - Open `INSTALL-INFO.txt` for the API key
    - Configure Control4 driver with the API key and stream URLs
    - Reboot if needed (auto-services pick up on boot)

Real-world install time: 10-15 minutes per server.

## Versioning

When you update the installer, change the version:

In `DroneServerSetup.iss`, find:
```
#define MyAppVersion "1.0.0"
```

Bump it (e.g., `1.0.1`, `1.1.0`, etc.) before recompiling.

Use semantic versioning:
- **Patch (1.0.x)** — bug fixes, no breaking changes
- **Minor (1.x.0)** — new features, backward compatible
- **Major (x.0.0)** — breaking changes, customers need to know

## Common gotchas

### "Compile failed: source file not found"

Inno Setup couldn't find a file in `Bin/` or `Code/`. Check that all the binaries are actually present where the .iss expects them. The error message usually shows the exact path.

### "Node.js not found" on customer install

The installer assumes Node.js is already installed on the target server. Options:
1. Document Node.js as a prerequisite in BEFORE.txt
2. Bundle Node.js installer and run it as part of installation
3. Skip Node.js services and use pkg/nexe to compile your Node code into .exe (advanced)

Easiest: document as prereq for now.

### "Services won't start"

After install, check `C:\DroneServer\logs\` for stdout/stderr files. NSSM captures all output there. Usually reveals what's wrong.

### "scrcpy window won't appear"

scrcpy requires a logged-in user with desktop session. Auto-services can't show windows. The customer must run `DroneServerStart.bat` after login to start the desktop-session-dependent parts.

### "Antivirus flags the installer"

Inno Setup installers sometimes trigger antivirus heuristics. Solutions:
1. **Code sign the installer** (purchase a code signing certificate, ~$200-500/year)
2. **Submit to antivirus vendors for whitelisting** (free but slow)
3. **Document workarounds** for the most common AV that flags it

For internal use / B2B customers, this is usually a one-time exception they add. For mass distribution, code signing is required.

## What this installer does NOT handle

Document these in your customer playbook:

1. **Hardware setup** — plugging in the controller, USB cable selection, dock setup
2. **ADB authorization** — physical interaction with the controller
3. **DJI dock binding** — done in DJI Pilot 2, not the server
4. **Network configuration** — static IP, VLAN, routing
5. **Control4 driver deployment** — your assistant pushes this
6. **GPS waypoint mapping** — done manually by flying around the property

## Iterative improvement workflow

As you install at more customers and discover edge cases:

1. **Update the relevant script** in your project (Scripts/, Configs/, etc.)
2. **Bump the version** in the .iss
3. **Recompile** in Inno Setup
4. **Test** on the VM
5. **Distribute** the new .exe

Each customer install teaches you something. Roll that learning into the next version.

## Optional advanced features for v2

Things to consider adding once v1 is solid:

- **Update checker** — installer queries a URL for newer versions
- **Web-based status page** — customer can see system health in a browser
- **Customer config import** — load values from a `.json` file instead of typing
- **Multi-language support** — if you sell internationally
- **Code signing** — eliminates antivirus warnings
- **Customer dashboard** — separate web UI showing all customer installs

## Action

1. Set up your build machine with Inno Setup
2. Gather all the binaries
3. Test the build process end to end
4. Compile and test on a VM
5. When solid, you have a real product to ship

You're now in a position where each customer install is a 15-minute job, not a 3-day debugging session.
