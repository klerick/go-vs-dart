import { Module } from '@nestjs/common';
import { DatabaseModule } from '../common/database.module';
import { CreateOrderController } from './create-order.controller';
import { CreateOrderService } from './create-order.service';
import { GetOrderController } from './get-order.controller';
import { GetOrderService } from './get-order.service';
import { ListOrdersController } from './list-orders.controller';
import { ListOrdersService } from './list-orders.service';

@Module({
  imports: [
    DatabaseModule.forChild(['ProductRepository', 'OrderRepository']),
  ],
  controllers: [CreateOrderController, GetOrderController, ListOrdersController],
  providers: [CreateOrderService, GetOrderService, ListOrdersService],
})
export class OrdersModule {}
