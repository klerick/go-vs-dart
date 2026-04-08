# bun-npm — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1182 | 276 | 75 |
| 50| 1380 | 340 | 72 |
| 100| 1413 | 365 | 91 |
| 500| 1414 | 366 | 88 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 13.2 | 91.1 | 292.7 |
| 50| 55.6 | 200.8 | 937.2 |
| 100| 96.3 | 389.3 | 1520.0 |
| 500| 445.2 | 1706.4 | 7897.9 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 69Mi | 62Mi | 54Mi |
| 50| 76Mi | 78Mi | 74Mi |
| 100| 79Mi | 84Mi | 75Mi |
| 500| 89Mi | 86Mi | 77Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 866m | 248m | 99m |
| 50| 872m | 251m | 99m |
| 100| 871m | 250m | 100m |
| 500| 874m | 250m | 99m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 22Mi |
| 250m | 22Mi |
| 100m | 22Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 89Mi | 72Mi | 52Mi | 52Mi | 52Mi | 52Mi | 0 |
| 250m | 84Mi | 69Mi | 69Mi | 47Mi | 47Mi | 47Mi | 0 |
| 100m | 67Mi | 70Mi | 47Mi | 47Mi | 47Mi | 47Mi | 0 |
