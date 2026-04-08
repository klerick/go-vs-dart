FROM denoland/deno:latest

WORKDIR /app
COPY server.mjs ./

# Cache npm dependencies
RUN deno install --entrypoint server.mjs

USER deno
ENTRYPOINT ["deno", "run", "--allow-net", "--allow-env", "--allow-read", "--allow-sys", "server.mjs"]
