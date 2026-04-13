# axum — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 618 | 650 | 313 |
| 50| 1368 | 949 | 384 |
| 100| 1410 | 961 | 398 |
| 500| 1519 | 1013 | 393 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 21.6 | 20.6 | 65.0 |
| 50| 46.4 | 76.5 | 186.7 |
| 100| 81.7 | 117.0 | 294.5 |
| 500| 352.4 | 508.8 | 1302.4 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 10Mi | 5Mi | 6Mi |
| 50| 3Mi | 3Mi | 3Mi |
| 100| 4Mi | 4Mi | 4Mi |
| 500| 16Mi | 16Mi | 15Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 204m | 207m | 95m |
| 50| 366m | 248m | 101m |
| 100| 369m | 248m | 100m |
| 500| 370m | 251m | 101m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 0Mi |
| 250m | 0Mi |
| 100m | 0Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 15Mi | 12Mi | 12Mi | 10Mi | 10Mi | 10Mi | 0 |
| 250m | 15Mi | 11Mi | 11Mi | 11Mi | 11Mi | 11Mi | 0 |
| 100m | 16Mi | 13Mi | 13Mi | 13Mi | 13Mi | 13Mi | 0 |
