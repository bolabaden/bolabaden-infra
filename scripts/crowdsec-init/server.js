#!/usr/bin/env node
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const crypto = require('crypto');

/* ==========================================================================
   Configuration
   ========================================================================== */
const PORT = parseInt(process.env.INIT_PORT || '3000', 10);
const CONFIG_PATH = process.env.CONFIG_PATH || '/work/config';
const SECRETS_PATH = process.env.SECRETS_PATH || '/work/secrets';
const CROWDSEC_CONTAINER = process.env.CROWDSEC_CONTAINER_NAME || 'crowdsec';
const DEFAULT_BOUNCER = process.env.CROWDSEC_BOUNCER_NAME || 'traefik-bouncer';
const WAIT_SECONDS = parseInt(process.env.CROWDSEC_WAIT_SECONDS || '180', 10);
const AUTO_EXIT_DELAY = parseInt(process.env.AUTO_EXIT_DELAY || '30', 10);
const LAPI_KEY_FILE = path.join(SECRETS_PATH, 'crowdsec-lapi-key.txt');
const TRAEFIK_ROOT = path.join(CONFIG_PATH, 'traefik');
const CROWDSEC_ROOT = path.join(TRAEFIK_ROOT, 'crowdsec');

/* ==========================================================================
   State
   ========================================================================== */
let autoExitTimer = null;
let autoExitRemaining = AUTO_EXIT_DELAY;
let autoExitCancelled = false;

/* ==========================================================================
   Utilities
   ========================================================================== */
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function log(msg) {
  console.log(`[${new Date().toISOString()}] ${msg}`);
}

function dockerExec(cmd, timeout = 30000) {
  try {
    return execSync(`docker exec ${CROWDSEC_CONTAINER} ${cmd}`, {
      encoding: 'utf-8',
      timeout,
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch (e) {
    const stderr = e.stderr ? e.stderr.toString().trim() : '';
    const stdout = e.stdout ? e.stdout.toString().trim() : '';
    throw new Error(stderr || stdout || e.message);
  }
}

function getDockerLogs(tail = 150) {
  try {
    return execSync(`docker logs ${CROWDSEC_CONTAINER} --tail=${tail} 2>&1`, {
      encoding: 'utf-8',
      timeout: 10000,
    }).trim();
  } catch (e) {
    return `Error fetching logs: ${e.message}`;
  }
}

function readLapiKey() {
  try {
    return fs.readFileSync(LAPI_KEY_FILE, 'utf-8').trim();
  } catch {
    return '';
  }
}

function writeLapiKey(key) {
  fs.mkdirSync(path.dirname(LAPI_KEY_FILE), { recursive: true });
  fs.writeFileSync(LAPI_KEY_FILE, key.trim() + '\n', { mode: 0o600 });
}

function sendJSON(res, status, data) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-cache',
  });
  res.end(body);
}

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        resolve(chunks.length ? JSON.parse(Buffer.concat(chunks).toString()) : {});
      } catch {
        resolve({});
      }
    });
    req.on('error', reject);
  });
}

/* ==========================================================================
   Bootstrap / Preparation
   ========================================================================== */
function prepareDirectories() {
  const dirs = [
    SECRETS_PATH,
    path.join(TRAEFIK_ROOT, 'logs'),
    path.join(CROWDSEC_ROOT, 'data'),
    path.join(CROWDSEC_ROOT, 'etc', 'crowdsec'),
    path.join(CROWDSEC_ROOT, 'plugins'),
    path.join(CROWDSEC_ROOT, 'var', 'log'),
  ];
  for (const d of dirs) {
    fs.mkdirSync(d, { recursive: true });
  }
  for (const f of ['auth.log', 'syslog']) {
    const p = path.join(CROWDSEC_ROOT, 'var', 'log', f);
    if (!fs.existsSync(p)) fs.writeFileSync(p, '');
  }
}

