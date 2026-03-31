import { BadRequestException, Injectable, NotFoundException, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { randomUUID } from 'crypto';
import { Repository } from 'typeorm';
import { ServiceCatalogItem } from './service-catalog-item.entity';
import { ServiceCatalogSuggestion } from './service-catalog-suggestion.entity';
import { SERVICE_CATALOG_SEED } from './service-catalog.seed';
import {
  catalogAllowedKindsForCategoryKey,
  SERVICE_CATALOG_CATEGORY_SORT_ORDER,
} from './service-catalog-metadata';
import { Organization } from '../organizations/organization.entity';
import { normalizeOrganizationBusinessKind } from '../organizations/organization-business-kind';

export { catalogAllowedKindsForCategoryKey } from './service-catalog-metadata';

function slugCategoryKey(raw: string): string {
  const s = raw
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9_]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 64);
  if (!s) throw new BadRequestException('Укажите латинский ключ категории (a-z, цифры, _)');
  return s;
}

@Injectable()
export class ServiceCatalogService implements OnModuleInit {
  constructor(
    @InjectRepository(ServiceCatalogItem) private itemRepo: Repository<ServiceCatalogItem>,
    @InjectRepository(ServiceCatalogSuggestion) private suggestRepo: Repository<ServiceCatalogSuggestion>,
    @InjectRepository(Organization) private orgRepo: Repository<Organization>,
  ) {}

  async onModuleInit() {
    await this.seedIfEmpty();
  }

  async seedIfEmpty() {
    const n = await this.itemRepo.count();
    if (n > 0) return;
    for (const row of SERVICE_CATALOG_SEED) {
      const e = this.itemRepo.create({
        id: row.id,
        categoryKey: row.categoryKey,
        categoryName: row.categoryName,
        categorySortOrder: SERVICE_CATALOG_CATEGORY_SORT_ORDER[row.categoryKey] ?? 1000,
        name: row.name,
        defaultDurationMinutes: row.defaultDurationMinutes,
        sortOrder: row.sortOrder,
        requiredSkill: row.requiredSkill ?? null,
        allowedBusinessKinds: catalogAllowedKindsForCategoryKey(row.categoryKey),
      });
      await this.itemRepo.save(e);
    }
    console.log('[ServiceCatalog] Seeded', SERVICE_CATALOG_SEED.length, 'items');
  }

  private filterCatalogItemsByBusinessKind(items: ServiceCatalogItem[], kindRaw: string): ServiceCatalogItem[] {
    const kind = normalizeOrganizationBusinessKind(kindRaw);
    return items.filter((it) => {
      const allowed = Array.isArray(it.allowedBusinessKinds) ? it.allowedBusinessKinds : ['sto'];
      return allowed.includes(kind);
    });
  }

  /**
   * Сгруппированный справочник услуг.
   * @param organizationId если задан — фильтр по business_kind этой организации
   * @param businessKindFilter если задан и organizationId нет — фильтр по коду вида бизнеса (для клиентского каталога)
   */
  async getCatalogGrouped(organizationId?: string | null, businessKindFilter?: string | null) {
    /** Повторная попытка сида: если миграции применили после старта API, таблица могла остаться пустой. */
    await this.seedIfEmpty();
    let items = await this.itemRepo.find({
      order: { categorySortOrder: 'ASC', categoryKey: 'ASC', sortOrder: 'ASC', id: 'ASC' },
    });
    if (organizationId) {
      const org = await this.orgRepo.findOne({ where: { id: organizationId } });
      if (org) {
        items = this.filterCatalogItemsByBusinessKind(items, (org as any).businessKind ?? 'sto');
      }
    } else if (businessKindFilter != null && String(businessKindFilter).trim() !== '') {
      items = this.filterCatalogItemsByBusinessKind(items, businessKindFilter);
    }
    const byKey = new Map<
      string,
      {
        category_key: string;
        category_name: string;
        category_sort_order: number;
        items: unknown[];
      }
    >();
    for (const it of items) {
      let g = byKey.get(it.categoryKey);
      if (!g) {
        g = {
          category_key: it.categoryKey,
          category_name: it.categoryName,
          category_sort_order: it.categorySortOrder,
          items: [],
        };
        byKey.set(it.categoryKey, g);
      }
      g.items.push({
        id: it.id,
        name: it.name,
        default_duration_minutes: it.defaultDurationMinutes,
        required_skill: it.requiredSkill,
        sort_order: it.sortOrder,
        allowed_business_kinds: Array.isArray(it.allowedBusinessKinds) ? it.allowedBusinessKinds : ['sto'],
      });
    }
    return { categories: Array.from(byKey.values()) };
  }

