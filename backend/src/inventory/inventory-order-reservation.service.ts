import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, Repository } from 'typeorm';
import { Order } from '../orders/order.entity';
import { OrderInventoryLine } from '../orders/order-inventory-line.entity';
import { OrganizationsService } from '../organizations/organizations.service';
import { InventoryItem } from './inventory-item.entity';
import { StockBalance } from './stock-balance.entity';
import { InventoryMovement } from './inventory-movement.entity';

@Injectable()
export class InventoryOrderReservationService {
  private readonly log = new Logger(InventoryOrderReservationService.name);

  constructor(
    @InjectRepository(OrderInventoryLine)
    private readonly lineRepo: Repository<OrderInventoryLine>,
    @InjectRepository(Order)
    private readonly orderRepo: Repository<Order>,
    @InjectRepository(InventoryItem)
    private readonly invItemRepo: Repository<InventoryItem>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
    private readonly orgService: OrganizationsService,
  ) {}

  private async readFlags(organizationId: string): Promise<{ reserveOnConfirm: boolean }> {
    const s = await this.orgService.getSettings(organizationId);
    const inv = s['inventory'];
    const o = inv && typeof inv === 'object' ? (inv as Record<string, unknown>) : {};
    const reserveOnConfirm = o['reserve_on_confirm'] !== false;
    return { reserveOnConfirm };
  }

  /**
   * После сохранения нового статуса заказа: резерв при confirmed/in_progress, снятие при cancelled.
   */
  async afterOrderStatusPersisted(
    orderId: string,
    organizationId: string,
    previousStatus: string,
    newStatus: string,
  ): Promise<void> {
    if (newStatus === 'cancelled' && previousStatus !== 'cancelled') {
      await this.releaseAllReserved(orderId, organizationId);
      return;
    }
    if (
      newStatus === 'pending_confirmation' &&
      previousStatus !== 'pending_confirmation' &&
      (previousStatus === 'confirmed' ||
        previousStatus === 'in_progress' ||
        previousStatus === 'pending_approval')
    ) {
      await this.releaseAllReserved(orderId, organizationId);
      return;
    }
    if (
      (newStatus === 'confirmed' || newStatus === 'in_progress') &&
      newStatus !== previousStatus
    ) {
      await this.reservePlannedForOrder(orderId, organizationId);
    }
  }

  async createPlannedLine(
    orderId: string,
    organizationId: string,
    dto: {
      inventory_item_id: string;
      quantity: number;
      unit?: string | null;
      order_item_id?: string | null;
    },
  ): Promise<OrderInventoryLine> {
    const qty = Number(dto.quantity);
    if (!(qty > 0) || Number.isNaN(qty)) {
      throw new BadRequestException('Укажите количество больше нуля');
    }
    const order = await this.orderRepo.findOne({ where: { id: orderId, organizationId } });
    if (!order) throw new NotFoundException('Заказ не найден');
    const st = String((order as any).status || '');
    if (st === 'cancelled' || st === 'done') {
      throw new BadRequestException('Нельзя добавить материалы к этому заказу');
    }
    const item = await this.invItemRepo.findOne({
      where: { id: dto.inventory_item_id, organizationId },
    });
    if (!item) throw new NotFoundException('Позиция склада не найдена');
    const unit = (dto.unit && String(dto.unit).trim()) || item.unit || 'pcs';
    let orderItemId: string | null = null;
    if (dto.order_item_id != null && String(dto.order_item_id).trim() !== '') {
      orderItemId = String(dto.order_item_id).trim();
    }
    const line = this.lineRepo.create({
      organizationId,
      orderId,
      inventoryItemId: item.id,
      orderItemId,
      quantityPlanned: qty,
      quantityReserved: 0,
      unit,
      status: 'planned',
    });
    await this.lineRepo.save(line);
    if (st === 'confirmed' || st === 'in_progress') {
      await this.reservePlannedForOrder(orderId, organizationId);
    }
    return (await this.lineRepo.findOne({ where: { id: line.id } })) ?? line;
  }

  async listLinesForOrder(orderId: string, organizationId: string): Promise<OrderInventoryLine[]> {
    return this.lineRepo.find({
      where: { orderId, organizationId },
      order: { createdAt: 'ASC' },
    });
  }

  async reservePlannedForOrder(orderId: string, organizationId: string): Promise<void> {
    const { reserveOnConfirm } = await this.readFlags(organizationId);
    if (!reserveOnConfirm) return;

    try {
      await this.dataSource.transaction(async (em) => {
        const lines = await em.find(OrderInventoryLine, {
          where: { orderId, organizationId, status: 'planned' },
          order: { inventoryItemId: 'ASC', id: 'ASC' },
        });
        if (lines.length === 0) return;

        for (const line of lines) {
          await this.reserveOneLine(em, organizationId, orderId, line);
        }
      });
    } catch (e) {
      this.log.warn(`reservePlannedForOrder order=${orderId}: ${e}`);
    }
  }

