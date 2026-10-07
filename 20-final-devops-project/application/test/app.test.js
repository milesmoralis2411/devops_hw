const { test, before, after } = require('node:test');
const assert = require('node:assert');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { createApp } = require('../src/app');
const { TripStore, validateTrip } = require('../src/store');

const API_KEY = 'test-key-123';
let server;
let base;
let dataDir;

function request(method, urlPath, { body, headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const data = body === undefined ? undefined : JSON.stringify(body);
    const req = http.request(`${base}${urlPath}`, {
      method,
      headers: { 'content-type': 'application/json', ...headers },
    }, (res) => {
      let raw = '';
      res.on('data', (c) => (raw += c));
      res.on('end', () => {
        let json;
        try { json = JSON.parse(raw); } catch { json = undefined; }
        resolve({ status: res.statusCode, json, raw });
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

before(async () => {
  dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'yatri-test-'));
  const app = createApp({ port: 0, appEnv: 'test', version: '9.9.9', dataDir, apiKey: API_KEY, maxTrips: 3 });
  server = http.createServer(app);
  await new Promise((r) => server.listen(0, r));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(() => {
  server.close();
  fs.rmSync(dataDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------- validation
test('validateTrip accepts a valid trip', () => {
  assert.deepStrictEqual(validateTrip({ destination: 'Goa', days: 4 }), []);
});

test('validateTrip rejects bad input', () => {
  assert.ok(validateTrip({ destination: '', days: 4 }).length > 0);
  assert.ok(validateTrip({ destination: 'Goa', days: 0 }).length > 0);
  assert.ok(validateTrip({ destination: 'Goa', days: 61 }).length > 0);
  assert.ok(validateTrip({ destination: 'Goa', days: 2.5 }).length > 0);
  assert.ok(validateTrip(null).length > 0);
});

// --------------------------------------------------------------------- store
test('store persists trips to disk and reloads them', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'yatri-store-'));
  const a = new TripStore(dir);
  const trip = a.add({ destination: 'Leh', days: 7 });
  const b = new TripStore(dir); // simulates a Pod restart on the same PVC
  assert.strictEqual(b.get(trip.id).destination, 'Leh');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('concurrent writers from separate processes lose no trips', async () => {
  // Simulates several Pods (HPA replicas) sharing one PVC.
  const { spawn } = require('node:child_process');
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'yatri-race-'));
  const storePath = path.join(__dirname, '..', 'src', 'store.js').split(path.sep).join('/');
  const script = `const { TripStore } = require('${storePath}');
    const s = new TripStore(process.argv[1], 10000);
    for (let i = 0; i < 25; i++) s.add({ destination: 'w' + process.pid + '-' + i, days: 1 });`;
  const runs = Array.from({ length: 4 }, () => new Promise((resolve, reject) => {
    const p = spawn(process.execPath, ['-e', script, dir], { stdio: 'inherit' });
    p.on('exit', (code) => (code === 0 ? resolve() : reject(new Error(`writer exited ${code}`))));
  }));
  await Promise.all(runs);
  assert.strictEqual(new TripStore(dir).list().length, 100);
  fs.rmSync(dir, { recursive: true, force: true });
});

// -------------------------------------------------------------------- routes
test('GET / returns service info', async () => {
  const r = await request('GET', '/');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.json.service, 'yatri-trips');
  assert.strictEqual(r.json.version, '9.9.9');
});

test('GET /healthz and /readyz report healthy', async () => {
  assert.strictEqual((await request('GET', '/healthz')).status, 200);
  const ready = await request('GET', '/readyz');
  assert.strictEqual(ready.status, 200);
  assert.strictEqual(ready.json.storage, true);
});

test('POST /api/trips requires the API key', async () => {
  const r = await request('POST', '/api/trips', { body: { destination: 'Goa', days: 3 } });
  assert.strictEqual(r.status, 401);
  const wrong = await request('POST', '/api/trips', { body: { destination: 'Goa', days: 3 }, headers: { 'x-api-key': 'nope' } });
  assert.strictEqual(wrong.status, 401);
});

test('POST, GET and DELETE a trip', async () => {
  const created = await request('POST', '/api/trips', { body: { destination: 'Jaipur', days: 3 }, headers: { 'x-api-key': API_KEY } });
  assert.strictEqual(created.status, 201);
  const id = created.json.id;

  const got = await request('GET', `/api/trips/${id}`);
  assert.strictEqual(got.status, 200);
  assert.strictEqual(got.json.destination, 'Jaipur');

  const list = await request('GET', '/api/trips');
  assert.ok(list.json.some((t) => t.id === id));

  assert.strictEqual((await request('DELETE', `/api/trips/${id}`, { headers: { 'x-api-key': API_KEY } })).status, 204);
  assert.strictEqual((await request('GET', `/api/trips/${id}`)).status, 404);
});

test('POST rejects invalid payloads', async () => {
  const bad = await request('POST', '/api/trips', { body: { destination: 'Goa', days: 100 }, headers: { 'x-api-key': API_KEY } });
  assert.strictEqual(bad.status, 400);
  assert.ok(bad.json.errors.length > 0);
});

test('trip limit is enforced', async () => {
  for (let i = 0; i < 3; i += 1) {
    await request('POST', '/api/trips', { body: { destination: `City ${i}`, days: 1 }, headers: { 'x-api-key': API_KEY } });
  }
  const over = await request('POST', '/api/trips', { body: { destination: 'One too many', days: 1 }, headers: { 'x-api-key': API_KEY } });
  assert.strictEqual(over.status, 409);
});

test('GET /metrics exposes Prometheus metrics', async () => {
  const r = await request('GET', '/metrics');
  assert.strictEqual(r.status, 200);
  assert.match(r.raw, /# TYPE http_requests_total counter/);
  assert.match(r.raw, /yatri_build_info\{version="9.9.9"\} 1/);
  assert.match(r.raw, /yatri_auth_failures_total [1-9]/);
  assert.match(r.raw, /route="\/api\/trips\/:id"/); // templated, not raw IDs
});

test('unknown routes return 404', async () => {
  assert.strictEqual((await request('GET', '/nope')).status, 404);
});
