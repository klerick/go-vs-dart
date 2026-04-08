import { Module, DynamicModule } from '@nestjs/common';
import Redis from 'ioredis';

@Module({})
export class RedisModule {
  static forRoot(url?: string): DynamicModule {
    const redisUrl = url || process.env.REDIS_URL || 'redis://localhost:6379';
    return {
      module: RedisModule,
      global: true,
      providers: [
        {
          provide: 'REDIS',
          useFactory: () => new Redis(redisUrl),
        },
      ],
      exports: ['REDIS'],
    };
  }
}
