import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/formatters.dart';
import '../org_business_kind.dart';
import '../../core/theme/client_palette.dart';

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
      case pendingConfirmation: return 'Ожидает подтверждения';
      case confirmed: return 'Подтверждён';
      case inProgress: return 'В работе';
      case pendingApproval: return 'Требуется согласование';
      case completed: return 'Готово к выдаче';
      case done: return 'Завершён';
      case cancelled: return 'Отменён';
    }
  }

  Color get color {
    switch (this) {
      case pendingConfirmation: return SemanticColors.statusPending;
      case confirmed: return SemanticColors.statusConfirmed;
      case inProgress: return SemanticColors.statusInProgress;
      case pendingApproval: return SemanticColors.statusApproval;
      case completed: return SemanticColors.statusCompleted;
      case done: return SemanticColors.statusDone;
      case cancelled: return SemanticColors.statusCancelled;
    }
  }

  double get progress {
    switch (this) {
      case pendingConfirmation: return 0.0;
      case confirmed: return 0.25;
      case inProgress: return 0.5;
      case pendingApproval: return 0.5;
      case completed: return 0.75;
      case done: return 1.0;
      case cancelled: return 0.0;
    }
  }

  bool get isActive => this != done && this != cancelled;

  /// Парсинг статуса из API (snake_case)
  static OrderStatus fromApi(String? v) {
    switch (v?.toLowerCase()) {
      case 'pending_confirmation': return OrderStatus.pendingConfirmation;
      case 'confirmed': return OrderStatus.confirmed;
      case 'in_progress': return OrderStatus.inProgress;
      case 'pending_approval': return OrderStatus.pendingApproval;
      case 'completed': return OrderStatus.completed;
      case 'done': return OrderStatus.done;
      case 'cancelled': return OrderStatus.cancelled;
      default: return OrderStatus.pendingConfirmation;
    }
  }

  String get shortLabel {
    switch (this) {
      case pendingConfirmation: return 'Записан';
      case confirmed: return 'Подтверждён';
      case inProgress: return 'В работе';
      case pendingApproval: return 'Согласование';
      case completed: return 'Готов';
      case done: return 'Завершён';
      case cancelled: return 'Отменён';
    }
  }
}

/// Кто должен подтвердить бронь в [OrderStatus.pendingConfirmation] (поле `confirmation_required_from` в API).
enum OrderConfirmationRequiredFrom {
  /// Подтверждает клиент (запись создала организация).
  client,
  /// Подтверждает сервис (заявку создал клиент).
  organization;

  static OrderConfirmationRequiredFrom? fromApi(String? v) {
    switch (v?.toLowerCase().trim()) {
      case 'client':
        return OrderConfirmationRequiredFrom.client;
      case 'organization':
        return OrderConfirmationRequiredFrom.organization;
      default:
        return null;
    }
  }
}

class OrderItem {
  final String id;
  final String name;
  final int priceKopecks;
  final int estimatedMinutes; // ← НОВОЕ: время выполнения
  final bool isCompleted;
  final bool isApproved;
  final bool isAdditional;
  final bool isRejected;
  /// ID услуги в каталоге организации (для запроса слотов). Может быть null.
  final String? serviceId;

  /// Id позиции общего справочника (`svc_*`), если бэкенд отдал.
  final String? catalogItemId;

  const OrderItem({
    required this.id,
    required this.name,
    required this.priceKopecks,
    this.estimatedMinutes = 60,
    this.isCompleted = false,
    this.isApproved = true,
    this.isAdditional = false,
    this.isRejected = false,
    this.serviceId,
    this.catalogItemId,
  });

  OrderItem copyWith({
    String? id,
    String? name,
    int? priceKopecks,
    int? estimatedMinutes,
    bool? isCompleted,
    bool? isApproved,
    bool? isAdditional,
    bool? isRejected,
    String? serviceId,
    String? catalogItemId,
  }) {
    return OrderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      priceKopecks: priceKopecks ?? this.priceKopecks,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      isApproved: isApproved ?? this.isApproved,
      isAdditional: isAdditional ?? this.isAdditional,
      isRejected: isRejected ?? this.isRejected,
      serviceId: serviceId ?? this.serviceId,
      catalogItemId: catalogItemId ?? this.catalogItemId,
    );
  }

  /// Форматированное время: "30 мин", "1:15 ч", …
  String get durationLabel => Formatters.durationMinutes(estimatedMinutes);
}

