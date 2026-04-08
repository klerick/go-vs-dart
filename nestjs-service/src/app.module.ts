import { Module } from '@nestjs/common';
import { DatabaseModule } from './common/database.module';
import { RedisModule } from './common/redis.module';
import { HealthModule } from './health/health.module';
import { OrdersModule } from './orders/orders.module';

@Module({
  imports: [
    DatabaseModule.forRoot(),
    RedisModule.forRoot(),
    HealthModule,
    OrdersModule,
  ],
})
export class AppModule {}
