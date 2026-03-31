import { Injectable, OnApplicationBootstrap } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Organization } from '../organizations/organization.entity';
import { StaffMember } from '../organizations/staff-member.entity';
import { MasterSchedule } from '../organizations/master-schedule.entity';
import { OrganizationSettings } from '../organizations/organization-settings.entity';
import { User } from '../users/user.entity';
import { Order } from '../orders/order.entity';
import { OrderItem } from '../orders/order-item.entity';
import { Chat } from '../chats/chat.entity';
import { ChatMessage } from '../chats/chat-message.entity';
import { CarBrand } from '../reference/car-brand.entity';
import { CarModel } from '../reference/car-model.entity';
import { CarGeneration } from '../reference/car-generation.entity';
import { CAR_BRANDS_AND_MODELS } from '../reference/car-brands.seed';
import { CAR_GENERATIONS_SEED } from '../reference/car-generations.seed';

const TEST_ORG_NAME = 'Тестовый автосервис';
const AUTO_MR_ORG_NAME = 'Авто МР';

/** Номера для ролей (сотрудники СТО) и клиентов. */
const STAFF_PHONES = [
  { phone: '79001111111', role: 'owner' as const, name: 'Иван (владелец)' },
  { phone: '79002222222', role: 'admin' as const, name: 'Мария (админ)' },
  { phone: '79003333333', role: 'master' as const, name: 'Алексей (мастер)' },
  { phone: '79004444444', role: 'solo' as const, name: 'Сергей (самозанятый)' },
  { phone: '79197341904', role: 'owner' as const, name: 'Владелец' },
];

/** Владелец и администратор для СТО «Авто МР». */
const AUTO_MR_OWNER_ADMIN = [
  { phone: '79009999991', role: 'owner' as const, name: 'Владелец Авто МР' },
  { phone: '79009999992', role: 'admin' as const, name: 'Админ Авто МР' },
];
/** Мастера для второго СТО «Авто МР». */
const AUTO_MR_MASTERS = [
  { phone: '79007777777', name: 'Виктор' },
  { phone: '79008888888', name: 'Дмитрий' },
];
const CLIENT_PHONES = [
  { phone: '79005555555', name: 'Пётр Клиентов' },
  { phone: '79006666666', name: 'Анна Смирнова' },
];

@Injectable()
export class SeedService implements OnApplicationBootstrap {
  constructor(
    @InjectRepository(Organization) private orgRepo: Repository<Organization>,
    @InjectRepository(StaffMember) private staffRepo: Repository<StaffMember>,
    @InjectRepository(MasterSchedule) private scheduleRepo: Repository<MasterSchedule>,
    @InjectRepository(OrganizationSettings) private settingsRepo: Repository<OrganizationSettings>,
    @InjectRepository(User) private userRepo: Repository<User>,
    @InjectRepository(Order) private orderRepo: Repository<Order>,
    @InjectRepository(OrderItem) private itemRepo: Repository<OrderItem>,
    @InjectRepository(Chat) private chatRepo: Repository<Chat>,
    @InjectRepository(ChatMessage) private messageRepo: Repository<ChatMessage>,
    @InjectRepository(CarBrand) private brandRepo: Repository<CarBrand>,
    @InjectRepository(CarModel) private modelRepo: Repository<CarModel>,
    @InjectRepository(CarGeneration) private generationRepo: Repository<CarGeneration>,
  ) {}

  async onApplicationBootstrap() {
    if (process.env.NODE_ENV === 'production' && !process.env.SEED_DEV) return;
    await this.run();
  }

