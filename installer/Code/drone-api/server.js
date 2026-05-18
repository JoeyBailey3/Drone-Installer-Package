// ============================================================================
// Drone API Service v1.4
// ----------------------------------------------------------------------------
// Bridges Control4 (and any HTTP client) to the DJI RC Plus 2 controller via
// ADB, which in turn commands the Matrice 4TD drone through DJI Pilot 2.
//
// v1.4 adds:
//   - /drone/patrol/start[/:name] — runs a pre-defined patrol route (stub)
//   - /drone/patrol/stop          — aborts active patrol (stub)
//   - /drone/patrol/status        — current patrol state
//   - /drone/patrol/list          — available patrol routes
//   - /drone/goto/:location       — hover at a named location (stub)
//   - /drone/locations            — list named locations
//   - patrols.json config file for routes & locations
//
// v1.3 added:
//   - /drone/fly_to — accepts lat/lon, validates geofence, logs request
//                     (stubbed for actual flight execution until Cloud API)
//   - Geofencing utilities (haversine distance, range check)
// ============================================================================

const express = require('express');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));
const commands = JSON.parse(fs.readFileSync(path.join(__dirname, 'commands.json'), 'utf8'));

const logFile = path.join(__dirname, 'drone-api.log');
function log(level, msg, extra = null) {
  const line = `[${new Date().toISOString()}] [${level}] ${msg}${extra ? ' ' + JSON.stringify(extra) : ''}`;
  console.log(line);
  fs.appendFileSync(logFile, line + '\n');
}

let adbBusy = false;
const adbQueue = [];

function runAdb(args, retries = 1) {
  return new Promise((resolve, reject) => {
    const job = () => {
      adbBusy = true;
      const cmd = `"${config.adbPath}" ${args}`;
      log('DEBUG', 'adb', { cmd });
      exec(cmd, { timeout: config.adbTimeoutMs }, (err, stdout, stderr) => {
        adbBusy = false;
        if (adbQueue.length > 0) {
          const next = adbQueue.shift();
          setImmediate(next);
        }
        if (err) {
          log('ERROR', 'adb command failed', { cmd, stderr: stderr?.trim(), err: err.message });
          if (retries > 0) {
            log('INFO', 'retrying after kill-server/start-server');
            exec(`"${config.adbPath}" kill-server`, () => {
              exec(`"${config.adbPath}" start-server`, () => {
                runAdb(args, retries - 1).then(resolve).catch(reject);
              });
            });
          } else {
            reject(stderr?.trim() || err.message);
          }
          return;
        }
        resolve(stdout);
      });
    };
    if (adbBusy) {
      adbQueue.push(job);
    } else {
      job();
    }
  });
}

const app = express();
app.use(express.json());

// CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, x-api-key');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.use((req, res, next) => {
  log('INFO', `${req.method} ${req.path}`, { ip: req.ip });
  next();
});

app.use((req, res, next) => {
  if (req.path === '/health') return next();
  const key = req.headers['x-api-key'];
  if (key !== config.apiKey) {
    log('WARN', 'auth failed', { ip: req.ip, path: req.path });
    return res.status(401).json({ error: 'unauthorized' });
  }
  next();
});

async function executeCommand(res, commandKey) {
  const cmd = commands[commandKey];
  if (!cmd) return res.status(404).json({ ok: false, error: `unknown command: ${commandKey}` });
  try {
    await runAdb(cmd.adb);
    log('INFO', `executed: ${commandKey}`, { description: cmd.description });
    res.json({ ok: true, command: commandKey, description: cmd.description });
  } catch (e) {
    log('ERROR', `failed: ${commandKey}`, { error: e });
    res.status(500).json({ ok: false, command: commandKey, error: String(e) });
  }
}

// Health & discovery
app.get('/health', async (req, res) => {
  try {
    const out = await runAdb('devices');
    const lines = out.split('\n').filter(l => l.trim() && !l.startsWith('List'));
    const connected = lines.length > 0 && lines.some(l => l.includes('device'));
    res.json({
      status: connected ? 'ok' : 'no_device',
      controllerConnected: connected,
      adbOutput: out.trim(),
      uptime: process.uptime(),
    });
  } catch (e) {
    res.status(500).json({ status: 'error', error: String(e) });
  }
});