  private async nextCategorySortOrder(): Promise<number> {
    const r = await this.itemRepo
      .createQueryBuilder('i')
      .select('MAX(i.categorySortOrder)', 'm')
      .getRawOne<{ m: string | null }>();
    const n = parseInt(r?.m ?? '0', 10) || 0;
    return n + 10;
  }

  private async nextItemSortOrder(categoryKey: string): Promise<number> {
    const r = await this.itemRepo
      .createQueryBuilder('i')
      .select('MAX(i.sortOrder)', 'm')
      .where('i.categoryKey = :k', { k: categoryKey })
      .getRawOne<{ m: string | null }>();
    const n = parseInt(r?.m ?? '0', 10) || 0;
    return n + 10;
  }

  async createCatalogCategoryAdmin(dto: {
    category_key: string;
    category_name: string;
    first_service_name?: string;
  }) {
    const categoryKey = slugCategoryKey(dto.category_key);
    const categoryName = (dto.category_name ?? '').trim();
    if (!categoryName) throw new BadRequestException('Укажите название категории');
    const exists = await this.itemRepo.findOne({ where: { categoryKey } });
    if (exists) throw new BadRequestException('Категория с таким ключом уже есть');
    const categorySortOrder = await this.nextCategorySortOrder();
    const name = (dto.first_service_name ?? '').trim() || 'Новая услуга';
    const id = `svc_${randomUUID().replace(/-/g, '')}`.slice(0, 96);
    const row = this.itemRepo.create({
      id,
      categoryKey,
      categoryName,
      categorySortOrder,
      name,
      defaultDurationMinutes: 60,
      sortOrder: 10,
      requiredSkill: null,
      allowedBusinessKinds: catalogAllowedKindsForCategoryKey(categoryKey),
    });
    await this.itemRepo.save(row);
    return this.getCatalogGrouped();
  }

  async createCatalogItemAdmin(dto: {
    id?: string;
    category_key: string;
    category_name: string;
    name: string;
    default_duration_minutes?: number;
    sort_order?: number;
    required_skill?: string | null;
  }) {
    const categoryKey = slugCategoryKey(dto.category_key);
    const categoryName = (dto.category_name ?? '').trim();
    const name = (dto.name ?? '').trim();
    if (!categoryName || !name) throw new BadRequestException('Укажите название категории и услуги');
    const sibling = await this.itemRepo.findOne({ where: { categoryKey } });
    const categorySortOrder = sibling?.categorySortOrder ?? (await this.nextCategorySortOrder());
    let sortOrder = dto.sort_order;
    if (sortOrder == null || Number.isNaN(sortOrder)) {
      sortOrder = await this.nextItemSortOrder(categoryKey);
    }
    const id = (dto.id?.trim() || `svc_${randomUUID().replace(/-/g, '')}`).slice(0, 96);
    const dup = await this.itemRepo.findOne({ where: { id } });
    if (dup) throw new BadRequestException('Позиция с таким id уже существует');
    const dur = dto.default_duration_minutes;
    const defaultDurationMinutes =
      dur != null && dur > 0 && dur <= 24 * 60 ? Math.floor(dur) : 60;
    const row = this.itemRepo.create({
      id,
      categoryKey,
      categoryName,
      categorySortOrder,
      name,
      defaultDurationMinutes,
      sortOrder,
      requiredSkill: dto.required_skill?.trim() || null,
      allowedBusinessKinds: catalogAllowedKindsForCategoryKey(categoryKey),
    });
    await this.itemRepo.save(row);
    return this.getCatalogGrouped();
  }

  async updateCatalogItemAdmin(
    id: string,
    dto: {
      name?: string;
      default_duration_minutes?: number;
      required_skill?: string | null;
      sort_order?: number;
      category_key?: string;
      category_name?: string;
    },
  ) {
    const row = await this.itemRepo.findOne({ where: { id } });
    if (!row) throw new NotFoundException('Позиция не найдена');
    if (dto.name !== undefined) {
      const t = dto.name.trim();
      if (!t) throw new BadRequestException('Название не может быть пустым');
      row.name = t;
    }
    if (dto.default_duration_minutes !== undefined) {
      const d = dto.default_duration_minutes;
      if (d <= 0 || d > 24 * 60) throw new BadRequestException('Длительность: 1–1440 минут');
      row.defaultDurationMinutes = Math.floor(d);
    }
    if (dto.required_skill !== undefined) {
      row.requiredSkill = dto.required_skill?.trim() || null;
    }
    if (dto.sort_order !== undefined) {
      if (Number.isNaN(dto.sort_order)) throw new BadRequestException('sort_order');
      row.sortOrder = Math.floor(dto.sort_order);
    }
    if (dto.category_key !== undefined) {
      const newKey = slugCategoryKey(dto.category_key);
      if (newKey !== row.categoryKey) {
        const target = await this.itemRepo.findOne({ where: { categoryKey: newKey } });
        if (!target) throw new BadRequestException('Целевая категория не найдена. Сначала создайте категорию.');
        row.categoryKey = newKey;
        row.categoryName = target.categoryName;
        row.categorySortOrder = target.categorySortOrder;
        row.sortOrder = await this.nextItemSortOrder(newKey);
      }
    }
    await this.itemRepo.save(row);
    return this.getCatalogGrouped();
  }