  async run() {
    await this.seedCarBrandsAndModels();
    await this.seedCarGenerations();

    const ORG_LAT = 45.039267;
    const ORG_LNG = 38.987221;
    let org = await this.orgRepo.findOne({ where: { name: TEST_ORG_NAME } });
    if (!org) {
      org = this.orgRepo.create({
        name: TEST_ORG_NAME,
        address: 'г. Краснодар, ул. Красная, д. 100',
        phone: '+7 900 000-00-00',
        workingHours: 'Пн–Пт 9:00–19:00, Сб 10:00–16:00',
        latitude: ORG_LAT,
        longitude: ORG_LNG,
      });
      await this.orgRepo.save(org);
      console.log('[Seed] Создана организация:', org.name);
    } else if ((org as any).latitude == null || (org as any).longitude == null) {
      await this.orgRepo.update(org.id, { latitude: ORG_LAT, longitude: ORG_LNG });
      (org as any).latitude = ORG_LAT;
      (org as any).longitude = ORG_LNG;
    }

    const existingStaff = await this.staffRepo.count({ where: { organizationId: org.id } });
    if (existingStaff === 0) {
      for (const s of STAFF_PHONES) {
        const member = this.staffRepo.create({
          organizationId: org.id,
          name: s.name,
          phone: s.phone,
          role: s.role,
          isActive: true,
          invitedAt: new Date(),
          skills: s.role === 'master' ? ['MAINTENANCE', 'DIAGNOSTICS'] : [],
        });
        await this.staffRepo.save(member);
        if (s.role === 'master') {
          for (let day = 1; day <= 5; day++) {
            await this.scheduleRepo.save(
              this.scheduleRepo.create({
                masterId: member.id,
                dayOfWeek: day,
                startTime: '09:00',
                endTime: '18:00',
                isWorkingDay: true,
              }),
            );
          }
          console.log('[Seed] График мастера', member.name);
        }
      }
      console.log('[Seed] Добавлены сотрудники в Персонал:', STAFF_PHONES.length);
    }

    for (const s of STAFF_PHONES) {
      let user = await this.userRepo.findOne({ where: { phone: s.phone } });
      if (!user) {
        user = this.userRepo.create({
          phone: s.phone,
          name: s.name,
          role: s.role,
          organizationId: org.id,
        });
        await this.userRepo.save(user);
      } else {
        user.organizationId = org.id;
        user.role = s.role;
        user.name = s.name;
        await this.userRepo.save(user);
      }
    }

    for (const c of CLIENT_PHONES) {
      let user = await this.userRepo.findOne({ where: { phone: c.phone } });
      if (!user) {
        user = this.userRepo.create({
          phone: c.phone,
          name: c.name,
          role: 'solo',
          organizationId: null,
        });
        await this.userRepo.save(user);
      } else {
        user.name = c.name;
        await this.userRepo.save(user);
      }
    }
    console.log('[Seed] Пользователи (роли + клиенты) созданы/обновлены');

    const categories = [
      { id: 'cat_1', name: 'ТО и ремонт', order: 0 },
      { id: 'cat_2', name: 'Шины и колёса', order: 1 },
      { id: 'cat_3', name: 'Кузовной ремонт', order: 2 },
      { id: 'cat_4', name: 'Электрика и диагностика', order: 3 },
    ];
    const services = [
      { id: 's1', category_id: 'cat_1', name: 'Замена масла', price_kopecks: 350000, duration_minutes: 60, required_skill: 'MAINTENANCE' },
      { id: 's2', category_id: 'cat_1', name: 'Замена масляного фильтра', price_kopecks: 50000, duration_minutes: 15, required_skill: 'MAINTENANCE' },
      { id: 's3', category_id: 'cat_1', name: 'Диагностика подвески', price_kopecks: 150000, duration_minutes: 45, required_skill: 'SUSPENSION' },
      { id: 's4', category_id: 'cat_1', name: 'Замена тормозных колодок', price_kopecks: 250000, duration_minutes: 60, required_skill: 'MAINTENANCE' },
      { id: 's5', category_id: 'cat_1', name: 'Замена тормозной жидкости', price_kopecks: 120000, duration_minutes: 30, required_skill: 'MAINTENANCE' },
      { id: 's6', category_id: 'cat_1', name: 'Развал-схождение', price_kopecks: 200000, duration_minutes: 60, required_skill: 'SUSPENSION' },
      { id: 's7', category_id: 'cat_1', name: 'Замена ремня ГРМ', price_kopecks: 450000, duration_minutes: 120, required_skill: 'ENGINE' },
      { id: 's8', category_id: 'cat_1', name: 'Замена свечей зажигания', price_kopecks: 80000, duration_minutes: 30, required_skill: 'ENGINE' },
      { id: 's9', category_id: 'cat_2', name: 'Шиномонтаж (комплект)', price_kopecks: 400000, duration_minutes: 90, required_skill: 'TIRES' },
      { id: 's10', category_id: 'cat_2', name: 'Балансировка колёс', price_kopecks: 150000, duration_minutes: 45, required_skill: 'TIRES' },
      { id: 's11', category_id: 'cat_2', name: 'Хранение шин', price_kopecks: 300000, duration_minutes: 0, required_skill: 'TIRES' },
      { id: 's12', category_id: 'cat_3', name: 'Локальная покраска', price_kopecks: 500000, duration_minutes: 480, required_skill: 'BODY' },
      { id: 's13', category_id: 'cat_3', name: 'Удаление вмятин без покраски', price_kopecks: 350000, duration_minutes: 120, required_skill: 'BODY' },
      { id: 's14', category_id: 'cat_3', name: 'Полировка кузова', price_kopecks: 250000, duration_minutes: 180, required_skill: 'BODY' },
      { id: 's15', category_id: 'cat_4', name: 'Компьютерная диагностика', price_kopecks: 150000, duration_minutes: 45, required_skill: 'DIAGNOSTICS' },
      { id: 's16', category_id: 'cat_4', name: 'Замена АКБ', price_kopecks: 100000, duration_minutes: 30, required_skill: 'ELECTRICAL' },
      { id: 's17', category_id: 'cat_4', name: 'Ремонт генератора', price_kopecks: 300000, duration_minutes: 120, required_skill: 'ELECTRICAL' },
    ];
    /** Услуги для «Авто МР» — другие цены и время, чтобы на карте отличались ценники. */
    const servicesAutoMr = [
      { id: 's1', category_id: 'cat_1', name: 'Замена масла', price_kopecks: 420000, duration_minutes: 45, required_skill: 'MAINTENANCE' },
      { id: 's2', category_id: 'cat_1', name: 'Замена масляного фильтра', price_kopecks: 60000, duration_minutes: 20, required_skill: 'MAINTENANCE' },
      { id: 's3', category_id: 'cat_1', name: 'Диагностика подвески', price_kopecks: 180000, duration_minutes: 50, required_skill: 'SUSPENSION' },
      { id: 's4', category_id: 'cat_1', name: 'Замена тормозных колодок', price_kopecks: 290000, duration_minutes: 70, required_skill: 'MAINTENANCE' },
      { id: 's5', category_id: 'cat_1', name: 'Замена тормозной жидкости', price_kopecks: 140000, duration_minutes: 35, required_skill: 'MAINTENANCE' },
      { id: 's6', category_id: 'cat_1', name: 'Развал-схождение', price_kopecks: 240000, duration_minutes: 70, required_skill: 'SUSPENSION' },
      { id: 's7', category_id: 'cat_1', name: 'Замена ремня ГРМ', price_kopecks: 520000, duration_minutes: 150, required_skill: 'ENGINE' },
      { id: 's8', category_id: 'cat_1', name: 'Замена свечей зажигания', price_kopecks: 95000, duration_minutes: 35, required_skill: 'ENGINE' },
      { id: 's9', category_id: 'cat_2', name: 'Шиномонтаж (комплект)', price_kopecks: 450000, duration_minutes: 100, required_skill: 'TIRES' },
      { id: 's10', category_id: 'cat_2', name: 'Балансировка колёс', price_kopecks: 170000, duration_minutes: 50, required_skill: 'TIRES' },
      { id: 's11', category_id: 'cat_2', name: 'Хранение шин', price_kopecks: 250000, duration_minutes: 0, required_skill: 'TIRES' },
      { id: 's12', category_id: 'cat_3', name: 'Локальная покраска', price_kopecks: 550000, duration_minutes: 500, required_skill: 'BODY' },
      { id: 's13', category_id: 'cat_3', name: 'Удаление вмятин без покраски', price_kopecks: 380000, duration_minutes: 130, required_skill: 'BODY' },
      { id: 's14', category_id: 'cat_3', name: 'Полировка кузова', price_kopecks: 280000, duration_minutes: 200, required_skill: 'BODY' },
      { id: 's15', category_id: 'cat_4', name: 'Компьютерная диагностика', price_kopecks: 120000, duration_minutes: 40, required_skill: 'DIAGNOSTICS' },
      { id: 's16', category_id: 'cat_4', name: 'Замена АКБ', price_kopecks: 80000, duration_minutes: 25, required_skill: 'ELECTRICAL' },
      { id: 's17', category_id: 'cat_4', name: 'Ремонт генератора', price_kopecks: 350000, duration_minutes: 140, required_skill: 'ELECTRICAL' },
    ];
    const settingsData = {
      categories,
      services,
      car_brands: [] as string[],
      slots: { slot_duration_minutes: 60, confirmation_timeout_minutes: 120 },
      notifications: { new_order: true, new_message: true, approval_response: true, order_reminder: false },
      message_templates: [{ id: 't1', title: 'Подтверждение', body: 'Здравствуйте! Ваш заказ подтверждён.' }],
    };

    let settings = await this.settingsRepo.findOne({ where: { organizationId: org.id } });
    if (!settings) {
      settings = this.settingsRepo.create({
        organizationId: org.id,
        data: settingsData,
      });
      await this.settingsRepo.save(settings);
      console.log('[Seed] Созданы настройки организации с', services.length, 'услугами');
    } else {
      await this.settingsRepo.update(settings.id, { data: settingsData });
      console.log('[Seed] Обновлены настройки организации:', services.length, 'услуг');
    }

    // Второе СТО «Авто МР» — рядом на карте (2 мастера)
    const AUTO_MR_LAT = 45.0412;
    const AUTO_MR_LNG = 38.9895;
    let orgMr = await this.orgRepo.findOne({ where: { name: AUTO_MR_ORG_NAME } });
    if (!orgMr) {
      orgMr = this.orgRepo.create({
        name: AUTO_MR_ORG_NAME,
        address: 'г. Краснодар, ул. Красная, д. 108',
        phone: '+7 900 777-77-77',
        workingHours: 'Пн–Пт 8:00–20:00, Сб 9:00–17:00',
        latitude: AUTO_MR_LAT,
        longitude: AUTO_MR_LNG,
      });
      await this.orgRepo.save(orgMr);
      console.log('[Seed] Создана организация:', orgMr.name);
    } else if ((orgMr as any).latitude == null || (orgMr as any).longitude == null) {
      await this.orgRepo.update(orgMr.id, { latitude: AUTO_MR_LAT, longitude: AUTO_MR_LNG });
      (orgMr as any).latitude = AUTO_MR_LAT;
      (orgMr as any).longitude = AUTO_MR_LNG;
    }
    const existingStaffMr = await this.staffRepo.count({ where: { organizationId: orgMr.id } });
    if (existingStaffMr === 0) {
      for (const s of AUTO_MR_OWNER_ADMIN) {
        const member = this.staffRepo.create({
          organizationId: orgMr.id,
          name: s.name,
          phone: s.phone,
          role: s.role,
          isActive: true,
          invitedAt: new Date(),
          skills: [],
        });
        await this.staffRepo.save(member);
        console.log('[Seed] Сотрудник Авто МР:', member.name, `(${s.role})`);
      }
      for (const m of AUTO_MR_MASTERS) {
        const member = this.staffRepo.create({
          organizationId: orgMr.id,
          name: m.name,
          phone: m.phone,
          role: 'master',
          isActive: true,
          invitedAt: new Date(),
          skills: ['MAINTENANCE', 'DIAGNOSTICS'],
        });
        await this.staffRepo.save(member);
        for (let day = 1; day <= 5; day++) {
          await this.scheduleRepo.save(
            this.scheduleRepo.create({
              masterId: member.id,
              dayOfWeek: day,
              startTime: '09:00',
              endTime: '18:00',
              isWorkingDay: true,
            }),
          );
        }
        console.log('[Seed] График мастера', member.name, '(Авто МР)');
      }
      console.log('[Seed] Добавлены владелец, админ и мастера в Авто МР');
    }
    const settingsDataMr = {
      ...settingsData,
      services: servicesAutoMr,
    };
    let settingsMr = await this.settingsRepo.findOne({ where: { organizationId: orgMr.id } });
    if (!settingsMr) {
      settingsMr = this.settingsRepo.create({
        organizationId: orgMr.id,
        data: settingsDataMr,
      });
      await this.settingsRepo.save(settingsMr);
      console.log('[Seed] Настройки Авто МР созданы (отдельные цены/время)');
    } else {
      await this.settingsRepo.update(settingsMr.id, { data: settingsDataMr });
    }
    for (const s of AUTO_MR_OWNER_ADMIN) {
      let userMr = await this.userRepo.findOne({ where: { phone: s.phone } });
      if (!userMr) {
        userMr = this.userRepo.create({
          phone: s.phone,
          name: s.name,
          role: s.role,
          organizationId: orgMr.id,
        });
        await this.userRepo.save(userMr);
      } else {
        userMr.organizationId = orgMr.id;
        userMr.role = s.role;
        userMr.name = s.name;
        await this.userRepo.save(userMr);
      }
    }
    for (const m of AUTO_MR_MASTERS) {
      let userMr = await this.userRepo.findOne({ where: { phone: m.phone } });
      if (!userMr) {
        userMr = this.userRepo.create({
          phone: m.phone,
          name: m.name,
          role: 'master',
          organizationId: orgMr.id,
        });
        await this.userRepo.save(userMr);
      } else {
        userMr.organizationId = orgMr.id;
        userMr.role = 'master';
        userMr.name = m.name;
        await this.userRepo.save(userMr);
      }
    }

    const orderCount = await this.orderRepo.count({ where: { organizationId: org.id } });
    if (orderCount === 0 && CLIENT_PHONES.length >= 2) {
      const masterStaff = await this.staffRepo.findOne({
        where: { organizationId: org.id, phone: '79003333333' },
      });
      const masterId = masterStaff?.id ?? null;

      for (let i = 0; i < CLIENT_PHONES.length; i++) {
        const client = CLIENT_PHONES[i];
        const orderNumber = `#2025-${String(i + 1).padStart(3, '0')}`;
        const dateTime = new Date();
        dateTime.setDate(dateTime.getDate() - (i === 0 ? 2 : 1));
        dateTime.setHours(10 + i, 0, 0, 0);

        const order = this.orderRepo.create({
          organizationId: org.id,
          orderNumber,
          carId: 'car_' + client.phone,
          carInfo: i === 0 ? 'Toyota Camry, 2020' : 'Hyundai Solaris, 2019',
          clientName: client.name,
          clientPhone: client.phone,
          status: i === 0 ? 'done' : 'pending_confirmation',
          dateTime,
          comment: i === 0 ? 'Проверить тормоза' : null,
          masterId: i === 0 ? masterId : null,
        });
        await this.orderRepo.save(order);

        const item1 = this.itemRepo.create({
          orderId: order.id,
          name: i === 0 ? 'Замена масла' : 'Диагностика',
          priceKopecks: 350000,
          estimatedMinutes: 60,
          isCompleted: i === 0,
          isAdditional: false,
        });
        await this.itemRepo.save(item1);
        const item2 = this.itemRepo.create({
          orderId: order.id,
          name: 'Осмотр ходовой',
          priceKopecks: 50000,
          estimatedMinutes: 30,
          isCompleted: false,
          isAdditional: false,
        });
        await this.itemRepo.save(item2);

        // Один чат на пару (organizationId, clientPhone) — как в getOrCreateForClient
        const phoneNorm = client.phone.replace(/\D/g, '');
        let chat = await this.chatRepo.findOne({
          where: { organizationId: org.id, clientPhone: phoneNorm },
        });
        if (!chat) {
          chat = this.chatRepo.create({ organizationId: org.id, clientPhone: phoneNorm });
          await this.chatRepo.save(chat);
        }

        const msg1 = this.messageRepo.create({
          chatId: chat.id,
          text: 'Добрый день! Ваш заказ подтверждён.',
          isFromClient: false,
          at: new Date(dateTime.getTime() + 3600000),
        });
        await this.messageRepo.save(msg1);
        const msg2 = this.messageRepo.create({
          chatId: chat.id,
          text: i === 0 ? 'Спасибо, жду к 10:00.' : 'Когда можно приехать?',
          isFromClient: true,
          at: new Date(dateTime.getTime() + 7200000),
        });
        await this.messageRepo.save(msg2);
      }
      console.log('[Seed] Созданы заказы и чаты для 2 клиентов');
    }

    console.log('[Seed] Готово.');
  }

