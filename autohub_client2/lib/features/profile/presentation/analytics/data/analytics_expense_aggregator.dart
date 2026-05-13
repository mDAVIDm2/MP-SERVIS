import '../../../../../core/l10n/app_l10n.dart';
import '../../../../../core/l10n/maintenance_type_l10n.dart';
import '../../../../../core/settings/car_expense_group_ids.dart';
import '../../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../../core/settings/maintenance_reminders_provider.dart';
import '../../../../../core/providers/app_providers.dart';
import '../../../../../shared/models/order_model.dart';
import '../analytics_catalog_helper.dart';
import '../domain/analytics_expense_entry.dart';
import '../domain/analytics_financial_order.dart';
import '../domain/analytics_global_period.dart';
import 'analytics_expense_line_classifier.dart';
import 'analytics_taxonomy_l10n.dart';

/// Собирает единый журнал расходов без дублирования в БД (только в памяти при открытии экрана).
abstract final class AnalyticsExpenseAggregator {
  static AnalyticsExpenseOperationType? _operationTypeFromManualName(
    CarManualExpenseRecord m,
  ) {
    final n = m.analyticsOperationName?.trim();
    if (n == null || n.isEmpty) return null;
    for (final v in AnalyticsExpenseOperationType.values) {
      if (v.name == n) return v;
    }
    return null;
  }

  static AnalyticsExpenseOperationType _opFromManual(CarManualExpenseRecord r) {
    final fromName = _operationTypeFromManualName(r);
    if (fromName != null) return fromName;
    final sid = r.expenseSubId;
    if (sid == CarExpenseAccessorySubIds.replace) {
      return AnalyticsExpenseOperationType.replacement;
    }
    if (sid == CarExpenseAccessorySubIds.retrofit) {
      return AnalyticsExpenseOperationType.repair;
    }
    if (sid == CarExpenseAccessorySubIds.purchase) {
      return AnalyticsExpenseOperationType.purchase;
    }
    if (sid == CarExpenseUnplannedSubIds.fine) {
      return AnalyticsExpenseOperationType.fine;
    }
    return AnalyticsExpenseOperationType.other;
  }

  static ({String categoryId, AnalyticsExpenseOperationType op}) _maintMeta(
    MaintenanceType t,
  ) {
    switch (t) {
      case MaintenanceType.oil:
      case MaintenanceType.airFilter:
      case MaintenanceType.fuelFilter:
      case MaintenanceType.cabinFilter:
        return (
          categoryId: AnalyticsTaxonomy.maintOilFilters,
          op: AnalyticsExpenseOperationType.replacement,
        );
      case MaintenanceType.antifreeze:
        return (
          categoryId: AnalyticsTaxonomy.maintCooling,
          op: AnalyticsExpenseOperationType.replacement,
        );
      case MaintenanceType.brakes:
      case MaintenanceType.brakeFluid:
        return (
          categoryId: AnalyticsTaxonomy.maintBrakes,
          op: AnalyticsExpenseOperationType.repair,
        );
      case MaintenanceType.tires:
      case MaintenanceType.alignment:
        return (
          categoryId: AnalyticsTaxonomy.maintTires,
          op: AnalyticsExpenseOperationType.service,
        );
      case MaintenanceType.battery:
        return (
          categoryId: AnalyticsTaxonomy.maintElectrics,
          op: AnalyticsExpenseOperationType.replacement,
        );
      case MaintenanceType.inspection:
        return (
          categoryId: AnalyticsTaxonomy.maintDiagnostics,
          op: AnalyticsExpenseOperationType.diagnostics,
        );
      case MaintenanceType.timingBelt:
      case MaintenanceType.sparkPlugs:
        return (
          categoryId: AnalyticsTaxonomy.maintEngine,
          op: AnalyticsExpenseOperationType.replacement,
        );
      case MaintenanceType.suspension:
        return (
          categoryId: AnalyticsTaxonomy.maintSuspension,
          op: AnalyticsExpenseOperationType.repair,
        );
      case MaintenanceType.general:
        return (
          categoryId: AnalyticsTaxonomy.maintOther,
          op: AnalyticsExpenseOperationType.service,
        );
      case MaintenanceType.atf:
        return (
          categoryId: AnalyticsTaxonomy.maintTransmission,
          op: AnalyticsExpenseOperationType.replacement,
        );
      case MaintenanceType.wiperBlades:
        return (
          categoryId: AnalyticsTaxonomy.maintGlassWipers,
          op: AnalyticsExpenseOperationType.replacement,
        );
    }
  }

