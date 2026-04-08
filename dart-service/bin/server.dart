import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:ioredis/ioredis.dart' as ioredis;

late Pool pgPool;
late ioredis.Redis redisClient;

void main() async {
  final port = int.parse(Platform.environment['HTTP_PORT'] ?? '8080');
  final postgresUrl =
      Platform.environment['POSTGRES_URL'] ?? 'postgres://bench:bench@localhost:5432/bench';
  final redisUrl = Platform.environment['REDIS_URL'] ?? 'redis://localhost:6379';

  // Parse Postgres URL
  final pgUri = Uri.parse(postgresUrl);
  final pgEndpoint = Endpoint(
    host: pgUri.host,
    port: pgUri.port,
    database: pgUri.pathSegments.isNotEmpty ? pgUri.pathSegments.first : 'bench',
    username:
        pgUri.userInfo.contains(':') ? pgUri.userInfo.split(':').first : pgUri.userInfo,
    password: pgUri.userInfo.contains(':') ? pgUri.userInfo.split(':').last : null,
  );

  pgPool = Pool.withEndpoints(
    [pgEndpoint],
    settings: PoolSettings(
      maxConnectionCount: 10,
      sslMode: SslMode.disable,
    ),
  );

  // Parse Redis URL
  final redisUri = Uri.parse(redisUrl);
  final redisHost = redisUri.host.isEmpty ? 'localhost' : redisUri.host;
  final redisPort = redisUri.port == 0 ? 6379 : redisUri.port;

  redisClient = ioredis.Redis(ioredis.RedisOptions(
    host: redisHost,
    port: redisPort,
  ));

  // Start HTTP server
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('Server listening on port $port');

  // Graceful shutdown
  late StreamSubscription<HttpRequest> sub;
  ProcessSignal.sigterm.watch().listen((_) async {
    print('SIGTERM received, shutting down...');
    await sub.cancel();
    await server.close();
    await pgPool.close();
    exit(0);
  });

  sub = server.listen((req) async {
    try {
      await _handleRequest(req);
    } catch (e, st) {
      print('Error handling request: $e\n$st');
      _sendJson(req.response, 500, {'error': 'internal server error'});
    }
  });
}

Future<void> _handleRequest(HttpRequest req) async {
  final path = req.uri.path;
  final method = req.method;

  if (method == 'GET' && path == '/health') {
    _sendJson(req.response, 200, {'status': 'ok'});
    return;
  }

  if (method == 'POST' && path == '/orders') {
    await _handleCreateOrder(req);
    return;
  }

  // GET /orders/123
  if (method == 'GET' && path.startsWith('/orders/')) {
    final idStr = path.substring('/orders/'.length);
    final id = int.tryParse(idStr);
    if (id != null) {
      await _handleGetOrder(req, id);
      return;
    }
  }

  // GET /orders?user_id=X
  if (method == 'GET' && path == '/orders') {
    await _handleListOrders(req);
    return;
  }

  _sendJson(req.response, 404, {'error': 'not found'});
}

Future<void> _handleCreateOrder(HttpRequest req) async {
  // Parse body
  final body = await utf8.decoder.bind(req).join();
  final Map<String, dynamic> json;
  try {
    json = jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    _sendJson(req.response, 400, {'error': 'invalid JSON'});
    return;
  }

  final userId = json['user_id'];
  final productId = json['product_id'];
  final quantity = json['quantity'];

  if (userId is! int || productId is! int || quantity is! int) {
    _sendJson(
        req.response, 400, {'error': 'user_id, product_id, and quantity are required integers'});
    return;
  }
  if (quantity <= 0) {
    _sendJson(req.response, 400, {'error': 'quantity must be greater than 0'});
    return;
  }

  // Read user from Redis
  final userRaw = await redisClient.get('user:$userId');
  if (userRaw == null) {
    _sendJson(req.response, 404, {'error': 'user not found'});
    return;
  }
  final user = jsonDecode(userRaw as String) as Map<String, dynamic>;

  // Read product from PostgreSQL
  final productResult = await pgPool.execute(
    Sql.named('SELECT id, name, price FROM products WHERE id = @id'),
    parameters: {'id': productId},
  );
  if (productResult.isEmpty) {
    _sendJson(req.response, 404, {'error': 'product not found'});
    return;
  }
  final productRow = productResult.first;
  final productName = productRow[1] as String;
  final rawPrice = productRow[2];
  final productPrice = rawPrice is num ? rawPrice.toDouble() : double.parse(rawPrice.toString());

  // Calculate total
  final total = productPrice * quantity;

  // Insert order
  final insertResult = await pgPool.execute(
    Sql.named(
      'INSERT INTO orders (user_id, product_id, quantity, total, created_at) '
      'VALUES (@user_id, @product_id, @quantity, @total, NOW()) '
      'RETURNING id, created_at',
    ),
    parameters: {
      'user_id': userId,
      'product_id': productId,
      'quantity': quantity,
      'total': total,
    },
  );
  final orderRow = insertResult.first;
  final orderId = orderRow[0] as int;
  final createdAt = orderRow[1].toString();

  // Invalidate cache
  await redisClient.del(['order_cache:$userId']);

  // Return response
  _sendJson(req.response, 201, {
    'order_id': orderId,
    'user_name': user['name'],
    'product_name': productName,
    'quantity': quantity,
    'total': total,
    'created_at': createdAt,
  });
}