function ensureLapiKey() {
  const key = readLapiKey();
  if (key.length >= 32) return key;
  const newKey = crypto.randomBytes(24).toString('hex'); // 48 hex chars
  writeLapiKey(newKey);
  log(`Generated new LAPI key (${newKey.length} chars)`);
  return newKey;
}

/* ==========================================================================
   Status Checks
   ========================================================================== */
function containerExists() {
  try {
    execSync(`docker inspect ${CROWDSEC_CONTAINER}`, {
      encoding: 'utf-8',
      timeout: 5000,
      stdio: ['pipe', 'pipe', 'pipe'],
    });
    return true;
  } catch {
    return false;
  }
}

function checkLapi() {
  try {
    const output = dockerExec('cscli lapi status 2>&1', 10000);
    const connected =
      !output.toLowerCase().includes('error') || output.toLowerCase().includes('on ');
    return { connected, output };
  } catch (e) {
    return { connected: false, error: e.message };
  }
}

function getVersion() {
  try {
    return dockerExec('cscli version 2>&1', 5000);
  } catch {
    return 'unknown';
  }
}

function listBouncers() {
  try {
    const raw = dockerExec('cscli bouncers list -o raw', 10000);
    const lines = raw.split('\n').filter((l) => l && !l.startsWith('name'));
    return lines.map((line) => {
      const p = line.split(',');
      return {
        name: p[0] || '',
        ip: p[1] || '',
        revoked: p[2] || '',
        lastPull: p[3] || '',
        type: p[4] || '',
        version: p[5] || '',
        authType: p[6] || '',
      };
    });
  } catch {
    return [];
  }
}

function listCollections() {
  try {
    const raw = dockerExec('cscli collections list -o raw', 10000);
    const lines = raw.split('\n').filter((l) => l && !l.startsWith('name'));
    return lines.map((line) => {
      const p = line.split(',');
      return { name: p[0] || '', status: p[1] || '', version: p[2] || '', description: p[3] || '' };
    });
  } catch {
    return [];
  }
}

function listDecisions() {
  try {
    const raw = dockerExec('cscli decisions list -o json 2>/dev/null', 10000);
    return JSON.parse(raw) || [];
  } catch {
    return [];
  }
}

function checkCapi() {
  try {
    const output = dockerExec('cscli capi status 2>&1', 10000);
    const enrolled =
      !output.toLowerCase().includes('not enrolled') &&
      !output.toLowerCase().includes('no credentials');
    return { enrolled, output };
  } catch {
    return { enrolled: false, error: 'CAPI check failed' };
  }
}

function getFullStatus() {
  const exists = containerExists();
  if (!exists) {
    return {
      timestamp: new Date().toISOString(),
      allHealthy: false,
      container: { exists: false },
      lapi: { connected: false },
      key: { exists: false, length: 0, path: LAPI_KEY_FILE },
      bouncer: { name: DEFAULT_BOUNCER, registered: false, all: [] },
      capi: { enrolled: false },
      collections: { installed: [], count: 0 },
      decisions: { count: 0 },
      version: 'N/A',
      autoExit: { active: autoExitTimer !== null, remaining: autoExitRemaining },
    };
  }

  const lapi = checkLapi();
  const key = readLapiKey();
  const bouncers = lapi.connected ? listBouncers() : [];
  const bouncerRegistered = bouncers.some((b) => b.name === DEFAULT_BOUNCER);
  const collections = lapi.connected ? listCollections() : [];
  const decisions = lapi.connected ? listDecisions() : [];
  const capi = lapi.connected ? checkCapi() : { enrolled: false };
  const version = getVersion();

  const allHealthy =
    lapi.connected && key.length >= 32 && bouncerRegistered && collections.length > 0;

  return {
    timestamp: new Date().toISOString(),
    allHealthy,
    container: { exists: true },
    lapi: { connected: lapi.connected, output: lapi.output || lapi.error },
    key: { exists: key.length > 0, length: key.length, path: LAPI_KEY_FILE },
    bouncer: { name: DEFAULT_BOUNCER, registered: bouncerRegistered, all: bouncers },
    capi: { enrolled: capi.enrolled },
    collections: { installed: collections, count: collections.length },
    decisions: {
      count: Array.isArray(decisions) ? decisions.length : 0,
      items: Array.isArray(decisions) ? decisions.slice(0, 20) : [],
    },
    version,
    autoExit: { active: autoExitTimer !== null, remaining: autoExitRemaining },
  };
}

