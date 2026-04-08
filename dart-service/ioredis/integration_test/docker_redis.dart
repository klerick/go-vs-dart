import 'dart:io';

/// Manages a Redis Docker container for integration tests.
///
/// Usage in tests:
/// ```dart
/// late DockerRedis docker;
///
/// setUpAll(() async {
///   docker = DockerRedis();
///   await docker.start();
/// });
///
/// tearDownAll(() async {
///   await docker.stop();
/// });
/// ```
class DockerRedis {
  DockerRedis({
    this.port = 6390,
    this.image = 'redis:7-alpine',
  }) : containerName = 'ioredis-test-$port';

  final int port;
  final String image;
  final String containerName;

  /// Start the Redis container and wait until it's ready.
  Future<void> start() async {
    // Remove leftover container if exists
    await Process.run('docker', ['rm', '-f', this.containerName]);

    // Start container
    final result = await Process.run('docker', [
      'run',
      '-d',
      '--name',
      this.containerName,
      '-p',
      '${this.port}:6379',
      this.image,
    ]);

    if (result.exitCode != 0) {
      throw StateError(
        'Failed to start Redis container: ${result.stderr}',
      );
    }

    // Wait for Redis to be ready (up to 10 seconds)
    for (var i = 0; i < 50; i++) {
      try {
        final socket = await Socket.connect('localhost', this.port,
            timeout: const Duration(milliseconds: 200));
        socket.destroy();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }

    throw StateError('Redis container did not become ready in time');
  }

  /// Stop and remove the Redis container.
  Future<void> stop() async {
    await Process.run('docker', ['stop', this.containerName]);
    await Process.run('docker', ['rm', '-f', this.containerName]);
  }
}