  static List<AnalyticsExpenseEntry> build({
    required AppL10n l10n,
    required String carId,
    required AnalyticsGlobalPeriod period,
    required List<Order> orders,
    required List<CarManualExpenseRecord> manual,
    required List<MaintenanceRecord> maintenance,
    required List<CatalogCategory> catalogCategories,
    required List<CatalogServiceItem> catalogItems,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final start = period.rangeStartInclusive(n);
    final end = period.rangeEndInclusive(n);

    bool inRange(DateTime d) {
      if (start != null && d.isBefore(start)) return false;
      if (end != null && d.isAfter(end)) return false;
      return true;
    }

    final out = <AnalyticsExpenseEntry>[];

    for (final o in orders) {
      if (o.carId != carId) continue;
      if (!isCompletedFinancialOrder(o, now: n)) continue;
      if (!inRange(o.dateTime)) continue;

      final displayItems = o.itemsForDisplay
          .where((i) => i.isApproved && !i.isRejected)
          .toList();
      final priced = displayItems.where((i) => i.priceKopecks > 0).toList();

      if (priced.isNotEmpty) {
        for (var idx = 0; idx < priced.length; idx++) {
          final item = priced[idx];
          final itemKey = item.id.trim().isNotEmpty
              ? item.id.trim()
              : 'index_$idx';
          final catLabel = AnalyticsCatalogHelper.labelForOrderItem(
            item,
            categories: catalogCategories,
            catalogLines: catalogItems,
            english: l10n.isEn,
          );
          final cl = AnalyticsExpenseLineClassifier.classify(
            item.name,
            catLabel,
          );
          final catTitle = l10n.analyticsTaxCategoryTitle(cl.categoryId);
          out.add(
            AnalyticsExpenseEntry(
              id: 'order_${o.id}_item_$itemKey',
              carId: carId,
              date: o.dateTime,
              title: item.name.trim().isEmpty ? o.stoName : item.name.trim(),
              totalKopecks: item.priceKopecks,
              sourceType: AnalyticsExpenseSourceType.order,
              sourceId: o.id,
              sourceItemId: item.id,
              sourceTitle: o.displayNumber,
              organizationName: o.stoName,
              expenseGroupId: cl.groupId,
              expenseCategoryId: cl.categoryId,
              expenseCategoryTitle: catTitle,
              expenseItemTitle: item.name.trim(),
              operationType: cl.op,
              isEditable: false,
              isDeletable: false,
              odometerKm: o.odometerAtCompletion ?? o.mileage,
              comment: o.comment,
              manualSyncStatus: null,
            ),
          );
        }
      } else if (o.totalKopecksForDisplay > 0) {
        final cl = AnalyticsExpenseLineClassifier.classify(o.stoName, '');
        final catTitle = l10n.analyticsTaxCategoryTitle(cl.categoryId);
        out.add(
          AnalyticsExpenseEntry(
            id: 'order_${o.id}_total',
            carId: carId,
            date: o.dateTime,
            title: o.stoName,
            totalKopecks: o.totalKopecksForDisplay,
            sourceType: AnalyticsExpenseSourceType.order,
            sourceId: o.id,
            sourceItemId: null,
            sourceTitle: o.displayNumber,
            organizationName: o.stoName,
            expenseGroupId: cl.groupId,
            expenseCategoryId: cl.categoryId,
            expenseCategoryTitle: catTitle,
            expenseItemTitle: l10n.analyticsExpenseOrderWholeItem,
            operationType: cl.op,
            isEditable: false,
            isDeletable: false,
            odometerKm: o.odometerAtCompletion ?? o.mileage,
            comment: o.comment,
            manualSyncStatus: null,
          ),
        );
      }
    }

    for (final r in maintenance) {
      if (r.carId != carId) continue;
      final p = r.priceKopecks;
      if (p == null || p <= 0) continue;
      if (!inRange(r.date)) continue;
      final type = MaintenanceType.fromTypeKey(r.typeKey);
      if (type == null) continue;
      final meta = _maintMeta(type);
      final itemTitle = type.localizedTitle(l10n);
      out.add(
        AnalyticsExpenseEntry(
          id: 'maint_${r.id}',
          carId: carId,
          date: r.date,
          title: itemTitle,
          totalKopecks: p,
          sourceType: AnalyticsExpenseSourceType.maintenance,
          sourceId: r.id,
          organizationName: r.place,
          expenseGroupId: CarExpenseGroupIds.maintenance,
          expenseCategoryId: meta.categoryId,
          expenseCategoryTitle: l10n.analyticsTaxCategoryTitle(meta.categoryId),
          expenseItemTitle: itemTitle,
          operationType: meta.op,
          isEditable: false,
          isDeletable: false,
          odometerKm: r.odometerKm,
          comment: null,
          manualSyncStatus: null,
        ),
      );
    }

    for (final m in manual) {
      if (m.carId != carId) continue;
      if (m.priceKopecks <= 0) continue;
      if (!inRange(m.date)) continue;

      if (m.isFuel) {
        final place = m.fuelStationName ?? m.placeName;
        out.add(
          AnalyticsExpenseEntry(
            id: 'fuel_${m.id}',
            carId: carId,
            date: m.date,
            title: m.groupLabelAppL10n(l10n),
            totalKopecks: m.priceKopecks,
            sourceType: AnalyticsExpenseSourceType.fuel,
            sourceId: m.id,
            placeName: place,
            expenseGroupId: CarExpenseGroupIds.fuel,
            expenseCategoryId: AnalyticsTaxonomy.fuelPurchase,
            expenseCategoryTitle: l10n.analyticsTaxCategoryTitle(
              AnalyticsTaxonomy.fuelPurchase,
            ),
            expenseItemTitle:
                m.fuelType?.label(l10n) ?? l10n.analyticsManualTabFuel,
            operationType: AnalyticsExpenseOperationType.fuel,
            isEditable: true,
            isDeletable: true,
            odometerKm: m.odometerKm,
            comment: m.note,
            manualSyncStatus: m.syncStatusForAnalytics,
          ),
        );
        continue;
      }

      final title = m.customTitle?.trim().isNotEmpty == true
          ? m.customTitle!.trim()
          : m.groupLabelAppL10n(l10n);
      final explicitCat = m.expenseCategoryId?.trim();
      final explicitGroup = m.expenseGroupId?.trim();
      var gid = m.resolvedExpenseGroupId;
      late final String cid;
      if (explicitCat != null && explicitCat.isNotEmpty) {
        cid = explicitCat;
      } else {
        final cl = AnalyticsExpenseLineClassifier.classify(title, '');
        cid = cl.categoryId;
        if (explicitGroup == null || explicitGroup.isEmpty) {
          gid = cl.groupId;
        }
      }
      final catTitle = l10n.analyticsTaxCategoryTitle(cid);
      final itemTitle = m.expenseItemTitle?.trim().isNotEmpty == true
          ? m.expenseItemTitle!.trim()
          : title;
      out.add(
        AnalyticsExpenseEntry(
          id: 'manual_${m.id}',
          carId: carId,
          date: m.date,
          title: title,
          materialKopecks: m.materialPriceKopecks,
          laborKopecks: m.laborPriceKopecks,
          totalKopecks: m.priceKopecks,
          sourceType: AnalyticsExpenseSourceType.manual,
          sourceId: m.id,
          placeName: m.placeName,
          expenseGroupId: gid,
          expenseCategoryId: cid,
          expenseCategoryTitle: catTitle,
          expenseItemTitle: itemTitle,
          operationType: _opFromManual(m),
          isEditable: true,
          isDeletable: true,
          odometerKm: m.odometerKm,
          comment: m.note,
          manualSyncStatus: m.syncStatusForAnalytics,
        ),
      );
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}
