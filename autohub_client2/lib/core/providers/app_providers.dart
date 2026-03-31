import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/car_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/sto_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/prefs_car_repository.dart';
import '../repositories/api_order_repository.dart';
import '../repositories/api_chat_repository.dart';
import '../repositories/api_sto_repository.dart';
import '../api/catalog_api_service.dart';
import '../repositories/api_notification_repository.dart';
import '../api/notification_api_service.dart';
import '../api/api_exceptions.dart';
import '../api/order_api_service.dart';
import '../api/chat_api_service.dart';
import '../api/reference_api_service.dart';
import '../auth/auth_provider.dart';
import '../../shared/models/notification_model.dart';
import '../../shared/models/car_model.dart' show Car, CarReminder;
import '../../shared/models/order_model.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/sto_model.dart';
import '../../shared/models/profile_note_model.dart';
import '../../shared/models/car_document_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ═══════════════════════════════════════
// РЕПОЗИТОРИИ
// ═══════════════════════════════════════
// Заказы, чаты, уведомления — API (общий бэкенд). Гараж — PrefsCarRepository (по userId).
// Каталог точек — заглушка (пустые результаты до API). Mock* репозитории не используются.

/// Машины хранятся в SharedPreferences по ключу cars_<userId>. У каждого аккаунта свой список.
final carRepositoryProvider = Provider<CarRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  if (prefs == null) return _EmptyCarRepository();
  return PrefsCarRepository(prefs, userId);
});

