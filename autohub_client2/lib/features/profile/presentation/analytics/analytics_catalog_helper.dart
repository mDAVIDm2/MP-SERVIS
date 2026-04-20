import '../../../../core/providers/app_providers.dart';
import '../../../../shared/models/order_model.dart';

/// Сопоставление строки заказа с категорией из общего справочника [catalogServicesProvider].
/// Если совпадения по названию услуги нет — используется эвристика по ключевым словам.
abstract final class AnalyticsCatalogHelper {
  /// Сначала [OrderItem.catalogItemId] (если бэкенд сохранил), иначе матч по названию.
  static String labelForOrderItem(
    OrderItem item, {
    required List<CatalogCategory> categories,
    required List<CatalogServiceItem> catalogLines,
    bool english = false,
  }) {
    final cid = item.catalogItemId?.trim();
    if (cid != null && cid.isNotEmpty) {
      for (final it in catalogLines) {
        if (it.id == cid) {
          for (final c in categories) {
            if (c.id == it.categoryId && c.name.trim().isNotEmpty) {
              return c.name.trim();
            }
          }
          break;
        }
      }
    }
    return labelForLine(
      item.name,
      categories: categories,
      items: catalogLines,
      english: english,
    );
  }

  static String labelForLine(
    String itemName, {
    required List<CatalogCategory> categories,
    required List<CatalogServiceItem> items,
    bool english = false,
  }) {
    final lower = itemName.trim().toLowerCase();
    if (lower.isEmpty) return _heuristic(itemName, english: english);
    if (items.isEmpty) return _heuristic(itemName, english: english);

    CatalogServiceItem? best;
    var bestScore = 0;
    for (final it in items) {
      final cn = it.name.trim().toLowerCase();
      if (cn.length < 3) continue;
      var score = 0;
      if (lower.contains(cn)) {
        score = cn.length;
      } else if (cn.contains(lower) && lower.length >= 4) {
        score = lower.length;
      }
      if (score > bestScore) {
        bestScore = score;
        best = it;
      }
    }
    if (best != null) {
      for (final c in categories) {
        if (c.id == best.categoryId && c.name.trim().isNotEmpty) {
          return c.name.trim();
        }
      }
    }
    return _heuristic(itemName, english: english);
  }

  static String _heuristic(String name, {required bool english}) {
    final n = name.toLowerCase();
    if (n.contains('масл') || n.contains('фильтр') || n.contains('антифриз') ||
        n.contains('oil') || n.contains('filter') || n.contains('antifreeze')) {
      return english ? 'Maintenance & consumables' : 'ТО и расходники';
    }
    if (n.contains('тормоз') || n.contains('колод') || n.contains('диск') ||
        n.contains('brake') || n.contains('pad') || n.contains('rotor')) {
      return english ? 'Brakes' : 'Тормоза';
    }
    if (n.contains('диагн') || n.contains('diagn')) {
      return english ? 'Diagnostics' : 'Диагностика';
    }
    if (n.contains('кондиц') || n.contains('фреон') || n.contains('a/c') || n.contains('ac ') ||
        n.contains('climate') || n.contains('freon')) {
      return english ? 'Climate' : 'Климат';
    }
    return english ? 'Other' : 'Прочее';
  }
}
