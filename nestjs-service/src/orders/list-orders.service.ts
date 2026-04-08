import { Injectable, Inject, HttpException, HttpStatus } from '@nestjs/common';
import type { Pool } from 'pg';
import type Redis from 'ioredis';

@Injectable()
export class ListOrdersService {
  constructor(
    @Inject('PG_POOL') private readonly pool: Pool,
    @Inject('REDIS') private readonly redis: Redis,
  ) {}

  async execute(userIdStr: string, limitStr?: string, offsetStr?: string) {
    if (!userIdStr) throw new HttpException({ error: 'user_id is required' }, HttpStatus.BAD_REQUEST);
    const userId = parseInt(userIdStr);
    if (isNaN(userId)) throw new HttpException({ error: 'invalid user_id' }, HttpStatus.BAD_REQUEST);

    let limit = 20;
    if (limitStr) { const p = parseInt(limitStr); if (!isNaN(p) && p > 0 && p <= 100) limit = p; }
    let offset = 0;
    if (offsetStr) { const p = parseInt(offsetStr); if (!isNaN(p) && p >= 0) offset = p; }

    let userName = '';
    const userRaw = await this.redis.get(`user:${userId}`);
    if (userRaw) userName = JSON.parse(userRaw).name;

    const result = await this.pool.query(
      'SELECT o.id, o.product_id, o.quantity, o.total, o.created_at, p.name FROM orders o JOIN products p ON p.id = o.product_id WHERE o.user_id = $1 ORDER BY o.created_at DESC LIMIT $2 OFFSET $3',
      [userId, limit, offset]
    );

    const orders = result.rows.map((row: any) => ({
      order_id: row.id,
      user_name: userName,
      product_name: row.name,
      quantity: row.quantity,
      total: parseFloat(row.total),
      created_at: row.created_at.toISOString(),
    }));

    return { orders, count: orders.length };
  }
}
