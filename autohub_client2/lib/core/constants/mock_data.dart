import '../../shared/models/car_model.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/sto_model.dart';
import '../../shared/models/notification_model.dart';
import '../../shared/models/car_document_model.dart';
import '../../shared/models/profile_note_model.dart';
import '../theme/client_palette.dart' show SemanticColors;
export '../../shared/models/notification_model.dart';
export '../../shared/models/sto_model.dart' show STOService;

/// @deprecated Фейковые данные только для справки. В приложении используются API и локальное хранилище по userId.
/// Не импортировать в экранах и провайдерах — каждый аккаунт должен видеть только свои данные.
class MockData {
  MockData._();

  // ═══════════════════════════════════════════════
  // АВТОМОБИЛИ
  // ═══════════════════════════════════════════════

  static final List<Car> cars = [
    Car(
      id: 'car_1',
      brand: 'BMW',
      model: 'X5 M',
      year: 2019,
      nickname: 'Чёрный зверь',
      plateNumber: 'А123АА777',
      vin: 'WBAXXXXXXXXXXXXXXX',
      mileage: 62850,
      engineType: 'Бензин, 4.4 л',
      transmission: 'Автомат',
      drivetrain: 'Полный',
      color: 'Чёрный',
      reminders: [
        CarReminder(
          id: 'rem_1', type: ReminderType.oil, title: 'Замена масла',
          currentMileage: 62850, recommendedMileage: 60000,
          status: ReminderStatus.overdue, statusText: 'Просрочено на 2 850 км',
        ),
        CarReminder(
          id: 'rem_2', type: ReminderType.brakes, title: 'Тормозные колодки',
          currentMileage: 62850, recommendedMileage: 65000,
          status: ReminderStatus.upcoming, statusText: 'Через 2 150 км',
        ),
      ],
    ),
    Car(
      id: 'car_2',
      brand: 'Audi',
      model: 'A4',
      year: 2021,
      plateNumber: 'В456ВВ77',
      mileage: 34200,
      engineType: 'Бензин, 2.0 л',
      transmission: 'Робот',
      drivetrain: 'Передний',
      color: 'Белый',
      reminders: [
        CarReminder(
          id: 'rem_3', type: ReminderType.tires, title: 'Сезонная замена шин',
          currentMileage: 34200, recommendedMileage: 0,
          status: ReminderStatus.upcoming, statusText: 'Апрель 2026',
        ),
      ],
    ),
  ];

  // ═══════════════════════════════════════════════
  // ДОКУМЕНТЫ ПО АВТОМОБИЛЯМ (ОСАГО, техосмотр, СТС)
  // ═══════════════════════════════════════════════

  static final List<CarDocument> carDocuments = [
    // car_1 — BMW X5 M
    CarDocument(carId: 'car_1', type: 'ОСАГО', detail: 'ХХХ 1234567890', status: 'Активен',
      statusColor: SemanticColors.success, expiry: 'до 15 марта 2026'),
    CarDocument(carId: 'car_1', type: 'Техосмотр', detail: 'Пройден: 01 июня 2025', status: 'Активен',
      statusColor: SemanticColors.success, expiry: 'до 01 июня 2026'),
    CarDocument(carId: 'car_1', type: 'СТС', detail: '99 АА 123456'),
    // car_2 — Audi A4
    CarDocument(carId: 'car_2', type: 'ОСАГО', detail: 'УУУ 9876543210', status: 'Активен',
      statusColor: SemanticColors.success, expiry: 'до 20 августа 2026'),
    CarDocument(carId: 'car_2', type: 'Техосмотр', detail: 'Пройден: 12 сентября 2025', status: 'Активен',
      statusColor: SemanticColors.success, expiry: 'до 12 сентября 2026'),
    CarDocument(carId: 'car_2', type: 'СТС', detail: '77 ВВ 654321'),
  ];

  static List<CarDocument> documentsForCar(String carId) {
    return carDocuments.where((d) => d.carId == carId).toList();
  }

  /// Обновить документ по carId и type (для редактирования ОСАГО, техосмотра и т.д.).
  static void updateCarDocument(CarDocument doc) {
    final i = carDocuments.indexWhere((d) => d.carId == doc.carId && d.type == doc.type);
    if (i >= 0) carDocuments[i] = doc;
  }

