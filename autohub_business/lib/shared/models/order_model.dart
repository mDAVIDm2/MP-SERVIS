import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Статусы заказа — идентичны клиентскому приложению (один бэкенд).
enum OrderStatus {
  pendingConfirmation,
  confirmed,
  inProgress,
  pendingApproval,
  completed,
  done,
  cancelled;

  String get label {
    switch (this) {
      case OrderStatus.pendingConfirmation:
        return 'Ожидает подтверждения';
      case OrderStatus.confirmed:
        return 'Подтверждён';
      case OrderStatus.inProgress:
        return 'В работе';
      case OrderStatus.pendingApproval:
        return 'Требуется согласование';
      case OrderStatus.completed:
        return 'Готово к выдаче';
      case OrderStatus.done:
        return 'Завершён';
      case OrderStatus.cancelled:
        return 'Отменён';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pendingConfirmation:
        return AppColors.statusPending;
      case OrderStatus.confirmed:
        return AppColors.statusConfirmed;
      case OrderStatus.inProgress:
        return AppColors.statusInProgress;
      case OrderStatus.pendingApproval:
        return AppColors.statusApproval;
      case OrderStatus.completed:
        return AppColors.statusCompleted;
      case OrderStatus.done:
        return AppColors.statusDone;
      case OrderStatus.cancelled:
        return AppColors.statusCancelled;
    }
  }

  bool get isActive => this != OrderStatus.done && this != OrderStatus.cancelled;
}

class OrderItem {
  final String id;
  final String name;
  final int? priceKopecks; // null для мастера (не видит цены)
  final int estimatedMinutes;
  final bool isCompleted;
  final bool isAdditional;

  const OrderItem({
    required this.id,
    required this.name,
    this.priceKopecks,
    this.estimatedMinutes = 60,
    this.isCompleted = false,
    this.isAdditional = false,
  });

