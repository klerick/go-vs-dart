# Runtime Benchmark Report

> **About this repo**: Started as "Go vs Dart" — turned into a 6-runtime + framework comparison after the original hypothesis (Dart as a viable backend runtime) collapsed against real numbers. The name stays as a reminder.

A benchmark of HTTP web service runtimes under realistic Kubernetes constraints — fixed memory, throttled CPU, real Postgres + Redis on a separate node, no service mesh, no fancy networking.

**All numbers are median across 3 runs.** See [methodology](#methodology) below.

## TL;DR

- **Go** is the safest choice — fastest, lowest memory, fully recovers memory, never crashes under any throttling
- **Bun (native APIs)** is the surprise — competitive with Go on `1000m`/`250m` CPU, sometimes even faster, but **liveness probe killing** under `100m` stress
- **Node.js** is the boring reliable middle — close to Go on `1000m`, predictable everywhere
- **Dart** loses on every metric — slower, never returns memory, fragile ecosystem
- **.NET** works *now* (after rewriting our HttpListener attempt to Kestrel) but requires understanding CoreCLR internals
- **Deno** offers no advantage over Node — same V8, more memory, slower
- **NestJS** is fine on `1000m`/`250m` (DI overhead is ~0% on Fastify, ~37% on Express). On `100m` — **dies on liveness probes**, regardless of adapter

## Comparisons

### Main story

- [**go vs node vs dart-redis310**](results/comparisons/go_vs_node_vs_dart-redis310.md) — the original three-way fight that started this whole thing. Dart loses everywhere.
- [**go vs node vs bun-native vs dotnet**](results/comparisons/go_vs_node_vs_bun-native_vs_dotnet.md) — full picture of viable backend runtimes.

### Bun deep dive

- [**go vs bun-native**](results/comparisons/go_vs_bun-native.md) — Bun's native APIs (Bun.serve + bun:sql + Bun RedisClient) actually compete with Go.
- [**bun-native vs bun-npm vs node**](results/comparisons/bun-native_vs_bun-npm_vs_node.md) — does just running your Node code on Bun help? **No**. You need to rewrite to native APIs.

#### Bun under heavy throttling — non-deterministic liveness probe killing

On `100m` CPU + 500 VUS, Bun (native APIs) shows non-deterministic behavior:

- **Run 1**: pod killed by kubelet (`Liveness probe failed: context deadline exceeded`) → restart count = 1
- **Run 2 (re-run from scratch)**: 3 runs in a row, only 1 of them killed via liveness probe (others completed normally). ~33% failure rate.
- **No consistent pattern** — same image, same data, same load, same node, same kubelet probe config (`timeoutSeconds: 1`, `failureThreshold: 3`)

What it looks like: under sustained heavy load, JSC's GC heuristics occasionally fall into a "bad mode" where the event loop is busy enough that the `/health` endpoint can't respond within 1 second. After 3 misses, kubelet sends SIGTERM mid-flight. Container exits cleanly (`Exit Code: 0`, `Reason: Completed`) — there is no OOMKill, no error in the application logs. From the application's perspective, **nothing is wrong** — it just got killed.

This is worse than a stable failure: it's a **time bomb** in production that's nearly impossible to debug. Logs are clean. Metrics show "running" until the moment kubelet kills it. The cause isn't visible from inside the container — only from `kubectl describe pod` events.

Go is immune to this because the goroutine scheduler guarantees forward progress on the `/health` handler regardless of how busy other goroutines are. JS-style runtimes (Bun, Node, Deno, NestJS) are vulnerable when the event loop gets blocked under throttling.

**Important**: this was only reproduced on `100m` CPU (a deliberate stress test, not a real production profile). On `250m`+ all 3 runs completed without any restarts.

### Deno

- [**deno-native vs deno-npm vs node**](results/comparisons/deno-native_vs_deno-npm_vs_node.md) — Deno's native deno-postgres / deno-redis are *worse* than npm versions. And neither beats Node.

### Dart Redis clients

- [**dart-redis310 vs dart-ioredis**](results/comparisons/dart-redis310_vs_dart-ioredis.md) — comparison of the only living Redis client on pub.dev (`redis` 3.1.0) vs an AI-written port of ioredis. Native port is ~5% faster, but the bottleneck is the Dart VM itself.

#### Dart VM Memory Investigation

Memory peak under load is fine — comparable to Node.js. The problem is **memory recovery after load**: the Dart VM never returns heap pages to the OS. Every GC flag combination was tried, none worked:

| Configuration | Peak | After 5min | Returned? |
|---------------|------|------------|-----------|
| Default (`scratch` image, no flags) | 39Mi | 37Mi | No (5%) |
| `--dontneed_on_sweep=true` | 39Mi | 38Mi | No |
| `--use_compactor=true --force_evacuation=true` | 39Mi | 37Mi | No |
| `--mark_when_idle=true` + all GC flags | 39Mi | 37Mi | No |
| Alpine base + `gcompat` + `MALLOC_TRIM_THRESHOLD_=131072` | 39Mi | 37Mi | No |
| `cgroup memory.limit = 40Mi` (force pressure) | 38Mi | OOMKill → restart at 7Mi | Restart only |

Root cause is **by design**, confirmed by the Dart VM team in [dart-lang/sdk#51126](https://github.com/dart-lang/sdk/issues/51126):

- Old space is organized in pages — if even one live object is on a page, the whole page is retained
- Mark-compact only runs when the VM is idle **and** the estimated compaction time is below `--idle_duration_micros`
- `madvise(MADV_DONTNEED)` marks pages as reclaimable but Linux doesn't actually reclaim them without memory pressure
- The VM never calls `munmap` — RSS stays permanently inflated

This is a deliberate trade-off: the Dart VM is optimized for Flutter (minimal GC pauses for 60fps animations), not for servers (minimal RSS for k8s pod packing). For mobile this is correct; for backend it's a deal-breaker. In Kubernetes you must size pod limits by peak memory, not by idle, which negates the AOT advantage of a small initial footprint.

### NestJS framework cost

- [**nestjs-fastify vs nestjs-express**](results/comparisons/nestjs-fastify_vs_nestjs-express.md) — Fastify gives ~60% more RPS over Express in a NestJS app. But both die on `100m` CPU + 500 VUS via liveness probe killing.

## Per-service summaries

Each runtime has its own page with all CPU profiles tested:

| Service | Page |
|---------|------|
| Go | [results/benchmarks/go/summary.md](results/benchmarks/go/summary.md) |
| Node.js | [results/benchmarks/node/summary.md](results/benchmarks/node/summary.md) |
| Bun (native APIs) | [results/benchmarks/bun-native/summary.md](results/benchmarks/bun-native/summary.md) |
| Bun (npm pg/redis) | [results/benchmarks/bun-npm/summary.md](results/benchmarks/bun-npm/summary.md) |
| Deno (native deno-postgres/redis) | [results/benchmarks/deno-native/summary.md](results/benchmarks/deno-native/summary.md) |
| Deno (npm pg/redis) | [results/benchmarks/deno-npm/summary.md](results/benchmarks/deno-npm/summary.md) |
| Dart (redis 3.1.0) | [results/benchmarks/dart-redis310/summary.md](results/benchmarks/dart-redis310/summary.md) |
| Dart (ioredis port) | [results/benchmarks/dart-ioredis/summary.md](results/benchmarks/dart-ioredis/summary.md) |
| .NET 9 (Kestrel + Npgsql) | [results/benchmarks/dotnet/summary.md](results/benchmarks/dotnet/summary.md) |
| NestJS + Fastify | [results/benchmarks/nestjs-fastify/summary.md](results/benchmarks/nestjs-fastify/summary.md) |
| NestJS + Express | [results/benchmarks/nestjs-express/summary.md](results/benchmarks/nestjs-express/summary.md) |

> **Disclaimer about .NET**: We are not .NET engineers. The first attempt used `HttpListener` (the closest analog to `dart:io HttpServer` and `net/http`) — it crashed under any load, the runtime barely used 10% of available CPU, and the results were unusable. We then rewrote it as a minimal Kestrel app with `WebApplication.CreateSlimBuilder` + Npgsql + StackExchange.Redis — that's what's measured here. .NET 9 has many GC modes (`DOTNET_gcServer`, `DOTNET_GCHeapCount`), thread pool tuning (`DOTNET_ThreadPool_MinThreads`), and connection pool sizing knobs that we did **not** touch. We probably left performance on the table. If you know how to cook .NET 9 properly for cgroup-limited containers — **PRs welcome**, see the runtime's README for adding/replacing services.

## Methodology

### Environment

- **Cluster**: Talos Linux k8s v1.34.3, 8 nodes (6× Raspberry Pi 5 + 1× VM control-plane + 1× VM worker)
- **Services node** (`your-app-node` in manifests): Raspberry Pi 5, ARM Cortex-A76 4 cores @ 2.4GHz, 8GB RAM
- **DB node** (`your-db-node` in manifests): VM, 4 vCPU, 4GB RAM, separate physical host
- **Network**: 1Gbit Ethernet between nodes, ~0.8ms RTT
- **Topology**: services and DB on different nodes — every Postgres/Redis call is a network hop
- **No NetworkPolicy, no Service Mesh, no sidecars** — pure pod-to-pod via ClusterIP, default Cilium CNI
- **All pods Guaranteed QoS** — `requests == limits`, no CPU pinning
- **No HPA, no VPA, no priority classes**

### Workload

- 3 endpoints, identical logic across all runtimes:
  - `POST /orders` — validate JSON → `GET user:{id}` from Redis → `SELECT product` from Postgres → `INSERT order` → `DEL order_cache:{user_id}` from Redis → return JSON
  - `GET /orders/:id` — `SELECT order` from Postgres → enrich with user from Redis + product from Postgres → return JSON
  - `GET /orders?user_id=X&limit=20` — `SELECT … JOIN products … LIMIT … OFFSET` → enrich with user → return JSON
- **Traffic mix** (k6): 50% GET single, 30% GET list, 20% POST create
- **k6 ramp**: 10s up → 30s sustain → 10s down
- **Pre-seeded data**: 100k orders, 100 products in Postgres, 100 users in Redis
- **Orders table is reset to 100k rows** before every VUS level

### Resource profiles

| Profile | CPU limit | Memory limit |
|---------|-----------|--------------|
| `prod` (1000m) | 1 core | 256Mi |
| `hobby` (250m) | 0.25 core | 256Mi |
| `micro` (100m) | 0.1 core | 256Mi |

Memory limit is **fixed at 256Mi for all profiles** — only CPU is throttled. The point is to compare CPU efficiency under fixed memory.

#### Why 100m? The noisy neighbor scenario

`100m` is not a realistic production CPU limit — nobody intentionally runs a web service on 0.1 core. It's a **stress test that simulates a real-world worst case: the noisy neighbor problem**.

In Kubernetes, your pod may have `requests: 1000m` and `limits: 1000m`, but if the node is overloaded by other pods (especially those without CPU limits — BestEffort QoS), the CFS scheduler throttles everyone. Your pod gets its guaranteed share, but with delays and context-switch overhead that effectively reduce available CPU to a fraction of the limit.

The `100m` profile models exactly this: "what happens when your pod only gets 10% of its requested CPU due to node-level contention?" This is when liveness probes start timing out, event loops stall, and kubelet kills pods that are actually healthy but too slow to respond. In our tests, **Bun native** and **NestJS** (both adapters) were killed this way. **Go, Node.js, and Dart** survived.

If your cluster has mixed QoS classes or occasional resource spikes — this scenario will happen. The `100m` test tells you which runtimes degrade gracefully and which ones crash.

### Run procedure

For each `(service, profile)` combination:

1. Patch deployment → wait for rollout
2. Wait **60 seconds** for runtime stabilization
3. Measure idle memory
4. Run k6 sequentially: **10 → 50 → 100 → 500 VUS**, same pod (no restart between VUS levels — JIT and pools stay warm, like real production)
5. Reset orders table between VUS levels
6. Capture peak memory + CPU after each k6 stage
7. After 500 VUS — wait **5 minutes**, sampling memory every 60 seconds (this is the "recovery" measurement)
8. **Repeat 3 times** (3 runs per profile)
9. **Take median across runs** — robust against the occasional `kubectl top` outlier

### Metrics collection

- **CPU / memory**: `kubectl top pods` (Kubernetes metrics-server)
  - metrics-server polls cAdvisor every 15s and reports a 60s rolling average
  - **Caveat**: occasional outliers possible due to sampling timing; anomalies were always re-checked by re-running the benchmark
- **k6 metrics**: `--summary-export` JSON (RPS, latency p95/avg/max, error rate)
- **Median is preferred over mean**: with 3 runs `[1656, 1643, 1667]` median is `1656`. With one outlier `[1656, 1643, 800]` median is `1643` (true value), mean is `1366` (distorted)

### What we did NOT do

- No `--no-cleanup`, no JIT pre-warming hacks
- No CPU pinning (`cpuset` cgroup)
- No NUMA topology hints
- No HPA / VPA / Vertical scaling experiments
- No CDN / load balancer / edge proxy in front
- No sidecars, no Istio, no Linkerd
- No "tuned for benchmark" configs — each service is the most idiomatic minimal raw HTTP server in its language. Read the source.

### Reproducibility

Everything is in this repo. Build the images, deploy the K8s manifests, run `./scripts/bench-one.sh <service> <image> results/benchmarks/<service> <cpu>`. See [README.md](README.md) for full setup instructions.
