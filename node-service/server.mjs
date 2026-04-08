import http from 'node:http';
import { createClient } from 'redis';
import pg from 'pg';

const PORT = parseInt(process.env.HTTP_PORT || '8080');
const POSTGRES_URL = process.env.POSTGRES_URL || 'postgres://bench:bench@localhost:5432/bench';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

// PostgreSQL pool
const pool = new pg.Pool({
  connectionString: POSTGRES_URL,
  max: 10,
  ssl: false,
});

// Redis client
const redis = createClient({ url: REDIS_URL });
await redis.connect();

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'GET' && req.url === '/health') {
      sendJson(res, 200, { status: 'ok' });
      return;
    }

    if (req.method === 'POST' && req.url === '/orders') {
      await handleCreateOrder(req, res);
      return;
    }

    // GET /orders/123
    const getMatch = req.url.match(/^\/orders\/(\d+)$/);
    if (req.method === 'GET' && getMatch) {
      await handleGetOrder(req, res, parseInt(getMatch[1]));
      return;
    }

    // GET /orders?user_id=X
    if (req.method === 'GET' && req.url.startsWith('/orders?')) {
      await handleListOrders(req, res);
      return;
    }

    sendJson(res, 404, { error: 'not found' });
  } catch (err) {
    console.error('Error handling request:', err);
    sendJson(res, 500, { error: 'internal server error' });
  }
});

async function handleCreateOrder(req, res) {
  const body = await readBody(req);
  let json;
  try {
    json = JSON.parse(body);
  } catch {
    sendJson(res, 400, { error: 'invalid JSON' });
    return;
  }

  const { user_id, product_id, quantity } = json;
  if (!Number.isInteger(user_id) || !Number.isInteger(product_id) || !Number.isInteger(quantity)) {
    sendJson(res, 400, { error: 'user_id, product_id, and quantity are required integers' });
    return;
  }
  if (quantity <= 0) {
    sendJson(res, 400, { error: 'quantity must be greater than 0' });
    return;
  }

  // Read user from Redis
  const userRaw = await redis.get(`user:${user_id}`);
  if (!userRaw) {
    sendJson(res, 404, { error: 'user not found' });
    return;
  }
  const user = JSON.parse(userRaw);

  // Read product from PostgreSQL
  const productResult = await pool.query('SELECT id, name, price FROM products WHERE id = $1', [product_id]);
  if (productResult.rows.length === 0) {
    sendJson(res, 404, { error: 'product not found' });
    return;
  }
  const product = productResult.rows[0];
  const price = parseFloat(product.price);

  // Calculate total
  const total = price * quantity;

  // Insert order
  const insertResult = await pool.query(
    'INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at',
    [user_id, product_id, quantity, total]
  );
  const order = insertResult.rows[0];

  // Invalidate cache
  await redis.del(`order_cache:${user_id}`);

  sendJson(res, 201, {
    order_id: order.id,
    user_name: user.name,
    product_name: product.name,
    quantity,
    total,
    created_at: order.created_at.toISOString(),
  });
}

async function handleGetOrder(req, res, id) {
  const result = await pool.query(
    'SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = $1', [id]
  );
  if (result.rows.length === 0) {
    sendJson(res, 404, { error: 'order not found' });
    return;
  }
  const row = result.rows[0];

  // Enrich with user name from Redis
  let userName = '';
  const userRaw = await redis.get(`user:${row.user_id}`);
  if (userRaw) {
    userName = JSON.parse(userRaw).name;
  }

  // Enrich with product name
  let productName = '';
  const prodResult = await pool.query('SELECT name FROM products WHERE id = $1', [row.product_id]);
  if (prodResult.rows.length > 0) {
    productName = prodResult.rows[0].name;
  }

  sendJson(res, 200, {
    order_id: row.id,
    user_name: userName,
    product_name: productName,
    quantity: row.quantity,
    total: parseFloat(row.total),
    created_at: row.created_at.toISOString(),
  });
}

async function handleListOrders(req, res) {
  const url = new URL(req.url, `http://localhost`);
  const userIdStr = url.searchParams.get('user_id');
  if (!userIdStr) {
    sendJson(res, 400, { error: 'user_id is required' });
    return;
  }
  const userId = parseInt(userIdStr);
  if (isNaN(userId)) {
    sendJson(res, 400, { error: 'invalid user_id' });
    return;
  }

  let limit = 20;
  const limitStr = url.searchParams.get('limit');
  if (limitStr) {
    const parsed = parseInt(limitStr);
    if (!isNaN(parsed) && parsed > 0 && parsed <= 100) limit = parsed;
  }

  let offset = 0;
  const offsetStr = url.searchParams.get('offset');
  if (offsetStr) {
    const parsed = parseInt(offsetStr);
    if (!isNaN(parsed) && parsed >= 0) offset = parsed;
  }

  // Get user name from Redis
  let userName = '';
  const userRaw = await redis.get(`user:${userId}`);
  if (userRaw) {
    userName = JSON.parse(userRaw).name;
  }

  const result = await pool.query(
    'SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3',
    [userId, limit, offset]
  );

  const orders = result.rows.map(row => ({
    order_id: row.id,
    user_name: userName,
    product_name: row.name,
    quantity: row.quantity,
    total: parseFloat(row.total),
    created_at: row.created_at.toISOString(),
  }));

  sendJson(res, 200, { orders, count: orders.length });
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = '';
    req.on('data', chunk => data += chunk);
    req.on('end', () => resolve(data));
    req.on('error', reject);
  });
}

function sendJson(res, statusCode, body) {
  const payload = JSON.stringify(body);
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  });
  res.end(payload);
}

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down...');
  server.close(async () => {
    await pool.end();
    await redis.quit();
    process.exit(0);
  });
});

server.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