  // ═══════════════════════════════════════════════
  // ЗАМЕТКИ ПО АВТОМОБИЛЯМ
  // ═══════════════════════════════════════════════

  static final List<ProfileNote> profileNotes = [
    ProfileNote(id: 'note_1', carId: 'car_1', title: 'Проверить стук в подвеске',
      body: 'При повороте руля слышен щелчок. Возможно, шаровая опора или ШРУС.',
      date: DateTime(2025, 12, 23)),
    ProfileNote(id: 'note_2', carId: 'car_1', title: 'Купить зимнюю резину',
      body: 'Michelin X-Ice North 4, 255/50 R19. Проверить наличие на exist.ru',
      date: DateTime(2025, 12, 15)),
    ProfileNote(id: 'note_3', carId: 'car_1', title: 'Поменять дворники',
      body: 'Bosch Aerotwin, размер 600/500', date: DateTime(2025, 12, 10)),
    ProfileNote(id: 'note_4', carId: 'car_2', title: 'Заменить лампы ближнего света',
      body: 'Левый ближний перегорел, купить пару H7', date: DateTime(2025, 12, 20)),
  ];

  static List<ProfileNote> notesForCar(String carId) {
    return profileNotes.where((n) => n.carId == carId).toList();
  }

  // ═══════════════════════════════════════════════
  // ЗАКАЗЫ (с реалистичным временем работ)
  // ═══════════════════════════════════════════════

  static List<Order> orders = [
    Order(
      id: 'order_1', orderNumber: 'AH-123456', carId: 'car_1',
      stoId: 'sto_1', stoName: 'АвтоМастер Премиум',
      stoAddress: 'ул. Ленина, 15', stoPhone: '+74951234567',
      status: OrderStatus.inProgress,
      dateTime: DateTime(2025, 12, 23, 9, 0),
      items: [
        OrderItem(id: 'i1', name: 'Замена масла двигателя',
          priceKopecks: 350000, estimatedMinutes: 45, isCompleted: true,
          serviceId: 's1', catalogItemId: 'svc_s1'),
        OrderItem(id: 'i2', name: 'Замена масляного фильтра',
          priceKopecks: 80000, estimatedMinutes: 15, isCompleted: true,
          serviceId: 's2', catalogItemId: 'svc_s2'),
        OrderItem(id: 'i3', name: 'Диагностика подвески',
          priceKopecks: 200000, estimatedMinutes: 60,
          serviceId: 's4', catalogItemId: 'svc_s4'),
      ],
      comment: 'Просьба проверить стук в подвеске',
    ),
    Order(
      id: 'order_2', orderNumber: 'AH-123457', carId: 'car_1',
      stoId: 'sto_2', stoName: 'БМВ Сервис Краснодар',
      stoAddress: 'Мичуринский пр., 7', stoPhone: '+74959876543',
      status: OrderStatus.confirmed,
      dateTime: DateTime(2025, 12, 25, 10, 0),
      items: [
        OrderItem(id: 'i5', name: 'ТО-2 регламентное',
          priceKopecks: 3200000, estimatedMinutes: 240),
      ],
    ),
    Order(
      id: 'order_3', orderNumber: 'AH-123455', carId: 'car_1',
      stoId: 'sto_1', stoName: 'АвтоМастер Премиум',
      stoAddress: 'ул. Ленина, 15', stoPhone: '+74951234567',
      status: OrderStatus.done,
      dateTime: DateTime(2025, 12, 20, 14, 0),
      items: [
        OrderItem(id: 'i6', name: 'Замена тормозных дисков',
          priceKopecks: 2800000, estimatedMinutes: 120, isCompleted: true,
          serviceId: 's7', catalogItemId: 'svc_s7'),
        OrderItem(id: 'i7', name: 'Замена колодок',
          priceKopecks: 1200000, estimatedMinutes: 60, isCompleted: true,
          serviceId: 's6', catalogItemId: 'svc_s6'),
        OrderItem(id: 'i8', name: 'Прокачка тормозной системы',
          priceKopecks: 500000, estimatedMinutes: 40, isCompleted: true),
      ],
    ),
    Order(
      id: 'order_4', orderNumber: 'AH-123458', carId: 'car_2',
      stoId: 'sto_3', stoName: 'Моторика',
      stoAddress: 'ул. Гагарина, 32', stoPhone: '+74951112233',
      status: OrderStatus.pendingApproval,
      dateTime: DateTime(2025, 12, 27, 11, 0),
      items: [
        OrderItem(id: 'i9', name: 'Диагностика кондиционера',
          priceKopecks: 350000, estimatedMinutes: 45),
        OrderItem(id: 'i10', name: 'Заправка фреоном',
          priceKopecks: 400000, estimatedMinutes: 30,
          isApproved: false, isAdditional: true),
      ],
    ),
  ];

