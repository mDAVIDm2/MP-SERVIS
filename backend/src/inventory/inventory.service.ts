import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, EntityManager, In, Repository } from 'typeorm';
import { Request } from 'express';
import { isClientAppRequest } from '../common/request-app.util';
import { User } from '../users/user.entity';
import { InventoryItem, InventoryItemType } from './inventory-item.entity';
import { StockBalance } from './stock-balance.entity';
import { InventoryMovement } from './inventory-movement.entity';
import { CreateInventoryItemDto } from './dto/create-inventory-item.dto';
import { PatchInventoryItemDto } from './dto/patch-inventory-item.dto';
import { InventoryReceiptDto } from './dto/inventory-receipt.dto';

@Injectable()
export class InventoryService {
  constructor(
    @InjectRepository(InventoryItem)
    private readonly itemRepo: Repository<InventoryItem>,
    @InjectRepository(StockBalance)
    private readonly balRepo: Repository<StockBalance>,
    @InjectRepository(InventoryMovement)
    private readonly movRepo: Repository<InventoryMovement>,
    @InjectDataSource()
    private readonly dataSource: DataSource,
  ) {}

  assertInventoryAccess(req: Request & { user?: User }): { orgId: string; user: User; hidePrices: boolean } {
    if (isClientAppRequest(req)) {
      throw new ForbiddenException('Доступно только в приложении для бизнеса');
    }
    const user = req.user;
    if (!user?.organizationId) {
      throw new ForbiddenException('Выберите организацию');
    }
    if (user.role === 'master') {
      throw new ForbiddenException('Склад недоступен для роли мастера');
    }
    return { orgId: user.organizationId, user, hidePrices: false };
  }

  private serializeItem(item: InventoryItem, hidePrices: boolean) {
    const b = item.stockBalance;
    const total = b?.quantityTotal ?? 0;
    const reserved = b?.quantityReserved ?? 0;
    return {
      id: item.id,
      organization_id: item.organizationId,
      item_type: item.itemType,
      category: item.category,
      name: item.name,
      description: item.description,
      brand: item.brand,
      article: item.article,
      sku: item.sku,
      barcode: item.barcode,
      unit: item.unit,
      purchase_price_kopecks: hidePrices ? null : item.purchasePriceKopecks,
      sale_price_kopecks: hidePrices ? null : item.salePriceKopecks,
      min_stock: item.minStock,
      track_stock: item.trackStock,
      allow_fractional: item.allowFractional,
      is_active: item.isActive,
      external_id: item.externalId,
      external_system: item.externalSystem,
      sync_status: item.syncStatus,
      last_synced_at: item.lastSyncedAt?.toISOString() ?? null,
      created_at: item.createdAt.toISOString(),
      updated_at: item.updatedAt.toISOString(),
      quantity_total: total,
      quantity_reserved: reserved,
      quantity_available: total - reserved,
    };
  }

  private serializeMovement(m: InventoryMovement, itemName?: string | null) {
    return {
      id: m.id,
      organization_id: m.organizationId,
      inventory_item_id: m.inventoryItemId,
      item_name: itemName ?? null,
      stock_balance_id: m.stockBalanceId,
      movement_type: m.movementType,
      source_type: m.sourceType,
      quantity: m.quantity,
      unit: m.unit,
      quantity_before_total: m.quantityBeforeTotal,
      quantity_after_total: m.quantityAfterTotal,
      quantity_before_reserved: m.quantityBeforeReserved,
      quantity_after_reserved: m.quantityAfterReserved,
      quantity_before_available: m.quantityBeforeAvailable,
      quantity_after_available: m.quantityAfterAvailable,
      order_id: m.orderId,
      order_inventory_line_id: m.orderInventoryLineId ?? null,
      actor_user_id: m.actorUserId,
      actor_role: m.actorRole,
      actor_name_snapshot: m.actorNameSnapshot,
      is_automatic: m.isAutomatic,
      automatic_reason: m.automaticReason,
      comment: m.comment,
      created_at: m.createdAt.toISOString(),
    };
  }

  async listItems(orgId: string, hidePrices: boolean, includeInactive = false) {
    const qb = this.itemRepo
      .createQueryBuilder('i')
      .leftJoinAndSelect('i.stockBalance', 'b')
      .where('i.organization_id = :orgId', { orgId })
      .orderBy('i.name', 'ASC');
    if (!includeInactive) {
      qb.andWhere('i.is_active = true');
    }
    const items = await qb.getMany();
    return { items: items.map((i) => this.serializeItem(i, hidePrices)) };
  }

  async getItem(orgId: string, id: string, hidePrices: boolean) {
    const item = await this.itemRepo.findOne({
      where: { id, organizationId: orgId },
      relations: ['stockBalance'],
    });
    if (!item) throw new NotFoundException('Позиция не найдена');
    return this.serializeItem(item, hidePrices);
  }

  async createItem(orgId: string, user: User, dto: CreateInventoryItemDto) {
    const unit = dto.unit?.trim() || 'pcs';
    const itemType = (dto.item_type || 'material') as InventoryItemType;
    const initial = dto.initial_quantity ?? 0;
    if (initial < 0) throw new BadRequestException('initial_quantity не может быть отрицательным');

    return this.dataSource.transaction(async (em) => {
      const item = em.create(InventoryItem, {
        organizationId: orgId,
        itemType,
        name: dto.name.trim(),
        unit,
        category: dto.category?.trim() || null,
        createdByUserId: user.id,
        updatedByUserId: user.id,
      });
      await em.save(item);
      const bal = em.create(StockBalance, {
        organizationId: orgId,
        inventoryItem: item,
        quantityTotal: 0,
        quantityReserved: 0,
      });
      await em.save(bal);
      item.stockBalance = bal;

      if (initial > 0) {
        await this.applyReceiptTx(em, orgId, item, bal, user, initial, unit, 'purchase_receipt', 'receipt', null);
      }

      const reloaded = await em.findOne(InventoryItem, {
        where: { id: item.id },
        relations: ['stockBalance'],
      });
      return this.serializeItem(reloaded!, false);
    });
  }