app.get('/commands', (req, res) => {
  const list = Object.entries(commands).map(([key, val]) => ({
    key,
    description: val.description,
    endpoint: `POST /command/${key}`,
  }));
  res.json({ commands: list });
});

// Camera endpoints — Control4-driver-friendly URLs
app.post('/camera/thermal',  (req, res) => executeCommand(res, 'thermal'));
app.post('/camera/standard', (req, res) => executeCommand(res, 'standard'));
app.post('/camera/wide',     (req, res) => executeCommand(res, 'standard'));
app.post('/camera/zoom',     (req, res) => executeCommand(res, 'zoom'));
app.post('/camera/range',    (req, res) => executeCommand(res, 'range'));
app.post('/camera/:mode',    (req, res) => executeCommand(res, req.params.mode));

// Generic + legacy aliases
app.post('/command/:key',    (req, res) => executeCommand(res, req.params.key));
app.post('/button/l1',       (req, res) => executeCommand(res, 'thermal'));
app.post('/button/l2',       (req, res) => executeCommand(res, 'zoom'));
app.post('/button/l3',       (req, res) => executeCommand(res, 'drop_marker'));
app.post('/button/r1',       (req, res) => executeCommand(res, 'r1'));
app.post('/button/r2',       (req, res) => executeCommand(res, 'r2'));
app.post('/button/r3',       (req, res) => executeCommand(res, 'r3'));

// Flight controls
app.post('/drone/rth',       (req, res) => executeCommand(res, 'rth'));
app.post('/drone/land',      (req, res) => executeCommand(res, 'land'));
app.post('/drone/home',      (req, res) => executeCommand(res, 'home_button'));
app.post('/land',            (req, res) => executeCommand(res, 'land'));
app.post('/recall',          (req, res) => executeCommand(res, 'rth'));
app.post('/return_to_base',  (req, res) => executeCommand(res, 'rth'));

// ----------------------------------------------------------------------------
// Fly-to-coordinate ("come to me") endpoint
// ----------------------------------------------------------------------------
// Accepts a user's GPS coordinates and validates them against a geofence.
// Currently logs the request and returns ETA — flight execution is stubbed
// pending DJI Cloud API integration.
//
// Configuration lives in config.json under "flyToConfig":
//   baseLat, baseLon          — drone home/dock coordinates
//   maxRangeMeters            — max distance from base allowed
//   droneSpeedMps             — cruise speed for ETA calculation
//   startupOverheadSec        — seconds added to ETA for takeoff/spinup
//   requireAccuracyMeters     — optional max GPS accuracy (null = any)
//
// Falls back to driver-property-style defaults if config missing.

const flyToCfg = config.flyToConfig || {};
const FLY_BASE_LAT          = flyToCfg.baseLat            ?? 40.7608;
const FLY_BASE_LON          = flyToCfg.baseLon            ?? -111.8910;
const FLY_MAX_RANGE_METERS  = flyToCfg.maxRangeMeters     ?? 500;
const FLY_SPEED_MPS         = flyToCfg.droneSpeedMps      ?? 10;
const FLY_STARTUP_SEC       = flyToCfg.startupOverheadSec ?? 10;
const FLY_MAX_GPS_ACCURACY  = flyToCfg.requireAccuracyMeters ?? null;

