// All configuration comes from the environment, so the same image runs in
// every environment. In Kubernetes: non-sensitive values from a ConfigMap,
// API_KEY from a Secret.
function loadConfig(env = process.env) {
  return {
    port: Number(env.PORT || 8080),
    appEnv: env.APP_ENV || 'development',
    logLevel: env.LOG_LEVEL || 'info',
    version: env.APP_VERSION || '1.0.0',
    dataDir: env.DATA_DIR || './data',
    apiKey: env.API_KEY || '',
    maxTrips: Number(env.MAX_TRIPS || 1000),
  };
}

module.exports = { loadConfig };
