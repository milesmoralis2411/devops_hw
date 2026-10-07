// The HTTP handler, kept separate from the listener so tests can call it
// without binding a port.
const http = require('http');

const VERSION = process.env.APP_VERSION || '1.0.0';
const GREETING = process.env.GREETING || 'Hello World from the CI/CD pipeline';

function routes(req) {
  const url = new URL(req.url, 'http://localhost');

  switch (url.pathname) {
    case '/':
      return { status: 200, body: { message: GREETING, version: VERSION } };

    case '/healthz':
      return { status: 200, body: { status: 'ok' } };

    case '/readyz':
      return { status: 200, body: { status: 'ready' } };

    case '/sum': {
      const a = Number(url.searchParams.get('a'));
      const b = Number(url.searchParams.get('b'));
      if (Number.isNaN(a) || Number.isNaN(b)) {
        return { status: 400, body: { error: 'a and b must be numbers' } };
      }
      return { status: 200, body: { a, b, sum: sum(a, b) } };
    }

    default:
      return { status: 404, body: { error: 'not found' } };
  }
}

// Pure function, unit-tested directly.
function sum(a, b) {
  return a + b;
}

function createServer() {
  return http.createServer((req, res) => {
    const { status, body } = routes(req);
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(body));
  });
}

module.exports = { createServer, routes, sum, VERSION };