function haversineMeters(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth radius in meters
  const toRad = (d) => d * Math.PI / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

app.post('/drone/fly_to', (req, res) => {
  const { lat, lon, accuracy } = req.body || {};

  // Validate types
  if (typeof lat !== 'number' || typeof lon !== 'number' || !isFinite(lat) || !isFinite(lon)) {
    log('WARN', 'fly_to bad request', { body: req.body });
    return res.status(400).json({
      ok: false,
      error: 'lat and lon required as finite numbers',
    });
  }

  // Validate ranges
  if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
    return res.status(400).json({
      ok: false,
      error: 'coordinates out of valid range (-90..90 lat, -180..180 lon)',
    });
  }

  // Optional accuracy check — reject coords with very poor GPS fix
  if (FLY_MAX_GPS_ACCURACY != null && typeof accuracy === 'number' && accuracy > FLY_MAX_GPS_ACCURACY) {
    return res.status(400).json({
      ok: false,
      error: `GPS accuracy too poor (${Math.round(accuracy)}m, max allowed ${FLY_MAX_GPS_ACCURACY}m)`,
    });
  }

  // Geofence check
  const distance = haversineMeters(FLY_BASE_LAT, FLY_BASE_LON, lat, lon);
  if (distance > FLY_MAX_RANGE_METERS) {
    log('WARN', 'fly_to outside geofence', {
      requested: { lat, lon },
      distanceMeters: Math.round(distance),
      maxMeters: FLY_MAX_RANGE_METERS,
    });
    return res.status(403).json({
      ok: false,
      error: `requested location is ${Math.round(distance)}m from base, exceeds ${FLY_MAX_RANGE_METERS}m flight area`,
      distanceMeters: Math.round(distance),
      maxMeters: FLY_MAX_RANGE_METERS,
    });
  }

  // Compute ETA
  const etaSeconds = Math.round(distance / FLY_SPEED_MPS) + FLY_STARTUP_SEC;

  log('INFO', 'fly_to request accepted (stub)', {
    lat, lon,
    accuracy: accuracy ?? null,
    distanceMeters: Math.round(distance),
    etaSeconds,
  });

  // STUB: this is where DJI Cloud API would receive the mission
  // For now we just return acknowledgment so the UI can show "drone enroute"
  res.json({
    ok: true,
    accepted: true,
    stub: true,
    message: 'Mission queued (stub — Cloud API integration pending)',
    destination: { lat, lon },
    distanceMeters: Math.round(distance),
    etaSeconds,
    base: { lat: FLY_BASE_LAT, lon: FLY_BASE_LON },
  });
});

// Quick GET to check geofence/config without sending a mission
app.get('/drone/fly_to/info', (req, res) => {
  res.json({
    base: { lat: FLY_BASE_LAT, lon: FLY_BASE_LON },
    maxRangeMeters: FLY_MAX_RANGE_METERS,
    droneSpeedMps: FLY_SPEED_MPS,
    startupOverheadSec: FLY_STARTUP_SEC,
    requireAccuracyMeters: FLY_MAX_GPS_ACCURACY,
    implemented: false,
    note: 'fly_to currently logs and validates only. Drone movement requires Cloud API integration.',
  });
});

// ----------------------------------------------------------------------------
// Patrol & Named Location endpoints
// ----------------------------------------------------------------------------
// Patrols run pre-defined routes with multiple waypoints in sequence.
// Locations are single-destination hover-and-watch.
// Both endpoints are currently STUBS — they validate, log, and queue requests
// but don't actually fly the drone. Real flight execution requires DJI Cloud
// API integration (planned, separate project).
//
// Configuration: patrols.json next to config.json. See patrols.json.example.

let patrolsConfig = { patrols: {}, locations: {} };
const patrolsPath = path.join(__dirname, 'patrols.json');
try {
  patrolsConfig = JSON.parse(fs.readFileSync(patrolsPath, 'utf8'));
  const pCount = Object.keys(patrolsConfig.patrols || {}).length;
  const lCount = Object.keys(patrolsConfig.locations || {}).length;
  log('INFO', 'patrols.json loaded', { patrols: pCount, locations: lCount });
} catch (e) {
  log('WARN', 'patrols.json not loaded — patrol endpoints will return 404', { error: e.message });
}

// In-memory state: track if a patrol is "active" (for stub concurrency check)
let activePatrol = null; // { name, startedAt, waypointCount, etaSec }

function validateWaypointGeofence(wp) {
  if (typeof wp.lat !== 'number' || typeof wp.lon !== 'number') {
    return { ok: false, error: `waypoint "${wp.name}" missing lat/lon` };
  }
  const dist = haversineMeters(FLY_BASE_LAT, FLY_BASE_LON, wp.lat, wp.lon);
  if (dist > FLY_MAX_RANGE_METERS) {
    return {
      ok: false,
      error: `waypoint "${wp.name}" is ${Math.round(dist)}m from base, exceeds ${FLY_MAX_RANGE_METERS}m`,
    };
  }
  return { ok: true, distance: dist };
}

