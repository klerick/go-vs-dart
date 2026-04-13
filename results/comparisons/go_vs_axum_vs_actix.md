# go vs axum vs actix

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| **1446** | 618 | 624 |
| 50| **1627** | 1368 | 1344 |
| 100| **1628** | 1410 | 1443 |
| 500| **1656** | 1519 | 1514 |

### Latency p95 (ms)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 10.4 | 21.6 | 20.4 |
| 50| 42.0 | 46.4 | 47.3 |
| 100| 80.6 | 81.7 | 80.4 |
| 500| 376.7 | 352.4 | 350.2 |

### Memory Peak (Mi)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 8Mi | 10Mi | **7Mi** |
| 50| 9Mi | **3Mi** | 8Mi |
| 100| 11Mi | **4Mi** | 9Mi |
| 500| 29Mi | **16Mi** | 18Mi |

### CPU usage (millicores)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 636m | 204m | 236m |
| 50| 644m | 366m | 393m |
| 100| 650m | 369m | 410m |
| 500| 647m | 370m | 409m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 1656 | 647m | 256.0 |
| axum | 1519 | 370m | **410.5** |
| actix | 1514 | 409m | 370.2 |

### Memory: idle / peak / recovery (500 VUS)

> **Returned**: how much of the allocated memory above idle was released back. Formula: `(peak - after_300s) / (peak - idle)`. 100% = back to baseline, 0% = nothing released.

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 24Mi | 8Mi | 75% | 0 |
| axum | -Mi | 16Mi | 12Mi | 10Mi | 38% | 0 |
| actix | 1Mi | 18Mi | 14Mi | 14Mi | 24% | 0 |

---

## 250m CPU

### RPS

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 517 | **650** | **650** |
| 50| 566 | **949** | 864 |
| 100| 573 | **961** | 869 |
| 500| 571 | **1013** | 898 |

### Latency p95 (ms)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 74.1 | 20.6 | 24.4 |
| 50| 108.4 | 76.5 | 82.8 |
| 100| 213.5 | 117.0 | 149.8 |
| 500| 1099.4 | 508.8 | 584.9 |

### Memory Peak (Mi)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 9Mi | **5Mi** | 9Mi |
| 50| 9Mi | **3Mi** | 8Mi |
| 100| 11Mi | **4Mi** | 9Mi |
| 500| 29Mi | **16Mi** | 17Mi |

### CPU usage (millicores)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 251m | 207m | 229m |
| 50| 250m | 248m | 249m |
| 100| 251m | 248m | 249m |
| 500| 250m | 251m | 250m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 571 | 250m | 228.4 |
| axum | 1013 | 251m | **403.6** |
| actix | 898 | 250m | 359.2 |

### Memory: idle / peak / recovery (500 VUS)

> **Returned**: how much of the allocated memory above idle was released back. Formula: `(peak - after_300s) / (peak - idle)`. 100% = back to baseline, 0% = nothing released.

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 23Mi | 8Mi | 75% | 0 |
| axum | -Mi | 16Mi | 11Mi | 11Mi | 31% | 0 |
| actix | 1Mi | 17Mi | 13Mi | 13Mi | 25% | 0 |

---

## 100m CPU

### RPS

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 200 | **313** | 289 |
| 50| 215 | **384** | 343 |
| 100| 215 | **398** | 349 |
| 500| 209 | **393** | 349 |

### Latency p95 (ms)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 96.8 | 65.0 | 80.0 |
| 50| 301.3 | 186.7 | 194.0 |
| 100| 598.6 | 294.5 | 305.9 |
| 500| 2899.5 | 1302.4 | 1486.4 |

### Memory Peak (Mi)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 9Mi | **6Mi** | 12Mi |
| 50| 9Mi | **3Mi** | 8Mi |
| 100| 10Mi | **4Mi** | 9Mi |
| 500| 28Mi | **15Mi** | 16Mi |

### CPU usage (millicores)

| VUS | go | axum | actix |
|-----|---|---|---|
| 10| 100m | 95m | 99m |
| 50| 100m | 101m | 100m |
| 100| 101m | 100m | 100m |
| 500| 101m | 101m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 209 | 101m | 206.9 |
| axum | 393 | 101m | **389.1** |
| actix | 349 | 100m | 349.0 |

### Memory: idle / peak / recovery (500 VUS)

> **Returned**: how much of the allocated memory above idle was released back. Formula: `(peak - after_300s) / (peak - idle)`. 100% = back to baseline, 0% = nothing released.

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 28Mi | 25Mi | 9Mi | 70% | 0 |
| axum | -Mi | 15Mi | 13Mi | 13Mi | 13% | 0 |
| actix | 1Mi | 16Mi | 12Mi | 12Mi | 27% | 0 |

---

