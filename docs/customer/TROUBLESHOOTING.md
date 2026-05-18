# Troubleshooting Guide

Common issues and how to fix them. Work top-down — earlier issues are more common.

## Quick Health Check

Always start here. Run on the server:

```powershell
C:\DroneServer\DroneServerHealthCheck.bat
```

This shows the state of all services. Find which one is broken, then jump to that section.

---

## Symptom: No video in Control4

### 1. Check if WebSocket broadcaster is alive

```powershell
netstat -an | findstr "LISTENING" | findstr ":8091"
```

Should show `TCP 0.0.0.0:8091 ... LISTENING`. If empty, the broadcaster is dead.

**Fix:**
```powershell
Start-Service WSBroadcaster
```

If that fails, check the log:
```powershell
Get-Content C:\DroneServer\logs\WSBroadcaster-stdout.log -Tail 50
```

### 2. Check if the video source is publishing

```powershell
curl.exe "http://localhost:9997/v3/paths/get/standard_clean"
```

Look for `"ready": true` and `bytesReceived` growing.

If `ready: false`:
- The scrcpy + FFmpeg capture chain is dead
- Run `C:\DroneServer\DroneServerStart.bat` to restart it

### 3. Check the DroneFeed window

It must be visible (not minimized). Restore it from the taskbar.

If gdigrab shows "capturing 0x0", the window is minimized.

### 4. Check from a browser (bypass Control4)

On the customer's Mac/PC, open browser to:
```
http://<server_ip>:8888/standard_clean/index.m3u8
```

(replace `<server_ip>` with actual IP)

If this works in browser but not Control4 → driver issue
If this doesn't work either → server/network issue

---

## Symptom: Camera switching doesn't work

### 1. Verify Drone API is alive

```powershell
curl.exe http://localhost:3000/health
```

Should return JSON. If timeout, restart:
```powershell
Restart-Service DroneAPI
```

### 2. Verify ADB sees the controller

```powershell
C:\DroneServer\bin\platform-tools\adb.exe devices
```

Should show device. If shows `unauthorized`, accept the prompt on the controller. If empty, replug USB.

### 3. Test the API directly

```powershell
$key = (Get-Content C:\DroneServer\drone-api\config.json | ConvertFrom-Json).apiKey
curl.exe -X POST -H "x-api-key: $key" http://localhost:3000/camera/thermal
```

Should return JSON with `ok: true`. Watch the controller — does it switch cameras?

**If yes:** Server works. Issue is Control4 driver wiring.
**If no:** Pilot 2 isn't reacting to the ADB tap. Common causes:
- Controller is on home screen, not Pilot 2
- Pilot 2 is in a menu/popup that blocks the camera button
- Drone isn't connected to controller

---

## Symptom: ADB shows "unauthorized" or empty

### Empty list

USB connection problem.

1. Unplug and replug USB-C cable
2. Try a different USB port on the server
3. Verify cable is data-capable (not charge-only)
4. On controller, check Settings → Developer Options → USB Debugging is ON

If still empty:
```powershell
.\adb.exe kill-server
.\adb.exe start-server
.\adb.exe devices
```

### "Unauthorized"

The RSA fingerprint popup wasn't accepted.

1. Look at the controller's screen for a popup
2. Tap **Always allow from this computer**
3. Tap OK
4. Re-run `adb devices`

If you accidentally tapped "Deny":
```powershell
.\adb.exe shell
exit
```
This forces a new fingerprint prompt.

---

## Symptom: Service won't start

### Check the service log

```powershell
$svc = "DroneAPI"   # or MediaMTX, or WSBroadcaster
Get-Content "C:\DroneServer\logs\$svc-stderr.log" -Tail 50
Get-Content "C:\DroneServer\logs\$svc-stdout.log" -Tail 50
```

The error message usually tells you what's wrong.

### Common service start failures

**"Cannot find module 'express'"** (DroneAPI)
→ npm install didn't run. Fix:
```powershell
cd C:\DroneServer\drone-api
npm install
Restart-Service DroneAPI
```

**"Cannot find module 'ws'"** (WSBroadcaster)
→ Same issue:
```powershell
cd C:\DroneServer\ws-broadcaster
npm install
Restart-Service WSBroadcaster
```

**"Port already in use"**
→ Another process has the port. Find it:
```powershell
netstat -ano | findstr ":3000"
```
The last column is the PID. Kill it:
```powershell
Stop-Process -Id <PID> -Force
```
Then restart the service.

**"Configuration file errors" / "Unexpected token"**
→ Config file has BOM or syntax error. Re-run customer configuration:
```powershell
powershell -ExecutionPolicy Bypass -File C:\DroneServer\scripts\04-Configure-Customer.ps1
```

---

## Symptom: DroneFeed window is black

### Cause: scrcpy using Direct3D renderer

scrcpy must use the `--render-driver=software` flag. The Start.bat script uses this, but if you ran scrcpy manually without the flag, it'll use Direct3D and the window will look fine but gdigrab can't capture it.

**Fix:** Stop scrcpy, restart with correct flag:
```powershell
Stop-Process -Name scrcpy -Force -ErrorAction SilentlyContinue
C:\DroneServer\bin\scrcpy\scrcpy.exe --no-audio -n --window-title "DroneFeed" --max-size 1920 --render-driver=software
```

