# go-vs-dart

> **Disclaimer**: This repo started as "Go vs Dart" because the original hypothesis was that Dart could be a viable backend runtime — at minimum offering memory savings over Node.js while sharing language with Flutter frontends. Reality hit hard. What began as a two-language comparison turned into a six-runtime benchmark when Dart lost to everything. The name stays as a reminder that expectations should be validated with data, not blog posts.

## What's inside

Identical HTTP API service implemented in 6 runtimes + NestJS framework overhead test:

- **Go** — net/http + pgx + go-redis
- **Node.js** — node:http + pg + redis
- **Dart** — dart:io HttpServer + postgres + ioredis (port)
- **Bun** — node:http compat + pg + redis
- **Deno** — node:http compat + npm:pg + npm:redis
- **.NET 9** — Kestrel minimal API + Npgsql + StackExchange.Redis
- **NestJS** — NestJS + Fastify/Express + pg + ioredis (framework overhead test)

All services implement the same 3 endpoints:
- `POST /orders` — validate JSON, read user from Redis, read product from Postgres, calculate total, insert order, invalidate cache
- `GET /orders/:id` — read order, enrich with user name from Redis + product name from Postgres
- `GET /orders?user_id=X&limit=20` — list orders with JOIN, pagination, user name from Redis

## Results

Full benchmark report: [REPORT.md](REPORT.md). Per-runtime summaries and pairwise comparisons live in [`results/`](results/).

### TL;DR (median across 3 runs, 1000m CPU / 256Mi, 500 VUS)

| Runtime | RPS | Idle | Peak | Recovery (5min) | Restarts |
|---------|-----|------|------|-----------------|----------|
| **Go** | 1656 | **1Mi** | **29Mi** | **8Mi (72%)** | 0 |
| Bun (native) | **1769** | 6Mi | 85Mi | 14Mi (84%) | 0 |
| Node.js | 1321 | 18Mi | 39Mi | 22Mi (44%) | 0 |
| .NET 9 (Kestrel) | 1277 | 78Mi | 113Mi | 107Mi (5%) | 0 |
| Bun (npm pg+redis) | 1419 | 22Mi | 89Mi | 49Mi (45%) | 0 |
| Deno (npm pg+redis) | 1105 | 28Mi | 86Mi | 70Mi (19%) | 0 |
| Deno (native deno-postgres+redis) | 1015 | 29Mi | 68Mi | 51Mi (25%) | 0 |
| Dart (redis 3.1.0) | 741 | 3Mi | 39Mi | 37Mi (5%) | 0 |
| Dart (ioredis port) | 792 | 3Mi | 39Mi | 37Mi (5%) | 0 |
| NestJS + Fastify | 1198 | 28Mi | 47Mi | 28Mi (40%) | 0 |
| NestJS + Express | 689 | 25Mi | 49Mi | 25Mi (49%) | 0 |

> "Recovery" = memory measured 5 minutes after the 500 VUS run finished. Percentage = portion of peak that was returned.
>
> On `100m` CPU + 500 VUS (deliberate stress test): **Bun native** and **NestJS** (both adapters) are killed by kubelet via liveness probe. Go, Node.js, Dart all stable. See [REPORT.md](REPORT.md) for details.

## Prerequisites

- Kubernetes cluster (tested on Talos k8s, ARM64)
- Docker with buildx (for multi-arch builds)
- Container registry (set `REGISTRY` env var)
- k6 (`brew install k6`)
- kubectl configured

## Quick Start

### 1. Set your registry

```bash
export REGISTRY=your-registry.example.com/library
```

### 2. Build and push images

```bash
# All services
for svc in go-service dart-service node-service bun-service deno-service dotnet-service nestjs-service; do
  docker buildx build --platform linux/arm64 \
    -t $REGISTRY/${svc%-service}-bench:latest \
    --push $svc/
done

# Or use the script (builds Go and Dart only)
./scripts/build-push.sh
```

### 3. Deploy infrastructure

```bash
# Create namespace + Postgres + Redis
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres.yaml -f k8s/redis.yaml

# Wait for ready
kubectl -n bench rollout status deployment/postgres --timeout=120s
kubectl -n bench rollout status deployment/redis --timeout=120s

# Seed data (100 users in Redis + 100k orders in Postgres)
kubectl apply -f k8s/seed-job.yaml
kubectl -n bench wait --for=condition=complete job/seed-data --timeout=120s
```

### 4. Deploy a service

```bash
# Update image registry in manifests first
# Then deploy (example: Go)
kubectl apply -f k8s/go-service.yaml
kubectl -n bench rollout status deployment/go-service --timeout=120s
```