/* ==========================================================================
   API Handlers
   ========================================================================== */
async function handleStatus(req, res) {
  sendJSON(res, 200, getFullStatus());
}

async function handleGetKey(req, res) {
  const key = readLapiKey();
  sendJSON(res, 200, {
    exists: key.length > 0,
    length: key.length,
    masked:
      key.length > 8
        ? key.slice(0, 4) + '\u2022'.repeat(Math.min(key.length - 8, 20)) + key.slice(-4)
        : '\u2022'.repeat(key.length),
    raw: key,
    path: LAPI_KEY_FILE,
  });
}

async function handleGenerateKey(req, res) {
  const newKey = crypto.randomBytes(24).toString('hex');
  writeLapiKey(newKey);
  log(`New LAPI key generated (${newKey.length} chars)`);
  sendJSON(res, 200, {
    success: true,
    length: newKey.length,
    masked: newKey.slice(0, 4) + '\u2022'.repeat(newKey.length - 8) + newKey.slice(-4),
  });
}

async function handleSetKey(req, res) {
  const body = await parseBody(req);
  if (!body.key || body.key.length < 32) {
    sendJSON(res, 400, { error: 'Key must be at least 32 characters' });
    return;
  }
  writeLapiKey(body.key);
  log(`LAPI key set manually (${body.key.length} chars)`);
  sendJSON(res, 200, { success: true, length: body.key.length });
}

async function handleRegisterBouncer(req, res) {
  const body = await parseBody(req);
  const name = body.name || DEFAULT_BOUNCER;
  const key = readLapiKey();
  if (!key) {
    sendJSON(res, 400, { error: 'No LAPI key found. Generate or set one first.' });
    return;
  }
  try {
    const bouncers = listBouncers();
    if (bouncers.some((b) => b.name === name)) {
      sendJSON(res, 200, {
        success: true,
        message: 'Bouncer already registered',
        alreadyExists: true,
      });
      return;
    }
    dockerExec(`cscli bouncers add "${name}" -k "${key}"`, 15000);
    log(`Bouncer '${name}' registered`);
    sendJSON(res, 200, { success: true, message: `Bouncer '${name}' registered` });
  } catch (e) {
    sendJSON(res, 500, { error: e.message });
  }
}

async function handleRemoveBouncer(req, res) {
  const body = await parseBody(req);
  const name = body.name;
  if (!name) {
    sendJSON(res, 400, { error: 'Bouncer name required' });
    return;
  }
  try {
    dockerExec(`cscli bouncers delete "${name}"`, 15000);
    log(`Bouncer '${name}' removed`);
    sendJSON(res, 200, { success: true, message: `Bouncer '${name}' removed` });
  } catch (e) {
    sendJSON(res, 500, { error: e.message });
  }
}

async function handleEnrollCAPI(req, res) {
  const body = await parseBody(req);
  if (!body.key) {
    sendJSON(res, 400, { error: 'Enrollment key required' });
    return;
  }
  try {
    let cmd = `cscli console enroll "${body.key}"`;
    if (body.name) cmd += ` --name "${body.name}"`;
    if (body.tags && Array.isArray(body.tags)) cmd += ` --tags "${body.tags.join(' ')}"`;
    const output = dockerExec(cmd, 30000);
    log('CAPI enrollment requested');
    sendJSON(res, 200, { success: true, output });
  } catch (e) {
    sendJSON(res, 500, { error: e.message });
  }
}

