import 'dart:io';

/// Manages a Redis Cluster via Docker for integration tests.
///
/// Starts 6 Redis nodes inside a single container (ports 7010-7015),
/// then creates the cluster. All nodes share the same network namespace
/// so they can see each other via 127.0.0.1.
class DockerRedisCluster {
  DockerRedisCluster({this.startPort = 7010});

  final int startPort;
  final String containerName = 'zest-redis-cluster-test';

  List<int> get ports => List.generate(6, (i) => this.startPort + i);

  List<({String host, int port})> get nodes {
    return this.ports.map((p) => (host: '127.0.0.1', port: p)).toList();
  }

  Future<void> start() async {
    await Process.run('docker', ['rm', '-f', this.containerName]);

    // Build port mappings
    final portArgs = <String>[];
    for (final port in this.ports) {
      portArgs.addAll(['-p', '$port:$port']);
    }

    // Single container: start 6 redis-server processes, then create cluster
    final startScript = StringBuffer();
    for (final port in this.ports) {
      startScript.writeln(
        'redis-server --port $port --cluster-enabled yes '
        '--cluster-config-file /data/nodes-$port.conf '
        '--cluster-node-timeout 5000 --appendonly no '
        '--bind 0.0.0.0 --protected-mode no --daemonize yes',
      );
    }
    // Wait for all to start
    startScript.writeln('sleep 1');
    // Create cluster
    final nodeAddrs = this.ports.map((p) => '127.0.0.1:$p').join(' ');
    startScript.writeln(
      'echo yes | redis-cli --cluster create $nodeAddrs --cluster-replicas 1',
    );
    // Keep container alive
    startScript.writeln('tail -f /dev/null');

    final result = await Process.run('docker', [
      'run', '-d',
      '--name', this.containerName,
      ...portArgs,
      'redis:7-alpine',
      'sh', '-c', startScript.toString(),
    ]);

    if (result.exitCode != 0) {
      throw StateError(
        'Failed to start Redis Cluster container: ${result.stderr}',
      );
    }

    // Wait for all ports to be reachable
    for (final port in this.ports) {
      await _waitForPort(port);
    }

    // Wait for cluster to be fully formed
    await _waitForClusterReady();
  }

  Future<void> stop() async {
    await Process.run('docker', ['rm', '-f', this.containerName]);
  }

  Future<void> _waitForPort(int port, {int attempts = 30}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final socket = await Socket.connect('127.0.0.1', port,
            timeout: const Duration(milliseconds: 500));
        socket.destroy();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    throw StateError('Port $port did not become available');
  }

  Future<void> _waitForClusterReady({int attempts = 30}) async {
    for (var i = 0; i < attempts; i++) {
      try {
        final result = await Process.run('docker', [
          'exec', this.containerName,
          'redis-cli', '-p', '${this.startPort}',
          'cluster', 'info',
        ]);
        final output = result.stdout.toString();
        if (output.contains('cluster_state:ok') &&
            output.contains('cluster_slots_assigned:16384')) {
          return;
        }
      } catch (_) {
        // ignore
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    throw StateError('Redis Cluster did not become ready');
  }
}
