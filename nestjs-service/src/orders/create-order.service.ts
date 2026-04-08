import { Injectable, Inject, HttpException, HttpStatus } from '@nestjs/common';
import type { Pool } from 'pg';
import type Redis from 'ioredis';

@Injectable()
export class CreateOrderService {
  constructor(
    @Inject('PG_POOL') private readonly pool: Pool,
    @Inject('REDIS') private readonly redis: Redis,
  ) {}

  async execute(body: any) {
    const { user_id, product_id, quantity } = body;
    if (!Number.isInteger(user_id) || !Number.isInteger(product_id) || !Number.isInteger(quantity)) {
      throw new HttpException({ error: 'user_id, product_id, and quantity are required integers' }, HttpStatus.BAD_REQUEST);
    }
    if (quantity <= 0) {
      throw new HttpException({ error: 'quantity must be > 0' }, HttpStatus.BAD_REQUEST);
    }

    const userRaw = await this.redis.get(`user:${user_id}`);
    if (!userRaw) throw new HttpException({ error: 'user not found' }, HttpStatus.NOT_FOUND);
    const user = JSON.parse(userRaw);

    const productResult = await this.pool.query('SELECT id, name, price FROM products WHERE id = $1', [product_id]);
    if (productResult.rows.length === 0) throw new HttpException({ error: 'product not found' }, HttpStatus.NOT_FOUND);
    const product = productResult.rows[0];
    const price = parseFloat(product.price);
    const total = price * quantity;

    const insertResult = await this.pool.query(
      'INSERT INTO orders (user_id, product_id, quantity, total, created_at) VALUES ($1, $2, $3, $4, NOW()) RETURNING id, created_at',
      [user_id, product_id, quantity, total]
    );
    const order = insertResult.rows[0];

    await this.redis.del(`order_cache:${user_id}`);

    return {
      order_id: order.id,
      user_name: user.name,
      product_name: product.name,
      quantity,
      total,
      created_at: order.created_at.toISOString(),
    };
  }
}