  private async seedCarBrandsAndModels() {
    const count = await this.brandRepo.count();
    if (count > 0) return;
    for (let i = 0; i < CAR_BRANDS_AND_MODELS.length; i++) {
      const { name, models } = CAR_BRANDS_AND_MODELS[i];
      const brand = this.brandRepo.create({ name, sortOrder: i });
      await this.brandRepo.save(brand);
      for (let j = 0; j < models.length; j++) {
        const model = this.modelRepo.create({
          brandId: brand.id,
          name: models[j],
          sortOrder: j,
        });
        await this.modelRepo.save(model);
      }
    }
    console.log('[Seed] Справочник марок и моделей: загружено', CAR_BRANDS_AND_MODELS.length, 'марок');
  }

  private async seedCarGenerations() {
    const count = await this.generationRepo.count();
    if (count > 0) return;
    let inserted = 0;
    for (const entry of CAR_GENERATIONS_SEED) {
      const brand = await this.brandRepo.findOne({ where: { name: entry.brandName } });
      if (!brand) continue;
      const model = await this.modelRepo.findOne({ where: { brandId: brand.id, name: entry.modelName } });
      if (!model) continue;
      for (let k = 0; k < entry.generations.length; k++) {
        const g = entry.generations[k];
        const gen = this.generationRepo.create({
          modelId: model.id,
          name: g.name,
          yearFrom: g.yearFrom ?? null,
          yearTo: g.yearTo ?? null,
          sortOrder: k,
        });
        await this.generationRepo.save(gen);
        inserted++;
      }
    }
    console.log('[Seed] Справочник поколений: загружено', inserted, 'поколений');
  }
}
