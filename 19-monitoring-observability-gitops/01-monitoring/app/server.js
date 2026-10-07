// Instrumented demo service for the monitoring session.
//
// Emits all three things a monitoring stack needs:
//   metrics - Prometheus text format on /metrics, written by hand so the
//             format is visible (a real app would use prom-client)
//   logs    - one structured JSON line per request on stdout
//   health  - /healthz (liveness) and /readyz (readiness)
//
// /work burns CPU and /error returns 500s, so load and failures can be
// generated on demand to make the graphs and alerts move.
const http = require('http');

const PORT = process.env.PORT || 8080;
const VERSION = process.env.APP_VERSION || '1.0.0';

// Latency histogram buckets, in seconds.
const BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5];

const requests = new Map();   // "route|status" -> count
const durations = new Map();  // route -> { buckets[], sum, count }
let ready = true;

function observe(route, status, seconds) {
  const key = `${route}|${status}`;
  requests.set(key, (requests.get(key) || 0) + 1);

  if (!durations.has(route)) {
    durations.set(route, { buckets: BUCKETS.map(() => 0), sum: 0, count: 0 });
  }
  const d = durations.get(route);
  BUCKETS.forEach((le, i) => { if (seconds <= le) d.buckets[i] += 1; });
  d.sum += seconds;
  d.count += 1;
}

function metrics() {
  const out = [];
  const mem = process.memoryUsage();
  const cpu = process.cpuUsage();

  out.push('# HELP app_info Build information.');
  out.push('# TYPE app_info gauge');
  out.push(`app_info{version="${VERSION}"} 1`);

  out.push('# HELP app_ready Whether the app reports itself ready (1) or not (0).');
  out.push('# TYPE app_ready gauge');
  out.push(`app_ready ${ready ? 1 : 0}`);

  out.push('# HELP http_requests_total Total HTTP requests by route and status code.');
  out.push('# TYPE http_requests_total counter');
  for (const [key, count] of requests) {
    const [route, status] = key.split('|');
    out.push(`http_requests_total{route="${route}",status="${status}"} ${count}`);
  }

  out.push('# HELP http_request_duration_seconds Request latency.');
  out.push('# TYPE http_request_duration_seconds histogram');
  for (const [route, d] of durations) {
    BUCKETS.forEach((le, i) => {
      out.push(`http_request_duration_seconds_bucket{route="${route}",le="${le}"} ${d.buckets[i]}`);
    });
    out.push(`http_request_duration_seconds_bucket{route="${route}",le="+Inf"} ${d.count}`);
    out.push(`http_request_duration_seconds_sum{route="${route}"} ${d.sum.toFixed(6)}`);
    out.push(`http_request_duration_seconds_count{route="${route}"} ${d.count}`);
  }

  out.push('# HELP process_resident_memory_bytes Resident memory size in bytes.');
  out.push('# TYPE process_resident_memory_bytes gauge');
  out.push(`process_resident_memory_bytes ${mem.rss}`);

  out.push('# HELP process_heap_used_bytes V8 heap in use, in bytes.');
  out.push('# TYPE process_heap_used_bytes gauge');
  out.push(`process_heap_used_bytes ${mem.heapUsed}`);

  out.push('# HELP process_cpu_seconds_total Total user and system CPU time spent in seconds.');
  out.push('# TYPE process_cpu_seconds_total counter');
  out.push(`process_cpu_seconds_total ${((cpu.user + cpu.system) / 1e6).toFixed(6)}`);

  return out.join('\n') + '\n';
}

function burnCpu(ms) {
  const end = Date.now() + ms;
  let x = 0;
  while (Date.now() < end) x += Math.sqrt(Math.random());
  return x;
}

function handle(req) {
  const url = new URL(req.url, 'http://localhost');
  switch (url.pathname) {
    case '/':
      return [200, { message: 'monitoring demo', version: VERSION }];
    case '/healthz':
      return [200, { status: 'ok' }];
    case '/readyz':
      return ready ? [200, { status: 'ready' }] : [503, { status: 'not ready' }];
    case '/work': {
      const ms = Math.min(Number(url.searchParams.get('ms')) || 100, 2000);
      burnCpu(ms);
      return [200, { burned_ms: ms }];
    }
    case '/error':
      return [500, { error: 'simulated failure' }];
    case '/toggle-ready':
      ready = !ready;
      return [200, { ready }];
    default:
      return [404, { error: 'not found' }];
  }
}

const server = http.createServer((req, res) => {
  const start = process.hrtime.bigint();
  const path = new URL(req.url, 'http://localhost').pathname;

  if (path === '/metrics') {
    res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' });
    res.end(metrics());
    return;
  }

  const [status, body] = handle(req);
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));

  const seconds = Number(process.hrtime.bigint() - start) / 1e9;
  // Keep the label set bounded: unknown paths collapse into one label.
  const route = ['/', '/healthz', '/readyz', '/work', '/error', '/toggle-ready'].includes(path) ? path : 'other';
  observe(route, status, seconds);

  // Structured log line. Probe traffic is skipped to keep the logs readable.
  if (route !== '/healthz' && route !== '/readyz') {
    console.log(JSON.stringify({
      ts: new Date().toISOString(),
      level: status >= 500 ? 'error' : 'info',
      method: req.method,
      route,
      status,
      duration_ms: Math.round(seconds * 1000),
      version: VERSION,
    }));
  }
});

server.listen(PORT, () => {
  console.log(JSON.stringify({ ts: new Date().toISOString(), level: 'info', msg: `listening on ${PORT}`, version: VERSION }));
});

process.on('SIGTERM', () => server.close(() => process.exit(0)));
