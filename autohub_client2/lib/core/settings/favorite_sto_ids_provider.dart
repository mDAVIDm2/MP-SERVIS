import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../providers/app_providers.dart';
import '../sync/client_app_state_push_bridge.dart';
import 'filter_by_car_setting.dart';
import '../../shared/models/sto_model.dart';

const _kFavoriteStoIdsPrefix = 'favorite_sto_ids_';
const _kPerCarFavoriteStoIdsPrefix = 'per_car_favorite_sto_ids_';

/// Состояние избранных точек: глобальный список (для всех машин) и по машинам. Привязано к аккаунту (userId).
class FavoriteStoState {
  final Set<String> globalIds;
  final Map<String, Set<String>> perCarIds;

  const FavoriteStoState({
    required this.globalIds,
    required this.perCarIds,
  });
}

final favoriteStoStateProvider =
    StateNotifierProvider<FavoriteStoNotifier, FavoriteStoState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider).valueOrNull;
  final userId = ref.watch(authProvider).user?.id;
  final carIds = ref.watch(carsProvider).valueOrNull?.map((c) => c.id).toSet() ?? {};
  return FavoriteStoNotifier(prefs, userId, carIds);
});

class FavoriteStoNotifier extends StateNotifier<FavoriteStoState> {
  FavoriteStoNotifier(SharedPreferences? prefs, this._userId, this._carIds)
      : _prefs = prefs,
        super(_load(prefs, _userId));

  final SharedPreferences? _prefs;
  final String? _userId;
  final Set<String> _carIds;

  String get _keyGlobal => _kFavoriteStoIdsPrefix + (_userId ?? '');
  String get _keyPerCar => _kPerCarFavoriteStoIdsPrefix + (_userId ?? '');

  static FavoriteStoState _load(SharedPreferences? prefs, String? userId) {
    Set<String> global = {};
    Map<String, Set<String>> perCar = {};

    if (prefs != null && userId != null && userId.isNotEmpty) {
      final list = prefs.getStringList(_kFavoriteStoIdsPrefix + userId);
      if (list != null && list.isNotEmpty) global = Set.from(list);

      final jsonStr = prefs.getString(_kPerCarFavoriteStoIdsPrefix + userId);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        try {
          final decoded = jsonDecode(jsonStr) as Map<String, dynamic>?;
          if (decoded != null) {
            perCar = decoded.map((k, v) => MapEntry(
                  k,
                  Set<String>.from((v as List).map((e) => e as String)),
                ));
          }
        } catch (_) {}
      }
    }

    return FavoriteStoState(globalIds: global, perCarIds: perCar);
  }

  /// Добавить/убрать точку из избранного.
  /// При выключенной сортировке по машине: добавить — в общий список и в избранное у каждой машины; убрать — везде.
  /// При включённой сортировке: добавить/убрать только у выбранного авто.
  Future<void> toggle(
    String stoId, {
    required bool filterByCar,
    String? selectedCarId,
  }) async {
    if (filterByCar && selectedCarId != null) {
      // Сортировка по машине включена — меняем только избранное выбранного авто
      final nextPerCar = Map<String, Set<String>>.from(state.perCarIds);
      final carSet = Set<String>.from(nextPerCar[selectedCarId] ?? {});
      if (carSet.contains(stoId)) {
        carSet.remove(stoId);
      } else {
        carSet.add(stoId);
      }
      if (carSet.isEmpty) {
        nextPerCar.remove(selectedCarId);
      } else {
        nextPerCar[selectedCarId] = carSet;
      }
      state = FavoriteStoState(globalIds: state.globalIds, perCarIds: nextPerCar);
      await _savePerCar(nextPerCar);
      scheduleClientAppStatePush();
    } else {
      // Сортировка выключена — добавляем/убираем «всем машинам»: в global и в perCar у каждой машины
      final nextGlobal = Set<String>.from(state.globalIds);
      final nextPerCar = Map<String, Set<String>>.from(state.perCarIds);
      final allCarIds = _carIds;

      if (nextGlobal.contains(stoId)) {
        nextGlobal.remove(stoId);
        for (final carId in allCarIds) {
          final carSet = nextPerCar[carId];
          if (carSet != null) {
            final next = Set<String>.from(carSet)..remove(stoId);
            if (next.isEmpty) {
              nextPerCar.remove(carId);
            } else {
              nextPerCar[carId] = next;
            }
          }
        }
      } else {
        nextGlobal.add(stoId);
        for (final carId in allCarIds) {
          nextPerCar[carId] = Set<String>.from(nextPerCar[carId] ?? {})..add(stoId);
        }
      }

      state = FavoriteStoState(globalIds: nextGlobal, perCarIds: nextPerCar);
      await _prefs?.setStringList(_keyGlobal, nextGlobal.toList());
      await _savePerCar(nextPerCar);
      scheduleClientAppStatePush();
    }
  }

  Future<void> _savePerCar(Map<String, Set<String>> perCar) async {
    final p = _prefs;
    if (p == null || _userId == null) return;
    final encoded = perCar.map((k, v) => MapEntry(k, v.toList()));
    await p.setString(_keyPerCar, jsonEncode(encoded));
  }
}

/// Эффективное множество избранных точек в текущем контексте: при включённой «Сортировать по машине» — избранное выбранного авто, иначе — общий список.
final effectiveFavoriteStoIdsProvider = Provider<Set<String>>((ref) {
  final state = ref.watch(favoriteStoStateProvider);
  final filterByCar = ref.watch(filterByCarSettingProvider);
  final selectedId = ref.watch(selectedCarIdProvider);
  if (filterByCar && selectedId != null) {
    return state.perCarIds[selectedId] ?? {};
  }
  return state.globalIds;
});

/// Список точек в избранном: загрузка по id из каталога API.
///
/// `GET /catalog/organizations/:id` не отдаёт `service_ids` / `services` (в отличие от поиска),
/// поэтому фильтр по услугам на экране «Услуги» обнулял бы список. Подтягиваем прайс отдельно.
final favoriteSTOsListProvider = FutureProvider<List<STO>>((ref) async {
  final ids = ref.watch(effectiveFavoriteStoIdsProvider);
  if (ids.isEmpty) return [];
  final repo = ref.watch(stoRepositoryProvider);
  final list = <STO>[];
  for (final id in ids) {
    final r = await repo.getSTOById(id);
    var sto = r.dataOrNull;
    if (sto == null) continue;
    if (sto.serviceIds.isEmpty && sto.services.isEmpty) {
      final sr = await repo.getServices(id);
      final svcs = sr.dataOrNull;
      if (svcs != null && svcs.isNotEmpty) {
        sto = sto.copyWith(
          services: svcs,
          serviceIds: svcs.map((s) => s.id).toList(),
        );
      }
    }
    list.add(sto);
  }
  return list;
});
