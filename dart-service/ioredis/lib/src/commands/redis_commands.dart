import '../client/redis.dart';
import '../scripting/scan_stream.dart';

/// All Redis commands as typed methods on the Redis client.
///
/// Organized by category matching Redis documentation.
/// Each method delegates to [Redis.call] with proper argument building.
extension RedisCommands on Redis {
  // ===== Connection =====

  Future<String> ping([String? message]) async {
    final result = await this.call('PING', [if (message != null) message]);
    return result.toString();
  }

  Future<String> echo(String message) async {
    final result = await this.call('ECHO', [message]);
    return result.toString();
  }

  Future<String> quit() async {
    final result = await this.call('QUIT');
    return result.toString();
  }

  Future<String> auth(String passwordOrUsername, [String? password]) async {
    if (password != null) {
      final result = await this.call('AUTH', [passwordOrUsername, password]);
      return result.toString();
    }
    final result = await this.call('AUTH', [passwordOrUsername]);
    return result.toString();
  }

  Future<String> select(int db) async {
    final result = await this.call('SELECT', [db]);
    return result.toString();
  }

  Future<String> swapdb(int index1, int index2) async {
    final result = await this.call('SWAPDB', [index1, index2]);
    return result.toString();
  }

  // ===== String =====

  Future<String?> get(String key) async {
    final result = await this.call('GET', [key]);
    return result?.toString();
  }

  Future<String?> set(
    String key,
    Object value, {
    int? ex,
    int? px,
    int? exat,
    int? pxat,
    bool? nx,
    bool? xx,
    bool? keepTtl,
    bool? get_,
  }) async {
    final args = <Object?>[key, value];
    if (ex != null) args.addAll(['EX', ex]);
    if (px != null) args.addAll(['PX', px]);
    if (exat != null) args.addAll(['EXAT', exat]);
    if (pxat != null) args.addAll(['PXAT', pxat]);
    if (nx == true) args.add('NX');
    if (xx == true) args.add('XX');
    if (keepTtl == true) args.add('KEEPTTL');
    if (get_ == true) args.add('GET');
    final result = await this.call('SET', args);
    return result?.toString();
  }

  Future<String?> getdel(String key) async {
    final result = await this.call('GETDEL', [key]);
    return result?.toString();
  }

  Future<String?> getex(String key, {int? ex, int? px, int? exat, int? pxat, bool? persist}) async {
    final args = <Object?>[key];
    if (ex != null) args.addAll(['EX', ex]);
    if (px != null) args.addAll(['PX', px]);
    if (exat != null) args.addAll(['EXAT', exat]);
    if (pxat != null) args.addAll(['PXAT', pxat]);
    if (persist == true) args.add('PERSIST');
    final result = await this.call('GETEX', args);
    return result?.toString();
  }

  Future<String?> getrange(String key, int start, int end) async {
    final result = await this.call('GETRANGE', [key, start, end]);
    return result?.toString();
  }

  Future<String?> getset(String key, Object value) async {
    final result = await this.call('GETSET', [key, value]);
    return result?.toString();
  }

  Future<List<String?>> mget(List<String> keys) async {
    final result = await this.call('MGET', keys);
    return (result as List).map((e) => e?.toString()).toList();
  }

  Future<String> mset(Map<String, Object> pairs) async {
    final result = await this.call('MSET', [pairs]);
    return result.toString();
  }

  Future<int> msetnx(Map<String, Object> pairs) async {
    final result = await this.call('MSETNX', [pairs]);
    return result as int;
  }

  Future<int> append(String key, String value) async {
    final result = await this.call('APPEND', [key, value]);
    return result as int;
  }

  Future<int> incr(String key) async {
    final result = await this.call('INCR', [key]);
    return result as int;
  }

  Future<int> incrby(String key, int increment) async {
    final result = await this.call('INCRBY', [key, increment]);
    return result as int;
  }

  Future<String> incrbyfloat(String key, double increment) async {
    final result = await this.call('INCRBYFLOAT', [key, increment]);
    return result.toString();
  }

  Future<int> decr(String key) async {
    final result = await this.call('DECR', [key]);
    return result as int;
  }

  Future<int> decrby(String key, int decrement) async {
    final result = await this.call('DECRBY', [key, decrement]);
    return result as int;
  }

  Future<int> strlen(String key) async {
    final result = await this.call('STRLEN', [key]);
    return result as int;
  }

  Future<String> setex(String key, int seconds, Object value) async {
    final result = await this.call('SETEX', [key, seconds, value]);
    return result.toString();
  }

  Future<String> psetex(String key, int milliseconds, Object value) async {
    final result = await this.call('PSETEX', [key, milliseconds, value]);
    return result.toString();
  }

  Future<int> setnx(String key, Object value) async {
    final result = await this.call('SETNX', [key, value]);
    return result as int;
  }

  Future<int> setrange(String key, int offset, String value) async {
    final result = await this.call('SETRANGE', [key, offset, value]);
    return result as int;
  }

  Future<String?> substr(String key, int start, int end) async {
    final result = await this.call('SUBSTR', [key, start, end]);
    return result?.toString();
  }

  // ===== Key =====

  Future<int> del(List<String> keys) async {
    final result = await this.call('DEL', keys);
    return result as int;
  }

