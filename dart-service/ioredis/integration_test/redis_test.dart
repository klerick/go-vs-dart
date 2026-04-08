import 'package:test/test.dart';
import 'package:ioredis/ioredis.dart';

import 'docker_redis.dart';

void main() {
  late DockerRedis docker;
  late Redis redis;

  setUpAll(() async {
    docker = DockerRedis();
    await docker.start();
    redis = Redis(RedisOptions(port: docker.port, lazyConnect: true));
    await redis.connect();
  });

  tearDownAll(() async {
    await redis.close();
    await docker.stop();
  });

  setUp(() async {
    await redis.call('FLUSHDB');
  });

  group('Connection', () {
    test('status is ready after connect', () {
      expect(redis.status, equals(RedisStatus.ready));
    });

    test('PING returns PONG', () async {
      final result = await redis.ping();
      expect(result, equals('PONG'));
    });

    test('PING with message', () async {
      final result = await redis.ping('hello');
      expect(result, equals('hello'));
    });

    test('INFO returns server info', () async {
      final result = await redis.info();
      expect(result, contains('redis_version'));
    });

    test('DBSIZE returns 0 after FLUSHDB', () async {
      final size = await redis.dbsize();
      expect(size, equals(0));
    });
  });

  group('String commands', () {
    test('SET and GET', () async {
      await redis.set('key', 'value');
      final result = await redis.get('key');
      expect(result, equals('value'));
    });

    test('SET with EX', () async {
      await redis.set('key', 'value', ex: 10);
      final ttl = await redis.ttl('key');
      expect(ttl, greaterThan(0));
      expect(ttl, lessThanOrEqualTo(10));
    });

    test('SET with NX — only if not exists', () async {
      await redis.set('key', 'first');
      await redis.set('key', 'second', nx: true);
      expect(await redis.get('key'), equals('first'));
    });

    test('SET with XX — only if exists', () async {
      final result = await redis.set('nokey', 'value', xx: true);
      expect(result, isNull);
    });

    test('GET returns null for missing key', () async {
      final result = await redis.get('nonexistent');
      expect(result, isNull);
    });

    test('MSET and MGET', () async {
      await redis.mset({'a': '1', 'b': '2', 'c': '3'});
      final result = await redis.mget(['a', 'b', 'c', 'missing']);
      expect(result, equals(['1', '2', '3', null]));
    });

    test('INCR and DECR', () async {
      await redis.set('counter', '10');
      expect(await redis.incr('counter'), equals(11));
      expect(await redis.decr('counter'), equals(10));
      expect(await redis.incrby('counter', 5), equals(15));
      expect(await redis.decrby('counter', 3), equals(12));
    });

    test('INCRBYFLOAT', () async {
      await redis.set('float', '10.5');
      final result = await redis.incrbyfloat('float', 0.1);
      expect(double.parse(result), closeTo(10.6, 0.001));
    });

    test('APPEND', () async {
      await redis.set('key', 'hello');
      await redis.append('key', ' world');
      expect(await redis.get('key'), equals('hello world'));
    });

    test('STRLEN', () async {
      await redis.set('key', 'hello');
      expect(await redis.strlen('key'), equals(5));
    });

    test('SETNX', () async {
      expect(await redis.setnx('key', 'value'), equals(1));
      expect(await redis.setnx('key', 'other'), equals(0));
      expect(await redis.get('key'), equals('value'));
    });

    test('SETEX', () async {
      await redis.setex('key', 10, 'value');
      expect(await redis.get('key'), equals('value'));
      expect(await redis.ttl('key'), greaterThan(0));
    });

    test('GETDEL', () async {
      await redis.set('key', 'value');
      expect(await redis.getdel('key'), equals('value'));
      expect(await redis.get('key'), isNull);
    });

    test('GETRANGE', () async {
      await redis.set('key', 'hello world');
      expect(await redis.getrange('key', 0, 4), equals('hello'));
    });

    test('SETRANGE', () async {
      await redis.set('key', 'hello world');
      await redis.setrange('key', 6, 'Redis');
      expect(await redis.get('key'), equals('hello Redis'));
    });
  });

  group('Key commands', () {
    test('DEL removes keys', () async {
      await redis.set('a', '1');
      await redis.set('b', '2');
      final deleted = await redis.del(['a', 'b', 'nonexistent']);
      expect(deleted, equals(2));
    });

    test('EXISTS', () async {
      await redis.set('key', 'value');
      expect(await redis.exists(['key']), equals(1));
      expect(await redis.exists(['nonexistent']), equals(0));
      expect(await redis.exists(['key', 'key']), equals(2));
    });

    test('EXPIRE and TTL', () async {
      await redis.set('key', 'value');
      await redis.expire('key', 100);
      final ttl = await redis.ttl('key');
      expect(ttl, greaterThan(0));
      expect(ttl, lessThanOrEqualTo(100));
    });

    test('PERSIST removes TTL', () async {
      await redis.set('key', 'value');
      await redis.expire('key', 100);
      await redis.persist('key');
      expect(await redis.ttl('key'), equals(-1));
    });

    test('TYPE', () async {
      await redis.set('str', 'value');
      await redis.lpush('list', ['a']);
      await redis.sadd('set', ['a']);
      expect(await redis.type('str'), equals('string'));
      expect(await redis.type('list'), equals('list'));
      expect(await redis.type('set'), equals('set'));
    });

    test('RENAME', () async {
      await redis.set('old', 'value');
      await redis.rename('old', 'new');
      expect(await redis.get('old'), isNull);
      expect(await redis.get('new'), equals('value'));
    });

    test('KEYS', () async {
      await redis.set('user:1', 'a');
      await redis.set('user:2', 'b');
      await redis.set('post:1', 'c');
      final keys = await redis.keys('user:*');
      expect(keys.length, equals(2));
      expect(keys, containsAll(['user:1', 'user:2']));
    });

    test('UNLINK', () async {
      await redis.set('key', 'value');
      expect(await redis.unlink(['key']), equals(1));
      expect(await redis.get('key'), isNull);
    });
  });

  group('Hash commands', () {
    test('HSET and HGET', () async {
      await redis.hset('hash', {'field': 'value'});
      expect(await redis.hget('hash', 'field'), equals('value'));
    });

    test('HSET multiple fields', () async {
      await redis.hset('hash', {'f1': 'v1', 'f2': 'v2', 'f3': 'v3'});
      expect(await redis.hget('hash', 'f1'), equals('v1'));
      expect(await redis.hget('hash', 'f2'), equals('v2'));
    });

    test('HGETALL', () async {
      await redis.hset('hash', {'name': 'Alice', 'age': '30'});
      final all = await redis.hgetall('hash');
      expect(all, equals({'name': 'Alice', 'age': '30'}));
    });

    test('HMGET', () async {
      await redis.hset('hash', {'a': '1', 'b': '2'});
      final result = await redis.hmget('hash', ['a', 'b', 'missing']);
      expect(result, equals(['1', '2', null]));
    });

    test('HDEL', () async {
      await redis.hset('hash', {'a': '1', 'b': '2'});
      expect(await redis.hdel('hash', ['a']), equals(1));
      expect(await redis.hget('hash', 'a'), isNull);
    });

    test('HEXISTS', () async {
      await redis.hset('hash', {'field': 'value'});
      expect(await redis.hexists('hash', 'field'), equals(1));
      expect(await redis.hexists('hash', 'nope'), equals(0));
    });

    test('HINCRBY', () async {
      await redis.hset('hash', {'counter': '10'});
      expect(await redis.hincrby('hash', 'counter', 5), equals(15));
    });

    test('HKEYS and HVALS', () async {
      await redis.hset('hash', {'a': '1', 'b': '2'});
      final keys = await redis.hkeys('hash');
      final vals = await redis.hvals('hash');
      expect(keys..sort(), equals(['a', 'b']));
      expect(vals..sort(), equals(['1', '2']));
    });

    test('HLEN', () async {
      await redis.hset('hash', {'a': '1', 'b': '2', 'c': '3'});
      expect(await redis.hlen('hash'), equals(3));
    });

    test('HSETNX', () async {
      await redis.hset('hash', {'field': 'original'});
      expect(await redis.hsetnx('hash', 'field', 'new'), equals(0));
      expect(await redis.hget('hash', 'field'), equals('original'));
      expect(await redis.hsetnx('hash', 'new_field', 'value'), equals(1));
    });
  });

  group('List commands', () {
    test('LPUSH and LRANGE', () async {
      await redis.lpush('list', ['c', 'b', 'a']);
      final result = await redis.lrange('list', 0, -1);
      expect(result, equals(['a', 'b', 'c']));
    });

    test('RPUSH', () async {
      await redis.rpush('list', ['a', 'b', 'c']);
      final result = await redis.lrange('list', 0, -1);
      expect(result, equals(['a', 'b', 'c']));
    });

    test('LPOP and RPOP', () async {
      await redis.rpush('list', ['a', 'b', 'c']);
      expect(await redis.lpop('list'), equals('a'));
      expect(await redis.rpop('list'), equals('c'));
    });

    test('LLEN', () async {
      await redis.rpush('list', ['a', 'b', 'c']);
      expect(await redis.llen('list'), equals(3));
    });

    test('LINDEX', () async {
      await redis.rpush('list', ['a', 'b', 'c']);
      expect(await redis.lindex('list', 0), equals('a'));
      expect(await redis.lindex('list', 2), equals('c'));
      expect(await redis.lindex('list', 99), isNull);
    });

    test('LSET', () async {
      await redis.rpush('list', ['a', 'b', 'c']);
      await redis.lset('list', 1, 'B');
      expect(await redis.lindex('list', 1), equals('B'));
    });

    test('LREM', () async {
      await redis.rpush('list', ['a', 'b', 'a', 'c', 'a']);
      expect(await redis.lrem('list', 2, 'a'), equals(2));
      expect(await redis.lrange('list', 0, -1), equals(['b', 'c', 'a']));
    });

    test('LTRIM', () async {
      await redis.rpush('list', ['a', 'b', 'c', 'd', 'e']);
      await redis.ltrim('list', 1, 3);
      expect(await redis.lrange('list', 0, -1), equals(['b', 'c', 'd']));
    });
  });

  group('Set commands', () {
    test('SADD and SMEMBERS', () async {
      await redis.sadd('set', ['a', 'b', 'c']);
      final members = await redis.smembers('set');
      expect(members..sort(), equals(['a', 'b', 'c']));
    });

    test('SREM', () async {
      await redis.sadd('set', ['a', 'b', 'c']);
      expect(await redis.srem('set', ['b']), equals(1));
      expect((await redis.smembers('set'))..sort(), equals(['a', 'c']));
    });

    test('SISMEMBER', () async {
      await redis.sadd('set', ['a', 'b']);
      expect(await redis.sismember('set', 'a'), equals(1));
      expect(await redis.sismember('set', 'z'), equals(0));
    });

    test('SCARD', () async {
      await redis.sadd('set', ['a', 'b', 'c']);
      expect(await redis.scard('set'), equals(3));
    });

    test('SDIFF, SINTER, SUNION', () async {
      await redis.sadd('s1', ['a', 'b', 'c']);
      await redis.sadd('s2', ['b', 'c', 'd']);
      expect((await redis.sdiff(['s1', 's2']))..sort(), equals(['a']));
      expect((await redis.sinter(['s1', 's2']))..sort(), equals(['b', 'c']));
      expect(
        (await redis.sunion(['s1', 's2']))..sort(),
        equals(['a', 'b', 'c', 'd']),
      );
    });
  });

  group('Sorted Set commands', () {
    test('ZADD and ZRANGE', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3});
      final result = await redis.zrange('zset', 0, -1);
      expect(result, equals(['a', 'b', 'c']));
    });

    test('ZSCORE', () async {
      await redis.zadd('zset', {'member': 42.5});
      expect(await redis.zscore('zset', 'member'), equals('42.5'));
    });

    test('ZRANK', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3});
      expect(await redis.zrank('zset', 'a'), equals(0));
      expect(await redis.zrank('zset', 'c'), equals(2));
    });

    test('ZREM', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3});
      expect(await redis.zrem('zset', ['b']), equals(1));
      expect(await redis.zcard('zset'), equals(2));
    });

    test('ZCOUNT', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      expect(await redis.zcount('zset', 2, 3), equals(2));
    });

    test('ZINCRBY', () async {
      await redis.zadd('zset', {'member': 10});
      expect(await redis.zincrby('zset', 5, 'member'), equals('15'));
    });

    test('ZRANGEBYSCORE', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3, 'd': 4});
      final result = await redis.zrangebyscore('zset', 2, 3);
      expect(result, equals(['b', 'c']));
    });

    test('ZREVRANGE', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2, 'c': 3});
      final result = await redis.zrevrange('zset', 0, -1);
      expect(result, equals(['c', 'b', 'a']));
    });

    test('ZRANGE with WITHSCORES', () async {
      await redis.zadd('zset', {'a': 1, 'b': 2});
      final result = await redis.zrange('zset', 0, -1, withScores: true);
      expect(result, equals(['a', '1', 'b', '2']));
    });
  });

  group('Expiry commands', () {
    test('PEXPIRE and PTTL', () async {
      await redis.set('key', 'value');
      await redis.pexpire('key', 10000);
      final pttl = await redis.pttl('key');
      expect(pttl, greaterThan(0));
      expect(pttl, lessThanOrEqualTo(10000));
    });
  });

  group('Pipeline', () {
    test('executes multiple commands in batch', () async {
      final pipe = redis.pipeline();
      pipe.addCommand('SET', ['p1', 'v1']);
      pipe.addCommand('SET', ['p2', 'v2']);
      pipe.addCommand('GET', ['p1']);
      pipe.addCommand('GET', ['p2']);
      final results = await pipe.exec();

      expect(results.length, equals(4));
      expect(results[0], equals((null, 'OK')));
      expect(results[1], equals((null, 'OK')));
      expect(results[2], equals((null, 'v1')));
      expect(results[3], equals((null, 'v2')));
    });

    test('error in one command does not break others', () async {
      await redis.set('str_key', 'value');
      final pipe = redis.pipeline();
      pipe.addCommand('GET', ['str_key']);
      pipe.addCommand('LPUSH', ['str_key', 'oops']); // WRONGTYPE error
      pipe.addCommand('GET', ['str_key']);
      final results = await pipe.exec();

      expect(results[0].$2, equals('value'));
      expect(results[1].$1, isNotNull); // error
      expect(results[2].$2, equals('value'));
    });
  });

  group('Transaction (MULTI/EXEC)', () {
    test('executes atomically', () async {
      await redis.set('counter', '0');
      final tx = redis.multi();
      tx.addCommand('INCR', ['counter']);
      tx.addCommand('INCR', ['counter']);
      tx.addCommand('INCR', ['counter']);
      final results = await tx.exec();

      // MULTI → OK, 3x INCR → QUEUED, EXEC → [1, 2, 3]
      expect(await redis.get('counter'), equals('3'));
      expect(results.length, greaterThan(0));
    });
  });

  group('Pub/Sub', () {
    test('subscribe and receive message', () async {
      // Create a separate subscriber connection
      final sub = Redis(RedisOptions(port: docker.port, lazyConnect: true));
      await sub.connect();

      final messages = <PubSubMessage>[];
      sub.messages.listen(messages.add);

      await sub.subscribe(['test-channel']);

      // Give subscription time to register
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Publish from main client
      final receivers = await redis.publish('test-channel', 'hello');
      expect(receivers, greaterThanOrEqualTo(1));

      // Wait for message delivery
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(messages, hasLength(1));
      expect(messages[0].channel, equals('test-channel'));
      expect(messages[0].message, equals('hello'));

      await sub.close();
    });
  });

  group('Scan', () {
    test('SCAN iterates all keys', () async {
      for (var i = 0; i < 20; i++) {
        await redis.set('scan:$i', 'value');
      }

      final keys = <String>[];
      await for (final key in redis.scan(match: 'scan:*')) {
        keys.add(key);
      }
      expect(keys.length, equals(20));
    });

    test('HSCAN iterates hash fields', () async {
      final fields = <String, Object>{};
      for (var i = 0; i < 20; i++) {
        fields['field:$i'] = 'value:$i';
      }
      await redis.hset('hscan-key', fields);

      final scanned = <String>[];
      await for (final item in redis.hscan('hscan-key')) {
        scanned.add(item);
      }
      // HSCAN returns field-value pairs interleaved
      expect(scanned.length, equals(40)); // 20 fields * 2
    });
  });

  group('Script', () {
    test('EVAL executes Lua script', () async {
      final result = await redis.eval_(
        "return redis.call('SET', KEYS[1], ARGV[1])",
        1,
        ['lua-key', 'lua-value'],
      );
      expect(result.toString(), equals('OK'));
      expect(await redis.get('lua-key'), equals('lua-value'));
    });

    test('SCRIPT LOAD and EVALSHA', () async {
      final script = "return redis.call('GET', KEYS[1])";
      final sha = await redis.scriptLoad(script);

      await redis.set('sha-key', 'sha-value');
      final result = await redis.evalsha(sha, 1, ['sha-key']);
      expect(result, equals('sha-value'));
    });
  });

  group('Duplicate', () {
    test('creates independent client with same options', () async {
      final dup = redis.duplicate(
        RedisOptions(port: docker.port, lazyConnect: true),
      );
      await dup.connect();

      await redis.set('dup-key', 'from-original');
      expect(await dup.get('dup-key'), equals('from-original'));

      await dup.close();
    });
  });

  group('Binary safe', () {
    test('SET and GET binary-safe strings', () async {
      await redis.set('bin', 'hello\x00world');
      final result = await redis.get('bin');
      expect(result, equals('hello\x00world'));
    });
  });
}