final orderApiServiceProvider = Provider<OrderApiService>(
  (ref) => OrderApiService(ref.watch(apiClientProvider)),
);
final chatApiServiceProvider = Provider<ChatApiService>(
  (ref) => ChatApiService(ref.watch(apiClientProvider)),
);
final referenceApiServiceProvider = Provider<ReferenceApiService>(
  (ref) => ReferenceApiService(ref.watch(apiClientProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => ApiOrderRepository(
    ref.watch(orderApiServiceProvider),
    ref.watch(stoRepositoryProvider),
  ),
);

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ApiChatRepository(ref.watch(chatApiServiceProvider)),
);

final catalogApiServiceProvider = Provider<CatalogApiService>(
  (ref) => CatalogApiService(ref.watch(apiClientProvider)),
);

final stoRepositoryProvider = Provider<STORepository>(
  (ref) => ApiSTORepository(ref.watch(catalogApiServiceProvider)),
);

final notificationApiServiceProvider = Provider<NotificationApiService>(
  (ref) => NotificationApiService(ref.watch(apiClientProvider)),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => ApiNotificationRepository(ref.watch(notificationApiServiceProvider)),
);

// ═══════════════════════════════════════
// GARAGE (Авто)
// ═══════════════════════════════════════

/// Список авто текущего пользователя
final carsProvider = StateNotifierProvider<CarsNotifier, AsyncValue<List<Car>>>(
  (ref) {
    final repo = ref.watch(carRepositoryProvider);
    return CarsNotifier(repo);
  },
);

class CarsNotifier extends StateNotifier<AsyncValue<List<Car>>> {
  final CarRepository _repo;

  CarsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadCars();
  }

  /// [silent]: true — не показывать состояние загрузки (после добавления авто, чтобы UI не «зависал»).
  Future<void> loadCars({bool silent = false}) async {
    final previous = state.valueOrNull;
    if (!silent) {
      state = const AsyncValue.loading();
    }
    final result = await _repo.getCars();
    result.when(
      success: (cars) {
        state = AsyncValue.data(cars);
      },
      failure: (error) {
        if (silent && previous != null) {
          state = AsyncValue.data(previous);
        } else {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  Future<Car?> addCar({
    required String brandName,
    required String modelName,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    required int year,
    String? licensePlate,
    int? mileage,
    String? vin,
    String? nickname,
    String? engineType,
    String? transmission,
    String? drivetrain,
    String? bodyType,
    String? color,
  }) async {
    final result = await _repo.addCar(
      brandName: brandName,
      modelName: modelName,
      generation: generation,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      year: year,
      licensePlate: licensePlate,
      mileage: mileage,
      vin: vin,
      nickname: nickname,
      engineType: engineType,
      transmission: transmission,
      drivetrain: drivetrain,
      bodyType: bodyType,
      color: color,
    );
    final car = result.dataOrNull;
    if (car != null) {
      await loadCars(silent: true);
      return car;
    }
    return null;
  }

  Future<bool> updateMileage(String carId, int newMileage) async {
    final result = await _repo.updateMileage(carId, newMileage);
    if (result.dataOrNull != null) {
      await loadCars();
      return true;
    }
    return false;
  }

  Future<bool> updateCarPhoto(String carId, String? photoUrl) async {
    final result = await _repo.updateCarPhoto(carId, photoUrl);
    if (result.dataOrNull != null) {
      await loadCars(silent: true);
      return true;
    }
    return false;
  }

  Future<bool> deleteCar(String id) async {
    final result = await _repo.deleteCar(id);
    if (result.errorOrNull == null) {
      await loadCars();
      return true;
    }
    return false;
  }

  /// Частичное обновление карточки (ник, госномер, пробег, VIN). Пустые строки сохраняются как пустые поля.
  Future<bool> updateCarDetails(
    String id, {
    required String nickname,
    required String licensePlate,
    required int mileage,
    required String vin,
  }) async {
    final result = await _repo.updateCar(
      id,
      nickname: nickname,
      licensePlate: licensePlate,
      mileage: mileage,
      vin: vin,
    );
    if (result.dataOrNull != null) {
      await loadCars(silent: true);
      return true;
    }
    return false;
  }
}

// ═══════════════════════════════════════
// ORDERS (Заказы)
// ═══════════════════════════════════════

final ordersProvider =
    StateNotifierProvider<OrdersNotifier, AsyncValue<List<Order>>>((ref) {
      final repo = ref.watch(orderRepositoryProvider);
      return OrdersNotifier(repo);
    });

/// Актуальный заказ по ID (для карточки заказа — чтобы видеть обновлённый статус, например «Требуется согласование»).
final orderByIdProvider = FutureProvider.family<Order?, String>((
  ref,
  id,
) async {
  if (id.isEmpty) return null;
  final repo = ref.watch(orderRepositoryProvider);
  final r = await repo.getOrderById(id);
  return r.dataOrNull;
});

class OrdersNotifier extends StateNotifier<AsyncValue<List<Order>>> {
  final OrderRepository _repo;

  OrdersNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadOrders();
  }

  Future<void> loadOrders() async {
    // При обновлении не сбрасываем список в loading — иначе в диалоге пропадают «ссылка на заказ» и карточки до прихода ответа.
    final hadData = state.hasValue;
    if (!hadData) state = const AsyncValue.loading();
    final result = await _repo.getOrders();
    state = result.when(
      success: (orders) => AsyncValue.data(orders),
      failure: (error) => AsyncValue.error(error, StackTrace.current),
    );
  }

  Future<bool> cancelOrder(String orderId) async {
    final result = await _repo.cancelOrder(orderId);
    if (result.errorOrNull == null) {
      await loadOrders();
      return true;
    }
    return false;
  }

  /// Успех — Result.success, при ошибке — Result.failure (message в errorOrNull для отображения пользователю).
  Future<Result<void>> confirmOrder(
    String orderId, {
    DateTime? dateTime,
    bool acceptProposed = true,
    String? approvalMessageId,
  }) async {
    final result = await _repo.confirmOrder(
      orderId,
      dateTime: dateTime,
      acceptProposed: acceptProposed,
      approvalMessageId: approvalMessageId,
    );
    if (result.errorOrNull == null) {
      await loadOrders();
      return Result.success(null);
    }
    return result;
  }

  /// Возвращает Result<Order>: success — заказ после согласования, failure — текст ошибки (например 409 «Нет сообщения согласования»).
  Future<Result<Order>> approveItems(
    String orderId, {
    required List<String> approvedItemIds,
    required List<String> rejectedItemIds,
    String? carId,
    String? approvalMessageId,
  }) async {
    final result = await _repo.approveItems(
      orderId,
      approvedItemIds: approvedItemIds,
      rejectedItemIds: rejectedItemIds,
      carId: carId,
      approvalMessageId: approvalMessageId,
    );
    if (result.dataOrNull != null) {
      await loadOrders();
      return result;
    }
    return result;
  }
}

// ═══════════════════════════════════════
// CHATS
// ═══════════════════════════════════════

final chatsProvider =
    StateNotifierProvider<ChatsNotifier, AsyncValue<List<Chat>>>((ref) {
      final repo = ref.watch(chatRepositoryProvider);
      return ChatsNotifier(repo);
    });

class ChatsNotifier extends StateNotifier<AsyncValue<List<Chat>>> {
  final ChatRepository _repo;

  ChatsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadChats();
  }

  Future<void> loadChats() async {
    final hadData = state.hasValue;
    if (!hadData) state = const AsyncValue.loading();
    final result = await _repo.getChats();
    state = result.when(
      success: (chats) => AsyncValue.data(chats),
      failure: (error) => AsyncValue.error(error, StackTrace.current),
    );
  }

  /// Получить один чат по id (если нет в списке — запрос GET /chats/:id). Для открытия общего чата без stub.
  Future<Result<Chat>> getChatById(String chatId) async =>
      _repo.getChatById(chatId);

  Future<bool> sendMessage(String chatId, String text) async {
    final result = await _repo.sendMessage(chatId, text: text);
    if (result.dataOrNull != null) {
      await loadChats();
      return true;
    }
    return false;
  }

  Future<bool> sendMessageWithMedia(
    String chatId, {
    String text = '',
    List<ChatOutgoingImage> images = const [],
  }) async {
    final result = await _repo.sendMessageWithMedia(
      chatId,
      text: text,
      images: images,
    );
    if (result.dataOrNull != null) {
      await loadChats();
      return true;
    }
    return false;
  }

  /// Отметить чат прочитанным и обновить список (для сброса бейджа).
  Future<void> markChatAsRead(String chatId) async {
    await _repo.markAllAsRead(chatId);
    await loadChats();
  }
}

/// Суммарное количество непрочитанных сообщений по всем чатам (для бейджа в нижней панели).
final totalUnreadChatsCountProvider = Provider<int>((ref) {
  final chats = ref.watch(chatsProvider);
  return chats.whenOrNull(
        data: (list) => list.fold<int>(0, (s, c) => s + c.unreadCount),
      ) ??
      0;
});

// ═══════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════

final notificationsProvider =
    StateNotifierProvider<
      NotificationsNotifier,
      AsyncValue<List<NotificationItem>>
    >((ref) {
      final repo = ref.watch(notificationRepositoryProvider);
      return NotificationsNotifier(repo);
    });

/// Общее число непрочитанных (для бейджа). Берётся с API.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final r = await repo.getUnreadCount();
  return r.dataOrNull ?? 0;
});

