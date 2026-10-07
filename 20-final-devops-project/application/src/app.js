// HTTP routing for the Yatri Trips API. createApp() returns a plain request
// handler, so tests drive it with in-process HTTP and no fixed port.
const crypto = require('crypto');
const { TripStore, validateTrip } = require('./store');
const { Metrics } = require('./metrics');

const MAX_BODY = 10 * 1024;

function createApp(config, log = () => {}) {
  const store = new TripStore(config.dataDir, config.maxTrips);
  const metrics = new Metrics(config.version);

  function send(res, status, body, type = 'application/json') {
    res.writeHead(status, { 'Content-Type': type });
    res.end(type === 'application/json' ? JSON.stringify(body) : body);
  }

  // Constant-time comparison, so response timing does not leak the key.
  function authorised(req) {
    const given = Buffer.from(String(req.headers['x-api-key'] || ''));
    const want = Buffer.from(config.apiKey);
    return want.length > 0 && given.length === want.length && crypto.timingSafeEqual(given, want);
  }

  function readJson(req) {
    return new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', (c) => {
        size += c.length;
        if (size > MAX_BODY) {
          reject(Object.assign(new Error('body too large'), { status: 413 }));
          req.destroy();
          return;
        }
        chunks.push(c);
      });
      req.on('end', () => {
        try {
          resolve(JSON.parse(Buffer.concat(chunks).toString() || '{}'));
        } catch {
          reject(Object.assign(new Error('invalid JSON'), { status: 400 }));
        }
      });
      req.on('error', reject);
    });
  }

  async function route(req, res) {
    const url = new URL(req.url, 'http://localhost');
    const p = url.pathname;
    const m = req.method;

    if (m === 'GET' && p === '/') {
      return ['/', send(res, 200, { service: 'yatri-trips', version: config.version, env: config.appEnv })];
    }
    if (m === 'GET' && p === '/healthz') {
      return ['/healthz', send(res, 200, { status: 'ok' })];
    }
    if (m === 'GET' && p === '/readyz') {
      const ok = store.writable() && config.apiKey.length > 0;
      return ['/readyz', send(res, ok ? 200 : 503, { status: ok ? 'ready' : 'not ready', storage: store.writable(), apiKeyConfigured: config.apiKey.length > 0 })];
    }
    if (m === 'GET' && p === '/metrics') {
      return ['/metrics', send(res, 200, metrics.render(store.list().length), 'text/plain; version=0.0.4')];
    }
    if (m === 'GET' && p === '/api/trips') {
      return ['/api/trips', send(res, 200, store.list())];
    }
    if (m === 'POST' && p === '/api/trips') {
      if (!authorised(req)) {
        metrics.authFailures += 1;
        return ['/api/trips', send(res, 401, { error: 'missing or invalid x-api-key' })];
      }
      const body = await readJson(req);
      const errors = validateTrip(body);
      if (errors.length) return ['/api/trips', send(res, 400, { errors })];
      const trip = store.add({ destination: body.destination.trim(), days: body.days });
      metrics.tripsCreated += 1;
      return ['/api/trips', send(res, 201, trip)];
    }
    const match = p.match(/^\/api\/trips\/([0-9a-f-]{36})$/);
    if (match && m === 'GET') {
      const trip = store.get(match[1]);
      return ['/api/trips/:id', trip ? send(res, 200, trip) : send(res, 404, { error: 'trip not found' })];
    }
    if (match && m === 'DELETE') {
      if (!authorised(req)) {
        metrics.authFailures += 1;
        return ['/api/trips/:id', send(res, 401, { error: 'missing or invalid x-api-key' })];
      }
      return ['/api/trips/:id', store.remove(match[1]) ? send(res, 204, '', 'text/plain') : send(res, 404, { error: 'trip not found' })];
    }
    return ['other', send(res, 404, { error: 'not found' })];
  }

  const handler = async (req, res) => {
    const start = process.hrtime.bigint();
    let routeLabel = 'other';
    try {
      [routeLabel] = await route(req, res);
    } catch (err) {
      const status = err.status || 500;
      if (!res.headersSent) send(res, status, { error: status === 500 ? 'internal error' : err.message });
      if (status === 500) log('error', 'unhandled error', { error: err.message });
    } finally {
      const seconds = Number(process.hrtime.bigint() - start) / 1e9;
      metrics.observe(req.method, routeLabel, res.statusCode, seconds);
      if (!['/healthz', '/readyz', '/metrics'].includes(routeLabel)) {
        log(res.statusCode >= 500 ? 'error' : 'info', 'request', {
          method: req.method,
          route: routeLabel,
          status: res.statusCode,
          duration_ms: Math.round(seconds * 1000),
        });
      }
    }
  };

  handler.store = store;
  return handler;
}

module.exports = { createApp };
