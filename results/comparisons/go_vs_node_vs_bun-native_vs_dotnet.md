# go vs node vs bun-native vs dotnet

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **1446** | 1177 | 1302 | 1103 |
| 50| **1627** | 1350 | 1518 | 1269 |
| 100| **1628** | 1336 | 1626 | 1291 |
| 500| 1656 | 1321 | **1769** | 1304 |

### Latency p95 (ms)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 10.4 | 12.1 | 14.4 | 22.2 |
| 50| 42.0 | 51.8 | 58.1 | 68.8 |
| 100| 80.6 | 105.7 | 97.4 | 96.6 |
| 500| 376.7 | 483.5 | 408.9 | 414.1 |

### Memory Peak (Mi)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **8Mi** | 25Mi | 21Mi | 106Mi |
| 50| **9Mi** | 33Mi | 36Mi | 100Mi |
| 100| **11Mi** | 34Mi | 83Mi | 101Mi |
| 500| **29Mi** | 39Mi | 85Mi | 112Mi |

### CPU usage (millicores)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 636m | 923m | 723m | 973m |
| 50| 644m | 946m | 717m | 970m |
| 100| 650m | 982m | 685m | 951m |
| 500| 647m | 981m | 699m | 924m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 1656 | 647m | **256.0** |
| node | 1321 | 981m | 134.7 |
| bun-native | 1769 | 699m | 253.1 |
| dotnet | 1304 | 924m | 141.1 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 24Mi | 8Mi | 72% | 0 |
| node | 18Mi | 39Mi | 21Mi | 22Mi | 44% | 0 |
| bun-native | 6Mi | 85Mi | 14Mi | 14Mi | 84% | 0 |
| dotnet | 78Mi | 112Mi | 107Mi | 107Mi | 4% | 0 |

---

## 250m CPU

### RPS

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **517** | 289 | 440 | 253 |
| 50| 566 | 369 | **577** | 372 |
| 100| 573 | 354 | **639** | 390 |
| 500| 571 | 337 | **825** | 373 |

### Latency p95 (ms)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 74.1 | 57.8 | 80.3 | 90.3 |
| 50| 108.4 | 193.9 | 105.2 | 196.0 |
| 100| 213.5 | 402.3 | 200.7 | 301.2 |
| 500| 1099.4 | 1896.0 | 794.3 | 1478.8 |

### Memory Peak (Mi)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **9Mi** | 24Mi | 21Mi | 49Mi |
| 50| **9Mi** | 32Mi | 29Mi | 47Mi |
| 100| **11Mi** | 33Mi | 41Mi | 42Mi |
| 500| **29Mi** | 38Mi | 55Mi | 54Mi |

### CPU usage (millicores)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 251m | 250m | 250m | 246m |
| 50| 250m | 250m | 251m | 247m |
| 100| 251m | 251m | 250m | 247m |
| 500| 250m | 251m | 250m | 248m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 571 | 250m | 228.4 |
| node | 337 | 251m | 134.3 |
| bun-native | 825 | 250m | **330.0** |
| dotnet | 373 | 248m | 150.4 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 29Mi | 23Mi | 8Mi | 72% | 0 |
| node | 18Mi | 38Mi | 36Mi | 22Mi | 42% | 0 |
| bun-native | 6Mi | 55Mi | 15Mi | 15Mi | 73% | 0 |
| dotnet | 25Mi | 54Mi | 53Mi | 49Mi | 9% | 0 |

---

## 100m CPU

### RPS

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **200** | 84 | 125 | 93 |
| 50| **215** | 134 | 148 | 138 |
| 100| **215** | 134 | 210 | 144 |
| 500| **209** | 128 | 172 | 137 |

### Latency p95 (ms)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 96.8 | 295.9 | 160.3 | 194.2 |
| 50| 301.3 | 499.3 | 465.4 | 494.6 |
| 100| 598.6 | 1096.0 | 598.4 | 802.6 |
| 500| 2899.5 | 4992.6 | 2599.7 | 3898.8 |

### Memory Peak (Mi)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| **9Mi** | 23Mi | 18Mi | 48Mi |
| 50| **9Mi** | 29Mi | 34Mi | 49Mi |
| 100| **10Mi** | 33Mi | 36Mi | 49Mi |
| 500| **28Mi** | 37Mi | 40Mi | 53Mi |

### CPU usage (millicores)

| VUS | go | node | bun-native | dotnet |
|-----|---|---|---|---|
| 10| 100m | 100m | 100m | 97m |
| 50| 100m | 100m | 100m | 98m |
| 100| 101m | 100m | 99m | 97m |
| 500| 101m | 100m | 99m | 98m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| go | 209 | 101m | **206.9** |
| node | 128 | 100m | 128.0 |
| bun-native | 172 | 99m | 173.7 |
| dotnet | 137 | 98m | 139.8 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| go | 1Mi | 28Mi | 25Mi | 9Mi | 68% | 0 |
| node | 18Mi | 37Mi | 20Mi | 21Mi | 43% | 0 |
| bun-native | 6Mi | 40Mi | 6Mi | 6Mi | 85% | 1 |
| dotnet | 25Mi | 53Mi | 50Mi | 48Mi | 9% | 0 |

---

