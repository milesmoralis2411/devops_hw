# Multi-stage build: tests run inside the build, and the final image carries
# only the runtime files and runs as a non-root user.

# ---- stage 1: dependencies ----
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
# The app has no runtime dependencies yet, so npm creates no node_modules;
# mkdir keeps the COPY in the runtime stage valid either way.
RUN npm ci --omit=dev --no-audit --no-fund && mkdir -p node_modules

# ---- stage 2: test ----
FROM node:22-alpine AS test
WORKDIR /app
COPY package.json ./
COPY src ./src
COPY test ./test
RUN npm test && touch /app/.tests-passed

# ---- stage 3: runtime ----
FROM node:22-alpine AS runtime
ENV NODE_ENV=production \
    PORT=3000
WORKDIR /app

# The runtime only needs "node". npm, npx, corepack and yarn ship in the base
# image and carry their own dependency CVEs (Trivy found 10 HIGH in npm's
# bundled packages), so they are removed from the final image.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
           /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
           /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg

# BuildKit only builds stages the final stage depends on. Copying the marker
# file forces the test stage to run: if the tests fail, the image is not built.
COPY --from=test /app/.tests-passed /tmp/.tests-passed

COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node package.json ./
COPY --chown=node:node src ./src

# Run as the unprivileged "node" user (uid 1000) that the base image provides.
USER node
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "src/server.js"]
