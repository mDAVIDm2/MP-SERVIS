import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/car_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/chat_repository.dart';
import '../repositories/sto_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/api_car_repository.dart';
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
import '../settings/mileage_prompt_storage.dart';
import '../settings/maintenance_reminders_provider.dart';
import '../sync/client_app_state_schema.dart';
import '../sync/client_app_state_push_bridge.dart' show scheduleClientAppStatePush;

// ═══════════════════════════════════════
// РЕПОЗИТОРИИ
// ═══════════════════════════════════════
// Заказы, чаты, уведомления — API. Гараж клиента — GET/POST `/profile/cars` на бэкенде.
// Каталог точек — заглушка (пустые результаты до API). Mock* репозитории не используются.

/// Гараж клиента: REST `/profile/cars` на бэкенде (привязка к аккаунту). Без входа — пустой репозиторий.
final carRepositoryProvider = Provider<CarRepository>((ref) {
  final userId = ref.watch(authProvider).user?.id;
  if (userId == null || userId.isEmpty) return _EmptyCarRepository();
  return ApiCarRepository(ref.watch(apiClientProvider));
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
    final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
    final userId = ref.watch(authProvider).user?.id;
    final orderRepo = ref.watch(orderRepositoryProvider);
    return CarsNotifier(ref, repo, prefs, userId, orderRepo);
  },
);

class CarsNotifier extends StateNotifier<AsyncValue<List<Car>>> {
  /// Тот же ключ, что в [PrefsCarRepository]: не подмешивать обратно из заказов после удаления.
  static const _hiddenMergeIdsKeyPrefix = 'garage_hidden_merge_car_ids_';

  final Ref _ref;
  final CarRepository _repo;
  final SharedPreferences? _prefs;
  final String? _userId;
  final OrderRepository _orderRepo;

  CarsNotifier(this._ref, this._repo, this._prefs, this._userId, this._orderRepo)
      : super(const AsyncValue.loading()) {
    loadCars();
  }

  String get _hiddenMergeIdsKey => _hiddenMergeIdsKeyPrefix + (_userId ?? '');

