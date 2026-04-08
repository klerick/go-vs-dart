import { Controller, Get, Param, ParseIntPipe } from '@nestjs/common';
import { GetOrderService } from './get-order.service';

@Controller('orders')
export class GetOrderController {
  constructor(private readonly getOrderService: GetOrderService) {}

  @Get(':id')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.getOrderService.execute(id);
  }
}
