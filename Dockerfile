# Use Node.js LTS base image
FROM node:20-bullseye

# Install required system dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    build-essential \
 && rm -rf /var/lib/apt/lists/*

# Enable Corepack and prepare pnpm
RUN corepack enable && corepack prepare pnpm@10.12.1 --activate

# Env for smoother CI/container installs
ENV PNPM_CONFIG_ENGINE_STRICT=false \
    npm_config_python=python3 \
    PUPPETEER_SKIP_DOWNLOAD=1 \
    CI=true \
    LEFTHOOK=0

# Set working directory
WORKDIR /app

# Copy package files first for better build cache
COPY package.json pnpm-lock.yaml* ./

# Install dependencies without running postinstall hooks
RUN pnpm install --frozen-lockfile --config.ignore-scripts=true --reporter=append-only

# Copy all project files
COPY . .

# Build the project (optional – only if you need a build step)
# RUN pnpm run build

# Expose port (update if needed)
EXPOSE 3000

# Start the application
CMD ["pnpm", "start"]
