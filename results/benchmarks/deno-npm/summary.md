# deno-npm — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 913 | 234 | 79 |
| 50| 1146 | 292 | 103 |
| 100| 1121 | 283 | 99 |
| 500| 1102 | 267 | 96 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 15.4 | 88.7 | 198.9 |
| 50| 69.9 | 302.8 | 801.7 |
| 100| 130.8 | 581.3 | 1500.2 |
| 500| 572.6 | 2305.8 | 6499.2 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 76Mi | 75Mi | 76Mi |
| 50| 79Mi | 77Mi | 79Mi |
| 100| 81Mi | 79Mi | 80Mi |
| 500| 88Mi | 88Mi | 84Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 972m | 250m | 100m |
| 50| 976m | 251m | 100m |
| 100| 990m | 250m | 100m |
| 500| 993m | 250m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 28Mi |
| 250m | 27Mi |
| 100m | 28Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 88Mi | 70Mi | 70Mi | 70Mi | 71Mi | 71Mi | 0 |
| 250m | 88Mi | 70Mi | 70Mi | 71Mi | 71Mi | 71Mi | 0 |
| 100m | 84Mi | 71Mi | 71Mi | 71Mi | 72Mi | 72Mi | 0 |
