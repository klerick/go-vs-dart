import '../client/redis.dart';

/// All Redis commands as chainable methods on Pipeline.
///
/// Each method adds a command to the pipeline queue and returns
/// the pipeline for chaining: `pipeline.set('a', '1').get('a').exec()`
extension PipelineCommands on Pipeline {
  // ===== Connection =====
  Pipeline ping([String? message]) => this.addCommand('PING', [if (message != null) message]);
  Pipeline echo_(String message) => this.addCommand('ECHO', [message]);
  Pipeline select_(int db) => this.addCommand('SELECT', [db]);

  // ===== String =====
  Pipeline get_(String key) => this.addCommand('GET', [key]);
  Pipeline set_(String key, Object value, {int? ex, int? px, bool? nx, bool? xx}) {
    final args = <Object?>[key, value];
    if (ex != null) args.addAll(['EX', ex]);
    if (px != null) args.addAll(['PX', px]);
    if (nx == true) args.add('NX');
    if (xx == true) args.add('XX');
    return this.addCommand('SET', args);
  }
  Pipeline getdel(String key) => this.addCommand('GETDEL', [key]);
  Pipeline mget(List<String> keys) => this.addCommand('MGET', keys);
  Pipeline mset(Map<String, Object> pairs) => this.addCommand('MSET', [pairs]);
  Pipeline msetnx(Map<String, Object> pairs) => this.addCommand('MSETNX', [pairs]);
  Pipeline append(String key, String value) => this.addCommand('APPEND', [key, value]);
  Pipeline incr(String key) => this.addCommand('INCR', [key]);
  Pipeline incrby(String key, int increment) => this.addCommand('INCRBY', [key, increment]);
  Pipeline incrbyfloat(String key, double increment) => this.addCommand('INCRBYFLOAT', [key, increment]);
  Pipeline decr(String key) => this.addCommand('DECR', [key]);
  Pipeline decrby(String key, int decrement) => this.addCommand('DECRBY', [key, decrement]);
  Pipeline strlen(String key) => this.addCommand('STRLEN', [key]);
  Pipeline setex(String key, int seconds, Object value) => this.addCommand('SETEX', [key, seconds, value]);
  Pipeline psetex(String key, int milliseconds, Object value) => this.addCommand('PSETEX', [key, milliseconds, value]);
  Pipeline setnx(String key, Object value) => this.addCommand('SETNX', [key, value]);
  Pipeline setrange(String key, int offset, String value) => this.addCommand('SETRANGE', [key, offset, value]);
  Pipeline getrange(String key, int start, int end) => this.addCommand('GETRANGE', [key, start, end]);

  // ===== Key =====
  Pipeline del(List<String> keys) => this.addCommand('DEL', keys);
  Pipeline unlink(List<String> keys) => this.addCommand('UNLINK', keys);
  Pipeline exists(List<String> keys) => this.addCommand('EXISTS', keys);
  Pipeline expire(String key, int seconds) => this.addCommand('EXPIRE', [key, seconds]);
  Pipeline expireat(String key, int timestamp) => this.addCommand('EXPIREAT', [key, timestamp]);
  Pipeline pexpire(String key, int ms) => this.addCommand('PEXPIRE', [key, ms]);
  Pipeline pexpireat(String key, int timestamp) => this.addCommand('PEXPIREAT', [key, timestamp]);
  Pipeline persist(String key) => this.addCommand('PERSIST', [key]);
  Pipeline ttl(String key) => this.addCommand('TTL', [key]);
  Pipeline pttl(String key) => this.addCommand('PTTL', [key]);
  Pipeline type(String key) => this.addCommand('TYPE', [key]);
  Pipeline rename(String key, String newKey) => this.addCommand('RENAME', [key, newKey]);
  Pipeline renamenx(String key, String newKey) => this.addCommand('RENAMENX', [key, newKey]);
  Pipeline keys_(String pattern) => this.addCommand('KEYS', [pattern]);