  Set<String> _loadGarageHiddenCarIds() {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null || uid.isEmpty) return {};
    final raw = p.getString(_hiddenMergeIdsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return {};
      return list.map((e) => '$e').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _rememberGarageHiddenCarId(String id) async {
    final p = _prefs;
    final uid = _userId;
    if (p == null || uid == null || uid.isEmpty || id.isEmpty) return;
    final s = _loadGarageHiddenCarIds();
    if (!s.add(id)) return;
    await p.setString(_hiddenMergeIdsKey, jsonEncode(s.toList()));
    scheduleClientAppStatePush();
  }

  List<Car> _withoutHiddenCars(List<Car> cars) {
    final h = _loadGarageHiddenCarIds();
    if (h.isEmpty) return cars;
    return cars.where((c) => !h.contains(c.id)).toList();
  }

  /// Подставить карточку из ответа PATCH до `loadCars`: при сбое тихой перезагрузки список не откатится к устаревшему.
  void _replaceCarInState(Car updated) {
    final list = state.valueOrNull;
    if (list == null) return;
    final i = list.indexWhere((c) => c.id == updated.id);
    if (i < 0) return;
    final old = list[i];
    final merged = updated.reminders.isNotEmpty
        ? updated
        : Car(
            id: updated.id,
            brand: updated.brand,
            model: updated.model,
            generation: updated.generation,
            brandId: updated.brandId,
            modelId: updated.modelId,
            generationId: updated.generationId,
            year: updated.year,
            nickname: updated.nickname,
            plateNumber: updated.plateNumber,
            vin: updated.vin,
            mileage: updated.mileage,
            engineType: updated.engineType,
            transmission: updated.transmission,
            drivetrain: updated.drivetrain,
            bodyType: updated.bodyType,
            color: updated.color,
            photoUrl: updated.photoUrl,
            reminders: old.reminders,
            mergedFromOrders: updated.mergedFromOrders,
          );
    final next = List<Car>.from(list);
    next[i] = merged;
    state = AsyncValue.data(next);
  }

  /// [silent]: true — не показывать состояние загрузки (после добавления авто, чтобы UI не «зависал»).
  Future<void> loadCars({bool silent = false}) async {
    final previous = state.valueOrNull;
    if (!silent) {
      state = const AsyncValue.loading();
    }
    final result = await _repo.getCars();
    await result.when(
      success: (cars) async {
        var list = _withoutHiddenCars(cars);
        if (_userId != null && _userId.isNotEmpty && _repo is ApiCarRepository) {
          await _migratePrefsGarageToApiOnce(list);
          final afterMigrate = await _repo.getCars();
          afterMigrate.when(
            success: (c) => list = _withoutHiddenCars(c),
            failure: (_) {},
          );
        }
        if (_userId != null && _userId.isNotEmpty) {
          final hidden = _loadGarageHiddenCarIds();
          final ordersRes = await _orderRepo.getOrders();
          await ordersRes.when(
            success: (orders) async {
              final mergeRes = await _repo.mergeCarsFromOrders(
                orders,
                skipCarIds: hidden,
              );
              final n = mergeRes.dataOrNull ?? 0;
              if (n > 0) {
                final again = await _repo.getCars();
                again.when(
                  success: (c) => list = _withoutHiddenCars(c),
                  failure: (_) {},
                );
              }
            },
            failure: (_) async {},
          );
        }
        state = AsyncValue.data(list);
      },
      failure: (error) async {
        if (silent && previous != null) {
          state = AsyncValue.data(previous);
        } else {
          state = AsyncValue.error(error, StackTrace.current);
        }
      },
    );
  }

  /// Одноразово: старый гараж из SharedPreferences → API, затем ключи очищаются.
  Future<void> _migratePrefsGarageToApiOnce(List<Car> serverCars) async {
    final p = _prefs;
    final uid = _userId;
    final apiRepo = _repo;
    if (p == null || uid == null || apiRepo is! ApiCarRepository) return;
    const flagKeyPrefix = 'garage_migrated_to_api_v1_';
    final flagKey = flagKeyPrefix + uid;
    if (p.getBool(flagKey) == true) return;
    final raw = p.getString('cars_$uid');
    if (raw == null || raw.isEmpty) {
      await p.setBool(flagKey, true);
      return;
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>?;
      if (decoded == null || decoded.isEmpty) {
        await p.remove('cars_$uid');
        await p.setBool(flagKey, true);
        return;
      }
      final localCars = decoded.map((e) => Car.fromJson(e as Map<String, dynamic>)).toList();
      if (serverCars.isEmpty) {
        for (final c in localCars) {
          await apiRepo.addCar(
            brandName: c.brand,
            modelName: c.model,
            generation: c.generation,
            brandId: c.brandId,
            modelId: c.modelId,
            generationId: c.generationId,
            year: c.year,
            licensePlate: c.plateNumber,
            mileage: c.mileage,
            vin: c.vin,
            nickname: c.nickname,
            engineType: c.engineType,
            transmission: c.transmission,
            drivetrain: c.drivetrain,
            bodyType: c.bodyType,
            color: c.color,
            preferredId: c.id,
          );
          final ph = c.photoUrl?.trim();
          if (ph != null &&
              ph.isNotEmpty &&
              !ph.startsWith('http://') &&
              !ph.startsWith('https://')) {
            await apiRepo.updateCarPhoto(c.id, ph);
          }
        }
      }
      await p.remove('cars_$uid');
      // Не трогаем garage_hidden_merge_car_ids_* — иначе после обновления снова подмешиваются
      // удалённые пользователем авто из заказов (mergeCarsFromOrders).
      await p.setBool(flagKey, true);
    } catch (_) {
      await p.setBool(flagKey, true);
    }
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
      final p = _prefs;
      final uid = _userId;
      if (p != null && uid != null) {
        await MileagePromptStorage.markNow(p, uid, car.id);
      }
      return car;
    }
    return null;
  }

  Future<bool> updateMileage(String carId, int newMileage) async {
    final result = await _repo.updateMileage(carId, newMileage);
    if (result.dataOrNull != null) {
      final p = _prefs;
      final uid = _userId;
      if (p != null && uid != null) {
        await MileagePromptStorage.markNow(p, uid, carId);
      }
      await loadCars();
      return true;
    }
    return false;
  }

  Future<bool> updateCarPhoto(String carId, String? photoUrl) async {
    final result = await _repo.updateCarPhoto(carId, photoUrl);
    final car = result.dataOrNull;
    if (car != null) {
      _replaceCarInState(car);
      await loadCars(silent: true);
      return true;
    }
    return false;
  }

