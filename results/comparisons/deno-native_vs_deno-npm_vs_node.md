# deno-native vs deno-npm vs node

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 983 | 913 | **1177** |
| 50| 1058 | 1146 | **1350** |
| 100| 1056 | 1121 | **1336** |
| 500| 1009 | 1102 | **1321** |

### Latency p95 (ms)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 14.0 | 15.4 | 12.1 |
| 50| 61.2 | 69.9 | 51.8 |
| 100| 116.3 | 130.8 | 105.7 |
| 500| 528.6 | 572.6 | 483.5 |

### Memory Peak (Mi)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 59Mi | 76Mi | **25Mi** |
| 50| 62Mi | 79Mi | **33Mi** |
| 100| 63Mi | 81Mi | **34Mi** |
| 500| 68Mi | 88Mi | **39Mi** |

### CPU usage (millicores)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 966m | 972m | 923m |
| 50| 992m | 976m | 946m |
| 100| 993m | 990m | 982m |
| 500| 997m | 993m | 981m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| deno-native | 1009 | 997m | 101.2 |
| deno-npm | 1102 | 993m | 111.0 |
| node | 1321 | 981m | **134.7** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| deno-native | 29Mi | 68Mi | 66Mi | 64Mi | 6% | 0 |
| deno-npm | 28Mi | 88Mi | 70Mi | 71Mi | 19% | 0 |
| node | 18Mi | 39Mi | 21Mi | 22Mi | 44% | 0 |

---

## 250m CPU

### RPS

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 246 | 234 | **289** |
| 50| 250 | 292 | **369** |
| 100| 252 | 283 | **354** |
| 500| 233 | 267 | **337** |

### Latency p95 (ms)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 89.3 | 88.7 | 57.8 |
| 50| 288.2 | 302.8 | 193.9 |
| 100| 498.1 | 581.3 | 402.3 |
| 500| 2294.9 | 2305.8 | 1896.0 |

### Memory Peak (Mi)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 59Mi | 75Mi | **24Mi** |
| 50| 64Mi | 77Mi | **32Mi** |
| 100| 65Mi | 79Mi | **33Mi** |
| 500| 67Mi | 88Mi | **38Mi** |

### CPU usage (millicores)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 250m | 250m | 250m |
| 50| 251m | 251m | 250m |
| 100| 250m | 250m | 251m |
| 500| 250m | 250m | 251m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| deno-native | 233 | 250m | 93.2 |
| deno-npm | 267 | 250m | 106.8 |
| node | 337 | 251m | **134.3** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| deno-native | 29Mi | 67Mi | 66Mi | 52Mi | 22% | 0 |
| deno-npm | 27Mi | 88Mi | 70Mi | 71Mi | 19% | 0 |
| node | 18Mi | 38Mi | 36Mi | 22Mi | 42% | 0 |

---

## 100m CPU

### RPS

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| **93** | 79 | 84 |
| 50| 94 | 103 | **134** |
| 100| 93 | 99 | **134** |
| 500| 88 | 96 | **128** |

### Latency p95 (ms)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 193.8 | 198.9 | 295.9 |
| 50| 700.1 | 801.7 | 499.3 |
| 100| 1368.9 | 1500.2 | 1096.0 |
| 500| 6196.1 | 6499.2 | 4992.6 |

### Memory Peak (Mi)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 56Mi | 76Mi | **23Mi** |
| 50| 63Mi | 79Mi | **29Mi** |
| 100| 63Mi | 80Mi | **33Mi** |
| 500| 67Mi | 84Mi | **37Mi** |

### CPU usage (millicores)

| VUS | deno-native | deno-npm | node |
|-----|---|---|---|
| 10| 100m | 100m | 100m |
| 50| 100m | 100m | 100m |
| 100| 100m | 100m | 100m |
| 500| 100m | 100m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| deno-native | 88 | 100m | 88.0 |
| deno-npm | 96 | 100m | 96.0 |
| node | 128 | 100m | **128.0** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| deno-native | 28Mi | 67Mi | 67Mi | 67Mi | 0% | 0 |
| deno-npm | 28Mi | 84Mi | 71Mi | 72Mi | 14% | 0 |
| node | 18Mi | 37Mi | 20Mi | 21Mi | 43% | 0 |

---