  private async reserveOneLine(
    em: EntityManager,
    organizationId: string,
    orderId: string,
    line: OrderInventoryLine,
  ): Promise<void> {
    const item = await em.findOne(InventoryItem, {
      where: { id: line.inventoryItemId, organizationId },
    });
    if (!item) {
      line.status = 'not_enough_stock';
      line.quantityReserved = 0;
      await em.save(line);
      return;
    }
    const need = line.quantityPlanned;
    if (!item.trackStock) {
      line.status = 'reserved';
      line.quantityReserved = need;
      await em.save(line);
      return;
    }
    const bal = await this.lockBalance(em, organizationId, line.inventoryItemId);
    if (!bal) {
      line.status = 'not_enough_stock';
      line.quantityReserved = 0;
      await em.save(line);
      return;
    }
    const beforeT = bal.quantityTotal;
    const beforeR = bal.quantityReserved;
    const beforeA = beforeT - beforeR;
    const avail = beforeA;
    if (avail < need) {
      line.status = 'not_enough_stock';
      line.quantityReserved = 0;
      await em.save(line);
      return;
    }
    bal.quantityReserved = beforeR + need;
    await em.save(bal);
    const afterR = bal.quantityReserved;
    const afterA = bal.quantityTotal - afterR;
    line.status = 'reserved';
    line.quantityReserved = need;
    await em.save(line);
    const mov = em.create(InventoryMovement, {
      organizationId,
      inventoryItemId: item.id,
      stockBalanceId: bal.id,
      movementType: 'reserve',
      sourceType: 'order_confirm',
      quantity: need,
      unit: line.unit,
      quantityBeforeTotal: beforeT,
      quantityAfterTotal: beforeT,
      quantityBeforeReserved: beforeR,
      quantityAfterReserved: afterR,
      quantityBeforeAvailable: beforeA,
      quantityAfterAvailable: afterA,
      orderId,
      orderInventoryLineId: line.id,
      isAutomatic: true,
      automaticReason: 'order_confirmed',
      reason: null,
      comment: null,
      metadata: null,
    });
    await em.save(mov);
  }

  private async lockBalance(
    em: EntityManager,
    organizationId: string,
    inventoryItemId: string,
  ): Promise<StockBalance | null> {
    return em
      .createQueryBuilder(StockBalance, 'b')
      .setLock('pessimistic_write')
      .innerJoin('b.inventoryItem', 'i')
      .where('b.organizationId = :orgId', { orgId: organizationId })
      .andWhere('i.id = :iid', { iid: inventoryItemId })
      .getOne();
  }

  async releaseAllReserved(orderId: string, organizationId: string): Promise<void> {
    try {
      await this.dataSource.transaction(async (em) => {
        const lines = await em.find(OrderInventoryLine, {
          where: { orderId, organizationId, status: 'reserved' },
          order: { inventoryItemId: 'ASC', id: 'ASC' },
        });
        for (const line of lines) {
          const qty = line.quantityReserved;
          if (!(qty > 0)) continue;
          const item = await em.findOne(InventoryItem, {
            where: { id: line.inventoryItemId, organizationId },
          });
          if (!item) {
            line.status = 'released';
            line.quantityReserved = 0;
            await em.save(line);
            continue;
          }
          if (!item.trackStock) {
            line.status = 'released';
            line.quantityReserved = 0;
            await em.save(line);
            continue;
          }
          const bal = await this.lockBalance(em, organizationId, line.inventoryItemId);
          if (!bal) {
            line.status = 'released';
            line.quantityReserved = 0;
            await em.save(line);
            continue;
          }
          const beforeT = bal.quantityTotal;
          const beforeR = bal.quantityReserved;
          const beforeA = beforeT - beforeR;
          const release = Math.min(qty, beforeR);
          bal.quantityReserved = beforeR - release;
          await em.save(bal);
          const afterR = bal.quantityReserved;
          const afterA = bal.quantityTotal - afterR;
          line.status = 'released';
          line.quantityReserved = 0;
          await em.save(line);
          const mov = em.create(InventoryMovement, {
            organizationId,
            inventoryItemId: item.id,
            stockBalanceId: bal.id,
            movementType: 'release_reserve',
            sourceType: 'order_cancelled',
            quantity: release,
            unit: line.unit,
            quantityBeforeTotal: beforeT,
            quantityAfterTotal: beforeT,
            quantityBeforeReserved: beforeR,
            quantityAfterReserved: afterR,
            quantityBeforeAvailable: beforeA,
            quantityAfterAvailable: afterA,
            orderId,
            orderInventoryLineId: line.id,
            isAutomatic: true,
            automaticReason: 'order_cancelled',
            reason: null,
            comment: null,
            metadata: null,
          });
          await em.save(mov);
        }
      });
    } catch (e) {
      this.log.warn(`releaseAllReserved order=${orderId}: ${e}`);
    }
  }
}
