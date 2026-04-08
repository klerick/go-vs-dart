import 'package:test/test.dart';
import 'package:ioredis/ioredis.dart';

import 'docker_redis_cluster.dart';

void main() {
  late DockerRedisCluster docker;
  late RedisCluster cluster;

  setUpAll(() async {
    docker = DockerRedisCluster();
    await docker.start();

    final nodes =
        docker.nodes.map((n) => ClusterNode(host: n.host, port: n.port)).toList();
    cluster = RedisCluster(nodes, const ClusterOptions(lazyConnect: true));
    await cluster.connect();
  });

  tearDownAll(() async {
    await cluster.close();
    await docker.stop();
  });

  group('Cluster connection', () {
    test('status is ready', () {
      expect(cluster.status, equals(ClusterStatus.ready));
    });

    test('has master nodes', () {
      final masters = cluster.nodes(NodeRole.master);
      expect(masters.length, greaterThanOrEqualTo(3));
    });

    test('CLUSTER INFO returns valid info', () async {
      final info = await cluster.call('CLUSTER', ['INFO']);
      expect(info.toString(), contains('cluster_state:ok'));
    });
  });

  group('Cluster command routing', () {
    test('SET and GET route to correct node', () async {
      await cluster.call('SET', ['test-key', 'test-value']);
      final result = await cluster.call('GET', ['test-key']);
      expect(result, equals('test-value'));
    });

    test('multiple keys route to different slots', () async {
      // Keys will likely hash to different slots/nodes
      for (var i = 0; i < 20; i++) {
        await cluster.call('SET', ['key:$i', 'value:$i']);
      }
      for (var i = 0; i < 20; i++) {
        final result = await cluster.call('GET', ['key:$i']);
        expect(result, equals('value:$i'));
      }
    });

    test('hash tags route to same slot', () async {
      // {user} hash tag ensures same slot
      await cluster.call('SET', ['{user}.name', 'Alice']);
      await cluster.call('SET', ['{user}.age', '30']);

      expect(
        await cluster.call('GET', ['{user}.name']),
        equals('Alice'),
      );
      expect(
        await cluster.call('GET', ['{user}.age']),
        equals('30'),
      );

      // Verify same slot
      final slot1 = calculateSlot('{user}.name');
      final slot2 = calculateSlot('{user}.age');
      expect(slot1, equals(slot2));
    });
  });

  group('Cluster data types', () {
    test('INCR works across routing', () async {
      await cluster.call('SET', ['counter:1', '0']);
      await cluster.call('INCR', ['counter:1']);
      await cluster.call('INCR', ['counter:1']);
      await cluster.call('INCR', ['counter:1']);
      final result = await cluster.call('GET', ['counter:1']);
      expect(result, equals('3'));
    });

    test('hash operations', () async {
      await cluster.call('HSET', ['user:100', 'name', 'Bob', 'age', '25']);
      final name = await cluster.call('HGET', ['user:100', 'name']);
      expect(name, equals('Bob'));
    });

    test('list operations', () async {
      await cluster.call('RPUSH', ['list:1', 'a', 'b', 'c']);
      final result = await cluster.call('LRANGE', ['list:1', '0', '-1']);
      expect(result, equals(['a', 'b', 'c']));
    });

    test('set operations', () async {
      await cluster.call('SADD', ['set:1', 'x', 'y', 'z']);
      final card = await cluster.call('SCARD', ['set:1']);
      expect(card, equals(3));
    });

    test('sorted set operations', () async {
      await cluster.call('ZADD', ['zset:1', '1', 'a', '2', 'b', '3', 'c']);
      final result = await cluster.call('ZRANGE', ['zset:1', '0', '-1']);
      expect(result, equals(['a', 'b', 'c']));
    });
  });

  group('Cluster TTL', () {
    test('SET with EX', () async {
      await cluster.call('SET', ['ttl-key', 'value', 'EX', '60']);
      final ttl = await cluster.call('TTL', ['ttl-key']);
      expect(ttl as int, greaterThan(0));
      expect(ttl as int, lessThanOrEqualTo(60));
    });

    test('EXPIRE', () async {
      await cluster.call('SET', ['exp-key', 'value']);
      await cluster.call('EXPIRE', ['exp-key', '120']);
      final ttl = await cluster.call('TTL', ['exp-key']);
      expect(ttl as int, greaterThan(0));
    });
  });

  group('Cluster DEL', () {
    test('DEL single key', () async {
      await cluster.call('SET', ['del-key', 'value']);
      final deleted = await cluster.call('DEL', ['del-key']);
      expect(deleted, equals(1));
      expect(await cluster.call('GET', ['del-key']), isNull);
    });
  });

  group('Cluster scripting', () {
    test('EVAL on cluster', () async {
      final result = await cluster.call(
        'EVAL',
        ["return redis.call('SET', KEYS[1], ARGV[1])", '1', 'lua:1', 'hello'],
      );
      expect(result.toString(), equals('OK'));
      expect(await cluster.call('GET', ['lua:1']), equals('hello'));
    });
  });

  group('Cluster slot calculation', () {
    test('calculateSlot consistent with CLUSTER KEYSLOT', () async {
      final keys = ['test', 'hello', '{user}.name', 'foo:bar', 'zest'];
      for (final key in keys) {
        final serverSlot = await cluster.call('CLUSTER', ['KEYSLOT', key]);
        final localSlot = calculateSlot(key);
        expect(
          localSlot,
          equals(serverSlot),
          reason: 'Slot mismatch for key "$key": local=$localSlot, server=$serverSlot',
        );
      }
    });
  });
}