  // ═══════════════════════════════════════════════
  // Точки на карте (мок)
  // ═══════════════════════════════════════════════

  static final List<STO> favoriteSTOs = [
    STO(
      id: 'sto_1', name: 'АвтоМастер Премиум',
      address: 'ул. Ленина, 15', phone: '+74951234567',
      phones: ['+74951234567', '+74951234568'],
      rating: 4.8, reviewCount: 124, distanceKm: 2.3,
      isOpen: true, workingHours: 'Пн-Пт 09:00-20:00',
      specializations: ['BMW', 'Mercedes', 'Audi'],
      isFavorite: true, minPrice: 'от 2 500 ₽',
      latitude: 45.0355, longitude: 38.9753,
      types: ['Автосервис', 'Диагностика'],
    ),
    STO(
      id: 'sto_2', name: 'БМВ Сервис Краснодар',
      address: 'ул. Красная, 150', phone: '+78612987654',
      rating: 4.9, reviewCount: 89, distanceKm: 5.1,
      isOpen: false, workingHours: 'Пн-Пт 09:00-19:00',
      specializations: ['BMW'],
      isFavorite: true, minPrice: 'от 4 200 ₽',
      latitude: 45.0280, longitude: 38.9620,
      types: ['Автосервис', 'Кузовной'],
    ),
    STO(
      id: 'sto_3', name: 'Моторика',
      address: 'ул. Гагарина, 32', phone: '+78612112233',
      rating: 4.7, reviewCount: 67, distanceKm: 1.8,
      isOpen: true, workingHours: 'Пн-Сб 08:00-21:00',
      specializations: ['Audi', 'VW', 'Skoda'],
      isFavorite: true, minPrice: 'от 3 000 ₽',
      latitude: 45.0420, longitude: 38.9880,
      types: ['Автосервис', 'Электрика'],
    ),
  ];

  static final List<STO> allSTOs = [
    ...favoriteSTOs,
    STO(
      id: 'sto_4', name: 'АвтоЛюкс',
      address: 'пр. Мира, 45', rating: 4.5, reviewCount: 203,
      distanceKm: 3.7, isOpen: true,
      specializations: ['BMW', 'Mercedes', 'Audi', 'Porsche'],
      minPrice: 'от 3 500 ₽',
      latitude: 45.0480, longitude: 38.9650,
      types: ['Автосервис', 'Мойка', 'Детейлинг'],
    ),
    STO(
      id: 'sto_5', name: 'ТехноСтар',
      address: 'ул. Ставропольская, 88', rating: 4.3, reviewCount: 56,
      distanceKm: 7.2, isOpen: true,
      specializations: ['Toyota', 'Hyundai', 'Kia'],
      minPrice: 'от 1 500 ₽',
      latitude: 45.0180, longitude: 38.9520,
      types: ['Автосервис', 'Шиномонтаж', 'Диагностика'],
    ),
    STO(
      id: 'sto_6', name: 'МастерПлюс',
      address: 'ул. Селезнёва, 19', rating: 4.6, reviewCount: 178,
      distanceKm: 4.5, isOpen: false,
      specializations: ['BMW', 'Audi', 'VW'],
      minPrice: 'от 2 000 ₽',
      latitude: 45.0550, longitude: 38.9780,
      types: ['Шиномонтаж', 'Автосервис'],
    ),
  ];

  // ═══════════════════════════════════════════════
  // ЧАТЫ
  // ═══════════════════════════════════════════════

