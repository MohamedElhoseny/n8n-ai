# ---------- build stage ----------
FROM node:22-bullseye AS build
WORKDIR /app

# Native deps for node-gyp (sqlite3, sharp, etc.) + git
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 python-is-python3 git ca-certificates pkg-config \
    libssl-dev libc6-dev libsqlite3-dev libvips-dev \
  && rm -rf /var/lib/apt/lists/*

# pnpm (n8n uses pnpm workspaces)
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Bring the whole repo so patches/ and workspace files are present
COPY . .

# Env for smoother CI/container installs
ENV PNPM_CONFIG_ENGINE_STRICT=false \
    npm_config_python=python3 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    CI=true \                 # <- skip CI prompts
    LEFTHOOK=0                # <- skip lefthook git-hooks install (no .git in build)

# Install workspace deps and build CLI
RUN pnpm -w install --frozen-lockfile --config.ignore-scripts=false
RUN pnpm --filter @n8n/cli build

# ---------- runtime stage ----------
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production

# Copy built workspace (packages + node_modules)
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# n8n data directory (mounted in Dokploy to persist)
RUN useradd -ms /bin/bash node \
  && mkdir -p /home/node/.n8n \
  && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
