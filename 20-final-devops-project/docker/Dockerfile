# Yatri Trips - production image.
# Build from the repository's final-project root:
#   docker build -f docker/Dockerfile -t yatri-trips:1.0.0 application/
#
# Stages: test (unit tests run inside the build) -> runtime (minimal, non-root)

ARG NODE_IMAGE=node:22-alpine

# ---- test ------------------------------------------------------------------
FROM ${NODE_IMAGE} AS test
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY test ./test
RUN npm run lint && npm test && touch /tmp/.tests-passed

# ---- runtime ---------------------------------------------------------------
FROM ${NODE_IMAGE} AS runtime
ARG APP_VERSION=1.0.0
LABEL org.opencontainers.image.title="yatri-trips" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.source="https://github.com/milesmoralis2411/devops_hw"

ENV NODE_ENV=production \
    PORT=8080 \
    APP_VERSION=${APP_VERSION} \
    DATA_DIR=/data

WORKDIR /app

# The runtime only needs "node". npm, npx, corepack and yarn ship in the base
# image and carry their own dependency CVEs (Trivy found 10 HIGH in npm's
# bundled packages), so they are removed from the final image.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg

# The runtime stage depends on the test stage, so BuildKit cannot skip tests.
COPY --from=test /tmp/.tests-passed /tmp/.tests-passed

COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

# The data directory is a volume mount point (a PVC in Kubernetes).
RUN mkdir -p /data && chown node:node /data
VOLUME ["/data"]

USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:8080/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
