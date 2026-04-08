import { SQL } from "bun";
import { RedisClient } from "bun";

const PORT = parseInt(process.env.HTTP_PORT || '8080');
const POSTGRES_URL = process.env.POSTGRES_URL || 'postgres://bench:bench@localhost:5432/bench';
const REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';

const sql = new SQL(POSTGRES_URL);
const redis = new RedisClient(REDIS_URL);

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

  const products = await sql`SELECT id, name, price FROM products WHERE id = ${product_id}`;
  if (products.length === 0) return json(404, { error: 'product not found' });
  const product = products[0];
  const price = parseFloat(product.price);
  const total = price * quantity;

  const orders = await sql`INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES (${user_id}, ${product_id}, ${quantity}, ${total}, NOW()) RETURNING id, created_at`;
  const order = orders[0];

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
  const rows = await sql`SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = ${id}`;
  if (rows.length === 0) return json(404, { error: 'order not found' });
  const row = rows[0];

  let userName = '';
  const userRaw = await redis.get(`user:${row.user_id}`);
  if (userRaw) userName = JSON.parse(userRaw).name;

  let productName = '';
  const prods = await sql`SELECT name FROM products WHERE id = ${row.product_id}`;
  if (prods.length > 0) productName = prods[0].name;

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

  const rows = await sql`SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = ${userId} ORDER BY o.created_at DESC LIMIT ${limit} OFFSET ${offset}`;

  const orders = rows.map(row => ({
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
  await sql.close();
  redis.close();
  process.exit(0);
});
