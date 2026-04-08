# dart-ioredis — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 801 | 188 | 70 |
| 50| 871 | 214 | 75 |
| 100| 842 | 213 | 76 |
| 500| 778 | 189 | 66 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 16.1 | 92.2 | 198.8 |
| 50| 77.1 | 301.6 | 895.7 |
| 100| 161.2 | 623.0 | 1701.4 |
| 500| 816.9 | 3408.0 | 9676.7 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 38Mi | 42Mi | 44Mi |
| 50| 38Mi | 42Mi | 44Mi |
| 100| 38Mi | 43Mi | 45Mi |
| 500| 39Mi | 46Mi | 47Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 992m | 250m | 100m |
| 50| 996m | 250m | 100m |
| 100| 997m | 250m | 101m |
| 500| 997m | 250m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 3Mi |
| 250m | 3Mi |
| 100m | 3Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 39Mi | 37Mi | 37Mi | 37Mi | 37Mi | 37Mi | 0 |
| 250m | 46Mi | 42Mi | 42Mi | 42Mi | 42Mi | 42Mi | 0 |
| 100m | 46Mi | 44Mi | 44Mi | 44Mi | 44Mi | 44Mi | 0 |