### 5. Run benchmark

```bash
# Port forward
kubectl -n bench port-forward svc/go-service 9090:8080 &

# Run k6
k6 run -e BASE_URL=http://localhost:9090 -e VUS=100 bench/k6-bench.js
```

### 6. Reset data between runs

```bash
kubectl -n bench delete job reset-data --ignore-not-found
kubectl apply -f k8s/reset-job.yaml
kubectl -n bench wait --for=condition=complete job/reset-data --timeout=120s
```

## Project Structure

```
.
├── go-service/          # Go implementation
├── node-service/        # Node.js raw implementation
├── dart-service/        # Dart implementation (with ioredis port)
├── bun-service/         # Bun implementation (same code as Node)
├── deno-service/        # Deno implementation
├── dotnet-service/      # .NET 9 implementation
├── nestjs-service/      # NestJS + Fastify (framework overhead test)
├── k8s/                 # Kubernetes manifests
│   ├── namespace.yaml
│   ├── postgres.yaml    # Postgres + init SQL (100 products)
│   ├── redis.yaml
│   ├── seed-job.yaml    # Seeds 100 users in Redis + 100k orders
│   ├── reset-job.yaml   # Resets orders to 100k between runs
│   └── *-service.yaml   # Service deployments
├── bench/
│   └── k6-bench.js      # k6 load test (50% GET single, 30% GET list, 20% POST)
├── scripts/
│   ├── build-push.sh    # Build and push images
│   ├── deploy.sh        # Deploy full stack
│   └── run-bench.sh     # Automated benchmark runner
└── results/
    └── REPORT.md        # Full benchmark report with analysis
```

## Notes

- All services pinned to same node (`nodeSelector`) for fair comparison
- Postgres and Redis on separate node (realistic network topology)
- CPU throttled via k8s resource limits, memory fixed at 256Mi
- k6 runs from host machine via port-forward (same overhead for all)
- Each service uses connection pool of 10 for Postgres
- Redis: Go uses pool(10), others use single multiplexed connection (idiomatic for each runtime)

## Adding a new runtime / service

Want to compare your favorite runtime? PRs welcome. The bar:

### Rules

1. **Raw HTTP only** — no frameworks, no routers, no middleware libraries. Use the runtime's native/standard HTTP server (`net/http`, `node:http`, `dart:io HttpServer`, `Bun.serve`, `Deno.serve`, Kestrel minimal API, etc).
2. **Standard PostgreSQL and Redis clients** — whatever the majority of real projects in that ecosystem use. No exotic experimental forks. Native bindings allowed if they ship with the runtime (`bun:sql`, `deno-postgres`, etc).
3. **Connection pool of 10 for Postgres**, idiomatic Redis client (single multiplexed connection or small pool — whatever is the standard for that runtime).
4. **Same business logic** — copy `node-service/server.mjs` or `go-service/main.go` and translate. Same endpoints, same SQL, same Redis keys, same response shapes. Don't optimize, don't simplify, don't restructure.
5. **Image must run on `linux/arm64`** (RPi5 cluster). Multi-arch is fine but arm64 is mandatory.
6. **Tag your image** as `your-registry/<name>-bench:v1`.

### Checklist for the PR

- [ ] `<name>-service/` directory with sources, Dockerfile and any runtime-specific config
- [ ] `k8s/<name>-service.yaml` deployment + service manifest (use existing ones as template — same `nodeSelector`, same `port`, same `resources`)
- [ ] Smoke-test all 3 endpoints locally and confirm they return identical JSON shapes to `node-service`
- [ ] Run `./scripts/bench-one.sh <name>-service <name>-bench:v1 results/benchmarks/<name> 1000m` for at least 1000m CPU
- [ ] Include the generated `results/benchmarks/<name>/` in the PR (raw CSVs + the auto-generated `summary.md` from `./scripts/generate-summary.sh <name>`)
- [ ] Add a row to the TL;DR table in this README

### What we will NOT accept

- Custom HTTP framework or "high-performance HTTP library written by the runtime author"
- Hand-rolled SQL protocol implementation just to win the benchmark
- Pre-warmed JIT, pinned CPUs, special k6 sequences, custom probes — anything that's not in the existing services
- "It's faster if you set this magic env var" — set it in the `Dockerfile`/manifest, then it's reproducible. Otherwise no.
- Optimizations that don't exist in real-world apps that use this runtime

The goal is to measure **what an average developer using this runtime would actually get in production**, not the theoretical maximum a runtime author can squeeze out.