---

## Symptom: gdigrab "Found window DroneFeed, capturing 0x0x32"

The DroneFeed window is minimized. Width and height are zero.

**Fix:**
1. Find DroneFeed in the taskbar
2. Click to restore
3. Move to a corner of the desktop
4. Don't minimize again

FFmpeg should automatically start capturing real frames once the window is visible.

---

## Symptom: Phone can't reach the server

### 1. Verify phone and server are on the same network

On phone, find current IP (Settings → Wi-Fi → tap your network → IP address).
Server IP is in `INSTALL-INFO.txt`.

Both should be on the same subnet (e.g., both 10.0.x.x).

If on different VLANs, the customer's network needs routing rules.

### 2. Verify firewall is allowing the phone's IP

```powershell
Get-NetFirewallRule -DisplayName "DroneServer*" | Format-Table DisplayName, Enabled, Action
```

All should show Enabled=True, Action=Allow.

If the phone is on a different subnet than configured, update the firewall rules:
```powershell
C:\DroneServer\scripts\02-Configure-Firewall.ps1
```

### 3. Test from phone with curl-equivalent

On iPhone Safari, try opening:
```
http://<server_ip>:3000/health
```

Should show JSON. If page won't load, network connectivity is broken between phone and server.

---

## Symptom: WebRTC laggy on phones (if using WebRTC instead of WebSocket)

The Control4 driver should be using WebSocket (`ws://<server>:8091`), not WebRTC.

If for some reason it's using WebRTC, the mobile jitter buffer needs tuning. The driver JavaScript should set:
```javascript
receiver.playoutDelayHint = 0;
receiver.jitterBufferTarget = 50;
```

If your driver doesn't do this, ask your driver developer to add it. Or switch to the WebSocket video path which doesn't have this issue.

---

## Symptom: After server reboot, nothing works

### What runs automatically on boot
- DroneAPI (Windows service)
- MediaMTX (Windows service)
- WSBroadcaster (Windows service)

### What does NOT auto-start
- scrcpy (needs desktop session)
- FFmpeg capture (needs DroneFeed window)
- ADB connection to controller (need to be physically reconnected if controller was off)

**After reboot, you must:**
1. Log in to the server (auto-login helps)
2. Run `DroneServerStart.bat` to launch scrcpy + FFmpeg
3. Verify with Health Check

To make this fully automatic, add `DroneServerStart.bat` to Windows startup folder:
```powershell
$startup = [Environment]::GetFolderPath('Startup')
Copy-Item C:\DroneServer\DroneServerStart.bat $startup
```

Now it'll run on every login.

---

## Symptom: Control4 app shows JS error in driver

### "stream.addEventListener is null"

Stale driver code. The customer's phone cached an old version of the driver HTML.

**Fix:**
1. Force-quit Control4 app
2. Settings → Apps → Control4 → Clear Cache (iOS may require app delete + reinstall)
3. Reopen Control4

If the error persists, the driver source itself has a bug. Contact your driver developer.

---

## Symptom: Antivirus flagging the installer

The installer .exe is unsigned, which triggers AV heuristics.

**Workarounds (for now, until you code-sign):**

1. **Add C:\DroneServer to AV exception list** before running installer
2. **Tell customer's IT to whitelist the installer hash**
3. **Right-click installer → Properties → Unblock** (if marked as downloaded from internet)

**Long-term fix:** Purchase a code signing certificate (~$200-500/year) and sign the .exe before distribution.

---

## When All Else Fails — Full Reset

If multiple things are broken and you can't pin it down:

```powershell
# Stop everything
Stop-Service DroneAPI -Force -ErrorAction SilentlyContinue
Stop-Service MediaMTX -Force -ErrorAction SilentlyContinue
Stop-Service WSBroadcaster -Force -ErrorAction SilentlyContinue
Get-Process scrcpy, ffmpeg -ErrorAction SilentlyContinue | Stop-Process -Force

# Reset ADB
C:\DroneServer\bin\platform-tools\adb.exe kill-server
C:\DroneServer\bin\platform-tools\adb.exe start-server
C:\DroneServer\bin\platform-tools\adb.exe devices

# Restart in sequence
Start-Service MediaMTX
Start-Sleep -Seconds 3
Start-Service DroneAPI
Start-Sleep -Seconds 2
Start-Service WSBroadcaster
Start-Sleep -Seconds 2
& C:\DroneServer\DroneServerStart.bat
```

Then run Health Check.

If still broken, escalate. Check service logs:
```powershell
ls C:\DroneServer\logs\
```

Email or share these logs with support.

---

## Reporting an Unfixable Issue

If you've worked through everything and can't fix it, collect:

1. **Health Check output** — full text from running the .bat
2. **Service logs** — `C:\DroneServer\logs\*.log` (last few hundred lines)
3. **Installer info** — `C:\DroneServer\INSTALL-INFO.txt` (REDACT THE API KEY)
4. **Customer environment**:
   - Server OS version
   - Network setup (single LAN, multiple VLANs)
   - Node.js version
   - Controller / drone serial numbers
5. **Steps to reproduce** the issue

Email all of this to support. We'll get back within 1 business day.
