import { Pool } from "https://deno.land/x/postgres@v0.19.3/mod.ts";
import { connect } from "https://deno.land/x/redis@v0.32.4/mod.ts";

const PORT = parseInt(Deno.env.get('HTTP_PORT') || '8080');
const POSTGRES_URL = Deno.env.get('POSTGRES_URL') || 'postgres://bench:bench@localhost:5432/bench';
const REDIS_URL = Deno.env.get('REDIS_URL') || 'redis://localhost:6379';

// Parse Postgres URL
const pgUri = new URL(POSTGRES_URL);
const pgPool = new Pool({
  hostname: pgUri.hostname,
  port: parseInt(pgUri.port) || 5432,
  database: pgUri.pathname.slice(1),
  user: pgUri.username,
  password: pgUri.password,
}, 10);

// Parse Redis URL
const redisUri = new URL(REDIS_URL);
const redis = await connect({
  hostname: redisUri.hostname || 'localhost',
  port: parseInt(redisUri.port) || 6379,
});

Deno.serve({ port: PORT, hostname: '0.0.0.0' }, async (req) => {
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

  const client = await pgPool.connect();
  try {
    const productResult = await client.queryArray`SELECT id, name, price FROM products WHERE id = ${product_id}`;
    if (productResult.rows.length === 0) return json(404, { error: 'product not found' });
    const [, productName, rawPrice] = productResult.rows[0];
    const price = parseFloat(rawPrice);
    const total = price * quantity;

    const insertResult = await client.queryArray`INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES (${user_id}, ${product_id}, ${quantity}, ${total}, NOW()) RETURNING id, created_at`;
    const [orderId, createdAt] = insertResult.rows[0];

    await redis.del(`order_cache:${user_id}`);

    return json(201, {
      order_id: orderId,
      user_name: user.name,
      product_name: productName,
      quantity,
      total,
      created_at: new Date(createdAt).toISOString(),
    });
  } finally {
    client.release();
  }
}

async function handleGetOrder(id) {
  const client = await pgPool.connect();
  try {
    const result = await client.queryArray`SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = ${id}`;
    if (result.rows.length === 0) return json(404, { error: 'order not found' });
    const [, userId, productId, quantity, rawTotal, createdAt] = result.rows[0];
    const total = parseFloat(rawTotal);

    let userName = '';
    const userRaw = await redis.get(`user:${userId}`);
    if (userRaw) userName = JSON.parse(userRaw).name;

    let productName = '';
    const prodResult = await client.queryArray`SELECT name FROM products WHERE id = ${productId}`;
    if (prodResult.rows.length > 0) productName = prodResult.rows[0][0];

    return json(200, {
      order_id: id,
      user_name: userName,
      product_name: productName,
      quantity,
      total,
      created_at: new Date(createdAt).toISOString(),
    });
  } finally {
    client.release();
  }
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

  const client = await pgPool.connect();
  try {
    const result = await client.queryArray`SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = ${userId} ORDER BY o.created_at DESC LIMIT ${limit} OFFSET ${offset}`;

    const orders = result.rows.map(row => ({
      order_id: row[0],
      user_name: userName,
      product_name: row[5],
      quantity: row[2],
      total: parseFloat(row[3]),
      created_at: new Date(row[4]).toISOString(),
    }));

    return json(200, { orders, count: orders.length });
  } finally {
    client.release();
  }
}

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

Deno.addSignalListener('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down...');
  await pgPool.end();
  redis.close();
  Deno.exit(0);
});