  Future<int> unlink(List<String> keys) async {
    final result = await this.call('UNLINK', keys);
    return result as int;
  }

  Future<int> exists(List<String> keys) async {
    final result = await this.call('EXISTS', keys);
    return result as int;
  }

  Future<int> expire(String key, int seconds, {String? mode}) async {
    final args = <Object?>[key, seconds];
    if (mode != null) args.add(mode);
    final result = await this.call('EXPIRE', args);
    return result as int;
  }

  Future<int> expireat(String key, int timestamp, {String? mode}) async {
    final args = <Object?>[key, timestamp];
    if (mode != null) args.add(mode);
    final result = await this.call('EXPIREAT', args);
    return result as int;
  }

  Future<int> pexpire(String key, int milliseconds, {String? mode}) async {
    final args = <Object?>[key, milliseconds];
    if (mode != null) args.add(mode);
    final result = await this.call('PEXPIRE', args);
    return result as int;
  }

  Future<int> pexpireat(String key, int timestamp, {String? mode}) async {
    final args = <Object?>[key, timestamp];
    if (mode != null) args.add(mode);
    final result = await this.call('PEXPIREAT', args);
    return result as int;
  }

  Future<int> persist(String key) async {
    final result = await this.call('PERSIST', [key]);
    return result as int;
  }

  Future<int> ttl(String key) async {
    final result = await this.call('TTL', [key]);
    return result as int;
  }

  Future<int> pttl(String key) async {
    final result = await this.call('PTTL', [key]);
    return result as int;
  }

  Future<int> expiretime(String key) async {
    final result = await this.call('EXPIRETIME', [key]);
    return result as int;
  }

  Future<int> pexpiretime(String key) async {
    final result = await this.call('PEXPIRETIME', [key]);
    return result as int;
  }

  Future<String> type(String key) async {
    final result = await this.call('TYPE', [key]);
    return result.toString();
  }

  Future<String?> randomkey() async {
    final result = await this.call('RANDOMKEY');
    return result?.toString();
  }

  Future<String> rename(String key, String newKey) async {
    final result = await this.call('RENAME', [key, newKey]);
    return result.toString();
  }

  Future<int> renamenx(String key, String newKey) async {
    final result = await this.call('RENAMENX', [key, newKey]);
    return result as int;
  }