async function handleListCollections(req, res) {
  sendJSON(res, 200, { collections: listCollections() });
}

async function handleInstallCollection(req, res) {
  const body = await parseBody(req);
  if (!body.name) {
    sendJSON(res, 400, { error: 'Collection name required' });
    return;
  }
  try {
    dockerExec(`cscli collections install "${body.name}"`, 60000);
    log(`Collection '${body.name}' installed`);
    sendJSON(res, 200, { success: true, message: `Collection '${body.name}' installed` });
  } catch (e) {
    sendJSON(res, 500, { error: e.message });
  }
}

async function handleGetDecisions(req, res) {
  const decisions = listDecisions();
  sendJSON(res, 200, { decisions, count: decisions.length });
}

async function handleGetLogs(req, res) {
  const logs = getDockerLogs(200);
  sendJSON(res, 200, { logs: logs.split('\n') });
}

async function handleFinalize(req, res) {
  clearAutoExit();
  sendJSON(res, 200, { success: true, message: 'Finalizing...' });
  log('Finalization requested via UI. Exiting in 1s...');
  setTimeout(() => process.exit(0), 1000);
}

async function handleCancelAutoExit(req, res) {
  clearAutoExit();
  autoExitCancelled = true;
  log('Auto-exit cancelled by user');
  sendJSON(res, 200, { success: true });
}

/* ==========================================================================
   Auto-Exit Logic
   ========================================================================== */
function startAutoExit() {
  if (autoExitTimer || autoExitCancelled) return;
  autoExitRemaining = AUTO_EXIT_DELAY;
  log(`Starting auto-exit countdown (${AUTO_EXIT_DELAY}s)...`);
  autoExitTimer = setInterval(() => {
    autoExitRemaining--;
    if (autoExitRemaining <= 0) {
      clearAutoExit();
      log('Auto-exit countdown complete. Exiting.');
      process.exit(0);
    }
  }, 1000);
}

function clearAutoExit() {
  if (autoExitTimer) {
    clearInterval(autoExitTimer);
    autoExitTimer = null;
  }
}

/* ==========================================================================
   Static File Server
   ========================================================================== */
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function serveStatic(req, res) {
  let filePath = req.url === '/' ? '/index.html' : req.url.split('?')[0];
  // Security: prevent path traversal
  filePath = path.normalize(filePath).replace(/^(\.\.(\/|\\|$))+/, '');
  filePath = path.join(__dirname, 'public', filePath);

  const ext = path.extname(filePath);
  const contentType = MIME_TYPES[ext] || 'application/octet-stream';

  try {
    const content = fs.readFileSync(filePath);
    res.writeHead(200, { 'Content-Type': contentType, 'Cache-Control': 'no-cache' });
    res.end(content);
  } catch {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
}

/* ==========================================================================
   HTTP Server & Router
   ========================================================================== */
const ROUTES = {
  'GET /api/status': handleStatus,
  'GET /api/key': handleGetKey,
  'POST /api/key/generate': handleGenerateKey,
  'POST /api/key/set': handleSetKey,
  'POST /api/bouncers/register': handleRegisterBouncer,
  'POST /api/bouncers/remove': handleRemoveBouncer,
  'POST /api/enroll': handleEnrollCAPI,
  'GET /api/collections': handleListCollections,
  'POST /api/collections/install': handleInstallCollection,
  'GET /api/decisions': handleGetDecisions,
  'GET /api/logs': handleGetLogs,
  'POST /api/finalize': handleFinalize,
  'POST /api/cancel-auto-exit': handleCancelAutoExit,
};

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const routeKey = `${req.method} ${req.url.split('?')[0]}`;
  const handler = ROUTES[routeKey];

  if (handler) {
    try {
      await handler(req, res);
    } catch (e) {
      log(`Handler error: ${e.message}`);
      sendJSON(res, 500, { error: e.message });
    }
  } else if (req.method === 'GET' && !req.url.startsWith('/api/')) {
    serveStatic(req, res);
  } else {
    sendJSON(res, 404, { error: 'Not found' });
  }
});