class Order {
  final String id;
  final String orderNumber;
  final String carId;
  final String stoId;
  final String stoName;
  final String? stoAddress;
  final String? stoPhone;
  final OrderStatus status;
  /// Статус до перехода в «требует согласования» (с бэкенда). Для отображения этапа заказа пользователю.
  final OrderStatus? previousStatus;
  final DateTime dateTime;
  /// Плановое начало и окончание (бронь «с — по»).
  final DateTime? plannedStartTime;
  final DateTime? plannedEndTime;
  final List<OrderItem> items;
  /// Черновик из последнего запроса согласования (только отображение при pending_approval).
  final List<OrderItem>? approvalPreviewItems;
  final int? approvalPreviewTotalKopecks;
  final int? approvalPreviewEstimatedMinutes;
  final String? comment;
  /// С бэкенда (для PDF и карточек).
  final String? clientName;
  final String? clientPhone;
  /// URL фото профиля текущего пользователя в контексте заказа (`client_avatar_url`).
  final String? clientAvatarUrl;
  final String? carInfo;
  /// Снимок URL фото авто с сервера (`car_photo_url`).
  final String? carPhotoUrl;
  final String? masterName;
  final String? bayName;
  final String? vin;
  final String? licensePlate;
  final int? mileage;
  /// Пробег авто при завершении заказа (для напоминаний о регламенте).
  final int? odometerAtCompletion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Код типа организации с бэкенда (`sto`, `car_wash`, …).
  final String? organizationBusinessKind;
  /// `staff_based` | `bay_based` — как строилось расписание у организации.
  final String? organizationSchedulingMode;
  /// См. [OrderConfirmationRequiredFrom] (`confirmation_required_from` в API).
  final OrderConfirmationRequiredFrom? confirmationRequiredFrom;
  /// `org_confirmed_on_behalf_of_client` — СТО сразу подтвердило бронь (согласие вне приложения).
  final bool orgConfirmedOnBehalfOfClient;

  /// Только автосервис / шиномонтаж / сервис ЭС: и только при явном коде из API (без кода — не подтягиваем).
  bool get isEligibleForMaintenanceSync =>
      OrgBusinessKind.isGarageMaintenanceSource(organizationBusinessKind);

  /// Статус для отображения в карточке: при pending_approval показываем этап, на котором был заказ при отправке изменений (подтверждён/записан/в работе).
  OrderStatus get displayStatus =>
      (status == OrderStatus.pendingApproval && previousStatus != null) ? previousStatus! : status;

  OrderConfirmationRequiredFrom get _resolvedConfirmationParty =>
      confirmationRequiredFrom ?? OrderConfirmationRequiredFrom.organization;

  /// Клиенту нужно нажать «подтвердить» (запись от сервиса).
  bool get clientMustConfirmPendingBooking =>
      status == OrderStatus.pendingConfirmation && _resolvedConfirmationParty == OrderConfirmationRequiredFrom.client;

  bool get hasApprovalPreview =>
      status == OrderStatus.pendingApproval &&
      approvalPreviewItems != null &&
      approvalPreviewItems!.isNotEmpty;

