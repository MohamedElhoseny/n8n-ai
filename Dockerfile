# ---- build stage ----
FROM node:22-bullseye AS build
WORKDIR /app

# Use pnpm (n8n uses it)
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Install deps & build CLI
COPY . .
# If you ever need to bypass engines (not recommended):
# ENV npm_config_engine_strict=false
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @n8n/cli build

# ---- runtime ----
FROM node:22-bullseye
WORKDIR /app
ENV NODE_ENV=production

# Copy built workspace
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# n8n data dir
RUN useradd -ms /bin/bash node \
  && mkdir -p /home/node/.n8n \
  && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