  async deleteCatalogItemAdmin(id: string) {
    const row = await this.itemRepo.findOne({ where: { id } });
    if (!row) throw new NotFoundException('Позиция не найдена');
    await this.itemRepo.delete({ id });
    return this.getCatalogGrouped();
  }

  async deleteCatalogCategoryAdmin(categoryKeyRaw: string) {
    const categoryKey = slugCategoryKey(categoryKeyRaw);
    const n = await this.itemRepo.count({ where: { categoryKey } });
    if (n === 0) throw new NotFoundException('Категория не найдена');
    await this.itemRepo.delete({ categoryKey });
    return this.getCatalogGrouped();
  }

  async patchCatalogCategoryAdmin(
    categoryKeyRaw: string,
    dto: { category_name?: string; new_category_key?: string },
  ) {
    const categoryKey = slugCategoryKey(categoryKeyRaw);
    const rows = await this.itemRepo.find({ where: { categoryKey } });
    if (rows.length === 0) throw new NotFoundException('Категория не найдена');
    let nextKey = categoryKey;
    if (dto.new_category_key !== undefined && dto.new_category_key.trim()) {
      nextKey = slugCategoryKey(dto.new_category_key);
      if (nextKey !== categoryKey) {
        const clash = await this.itemRepo.findOne({ where: { categoryKey: nextKey } });
        if (clash) throw new BadRequestException('Ключ категории уже занят');
      }
    }
    const nextName =
      dto.category_name !== undefined ? dto.category_name.trim() : rows[0].categoryName;
    if (!nextName) throw new BadRequestException('Название категории');
    const cso = rows[0].categorySortOrder;
    await this.itemRepo.update(
      { categoryKey },
      { categoryKey: nextKey, categoryName: nextName, categorySortOrder: cso },
    );
    return this.getCatalogGrouped();
  }

  async reorderCatalogCategoryAdmin(categoryKeyRaw: string, delta: number) {
    if (delta !== 1 && delta !== -1) throw new BadRequestException('delta: 1 или -1');
    const categoryKey = slugCategoryKey(categoryKeyRaw);
    const meta = await this.itemRepo
      .createQueryBuilder('i')
      .select('i.categoryKey', 'categoryKey')
      .addSelect('MIN(i.categorySortOrder)', 'cso')
      .groupBy('i.categoryKey')
      .orderBy('MIN(i.categorySortOrder)', 'ASC')
      .addOrderBy('i.categoryKey', 'ASC')
      .getRawMany<{ categoryKey: string; cso: string }>();
    const keys = meta.map((m) => m.categoryKey);
    const idx = keys.indexOf(categoryKey);
    if (idx < 0) throw new NotFoundException('Категория не найдена');
    const j = idx + delta;
    if (j < 0 || j >= keys.length) return this.getCatalogGrouped();
    const keyA = keys[idx];
    const keyB = keys[j];
    const sortA = parseInt(meta[idx].cso, 10) || 0;
    const sortB = parseInt(meta[j].cso, 10) || 0;
    await this.itemRepo.manager.transaction(async (em) => {
      await em.update(ServiceCatalogItem, { categoryKey: keyA }, { categorySortOrder: sortB });
      await em.update(ServiceCatalogItem, { categoryKey: keyB }, { categorySortOrder: sortA });
    });
    return this.getCatalogGrouped();
  }

  async reorderCatalogItemAdmin(itemId: string, delta: number) {
    if (delta !== 1 && delta !== -1) throw new BadRequestException('delta: 1 или -1');
    const row = await this.itemRepo.findOne({ where: { id: itemId } });
    if (!row) throw new NotFoundException('Позиция не найдена');
    const siblings = await this.itemRepo.find({
      where: { categoryKey: row.categoryKey },
      order: { sortOrder: 'ASC', id: 'ASC' },
    });
    const idx = siblings.findIndex((s) => s.id === itemId);
    if (idx < 0) throw new NotFoundException();
    const j = idx + delta;
    if (j < 0 || j >= siblings.length) return this.getCatalogGrouped();
    const a = siblings[idx];
    const b = siblings[j];
    const soA = a.sortOrder;
    const soB = b.sortOrder;
    await this.itemRepo.manager.transaction(async (em) => {
      await em.update(ServiceCatalogItem, { id: a.id }, { sortOrder: soB });
      await em.update(ServiceCatalogItem, { id: b.id }, { sortOrder: soA });
    });
    return this.getCatalogGrouped();
  }

