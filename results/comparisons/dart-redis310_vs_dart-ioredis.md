# dart-redis310 vs dart-ioredis

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 774 | **801** |
| 50| 825 | **871** |
| 100| 799 | **842** |
| 500| 741 | **778** |

### Latency p95 (ms)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 16.7 | 16.1 |
| 50| 79.8 | 77.1 |
| 100| 165.2 | 161.2 |
| 500| 850.4 | 816.9 |

### Memory Peak (Mi)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| **37Mi** | 38Mi |
| 50| **37Mi** | 38Mi |
| 100| **38Mi** | **38Mi** |
| 500| **39Mi** | **39Mi** |

### CPU usage (millicores)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 992m | 992m |
| 50| 998m | 996m |
| 100| 999m | 997m |
| 500| 998m | 997m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| dart-redis310 | 741 | 998m | 74.2 |
| dart-ioredis | 778 | 997m | **78.0** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| dart-redis310 | 3Mi | 39Mi | 37Mi | 37Mi | 5% | 0 |
| dart-ioredis | 3Mi | 39Mi | 37Mi | 37Mi | 5% | 0 |

---

## 250m CPU

### RPS

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| **191** | 188 |
| 50| 205 | **214** |
| 100| 208 | **213** |
| 500| 187 | **189** |

### Latency p95 (ms)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 92.7 | 92.2 |
| 50| 306.8 | 301.6 |
| 100| 613.2 | 623.0 |
| 500| 3395.1 | 3408.0 |

### Memory Peak (Mi)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 43Mi | **42Mi** |
| 50| 44Mi | **42Mi** |
| 100| 44Mi | **43Mi** |
| 500| 48Mi | **46Mi** |

### CPU usage (millicores)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 250m | 250m |
| 50| 250m | 250m |
| 100| 250m | 250m |
| 500| 250m | 250m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| dart-redis310 | 187 | 250m | 74.8 |
| dart-ioredis | 189 | 250m | **75.6** |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| dart-redis310 | 3Mi | 48Mi | 44Mi | 44Mi | 8% | 0 |
| dart-ioredis | 3Mi | 46Mi | 42Mi | 42Mi | 9% | 0 |

---

## 100m CPU

### RPS

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| **70** | **70** |
| 50| 72 | **75** |
| 100| **77** | 76 |
| 500| **67** | 66 |

### Latency p95 (ms)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 199.4 | 198.8 |
| 50| 913.0 | 895.7 |
| 100| 1602.6 | 1701.4 |
| 500| 9499.3 | 9676.7 |

### Memory Peak (Mi)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| **44Mi** | **44Mi** |
| 50| **44Mi** | **44Mi** |
| 100| **45Mi** | **45Mi** |
| 500| **47Mi** | **47Mi** |

### CPU usage (millicores)

| VUS | dart-redis310 | dart-ioredis |
|-----|---|---|
| 10| 100m | 100m |
| 50| 100m | 100m |
| 100| 101m | 101m |
| 500| 100m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| dart-redis310 | 67 | 100m | **67.0** |
| dart-ioredis | 66 | 100m | 66.0 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| dart-redis310 | 3Mi | 47Mi | 45Mi | 45Mi | 4% | 0 |
| dart-ioredis | 3Mi | 47Mi | 44Mi | 44Mi | 6% | 0 |

---