  // ===== Hash =====
  Pipeline hset(String key, Map<String, Object> fieldValues) => this.addCommand('HSET', [key, fieldValues]);
  Pipeline hget(String key, String field) => this.addCommand('HGET', [key, field]);
  Pipeline hsetnx(String key, String field, Object value) => this.addCommand('HSETNX', [key, field, value]);
  Pipeline hmset(String key, Map<String, Object> fieldValues) => this.addCommand('HMSET', [key, fieldValues]);
  Pipeline hmget(String key, List<String> fields) => this.addCommand('HMGET', [key, ...fields]);
  Pipeline hgetall(String key) => this.addCommand('HGETALL', [key]);
  Pipeline hdel(String key, List<String> fields) => this.addCommand('HDEL', [key, ...fields]);
  Pipeline hexists(String key, String field) => this.addCommand('HEXISTS', [key, field]);
  Pipeline hincrby(String key, String field, int increment) => this.addCommand('HINCRBY', [key, field, increment]);
  Pipeline hincrbyfloat(String key, String field, double increment) => this.addCommand('HINCRBYFLOAT', [key, field, increment]);
  Pipeline hkeys(String key) => this.addCommand('HKEYS', [key]);
  Pipeline hvals(String key) => this.addCommand('HVALS', [key]);
  Pipeline hlen(String key) => this.addCommand('HLEN', [key]);

  // ===== List =====
  Pipeline lpush(String key, List<Object> values) => this.addCommand('LPUSH', [key, ...values]);
  Pipeline rpush(String key, List<Object> values) => this.addCommand('RPUSH', [key, ...values]);
  Pipeline lpushx(String key, List<Object> values) => this.addCommand('LPUSHX', [key, ...values]);
  Pipeline rpushx(String key, List<Object> values) => this.addCommand('RPUSHX', [key, ...values]);
  Pipeline lpop(String key) => this.addCommand('LPOP', [key]);
  Pipeline rpop(String key) => this.addCommand('RPOP', [key]);
  Pipeline lrange(String key, int start, int stop) => this.addCommand('LRANGE', [key, start, stop]);
  Pipeline llen(String key) => this.addCommand('LLEN', [key]);
  Pipeline lindex(String key, int index) => this.addCommand('LINDEX', [key, index]);
  Pipeline lset(String key, int index, Object value) => this.addCommand('LSET', [key, index, value]);
  Pipeline linsert(String key, String pos, Object pivot, Object value) => this.addCommand('LINSERT', [key, pos, pivot, value]);
  Pipeline lrem(String key, int count, Object value) => this.addCommand('LREM', [key, count, value]);
  Pipeline ltrim(String key, int start, int stop) => this.addCommand('LTRIM', [key, start, stop]);
  Pipeline rpoplpush(String source, String dest) => this.addCommand('RPOPLPUSH', [source, dest]);
  Pipeline lmove(String source, String dest, String from, String to) => this.addCommand('LMOVE', [source, dest, from, to]);

  // ===== Set =====
  Pipeline sadd(String key, List<Object> members) => this.addCommand('SADD', [key, ...members]);
  Pipeline srem(String key, List<Object> members) => this.addCommand('SREM', [key, ...members]);
  Pipeline smembers(String key) => this.addCommand('SMEMBERS', [key]);
  Pipeline sismember(String key, Object member) => this.addCommand('SISMEMBER', [key, member]);
  Pipeline scard(String key) => this.addCommand('SCARD', [key]);
  Pipeline smove(String source, String dest, Object member) => this.addCommand('SMOVE', [source, dest, member]);
  Pipeline spop(String key) => this.addCommand('SPOP', [key]);
  Pipeline sdiff(List<String> keys) => this.addCommand('SDIFF', keys);
  Pipeline sdiffstore(String dest, List<String> keys) => this.addCommand('SDIFFSTORE', [dest, ...keys]);
  Pipeline sinter(List<String> keys) => this.addCommand('SINTER', keys);
  Pipeline sinterstore(String dest, List<String> keys) => this.addCommand('SINTERSTORE', [dest, ...keys]);
  Pipeline sunion(List<String> keys) => this.addCommand('SUNION', keys);
  Pipeline sunionstore(String dest, List<String> keys) => this.addCommand('SUNIONSTORE', [dest, ...keys]);

