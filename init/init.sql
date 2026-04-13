CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  price NUMERIC(10,2) NOT NULL
);

CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL,
  product_id INTEGER NOT NULL,
  quantity INTEGER NOT NULL,
  total NUMERIC(10,2) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);

-- Seed 100 products
INSERT INTO products (name, price)
SELECT
  'Product ' || i,
  (random() * 100 + 1)::numeric(10,2)
FROM generate_series(1, 100) AS i
ON CONFLICT DO NOTHING;

-- Seed 100k orders
INSERT INTO orders (user_id, product_id, quantity, total, created_at)
SELECT
  (random() * 99 + 1)::int,
  (random() * 99 + 1)::int,
  (random() * 4 + 1)::int,
  (random() * 500 + 1)::numeric(10,2),
  NOW() - (random() * interval '90 days')
FROM generate_series(1, 100000);

ANALYZE orders;
ANALYZE products;
