import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../../shared/models/external_poi.dart';

const _prefsKey = 'external_poi_cache_v3';
const _prefsKeyLegacy = 'external_poi_cache_v1';
const _maxEntries = 96;
/// Кэш считается свежим 21 день, потом данные обновляются при следующем запросе области.
const _cacheValidDuration = Duration(days: 21);

/// Результат чтения кэша (список + время загрузки для фонового обновления).
class ExternalPoiCacheHit {
  const ExternalPoiCacheHit({required this.pois, required this.fetchedAt});
  final List<ExternalPOI> pois;
  final DateTime fetchedAt;
}

/// Кэш загруженных внешних POI по области карты. Сохраняется на диск, при повторном открытии области данные берутся из кэша.
class ExternalPOICache {
  ExternalPOICache([SharedPreferences? prefs]) : _prefs = prefs;

  SharedPreferences? _prefs;
  final Map<String, _CacheEntry> _memory = {};

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Ключ области: 1 знак после запятой (~11 км), чтобы соседние смещения карты попадали в один кэш и реже бить Overpass.
  static String _bboxKey(double minLat, double minLng, double maxLat, double maxLng) {
    return '${minLat.toStringAsFixed(1)}_${minLng.toStringAsFixed(1)}_'
        '${maxLat.toStringAsFixed(1)}_${maxLng.toStringAsFixed(1)}';
  }

  bool _loaded = false;

  /// Предзагрузить кэш с диска до первого [lookup] (быстрее показать точки после перезапуска).
  Future<void> ensureLoaded() async {
    await _loadFromDisk();
  }

  static bool _rectsOverlap(
    double aMinLat,
    double aMinLng,
    double aMaxLat,
    double aMaxLng,
    double bMinLat,
    double bMinLng,
    double bMaxLat,
    double bMaxLng,
  ) {
    return aMinLat <= bMaxLat && aMaxLat >= bMinLat && aMinLng <= bMaxLng && aMaxLng >= bMinLng;
  }

  static bool _entryFresh(DateTime fetchedAt) =>
      DateTime.now().difference(fetchedAt) <= _cacheValidDuration;

  /// Объединить все **ещё валидные** области кэша, пересекающиеся с запрошенным bbox (не только точное совпадение ключа).
  /// Нужен, чтобы после перезапуска подставлять данные из памяти/диска для соседних смещений карты.
  Future<ExternalPoiCacheHit?> lookupMergeOverlapping(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  ) async {
    await _loadFromDisk();
    if (_memory.isEmpty) return null;
    final merged = <ExternalPOI>[];
    final ids = <String>{};
    DateTime? newest;
    for (final e in _memory.values) {
      if (!_entryFresh(e.fetchedAt)) continue;
      if (!_rectsOverlap(e.minLat, e.minLng, e.maxLat, e.maxLng, minLat, minLng, maxLat, maxLng)) {
        continue;
      }
      if (newest == null || e.fetchedAt.isAfter(newest)) {
        newest = e.fetchedAt;
      }
      for (final p in e.pois) {
        if (ids.add(p.id)) merged.add(p);
      }
    }
    if (merged.isEmpty || newest == null) return null;
    return ExternalPoiCacheHit(pois: merged, fetchedAt: newest);
  }

  Future<void> _loadFromDisk() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await _getPrefs();
      var json = prefs.getString(_prefsKey);
      json ??= prefs.getString(_prefsKeyLegacy);
      if (json == null) return;
      final data = jsonDecode(json) as Map<String, dynamic>?;
      final entries = data?['entries'] as Map<String, dynamic>?;
      if (entries == null) return;
      for (final e in entries.entries) {
        if (e.value is Map<String, dynamic>) {
          final entry = _CacheEntry.fromJson(e.value as Map<String, dynamic>);
          final key = _bboxKey(entry.minLat, entry.minLng, entry.maxLat, entry.maxLng);
          _memory[key] = entry;
        }
      }
    } catch (_) {}
  }

  /// Получить POI и метаданные. null, если нет или кэш жёстко устарел (>21 дня).
  Future<ExternalPoiCacheHit?> lookup(
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
      await _persist();
      return null;
    }
    return ExternalPoiCacheHit(pois: entry.pois, fetchedAt: entry.fetchedAt);
  }

  /// Получить POI из кэша для области. null, если нет или кэш устарел.
  Future<List<ExternalPOI>?> get(
    double minLat,
    double minLng,
    double maxLat,
    double maxLng,
  ) async {
    final hit = await lookup(minLat, minLng, maxLat, maxLng);
    return hit?.pois;
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

const _sessionKey = 'external_poi_merged_session_v1';
const _maxSessionPersist = 1200;

/// Последний объединённый список внешних POI для быстрого показа после перезапуска (до подгрузки сети).
class ExternalPoiSessionStore {
  static Future<List<ExternalPOI>?> load(SharedPreferences prefs) async {
    try {
      final s = prefs.getString(_sessionKey);
      if (s == null || s.isEmpty) return null;
      final list = jsonDecode(s) as List<dynamic>?;
      if (list == null || list.isEmpty) return null;
      return list.map((e) => ExternalPOI.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> save(SharedPreferences prefs, List<ExternalPOI> pois) async {
    try {
      final cap = pois.length > _maxSessionPersist ? pois.sublist(0, _maxSessionPersist) : pois;
      await prefs.setString(_sessionKey, jsonEncode(cap.map((p) => p.toJson()).toList()));
    } catch (_) {}
  }
}
