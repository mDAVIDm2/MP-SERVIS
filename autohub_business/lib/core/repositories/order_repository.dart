import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/models/order_model.dart';
import '../../shared/models/staff_model.dart';
import '../api/api_exceptions.dart';
import '../api/services/api_services_providers.dart';
import '../api/services/order_api_service.dart';
import '../ws/ws_client.dart';
import '../ws/ws_provider.dart';
import '../auth/auth_provider.dart';
import 'staff_repository.dart';

/// Мастер в организации (для назначения на заказ).
class StaffMember {
  final String id;
  final String name;
  final String? roleLabel;

  const StaffMember({required this.id, required this.name, this.roleLabel});
}

/// Репозиторий заказов: загрузка из API, обновления по WebSocket, мутации через API.
class OrderRepository extends StateNotifier<List<Order>> {
  OrderRepository(this._api, this._ws) : super([]) {
    _wsSub = _ws.events.where((e) =>
      e.type == 'order_updated' || e.type == 'order_created' || e.type == 'order').listen(_onWsEvent);
  }

  final OrderApiService _api;
  final WsClient _ws;
  StreamSubscription<WsEvent>? _wsSub;
  CancelToken? _loadOrdersToken;
  Future<void>? _loadOrdersInFlight;

  /// Сообщение последней неудачной загрузки списка заказов (null — ок или ещё не было ошибки).
  String? ordersLoadError;
  /// После первого завершения [loadFromApi] (успех или ошибка) — чтобы не скрывать чаты по заказам до ответа API.
  bool ordersInitialLoadComplete = false;

  void _onWsEvent(WsEvent e) {
    final payload = e.payload;
    if (payload.isEmpty) return;
    try {
      Order order = Order.fromJson(payload);
      if (order.items.isEmpty) {
        final prev = state.where((o) => o.id == order.id).firstOrNull;
        if (prev != null && prev.items.isNotEmpty) {
          order = order.copyWith(
            items: prev.items,
            clientAvatarUrl: order.clientAvatarUrl ?? prev.clientAvatarUrl,
            carPhotoUrl: order.carPhotoUrl ?? prev.carPhotoUrl,
          );
        }
      }
      state = [...state.where((o) => o.id != order.id), order];
      state = state.where((o) => !o.isHiddenFromUser).toList();
    } catch (_) {}
  }

  /// Очистить все заказы в БД (API) и локально. При успехе state = [].
  /// Возвращает true при успехе, false при ошибке API.
  Future<bool> clearAllOrders() async {
    final result = await _api.deleteAllOrders();
    if (result.errorOrNull != null) return false;
    state = [];
    return true;
  }

  /// Загрузить заказы с бэкенда. При ошибке API демо не подставляем — список не меняется.
  /// Если API вернул заказ с пустым items, сохраняем прежний состав из state.
  /// Параллельные вызовы сливаются в один Future.
  Future<void> loadFromApi() async {
    if (_loadOrdersInFlight != null) return _loadOrdersInFlight!;
    final run = _loadOrdersFromApi();
    _loadOrdersInFlight = run;
    try {
      await run;
    } finally {
      _loadOrdersInFlight = null;
    }
  }

  Future<void> _loadOrdersFromApi() async {
    if (kDebugMode) {
      debugPrint('[ChatOrderDebug] OrderRepository.loadFromApi | START | currentStateCount=${state.length}');
    }
    try {
      _loadOrdersToken?.cancel();
      _loadOrdersToken = CancelToken();
      final result = await _api.getOrders(cancelToken: _loadOrdersToken);
      if (result.dataOrNull != null) {
        ordersLoadError = null;
        final incoming = result.dataOrNull!.where((o) => !o.isHiddenFromUser).toList();
        state = incoming.map((o) {
          if (o.items.isNotEmpty) return o;
          final prev = state.where((e) => e.id == o.id).firstOrNull;
          return prev != null && prev.items.isNotEmpty
              ? o.copyWith(
                  items: prev.items,
                  clientAvatarUrl: o.clientAvatarUrl ?? prev.clientAvatarUrl,
                  carPhotoUrl: o.carPhotoUrl ?? prev.carPhotoUrl,
                )
              : o;
        }).toList();
        if (kDebugMode) {
          debugPrint('[ChatOrderDebug] OrderRepository.loadFromApi | state updated | newCount=${state.length} orderIds=${state.take(3).map((o) => o.id).join(';')}');
        }
        return;
      }
      ordersLoadError = result.errorOrNull?.message ?? 'Не удалось загрузить заказы';
      state = [...state];
      if (kDebugMode) {
        final err = result.errorOrNull;
        debugPrint(
          '[ChatOrderDebug] OrderRepository.loadFromApi | no data (error) | ordersLoadError=$ordersLoadError'
          '${err != null ? ' | code=${err.code.code}' : ''}',
        );
      }
    } finally {
      ordersInitialLoadComplete = true;
    }
  }

