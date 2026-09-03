# Node.js Hello World
FROM node:20-alpine

WORKDIR /app

# Copy manifest first (better layer caching), then the rest
COPY package.json ./
# No external dependencies, but this is where `npm install` would run
COPY server.js ./

EXPOSE 3000
CMD ["node", "server.js"]