  // ===== Sorted Set =====
  Pipeline zadd(String key, Map<String, double> members) {
    final args = <Object?>[key];
    for (final entry in members.entries) { args.addAll([entry.value, entry.key]); }
    return this.addCommand('ZADD', args);
  }
  Pipeline zcard(String key) => this.addCommand('ZCARD', [key]);
  Pipeline zcount(String key, Object min, Object max) => this.addCommand('ZCOUNT', [key, min, max]);
  Pipeline zincrby(String key, double incr, String member) => this.addCommand('ZINCRBY', [key, incr, member]);
  Pipeline zscore(String key, String member) => this.addCommand('ZSCORE', [key, member]);
  Pipeline zrank(String key, String member) => this.addCommand('ZRANK', [key, member]);
  Pipeline zrevrank(String key, String member) => this.addCommand('ZREVRANK', [key, member]);
  Pipeline zrem(String key, List<String> members) => this.addCommand('ZREM', [key, ...members]);
  Pipeline zrange(String key, Object start, Object stop) => this.addCommand('ZRANGE', [key, start, stop]);
  Pipeline zrevrange(String key, int start, int stop) => this.addCommand('ZREVRANGE', [key, start, stop]);
  Pipeline zrangebyscore(String key, Object min, Object max) => this.addCommand('ZRANGEBYSCORE', [key, min, max]);
  Pipeline zremrangebyscore(String key, Object min, Object max) => this.addCommand('ZREMRANGEBYSCORE', [key, min, max]);
  Pipeline zremrangebyrank(String key, int start, int stop) => this.addCommand('ZREMRANGEBYRANK', [key, start, stop]);

  // ===== HyperLogLog =====
  Pipeline pfadd(String key, List<Object> elements) => this.addCommand('PFADD', [key, ...elements]);
  Pipeline pfcount(List<String> keys) => this.addCommand('PFCOUNT', keys);
  Pipeline pfmerge(String dest, List<String> sources) => this.addCommand('PFMERGE', [dest, ...sources]);

  // ===== Bitmap =====
  Pipeline setbit(String key, int offset, int value) => this.addCommand('SETBIT', [key, offset, value]);
  Pipeline getbit(String key, int offset) => this.addCommand('GETBIT', [key, offset]);
  Pipeline bitcount(String key, [int? start, int? end]) {
    final args = <Object?>[key]; if (start != null) args.add(start); if (end != null) args.add(end);
    return this.addCommand('BITCOUNT', args);
  }

  // ===== Server =====
  Pipeline info([String? section]) => this.addCommand('INFO', [if (section != null) section]);
  Pipeline dbsize() => this.addCommand('DBSIZE');
  Pipeline flushdb() => this.addCommand('FLUSHDB');
  Pipeline flushall() => this.addCommand('FLUSHALL');

  // ===== Scripting =====
  Pipeline eval_(String script, int numKeys, [List<Object> args = const []]) => this.addCommand('EVAL', [script, numKeys, ...args]);
  Pipeline evalsha(String sha1, int numKeys, [List<Object> args = const []]) => this.addCommand('EVALSHA', [sha1, numKeys, ...args]);

  // ===== Stream =====
  Pipeline xadd(String key, Map<String, Object> fields, {String? id}) {
    final args = <Object?>[key, id ?? '*'];
    for (final e in fields.entries) { args.addAll([e.key, e.value]); }
    return this.addCommand('XADD', args);
  }
  Pipeline xlen(String key) => this.addCommand('XLEN', [key]);
  Pipeline xrange(String key, String start, String end) => this.addCommand('XRANGE', [key, start, end]);
  Pipeline xrevrange(String key, String end, String start) => this.addCommand('XREVRANGE', [key, end, start]);
  Pipeline xdel(String key, List<String> ids) => this.addCommand('XDEL', [key, ...ids]);
  Pipeline xack(String key, String group, List<String> ids) => this.addCommand('XACK', [key, group, ...ids]);
}
