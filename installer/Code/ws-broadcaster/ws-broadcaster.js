// ============================================================================
// WebSocket MJPEG Broadcaster v2 (TCP socket internal)
// ============================================================================

const WebSocket = require('ws');
const net = require('net');
const { spawn } = require('child_process');

const CONFIG = {
  wsPort: 8091,
  tcpPort: 18091,
  rtspSource: 'rtsp://localhost:8554/standard_clean',
  ffmpegBin: 'C:\\DroneServer\\bin\\ffmpeg\\bin\\ffmpeg.exe',
  scale: '640:360',
  fps: 20,
  jpegQuality: 6,
  reconnectDelayMs: 1000,
};

function log(level, msg, data) {
  const ts = new Date().toISOString();
  const dataStr = data ? ' ' + JSON.stringify(data) : '';
  console.log(`${ts} [${level}] ${msg}${dataStr}`);
}

const wss = new WebSocket.Server({ port: CONFIG.wsPort });
const clients = new Set();

wss.on('connection', (ws, req) => {
  const ip = req.socket.remoteAddress;
  clients.add(ws);
  log('INFO', 'client connected', { ip, total: clients.size });
  ws.on('close', () => { clients.delete(ws); log('INFO', 'client disconnected', { ip, total: clients.size }); });
  ws.on('error', (err) => { log('WARN', 'client error', { ip, error: err.message }); clients.delete(ws); });
});

wss.on('listening', () => log('INFO', `WebSocket server listening on port ${CONFIG.wsPort}`));
wss.on('error', (err) => log('ERROR', 'WebSocket server error', { error: err.message }));

function broadcastFrame(jpegBuffer) {
  if (clients.size === 0) return;
  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      try { client.send(jpegBuffer, { binary: true }); }
      catch (err) { log('WARN', 'send failed', { error: err.message }); }
    }
  }
}

let frameBuffer = Buffer.alloc(0);
let framesSent = 0, bytesProcessed = 0;

setInterval(() => {
  if (framesSent > 0) {
    log('INFO', 'stats', { framesSent, bytesProcessed, avgFrameSize: Math.round(bytesProcessed / framesSent), clients: clients.size });
    framesSent = 0; bytesProcessed = 0;
  } else if (clients.size > 0) {
    log('WARN', 'no frames produced in last 10s', { clients: clients.size });
  }
}, 10000);

function processData(chunk) {
  frameBuffer = Buffer.concat([frameBuffer, chunk]);
  while (true) {
    const soiIdx = frameBuffer.indexOf(Buffer.from([0xFF, 0xD8]));
    if (soiIdx === -1) { frameBuffer = Buffer.alloc(0); break; }
    if (soiIdx > 0) frameBuffer = frameBuffer.slice(soiIdx);
    const eoiIdx = frameBuffer.indexOf(Buffer.from([0xFF, 0xD9]), 2);
    if (eoiIdx === -1) break;
    const jpegEnd = eoiIdx + 2;
    const jpeg = frameBuffer.slice(0, jpegEnd);
    frameBuffer = frameBuffer.slice(jpegEnd);
    broadcastFrame(jpeg);
    framesSent++; bytesProcessed += jpeg.length;
  }
}

let activeTcpConnection = null;
const tcpServer = net.createServer((socket) => {
  log('INFO', 'FFmpeg TCP connection received');
  activeTcpConnection = socket;
  socket.on('data', processData);
  socket.on('close', () => { log('WARN', 'FFmpeg TCP closed'); activeTcpConnection = null; frameBuffer = Buffer.alloc(0); });
  socket.on('error', (err) => { log('WARN', 'FFmpeg TCP error', { error: err.message }); activeTcpConnection = null; });
});

tcpServer.listen(CONFIG.tcpPort, '127.0.0.1', () => {
  log('INFO', `Internal TCP listening on 127.0.0.1:${CONFIG.tcpPort}`);
  startFFmpeg();
});

let ffmpegProc = null;
function startFFmpeg() {
  if (ffmpegProc) return;
  log('INFO', 'starting FFmpeg', { source: CONFIG.rtspSource });
  const args = [
    '-rtsp_transport', 'tcp', '-i', CONFIG.rtspSource,
    '-vf', `scale=${CONFIG.scale}`, '-r', String(CONFIG.fps),
    '-c:v', 'mjpeg', '-q:v', String(CONFIG.jpegQuality),
    '-f', 'mjpeg', '-an', `tcp://127.0.0.1:${CONFIG.tcpPort}`,
  ];
  ffmpegProc = spawn(CONFIG.ffmpegBin, args, { stdio: ['ignore', 'ignore', 'pipe'] });
  ffmpegProc.stderr.on('data', (data) => {
    const text = data.toString();
    if (/error|fail|invalid|refused|cannot/i.test(text)) {
      log('FFMPEG-ERR', text.trim().split('\n').slice(-3).join(' | '));
    }
  });
  ffmpegProc.on('exit', (code, signal) => {
    log('WARN', 'FFmpeg exited', { code, signal });
    ffmpegProc = null;
    setTimeout(startFFmpeg, CONFIG.reconnectDelayMs);
  });
  ffmpegProc.on('error', (err) => { log('ERROR', 'FFmpeg spawn error', { error: err.message }); ffmpegProc = null; });
}

function shutdown() {
  log('INFO', 'shutting down');
  if (ffmpegProc) { ffmpegProc.removeAllListeners('exit'); ffmpegProc.kill(); }
  if (activeTcpConnection) activeTcpConnection.destroy();
  tcpServer.close(); wss.close();
  process.exit(0);
}

process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

log('INFO', 'WebSocket MJPEG broadcaster v2 starting', CONFIG);
