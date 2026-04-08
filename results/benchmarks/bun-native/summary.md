# bun-native — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1302 | 440 | 125 |
| 50| 1518 | 577 | 148 |
| 100| 1626 | 639 | 210 |
| 500| 1769 | 825 | 172 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 14.4 | 80.3 | 160.3 |
| 50| 58.1 | 105.2 | 465.4 |
| 100| 97.4 | 200.7 | 598.4 |
| 500| 408.9 | 794.3 | 2599.7 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 21Mi | 21Mi | 18Mi |
| 50| 36Mi | 29Mi | 34Mi |
| 100| 83Mi | 41Mi | 36Mi |
| 500| 85Mi | 55Mi | 40Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 723m | 250m | 100m |
| 50| 717m | 251m | 100m |
| 100| 685m | 250m | 99m |
| 500| 699m | 250m | 99m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 6Mi |
| 250m | 6Mi |
| 100m | 6Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 65Mi | 14Mi | 14Mi | 14Mi | 14Mi | 14Mi | 0 |
| 250m | 34Mi | 15Mi | 15Mi | 15Mi | 15Mi | 15Mi | 0 |
| 100m | 6Mi | 6Mi | 6Mi | 6Mi | 6Mi | 6Mi | 1 |
