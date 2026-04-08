FROM node:22-alpine AS builder

WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev

FROM node:22-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY server.mjs ./
USER node
ENTRYPOINT ["node", "server.mjs"]
