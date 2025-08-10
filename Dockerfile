# ---- build stage ----
FROM node:22-bullseye AS build
WORKDIR /app

# Native deps for node-gyp, sqlite3, sharp(libvips), git
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential python3 python-is-python3 git ca-certificates pkg-config \
    libssl-dev libc6-dev libsqlite3-dev libvips-dev \
  && rm -rf /var/lib/apt/lists/*

# pnpm
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# bring the whole repo (ensures patches/ is present)
COPY . .

# helpful envs
ENV PNPM_CONFIG_ENGINE_STRICT=false
ENV npm_config_python=python3
ENV PUPPETEER_SKIP_DOWNLOAD=1

# ---- install with FULL logs (workspace/root)
RUN pnpm -w install --frozen-lockfile --config.ignore-scripts=false

# build CLI
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
