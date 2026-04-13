# actix — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 624 | 650 | 289 |
| 50| 1344 | 864 | 343 |
| 100| 1443 | 869 | 349 |
| 500| 1514 | 898 | 349 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 20.4 | 24.4 | 80.0 |
| 50| 47.3 | 82.8 | 194.0 |
| 100| 80.4 | 149.8 | 305.9 |
| 500| 350.2 | 584.9 | 1486.4 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 7Mi | 9Mi | 12Mi |
| 50| 8Mi | 8Mi | 8Mi |
| 100| 9Mi | 9Mi | 9Mi |
| 500| 18Mi | 17Mi | 16Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 236m | 229m | 99m |
| 50| 393m | 249m | 100m |
| 100| 410m | 249m | 100m |
| 500| 409m | 250m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 1Mi |
| 250m | 1Mi |
| 100m | 1Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 18Mi | 14Mi | 14Mi | 14Mi | 14Mi | 14Mi | 0 |
| 250m | 17Mi | 13Mi | 13Mi | 13Mi | 13Mi | 13Mi | 0 |
| 100m | 16Mi | 12Mi | 12Mi | 12Mi | 12Mi | 12Mi | 0 |