function calculatePatrolEta(waypoints) {
  let total = FLY_STARTUP_SEC; // startup overhead
  let prevLat = FLY_BASE_LAT, prevLon = FLY_BASE_LON;
  for (const wp of waypoints) {
    const segment = haversineMeters(prevLat, prevLon, wp.lat, wp.lon);
    total += segment / FLY_SPEED_MPS;
    total += wp.hoverSeconds || 0;
    prevLat = wp.lat; prevLon = wp.lon;
  }
  // Return to base
  const returnDist = haversineMeters(prevLat, prevLon, FLY_BASE_LAT, FLY_BASE_LON);
  total += returnDist / FLY_SPEED_MPS;
  return Math.round(total);
}

// GET /drone/patrol/list — available patrol routes
app.get('/drone/patrol/list', (req, res) => {
  const list = Object.entries(patrolsConfig.patrols || {}).map(([key, p]) => ({
    id: key,
    name: p.name,
    description: p.description,
    waypointCount: (p.waypoints || []).length,
    estimatedDurationSeconds: p.estimatedDurationSeconds || calculatePatrolEta(p.waypoints || []),
  }));
  res.json({ patrols: list });
});

// GET /drone/patrol/status — current patrol state
app.get('/drone/patrol/status', (req, res) => {
  if (!activePatrol) {
    res.json({ active: false, state: 'idle' });
    return;
  }
  const elapsedSec = Math.round((Date.now() - activePatrol.startedAt) / 1000);
  res.json({
    active: true,
    state: elapsedSec < activePatrol.etaSec ? 'in_progress' : 'completing',
    patrolName: activePatrol.name,
    waypointCount: activePatrol.waypointCount,
    etaSec: activePatrol.etaSec,
    elapsedSec,
    remainingSec: Math.max(0, activePatrol.etaSec - elapsedSec),
    stub: true,
  });
});

// POST /drone/patrol/start[/:name] — start a patrol
app.post(['/drone/patrol/start', '/drone/patrol/start/:name'], (req, res) => {
  const patrolName = req.params.name || 'perimeter';
  const patrol = (patrolsConfig.patrols || {})[patrolName];

  if (!patrol) {
    return res.status(404).json({
      ok: false,
      error: `patrol "${patrolName}" not found`,
      available: Object.keys(patrolsConfig.patrols || {}),
    });
  }

  // Concurrency check
  if (activePatrol) {
    return res.status(409).json({
      ok: false,
      error: 'another patrol is already in progress',
      activePatrol: activePatrol.name,
    });
  }

  // Validate waypoints
  const waypoints = patrol.waypoints || [];
  if (waypoints.length === 0) {
    return res.status(400).json({ ok: false, error: 'patrol has no waypoints' });
  }
  for (const wp of waypoints) {
    const v = validateWaypointGeofence(wp);
    if (!v.ok) {
      return res.status(403).json({ ok: false, error: v.error });
    }
  }

  const etaSec = calculatePatrolEta(waypoints);

  log('INFO', 'patrol start (stub)', {
    patrol: patrolName,
    waypoints: waypoints.length,
    etaSec,
  });

  // Update state (stub — would be real flight launch via Cloud API)
  activePatrol = {
    name: patrolName,
    startedAt: Date.now(),
    waypointCount: waypoints.length,
    etaSec,
  };

  // Auto-clear active state after ETA elapses (stub behavior)
  setTimeout(() => {
    if (activePatrol && activePatrol.name === patrolName) {
      log('INFO', 'patrol stub complete', { patrol: patrolName });
      activePatrol = null;
    }
  }, etaSec * 1000);

  res.json({
    ok: true,
    stub: true,
    accepted: true,
    patrol: patrolName,
    name: patrol.name,
    waypointCount: waypoints.length,
    etaSec,
    message: 'Patrol queued (stub — Cloud API integration pending)',
  });
});

// POST /drone/patrol/stop — abort active patrol
app.post('/drone/patrol/stop', (req, res) => {
  if (!activePatrol) {
    return res.status(400).json({ ok: false, error: 'no patrol in progress' });
  }
  log('INFO', 'patrol abort (stub)', { patrol: activePatrol.name });
  const stopped = activePatrol.name;
  activePatrol = null;
  res.json({
    ok: true,
    stub: true,
    stopped,
    message: 'Abort signaled (stub — Cloud API integration pending). Drone would now RTH.',
  });
});

