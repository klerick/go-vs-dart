# go vs bun-native

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | go | bun-native |
|-----|---|---|
| 10| **1446** | 1302 |
| 50| **1627** | 1518 |
| 100| **1628** | 1626 |
| 500| 1656 | **1769** |

### Latency p95 (ms)

| VUS | go | bun-native |
|-----|---|---|
| 10| 10.4 | 14.4 |
| 50| 42.0 | 58.1 |
| 100| 80.6 | 97.4 |
| 500| 376.7 | 408.9 |

### Memory Peak (Mi)

| VUS | go | bun-native |
|-----|---|---|
| 10| **8Mi** | 21Mi |
| 50| **9Mi** | 36Mi |
| 100| **11Mi** | 83Mi |
| 500| **29Mi** | 85Mi |

### CPU usage (millicores)

| VUS | go | bun-native |
|-----|---|---|
| 10| 636m | 723m |
| 50| 644m | 717m |
| 100| 650m | 685m |
| 500| 647m | 699m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 1656 | 647m | **256.0** |
| bun-native | 1769 | 699m | 253.1 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 24Mi | 8Mi | 72% | 0 |
| bun-native | 6Mi | 85Mi | 14Mi | 14Mi | 84% | 0 |

---

## 250m CPU

### RPS

| VUS | go | bun-native |
|-----|---|---|
| 10| **517** | 440 |
| 50| 566 | **577** |
| 100| 573 | **639** |
| 500| 571 | **825** |

### Latency p95 (ms)

| VUS | go | bun-native |
|-----|---|---|
| 10| 74.1 | 80.3 |
| 50| 108.4 | 105.2 |
| 100| 213.5 | 200.7 |
| 500| 1099.4 | 794.3 |

### Memory Peak (Mi)

| VUS | go | bun-native |
|-----|---|---|
| 10| **9Mi** | 21Mi |
| 50| **9Mi** | 29Mi |
| 100| **11Mi** | 41Mi |
| 500| **29Mi** | 55Mi |

### CPU usage (millicores)

| VUS | go | bun-native |
|-----|---|---|
| 10| 251m | 250m |
| 50| 250m | 251m |
| 100| 251m | 250m |
| 500| 250m | 250m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 571 | 250m | 228.4 |
| bun-native | 825 | 250m | **330.0** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 23Mi | 8Mi | 72% | 0 |
| bun-native | 6Mi | 55Mi | 15Mi | 15Mi | 73% | 0 |

---

## 100m CPU

### RPS

| VUS | go | bun-native |
|-----|---|---|
| 10| **200** | 125 |
| 50| **215** | 148 |
| 100| **215** | 210 |
| 500| **209** | 172 |

### Latency p95 (ms)

| VUS | go | bun-native |
|-----|---|---|
| 10| 96.8 | 160.3 |
| 50| 301.3 | 465.4 |
| 100| 598.6 | 598.4 |
| 500| 2899.5 | 2599.7 |

### Memory Peak (Mi)

| VUS | go | bun-native |
|-----|---|---|
| 10| **9Mi** | 18Mi |
| 50| **9Mi** | 34Mi |
| 100| **10Mi** | 36Mi |
| 500| **28Mi** | 40Mi |

### CPU usage (millicores)

| VUS | go | bun-native |
|-----|---|---|
| 10| 100m | 100m |
| 50| 100m | 100m |
| 100| 101m | 99m |
| 500| 101m | 99m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 209 | 101m | **206.9** |
| bun-native | 172 | 99m | 173.7 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 28Mi | 25Mi | 9Mi | 68% | 0 |
| bun-native | 6Mi | 40Mi | 6Mi | 6Mi | 85% | 1 |

---