/// Непрочитанные по машинам: carId -> count (для счётчика у каждой машины в гараже).
final unreadByCarProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  final r = await repo.getUnreadByCar();
  return r.dataOrNull ?? {};
});

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<NotificationItem>>> {
  NotificationsNotifier(this._repo) : super(const AsyncValue.loading());
  final NotificationRepository _repo;

  String? _lastCarId;

  Future<void> loadNotifications({String? carId}) async {
    _lastCarId = carId;
    state = const AsyncValue.loading();
    final result = await _repo.getNotifications(carId: carId);
    state = result.when(
      success: (items) => AsyncValue.data(items),
      failure: (error) => AsyncValue.error(error, StackTrace.current),
    );
  }

  Future<void> markAsRead(String id) async {
    await _repo.markAsRead(id);
    await loadNotifications(carId: _lastCarId);
  }

  Future<void> markAllAsRead({String? carId}) async {
    await _repo.markAllAsRead(carId: carId ?? _lastCarId);
    await loadNotifications(carId: carId ?? _lastCarId);
  }

  /// Снять бейджи, связанные с заказом (согласование и т.п.).
  Future<void> markReadByOrderId(String orderId) async {
    if (orderId.isEmpty) return;
    await _repo.markReadByOrderId(orderId);
    await loadNotifications(carId: _lastCarId);
  }

  /// Снять бейджи о сообщениях в чате при открытии диалога.
  Future<void> markReadByChatId(String chatId) async {
    if (chatId.isEmpty) return;
    await _repo.markReadByChatId(chatId);
    await loadNotifications(carId: _lastCarId);
  }

  Future<void> deleteNotification(String id) async {
    await _repo.deleteNotification(id);
    await loadNotifications(carId: _lastCarId);
  }
}

// ═══════════════════════════════════════
// STO (Поиск, избранное)
// ═══════════════════════════════════════