// GET /drone/locations — list named locations for goto
app.get('/drone/locations', (req, res) => {
  const list = Object.entries(patrolsConfig.locations || {}).map(([key, loc]) => ({
    id: key,
    name: loc.name,
    description: loc.description,
    lat: loc.lat,
    lon: loc.lon,
    altitudeM: loc.altitudeM,
  }));
  res.json({ locations: list });
});

// POST /drone/goto/:location — fly to a named location and hover
app.post('/drone/goto/:location', (req, res) => {
  const locName = req.params.location;
  const loc = (patrolsConfig.locations || {})[locName];

  if (!loc) {
    return res.status(404).json({
      ok: false,
      error: `location "${locName}" not found`,
      available: Object.keys(patrolsConfig.locations || {}),
    });
  }

  if (activePatrol) {
    return res.status(409).json({
      ok: false,
      error: 'a patrol is currently active',
      activePatrol: activePatrol.name,
    });
  }

  // Validate geofence
  const v = validateWaypointGeofence({ name: locName, lat: loc.lat, lon: loc.lon });
  if (!v.ok) {
    return res.status(403).json({ ok: false, error: v.error });
  }

  const distance = v.distance;
  const flightSec = distance / FLY_SPEED_MPS;
  const etaSec = Math.round(FLY_STARTUP_SEC + flightSec + (loc.hoverSeconds || 30) + flightSec);

  log('INFO', 'goto location (stub)', {
    location: locName,
    distanceMeters: Math.round(distance),
    etaSec,
  });

  res.json({
    ok: true,
    stub: true,
    accepted: true,
    location: locName,
    name: loc.name,
    distanceMeters: Math.round(distance),
    etaSec,
    altitudeM: loc.altitudeM,
    hoverSeconds: loc.hoverSeconds || 30,
    message: 'Goto queued (stub — Cloud API integration pending)',
  });
});

// Screenshot
app.get('/drone/screenshot', async (req, res) => {
  try {
    await runAdb('shell screencap -p /sdcard/snap.png');
    const localPath = path.join(__dirname, 'snap.png');
    await runAdb(`pull /sdcard/snap.png "${localPath}"`);
    res.sendFile(localPath);
  } catch (e) {
    log('ERROR', 'screenshot failed', { error: e });
    res.status(500).json({ ok: false, error: String(e) });
  }
});

// Telemetry stub
app.get('/telemetry', async (req, res) => {
  try {
    const out = await runAdb('devices');
    const lines = out.split('\n').filter(l => l.trim() && !l.startsWith('List'));
    const connected = lines.length > 0 && lines.some(l => l.includes('device'));
    res.json({
      controllerConnected: connected,
      droneConnected: null,
      battery: null,
      altitude: null,
      latitude: null,
      longitude: null,
      cameraMode: null,
      flightMode: null,
      notImplemented: "Live drone telemetry requires DJI Cloud API integration. Only controller-connected status is available.",
      uptime: process.uptime(),
    });
  } catch (e) {
    res.status(500).json({ error: String(e) });
  }
});

// Sweep / patrol stub
app.post('/sweep', (req, res) => {
  log('WARN', 'sweep called — deprecated, redirect to /drone/patrol/start', { body: req.body });
  res.status(501).json({
    ok: false,
    deprecated: true,
    notImplemented: "Use /drone/patrol/start[/:name] instead. See /drone/patrol/list for available routes.",
    receivedBody: req.body,
  });
});

// Raw ADB passthrough (debug)
app.post('/raw', async (req, res) => {
  const { adb } = req.body;
  if (!adb || typeof adb !== 'string') {
    return res.status(400).json({ ok: false, error: 'provide {"adb": "shell input keyevent 3"}' });
  }
  try {
    const out = await runAdb(adb);
    res.json({ ok: true, output: out });
  } catch (e) {
    res.status(500).json({ ok: false, error: String(e) });
  }
});

app.listen(config.port, config.bindAddress, () => {
  log('INFO', `Drone API v1.4 listening on ${config.bindAddress}:${config.port}`);
  log('INFO', `ADB path: ${config.adbPath}`);
  log('INFO', `Loaded ${Object.keys(commands).length} commands`);
});

process.on('uncaughtException', (err) => {
  log('FATAL', 'uncaughtException', { error: err.message, stack: err.stack });
});
process.on('unhandledRejection', (reason) => {
  log('FATAL', 'unhandledRejection', { reason: String(reason) });
});
