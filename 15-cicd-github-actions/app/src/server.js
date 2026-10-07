const { createServer, VERSION } = require('./app');

const PORT = process.env.PORT || 3000;
const server = createServer();

server.listen(PORT, () => {
  console.log(`yatri-cicd-demo v${VERSION} listening on port ${PORT}`);
});

// Shut down cleanly so Kubernetes rolling updates do not drop requests.
for (const signal of ['SIGTERM', 'SIGINT']) {
  process.on(signal, () => {
    console.log(`${signal} received, closing server`);
    server.close(() => process.exit(0));
  });
}