/// Заглушка, когда prefs ещё не загружены (возвращает пустой гараж).
class _EmptyCarRepository implements CarRepository {
  @override
  Future<Result<List<Car>>> getCars() async => Result.success([]);
  @override
  Future<Result<Car>> getCarById(String id) async => Result.failure(
    const ApiException(code: ApiErrorCode.notFound, message: 'Нет данных'),
  );
  @override
  Future<Result<Car>> addCar({
    required String brandName,
    required String modelName,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    required int year,
    String? licensePlate,
    int? mileage,
    String? vin,
    String? nickname,
    String? engineType,
    String? transmission,
    String? drivetrain,
    String? bodyType,
    String? color,
  }) async => Result.failure(
    const ApiException(
      code: ApiErrorCode.internal,
      message: 'Нет доступа к хранилищу',
    ),
  );
  @override
  Future<Result<Car>> updateCar(
    String id, {
    String? nickname,
    String? licensePlate,
    int? mileage,
    String? vin,
  }) async => Result.failure(
    const ApiException(code: ApiErrorCode.notFound, message: 'Нет данных'),
  );
  @override
  Future<Result<Car>> updateCarReference(
    String id, {
    required int brandId,
    required int modelId,
    required int generationId,
    required String brandName,
    required String modelName,
    required String generationName,
  }) async => Result.failure(
    const ApiException(code: ApiErrorCode.notFound, message: 'Нет данных'),
  );
  @override
  Future<Result<Car>> updateMileage(String carId, int newMileage) async =>
      Result.failure(
        const ApiException(code: ApiErrorCode.notFound, message: 'Нет данных'),
      );
  @override
  Future<Result<Car>> updateCarPhoto(String carId, String? photoUrl) async =>
      Result.failure(
        const ApiException(code: ApiErrorCode.notFound, message: 'Нет данных'),
      );
  @override
  Future<Result<void>> deleteCar(String id) async => Result.success(null);
  @override
  Future<Result<List<CarReminder>>> getReminders(String carId) async =>
      Result.success([]);
  @override
  Future<Result<void>> dismissReminder(String carId, String reminderId) async =>
      Result.success(null);
}

/// Документы по автомобилям (ОСАГО, VIN, техосмотр, СТС и др.). Хранятся в SharedPreferences.
final carDocumentsProvider =
    StateNotifierProvider<CarDocumentsNotifier, List<CarDocument>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
      final userId = ref.watch(authProvider).user?.id;
      return CarDocumentsNotifier(prefs, userId);
    });

class CarDocumentsNotifier extends StateNotifier<List<CarDocument>> {
  CarDocumentsNotifier(this._prefs, this._userId)
    : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  static const _keyPrefix = 'car_documents_';

  String get _key => _keyPrefix + (_userId ?? 'guest');

  static List<CarDocument> _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null || userId.isEmpty) return [];
    final raw = prefs.getString(_keyPrefix + userId);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => CarDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    if (_prefs == null || _userId == null || _userId!.isEmpty) return;
    final list = state.map((d) => d.toJson()).toList();
    _prefs!.setString(_key, jsonEncode(list));
  }

  void addDocument(CarDocument doc) {
    state = [...state, doc];
    _save();
  }

  void updateDocument(CarDocument doc) {
    state = state
        .map((d) => d.carId == doc.carId && d.type == doc.type ? doc : d)
        .toList();
    _save();
  }

  void removeDocument(String carId, String type) {
    state = state.where((d) => !(d.carId == carId && d.type == type)).toList();
    _save();
  }

  List<CarDocument> forCar(String carId) =>
      state.where((d) => d.carId == carId).toList();
}

/// Заметки профиля по авто: в памяти, привязаны к текущему пользователю (при смене аккаунта — пустой список).
final profileNotesProvider =
    StateNotifierProvider<ProfileNotesNotifier, List<ProfileNote>>((ref) {
      final userId = ref.watch(authProvider).user?.id;
      return ProfileNotesNotifier(userId);
    });

class ProfileNotesNotifier extends StateNotifier<List<ProfileNote>> {
  ProfileNotesNotifier(this._userId) : super([]);

  final String? _userId;

  void add(ProfileNote n) {
    if (_userId == null) return;
    state = [...state, n];
  }

  void update(ProfileNote n) {
    state = state.map((e) => e.id == n.id ? n : e).toList();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
  }
}

class CatalogCategory {
  final String id;
  final String name;
  const CatalogCategory({required this.id, required this.name});
}

class CatalogServiceItem {
  final String id;
  final String name;
  final String categoryId;
  const CatalogServiceItem({
    required this.id,
    required this.name,
    required this.categoryId,
  });
}

/// Параметры поиска организаций в каталоге (текст + тип точки на карте).
typedef StoSearchParams = ({String? query, String? businessKind});