/* ==========================================================================
   Background Monitor
   ========================================================================== */
async function backgroundMonitor() {
  while (true) {
    await sleep(5000);
    try {
      const status = getFullStatus();
      if (status.allHealthy && !autoExitTimer && !autoExitCancelled) {
        log('All health checks passed.');
        startAutoExit();
      } else if (!status.allHealthy && autoExitTimer) {
        log('Health check regression detected. Cancelling auto-exit.');
        clearAutoExit();
      }
    } catch (e) {
      log(`Monitor error: ${e.message}`);
    }
  }
}

/* ==========================================================================
   Main
   ========================================================================== */
async function main() {
  log('CrowdSec Init starting...');
  log(`  Container: ${CROWDSEC_CONTAINER}`);
  log(`  Bouncer:   ${DEFAULT_BOUNCER}`);
  log(`  Key file:  ${LAPI_KEY_FILE}`);
  log(`  UI port:   ${PORT}`);

  // Phase 1: Prepare host paths and key
  log('Phase 1: Preparing directories...');
  prepareDirectories();
  const key = ensureLapiKey();
  log(`  LAPI key ready (${key.length} chars)`);

  // Phase 2: Quick check — if everything already works, exit immediately
  log('Phase 2: Quick health check...');
  if (containerExists()) {
    const quick = getFullStatus();
    if (quick.allHealthy) {
      log('All systems already operational. No UI needed. Exiting.');
      process.exit(0);
    }
    log(`  Quick check: lapi=${quick.lapi.connected} key=${quick.key.exists} bouncer=${quick.bouncer.registered} collections=${quick.collections.count}`);
  } else {
    log('  CrowdSec container not found yet.');
  }

  // Phase 3: Start web server
  log('Phase 3: Starting configuration UI...');
  server.listen(PORT, '0.0.0.0', () => {
    log(`Configuration UI: http://0.0.0.0:${PORT}`);
  });

  // Phase 4: Wait for LAPI and auto-bootstrap
  log('Phase 4: Waiting for CrowdSec LAPI...');
  const deadline = Date.now() + WAIT_SECONDS * 1000;
  let lapiReady = false;

  while (Date.now() < deadline) {
    if (containerExists()) {
      const lapi = checkLapi();
      if (lapi.connected) {
        log('LAPI is reachable!');
        lapiReady = true;
        break;
      }
    }
    await sleep(3000);
  }

  if (lapiReady) {
    // Auto-register bouncer
    try {
      const bouncers = listBouncers();
      if (!bouncers.some((b) => b.name === DEFAULT_BOUNCER)) {
        const lapiKey = readLapiKey();
        if (lapiKey) {
          dockerExec(`cscli bouncers add "${DEFAULT_BOUNCER}" -k "${lapiKey}"`, 15000);
          log(`Bouncer '${DEFAULT_BOUNCER}' auto-registered.`);
        }
      } else {
        log(`Bouncer '${DEFAULT_BOUNCER}' already registered.`);
      }
    } catch (e) {
      log(`Auto-register bouncer failed: ${e.message}`);
    }

    // Final check
    const status = getFullStatus();
    if (status.allHealthy) {
      log('All systems operational after auto-bootstrap!');
      startAutoExit();
    } else {
      log(
        `Some checks pending. UI available for manual config. lapi=${status.lapi.connected} bouncer=${status.bouncer.registered} collections=${status.collections.count}`
      );
    }
  } else {
    log(`LAPI not reachable after ${WAIT_SECONDS}s. UI available for manual config.`);
  }

  // Phase 5: Background health monitor
  backgroundMonitor();
}

main().catch((e) => {
  console.error('Fatal error:', e);
  process.exit(1);
});