  /// Перезапросить один заказ с сервера. При пустом items сохраняем прежний состав.
  Future<void> refreshOrder(String orderId) async {
    final result = await _api.getOrder(orderId);
    final order = result.dataOrNull;
    if (order != null) {
      Order merged = order;
      if (order.items.isEmpty) {
        final prev = state.where((o) => o.id == orderId).firstOrNull;
        if (prev != null && prev.items.isNotEmpty) {
          merged = order.copyWith(
            items: prev.items,
            clientAvatarUrl: order.clientAvatarUrl ?? prev.clientAvatarUrl,
            carPhotoUrl: order.carPhotoUrl ?? prev.carPhotoUrl,
          );
        }
      }
      state = [...state.where((o) => o.id != orderId), merged];
    }
  }

  @override
  void dispose() {
    _wsSub?.cancel();
    _wsSub = null;
    super.dispose();
  }

  Order? getById(String id) {
    try {
      return state.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Order> get activeOrders =>
      state.where((o) => o.status.isActive).toList()..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));

  List<Order> get historyOrders =>
      state.where((o) => !o.status.isActive).toList()..sort((a, b) => b.effectiveDateTime.compareTo(a.effectiveDateTime));

  List<Order> ordersForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return state
        .where((o) => !o.effectiveDateTime.isBefore(start) && o.effectiveDateTime.isBefore(end))
        .toList()
      ..sort((a, b) => a.effectiveDateTime.compareTo(b.effectiveDateTime));
  }

  List<Order> get todayOrders => ordersForDate(DateTime.now());

  /// Заказы, требующие внимания: новые заявки и ожидающие согласования.
  List<Order> get attentionOrders => state
      .where((o) =>
          o.status == OrderStatus.pendingConfirmation || o.status == OrderStatus.pendingApproval)
      .toList();

  void updateOrder(Order order) {
    state = [
      for (final o in state) if (o.id == order.id) order else o,
    ];
  }

  /// Подставить состав заказа из fallback (например из чата), только если у заказа пустой items.
  /// Чтобы новые заказы показывали позиции везде (список заказов, mini-card, панель) и по ним работало «отметить выполненной».
  void setOrderItemsIfEmpty(String orderId, List<OrderItem> items) {
    if (items.isEmpty) return;
    state = [
      for (final o in state)
        if (o.id == orderId && o.items.isEmpty) o.copyWith(items: items) else o,
    ];
  }

  /// Организация подтверждает согласование за клиента («подтвердить по телефону»). Применяет черновик, восстанавливает статус. Возвращает обновлённый заказ при успехе.
  Future<Result<Order>> confirmOrderByPhone(String orderId) async {
    final result = await _api.confirmOrderByPhone(orderId);
    final order = result.dataOrNull;
    if (order != null) {
      state = [...state.where((o) => o.id != orderId), order];
      return Result.success(order);
    }
    return Result.failure(result.errorOrNull ?? const ApiException(code: ApiErrorCode.network, message: 'Не удалось подтвердить'));
  }

  /// Смена статуса заказа. При ошибке API откатывает state. Возвращает Result для показа сообщения в UI.
  Future<Result<void>> setOrderStatus(String orderId, OrderStatus status) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(status: status));
    final result = await _api.setOrderStatus(orderId, status);
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    return Result.success(null);
  }

  /// Назначение мастера. При ошибке API откатывает state.
  Future<Result<void>> assignMaster(String orderId, StaffMember master) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(masterId: master.id, masterName: master.name));
    final result = await _api.patchOrderAssignment(orderId, <String, dynamic>{'master_id': master.id});
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    await refreshOrder(orderId);
    final after = getById(orderId);
    if (after != null &&
        master.id.isNotEmpty &&
        (after.masterId == null || after.masterId!.isEmpty)) {
      updateOrder(after.copyWith(masterId: master.id, masterName: master.name));
    }
    return Result.success(null);
  }

  /// Снять мастера с заказа (в нераспределённые). При ошибке API откатывает state.
  Future<Result<void>> clearMaster(String orderId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(clearMaster: true));
    final result = await _api.patchOrderAssignment(orderId, <String, dynamic>{'master_id': null});
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    await refreshOrder(orderId);
    return Result.success(null);
  }

  /// Назначить или снять пост (именованный бокс из настроек).
  Future<Result<void>> assignBay(String orderId, String? bayId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(bayId: bayId, bayName: null));
    final result = await _api.patchOrderAssignment(orderId, <String, dynamic>{'bay_id': bayId});
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    await refreshOrder(orderId);
    return Result.success(null);
  }

  /// Ручная корректировка планового времени заказа (С / По).
  Future<Result<void>> updateOrderTime(String orderId, {DateTime? plannedStartTime, DateTime? plannedEndTime}) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(
      plannedStartTime: plannedStartTime ?? order.plannedStartTime,
      plannedEndTime: plannedEndTime ?? order.plannedEndTime,
    ));
    final result = await _api.updateOrderTime(orderId, plannedStartTime: plannedStartTime, plannedEndTime: plannedEndTime);
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    await refreshOrder(orderId);
    return Result.success(null);
  }

  /// Добавить доп. работу к заказу (мастер запрашивает — позиция с isAdditional: true).
  Future<bool> addExtraWorkItem(String orderId, String name, int estimatedMinutes) async {
    final order = getById(orderId);
    if (order == null) return false;
    final newItem = OrderItem(
      id: 'extra_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      estimatedMinutes: estimatedMinutes,
      isAdditional: true,
    );
    final updatedItems = [...order.items, newItem];
    final result = await _api.patchOrderItems(orderId, updatedItems);
    final updated = result.dataOrNull;
    if (updated != null) {
      updateOrder(updated);
      return true;
    }
    return false;
  }

  /// Заменить перечень позиций заказа (подтверждение/корректировка заявки). При ошибке API state не меняется.
  Future<Result<Order>> replaceOrderItems(String orderId, List<OrderItem> items) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final result = await _api.patchOrderItems(orderId, items);
    final updated = result.dataOrNull;
    if (updated != null) {
      updateOrder(updated);
      return Result.success(updated);
    }
    return Result.failure(result.errorOrNull ?? const ApiException(code: ApiErrorCode.network, message: 'Не удалось обновить'));
  }

  /// Отметить позицию заказа выполненной. При ошибке API state не меняется.
  /// Если API вернул заказ с пустым items, в state сохраняем локально собранный состав.
  Future<Result<void>> completeOrderItem(String orderId, String itemId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final items = order.items
        .map((i) => i.id == itemId ? i.copyWith(isCompleted: true) : i)
        .toList();
    final result = await _api.patchOrderItems(orderId, items);
    final updated = result.dataOrNull;
    if (updated != null) {
      final toApply = updated.items.isEmpty ? updated.copyWith(items: items) : updated;
      updateOrder(toApply);
      return Result.success(null);
    }
    return Result.failure(result.errorOrNull ?? const ApiException(code: ApiErrorCode.network, message: 'Не удалось обновить'));
  }

  /// Отменить выполнение позиции заказа (повторный клик по задаче). При ошибке API state не меняется.
  /// Если API вернул заказ с пустым items, в state сохраняем локально собранный состав.
  Future<Result<void>> uncompleteOrderItem(String orderId, String itemId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final items = order.items
        .map((i) => i.id == itemId ? i.copyWith(isCompleted: false) : i)
        .toList();
    final result = await _api.patchOrderItems(orderId, items);
    final updated = result.dataOrNull;
    if (updated != null) {
      final toApply = updated.items.isEmpty ? updated.copyWith(items: items) : updated;
      updateOrder(toApply);
      return Result.success(null);
    }
    return Result.failure(result.errorOrNull ?? const ApiException(code: ApiErrorCode.network, message: 'Не удалось обновить'));
  }

  /// Скрыть заказ из отображения (soft delete: в БД остаётся с пометкой). Пользователь больше не видит заказ нигде.
  Future<Result<void>> hideOrderFromUser(String orderId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final result = await _api.hideOrderFromUser(orderId);
    if (result.errorOrNull != null) return Result.failure(result.errorOrNull!);
    state = state.where((o) => o.id != orderId).toList();
    return Result.success(null);
  }

  /// Удалить заказ из системы (hard delete). Разрешено только для статусов: отменён, завершён, готово к выдаче.
  /// При ошибке API state не меняется.
  Future<Result<void>> deleteOrder(String orderId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final allowed = order.status == OrderStatus.cancelled ||
        order.status == OrderStatus.done ||
        order.status == OrderStatus.completed;
    if (!allowed) {
      return Result.failure(const ApiException(
        code: ApiErrorCode.internal,
        message: 'Удалить можно только заказ со статусом «Отменён», «Завершён» или «Готово к выдаче»',
      ));
    }
    final result = await _api.deleteOrder(orderId);
    if (result.errorOrNull != null) return Result.failure(result.errorOrNull!);
    state = state.where((o) => o.id != orderId).toList();
    return Result.success(null);
  }

  /// Отмена заказа (POST cancel). При ошибке API откатывает state.
  Future<Result<void>> cancelOrder(String orderId) async {
    final order = getById(orderId);
    if (order == null) return Result.failure(const ApiException(code: ApiErrorCode.internal, message: 'Заказ не найден'));
    final previous = order;
    updateOrder(order.copyWith(status: OrderStatus.cancelled));
    final result = await _api.cancelOrder(orderId);
    if (result.errorOrNull != null) {
      updateOrder(previous);
      return Result.failure(result.errorOrNull!);
    }
    return Result.success(null);
  }

  /// Создать заказ: запрос к API, при успехе — добавить в state; при ошибке — добавить локально.
  Future<Order> addOrderAsync(Order order) async {
    final result = await _api.createOrder(
      carId: order.carId,
      carInfo: order.carInfo,
      dateTime: order.dateTime ?? DateTime.utc(0),
      items: order.items,
      clientName: order.clientName,
      clientPhone: order.clientPhone,
      comment: order.comment,
      vin: order.vin,
      licensePlate: order.licensePlate,
      bodyType: order.bodyType,
      color: order.color,
      mileage: order.mileage,
      engineType: order.engineType,
      bayId: order.bayId,
    );
    if (result.dataOrNull != null) {
      state = [...state, result.dataOrNull!];
      return result.dataOrNull!;
    }
    final nextNum = state.isEmpty ? 1 : state.length + 1;
    final orderNumber = '#2024-${nextNum.toString().padLeft(3, '0')}';
    final newOrder = order.copyWith(
      orderNumber: orderNumber,
      id: order.id.isEmpty ? 'order_${DateTime.now().millisecondsSinceEpoch}' : order.id,
    );
    state = [...state, newOrder];
    return newOrder;
  }
}

