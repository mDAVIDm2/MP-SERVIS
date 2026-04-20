"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SeedService = void 0;
const common_1 = require("@nestjs/common");
const typeorm_1 = require("@nestjs/typeorm");
const typeorm_2 = require("typeorm");
const organization_entity_1 = require("../organizations/organization.entity");
const staff_member_entity_1 = require("../organizations/staff-member.entity");
const master_schedule_entity_1 = require("../organizations/master-schedule.entity");
const organization_settings_entity_1 = require("../organizations/organization-settings.entity");
const user_entity_1 = require("../users/user.entity");
const order_entity_1 = require("../orders/order.entity");
const order_item_entity_1 = require("../orders/order-item.entity");
const chat_entity_1 = require("../chats/chat.entity");
const chat_message_entity_1 = require("../chats/chat-message.entity");
const car_brand_entity_1 = require("../reference/car-brand.entity");
const car_model_entity_1 = require("../reference/car-model.entity");
const car_generation_entity_1 = require("../reference/car-generation.entity");
const car_brands_seed_1 = require("../reference/car-brands.seed");
const car_generations_seed_1 = require("../reference/car-generations.seed");
const TEST_ORG_NAME = 'Тестовый автосервис';
const AUTO_MR_ORG_NAME = 'Авто МР';
const STAFF_PHONES = [
    { phone: '79001111111', role: 'owner', name: 'Иван (владелец)' },
    { phone: '79002222222', role: 'admin', name: 'Мария (админ)' },
    { phone: '79003333333', role: 'master', name: 'Алексей (мастер)' },
    { phone: '79004444444', role: 'solo', name: 'Сергей (самозанятый)' },
    { phone: '79197341904', role: 'owner', name: 'Владелец' },
];
const AUTO_MR_OWNER_ADMIN = [
    { phone: '79009999991', role: 'owner', name: 'Владелец Авто МР' },
    { phone: '79009999992', role: 'admin', name: 'Админ Авто МР' },
];
const AUTO_MR_MASTERS = [
    { phone: '79007777777', name: 'Виктор' },
    { phone: '79008888888', name: 'Дмитрий' },
];
const CLIENT_PHONES = [
    { phone: '79005555555', name: 'Пётр Клиентов' },
    { phone: '79006666666', name: 'Анна Смирнова' },
];
let SeedService = class SeedService {
    constructor(orgRepo, staffRepo, scheduleRepo, settingsRepo, userRepo, orderRepo, itemRepo, chatRepo, messageRepo, brandRepo, modelRepo, generationRepo) {
        this.orgRepo = orgRepo;
        this.staffRepo = staffRepo;
        this.scheduleRepo = scheduleRepo;
        this.settingsRepo = settingsRepo;
        this.userRepo = userRepo;
        this.orderRepo = orderRepo;
        this.itemRepo = itemRepo;
        this.chatRepo = chatRepo;
        this.messageRepo = messageRepo;
        this.brandRepo = brandRepo;
        this.modelRepo = modelRepo;
        this.generationRepo = generationRepo;
    }
    async onApplicationBootstrap() {
        const refOnly = process.env.SEED_REFERENCE_ONLY === '1' || process.env.SEED_REFERENCE_ONLY === 'true';
        if (refOnly) {
            await this.seedCarBrandsAndModels();
            await this.seedCarGenerations();
            console.log('[Seed] Справочник авто (SEED_REFERENCE_ONLY): проверка/загрузка выполнена.');
            return;
        }
        if (process.env.NODE_ENV === 'production' && !process.env.SEED_DEV)
            return;
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
        }
        else if (org.latitude == null || org.longitude == null) {
            await this.orgRepo.update(org.id, { latitude: ORG_LAT, longitude: ORG_LNG });
            org.latitude = ORG_LAT;
            org.longitude = ORG_LNG;
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
                        await this.scheduleRepo.save(this.scheduleRepo.create({
                            masterId: member.id,
                            dayOfWeek: day,
                            startTime: '09:00',
                            endTime: '18:00',
                            isWorkingDay: true,
                        }));
                    }
                    console.log('[Seed] График мастера', member.name);
                }
            }
            console.log('[Seed] Добавлены сотрудники в Персонал:', STAFF_PHONES.length);
        }
        for (const s of STAFF_PHONES) {
            let user = await this.userRepo.findOne({ where: { phone: s.phone, accountRealm: 'business' } });
            if (!user) {
                user = this.userRepo.create({
                    phone: s.phone,
                    name: s.name,
                    role: s.role,
                    organizationId: org.id,
                    accountRealm: 'business',
                });
                await this.userRepo.save(user);
            }
            else {
                user.organizationId = org.id;
                user.role = s.role;
                user.name = s.name;
                user.accountRealm = 'business';
                await this.userRepo.save(user);
            }
        }
        for (const c of CLIENT_PHONES) {
            let user = await this.userRepo.findOne({ where: { phone: c.phone, accountRealm: 'client' } });
            if (!user) {
                const legacy = await this.userRepo.findOne({ where: { phone: c.phone } });
                if (legacy && legacy.accountRealm === 'business' && !legacy.organizationId) {
                    legacy.accountRealm = 'client';
                    legacy.name = c.name;
                    await this.userRepo.save(legacy);
                    user = legacy;
                }
                else if (!legacy) {
                    user = this.userRepo.create({
                        phone: c.phone,
                        name: c.name,
                        role: 'solo',
                        organizationId: null,
                        accountRealm: 'client',
                    });
                    await this.userRepo.save(user);
                }
            }
            if (user) {
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
            car_brands: [],
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
        }
        else {
            await this.settingsRepo.update(settings.id, { data: settingsData });
            console.log('[Seed] Обновлены настройки организации:', services.length, 'услуг');
        }
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
        }
        else if (orgMr.latitude == null || orgMr.longitude == null) {
            await this.orgRepo.update(orgMr.id, { latitude: AUTO_MR_LAT, longitude: AUTO_MR_LNG });
            orgMr.latitude = AUTO_MR_LAT;
            orgMr.longitude = AUTO_MR_LNG;
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
                    await this.scheduleRepo.save(this.scheduleRepo.create({
                        masterId: member.id,
                        dayOfWeek: day,
                        startTime: '09:00',
                        endTime: '18:00',
                        isWorkingDay: true,
                    }));
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
        }
        else {
            await this.settingsRepo.update(settingsMr.id, { data: settingsDataMr });
        }
        for (const s of AUTO_MR_OWNER_ADMIN) {
            let userMr = await this.userRepo.findOne({ where: { phone: s.phone, accountRealm: 'business' } });
            if (!userMr) {
                userMr = this.userRepo.create({
                    phone: s.phone,
                    name: s.name,
                    role: s.role,
                    organizationId: orgMr.id,
                    accountRealm: 'business',
                });
                await this.userRepo.save(userMr);
            }
            else {
                userMr.organizationId = orgMr.id;
                userMr.role = s.role;
                userMr.name = s.name;
                userMr.accountRealm = 'business';
                await this.userRepo.save(userMr);
            }
        }
        for (const m of AUTO_MR_MASTERS) {
            let userMr = await this.userRepo.findOne({ where: { phone: m.phone, accountRealm: 'business' } });
            if (!userMr) {
                userMr = this.userRepo.create({
                    phone: m.phone,
                    name: m.name,
                    role: 'master',
                    organizationId: orgMr.id,
                    accountRealm: 'business',
                });
                await this.userRepo.save(userMr);
            }
            else {
                userMr.organizationId = orgMr.id;
                userMr.role = 'master';
                userMr.name = m.name;
                userMr.accountRealm = 'business';
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
    async seedCarBrandsAndModels() {
        const count = await this.brandRepo.count();
        if (count > 0)
            return;
        for (let i = 0; i < car_brands_seed_1.CAR_BRANDS_AND_MODELS.length; i++) {
            const { name, models } = car_brands_seed_1.CAR_BRANDS_AND_MODELS[i];
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
        console.log('[Seed] Справочник марок и моделей: загружено', car_brands_seed_1.CAR_BRANDS_AND_MODELS.length, 'марок');
    }
    async seedCarGenerations() {
        const count = await this.generationRepo.count();
        if (count > 0)
            return;
        let inserted = 0;
        for (const entry of car_generations_seed_1.CAR_GENERATIONS_SEED) {
            const brand = await this.brandRepo.findOne({ where: { name: entry.brandName } });
            if (!brand)
                continue;
            const model = await this.modelRepo.findOne({ where: { brandId: brand.id, name: entry.modelName } });
            if (!model)
                continue;
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
};
exports.SeedService = SeedService;
exports.SeedService = SeedService = __decorate([
    (0, common_1.Injectable)(),
    __param(0, (0, typeorm_1.InjectRepository)(organization_entity_1.Organization)),
    __param(1, (0, typeorm_1.InjectRepository)(staff_member_entity_1.StaffMember)),
    __param(2, (0, typeorm_1.InjectRepository)(master_schedule_entity_1.MasterSchedule)),
    __param(3, (0, typeorm_1.InjectRepository)(organization_settings_entity_1.OrganizationSettings)),
    __param(4, (0, typeorm_1.InjectRepository)(user_entity_1.User)),
    __param(5, (0, typeorm_1.InjectRepository)(order_entity_1.Order)),
    __param(6, (0, typeorm_1.InjectRepository)(order_item_entity_1.OrderItem)),
    __param(7, (0, typeorm_1.InjectRepository)(chat_entity_1.Chat)),
    __param(8, (0, typeorm_1.InjectRepository)(chat_message_entity_1.ChatMessage)),
    __param(9, (0, typeorm_1.InjectRepository)(car_brand_entity_1.CarBrand)),
    __param(10, (0, typeorm_1.InjectRepository)(car_model_entity_1.CarModel)),
    __param(11, (0, typeorm_1.InjectRepository)(car_generation_entity_1.CarGeneration)),
    __metadata("design:paramtypes", [typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository,
        typeorm_2.Repository])
], SeedService);
//# sourceMappingURL=seed.service.js.map