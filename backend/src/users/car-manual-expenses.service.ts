import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import { CarManualExpense } from './car-manual-expense.entity';
import { User } from './user.entity';
import { ClientCarsService } from './client-cars.service';
import {
  ListManualExpensesQueryDto,
  SyncManualExpensesDto,
  UpsertManualExpenseDto,
} from './dto/car-manual-expense.dto';

interface CursorPayload {
  t: string;
  id: string;
}

@Injectable()
export class CarManualExpensesService {
  constructor(
    @InjectRepository(CarManualExpense) private readonly repo: Repository<CarManualExpense>,
    private readonly cars: ClientCarsService,
  ) {}

  encodeCursor(row: CarManualExpense): string {
    return Buffer.from(JSON.stringify({ t: row.updatedAt.toISOString(), id: row.id }), 'utf8').toString(
      'base64url',
    );
  }

  private decodeCursor(c: string): CursorPayload | null {
    try {
      const j = JSON.parse(Buffer.from(c, 'base64url').toString('utf8')) as unknown;
      if (j && typeof (j as CursorPayload).t === 'string' && typeof (j as CursorPayload).id === 'string') {
        return j as CursorPayload;
      }
    } catch {
      /* ignore */
    }
    return null;
  }

  toApiItem(e: CarManualExpense): Record<string, unknown> {
    const litersRaw = e.liters != null && String(e.liters).trim() !== '' ? Number.parseFloat(String(e.liters)) : null;
    const fuelLiters = litersRaw != null && !Number.isNaN(litersRaw) ? litersRaw : null;
    return {
      serverId: e.id,
      clientRecordId: e.clientLocalId,
      carId: e.carId,
      date: e.date.toISOString(),
      kind: e.kind,
      priceKopecks: e.priceKopecks,
      fuelType: e.fuelType,
      fuelLiters,
      fuelPricePerLiterKopecks: e.pricePerLiterKopecks,
      odometerKm: e.odometerKm,
      fuelStationName: e.fuelStationName,
      fullTank: e.fullTank,
      presetId: e.presetId,
      customTitle: e.customTitle,
      note: e.note,
      expenseGroupId: e.expenseGroupId,
      expenseSubId: e.expenseSubId,
      expenseCategoryId: e.expenseCategoryId,
      expenseItemTitle: e.expenseItemTitle,
      analyticsOperationName: e.analyticsOperationName,
      materialPriceKopecks: e.materialPriceKopecks,
      laborPriceKopecks: e.laborPriceKopecks,
      placeName: e.placeName,
      clientUpdatedAt: e.clientUpdatedAt?.toISOString() ?? null,
      serverUpdatedAt: e.updatedAt.toISOString(),
      deletedAt: e.deletedAt?.toISOString() ?? null,
      deviceId: e.deviceId,
      version: e.version,
    };
  }

  async list(user: User, carId: string, q: ListManualExpensesQueryDto) {
    await this.cars.assertOwnsCar(user, carId);
    const limit = q.limit != null && q.limit > 0 ? Math.min(q.limit, 500) : 100;
    const includeDeleted = q.includeDeleted === true;
    const qb = this.repo
      .createQueryBuilder('e')
      .where('e.user_id = :uid AND e.car_id = :cid', { uid: user.id, cid: carId });
    if (!includeDeleted) {
      qb.andWhere('e.deleted_at IS NULL');
    }
    if (q.from) {
      qb.andWhere('e.date >= :from', { from: new Date(q.from) });
    }
    if (q.to) {
      qb.andWhere('e.date <= :to', { to: new Date(q.to) });
    }
    if (q.updatedSince) {
      qb.andWhere('e.updated_at > :us', { us: new Date(q.updatedSince) });
    }
    if (q.cursor) {
      const cur = this.decodeCursor(q.cursor);
      if (cur) {
        const ct = new Date(cur.t);
        qb.andWhere(
          new Brackets((w) => {
            w.where('e.updated_at > :ct', { ct }).orWhere('(e.updated_at = :ct2 AND e.id > :cid)', {
              ct2: ct,
              cid: cur.id,
            });
          }),
        );
      }
    }
    qb.orderBy('e.updated_at', 'ASC').addOrderBy('e.id', 'ASC').take(limit + 1);
    const rows = await qb.getMany();
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const nextCursor = hasMore && items.length ? this.encodeCursor(items[items.length - 1]!) : null;
    return {
      items: items.map((r) => this.toApiItem(r)),
      nextCursor,
      serverTime: new Date().toISOString(),
    };
  }

