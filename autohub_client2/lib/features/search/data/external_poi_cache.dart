import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/external_poi.dart';

const _prefsKey = 'external_poi_cache_v1';
const _maxEntries = 40;
/// Кэш считается свежим 7 дней, потом данные обновляются при следующем запросе области.
const _cacheValidDuration = Duration(days: 7);

/// Кэш загруженных внешних POI по области карты. Сохраняется на диск, при повторном открытии области данные берутся из кэша.
class ExternalPOICache {
  ExternalPOICache([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memory = {};

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Ключ области: округление до 2 знаков (~1.1 км), чтобы соседние запросы попадали в один кэш.
  static String _bboxKey(double minLat, double minLng, double maxLat, double maxLng) {
    return '${minLat.toStringAsFixed(2)}_${minLng.toStringAsFixed(2)}_'
        '${maxLat.toStringAsFixed(2)}_${maxLng.toStringAsFixed(2)}';
  }

  bool _loaded = false;

  Future<void> _loadFromDisk() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await _getPrefs();
      final json = prefs.getString(_prefsKey);
      if (json == null) return;
      final data = jsonDecode(json) as Map<String, dynamic>?;
      final entries = data?['entries'] as Map<String, dynamic>?;
      if (entries == null) return;
      for (final e in entries.entries) {
        if (e.value is Map<String, dynamic>) {
          _memory[e.key] = _CacheEntry.fromJson(e.value as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  /// Получить POI из кэша для области. null, если нет или кэш устарел.
  Future<List<ExternalPOI>?> get(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  ) async {
    await _loadFromDisk();
    final key = _bboxKey(minLat, minLng, maxLat, maxLng);
    final entry = _memory[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.fetchedAt) > _cacheValidDuration) {
      _memory.remove(key);
      return null;
    }
    return entry.pois;
  }

  /// Сохранить POI для области в кэш и на диск.
  Future<void> put(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
    List<ExternalPOI> pois,
  ) async {
    final key = _bboxKey(minLat, minLng, maxLat, maxLng);
    _memory[key] = _CacheEntry(
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
      pois: pois,
      fetchedAt: DateTime.now(),
    );
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await _getPrefs();
      final entries = <String, dynamic>{};
      final keys = _memory.keys.toList();
      keys.sort((a, b) {
        final ta = _memory[a]!.fetchedAt;
        final tb = _memory[b]!.fetchedAt;
        return tb.compareTo(ta);
      });
      for (var i = 0; i < keys.length && i < _maxEntries; i++) {
        final k = keys[i];
        entries[k] = _memory[k]!.toJson();
      }
      await prefs.setString(_prefsKey, jsonEncode({'entries': entries}));
    } catch (_) {}
  }
}

class _CacheEntry {
  _CacheEntry({
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    required this.pois,
    required this.fetchedAt,
  });

  final double minLat, minLng, maxLat, maxLng;
  final List<ExternalPOI> pois;
  final DateTime fetchedAt;

  Map<String, dynamic> toJson() => {
        'minLat': minLat,
        'minLng': minLng,
        'maxLat': maxLat,
        'maxLng': maxLng,
        'pois': pois.map((e) => e.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };

  static _CacheEntry fromJson(Map<String, dynamic> map) {
    final list = map['pois'] as List<dynamic>? ?? [];
    return _CacheEntry(
      minLat: (map['minLat'] as num?)?.toDouble() ?? 0,
      minLng: (map['minLng'] as num?)?.toDouble() ?? 0,
      maxLat: (map['maxLat'] as num?)?.toDouble() ?? 0,
      maxLng: (map['maxLng'] as num?)?.toDouble() ?? 0,
      pois: list.map((e) => ExternalPOI.fromJson(e as Map<String, dynamic>)).toList(),
      fetchedAt: DateTime.tryParse(map['fetchedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
