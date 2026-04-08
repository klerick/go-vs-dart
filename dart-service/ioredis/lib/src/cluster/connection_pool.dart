import 'dart:math';

import '../client/redis.dart';
import '../client/redis_options.dart';

/// Role filter for node queries.
enum NodeRole { all, master, slave }

/// Manages connections to all cluster nodes.
class ConnectionPool {
  ConnectionPool(this._baseOptions);

  final RedisOptions _baseOptions;

  final Map<String, Redis> _all = {};
  final Map<String, Redis> _masters = {};
  final Map<String, Redis> _slaves = {};

  final _random = Random();

  /// Get all nodes, optionally filtered by role.
  List<Redis> getNodes([NodeRole role = NodeRole.all]) {
    return switch (role) {
      NodeRole.all => _all.values.toList(),
      NodeRole.master => _masters.values.toList(),
      NodeRole.slave => _slaves.values.toList(),
    };
  }

  /// Get a specific node by key ("host:port").
  Redis? getByKey(String key) {
    return _all[key];
  }

  /// Get a random node, optionally filtered by role.
  Redis? getSample([NodeRole role = NodeRole.all]) {
    final nodes = this.getNodes(role);
    if (nodes.isEmpty) return null;
    return nodes[_random.nextInt(nodes.length)];
  }

  /// Get or create a connection to a node.
  Redis findOrCreate(String host, int port, {bool readOnly = false}) {
    final key = '$host:$port';

    final existing = _all[key];
    if (existing != null) {
      // Update role if changed
      if (readOnly && _masters.containsKey(key)) {
        _masters.remove(key);
        _slaves[key] = existing;
      } else if (!readOnly && _slaves.containsKey(key)) {
        _slaves.remove(key);
        _masters[key] = existing;
      }
      return existing;
    }

    final client = Redis(
      _baseOptions.copyWith(
        host: host,
        port: port,
        readOnly: readOnly,
        lazyConnect: true,
        enableOfflineQueue: true,
        retryStrategy: (attempts) => attempts > 3 ? null : const Duration(milliseconds: 100),
      ),
    );

    _all[key] = client;
    if (readOnly) {
      _slaves[key] = client;
    } else {
      _masters[key] = client;
    }

    return client;
  }

  /// Replace all nodes with a new set.
  void reset(List<({String host, int port, bool readOnly})> nodes) {
    final newKeys = <String>{};

    for (final node in nodes) {
      final key = '${node.host}:${node.port}';
      newKeys.add(key);
      this.findOrCreate(node.host, node.port, readOnly: node.readOnly);
    }

    // Remove nodes not in new set
    final toRemove = _all.keys.where((k) => !newKeys.contains(k)).toList();
    for (final key in toRemove) {
      final client = _all.remove(key);
      _masters.remove(key);
      _slaves.remove(key);
      client?.disconnect();
    }
  }

  /// Disconnect all nodes.
  Future<void> disconnectAll() async {
    for (final client in _all.values) {
      await client.disconnect();
    }
    _all.clear();
    _masters.clear();
    _slaves.clear();
  }
}