  private async applyUpsertInternal(
    userId: string,
    carId: string,
    clientRecordId: string,
    dto: UpsertManualExpenseDto,
  ): Promise<CarManualExpense> {
    const cid = clientRecordId.trim().slice(0, 120);
    let row = await this.repo.findOne({
      where: { userId, carId, clientLocalId: cid },
    });
    const litersStr =
      dto.fuelLiters != null && Number(dto.fuelLiters) > 0 ? String(dto.fuelLiters) : null;
    if (!row) {
      row = this.repo.create({
        userId,
        carId,
        clientLocalId: cid,
        kind: dto.kind.trim().slice(0, 40),
        date: new Date(dto.date),
        priceKopecks: dto.priceKopecks,
        fuelType: dto.fuelType?.trim() || null,
        liters: litersStr,
        pricePerLiterKopecks: dto.fuelPricePerLiterKopecks ?? null,
        odometerKm: dto.odometerKm ?? null,
        fuelStationName: dto.fuelStationName?.trim() || null,
        fullTank: dto.fullTank ?? null,
        presetId: dto.presetId?.trim() || null,
        customTitle: dto.customTitle?.trim() || null,
        note: dto.note?.trim() || null,
        expenseGroupId: dto.expenseGroupId?.trim() || null,
        expenseSubId: dto.expenseSubId?.trim() || null,
        expenseCategoryId: dto.expenseCategoryId?.trim() || null,
        expenseItemTitle: dto.expenseItemTitle?.trim() || null,
        analyticsOperationName: dto.analyticsOperationName?.trim() || null,
        materialPriceKopecks: dto.materialPriceKopecks ?? null,
        laborPriceKopecks: dto.laborPriceKopecks ?? null,
        placeName: dto.placeName?.trim() || null,
        clientUpdatedAt: dto.clientUpdatedAt ? new Date(dto.clientUpdatedAt) : null,
        deviceId: dto.deviceId?.trim() || null,
        deletedAt: null,
      });
    } else {
      row.kind = dto.kind.trim().slice(0, 40);
      row.date = new Date(dto.date);
      row.priceKopecks = dto.priceKopecks;
      row.fuelType = dto.fuelType?.trim() || null;
      row.liters = litersStr;
      row.pricePerLiterKopecks = dto.fuelPricePerLiterKopecks ?? null;
      row.odometerKm = dto.odometerKm ?? null;
      row.fuelStationName = dto.fuelStationName?.trim() || null;
      row.fullTank = dto.fullTank ?? null;
      row.presetId = dto.presetId?.trim() || null;
      row.customTitle = dto.customTitle?.trim() || null;
      row.note = dto.note?.trim() || null;
      row.expenseGroupId = dto.expenseGroupId?.trim() || null;
      row.expenseSubId = dto.expenseSubId?.trim() || null;
      row.expenseCategoryId = dto.expenseCategoryId?.trim() || null;
      row.expenseItemTitle = dto.expenseItemTitle?.trim() || null;
      row.analyticsOperationName = dto.analyticsOperationName?.trim() || null;
      row.materialPriceKopecks = dto.materialPriceKopecks ?? null;
      row.laborPriceKopecks = dto.laborPriceKopecks ?? null;
      row.placeName = dto.placeName?.trim() || null;
      row.clientUpdatedAt = dto.clientUpdatedAt ? new Date(dto.clientUpdatedAt) : row.clientUpdatedAt;
      row.deviceId = dto.deviceId?.trim() || row.deviceId;
      row.deletedAt = null;
    }
    await this.repo.save(row);
    return row;
  }

  async putByClientId(user: User, carId: string, clientRecordId: string, dto: UpsertManualExpenseDto) {
    await this.cars.assertOwnsCar(user, carId);
    const r = await this.applyUpsertInternal(user.id, carId, clientRecordId, dto);
    return { item: this.toApiItem(r), serverTime: new Date().toISOString() };
  }

  async softDelete(user: User, carId: string, clientRecordId: string) {
    await this.cars.assertOwnsCar(user, carId);
    const cid = clientRecordId.trim().slice(0, 120);
    const row = await this.repo.findOne({ where: { userId: user.id, carId, clientLocalId: cid } });
    const now = new Date();
    if (!row) {
      return { ok: true, item: null, serverTime: now.toISOString() };
    }
    if (!row.deletedAt) {
      row.deletedAt = now;
      await this.repo.save(row);
    }
    return { ok: true, item: this.toApiItem(row), serverTime: new Date().toISOString() };
  }

  private async softDeleteInternal(userId: string, carId: string, clientRecordId: string): Promise<void> {
    const cid = clientRecordId.trim().slice(0, 120);
    const row = await this.repo.findOne({ where: { userId, carId, clientLocalId: cid } });
    if (!row || row.deletedAt) return;
    row.deletedAt = new Date();
    await this.repo.save(row);
  }

  async bulkSync(user: User, carId: string, body: SyncManualExpensesDto) {
    await this.cars.assertOwnsCar(user, carId);
    const changes = body.changes ?? { upserts: [], deletes: [] };
    const upserts = Array.isArray(changes.upserts) ? changes.upserts : [];
    const deletes = Array.isArray(changes.deletes) ? changes.deletes : [];
    for (const u of upserts) {
      const idRaw = u.clientRecordId;
      if (!idRaw || !String(idRaw).trim()) continue;
      await this.applyUpsertInternal(user.id, carId, idRaw, u);
    }
    for (const d of deletes) {
      await this.softDeleteInternal(user.id, carId, d.clientRecordId);
    }
    const since = body.lastPulledAt ? new Date(body.lastPulledAt) : new Date(0);
    const rows = await this.repo
      .createQueryBuilder('e')
      .where('e.user_id = :uid AND e.car_id = :cid', { uid: user.id, cid: carId })
      .andWhere('e.updated_at > :since', { since })
      .orderBy('e.updated_at', 'ASC')
      .addOrderBy('e.id', 'ASC')
      .getMany();
    return {
      serverTime: new Date().toISOString(),
      items: rows.map((r) => this.toApiItem(r)),
      conflicts: [] as unknown[],
      nextCursor: null as string | null,
    };
  }
}
