# ---- build stage ----
FROM node:20-bullseye AS build
WORKDIR /app

# Use pnpm (n8n monorepo uses it)
RUN corepack enable && corepack prepare pnpm@9.0.0 --activate

# Install deps & build CLI
COPY . .
RUN pnpm install --frozen-lockfile
RUN pnpm --filter @n8n/cli build

# ---- runtime ----
FROM node:20-bullseye
WORKDIR /app
ENV NODE_ENV=production

# copy only what runtime needs
COPY --from=build /app/packages /app/packages
COPY --from=build /app/node_modules /app/node_modules

# n8n data lives here (credentials, workflows)
RUN useradd -ms /bin/bash node \
  && mkdir -p /home/node/.n8n \
  && chown -R node:node /home/node
USER node

EXPOSE 5678
CMD ["node", "packages/cli/dist/main.js"]
