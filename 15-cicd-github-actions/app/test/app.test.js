const { test } = require('node:test');
const assert = require('node:assert');
const { routes, sum } = require('../src/app');

function req(url) {
  return { url, method: 'GET' };
}

test('sum adds two numbers', () => {
  assert.strictEqual(sum(2, 3), 5);
  assert.strictEqual(sum(-1, 1), 0);
  assert.strictEqual(sum(0, 0), 0);
});

test('GET / returns the greeting and a version', () => {
  const res = routes(req('/'));
  assert.strictEqual(res.status, 200);
  assert.ok(res.body.message.length > 0);
  assert.ok(res.body.version);
});

test('GET /healthz reports ok', () => {
  const res = routes(req('/healthz'));
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(res.body, { status: 'ok' });
});

test('GET /readyz reports ready', () => {
  const res = routes(req('/readyz'));
  assert.strictEqual(res.status, 200);
  assert.deepStrictEqual(res.body, { status: 'ready' });
});

test('GET /sum adds query parameters', () => {
  const res = routes(req('/sum?a=7&b=5'));
  assert.strictEqual(res.status, 200);
  assert.strictEqual(res.body.sum, 12);
});

test('GET /sum rejects non-numeric input', () => {
  const res = routes(req('/sum?a=hello&b=5'));
  assert.strictEqual(res.status, 400);
});

test('unknown path returns 404', () => {
  const res = routes(req('/nope'));
  assert.strictEqual(res.status, 404);
});
