# ---- build stage ----
FROM node:22-bullseye AS build
WORKDIR /app

# Native deps for node-gyp (sqlite3, etc.) + git
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 python-is-python3 git ca-certificates pkg-config \
    libssl-dev libc6-dev libsqlite3-dev \
  && rm -rf /var/lib/apt/lists/*

# Use pnpm
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Copy repo (ensure patches/ is included)
COPY . .

# Relax engine strictness if any workspace enforces it
ENV PNPM_CONFIG_ENGINE_STRICT=false
# Help node-gyp find python
ENV npm_config_python=python3

# Install deps (show debug log on failure)
RUN pnpm install --frozen-lockfile --config.ignore-scripts=false --reporter=append-only \
  || (echo "---- pnpm debug log ----" && cat /root/.pnpm-debug.log || true && exit 1)

# Build CLI
RUN pnpm --filter @n8n/cli build

# ---- runtime ----
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules
RUN useradd -ms /bin/bash node && mkdir -p /home/node/.n8n && chown -R node:node /home/node
USER node
EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
