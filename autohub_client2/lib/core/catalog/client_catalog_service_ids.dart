import '../../shared/models/sto_model.dart';

/// ID позиций единого справочника на бэкенде (`service-catalog.seed.ts`).
/// Должны совпадать с тем, что возвращает API в `service_ids` / каталоге.
abstract final class ClientCatalogServiceIds {
  static const oilEngine = 'svc_maint_oil_engine';
  static const oilFilterOnly = 'svc_maint_oil_filter_only';
  static const airFilter = 'svc_maint_air_filter';
  static const coolant = 'svc_maint_coolant';
  static const brakePadsFront = 'svc_brake_pads_f';
  static const computerDiag = 'svc_diag_computer';
  static const wheelAlignment = 'svc_diag_align';
  static const battery = 'svc_el_batt';
  static const timingBelt = 'svc_maint_timing_belt';
  static const shockFront = 'svc_susp_shock_f';
  static const sparkPlugs = 'svc_maint_spark_plugs';
}

/// Старые mock-ID из клиента (`mock_data.dart`) → актуальные `svc_*`.
const Map<String, String> _legacyMockServiceIdToCatalog = {
  's1': ClientCatalogServiceIds.oilEngine,
  's2': ClientCatalogServiceIds.oilFilterOnly,
  's3': ClientCatalogServiceIds.airFilter,
  's5': ClientCatalogServiceIds.computerDiag,
  's6': ClientCatalogServiceIds.brakePadsFront,
  's8': ClientCatalogServiceIds.coolant,
  's10': ClientCatalogServiceIds.wheelAlignment,
};

/// Приводит фильтр услуг на карте/в поиске к ID каталога API.
/// Пара «масло + масляный фильтр» (s1+s2) → одна позиция «масло и фильтр».
/// [mergeOilEngineWithFilter]: если `false`, оставляет и моторное масло, и замену масляного фильтра отдельно (запись из напоминаний).
List<String> normalizeClientServiceFilterIds(
  Iterable<String> ids, {
  bool mergeOilEngineWithFilter = true,
}) {
  final set = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  if (set.contains('s1') && set.contains('s2')) {
    set.remove('s1');
    set.remove('s2');
    set.add(ClientCatalogServiceIds.oilEngine);
  }
  final out = <String>{};
  for (final id in set) {
    if (id.startsWith('svc_')) {
      out.add(id);
      continue;
    }
    final mapped = _legacyMockServiceIdToCatalog[id];
    if (mapped != null) {
      out.add(mapped);
    } else {
      out.add(id);
    }
  }
  if (mergeOilEngineWithFilter &&
      out.contains(ClientCatalogServiceIds.oilEngine) &&
      out.contains(ClientCatalogServiceIds.oilFilterOnly)) {
    out.remove(ClientCatalogServiceIds.oilFilterOnly);
  }
  return out.toList();
}

/// Все id услуг точки из ответа поиска (`service_ids` + строки `services`).
/// Добавляем эквиваленты каталога `svc_*` для старых id из настроек СТО (`s1`, `s2`, …).
Set<String> effectiveOfferedServiceIds(STO s) {
  final ids = <String>{};
  void addOne(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return;
    ids.add(t);
    final mapped = _legacyMockServiceIdToCatalog[t];
    if (mapped != null) ids.add(mapped);
  }
  for (final id in s.serviceIds) {
    addOne(id);
  }
  for (final svc in s.services) {
    addOne(svc.id);
    final c = svc.catalogItemId?.trim();
    if (c != null && c.isNotEmpty) {
      ids.add(c);
      final mapped = _legacyMockServiceIdToCatalog[c];
      if (mapped != null) ids.add(mapped);
    }
  }
  return ids;
}

/// Точка подходит под фильтр по id каталога (с учётом эквивалентов ТО).
bool stoOffersCatalogServiceForFilter(Set<String> offered, String filterCatalogId) {
  if (offered.contains(filterCatalogId)) return true;
  if (filterCatalogId == ClientCatalogServiceIds.oilFilterOnly &&
      offered.contains(ClientCatalogServiceIds.oilEngine)) {
    return true;
  }
  return false;
}

bool stoMatchesAllCatalogServiceFilters(STO s, List<String> normalizedFilterIds) {
  if (normalizedFilterIds.isEmpty) return true;
  final offered = effectiveOfferedServiceIds(s);
  return normalizedFilterIds.every((id) => stoOffersCatalogServiceForFilter(offered, id));
}

Set<String> _catalogIdsRepresentedByServiceRow(String rowId) {
  final t = rowId.trim();
  final set = <String>{t};
  final mapped = _legacyMockServiceIdToCatalog[t];
  if (mapped != null) set.add(mapped);
  return set;
}

