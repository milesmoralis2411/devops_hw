const http = require('http');
const { loadConfig } = require('./config');
const { createApp } = require('./app');

const config = loadConfig();
const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

// One JSON object per line on stdout: what Kubernetes, Fluent Bit and Loki
// all expect. Secrets are never logged.
function log(level, msg, fields = {}) {
  if ((LEVELS[level] || 20) < (LEVELS[config.logLevel] || 20)) return;
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, service: 'yatri-trips', version: config.version, ...fields }));
}

const server = http.createServer(createApp(config, log));

server.listen(config.port, () => {
  log('info', 'listening', { port: config.port, env: config.appEnv, dataDir: config.dataDir, apiKeyConfigured: config.apiKey.length > 0 });
});

// Kubernetes sends SIGTERM on rollout/scale-down; finish in-flight requests.
for (const sig of ['SIGTERM', 'SIGINT']) {
  process.on(sig, () => {
    log('info', 'shutting down', { signal: sig });
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  });
}
