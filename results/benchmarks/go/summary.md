# go — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1446 | 517 | 200 |
| 50| 1627 | 566 | 215 |
| 100| 1628 | 573 | 215 |
| 500| 1656 | 571 | 209 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 10.4 | 74.1 | 96.8 |
| 50| 42.0 | 108.4 | 301.3 |
| 100| 80.6 | 213.5 | 598.6 |
| 500| 376.7 | 1099.4 | 2899.5 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 8Mi | 9Mi | 9Mi |
| 50| 9Mi | 9Mi | 9Mi |
| 100| 11Mi | 11Mi | 10Mi |
| 500| 29Mi | 29Mi | 28Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 636m | 251m | 100m |
| 50| 644m | 250m | 100m |
| 100| 650m | 251m | 101m |
| 500| 647m | 250m | 101m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 1Mi |
| 250m | 1Mi |
| 100m | 1Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 29Mi | 24Mi | 24Mi | 16Mi | 16Mi | 8Mi | 0 |
| 250m | 29Mi | 23Mi | 23Mi | 14Mi | 14Mi | 8Mi | 0 |
| 100m | 28Mi | 25Mi | 25Mi | 15Mi | 15Mi | 9Mi | 0 |