  OrderItem copyWith({
    String? id,
    String? name,
    int? priceKopecks,
    int? estimatedMinutes,
    bool? isCompleted,
    bool? isAdditional,
  }) {
    return OrderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      priceKopecks: priceKopecks ?? this.priceKopecks,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      isAdditional: isAdditional ?? this.isAdditional,
    );
  }

  String get durationLabel {
    if (estimatedMinutes < 60) return '$estimatedMinutes мин';
    final h = estimatedMinutes / 60;
    return estimatedMinutes % 60 == 0 ? '${h.toInt()} ч' : '${h.toStringAsFixed(1)} ч';
  }

  /// Парсит элемент заказа. id может быть строкой ('proposed_0') или числом — всегда приводим к String.
  /// Поддерживаются ключи snake_case (price_kopecks, estimated_minutes) как в ответе API.
  static OrderItem fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final priceVal = j['price_kopecks'] ?? j['priceKopecks'];
    final minutesVal = j['estimated_minutes'] ?? j['estimatedMinutes'];
    final priceKopecks = priceVal == null ? null : (priceVal is num ? priceVal.toInt() : int.tryParse(priceVal.toString()));
    final estimatedMinutes = minutesVal == null ? 60 : (minutesVal is num ? minutesVal.toInt() : int.tryParse(minutesVal.toString()) ?? 60);
    return OrderItem(
      id: id == null ? '' : id.toString(),
      name: j['name'] as String? ?? '',
      priceKopecks: priceKopecks,
      estimatedMinutes: estimatedMinutes.clamp(0, 9999),
      isCompleted: j['is_completed'] as bool? ?? false,
      isAdditional: j['is_additional'] as bool? ?? false,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String carId;
  final String? clientName;   // для списка; у мастера может быть скрыт
  final String? clientPhone;  // только для Admin/Owner/Solo
  final String carInfo;       // "Toyota Camry, А123АА777"
  final String? vin;
  final String? licensePlate;
  final String? bodyType;
  final String? color;
  final int? mileage;
  final String? engineType;
  final OrderStatus status;
  /// Дата/время приёма. null при невалидном ответе API — не подставляем текущее время.
  final DateTime? dateTime;
  /// Плановое начало и окончание (бронь «с — по»).
  final DateTime? plannedStartTime;
  final DateTime? plannedEndTime;
  final List<OrderItem> items;
  /// При pending_approval — предлагаемый состав из последнего запроса согласования (только отображение; items остаётся из БД).
  final List<OrderItem>? approvalPreviewItems;
  final int? approvalPreviewTotalKopecks;
  final int? approvalPreviewEstimatedMinutes;
  final String? comment;
  final String? masterId;
  final String? masterName;
  final String? bayId;
  final String? bayName;
  /// Данные организации с API (для PDF и подписей).
  final String? organizationName;
  final String? organizationAddress;
  final String? organizationPhone;
  /// Код вида точки с API (`organization_business_kind`): sto, car_wash, …
  final String? organizationBusinessKind;
  /// `staff_based` | `bay_based` — снимок на момент выдачи заказа.
  final String? organizationSchedulingMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Скрыт для пользователя (удалён из отображения, в БД хранится с пометкой).
  final bool isHiddenFromUser;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.carId,
    this.clientName,
    this.clientPhone,
    required this.carInfo,
    this.vin,
    this.licensePlate,
    this.bodyType,
    this.color,
    this.mileage,
    this.engineType,
    required this.status,
    this.dateTime,
    this.plannedStartTime,
    this.plannedEndTime,
    required this.items,
    this.approvalPreviewItems,
    this.approvalPreviewTotalKopecks,
    this.approvalPreviewEstimatedMinutes,
    this.comment,
    this.masterId,
    this.masterName,
    this.bayId,
    this.bayName,
    this.organizationName,
    this.organizationAddress,
    this.organizationPhone,
    this.organizationBusinessKind,
    this.organizationSchedulingMode,
    this.createdAt,
    this.updatedAt,
    this.isHiddenFromUser = false,
  });

  bool get hasApprovalPreview =>
      status == OrderStatus.pendingApproval &&
      approvalPreviewItems != null &&
      approvalPreviewItems!.isNotEmpty;

  /// Состав для карточек и списков: при ожидании согласования — черновик из чата.
  List<OrderItem> get itemsForDisplay => hasApprovalPreview ? approvalPreviewItems! : items;

  int get totalKopecksForDisplay {
    if (status == OrderStatus.pendingApproval && approvalPreviewTotalKopecks != null) {
      return approvalPreviewTotalKopecks!;
    }
    return totalKopecks;
  }

  int get estimatedMinutesForDisplay {
    if (status == OrderStatus.pendingApproval && approvalPreviewEstimatedMinutes != null) {
      return approvalPreviewEstimatedMinutes!;
    }
    return items.fold<int>(0, (s, i) => s + i.estimatedMinutes);
  }

  /// Время для сортировки в ленте чата: при «требует согласования» — по обновлению, иначе по созданию.
  DateTime get timelineSortAt {
    if (status == OrderStatus.pendingApproval && updatedAt != null) return updatedAt!;
    return createdAt ?? dateTime ?? DateTime.utc(0);
  }

  /// Для сортировки и сравнения: дата приёма или sentinel при null (не подставляем текущее время).
  DateTime get effectiveDateTime => dateTime ?? DateTime.utc(0);

  int get totalKopecks => items
      .where((i) => i.priceKopecks != null)
      .fold(0, (sum, item) => sum + (item.priceKopecks ?? 0));

  int get completedCount => items.where((i) => i.isCompleted).length;
  int get totalCount => items.length;

  /// Номер для UI: один символ `#` в начале (API может отдавать уже с `#`).
  String get displayNumber {
    var s = orderNumber.trim();
    while (s.startsWith('#')) {
      s = s.substring(1).trim();
    }
    return s.isEmpty ? orderNumber.trim() : '#$s';
  }

  Order copyWith({
    String? id,
    String? orderNumber,
    String? carId,
    String? clientName,
    String? clientPhone,
    String? carInfo,
    String? vin,
    String? licensePlate,
    String? bodyType,
    String? color,
    int? mileage,
    String? engineType,
    OrderStatus? status,
    DateTime? dateTime,
    DateTime? plannedStartTime,
    DateTime? plannedEndTime,
    List<OrderItem>? items,
    List<OrderItem>? approvalPreviewItems,
    int? approvalPreviewTotalKopecks,
    int? approvalPreviewEstimatedMinutes,
    String? comment,
    String? masterId,
    String? masterName,
    String? bayId,
    String? bayName,
    String? organizationName,
    String? organizationAddress,
    String? organizationPhone,
    String? organizationBusinessKind,
    String? organizationSchedulingMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isHiddenFromUser,
    bool clearMaster = false,
    bool clearBay = false,
    bool clearApprovalPreview = false,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      carId: carId ?? this.carId,
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      carInfo: carInfo ?? this.carInfo,
      vin: vin ?? this.vin,
      licensePlate: licensePlate ?? this.licensePlate,
      bodyType: bodyType ?? this.bodyType,
      color: color ?? this.color,
      mileage: mileage ?? this.mileage,
      engineType: engineType ?? this.engineType,
      status: status ?? this.status,
      dateTime: dateTime ?? this.dateTime,
      plannedStartTime: plannedStartTime ?? this.plannedStartTime,
      plannedEndTime: plannedEndTime ?? this.plannedEndTime,
      items: items ?? this.items,
      approvalPreviewItems: clearApprovalPreview ? null : (approvalPreviewItems ?? this.approvalPreviewItems),
      approvalPreviewTotalKopecks:
          clearApprovalPreview ? null : (approvalPreviewTotalKopecks ?? this.approvalPreviewTotalKopecks),
      approvalPreviewEstimatedMinutes:
          clearApprovalPreview ? null : (approvalPreviewEstimatedMinutes ?? this.approvalPreviewEstimatedMinutes),
      comment: comment ?? this.comment,
      masterId: clearMaster ? null : (masterId ?? this.masterId),
      masterName: clearMaster ? null : (masterName ?? this.masterName),
      bayId: clearBay ? null : (bayId ?? this.bayId),
      bayName: clearBay ? null : (bayName ?? this.bayName),
      organizationName: organizationName ?? this.organizationName,
      organizationAddress: organizationAddress ?? this.organizationAddress,
      organizationPhone: organizationPhone ?? this.organizationPhone,
      organizationBusinessKind: organizationBusinessKind ?? this.organizationBusinessKind,
      organizationSchedulingMode: organizationSchedulingMode ?? this.organizationSchedulingMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isHiddenFromUser: isHiddenFromUser ?? this.isHiddenFromUser,
    );
  }

  static OrderStatus _statusFromString(String? s) {
    if (s == null) return OrderStatus.pendingConfirmation;
    final normalized = (s as String).toLowerCase().replaceAll(' ', '_').replaceAll('_', '');
    for (final e in OrderStatus.values) {
      if (e.name.toLowerCase() == normalized) return e;
    }
    return OrderStatus.pendingConfirmation;
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String? _orgKindFromApi(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim().toLowerCase().replaceAll('-', '_');
    return s.isEmpty ? null : s;
  }

  static String? _schedulingModeFromApi(dynamic v) {
    final s = _orgKindFromApi(v);
    if (s == null) return null;
    if (s == 'bay_based' || s == 'staff_based') return s;
    return null;
  }

  static Order fromJson(Map<String, dynamic> j) {
    final itemsRaw = j['items'] as List<dynamic>?;
    final items = <OrderItem>[];
    if (itemsRaw != null) {
      for (final e in itemsRaw) {
        if (e is! Map<String, dynamic>) continue;
        try {
          items.add(OrderItem.fromJson(e));
        } catch (_) {
          // Пропускаем битый элемент (например, неверный тип id), чтобы не терять весь заказ.
        }
      }
    }
    final plannedStart = j['planned_start_time'] != null ? DateTime.tryParse(j['planned_start_time'].toString()) : null;
    final plannedEnd = j['planned_end_time'] != null ? DateTime.tryParse(j['planned_end_time'].toString()) : null;
    final createdAt = j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null;
    final updatedAt = j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null;
    final hidden = j['hidden_from_user'] as bool? ?? false;
    final mileageRaw = j['mileage'];
    final mileage = mileageRaw == null ? null : (mileageRaw is num ? mileageRaw.toInt() : int.tryParse(mileageRaw.toString()));
    List<OrderItem>? previewItems;
    int? previewTotalK;
    int? previewMins;
    final apRaw = j['approval_preview'];
    if (apRaw is Map<String, dynamic>) {
      final pi = apRaw['items'] as List<dynamic>?;
      if (pi != null && pi.isNotEmpty) {
        previewItems = <OrderItem>[];
        for (final e in pi) {
          if (e is! Map<String, dynamic>) continue;
          try {
            previewItems.add(OrderItem.fromJson(e));
          } catch (_) {}
        }
        if (previewItems.isEmpty) previewItems = null;
      }
      final tk = apRaw['total_kopecks'] ?? apRaw['totalKopecks'];
      if (tk is num) previewTotalK = tk.toInt();
      final em = apRaw['estimated_minutes'] ?? apRaw['estimatedMinutes'];
      if (em is num) previewMins = em.toInt();
    }
    return Order(
      id: j['id'] as String? ?? '',
      orderNumber: j['order_number'] as String? ?? '',
      carId: j['car_id'] as String? ?? '',
      clientName: j['client_name'] as String?,
      clientPhone: j['client_phone'] as String?,
      carInfo: j['car_info'] as String? ?? '',
      vin: j['vin'] as String?,
      licensePlate: j['license_plate'] as String?,
      bodyType: j['body_type'] as String?,
      color: j['color'] as String?,
      mileage: mileage,
      engineType: j['engine_type'] as String?,
      status: _statusFromString(j['status'] as String?),
      dateTime: _parseDateTime(j['date_time']),
      plannedStartTime: plannedStart,
      plannedEndTime: plannedEnd,
      items: items,
      approvalPreviewItems: previewItems,
      approvalPreviewTotalKopecks: previewTotalK,
      approvalPreviewEstimatedMinutes: previewMins,
      comment: j['comment'] as String?,
      masterId: j['master_id'] as String?,
      masterName: j['master_name'] as String?,
      bayId: j['bay_id'] as String?,
      bayName: j['bay_name'] as String?,
      organizationName: j['organization_name']?.toString(),
      organizationAddress: j['organization_address']?.toString(),
      organizationPhone: j['organization_phone']?.toString(),
      organizationBusinessKind: _orgKindFromApi(j['organization_business_kind']),
      organizationSchedulingMode: _schedulingModeFromApi(j['organization_scheduling_mode']),
      createdAt: createdAt,
      updatedAt: updatedAt,
      isHiddenFromUser: hidden,
    );
  }
}

/// Фото по заказу (ответ API списка и загрузки).
class OrderPhoto {
  final String id;
  final String url;
  final DateTime? createdAt;

  const OrderPhoto({
    required this.id,
    required this.url,
    this.createdAt,
  });

  static OrderPhoto fromJson(Map<String, dynamic> j) {
    return OrderPhoto(
      id: j['id'] as String? ?? '',
      url: j['url'] as String? ?? j['file_path'] as String? ?? '',
      createdAt: _parseAt(j['created_at']),
    );
  }

  static DateTime? _parseAt(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }
}

/// Результат запроса доступных слотов (для выбора времени в запросе согласования).
class AvailableSlotsResult {
  final List<String> startTimes; // "HH:mm" в локальном времени
  final int slotDurationMinutes;
  final int workStartMinutes;
  final int workEndMinutes;

  const AvailableSlotsResult({
    this.startTimes = const [],
    this.slotDurationMinutes = 30,
    this.workStartMinutes = 9 * 60,
    this.workEndMinutes = 18 * 60,
  });
}
