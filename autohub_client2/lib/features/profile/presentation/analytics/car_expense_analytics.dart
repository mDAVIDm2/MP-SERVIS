import '../../../../core/providers/app_providers.dart';
import '../../../../core/settings/car_expense_group_ids.dart';
import '../../../../core/settings/car_manual_expenses_provider.dart';
import '../../../../shared/models/order_model.dart';
import 'analytics_catalog_helper.dart';

/// Классификация заказов и ручных записей для аналитики.
abstract final class CarExpenseClassifier {
  static String groupForManual(CarManualExpenseRecord r) => r.resolvedExpenseGroupId;

  static String? accessorySubForManual(CarManualExpenseRecord r) {
    final s = r.expenseSubId?.trim();
    if (s != null && s.isNotEmpty) return s;
    return null;
  }

  static String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е');

  static String groupForOrderItem(
    OrderItem item, {
    required List<CatalogCategory> categories,
    required List<CatalogServiceItem> catalogItems,
  }) {
    final catLabel = AnalyticsCatalogHelper.labelForOrderItem(
      item,
      categories: categories,
      catalogLines: catalogItems,
      english: false,
    );
    return _groupForTexts(item.name, catLabel);
  }

  static String _groupForTexts(String serviceName, String categoryLabel) {
    final t = _norm('$serviceName $categoryLabel');

    if (_hasAny(t, ['осаго', 'каско', 'страхов', 'insurance', 'osago', 'casco'])) {
      return CarExpenseGroupIds.ownership;
    }
    if (_hasAny(t, ['парков', 'parking', 'парковк'])) {
      return CarExpenseGroupIds.ownership;
    }
    if (_hasAny(t, ['штраф', 'fine', 'гибдд'])) {
      return CarExpenseGroupIds.unplanned;
    }
    if (_hasAny(t, ['шиномонтаж', 'балансиров', 'равал', 'схожден', 'tire mount', 'wheel balanc'])) {
      return CarExpenseGroupIds.unplanned;
    }
    if (_hasAny(t, ['мойк', 'химчист', 'полиров', 'детейл', 'wash', 'detailing', 'vacuum', 'пылесос'])) {
      return CarExpenseGroupIds.cleanComfort;
    }
    if (_hasAny(t, ['тюнинг', 'аксессу', 'противотуман', 'обвес', 'tuning', 'spoiler', 'led bar'])) {
      return CarExpenseGroupIds.accessories;
    }
    if (_hasAny(t, [
      'масл',
      'фильтр',
      'антифриз',
      'тормоз',
      'колод',
      'диск',
      'то ',
      'техобслуж',
      'свеч',
      'акпп',
      'atf',
      'oil',
      'filter',
      'antifreeze',
      'brake',
      'pad',
      'rotor',
      'maintenance',
      'timing',
      'подвеск',
      'амортиз',
      'акб',
      'battery',
      'техосмотр',
      'диагност',
      'ремонт двиг',
      'салонн фильтр',
      'топливн фильтр',
      'тормозн жидк',
    ])) {
      return CarExpenseGroupIds.maintenance;
    }
    if (_hasAny(t, ['заправ', 'топлив', 'fuel', 'gas station', 'diesel', 'бензин'])) {
      return CarExpenseGroupIds.fuel;
    }
    return CarExpenseGroupIds.unplanned;
  }

  static bool _hasAny(String t, List<String> keys) {
    for (final k in keys) {
      if (t.contains(k)) return true;
    }
    return false;
  }
}

extension CarFuelRefuelStatsMean on CarFuelRefuelStats {
  /// Среднее л/100 по всем интервалам, где удалось посчитать.
  double? get meanLPer100FromIntervals {
    final xs = intervals.map((e) => e.lPer100).whereType<double>().toList();
    if (xs.isEmpty) return null;
    return xs.reduce((a, b) => a + b) / xs.length;
  }
}
