# dart-redis310 — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 774 | 191 | 70 |
| 50| 825 | 205 | 72 |
| 100| 799 | 208 | 77 |
| 500| 741 | 187 | 67 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 16.7 | 92.7 | 199.4 |
| 50| 79.8 | 306.8 | 913.0 |
| 100| 165.2 | 613.2 | 1602.6 |
| 500| 850.4 | 3395.1 | 9499.3 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 37Mi | 43Mi | 44Mi |
| 50| 37Mi | 44Mi | 44Mi |
| 100| 38Mi | 44Mi | 45Mi |
| 500| 39Mi | 48Mi | 47Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 992m | 250m | 100m |
| 50| 998m | 250m | 100m |
| 100| 999m | 250m | 101m |
| 500| 998m | 250m | 100m |

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
| 250m | 47Mi | 44Mi | 44Mi | 44Mi | 44Mi | 44Mi | 0 |
| 100m | 46Mi | 45Mi | 45Mi | 45Mi | 45Mi | 45Mi | 0 |
