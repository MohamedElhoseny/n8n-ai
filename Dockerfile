# ---- build stage ----
FROM node:22-bullseye AS build
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 make g++ git ca-certificates pkg-config \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Copy everything so patches/ is present
COPY . .

# (optional) relax engine check if any workspace is strict
ENV PNPM_CONFIG_ENGINE_STRICT=false

# Install & build
RUN pnpm install --frozen-lockfile --config.ignore-scripts=false
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