  Future<List<String>> keys(String pattern) async {
    final result = await this.call('KEYS', [pattern]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<String?> dump(String key) async {
    final result = await this.call('DUMP', [key]);
    return result?.toString();
  }

  Future<String> restore(String key, int ttl, String serializedValue, {bool? replace, bool? absttl, int? idletime, int? freq}) async {
    final args = <Object?>[key, ttl, serializedValue];
    if (replace == true) args.add('REPLACE');
    if (absttl == true) args.add('ABSTTL');
    if (idletime != null) args.addAll(['IDLETIME', idletime]);
    if (freq != null) args.addAll(['FREQ', freq]);
    final result = await this.call('RESTORE', args);
    return result.toString();
  }

  Future<int> move(String key, int db) async {
    final result = await this.call('MOVE', [key, db]);
    return result as int;
  }

  Future<int> touch(List<String> keys) async {
    final result = await this.call('TOUCH', keys);
    return result as int;
  }

  Future<int> objectRefcount(String key) async {
    final result = await this.call('OBJECT', ['REFCOUNT', key]);
    return result as int;
  }

  Future<String?> objectEncoding(String key) async {
    final result = await this.call('OBJECT', ['ENCODING', key]);
    return result?.toString();
  }

  Future<int> objectIdletime(String key) async {
    final result = await this.call('OBJECT', ['IDLETIME', key]);
    return result as int;
  }

  Future<int> objectFreq(String key) async {
    final result = await this.call('OBJECT', ['FREQ', key]);
    return result as int;
  }

  Future<int> wait_(int numReplicas, int timeout) async {
    final result = await this.call('WAIT', [numReplicas, timeout]);
    return result as int;
  }

  // ===== SCAN =====

  Stream<String> scan({String? match, int? count, String? type}) {
    return scanStream(this, options: ScanOptions(match: match, count: count, type: type));
  }

  // ===== Hash =====

  Future<int> hset(String key, Map<String, Object> fieldValues) async {
    final args = <Object?>[key];
    for (final entry in fieldValues.entries) {
      args.addAll([entry.key, entry.value]);
    }
    final result = await this.call('HSET', args);
    return result as int;
  }

  Future<String?> hget(String key, String field) async {
    final result = await this.call('HGET', [key, field]);
    return result?.toString();
  }

  Future<int> hsetnx(String key, String field, Object value) async {
    final result = await this.call('HSETNX', [key, field, value]);
    return result as int;
  }

  Future<String> hmset(String key, Map<String, Object> fieldValues) async {
    final args = <Object?>[key];
    for (final entry in fieldValues.entries) {
      args.addAll([entry.key, entry.value]);
    }
    final result = await this.call('HMSET', args);
    return result.toString();
  }

  Future<List<String?>> hmget(String key, List<String> fields) async {
    final result = await this.call('HMGET', [key, ...fields]);
    return (result as List).map((e) => e?.toString()).toList();
  }

  Future<Map<String, String>> hgetall(String key) async {
    final result = await this.call('HGETALL', [key]);
    if (result is Map) {
      return result.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  Future<int> hdel(String key, List<String> fields) async {
    final result = await this.call('HDEL', [key, ...fields]);
    return result as int;
  }

  Future<int> hexists(String key, String field) async {
    final result = await this.call('HEXISTS', [key, field]);
    return result as int;
  }

  Future<int> hincrby(String key, String field, int increment) async {
    final result = await this.call('HINCRBY', [key, field, increment]);
    return result as int;
  }

  Future<String> hincrbyfloat(String key, String field, double increment) async {
    final result = await this.call('HINCRBYFLOAT', [key, field, increment]);
    return result.toString();
  }

  Future<List<String>> hkeys(String key) async {
    final result = await this.call('HKEYS', [key]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> hvals(String key) async {
    final result = await this.call('HVALS', [key]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> hlen(String key) async {
    final result = await this.call('HLEN', [key]);
    return result as int;
  }

  Future<int> hstrlen(String key, String field) async {
    final result = await this.call('HSTRLEN', [key, field]);
    return result as int;
  }

  Future<List<String>> hrandfield(String key, {int? count, bool? withValues}) async {
    final args = <Object?>[key];
    if (count != null) args.add(count);
    if (withValues == true) args.add('WITHVALUES');
    final result = await this.call('HRANDFIELD', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return [result.toString()];
  }

  Stream<String> hscan(String key, {String? match, int? count}) {
    return scanStream(this, command: 'HSCAN', key: key, options: ScanOptions(match: match, count: count));
  }

  // ===== List =====

  Future<int> lpush(String key, List<Object> values) async {
    final result = await this.call('LPUSH', [key, ...values]);
    return result as int;
  }

  Future<int> rpush(String key, List<Object> values) async {
    final result = await this.call('RPUSH', [key, ...values]);
    return result as int;
  }

  Future<int> lpushx(String key, List<Object> values) async {
    final result = await this.call('LPUSHX', [key, ...values]);
    return result as int;
  }

  Future<int> rpushx(String key, List<Object> values) async {
    final result = await this.call('RPUSHX', [key, ...values]);
    return result as int;
  }

  Future<String?> lpop(String key) async {
    final result = await this.call('LPOP', [key]);
    return result?.toString();
  }

  Future<String?> rpop(String key) async {
    final result = await this.call('RPOP', [key]);
    return result?.toString();
  }

  Future<List<String>> lrange(String key, int start, int stop) async {
    final result = await this.call('LRANGE', [key, start, stop]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> llen(String key) async {
    final result = await this.call('LLEN', [key]);
    return result as int;
  }

  Future<String?> lindex(String key, int index) async {
    final result = await this.call('LINDEX', [key, index]);
    return result?.toString();
  }

  Future<String> lset(String key, int index, Object value) async {
    final result = await this.call('LSET', [key, index, value]);
    return result.toString();
  }

  Future<int> linsert(String key, String position, Object pivot, Object value) async {
    final result = await this.call('LINSERT', [key, position, pivot, value]);
    return result as int;
  }

  Future<int> lrem(String key, int count, Object value) async {
    final result = await this.call('LREM', [key, count, value]);
    return result as int;
  }

  Future<String> ltrim(String key, int start, int stop) async {
    final result = await this.call('LTRIM', [key, start, stop]);
    return result.toString();
  }

  Future<String?> rpoplpush(String source, String destination) async {
    final result = await this.call('RPOPLPUSH', [source, destination]);
    return result?.toString();
  }

  Future<String?> lmove(String source, String destination, String from, String to) async {
    final result = await this.call('LMOVE', [source, destination, from, to]);
    return result?.toString();
  }

  Future<List<String>?> lpos(String key, Object element, {int? rank, int? count, int? maxLen}) async {
    final args = <Object?>[key, element];
    if (rank != null) args.addAll(['RANK', rank]);
    if (count != null) args.addAll(['COUNT', count]);
    if (maxLen != null) args.addAll(['MAXLEN', maxLen]);
    final result = await this.call('LPOS', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return result != null ? [result.toString()] : null;
  }

  // Blocking list operations

  Future<List<String>?> blpop(List<String> keys, int timeout) async {
    final result = await this.call('BLPOP', [...keys, timeout]);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<List<String>?> brpop(List<String> keys, int timeout) async {
    final result = await this.call('BRPOP', [...keys, timeout]);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<String?> brpoplpush(String source, String destination, int timeout) async {
    final result = await this.call('BRPOPLPUSH', [source, destination, timeout]);
    return result?.toString();
  }

  Future<String?> blmove(String source, String destination, String from, String to, int timeout) async {
    final result = await this.call('BLMOVE', [source, destination, from, to, timeout]);
    return result?.toString();
  }

  // ===== Set =====

  Future<int> sadd(String key, List<Object> members) async {
    final result = await this.call('SADD', [key, ...members]);
    return result as int;
  }

  Future<int> srem(String key, List<Object> members) async {
    final result = await this.call('SREM', [key, ...members]);
    return result as int;
  }

  Future<List<String>> smembers(String key) async {
    final result = await this.call('SMEMBERS', [key]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> sismember(String key, Object member) async {
    final result = await this.call('SISMEMBER', [key, member]);
    return result as int;
  }

  Future<List<int>> smismember(String key, List<Object> members) async {
    final result = await this.call('SMISMEMBER', [key, ...members]);
    return (result as List).cast<int>();
  }

  Future<int> scard(String key) async {
    final result = await this.call('SCARD', [key]);
    return result as int;
  }

  Future<int> smove(String source, String destination, Object member) async {
    final result = await this.call('SMOVE', [source, destination, member]);
    return result as int;
  }

  Future<String?> spop(String key) async {
    final result = await this.call('SPOP', [key]);
    return result?.toString();
  }

  Future<List<String>> srandmember(String key, [int? count]) async {
    final args = <Object?>[key];
    if (count != null) args.add(count);
    final result = await this.call('SRANDMEMBER', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return result != null ? [result.toString()] : [];
  }

  Future<List<String>> sdiff(List<String> keys) async {
    final result = await this.call('SDIFF', keys);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> sdiffstore(String destination, List<String> keys) async {
    final result = await this.call('SDIFFSTORE', [destination, ...keys]);
    return result as int;
  }

  Future<List<String>> sinter(List<String> keys) async {
    final result = await this.call('SINTER', keys);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> sinterstore(String destination, List<String> keys) async {
    final result = await this.call('SINTERSTORE', [destination, ...keys]);
    return result as int;
  }

  Future<int> sintercard(int numKeys, List<String> keys, {int? limit}) async {
    final args = <Object?>[numKeys, ...keys];
    if (limit != null) args.addAll(['LIMIT', limit]);
    final result = await this.call('SINTERCARD', args);
    return result as int;
  }

  Future<List<String>> sunion(List<String> keys) async {
    final result = await this.call('SUNION', keys);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> sunionstore(String destination, List<String> keys) async {
    final result = await this.call('SUNIONSTORE', [destination, ...keys]);
    return result as int;
  }

  Stream<String> sscan(String key, {String? match, int? count}) {
    return scanStream(this, command: 'SSCAN', key: key, options: ScanOptions(match: match, count: count));
  }

  // ===== Sorted Set =====

  Future<int> zadd(String key, Map<String, double> members, {bool? nx, bool? xx, bool? gt, bool? lt, bool? ch}) async {
    final args = <Object?>[key];
    if (nx == true) args.add('NX');
    if (xx == true) args.add('XX');
    if (gt == true) args.add('GT');
    if (lt == true) args.add('LT');
    if (ch == true) args.add('CH');
    for (final entry in members.entries) {
      args.addAll([entry.value, entry.key]);
    }
    final result = await this.call('ZADD', args);
    return result as int;
  }

  Future<int> zcard(String key) async {
    final result = await this.call('ZCARD', [key]);
    return result as int;
  }

  Future<int> zcount(String key, Object min, Object max) async {
    final result = await this.call('ZCOUNT', [key, min, max]);
    return result as int;
  }

  Future<String> zincrby(String key, double increment, String member) async {
    final result = await this.call('ZINCRBY', [key, increment, member]);
    return result.toString();
  }

  Future<String?> zscore(String key, String member) async {
    final result = await this.call('ZSCORE', [key, member]);
    return result?.toString();
  }

  Future<List<String?>> zmscore(String key, List<String> members) async {
    final result = await this.call('ZMSCORE', [key, ...members]);
    return (result as List).map((e) => e?.toString()).toList();
  }

  Future<int?> zrank(String key, String member) async {
    final result = await this.call('ZRANK', [key, member]);
    return result as int?;
  }

  Future<int?> zrevrank(String key, String member) async {
    final result = await this.call('ZREVRANK', [key, member]);
    return result as int?;
  }

  Future<int> zrem(String key, List<String> members) async {
    final result = await this.call('ZREM', [key, ...members]);
    return result as int;
  }

  Future<List<String>> zrange(String key, Object start, Object stop, {bool? withScores, String? by, bool? rev, List<int>? limit}) async {
    final args = <Object?>[key, start, stop];
    if (by != null) args.add(by);
    if (rev == true) args.add('REV');
    if (limit != null) args.addAll(['LIMIT', limit[0], limit[1]]);
    if (withScores == true) args.add('WITHSCORES');
    final result = await this.call('ZRANGE', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> zrangebyscore(String key, Object min, Object max, {bool? withScores, int? offset, int? count}) async {
    final args = <Object?>[key, min, max];
    if (withScores == true) args.add('WITHSCORES');
    if (offset != null && count != null) args.addAll(['LIMIT', offset, count]);
    final result = await this.call('ZRANGEBYSCORE', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> zrevrangebyscore(String key, Object max, Object min, {bool? withScores, int? offset, int? count}) async {
    final args = <Object?>[key, max, min];
    if (withScores == true) args.add('WITHSCORES');
    if (offset != null && count != null) args.addAll(['LIMIT', offset, count]);
    final result = await this.call('ZREVRANGEBYSCORE', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> zrangebylex(String key, String min, String max, {int? offset, int? count}) async {
    final args = <Object?>[key, min, max];
    if (offset != null && count != null) args.addAll(['LIMIT', offset, count]);
    final result = await this.call('ZRANGEBYLEX', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> zrevrange(String key, int start, int stop, {bool? withScores}) async {
    final args = <Object?>[key, start, stop];
    if (withScores == true) args.add('WITHSCORES');
    final result = await this.call('ZREVRANGE', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<int> zremrangebyscore(String key, Object min, Object max) async {
    final result = await this.call('ZREMRANGEBYSCORE', [key, min, max]);
    return result as int;
  }

  Future<int> zremrangebyrank(String key, int start, int stop) async {
    final result = await this.call('ZREMRANGEBYRANK', [key, start, stop]);
    return result as int;
  }

  Future<int> zremrangebylex(String key, String min, String max) async {
    final result = await this.call('ZREMRANGEBYLEX', [key, min, max]);
    return result as int;
  }

  Future<int> zlexcount(String key, String min, String max) async {
    final result = await this.call('ZLEXCOUNT', [key, min, max]);
    return result as int;
  }

  Future<List<String>?> zpopmin(String key, [int? count]) async {
    final args = <Object?>[key];
    if (count != null) args.add(count);
    final result = await this.call('ZPOPMIN', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<List<String>?> zpopmax(String key, [int? count]) async {
    final args = <Object?>[key];
    if (count != null) args.add(count);
    final result = await this.call('ZPOPMAX', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<List<String>?> bzpopmin(List<String> keys, int timeout) async {
    final result = await this.call('BZPOPMIN', [...keys, timeout]);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<List<String>?> bzpopmax(List<String> keys, int timeout) async {
    final result = await this.call('BZPOPMAX', [...keys, timeout]);
    if (result is List) return result.map((e) => e.toString()).toList();
    return null;
  }

  Future<int> zunionstore(String destination, List<String> keys, {List<double>? weights, String? aggregate}) async {
    final args = <Object?>[destination, keys.length, ...keys];
    if (weights != null) { args.add('WEIGHTS'); args.addAll(weights); }
    if (aggregate != null) args.addAll(['AGGREGATE', aggregate]);
    final result = await this.call('ZUNIONSTORE', args);
    return result as int;
  }

  Future<int> zinterstore(String destination, List<String> keys, {List<double>? weights, String? aggregate}) async {
    final args = <Object?>[destination, keys.length, ...keys];
    if (weights != null) { args.add('WEIGHTS'); args.addAll(weights); }
    if (aggregate != null) args.addAll(['AGGREGATE', aggregate]);
    final result = await this.call('ZINTERSTORE', args);
    return result as int;
  }

  Future<List<String>> zrandmember(String key, {int? count, bool? withScores}) async {
    final args = <Object?>[key];
    if (count != null) args.add(count);
    if (withScores == true) args.add('WITHSCORES');
    final result = await this.call('ZRANDMEMBER', args);
    if (result is List) return result.map((e) => e.toString()).toList();
    return [result.toString()];
  }

  Future<int> zrangestore(String destination, String source, Object min, Object max, {String? by, bool? rev, List<int>? limit}) async {
    final args = <Object?>[destination, source, min, max];
    if (by != null) args.add(by);
    if (rev == true) args.add('REV');
    if (limit != null) args.addAll(['LIMIT', limit[0], limit[1]]);
    final result = await this.call('ZRANGESTORE', args);
    return result as int;
  }

  Stream<String> zscan(String key, {String? match, int? count}) {
    return scanStream(this, command: 'ZSCAN', key: key, options: ScanOptions(match: match, count: count));
  }

  // ===== HyperLogLog =====

  Future<int> pfadd(String key, List<Object> elements) async {
    final result = await this.call('PFADD', [key, ...elements]);
    return result as int;
  }

  Future<int> pfcount(List<String> keys) async {
    final result = await this.call('PFCOUNT', keys);
    return result as int;
  }

  Future<String> pfmerge(String destination, List<String> sources) async {
    final result = await this.call('PFMERGE', [destination, ...sources]);
    return result.toString();
  }

  // ===== Bitmap =====

  Future<int> setbit(String key, int offset, int value) async {
    final result = await this.call('SETBIT', [key, offset, value]);
    return result as int;
  }

  Future<int> getbit(String key, int offset) async {
    final result = await this.call('GETBIT', [key, offset]);
    return result as int;
  }

  Future<int> bitcount(String key, [int? start, int? end]) async {
    final args = <Object?>[key];
    if (start != null) args.add(start);
    if (end != null) args.add(end);
    final result = await this.call('BITCOUNT', args);
    return result as int;
  }

  Future<int> bitpos(String key, int bit, [int? start, int? end]) async {
    final args = <Object?>[key, bit];
    if (start != null) args.add(start);
    if (end != null) args.add(end);
    final result = await this.call('BITPOS', args);
    return result as int;
  }

  Future<int> bitop(String operation, String destKey, List<String> keys) async {
    final result = await this.call('BITOP', [operation, destKey, ...keys]);
    return result as int;
  }

  // ===== Geo =====

  Future<int> geoadd(String key, List<({double longitude, double latitude, String member})> members, {bool? nx, bool? xx, bool? ch}) async {
    final args = <Object?>[key];
    if (nx == true) args.add('NX');
    if (xx == true) args.add('XX');
    if (ch == true) args.add('CH');
    for (final m in members) {
      args.addAll([m.longitude, m.latitude, m.member]);
    }
    final result = await this.call('GEOADD', args);
    return result as int;
  }

  Future<String?> geodist(String key, String member1, String member2, [String? unit]) async {
    final args = <Object?>[key, member1, member2];
    if (unit != null) args.add(unit);
    final result = await this.call('GEODIST', args);
    return result?.toString();
  }

  Future<List<String?>> geohash(String key, List<String> members) async {
    final result = await this.call('GEOHASH', [key, ...members]);
    return (result as List).map((e) => e?.toString()).toList();
  }

  Future<List<Object?>> geopos(String key, List<String> members) async {
    final result = await this.call('GEOPOS', [key, ...members]);
    return result as List<Object?>;
  }

  Future<List<Object?>> geosearch(String key, {Object? fromMember, List<double>? fromLonLat, double? byRadius, String? radiusUnit, List<double>? byBox, String? boxUnit, String? order, int? count, bool? any, bool? withCoord, bool? withDist, bool? withHash}) async {
    final args = <Object?>[key];
    if (fromMember != null) args.addAll(['FROMMEMBER', fromMember]);
    if (fromLonLat != null) args.addAll(['FROMLONLAT', fromLonLat[0], fromLonLat[1]]);
    if (byRadius != null) args.addAll(['BYRADIUS', byRadius, radiusUnit ?? 'm']);
    if (byBox != null) args.addAll(['BYBOX', byBox[0], byBox[1], boxUnit ?? 'm']);
    if (order != null) args.add(order);
    if (count != null) { args.addAll(['COUNT', count]); if (any == true) args.add('ANY'); }
    if (withCoord == true) args.add('WITHCOORD');
    if (withDist == true) args.add('WITHDIST');
    if (withHash == true) args.add('WITHHASH');
    final result = await this.call('GEOSEARCH', args);
    return result as List<Object?>;
  }

  // ===== Stream =====

  Future<String> xadd(String key, Map<String, Object> fields, {String? id, int? maxLen, bool? approx, String? minId}) async {
    final args = <Object?>[key];
    if (maxLen != null) { args.add('MAXLEN'); if (approx == true) args.add('~'); args.add(maxLen); }
    if (minId != null) { args.add('MINID'); if (approx == true) args.add('~'); args.add(minId); }
    args.add(id ?? '*');
    for (final entry in fields.entries) {
      args.addAll([entry.key, entry.value]);
    }
    final result = await this.call('XADD', args);
    return result.toString();
  }

  Future<int> xlen(String key) async {
    final result = await this.call('XLEN', [key]);
    return result as int;
  }

  Future<List<Object?>> xrange(String key, String start, String end, {int? count}) async {
    final args = <Object?>[key, start, end];
    if (count != null) args.addAll(['COUNT', count]);
    final result = await this.call('XRANGE', args);
    return result as List<Object?>;
  }

  Future<List<Object?>> xrevrange(String key, String end, String start, {int? count}) async {
    final args = <Object?>[key, end, start];
    if (count != null) args.addAll(['COUNT', count]);
    final result = await this.call('XREVRANGE', args);
    return result as List<Object?>;
  }

  Future<int> xdel(String key, List<String> ids) async {
    final result = await this.call('XDEL', [key, ...ids]);
    return result as int;
  }

  Future<int> xtrim(String key, {int? maxLen, bool? approx, String? minId}) async {
    final args = <Object?>[key];
    if (maxLen != null) { args.add('MAXLEN'); if (approx == true) args.add('~'); args.add(maxLen); }
    if (minId != null) { args.add('MINID'); if (approx == true) args.add('~'); args.add(minId); }
    final result = await this.call('XTRIM', args);
    return result as int;
  }

  Future<Object?> xread(Map<String, String> streams, {int? count, int? block}) async {
    final args = <Object?>[];
    if (count != null) args.addAll(['COUNT', count]);
    if (block != null) args.addAll(['BLOCK', block]);
    args.add('STREAMS');
    args.addAll(streams.keys);
    args.addAll(streams.values);
    return this.call('XREAD', args);
  }

  Future<String> xgroupCreate(String key, String group, String id, {bool? mkstream}) async {
    final args = <Object?>[key, group, id];
    if (mkstream == true) args.add('MKSTREAM');
    final result = await this.call('XGROUP', ['CREATE', ...args]);
    return result.toString();
  }

  Future<int> xgroupDestroy(String key, String group) async {
    final result = await this.call('XGROUP', ['DESTROY', key, group]);
    return result as int;
  }

  Future<String> xgroupSetid(String key, String group, String id) async {
    final result = await this.call('XGROUP', ['SETID', key, group, id]);
    return result.toString();
  }

  Future<int> xgroupDelconsumer(String key, String group, String consumer) async {
    final result = await this.call('XGROUP', ['DELCONSUMER', key, group, consumer]);
    return result as int;
  }

  Future<Object?> xreadgroup(String group, String consumer, Map<String, String> streams, {int? count, int? block, bool? noack}) async {
    final args = <Object?>['GROUP', group, consumer];
    if (count != null) args.addAll(['COUNT', count]);
    if (block != null) args.addAll(['BLOCK', block]);
    if (noack == true) args.add('NOACK');
    args.add('STREAMS');
    args.addAll(streams.keys);
    args.addAll(streams.values);
    return this.call('XREADGROUP', args);
  }

  Future<int> xack(String key, String group, List<String> ids) async {
    final result = await this.call('XACK', [key, group, ...ids]);
    return result as int;
  }

  Future<Object?> xpending(String key, String group, {String? start, String? end, int? count, String? consumer}) async {
    final args = <Object?>[key, group];
    if (start != null && end != null && count != null) {
      args.addAll([start, end, count]);
      if (consumer != null) args.add(consumer);
    }
    return this.call('XPENDING', args);
  }

  Future<Object?> xclaim(String key, String group, String consumer, int minIdleTime, List<String> ids, {bool? justid}) async {
    final args = <Object?>[key, group, consumer, minIdleTime, ...ids];
    if (justid == true) args.add('JUSTID');
    return this.call('XCLAIM', args);
  }

  Future<Object?> xautoclaim(String key, String group, String consumer, int minIdleTime, String start, {int? count, bool? justid}) async {
    final args = <Object?>[key, group, consumer, minIdleTime, start];
    if (count != null) args.addAll(['COUNT', count]);
    if (justid == true) args.add('JUSTID');
    return this.call('XAUTOCLAIM', args);
  }

  Future<Object?> xinfo(String subcommand, [String? key, String? group]) async {
    final args = <Object?>[subcommand];
    if (key != null) args.add(key);
    if (group != null) args.add(group);
    return this.call('XINFO', args);
  }

  // ===== Server =====

  Future<String> info([String? section]) async {
    final result = await this.call('INFO', [if (section != null) section]);
    return result.toString();
  }

  Future<int> dbsize() async {
    final result = await this.call('DBSIZE');
    return result as int;
  }

  Future<String> flushdb({bool? async_}) async {
    final args = <Object?>[];
    if (async_ == true) args.add('ASYNC');
    final result = await this.call('FLUSHDB', args);
    return result.toString();
  }

  Future<String> flushall({bool? async_}) async {
    final args = <Object?>[];
    if (async_ == true) args.add('ASYNC');
    final result = await this.call('FLUSHALL', args);
    return result.toString();
  }

  Future<String> save() async {
    final result = await this.call('SAVE');
    return result.toString();
  }

  Future<String> bgsave() async {
    final result = await this.call('BGSAVE');
    return result.toString();
  }

  Future<String> bgrewriteaof() async {
    final result = await this.call('BGREWRITEAOF');
    return result.toString();
  }

  Future<int> lastsave() async {
    final result = await this.call('LASTSAVE');
    return result as int;
  }

  Future<List<String>> time() async {
    final result = await this.call('TIME');
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> configGet(String parameter) async {
    final result = await this.call('CONFIG', ['GET', parameter]);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<String> configSet(String parameter, Object value) async {
    final result = await this.call('CONFIG', ['SET', parameter, value]);
    return result.toString();
  }

  Future<String> configResetstat() async {
    final result = await this.call('CONFIG', ['RESETSTAT']);
    return result.toString();
  }

  Future<String> configRewrite() async {
    final result = await this.call('CONFIG', ['REWRITE']);
    return result.toString();
  }

  Future<Object?> clientList() async {
    return this.call('CLIENT', ['LIST']);
  }

  Future<String> clientSetname(String name) async {
    final result = await this.call('CLIENT', ['SETNAME', name]);
    return result.toString();
  }

  Future<String?> clientGetname() async {
    final result = await this.call('CLIENT', ['GETNAME']);
    return result?.toString();
  }

  Future<int> clientId() async {
    final result = await this.call('CLIENT', ['ID']);
    return result as int;
  }

  Future<String> clientKill(String addr) async {
    final result = await this.call('CLIENT', ['KILL', addr]);
    return result.toString();
  }

  Future<String> clientPause(int timeout) async {
    final result = await this.call('CLIENT', ['PAUSE', timeout]);
    return result.toString();
  }

  Future<String> clientUnpause() async {
    final result = await this.call('CLIENT', ['UNPAUSE']);
    return result.toString();
  }

  Future<String> slaveof(String host, int port) async {
    final result = await this.call('SLAVEOF', [host, port]);
    return result.toString();
  }

  Future<String> replicaof(String host, int port) async {
    final result = await this.call('REPLICAOF', [host, port]);
    return result.toString();
  }

  Future<List<Object?>> slowlogGet([int? count]) async {
    final args = <Object?>['GET'];
    if (count != null) args.add(count);
    final result = await this.call('SLOWLOG', args);
    return result as List<Object?>;
  }

  Future<int> slowlogLen() async {
    final result = await this.call('SLOWLOG', ['LEN']);
    return result as int;
  }

  Future<String> slowlogReset() async {
    final result = await this.call('SLOWLOG', ['RESET']);
    return result.toString();
  }

  // ===== Scripting =====

  Future<Object?> eval_(String script, int numKeys, [List<Object> args = const []]) async {
    return this.call('EVAL', [script, numKeys, ...args]);
  }

  Future<Object?> evalsha(String sha1, int numKeys, [List<Object> args = const []]) async {
    return this.call('EVALSHA', [sha1, numKeys, ...args]);
  }

  Future<List<int>> scriptExists(List<String> sha1s) async {
    final result = await this.call('SCRIPT', ['EXISTS', ...sha1s]);
    return (result as List).cast<int>();
  }

  Future<String> scriptFlush() async {
    final result = await this.call('SCRIPT', ['FLUSH']);
    return result.toString();
  }

  Future<String> scriptKill() async {
    final result = await this.call('SCRIPT', ['KILL']);
    return result.toString();
  }

  Future<String> scriptLoad(String script) async {
    final result = await this.call('SCRIPT', ['LOAD', script]);
    return result.toString();
  }

  // ===== Transaction =====

  Future<String> watch(List<String> keys) async {
    final result = await this.call('WATCH', keys);
    return result.toString();
  }

  Future<String> unwatch() async {
    final result = await this.call('UNWATCH');
    return result.toString();
  }

  Future<String> discard() async {
    final result = await this.call('DISCARD');
    return result.toString();
  }

  // ===== Pub/Sub (additional commands) =====

  Future<List<Object?>> pubsubChannels([String? pattern]) async {
    final args = <Object?>['CHANNELS'];
    if (pattern != null) args.add(pattern);
    final result = await this.call('PUBSUB', args);
    return result as List<Object?>;
  }

  Future<int> pubsubNumsub(String channel) async {
    final result = await this.call('PUBSUB', ['NUMSUB', channel]);
    final list = result as List;
    return list.length >= 2 ? list[1] as int : 0;
  }

  Future<int> pubsubNumpat() async {
    final result = await this.call('PUBSUB', ['NUMPAT']);
    return result as int;
  }

  // ===== ACL =====

  Future<List<String>> aclList() async {
    final result = await this.call('ACL', ['LIST']);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<String> aclSetuser(String username, List<String> rules) async {
    final result = await this.call('ACL', ['SETUSER', username, ...rules]);
    return result.toString();
  }

  Future<int> aclDeluser(List<String> usernames) async {
    final result = await this.call('ACL', ['DELUSER', ...usernames]);
    return result as int;
  }

  Future<List<Object?>> aclGetuser(String username) async {
    final result = await this.call('ACL', ['GETUSER', username]);
    return result as List<Object?>;
  }

  Future<List<String>> aclCat([String? category]) async {
    final args = <Object?>['CAT'];
    if (category != null) args.add(category);
    final result = await this.call('ACL', args);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<String> aclGenpass([int? bits]) async {
    final args = <Object?>['GENPASS'];
    if (bits != null) args.add(bits);
    final result = await this.call('ACL', args);
    return result.toString();
  }

  Future<List<String>> aclUsers() async {
    final result = await this.call('ACL', ['USERS']);
    return (result as List).map((e) => e.toString()).toList();
  }

  Future<String> aclWhoami() async {
    final result = await this.call('ACL', ['WHOAMI']);
    return result.toString();
  }

  Future<String> aclLoad() async {
    final result = await this.call('ACL', ['LOAD']);
    return result.toString();
  }

  Future<String> aclSave() async {
    final result = await this.call('ACL', ['SAVE']);
    return result.toString();
  }

  // ===== Cluster =====

  Future<Object?> clusterInfo() async {
    return this.call('CLUSTER', ['INFO']);
  }

  Future<Object?> clusterNodes() async {
    return this.call('CLUSTER', ['NODES']);
  }

  Future<Object?> clusterSlots() async {
    return this.call('CLUSTER', ['SLOTS']);
  }

  Future<String> clusterMeet(String host, int port) async {
    final result = await this.call('CLUSTER', ['MEET', host, port]);
    return result.toString();
  }

  Future<String> clusterReset([String? mode]) async {
    final args = <Object?>['RESET'];
    if (mode != null) args.add(mode);
    final result = await this.call('CLUSTER', args);
    return result.toString();
  }

  Future<String> clusterFailover([String? option]) async {
    final args = <Object?>['FAILOVER'];
    if (option != null) args.add(option);
    final result = await this.call('CLUSTER', args);
    return result.toString();
  }

  Future<int> clusterKeyslot(String key) async {
    final result = await this.call('CLUSTER', ['KEYSLOT', key]);
    return result as int;
  }

  Future<int> clusterCountkeysinslot(int slot) async {
    final result = await this.call('CLUSTER', ['COUNTKEYSINSLOT', slot]);
    return result as int;
  }

  Future<List<String>> clusterGetkeysinslot(int slot, int count) async {
    final result = await this.call('CLUSTER', ['GETKEYSINSLOT', slot, count]);
    return (result as List).map((e) => e.toString()).toList();
  }

  // ===== Memory =====

  Future<int> memoryUsage(String key, {int? samples}) async {
    final args = <Object?>[key];
    if (samples != null) args.addAll(['SAMPLES', samples]);
    final result = await this.call('MEMORY', ['USAGE', ...args]);
    return result as int;
  }

  // ===== Copy =====

  Future<int> copy(String source, String destination, {int? db, bool? replace}) async {
    final args = <Object?>[source, destination];
    if (db != null) args.addAll(['DB', db]);
    if (replace == true) args.add('REPLACE');
    final result = await this.call('COPY', args);
    return result as int;
  }

  // ===== LCS (Longest Common Substring, Redis 7.0+) =====

  Future<Object?> lcs(String key1, String key2, {bool? len, bool? idx, int? minMatchLen, bool? withMatchLen}) async {
    final args = <Object?>[key1, key2];
    if (len == true) args.add('LEN');
    if (idx == true) args.add('IDX');
    if (minMatchLen != null) args.addAll(['MINMATCHLEN', minMatchLen]);
    if (withMatchLen == true) args.add('WITHMATCHLEN');
    return this.call('LCS', args);
  }
}
