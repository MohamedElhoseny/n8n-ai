# ---------- BUILD STAGE ----------
FROM node:22-bullseye AS build
WORKDIR /app

# Native deps for node-gyp (sqlite3, sharp/libvips), git, etc.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 python-is-python3 git ca-certificates pkg-config \
    libssl-dev libc6-dev libsqlite3-dev libvips-dev \
  && rm -rf /var/lib/apt/lists/*

# pnpm for the monorepo
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Bring the whole repo (patches/, turbo.json, workspaces, etc.)
COPY . .

# CI-friendly install; skip git hooks; force community build
ENV LEFTHOOK=0 \
    CI=true \
    PNPM_CONFIG_ENGINE_STRICT=false \
    npm_config_python=python3 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    N8N_RELEASE_TYPE=community \
    TURBO_TELEMETRY_DISABLED=1

# 1) Install ALL workspace deps
RUN pnpm install --frozen-lockfile

# 2) Increase Node heap + serialize Turbo to avoid OOM in big frontend packages
ENV NODE_OPTIONS="--max-old-space-size=6144"
RUN pnpm -w turbo run build --concurrency=1

# ---------- RUNTIME STAGE ----------
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production

# Copy built workspace
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# Ensure data dir exists (you’ll mount this in Dokploy)
RUN mkdir -p /home/node/.n8n && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