  /// Состав и суммы в карточках при ожидании согласования — по черновику из API.
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
    return totalEstimatedMinutes;
  }

  String get displayDurationLabel =>
      hasApprovalPreview && approvalPreviewEstimatedMinutes != null
          ? Formatters.durationMinutes(approvalPreviewEstimatedMinutes!)
          : totalDurationLabel;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.carId,
    required this.stoId,
    required this.stoName,
    this.stoAddress,
    this.stoPhone,
    required this.status,
    this.previousStatus,
    required this.dateTime,
    this.plannedStartTime,
    this.plannedEndTime,
    required this.items,
    this.approvalPreviewItems,
    this.approvalPreviewTotalKopecks,
    this.approvalPreviewEstimatedMinutes,
    this.comment,
    this.clientName,
    this.clientPhone,
    this.clientAvatarUrl,
    this.carInfo,
    this.carPhotoUrl,
    this.masterName,
    this.bayName,
    this.vin,
    this.licensePlate,
    this.mileage,
    this.odometerAtCompletion,
    this.createdAt,
    this.updatedAt,
    this.organizationBusinessKind,
    this.organizationSchedulingMode,
    this.confirmationRequiredFrom,
    this.orgConfirmedOnBehalfOfClient = false,
  });

  Order copyWith({
    String? id,
    String? orderNumber,
    String? carId,
    String? stoId,
    String? stoName,
    String? stoAddress,
    String? stoPhone,
    OrderStatus? status,
    OrderStatus? previousStatus,
    DateTime? dateTime,
    DateTime? plannedStartTime,
    DateTime? plannedEndTime,
    List<OrderItem>? items,
    List<OrderItem>? approvalPreviewItems,
    int? approvalPreviewTotalKopecks,
    int? approvalPreviewEstimatedMinutes,
    String? comment,
    String? clientName,
    String? clientPhone,
    String? clientAvatarUrl,
    String? carInfo,
    String? carPhotoUrl,
    String? masterName,
    String? bayName,
    String? vin,
    String? licensePlate,
    int? mileage,
    int? odometerAtCompletion,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? organizationBusinessKind,
    String? organizationSchedulingMode,
    OrderConfirmationRequiredFrom? confirmationRequiredFrom,
    bool? orgConfirmedOnBehalfOfClient,
    bool clearApprovalPreview = false,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      carId: carId ?? this.carId,
      stoId: stoId ?? this.stoId,
      stoName: stoName ?? this.stoName,
      stoAddress: stoAddress ?? this.stoAddress,
      stoPhone: stoPhone ?? this.stoPhone,
      status: status ?? this.status,
      previousStatus: previousStatus ?? this.previousStatus,
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
      clientName: clientName ?? this.clientName,
      clientPhone: clientPhone ?? this.clientPhone,
      clientAvatarUrl: clientAvatarUrl ?? this.clientAvatarUrl,
      carInfo: carInfo ?? this.carInfo,
      carPhotoUrl: carPhotoUrl ?? this.carPhotoUrl,
      masterName: masterName ?? this.masterName,
      bayName: bayName ?? this.bayName,
      vin: vin ?? this.vin,
      licensePlate: licensePlate ?? this.licensePlate,
      mileage: mileage ?? this.mileage,
      odometerAtCompletion: odometerAtCompletion ?? this.odometerAtCompletion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      organizationBusinessKind: organizationBusinessKind ?? this.organizationBusinessKind,
      organizationSchedulingMode: organizationSchedulingMode ?? this.organizationSchedulingMode,
      confirmationRequiredFrom: confirmationRequiredFrom ?? this.confirmationRequiredFrom,
      orgConfirmedOnBehalfOfClient: orgConfirmedOnBehalfOfClient ?? this.orgConfirmedOnBehalfOfClient,
    );
  }

  /// Время для сортировки в ленте чата: при «требует согласования» — по обновлению, иначе по созданию.
  DateTime get timelineSortAt {
    if (status == OrderStatus.pendingApproval && updatedAt != null) return updatedAt!;
    return createdAt ?? dateTime;
  }

  int get totalKopecks => items
      .where((i) => i.isApproved && !i.isRejected)
      .fold(0, (sum, item) => sum + item.priceKopecks);

  int get completedCount => items.where((i) => i.isCompleted).length;
  int get totalCount => items.where((i) => i.isApproved && !i.isRejected).length;
  double get itemsProgress => totalCount > 0 ? completedCount / totalCount : 0;

  /// Из ответа API (общий бэкенд с Business)
  static Order fromApiJson(Map<String, dynamic> j) {
    OrderItem parseItem(Map<String, dynamic> m) {
      final catRaw = m['catalog_item_id']?.toString() ?? m['catalogItemId']?.toString();
      return OrderItem(
        id: m['id']?.toString() ?? '',
        name: m['name']?.toString() ?? '',
        priceKopecks: (m['price_kopecks'] as num?)?.toInt() ?? 0,
        estimatedMinutes: (m['estimated_minutes'] as num?)?.toInt() ?? 60,
        isCompleted: m['is_completed'] == true,
        isAdditional: m['is_additional'] == true,
        isApproved: true,
        isRejected: false,
        serviceId: m['service_id']?.toString(),
        catalogItemId: (catRaw != null && catRaw.trim().isNotEmpty) ? catRaw.trim() : null,
      );
    }

    final itemsJson = j['items'] as List<dynamic>? ?? [];
    final items = itemsJson.map((i) => parseItem(i as Map<String, dynamic>)).toList();

    List<OrderItem>? previewItems;
    int? previewTotalK;
    int? previewMins;
    final apRaw = j['approval_preview'];
    if (apRaw is Map<String, dynamic>) {
      final pi = apRaw['items'] as List<dynamic>?;
      if (pi != null && pi.isNotEmpty) {
        previewItems = pi.map((e) => parseItem(e as Map<String, dynamic>)).toList();
      }
      final tk = apRaw['total_kopecks'] ?? apRaw['totalKopecks'];
      if (tk is num) previewTotalK = tk.toInt();
      final em = apRaw['estimated_minutes'] ?? apRaw['estimatedMinutes'];
      if (em is num) previewMins = em.toInt();
    }
    final dateTime = j['date_time'] != null
        ? DateTime.tryParse(j['date_time'].toString()) ?? DateTime.now()
        : DateTime.now();
    final plannedStart = j['planned_start_time'] != null ? DateTime.tryParse(j['planned_start_time'].toString()) : null;
    final plannedEnd = j['planned_end_time'] != null ? DateTime.tryParse(j['planned_end_time'].toString()) : null;
    final createdAt = j['created_at'] != null ? DateTime.tryParse(j['created_at'].toString()) : null;
    final updatedAt = j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null;
    return Order(
      id: j['id']?.toString() ?? '',
      orderNumber: j['order_number']?.toString() ?? '',
      carId: j['car_id']?.toString() ?? '',
      stoId: j['organization_id']?.toString() ?? '',
      stoName: j['organization_name']?.toString() ?? 'Сервис',
      stoAddress: j['organization_address']?.toString(),
      stoPhone: j['organization_phone']?.toString(),
      status: OrderStatus.fromApi(j['status']?.toString()),
      previousStatus: j['previous_status'] != null ? OrderStatus.fromApi(j['previous_status'].toString()) : null,
      dateTime: dateTime,
      plannedStartTime: plannedStart,
      plannedEndTime: plannedEnd,
      items: items,
      approvalPreviewItems: previewItems,
      approvalPreviewTotalKopecks: previewTotalK,
      approvalPreviewEstimatedMinutes: previewMins,
      comment: j['comment']?.toString(),
      clientName: j['client_name']?.toString(),
      clientPhone: j['client_phone']?.toString(),
      clientAvatarUrl: () {
        final u = j['client_avatar_url']?.toString() ?? j['clientAvatarUrl']?.toString() ?? '';
        final t = u.trim();
        if (t.isEmpty) return null;
        return AppConfig.resolveProfileAvatarUrl(t);
      }(),
      carInfo: j['car_info']?.toString(),
      carPhotoUrl: () {
        final u = j['car_photo_url']?.toString() ?? j['carPhotoUrl']?.toString() ?? '';
        final t = u.trim();
        if (t.isEmpty) return null;
        return AppConfig.resolveCarOrOrderPhotoUrl(t);
      }(),
      masterName: j['master_name']?.toString(),
      bayName: j['bay_name']?.toString(),
      vin: j['vin']?.toString(),
      licensePlate: j['license_plate']?.toString(),
      mileage: (j['mileage'] as num?)?.toInt(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      organizationBusinessKind: OrgBusinessKind.normalizeCode(j['organization_business_kind']?.toString()),
      organizationSchedulingMode:
          OrgBusinessKind.normalizeSchedulingMode(j['organization_scheduling_mode']?.toString()),
      confirmationRequiredFrom: OrderConfirmationRequiredFrom.fromApi(
        j['confirmation_required_from']?.toString() ?? j['confirmationRequiredFrom']?.toString(),
      ),
      orgConfirmedOnBehalfOfClient: j['org_confirmed_on_behalf_of_client'] as bool? ??
          j['orgConfirmedOnBehalfOfClient'] as bool? ??
          false,
    );
  }

  /// Суммарное время выполнения всех работ
  int get totalEstimatedMinutes => items
      .where((i) => i.isApproved && !i.isRejected)
      .fold(0, (sum, item) => sum + item.estimatedMinutes);

  String get totalDurationLabel => Formatters.durationMinutes(totalEstimatedMinutes);

  /// Номер для UI: один `#` в начале.
  String get displayNumber {
    var s = orderNumber.trim();
    while (s.startsWith('#')) {
      s = s.substring(1).trim();
    }
    return s.isEmpty ? orderNumber.trim() : '#$s';
  }
}