  async patchItem(orgId: string, id: string, user: User, dto: PatchInventoryItemDto) {
    const item = await this.itemRepo.findOne({ where: { id, organizationId: orgId } });
    if (!item) throw new NotFoundException('Позиция не найдена');
    if (dto.name != null) item.name = dto.name.trim();
    if (dto.unit != null) item.unit = dto.unit.trim();
    if (dto.item_type != null) item.itemType = dto.item_type as InventoryItemType;
    if (dto.category !== undefined) item.category = dto.category?.trim() || null;
    if (dto.description !== undefined) item.description = dto.description;
    if (dto.brand !== undefined) item.brand = dto.brand?.trim() || null;
    if (dto.article !== undefined) item.article = dto.article?.trim() || null;
    if (dto.sku !== undefined) item.sku = dto.sku?.trim() || null;
    if (dto.purchase_price_kopecks !== undefined) item.purchasePriceKopecks = dto.purchase_price_kopecks;
    if (dto.sale_price_kopecks !== undefined) item.salePriceKopecks = dto.sale_price_kopecks;
    if (dto.min_stock != null) item.minStock = dto.min_stock;
    if (dto.track_stock != null) item.trackStock = dto.track_stock;
    if (dto.allow_fractional != null) item.allowFractional = dto.allow_fractional;
    if (dto.is_active != null) item.isActive = dto.is_active;
    item.updatedByUserId = user.id;
    await this.itemRepo.save(item);
    return this.getItem(orgId, id, false);
  }

  async listMovementsForItem(orgId: string, itemId: string, limit = 200) {
    const item = await this.itemRepo.findOne({ where: { id: itemId, organizationId: orgId } });
    if (!item) throw new NotFoundException('Позиция не найдена');
    const rows = await this.movRepo.find({
      where: { organizationId: orgId, inventoryItemId: itemId },
      order: { createdAt: 'DESC' },
      take: Math.min(limit, 500),
    });
    return { items: rows.map((m) => this.serializeMovement(m, null)) };
  }

  async listRecentMovements(orgId: string, limit = 150) {
    const rows = await this.movRepo.find({
      where: { organizationId: orgId },
      order: { createdAt: 'DESC' },
      take: Math.min(limit, 500),
    });
    if (rows.length === 0) return { items: [] };
    const itemIds = [...new Set(rows.map((r) => r.inventoryItemId))];
    const items = await this.itemRepo.find({ where: { id: In(itemIds), organizationId: orgId } });
    const nameById = new Map(items.map((i) => [i.id, i.name] as const));
    return {
      items: rows.map((m) => this.serializeMovement(m, nameById.get(m.inventoryItemId) ?? null)),
    };
  }

  async receipt(orgId: string, itemId: string, user: User, dto: InventoryReceiptDto) {
    const qty = dto.quantity;
    if (!(qty > 0)) throw new BadRequestException('Укажите количество больше нуля');

    return this.dataSource.transaction(async (em) => {
      const item = await em.findOne(InventoryItem, {
        where: { id: itemId, organizationId: orgId },
        relations: ['stockBalance'],
      });
      if (!item?.stockBalance) throw new NotFoundException('Позиция не найдена');
      const unit = dto.unit?.trim() || item.unit;
      await this.applyReceiptTx(
        em,
        orgId,
        item,
        item.stockBalance,
        user,
        qty,
        unit,
        'manual',
        'receipt',
        dto.comment?.trim() || null,
      );
      const reloaded = await em.findOne(InventoryItem, {
        where: { id: itemId },
        relations: ['stockBalance'],
      });
      return this.serializeItem(reloaded!, false);
    });
  }

  private async applyReceiptTx(
    em: EntityManager,
    orgId: string,
    item: InventoryItem,
    bal: StockBalance,
    user: User,
    qty: number,
    unit: string,
    sourceType: string,
    movementType: string,
    comment: string | null,
  ) {
    const b = await em
      .getRepository(StockBalance)
      .createQueryBuilder('b')
      .setLock('pessimistic_write')
      .where('b.id = :id', { id: bal.id })
      .getOne();
    if (!b) throw new NotFoundException('Остаток не найден');

    const beforeT = b.quantityTotal;
    const beforeR = b.quantityReserved;
    const beforeA = beforeT - beforeR;
    b.quantityTotal = beforeT + qty;
    const afterT = b.quantityTotal;
    const afterR = b.quantityReserved;
    const afterA = afterT - afterR;
    await em.save(b);

    const mov = em.create(InventoryMovement, {
      organizationId: orgId,
      inventoryItemId: item.id,
      stockBalanceId: b.id,
      movementType,
      sourceType,
      quantity: qty,
      unit,
      quantityBeforeTotal: beforeT,
      quantityAfterTotal: afterT,
      quantityBeforeReserved: beforeR,
      quantityAfterReserved: afterR,
      quantityBeforeAvailable: beforeA,
      quantityAfterAvailable: afterA,
      actorUserId: user.id,
      actorRole: user.role,
      actorNameSnapshot: user.name?.trim() || null,
      isAutomatic: false,
      comment,
    });
    await em.save(mov);
  }
}
