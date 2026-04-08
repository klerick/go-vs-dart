# nestjs-fastify vs nestjs-express

> Median across 3 runs. Higher RPS / lower latency / lower memory = better.

## 1000m CPU

### RPS

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **1034** | 719 |
| 50| **1173** | 738 |
| 100| **1130** | 725 |
| 500| **1080** | 690 |

### Latency p95 (ms)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 12.6 | 18.5 |
| 50| 59.0 | 106.0 |
| 100| 136.9 | 196.0 |
| 500| 597.8 | 908.2 |

### Memory Peak (Mi)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **39Mi** | 40Mi |
| 50| **40Mi** | 41Mi |
| 100| **41Mi** | 42Mi |
| 500| **47Mi** | 49Mi |

### CPU usage (millicores)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 939m | 994m |
| 50| 993m | 1000m |
| 100| 998m | 999m |
| 500| 995m | 999m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| nestjs-fastify | 1080 | 995m | **108.5** |
| nestjs-express | 690 | 999m | 69.1 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| nestjs-fastify | 26Mi | 47Mi | 28Mi | 29Mi | 38% | 0 |
| nestjs-express | 25Mi | 49Mi | 28Mi | 30Mi | 39% | 0 |

---

## 250m CPU

### RPS

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **233** | 159 |
| 50| **283** | 179 |
| 100| **268** | 178 |
| 500| **256** | 168 |

### Latency p95 (ms)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 90.6 | 99.7 |
| 50| 282.5 | 494.1 |
| 100| 600.2 | 809.3 |
| 500| 2409.6 | 3892.0 |

### Memory Peak (Mi)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **36Mi** | 39Mi |
| 50| **39Mi** | 40Mi |
| 100| **40Mi** | 41Mi |
| 500| **45Mi** | 47Mi |

### CPU usage (millicores)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 250m | 251m |
| 50| 251m | 250m |
| 100| 250m | 251m |
| 500| 250m | 251m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| nestjs-fastify | 256 | 250m | **102.4** |
| nestjs-express | 168 | 251m | 66.9 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| nestjs-fastify | 26Mi | 45Mi | 28Mi | 29Mi | 36% | 0 |
| nestjs-express | 25Mi | 47Mi | 28Mi | 30Mi | 36% | 0 |

---

## 100m CPU

### RPS

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **54** | 39 |
| 50| **81** | 48 |
| 100| **105** | 68 |
| 500| **97** | 65 |

### Latency p95 (ms)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 303.8 | 495.3 |
| 50| 1193.1 | 2121.7 |
| 100| 1405.4 | 2017.2 |
| 500| 12420.4 | 28584.7 |

### Memory Peak (Mi)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| **32Mi** | 36Mi |
| 50| **39Mi** | **39Mi** |
| 100| **39Mi** | **39Mi** |
| 500| **42Mi** | 43Mi |

### CPU usage (millicores)

| VUS | nestjs-fastify | nestjs-express |
|-----|---|---|
| 10| 100m | 100m |
| 50| 100m | 100m |
| 100| 100m | 100m |
| 500| 100m | 100m |

### CPU Efficiency (RPS per 100m CPU @ 500 VUS, higher = better)

| Service | RPS | CPU used | RPS / 100m CPU |
|---------|-----|----------|----------------|
| nestjs-fastify | 97 | 100m | **97.0** |
| nestjs-express | 65 | 100m | 65.0 |

### Memory: idle / peak / recovery (500 VUS)

| Service | Idle | Peak | After 60s | After 300s | Returned | Restarts |
|---------|------|------|-----------|------------|----------|----------|
| nestjs-fastify | 26Mi | 42Mi | 30Mi | 27Mi | 36% | 3 |
| nestjs-express | 25Mi | 43Mi | 28Mi | 27Mi | 37% | 3 |

---