Future<void> _handleGetOrder(HttpRequest req, int id) async {
  final result = await pgPool.execute(
    Sql.named('SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = @id'),
    parameters: {'id': id},
  );
  if (result.isEmpty) {
    _sendJson(req.response, 404, {'error': 'order not found'});
    return;
  }
  final row = result.first;
  final userId = row[1] as int;
  final productId = row[2] as int;
  final quantity = row[3] as int;
  final rawTotal = row[4];
  final total = rawTotal is num ? rawTotal.toDouble() : double.parse(rawTotal.toString());
  final createdAt = row[5].toString();

  // Enrich with user name from Redis
  String userName = '';
  final userRaw = await redisClient.get('user:$userId');
  if (userRaw != null) {
    final user = jsonDecode(userRaw as String) as Map<String, dynamic>;
    userName = user['name'] as String;
  }

  // Enrich with product name
  String productName = '';
  final prodResult = await pgPool.execute(
    Sql.named('SELECT name FROM products WHERE id = @id'),
    parameters: {'id': productId},
  );
  if (prodResult.isNotEmpty) {
    productName = prodResult.first[0] as String;
  }

  _sendJson(req.response, 200, {
    'order_id': id,
    'user_name': userName,
    'product_name': productName,
    'quantity': quantity,
    'total': total,
    'created_at': createdAt,
  });
}

Future<void> _handleListOrders(HttpRequest req) async {
  final params = req.uri.queryParameters;
  final userIdStr = params['user_id'];
  if (userIdStr == null) {
    _sendJson(req.response, 400, {'error': 'user_id is required'});
    return;
  }
  final userId = int.tryParse(userIdStr);
  if (userId == null) {
    _sendJson(req.response, 400, {'error': 'invalid user_id'});
    return;
  }

  var limit = 20;
  if (params['limit'] != null) {
    final parsed = int.tryParse(params['limit']!);
    if (parsed != null && parsed > 0 && parsed <= 100) limit = parsed;
  }

  var offset = 0;
  if (params['offset'] != null) {
    final parsed = int.tryParse(params['offset']!);
    if (parsed != null && parsed >= 0) offset = parsed;
  }

  // Get user name from Redis
  String userName = '';
  final userRaw = await redisClient.get('user:$userId');
  if (userRaw != null) {
    final user = jsonDecode(userRaw as String) as Map<String, dynamic>;
    userName = user['name'] as String;
  }

  final result = await pgPool.execute(
    Sql.named(
      'SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name '
      'FROM orders o JOIN products p ON p.id = o.product_id '
      'WHERE o.user_id = @user_id ORDER BY o.created_at DESC LIMIT @limit OFFSET @offset',
    ),
    parameters: {'user_id': userId, 'limit': limit, 'offset': offset},
  );

  final orders = <Map<String, dynamic>>[];
  for (final row in result) {
    final rawTotal = row[3];
    final total = rawTotal is num ? rawTotal.toDouble() : double.parse(rawTotal.toString());
    orders.add({
      'order_id': row[0] as int,
      'user_name': userName,
      'product_name': row[5] as String,
      'quantity': row[2] as int,
      'total': total,
      'created_at': row[4].toString(),
    });
  }

  _sendJson(req.response, 200, {'orders': orders, 'count': orders.length});
}

void _sendJson(HttpResponse response, int statusCode, Object body) {
  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..write(jsonEncode(body))
    ..close();
}