import '../../../../../core/settings/car_manual_expense_models.dart';

/// Источник строки журнала аналитики (в памяти, без дублей в SharedPreferences).
enum AnalyticsExpenseSourceType { order, manual, fuel, maintenance }

/// Укрупнённый тип операции для фильтров и экспорта.
enum AnalyticsExpenseOperationType {
  replacement,
  repair,
  diagnostics,
  service,
  purchase,
  fuel,
  insurance,
  parking,
  fine,
  wash,
  tuning,
  other,
}

/// Единая модель расхода для аналитики (строится на лету из заказов, ТО, ручных записей).
///
/// [totalKopecks] — единственная денежная «истина» для суммирования и экспорта.
/// [materialKopecks] и [laborKopecks] — опциональная детализация; если заданы и их
/// сумма не совпадает с [totalKopecks], при отображении приоритет у [totalKopecks].
class AnalyticsExpenseEntry {
  const AnalyticsExpenseEntry({
    required this.id,
    required this.carId,
    required this.date,
    required this.title,
    required this.totalKopecks,
    required this.sourceType,
    required this.expenseGroupId,
    required this.expenseCategoryId,
    required this.expenseCategoryTitle,
    required this.expenseItemTitle,
    required this.operationType,
    required this.isEditable,
    required this.isDeletable,
    this.materialKopecks,
    this.laborKopecks,
    this.odometerKm,
    this.comment,
    this.sourceId,
    this.sourceItemId,
    this.sourceTitle,
    this.organizationName,
    this.placeName,
    this.manualSyncStatus,
  });

  /// Стабильный ключ: `order_<orderId>_item_<itemId>` | `manual_<id>` | `fuel_<id>` | `maint_<id>`.
  final String id;
  final String carId;
  final DateTime date;
  final String title;
  final int? materialKopecks;
  final int? laborKopecks;
  final int totalKopecks;
  final int? odometerKm;
  final String? comment;

  final AnalyticsExpenseSourceType sourceType;
  final String? sourceId;
  final String? sourceItemId;
  final String? sourceTitle;
  final String? organizationName;
  final String? placeName;

  final String expenseGroupId;
  final String expenseCategoryId;
  final String expenseCategoryTitle;
  final String expenseItemTitle;
  final AnalyticsExpenseOperationType operationType;

  final bool isEditable;
  final bool isDeletable;

  /// Только для ручных записей и заправок: индикатор синхронизации.
  final CarManualExpenseSyncStatus? manualSyncStatus;
}
