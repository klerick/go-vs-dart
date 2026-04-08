# nestjs-express — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 719 | 159 | 39 |
| 50| 738 | 179 | 48 |
| 100| 725 | 178 | 68 |
| 500| 690 | 168 | 65 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 18.5 | 99.7 | 495.3 |
| 50| 106.0 | 494.1 | 2121.7 |
| 100| 196.0 | 809.3 | 2017.2 |
| 500| 908.2 | 3892.0 | 28584.7 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 40Mi | 39Mi | 36Mi |
| 50| 41Mi | 40Mi | 39Mi |
| 100| 42Mi | 41Mi | 39Mi |
| 500| 49Mi | 47Mi | 43Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 994m | 251m | 100m |
| 50| 1000m | 250m | 100m |
| 100| 999m | 251m | 100m |
| 500| 999m | 251m | 100m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 25Mi |
| 250m | 25Mi |
| 100m | 25Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 49Mi | 28Mi | 29Mi | 30Mi | 30Mi | 30Mi | 0 |
| 250m | 48Mi | 28Mi | 29Mi | 30Mi | 30Mi | 30Mi | 0 |
| 100m | 44Mi | 28Mi | 25Mi | 26Mi | 27Mi | 27Mi | 3 |