final orderRepositoryProvider =
    StateNotifierProvider<OrderRepository, List<Order>>((ref) {
  final api = ref.watch(orderApiServiceProvider);
  final ws = ref.watch(wsClientProvider);
  final repo = OrderRepository(api, ws);
  ref.onDispose(() => repo.dispose());
  Future.microtask(() => repo.loadFromApi());
  return repo;
});

/// Текущий заказ по id (обновляется при изменении репозитория).
Order? _orderById(List<Order> list, String id) {
  try {
    return list.firstWhere((o) => o.id == id);
  } catch (_) {
    return null;
  }
}

final orderByIdProvider = Provider.family<Order?, String>((ref, orderId) {
  final list = ref.watch(orderRepositoryProvider);
  return _orderById(list, orderId);
});

/// Текст ошибки загрузки заказов; подписывайтесь через [ref.watch], список заказов тоже участвует в инвалидации.
final ordersLoadErrorProvider = Provider<String?>((ref) {
  ref.watch(orderRepositoryProvider);
  return ref.read(orderRepositoryProvider.notifier).ordersLoadError;
});

/// Можно сужать список чатов по `orderId`, только когда заказы уже получены с сервера без ошибки.
final ordersSyncReadyForChatFilterProvider = Provider<bool>((ref) {
  ref.watch(orderRepositoryProvider);
  final n = ref.read(orderRepositoryProvider.notifier);
  return n.ordersInitialLoadComplete && n.ordersLoadError == null;
});

