FROM oven/bun:1-alpine AS builder

WORKDIR /app
COPY package.json ./
RUN bun install --production

FROM oven/bun:1-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY server.mjs ./
USER bun
ENTRYPOINT ["bun", "run", "server.mjs"]