  static final List<Chat> chats = [
    Chat(
      id: 'chat_1', stoId: 'sto_1', stoName: 'АвтоМастер Премиум',
      orderId: 'order_1', orderNumber: 'AH-123456',
      carBrand: 'BMW', carModel: 'X5',
      orderStatus: OrderStatus.inProgress,
      lastMessage: 'Запчасти прибыли, начинаем работу',
      lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
      unreadCount: 1, isPinned: false,
      previewCarId: 'car_1',
      lastMessageOrderId: 'order_1',
    ),
    Chat(
      id: 'chat_2', stoId: 'sto_3', stoName: 'Моторика',
      orderId: 'order_4', orderNumber: 'AH-123458',
      carBrand: 'Audi', carModel: 'A4',
      orderStatus: OrderStatus.pendingApproval,
      lastMessage: 'Добавлены доп. работы к заказу',
      lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
      unreadCount: 2, isPinned: true,
      previewCarId: 'car_2',
      lastMessageOrderId: 'order_4',
    ),
    Chat(
      id: 'chat_3', stoId: 'sto_2', stoName: 'БМВ Сервис Краснодар',
      orderId: 'order_2', orderNumber: 'AH-123457',
      carBrand: 'BMW', carModel: 'X5',
      orderStatus: OrderStatus.confirmed,
      lastMessage: 'Приеду к 10',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
      lastMessageFromUser: true,
      lastMessageStatus: MessageDeliveryStatus.read,
      previewCarId: 'car_1',
      lastMessageOrderId: 'order_2',
    ),
    Chat(
      id: 'chat_4', stoId: 'sto_1', stoName: 'АвтоМастер Премиум',
      orderId: 'order_3', orderNumber: 'AH-123455',
      carBrand: 'BMW', carModel: 'X5',
      orderStatus: OrderStatus.done,
      lastMessage: 'Спасибо за визит!',
      lastMessageTime: DateTime.now().subtract(const Duration(days: 3)),
      previewCarId: 'car_1',
      lastMessageOrderId: 'order_3',
    ),
  ];

  static List<ChatMessage> messagesForChat(String chatId) {
    final now = DateTime.now();
    if (chatId == 'chat_1') {
      return [
        ChatMessage(id: 'm1', chatId: chatId, isFromUser: false, isSystem: true,
          content: 'Заказ создан', type: MessageType.system,
          timestamp: now.subtract(const Duration(hours: 5))),
        ChatMessage(id: 'm2', chatId: chatId, isFromUser: false, isSystem: true,
          content: 'Заказ подтверждён. Ждём вас 23 декабря в 09:00',
          type: MessageType.system, timestamp: now.subtract(const Duration(hours: 4, minutes: 50))),
        ChatMessage(id: 'm3', chatId: chatId, isFromUser: true,
          content: 'Здравствуйте! Привезу к 9 утра',
          timestamp: now.subtract(const Duration(hours: 4, minutes: 30)),
          deliveryStatus: MessageDeliveryStatus.read),
        ChatMessage(id: 'm4', chatId: chatId, isFromUser: false,
          content: 'Ждём вас! Бокс №3',
          timestamp: now.subtract(const Duration(hours: 4, minutes: 28))),
        ChatMessage(id: 'm5', chatId: chatId, isFromUser: false, isSystem: true,
          content: 'Автомобиль принят в работу',
          type: MessageType.system, timestamp: now.subtract(const Duration(hours: 3))),
        ChatMessage(id: 'm6', chatId: chatId, isFromUser: false,
          content: 'Начали диагностику, масло и фильтр уже заменили ✓',
          timestamp: now.subtract(const Duration(hours: 2, minutes: 30))),
        ChatMessage(id: 'm7', chatId: chatId, isFromUser: false,
          content: 'Запчасти прибыли, начинаем работу',
          timestamp: now.subtract(const Duration(hours: 2))),
      ];
    }
    if (chatId == 'chat_2') {
      return [
        ChatMessage(id: 'm10', chatId: chatId, isFromUser: false, isSystem: true,
          content: 'Заказ создан', type: MessageType.system,
          timestamp: now.subtract(const Duration(hours: 3))),
        ChatMessage(id: 'm11', chatId: chatId, isFromUser: false,
          content: 'Добрый день! Приняли ваш автомобиль',
          timestamp: now.subtract(const Duration(hours: 2))),
        ChatMessage(id: 'm12', chatId: chatId, isFromUser: false, isSystem: true,
          content: 'Автомобиль принят в работу',
          type: MessageType.system, timestamp: now.subtract(const Duration(hours: 1, minutes: 30))),
        ChatMessage(id: 'm13', chatId: chatId, isFromUser: false,
          content: 'При диагностике обнаружили что фреон подтекает. Нужна заправка. Согласуйте пожалуйста.',
          timestamp: now.subtract(const Duration(minutes: 30))),
        ChatMessage(id: 'm14', chatId: chatId, isFromUser: false, isSystem: false,
          content: 'approval_request', type: MessageType.approval,
          timestamp: now.subtract(const Duration(minutes: 28))),
      ];
    }
    return [
      ChatMessage(id: 'mx1', chatId: chatId, isFromUser: false, isSystem: true,
        content: 'Заказ создан', type: MessageType.system,
        timestamp: now.subtract(const Duration(days: 2))),
      ChatMessage(id: 'mx2', chatId: chatId, isFromUser: true,
        content: 'Приеду к 10',
        timestamp: now.subtract(const Duration(days: 1)),
        deliveryStatus: MessageDeliveryStatus.read),
    ];
  }

