# ---- build stage ----
FROM node:22-bullseye AS build
WORKDIR /app

# System deps for node-gyp/native modules + git
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git ca-certificates pkg-config \
  && rm -rf /var/lib/apt/lists/*

# Use pnpm
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Improve caching: fetch deps first, then copy source
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
# Some workspaces also need the top-level 'packages/*/package.json' for fetch;
# if fetch complains, comment the line above and just copy everything early.
RUN pnpm fetch

# Now copy the whole repo
COPY . .

# Loosen engine check just in case some workspace enforces >=22.16 strictly
ENV PNPM_CONFIG_ENGINE_STRICT=false

# Install and build
RUN pnpm install --frozen-lockfile --config.ignore-scripts=false
RUN pnpm --filter @n8n/cli build

# ---- runtime ----
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production

# Copy runtime bits
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# n8n data dir
RUN useradd -ms /bin/bash node \
  && mkdir -p /home/node/.n8n \
  && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
