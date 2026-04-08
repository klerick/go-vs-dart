# bun-native vs bun-npm vs node

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **1302** | 1182 | 1177 |
| 50| **1518** | 1380 | 1350 |
| 100| **1626** | 1413 | 1336 |
| 500| **1769** | 1414 | 1321 |

### Latency p95 (ms)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 14.4 | 13.2 | 12.1 |
| 50| 58.1 | 55.6 | 51.8 |
| 100| 97.4 | 96.3 | 105.7 |
| 500| 408.9 | 445.2 | 483.5 |

### Memory Peak (Mi)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **21Mi** | 69Mi | 25Mi |
| 50| 36Mi | 76Mi | **33Mi** |
| 100| 83Mi | 79Mi | **34Mi** |
| 500| 85Mi | 89Mi | **39Mi** |

### CPU usage (millicores)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 723m | 866m | 923m |
| 50| 717m | 872m | 946m |
| 100| 685m | 871m | 982m |
| 500| 699m | 874m | 981m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| bun-native | 1769 | 699m | **253.1** |
| bun-npm | 1414 | 874m | 161.8 |
| node | 1321 | 981m | 134.7 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| bun-native | 6Mi | 85Mi | 14Mi | 14Mi | 84% | 0 |
| bun-npm | 22Mi | 89Mi | 72Mi | 52Mi | 42% | 0 |
| node | 18Mi | 39Mi | 21Mi | 22Mi | 44% | 0 |

---

## 250m CPU

### RPS

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **440** | 276 | 289 |
| 50| **577** | 340 | 369 |
| 100| **639** | 365 | 354 |
| 500| **825** | 366 | 337 |

### Latency p95 (ms)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 80.3 | 91.1 | 57.8 |
| 50| 105.2 | 200.8 | 193.9 |
| 100| 200.7 | 389.3 | 402.3 |
| 500| 794.3 | 1706.4 | 1896.0 |

### Memory Peak (Mi)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **21Mi** | 62Mi | 24Mi |
| 50| **29Mi** | 78Mi | 32Mi |
| 100| 41Mi | 84Mi | **33Mi** |
| 500| 55Mi | 86Mi | **38Mi** |

### CPU usage (millicores)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 250m | 248m | 250m |
| 50| 251m | 251m | 250m |
| 100| 250m | 250m | 251m |
| 500| 250m | 250m | 251m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| bun-native | 825 | 250m | **330.0** |
| bun-npm | 366 | 250m | 146.4 |
| node | 337 | 251m | 134.3 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| bun-native | 6Mi | 55Mi | 15Mi | 15Mi | 73% | 0 |
| bun-npm | 22Mi | 86Mi | 69Mi | 47Mi | 45% | 0 |
| node | 18Mi | 38Mi | 36Mi | 22Mi | 42% | 0 |

---

## 100m CPU

### RPS

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **125** | 75 | 84 |
| 50| **148** | 72 | 134 |
| 100| **210** | 91 | 134 |
| 500| **172** | 88 | 128 |

### Latency p95 (ms)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 160.3 | 292.7 | 295.9 |
| 50| 465.4 | 937.2 | 499.3 |
| 100| 598.4 | 1520.0 | 1096.0 |
| 500| 2599.7 | 7897.9 | 4992.6 |

### Memory Peak (Mi)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| **18Mi** | 54Mi | 23Mi |
| 50| 34Mi | 74Mi | **29Mi** |
| 100| 36Mi | 75Mi | **33Mi** |
| 500| 40Mi | 77Mi | **37Mi** |

### CPU usage (millicores)

| VUS | bun-native | bun-npm | node |
|-----|---|---|---|
| 10| 100m | 99m | 100m |
| 50| 100m | 99m | 100m |
| 100| 99m | 100m | 100m |
| 500| 99m | 99m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| bun-native | 172 | 99m | **173.7** |
| bun-npm | 88 | 99m | 88.9 |
| node | 128 | 100m | 128.0 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| bun-native | 6Mi | 40Mi | 6Mi | 6Mi | 85% | 1 |
| bun-npm | 22Mi | 77Mi | 70Mi | 47Mi | 39% | 0 |
| node | 18Mi | 37Mi | 20Mi | 21Mi | 43% | 0 |

---

