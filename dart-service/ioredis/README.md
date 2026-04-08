# ioredis (Dart)

> **Disclaimer:** This package was entirely written by an AI agent (Claude). The repository author merely watched, occasionally facepalmed, and said things we can't print here. All bugs are the neural network's achievement. All working features are pure luck.

Production-grade Redis client for Dart. A full port of [ioredis](https://github.com/redis/ioredis) — minus the 15,000 lines of TypeScript overloads and the `node_modules` the size of a galaxy.

## Features

- **Standalone** — single Redis server connection (TCP/TLS)
- **Cluster** — automatic slot routing, MOVED/ASK redirects, topology refresh
- **Sentinel** — High Availability, automatic failover detection
- **Pipeline** — command batching in a single roundtrip
- **Transactions** — MULTI/EXEC
- **Pub/Sub** — channel subscriptions, patterns, Dart Stream API
- **Lua Scripting** — EVALSHA with EVAL fallback
- **SCAN Streams** — cursor-based iteration via `async for`
- **Reconnection** — automatic reconnect with configurable retry strategy
- **Offline Queue** — commands buffered until connection is ready
- **316 typed commands** — all hardcoded by hand (AI doesn't complain about grunt work)
- **CRC16** — slot calculation matches Redis server (on the second attempt)

## Usage

### Standalone

```dart
import 'package:ioredis/ioredis.dart';

final redis = Redis(RedisOptions(host: 'localhost', port: 6379));

await redis.set('key', 'value', ex: 60);
final value = await redis.get('key');

await redis.hset('user:1', {'name': 'Alice', 'age': '30'});
final user = await redis.hgetall('user:1');

await redis.close();
```

### Pipeline

```dart
final pipe = redis.pipeline();
pipe.addCommand('SET', ['a', '1']);
pipe.addCommand('SET', ['b', '2']);
pipe.addCommand('GET', ['a']);
pipe.addCommand('GET', ['b']);
final results = await pipe.exec();
// [(null, 'OK'), (null, 'OK'), (null, '1'), (null, '2')]
```

### Pub/Sub

```dart
final sub = Redis(RedisOptions(port: 6379, lazyConnect: true));
await sub.connect();

sub.messages.listen((msg) {
  print('${msg.channel}: ${msg.message}');
});

await sub.subscribe(['news', 'events']);

// From another client:
await redis.publish('news', 'hello');
```

### Cluster

```dart
final cluster = RedisCluster([
  ClusterNode(host: '127.0.0.1', port: 7010),
  ClusterNode(host: '127.0.0.1', port: 7011),
  ClusterNode(host: '127.0.0.1', port: 7012),
]);

await cluster.call('SET', ['key', 'value']); // automatic slot routing
final value = await cluster.call('GET', ['key']);
```

### Scan

```dart
await for (final key in redis.scan(match: 'user:*')) {
  print(key);
}
```

### Lua Scripts

```dart
final script = RedisScript(
  "return redis.call('SET', KEYS[1], ARGV[1])",
  numberOfKeys: 1,
);
await script.execute(redis, keys: ['mykey'], args: ['myvalue']);
```

## What we didn't port

- **Auto-pipelining** — `setImmediate`-based batching from ioredis. Dart's event loop works differently. Not needed yet.
- **Sharded Pub/Sub** — Redis 7.0+ feature. Will add when needed.
- **TLS Profiles** — hardcoded CA certificates. Pass your own `SecurityContext` like a grown-up.
- **Callback API** — this is Dart, we have `Future`. Welcome to civilization.

## Tests

```bash
dart test test/                              # 87 unit tests
dart test integration_test/redis_test.dart   # 71 integration (Docker)
dart test integration_test/cluster_test.dart # 16 cluster (Docker, 6 nodes)
```

Integration tests spin up Redis in Docker automatically. Just have `docker` installed.

## Architecture

```
lib/src/
├── protocol/       # RESP encoder/parser (incremental, streaming)
├── command/        # Command abstraction, CRC16 slot calculation
├── client/         # Redis client, state machine, reconnection
├── connectors/     # Standalone TCP/TLS, Sentinel HA
├── cluster/        # Cluster routing, MOVED/ASK, connection pool
├── commands/       # 316 typed methods (extension methods)
├── pubsub/         # Subscription tracking
├── scripting/      # Lua scripts, SCAN streams
└── errors.dart     # Exception hierarchy
```

## Stats

| | LOC |
|---|-----|
| Source (lib/) | 4,347 |
| Unit tests | 728 |
| Integration tests | 630 |
| **Total** | **5,705** |

The original ioredis is 23,500 LOC of TypeScript. The Dart version is 80% smaller thanks to no callback API, no Buffer/String dualism, no TypeScript overloads, no lodash, and no `node_modules` existential crisis.

## License

MIT — as is everything written by robots.
