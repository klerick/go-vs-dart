# deno-native — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 983 | 246 | 93 |
| 50| 1058 | 250 | 94 |
| 100| 1056 | 252 | 93 |
| 500| 1009 | 233 | 88 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 14.0 | 89.3 | 193.8 |
| 50| 61.2 | 288.2 | 700.1 |
| 100| 116.3 | 498.1 | 1368.9 |
| 500| 528.6 | 2294.9 | 6196.1 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 59Mi | 59Mi | 56Mi |
| 50| 62Mi | 64Mi | 63Mi |
| 100| 63Mi | 65Mi | 63Mi |
| 500| 68Mi | 67Mi | 67Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 966m | 250m | 100m |
| 50| 992m | 251m | 100m |
| 100| 993m | 250m | 100m |
| 500| 997m | 250m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 29Mi |
| 250m | 29Mi |
| 100m | 28Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 68Mi | 66Mi | 64Mi | 64Mi | 64Mi | 64Mi | 0 |
| 250m | 67Mi | 66Mi | 66Mi | 53Mi | 52Mi | 52Mi | 0 |
| 100m | 67Mi | 67Mi | 67Mi | 67Mi | 67Mi | 67Mi | 0 |