  Future<bool> deleteCar(String id) async {
    if (id.isEmpty) return false;
    await _rememberGarageHiddenCarId(id);
    _ref.read(maintenanceRemindersProvider.notifier).removeAllDataForCar(id);
    _ref.read(carDocumentsProvider.notifier).removeAllDocumentsForCar(id);
    final result = await _repo.deleteCar(id);
    await loadCars();
    final couldPersistHide =
        _prefs != null && _userId != null && _userId.isNotEmpty;
    // Скрытие в prefs уже не даёт машине вернуться из merge; при ошибке API всё равно считаем успехом.
    if (result.errorOrNull != null && !couldPersistHide) {
      return false;
    }
    return true;
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
      final p = _prefs;
      final uid = _userId;
      if (p != null && uid != null) {
        await MileagePromptStorage.markNow(p, uid, id);
      }
      return true;
    }
    return false;
  }

  /// PATCH марки/модели/поколения (ответ сервера — актуальная карточка).
  Future<Car?> patchCarGarageReference(
    String id, {
    required String brand,
    required String model,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    String? nickname,
  }) async {
    final result = await _repo.patchCarGarageReference(
      id,
      brand: brand,
      model: model,
      generation: generation,
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      nickname: nickname,
    );
    final car = result.dataOrNull;
    if (car != null) {
      _replaceCarInState(car);
      await loadCars(silent: true);
      final list = state.valueOrNull;
      if (list != null) {
        Car? refreshed;
        for (final c in list) {
          if (c.id == car.id) {
            refreshed = c;
            break;
          }
        }
        if (refreshed != null &&
            refreshed.hasManualReferencePending &&
            !car.hasManualReferencePending) {
          _replaceCarInState(car);
        }
      }
    }
    return car;
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

  /// Результат с текстом ошибки от API (тариф/лимиты — у организации, не у клиента).
  Future<Result<ChatMessage>> sendMessageWithMedia(
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
    }
    return result;
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
    String? preferredId,
    bool mergedFromOrders = false,
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
  Future<Result<Car>> patchCarGarageReference(
    String id, {
    required String brand,
    required String model,
    String? generation,
    int? brandId,
    int? modelId,
    int? generationId,
    String? nickname,
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

  @override
  Future<Result<int>> mergeCarsFromOrders(
    Iterable<Order> orders, {
    Set<String> skipCarIds = const {},
  }) async =>
      Result.success(0);
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
    scheduleClientAppStatePush();
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

  void removeAllDocumentsForCar(String carId) {
    if (carId.isEmpty) return;
    state = state.where((d) => d.carId != carId).toList();
    _save();
  }

  List<CarDocument> forCar(String carId) =>
      state.where((d) => d.carId == carId).toList();
}

/// Заметки профиля по авто: SharedPreferences + синхронизация через [client_app_state_sync].
final profileNotesProvider =
    StateNotifierProvider<ProfileNotesNotifier, List<ProfileNote>>((ref) {
      final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
      final userId = ref.watch(authProvider).user?.id;
      return ProfileNotesNotifier(prefs, userId);
    });

class ProfileNotesNotifier extends StateNotifier<List<ProfileNote>> {
  ProfileNotesNotifier(this._prefs, this._userId) : super(_load(_prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;

  String get _key => ClientAppStateSchema.profileNotesPrefix + (_userId ?? '');

  static List<ProfileNote> _load(SharedPreferences? prefs, String? userId) {
    if (prefs == null || userId == null || userId.isEmpty) return [];
    final raw = prefs.getString(ClientAppStateSchema.profileNotesPrefix + userId);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return [];
      return list
          .map((e) => ProfileNote.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  void _save() {
    if (_prefs == null || _userId == null || _userId!.isEmpty) return;
    _prefs!.setString(_key, jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  void add(ProfileNote n) {
    if (_userId == null) return;
    state = [...state, n];
    _save();
    _scheduleSync();
  }

  void update(ProfileNote n) {
    state = state.map((e) => e.id == n.id ? n : e).toList();
    _save();
    _scheduleSync();
  }

  void remove(String id) {
    state = state.where((e) => e.id != id).toList();
    _save();
    _scheduleSync();
  }

  void _scheduleSync() {
    scheduleClientAppStatePush();
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
          packageDurationMinutes:
              (m['package_duration_minutes'] as num?)?.toInt() ?? 0,
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
                  extraDurationMinutes:
                      (a['extra_duration_minutes'] as num?)?.toInt() ?? 0,
                ),
              )
              .where((a) => a.serviceId.isNotEmpty)
              .toList(),
        ),
      )
      .where((p) => p.id.isNotEmpty)
      .toList();
});
