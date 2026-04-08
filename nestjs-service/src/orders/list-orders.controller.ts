import { Controller, Get, Query } from '@nestjs/common';
import { ListOrdersService } from './list-orders.service';

@Controller('orders')
export class ListOrdersController {
  constructor(private readonly listOrdersService: ListOrdersService) {}

  @Get()
  list(@Query('user_id') userId: string, @Query('limit') limit: string, @Query('offset') offset: string) {
    return this.listOrdersService.execute(userId, limit, offset);
  }
}
