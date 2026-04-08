import { createClient } from 'redis';
import pg from 'pg';

const PORT = parseInt(process.env.HTTP_PORT || '8080');
const POSTGRES_URL = process.env.POSTGRES_URL || 'postgres://bench:bench@localhost:5432/bench';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const pool = new pg.Pool({ connectionString: POSTGRES_URL, max: 10, ssl: false });
const redis = createClient({ url: REDIS_URL });
await redis.connect();

Bun.serve({
  port: PORT,
  async fetch(req) {
    try {
      const url = new URL(req.url);
      const path = url.pathname;
      const method = req.method;

      if (method === 'GET' && path === '/health') {
        return json(200, { status: 'ok' });
      }

      if (method === 'POST' && path === '/orders') {
        return await handleCreateOrder(req);
      }

      const getMatch = path.match(/^\/orders\/(\d+)$/);
      if (method === 'GET' && getMatch) {
        return await handleGetOrder(parseInt(getMatch[1]));
      }

      if (method === 'GET' && path === '/orders') {
        return await handleListOrders(url);
      }

      return json(404, { error: 'not found' });
    } catch (err) {
      console.error('Error handling request:', err);
      return json(500, { error: 'internal server error' });
    }
  },
});

console.log(`Server listening on port ${PORT}`);

async function handleCreateOrder(req) {
  let body;
  try {
    body = await req.json();
  } catch {
    return json(400, { error: 'invalid JSON' });
  }

  const { user_id, product_id, quantity } = body;
  if (!Number.isInteger(user_id) || !Number.isInteger(product_id) || !Number.isInteger(quantity)) {
    return json(400, { error: 'user_id, product_id, and quantity are required integers' });
  }
  if (quantity <= 0) return json(400, { error: 'quantity must be > 0' });

  const userRaw = await redis.get(`user:${user_id}`);
  if (!userRaw) return json(404, { error: 'user not found' });
  const user = JSON.parse(userRaw);

  const productResult = await pool.query('SELECT id, name, price FROM products WHERE id = $1', [product_id]);
  if (productResult.rows.length === 0) return json(404, { error: 'product not found' });
  const product = productResult.rows[0];
  const price = parseFloat(product.price);
  const total = price * quantity;

  const insertResult = await pool.query(
    'INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at',
    [user_id, product_id, quantity, total]
  );
  const order = insertResult.rows[0];

  await redis.del(`order_cache:${user_id}`);

  return json(201, {
    order_id: order.id,
    user_name: user.name,
    product_name: product.name,
    quantity,
    total,
    created_at: order.created_at.toISOString(),
  });
}

async function handleGetOrder(id) {
  const result = await pool.query(
    'SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = $1', [id]
  );
  if (result.rows.length === 0) return json(404, { error: 'order not found' });
  const row = result.rows[0];

  let userName = '';
  const userRaw = await redis.get(`user:${row.user_id}`);
  if (userRaw) userName = JSON.parse(userRaw).name;

  let productName = '';
  const prodResult = await pool.query('SELECT name FROM products WHERE id = $1', [row.product_id]);
  if (prodResult.rows.length > 0) productName = prodResult.rows[0].name;

  return json(200, {
    order_id: row.id,
    user_name: userName,
    product_name: productName,
    quantity: row.quantity,
    total: parseFloat(row.total),
    created_at: row.created_at.toISOString(),
  });
}

async function handleListOrders(url) {
  const userIdStr = url.searchParams.get('user_id');
  if (!userIdStr) return json(400, { error: 'user_id is required' });
  const userId = parseInt(userIdStr);
  if (isNaN(userId)) return json(400, { error: 'invalid user_id' });

  let limit = 20;
  const limitStr = url.searchParams.get('limit');
  if (limitStr) { const p = parseInt(limitStr); if (!isNaN(p) && p > 0 && p <= 100) limit = p; }

  let offset = 0;
  const offsetStr = url.searchParams.get('offset');
  if (offsetStr) { const p = parseInt(offsetStr); if (!isNaN(p) && p >= 0) offset = p; }

  let userName = '';
  const userRaw = await redis.get(`user:${userId}`);
  if (userRaw) userName = JSON.parse(userRaw).name;

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

  return json(200, { orders, count: orders.length });
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await pool.end();
  await redis.quit();
  process.exit(0);
});