  // ═══════════════════════════════════════════════
  // УВЕДОМЛЕНИЯ (с навигацией)
  // ═══════════════════════════════════════════════

  static final List<NotificationItem> notifications = [
    NotificationItem(
      id: 'n1', icon: '🔔', title: 'Автомобиль принят в работу',
      subtitle: 'BMW X5 M | АвтоМастер Премиум',
      time: DateTime.now().subtract(const Duration(hours: 2)), isRead: false,
      targetType: NotificationTarget.order, targetId: 'order_1',
    ),
    NotificationItem(
      id: 'n2', icon: '⚠️', title: 'Требуется согласование',
      subtitle: 'Добавлены доп. работы к #AH-123458',
      time: DateTime.now().subtract(const Duration(hours: 4)), isRead: false,
      targetType: NotificationTarget.chat, targetId: 'chat_2',
    ),
    NotificationItem(
      id: 'n3', icon: '✓', title: 'Запись подтверждена',
      subtitle: 'БМВ Сервис Краснодар, 25 дек, 10:00',
      time: DateTime.now().subtract(const Duration(days: 1)), isRead: true,
      targetType: NotificationTarget.order, targetId: 'order_2',
    ),
    NotificationItem(
      id: 'n4', icon: '🛢', title: 'Пора заменить масло',
      subtitle: 'Пробег превышен на 2 850 км',
      time: DateTime.now().subtract(const Duration(days: 3)), isRead: true,
      targetType: NotificationTarget.garage, targetId: 'car_1',
    ),
    NotificationItem(
      id: 'n5', icon: '📄', title: 'ОСАГО истекает через 30 дней',
      subtitle: 'Полис ХХХ 1234567890',
      time: DateTime.now().subtract(const Duration(days: 5)), isRead: true,
      targetType: NotificationTarget.profile,
    ),
    NotificationItem(
      id: 'n6', icon: '✅', title: 'Работы завершены',
      subtitle: 'АвтоМастер Премиум | #AH-123455',
      time: DateTime.now().subtract(const Duration(days: 3)), isRead: true,
      targetType: NotificationTarget.order, targetId: 'order_3',
    ),
  ];

  // ═══════════════════════════════════════════════
  // КАТАЛОГ УСЛУГ (с реалистичным временем)
  // ═══════════════════════════════════════════════

