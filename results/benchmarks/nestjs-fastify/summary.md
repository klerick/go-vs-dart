# nestjs-fastify — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1034 | 233 | 54 |
| 50| 1173 | 283 | 81 |
| 100| 1130 | 268 | 105 |
| 500| 1080 | 256 | 97 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 12.6 | 90.6 | 303.8 |
| 50| 59.0 | 282.5 | 1193.1 |
| 100| 136.9 | 600.2 | 1405.4 |
| 500| 597.8 | 2409.6 | 12420.4 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 39Mi | 36Mi | 32Mi |
| 50| 40Mi | 39Mi | 39Mi |
| 100| 41Mi | 40Mi | 39Mi |
| 500| 47Mi | 45Mi | 42Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 939m | 250m | 100m |
| 50| 993m | 251m | 100m |
| 100| 998m | 250m | 100m |
| 500| 995m | 250m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 26Mi |
| 250m | 26Mi |
| 100m | 26Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 47Mi | 28Mi | 28Mi | 29Mi | 29Mi | 29Mi | 0 |
| 250m | 46Mi | 28Mi | 28Mi | 28Mi | 29Mi | 29Mi | 0 |
| 100m | 44Mi | 30Mi | 25Mi | 26Mi | 26Mi | 27Mi | 3 |
