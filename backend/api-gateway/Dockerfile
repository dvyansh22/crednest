# ── Stage 1: deps ────────────────────────────────────────────────────────────
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# ── Stage 2: build (nothing to compile — pure JS, but good practice) ─────────
FROM node:20-alpine AS runner
WORKDIR /app

# Create non-root user
RUN addgroup -S crednest && adduser -S crednest -G crednest

# Copy deps and source
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Vault storage dir — will be mounted as a volume in production
RUN mkdir -p ./vault_storage && chown -R crednest:crednest ./vault_storage

# Drop to non-root
USER crednest

ENV NODE_ENV=production
EXPOSE 4000

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:4000/health || exit 1

CMD ["node", "src/index.js"]
