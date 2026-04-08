import { Injectable, Inject, HttpException, HttpStatus } from '@nestjs/common';
import type { Pool } from 'pg';
import type Redis from 'ioredis';

@Injectable()
export class GetOrderService {
  constructor(
    @Inject('PG_POOL') private readonly pool: Pool,
    @Inject('REDIS') private readonly redis: Redis,
  ) {}

  async execute(id: number) {
    const result = await this.pool.query(
      'SELECT id, user_id, product_id, quantity, total, created_at FROM orders WHERE id = $1', [id]
    );
    if (result.rows.length === 0) throw new HttpException({ error: 'order not found' }, HttpStatus.NOT_FOUND);
    const row = result.rows[0];

    let userName = '';
    const userRaw = await this.redis.get(`user:${row.user_id}`);
    if (userRaw) userName = JSON.parse(userRaw).name;

    let productName = '';
    const prodResult = await this.pool.query('SELECT name FROM products WHERE id = $1', [row.product_id]);
    if (prodResult.rows.length > 0) productName = prodResult.rows[0].name;

    return {
      order_id: row.id,
      user_name: userName,
      product_name: productName,
      quantity: row.quantity,
      total: parseFloat(row.total),
      created_at: row.created_at.toISOString(),
    };
  }
}
