# go vs node vs dart-redis310

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **1446** | 1177 | 774 |
| 50| **1627** | 1350 | 825 |
| 100| **1628** | 1336 | 799 |
| 500| **1656** | 1321 | 741 |

### Latency p95 (ms)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 10.4 | 12.1 | 16.7 |
| 50| 42.0 | 51.8 | 79.8 |
| 100| 80.6 | 105.7 | 165.2 |
| 500| 376.7 | 483.5 | 850.4 |

### Memory Peak (Mi)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **8Mi** | 25Mi | 37Mi |
| 50| **9Mi** | 33Mi | 37Mi |
| 100| **11Mi** | 34Mi | 38Mi |
| 500| **29Mi** | 39Mi | 39Mi |

### CPU usage (millicores)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 636m | 923m | 992m |
| 50| 644m | 946m | 998m |
| 100| 650m | 982m | 999m |
| 500| 647m | 981m | 998m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 1656 | 647m | **256.0** |
| node | 1321 | 981m | 134.7 |
| dart-redis310 | 741 | 998m | 74.2 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 24Mi | 8Mi | 72% | 0 |
| node | 18Mi | 39Mi | 21Mi | 22Mi | 44% | 0 |
| dart-redis310 | 3Mi | 39Mi | 37Mi | 37Mi | 5% | 0 |

---

## 250m CPU

### RPS

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **517** | 289 | 191 |
| 50| **566** | 369 | 205 |
| 100| **573** | 354 | 208 |
| 500| **571** | 337 | 187 |

### Latency p95 (ms)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 74.1 | 57.8 | 92.7 |
| 50| 108.4 | 193.9 | 306.8 |
| 100| 213.5 | 402.3 | 613.2 |
| 500| 1099.4 | 1896.0 | 3395.1 |

### Memory Peak (Mi)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **9Mi** | 24Mi | 43Mi |
| 50| **9Mi** | 32Mi | 44Mi |
| 100| **11Mi** | 33Mi | 44Mi |
| 500| **29Mi** | 38Mi | 48Mi |

### CPU usage (millicores)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 251m | 250m | 250m |
| 50| 250m | 250m | 250m |
| 100| 251m | 251m | 250m |
| 500| 250m | 251m | 250m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 571 | 250m | **228.4** |
| node | 337 | 251m | 134.3 |
| dart-redis310 | 187 | 250m | 74.8 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 23Mi | 8Mi | 72% | 0 |
| node | 18Mi | 38Mi | 36Mi | 22Mi | 42% | 0 |
| dart-redis310 | 3Mi | 48Mi | 44Mi | 44Mi | 8% | 0 |

---

## 100m CPU

### RPS

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **200** | 84 | 70 |
| 50| **215** | 134 | 72 |
| 100| **215** | 134 | 77 |
| 500| **209** | 128 | 67 |

### Latency p95 (ms)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 96.8 | 295.9 | 199.4 |
| 50| 301.3 | 499.3 | 913.0 |
| 100| 598.6 | 1096.0 | 1602.6 |
| 500| 2899.5 | 4992.6 | 9499.3 |

### Memory Peak (Mi)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| **9Mi** | 23Mi | 44Mi |
| 50| **9Mi** | 29Mi | 44Mi |
| 100| **10Mi** | 33Mi | 45Mi |
| 500| **28Mi** | 37Mi | 47Mi |

### CPU usage (millicores)

| VUS | go | node | dart-redis310 |
|-----|---|---|---|
| 10| 100m | 100m | 100m |
| 50| 100m | 100m | 100m |
| 100| 101m | 100m | 101m |
| 500| 101m | 100m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 209 | 101m | **206.9** |
| node | 128 | 100m | 128.0 |
| dart-redis310 | 67 | 100m | 67.0 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 28Mi | 25Mi | 9Mi | 68% | 0 |
| node | 18Mi | 37Mi | 20Mi | 21Mi | 43% | 0 |
| dart-redis310 | 3Mi | 47Mi | 45Mi | 45Mi | 4% | 0 |

---