  async createSuggestion(
    organizationId: string,
    dto: { requested_name: string; category_hint?: string; note?: string },
  ) {
    const name = (dto.requested_name ?? '').trim();
    if (!name) throw new BadRequestException('Укажите название услуги');
    const row = this.suggestRepo.create({
      organizationId,
      requestedName: name,
      categoryHint: dto.category_hint?.trim() || null,
      note: dto.note?.trim() || null,
      status: 'pending',
    });
    await this.suggestRepo.save(row);
    return {
      id: row.id,
      status: row.status,
      message: 'Запрос отправлен разработчикам AutoHub. Услугу добавят в справочник после проверки.',
    };
  }

  async getSuggestionStats() {
    const raw = await this.suggestRepo
      .createQueryBuilder('s')
      .select('s.status', 'status')
      .addSelect('COUNT(*)', 'cnt')
      .groupBy('s.status')
      .getRawMany<{ status: string; cnt: string }>();
    let pending = 0;
    let reviewed = 0;
    for (const r of raw) {
      const n = parseInt(r.cnt, 10) || 0;
      if (r.status === 'pending') pending = n;
      if (r.status === 'reviewed') reviewed = n;
    }
    const total = await this.suggestRepo.count();
    return { pending, reviewed, total };
  }

  async listSuggestionsAdmin(params: {
    status?: string;
    page?: number;
    limit?: number;
    q?: string;
  }) {
    const page = Math.max(1, params.page ?? 1);
    const limit = Math.min(100, Math.max(1, params.limit ?? 24));
    const qb = this.suggestRepo
      .createQueryBuilder('s')
      .leftJoinAndSelect('s.organization', 'o')
      .orderBy('s.createdAt', 'DESC');
    const st = params.status?.trim().toLowerCase();
    if (st && st !== 'all') {
      if (st !== 'pending' && st !== 'reviewed') {
        throw new BadRequestException('status: ожидается pending, reviewed или all');
      }
      qb.andWhere('s.status = :status', { status: st });
    }
    const q = params.q?.trim();
    if (q) {
      const like = `%${q.toLowerCase()}%`;
      qb.andWhere(
        '(LOWER(s.requestedName) LIKE :like OR LOWER(s.categoryHint) LIKE :like OR LOWER(o.name) LIKE :like OR LOWER(s.note) LIKE :like)',
        { like },
      );
    }
    const skip = (page - 1) * limit;
    qb.skip(skip).take(limit);
    const [rows, total] = await qb.getManyAndCount();
    const items = rows.map((s) => ({
      id: s.id,
      organization_id: s.organizationId,
      organization_name: s.organization?.name ?? '—',
      requested_name: s.requestedName,
      category_hint: s.categoryHint,
      note: s.note,
      status: s.status,
      created_at: s.createdAt?.toISOString() ?? null,
      reviewed_at: s.reviewedAt?.toISOString() ?? null,
      review_note: s.reviewNote,
    }));
    return { items, total, page, limit, pages: Math.max(1, Math.ceil(total / limit)) };
  }

  async updateSuggestionAdmin(
    id: string,
    dto: { status: string; review_note?: string | null },
  ) {
    const row = await this.suggestRepo.findOne({ where: { id } });
    if (!row) throw new NotFoundException('Заявка не найдена');
    const next = dto.status.trim().toLowerCase();
    if (next !== 'pending' && next !== 'reviewed') {
      throw new BadRequestException('status: pending или reviewed');
    }
    row.status = next;
    if (dto.review_note !== undefined) {
      const t = dto.review_note?.trim();
      row.reviewNote = t && t.length > 0 ? t : null;
    }
    if (next === 'reviewed') {
      if (!row.reviewedAt) row.reviewedAt = new Date();
    } else {
      row.reviewedAt = null;
    }
    await this.suggestRepo.save(row);
    const withOrg = await this.suggestRepo.findOne({
      where: { id },
      relations: ['organization'],
    });
    if (!withOrg) throw new NotFoundException();
    return {
      id: withOrg.id,
      organization_id: withOrg.organizationId,
      organization_name: withOrg.organization?.name ?? '—',
      requested_name: withOrg.requestedName,
      category_hint: withOrg.categoryHint,
      note: withOrg.note,
      status: withOrg.status,
      created_at: withOrg.createdAt?.toISOString() ?? null,
      reviewed_at: withOrg.reviewedAt?.toISOString() ?? null,
      review_note: withOrg.reviewNote,
    };
  }
}