/// Каталог услуг для фильтра поиска (категории + услуги из API `GET /catalog/services`).
/// [businessKind] null / all — полный справочник; иначе — только позиции, разрешённые для типа организации.
final catalogServicesProvider =
    FutureProvider.family<
      ({List<CatalogCategory> categories, List<CatalogServiceItem> items}),
      String?
    >((ref, businessKind) async {
      final api = ref.watch(catalogApiServiceProvider);
      final kind =
          (businessKind == null ||
              businessKind.isEmpty ||
              businessKind == 'all')
          ? null
          : businessKind;
      final result = await api.getCatalogServices(businessKind: kind);
      final data = result.dataOrNull;
      if (data == null)
        return (categories: <CatalogCategory>[], items: <CatalogServiceItem>[]);
      final categoriesRaw = data['categories'] as List<dynamic>? ?? [];
      final categories = <CatalogCategory>[];
      final items = <CatalogServiceItem>[];

      for (final c in categoriesRaw) {
        final m = c as Map<String, dynamic>;
        final catKey =
            m['category_key']?.toString() ?? m['id']?.toString() ?? '';
        final catName =
            m['category_name']?.toString() ?? m['name']?.toString() ?? '';
        if (catKey.isEmpty) continue;
        categories.add(
          CatalogCategory(id: catKey, name: catName.isEmpty ? catKey : catName),
        );
        final inner = m['items'] as List<dynamic>? ?? [];
        for (final s in inner) {
          final sm = s as Map<String, dynamic>;
          final id = sm['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          items.add(
            CatalogServiceItem(
              id: id,
              name: sm['name']?.toString() ?? '',
              categoryId: catKey,
            ),
          );
        }
      }

      // Обратная совместимость: плоский список items + categories с полем id/name (старый API).
      if (items.isEmpty) {
        final flatCats = categoriesRaw
            .map((c) {
              final m = c as Map<String, dynamic>;
              return CatalogCategory(
                id: m['id']?.toString() ?? '',
                name: m['name']?.toString() ?? '',
              );
            })
            .where((e) => e.id.isNotEmpty)
            .toList();
        final itemsRaw = data['items'] as List<dynamic>? ?? [];
        final flatItems = itemsRaw
            .map((s) {
              final m = s as Map<String, dynamic>;
              return CatalogServiceItem(
                id: m['id']?.toString() ?? '',
                name: m['name']?.toString() ?? '',
                categoryId: m['category_id']?.toString() ?? '',
              );
            })
            .where((e) => e.id.isNotEmpty)
            .toList();
        if (flatItems.isNotEmpty) {
          return (categories: flatCats, items: flatItems);
        }
      }

      return (categories: categories, items: items);
    });

final stoSearchProvider = FutureProvider.family<List<STO>, StoSearchParams>((
  ref,
  params,
) async {
  final repo = ref.watch(stoRepositoryProvider);
  final result = await repo.searchSTOs(
    query: params.query,
    businessKind: params.businessKind,
  );
  return result.dataOrNull ?? [];
});

/// Точка по id (для перехода в профиль из карточки заказа и маршрута).
final stoByIdProvider = FutureProvider.family<STO?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final repo = ref.watch(stoRepositoryProvider);
  final result = await repo.getSTOById(id);
  return result.dataOrNull;
});

final favoriteSTOsProvider = FutureProvider<List<STO>>((ref) async {
  final repo = ref.watch(stoRepositoryProvider);
  final result = await repo.getFavorites();
  return result.dataOrNull ?? [];
});

/// Услуги конкретной точки по id (для экрана карточки и записи).
final stoServicesProvider = FutureProvider.family<List<STOService>, String>((
  ref,
  stoId,
) async {
  final repo = ref.watch(stoRepositoryProvider);
  final result = await repo.getServices(stoId);
  return result.dataOrNull ?? [];
});

/// Комплексы услуг конкретной точки (GET /catalog/organizations/:id/services).
final stoPackagesProvider = FutureProvider.family<List<STOPackage>, String>((
  ref,
  stoId,
) async {
  final api = ref.watch(catalogApiServiceProvider);
  final result = await api.getOrganizationServices(stoId);
  final data = result.dataOrNull;
  if (data == null) return <STOPackage>[];
  final raw = (data['packages'] as List<dynamic>?) ?? [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(
        (m) => STOPackage(
          id: m['id']?.toString() ?? '',
          name: m['name']?.toString() ?? '',
          categoryId: m['category_id']?.toString() ?? '',
          packagePriceKopecks:
              (m['package_price_kopecks'] as num?)?.toInt() ?? 0,
          includedServiceIds:
              ((m['included_service_ids'] as List<dynamic>?) ?? const [])
                  .map((e) => e.toString())
                  .where((e) => e.isNotEmpty)
                  .toList(),
          addons: ((m['addons'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(
                (a) => STOPackageAddon(
                  serviceId: a['service_id']?.toString() ?? '',
                  extraPriceKopecks:
                      (a['extra_price_kopecks'] as num?)?.toInt() ?? 0,
                ),
              )
              .where((a) => a.serviceId.isNotEmpty)
              .toList(),
        ),
      )
      .where((p) => p.id.isNotEmpty)
      .toList();
});