/// Все id каталога / legacy, которые представляет строка прайса (включая [STOService.catalogItemId]).
Set<String> catalogIdsRepresentedByStoServiceRow(STOService s) {
  final set = _catalogIdsRepresentedByServiceRow(s.id);
  final c = s.catalogItemId?.trim();
  if (c != null && c.isNotEmpty) {
    set.add(c);
    final mapped = _legacyMockServiceIdToCatalog[c];
    if (mapped != null) set.add(mapped);
  }
  return set;
}

/// Строка прайса [s] считается соответствующей фильтру по каталогу (в т.ч. legacy id и пара масло/фильтр).
bool stoServiceRowMatchesCatalogFilter(STOService s, String catalogFilterId) {
  return stoOffersCatalogServiceForFilter(
    catalogIdsRepresentedByStoServiceRow(s),
    catalogFilterId,
  );
}

/// Id строк прайса точки, соответствующие позициям из фильтра поиска.
List<String> stoServiceRowIdsForCatalogFilter(Iterable<STOService> services, String catalogFilterId) {
  return [
    for (final s in services)
      if (stoServiceRowMatchesCatalogFilter(s, catalogFilterId)) s.id,
  ];
}

/// Для итога в поиске: при ценах по типу кузова базовый [STOService.priceKopecks] часто 0.
int _linePriceKopecks(STOService svc) {
  if (svc.useBodyTypePricing && svc.bodyTypePricing.isNotEmpty) {
    final prices = svc.bodyTypePricing.map((p) => p.priceKopecks).where((p) => p > 0);
    if (prices.isNotEmpty) return prices.reduce((a, b) => a < b ? a : b);
  }
  return svc.priceKopecks;
}

int _lineDurationMinutes(STOService svc) {
  if (svc.useBodyTypePricing && svc.bodyTypePricing.isNotEmpty) {
    final mins = svc.bodyTypePricing.map((p) => p.durationMinutes).where((m) => m > 0);
    if (mins.isNotEmpty) return mins.reduce((a, b) => a < b ? a : b);
  }
  return svc.durationMinutes;
}

int _priceForServiceId(STO s, String serviceId) {
  for (final svc in s.services) {
    if (svc.id == serviceId) return _linePriceKopecks(svc);
    final cat = svc.catalogItemId?.trim();
    if (cat != null && cat.isNotEmpty && cat == serviceId) {
      return _linePriceKopecks(svc);
    }
  }
  return 0;
}

/// Цена по id строки в точке, включая legacy-id, эквивалентные [catalogId].
int _priceForCatalogLine(STO s, String catalogId) {
  final direct = _priceForServiceId(s, catalogId);
  if (direct > 0) return direct;
  for (final e in _legacyMockServiceIdToCatalog.entries) {
    if (e.value == catalogId) {
      final p = _priceForServiceId(s, e.key);
      if (p > 0) return p;
    }
  }
  return 0;
}

int _durationForServiceId(STO s, String serviceId) {
  for (final svc in s.services) {
    if (svc.id == serviceId) return _lineDurationMinutes(svc);
    final cat = svc.catalogItemId?.trim();
    if (cat != null && cat.isNotEmpty && cat == serviceId) {
      return _lineDurationMinutes(svc);
    }
  }
  return 0;
}

int _durationForCatalogLine(STO s, String catalogId) {
  final direct = _durationForServiceId(s, catalogId);
  if (direct > 0) return direct;
  for (final e in _legacyMockServiceIdToCatalog.entries) {
    if (e.value == catalogId) {
      final d = _durationForServiceId(s, e.key);
      if (d > 0) return d;
    }
  }
  return 0;
}

/// Цена/время для строки итога по выбранному в фильтре id (с эквивалентом масло↔фильтр).
int priceKopecksForCatalogFilterLine(STO s, String filterId) {
  var p = _priceForCatalogLine(s, filterId);
  if (p > 0) return p;
  if (filterId == ClientCatalogServiceIds.oilFilterOnly) {
    p = _priceForCatalogLine(s, ClientCatalogServiceIds.oilEngine);
    if (p > 0) return p;
  }
  return 0;
}

int durationMinutesForCatalogFilterLine(STO s, String filterId) {
  var d = _durationForCatalogLine(s, filterId);
  if (d > 0) return d;
  if (filterId == ClientCatalogServiceIds.oilFilterOnly) {
    d = _durationForCatalogLine(s, ClientCatalogServiceIds.oilEngine);
    if (d > 0) return d;
  }
  return 0;
}
