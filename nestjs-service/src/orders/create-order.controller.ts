import { Controller, Post, Body, HttpCode, HttpStatus } from '@nestjs/common';
import { CreateOrderService } from './create-order.service';

@Controller('orders')
export class CreateOrderController {
  constructor(private readonly createOrderService: CreateOrderService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  create(@Body() body: any) {
    return this.createOrderService.execute(body);
  }
}
