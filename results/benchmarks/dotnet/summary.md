# dotnet — Benchmark Summary

> Median across 3 runs. See raw CSV files in each profile directory.

## RPS (median, higher = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 1103 | 253 | 93 |
| 50| 1269 | 372 | 138 |
| 100| 1291 | 390 | 144 |
| 500| 1304 | 373 | 137 |

## Latency p95 (median ms, lower = better)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 22.2 | 90.3 | 194.2 |
| 50| 68.8 | 196.0 | 494.6 |
| 100| 96.6 | 301.2 | 802.6 |
| 500| 414.1 | 1478.8 | 3898.8 |

## Memory Peak (median Mi)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 106Mi | 49Mi | 48Mi |
| 50| 100Mi | 47Mi | 49Mi |
| 100| 101Mi | 42Mi | 49Mi |
| 500| 112Mi | 54Mi | 53Mi |

## CPU Usage (median, millicores)

| VUS | 1000m | 250m | 100m |
|-----|---|---|---|
| 10| 973m | 246m | 97m |
| 50| 970m | 247m | 98m |
| 100| 951m | 247m | 97m |
| 500| 924m | 248m | 98m |

## Idle Memory (after 60s stabilization)

| Profile | Memory |
|---------|--------|
| 1000m | 78Mi |
| 250m | 25Mi |
| 100m | 25Mi |

## Memory Recovery after 500 VUS (median Mi)

| Profile | Right after | 60s | 120s | 180s | 240s | 300s | Restarts |
|---------|------------|-----|------|------|------|------|----------|
| 1000m | 112Mi | 107Mi | 107Mi | 107Mi | 107Mi | 107Mi | 0 |
| 250m | 54Mi | 53Mi | 53Mi | 49Mi | 49Mi | 49Mi | 0 |
| 100m | 53Mi | 50Mi | 50Mi | 50Mi | 50Mi | 48Mi | 0 |
