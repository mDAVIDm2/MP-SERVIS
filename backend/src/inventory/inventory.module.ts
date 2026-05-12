import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { InventoryItem } from './inventory-item.entity';
import { StockBalance } from './stock-balance.entity';
import { InventoryMovement } from './inventory-movement.entity';
import { InventoryService } from './inventory.service';
import { InventoryController } from './inventory.controller';
import { InventoryOrderReservationService } from './inventory-order-reservation.service';
import { OrderInventoryLine } from '../orders/order-inventory-line.entity';
import { Order } from '../orders/order.entity';
import { OrganizationsModule } from '../organizations/organizations.module';

@Module({
  imports: [
    OrganizationsModule,
    TypeOrmModule.forFeature([InventoryItem, StockBalance, InventoryMovement, OrderInventoryLine, Order]),
  ],
  controllers: [InventoryController],
  providers: [InventoryService, InventoryOrderReservationService],
  exports: [InventoryService, InventoryOrderReservationService],
})
export class InventoryModule {}