/// Список активных мастеров для назначения на заказ (из репозитория персонала).
final staffListProvider = Provider<List<StaffMember>>((ref) {
  final user = ref.watch(authProvider).user;
  var staff = ref.watch(staffRepositoryProvider).where((e) => e.isActive).toList();
  if (user != null && user.role == BusinessRole.solo && user.id.isNotEmpty) {
    final matched = staff.where((e) => e.userId != null && e.userId == user.id).toList();
    if (matched.isNotEmpty) {
      staff = matched;
    } else {
      final mastersOnly = staff.where((e) => e.isActive && e.role == StaffRole.master).toList();
      staff = mastersOnly.length == 1 ? mastersOnly : matched;
    }
  }
  return staff.map((e) => StaffMember(id: e.id, name: e.name, roleLabel: e.roleLabel)).toList();
});

/// Нормализация телефона для сравнения (только цифры; для РФ 8 в начале → 7).
String _normalizePhone(String? phone) {
  if (phone == null) return '';
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('8')) return '7${digits.substring(1)}';
  return digits;
}

/// Для роли Master: id сотрудника (StaffEntry) в списке персонала, привязанного к текущему пользователю по телефону.
/// Используется в «Мои задачи» и «Расписание», чтобы показывать заказы, назначенные на этого мастера.
final currentMasterStaffIdProvider = Provider<String?>((ref) {
  final user = ref.watch(authProvider).user;
  if (user == null || user.role != BusinessRole.master) return null;
  final staffList = ref.watch(staffRepositoryProvider);
  for (final e in staffList) {
    if (e.isActive && e.userId != null && e.userId == user.id) return e.id;
  }
  final normalizedUser = _normalizePhone(user.phone);
  if (normalizedUser.isEmpty) return null;
  for (final e in staffList) {
    if (e.isActive && _normalizePhone(e.phone) == normalizedUser) return e.id;
  }
  return null;
});
