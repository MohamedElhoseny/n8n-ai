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

# Env to make installs deterministic in CI and to SKIP lefthook hooks
ENV PNPM_CONFIG_ENGINE_STRICT=false \
    npm_config_python=python3 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    CI=true \
    LEFTHOOK=0

# Install workspace deps (scripts enabled; lefthook disabled by env above)
RUN pnpm -w install --frozen-lockfile --config.ignore-scripts=false --loglevel=verbose

# Build the CLI package (workspaces aware)
# If your pnpm version ever complains, the fallback builds directly in the package dir.
RUN pnpm -w --filter "@n8n/cli" build || pnpm --dir packages/cli build

# ---------- runtime stage ----------
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production

# Copy built workspace (packages + node_modules)
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# Ensure data dir exists; DO NOT add the user (already present)
RUN mkdir -p /home/node/.n8n && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
