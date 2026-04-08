# node — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1177 | 289 | 84 |
| 50| 1350 | 369 | 134 |
| 100| 1336 | 354 | 134 |
| 500| 1321 | 337 | 128 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 12.1 | 57.8 | 295.9 |
| 50| 51.8 | 193.9 | 499.3 |
| 100| 105.7 | 402.3 | 1096.0 |
| 500| 483.5 | 1896.0 | 4992.6 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 25Mi | 24Mi | 23Mi |
| 50| 33Mi | 32Mi | 29Mi |
| 100| 34Mi | 33Mi | 33Mi |
| 500| 39Mi | 38Mi | 37Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 923m | 250m | 100m |
| 50| 946m | 250m | 100m |
| 100| 982m | 251m | 100m |
| 500| 981m | 251m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 18Mi |
| 250m | 18Mi |
| 100m | 18Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 39Mi | 21Mi | 21Mi | 21Mi | 22Mi | 22Mi | 0 |
| 250m | 38Mi | 36Mi | 21Mi | 21Mi | 21Mi | 22Mi | 0 |
| 100m | 37Mi | 20Mi | 20Mi | 21Mi | 21Mi | 21Mi | 0 |