  static final List<STOService> stoServices = [
    // Техническое обслуживание (`catalogItemId` — как у API для аналитики/моков)
    STOService(id: 's1', name: 'Замена масла двигателя',
      category: 'Техническое обслуживание', priceKopecks: 350000, durationMinutes: 45,
      catalogItemId: 'svc_s1'),
    STOService(id: 's2', name: 'Замена масляного фильтра',
      category: 'Техническое обслуживание', priceKopecks: 80000, durationMinutes: 15,
      catalogItemId: 'svc_s2'),
    STOService(id: 's3', name: 'Замена воздушного фильтра',
      category: 'Техническое обслуживание', priceKopecks: 120000, durationMinutes: 20,
      catalogItemId: 'svc_s3'),
    STOService(id: 's8', name: 'Замена антифриза',
      category: 'Техническое обслуживание', priceKopecks: 250000, durationMinutes: 60,
      catalogItemId: 'svc_s8'),
    // Диагностика
    STOService(id: 's4', name: 'Диагностика подвески',
      category: 'Диагностика', priceKopecks: 200000, durationMinutes: 60,
      catalogItemId: 'svc_s4'),
    STOService(id: 's5', name: 'Компьютерная диагностика',
      category: 'Диагностика', priceKopecks: 300000, durationMinutes: 45,
      catalogItemId: 'svc_s5'),
    // Тормозная система
    STOService(id: 's6', name: 'Замена тормозных колодок (перед)',
      category: 'Тормозная система', priceKopecks: 450000, durationMinutes: 60,
      catalogItemId: 'svc_s6'),
    STOService(id: 's7', name: 'Замена тормозных дисков (перед)',
      category: 'Тормозная система', priceKopecks: 800000, durationMinutes: 120,
      catalogItemId: 'svc_s7'),
    // Двигатель
    STOService(id: 's9', name: 'Замена свечей зажигания',
      category: 'Двигатель', priceKopecks: 400000, durationMinutes: 40,
      catalogItemId: 'svc_s9'),
    STOService(id: 's11', name: 'Капитальный ремонт двигателя',
      category: 'Двигатель', priceKopecks: 15000000, durationMinutes: 2880, // 2-3 дня
      catalogItemId: 'svc_s11'),
    STOService(id: 's12', name: 'Замена ремня ГРМ',
      category: 'Двигатель', priceKopecks: 1200000, durationMinutes: 360, // 6 ч
      catalogItemId: 'svc_s12'),
    // Ходовая часть
    STOService(id: 's10', name: 'Развал-схождение',
      category: 'Ходовая часть', priceKopecks: 350000, durationMinutes: 60,
      catalogItemId: 'svc_s10'),
    STOService(id: 's13', name: 'Замена амортизаторов (пара)',
      category: 'Ходовая часть', priceKopecks: 600000, durationMinutes: 180,
      catalogItemId: 'svc_s13'),
    // Кузовные
    STOService(id: 's14', name: 'Покраска элемента',
      category: 'Кузовные работы', priceKopecks: 800000, durationMinutes: 480, // 8 ч
      catalogItemId: 'svc_s14'),
    STOService(id: 's15', name: 'Полировка кузова',
      category: 'Кузовные работы', priceKopecks: 500000, durationMinutes: 240,
      catalogItemId: 'svc_s15'),
  ];

  // ═══════════════════════════════════════════════
  // Занятые слоты точки (для логики «непрерывного окна»)
  // Ключ — stoId, дата нормализована. Занято = уже есть запись в это время.
  // ═══════════════════════════════════════════════

  /// Занятые интервалы на дату для точки. Формат: список (start "HH:mm", end "HH:mm").
  /// Учитываем только день (год/месяц/день), без времени.
  static List<({String start, String end})> getBusyRangesForStoOnDate(String stoId, DateTime date) {
    final norm = DateTime(date.year, date.month, date.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final daysFromToday = norm.difference(today).inDays;
    if (daysFromToday < 1 || daysFromToday > 14) return [];
    // Для всех точек в моке: 11:30–12:30 занято, чтобы при записи от 1.5 ч нельзя было выбрать 11:00
    return [(start: '11:30', end: '12:30'), (start: '14:00', end: '15:00')];
  }

  // ═══════════════════════════════════════════════
  // Хелпер: найти заказ / чат по ID
  // ═══════════════════════════════════════════════

  static Order? findOrderById(String id) {
    try { return orders.firstWhere((o) => o.id == id); }
    catch (_) { return null; }
  }

  static Chat? findChatById(String id) {
    try { return chats.firstWhere((c) => c.id == id); }
    catch (_) { return null; }
  }

  static Chat? findChatByOrderId(String orderId) {
    try { return chats.firstWhere((c) => c.orderId == orderId); }
    catch (_) { return null; }
  }

  static STO? findStoById(String stoId) {
    try { return allSTOs.firstWhere((s) => s.id == stoId); }
    catch (_) { return null; }
  }
}

// ═══════════════════════════════════════════════
// МОДЕЛИ ДАННЫХ
// ═══════════════════════════════════════════════

// NotificationItem и NotificationTarget перенесены в shared/models/notification_model.dart

// STOService перенесён в shared/models/sto_model.dart
