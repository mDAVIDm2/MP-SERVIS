import 'dart:convert';

/// Разбор payload уведомлений pending_car_* (разный регистр ключей, snake_case с бэкенда, строковые id).
class PendingCarNotificationPayload {
  PendingCarNotificationPayload._();

  /// Приводит payload к Map с ключами-строками; поддерживает JSON-строку.
  static Map<String, dynamic>? asStringKeyedMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final t = raw.trim();
      if (t.isEmpty) return null;
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map) {
          return _mapFromAny(decoded);
        }
      } catch (_) {
        return null;
      }
      return null;
    }
    if (raw is Map) {
      return _mapFromAny(raw);
    }
    return null;
  }

  static Map<String, dynamic> _mapFromAny(Map map) {
    return Map<String, dynamic>.from(
      map.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  static int? readInt(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      final v = p[k];
      if (v == null) continue;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final n = int.tryParse(v.trim());
        if (n != null) return n;
      }
    }
    return null;
  }

  static String readString(Map<String, dynamic> p, List<String> keys) {
    for (final k in keys) {
      final v = p[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty && s != 'null') return s;
    }
    return '';
  }

  /// Извлекает id и названия для обновления карточки авто.
  static ({
    int? brandId,
    int? modelId,
    int? genId,
    String brandName,
    String modelName,
    String genName,
  }) parse(
    Map<String, dynamic> p, {
    required bool isSuggested,
  }) {
    var brandId = readInt(p, ['brandId', 'brand_id']);
    var modelId = readInt(p, ['modelId', 'model_id']);
    var genId = readInt(p, ['generationId', 'generation_id']);

    if (isSuggested) {
      brandId ??= readInt(p, ['suggestedBrandId', 'suggested_brand_id']);
      modelId ??= readInt(p, ['suggestedModelId', 'suggested_model_id']);
      genId ??= readInt(p, ['suggestedGenerationId', 'suggested_generation_id']);
    }

    final brandName = readString(p, [
      if (isSuggested) ...['suggestedBrandName', 'suggested_brand_name'],
      'brandName',
      'brand_name',
    ]);
    final modelName = readString(p, [
      if (isSuggested) ...['suggestedModelName', 'suggested_model_name'],
      'modelName',
      'model_name',
    ]);
    final genName = readString(p, [
      if (isSuggested) ...['suggestedGenerationName', 'suggested_generation_name'],
      'generationName',
      'generation_name',
    ]);

    return (
      brandId: brandId,
      modelId: modelId,
      genId: genId,
      brandName: brandName,
      modelName: modelName,
      genName: genName,
    );
  }
}
